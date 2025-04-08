# YAMLファイルからアプリケーションリストを読み込み、インストールするPowerShellスクリプト

# 必要なモジュールの確認とインストール
function Ensure-Module {
    param (
        [string]$ModuleName
    )
    
    if (-not (Get-Module -ListAvailable -Name $ModuleName)) {
        Write-Host "$ModuleName モジュールがインストールされていません。インストールします..." -ForegroundColor Yellow
        try {
            Install-Module -Name $ModuleName -Scope CurrentUser -Force -ErrorAction Stop
            Write-Host "$ModuleName モジュールのインストールが完了しました。" -ForegroundColor Green
        }
        catch {
            Write-Error "モジュールのインストールに失敗しました: $_"
            exit 1
        }
    }
}

# PowerShell-YAMLモジュールが必要
Ensure-Module -ModuleName "powershell-yaml"

# YAMLファイルのパス
$yamlPath = Join-Path $PSScriptRoot "packages.yml"

# YAMLファイルが存在するか確認
if (-not (Test-Path $yamlPath)) {
    # サンプルYAMLの内容
    $sampleYaml = @"
packages:
  - id: Anthropic.Claude
    scope: User
    architecture: x64
  - id: AntibodySoftware.WizTree
    scope: User
    architecture: x64
  - id: Anysphere.Cursor
    scope: User
    architecture: x64
  - id: CoreyButler.NVMforWindows
    scope: User
    architecture: x64
  - id: DeepL.DeepL
    scope: User
    architecture: x64
  - id: DimitriVanHeesch.Doxygen
    scope: User
    architecture: x64
  - id: DevToys-app.DevToys
    scope: User
    architecture: x64
  - id: gerardog.gsudo
    scope: User
    architecture: x64
  - id: Git.Git
    scope: User
    architecture: x64
  - id: Microsoft.PowerShell
    scope: User
    architecture: x64
  - id: Microsoft.PowerToys
    scope: User
    architecture: x64
  - id: Microsoft.WindowsTerminal
    scope: User
    architecture: x64
  - id: OpenJS.NodeJS
    scope: User
    architecture: x64
  - id: Python.Python.3.13
    scope: User
    architecture: x64
  - id: JetBrains.PyCharm.Community
    scope: User
    architecture: x64
  - id: voidtools.Everything
    scope: User
    architecture: x64
  - id: WinMerge.WinMerge
    scope: User
    architecture: x64
  - id: Zoom.Zoom
    scope: User
    architecture: x64
"@

    # YAMLファイルが存在しない場合、サンプルファイルを作成
    Write-Host "YAMLファイルが見つかりません。サンプルファイルを作成します: $yamlPath" -ForegroundColor Yellow
    $sampleYaml | Out-File -FilePath $yamlPath -Encoding utf8
    Write-Host "サンプルYAMLファイルを作成しました。必要に応じて編集してから再実行してください。" -ForegroundColor Green
    exit 0
}

# YAMLファイルの読み込み
try {
    $yamlContent = Get-Content -Path $yamlPath -Raw
    Import-Module powershell-yaml
    $packagesConfig = ConvertFrom-Yaml -Yaml $yamlContent -ErrorAction Stop
    $packages = $packagesConfig.packages
    
    if (-not $packages) {
        Write-Error "YAMLファイルから packages の配列が読み込めませんでした。ファイル形式を確認してください。"
        exit 1
    }
    
    Write-Host "YAMLファイルから $($packages.Count) 個のパッケージ情報を読み込みました。" -ForegroundColor Green
}
catch {
    Write-Error "YAMLファイルの読み込みまたは解析中にエラーが発生しました: $_"
    exit 1
}

# wingetが利用可能か確認
try {
    $wingetVersion = winget --version
    Write-Host "wingetが見つかりました: $wingetVersion" -ForegroundColor Green
}
catch {
    Write-Error "wingetが見つかりません。Windows App Installerがインストールされているか確認してください。"
    Write-Host "Microsoft Storeから 'App Installer' をインストールするか、Windows 更新プログラムを適用してください。" -ForegroundColor Yellow
    exit 1
}

# インストール結果のログ
$successCount = 0
$failCount = 0
$skippedCount = 0
$logPath = Join-Path $PSScriptRoot "winget_install_log_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
"# wingetパッケージインストール ログ - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Out-File -FilePath $logPath

# 各パッケージをインストール
foreach ($package in $packages) {
    # idは必須
    if (-not $package.id) {
        Write-Host "警告: IDが指定されていないパッケージをスキップします" -ForegroundColor Yellow
        "スキップ: IDが指定されていないパッケージ" | Out-File -FilePath $logPath -Append
        $skippedCount++
        continue
    }
    
    $id = $package.id
    
    # コマンドの構築
    $command = "winget install -e $id"
    
    # オプションパラメータの追加（存在する場合のみ）
    if ($package.scope) {
        $command += " --scope $($package.scope)"
    }
    
    if ($package.architecture) {
        $command += " --architecture $($package.architecture)"
    }
    
    # オプショナルパラメータの追加
    if ($package.source) {
        $command += " --source $($package.source)"
    }
    
    if ($package.version) {
        $command += " --version $($package.version)"
    }
    
    if ($package.location) {
        $command += " --location `"$($package.location)`""
    }
    
    if ($package.override) {
        $command += " --override `"$($package.override)`""
    }
    
    # インストールコマンド実行
    try {
        Write-Host "インストール中: $id..." -ForegroundColor Cyan
        "インストール開始: $id - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Out-File -FilePath $logPath -Append
        Write-Host "実行コマンド: $command" -ForegroundColor DarkGray
        
        # コマンド実行
        $output = Invoke-Expression -Command "$command" -ErrorVariable installError 2>&1
        
        # 結果の確認
        if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq -1978335189) {  # 0: 成功, -1978335189: 既にインストール済み
            if ($LASTEXITCODE -eq -1978335189) {
                Write-Host "$id は既にインストールされています。" -ForegroundColor Yellow
                "$id は既にインストールされています。" | Out-File -FilePath $logPath -Append
                $skippedCount++
            } else {
                Write-Host "$id のインストールが完了しました。" -ForegroundColor Green
                "$id のインストールが成功しました。" | Out-File -FilePath $logPath -Append
                $successCount++
            }
        } else {
            Write-Host "$id のインストール中にエラーが発生しました。終了コード: $LASTEXITCODE" -ForegroundColor Red
            "$id のインストールに失敗しました。終了コード: $LASTEXITCODE" | Out-File -FilePath $logPath -Append
            $output | Out-File -FilePath $logPath -Append
            $failCount++
        }
    }
    catch {
        Write-Host "$id のインストール中に例外が発生しました: $_" -ForegroundColor Red
        "$id のインストール中に例外が発生しました: $_" | Out-File -FilePath $logPath -Append
        if ($installError) {
            $installError | Out-File -FilePath $logPath -Append
        }
        $failCount++
    }
    
    # 区切り線
    "-" * 50 | Out-File -FilePath $logPath -Append
}

# 結果の表示
Write-Host "`n-------------------------------------" -ForegroundColor Cyan
Write-Host "インストール完了:" -ForegroundColor Cyan
Write-Host "  成功: $successCount" -ForegroundColor Green
Write-Host "  スキップ/既存: $skippedCount" -ForegroundColor Yellow
Write-Host "  失敗: $failCount" -ForegroundColor $(if ($failCount -eq 0) { "Green" } else { "Red" })
Write-Host "ログファイル: $logPath" -ForegroundColor Cyan
Write-Host "-------------------------------------" -ForegroundColor Cyan

# スクリプト終了
if ($failCount -gt 0) {
    Write-Host "一部のパッケージのインストールに失敗しました。詳細はログファイルを確認してください。" -ForegroundColor Yellow
    Write-Host "Enter キーを押して終了します..." -ForegroundColor Cyan
    Read-Host
    exit 1
} else {
    Write-Host "すべてのパッケージのインストールが正常に完了しました。" -ForegroundColor Green
    Write-Host "Enter キーを押して終了します..." -ForegroundColor Cyan
    Read-Host
    exit 0
}