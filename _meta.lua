local _ = require("gettext")
return {
    name = "ai_translator",
    fullname = _("AI翻译"),
    version = "1.2.2",
    description = _([[多翻译引擎插件，内置完全免费的 Microsoft Edge 翻译（无需API密钥，开箱即用），同时支持DeepL、DeepSeek、通用OpenAI兼容API，以及免费的智谱GLM-4 Flash翻译。在中国提供更好的翻译质量。菜单内可一键启用/停用，停用后立即恢复 KOReader 原生翻译；「测试配置」可一键自检当前引擎能否正常翻译；「关于」里可在线检查并安装更新。]]),
}
