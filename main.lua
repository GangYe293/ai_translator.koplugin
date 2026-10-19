--[[--
AI翻译

多翻译引擎插件，内置完全免费的 Microsoft Edge 翻译（无需API密钥），在中国提供更好的翻译质量。

@module koplugin.xiaosijitranslatorplugin
--]]

local DeepLTranslator = require("deepl_translator")
local DeepSeekTranslator = require("deepseek_translator")
local OpenAITranslator = require("openai_translator")
local GLMTranslator = require("glm_translator")
local SiliconFlowTranslator = require("siliconflow_translator")
local EdgeTranslator = require("edge_translator")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local ffiUtil = require("ffi/util")
local logger = require("logger")
local _ = require("gettext")
local T = ffiUtil.template

local xiaosijitranslatorplugin = WidgetContainer:extend{
    name = "ai_translator",
    is_doc_only = false,
}

-- 插件启用开关的设置键；未设置时视为启用（兼容老用户）
local ENABLED_SETTING_KEY = "ai_translator_enabled"

--[[--
原始方法只保存一次，而且必须保存在**模块级**，不能放在实例上。

插件在文件管理器和阅读器里各有一个实例（is_doc_only = false）。文件管理器实例
init 时就会接管 Translator；等打开书、阅读器实例 init 时，如果再去"保存原生
方法"，抓到的其实是文件管理器实例的补丁 —— 于是在书里取消启用只会还原成补丁
本身，看起来"取消失效、还是走 Edge"。模块级变量全进程唯一，第一次捕获到的
才是真正的原生实现。
]]
local original_translate
local original_showTranslation
local original_highlightShowTranslation

-- 当前是否由本插件接管中：没接管过就不要去还原，免得覆盖别的插件的补丁
local translator_patched = false
local highlight_patched = false
-- 被接管过的那个 ReaderHighlight 实例。在文件管理器里关开关时 self.ui.highlight
-- 是 nil，只能靠它把补丁还原回去。
local highlight_patched_target

function xiaosijitranslatorplugin:isEnabled()
    local value = G_reader_settings:readSetting(ENABLED_SETTING_KEY)
    if value == nil then
        return true
    end
    return value and true or false
end

local function captureTranslatorOriginals()
    if original_translate ~= nil then return end
    local Translator = require("ui/translator")
    original_translate = Translator.translate
    original_showTranslation = Translator.showTranslation
    logger.info("AI翻译: 已保存 Translator 原生方法")
end

local function captureHighlightOriginals(highlight)
    if original_highlightShowTranslation ~= nil then return end
    -- 部分 KOReader 版本没有 ReaderHighlight.showTranslation（划词翻译直接调
    -- 模块级 Translator.showTranslation），那就不要凭空造一个死方法出来。
    if not highlight or type(highlight.showTranslation) ~= "function" then return end
    original_highlightShowTranslation = highlight.showTranslation
    logger.info("AI翻译: 已保存 ReaderHighlight.showTranslation 原生方法")
end

function xiaosijitranslatorplugin:restoreTranslator()
    if not translator_patched then return end
    local Translator = require("ui/translator")
    if original_translate then
        Translator.translate = original_translate
    end
    if original_showTranslation then
        Translator.showTranslation = original_showTranslation
    end
    translator_patched = false
    logger.info("AI翻译: Translator 已还原为 KOReader 原生实现")
end

function xiaosijitranslatorplugin:restoreHighlight()
    if not highlight_patched then return end
    local highlight = highlight_patched_target or (self.ui and self.ui.highlight)
    if highlight and original_highlightShowTranslation then
        highlight.showTranslation = original_highlightShowTranslation
    end
    highlight_patched = false
    highlight_patched_target = nil
    logger.info("AI翻译: ReaderHighlight 已还原为 KOReader 原生实现")
end

-- 停用：把接管过的入口全部还原成 KOReader 原生实现
function xiaosijitranslatorplugin:restoreAll()
    self:restoreTranslator()
    self:restoreHighlight()
end

function xiaosijitranslatorplugin:init()
    self.ui.menu:registerToMainMenu(self)

    if not self:isEnabled() then
        -- 同进程里可能有别的实例先接管过，这里一并还原
        self:restoreAll()
        logger.info("AI翻译: 插件已停用（ai_translator_enabled=false），不做任何接管")
        return
    end

    self:patchTranslator()

    if self.ui.highlight then
        self:patchHighlightModule()
    end
end

function xiaosijitranslatorplugin:patchTranslator()
    local Translator = require("ui/translator")

    if not self:isEnabled() then
        self:restoreTranslator()
        return
    end

    captureTranslatorOriginals()

    local engine = G_reader_settings:readSetting("translator_engine") or "edge"
    if engine == "deepl" then
        logger.dbg("AI翻译: patching translator with DeepL")
        Translator.translate = function(self, text, target_lang, source_lang)
            return DeepLTranslator:translate(text, target_lang, source_lang)
        end

        Translator.showTranslation = function(self, text, detailed_view, source_lang, target_lang, from_highlight, index)
            return DeepLTranslator:showTranslation(text, detailed_view, source_lang, target_lang, from_highlight, index)
        end

        logger.dbg("AI翻译: DeepL translator patched successfully")
    elseif engine == "deepseek" then
        logger.dbg("AI翻译: patching translator with DeepSeek")
        Translator.translate = function(self, text, target_lang, source_lang)
            return DeepSeekTranslator:translate(text, target_lang, source_lang)
        end

        Translator.showTranslation = function(self, text, detailed_view, source_lang, target_lang, from_highlight, index)
            return DeepSeekTranslator:showTranslation(text, detailed_view, source_lang, target_lang, from_highlight, index)
        end

        logger.dbg("AI翻译: DeepSeek translator patched successfully")
    elseif engine == "openai" then
        logger.dbg("AI翻译: patching translator with OpenAI")
        Translator.translate = function(self, text, target_lang, source_lang)
            return OpenAITranslator:translate(text, target_lang, source_lang)
        end

        Translator.showTranslation = function(self, text, detailed_view, source_lang, target_lang, from_highlight, index)
            return OpenAITranslator:showTranslation(text, detailed_view, source_lang, target_lang, from_highlight, index)
        end

        logger.dbg("AI翻译: OpenAI translator patched successfully")
    elseif engine == "glm" then
        logger.dbg("AI翻译: patching translator with 智谱GLM")
        Translator.translate = function(self, text, target_lang, source_lang)
            return GLMTranslator:translate(text, target_lang, source_lang)
        end

        Translator.showTranslation = function(self, text, detailed_view, source_lang, target_lang, from_highlight, index)
            return GLMTranslator:showTranslation(text, detailed_view, source_lang, target_lang, from_highlight, index)
        end

        logger.dbg("AI翻译: 智谱GLM translator patched successfully")
    elseif engine == "siliconflow" then
        logger.dbg("AI翻译: patching translator with 硅基流动")
        Translator.translate = function(self, text, target_lang, source_lang)
            return SiliconFlowTranslator:translate(text, target_lang, source_lang)
        end

        Translator.showTranslation = function(self, text, detailed_view, source_lang, target_lang, from_highlight, index)
            return SiliconFlowTranslator:showTranslation(text, detailed_view, source_lang, target_lang, from_highlight, index)
        end

        logger.dbg("AI翻译: 硅基流动 translator patched successfully")
    elseif engine == "edge" then
        logger.dbg("AI翻译: patching translator with Microsoft Edge")
        Translator.translate = function(self, text, target_lang, source_lang)
            return EdgeTranslator:translate(text, target_lang, source_lang)
        end

        Translator.showTranslation = function(self, text, detailed_view, source_lang, target_lang, from_highlight, index)
            return EdgeTranslator:showTranslation(text, detailed_view, source_lang, target_lang, from_highlight, index)
        end

        logger.dbg("AI翻译: Microsoft Edge translator patched successfully")
    else
        logger.info("AI翻译: 使用 KOReader 原生 Google 翻译")
        self:restoreTranslator()
        return
    end

    translator_patched = true
    logger.info("AI翻译: 已接管翻译入口，引擎 = " .. tostring(engine))
end

function xiaosijitranslatorplugin:patchHighlightModule()
    local ReaderHighlight = self.ui and self.ui.highlight
    if not ReaderHighlight then
        return
    end

    if not self:isEnabled() then
        self:restoreHighlight()
        return
    end

    -- 部分 KOReader 版本没有 ReaderHighlight.showTranslation（划词翻译直接调
    -- 模块级 Translator.showTranslation），此时不要凭空造一个永远不会被调用的方法。
    if type(ReaderHighlight.showTranslation) ~= "function" then
        return
    end

    captureHighlightOriginals(ReaderHighlight)

    local engine = G_reader_settings:readSetting("translator_engine") or "edge"

    if engine == "deepl" then
        logger.dbg("AI翻译: patching highlight module with DeepL")
        ReaderHighlight.showTranslation = function(self, text, detailed_view, source_lang, target_lang, from_highlight, index)
            return DeepLTranslator:showTranslation(text, detailed_view, source_lang, target_lang, from_highlight, index)
        end
    elseif engine == "deepseek" then
        logger.dbg("AI翻译: patching highlight module with DeepSeek")
        ReaderHighlight.showTranslation = function(self, text, detailed_view, source_lang, target_lang, from_highlight, index)
            return DeepSeekTranslator:showTranslation(text, detailed_view, source_lang, target_lang, from_highlight, index)
        end
    elseif engine == "openai" then
        logger.dbg("AI翻译: patching highlight module with OpenAI")
        ReaderHighlight.showTranslation = function(self, text, detailed_view, source_lang, target_lang, from_highlight, index)
            return OpenAITranslator:showTranslation(text, detailed_view, source_lang, target_lang, from_highlight, index)
        end
    elseif engine == "glm" then
        logger.dbg("AI翻译: patching highlight module with 智谱GLM")
        ReaderHighlight.showTranslation = function(self, text, detailed_view, source_lang, target_lang, from_highlight, index)
            return GLMTranslator:showTranslation(text, detailed_view, source_lang, target_lang, from_highlight, index)
        end
    elseif engine == "siliconflow" then
        logger.dbg("AI翻译: patching highlight module with 硅基流动")
        ReaderHighlight.showTranslation = function(self, text, detailed_view, source_lang, target_lang, from_highlight, index)
            return SiliconFlowTranslator:showTranslation(text, detailed_view, source_lang, target_lang, from_highlight, index)
        end
    elseif engine == "edge" then
        logger.dbg("AI翻译: patching highlight module with Microsoft Edge")
        ReaderHighlight.showTranslation = function(self, text, detailed_view, source_lang, target_lang, from_highlight, index)
            return EdgeTranslator:showTranslation(text, detailed_view, source_lang, target_lang, from_highlight, index)
        end
    else
        self:restoreHighlight()
        return
    end

    highlight_patched = true
    highlight_patched_target = ReaderHighlight
    logger.info("AI翻译: 已接管 ReaderHighlight.showTranslation，引擎 = " .. tostring(engine))
end

-- 切换引擎：开关打开时立即接管，关闭时只记住选择（等启用后生效）
function xiaosijitranslatorplugin:onEngineSelected(engine, display_name)
    G_reader_settings:saveSetting("translator_engine", engine)
    G_reader_settings:flush()

    self:patchTranslator()
    self:patchHighlightModule()

    local text
    if self:isEnabled() then
        text = T(_("%1 已启用"), display_name)
    else
        text = T(_("已选择%1\n插件当前处于停用状态，勾选「启用插件」后生效"), display_name)
    end
    UIManager:show(require("ui/widget/infomessage"):new{ text = text })
end

------------------------------------------------------------------------
-- 「测试配置」：拿当前选中的引擎真发一次请求，把能不能翻、耗时、错误详情摊开
------------------------------------------------------------------------

local ENGINE_NAMES = {
    google = _("Google翻译"),
    deepl = _("DeepL翻译"),
    deepseek = _("DeepSeek翻译"),
    openai = _("通用OpenAI翻译"),
    glm = _("智谱GLM-4 Flash翻译"),
    siliconflow = _("硅基流动翻译"),
    edge = _("Microsoft Edge 免费翻译"),
}

local ENGINE_MODULES = {
    deepl = DeepLTranslator,
    deepseek = DeepSeekTranslator,
    openai = OpenAITranslator,
    glm = GLMTranslator,
    siliconflow = SiliconFlowTranslator,
    edge = EdgeTranslator,
}

local TEST_SHORT_TEXT = "Hello World"

-- 公版英文（《傲慢与偏见》开头）拼到接近 Kindle 一页的量级，
-- 用来区分「短句能翻、整页翻不了」这类只有长文本才暴露的问题。
local TEST_LONG_PARAGRAPH = "It is a truth universally acknowledged, that a single man in possession "
    .. "of a good fortune, must be in want of a wife. However little known the feelings or views of "
    .. "such a man may be on his first entering a neighbourhood, this truth is so well fixed in the "
    .. "minds of the surrounding families, that he is considered the rightful property of some one or "
    .. "other of their daughters."
local TEST_LONG_TEXT = string.rep(TEST_LONG_PARAGRAPH .. "\n\n", 6)

local function nowSeconds()
    local ok, socket = pcall(require, "socket")
    if ok and socket and socket.gettime then
        local ok2, value = pcall(socket.gettime)
        if ok2 and value then
            return value
        end
    end
    return os.time()
end

local function elapsedText(seconds)
    if not seconds or seconds < 0 then
        return "?"
    end
    if seconds < 10 then
        return string.format("%.1f", seconds)
    end
    return string.format("%.0f", seconds)
end

local function shorten(text, limit)
    text = (text or ""):gsub("%s+", " ")
    if #text > limit then
        return text:sub(1, limit) .. "…"
    end
    return text
end

-- 发一次真实请求，返回：译文 / 错误详情 / 耗时（秒）
-- 各引擎 loadPage 的返回结构不同（Edge: translation，DeepL: translations，AI: choices），
-- 这里统一归一化，顺便把 pcall 兜住 —— DeepL 出错时是直接 error() 的。
local function probeEngine(module, text, target_lang)
    local started = nowSeconds()
    local ok, result = pcall(module.loadPage, module, text, target_lang, nil)
    local elapsed = nowSeconds() - started

    local translation, err_text
    if not ok then
        err_text = tostring(result)
    elseif type(result) ~= "table" then
        err_text = _("引擎没有返回任何结果")
    elseif result.success == false then
        err_text = result.error or _("未知错误")
    elseif type(result.translation) == "string" and result.translation ~= "" then
        translation = result.translation
    elseif result.translations and result.translations[1] then
        translation = result.translations[1].text
    elseif result.choices and result.choices[1] and result.choices[1].message then
        translation = result.choices[1].message.content
    else
        err_text = result.error or _("未收到有效的翻译结果")
    end

    if translation then
        translation = translation:gsub("^%s+", ""):gsub("%s+$", "")
        if translation == "" then
            translation = nil
            err_text = _("引擎返回了空译文")
        end
    end

    return translation, err_text, elapsed
end

local function appendEngineInfo(lines, engine, module)
    lines[#lines + 1] = T(_("引擎：%1"), ENGINE_NAMES[engine] or tostring(engine))
    if engine == "edge" then
        lines[#lines + 1] = _("接口：Microsoft Edge 公共翻译接口（免费，无需密钥）")
        return
    end
    if module.getApiEndpoint then
        local ok, endpoint = pcall(module.getApiEndpoint, module)
        if ok and endpoint then
            lines[#lines + 1] = T(_("接口：%1"), endpoint)
        end
    end
    if module.getModel then
        local ok, model = pcall(module.getModel, module)
        if ok and model then
            lines[#lines + 1] = T(_("模型：%1"), model)
        end
    end
    if module.getApiKey then
        local ok, key = pcall(module.getApiKey, module)
        if ok then
            if key then
                lines[#lines + 1] = _("API 密钥：已配置")
            else
                lines[#lines + 1] = _("API 密钥：❌ 未配置")
            end
        end
    end
end

-- 纯函数：跑两次探测并拼出报告文本（不碰 UI，方便离线测试）
function xiaosijitranslatorplugin:buildConfigTestReport(engine)
    local module = ENGINE_MODULES[engine]
    if not module then
        return T(_("当前引擎：%1\n\n该引擎不支持配置测试（Google 由 KOReader 原生实现，插件没有接口可测）。\n请在「当前：…」里选一个插件内置引擎后再试。"),
            ENGINE_NAMES[engine] or tostring(engine))
    end

    local target_lang = "ZH"
    if module.getTargetLanguage then
        local ok, lang = pcall(module.getTargetLanguage, module)
        if ok and lang then
            target_lang = lang
        end
    end

    local lines = {}
    appendEngineInfo(lines, engine, module)
    lines[#lines + 1] = T(_("目标语言：%1"), target_lang)
    lines[#lines + 1] = ""

    local short_translation, short_error, short_elapsed = probeEngine(module, TEST_SHORT_TEXT, target_lang)
    local short_ok = short_translation ~= nil
    lines[#lines + 1] = T(_("【短文本】%1"), TEST_SHORT_TEXT)
    if short_ok then
        lines[#lines + 1] = T(_("结果：✅ 成功（%1 秒）"), elapsedText(short_elapsed))
        lines[#lines + 1] = T(_("译文：%1"), shorten(short_translation, 200))
    else
        lines[#lines + 1] = T(_("结果：❌ 失败（%1 秒）"), elapsedText(short_elapsed))
        lines[#lines + 1] = _("错误详情：")
        lines[#lines + 1] = short_error or "?"
    end

    local long_ok = false
    if short_ok then
        lines[#lines + 1] = ""
        local long_translation, long_error, long_elapsed = probeEngine(module, TEST_LONG_TEXT, target_lang)
        long_ok = long_translation ~= nil
        lines[#lines + 1] = T(_("【长文本】约 %1 字符（≈ 一页）"), #TEST_LONG_TEXT)
        if long_ok then
            lines[#lines + 1] = T(_("结果：✅ 成功（%1 秒）"), elapsedText(long_elapsed))
            lines[#lines + 1] = T(_("译文开头：%1"), shorten(long_translation, 200))
        else
            lines[#lines + 1] = T(_("结果：❌ 失败（%1 秒）"), elapsedText(long_elapsed))
            lines[#lines + 1] = _("错误详情：")
            lines[#lines + 1] = long_error or "?"
        end
    end

    lines[#lines + 1] = ""
    lines[#lines + 1] = _("— 结论 —")
    if not short_ok then
        lines[#lines + 1] = _("❌ 短文本就失败了：先看上面的错误详情（密钥 / 网络 / 模型名 / 余额）。")
    elseif long_ok then
        lines[#lines + 1] = _("✅ 短文本和长文本都能翻，该引擎可以正常用于整页翻译。")
    else
        lines[#lines + 1] = _("⚠️ 短文本能翻、长文本失败：多半是超时（网络慢 / 模型慢）或模型上下文不足。")
        lines[#lines + 1] = _("   可换更快的模型，或把整页翻译拆成更小的段落。")
    end
    return table.concat(lines, "\n")
end

function xiaosijitranslatorplugin:showConfigTest()
    local engine = G_reader_settings:readSetting("translator_engine") or "edge"
    local Trapper = require("ui/trapper")
    local TextViewer = require("ui/widget/textviewer")
    local Screen = require("device").screen

    logger.info("AI翻译: 开始测试配置，引擎 = " .. tostring(engine))

    -- 放子进程里跑：网络再慢也不卡界面（Trapper 自带「请稍候」提示）
    Trapper:wrap(function()
        local report = self:buildConfigTestReport(engine)
        logger.info("AI翻译: 测试配置结束，引擎 = " .. tostring(engine))
        UIManager:show(TextViewer:new{
            title = _("配置测试结果"),
            title_multilines = true,
            text = report,
            text_type = "lookup",
            height = math.floor(Screen:getHeight() * 0.8),
            add_default_buttons = true,
        })
    end)
end

function xiaosijitranslatorplugin:addToMainMenu(menu_items)
    logger.dbg("AI翻译: addToMainMenu called")
    
    menu_items.ai_translator = {
        text = _("AI翻译"),
        sorting_hint = "tools",
        sub_item_table = {
            {
                text = _("启用插件"),
                help_text = _("勾选：接管 KOReader 翻译并使用本插件的引擎。取消勾选：立即还原为 KOReader 原生翻译，菜单仍保留以便随时重新启用。"),
                checked_func = function()
                    return self:isEnabled()
                end,
                callback = function()
                    local enabled = not self:isEnabled()
                    G_reader_settings:saveSetting(ENABLED_SETTING_KEY, enabled)
                    G_reader_settings:flush()
                    if enabled then
                        -- 立即接管，无需重启
                        self:patchTranslator()
                        self:patchHighlightModule()
                    else
                        -- 立即把三个入口还原成 KOReader 原生实现
                        self:restoreAll()
                    end
                    UIManager:show(require("ui/widget/infomessage"):new{
                        text = enabled and _("AI翻译插件已启用") or _("AI翻译插件已停用\n翻译已恢复 KOReader 原生行为"),
                    })
                end,
                separator = true,
            },
            {
                text_func = function()
                    local engine = G_reader_settings:readSetting("translator_engine") or "edge"
                    local name = ENGINE_NAMES[engine] or engine
                    if not self:isEnabled() then
                        return T(_("当前：%1（插件已停用）"), name)
                    end
                    return T(_("当前：%1"), name)
                end,
                sub_item_table = {
                    {
                        text = _("Google翻译"),
                        help_text = _("使用默认的Google翻译引擎"),
                        checked_func = function()
                            return (G_reader_settings:readSetting("translator_engine") or "edge") == "google"
                        end,
                        callback = function()
                            self:onEngineSelected("google", _("Google翻译"))
                        end,
                    },
                    {
                        text = _("DeepL翻译"),
                        help_text = _("使用DeepL翻译引擎，翻译质量好，需要API密钥"),
                        checked_func = function()
                            return G_reader_settings:readSetting("translator_engine") == "deepl"
                        end,
                        callback = function()
                            self:onEngineSelected("deepl", _("DeepL翻译"))
                        end,
                    },
                    {
                        text = _("DeepSeek翻译"),
                        help_text = _("使用DeepSeek翻译引擎，翻译质量好，需要API密钥"),
                        checked_func = function()
                            return G_reader_settings:readSetting("translator_engine") == "deepseek"
                        end,
                        callback = function()
                            self:onEngineSelected("deepseek", _("DeepSeek翻译"))
                        end,
                    },
                    {
                        text = _("通用OpenAI翻译"),
                        help_text = _("使用OpenAI兼容API翻译引擎，如硅基流动，需要API密钥"),
                        checked_func = function()
                            return G_reader_settings:readSetting("translator_engine") == "openai"
                        end,
                        callback = function()
                            self:onEngineSelected("openai", _("通用OpenAI翻译"))
                        end,
                    },
                    {
                        text = _("硅基流动翻译"),
                        help_text = _("使用硅基流动API翻译（OpenAI兼容，平台提供免费额度），需要API密钥"),
                        checked_func = function()
                            return G_reader_settings:readSetting("translator_engine") == "siliconflow"
                        end,
                        callback = function()
                            self:onEngineSelected("siliconflow", _("硅基流动翻译"))
                        end,
                    },
                    {
                        text = _("智谱GLM-4 Flash翻译"),
                        help_text = _("使用智谱AI免费模型GLM-4 Flash，注册即可免费使用，需要免费API密钥"),
                        checked_func = function()
                            return G_reader_settings:readSetting("translator_engine") == "glm"
                        end,
                        callback = function()
                            self:onEngineSelected("glm", _("智谱GLM-4 Flash翻译"))
                        end,
                    },
                    {
                        text = _("Microsoft Edge 免费翻译"),
                        help_text = _("使用微软Edge公共翻译接口，完全免费，无需任何API密钥，开箱即用"),
                        checked_func = function()
                            return G_reader_settings:readSetting("translator_engine") == "edge"
                        end,
                        callback = function()
                            self:onEngineSelected("edge", _("Microsoft Edge 免费翻译"))
                        end,
                    },
                },
                separator = true,
            },
            {
                text = _("免费"),
                sub_item_table = {
                    GLMTranslator:genSettingsMenu(),
                    SiliconFlowTranslator:genSettingsMenu(),
                },
            },
            {
                text = _("收费"),
                sub_item_table = {
                    DeepLTranslator:genSettingsMenu(),
                    DeepSeekTranslator:genSettingsMenu(),
                    OpenAITranslator:genSettingsMenu(),
                },
            },
            {
                text = _("测试配置"),
                help_text = _("向当前选中的引擎发一条 Hello World，再追加一段约一页的长文本，检查密钥、网络、模型名以及长文本翻译是否正常。结果里会显示耗时和完整错误详情。"),
                callback = function()
                    self:showConfigTest()
                end,
            },
        },
    }
end

require("insert_menu")

return xiaosijitranslatorplugin
