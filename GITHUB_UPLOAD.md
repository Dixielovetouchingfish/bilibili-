# 用 GitHub 网页上传

这份项目尚未发布；你可以通过网页上传，无需输入 Git 命令。

1. 登录自己的 GitHub，点击右上角 **+ → New repository**。
2. 仓库名称填写 `bilibili-oneclick`，描述可复制 README 中的文字。
3. 希望所有人可见时选择 **Public**。项目已有 README、LICENSE 和 .gitignore，创建页的这些选项保持未勾选。
4. 点击 **Create repository**。在空仓库页面点击 **uploading an existing file**；以后可用 **Add file → Upload files**。
5. 解压“GitHub源码包”，把项目文件夹里的全部源码文件拖入上传区域，包含 `.gitignore`、`.gitattributes`、三个 CMD、两个 PS1、Markdown 说明和 LICENSE。
6. 提交说明填写 `Initial release`，点击 **Commit changes**。

建议使用原始源码包上传，里面没有下载过的视频、工具缓存、个人设置或第三方 EXE。不要把已运行过的整个工具目录拖进网页上传。

发布供普通用户下载的 ZIP：

1. 进入仓库的 **Releases → Draft a new release**。
2. 创建标签 `v1.0.0`，标题填 `B站一键下载 v1.0.0`。
3. 在附件区域上传“分享版 ZIP”，说明首次运行会自动准备依赖。
4. 点击 **Publish release**。

普通用户从 Release 下载分享版 ZIP，解压后双击“一键下载.cmd”。源码也可直接解压运行。
