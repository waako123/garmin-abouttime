# fix-symlinks.ps1 v3 -- materialize Windows git symlink placeholders under resources-zho (build requirement)
# Why: git symlinks (mode 120000) are checked out by Git for Windows as plain text files holding the
#      target path. The zho build needs the real files/dirs.
# Approach: index-driven and idempotent -- enumerate tracked symlinks under resources-zho via
#      `git ls-files -s` (mode 120000), read each target from the blob, resolve nested placeholders,
#      then: file links -> real copies, dir links -> junctions. Finally silence locally
#      (.git/info/exclude + assume-unchanged) so git status stays clean and nothing pollutes commits.
# Usage: run from repo root:  pwsh scripts/fix-symlinks.ps1   (or powershell -File ...)
$ErrorActionPreference = 'Stop'
$root = (Get-Location).Path

# resolve a possibly-nested placeholder chain to a real path
function Resolve-Target([string]$startRel, [string]$fromDir) {
  $current = [System.IO.Path]::GetFullPath((Join-Path $fromDir ($startRel -replace '/', '\')))
  $depth = 0
  while ($depth -lt 6) {
    if ((Test-Path $current -PathType Leaf) -and ((Get-Content $current -Raw).Trim() -match '^\.\./')) {
      $inner = (Get-Content $current -Raw).Trim()
      $current = [System.IO.Path]::GetFullPath((Join-Path (Split-Path $current -Parent) ($inner -replace '/', '\')))
      $depth++
    } else {
      break
    }
  }
  return $current
}

$fixed = @()
$symlinkPaths = @()
$out = git -C $root ls-files -s 'resources-zho/'
foreach ($line in $out) {
  if ($line -match '^120000 ([0-9a-f]{40}) 0\t(.+)$') {
    $sha = $matches[1]
    $rel = $matches[2]
    $symlinkPaths += $rel
    $linkTarget = (git -C $root cat-file blob $sha).Trim()
    $p = Join-Path $root $rel
    $fromDir = Split-Path $p -Parent
    $real = Resolve-Target $linkTarget $fromDir
    if (Test-Path $p -PathType Container) {
      Write-Host "[keep] dir  $rel already a directory"
      continue
    }
    if (Test-Path $real -PathType Container) {
      if (Test-Path $p -PathType Leaf) { Remove-Item -Force $p }
      try {
        New-Item -ItemType Junction -Path $p -Target $real | Out-Null
        Write-Host "[ok] dir  $rel -> junction $real"
      } catch {
        Copy-Item -Recurse -Force $real $p
        Write-Host "[ok] dir  $rel -> copy $real"
      }
      $fixed += $rel
    }
    elseif (Test-Path $real -PathType Leaf) {
      if (Test-Path $p -PathType Leaf) { Remove-Item -Force $p }
      Copy-Item -Force $real $p
      Write-Host "[ok] file $rel <- $real"
      $fixed += $rel
    }
    else {
      Write-Host "[warn] $rel target not resolvable: $linkTarget"
    }
  }
}

if ($symlinkPaths.Count -gt 0) {
  $excludeFile = Join-Path $root '.git\info\exclude'
  $existing = @()
  if (Test-Path $excludeFile) { $existing = Get-Content $excludeFile }
  $excludeEntries = @()
  foreach ($rel in $symlinkPaths) {
    if (Test-Path (Join-Path $root $rel) -PathType Container) { $excludeEntries += "$rel/" }
  }
  $toAdd = $excludeEntries | Where-Object { $_ -notin $existing }
  if ($toAdd.Count -gt 0) {
    Add-Content -Path $excludeFile -Value $toAdd
    Write-Host "[info] added $($toAdd.Count) paths to .git/info/exclude (local only)"
  }
  git -C $root update-index --assume-unchanged @($symlinkPaths) 2>&1 | Out-Null
  Write-Host "[info] assume-unchanged set for $($symlinkPaths.Count) paths"
}
Write-Host "done."
