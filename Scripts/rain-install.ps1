# Rain の最新バージョンをダウンロードするスクリプト
$releases = Invoke-RestMethod -Uri "https://api.github.com/repos/aws-cloudformation/rain/releases/latest"
$asset = $releases.assets | Where-Object { $_.name -like "*windows-amd64.zip" }
$downloadUrl = $asset.browser_download_url

# ダウンロード先ディレクトリを作成
$installDir = "$env:USERPROFILE\rain"
if (!(Test-Path $installDir)) {
    New-Item -ItemType Directory -Path $installDir | Out-Null
}

# ダウンロードして解凍
$zipPath = "$env:TEMP\rain.zip"
Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath
Expand-Archive -Path $zipPath -DestinationPath $installDir -Force
Remove-Item $zipPath

# 実際の rain.exe の場所を特定
$rainExePath = Get-ChildItem -Path $installDir -Recurse -Filter "rain.exe" | Select-Object -First 1 -ExpandProperty DirectoryName

# PATHに追加
$currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
if (!($currentPath -like "*$rainExePath*")) {
    [Environment]::SetEnvironmentVariable("Path", "$currentPath;$rainExePath", "User")
    Write-Host "Rain がインストールされ、PATH に追加されました。新しいターミナルを開いて 'rain --version' を実行してください。"
} else {
    Write-Host "Rain がインストールされました。'rain --version' を実行して確認してください。"
}