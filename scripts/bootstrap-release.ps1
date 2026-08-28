# bootstrap-release.ps1
# Standard npm release flow per publish-kit REFERENCE.md section A.
# Usage: .\bootstrap-release.ps1 -BumpType patch|minor|major
#
# For exe projects (PyInstaller / Go single-binary / Rust single-binary / Electron):
# see scripts/release-exe.ps1 -ProjectType pyinstaller|go|rust|electron -AppName <name> -Version <v>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][ValidateSet('patch','minor','major')][string]$BumpType,
    [string]$NpmRegistry = 'https://registry.npmjs.org/',
    [string]$CommitMsgPrefix = 'chore: release'
)

$ErrorActionPreference = 'Stop'
Set-Location (Split-Path -Parent $PSCommandPath) | Out-Null

Write-Host "=== bootstrap-release.ps1 ($BumpType) ===" -ForegroundColor Cyan

# Step 1: bump version
Write-Host "[1/6] bump version ($BumpType)" -ForegroundColor Yellow
$pkgJson = Get-Content package.json -Raw | ConvertFrom-Json
$current = $pkgJson.version
npm version $BumpType --no-git-tag-version | Out-Null
$newVersion = (Get-Content package.json -Raw | ConvertFrom-Json).version
Write-Host "    $current -> $newVersion"

# Step 2: tests + build
Write-Host "[2/6] test + build" -ForegroundColor Yellow
npm test
if (Get-Command npm run build -ErrorAction SilentlyContinue) { npm run build }

# Step 3: stage + commit
Write-Host "[3/6] commit" -ForegroundColor Yellow
git add -A
git commit -m "$CommitMsgPrefix v$newVersion" --allow-empty

# Step 4: npm publish (with throwaway token)
Write-Host "[4/6] npm publish --registry=$NpmRegistry" -ForegroundColor Yellow
$tokenPath = ".npmrc.publish"
if (Test-Path $tokenPath) {
    Write-Host "    using existing $tokenPath" -ForegroundColor DarkGray
} else {
    Write-Host "    enter npm auth token (will be written to .npmrc.publish and removed after):" -ForegroundColor DarkGray
    $token = Read-Host -AsSecureString
    $plain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($token))
    ".npmrc.publish" | Set-Content -Value "//registry.npmjs.org/:_authToken=$plain" -Encoding Ascii
}
try {
    npm publish --registry=$NpmRegistry --access public
} finally {
    Remove-Item $tokenPath -ErrorAction SilentlyContinue
}

# Step 5: git tag + push both remotes
Write-Host "[5/6] git tag v$newVersion + push" -ForegroundColor Yellow
git tag -a "v$newVersion" -m "v$newVersion"
$tagSubject = git show "v$newVersion" --no-patch --format='%s'
Write-Host "    verified tag subject: $tagSubject"
git push origin main --tags
git push gitee main --tags 2>$null
if ($LASTEXITCODE -ne 0) { Write-Host "    WARN: gitee push failed (skip if remote not configured)" -ForegroundColor DarkYellow }

# Step 6: GitHub RP (Description + Topics via API)
Write-Host "[6/6] GitHub RP fields (description + topics)" -ForegroundColor Yellow
$repo = (git remote get-url origin) -replace '.*github.com[:/](.+?)/(.+?)\.git$', '$1/$2'
if ($repo -match '/') {
    $description = Read-Host "    repository description"
    $topicsRaw = Read-Host "    topics (comma-separated, e.g. dsh-plugin,publishing)"
    $topicsArr = ($topicsRaw -split ',').Trim() | Where-Object { $_ }
    $topicsJson = @{ names = $topicsArr } | ConvertTo-Json -Compress
    $tmp = New-TemporaryFile
    Set-Content -Path $tmp -Value $topicsJson -Encoding UTF8
    gh api -X PATCH "repos/$repo" -f description="$description" | Out-Null
    gh api -X PUT "repos/$repo/topics" --input $tmp.FullName | Out-Null
    Remove-Item $tmp -ErrorAction SilentlyContinue
    Write-Host "    RP updated"
} else {
    Write-Host "    WARN: cannot infer GitHub repo from origin remote" -ForegroundColor DarkYellow
}

Write-Host "=== release v$newVersion complete ===" -ForegroundColor Green
