# https://gnuwin32.sourceforge.net/packages/libiconv.htm
# Complete package, except sourcesをDLする前提
[Environment]::SetEnvironmentVariable("APR_ICONV_PATH", "$HOME\GnuWin32", "User")


# https://github.com/TortoiseGit/tortoisesvn/blob/3407164d485b6392053ed1344a921ffccf180926/src/TortoiseSVNSetup/FeaturesFragment.wxs#L68
# https://zenn.dev/proudust/scraps/a39083402ecd31

# installしてCLIへのパスの追加まで
winget install -e TortoiseSVN.TortoiseSVN --override "ADDLOCAL=MoreIcons,CLI /qn"
$currentUserPath = [Environment]::GetEnvironmentVariable("Path", "User")
[Environment]::SetEnvironmentVariable("Path", $currentUserPath + ";C:\Program Files\TortoiseSVN\bin", "User")

# ディレクトリの作成
# システム環境変数いじれないのでユーザー配下
$svnlocation = "$HOME\repository\svn"
mkdir $svnlocation -Force; cd $svnlocation

# チェックアウト
$svnRepositoryUrlRoot =  "http://192.168.70.51/svn/104_sbi/07_CCoE/"
$svnRepositoryUrlBranches = "$svnRepositoryUrlRoot/branches"

# Trunkのチェックアウト
echo "トランク全体をチェックアウトしています..."
svn checkout "$svnRepositoryUrlRoot/trunk" "./trunk"
echo "トランクのチェックアウトが完了しました"

# Branchのチェックアウト
Write-Host "ブランチ一覧を取得しています..." -ForegroundColor Cyan
$branches = (svn list $svnRepositoryUrlBranches).Trim()

# 3か月前の日付を計算
$THREE_MONTHS_AGO = [datetime]::Parse((Get-Date).AddMonths(-3)).ToString("yyyy-MM-dd")

Write-Host "直近3カ月($THREE_MONTHS_AGO)以降で更新のあったブランチをチェックアウトしています..." -ForegroundColor Cyan

# 各ブランチの最終更新日をチェック
foreach ($branch in $branches) {
    # ブランチが実際のディレクトリ名かを確認（末尾のスラッシュを除去）
    $branch = $branch.TrimEnd('/')
    
    # 空でない場合のみ処理
    if (-not [string]::IsNullOrWhiteSpace($branch)) {
        # ブランチの最終更新日を取得
        $tmpinfo = svn info --xml "$svnRepositoryUrlBranches/$branch"

        # 文字化けするのでブランチ名が表示される行を削除してXMLに取り込む
        # 4行目を除外（インデックス3）
        $resultLines = $tmpinfo[0..2] + $tmpinfo[4..($tmpinfo.Count-1)]

        [xml]$svnInfo = $resultLines

        $lastChangedDateStr = $svnInfo.info.entry.commit.date
        
        # 最終更新日を日付形式に変換して比較
        $lastChangedDate = [datetime]::Parse($lastChangedDateStr).ToString("yyyy-MM-dd")
        
        # 3カ月以内に更新されたブランチかどうかを確認
        if ($lastChangedDate -ge $THREE_MONTHS_AGO) {
            Write-Host "チェックアウト: $branch (最終更新日: $lastChangedDate)" -ForegroundColor Green
            svn checkout "$svnRepositoryUrlBranches/$branch" ".\branches\$branch"
        } else {
            Write-Host "スキップ: $branch (最終更新日: $lastChangedDate - 3カ月以上前)" -ForegroundColor Yellow
        }
    }
}

Write-Host "チェックアウト処理が完了しました" -ForegroundColor Cyan