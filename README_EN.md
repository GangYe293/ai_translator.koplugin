# AI Translator Plugin for KOReader

[简体中文](./README.md) | **English**

A multi-engine translation plugin for KOReader. It ships with **Microsoft Edge Translate built in — completely free, no API key, works out of the box** — and also supports DeepL, DeepSeek, Zhipu GLM-4 Flash (free tier), SiliconFlow, and any OpenAI-compatible endpoint.

The plugin does not modify a single line of KOReader source. It takes over KOReader's built-in translation entry points at runtime, so your existing gestures — long-press, text selection, dictionary and highlight menus — stay exactly the same. Only the engine behind them changes.

## Features

- **7 engines**: Google (native), DeepL, DeepSeek, Zhipu GLM-4 Flash, SiliconFlow, generic OpenAI-compatible, Microsoft Edge
- **One-tap on/off switch**: *Tools → AI Translator → Enable plugin* — untick to hand translation straight back to KOReader's native implementation, tick to take over again. No restart, no uninstall
- **Genuinely free options**: Microsoft Edge needs no key at all; Zhipu GLM-4 Flash is free after sign-up
- **Non-invasive takeover**: patches both `Translator.translate/showTranslation` and `ReaderHighlight.showTranslation`
- **Reusable results**: the result dialog offers *Save translation to note* and *Copy translation*
- **Network resilience**: a uniform 60 s block timeout plus up to 5 retries with exponential backoff; offline requests are queued by NetworkMgr and resumed when the connection returns
- **One-tap self-check**: *Tools → AI Translator → Test configuration* sends Hello World plus a page-length passage to the active engine and reports timings, output and errors
- **Visible diagnostics**: on failure the dialog shows the full trace — endpoint, status code, request/response body — with the API key masked
- **Persistent settings**: everything is stored in KOReader's native `G_reader_settings` (`settings.reader.lua`) and survives upgrades
- **Online updates**: *Tools → AI Translator → About → Check for updates* pulls the latest release from GitHub, verifies SHA-256, backs up the old version and rolls back on failure
- **Auto-placed menu**: the entry is inserted right after the statistics item under *Tools*, in both the file manager and the reader

## Engine comparison

| Engine | Cost | API key | Default endpoint / model |
| --- | --- | --- | --- |
| Microsoft Edge | Free | No | `https://edge.microsoft.com/translate/translatetext` |
| Zhipu GLM-4 Flash | Free (rate limited) | Yes (free) | `https://open.bigmodel.cn/api/paas/v4` · `glm-4-flash` |
| SiliconFlow | Free tier available | Yes | `https://api.siliconflow.cn/v1` · `Qwen/Qwen2.5-72B-Instruct` |
| DeepSeek | Paid | Yes | `https://api.deepseek.com` · `deepseek-chat` (default; type any model name) |
| Generic OpenAI-compatible | Depends on provider | Yes | Custom base URL + model name |
| DeepL | Free plan 500k chars/month, Pro paid | Yes | `https://api-free.deepl.com` / `https://api.deepl.com` |
| Google | Free | No | KOReader's native implementation |

## Installation

1. Download or clone this repository and locate the `ai_translator.koplugin` directory.
2. Copy the whole directory into KOReader's `koreader/plugins/`:

   ```
   koreader/plugins/ai_translator.koplugin/
   ├── _meta.lua
   ├── main.lua
   ├── ...
   ```

   > Do not create an extra nesting level (`plugins/ai_translator.koplugin/ai_translator.koplugin/…` will not be loaded).
3. **Restart KOReader** — the takeover happens at plugin init time.

Requirements: a reasonably recent KOReader build (relies on `ui/trapper`, `ui/translator` and `socketutil`); 2024.01 or newer is recommended. Network access is required.

## Usage

### 1. Enable / disable the plugin

*Tools → AI Translator → Enable plugin*:

- **Ticked (default)**: the plugin takes over `Translator` and `ReaderHighlight`, so all translation goes through the engine you picked.
- **Unticked**: both entry points are restored to KOReader's native implementation (Google Translate) immediately; the plugin stays out of every translation path. The menu remains, so you can tick it back at any time.

The switch is stored as `ai_translator_enabled` in `settings.reader.lua` and survives restarts. When the key is absent — a fresh install, or an upgrade from an older version — the plugin is treated as **enabled**, so nothing changes for existing users.

> Just want native translation back? Use the switch instead of uninstalling; delete the directory only when you want it gone for good.

### 2. Pick an engine

*Tools → AI Translator → Current: xxx* and choose:

- Want it working right now with no sign-up? → **Microsoft Edge Translate**
- Want an LLM with more natural wording? → **Zhipu GLM-4 Flash** (free), DeepSeek, or SiliconFlow

The change is applied immediately, no restart needed; if some entry point still uses the old engine, restart KOReader once.

### 3. Configure your key

Under *Tools → AI Translator*, engines are grouped by cost:

- **Free**: Zhipu GLM settings, SiliconFlow settings
- **Paid**: DeepL settings, DeepSeek settings, Generic OpenAI settings

Each engine exposes up to three fields: API key, base URL, model name (DeepL instead offers Free/Pro API switching). Clearing a field restores the built-in default. Where to get keys:

- Zhipu: https://open.bigmodel.cn/usercenter/apikeys
- SiliconFlow: https://cloud.siliconflow.cn
- DeepSeek: https://platform.deepseek.com/
- DeepL: https://www.deepl.com/pro-api

### 4. Translate

Keep your usual habits:

- Select text by long-press or drag, then choose *Translate* from the popup menu
- Results appear in a dialog with source and target stacked (`▣` source / `●` translation)
- Bottom buttons: **Save translation to note** (writes into the highlight's note) and **Copy translation** (clipboard)

The target language follows KOReader's UI language by default, and can also be pinned in KOReader's own *Translation* settings.

### 5. Test configuration

*Tools → AI Translator → Test configuration* sends a real request to the **currently selected engine**, so you can tell in seconds whether the setup works and whether it survives a full page.

The report contains:

- engine, endpoint, model, whether an API key is configured, target language;
- **short text**: `Hello World` — validates key, balance, network and model name;
- **long text**: roughly 2000 characters (about one page) — validates timeouts and model context;
- per-test timing plus full error details, and a verdict at the end.

Reading the verdict:

| Symptom | Meaning |
| --- | --- |
| short OK, long fails | usually a timeout (slow network / slow model) or too small a context window |
| short fails too | key, balance, model name or network — the error detail carries the HTTP status |
| both OK | the engine is fine for full-page translation |

> The check does spend one or two real requests (Edge is free, so it costs nothing). When the short test fails the long one is skipped — faster, and it saves quota.

### 6. Online updates

*Tools → AI Translator → About*:

| Item | Purpose |
| --- | --- |
| Version: x.y.z | Shows the current version; tap for the project URL and Releases page |
| Author: GangYe293 | Project home page |
| Xiaohongshu ID: 老王的生活指南 | The author's Xiaohongshu account (KOReader plugins & e-book tips) |
| Check for updates | Asks GitHub for the latest release once; only speaks up when something is newer |

Updates are manual-only as of v1.2.1 (the daily check toggle was removed): nothing goes online unless you tap *Check for updates*.

Install flow: download `ai_translator-<version>.zip` → verify size and SHA-256 → extract into a staging directory outside the plugin → verify the `_meta.lua` version → rename the old directory to `ai_translator.koplugin.backup` and move the new one in place → offer a restart.

- **A failed step never touches the plugin directory**: download, size check, checksum, extraction and version check all bail out before the swap.
- **The backup is kept until the new version actually starts**: if the new code crashes on load, the `.backup` next to it is the way back.
- **Mirror fallback**: when GitHub is unreachable, gh-proxy / ghfast / ghproxy are tried in turn; the package is the very Release asset.
- Only code is replaced — settings (keys, engine choice in `settings.reader.lua`) are untouched.

## Project layout

```
ai_translator.koplugin/
├── _meta.lua                     # Plugin metadata (name, description) read by KOReader's plugin manager
├── main.lua                      # Entry point: menu registration, engine dispatch, Translator/Highlight patching
├── insert_menu.lua               # Inserts the menu item after `statistics` under Tools
├── ai_translator_update.lua     # Updater: fetch release, verify, back up and swap
├── ai_translator_update_ui.lua  # About menu and update dialogs
├── ai_translator_sha2.lua       # SHA-256 (only used to verify update packages)
├── edge_translator.lua           # Microsoft Edge Translate (no key required)
├── glm_translator.lua            # Zhipu GLM-4 Flash (OpenAI-compatible)
├── siliconflow_translator.lua    # SiliconFlow (OpenAI-compatible)
├── deepseek_translator.lua       # DeepSeek (OpenAI-compatible)
├── openai_translator.lua         # Generic OpenAI-compatible endpoint
└── deepl_translator.lua          # DeepL official REST API (not OpenAI-compatible)
```

## Design

### 1. Engine abstraction: three shared methods

Every engine module is a standalone Lua table exposing the same interface:

| Method | Purpose |
| --- | --- |
| `translate(text, target_lang, source_lang)` | Plain text translation, returns the translated string |
| `showTranslation(...)` | Shows the result dialog (network check + Trapper wrapping) |
| `genSettingsMenu()` | Returns its own settings submenu for `main.lua` to assemble |

Internally each one implements `loadPage()` (send request, parse response), `getApiKey()`, `getModel()`, `getTargetLanguage()` and `getLanguageName()`. Adding an engine means adding one file plus two branches in `main.lua` — **no other engine is touched**.

### 2. Takeover, not replacement: monkey patching

KOReader has two translation entry points: `ui/translator` (dictionary / menu calls) and `ReaderHighlight.showTranslation` (after text selection). At `init()` the plugin swaps both for the active engine's implementation and keeps the originals:

```
switch off       →  restore originals (as if the plugin were not installed)
engine == google →  restore originals, use KOReader's native Google Translate
engine == other  →  swap in that engine's translate / showTranslation
```

Benefits: zero changes to KOReader source, uninstalling restores everything, and all upstream logic — selection, notes, long-press menus — is reused as is.

The originals are captured **once, in module-level variables** (`original_translate` / `original_showTranslation` / `original_highlightShowTranslation`), so restoring is deterministic: both the switch and picking Google point the entries back at those three functions, with no leftover takeover.

> Why module-level matters: the plugin is instantiated twice (file manager and reader). If the originals lived on the instance, the file-manager instance would patch first and the reader instance would then record **that patch** as the "original" — unticking inside a book would restore the patch instead of the native implementation. A module-level variable is process-wide, so the first capture is always the real original.

Toggling re-patches (or restores) immediately, and on the next start `ai_translator_enabled` decides the initial state. Every takeover/restore logs at `logger.info`, so the lines are visible in `crash.log` on the device.

### 3. Networking and interaction

- Requests use KOReader's bundled LuaSocket (`socket.http` + `ltn12` + `socketutil`); no new dependency
- `socketutil:set_timeout()` sets the timeout (30 s for Edge, 60 s for LLM engines) and `reset_timeout()` restores it
- `wantread` / `timeout` errors are retried up to 3–5 times with growing backoff
- Results are rendered inside `Trapper:wrap()` with an interruptible waiting dialog; when offline, `NetworkMgr:willRerunWhenOnline()` re-runs the request automatically once connectivity is back

### 4. Observability

Each `loadPage()` appends the endpoint, request body, status code and response body to a `debug_info` buffer as it runs. On failure that buffer is shown directly in the dialog (API keys are truncated to the first 8 characters), and mirrored to the KOReader log via `logger.dbg` — so debugging a bad config rarely needs a packet capture.

### 5. Settings storage

Everything goes through `G_reader_settings`, with per-engine key prefixes so engines never interfere:

| Engine | Keys |
| --- | --- |
| Global | `translator_engine` (`google`/`deepl`/`deepseek`/`openai`/`glm`/`siliconflow`/`edge`) |
| Global | `ai_translator_enabled` (`true`/`false`, absent means `true`) |
| Global | `ai_translator_update` (updater state: `available_version`, `checked_at`, `auto_check`, `last_error`) |
| Zhipu | `glm_api_key`, `glm_base_url`, `glm_model` |
| SiliconFlow | `siliconflow_api_key`, `siliconflow_base_url`, `siliconflow_model` |
| DeepSeek | `deepseek_api_key`, `deepseek_base_url`, `deepseek_model` |
| OpenAI | `openai_api_key`, `openai_base_url`, `openai_model` |
| DeepL | `deepl_api_key`, `deepl_api_type` (`free`/`pro`) |

Saving an empty value calls `delSetting`, falling back to the default.

## Troubleshooting

**Dialog says "API key not configured"** → fill in the key in that engine's settings menu, and make sure that engine is the one selected in the main menu.

**HTTP 401** → the key is wrong or expired; regenerate it and paste again (watch for stray spaces).

**HTTP 429** → rate limit hit, common on free models such as GLM-4 Flash; wait and retry.

**Spins forever with no result** → check the connection; LLM engines time out after 60 s per request, so split long passages.

**A paragraph translates but a whole page does not** → run *Test configuration* first. This is usually the time-to-first-byte on long input exceeding the network timeout (before v1.1.2 the SiliconFlow engine used a 5-second block timeout and had no retries at all), and occasionally a context-window limit. All engines now use a 60 s block timeout with up to 5 backoff retries.

**"Check for updates" says the network failed** → Kindles often cannot reach GitHub. The updater tries the direct connection and three mirrors; if all fail, install the Release asset manually.

**The UI still looks like the old version after updating** → the update only replaces files on disk; restart KOReader to load the new code. Use *Restart now* in the dialog shown after installation.

**Nothing changed after switching engines** → first make sure *Enable plugin* is ticked; engine picks are ignored while the plugin is disabled. If it still does not change, restart KOReader and confirm no other translation plugin is patching `Translator` at the same time.

**Does the plugin still take over after unticking "Enable plugin"?** → No. Unticking immediately restores `Translator.translate`, `Translator.showTranslation` and `ReaderHighlight.showTranslation` to their original implementations, and translation runs entirely on KOReader's native path afterwards.

**Want the full error** → the failure dialog contains it, and the KOReader log can be searched for `AI翻译`, `GLM request` or `Edge request`.

## References and credits

- [KOReader](https://github.com/koreader/koreader) — host application; the plugin mechanism, `ui/translator`, `Trapper` and `NetworkMgr` all come from its official modules
- [enneaa/dualtranslate.koplugin](https://github.com/enneaa/dualtranslate.koplugin) — bilingual translation plugin; the Microsoft Edge public endpoint is called the same way
- [Zhipu AI Open Platform](https://open.bigmodel.cn) / [SiliconFlow](https://siliconflow.cn) / [DeepSeek](https://www.deepseek.com) / [DeepL](https://www.deepl.com) — APIs and documentation

## Notes

- Third-party endpoints used here (especially the public Microsoft Edge endpoint) are unofficial; their stability and quotas are decided by the providers. Please use them reasonably.
- API keys are stored locally in KOReader's settings file on your device — do not share that file publicly.

## Changelog

### v1.2.1

- *Test configuration* now supports the **native Google engine**: probes KOReader's built-in `Translator:translate` with a real request instead of reporting "not supported"
- DeepSeek settings menu aligned with wordgloss.koplugin: removed the *DeepSeek Chat / Reasoner* picker (translation does not need a reasoning chain); the model name is now a free-text field (default `deepseek-chat`); the key status moved into the *API key* item title
- *About* menu: added **Xiaohongshu ID: 老王的生活指南** under the author; removed the daily auto-check toggle — updates are manual-only
- Regression suite: 85 + 100 assertions passing

### v1.2.0

- Added **online updates** (*About → Check for updates*): downloads from GitHub Releases, verifies size + SHA-256, backs up the previous version and rolls back on failure
- Added *Check once a day* (off by default; notify only, never auto-install)
- Added the *About* submenu: version, author, check for updates, daily check toggle
- Update verification uses a pure-Lua SHA-256 that runs on both LuaJIT and Lua 5.3
- Automatic mirror fallback (gh-proxy / ghfast / ghproxy) when GitHub is unreachable
- Backup cleanup now checks the running version against `_meta.lua` on disk, so declining the restart and opening another book cannot delete the rollback copy
- Regression suite: 73 + 96 assertions passing

### v1.1.3

- Fixed: the "Test configuration" report showed "◆◈" garbage after the long-text sample. The report truncated the sample **by bytes**, which can cut a multi-byte UTF-8 character in half; the device font renders the dangling bytes as boxes. Truncation is now UTF-8-safe (backs up to a complete character boundary, 4-byte emoji included). The translation content itself was never affected

### v1.1.2

- **Fixed: SiliconFlow failed on full-page translation** (a selection worked, a page did not). Root cause: `socketutil:set_timeout()` without arguments sets a **5-second** block timeout, and this engine had no retries at all; it now uses 60 s plus 5 backoff retries
- SiliconFlow now splits the prompt into system/user messages and respects the target language (it used to hardcode "translate into Chinese")
- SiliconFlow logs the input length and error code on failure, so `crash.log` on the device is enough to diagnose it
- DeepL and the generic OpenAI engine also moved from the 5-second default to 60 s
- Added the *Test configuration* menu (below *Paid*): sends Hello World plus a page-length passage to the active engine and reports timing, output and full error details
- Engine metadata (name / endpoint / model) consolidated into one shared table used by both the menu and the test
- Regression suite grew from 41 to 66 assertions

### v1.1.1

- Fixed: unticking *Enable plugin* inside the reader still used Edge (the old code recorded the previous patch as the "original", so restoring was a no-op)
- Originals now live in module-level variables and are captured once; added `translator_patched` / `highlight_patched` guards so we never restore something we did not patch
- No longer invent a dead `ReaderHighlight.showTranslation` method on versions that do not have one
- Takeover / restore / engine-switch events log at `logger.info` so they can be verified in `crash.log`

### v1.1.0

- Added the *Enable plugin* switch (*Tools → AI Translator → Enable plugin*): tick to take over, untick to restore — no restart, no uninstall
- The switch persists as `ai_translator_enabled`; absence of the key means enabled, so upgrades are seamless
- Engine selection now applies immediately, and reports clearly when the plugin is disabled instead of claiming "enabled"
- The engine submenu title shows "Current: xxx (plugin disabled)" while the plugin is off
