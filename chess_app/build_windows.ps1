# Gradi Windows release i, po zelji, pokrece ga.
#
# Postoji zbog jedne stvari koja ne sme da ide u komandu: Windows prijava preko
# Google-a trazi GOOGLE_DESKTOP_CLIENT_ID i GOOGLE_DESKTOP_CLIENT_SECRET. Oni se
# citaju iz dart_defines.json, koji je van repozitorijuma (repo je javan), pa
# vrednosti ne zavrsavaju ni u istoriji komandi ni u git-u.
#
# Isti fajl koristi i build_and_deploy.ps1 za Android, pa se podesavanje pise
# jednom.

param(
    # Pokrece .exe posle gradnje.
    [switch]$Run
)

$ErrorActionPreference = "Stop"

function Fail($poruka) {
    Write-Host "X $poruka" -ForegroundColor Red
    exit 1
}

# --- [0/3] Provere pre gradnje ---

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

# --- [1/3] Gradnja ---

Write-Host "--- [1/3] flutter build windows --release ---" -ForegroundColor Cyan
$pocetak = Get-Date

flutter build windows --release --dart-define-from-file=dart_defines.json
if ($LASTEXITCODE -ne 0) { Fail "Build nije uspeo." }

# --- [2/3] Zaostao font sa ikonama ---
#
# Ikone se tree-shake-uju u MaterialIcons-Regular.otf, a taj fajl se ne
# regenerise uvek kad se doda nova ikona: dve gradnje zaredom su zadrzale font
# od pre dodavanja, pa su se Icons.handshake i Icons.chat_bubble_outline
# iscrtavale kao nista. Ikone koje se vec koriste drugde rade, sto i navodi na
# pogresan trag. Detaljno u CLAUDE.md.

$font = "build\windows\x64\runner\Release\data\flutter_assets\fonts\MaterialIcons-Regular.otf"
if (Test-Path $font) {
    $fontVreme = (Get-Item $font).LastWriteTime
    if ($fontVreme -lt $pocetak) {
        Write-Host ""
        Write-Host "! Font sa ikonama je od $fontVreme, a gradnja je pocela $pocetak." -ForegroundColor Yellow
        Write-Host "  Ako neka novododata ikona izadje prazna, obrisi ga i gradi ponovo:" -ForegroundColor Yellow
        Write-Host "  Remove-Item '$font'" -ForegroundColor Yellow
    }
}

# --- [3/3] Rezultat ---

$exe = "build\windows\x64\runner\Release\chess_app.exe"
if (-not (Test-Path $exe)) {
    Fail "Nema $exe - gradnja je prijavila uspeh, ali izlaz ne postoji."
}

Write-Host "--- [3/3] GOTOVO: $exe ---" -ForegroundColor Green
if ($imaId -and $imaSecret) {
    Write-Host "  Google prijava je ukljucena u ovaj build." -ForegroundColor DarkGray
    Write-Host "  Da bi radila, isti client ID mora biti i u GOOGLE_CLIENT_IDS na serveru." -ForegroundColor DarkGray
}

if ($Run) {
    Write-Host "Pokrecem..." -ForegroundColor Yellow
    & $exe
}
