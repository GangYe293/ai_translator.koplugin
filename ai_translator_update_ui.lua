-- 菜单与对话框：「关于」子菜单、检查更新、下载安装、进度与重启提示。

local UIManager = require("ui/uimanager")
local ButtonDialog = require("ui/widget/buttondialog")
local Notification = require("ui/widget/notification")
local ProgressbarDialog = require("ui/widget/progressbardialog")
local Trapper = require("ui/trapper")
local _ = require("gettext")
local T = require("ffi/util").template

local Updater = require("ai_translator_update")

local UI = {}

UI.PROJECT_URL = "https://github.com/GangYe293/ai_translator.koplugin"

function UI.showInfo(text, timeout)
    UIManager:show(Notification:new{ text = text, timeout = timeout or 2 })
end

function UI.confirm(options, on_confirm)
    local dialog
    dialog = ButtonDialog:new{
        title = options.title,
        buttons = {{
            {
                text = options.cancel_text or _("取消"),
                callback = function() UIManager:close(dialog) end,
            },
            {
                text = options.confirm_text or _("确定"),
                callback = function()
                    UIManager:close(dialog)
                    if on_confirm then on_confirm() end
                end,
            },
        }},
    }
    UIManager:show(dialog)
end

function UI.hide_subtitle(dialog)
    local frame = dialog and dialog[1]
    local group = frame and frame[1]
    if not group then return end
    local subtitle_widget
    for index, widget in ipairs(group) do
        if index == 2 then
            subtitle_widget = widget
            break
        end
    end
    if not subtitle_widget then return end
    if subtitle_widget.setText then subtitle_widget:setText("") end
end

-- 可滚动的纯文本查看窗。TextViewer 是 KOReader 自带组件。
function UI.show_text(title, text)
    local ok, TextViewer = pcall(require, "ui/widget/textviewer")
    if not ok or not TextViewer then
        UI.showInfo(text, 6)
        return
    end
    UIManager:show(TextViewer:new{
        title = title,
        text = text,
        justified = true,
    })
end

function UI.format_size(bytes)
    local size = tonumber(bytes) or 0
    if size >= 1024 * 1024 then
        return string.format("%.1f MB", size / (1024 * 1024))
    end
    if size >= 1024 then
        return string.format("%d KB", math.floor(size / 1024 + 0.5))
    end
    return tostring(size) .. " B"
end

-- UTF-8 安全截断（按字节切会把汉字劈开，设备上显示成「◆◈」）。
function UI.truncate_utf8(text, limit)
    if #text <= limit then return text, false end
    local cut = limit
    while cut > 0 and cut > limit - 3 do
        local nxt = text:byte(cut + 1)
        if nxt == nil or nxt < 128 or nxt >= 192 then break end
        cut = cut - 1
    end
    if cut <= 0 then return "…", true end
    return text:sub(1, cut) .. "…", true
end

local UPDATE_STAGES = {
    preparing = _("准备"),
    downloading = _("下载"),
    checking = _("核对体积"),
    checksum = _("取校验值"),
    verifying = _("校验"),
    extracting = _("解压"),
    installing = _("安装"),
    done = _("完成"),
}

-- 更新进度窗：标题显示"阶段 xx%"，只在百分比真的往前走时重绘。
function UI.update_progress()
    local dialog = ProgressbarDialog:new{
        title = _("正在更新…"),
        subtitle = "",
        progress_max = 100,
        dismissable = false,
    }
    dialog:show()
    UI.hide_subtitle(dialog)
    local last = -1
    return {
        dialog = dialog,
        set = function(self, stage, percent)
            percent = math.floor(tonumber(percent) or 0)
            if percent > 100 then percent = 100 end
            if percent <= last then return end
            last = percent
            local label = UPDATE_STAGES[stage] or (stage and tostring(stage) or "")
            pcall(function()
                local frame = dialog[1]
                local group = frame and frame[1]
                if group and group[1] and group[1].setText then
                    group[1]:setText(T(_("%1 %2%"), label, percent))
                end
                dialog:reportProgress(percent)
                UIManager:setDirty(dialog, "ui")
            end)
        end,
        close = function(self) UIManager:close(dialog) end,
    }
end

--[[--
「关于」：版本、作者、检查更新、每天自动检查一次。

更新是联网动作，默认不自动跑；勾上「每天检查一次」后才会在打开书时静默问
一次 GitHub，有新版本也只是提示，装不装由用户点。
]]
function UI.about_menu(plugin)
    local updater = plugin.updater
    local function info_row(text, on_tap)
        return {
            text = text,
            keep_menu_open = true,
            callback = on_tap,
        }
    end
    return {
        text = _("关于"),
        separator = true,
        sub_item_table = {
            info_row(_("版本：") .. tostring(plugin.VERSION or _("未知")), function()
                UI.show_text(T(_("AI翻译 %1"), tostring(plugin.VERSION or _("未知"))),
                    T(_("多翻译引擎插件，内置完全免费的 Microsoft Edge 翻译。\n\n"
                        .. "项目地址：%1\n\n"
                        .. "更新记录、安装包都在 Releases 页面：\n%1/releases"), UI.PROJECT_URL))
            end),
            info_row(_("作者：GangYe293"), function()
                UI.show_text(_("项目地址"), UI.PROJECT_URL
                    .. "\n\n" .. _("源码和更新记录都在这里。"))
            end),
            {
                text_func = function()
                    if not updater then return _("检查更新") end
                    local latest = updater:available_version()
                    if latest then
                        return T(_("检查更新（有新版 %1）"), latest)
                    end
                    return _("检查更新")
                end,
                callback = function() UI.check_update(plugin) end,
            },
            {
                text = _("每天自动检查一次"),
                checked_func = function()
                    return updater ~= nil and updater:get_auto_check() == true
                end,
                callback = function()
                    if not updater then
                        UI.showInfo(_("更新组件未就绪，重启 KOReader 后再试"), 3)
                        return
                    end
                    local enabled = updater:get_auto_check() ~= true
                    updater:set_auto_check(enabled)
                    UI.showInfo(enabled
                        and _("已开启：每天第一次打开书时检查一次更新")
                        or _("已关闭：只在手动点「检查更新」时联网"), 3)
                end,
            },
        },
    }
end

-- 查一次更新。silent = 自动检查（没有更新就不吭声）。
function UI.check_update(plugin, silent)
    local updater = plugin.updater
    if not updater then
        if not silent then UI.showInfo(_("更新组件未就绪，重启 KOReader 后再试"), 3) end
        return
    end
    if not silent then UI.showInfo(_("正在检查更新…"), 2) end

    local release, err
    local ok, wrap_err = Trapper:wrap(function()
        release, err = updater:fetch()
    end)
    if not ok then
        if not silent then
            UI.showInfo(_("检查更新失败：") .. tostring(wrap_err), 3)
        end
        return
    end
    if not release then
        if silent then return end
        UI.showInfo(_("检查更新失败：") .. tostring(err or _("网络不可用")), 3)
        return
    end
    if Updater.compare_versions(release.version, updater.current_version) ~= 1 then
        if not silent then
            UI.showInfo(T(_("已是最新版（%1）"), updater.current_version), 3)
        end
        return
    end
    UI.offer_update(plugin, release)
end

-- 更新说明可以长到 1200 字符。整份塞进 ButtonDialog 的标题会把按钮顶出屏幕，
-- 所以标题里只放几行预览，完整内容交给可滚动的「查看完整更新说明」。
UI.NOTES_PREVIEW_LINES = 4
UI.NOTES_PREVIEW_CHARS = 200

-- 返回 (预览文本, 是否被截断)。行数与字符数任一超限就截断。
function UI.notes_preview(notes)
    if type(notes) ~= "string" or notes == "" then return "", false end
    local text = notes:gsub("\r\n", "\n"):gsub("\r", "\n")
    text = text:gsub("^%s+", ""):gsub("%s+$", "")
    if text == "" then return "", false end

    local shown, chars, truncated = {}, 0, false
    for line in (text .. "\n"):gmatch("([^\n]*)\n") do
        local cost = #line + 1
        if #shown >= UI.NOTES_PREVIEW_LINES or chars + cost > UI.NOTES_PREVIEW_CHARS then
            truncated = true
            break
        end
        shown[#shown + 1] = line
        chars = chars + cost
    end
    if #shown == 0 then
        -- 第一行本身就超长（Release 说明里偶尔有一整段）
        local line = text:match("^[^\n]*") or ""
        local cut = UI.truncate_utf8(line, UI.NOTES_PREVIEW_CHARS)
        return cut, true
    end
    return table.concat(shown, "\n"), truncated
end

-- 标题 = "发现新版本 x（当前 y）" + 说明预览。返回 (标题, 是否被截断)。
function UI.update_offer_title(version, current, notes)
    local title = T(_("发现新版本 %1（当前 %2）"), version, current)
    local preview, truncated = UI.notes_preview(notes)
    if preview ~= "" then
        title = title .. "\n\n" .. preview .. (truncated and "\n…" or "")
    end
    return title, truncated
end

-- 问用户装不装（单包：只有代码，没有离线数据）。
function UI.offer_update(plugin, release)
    local asset = release and release.asset
    if not asset or not asset.url then
        UI.showInfo(_("这个版本没有可下载的安装包"), 3)
        return
    end
    local size = UI.format_size(asset.size)

    local offer
    local buttons = {}
    buttons[#buttons + 1] = {{
        text = T(_("下载并安装（%1）"), size),
        callback = function()
            UIManager:close(offer)
            UI.install_update(plugin, release)
        end,
    }}
    local title, truncated = UI.update_offer_title(release.version,
        plugin.updater and plugin.updater.current_version or _("未知"), release.notes)
    if truncated then
        buttons[#buttons + 1] = {{
            text = _("查看完整更新说明"),
            callback = function()
                UI.show_text(T(_("AI翻译 %1 更新说明"), release.version),
                    release.notes or "")
            end,
        }}
    end
    buttons[#buttons + 1] = {{
        text = _("以后再说"),
        callback = function() UIManager:close(offer) end,
    }}

    offer = ButtonDialog:new{ title = title, buttons = buttons }
    UIManager:show(offer)
end

-- 下载 → 校验 → 解压 → 备份替换。装完问一句要不要重启。
function UI.install_update(plugin, release)
    local updater = plugin.updater
    if not updater then
        UI.showInfo(_("更新组件未就绪，重启 KOReader 后再试"), 3)
        return
    end
    local progress = UI.update_progress()
    local ok, err
    Trapper:wrap(function()
        ok, err = updater:install(release, {
            on_progress = function(stage, percent) progress:set(stage, percent) end,
        })
    end)
    UIManager:nextTick(function()
        progress:close()
        if ok then
            UI.confirm({
                title = _("更新已安装。要现在重启 KOReader 吗？\n"
                       .. "（不重启就还是旧版本，下次启动自动生效）"),
                confirm_text = _("立即重启"),
            }, function()
                if UIManager.restartKOReader then
                    UIManager:restartKOReader()
                else
                    UI.showInfo(_("请手动退出并重启 KOReader"), 4)
                end
            end)
        else
            UI.showInfo(tostring(err or _("更新失败")), 4)
        end
    end)
end

return UI
