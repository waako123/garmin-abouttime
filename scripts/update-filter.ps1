# update-filter.ps1 -- recompute the five font filters from resources-zho/strings.xml
# Principle: Connect IQ subsets fonts at compile time using the <font filter="..."> attribute in
#            resources.xml. Any new character introduced by the strings must be in the filter,
#            otherwise it renders as tofu. This is the Windows equivalent of the upstream bash
#            filter.sh (which only scans strings.xml).
# Usage: run from repo root:  pwsh scripts/update-filter.ps1   (or powershell -File ...)
$ErrorActionPreference = 'Stop'
$root = (Get-Location).Path
$stringsPath = Join-Path $root 'resources-zho/strings.xml'
if (-not (Test-Path $stringsPath)) {
  Write-Error "resources-zho/strings.xml not found -- run from the repo root"
}

$raw = Get-Content $stringsPath -Raw
# strip XML tags, $1$/$2$ placeholders and whitespace
$text = $raw -replace '<[^>]*>', '' -replace '\$.\$', '' -replace '\s', ''
$chars = @()
foreach ($ch in $text.ToCharArray()) { $chars += $ch }
# base set matches upstream filter.sh (digits / percent / colon / dot / km / space;
# space is used by the date string, colon by the digital time)
$base = "0123456789%.:km "
$filter = (($base.ToCharArray() + $chars) | Sort-Object -Unique) -join ''

$dirs = @('resource','small','large','extralarge','fr920xt')
foreach ($d in $dirs) {
  $p = Join-Path $root "resources-zho/$d/resources.xml"
  if (Test-Path $p) {
    $xml = Get-Content $p -Raw
    $new = [regex]::Replace($xml, 'filter="[^"]*"', "filter=`"$filter`"")
    if ($new -ne $xml) {
      Set-Content -Path $p -Value $new -NoNewline -Encoding utf8
      Write-Host "[ok] $d"
    } else {
      Write-Host "[warn] $d no filter attribute found"
    }
  } else {
    Write-Host "[skip] $d/resources.xml missing"
  }
}
Write-Host "new filter: $filter"
