param(
    [string]$VideoUrl,
    [switch]$NoOpenFolder,
    [switch]$PrepareOnly,
    [switch]$UpdateTools,
    [switch]$Configure
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = New-Object Text.UTF8Encoding($false)
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName Microsoft.VisualBasic
. (Join-Path $PSScriptRoot 'core.ps1')

try {
    if (-not [Environment]::Is64BitOperatingSystem) { throw '此版本需要 64 位 Windows 10 / 11。' }
    if ($Configure) { Show-Settings $PSScriptRoot; exit 0 }
    Write-Host 'B站一键下载 v1.0.0' -ForegroundColor Cyan
    Write-Host '复制 B站视频链接，再双击“一键下载.cmd”。'
    Write-Host ''

    if (-not $PrepareOnly -and -not $UpdateTools) {
        if ($VideoUrl) {
            $link = Get-BiliLink $VideoUrl
            if (-not $link) { throw '没有找到 B站视频链接。' }
        } else {
            $clipboardText = ''
            try { $clipboardText = [System.Windows.Forms.Clipboard]::GetText() } catch { }
            $link = Get-BiliLink $clipboardText
            if (-not $link) {
                $typed = [Microsoft.VisualBasic.Interaction]::InputBox('粘贴 B站视频链接或包含链接的分享文字：', 'B站一键下载', '')
                if ([string]::IsNullOrWhiteSpace($typed)) { exit 0 }
                $link = Get-BiliLink $typed
                if (-not $link) { throw '没有找到 B站视频链接，请复制后重新运行。' }
            }
        }
    }

    $tools = Ensure-Tools -Root $PSScriptRoot -Force:$UpdateTools
    if ($PrepareOnly -or $UpdateTools) { Write-Host '下载程序已准备好。' -ForegroundColor Green; exit 0 }
    $settings = Get-AppSettings $PSScriptRoot
    $outputDirectory = Join-Path $PSScriptRoot '下载的视频'
    New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
    $arguments = @(
        '--ignore-config', '--encoding', 'utf-8', '--no-playlist', '--windows-filenames', '--newline',
        '--ffmpeg-location', $tools.FFmpegDirectory,
        '-f', 'bv+ba/b', '-S', 'vcodec:h264,acodec:aac',
        '--merge-output-format', 'mp4', '--remux-video', 'mp4',
        '-P', $outputDirectory,
        '-o', '%(title).160B [%(id)s].%(ext)s'
    )
    if ($settings.ProxyMode -eq 'direct') { $arguments += '--proxy=' }
    $arguments += @('--', $link)
    Write-Host "开始下载：$link" -ForegroundColor Green
    Write-Host "保存位置：$outputDirectory"
    Write-Host '下载和合并过程中请保持窗口打开。'
    Write-Host ''
    & $tools.YtDlp @arguments
    if ($LASTEXITCODE -ne 0) {
        Write-Host ''
        Write-Host '下载失败。请保留上方具体报错。' -ForegroundColor Red
        Write-Host '网站兼容问题：双击“更新下载器.cmd”后再试。'
        Write-Host '连接问题：双击“设置.cmd”可切换直连 / 系统代理。'
        exit 1
    }
    Write-Host ''
    Write-Host '下载完成！' -ForegroundColor Green
    if (-not $NoOpenFolder) { Start-Process -FilePath 'explorer.exe' -ArgumentList ('"' + $outputDirectory + '"') }
    exit 0
} catch {
    Write-Host ''
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host '首次准备程序失败时，可按 README.md 中的“手动准备”步骤操作。'
    exit 1
}
