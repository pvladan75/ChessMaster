# Gradi Windows verziju (debug ili release), po zelji je instalira i pokrece.
#
# Postoji zbog jedne stvari koja ne sme da ide u komandu: Windows prijava preko
# Google-a trazi GOOGLE_DESKTOP_CLIENT_ID i GOOGLE_DESKTOP_CLIENT_SECRET. Oni se
# citaju iz dart_defines.json, koji je van repozitorijuma (repo je javan), pa
# vrednosti ne zavrsavaju ni u istoriji komandi ni u git-u.
#
# Isti fajl koristi i build_and_deploy.ps1 za Android, pa se podesavanje pise
# jednom. Odatle su preuzete jos dve stvari, jer su na telefonu vec placene:
#
#   1. Build se ozigosava commitom (BUILD_COMMIT i ostali). Bez toga Podesavanja
#      na Windows-u pisu "build nije oznacen", dok ista aplikacija na telefonu
#      kaze tacno koji je - pa je izvestaj o bagu sa Windows-a bezvredan.
#   2. Skripta pita debug ili release umesto da pretpostavlja. Debug crta
#      zuto-crne pruge preko prelivanja; release ga cuti i samo isece red, pa je
#      za pregled izgleda debug instrument, a release ono sto korisnik dobija.
#
# "Instalacija" na Windows-u nije instalacija: nema instalera i nema registra.
# -Install kopira ceo izlazni folder na stalno mesto i pravi precicu u Start
# meniju, pa aplikacija prezivi sledecu gradnju i `flutter clean`. Sam .exe se
# ne kopira - bez DLL-ova i data\ foldera pored sebe ne radi.

param(
    # debug ili release. Bez ovoga skripta pita.
    [ValidateSet("debug", "release")]
    [string]$Mode,

    # Kopira izlaz na stalno mesto i pravi precicu u Start meniju.
    [switch]$Install,

    # Gde. Podrazumevano %LOCALAPPDATA%\Mislisha.
    [string]$InstallPath = "$env:LOCALAPPDATA\Mislisha",

    # Pokrece aplikaciju posle gradnje (instaliranu kopiju ako je bilo -Install).
    [switch]$Run,

    # Brise instaliranu kopiju i precicu, pa izlazi. Ne dira build\.
    [switch]$Uninstall
)

$ErrorActionPreference = "Stop"

function Fail($poruka) {
    Write-Host "X $poruka" -ForegroundColor Red
    exit 1
}

$precica = Join-Path ([Environment]::GetFolderPath('Programs')) "Mislisha.lnk"

# --- -Uninstall: sam za sebe, pre svih provera ---

if ($Uninstall) {
    $obrisano = $false

    if (Test-Path $InstallPath) {
        # Brise se samo folder koji izgleda kao nas. Bez ove provere jedan
        # pogresan -InstallPath odnosi tudji folder bez pitanja.
        if (-not (Test-Path (Join-Path $InstallPath "chess_app.exe"))) {
            Fail "$InstallPath ne sadrzi chess_app.exe, pa ovo nije instalacija koju je ova skripta napravila. Nista nije obrisano."
        }
        Remove-Item -Recurse -Force $InstallPath
        Write-Host "Obrisano: $InstallPath" -ForegroundColor Green
        $obrisano = $true
    }
    if (Test-Path $precica) {
        Remove-Item -Force $precica
        Write-Host "Obrisana precica: $precica" -ForegroundColor Green
        $obrisano = $true
    }
    if (-not $obrisano) { Write-Host "Nema sta da se brise." -ForegroundColor DarkGray }
    exit 0
}

# --- [0/4] Provere pre gradnje, da se ne otkriju tek posle nekoliko minuta ---

if (-not (Test-Path "dart_defines.json")) {
    Fail "Nema dart_defines.json. Fajl je namerno van repozitorijuma - vidi dart_defines.example.json."
}

$defines = Get-Content "dart_defines.json" -Raw | ConvertFrom-Json

# Nedostatak nije greska: email prijava radi i bez ovoga. Ali mora da se kaze
# naglas, jer je simptom tih - Google dugme se prosto ne pojavi, i lako je
# pomisliti da je build pogresan.
$imaId = -not [string]::IsNullOrWhiteSpace($defines.GOOGLE_DESKTOP_CLIENT_ID)
$imaSecret = -not [string]::IsNullOrWhiteSpace($defines.GOOGLE_DESKTOP_CLIENT_SECRET)

if (-not $imaId) {
    Write-Host "! U dart_defines.json nema GOOGLE_DESKTOP_CLIENT_ID." -ForegroundColor Yellow
    Write-Host "  Google dugme se na Windows-u nece prikazati. Email prijava radi normalno." -ForegroundColor Yellow
} elseif (-not $imaSecret) {
    Write-Host "! Ima ID, nema GOOGLE_DESKTOP_CLIENT_SECRET." -ForegroundColor Yellow
    Write-Host "  Dugme ce se prikazati, ali ce razmena koda pasti - Google ga trazi za 'Desktop app' klijent." -ForegroundColor Yellow
}

if (-not $Mode) {
    Write-Host ""
    Write-Host "Koju verziju?" -ForegroundColor Cyan
    Write-Host "  [R] release - ono sto korisnik dobija. Motor i tabla rade punom brzinom," -ForegroundColor DarkGray
    Write-Host "                ali prelivanje se ne vidi: red siri od prozora se samo isece." -ForegroundColor DarkGray
    Write-Host "  [D] debug   - crta zuto-crne pruge preko prelivanja i puca na tvrdnjama," -ForegroundColor DarkGray
    Write-Host "                sporiji je, i to sto je spor nije nalaz." -ForegroundColor DarkGray
    $izbor = (Read-Host "R ili D (prazno = R)").Trim().ToUpper()
    switch ($izbor) {
        ""        { $Mode = "release" }
        "R"       { $Mode = "release" }
        "RELEASE" { $Mode = "release" }
        "D"       { $Mode = "debug" }
        "DEBUG"   { $Mode = "debug" }
        default   { Fail "Nejasan odgovor: '$izbor'. Ocekuje se R ili D." }
    }
}

$izlazniFolder = "build\windows\x64\runner\" + $Mode.Substring(0, 1).ToUpper() + $Mode.Substring(1)
$exe = Join-Path $izlazniFolder "chess_app.exe"
$font = Join-Path $izlazniFolder "data\flutter_assets\fonts\MaterialIcons-Regular.otf"

# --- Zig gradnje ---
#
# Isto obrazlozenje kao u build_and_deploy.ps1: `version:` iz pubspec-a je isti
# niz na svakoj gradnji ove nedelje, pa ne kaze koji je build. `+` na kraju
# commita znaci da radno stablo nije bilo cisto.

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

function Invoke-Build {
    flutter build windows "--$Mode" --dart-define-from-file=dart_defines.json `
        "--dart-define=BUILD_COMMIT=$commit" "--dart-define=BUILD_MODE=$Mode" `
        "--dart-define=BUILD_TIME=$vreme" "--dart-define=BUILD_VERSION=$verzija"
    if ($LASTEXITCODE -ne 0) { Fail "Build nije uspeo." }
}

Write-Host "--- [1/4] flutter build windows --$Mode ---" -ForegroundColor Cyan
$pocetak = Get-Date
Invoke-Build

# --- [2/4] Zaostao font sa ikonama ---
#
# Ikone se tree-shake-uju u MaterialIcons-Regular.otf, a taj fajl se ne
# regenerise uvek kad se doda nova ikona: dve gradnje zaredom su zadrzale font
# od pre dodavanja, pa su se Icons.handshake i Icons.chat_bubble_outline
# iscrtavale kao nista. Ikone koje se vec koriste drugde rade, sto i navodi na
# pogresan trag. Detaljno u CLAUDE.md.
#
# Ranije je ovde stajalo upozorenje sa komandom za rucno brisanje. Upozorenje
# koje trazi od korisnika jedini moguci sledeci korak je posao koji skripta nije
# zavrsila, pa ga sada radi sama - jednom, glasno, i proverava ishod.

Write-Host "--- [2/4] Font sa ikonama ---" -ForegroundColor Cyan
if (-not (Test-Path $font)) {
    Write-Host "  Fonta nema u izlazu; nema sta da zastari." -ForegroundColor DarkGray
} elseif ((Get-Item $font).LastWriteTime -lt $pocetak) {
    Write-Host "! Font je od $((Get-Item $font).LastWriteTime), a gradnja je pocela $pocetak." -ForegroundColor Yellow
    Write-Host "  Brisem ga i gradim ponovo - inace bi novododata ikona izasla prazna." -ForegroundColor Yellow
    Remove-Item -Force $font
    $pocetak = Get-Date
    Invoke-Build
    if (-not (Test-Path $font)) {
        Fail "Font nije ponovo napravljen. Ovo je vec pojelo dan 20.8.2026 - vidi CLAUDE.md pre nego sto se nastavi."
    }
    if ((Get-Item $font).LastWriteTime -lt $pocetak) {
        Fail "Font je i posle brisanja stariji od gradnje. Ne nastavljaj sa pretpostavkom da su ikone tacne."
    }
    Write-Host "  Sada je svez." -ForegroundColor Green
}
else {
    Write-Host "  Svez." -ForegroundColor DarkGray
}

if (-not (Test-Path $exe)) {
    Fail "Nema $exe - gradnja je prijavila uspeh, ali izlaz ne postoji."
}

# --- [3/4] Instalacija, ako je trazena ---

$pokreni = $exe

Write-Host "--- [3/4] Instalacija ---" -ForegroundColor Cyan
if ($Install) {
    # Nije .exe nego ceo folder: pored njega stoje DLL-ovi i data\, i .exe sam
    # se ne pokrece. Stara kopija se brise da ne ostane fajl iz proslog builda
    # koji vise niko ne pravi.
    if (Test-Path $InstallPath) {
        if (-not (Test-Path (Join-Path $InstallPath "chess_app.exe"))) {
            Fail "$InstallPath postoji a nije instalacija ove aplikacije. Izaberi drugo mesto sa -InstallPath."
        }
        try {
            Remove-Item -Recurse -Force $InstallPath
        }
        catch {
            Fail "Ne mogu da obrisem staru kopiju u $InstallPath - najverovatnije je aplikacija pokrenuta. Zatvori je pa pokreni ponovo."
        }
    }
    New-Item -ItemType Directory -Force -Path $InstallPath | Out-Null
    Copy-Item -Recurse -Force (Join-Path $izlazniFolder "*") $InstallPath

    # Zapis o tome sta je instalirano, da se debug i release ne pomesaju: obe
    # kopije izgledaju isto u Exploreru.
    "$verzija $commit $Mode $vreme" | Set-Content (Join-Path $InstallPath "BUILD.txt") -Encoding UTF8

    $wsh = New-Object -ComObject WScript.Shell
    $lnk = $wsh.CreateShortcut($precica)
    $lnk.TargetPath = Join-Path $InstallPath "chess_app.exe"
    $lnk.WorkingDirectory = $InstallPath
    $lnk.Description = "Mislisha $verzija ($Mode)"
    $lnk.Save()

    $pokreni = Join-Path $InstallPath "chess_app.exe"
    Write-Host "  Instalirano: $InstallPath" -ForegroundColor Green
    Write-Host "  Precica: $precica" -ForegroundColor Green
}
else {
    Write-Host "  Preskoceno (nema -Install). Aplikacija ostaje u $izlazniFolder i nestaje pri sledecem flutter clean." -ForegroundColor DarkGray
}

# --- [4/4] Rezultat ---

$oznaka = if ($commit) { "$Mode $commit" } else { "$Mode, build nije oznacen" }
Write-Host "--- [4/4] GOTOVO: Mislisha $verzija ($oznaka) ---" -ForegroundColor Green
Write-Host "  $pokreni" -ForegroundColor DarkGray
if ($imaId -and $imaSecret) {
    Write-Host "  Google prijava je ukljucena u ovaj build." -ForegroundColor DarkGray
    Write-Host "  Da bi radila, isti client ID mora biti i u GOOGLE_CLIENT_IDS na serveru." -ForegroundColor DarkGray
}
if ($Mode -eq "debug") {
    Write-Host "  Debug: prelivanje se vidi kao zuto-crne pruge. Sporost nije nalaz." -ForegroundColor DarkGray
}

if ($Run) {
    Write-Host "Pokrecem..." -ForegroundColor Yellow
    Start-Process -FilePath $pokreni -WorkingDirectory (Split-Path $pokreni)
}
