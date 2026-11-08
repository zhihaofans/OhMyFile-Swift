# OhMyFile

<p align="center">
  <img src="OhMyFile/Assets.xcassets/AppIcon.appiconset/AppIcon-Light.png" width="128" alt="OhMyFile icon">
</p>

<p align="center">
  <a href="https://github.com/zhihaofans/OhMyFile-Swift/tags"><img src="https://img.shields.io/github/v/tag/zhihaofans/OhMyFile-Swift?label=version&color=blue" alt="Version"></a>
  <img src="https://img.shields.io/badge/platform-iOS%2017%2B-blue" alt="Platform">
</p>

一款以 iOS 为首发平台的原生文件预览与编辑应用。

## 核心流程

**分享文件 → 接收文件 → 预览 → 分享 / 保存**

通过 iOS 系统分享菜单把其他应用中的文件发送给 OhMyFile，快速完成查看；编辑能力在预览链路稳定后分批支持（见 [TODO.md](TODO.md)）。

## 平台

- iOS：首要开发和发布平台。
- iPadOS：与 iOS 共用主要代码，适配大屏。
- macOS：后续视情况扩展。
- visionOS：暂不考虑。

## 当前状态

0.0.2 已实现分享导入、文件管理（收件箱 / 下载 / 回收站）、常见格式预览（文本 / Markdown / JSON / XML / CSV / Office 等）、相册 / 拍照 / 扫描 / 剪贴板导入，以及设置（外观 / 权限 / 存储 / 关于）等基础功能。开发规划见 [TODO.md](TODO.md)，已完成变化见 [CHANGELOG.md](CHANGELOG.md)。

## 开发

- 开发规范、目录、命令与已知坑：[AGENTS.md](AGENTS.md)
- 构建：用 Xcode 27.2 打开 `OhMyFile.xcodeproj`，⌘B 构建，⌘U 测试。
- 技术约定：功能优先复用 SwiftUtils 库；崩溃收集使用 CrashKit（接入前先出方案）。

## 文档

规划：构建时把本文件与 `CHANGELOG.md` 打包进 App，作为 App 内的示例文件（见 [TODO.md](TODO.md) 的工程卫生条目）。
