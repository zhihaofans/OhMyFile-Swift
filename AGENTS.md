# OhMyFile — 项目开发规范

本文件写给在本仓库工作的 coding agent，同时是项目的长期约定。面向用户的说明见 `README.md`。

- 未完成的事：只记在 `TODO.md`。
- 已完成、用户能感知的变化：记在 `CHANGELOG.md`。
- 本文件只写长期有效、且已核对过工程的事实；功能是否已实现以代码和 Git 为准。

## 1. 项目定位

OhMyFile 是一款以 iOS 为首发平台的原生文件预览与编辑应用。

核心使用流程（预览优先，编辑后置）：

**分享文件 → 接收文件 → 预览 → 分享 / 保存**

用户通过 iOS 系统分享菜单把其他应用中的文件发给 OhMyFile，完成快速查看。

编辑能力（文本、Markdown / JSON / XML / CSV、PDF 标注、图片基础编辑）在预览链路稳定后分批支持；第一版验收不包含编辑。

### 平台规划

- iOS：首要开发和发布平台。
- iPadOS：与 iOS 共用主要代码，界面适配大屏。
- macOS：有条件时扩展原生 macOS App，不是首期交付要求。
- visionOS：暂不考虑（见 `TODO.md` 的「明确不做」）。

### 核心原则

1. 原生优先：优先使用 Apple 官方框架。
2. iOS 优先：所有核心功能首先保证 iPhone 体验。
3. 跨平台友好：设计时为 iPadOS 和 macOS 留出扩展空间，但不为此牺牲 iOS 体验。
4. 本地优先：尽可能在本地处理用户文件。
5. 安全可靠：避免意外覆盖、丢失或泄露用户文件。
6. 简洁高效：减少不必要的操作和界面层级。
7. 模块化：文件导入、预览、编辑和存储保持职责独立。
8. 预览优先：第一阶段只做接收和只读预览；编辑能力后置，不阻塞预览体验。

不要为了追求跨平台而牺牲 iOS 原生体验。

## 2. 仓库工作约定（先读）

### 三件套

| 文件 | 写什么 | 不写什么 |
|---|---|---|
| `TODO.md` | 唯一未完成清单：进行中 / 待办 / 阻塞；可选的「明确不做」「想法（未承诺）」分区 | 已完成的事、愿望清单、讨论记录 |
| `CHANGELOG.md` | 已完成且用户可感知的变化，按版本分组（Keep a Changelog） | commit log 的复述、「优化代码」 |
| `AGENTS.md` | 长期规则：定位、选型、架构、规范、安全、测试、已知坑 | 进度、新闻、一次性计划 |

一条任务的完整生命周期：写进 `TODO.md`（可验收）→ 做 → 从 TODO 删除 → 有用户可感知变化就记 `CHANGELOG.md` → 征得同意后提交。纯内部改动（重构、补测试、注释）只从 TODO 删除，不进 CHANGELOG，靠 commit message 留痕。

### Git：先问，再做

必须先在对话里征得明确同意：

- `commit`（含 `--amend`）、`push`、`tag`、`pull`、建 / 删 / 改名 / 切换分支、`merge`、`rebase`、`cherry-pick`、`reset`、`revert`、`restore` / `checkout` 丢弃改动、`stash drop|clear`、`clean`、`rm`、`mv`、改 remote、`gh pr|release`、加 submodule。
- 征询时贴 `git status --short` 摘要、逐条命令、拟用提交信息、影响范围（推到哪、是否动已推送历史）；只 `git add` 本次审阅过的文件，`add -A` / `add .` 要单独问并列出会加入什么。
- 同意只覆盖当次、当条：批了 commit 不等于批了 push，批了 push 不等于批了打 tag。
- 只读命令（`status`、`diff`、`log`、`show`、`blame`、`rev-parse`、`ls-files`）可直接跑；`fetch` 可以跑，但要说明拉了什么，不能当 `pull` 用。
- 不用 `--no-verify` 跳过 hook；hook 失败就修。不 force-push、不移动已推送的 tag、不 amend 已推送提交。
- 一次 commit 只做一件事；提交信息用 `feat: / fix: / docs: / refactor: / perf: / test: / build: / ci: / style: / chore:` + 一句话说清改了什么。

### 版本号：改之前先问

- 以下都算发版动作，每次都先问用户，上次同意不代表这次同意：改 `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION`；把 CHANGELOG 的 `[Unreleased]` 切成 `## [x.y.z]`；打 tag；上传 TestFlight / App Store。
- 功能提交不带版本号：做完先留在 `[Unreleased]`，等用户说「发版」再单独一次提交做版本变更。
- 版本语义按 SemVer 2.0：X = 不兼容改动，Y = 新功能，Z = 修复；预发布写 `0.1.0-rc.1`。
- 问的时候给：当前版本、建议版本与理由、要改的文件、要不要同时打 tag / 发布。

### 方案先行

先出五段短方案（一屏看完），停，等用户同意再动代码：

```text
目标 / 不做：
改动文件：
步骤（≤5）：
风险与回滚：
验证方式：
待你决定：
```

- 需要方案：新功能；跨文件改动（≥3 个文件或动公共接口 / 数据结构）；依赖、构建、发布、迁移；删除或重命名；需求有两种读法。
- 可以跳过：错别字、单行修复、用户已给出明确步骤——但仍先用一句话说清要改什么。
- 需求有两种读法、会删数据 / 改历史 / 发版 / 动线上、要账号密钥外部服务、命名或公共 API 或目录结构取舍、与现有文档冲突：先问，不猜。一次问一个主题，最多 3 个问题，给选项和推荐项。

### 文档语言

项目文档统一使用简体中文；技术名称、API、框架名和代码标识符保留英文原文。

## 3. 工程现状与常用命令

### 环境（已核对）

- Xcode 27.2（27B52），iOS SDK 27.2，可用模拟器为 iOS 27.2。
- 工程：`OhMyFile.xcodeproj`；scheme 只有一个：`OhMyFile`。
- Targets：`OhMyFile`（app）、`OhMyFileTests`（单元测试）、`OhMyFileUITests`（UI 测试）。
- 业务功能尚未实现，当前只有模板视图与测试代码（`OhMyFileApp.swift`、`ContentView.swift`）。

### 命令

```bash
# 查看 target / scheme / 配置（已验证通过）
xcodebuild -list -project OhMyFile.xcodeproj

# 构建 / 测试：在 Xcode 中打开工程，⌘B / ⌘U
# 命令行构建（命令本身正确；当前 agent 沙盒下会因宏插件被拒而失败，见 §18）：
xcodebuild -project OhMyFile.xcodeproj -scheme OhMyFile \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
  -derivedDataPath .build/DerivedData build
```

日常验证走 Xcode；命令行完整构建在当前 agent 沙盒内不可用（原因和替代方案见 §18「已知限制与坑」）。不要因为命令行失败就改代码。

### 目录

```text
OhMyFile/            App 源码（OhMyFileApp.swift、ContentView.swift、Assets.xcassets）
OhMyFileTests/       Swift Testing 单元测试
OhMyFileUITests/     XCTest UI 测试
OhMyFile.xcodeproj/  工程文件（project.xcproj 为 JSON 风格文本，含尾逗号）
.gitignore           忽略构建产物、用户数据和分发产物
README.md            项目说明（规划作为示例文件随 App 打包）
AGENTS.md / TODO.md / CHANGELOG.md   三件套
```

当前没有 `Package.swift`、没有 SPM 依赖、没有独立 `Info.plist`、没有 Entitlements 文件。

## 4. 目录与架构

### 规划的职责划分

以下按职责组织，**不是现在就要建的空目录**；新增代码时按此归属，目录随实际需要创建：

- App：应用入口、生命周期和全局配置。
- Features：用户功能模块（Home：最近打开；Preview：文件预览；Editor：文件编辑；Settings：应用设置）。
- FileCore：文件模型和基础操作。
- FileImport：文件导入及分享处理。
- FilePreview：文件预览。
- FileEditor：文件编辑。
- FileStorage：文件存储。
- Shared：跨功能通用组件。
- Platform：平台专属实现。

### 架构要求

- UI 与业务逻辑分离。
- 文件操作与界面展示分离。
- 不同格式的预览实现保持独立。
- 不同格式的编辑实现保持独立。
- 优先使用清晰的值类型模型。
- 在有实际需要时使用 Protocol。
- 避免过度抽象；避免无意义的 Manager、Service、Factory 层级。
- 不要将所有业务逻辑放进 View 或 ViewModel。

### 跨平台代码

只有在多个平台具有相同业务语义时才共享实现。

优先共享：文件模型、文件类型识别、文件元数据、文件读写逻辑、文本编码处理、JSON / XML 等数据解析、通用业务规则。

平台专属实现：Share Extension、平台导航、窗口管理、系统菜单、平台专属文件访问、平台专属预览能力。

共享业务逻辑，不强制共享 UI。

## 5. 技术选型与平台策略

| 领域 | 技术 |
|---|---|
| 编程语言 | Swift |
| UI 框架 | SwiftUI |
| 文件操作 | Foundation、FileManager |
| 网盘 / 云存储 | OAuth 2.0 + 官方 REST API（后续） |
| 文件类型识别 | UniformTypeIdentifiers |
| 文件分享 | Share Extension（接收）、系统分享（导出） |
| 文件预览 | QuickLook |
| PDF 处理 | PDFKit |
| 图片处理 | CoreGraphics、ImageIO |
| 文本编辑 | SwiftUI 原生组件 |
| 代码编辑 | TextKit / SwiftUI（语法高亮方案待评估） |
| 并发处理 | Swift Concurrency |
| 通用工具 | SwiftUtils（优先复用） |
| 崩溃收集 | CrashKit |
| 日志 | OSLog / Logger |
| 单元测试 | Swift Testing |
| UI 测试 | XCTest |

以上为选型方向；实际接入情况以工程配置为准（见 §17）。

### 选型规则

- 优先使用 Apple 官方框架，优先使用 SwiftUI。
- 只有在 SwiftUI 无法满足需求时才使用 UIKit；macOS 专属功能可以使用 AppKit。
- 优先使用系统自带接口：预览优先 QuickLook、PDFKit、AVKit 等系统能力；系统能覆盖的不引入第三方库、不自研格式解析器。
- 网盘与远程存储优先使用各服务的官方 OAuth 2.0 + REST API；引入官方 SDK 前先评估体积、维护状态和审核风险，并先问用户。
- 功能实现优先复用 SwiftUtils 已提供的能力；SwiftUtils 未覆盖时再自研或引入其他依赖。
- 崩溃收集使用 CrashKit；崩溃日志默认本地保存，上传需用户明确同意，且不得包含文件内容或用户标识。
- 引入 SwiftUtils / CrashKit 同样走 Swift Package Manager，接入前确认版本与许可，并先出方案。
- 引入第三方依赖必须说明「系统能力为什么不够」，并先问用户。
- 代码编辑器的语法高亮优先基于系统 TextKit / SwiftUI 实现；引入第三方编辑器前先评估维护状态与体积，并先问用户。
- 不要为了简单功能引入大型第三方库；依赖用 Swift Package Manager 管理。
- 不要在没有明确收益的情况下引入复杂架构。
- 不要为了代码复用而强行统一不同平台的交互方式。

### API 可用性

- 使用 API 前检查对应平台的可用性。
- 使用 `#available` 处理平台版本差异。
- 使用 `#if os(iOS)`、`#if os(macOS)` 处理平台专属代码。
- 不要假设 iOS、iPadOS 和 macOS 的系统 API 完全一致。

### 平台策略

**iOS（首要平台）**：所有核心功能必须优先在 iPhone 上完成和验证。重点关注 Share Sheet 文件接收、快速预览、编辑与保存、系统导航和工具栏、文件操作反馈、内存和性能控制、系统权限及沙盒限制。

**iPadOS**：与 iOS 共用主要业务逻辑，界面根据屏幕尺寸适配。重点关注横竖屏、多列布局、Split View、Stage Manager、外接键盘、更大的预览区域。不要简单放大 iPhone 界面。

**macOS（后续扩展，不是首期交付）**：架构避免与 iOS 紧密耦合。未来优先采用原生 macOS App Target，使用 SwiftUI 和必要的 AppKit API。重点考虑原生窗口体验、菜单栏和工具栏、Finder 打开和拖放、键盘快捷键、文件系统访问、macOS 分享机制、多窗口和文档管理。不要直接把 iOS Share Extension 当作 macOS 分享扩展使用。

不同平台的功能或系统 API 差异较大时，使用独立的平台实现，而不是强行共用。

## 6. 文件导入与分享（尚未实现）

> 本节规则在创建 Share Extension 和导入功能时执行；当前工程没有 Share Extension target、没有 App Groups。

iOS 首期通过 Share Extension 接收其他应用分享的文件。

### 功能要求

- 接收单个文件；在合理情况下支持多个文件。
- 正确识别文件类型，保留原始文件名。
- 处理同名文件，检查文件可访问性。
- 必要时将外部文件复制到应用存储空间。
- 提供明确的导入成功和失败反馈。
- 局域网 / 热点传输由用户显式开启，仅在同一局域网内监听；传输结束或离开页面即关闭，不默认开放端口。
- 系统文件位置（iCloud 云盘、我的 iPhone、第三方文件提供者）通过文件选择器与安全作用域书签访问，只读用户授权的位置。
- File Provider 暴露（把 OhMyFile 挂到系统「文件」App）需要新增 Extension target，实现前先出方案。

### 安全要求

- 正确处理 Security-Scoped URL。
- 不要假设外部 URL 永久有效，不要长期依赖临时文件路径。
- 不要在没有必要的情况下复制大型文件。
- 访问外部文件时正确管理安全作用域的生命周期。
- 不要在主线程执行耗时文件操作。

### Share Extension

Share Extension 必须保持轻量。

- 正确处理 Extension 生命周期；不要假设它可以无限期运行。
- 避免在 Extension 中执行大型文件处理；及时释放资源。
- 根据需要使用 App Groups 共享文件或状态；使用 App Groups 时必须保证相关 Target 配置一致。
- 主 App 与 Extension 应有明确的文件交接协议；不要为了共享简单数据建立不必要的复杂通信机制。

## 7. 文件类型识别（尚未实现）

统一使用 UniformTypeIdentifiers 识别文件类型。

- 优先根据 UTType 判断文件能力，而不是只检查扩展名。
- 每种文件类型区分：是否可以预览、是否可以编辑、是否可以导出、是否支持特定操作。
- 建立统一的文件能力描述模型；不要将文件类型与具体 UI 绑定。
- 同一种文件格式可以拥有不同的预览和编辑实现。
- 对于未知文件类型，提供通用预览或明确的暂不支持提示。

## 8. 文件预览（第一期核心，尚未实现）

建立统一的文件预览入口，根据文件类型选择合适的预览实现。先保证常见格式的覆盖率和打开速度；编辑能力不在本阶段验收范围。

计划支持：PDF、PNG / JPEG / HEIC 等图片、TXT、Markdown、JSON、XML、CSV、HTML、音频、视频、Office 文档，以及其他 Quick Look 支持的格式。

技术选型：通用文件预览用 QuickLook；PDF 用 PDFKit；图片用 ImageIO、CoreGraphics；音视频用 AVFoundation；文本用 SwiftUI 原生组件。

预览要求：

- 优先使用原生系统能力；预览逻辑独立于编辑逻辑。
- 大型文件采用合理的加载策略，避免一次性加载大量数据到内存。
- 提供加载状态和错误状态；对不支持的格式提供明确反馈。
- 预览操作不允许意外修改原始文件。
- 不要默认所有可预览格式都能编辑。

## 9. 文件编辑与保存（后续能力，尚未实现）

编辑能力在预览链路稳定后分批上线；本节只约束做法，不代表第一版交付内容。

计划支持：纯文本、Markdown、JSON、XML、CSV、PDF 标注、图片基础编辑。

编辑要求：

- 原始文件与工作副本分离；默认避免直接修改原文件。
- 支持明确保存修改；保留合理的文件编码和换行格式。
- 保存前校验结构化数据；处理保存失败。
- 避免意外覆盖用户文件；在必要时检测文件外部变化。
- 不支持编辑的格式保持只读模式。

保存策略：编辑器必须明确区分原始文件、工作副本、已保存文件；根据功能决定原位保存还是另存为；未经用户明确操作，不要执行不可逆的破坏性修改。

## 10. 文件存储（尚未实现）

使用 FileManager 和系统沙盒目录管理文件，建议区分：

- Imported：导入文件。
- Working：编辑中的文件。
- Documents：正式保存的文件。
- Cache：缓存文件。
- Temporary：临时文件。

存储规则：

- 不使用 UserDefaults 保存大型文件。
- 避免不必要的文件复制；适当使用原子写入。
- 正确处理同名文件；及时清理废弃临时文件。
- 不自动删除用户正式文件；考虑文件保护和备份策略。
- 避免将可重新生成的缓存加入 iCloud 备份。
- 不要假设所有分享进来的文件都需要永久保存。
- 网盘文件按需下载，缓存单独存放且可清理；断开连接后清空对应凭证与缓存。
- 用户可见目录（收件箱 / 下载 / 回收站）与上述内部目录的映射在文件管理实现时确定，并写回本文件。

## 11. UI 与交互

优先遵循 Apple 原生设计规范。

### 通用规范

- 使用 SwiftUI 和 SF Symbols。
- 支持浅色 / 深色模式、Dynamic Type；考虑 VoiceOver。
- 使用系统原生导航；合理使用 Toolbar、Menu、Sheet。
- 提供空状态、加载状态和错误状态。
- 保持界面简洁；避免不必要的动画和装饰。

### 各平台

- iPhone：优先单列布局，操作入口清晰，避免过多层级，适应不同屏幕尺寸。
- iPad：合理使用多列布局，支持横竖屏，考虑键盘和指针交互，避免简单拉伸 iPhone 界面。
- macOS：使用原生窗口和菜单结构，支持键盘快捷键，尊重 macOS 用户习惯，避免照搬 iPhone 导航方式。

不要为了追求统一而牺牲平台原生体验。

## 12. Swift 编码规范

- 遵循 Swift API Design Guidelines；使用清晰、统一的命名。
- 优先使用 `let`；合理使用访问控制。
- 优先使用 `struct` 表达值类型，仅在需要引用语义时使用 `class`。
- 避免不必要的强制解包和强制类型转换；明确处理错误。
- 保持函数职责单一；避免不必要的代码重复。

### SwiftUI

- 合理拆分 View，组件职责单一。
- 避免过度使用 `AnyView`；不要在 `body` 中执行耗时操作。
- 正确管理 State 和 Observation；使用稳定的 `ForEach` 标识符。
- 优先采用项目最低系统版本支持的现代 API；不使用已废弃 API。
- 不在 `body` 里写会触发 `body` 重算的副作用；视图之间不互相调用，共享状态走同一个 Store。

### 并发

- UI 更新在 MainActor 上执行；文件 I/O 避免阻塞主线程。
- 正确处理 Task 取消；避免不必要的 `Task.detached`。
- 注意共享状态的数据竞争；不要忽略 Swift Concurrency 相关警告。
- 注意 app target 默认开启 `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`（见 §18）：回调式 API 的闭包会隐式继承主线程隔离，后台队列回调会运行时崩溃。新代码优先 `async` / `await`；必须用回调时，参数标 `@Sendable`，或在调用点标 `nonisolated`。

## 13. 隐私与安全

隐私是产品的基本要求。

- 默认本地处理文件；未经用户明确同意不得上传文件。
- 仅申请必要的系统权限；正确处理外部文件访问权限。
- 不执行导入文件中的可执行内容。
- 不信任外部文件名和扩展名；校验外部输入。
- 避免在日志中输出敏感内容；遵守 Apple 沙盒和文件访问规则。
- 网盘 / 远程连接由用户显式发起；凭证存 Keychain，不写 UserDefaults 或日志，可随时断开并清除。
- 不自动上传或同步用户文件到网盘；上传 / 下载必须由用户操作触发。
- 远程连接按协议启用加密与校验：WebDAV 强制 HTTPS、FTP 用 FTPS、SMB 启用加密或签名、SFTP 校验 host key；不默认接受明文连接；不信任服务端返回的文件名与路径。
- 局域网 / 热点传输只在用户主动开启时监听，只暴露给同一网络；接收的文件不自动上传云端。
- 访问系统文件位置前取得用户授权，不扫描未授权位置；File Provider 只暴露用户文件，不暴露内部数据。
- 崩溃日志不含文件名、文件内容或用户标识；CrashKit 上报默认关闭或需用户明确同意，并提供开关。

## 14. 性能

- 避免不必要的文件复制；避免大型文件一次性加载。
- 避免阻塞主线程；合理使用异步处理。
- 控制图片解码的内存使用；及时释放临时资源。
- 支持耗时任务取消；避免无意义的重复解析和计算。

## 15. 错误处理与日志

重点处理：文件不存在、文件不可访问、文件格式不支持、文件内容损坏、文件权限错误、存储空间不足、文件导入失败、文件预览失败、文件保存失败、Extension 生命周期中断。

- 使用明确的错误类型。
- 使用 `Logger`（OSLog）记录诊断信息；不使用 `print` 作为正式日志方案。
- 不记录文件敏感内容。
- 用户提示清晰易懂；错误信息不泄露内部实现。

## 16. 测试与验证

优先测试核心业务逻辑，重点包括：UTType 文件识别、文件导入（含多文件和同名冲突）、文件存储、文本编码、JSON 校验、保存与恢复、文件权限、临时文件清理、文件预览和编辑流程。

- Swift Testing：业务逻辑单元测试。
- XCTest：UI 测试及需要 XCTest 能力的场景。
- 测试依赖环境（时区、语言、深色模式）时注入固定值，不改进程全局默认。
- 验证方式是「写入 → 销毁实例 → 重新从磁盘构造 → 断言」，同一个对象再读一次不算。
- Share Extension 必须进行真实设备和模拟器验证；不能只凭主 App 编译成功，就认定分享功能正常。
- 每类 bug 写「它回来就会红」的用例，而不是「验证代码写对了」。
- 自动化测试跑什么、哪些必须手工验证，写清楚；没跑的验证在交付说明里写明。
- 示例文件：构建后验证 bundle 内 `SampleFiles/README.md`、`SampleFiles/CHANGELOG.md` 存在且与仓库根内容一致（T-59 接入后启用）。

## 17. 工程配置

以下以实际工程为准（已核对）：

| 配置 | 实际值 |
|---|---|
| 工程文件 | `OhMyFile.xcodeproj/project.xcproj`（JSON 风格文本、含尾逗号，不是 pbxproj） |
| Scheme | `OhMyFile` |
| App Bundle ID | `me.zzhhoo.OhMyFile` |
| 单元测试 Bundle ID | `me.zzhhoo.OhMyFileTests` |
| UI 测试 Bundle ID | `me.zzhhoo.OhMyFileUITests` |
| Team | `9DU6DRLH3R`（Automatic signing） |
| App Deployment Target | `$(RECOMMENDED_IPHONEOS_DEPLOYMENT_TARGET)`（当前解析为 17.0；与测试 target 的 27.2 不一致） |
| 测试 Deployment Target | 硬编码 `27.2` |
| Swift Language Version | `5.0`（Swift 5 语言模式） |
| 并发默认隔离 | `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`，`SWIFT_APPROACHABLE_CONCURRENCY = YES` |
| Supported Destinations | iPhone + iPad（`TARGETED_DEVICE_FAMILY = 1,2`，`SDKROOT = iphoneos`） |
| 支持方向 | iPhone：竖 + 横；iPad：四个方向 |
| App 版本 | `MARKETING_VERSION = 0.0.1`，`CURRENT_PROJECT_VERSION = 1` |
| App Groups / Share Extension / Entitlements | 均未创建 |
| Info.plist | 无独立文件（`GENERATE_INFOPLIST_FILE = YES`，键写在 build settings） |
| 第三方依赖 | 无；规划接入 SwiftUtils（优先复用）与 CrashKit（崩溃收集） |
| 示例文件 | 规划：构建时把仓库根 `README.md`、`CHANGELOG.md` 复制进 App bundle 的 `SampleFiles/`；尚未接入（TODO T-59） |

### 修改规则

- 不要擅自修改 Bundle Identifier、Team。
- 不要擅自提高或降低 Deployment Target。
- 不要随意更改签名和 Entitlements。
- 不要随意删除 Target。
- 不要擅自修改 App Groups。
- 修改项目配置前必须理解其影响范围；不要假设不同 Target 使用相同的配置。
- 需要修改多个 Target 时，必须逐一检查其配置。
- 工程文件是 JSON 风格文本（`project.xcproj`，含尾逗号）：不要用 jq / plutil / 严格 JSON 解析器或 pbxproj 工具直接改；手动修改前先备份，改完确认 `xcodebuild -list` 仍能解析、Xcode 能打开。
- 不要把 `README.md` / `CHANGELOG.md` 手动复制进源码目录；接入后它们作为构建产物随 App 打包，仓库根是唯一来源。修改这两个文件后要重新构建，bundle 内副本才会更新。

## 18. 已知限制与坑

1. **最低系统版本随 Xcode 浮动**：app target 用 `$(RECOMMENDED_IPHONEOS_DEPLOYMENT_TARGET)`（当前解析为 17.0）；项目级和测试 target 硬编码 `27.2`，两者不一致。升级 Xcode 后 app 的最低版本会静默改变，测试 target 不会跟着变。改 Deployment Target 先问用户。
2. **主线程默认隔离**：app target 默认开启 `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`（项目级与测试 target 没有）。回调式 API（`URLSession` 回调、文件协调、`AVFoundation` 通知等）在后台线程回调时，闭包隐式继承的 MainActor 隔离会触发运行时 trap（编译通过）。新代码用 `async` API；写回调参数标 `@Sendable`，或调用点标 `nonisolated`。
3. **没有 Share Extension / App Groups**：分享能力和相关规则（§6）尚未落地，不要假设 target、entitlements 或 `Info.plist` 里的分享声明存在。
4. **没有 macOS target**：`SDKROOT = iphoneos`、`TARGETED_DEVICE_FAMILY = 1,2`；macOS 支撑是规划，不是现状。不要写 `#if os(macOS)` 分支却无法验证。
5. **`.gitignore` 已覆盖构建产物**：`/build/`、`/DerivedData/`、`/.build/`、`xcuserdata/`、`.DS_Store` 已忽略，`.build/DerivedData` 只是本地构建产物，不要提交。注意 `xcuserdata/xcschememanagement.plist`（`OhMyFile.xcodeproj/xcuserdata/zzh.xcuserdatad/xcschemes/`）在加规则前就已被 Git 跟踪，`.gitignore` 不会取消跟踪；要移出需 `git rm --cached`（git 写操作，先问用户，见 TODO.md 的「工程卫生」条目）。
6. **命令行构建被沙盒拒绝**：`xcodebuild` 调起的 `swift-plugin-server` 无法 `sandbox-exec`（`sandbox_apply: Operation not permitted`），导致 `#Preview` 宏报 `PreviewsMacros.SwiftUIView could not be found`。这是 agent 沙盒限制，不是代码错误；在 Xcode GUI 里构建，或对构建命令放开文件访问权限后重试。
7. **Swift 5 语言模式**：`SWIFT_VERSION = 5.0`，但已启用 `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`、`SWIFT_APPROACHABLE_CONCURRENCY`、`SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY`。迁移到 Swift 6 语言模式会改变全局并发检查，属跨文件改动，先出方案。
8. **版本号两处**：app target 的 `MARKETING_VERSION` 是真实版本（0.0.1）；测试 target 的 `1.0` 无实际含义。改版本只改 app target，且先问用户（§2）。
9. **没有 File Provider Extension target**：系统「文件」App 里出现 OhMyFile 需要新增 File Provider Extension 与对应 entitlements；新增 Target 属跨 Target 改动，先出方案并征得同意。
10. **示例文件尚未接入构建**：README.md、CHANGELOG.md 目前只存在于仓库；接入后要保证 bundle 内 `SampleFiles/` 副本与仓库根一致，改文档后重新构建，不在源码目录留副本。
11. **CrashKit / SwiftUtils 尚未接入**：当前工程没有 SPM 依赖；接入需新增 Package 依赖与对应配置，属依赖变更，先出方案并征得同意。

## 19. 开发工作流程与收尾

### 开始前

1. 检查项目目录和现有代码。
2. 理解当前架构。
3. 检查相关 Target。
4. 确认最低系统版本。
5. 检查相关 API 的可用性。
6. 明确需求影响范围。
7. 判断这次要不要出方案（§2）；要，就先出方案再动文件。

### 实现时

1. 保持修改范围最小。
2. 优先复用现有实现。
3. 避免无关重构。
4. 考虑错误处理和边界情况。
5. 适当增加测试。
6. 尽可能验证编译。
7. 更新必要的项目文档。

### 不要

- 未经要求重写整个项目。
- 引入没有必要的第三方库。
- 擅自改变产品方向或删除已有功能。
- 未经验证声称功能已经完成。

### 收尾

- [ ] 做完的已从 `TODO.md` 移走，新发现的已记进 `TODO.md`。
- [ ] `CHANGELOG.md` 有对应用户视角条目（纯内部改动可没有）。
- [ ] 验证真跑过（命令 + 结果）；没跑的在回复里说明。
- [ ] git 操作都征得过同意，没有未说明的残留改动。
- [ ] 没有擅自改版本号、切版本段或打 tag。
- [ ] 回复说清：改了什么、没做什么、下一步 / 待决定。

## 20. 最终原则

OhMyFile 的核心链路：

**Share → Preview → Share**

Edit 是后续能力，不阻塞预览链路。

开发时优先保证：文件接收可靠、预览快速、打开体验优秀；之后才轮到编辑安全与保存正确。iPadOS 和 macOS 可以合理扩展。

保持架构简单、代码清晰、功能可靠。不要为了未来可能出现的需求，提前引入不必要的复杂性。
