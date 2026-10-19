# AI 翻译插件 for KOReader

**简体中文** | [English](./README_EN.md)

一个给 KOReader 用的多引擎翻译插件。内置 **Microsoft Edge 免费翻译（零配置、无需 API Key，开箱即用）**，同时支持 DeepL、DeepSeek、智谱 GLM-4 Flash（免费）、硅基流动，以及任意 OpenAI 兼容接口。

插件不改 KOReader 源码，而是在运行时接管其内置翻译入口，因此你原有的划词翻译、词典、长按菜单等操作方式完全不变，只是背后换了个翻译引擎。

## 特性

- **7 个引擎可选**：Google（原生）、DeepL、DeepSeek、智谱 GLM-4 Flash、硅基流动、通用 OpenAI 兼容、Microsoft Edge
- **一键启用 / 停用**：`工具 → AI 翻译 → 启用插件`，取消勾选立即把翻译还给 KOReader 原生实现，勾选立即接管，不用重启、不用卸载
- **完全免费选项**：Microsoft Edge 无需任何密钥；智谱 GLM-4 Flash 注册即送免费额度
- **零侵入接管**：同时接管 `Translator.translate/showTranslation` 与划词高亮的 `ReaderHighlight.showTranslation`
- **结果可复用**：翻译弹窗支持「保存翻译到笔记」与「复制翻译」，译文可直接写入高亮笔记
- **网络容错**：内置 3~5 次重试与指数退避，离线时通过 NetworkMgr 自动排队，联网后继续执行
- **可视化排错**：失败时弹出完整的调试信息（端点、状态码、请求/响应体，密钥自动脱敏）
- **配置持久化**：所有配置写入 KOReader 原生 `G_reader_settings`（`settings.reader.lua`），升级不丢
- **菜单自动归位**：自动插到「工具」菜单里统计项之后，文件管理器和阅读器两处都有入口

## 引擎对比

| 引擎 | 费用 | 需要 API Key | 默认端点 / 模型 |
| --- | --- | --- | --- |
| Microsoft Edge | 免费 | 否 | `https://edge.microsoft.com/translate/translatetext` |
| 智谱 GLM-4 Flash | 免费（有速率限制） | 是（免费领取） | `https://open.bigmodel.cn/api/paas/v4` · `glm-4-flash` |
| 硅基流动 | 有免费额度 | 是 | `https://api.siliconflow.cn/v1` · `Qwen/Qwen2.5-72B-Instruct` |
| DeepSeek | 付费 | 是 | `https://api.deepseek.com` · `deepseek-chat` / `deepseek-reasoner` |
| 通用 OpenAI 兼容 | 取决于服务商 | 是 | 自建 Base URL + 模型名 |
| DeepL | 免费版 50 万字符/月，Pro 付费 | 是 | `https://api-free.deepl.com` / `https://api.deepl.com` |
| Google | 免费 | 否 | KOReader 原生实现 |

## 安装

1. 下载或克隆本仓库，得到 `ai_translator.koplugin` 目录。
2. 把整个目录拷进 KOReader 的 `koreader/plugins/`：

   ```
   koreader/plugins/ai_translator.koplugin/
   ├── _meta.lua
   ├── main.lua
   ├── ...
   ```

   > 注意不要多套一层目录（`plugins/ai_translator.koplugin/ai_translator.koplugin/…` 不会被加载）。
3. **重启 KOReader**（插件在启动时完成引擎接管，热启用不彻底）。

要求：较新的 KOReader 版本（依赖 `ui/trapper`、`ui/translator`、`socketutil`），建议使用 2024.01 及以上。设备需能联网。

## 使用

### 1. 启用 / 停用插件

`工具 → AI 翻译 → 启用插件`：

- **勾选（默认）**：插件接管 `Translator` 与 `ReaderHighlight` 的翻译入口，划词翻译、词典翻译走你选中的引擎。
- **取消勾选**：立刻把两个入口还原成 KOReader 原生实现（Google 翻译），插件不再介入任何翻译流程；菜单保留，随时勾回来即可。

开关写进 `settings.reader.lua` 的 `ai_translator_enabled`，重启后保持。首次安装未写过该键时按**启用**处理，老用户升级行为不变。

> 只是想换回原生翻译？用这个开关比卸载插件更省事；想彻底移除再删目录。

### 2. 选择引擎

`工具 → AI 翻译 → 当前：xxx`，选择你想用的引擎：

- 想立刻用、不想申请密钥 → **Microsoft Edge 免费翻译**
- 想用大模型、翻译更有"人味" → **智谱 GLM-4 Flash**（免费）或 DeepSeek / 硅基流动

切换后立即接管，无需重启；若某处入口仍走旧引擎，重启 KOReader 即可。

### 3. 配置密钥

`工具 → AI 翻译` 下按费用分了两组：

- **免费**：智谱 GLM 设置、硅基流动设置
- **收费**：DeepL 设置、DeepSeek 设置、通用 OpenAI 设置

每个引擎一般有三项：API 密钥、Base URL、模型名（DeepL 为 Free/Pro API 切换）。留空即恢复默认值。密钥获取地址：

- 智谱：https://open.bigmodel.cn/usercenter/apikeys
- 硅基流动：https://cloud.siliconflow.cn
- DeepSeek：https://platform.deepseek.com/
- DeepL：https://www.deepl.com/pro-api

### 4. 翻译

保持你原有的操作习惯即可：

- 长按或拖动选中文本 → 在弹出菜单里选「翻译」
- 翻译结果会以弹窗展示，原文与译文上下对照（`▣` 原文 / `●` 译文）
- 弹窗底部按钮：**保存翻译到笔记**（写入该高亮的笔记）、**复制翻译**（写入剪贴板）

目标语言默认跟随 KOReader 界面语言，也可在 KOReader 自带的「翻译」设置里指定。

## 目录结构

```
ai_translator.koplugin/
├── _meta.lua                     # 插件元信息（名称、描述），KOReader 插件管理器读取
├── main.lua                      # 入口：注册菜单、引擎分发、Translator/Highlight 接管
├── insert_menu.lua               # 把菜单项插到「工具」菜单中 statistics 之后
├── edge_translator.lua           # Microsoft Edge 免费翻译（无需密钥）
├── glm_translator.lua            # 智谱 GLM-4 Flash（OpenAI 兼容）
├── siliconflow_translator.lua    # 硅基流动（OpenAI 兼容）
├── deepseek_translator.lua       # DeepSeek（OpenAI 兼容）
├── openai_translator.lua         # 通用 OpenAI 兼容接口
└── deepl_translator.lua          # DeepL 官方 REST API（非 OpenAI 兼容）
```

## 设计思路

### 1. 引擎抽象：统一的三个方法

每个引擎模块都是一张独立的 Lua table，对外只暴露同一组接口：

| 方法 | 作用 |
| --- | --- |
| `translate(text, target_lang, source_lang)` | 纯文本翻译，返回译文字符串 |
| `showTranslation(...)` | 弹出结果窗口（含网络检查、Trapper 包裹） |
| `genSettingsMenu()` | 返回自己的设置子菜单，供 `main.lua` 拼装 |

内部则各自实现 `loadPage()`（发请求、解析响应）、`getApiKey()`、`getModel()`、`getTargetLanguage()`、`getLanguageName()`。新增一个引擎 = 新增一个文件 + 在 `main.lua` 里加两个分支，**不需要改动其它引擎**。

### 2. 接管而非替换：monkey patch

KOReader 内置翻译入口有两个：`ui/translator`（词典/菜单调用）和 `ReaderHighlight.showTranslation`（划词后调用）。插件在 `init()` 时把这两个模块的关键方法替换成当前引擎的实现，并把原始方法存起来：

```
开关关闭        →  还原原方法（等价于没装插件）
引擎 == google  →  还原原方法，走 KOReader 原生 Google 翻译
引擎 == 其它    →  替换为对应引擎的 translate / showTranslation
```

好处：不用改 KOReader 一行源码，卸载插件即恢复原状；划词、笔记、长按菜单等上层逻辑全部复用。

原始方法在 `init()` 里先存进 `original_translate` / `original_showTranslation` / `original_highlightShowTranslation`，所以「还原」是确定性的：菜单开关或选 Google 都会把指针指回这三个原始函数，不存在残留接管。开关切换时会立刻重新 patch 或还原一次，无需重启；重启后按 `ai_translator_enabled` 决定初始状态。

### 3. 网络与交互

- 请求用 KOReader 自带的 LuaSocket（`socket.http` + `ltn12` + `socketutil`），不引入新依赖
- `socketutil:set_timeout()` 设置超时（Edge 30s，LLM 引擎 60s），结束后 `reset_timeout()` 复原
- 对 `wantread` / `timeout` 类错误最多重试 3~5 次，退避间隔逐步放大
- 结果展示走 `Trapper:wrap()`，配合可中断的等待提示；离线时 `NetworkMgr:willRerunWhenOnline()` 会在恢复联网后自动重跑

### 4. 可观测性

每个 `loadPage()` 都边跑边往 `debug_info` 里追加端点、请求体、状态码、响应体。失败时这些信息直接以弹窗展示（API Key 只显示前 8 位），配合 `logger.dbg` 输出到 KOReader 日志，排查配置错误基本不用抓包。

### 5. 配置存储

全部走 `G_reader_settings`，键名按引擎前缀隔离，互不干扰：

| 引擎 | 键 |
| --- | --- |
| 全局 | `translator_engine`（`google`/`deepl`/`deepseek`/`openai`/`glm`/`siliconflow`/`edge`） |
| 全局 | `ai_translator_enabled`（`true`/`false`，缺省视为 `true`） |
| 智谱 | `glm_api_key`、`glm_base_url`、`glm_model` |
| 硅基流动 | `siliconflow_api_key`、`siliconflow_base_url`、`siliconflow_model` |
| DeepSeek | `deepseek_api_key`、`deepseek_base_url`、`deepseek_model` |
| OpenAI | `openai_api_key`、`openai_base_url`、`openai_model` |
| DeepL | `deepl_api_key`、`deepl_api_type`（`free`/`pro`） |

留空保存会自动 `delSetting`，回落到默认值。

## 常见问题

**翻译弹窗报「API 密钥未配置」** → 在对应引擎的设置菜单里填密钥，并确认主菜单当前选中的是该引擎。

**HTTP 401** → 密钥错误或已失效，重新生成并粘贴（注意别带空格）。

**HTTP 429** → 触发速率限制，免费模型（GLM-4 Flash）尤其常见，稍等再试。

**一直在转圈没结果** → 检查网络；LLM 类引擎单次 60s 超时，长文本建议分段翻译。

**切换引擎后没变化** → 先确认「启用插件」是勾选状态；插件被停用时会忽略引擎选择。仍无变化就重启 KOReader，并确认没有其它翻译类插件同时接管了 `Translator`。

**取消「启用插件」后还会被接管吗** → 不会。取消勾选会立即把 `Translator.translate`、`Translator.showTranslation`、`ReaderHighlight.showTranslation` 三个指针还原成原始实现，之后翻译完全走 KOReader 原生逻辑。

**想看详细报错** → 失败弹窗内就是调试信息，也可在 KOReader 日志里搜 `AI翻译`、`GLM request`、`Edge request`。

## 参考项目与致谢

- [KOReader](https://github.com/koreader/koreader) — 宿主程序，插件机制、`ui/translator`、`Trapper`、`NetworkMgr` 均来自其官方模块
- [enneaa/dualtranslate.koplugin](https://github.com/enneaa/dualtranslate.koplugin) — 双语对照翻译插件；Microsoft Edge 公共翻译接口的调用方式与之保持一致
- [Zhipu AI 开放平台](https://open.bigmodel.cn) / [SiliconFlow](https://siliconflow.cn) / [DeepSeek](https://www.deepseek.com) / [DeepL](https://www.deepl.com) — 各家翻译 API 与文档

## 说明

- 本插件调用的各第三方接口（尤其是 Microsoft Edge 公共端点）为非官方接口，稳定性与配额由服务商决定，请合理使用。
- API 密钥保存在设备本地的 KOReader 设置文件中，请勿在公开场合分享该文件。

## 更新记录

### v1.1.0

- 新增「启用插件」开关（`工具 → AI 翻译 → 启用插件`）：勾选即接管、取消即还原，无需重启或卸载
- 开关持久化到 `ai_translator_enabled`，未设置时默认启用，升级无感
- 引擎选择改为即时生效，并在插件停用时给出明确提示（不再误导为"已启用"）
- 停用状态下主菜单标题显示「当前：xxx（插件已停用）」
