# Full mining pass: every endgame type, every PGN database, both results.
#
# Ordered so the cheap and certain work lands first. RookPawnVsRook and
# QueenVsRook are answered from the tablebases, so they finish fast and their
# output needs no second opinion; the types that fall back on the engine come
# after, and the rarest last.
#
# Safe to stop with Ctrl-C and start again: each type records the databases it
# has finished in <out>.done and skips them next time.
#
# ASCII only, deliberately. Windows PowerShell 5.1 reads a .ps1 in the system
# ANSI codepage unless it carries a BOM, so a UTF-8 em dash inside a string
# terminates the string and the file fails to parse. Plain hyphens survive
# every host.

$ErrorActionPreference = 'Stop'

$Miner   = 'D:\Projekti\chess_master\puzzles\endgame_miner.py'
$Syzygy  = 'D:\syzygy\3-4-5'
$OutDir  = 'D:\chess_base\_mining'
$LogFile = "$OutDir\mining.log"

# How many positions to collect per type. Split between databases in
# proportion to how many games each holds, so a 7484-game file contributes
# thirty times what a 250-game one does instead of the same handful.
$Target = 500

# RookPawnVsRook and QueenVsRook are finished - all 43 databases swept, 429 and
# 173 positions - and are left out on purpose. To extend them later, run the
# miner directly with a higher --target: it picks up games those types have
# never looked at rather than redoing the ones they have.
$Types = @(
    'PawnEnding',
    'BishopVsKnight',
    'RookBishopVsRook',
    'OppositeBishops',
    'DoubleBishopVsBishopKnight'
)

if (-not (Test-Path $Miner))  { throw "Nema skripte: $Miner" }
if (-not (Test-Path $Syzygy)) { throw "Nema Syzygy tablica: $Syzygy" }
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

# Refuse to start beside another run. Tee-Object holds the log open for append,
# so a second copy dies on the first line with a bare IOException about a file
# in use - which says nothing about the real problem. Worse, had the log not
# been locked, two runs would have written the same JSON files and the same
# .done markers at once and quietly corrupted both.
$running = @(Get-CimInstance Win32_Process -Filter "Name='python.exe'" -ErrorAction SilentlyContinue |
             Where-Object { $_.CommandLine -like '*endgame_miner*' })
if ($running.Count -gt 0) {
    $pids = ($running | ForEach-Object { $_.ProcessId }) -join ', '
    throw @"
Rudarenje vec radi (PID: $pids).
Dve kopije bi pisale u iste JSON fajlove i pokvarile ih.
Da zaustavite tekuce pokretanje:
  Get-CimInstance Win32_Process -Filter "Name='python.exe'" |
    Where-Object { `$_.CommandLine -like '*endgame_miner*' } |
    ForEach-Object { Stop-Process -Id `$_.ProcessId -Force }
  Get-Process stockfish* | Stop-Process -Force
"@
}

"=== POCETAK: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ===" |
    Tee-Object -FilePath $LogFile -Append

foreach ($type in $Types) {
    $started = Get-Date
    "" | Tee-Object -FilePath $LogFile -Append
    "########## $type : start $($started.ToString('HH:mm:ss')) ##########" |
        Tee-Object -FilePath $LogFile -Append

    # Out-String -Stream between the redirect and the tee, because 2>&1 turns
    # each stderr line into an ErrorRecord and Tee-Object then renders only the
    # first line of one, wrapped in PowerShell's own error formatting. A Python
    # traceback arrived as the single line "Traceback (most recent call last):"
    # and the exception itself was lost. Flattening to strings first keeps it.
    #
    # The exit code is checked explicitly: a failing python inside a pipeline
    # does not stop the loop on its own, so without this the run would carry on
    # to the next type and the summary would report a partial file as finished.
    python $Miner --type $type --mode any --syzygy $Syzygy --target $Target `
        --out "$OutDir\$type.json" 2>&1 |
        Out-String -Stream | Tee-Object -FilePath $LogFile -Append
    $code = $LASTEXITCODE

    if ($code -ne 0) {
        "########## $type PAO (izlazni kod $code) - prekidam ##########" |
            Tee-Object -FilePath $LogFile -Append
        throw "Rudarenje tipa $type nije uspelo (kod $code). Log: $LogFile"
    }

    $mins = [math]::Round(((Get-Date) - $started).TotalMinutes, 1)
    # No @() here. Windows PowerShell 5.1 hands the whole decoded array down the
    # pipeline as a single object, so @() wraps that one object and .Count comes
    # back 1 no matter how many positions were found. PowerShell 7 enumerates
    # and gives the right answer either way, which is what makes it easy to
    # miss: the summary read "ukupno 1 pozicija" for a file holding 429.
    $count = 0
    if (Test-Path "$OutDir\$type.json") {
        $count = (Get-Content "$OutDir\$type.json" -Raw | ConvertFrom-Json).Count
    }
    "########## $type gotovo za $mins min, ukupno $count pozicija ##########" |
        Tee-Object -FilePath $LogFile -Append
}

"" | Tee-Object -FilePath $LogFile -Append
"=== KRAJ: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ===" |
    Tee-Object -FilePath $LogFile -Append
