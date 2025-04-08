pip install uv --user

$currentUserPath = [Environment]::GetEnvironmentVariable("Path", "User")
[Environment]::SetEnvironmentVariable("Path", $currentUserPath + ";C:\Users\junki.akiyama\AppData\Roaming\Python\Python313\Scripts", "User")

$claudeFolder = Join-Path $env:APPDATA "Claude"
Copy-Item -Path "claude\claude_desktop_config.json" -Destination $claudeFolder -Force

