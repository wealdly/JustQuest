# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2025-2026 wealdly
# Build script for JustQuest distribution package
# Run: .\build.ps1

$addonName = "JustQuest"
$version = (Get-Content "JustQuest.toc" | Select-String "## Version:" | ForEach-Object { $_ -replace "## Version:\s*", "" }).Trim()
if (-not $version) { $version = "dev" }

# Output to a "dist" folder inside the addon
$distDir = Join-Path $PSScriptRoot "dist"
$tempDir = Join-Path $env:TEMP "$addonName-build"
$outputDir = Join-Path $tempDir $addonName
$zipFile = Join-Path $distDir "$addonName-$version.zip"

# Clean previous build
if (Test-Path $tempDir) { Remove-Item $tempDir -Recurse -Force }
if (Test-Path $zipFile) { Remove-Item $zipFile -Force }

# Create directories
New-Item -ItemType Directory -Path $distDir -Force | Out-Null
New-Item -ItemType Directory -Path $outputDir -Force | Out-Null

Write-Host "Building $addonName v$version..." -ForegroundColor Cyan

# Core addon files (explicit list matching .toc load order)
$coreFiles = @(
    "JustQuest.toc",
    "Libs\LibStub\LibStub.lua",
    "Libs\AceDB-3.0\AceDB-3.0.xml",
    "Libs\AceConfig-3.0\AceConfig-3.0.xml",
    "Libs\AceDBOptions-3.0\AceDBOptions-3.0.xml",
    "Libs\AceTimer-3.0\AceTimer-3.0.xml",
    "Core\Constants.lua",
    "Core\Core.lua",
    "Core\Config.lua",
    "Services\Services.lua",
    "Services\GameData.lua",
    "Database\BlockedContent.lua",
    "Database\ContainerDB.lua",
    "Engines\SafetyEngine.lua",
    "Engines\RewardEngine.lua",
    "Engines\QuestEngine.lua",
    "Engines\GossipEngine.lua",
    "Engines\ContainerEngine.lua",
    "Interface\ConfigUI.lua",
    "Interface\LFGQuickStart.lua"
)

# Copy core files
foreach ($file in $coreFiles) {
    $src = Join-Path $PSScriptRoot $file
    $dst = Join-Path $outputDir $file
    $dstDir = Split-Path $dst -Parent
    if (-not (Test-Path $dstDir)) { New-Item -ItemType Directory -Path $dstDir -Force | Out-Null }
    Copy-Item $src $dst -Force
}

# Copy Libs subdirectories (XML files reference siblings)
$libDirs = @(
    "Libs\AceConfig-3.0",
    "Libs\AceDB-3.0",
    "Libs\AceDBOptions-3.0",
    "Libs\AceTimer-3.0",
    "Libs\LibStub"
)
foreach ($dir in $libDirs) {
    $src = Join-Path $PSScriptRoot $dir
    $dst = Join-Path $outputDir $dir
    if (Test-Path $src) {
        Copy-Item $src $dst -Recurse -Force
    }
}

# Create zip
Write-Host "Creating $zipFile..." -ForegroundColor Yellow
Compress-Archive -Path $outputDir -DestinationPath $zipFile -Force

# Clean up temp
Remove-Item $tempDir -Recurse -Force

$size = [math]::Round((Get-Item $zipFile).Length / 1KB, 1)
Write-Host "Done! $zipFile ($size KB)" -ForegroundColor Green
