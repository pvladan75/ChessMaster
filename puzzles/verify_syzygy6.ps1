# Verify the downloaded 6-piece Syzygy tablebases against the mirror's SHA-256
# list. 730 files, 149.2 GB - reading all of it takes as long as the disk takes,
# so this is resumable too: every file that matches is appended to _verified.txt
# and skipped on the next run. Ctrl-C whenever.
#
# Nothing is deleted here. A file whose hash is wrong is reported and left in
# place; deleting it and re-running get_syzygy6.ps1 is a decision for a human.
#
# ASCII only, same reason as get_syzygy6.ps1: Windows PowerShell 5.1 reads a
# .ps1 in the system ANSI codepage unless it carries a BOM.

param(
    [string]$Dest = 'D:\syzygy\6',
    [switch]$Recheck
)

$ErrorActionPreference = 'Stop'
$Base = 'https://tablebase.lichess.ovh/tables/standard'

if (-not (Test-Path $Dest)) { throw "Nema foldera $Dest." }

$sumPath = Join-Path $Dest '_sha256'
if (-not (Test-Path $sumPath)) {
    Write-Host "Preuzimam kontrolne sume..."
    curl.exe -sS -L --max-time 120 -o $sumPath "$Base/sha256"
    if ($LASTEXITCODE -ne 0) { throw "curl je vratio $LASTEXITCODE na sha256." }
}

# "<hash>  <ime>", golo ime fajla, bez foldera.
$expected = @{}
foreach ($line in Get-Content $sumPath) {
    $p = $line -split '\s+', 2
    if ($p.Count -eq 2 -and $p[0].Length -eq 64) { $expected[$p[1].Trim()] = $p[0].ToLower() }
}
if ($expected.Count -eq 0) { throw "Neocekivan format u $sumPath - nijedna suma nije procitana." }

# Ocekivane velicine: promasaj u velicini je odsecen fajl, i to se vidi odmah,
# bez citanja 200 MB.
$sizesPath = Join-Path $Dest '_bytes.tsv'
if (-not (Test-Path $sizesPath)) { throw "Nema $sizesPath - pokrenite prvo get_syzygy6.ps1." }
$sizes = @{}
foreach ($line in Get-Content $sizesPath) {
    $p = $line -split "`t"
    if ($p.Count -eq 2) { $sizes[$p[1]] = [int64]$p[0] }
}

$plan = @()
foreach ($sub in @('6-wdl', '6-dtz')) {
    $indexPath = Join-Path $Dest "_index_$sub.txt"
    if (-not (Test-Path $indexPath)) { throw "Nema $indexPath - pokrenite prvo get_syzygy6.ps1." }
    $plan += Get-Content $indexPath | Where-Object { $_ -ne '' }
}

# Sve mora da postoji i sve mora da ima svoju sumu, pre nego sto pocne citanje.
foreach ($name in $plan) {
    if (-not $expected.ContainsKey($name)) { throw "$name nije u spisku kontrolnih suma." }
    if (-not (Test-Path (Join-Path $Dest $name))) { throw "$name nedostaje u $Dest." }
}

$logPath = Join-Path $Dest '_verified.txt'
$done = @{}
if ($Recheck) {
    if (Test-Path $logPath) { Remove-Item $logPath }
} elseif (Test-Path $logPath) {
    foreach ($n in Get-Content $logPath) { if ($n) { $done[$n] = $true } }
}

$todo = $plan | Where-Object { -not $done.ContainsKey($_) }
$todoBytes = ($todo | ForEach-Object { $sizes[$_] } | Measure-Object -Sum).Sum
Write-Host ("Provera: {0} fajlova, {1:N1} GB (vec provereno: {2})" -f $todo.Count, ($todoBytes / 1GB), $done.Count)

$bad = @()
$i = 0
$readBytes = 0
$sw = [Diagnostics.Stopwatch]::StartNew()

foreach ($name in $todo) {
    $i++
    $target = Join-Path $Dest $name
    $want = $sizes[$name]
    $got = (Get-Item $target).Length
    if ($want -and $got -ne $want) {
        Write-Host ("ODSECEN   {0}  {1}/{2} bajtova" -f $name, $got, $want)
        $bad += $name
        continue
    }

    $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $target).Hash.ToLower()
    $readBytes += $got

    if ($hash -ne $expected[$name]) {
        Write-Host ("POGRESNA SUMA  {0}" -f $name)
        Write-Host ("  ocekivano {0}" -f $expected[$name])
        Write-Host ("  dobijeno  {0}" -f $hash)
        $bad += $name
        continue
    }

    Add-Content -LiteralPath $logPath -Value $name
    $mbs = if ($sw.Elapsed.TotalSeconds -gt 0) { ($readBytes / 1MB) / $sw.Elapsed.TotalSeconds } else { 0 }
    $left = if ($mbs -gt 0) { [TimeSpan]::FromSeconds((($todoBytes - $readBytes) / 1MB) / $mbs) } else { [TimeSpan]::Zero }
    Write-Host ("[{0}/{1}] OK  {2}  ({3:N0} MB/s, jos ~{4:hh\:mm})" -f $i, $todo.Count, $name, $mbs, $left)
}

if ($bad.Count -gt 0) {
    Write-Host ""
    Write-Host ("NEISPRAVNIH: {0}" -f $bad.Count)
    $bad | ForEach-Object { Write-Host "  $_" }
    Write-Host "Obrisite ih i pokrenite get_syzygy6.ps1 ponovo - skinuce samo njih."
    exit 1
}

Write-Host ""
Write-Host ("Gotovo: {0}/{1} fajlova provereno, sve sume se slazu." -f $plan.Count, $plan.Count)
