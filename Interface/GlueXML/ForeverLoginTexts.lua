-- Login screen texts in the client's language. A text the client already has is read from its
-- global; every other shown text is read from G.L.KEY. Each language is a
-- ForeverLoginTexts_<code>.lua file calling AddTexts("<code>", {...}); enUS is the fallback.

ForeverLogin = ForeverLogin or {}
local G = ForeverLogin

local languages = {}
local BASE = "enUS"

function G.AddTexts(language, texts)
	local t = languages[language] or {}
	for key, text in pairs(texts) do t[key] = text end
	languages[language] = t
end

-- Keys looked up that no language has.
G.missingTexts = {}

-- G.L[key]: text in the client's language, else English, else the key itself.
G.L = setmetatable({}, {
	__index = function(_, key)
		local t = languages[GetLocale()]
		local text = t and t[key]
		if text == nil and languages[BASE] then text = languages[BASE][key] end
		if text == nil then
			G.missingTexts[key] = true
			text = tostring(key)
		end
		return text
	end,
})

function G.TextsFor(language)
	return languages[language]
end
