# release-exe.ps1
# Cross-platform build + checksum + GitHub Release upload for an exe project.
# Supports PyInstaller, Go, Rust single-binary, Electron/Tauri desktop apps.
#
# Usage examples:
#   .\release-exe.ps1 -ProjectType pyinstaller -AppName findany -Version 1.0.0
#   .\release-exe.ps1 -ProjectType go -AppName mytool -Version 1.0.0 -GoOS windows,linux,darwin -GoArch amd64,arm64
#   .\release-exe.ps1 -ProjectType rust -AppName mycli -Version 1.0.0 -RustTargets x86_64-pc-windows-msvc,x86_64-unknown-linux-gnu
#   .\release-exe.ps1 -ProjectType electron -AppName mydesk -Version 1.0.0
#
# Prerequisites:
#   - PowerShell 7+ recommended
#   - gh CLI installed and authenticated
#   - Project-specific toolchains (Python+PyInstaller, Go, Rust, Node) on PATH
#   - git remote origin points to a GitHub repo (for gh release create)

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][ValidateSet('pyinstaller','go','rust','electron')][string]$ProjectType,
    [Parameter(Mandatory=$true)][string]$AppName,
    [Parameter(Mandatory=$true)][string]$Version,
    [string]$DistDir = "./dist",
    [string[]]$GoOS = @('windows','linux','darwin'),
    [string[]]$GoArch = @('amd64','arm64'),
    [string[]]$RustTargets = @('x86_64-pc-windows-msvc','x86_64-unknown-linux-gnu','x86_64-apple-darwin','aarch64-apple-darwin'),
    [string[]]$ElectronTargets = @('win-x64','mac-x64','mac-arm64','linux-x64'),
    [string]$EntryPoint = "main.go",
    [string]$CommitPrefix = "chore: release",
    [switch]$SkipGitTag,
    [switch]$Draft
)

$ErrorActionPreference = 'Stop'

# Resolve repo root from script location
$RepoRoot = git rev-parse --show-toplevel 2>$null
if (-not $RepoRoot) { $RepoRoot = (Get-Location).Path }
Set-Location $RepoRoot

Write-Host "=== release-exe.ps1 ===" -ForegroundColor Cyan
Write-Host "  ProjectType: $ProjectType"
Write-Host "  AppName:     $AppName"
Write-Host "  Version:     $Version"
Write-Host "  DistDir:     $DistDir"

# Sanity checks
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    throw "gh CLI not found. Install: https://cli.github.com/"
}
$origin = git remote get-url origin 2>$null
if (-not $origin) { throw "no git remote 'origin' configured" }
if ($origin -notmatch 'github.com[:/](.+?)/(.+?)\.git$') {
    throw "origin does not point to GitHub: $origin"
}
$Repo = ($origin -replace '.*github.com[:/](.+?)/(.+?)\.git$', '$1/$2')
Write-Host "  Repo:        $Repo" -ForegroundColor DarkGray

# Clean dist
if (Test-Path $DistDir) { Remove-Item -Recurse -Force $DistDir }
New-Item -ItemType Directory -Force -Path $DistDir | Out-Null

# Build matrix
$artifacts = @()
switch ($ProjectType) {
    'pyinstaller' {
        if (-not (Get-Command python -ErrorAction SilentlyContinue)) { throw "python not on PATH" }
        if (-not (python -c "import PyInstaller" 2>$null)) { pip install pyinstaller | Out-Null }
        $entry = Read-Host "  PyInstaller entry script (e.g. app.py)"
        $artifact = "$AppName-$Version.exe"
        python -m PyInstaller --onefile --name $AppName --clean $entry
        Move-Item -Force "./dist/$AppName.exe" "$DistDir/$artifact"
        $artifacts += $artifact
    }
    'go' {
        if (-not (Get-Command go -ErrorAction SilentlyContinue)) { throw "go not on PATH" }
        foreach ($os in $GoOS) {
            foreach ($arch in $GoArch) {
                $ext = if ($os -eq 'windows') { '.exe' } else { '' }
                $out = "$AppName-$Version-$os-$arch$ext"
                Write-Host "  building $os/$arch..." -ForegroundColor Yellow
                $env:GOOS = $os; $env:GOARCH = $arch
                go build -ldflags="-s -w" -o "$DistDir/$out" $EntryPoint
                Remove-Item Env:GOOS -ErrorAction SilentlyContinue
                Remove-Item Env:GOARCH -ErrorAction SilentlyContinue
                $artifacts += $out
            }
        }
    }
    'rust' {
        if (-not (Get-Command cargo -ErrorAction SilentlyContinue)) { throw "cargo not on PATH" }
        foreach ($target in $RustTargets) {
            $ext = if ($target -like '*windows*') { '.exe' } else { '' }
            $out = "$AppName-$Version-$target$ext"
            Write-Host "  building target=$target..." -ForegroundColor Yellow
            rustup target add $target 2>$null | Out-Null
            cargo build --release --target $target
            Move-Item -Force "./target/$target/release/$AppName$ext" "$DistDir/$out"
            $artifacts += $out
        }
    }
    'electron' {
        if (-not (Get-Command npm -ErrorAction SilentlyContinue)) { throw "npm not on PATH" }
        foreach ($target in $ElectronTargets) {
            Write-Host "  building electron target=$target..." -ForegroundColor Yellow
            npx --yes electron-builder --$target --publish never
        }
        # electron-builder outputs to ./dist by default
        Get-ChildItem -Path ./dist -File | Where-Object { $_.Name -like "*.exe" -or $_.Name -like "*.dmg" -or $_.Name -like "*.AppImage" -or $_.Name -like "*.zip" -or $_.Name -like "*.deb" -or $_.Name -like "*.rpm" } | ForEach-Object {
            $newName = "$AppName-$Version-$($_.Name)"
            Move-Item -Force $_.FullName "$DistDir/$newName"
            $artifacts += $newName
        }
    }
}

if ($artifacts.Count -eq 0) {
    throw "no artifacts produced"
}
Write-Host "  built $($artifacts.Count) artifact(s):" -ForegroundColor Green
$artifacts | ForEach-Object { Write-Host "    - $_" -ForegroundColor DarkGray }

# Checksums
Write-Host "  generating sha256..." -ForegroundColor Yellow
$checksums = @()
foreach ($a in $artifacts) {
    $hash = (Get-FileHash -Path "$DistDir/$a" -Algorithm SHA256).Hash.ToLower()
    "$hash  $a" | Out-File -Append -FilePath "$DistDir/SHA256SUMS" -Encoding Ascii
    $checksums += "$hash  $a"
}
Get-Content "$DistDir/SHA256SUMS" | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }

# Commit + tag (unless skipped)
if (-not $SkipGitTag) {
    Write-Host "  commit + tag v$Version..." -ForegroundColor Yellow
    git add -A
    git commit -m "$CommitPrefix v$Version" --allow-empty
    git tag -a "v$Version" -m "v$Version"
    git show "v$Version" --no-patch --format='%s'
    git push origin main --tags
}

# GitHub Release
$isDraft = if ($Draft) { '--draft' } else { '--draft=false' }
Write-Host "  creating GitHub Release v$Version..." -ForegroundColor Yellow
$ghArgs = @('release','create',"v$Version","--repo",$Repo,$isDraft,'--title',"v$Version",'--generate-notes')
foreach ($a in $artifacts + 'SHA256SUMS') {
    $ghArgs += $DistDir + '/' + $a
}
& gh @ghArgs
if ($LASTEXITCODE -ne 0) { throw "gh release create failed" }

# Gitee Release (if remote configured)
$gitee = git remote get-url gitee 2>$null
if ($gitee) {
    Write-Host "  Gitee mirror: upload artifacts manually via gitee.com UI (no API write available)" -ForegroundColor DarkYellow
    Write-Host "    $gitee" -ForegroundColor DarkGray
}

Write-Host "=== v$Version published ===" -ForegroundColor Green
Write-Host "  GitHub Release: https://github.com/$Repo/releases/tag/v$Version" -ForegroundColor Cyan
