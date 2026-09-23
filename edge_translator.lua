--[[--
Microsoft Edge 免费翻译插件 for KOReader

本模块提供 Microsoft Edge 的免费翻译接口，无需任何 API 密钥，开箱即用、完全免费。
接口为微软 Edge 浏览器内置的公开翻译端点（非官方但长期可用），使用方式与
dualtranslate 等项目一致。

接口说明：
- Endpoint: https://edge.microsoft.com/translate/translatetext?isEnterpriseClient=false
- 参数: &to=<目标语言> &from=<源语言（可省略，自动检测）>
- 请求体: {"text": "待翻译文本"}  (JSON)
- 响应: [ { "translations": [ { "text": "译文", "to": "..." } ] } ]
- 语言代码: zh-Hans / zh-Hant / en / ja / ko / fr / de / es / ru / it / pt / ar / hi ...

@module koplugin.EdgeTranslator
--]]

local Device = require("device")
local TextViewer = require("ui/widget/textviewer")
local UIManager = require("ui/uimanager")
local JSON = require("json")
local Screen = require("device").screen
local ffiUtil = require("ffi/util")
local logger = require("logger")
local util = require("util")
local T = ffiUtil.template
local _ = require("gettext")

local EdgeTranslator = {
    endpoint = "https://edge.microsoft.com/translate/translatetext?isEnterpriseClient=false",
    default_lang = "ZH",
}

-- 将本插件内部使用的 2 字母大写语言代码（ZH/EN/JA...）映射为 Edge 使用的代码。
-- 目标语言必须给出；源语言可省略以自动检测。
local LANG_MAP = {
    ZH = "zh-Hans",
    EN = "en",
    JA = "ja",
    KO = "ko",
    FR = "fr",
    DE = "de",
    ES = "es",
    RU = "ru",
    IT = "it",
    PT = "pt",
    AR = "ar",
    HI = "hi",
}

function EdgeTranslator:toEdgeLang(code)
    if not code or code == "" or code:lower() == "auto" then
        return nil -- 省略，交给 Edge 自动检测
    end
    -- 处理带区域/文字变体的语言码，如 zh_CN、zh-Hant、en_US（KOReader 界面语言常为此格式）
    local base, variant = code:match("^(%a+)[_-](%a+)$")
    if base then
        base = base:lower()
        variant = variant:lower()
        if base == "zh" then
            if variant == "hant" or variant == "tw" or variant == "hk" or variant == "mo" then
                return "zh-Hant"
            end
            return "zh-Hans" -- hans / cn / sg 及其他默认简体
        end
        return base -- 其他语言（如 en_US）只需主语言码
    end
    local up = code:upper()
    if LANG_MAP[up] then
        return LANG_MAP[up]
    end
    -- 兜底：直接转小写（如 zh-CN -> zh-cn），让 Edge 自行判断
    return code:lower()
end

function EdgeTranslator:getTargetLanguage()
    local lang = G_reader_settings:readSetting("edge_to_language")
    if not lang then
        lang = G_reader_settings:readSetting("language")
        if lang and lang ~= "" then
            lang = lang:match("(.*)-") or lang
            if lang == "C" then
                lang = "ZH"
            else
                lang = lang:upper()
            end
        end
    end
    return lang or "ZH"
end

function EdgeTranslator:getLanguageName(lang, default_string)
    local lang_names = {
        ZH = _("中文（简体）"),
        EN = _("英语"),
        JA = _("日语"),
        KO = _("韩语"),
        FR = _("法语"),
        DE = _("德语"),
        ES = _("西班牙语"),
        RU = _("俄语"),
        IT = _("意大利语"),
        PT = _("葡萄牙语"),
        AR = _("阿拉伯语"),
        HI = _("印地语"),
    }
    if lang_names[lang] then
        return lang_names[lang], true
    elseif lang then
        return lang:upper(), false
    end
    return default_string, false
end

function EdgeTranslator:genSettingsMenu()
    return {
        text = _("Microsoft Edge 设置"),
        sub_item_table = {
            {
                text = _("无需配置，免费即用"),
                help_text = _([[Microsoft Edge 免费翻译由微软公共接口提供，无需任何 API 密钥，开箱即用、完全免费。只需在本插件主菜单中选择它即可使用。]]),
                enabled_func = function()
                    return false
                end,
            },
            {
                text_func = function()
                    local lang = self:getTargetLanguage()
                    local name = self:getLanguageName(lang, lang)
                    return T(_("目标语言：%1"), name)
                end,
                help_text = _([[翻译目标语言默认为 KOReader 界面语言，可在 KOReader 的「翻译」设置中更改。]]),
                enabled_func = function()
                    return false
                end,
            },
        },
    }
end

function EdgeTranslator:loadPage(text, target_lang, source_lang)
    local socket = require("socket")
    local socketutil = require("socketutil")
    local url = require("socket.url")
    local http = require("socket.http")
    local ltn12 = require("ltn12")

    local debug_info = {}
    table.insert(debug_info, "=== Microsoft Edge 免费翻译调试信息 ===")
    table.insert(debug_info, "")
    table.insert(debug_info, "💡 本引擎由微软公共接口提供，完全免费，无需 API 密钥")
    table.insert(debug_info, "")

    local to_lang = self:toEdgeLang(target_lang)
    if not to_lang then
        table.insert(debug_info, "❌ 无法识别的目标语言: " .. tostring(target_lang))
        return { success = false, error = table.concat(debug_info, "\n") }
    end

    local api_endpoint = self.endpoint .. "&to=" .. url.escape(to_lang)
    local from_lang = self:toEdgeLang(source_lang)
    if from_lang then
        api_endpoint = api_endpoint .. "&from=" .. url.escape(from_lang)
    end

    table.insert(debug_info, "📡 API端点: " .. api_endpoint)

    -- Edge 接口要求请求体为纯字符串数组：["..."]（实测 200 OK；对象格式 {"text":...} 会返回 400）
    local body = JSON.encode({ text })
    table.insert(debug_info, "📤 发送的请求Body:")
    table.insert(debug_info, body)
    table.insert(debug_info, "")

    local sink = {}
    socketutil:set_timeout(30)

    local request = {
        url = api_endpoint,
        method = "POST",
        headers = {
            ["Content-Type"] = "application/json",
            ["Accept"] = "application/json",
            ["Content-Length"] = #body,
        },
        source = ltn12.source.string(body),
        sink = ltn12.sink.table(sink),
    }

    logger.dbg("Edge request:", api_endpoint, "target:", to_lang)

    local code, headers, status
    local max_retries = 3
    local retry_delay = 2
    local retry_count = 0

    while retry_count < max_retries do
        code, headers, status = socket.skip(1, http.request(request))

        if status and (status:find("wantread") or status:find("WANTREAD") or status:find("timeout") or status:find("TIMEOUT")) then
            retry_count = retry_count + 1
            table.insert(debug_info, "🔄 遇到网络错误(" .. tostring(status) .. ")，正在重试... (" .. retry_count .. "/" .. max_retries .. ")")
            socket.sleep(retry_delay)
            retry_delay = retry_delay * 1.2
        else
            break
        end
    end

    socketutil:reset_timeout()

    table.insert(debug_info, "📊 HTTP状态码: " .. tostring(code or "无"))

    if headers == nil then
        table.insert(debug_info, "❌ 网络错误: " .. (status or code or "未知错误"))
        table.insert(debug_info, "请检查网络连接")
        return { success = false, error = table.concat(debug_info, "\n") }
    end

    local response = table.concat(sink)
    table.insert(debug_info, "📄 接收到的响应Body:")
    table.insert(debug_info, response)
    table.insert(debug_info, "")

    if code ~= 200 then
        logger.warn("Edge HTTP status not okay:", status or code)
        logger.dbg("Response headers:", headers)
        logger.dbg("Response body:", response)

        local error_msg = "翻译失败：" .. (status or tostring(code))
        table.insert(debug_info, "❌ " .. error_msg)
        return { success = false, error = table.concat(debug_info, "\n") }
    end

    local ok, result = pcall(JSON.decode, response)
    if not ok or type(result) ~= "table" then
        logger.warn("Edge JSON decode error:", result)
        table.insert(debug_info, "❌ JSON解析失败: " .. tostring(result))
        return { success = false, error = table.concat(debug_info, "\n") }
    end

    local translation = nil
    if result[1] and result[1].translations and result[1].translations[1] then
        translation = result[1].translations[1].text
    end

    if not translation then
        table.insert(debug_info, "❌ 响应中未找到翻译结果")
        return { success = false, error = table.concat(debug_info, "\n") }
    end

    table.insert(debug_info, "✅ 翻译成功")
    return { success = true, translation = translation, _debug_info = table.concat(debug_info, "\n") }
end

function EdgeTranslator:translate(text, target_lang, source_lang)
    if not target_lang then
        target_lang = self:getTargetLanguage()
    end

    local result = self:loadPage(text, target_lang, source_lang)
    if result and result.success and result.translation then
        return result.translation
    end
    return nil
end

function EdgeTranslator:showTranslation(text, detailed_view, source_lang, target_lang, from_highlight, index)
    if Device:hasClipboard() then
        Device.input.setClipboardText(text)
    end

    local NetworkMgr = require("ui/network/manager")
    if NetworkMgr:willRerunWhenOnline(function()
                self:showTranslation(text, detailed_view, source_lang, target_lang, from_highlight, index)
            end) then
        return
    end

    local Trapper = require("ui/trapper")
    Trapper:wrap(function()
        self:_showTranslation(text, detailed_view, source_lang, target_lang, from_highlight, index)
    end)
end

function EdgeTranslator:_showTranslation(text, detailed_view, source_lang, target_lang, from_highlight, index)
    if not target_lang then
        target_lang = self:getTargetLanguage()
    end

    local result = self:loadPage(text, target_lang, source_lang)

    local output = {}
    local translation = nil
    local debug_info = nil

    if result then
        if result.success and result.translation then
            translation = result.translation
            debug_info = result._debug_info
        else
            debug_info = result.error or "❌ 未收到有效的翻译结果"
        end
    else
        debug_info = "❌ 未收到任何返回结果"
    end

    if not translation then
        table.insert(output, "❌ 翻译失败")
        table.insert(output, "")
        if debug_info then
            table.insert(output, debug_info)
        end
        UIManager:show(TextViewer:new{
            title = _("Microsoft Edge 翻译错误"),
            title_multilines = true,
            text = table.concat(output, "\n"),
            text_type = "lookup",
            height = math.floor(Screen:getHeight() * 0.8),
            add_default_buttons = true,
        })
        return
    end

    local detected_lang = source_lang or target_lang

    if detailed_view then
        table.insert(output, "▣ " .. text)
        table.insert(output, "")
        table.insert(output, "● " .. translation)
    else
        table.insert(output, translation)
    end

    local text_all = table.concat(output, "\n")

    local textviewer, height, buttons_table, close_callback
    if detailed_view then
        height = math.floor(Screen:getHeight() * 0.8)
        buttons_table = {}
        if from_highlight then
            local ui = require("apps/reader/readerui").instance
            table.insert(buttons_table,
                {
                    {
                        text = _("保存翻译到笔记"),
                        callback = function()
                            UIManager:close(textviewer)
                            UIManager:close(ui.highlight.highlight_dialog)
                            ui.highlight.highlight_dialog = nil
                            if index then
                                ui.highlight:editNote(index, false, translation)
                            else
                                ui.highlight:addNote(translation)
                            end
                        end,
                    },
                }
            )
            close_callback = function()
                if not ui.highlight.highlight_dialog then
                    ui.highlight:clear()
                end
            end
        end
        if Device:hasClipboard() then
            table.insert(buttons_table,
                {
                    {
                        text = _("复制翻译"),
                        callback = function()
                            Device.input.setClipboardText(translation)
                        end,
                    },
                }
            )
        end
    end

    textviewer = TextViewer:new{
        title = T(_("Microsoft Edge 翻译至 %1"), self:getLanguageName(detected_lang, "?")),
        title_multilines = true,
        text = text_all,
        text_type = "lookup",
        height = height,
        add_default_buttons = true,
        buttons_table = buttons_table,
        close_callback = close_callback,
    }
    UIManager:show(textviewer)
end

return EdgeTranslator
