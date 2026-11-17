# Copy the working tree into the WoW Forever client's AddOns folder.
#
#   powershell -File tools/sync_forever.ps1 [-Flavor C:\...\_classic_beta_] [-Interface 16001]
#
# One codebase serves both clients; the only Forever-specific difference is the .toc
# interface number, which is rewritten on the copy. Without that rewrite the Forever client
# reads the retail number and marks the addon out of date. The repo .toc is never touched.
#
# The interface number is derived from the Forever client's own build (1.60.1 -> 16001), so
# a client patch doesn't silently leave the copy flagged out of date. Pass -Interface to
# override. Files excluded from a release (.pkgmeta "ignore") are excluded here too.

param(
    [string]$Flavor = "C:\Blizzard\World of Warcraft\_classic_beta_",
    [string]$Interface
)

$ErrorActionPreference = "Stop"
$repo = Split-Path -Parent $PSScriptRoot
$dest = Join-Path $Flavor "Interface\AddOns\JustQuest"

if (-not (Test-Path (Join-Path $Flavor "Interface\AddOns"))) {
    throw "No AddOns folder under $Flavor - pass -Flavor <client folder>."
}

if (-not $Interface) {
    # .flavor.info names this folder's product; the install root's .build.info has its version.
    $product = (Get-Content (Join-Path $Flavor ".flavor.info") | Select-Object -Last 1).Trim()
    $row = Get-Content (Join-Path (Split-Path $Flavor -Parent) ".build.info") |
        Where-Object { $_ -match "\|$([regex]::Escape($product))$" } | Select-Object -First 1
    if (-not $row -or $row -notmatch "\|(\d+)\.(\d+)\.(\d+)\.\d+\|") {
        throw "Couldn't read the client version for '$product' - pass -Interface."
    }
    $Interface = [string]([int]$Matches[1] * 10000 + [int]$Matches[2] * 100 + [int]$Matches[3])
}

# Same exclusions as a release build, read from .pkgmeta so there is one list.
$ignore = @(Get-Content (Join-Path $repo ".pkgmeta") |
    Where-Object { $_ -match '^\s+-\s+(.+)$' } | ForEach-Object { $Matches[1].Trim('"') })
$xd = $ignore | Where-Object { Test-Path (Join-Path $repo $_) -PathType Container }
$xf = $ignore | Where-Object { -not (Test-Path (Join-Path $repo $_) -PathType Container) }

# /MIR so files deleted in the repo don't linger in the copy. Robocopy exit codes below 8
# are success.
robocopy $repo $dest /MIR /NFL /NDL /NJH /NP /XD @xd /XF @xf | Out-Null
if ($LASTEXITCODE -ge 8) { throw "robocopy failed ($LASTEXITCODE)" }

# /MIR never purges a file it was told to exclude, so anything copied before it joined the
# ignore list would stay in the copy forever. Enforce the list on the destination too.
foreach ($x in $ignore) {
    Remove-Item (Join-Path $dest $x) -Recurse -Force -ErrorAction SilentlyContinue
}

$toc = Join-Path $dest "JustQuest.toc"
$text = (Get-Content $toc -Raw) -replace '(?m)^## Interface:.*$', "## Interface: $Interface"
[IO.File]::WriteAllText($toc, $text)

Write-Host "Synced to $dest (Interface $Interface)"
exit 0  # robocopy's "files copied" code (1) would otherwise become this script's status
