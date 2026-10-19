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
                    local engine_names = {
                        google = _("Google翻译"),
                        deepl = _("DeepL翻译"),
                        deepseek = _("DeepSeek翻译"),
                        openai = _("通用OpenAI翻译"),
                        glm = _("智谱GLM-4 Flash翻译"),
                        siliconflow = _("硅基流动翻译"),
                        edge = _("Microsoft Edge 免费翻译"),
                    }
                    local name = engine_names[engine] or engine
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
        },
    }
end

require("insert_menu")

return xiaosijitranslatorplugin
