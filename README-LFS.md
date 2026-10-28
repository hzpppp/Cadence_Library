# 大文件上传说明

GitHub 普通 Git 单个文件的上限为 100 MiB。这个仓库使用 Git LFS 保存大文件内容，Git 提交中保存对应指针；LFS 单文件上限、存储和流量额度取决于 GitHub 账户套餐。

## 日常提交

在仓库根目录运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\Track-LargeFiles.ps1
git add .
git commit -m "更新元件库"
git push
```

扫描脚本会为已跟踪或未被忽略的、大小达到 50 MiB 的文件添加精确 LFS 规则，并跳过已经使用 LFS 的文件。它只初始化本仓库的 LFS 配置、更新 `.gitattributes`，不会自动暂存、提交或推送。每次添加或修改大文件后，先运行扫描，再运行 `git add`，并将 `.gitattributes` 一起提交。

`.gitignore` 使用扩展名白名单。如果新文件的扩展名没有放行，请先在 `.gitignore` 添加相应的 `!*.扩展名` 规则，再运行扫描。脚本不会修改已提交的历史。

## 新电脑或重新克隆

先安装包含 Git LFS 的 Git for Windows，然后运行：

```powershell
git lfs install
git clone <仓库地址>
cd Cadence_Library
git lfs pull
```

如果 LFS 上传因存储或流量额度失败，请查看 GitHub 仓库所属账户的 LFS 用量和套餐。不要移除 LFS 规则后将超过 100 MiB 的原文件直接提交到普通 Git。
