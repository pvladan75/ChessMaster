# Jedan ulaz za instalaciju: Windows, telefon, ili oboje - i deinstalacija.
#
# Ovo je vrata, ne nova skripta. Gradnju i dalje rade build_windows.ps1 i
# build_and_deploy.ps1, i to namerno: u njima stoje provere koje su placene
# izgubljenim danima - zaostao font sa ikonama, ime paketa procitano iz
# Gradle-a umesto prepisano, APK od pre nedelju dana koji izgleda kao svez,
# adb koji pise na stderr pa uspeh lici na pad. Prepisati sve to u jedan fajl
# znacilo bi izgubiti bar jednu od tih provera, a nijedna se ne bi javila
# odmah.
#
# Zato ovde stoji samo ono sto te dve skripte nemaju: izbor sta se radi, i
# deinstalacija na oba mesta.

param(
    # windows, android, oba. Bez ovoga skripta pita.
    [ValidateSet("windows", "android", "oba")]
    [string]$Platforma,

    # debug ili release. Prosledjuje se dalje; bez ovoga pitaju one.
    [ValidateSet("debug", "release")]
    [string]$Mode,

    # Gde ide Windows kopija. Podrazumevano %LOCALAPPDATA%\Mislisha.
    [string]$InstallPath = "$env:LOCALAPPDATA\Mislisha",

    # Kad je povezano vise telefona.
    [string]$Serial,

    # Pokrece Windows kopiju posle instalacije. Telefon se pokrece uvek.
    [switch]$Run,

    # Deinstalacija umesto instalacije.
    [switch]$Uninstall
)

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

function Fail($poruka) {
    Write-Host "X $poruka" -ForegroundColor Red
    exit 1
}

function Naslov($tekst) {
    Write-Host ""
    Write-Host "=== $tekst ===" -ForegroundColor Cyan
}

# --- Ime paketa i ime programa: procitani, ne prepisani ---
#
# Isti razlog kao u obe skripte ispod. Ovde su potrebni samo za deinstalaciju,
# ali pogresno ime paketa u `adb uninstall` ne prijavljuje gresku - samo ne
# obrise nista, i izgleda kao da je proslo.

$gradle = "android\app\build.gradle.kts"
$appId = ""
if (Test-Path $gradle) {
    $appId = (Select-String -Path $gradle -Pattern 'applicationId\s*=\s*"([^"]+)"' |
        Select-Object -First 1).Matches.Groups[1].Value
}

$cmake = "windows\CMakeLists.txt"
$imeExe = "chess_app.exe"
if (Test-Path $cmake) {
    $bin = (Select-String -Path $cmake -Pattern 'set\(BINARY_NAME\s+"([^"]+)"' |
        Select-Object -First 1).Matches.Groups[1].Value
    if ($bin) { $imeExe = "$bin.exe" }
}

# Instalacije od pre preimenovanja binarnog fajla i dalje moraju da se prepoznaju.
$stariExe = "chess_app.exe"

function Test-NasaInstalacija($putanja) {
    return (Test-Path (Join-Path $putanja $imeExe)) -or
           (Test-Path (Join-Path $putanja $stariExe))
}

# --- Gde sve moze da stoji Windows kopija ---
#
# Trazi se umesto da se pamti: skripta nema gde da vodi spisak, a jedna
# zaboravljena stara kopija je tacno ono zbog cega covek misli da testira novu
# verziju a gleda staru.

function Nadji-Instalacije {
    $mesta = @("$env:LOCALAPPDATA\Mislisha")
    Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue |
        Where-Object { $_.Root -match '^[A-Z]:\\$' } |
        ForEach-Object { $mesta += (Join-Path $_.Root "Mislisha") }
    if ($InstallPath) { $mesta += $InstallPath }

    $nadjene = @()
    foreach ($m in ($mesta | Select-Object -Unique)) {
        if ((Test-Path $m) -and (Test-NasaInstalacija $m)) { $nadjene += $m }
    }
    return $nadjene
}

# --- Deinstalacija ---

function Ukloni-Windows {
    $nadjene = Nadji-Instalacije
    if ($nadjene.Count -eq 0) {
        Write-Host "  Nema nijedne Windows instalacije." -ForegroundColor DarkGray
        return
    }

    Write-Host "  Nadjeno:" -ForegroundColor Yellow
    foreach ($m in $nadjene) {
        $oznaka = ""
        $buildTxt = Join-Path $m "BUILD.txt"
        if (Test-Path $buildTxt) { $oznaka = "  [" + ((Get-Content $buildTxt -Raw).Trim()) + "]" }
        Write-Host "    $m$oznaka"
    }

    $odgovor = (Read-Host "  Obrisati sve navedeno? (d/N)").Trim().ToLower()
    if ($odgovor -ne "d") {
        Write-Host "  Preskoceno." -ForegroundColor DarkGray
        return
    }

    foreach ($m in $nadjene) {
        # Brise se kroz build_windows.ps1, ne rucno: tamo stoji zastita koja
        # odbija folder koji nije nasa instalacija, i ona je jedini razlog zbog
        # kog jedan pogresan -InstallPath ne odnese tudji folder.
        & "$PSScriptRoot\build_windows.ps1" -Uninstall -InstallPath $m
        if ($LASTEXITCODE -ne 0) { Fail "Brisanje $m nije uspelo." }
    }
}

function Ukloni-Android {
    if (-not (Get-Command adb -ErrorAction SilentlyContinue)) {
        $env:Path += ";$env:LOCALAPPDATA\Android\Sdk\platform-tools"
    }
    if (-not (Get-Command adb -ErrorAction SilentlyContinue)) {
        Write-Host "  adb nije nadjen; telefon se preskace." -ForegroundColor Yellow
        return
    }
    if (-not $appId) {
        Write-Host "  Ne mogu da procitam applicationId; telefon se preskace." -ForegroundColor Yellow
        return
    }

    $adbArgs = @()
    if ($Serial) { $adbArgs = @("-s", $Serial) }

    # Stari paket se nudi zajedno sa novim: dok stoji na telefonu, ikona mu lici
    # i lako se otvori pogresna aplikacija - sto se vec desilo.
    $paketi = @($appId, "com.example.chess_app")

    Write-Host ""
    Write-Host "  ! Brisanje aplikacije sa telefona odnosi i prijavu i sva podesavanja." -ForegroundColor Yellow
    Write-Host "    Partije i zadaci ostaju na serveru; sa telefona nestaje samo nalog." -ForegroundColor DarkGray
    $odgovor = (Read-Host "  Obrisati $($paketi -join ' i ') sa telefona? (d/N)").Trim().ToLower()
    if ($odgovor -ne "d") {
        Write-Host "  Preskoceno." -ForegroundColor DarkGray
        return
    }

    foreach ($p in $paketi) {
        $prethodni = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        $izlaz = & adb @($adbArgs + @("uninstall", $p)) 2>&1 | ForEach-Object { "$_" }
        $ErrorActionPreference = $prethodni

        if ("$izlaz" -match "Success") {
            Write-Host "  Obrisano: $p" -ForegroundColor Green
        } else {
            # `adb uninstall` na paket koji ne postoji nije greska ovde: to je
            # ocekivan slucaj za stari paket.
            Write-Host "  $p nije bio instaliran." -ForegroundColor DarkGray
        }
    }
}

# --- Sta se radi ---

if (-not $Platforma) {
    Write-Host ""
    if ($Uninstall) {
        Write-Host "Sta da obrisem?" -ForegroundColor Cyan
    } else {
        Write-Host "Sta da instaliram?" -ForegroundColor Cyan
    }
    Write-Host "  [W] Windows" -ForegroundColor DarkGray
    Write-Host "  [A] Android (telefon povezan kablom)" -ForegroundColor DarkGray
    Write-Host "  [O] oba" -ForegroundColor DarkGray
    if (-not $Uninstall) {
        Write-Host "  [B] brisanje - deinstalacija umesto instalacije" -ForegroundColor DarkGray
    }
    $izbor = (Read-Host "W, A, O ili B (prazno = W)").Trim().ToUpper()
    switch ($izbor) {
        ""  { $Platforma = "windows" }
        "W" { $Platforma = "windows" }
        "A" { $Platforma = "android" }
        "O" { $Platforma = "oba" }
        "B" {
            $Uninstall = $true
            $sta = (Read-Host "  Brisem: W, A ili O (prazno = O)").Trim().ToUpper()
            switch ($sta) {
                ""  { $Platforma = "oba" }
                "W" { $Platforma = "windows" }
                "A" { $Platforma = "android" }
                "O" { $Platforma = "oba" }
                default { Fail "Nejasan odgovor: '$sta'." }
            }
        }
        default { Fail "Nejasan odgovor: '$izbor'. Ocekuje se W, A, O ili B." }
    }
}

$radiWindows = $Platforma -eq "windows" -or $Platforma -eq "oba"
$radiAndroid = $Platforma -eq "android" -or $Platforma -eq "oba"

# --- Deinstalacija, pa kraj ---

if ($Uninstall) {
    if ($radiWindows) { Naslov "Brisem Windows kopije"; Ukloni-Windows }
    if ($radiAndroid) { Naslov "Brisem sa telefona"; Ukloni-Android }
    Write-Host ""
    Write-Host "Gotovo." -ForegroundColor Green
    exit 0
}

# --- Instalacija ---
#
# Pitanje debug/release stoji jednom, ovde, i prosledjuje se obema skriptama.
# Inace bi kod izbora "oba" isto pitanje stiglo dvaput, a dva razlicita
# odgovora daju dve razlicite verzije koje se posle porede kao da su ista.

if (-not $Mode) {
    Write-Host ""
    Write-Host "Koju verziju?" -ForegroundColor Cyan
    Write-Host "  [R] release - ono sto korisnik dobija. Puna brzina, ali se prelivanje" -ForegroundColor DarkGray
    Write-Host "                ne crta nego se cutke isece." -ForegroundColor DarkGray
    Write-Host "  [D] debug   - crta zuto-crne pruge preko prelivanja. Sporiji je, i to" -ForegroundColor DarkGray
    Write-Host "                sto je spor nije nalaz." -ForegroundColor DarkGray
    $izbor = (Read-Host "R ili D (prazno = R)").Trim().ToUpper()
    switch ($izbor) {
        ""  { $Mode = "release" }
        "R" { $Mode = "release" }
        "D" { $Mode = "debug" }
        default { Fail "Nejasan odgovor: '$izbor'. Ocekuje se R ili D." }
    }
}

if ($radiWindows) {
    Naslov "Windows ($Mode) -> $InstallPath"
    $argumenti = @("-Mode", $Mode, "-Install", "-InstallPath", $InstallPath)
    if ($Run -and -not $radiAndroid) { $argumenti += "-Run" }
    & "$PSScriptRoot\build_windows.ps1" @argumenti
    if ($LASTEXITCODE -ne 0) { Fail "Windows gradnja nije uspela." }
}

if ($radiAndroid) {
    Naslov "Android ($Mode)"
    $argumenti = @("-Mode", $Mode)
    if ($Serial) { $argumenti += @("-Serial", $Serial) }
    & "$PSScriptRoot\build_and_deploy.ps1" @argumenti
    if ($LASTEXITCODE -ne 0) { Fail "Android gradnja nije uspela." }
}

Write-Host ""
Write-Host "Gotovo: $Platforma, $Mode." -ForegroundColor Green
if ($radiWindows) {
    Write-Host "  Windows: $InstallPath" -ForegroundColor DarkGray
    Write-Host "  Precica: Start meni -> Mislisha" -ForegroundColor DarkGray
}
