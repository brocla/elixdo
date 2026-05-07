$health = Invoke-RestMethod -Uri "https://elixdo.fly.dev/health"
$deployed_sha = $health.sha
Write-Host "Deployed SHA: $deployed_sha"
Write-Host ""
Write-Host "Recent commits:"
git log --oneline | Select-Object -First 5
