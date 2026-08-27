# Gradi ARM64 APK (debug ili release) i pokrece ga na povezanom telefonu.
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
#
# Trece, nadjeno 27.8.2026, istog oblika kao prva dva: PowerShell sa
# $ErrorActionPreference = "Stop" pretvara svaki red koji izvorna komanda
# napise na stderr u terminirajucu gresku cim se stderr preusmerava. `monkey`
# uvek pise "args: [...]" na stderr, pa je uspesno pokretanje prijavljeno kao
# pad - a skripta je onda stala tacno pre provere stare instalacije, koja je
# jedini razlog zbog kog ta provera i postoji. Zato svaki adb ide kroz
# Invoke-Adb.

param(
    # Kad je povezano vise uredjaja, izaberi jedan: .\build_and_deploy.ps1 -Serial ABC123
    [string]$Serial,

    # debug ili release. Bez ovoga skripta pita.
    [ValidateSet("debug", "release")]
    [string]$Mode
)

$ErrorActionPreference = "Stop"
$env:Path += ";$env:LOCALAPPDATA\Android\Sdk\platform-tools"

function Fail($poruka) {
    Write-Host "X $poruka" -ForegroundColor Red
    exit 1
}

# Pokrece adb i vraca sve sto je ispisao, bez pretvaranja stderr-a u gresku.
# Izlazni kod ostaje u $LASTEXITCODE, kao i inace.
function Invoke-Adb {
    param([string[]]$Argumenti, [switch]$Prikazi)

    $prethodni = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $izlaz = & adb @Argumenti 2>&1 | ForEach-Object { "$_" }
    } finally {
        $ErrorActionPreference = $prethodni
    }
    if ($Prikazi) {
        $izlaz | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray }
    }
    return $izlaz
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
$uredjaji = (Invoke-Adb -Argumenti @("devices")) | Select-Object -Skip 1 |
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

# --- Koja gradnja ---
#
# Pitanje stoji ovde, posle jeftinih provera a pre gradnje od dva i po minuta.

if (-not $Mode) {
    Write-Host ""
    Write-Host "Koju verziju da instaliram?" -ForegroundColor Cyan
    Write-Host "  [R] release - ono sto korisnik dobija. Motor i tabla rade punom brzinom," -ForegroundColor DarkGray
    Write-Host "                pa se zamrzavanje i sporost mere na njoj. Prelivanje se ne" -ForegroundColor DarkGray
    Write-Host "                crta nego se cutke isece." -ForegroundColor DarkGray
    Write-Host "  [D] debug   - crta zuto-crne pruge preko prelivanja i puca na tvrdnjama," -ForegroundColor DarkGray
    Write-Host "                ali radi osetno sporije, pa merenje brzine odavde laze." -ForegroundColor DarkGray
    $izbor = (Read-Host "R ili D (prazno = R)").Trim().ToUpper()
    switch ($izbor) {
        ""        { $Mode = "release" }
        "R"       { $Mode = "release" }
        "RELEASE" { $Mode = "release" }
        "D"       { $Mode = "debug" }
        "DEBUG"   { $Mode = "debug" }
        default   { Fail "Nepoznat izbor: $izbor" }
    }
}

# --- Zig gradnje ---
#
# Bez commita aplikacija ne moze da kaze koji je build na telefonu, a `version:`
# iz pubspec-a to ne resava: 1.1.0+2 je isti niz na svakom APK-u ove nedelje.
# `+` na kraju commita znaci da radno stablo nije bilo cisto, pa commit sam ne
# opisuje ovaj APK.

$commit = ""
$prethodni = $ErrorActionPreference
$ErrorActionPreference = "Continue"
$kratki = (git rev-parse --short HEAD 2>$null)
$prljavo = (git status --porcelain 2>$null)
$ErrorActionPreference = $prethodni
if ($kratki) {
    $commit = "$kratki".Trim()
    if ($prljavo) { $commit = "$commit+" }
}
if (-not $commit) {
    Write-Host "! Commit se ne cita iz git-a; aplikacija ce pisati da build nije oznacen." -ForegroundColor Yellow
}

$vreme = Get-Date -Format "yyyy-MM-ddTHH:mm"
$verzija = (Select-String -Path "pubspec.yaml" -Pattern '^version:\s*(.+)$' |
            Select-Object -First 1).Matches.Groups[1].Value.Trim()

# --- [1/4] Gradnja ---

Write-Host "--- [1/4] Pokrecem Flutter ARM64 $Mode build ---" -ForegroundColor Cyan
$pocetak = Get-Date

flutter build apk "--$Mode" --target-platform=android-arm64 --split-per-abi --dart-define-from-file=dart_defines.json "--dart-define=BUILD_COMMIT=$commit" "--dart-define=BUILD_MODE=$Mode" "--dart-define=BUILD_TIME=$vreme" "--dart-define=BUILD_VERSION=$verzija"
if ($LASTEXITCODE -ne 0) { Fail "Build nije uspeo." }

# --- [2/4] Koji APK, i da li je stvarno od maloprvasnje gradnje ---

$APK = "build\app\outputs\flutter-apk\app-arm64-v8a-$Mode.apk"
if (-not (Test-Path $APK)) {
    Fail "Nema $APK. Ranije se ovde padalo na app-release.apk, ali to ume da bude star fajl iz build\ i tako se na telefon vrati verzija od pre nedelju dana."
}

$napravljen = (Get-Item $APK).LastWriteTime
if ($napravljen -lt $pocetak) {
    Fail "APK je od $napravljen, a gradnja je pocela $pocetak - to je zaostao fajl, ne sveza gradnja."
}

# --- [3/4] Instalacija ---

Write-Host "--- [2/4] Instaliram $APK ---" -ForegroundColor Yellow
$izlaz = Invoke-Adb -Argumenti ($adbArgs + @("install", "-r", $APK)) -Prikazi
if ($LASTEXITCODE -ne 0) {
    # debug i release nisu potpisani istim kljucem, pa se jedan preko drugog ne
    # instalira. Brisanje odnosi i podatke, zato se ovde samo kaze sta treba -
    # ne radi se.
    if ("$izlaz" -match "INSTALL_FAILED_UPDATE_INCOMPATIBLE|signatures do not match") {
        $komanda = (@("adb") + $adbArgs + @("uninstall", $appId)) -join " "
        Fail "Na telefonu vec stoji $appId potpisan drugim kljucem - prelazak debug <-> release trazi brisanje. Komanda: $komanda   (odnosi i prijavu i podesavanja na telefonu)"
    }
    Fail "Instalacija nije uspela."
}

# --- [4/4] Pokretanje bas onog paketa koji je upravo instaliran ---

Write-Host "--- [3/4] Pokrecem $appId ---" -ForegroundColor Yellow
Invoke-Adb -Argumenti ($adbArgs + @("shell", "monkey", "-p", $appId, "-c", "android.intent.category.LAUNCHER", "1")) | Out-Null
if ($LASTEXITCODE -ne 0) { Fail "Aplikacija je instalirana, ali se nije pokrenula." }

$oznaka = if ($commit) { "$Mode $commit" } else { "$Mode, build nije oznacen" }
Write-Host "--- [4/4] USPESNO INSTALIRANO I POKRENUTO ($appId, $oznaka) ---" -ForegroundColor Green
Write-Host "    Isto pise i u aplikaciji, na dnu Podesavanja - i kopira se dodirom." -ForegroundColor DarkGray

# Stara instalacija pod starim imenom paketa se nikad ne azurira, a ikona joj
# lici. Dok stoji na telefonu, lako se otvori pogresna - sto se vec desilo.
$stara = Invoke-Adb -Argumenti ($adbArgs + @("shell", "pm", "list", "packages", "com.example.chess_app"))
if ($stara) {
    Write-Host ""
    Write-Host "! Na telefonu i dalje stoji stara instalacija: com.example.chess_app" -ForegroundColor Yellow
    Write-Host "  Ona se ne azurira i nema nista od novog rada. Ako je otvoris, nalog izgleda prazan." -ForegroundColor Yellow
    $komanda = (@("adb") + $adbArgs + @("uninstall", "com.example.chess_app")) -join " "
    Write-Host "  Brisanje: $komanda" -ForegroundColor Yellow
}
