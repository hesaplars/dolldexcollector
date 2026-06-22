param(
  [string]$Message = ""
)

$ErrorActionPreference = "Stop"

function Run-Git {
  git @args
  if ($LASTEXITCODE -ne 0) {
    throw "Git command failed: git $args"
  }
}

Run-Git rev-parse --is-inside-work-tree | Out-Null

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
if ([string]::IsNullOrWhiteSpace($Message)) {
  $Message = "Backup $timestamp"
}

Run-Git add -A

$hasStagedChanges = $true
git diff --cached --quiet
if ($LASTEXITCODE -eq 0) {
  $hasStagedChanges = $false
} elseif ($LASTEXITCODE -ne 1) {
  throw "Could not check staged changes."
}

if ($hasStagedChanges) {
  Run-Git commit -m $Message
  Write-Host "Created backup commit: $Message"
} else {
  Write-Host "No file changes to back up."
}

$remote = git remote get-url origin 2>$null
if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($remote)) {
  $branch = git branch --show-current
  if ([string]::IsNullOrWhiteSpace($branch)) {
    throw "Could not determine the current branch."
  }

  Run-Git push -u origin $branch
  Write-Host "Pushed backup to origin/$branch"
} else {
  Write-Host "No GitHub remote named 'origin' is configured yet."
  Write-Host "After creating an empty GitHub repo, run:"
  Write-Host "  git remote add origin <repo-url>"
  Write-Host "  git push -u origin $(git branch --show-current)"
}
