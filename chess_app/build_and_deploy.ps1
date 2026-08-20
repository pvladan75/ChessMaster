# Gradi ARM64 release APK i pokrece ga na povezanom telefonu.
#
# Sta je ovde islo naopako 20.8.2026: skripta je instalirala novu aplikaciju, a
# pokretala staru (`com.example.chess_app`, ime paketa od pre preimenovanja).
# Stara instalacija i dalje stoji na telefonu, prijava u njoj radi jer se
# backend nije menjao, pa je izgledalo kao da je nalog prazan - bez zadataka i
# bez trenera. Zato se ime paketa vise ne kuca ovde nego se cita iz Gradle-a.
#
# Drugo pravilo: ako sveze sagradjen APK ne postoji, skripta staje. Ranije je
# padala na `app-release.apk`, a to ume da bude nedelju dana star fajl koji je
# ostao u `build/`.

param(
    # Kad je povezano vise uredjaja, izaberi jedan: .\build_and_deploy.ps1 -Serial ABC123
    [string]$Serial
)

$ErrorActionPreference = "Stop"
$env:Path += ";$env:LOCALAPPDATA\Android\Sdk\platform-tools"

function Fail($poruka) {
    Write-Host "X $poruka" -ForegroundColor Red
    exit 1
}

# --- [0/4] Provere pre gradnje, da se ne otkriju tek posle tri minuta ---

if (-not (Get-Command adb -ErrorAction SilentlyContinue)) {
    Fail "adb nije nadjen. Ocekivan je u $env:LOCALAPPDATA\Android\Sdk\platform-tools."
}

if (-not (Test-Path "dart_defines.json")) {
    Fail "Nema dart_defines.json. Fajl je namerno van repozitorijuma - napravi ga po uzoru na .env.example, sa adresom backend-a."
}

# Ime paketa se izvodi iz Gradle-a. Prepisano ovde, jednom bi se razislo sa
# aplikacijom - i tacno to se i desilo.
$gradle = "android\app\build.gradle.kts"
if (-not (Test-Path $gradle)) { Fail "Nema $gradle." }

$appId = (Select-String -Path $gradle -Pattern 'applicationId\s*=\s*"([^"]+)"' |
          Select-Object -First 1).Matches.Groups[1].Value
if ([string]::IsNullOrWhiteSpace($appId)) {
    Fail "Ne mogu da procitam applicationId iz $gradle."
}

# Uredjaji: jedan je ocekivan slucaj, vise njih traze izbor umesto pogadjanja.
$uredjaji = (adb devices) | Select-Object -Skip 1 |
            Where-Object { $_ -match "\tdevice$" } |
            ForEach-Object { ($_ -split "\t")[0] }

if ($uredjaji.Count -eq 0) { Fail "Nijedan telefon nije povezan (adb devices)." }
if ($uredjaji.Count -gt 1 -and -not $Serial) {
    Write-Host "Povezano je vise uredjaja:" -ForegroundColor Yellow
    $uredjaji | ForEach-Object { Write-Host "  $_" }
    Fail "Izaberi jedan: .\build_and_deploy.ps1 -Serial $($uredjaji[0])"
}
if ($Serial -and ($uredjaji -notcontains $Serial)) { Fail "Uredjaj $Serial nije povezan." }

$adbArgs = @()
if ($Serial) { $adbArgs = @("-s", $Serial) }

Write-Host "Paket: $appId" -ForegroundColor DarkGray

# --- [1/4] Gradnja ---

Write-Host "--- [1/4] Pokrecem Flutter ARM64 Release Build ---" -ForegroundColor Cyan
$pocetak = Get-Date

flutter build apk --release --target-platform=android-arm64 --split-per-abi --dart-define-from-file=dart_defines.json
if ($LASTEXITCODE -ne 0) { Fail "Build nije uspeo." }

# --- [2/4] Koji APK, i da li je stvarno od maloprvasnje gradnje ---

$APK = "build\app\outputs\flutter-apk\app-arm64-v8a-release.apk"
if (-not (Test-Path $APK)) {
    Fail "Nema $APK. Ranije se ovde padalo na app-release.apk, ali to ume da bude star fajl iz build\ i tako se na telefon vrati verzija od pre nedelju dana."
}

$napravljen = (Get-Item $APK).LastWriteTime
if ($napravljen -lt $pocetak) {
    Fail "APK je od $napravljen, a gradnja je pocela $pocetak - to je zaostao fajl, ne sveza gradnja."
}

# --- [3/4] Instalacija ---

Write-Host "--- [2/4] Instaliram $APK ---" -ForegroundColor Yellow
adb @adbArgs install -r $APK
if ($LASTEXITCODE -ne 0) { Fail "Instalacija nije uspela." }

# --- [4/4] Pokretanje bas onog paketa koji je upravo instaliran ---

Write-Host "--- [3/4] Pokrecem $appId ---" -ForegroundColor Yellow
adb @adbArgs shell monkey -p $appId -c android.intent.category.LAUNCHER 1 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) { Fail "Aplikacija je instalirana, ali se nije pokrenula." }

Write-Host "--- [4/4] USPESNO INSTALIRANO I POKRENUTO ($appId) ---" -ForegroundColor Green

# Stara instalacija pod starim imenom paketa se nikad ne azurira, a ikona joj
# lici. Dok stoji na telefonu, lako se otvori pogresna - sto se vec desilo.
$stara = adb @adbArgs shell pm list packages com.example.chess_app
if ($stara) {
    Write-Host ""
    Write-Host "! Na telefonu i dalje stoji stara instalacija: com.example.chess_app" -ForegroundColor Yellow
    Write-Host "  Ona se ne azurira i nema nista od novog rada. Ako je otvoris, nalog izgleda prazan." -ForegroundColor Yellow
    $komanda = (@("adb") + $adbArgs + @("uninstall", "com.example.chess_app")) -join " "
    Write-Host "  Brisanje: $komanda" -ForegroundColor Yellow
}
