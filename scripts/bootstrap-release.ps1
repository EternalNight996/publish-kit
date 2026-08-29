# bootstrap-release.ps1
# Standard release flow per publish-kit REFERENCE.md section A + K.
#
# Two release modes:
#   .
Recommended: PRERELEASE first, then PROMOTE
#   1. .\bootstrap-release.ps1 -BumpType patch -PreRelease beta     # v0.4.1-beta.1 -> npm next tag + GitHub Pre-release
#   2. validate, monitor, iterate .\bootstrap-release.ps1 -PreRelease beta -PreReleaseBump 1  # v0.4.1-beta.2
#   3. when stable: .\bootstrap-release.ps1 -BumpType patch -PromoteFromBeta 1  # promote v0.4.1-beta.1 -> v0.4.1 latest
#
# For exe projects see scripts/release-exe.ps1.

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][ValidateSet('patch','minor','major')][string]$BumpType,
    [string]$NpmRegistry = 'https://registry.npmjs.org/',
    [string]$CommitPrefix = 'chore: release',
    [string]$PreRelease = '',  # '' = production; 'beta' / 'rc' / 'alpha' = prerelease
    [int]$PreReleaseBump = 1,  # bump the prerelease counter (1 -> beta.1, 2 -> beta.2)
    [switch]$PromoteFromBeta,  # move a prerelease dist-tag to latest
    [string]$PromoteVersion = '',  # explicit version to promote; default = current next dist-tag
    [switch]$SkipGitTag,
    [switch]$SkipNpmPublish,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

$RepoRoot = git rev-parse --show-toplevel 2>$null
if (-not $RepoRoot) { $RepoRoot = (Get-Location).Path }
Set-Location $RepoRoot

function Step($msg) { Write-Host "`n=== $msg ===" -ForegroundColor Cyan }
function Info($msg) { Write-Host "  $msg" -ForegroundColor DarkGray }
function Warn($msg) { Write-Host "  ! $msg" -ForegroundColor Yellow }
function Fail($msg) { Write-Host "  X $msg" -ForegroundColor Red }

# Sanity checks
if (-not (Test-Path package.json)) { throw "no package.json" }
$pkg = Get-Content package.json -Raw | ConvertFrom-Json

# Sanity: gh CLI for GitHub Release
$hasGh = [bool](Get-Command gh -ErrorAction SilentlyContinue)
if (-not $hasGh) { Warn "gh CLI not found; GitHub Release step will be skipped" }

# Resolve pre-publish target version
Step "Resolve target version"
if ($PromoteFromBeta) {
    # Promote: don't bump version, just move dist-tag from next/beta -> latest
    if ($PromoteVersion) {
        $targetVersion = $PromoteVersion
    } else {
        # Read current next tag
        try {
            $nextRaw = npm view $pkg.name dist-tags.next --registry=$NpmRegistry 2>$null
            $targetVersion = $nextRaw.Trim()
            if (-not $targetVersion) {
                throw "no `next` dist-tag set; pass -PromoteVersion explicitly"
            }
        } catch {
            throw "failed to read next dist-tag: $_"
        }
    }
    Info "Promote mode: moving $targetVersion from dist-tag next -> latest"
} elseif ($PreRelease) {
    # Pre-release bump: bump prerelease counter on current package.json version
    # If current version is X.Y.Z, target is X.Y.Z-<pre>.<n>
    # If current is X.Y.Z-<pre>.<n>, target is X.Y.Z-<pre>.<n+1>
    $cur = $pkg.version
    if ($cur -match '^(.+)-([a-zA-Z]+)\.(\d+)$') {
        $base = $Matches[1]; $curPre = $Matches[2]; $curNum = [int]$Matches[3]
        if ($curPre -eq $PreRelease) {
            $newNum = $curNum + $PreReleaseBump
            $targetVersion = "$base-$PreRelease.$newNum"
        } else {
            $targetVersion = "$base-$PreRelease.$PreReleaseBump"
        }
    } else {
        # base release; bump via npm version and append -<pre>.<n>
        $bumped = npm version $BumpType --no-git-tag-version 2>&1 | Out-String
        if ($LASTEXITCODE -ne 0) { throw "npm version failed: $bumped" }
        $pkg = Get-Content package.json -Raw | ConvertFrom-Json
        $targetVersion = "$($pkg.version)-$PreRelease.$PreReleaseBump"
    }
    Info "Pre-release target: $targetVersion (dist-tag: $PreRelease)"
} else {
    # Production bump
    $bumped = npm version $BumpType --no-git-tag-version 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) { throw "npm version failed: $bumped" }
    $pkg = Get-Content package.json -Raw | ConvertFrom-Json
    $targetVersion = $pkg.version
    Info "Production target: $targetVersion (dist-tag: latest)"
}

# Set version in package.json (for pre-release or promote modes, npm version didn't write the full form)
if ($targetVersion -ne $pkg.version) {
    Info "Updating package.json version to $targetVersion"
    $pkg.version = $targetVersion
    $pkg | ConvertTo-Json -Depth 10 | Set-Content package.json -Encoding UTF8
    $pkg = Get-Content package.json -Raw | ConvertFrom-Json
}

# Show dry-run summary and exit
if ($DryRun) {
    Step "Dry-run summary"
    Info "target version: $targetVersion"
    Info "dist-tag: $(if ($PromoteFromBeta) { 'latest (promote)' } elseif ($PreRelease) { $PreRelease } else { 'latest' })"
    Info "git tag: v$targetVersion"
    Info "GitHub Release: $(if ($PreRelease -or $PromoteFromBeta) { 'pre-release' } else { 'production' })"
    exit 0
}

# Step 1: tests + build
Step "Test + build"
npm test
$buildCmd = $pkg.scripts.build
if ($buildCmd) { npm run build }

# Step 2: stage + commit
Step "Commit"
git add -A
git commit -m "$CommitPrefix v$targetVersion" --allow-empty

# Step 3: npm publish (with throwaway token)
if (-not $SkipNpmPublish) {
    Step "npm publish (dist-tag: $(if ($PromoteFromBeta) { 'latest' } elseif ($PreRelease) { $PreRelease } else { 'latest' }))"
    $tokenPath = ".npmrc.publish"
    if (Test-Path $tokenPath) {
        Info "using existing $tokenPath"
    } else {
        Info "enter npm auth token (will be written to .npmrc.publish and removed after):"
        $token = Read-Host -AsSecureString
        $plain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($token))
        "//registry.npmjs.org/:_authToken=$plain" | Set-Content -Path $tokenPath -Encoding Ascii
    }
    try {
        $publishTag = if ($PromoteFromBeta) { 'latest' } elseif ($PreRelease) { $PreRelease } else { 'latest' }
        npm publish --registry=$NpmRegistry --access public --tag $publishTag 2>&1 | Select-Object -First 20
    } finally {
        Remove-Item $tokenPath -ErrorAction SilentlyContinue
    }
}

# Step 4: git tag + push both remotes
if (-not $SkipGitTag) {
    Step "git tag v$targetVersion + push"
    git tag -a "v$targetVersion" -m "v$targetVersion"
    git show "v$targetVersion" --no-patch --format='%s'
    git push origin main --tags
    if (git remote get-url gitee >$null 2>&1) {
        git push gitee main --tags || Warn "gitee push failed (skip if remote not configured)"
    }
}

# Step 5: GitHub Release
if ($hasGh) {
    Step "GitHub Release v$targetVersion"
    $isPrerelease = ($PreRelease -or $PromoteFromBeta)
    $origin = git remote get-url origin
    if ($origin -match 'github\.com[:/](.+?)/(.+?)\.git$') {
    $Repo = ($origin -replace '.*github\.com[:/](.+?)/(.+?)\.git$', '$1/$2')
    $prereleaseFlag = if ($isPrerelease) { '--prerelease' } else { '--prerelease=false' }
    $releaseArgs = @('release','create',"v$targetVersion","--repo",$Repo,$prereleaseFlag,'--title',"v$targetVersion",'--generate-notes')
    # Allow scripts to attach to release via npm package `files` (no executables for bootstrap)
    & gh @releaseArgs
    if ($LASTEXITCODE -ne 0) { Warn "gh release create failed" }
    }
}

Step "Done"
Info "version: v$targetVersion"
Info "npm dist-tag: $(if ($PromoteFromBeta) { 'latest' } elseif ($PreRelease) { $PreRelease } else { 'latest' })"
Info "git tag pushed to: $(if (git remote get-url origin >$null) { 'origin' } else { 'NO ORIGIN' }), gitee"
Info "GitHub Release: $(if ($PreRelease -or $PromoteFromBeta) { 'pre-release' } else { 'production' })"

# Promote follow-up hint
if ($PreRelease -and -not $PromoteFromBeta) {
    Write-Host ""
    Write-Host "Next: when this prerelease is stable, promote it to latest:" -ForegroundColor Yellow
    Write-Host "  .\bootstrap-release.ps1 -BumpType patch -PromoteFromBeta -PromoteVersion v$targetVersion" -ForegroundColor Yellow
    Write-Host "  or simply:" -ForegroundColor Yellow
    Write-Host "  npm dist-tag add $pkg.name@$targetVersion latest --registry=$NpmRegistry" -ForegroundColor Yellow
}
