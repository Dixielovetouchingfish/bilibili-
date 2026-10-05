Set-StrictMode -Version 2.0

function Get-BiliLink {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return $null }
    foreach ($matchFound in [regex]::Matches($Text, 'https?://[^\s<>"“”]+')) {
        $candidate = $matchFound.Value.TrimEnd([char[]]'，。；！）】,;!)].')
        $parsed = $null
        if (-not [Uri]::TryCreate($candidate, [UriKind]::Absolute, [ref]$parsed)) { continue }
        $hostName = $parsed.DnsSafeHost.ToLowerInvariant()
        if ($hostName -eq 'b23.tv') { return $candidate }
        if ($hostName -ne 'bilibili.com' -and -not $hostName.EndsWith('.bilibili.com')) { continue }
        if ($parsed.AbsolutePath -match '^/video/((?i:BV)[A-Za-z0-9]+|(?i:av)[0-9]+)') {
            $cleanLink = 'https://www.bilibili.com/video/' + $Matches[1] + '/'
            if ($parsed.Query -match '(?:\?|&)p=([1-9][0-9]*)(?:&|$)') { $cleanLink += '?p=' + $Matches[1] }
            return $cleanLink
        }
        return $candidate
    }
    return $null
}

function Get-WebText {
    param([string]$Uri)
    $oldProgress = $ProgressPreference
    try {
        $ProgressPreference = 'SilentlyContinue'
        $response = Invoke-WebRequest -Uri $Uri -UseBasicParsing -TimeoutSec 60
        if ($response.Content -is [byte[]]) { return [Text.Encoding]::UTF8.GetString($response.Content) }
        return [string]$response.Content
    } finally { $ProgressPreference = $oldProgress }
}

function Get-ExpectedHash {
    param([string]$Manifest, [string]$FileName)
    foreach ($line in ($Manifest -split '\r?\n')) {
        if ($line -match '^\s*([a-fA-F0-9]{64})\s+\*?(.+?)\s*$') {
            if ($Matches[2] -eq $FileName) { return $Matches[1].ToLowerInvariant() }
        }
        if ($line.Trim() -match '^[a-fA-F0-9]{64}$') { return $line.Trim().ToLowerInvariant() }
    }
    throw "没有找到 $FileName 的 SHA-256 校验信息。请稍后重试。"
}

function Save-VerifiedDownload {
    param([string]$Uri, [string]$Destination, [string]$ExpectedHash)
    if ($ExpectedHash -notmatch '^[a-fA-F0-9]{64}$') { throw '无效的下载校验信息。' }
    $partialPath = $Destination + '.part'
    $oldProgress = $ProgressPreference
    try {
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $Uri -OutFile $partialPath -UseBasicParsing -TimeoutSec 300
        $stream = [IO.File]::OpenRead($partialPath)
        $sha256 = [Security.Cryptography.SHA256]::Create()
        try { $actualHash = [BitConverter]::ToString($sha256.ComputeHash($stream)).Replace('-', '').ToLowerInvariant() }
        finally { $stream.Dispose(); $sha256.Dispose() }
        if ($actualHash -ne $ExpectedHash) { throw '下载文件校验失败，程序未安装。请重新运行或稍后重试。' }
        Move-Item -LiteralPath $partialPath -Destination $Destination -Force
    } finally { $ProgressPreference = $oldProgress }
}

function Find-FFmpegDirectory {
    param([string]$Directory)
    if (-not (Test-Path -LiteralPath $Directory -PathType Container)) { return $null }
    foreach ($found in (Get-ChildItem -LiteralPath $Directory -Filter 'ffmpeg.exe' -File -Recurse -ErrorAction SilentlyContinue)) {
        if (Test-Path -LiteralPath (Join-Path $found.DirectoryName 'ffprobe.exe') -PathType Leaf) { return $found.DirectoryName }
    }
    return $null
}

function Ensure-Tools {
    param([string]$Root, [switch]$Force)
    $toolRoot = Join-Path $Root '.tools'
    $cacheRoot = Join-Path $Root '.cache'
    New-Item -ItemType Directory -Force -Path $toolRoot,$cacheRoot | Out-Null
    $ytDlp = Join-Path $toolRoot 'yt-dlp.exe'
    $ffmpegRoot = Join-Path $toolRoot 'ffmpeg'
    $ffmpegDirectory = $null
    $locationFile = Join-Path $toolRoot 'ffmpeg-location.txt'
    if (Test-Path -LiteralPath $locationFile) {
        $relativeLocation = (Get-Content -LiteralPath $locationFile -Raw -Encoding UTF8).Trim()
        $candidateDirectory = [IO.Path]::GetFullPath((Join-Path $toolRoot $relativeLocation))
        $expectedPrefix = [IO.Path]::GetFullPath($ffmpegRoot).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
        if ($candidateDirectory.StartsWith($expectedPrefix, [StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath (Join-Path $candidateDirectory 'ffmpeg.exe')) -and (Test-Path -LiteralPath (Join-Path $candidateDirectory 'ffprobe.exe'))) { $ffmpegDirectory = $candidateDirectory }
    }
    if (-not $ffmpegDirectory) { $ffmpegDirectory = Find-FFmpegDirectory $ffmpegRoot }

    # Existing tools can be copied beside the launcher for offline setup.
    $providedYtDlp = Join-Path $Root 'yt-dlp.exe'
    if (-not $Force -and (Test-Path -LiteralPath $providedYtDlp -PathType Leaf)) { $ytDlp = $providedYtDlp }
    if (-not $Force -and (Test-Path -LiteralPath (Join-Path $Root 'ffmpeg.exe') -PathType Leaf) -and (Test-Path -LiteralPath (Join-Path $Root 'ffprobe.exe') -PathType Leaf)) { $ffmpegDirectory = $Root }

    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    if ($Force -or -not (Test-Path -LiteralPath $ytDlp -PathType Leaf)) {
        Write-Host '首次准备 / 更新：正在从 yt-dlp 官方发布页下载程序……' -ForegroundColor Cyan
        $manifest = Get-WebText 'https://github.com/yt-dlp/yt-dlp/releases/latest/download/SHA2-256SUMS'
        $expectedHash = Get-ExpectedHash $manifest 'yt-dlp.exe'
        $ytDlp = Join-Path $toolRoot 'yt-dlp.exe'
        Save-VerifiedDownload 'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe' $ytDlp $expectedHash
    }
    if ($Force -or -not $ffmpegDirectory) {
        Write-Host '首次准备 / 更新：正在下载 FFmpeg ZIP 包，约 100 MB，请耐心等待……' -ForegroundColor Cyan
        $archive = Join-Path $cacheRoot 'ffmpeg-release-essentials.zip'
        $manifest = Get-WebText 'https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip.sha256'
        $expectedHash = Get-ExpectedHash $manifest 'ffmpeg-release-essentials.zip'
        Save-VerifiedDownload 'https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip' $archive $expectedHash
        New-Item -ItemType Directory -Force -Path $ffmpegRoot | Out-Null
        # Keep the complete upstream package, including its license and notices.
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $zip = [IO.Compression.ZipFile]::OpenRead($archive)
        try {
            $ffmpegEntry = $zip.Entries | Where-Object { $_.FullName -match '(^|/)bin/ffmpeg\.exe$' } | Select-Object -First 1
            if (-not $ffmpegEntry) { throw 'FFmpeg 包内未找到 ffmpeg.exe。' }
            $relativeExecutable = $ffmpegEntry.FullName.Replace([char]'/', [IO.Path]::DirectorySeparatorChar)
        } finally { $zip.Dispose() }
        $extractRoot = Join-Path $ffmpegRoot ([Guid]::NewGuid().ToString('N'))
        [IO.Compression.ZipFile]::ExtractToDirectory($archive, $extractRoot)
        $ffmpegDirectory = Split-Path -Parent (Join-Path $extractRoot $relativeExecutable)
        if (-not (Test-Path -LiteralPath (Join-Path $ffmpegDirectory 'ffprobe.exe') -PathType Leaf)) { throw 'FFmpeg 包内未找到 ffprobe.exe。' }
        $relativeLocation = $ffmpegDirectory.Substring($toolRoot.Length + 1)
        Set-Content -LiteralPath $locationFile -Value $relativeLocation -Encoding UTF8
    }
    return [pscustomobject]@{ YtDlp = $ytDlp; FFmpegDirectory = $ffmpegDirectory }
}

function Get-AppSettings {
    param([string]$Root)
    $settings = [pscustomobject]@{ ProxyMode = 'direct' }
    $path = Join-Path $Root 'settings.json'
    if (Test-Path -LiteralPath $path) {
        $stored = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($stored.PSObject.Properties.Name -contains 'ProxyMode') {
            if ($stored.ProxyMode -in @('direct','system')) { $settings.ProxyMode = $stored.ProxyMode }
        }
    }
    return $settings
}

function Show-Settings {
    param([string]$Root)
    $settings = Get-AppSettings $Root
    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'B站一键下载 - 设置'
    $form.ClientSize = New-Object Drawing.Size(440,180)
    $form.StartPosition = 'CenterScreen'
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $label = New-Object System.Windows.Forms.Label
    $label.Text = '视频连接方式（默认直连，避免代理引发 HTTP 412）'
    $label.SetBounds(18,20,405,28)
    $choices = New-Object System.Windows.Forms.ComboBox
    $choices.DropDownStyle = 'DropDownList'
    $choices.SetBounds(18,55,405,30)
    [void]$choices.Items.Add('直连 B站（默认）')
    [void]$choices.Items.Add('使用系统代理')
    $choices.SelectedIndex = 0
    if ($settings.ProxyMode -eq 'system') { $choices.SelectedIndex = 1 }
    $save = New-Object System.Windows.Forms.Button
    $save.Text = '保存'
    $save.SetBounds(315,112,108,32)
    $save.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.AcceptButton = $save
    $form.Controls.AddRange(@($label,$choices,$save))
    try {
        if ($form.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $mode = 'direct'
            if ($choices.SelectedIndex -eq 1) { $mode = 'system' }
            @{ ProxyMode = $mode } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $Root 'settings.json') -Encoding UTF8
            Write-Host '设置已保存。'
        }
    } finally { $form.Dispose() }
}
