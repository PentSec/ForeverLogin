-- AddOns list over the client's data: a black translucent background like the realm list,
-- no categories or groups (absent in 3.3.5). The client window is hidden but its logic stays:
-- OK and Cancel call AddonList_OnOk / AddonList_OnCancel, and Esc and Enter keep working.

local G = ForeverLogin
local L = G.L

-- strings missing from 3.3.5: G.L (ForeverLoginTexts)
local TEXT = { SEARCH = L.GLUEADDONLIST_SEARCH }

local NOTE = "Interface\\Buttons\\UI-GuildButton-PublicNote-Up"
local STAR = "Interface\\Glues\\CharacterSelect\\Glues-AddOn-Icons"
local HOVER = "Interface\\QuestFrame\\UI-QuestTitleHighlight"
local SOUND = { yes = "igMainMenuOptionCheckBoxOn", no = "igMainMenuOptionCheckBoxOff" }

local M = {
	width = 600, height = 550, y = 24,
	-- listRightNoBar: without the bar, rows (at 7 + 5 = 12, 3 inside the inset that starts
	-- at 9) keep the same 3 px margin on the inset's right (594): they end at 591, the list
	-- (with its 5 margin) at 596
	listLeft = 7, listTop = 65, listRight = 34, listRightNoBar = 4, listBottom = 28,
	margin = 5, rowH = 16, gap = 8, wheel = 2,
	menuW = 140, menuH = 25, menuRowH = 20, menuMargins = { 8, 8, 8, 15 },
	tooltipW = 200,
}
M.step = M.rowH + M.gap
M.listW = M.width - M.listLeft - M.listRight
M.listView = M.height - M.listTop - M.listBottom

-- 3.3.5 returns 1 / nil, sometimes 0 / 1: zero is true in Lua
local function truthy(v)
	return v and v ~= 0 and true or false
end

-- Sets a button or checkbox state texture to an atlas entry covering the whole button.
-- set, get: texture setter and getter names; mode: optional blend mode
local function applyState(b, set, get, name, mode)
	local t = G.StateTexture(b, set, get)
	G.PlaceAtlas(t, name)
	t:ClearAllPoints()
	t:SetAllPoints(b)
	if mode then
		t:SetBlendMode(mode)
	end
	return t
end

-- MinimalCheckboxArtTemplate
local function skinMinimalCheckbox(c)
	applyState(c, "SetNormalTexture", "GetNormalTexture", "checkbox-minimal")
	applyState(c, "SetPushedTexture", "GetPushedTexture", "checkbox-minimal")
	applyState(c, "SetHighlightTexture", "GetHighlightTexture", "checkbox-minimal", "ADD")
	applyState(c, "SetCheckedTexture", "GetCheckedTexture", "checkmark-minimal")
	applyState(c, "SetDisabledCheckedTexture", "GetDisabledCheckedTexture", "checkmark-minimal-disabled")
end

-- ------------------------------------------------------------ Client window

-- fully hidden: art, child frames, mouse; alpha is the only setting no client code resets
AddonListBackground:SetAlpha(0)
AddonListBackground:Hide()
G.Hook(AddonListBackground, "OnShow", function(self)
	self:Hide()
end)

-- ------------------------------------------------------------ Window

local F = CreateFrame("Frame", "ForeverLoginAddonList", AddonList)
F:SetWidth(M.width)
F:SetHeight(M.height)
F:SetPoint("CENTER", AddonList, "CENTER", 0, M.y)
F:EnableMouse(true)
G.Window(F, ADDON_LIST, true)
local inset = CreateFrame("Frame", nil, F)
inset:SetPoint("TOPLEFT", F, "TOPLEFT", 9, -60)
inset:SetPoint("BOTTOMRIGHT", F, "BOTTOMRIGHT", -6, 26)
G.Inset(F, inset, true)

-- controls draw above the list: a half-scrolled row overflows the list frame
local FRONT_LEVEL = F:GetFrameLevel() + 10

local closeButton = CreateFrame("Button", "ForeverLoginAddonListCloseButton", F)
closeButton:SetFrameLevel(FRONT_LEVEL + 1)
G.WindowCloseButton(closeButton, F)
closeButton:SetScript("OnClick", function()
	AddonList_OnCancel()
end)

local state = { character = nil, rows = {}, position = 0, isOpen = false }
local update

-- ------------------------------------------------------------ Tooltip

local tooltipFrame = CreateFrame("Frame", "ForeverLoginAddonListTooltip", AddonList)
tooltipFrame:SetFrameStrata("TOOLTIP")
tooltipFrame:SetClampedToScreen(true)
tooltipFrame:Hide()
G.TooltipBackground(tooltipFrame, "TooltipDefaultLayout", G.GLUE_BACKDROP_COLOR)
tooltipFrame.title = tooltipFrame:CreateFontString(nil, "ARTWORK")
tooltipFrame.title:SetFontObject(G.Font("GlueFontNormal"))
tooltipFrame.title:SetJustifyH("LEFT")
tooltipFrame.title:SetPoint("TOPLEFT", tooltipFrame, "TOPLEFT", 10, -10)
tooltipFrame.version = tooltipFrame:CreateFontString(nil, "ARTWORK")
tooltipFrame.version:SetFontObject(G.Font("GlueFontNormal"))
tooltipFrame.version:SetJustifyH("RIGHT")
tooltipFrame.version:SetPoint("TOPRIGHT", tooltipFrame, "TOPRIGHT", -10, -10)
tooltipFrame.notes = tooltipFrame:CreateFontString(nil, "ARTWORK")
tooltipFrame.notes:SetFontObject(G.Font("GlueFontNormalSmall"))
tooltipFrame.notes:SetJustifyH("LEFT")
tooltipFrame.notes:SetTextColor(1, 1, 1)
tooltipFrame.notes:SetPoint("TOPLEFT", tooltipFrame.title, "BOTTOMLEFT", 0, -2)
tooltipFrame.deps = tooltipFrame:CreateFontString(nil, "ARTWORK")
tooltipFrame.deps:SetFontObject(G.Font("GlueFontNormalSmall"))
tooltipFrame.deps:SetJustifyH("LEFT")
tooltipFrame.deps:SetTextColor(1, 0.82, 0)

-- Lines: title, version, notes, deps. Text wraps at the title width, at least 200
-- (the 3.3.5 AddOn tooltip width; the engine wraps the remainder).
local function showTooltip(owner, title, version, notes, deps)
	tooltipFrame.title:SetText(title or "")
	tooltipFrame.version:SetText(version or "")
	local l = tooltipFrame.title:GetStringWidth()
	if version and version ~= "" then
		l = l + 20 + tooltipFrame.version:GetStringWidth()
	end
	local wrapWidth = math.max(M.tooltipW, l)
	local h = tooltipFrame.title:GetHeight()
	local below = tooltipFrame.title
	for _, v in ipairs({ { tooltipFrame.notes, notes }, { tooltipFrame.deps, deps } }) do
		local fs, text = v[1], v[2]
		if text and text ~= "" then
			fs:SetWidth(wrapWidth)
			fs:SetText(text)
			fs:ClearAllPoints()
			fs:SetPoint("TOPLEFT", below, "BOTTOMLEFT", 0, -2)
			fs:Show()
			h = h + 2 + fs:GetHeight()
			below = fs
		else
			fs:SetText("")
			fs:Hide()
		end
	end
	if (notes and notes ~= "") or (deps and deps ~= "") then
		l = wrapWidth
	end
	tooltipFrame:SetWidth(l + 20)
	tooltipFrame:SetHeight(h + 20)
	tooltipFrame:ClearAllPoints()
	tooltipFrame:SetPoint("BOTTOMLEFT", owner, "TOPRIGHT", -270, 0)
	tooltipFrame:Show()
end

-- TOC field of an AddOn, or nil when GetAddOnMetadata is missing or fails
local function metadata(index, field)
	if not GetAddOnMetadata then
		return nil
	end
	local ok, v = pcall(GetAddOnMetadata, index, field)
	if ok then
		return v
	end
end

-- Fills and shows the tooltip for one addon row.
local function showAddOnTooltip(row)
	local index = row.index
	local name, title, notes, _, _, _, security = GetAddOnInfo(index)
	if security == "BANNED" then
		showTooltip(row, ADDON_BANNED_TOOLTIP)
	else
		showTooltip(row, title or name, metadata(index, "Version"), notes,
			AddonTooltip_BuildDeps(GetAddOnDependencies(index)))
	end
end

-- ------------------------------------------------------------ Character menu

local menu = CreateFrame("Button", "ForeverLoginAddonListDropdown", F)
menu:SetFrameLevel(FRONT_LEVEL)
menu:SetWidth(M.menuW)
menu:SetHeight(M.menuH)
menu:SetPoint("TOPLEFT", F, "TOPLEFT", 12, -30)
menu:RegisterForClicks("LeftButtonDown")
local menuBackground = G.StretchedAtlas(menu, "common-dropdown-textholder", "BACKGROUND")
menuBackground.rect:SetPoint("TOPLEFT", menu, "TOPLEFT", -8, 7)
menuBackground.rect:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", 8, -9)
menu.arrow = menu:CreateTexture(nil, "OVERLAY")
G.PlaceAtlas(menu.arrow, "common-dropdown-a-button", true)
menu.arrow:SetPoint("RIGHT", menu, "RIGHT", 1, -3)
menu.text = menu:CreateFontString(nil, "OVERLAY")
menu.text:SetFontObject(G.Font("GameFontHighlight"))
menu.text:SetJustifyH("LEFT")
menu.text:SetHeight(10)
menu.text:SetPoint("TOPLEFT", menu, "TOPLEFT", 8, -8)
menu.text:SetPoint("TOPRIGHT", menu.arrow, "LEFT", 0, 0)

-- GetWowStyle1ArrowButtonState
local function paintMenu()
	local n = "common-dropdown-a-button"
	if not truthy(menu:IsEnabled()) then
		n = n .. "-disabled"
	elseif menu.down and menu.hovered then
		n = n .. "-pressedhover"
	elseif menu.hovered then
		n = n .. "-hover"
	elseif menu.down then
		n = n .. "-pressed"
	elseif state.isOpen then
		n = n .. "-open"
	end
	G.PlaceAtlas(menu.arrow, n, true)
end
menu:SetScript("OnEnter", function(self) self.hovered = true; paintMenu() end)
menu:SetScript("OnLeave", function(self) self.hovered = false; paintMenu() end)
menu:SetScript("OnMouseDown", function(self) self.down = true; paintMenu() end)
menu:SetScript("OnMouseUp", function(self) self.down = false; paintMenu() end)

-- the open list (MenuStyle1)
local list = CreateFrame("Frame", "ForeverLoginAddonListDropdownMenu", F)
list:SetFrameStrata("FULLSCREEN_DIALOG")
list:SetFrameLevel(20)
list:EnableMouse(true)
list:Hide()
local listBackground = G.StretchedAtlas(list, "common-dropdown-bg", "BACKGROUND")
listBackground.rect:SetPoint("TOPLEFT", list, "TOPLEFT", -10, 3)
listBackground.rect:SetPoint("BOTTOMRIGHT", list, "BOTTOMRIGHT", 10, -3)
listBackground.rect:SetAlpha(0.925)
for _, t in ipairs(listBackground.pieces) do
	t:SetAlpha(0.925)
end
-- a click outside the list closes it
local catcher = CreateFrame("Button", nil, F)
catcher:SetFrameStrata("FULLSCREEN_DIALOG")
catcher:SetFrameLevel(10)
catcher:SetAllPoints(GlueParent)
catcher:Hide()

local choice = {}

-- Closes the character list; silence: skip the close sound
local function closeList(silence)
	if not state.isOpen then
		return
	end
	state.isOpen = false
	list:Hide()
	catcher:Hide()
	if not silence then
		PlaySound(SOUND.no)
	end
	paintMenu()
end
catcher:SetScript("OnClick", function() closeList() end)

-- ALL, then each character (AddonListCharacterDropDown_Initialize)
local function options()
	local o = { { text = ALL, value = nil } }
	for i = 1, GetNumCharacters() do
		local name = GetCharacterInfo(i)
		o[#o + 1] = { text = name, value = name }
	end
	return o
end

local function selectedText()
	menu.text:SetText(state.character or ALL)
end

-- Returns list entry k, creating it on first use.
local function listItem(k)
	if choice[k] then
		return choice[k]
	end
	local e = CreateFrame("Button", nil, list)
	e:SetHeight(M.menuRowH)
	e.hover = e:CreateTexture(nil, "BACKGROUND")
	e.hover:SetTexture(HOVER)
	e.hover:SetBlendMode("ADD")
	e.hover:SetAllPoints(e)
	e.hover:Hide()
	e.circle = e:CreateTexture(nil, "ARTWORK")
	G.PlaceAtlas(e.circle, "common-dropdown-tickradial", true)
	e.circle:SetPoint("LEFT", e, "LEFT", -3, 0)
	e.point = e:CreateTexture(nil, "OVERLAY")
	G.PlaceAtlas(e.point, "common-dropdown-icon-radialtick-yellow", true)
	e.point:SetPoint("TOPLEFT", e.circle, "TOPLEFT")
	e.text = e:CreateFontString(nil, "ARTWORK")
	e.text:SetFontObject(G.Font("GameFontHighlight"))
	e.text:SetJustifyH("LEFT")
	e.text:SetHeight(M.menuRowH)
	e.text:SetPoint("LEFT", e.circle, "RIGHT", 1, 0)
	e:SetScript("OnEnter", function(self) self.hover:Show() end)
	e:SetScript("OnLeave", function(self) self.hover:Hide() end)
	e:SetScript("OnClick", function(self)
		PlaySound(SOUND.yes)
		state.character = self.value
		selectedText()
		closeList()
		update()
	end)
	choice[k] = e
	return e
end

local function openList()
	local o = options()
	local g, h, d, b = M.menuMargins[1], M.menuMargins[2], M.menuMargins[3], M.menuMargins[4]
	-- row width: radio (-3 .. 15), 1, text; plus 20
	local wide = 0
	for k, v in ipairs(o) do
		local e = listItem(k)
		e.text:SetText(v.text)
		wide = math.max(wide, 16 + e.text:GetStringWidth() + 20)
	end
	wide = math.max(wide, M.menuW - g - d)
	for k, v in ipairs(o) do
		local e = choice[k]
		e.value = v.value
		e:SetWidth(wide)
		e:ClearAllPoints()
		e:SetPoint("TOPLEFT", list, "TOPLEFT", g, -(h + (k - 1) * M.menuRowH))
		G.SetShown(e.point, v.value == state.character)
		e.hover:Hide()
		e:Show()
	end
	for k = #o + 1, #choice do
		choice[k]:Hide()
	end
	list:SetWidth(g + wide + d)
	list:SetHeight(h + #o * M.menuRowH + b)
	list:ClearAllPoints()
	list:SetPoint("TOPLEFT", menu, "BOTTOMLEFT", 0, 0)
	state.isOpen = true
	list:Show()
	catcher:Show()
	PlaySound(SOUND.yes)
	paintMenu()
end
menu:SetScript("OnClick", function()
	if state.isOpen then
		closeList()
	else
		openList()
	end
end)

-- ------------------------------------------------------------ Out of date AddOns

local force = CreateFrame("CheckButton", "ForeverLoginAddonListForceLoad", F)
force:SetFrameLevel(FRONT_LEVEL)
force:SetWidth(30)
force:SetHeight(29)
force:SetPoint("TOP", F, "TOP", -80, -27)
skinMinimalCheckbox(force)
force.text = force:CreateFontString(nil, "ARTWORK")
force.text:SetFontObject(G.Font("GameFontNormalSmall"))
force.text:SetPoint("LEFT", force, "LEFT", 36, 0)
force.text:SetText(ADDON_FORCE_LOAD)
force:SetScript("OnClick", function(self)
	if truthy(self:GetChecked()) then
		PlaySound(SOUND.yes)
		SetAddonVersionCheck(0)
	else
		PlaySound(SOUND.no)
		SetAddonVersionCheck(1)
	end
	update()
end)

-- ------------------------------------------------------------ Search

local searching = CreateFrame("EditBox", "ForeverLoginAddonListSearchBox", F)
searching:SetFrameLevel(FRONT_LEVEL)
searching:SetWidth(160)
searching:SetHeight(22)
searching:SetPoint("TOPRIGHT", F, "TOPRIGHT", -10, -31)
searching:SetAutoFocus(false)
searching:EnableMouse(true)
searching:SetFontObject(G.Font("GameFontHighlightSmall"))
searching:SetTextInsets(16, 20, 0, 0)
do
	local g = searching:CreateTexture(nil, "BACKGROUND")
	G.PlaceAtlas(g, "common-search-border-left")
	g:SetWidth(8)
	g:SetHeight(20)
	g:SetPoint("LEFT", searching, "LEFT", -5, 0)
	local d = searching:CreateTexture(nil, "BACKGROUND")
	G.PlaceAtlas(d, "common-search-border-right")
	d:SetWidth(8)
	d:SetHeight(20)
	d:SetPoint("RIGHT", searching, "RIGHT", 0, 0)
	local m = searching:CreateTexture(nil, "BACKGROUND")
	G.PlaceAtlas(m, "common-search-border-middle")
	m:SetHeight(20)
	m:SetPoint("LEFT", g, "RIGHT")
	m:SetPoint("RIGHT", d, "LEFT")
end
searching.magnifier = searching:CreateTexture(nil, "OVERLAY")
G.PlaceAtlas(searching.magnifier, "common-search-magnifyingglass")
searching.magnifier:SetWidth(10)
searching.magnifier:SetHeight(10)
searching.magnifier:SetPoint("LEFT", searching, "LEFT", 1, -1)
searching.instruction = searching:CreateFontString(nil, "ARTWORK")
searching.instruction:SetFontObject(G.Font("GameFontDisableSmall"))
searching.instruction:SetJustifyH("LEFT")
searching.instruction:SetJustifyV("MIDDLE")
searching.instruction:SetPoint("TOPLEFT", searching, "TOPLEFT", 16, 0)
searching.instruction:SetPoint("BOTTOMRIGHT", searching, "BOTTOMRIGHT", -20, 0)
searching.instruction:SetTextColor(0.35, 0.35, 0.35)
searching.instruction:SetText(TEXT.SEARCH)

local clear = CreateFrame("Button", nil, searching)
clear:SetWidth(17)
clear:SetHeight(17)
clear:SetPoint("RIGHT", searching, "RIGHT", -3, 0)
clear.icon = clear:CreateTexture(nil, "ARTWORK")
G.PlaceAtlas(clear.icon, "common-search-clearbutton")
clear.icon:SetWidth(10)
clear.icon:SetHeight(10)
clear.icon:SetPoint("TOPLEFT", clear, "TOPLEFT", 3, -3)
clear.icon:SetAlpha(0.5)
clear:SetScript("OnEnter", function(self) self.icon:SetAlpha(1) end)
clear:SetScript("OnLeave", function(self) self.icon:SetAlpha(0.5) end)
clear:SetScript("OnMouseDown", function(self) self.icon:SetPoint("TOPLEFT", self, "TOPLEFT", 4, -4) end)
clear:SetScript("OnMouseUp", function(self) self.icon:SetPoint("TOPLEFT", self, "TOPLEFT", 3, -3) end)
clear:SetScript("OnClick", function()
	PlaySound(SOUND.yes)
	searching:SetText("")
	searching:ClearFocus()
end)
clear:Hide()

-- SearchBoxTemplate_On*: grey magnifier and hidden clear button when idle
local function paintSearch()
	local empty = (searching:GetText() or "") == ""
	local active = searching.focus or not empty
	local g = active and 1 or 0.6
	searching.magnifier:SetVertexColor(g, g, g)
	G.SetShown(clear, active)
	G.SetShown(searching.instruction, empty)
end
searching:SetScript("OnEditFocusGained", function(self) self.focus = true; paintSearch() end)
searching:SetScript("OnEditFocusLost", function(self) self.focus = false; paintSearch() end)
searching:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
searching:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
searching:SetScript("OnTextChanged", function()
	paintSearch()
	update()
end)
paintSearch()

-- ------------------------------------------------------------ List

local view = CreateFrame("ScrollFrame", "ForeverLoginAddonListScrollBox", F)
view:SetPoint("TOPLEFT", F, "TOPLEFT", M.listLeft, -M.listTop)
view:SetPoint("BOTTOMRIGHT", F, "BOTTOMRIGHT", -M.listRight, M.listBottom)
local content = CreateFrame("Frame", nil, view)
content:SetWidth(M.listW)
content:SetHeight(1)
view:SetScrollChild(content)

local bar = G.MinimalBar(F, "ForeverLoginAddonListScrollBar")
bar:SetPoint("TOPLEFT", view, "TOPRIGHT", 4, -3)
bar:SetPoint("BOTTOMLEFT", view, "BOTTOMRIGHT", 4, 2)
bar.step = M.step

-- the bar only when needed; without it the list and its rows widen
-- (M.listRightNoBar), with it they use M.listRight.
bar.hideIfUnneeded = true
local function rowWidth()
	return M.width - M.listLeft - (bar:IsShown() and M.listRight or M.listRightNoBar) - 2 * M.margin
end
bar.onVisibility = function(hasBar)
	local d = hasBar and M.listRight or M.listRightNoBar
	view:SetPoint("BOTTOMRIGHT", F, "BOTTOMRIGHT", -d, M.listBottom)
	content:SetWidth(M.width - M.listLeft - d)
	for _, l in ipairs(state.rows) do
		l:SetWidth(rowWidth())
	end
end

-- a row fully outside the view is hidden
local function scrollTo(position)
	state.position = position
	view:SetVerticalScroll(position)
	for k, l in ipairs(state.rows) do
		if l.rank then
			local top = M.margin + (l.rank - 1) * M.step
			G.SetShown(l, top + M.rowH > position and top < position + M.listView)
		end
	end
end
bar.onScroll = scrollTo

view:EnableMouseWheel(true)
view:SetScript("OnMouseWheel", function(_, direction)
	bar:MoveTo(bar.position - direction * M.wheel * M.step)
end)

-- Returns list row k, creating it on first use.
local function row(k)
	if state.rows[k] then
		return state.rows[k]
	end
	local l = CreateFrame("Button", nil, content)
	l:SetHeight(M.rowH)
	l:SetWidth(rowWidth())
	l:SetPoint("TOPLEFT", content, "TOPLEFT", M.margin, -(M.margin + (k - 1) * M.step))
	l:RegisterForClicks("LeftButtonDown", "RightButtonDown")
	local s = l:CreateTexture(nil, "HIGHLIGHT")
	s:SetTexture(HOVER)
	s:SetBlendMode("ADD")
	s:SetHeight(22)
	s:SetPoint("LEFT", l, "LEFT", 40, 0)
	s:SetPoint("RIGHT", l, "RIGHT")
	l.title = l:CreateFontString(nil, "BACKGROUND")
	l.title:SetFontObject(G.Font("GameFontNormal"))
	l.title:SetJustifyH("LEFT")
	l.title:SetWidth(300)
	l.title:SetHeight(12)
	l.title:SetPoint("LEFT", l, "LEFT", 32, 0)
	-- the URL button and the update button, at the same place
	l.url = CreateFrame("Button", nil, l)
	l.url:SetNormalTexture(NOTE)
	G.StateTexture(l.url, "SetHighlightTexture", "GetHighlightTexture"):SetBlendMode("ADD")
	l.update = CreateFrame("Button", nil, l)
	l.update:SetNormalTexture(STAR)
	G.StateTexture(l.update, "SetNormalTexture", "GetNormalTexture"):SetTexCoord(0.75, 1, 0, 1)
	G.StateTexture(l.update, "SetHighlightTexture", "GetHighlightTexture"):SetTexCoord(0.75, 1, 0, 1)
	G.StateTexture(l.update, "SetHighlightTexture", "GetHighlightTexture"):SetBlendMode("ADD")
	for _, b in ipairs({ l.url, l.update }) do
		b:SetWidth(16)
		b:SetHeight(16)
		b:SetPoint("LEFT", l.title, "RIGHT", 0, 0)
		b:Hide()
		b:SetScript("OnEnter", function(self)
			GlueTooltip_SetOwner(self)
			GlueTooltip_SetText(self.tooltip)
		end)
		b:SetScript("OnLeave", function() GlueTooltip:Hide() end)
		-- the client's click: AddonList.selectedID, then the confirmation
		b:SetScript("OnClick", function(self)
			AddonList.selectedID = self:GetParent().index
			AddonDialog_Show("CONFIRM_LAUNCH_ADDON_URL", self.url)
		end)
	end
	l.status = l:CreateFontString(nil, "BACKGROUND")
	l.status:SetFontObject(G.Font("GameFontNormalSmall"))
	l.status:SetJustifyH("LEFT")
	l.status:SetPoint("RIGHT", l, "RIGHT", 0, 0)
	local c = CreateFrame("CheckButton", nil, l)
	c:SetWidth(24)
	c:SetHeight(24)
	c:SetPoint("LEFT", l, "LEFT", 5, 0)
	c:SetHitRectInsets(0, 0, 0, 8)
	skinMinimalCheckbox(c)
	l.checkbox = c
	-- AddonList_Enable
	c:SetScript("OnClick", function(self)
		local index = self:GetParent().index
		if truthy(self:GetChecked()) then
			PlaySound(SOUND.yes)
			EnableAddOn(state.character, index)
		else
			PlaySound(SOUND.no)
			DisableAddOn(state.character, index)
		end
		update()
	end)
	c:SetScript("OnEnter", function(self)
		if self.tooltip then
			showTooltip(self, self.tooltip)
		end
	end)
	c:SetScript("OnLeave", function() tooltipFrame:Hide() end)
	l:SetScript("OnClick", function(self, button)
		if button == "LeftButton" then
			self.checkbox:Click()
		end
	end)
	l:SetScript("OnEnter", function(self) showAddOnTooltip(self) end)
	l:SetScript("OnLeave", function() tooltipFrame:Hide() end)
	state.rows[k] = l
	return l
end

-- Builds one addon row from GetAddOnInfo and GetAddOnEnableState.
local function populate(l, index)
	local name, title, _, url, loadable, reason, _, newVersion = GetAddOnInfo(index)
	local level = GetAddOnEnableState(state.character, index) or 0
	local active = level > 0
	l.index = index
	local c = l.checkbox
	c:SetChecked(active)
	c:GetCheckedTexture():SetDesaturated(level == 1)
	c.tooltip = (level == 1) and ENABLED_FOR_SOME or nil
	if loadable or (active and (reason == "DEP_DEMAND_LOADED" or reason == "DEMAND_LOADED")) then
		l.title:SetTextColor(1.0, 0.78, 0.0)
	elseif active and reason ~= "DEP_DISABLED" then
		l.title:SetTextColor(1.0, 0.1, 0.1)
	else
		l.title:SetTextColor(0.5, 0.5, 0.5)
	end
	l.title:SetText(title or name or "")
	-- 3.3.5 AddonList_Update: the star when a newer version is announced, else the note,
	-- when there is a URL
	l.url:Hide()
	l.update:Hide()
	if url then
		local b = newVersion and l.update or l.url
		b.url = url
		b.tooltip = (newVersion and ADDON_UPDATE_AVAILABLE or "") .. CLICK_TO_LAUNCH_ADDON_URL .. url
		b:Show()
	end
	if not loadable and reason then
		l.status:SetText(_G["ADDON_" .. reason] or reason)
	else
		l.status:SetText("")
	end
end

-- Rebuilds the list: filter, rows and extent; the scroll position is kept.
update = function()
	local filter = string.lower(searching:GetText() or "")
	local n = 0
	for index = 1, GetNumAddOns() do
		local name, title = GetAddOnInfo(index)
		if filter == "" or string.find(string.lower(title or ""), filter, 1, true)
			or string.find(string.lower(name or ""), filter, 1, true) then
			n = n + 1
			local l = row(n)
			l.rank = n
			populate(l, index)
		end
	end
	for k = n + 1, #state.rows do
		state.rows[k].rank = nil
		state.rows[k]:Hide()
	end
	local total = 0
	if n > 0 then
		total = 2 * M.margin + n * M.rowH + (n - 1) * M.gap
	end
	content:SetHeight(math.max(total, 1))
	view:UpdateScrollChildRect()
	bar:Configure(total, M.listView, state.position)
	scrollTo(bar.position)
	force:SetChecked(not truthy(IsAddonVersionCheckEnabled()))
	selectedText()
end

-- ------------------------------------------------------------ Buttons

local FONTS = { "GameFontNormal", "GameFontHighlight", "GameFontDisable" }
local cancel = G.CreateThreeSliceButton("ForeverLoginAddonListCancelButton", F, 80, 22, "128-RedButton", FONTS, CANCEL)
cancel:SetPoint("BOTTOMRIGHT", F, "BOTTOMRIGHT", -4, 4)
cancel:SetScript("OnClick", function() AddonList_OnCancel() end)
local ok = G.CreateThreeSliceButton("ForeverLoginAddonListOkayButton", F, 80, 22, "128-RedButton", FONTS, OKAY)
ok:SetPoint("TOPRIGHT", cancel, "TOPLEFT", 0, 0)
ok:SetScript("OnClick", function() AddonList_OnOk() end)
local all = G.CreateThreeSliceButton("ForeverLoginAddonListEnableAllButton", F, 120, 22, "128-RedButton", FONTS, ENABLE_ALL_ADDONS)
all:SetPoint("BOTTOMLEFT", F, "BOTTOMLEFT", 4, 4)
all:SetScript("OnClick", function()
	EnableAllAddOns(state.character)
	update()
end)
local none = G.CreateThreeSliceButton("ForeverLoginAddonListDisableAllButton", F, 120, 22, "128-RedButton", FONTS, DISABLE_ALL_ADDONS)
none:SetPoint("TOPLEFT", all, "TOPRIGHT", 0, 0)
none:SetScript("OnClick", function()
	DisableAllAddOns(state.character)
	update()
end)
for _, b in ipairs({ cancel, ok, all, none }) do
	b:SetFrameLevel(FRONT_LEVEL)
end

-- ------------------------------------------------------------ After the client

G.HookFunction("AddonList_Update", function()
	update()
end)
G.Hook(AddonList, "OnHide", function()
	closeList(true)
	tooltipFrame:Hide()
end)

-- ------------------------------------------------------------ Out of date AddOns dialog

local panelButton = G.PanelButton

-- The client's AddonDialog_Show places the buttons and the height
-- (16 + text + 8 + button + 16); only border and fonts are restyled here.
AddonDialogBackground:SetBackdrop(nil)
G.DialogFrame(AddonDialogBackground)
AddonDialogText:SetFontObject(G.Font("GameFontNormalLarge"))
for i = 1, 2 do
	local b = _G["AddonDialogButton" .. i]
	b:SetWidth(120)
	b:SetHeight(22)
	panelButton(b)
end
