# Download the 6-piece Syzygy tablebases, resumably.
#
# 730 files, 149.2 GB. Stop it with Ctrl-C whenever; run it again and it picks
# up where it left off - a part-downloaded file is continued from its byte
# offset, a complete one is skipped after its size is checked.
#
# One connection at a time, on purpose. The other mirror (tablebase.sesse.net)
# threatens to nullroute anyone using download accelerators, and multiplying
# connections against a donated server to grab a bigger share of it is rude
# whichever mirror is serving. 7 MB/s on one connection was measured here, so
# roughly six and a half hours.
#
# ASCII only: Windows PowerShell 5.1 reads a .ps1 in the system ANSI codepage
# unless it carries a BOM, and a UTF-8 dash inside a string kills the parse.

param(
    [string]$Dest = 'D:\syzygy\6',
    [switch]$VerifyOnly
)

$ErrorActionPreference = 'Stop'
$Base = 'https://tablebase.lichess.ovh/tables/standard'

New-Item -ItemType Directory -Force -Path $Dest | Out-Null

# Expected sizes, so a truncated file is continued rather than trusted.
$sizesUrl = "$Base/bytes.tsv"
$sizesPath = Join-Path $Dest '_bytes.tsv'
if (-not (Test-Path $sizesPath)) {
    Write-Host "Preuzimam spisak velicina..."
    curl.exe -sS -L --max-time 120 -o $sizesPath $sizesUrl
}
$expected = @{}
foreach ($line in Get-Content $sizesPath) {
    $p = $line -split "`t"
    if ($p.Count -eq 2) { $expected[$p[1]] = [int64]$p[0] }
}

$plan = @()
foreach ($sub in @('6-wdl', '6-dtz')) {
    $indexPath = Join-Path $Dest "_index_$sub.txt"
    if (-not (Test-Path $indexPath)) {
        Write-Host "Preuzimam spisak fajlova za $sub..."
        $html = curl.exe -sS -L --max-time 120 "$Base/$sub/"
        ($html | Select-String -Pattern 'href="([^"]+\.rtb[wz])"' -AllMatches).Matches |
            ForEach-Object { $_.Groups[1].Value } | Set-Content $indexPath
    }
    foreach ($name in Get-Content $indexPath) {
        $plan += [pscustomobject]@{ Name = $name; Url = "$Base/$sub/$name" }
    }
}

$totalBytes = ($plan | ForEach-Object { $expected[$_.Name] } | Measure-Object -Sum).Sum
Write-Host ("Plan: {0} fajlova, {1:N1} GB, u {2}" -f $plan.Count, ($totalBytes / 1GB), $Dest)

$doneBytes = 0; $doneFiles = 0; $index = 0
foreach ($item in $plan) {
    $index++
    $target = Join-Path $Dest $item.Name
    $want = $expected[$item.Name]

    if ((Test-Path $target) -and $want -and ((Get-Item $target).Length -eq $want)) {
        $doneFiles++; $doneBytes += $want
        continue
    }
    if ($VerifyOnly) {
        $have = if (Test-Path $target) { (Get-Item $target).Length } else { 0 }
        Write-Host ("NEPOTPUN  {0}  {1}/{2}" -f $item.Name, $have, $want)
        continue
    }

    Write-Host ("[{0}/{1}] {2}  ({3:N0} MB)" -f $index, $plan.Count, $item.Name, ($want / 1MB))
    # -C - continues a partial file; --retry rides out a dropped connection.
    curl.exe -L -C - --retry 5 --retry-delay 5 --progress-bar -o $target $item.Url
    if ($LASTEXITCODE -ne 0) {
        throw "curl je vratio $LASTEXITCODE na $($item.Name). Pokrenite ponovo da nastavi."
    }
    $got = (Get-Item $target).Length
    if ($want -and $got -ne $want) {
        throw "$($item.Name): ocekivano $want bajtova, dobijeno $got. Obrisite fajl i pokrenite ponovo."
    }
    $doneFiles++; $doneBytes += $want
}

Write-Host ("`nGotovo: {0}/{1} fajlova, {2:N1} GB" -f $doneFiles, $plan.Count, ($doneBytes / 1GB))
Write-Host "Sledeci korak - provera kontrolnih suma:"
Write-Host "  curl.exe -sS -L -o $Dest\_sha256 $Base/sha256"
Write-Host "  (pa uporediti sa Get-FileHash -Algorithm SHA256)"
