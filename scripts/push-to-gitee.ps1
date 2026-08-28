# push-to-gitee.ps1
- One command to push the current main to the Gitee mirror.
- Use AFTER you have manually created the empty Gitee repo at
  https://gitee.com/eternalnight996/publish-kit (public, do NOT init with README).

[CmdletBinding()]
param(
    [string]$GiteeUser = 'eternalnight996',
    [string]$RepoName = 'publish-kit'
)

$ErrorActionPreference = 'Stop'
Set-Location (git rev-parse --show-toplevel)

$giteeRemote = "git@gitee.com:${GiteeUser}/${RepoName}.git"
Write-Host "Setting gitee remote to $giteeRemote" -ForegroundColor Cyan
git remote remove gitee 2>$null
git remote add gitee $giteeRemote

Write-Host "Pushing main + all tags..." -ForegroundColor Yellow
git push -u gitee main
# Tags only (existing + new since last push)
$existingTags = git ls-remote --tags gitee 2>$null | ForEach-Object { ($_ -split "\t")[1] -replace 'refs/tags/','' }
$localTags = git tag --list
$newTags = $localTags | Where-Object { $_ -notin $existingTags }
foreach ($t in $newTags) {
    Write-Host "  pushing tag $t" -ForegroundColor DarkGray
    git push gitee "refs/tags/$t"
}

Write-Host ""
---Gitee mirror sync complete---" -ForegroundColor Green
Write-Host "Repo: https://gitee.com/$GiteeUser/$RepoName"
Write-Host "Tip: also create a Release at https://gitee.com/$GiteeUser/$RepoName/releases/new for each tag"
