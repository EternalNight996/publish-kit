# bootstrap-release.ps1
# Standard release flow per publish-kit REFERENCE.md section A + K, and RELEASE-GRADES.md.
#
# GRADES (owner rule: a stable version needs explicit approval):
#   alpha   X.Y.Z-alpha.N  dist-tag alpha   internal preview, self-service
#   beta    X.Y.Z-beta.N   dist-tag beta    public test, self-service (DEFAULT when -Grade is omitted)
#   rc      X.Y.Z-rc.N     dist-tag rc      feature-frozen candidate, self-service
#   release X.Y.Z          dist-tag latest  needs approval: $env:PUBLISH_KIT_APPROVED=1 or -ApprovedBy <owner>
#   patch   X.Y.Z+1        dist-tag latest  needs approval, fixes only
#
# Examples:
#   .\bootstrap-release.ps1 -BumpType minor -Grade beta
#   .\bootstrap-release.ps1 -Grade beta -GradeBump 2
#   $env:PUBLISH_KIT_APPROVED=1; .\bootstrap-release.ps1 -BumpType minor -Grade release
#   .\bootstrap-release.ps1 -Grade release -PromoteFromBeta -PromoteVersion v0.4.1-rc.1 -ApprovedBy <owner>
#
# Windows PowerShell 5.1 blocks unsigned scripts: run with
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\bootstrap-release.ps1 -Grade beta -DryRun
#
# For exe projects see scripts/release-exe.ps1.

[CmdletBinding()]
param(
    [ValidateSet('patch','minor','major')][string]$BumpType = 'patch',
    [ValidateSet('alpha','beta','rc','release','patch','')][string]$Grade = '',
    [int]$GradeBump = 1,
    [string]$ApprovedBy = '',
    [string]$NpmRegistry = 'https://registry.npmjs.org/',
    [string]$CommitPrefix = 'chore: release',
    [string]$PreRelease = '',  # legacy alias: -PreRelease beta == -Grade beta
    [int]$PreReleaseBump = 1,  # legacy alias for -GradeBump
    [switch]$PromoteFromBeta,
    [string]$PromoteVersion = '',
    [switch]$SkipGitTag,
    [switch]$SkipNpmPublish,
    [switch]$DryRun
)

# 'Continue' keeps native stderr (npm notices, E404 probes) from aborting the run;
# every step that matters checks $LASTEXITCODE explicitly instead.
$ErrorActionPreference = 'Continue'

$RepoRoot = git rev-parse --show-toplevel 2>$null
if (-not $RepoRoot) { $RepoRoot = (Get-Location).Path }
Set-Location $RepoRoot

function Step($msg) { Write-Host "`n=== $msg ===" -ForegroundColor Cyan }
function Info($msg) { Write-Host "  $msg" -ForegroundColor DarkGray }
function Warn($msg) { Write-Host "  ! $msg" -ForegroundColor Yellow }
function Fail($msg) { Write-Host "  X $msg" -ForegroundColor Red }

# npm view that tolerates E404 / offline and only returns a real semver (or $null).
function Get-NpmVersion([string]$Spec, [string]$Field) {
    $out = (npm view $Spec $Field --registry=$NpmRegistry 2>&1 | Out-String)
    $match = ($out -split "`r?`n" | Where-Object { $_ -match '^\s*v?\d+\.\d+\.\d+' } | Select-Object -First 1)
    if (-not $match) { return $null }
    return ($match.Trim() -replace '^v', '')
}

if (-not (Test-Path package.json)) { throw "no package.json" }
$pkg = Get-Content package.json -Raw | ConvertFrom-Json
$PkgName = $pkg.name

$hasGh = [bool](Get-Command gh -ErrorAction SilentlyContinue)
if (-not $hasGh) { Warn "gh CLI not found; GitHub Release step will be skipped" }

# --- grade normalization: legacy -PreRelease <tag> == -Grade <tag> ---
if (-not $Grade -and $PreRelease) { $Grade = $PreRelease }
if ($PreRelease -and $PreReleaseBump -ne 1) { $GradeBump = $PreReleaseBump }

$defaulted = $false
if ($PromoteFromBeta) {
    $Grade = 'release'; $mode = 'promote'
} elseif (-not $Grade) {
    $Grade = 'beta'; $mode = 'test'; $defaulted = $true
} elseif ($Grade -in @('alpha','beta','rc')) {
    $mode = 'test'
} elseif ($Grade -in @('release','patch')) {
    $mode = 'stable'
} else {
    Fail "unknown grade: $Grade (allowed: alpha beta rc release patch)"; exit 2
}

function Test-Approval {
    if ($env:PUBLISH_KIT_APPROVED -eq '1') { return $true }
    if ($ApprovedBy) { return $true }
    return $false
}

if ($defaulted) {
    Warn "no -Grade given: publishing as beta (test build)."
    Warn "a stable release/patch needs the owner's approval: `$env:PUBLISH_KIT_APPROVED=1 or -ApprovedBy <owner>"
}

if ($mode -in @('stable','promote') -and -not (Test-Approval)) {
    Step "Approval gate"
    Fail "grade=$Grade requires the owner's approval before it can reach dist-tag 'latest'."
    Info "pass one of:"
    Info "  `$env:PUBLISH_KIT_APPROVED=1; .\bootstrap-release.ps1 -BumpType $BumpType -Grade $Grade"
    Info "  .\bootstrap-release.ps1 -BumpType $BumpType -Grade $Grade -ApprovedBy <owner>"
    Info "or publish a test build instead (no approval needed):"
    Info "  .\bootstrap-release.ps1 -BumpType $BumpType -Grade beta"
    exit 2
}
if ($mode -in @('stable','promote')) {
    Info "approval ok: $(if ($ApprovedBy) { "approved-by=$ApprovedBy" } else { 'PUBLISH_KIT_APPROVED=1' })"
}

Step "Resolve target version"
$origPkg = Get-Content package.json -Raw
$versionExists = $false

if ($mode -eq 'promote') {
    if ($PromoteVersion) {
        $targetVersion = $PromoteVersion
    } else {
        $targetVersion = Get-NpmVersion $PkgName 'dist-tags.rc'
        if (-not $targetVersion) { $targetVersion = Get-NpmVersion $PkgName 'dist-tags.beta' }
        if (-not $targetVersion) { throw "no rc/beta dist-tag set; pass -PromoteVersion vX.Y.Z-<tag>.N" }
    }
    $targetVersion = $targetVersion -replace '^v', ''
    $sourceVersion = $targetVersion
    # promote publishes the STABLE version, never the prerelease string: 0.6.0-beta.2 -> 0.6.0
    if ($targetVersion -match '^(\d+\.\d+\.\d+)-') { $targetVersion = $Matches[1] }
    if (Get-NpmVersion "$PkgName@$targetVersion" 'version') {
        $versionExists = $true
        Info "Promote: $sourceVersion -> $targetVersion already on npm; will move dist-tag latest instead of republishing"
    } else {
        Info "Promote: $sourceVersion -> stable $targetVersion (dist-tag latest)"
    }
} elseif ($mode -eq 'test') {
    $cur = $pkg.version
    if ($cur -match '^(.+)-([a-zA-Z]+)\.(\d+)$') {
        $base = $Matches[1]; $curPre = $Matches[2]; $curNum = [int]$Matches[3]
        $newNum = if ($curPre -eq $Grade) { $curNum + $GradeBump } else { $GradeBump }
        $targetVersion = "$base-$Grade.$newNum"
    } else {
        npm version $BumpType --no-git-tag-version > $null
        if ($LASTEXITCODE -ne 0) { throw "npm version failed" }
        $pkg = Get-Content package.json -Raw | ConvertFrom-Json
        $targetVersion = "$($pkg.version)-$Grade.$GradeBump"
    }
    Info "Grade $Grade target: $targetVersion (dist-tag: $Grade, GitHub Pre-release)"
} else {
    $effectiveBump = $BumpType
    if ($Grade -eq 'patch' -and $BumpType -ne 'patch') {
        Warn "grade=patch forces a patch bump (no new features allowed in a patch)"
        $effectiveBump = 'patch'
    }
    npm version $effectiveBump --no-git-tag-version > $null
    if ($LASTEXITCODE -ne 0) { throw "npm version failed" }
    $pkg = Get-Content package.json -Raw | ConvertFrom-Json
    $targetVersion = $pkg.version
    Info "Grade $Grade target: $targetVersion (dist-tag: latest, production release)"
}

$cur = $pkg.version
if ($targetVersion -ne $cur) {
    Info "Updating package.json version to $targetVersion"
    node -e "const fs=require('fs');const p=JSON.parse(fs.readFileSync('package.json','utf8'));p.version=process.argv[1];fs.writeFileSync('package.json',JSON.stringify(p,null,4)+'\n');" $targetVersion
    if ($LASTEXITCODE -ne 0) { throw "failed to write package.json version" }
    $pkg = Get-Content package.json -Raw | ConvertFrom-Json
}

$distTag = if ($mode -eq 'test') { $Grade } else { 'latest' }
$prereleaseFlag = if ($mode -eq 'test') { '--prerelease' } else { '--prerelease=false' }

if ($DryRun) {
    Step "Dry-run summary"
    Info "grade: $Grade ($mode)"
    Info "target version: $targetVersion"
    Info "dist-tag: $distTag"
    Info "git tag: v$targetVersion"
    Info "GitHub Release: $(if ($prereleaseFlag -eq '--prerelease') { 'pre-release' } else { 'production' })"
    Info "approval: $(if ($mode -eq 'test') { 'not required (test grade)' } elseif (Test-Approval) { 'ok' } else { 'MISSING -> would exit 2' })"
    # WriteAllText with a BOM-less encoder: Set-Content -Encoding utf8 emits a BOM on PS 5.1 and breaks JSON.parse
    [System.IO.File]::WriteAllText((Join-Path (Get-Location) 'package.json'), $origPkg, (New-Object System.Text.UTF8Encoding($false)))
    Info "(package.json restored: dry-run writes nothing)"
    exit 0
}

Step "Test + build"
npm test
if ($LASTEXITCODE -ne 0) { throw "npm test failed" }
if ($pkg.scripts.build) {
    npm run build
    if ($LASTEXITCODE -ne 0) { throw "npm run build failed" }
}

Step "Commit"
git add -A
git commit -m "$CommitPrefix v$targetVersion" --allow-empty > $null
if ($LASTEXITCODE -ne 0) { Warn "nothing to commit (or commit failed); continuing" }

if (-not $SkipNpmPublish) {
    Step "npm publish (dist-tag: $distTag)"
    $tokenPath = ".npmrc.publish"
    if (-not (Test-Path $tokenPath)) {
        Info "enter npm auth token (written to .npmrc.publish, removed after):"
        $token = Read-Host -AsSecureString
        $plain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($token))
        "//registry.npmjs.org/:_authToken=$plain" | Set-Content -Path $tokenPath -Encoding Ascii
    }
    try {
        if ($versionExists) {
            npm dist-tag add "$PkgName@$targetVersion" $distTag --registry=$NpmRegistry
        } else {
            npm publish --registry=$NpmRegistry --access public --tag $distTag
        }
        if ($LASTEXITCODE -ne 0) { throw "npm publish failed (2FA / network / version conflict?)" }
    } finally {
        Remove-Item $tokenPath -ErrorAction SilentlyContinue
    }
}

if (-not $SkipGitTag) {
    Step "git tag v$targetVersion + push"
    git tag -a "v$targetVersion" -m "v$targetVersion (grade: $Grade)"
    if ($LASTEXITCODE -ne 0) { throw "git tag failed (tag already exists?)" }
    git show "v$targetVersion" --no-patch --format='%s'
    git push origin main --tags
    if ($LASTEXITCODE -ne 0) { throw "git push origin failed" }
    $giteeUrl = (git remote get-url gitee 2>&1 | Out-String)
    if ($LASTEXITCODE -eq 0 -and $giteeUrl -and $giteeUrl -notmatch 'error|fatal') {
        git push gitee main --tags
        if ($LASTEXITCODE -ne 0) { Warn "gitee push failed (skip if remote not configured)" }
    }
}

if ($hasGh) {
    Step "GitHub Release v$targetVersion"
    $origin = (git remote get-url origin 2>&1 | Out-String).Trim()
    if ($origin -match 'github\.com[:/](.+?)/(.+?)\.git$') {
        $Repo = "$($Matches[1])/$($Matches[2])"
        & gh release create "v$targetVersion" --repo $Repo $prereleaseFlag --title "v$targetVersion" --generate-notes
        if ($LASTEXITCODE -ne 0) { Warn "gh release create failed" }
    }
}

Step "Done"
Info "grade: $Grade"
Info "version: v$targetVersion"
Info "npm dist-tag: $distTag"
Info "git tag pushed to: origin, gitee (if configured)"
Info "GitHub Release: $(if ($prereleaseFlag -eq '--prerelease') { 'pre-release' } else { 'production' })"

if ($mode -eq 'test') {
    Write-Host ""
    Write-Host "Next: when this $Grade is validated and the owner approves, promote it to latest:" -ForegroundColor Yellow
    Write-Host "  .\bootstrap-release.ps1 -Grade release -PromoteFromBeta -PromoteVersion v$targetVersion -ApprovedBy <owner>" -ForegroundColor Yellow
    Write-Host "  or simply: npm dist-tag add $PkgName@$targetVersion latest --registry=$NpmRegistry" -ForegroundColor Yellow
}
