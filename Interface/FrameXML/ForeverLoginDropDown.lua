-- Dropdown menus of the in game windows. The client menu keeps its logic (ToggleDropDownMenu,
-- UIDropDownMenu_AddButton) and its art and rows are re-applied after it. Style 2 buttons and
-- rows use the size 10 of the other option texts.

local G = ForeverLogin

local HOVER = "Interface\\QuestFrame\\UI-QuestTitleHighlight"
local ROWS = 20
local EXTENT = 16 + 20                 -- radio (-3 .. 15) + 1, plus the padding
local LEVELS = UIDROPDOWNMENU_MAXLEVELS or 2

local STYLES = {
	[1] = { background = "common-dropdown-bg", backgroundA = { -10, 3 }, backgroundB = { 10, -3 }, alpha = 0.925,
		margins = { 8, 8, 8, 15 } },
	[2] = { background = "common-dropdown-c-bg", backgroundA = { -17, 12 }, backgroundB = { 17, -22 }, alpha = 1,
		margins = { 3, 6, 3, 7 } },
}

-- 3.3.5 returns 1 / nil, sometimes 0 / 1: zero is true in Lua
local function truthy(v)
	return v and v ~= 0 and true or false
end

-- ------------------------------------------------------------ Windows-1252
-- Audio output names (Sound_GameSystem_GetOutputDriverNameByIndex) come in the system code
-- page (Windows-1252) and the client shows them as UTF-8; they are converted for display only.

-- 0x80 to 0x9F of Windows-1252; 0xA0 to 0xFF equal their code point
local CP1252 = {
	[0x80] = 0x20AC, [0x82] = 0x201A, [0x83] = 0x0192, [0x84] = 0x201E, [0x85] = 0x2026,
	[0x86] = 0x2020, [0x87] = 0x2021, [0x88] = 0x02C6, [0x89] = 0x2030, [0x8A] = 0x0160,
	[0x8B] = 0x2039, [0x8C] = 0x0152, [0x8E] = 0x017D, [0x91] = 0x2018, [0x92] = 0x2019,
	[0x93] = 0x201C, [0x94] = 0x201D, [0x95] = 0x2022, [0x96] = 0x2013, [0x97] = 0x2014,
	[0x98] = 0x02DC, [0x99] = 0x2122, [0x9A] = 0x0161, [0x9B] = 0x203A, [0x9C] = 0x0153,
	[0x9E] = 0x017E, [0x9F] = 0x0178,
}

local function toUtf8(cp)
	if cp < 0x80 then
		return string.char(cp)
	elseif cp < 0x800 then
		return string.char(0xC0 + math.floor(cp / 64), 0x80 + cp % 64)
	end
	return string.char(0xE0 + math.floor(cp / 4096), 0x80 + math.floor(cp / 64) % 64, 0x80 + cp % 64)
end

local function isValidUtf8(s)
	local i, n = 1, string.len(s)
	while i <= n do
		local c = string.byte(s, i)
		local tail
		if c < 0x80 then
			tail = 0
		elseif c >= 0xC2 and c <= 0xDF then
			tail = 1
		elseif c >= 0xE0 and c <= 0xEF then
			tail = 2
		elseif c >= 0xF0 and c <= 0xF4 then
			tail = 3
		else
			return false
		end
		for j = 1, tail do
			local d = string.byte(s, i + j)
			if not d or d < 0x80 or d > 0xBF then
				return false
			end
		end
		i = i + tail + 1
	end
	return true
end

-- Windows-1252 string to UTF-8; an already valid string is unchanged
function G.Utf8Text(s)
	if type(s) ~= "string" or isValidUtf8(s) then
		return s
	end
	return (string.gsub(s, "[\128-\255]", function(ch)
		local b = string.byte(ch)
		return toUtf8(CP1252[b] or b)
	end))
end

-- the menu that opens (or fills) the list; in game the client keeps the frame itself
local function opener()
	return UIDROPDOWNMENU_OPEN_MENU or UIDROPDOWNMENU_INIT_MENU
end

local function styleOf(dd)
	return STYLES[dd and dd.foreverStyle or 1]
end

-- ------------------------------------------------------------ button

local function isOpen(dd)
	return DropDownList1:IsShown() and UIDROPDOWNMENU_OPEN_MENU == dd
end

-- GetWowStyle1ArrowButtonState
local function paintStyle1(dd, b)
	local n = "common-dropdown-a-button"
	if not truthy(b:IsEnabled()) then
		n = n .. "-disabled"
	elseif b.down and b.hovered then
		n = n .. "-pressedhover"
	elseif b.hovered then
		n = n .. "-hover"
	elseif b.down then
		n = n .. "-pressed"
	elseif isOpen(dd) then
		n = n .. "-open"
	end
	G.PlaceAtlas(dd.foreverArrow, n, true)
end

-- Paints a style 2 dropdown button from its state.
local function paintStyle2(dd, b)
	local active = truthy(b:IsEnabled())
	local n = "common-dropdown-c-button"
	if not active then
		n = n .. "-disabled"
	elseif b.down and b.hovered then
		n = n .. "-pressedhover-1"
	elseif b.hovered then
		n = n .. "-hover-1"
	elseif b.down then
		n = n .. "-pressed-1"
	elseif isOpen(dd) then
		n = n .. "-open"
	end
	dd.foreverBackground:Place(n)
	G.SetShown(dd.foreverArrow, b.hovered)
	dd.foreverArrow:SetDesaturated(not active)
	local text = _G[dd:GetName() .. "Text"]
	if not text then
		return
	end
	-- the client greys the text with SetVertexColor: reset it and use our color
	text:SetVertexColor(1, 1, 1)
	if active then
		text:SetTextColor(1, 0.82, 0)
	else
		text:SetTextColor(0.5, 0.5, 0.5)
	end
	-- SetDisplacedRegions(2, -1, Text)
	local dx, dy = 0, 0
	if b.down and active then
		dx, dy = 2, -1
	end
	text:ClearAllPoints()
	text:SetPoint("LEFT", b, "LEFT", 13 + dx, dy)
	text:SetPoint("RIGHT", b, "RIGHT", -13 + dx, dy)
end

local function paintButton(dd)
	local b = dd.foreverButton
	if dd.foreverStyle == 2 then
		paintStyle2(dd, b)
	else
		paintStyle1(dd, b)
	end
end

-- Skins a client dropdown; style: 1 (WowStyle1, default) or 2 (WowStyle2, settings)
function G.DropDown(dd, style)
	if dd.foreverButton then
		return
	end
	dd.foreverStyle = style or 1
	local name = dd:GetName()
	local left, right = _G[name .. "Left"], _G[name .. "Right"]
	for _, suffix in ipairs({ "Left", "Middle", "Right" }) do
		local piece = _G[name .. suffix]
		if piece then
			piece:SetAlpha(0)
		end
	end
	-- The button sits inside the visible part of the 3.3.5 frame (CharacterCreate-LabelFrame
	-- is opaque from 16 to 111 of 128 wide, 19 to 45 of 64 high); the whole box opens the list
	local b = _G[name .. "Button"]
	if not b then
		return
	end
	dd.foreverButton = b
	b:ClearAllPoints()
	if left and right then
		b:SetPoint("TOPLEFT", left, "TOPLEFT", 16, -19)
		b:SetPoint("RIGHT", right, "RIGHT", -17, 0)
	end
	b:SetHeight(25)
	G.ClearClientArt(b)
	-- background as a region of the dropdown, below its text; the box (child frame) holds only
	-- the arrow
	local text = _G[name .. "Text"]
	if text then
		text:SetHeight(dd.foreverStyle == 2 and 20 or 10)
		text:ClearAllPoints()
	end
	dd.foreverArrow = b:CreateTexture(nil, "OVERLAY")
	if dd.foreverStyle == 2 then
		dd.foreverBackground = G.StretchedAtlas(dd, "common-dropdown-c-button", "BACKGROUND")
		dd.foreverBackground.rect:SetPoint("TOPLEFT", b, "TOPLEFT", -7, 7)
		dd.foreverBackground.rect:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 7, -7)
		G.PlaceAtlas(dd.foreverArrow, "common-dropdown-c-button-hover-arrow", true)
		dd.foreverArrow:SetPoint("BOTTOM", b, "BOTTOM", 0, -5)
		if text then
			text:SetFontObject(G.Font("GameFontNormalSmall"))
			text:SetJustifyH("CENTER")
		end
	else
		local background = G.StretchedAtlas(dd, "common-dropdown-textholder", "BACKGROUND")
		background.rect:SetPoint("TOPLEFT", b, "TOPLEFT", -8, 7)
		background.rect:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 8, -9)
		G.PlaceAtlas(dd.foreverArrow, "common-dropdown-a-button", true)
		dd.foreverArrow:SetPoint("RIGHT", b, "RIGHT", 1, -3)
		if text then
			text:SetFontObject(G.Font("GameFontHighlight"))
			text:SetJustifyH("LEFT")
			text:SetPoint("TOPLEFT", b, "TOPLEFT", 8, -8)
			text:SetPoint("TOPRIGHT", dd.foreverArrow, "LEFT", 0, 0)
		end
	end
	G.Hook(b, "OnEnter", function(self) self.hovered = true; paintButton(dd) end)
	G.Hook(b, "OnLeave", function(self) self.hovered = false; paintButton(dd) end)
	G.Hook(b, "OnMouseDown", function(self) self.down = true; paintButton(dd) end)
	G.Hook(b, "OnMouseUp", function(self) self.down = false; paintButton(dd) end)
	G.Hook(b, "OnDisable", function() paintButton(dd) end)
	G.Hook(b, "OnEnable", function() paintButton(dd) end)
	-- the dropdown's own hover (its tooltip) stays the client's; the box relays it
	G.Hook(b, "OnEnter", function()
		local onEnter = dd:GetScript("OnEnter")
		if onEnter then onEnter(dd) end
	end)
	G.Hook(b, "OnLeave", function()
		local onLeave = dd:GetScript("OnLeave")
		if onLeave then onLeave(dd) end
	end)
	paintButton(dd)
end

-- ------------------------------------------------------------ list

-- both backgrounds, shown by the style of the opening menu
local function skinList(l)
	if l.foreverBackgrounds then
		return
	end
	local name = l:GetName()
	for _, suffix in ipairs({ "Backdrop", "MenuBackdrop" }) do
		local c = _G[name .. suffix]
		if c and c.SetBackdrop then
			c:SetBackdrop(nil)
		end
	end
	l.foreverBackgrounds = {}
	for i, s in ipairs(STYLES) do
		local background = G.StretchedAtlas(l, s.background, "BACKGROUND")
		background.rect:SetPoint("TOPLEFT", l, "TOPLEFT", s.backgroundA[1], s.backgroundA[2])
		background.rect:SetPoint("BOTTOMRIGHT", l, "BOTTOMRIGHT", s.backgroundB[1], s.backgroundB[2])
		background.rect:SetAlpha(s.alpha)
		for _, t in ipairs(background.pieces) do
			t:SetAlpha(s.alpha)
		end
		l.foreverBackgrounds[i] = background
	end
end

local function showBackground(l, dd)
	local style = dd and dd.foreverStyle or 1
	for i, background in ipairs(l.foreverBackgrounds) do
		background:SetShown(i == style)
	end
end

-- A row: a radio under the client check (which becomes the yellow dot), text on its right.
local function skinRow(b)
	if b.foreverCircle then
		return
	end
	local circle = b:CreateTexture(nil, "BORDER")
	G.PlaceAtlas(circle, "common-dropdown-tickradial", true)
	circle:SetPoint("LEFT", b, "LEFT", -3, 0)
	b.foreverCircle = circle
	local point = _G[b:GetName() .. "Check"]
	if point then
		G.PlaceAtlas(point, "common-dropdown-icon-radialtick-yellow", true)
		point:ClearAllPoints()
		point:SetPoint("TOPLEFT", circle, "TOPLEFT")
	end
	local hover = _G[b:GetName() .. "Highlight"]
	if hover then
		hover:SetTexture(HOVER)
		hover:SetBlendMode("ADD")
		hover:ClearAllPoints()
		hover:SetAllPoints(b)
	end
end

-- width: the content's, at least the button's on the first level of a dropdown;
-- rows stay inside the margins
local function width(l, level)
	local dd = opener()
	local m = styleOf(dd).margins
	local wantedValue = (l.foreverContent or 0) + m[1] + m[3]
	if level == 1 and dd and dd.foreverButton and dd.displayMode ~= "MENU" then
		wantedValue = math.max(wantedValue, dd.foreverButton:GetWidth() or 0)
	end
	if not wantedValue or wantedValue <= 0 then
		return
	end
	l:SetWidth(wantedValue)
	for i = 1, (l.numButtons or 0) do
		_G[l:GetName() .. "Button" .. i]:SetWidth(wantedValue - m[1] - m[3])
	end
end

-- after UIDropDownMenu_AddButton: places the row, its font and its radio, and sizes
-- the list height
G.HookFunction("UIDropDownMenu_AddButton", function(info, level)
	level = level or 1
	local l = _G["DropDownList" .. level]
	if not l then
		return
	end
	skinList(l)
	local dd = opener()
	showBackground(l, dd)
	local m = styleOf(dd).margins
	local i = l.numButtons or 1
	local b = _G[l:GetName() .. "Button" .. i]
	if not b then
		return
	end
	skinRow(b)
	local raw = b:GetText()
	local clean = G.Utf8Text(raw)
	if clean ~= raw then
		b:SetText(clean)
	end
	b:SetHeight(ROWS)
	b:ClearAllPoints()
	b:SetPoint("TOPLEFT", l, "TOPLEFT", m[1], -(m[2] + (i - 1) * ROWS))
	b:SetNormalFontObject(G.Font("GameFontHighlightSmallLeft"))
	b:SetHighlightFontObject(G.Font("GameFontHighlightSmallLeft"))
	if info and info.isTitle then
		b:SetDisabledFontObject(G.Font("GameFontNormalSmallLeft"))
	elseif info and info.notClickable then
		b:SetDisabledFontObject(G.Font("GameFontHighlightSmallLeft"))
	else
		b:SetDisabledFontObject(G.Font("GameFontDisableSmallLeft"))
	end
	local text = _G[b:GetName() .. "NormalText"]
	if not text then
		return
	end
	local checkMark = not (info and info.notCheckable)
	G.SetShown(b.foreverCircle, checkMark)
	text:ClearAllPoints()
	if checkMark then
		text:SetPoint("LEFT", b.foreverCircle, "RIGHT", 1, 0)
	elseif info and info.justifyH == "CENTER" then
		text:SetPoint("CENTER", b, "CENTER", 0, 0)
	else
		text:SetPoint("LEFT", b, "LEFT", 0, 0)
	end
	-- row extent (MeasureFrameExtents + 20 padding)
	local e = (checkMark and EXTENT or 20) + (text:GetStringWidth() or 0)
	if i == 1 or e > (l.foreverContent or 0) then
		l.foreverContent = e
	end
	l:SetHeight(m[2] + i * ROWS + m[4])
end)

-- After ToggleDropDownMenu: the list goes under the button at its width and the arrow shows
-- the open state.
G.HookFunction("ToggleDropDownMenu", function(level)
	level = level or 1
	local l = _G["DropDownList" .. level]
	if not (l and l:IsShown()) then
		return
	end
	width(l, level)
	local dd = opener()
	if level == 1 and dd and dd.foreverButton and dd.displayMode ~= "MENU" then
		l:ClearAllPoints()
		l:SetPoint("TOPLEFT", dd.foreverButton, "BOTTOMLEFT", 0, 0)
	end
	if dd and dd.foreverButton then
		paintButton(dd)
	end
end)

-- The client sets it with the frame first (UIDropDownMenu_SetText(frame, text)); the text is
-- converted like the rows.
G.HookFunction("UIDropDownMenu_SetText", function(a, b)
	local dd, text = a, b
	if type(a) ~= "table" then
		dd, text = b, a
	end
	local fs = dd and dd.GetName and _G[dd:GetName() .. "Text"]
	local clean = G.Utf8Text(text)
	if fs and clean ~= text then
		fs:SetText(clean)
	end
end)

-- the arrow returns to rest when the list closes
for i = 1, LEVELS do
	local l = _G["DropDownList" .. i]
	if l then
		G.Hook(l, "OnShow", function(self)
			-- the client OnShow resizes the list to its text
			width(self, i)
		end)
		G.Hook(l, "OnHide", function()
			local dd = opener()
			if dd and dd.foreverButton then
				paintButton(dd)
			end
		end)
	end
end
