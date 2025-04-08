# アプリケーションアンインストールスクリプト
# 指定されたアプリケーションを自動的にアンインストールします
# PowerShell 7 で実行することを想定しています

# 管理者権限で実行されているか確認
function Test-Admin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Admin)) {
    Write-Error "このスクリプトは管理者権限で実行する必要があります。PowerShell を管理者として実行し、スクリプトを再度実行してください。"
    exit 1
}

# ログ用関数
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] [$Level] $Message"
}

# アンインストール対象のアプリケーション名（部分一致で検索されます）
$appsToUninstall = @(
    "Visual Studio Code",
    "TortoiseSVN",
    "TortoiseSVN 日本語パッチ",
    "Git for Windows",
    "TortoiseGit",
    "TortoiseGit 日本語パッチ"
)

# アンインストールログの保存場所
$logPath = "$env:USERPROFILE\Desktop\uninstall_log.txt"
"アンインストールログ - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Out-File -FilePath $logPath

# インストール済みのアプリケーションを取得
Write-Log "インストール済みアプリケーションを取得しています..."

# 32ビットアプリケーションと64ビットアプリケーションの両方を検索
$installedApps = @()
$installedApps += Get-ItemProperty "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
$installedApps += Get-ItemProperty "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue
$installedApps += Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue

# アプリケーションごとにアンインストール処理
foreach ($appName in $appsToUninstall) {
    Write-Log "アプリケーション「$appName」のアンインストールを開始します..." "PROCESS"
    
    # アプリケーション名に一致するエントリを検索
    $matchingApps = $installedApps | Where-Object { $_.DisplayName -match [regex]::Escape($appName) }
    
    if ($matchingApps.Count -eq 0) {
        Write-Log "アプリケーション「$appName」は見つかりませんでした。" "WARNING"
        "アプリケーション「$appName」は見つかりませんでした。" | Out-File -FilePath $logPath -Append
        continue
    }
    
    # 見つかったアプリケーションごとにアンインストール
    foreach ($app in $matchingApps) {
        $uninstallString = $app.UninstallString
        $displayName = $app.DisplayName
        
        Write-Log "アンインストール対象: $displayName" "INFO"
        "アンインストール対象: $displayName" | Out-File -FilePath $logPath -Append
        
        try {
            # UninstallStringの形式によって処理を分ける
            if ($uninstallString -match "msiexec") {
                # MSIアンインストール文字列から製品コードを抽出
                if ($uninstallString -match "{[A-Z0-9\-]+}") {
                    $productCode = $Matches[0]
                    Write-Log "MSIによるアンインストールを実行します: $productCode" "INFO"
                    
                    # msiexecによるサイレントアンインストール
                    $process = Start-Process -FilePath "msiexec.exe" -ArgumentList "/x $productCode /qn /norestart" -PassThru -Wait
                    if ($process.ExitCode -eq 0) {
                        Write-Log "$displayName のアンインストールに成功しました。" "SUCCESS"
                        "$displayName のアンインストールに成功しました。" | Out-File -FilePath $logPath -Append
                    }
                    else {
                        Write-Log "$displayName のアンインストールに失敗しました。終了コード: $($process.ExitCode)" "ERROR"
                        "$displayName のアンインストールに失敗しました。終了コード: $($process.ExitCode)" | Out-File -FilePath $logPath -Append
                    }
                }
                else {
                    # MSIアンインストール文字列を直接実行
                    $uninstallArgs = ($uninstallString -replace "msiexec.exe", "").Trim() + " /qn /norestart"
                    $process = Start-Process -FilePath "msiexec.exe" -ArgumentList $uninstallArgs -PassThru -Wait
                    if ($process.ExitCode -eq 0) {
                        Write-Log "$displayName のアンインストールに成功しました。" "SUCCESS"
                        "$displayName のアンインストールに成功しました。" | Out-File -FilePath $logPath -Append
                    }
                    else {
                        Write-Log "$displayName のアンインストールに失敗しました。終了コード: $($process.ExitCode)" "ERROR"
                        "$displayName のアンインストールに失敗しました。終了コード: $($process.ExitCode)" | Out-File -FilePath $logPath -Append
                    }
                }
            }
            else {
                # EXEインストーラーの場合
                # 多くのアンインストーラーはサイレントモードをサポートしているため、/S または /SILENT フラグを追加
                $uninstallCommand = $uninstallString
                
                # アンインストーラーによってはサイレントオプションが異なる
                # VS Codeの場合
                if ($displayName -match "Visual Studio Code") {
                    $uninstallCommand = $uninstallString + " /SILENT"
                }
                # TortoiseGitやTortoiseSVNの場合
                elseif ($displayName -match "Tortoise") {
                    $uninstallCommand = $uninstallString + " /S"
                }
                # Gitの場合
                elseif ($displayName -match "Git") {
                    $uninstallCommand = $uninstallString + " /SILENT"
                }
                # その他のアプリケーション（一般的なサイレントオプション）
                else {
                    $uninstallCommand = $uninstallString + " /S"
                }
                
                Write-Log "EXEによるアンインストールを実行します: $uninstallCommand" "INFO"
                
                # コマンドを実行するための準備
                if ($uninstallCommand -match '^"([^"]+)"(.*)$') {
                    $exePath = $Matches[1]
                    $exeArgs = $Matches[2].Trim()
                    $process = Start-Process -FilePath $exePath -ArgumentList $exeArgs -PassThru -Wait
                }
                elseif ($uninstallCommand -match '^([^\s]+)(.*)$') {
                    $exePath = $Matches[1]
                    $exeArgs = $Matches[2].Trim()
                    $process = Start-Process -FilePath $exePath -ArgumentList $exeArgs -PassThru -Wait
                }
                else {
                    # コマンドをそのまま実行
                    $process = Start-Process -FilePath "cmd.exe" -ArgumentList "/c $uninstallCommand" -PassThru -Wait
                }
                
                if ($process.ExitCode -eq 0) {
                    Write-Log "$displayName のアンインストールに成功しました。" "SUCCESS"
                    "$displayName のアンインストールに成功しました。" | Out-File -FilePath $logPath -Append
                }
                else {
                    Write-Log "$displayName のアンインストールに失敗しました。終了コード: $($process.ExitCode)" "ERROR"
                    "$displayName のアンインストールに失敗しました。終了コード: $($process.ExitCode)" | Out-File -FilePath $logPath -Append
                }
            }
        }
        catch {
            Write-Log "$displayName のアンインストール中にエラーが発生しました: $_" "ERROR"
            "$displayName のアンインストール中にエラーが発生しました: $_" | Out-File -FilePath $logPath -Append
        }
    }
}

Write-Log "すべてのアンインストール処理が完了しました。" "COMPLETE"
"すべてのアンインストール処理が完了しました。" | Out-File -FilePath $logPath -Append
Write-Log "ログファイルは $logPath に保存されました。" "INFO"

# スクリプト実行後にユーザーに通知
Write-Host "`n-------------------------------------" -ForegroundColor Green
Write-Host "アンインストール処理が完了しました。" -ForegroundColor Green
Write-Host "ログファイルは $logPath に保存されました。" -ForegroundColor Green
Write-Host "問題が発生した場合は、ログファイルを確認してください。" -ForegroundColor Yellow
Write-Host "Enter キーを押して終了します..." -ForegroundColor Cyan
Read-Host