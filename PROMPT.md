# 通用提示词（任何 AI 助手都能用）

豆包、DeepSeek、WorkBuddy、Claude Code、ChatGPT……只要是能执行命令或联网的 AI 助手，
**整段复制发给它即可**，不需要任何插件或 skill 文件。

## 安装并打开工具

> 帮我安装并打开「照片审核」这个 macOS 报名照片工具：
>
> `git clone https://github.com/liamrubicon-droid/zhaopianshenhe-mac.git ~/.zhaopianshenhe-mac && cd ~/.zhaopianshenhe-mac && bash build.sh && open 照片审核.app`
>
> 若提示缺编译器，先执行 `xcode-select --install`。

## 直接审核一张照片（把「照片.jpg」换成你的文件路径）

> 帮我用「照片审核」审核这张照片 `照片.jpg`：先装好工具
> `git clone https://github.com/liamrubicon-droid/zhaopianshenhe-mac.git ~/.zhaopianshenhe-mac && cd ~/.zhaopianshenhe-mac && bash build.sh`，
> 再运行 `~/.zhaopianshenhe-mac/照片审核.app/Contents/MacOS/PhotoReview 照片.jpg 报名照片.jpg`，
> 告诉我审核是否通过；不通过的话，原因是什么。
