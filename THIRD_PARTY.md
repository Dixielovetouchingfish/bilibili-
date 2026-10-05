# 第三方程序

本项目调用外部下载器与媒体工具；项目的 MIT 许可仅覆盖本项目脚本，不替代依赖的许可。

| 程序 | 作用 | 下载来源 / 项目 |
| --- | --- | --- |
| yt-dlp | 获取视频和音频 | [官方 GitHub](https://github.com/yt-dlp/yt-dlp) |
| FFmpeg / ffprobe | 合并、处理和检查媒体 | [FFmpeg 官网](https://ffmpeg.org/)、[gyan.dev Windows 构建](https://www.gyan.dev/ffmpeg/builds/) |

yt-dlp 源码以 [Unlicense](https://github.com/yt-dlp/yt-dlp/blob/master/LICENSE) 发布。官方 Windows 二进制包含其他组件，具体许可和说明以对应发布包及[官方 README](https://github.com/yt-dlp/yt-dlp#release-files)为准。

FFmpeg 的许可与构建选项有关，见 [FFmpeg 许可说明](https://ffmpeg.org/legal.html)。本工具获取 gyan.dev 提供的 essentials 构建，其页面标注为 GPLv3；自动准备时保留完整上游解压包中的许可、说明和链接。

分享包与源码包不包含这些第三方二进制。程序运行时从各上游网站获取并核对其公布的 SHA-256。校验用于确认文件完整性，不代表本项目对第三方程序的行为提供保证。
