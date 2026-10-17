-- Character select screen: a scrolling list of our own character cards (3.3.5 has none).
-- Each card reads GetCharacterInfo and clicks the hidden client buttons; the scale is set on
-- GlueParent.

local G = ForeverLogin
local L = G.L
local ui = CharacterSelectUI
local list = CharacterSelectCharacterFrame

-- Texts missing from 3.3.5: G.L (ForeverLoginTexts)
local TEXT = {
	REALMS = L.GLUECHARACTERSELECT_REALMS,
	MENU = L.GLUECHARACTERSELECT_MENU,
	TOGGLE = L.GLUECHARACTERSELECT_TOGGLE_LIST,
}

-- Faction of a race: GetSelectBackgroundModel token, or the English race name for death
-- knights, whose background is DeathKnight.
local FACTIONS = {
	Human = "Alliance", Dwarf = "Alliance", NightElf = "Alliance", Gnome = "Alliance", Draenei = "Alliance",
	Orc = "Horde", Scourge = "Horde", Tauren = "Horde", Troll = "Horde", BloodElf = "Horde",
	["Night Elf"] = "Alliance", Undead = "Horde", ["Blood Elf"] = "Horde",
}

local state = { offset = 0, maps = {}, visibleCount = {} }

-- ---------- Logo

CharacterSelectLogo:ClearAllPoints()
CharacterSelectLogo:SetPoint("TOPLEFT", ui, "TOPLEFT", 3, -2)

-- ---------- Top bar

local nav = CreateFrame("Frame", "ForeverLoginCharacterSelectNavBar", ui)
nav:SetHeight(55)
nav:SetPoint("TOPLEFT", ui, "TOPLEFT")
nav:SetPoint("TOPRIGHT", ui, "TOPRIGHT")
local tray = CreateFrame("Frame", nil, nav)
tray:SetPoint("TOP", nav, "TOP")
tray:SetPoint("BOTTOM", nav, "BOTTOM")
tray:SetWidth(1)

-- Top bar button. action: OnClick handler.
local function navButton(text, action)
	local b = CreateFrame("Button", nil, tray)
	b:SetHeight(64)
	b:SetNormalFontObject(G.Font("GlueFontNormal"))
	b:SetHighlightFontObject(G.Font("GlueFontYellow"))
	b:SetDisabledFontObject(G.Font("GlueFontDisable"))
	b:SetText(text)
	b:SetWidth(b:GetTextWidth() + 70)
	b.background = G.StretchedAtlas(b, "glues-characterselect-tophud-middle-bg", "BACKGROUND")
	b.grayed = G.StretchedAtlas(b, "glues-characterselect-tophud-middle-dis-bg", "BACKGROUND")
	b.hover = G.StretchedAtlas(b, "glues-characterselect-tophud-selected-middle", "BORDER")
	b.bar = b:CreateTexture(nil, "OVERLAY")
	G.PlaceAtlas(b.bar, "glues-characterselect-tophud-bg-divider", true)
	b.bar:SetPoint("RIGHT", b, "RIGHT")
	b:SetScript("OnClick", action)
	b:SetScript("OnEnter", function(self) if G.Truthy(self:IsEnabled()) then self.hover:SetShown(true) end end)
	b:SetScript("OnLeave", function(self) self.hover:SetShown(false) end)
	return b
end

local navButtons = {
	navButton(TEXT.REALMS, function() CharacterSelect_ChangeRealm() end),
	navButton(TEXT.MENU, function() G.ToggleMenu() end),
	navButton(string.upper(ADDONS), function() CharacterSelectAddonsButton:Click() end),
}

-- Paints an end piece of the bar.
-- rank: position in the bar; last: true for the last button.
local function paintNav(b, rank, last)
	local background, grayed = "glues-characterselect-tophud-middle-bg", "glues-characterselect-tophud-middle-dis-bg"
	local hover = "glues-characterselect-tophud-selected-middle"
	local fg, fd = 0, 0            -- background overhang, left and right
	local sg, sd = 0, -7           -- hover inset, left and right
	if rank == 1 then
		background, grayed = "glues-characterselect-tophud-left-bg", "glues-characterselect-tophud-left-dis-bg"
		hover = "glues-characterselect-tophud-selected-left"
		fg, sg, sd = -27, 4, -3 - 18
	end
	if last then
		background, grayed = "glues-characterselect-tophud-right-bg", "glues-characterselect-tophud-right-dis-bg"
		hover = "glues-characterselect-tophud-selected-right"
		fd, sg, sd = 27, 9, -10
	end
	for _, obj in ipairs({ { b.background, background }, { b.grayed, grayed } }) do
		obj[1]:Place(obj[2])
		obj[1].rect:ClearAllPoints()
		obj[1].rect:SetPoint("TOPLEFT", b, "TOPLEFT", fg, 0)
		obj[1].rect:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", fd, 0)
	end
	b.hover:Place(hover)
	b.hover.rect:ClearAllPoints()
	b.hover.rect:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", sg, 7)
	b.hover.rect:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", sd, 7)
	b.hover.rect:SetHeight(44)
	b.hover:SetShown(false)
	G.SetShown(b.bar, not last)
	local active = G.Truthy(b:IsEnabled())
	b.background:SetShown(active)
	b.grayed:SetShown(not active)
	G.PlaceAtlas(b.bar, active and "glues-characterselect-tophud-bg-divider" or "glues-characterselect-tophud-bg-divider-dis", true)
end

local function arrangeNav()
	local shownItems = {}
	for i, b in ipairs(navButtons) do
		-- AddOns only if there are any (the client recounts in UpdateAddonButton)
		local visible = (i ~= 3) or (GetNumAddOns() > 0)
		G.SetShown(b, visible)
		if visible then table.insert(shownItems, b) end
	end
	local x = 0
	for i, b in ipairs(shownItems) do
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", tray, "TOPLEFT", x, 0)
		x = x + b:GetWidth()
		paintNav(b, i, i == #shownItems)
	end
	tray:SetWidth(math.max(1, x))
end
arrangeNav()

-- ---------- Character list

CharSelectRealmName:Hide()
CharSelectChangeRealmButton:Hide()
list:SetBackdrop(nil)
list:SetWidth(386)

-- Tiled background, recomputed at the list size (two anchors: its height comes from
-- GetTop - GetBottom).
local listBackground = list:CreateTexture(nil, "BACKGROUND")
listBackground:SetAllPoints(list)
local function placeListBackground()
	local l = (list:GetRight() or 0) - (list:GetLeft() or 0)
	local h = (list:GetTop() or 0) - (list:GetBottom() or 0)
	if l > 0 and h > 0 then
		G.Tile(listBackground, "heavybronze-frame-background", l, h)
	end
end
local listFrame = G.StretchedAtlas(list, "heavybronze-frame-basic", "BORDER")
listFrame.rect:SetPoint("TOPLEFT", list, "TOPLEFT", -9, 15)
listFrame.rect:SetPoint("BOTTOMRIGHT", list, "BOTTOMRIGHT", 9, -15)
for _, e in ipairs({ { "heavybronze-vert-cornerbracket-tr", "TOPRIGHT" }, { "heavybronze-vert-cornerbracket-br", "BOTTOMRIGHT" } }) do
	local t = list:CreateTexture(nil, "ARTWORK")
	G.PlaceAtlas(t, e[1], true)
	t:SetPoint(e[2], listFrame.rect, e[2])
end

-- ---------- Card area

local CARD_W, CARD_H, GAP, LEFT_MARGIN = 347, 95, 2, 122
local PAN = 95
-- Without a scroll bar, cards are centered in the list: the card art (321, 20 to -10 of the
-- card) has its middle at -115 + 122 + 20 + 317 / 2 = 185.5 from the list, whose middle is
-- at 193. With the bar, the layout position.
local CENTERING = 386 / 2 - (-115 + LEFT_MARGIN + 20 + (CARD_W - 30) / 2)
-- So that 10 cards (10 x 95 + 9 x 2 = 968) fit without scrolling: no search box, the
-- area takes its place (top -67 -> -25); the buttons below move down 11 (bottom 83 -> 72)
-- and the paid service button sits at 53 instead of 58.
local ZONE_TOP, DROP, SERVICE = -25, 11, 53

local zone = CreateFrame("ScrollFrame", "ForeverLoginCharacterSelectScrollBox", list)
zone:SetPoint("TOPLEFT", list, "TOPLEFT", -115, ZONE_TOP)
zone:SetPoint("BOTTOMRIGHT", list, "BOTTOMRIGHT", -32, 83 - DROP)
local content = CreateFrame("Frame", nil, zone)
content:SetWidth(386 + 115 - 32)
content:SetHeight(1)
zone:SetScrollChild(content)

local scrollBar = G.MinimalBar(list, "ForeverLoginCharacterSelectScrollBar")
scrollBar:SetPoint("TOP", zone, "TOP", 0, -2)
scrollBar:SetPoint("BOTTOM", zone, "BOTTOM", 0, 4)
scrollBar:SetPoint("RIGHT", list, "RIGHT", -16, 0)
scrollBar.step = PAN
scrollBar.hideIfUnneeded = true
-- Without a scroll bar, the area (which clips the cards) extends over its place up to the
-- bar's right edge (-16): the centered card and its selection frame (-13 to +13) fit.
scrollBar.onVisibility = function(hasBar)
	local right = hasBar and -32 or -16
	zone:SetPoint("BOTTOMRIGHT", list, "BOTTOMRIGHT", right, 83 - DROP)
	content:SetWidth(386 + 115 + right)
end
scrollBar.onScroll = function(position)
	state.offset = position
	zone:SetVerticalScroll(position)
end
zone:EnableMouseWheel(true)
zone:SetScript("OnMouseWheel", function(_, direction)
	scrollBar:MoveTo(scrollBar.position - direction * PAN * 2)
end)

-- ---------- One card

local SERVICES = {
	{ "CharSelectFactionChange", PAID_FACTION_CHANGE, "glues-characterselect-icon-factionchange", PAID_FACTION_CHANGE_TOOLTIP },
	{ "CharSelectRaceChange", PAID_RACE_CHANGE, "glues-characterselect-icon-racechange", PAID_RACE_CHANGE_TOOLTIP },
	{ "CharSelectCharacterCustomize", PAID_CHARACTER_CUSTOMIZATION, "glues-characterselect-icon-appearancechange", PAID_CHARACTER_CUSTOMIZE_TOOLTIP },
}

local function hoverCard(c, hovered)
	c.hovered = hovered
	local selectedItem = c.selectedItem
	G.SetShown(c.selectedHighlight, hovered and selectedItem)
	G.SetShown(c.highlight, hovered and not selectedItem)
	if c.faction then
		-- The selected emblem stays on hover: 3.3.5 cannot reorder characters, so there
		-- are no move arrows to make room for.
		G.SetShown(c.emblemHover, hovered and not selectedItem)
		G.SetShown(c.selectedEmblem, selectedItem)
		G.SetShown(c.emblem, not selectedItem)
	end
end

local function createCard(n)
	local c = CreateFrame("Button", "ForeverLoginCharacterCard" .. n, content)
	c:SetWidth(CARD_W)
	c:SetHeight(CARD_H)
	c:SetHitRectInsets(20, 12, 0, 0)
	c:RegisterForClicks("LeftButtonUp")
	local ic = CreateFrame("Frame", nil, c)
	ic:SetPoint("TOPLEFT", c, "TOPLEFT", 20, 0)
	ic:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -10, 0)
	local function tex(layer, atlas, point, x, y)
		local t = ic:CreateTexture(nil, layer)
		if atlas then G.PlaceAtlas(t, atlas, true) end
		t:SetPoint(point, ic, point, x or 0, y or 0)
		return t
	end
	c.background = tex("BACKGROUND", "glues-characterselect-card-singles", "CENTER")
	c.highlight = tex("BORDER", "glues-characterselect-card-singles-hover", "CENTER")
	c.selected = tex("ARTWORK", "glues-characterselect-card-selected", "TOPLEFT", -13, 14)
	c.selectedHighlight = tex("ARTWORK", "glues-characterselect-card-selected-hover", "TOPLEFT", -13, 14)
	c.emblem = tex("OVERLAY", nil, "TOPRIGHT", -20, -27)
	c.emblemHover = tex("OVERLAY", nil, "TOPRIGHT", -20, -27)
	c.selectedEmblem = tex("OVERLAY", nil, "TOPRIGHT", -17, -25)
	-- Texts (Text, SetAllPoints on InnerContent)
	local function text(font, l, h)
		local f = ic:CreateFontString(nil, "OVERLAY")
		f:SetFontObject(G.Font(font))
		f:SetJustifyH("LEFT")
		f:SetWidth(l)
		f:SetHeight(h)
		return f
	end
	c.name = text("GlueFontNormalHuge", 270, 22)
	c.name:SetPoint("TOPLEFT", ic, "TOPLEFT", 14, -14)
	c.info = text("GlueFontNormalLarge", 270, 18)
	c.info:SetPoint("TOPLEFT", c.name, "BOTTOMLEFT", 0, -4)
	c.zone = text("GlueFontDisableLarge", 215, 18)
	c.zone:SetPoint("BOTTOMLEFT", ic, "BOTTOMLEFT", 14, 17)
	-- Paid service button, left of the card
	c.service = CreateFrame("Button", nil, c)
	c.service:SetWidth(SERVICE)
	c.service:SetHeight(SERVICE)
	c.service:SetPoint("RIGHT", c, "LEFT", -5, 0)
	c.service:SetScript("OnClick", function(self, button, down)
		CharacterSelect_PaidServiceOnClick(self, button, down, self.type)
	end)
	c.service:SetScript("OnEnter", function(self)
		-- Tooltip on hover: anchor left (4, -8), its bottom-right corner on the button's
		-- top-left corner.
		GlueTooltip_SetOwner(self, nil, 4, -8, "BOTTOMRIGHT", "TOPLEFT")
		GlueTooltip_SetText(self.tooltip, nil, 1.0, 1.0, 1.0)
	end)
	c.service:SetScript("OnLeave", function() GlueTooltip:Hide() end)

	c:SetScript("OnEnter", function(self) hoverCard(self, true) end)
	c:SetScript("OnLeave", function(self) hoverCard(self, false) end)
	c:SetScript("OnClick", function(self)
		CharacterSelectButton_OnClick(_G["CharSelectCharacterButton" .. self.index])
	end)
	c:SetScript("OnDoubleClick", function(self)
		CharacterSelectButton_OnDoubleClick(_G["CharSelectCharacterButton" .. self.index])
	end)
	c.selected:Hide()
	c.selectedHighlight:Hide()
	c.highlight:Hide()
	return c
end

for i = 1, MAX_CHARACTERS_DISPLAYED do
	state.maps[i] = createCard(i)
end

-- GetCharacterInfo returns localized race and class, mapped back to tokens below.
-- GetAvailableRaces / GetAvailableClasses crash the client outside character creation,
-- so the race names come from GLUECHARACTERSELECT_RACE_* (forms separated by |).
local RACE_TOKENS = { "Human", "Dwarf", "NightElf", "Gnome", "Draenei", "Orc", "Scourge", "Tauren", "Troll", "BloodElf" }
local RACE_PREFIX = "GLUECHARACTERSELECT_RACE_"
local races
local function raceToken(name)
	if not races then
		races = {}
		for _, token in ipairs(RACE_TOKENS) do
			for shape in string.gmatch(L[RACE_PREFIX .. string.upper(token)], "[^|]+") do
				races[shape] = token
			end
		end
	end
	return name and races[name]
end

-- Class: the first line of the client's <TOKEN>_DISABLED (GlueStrings, every language) is the
-- class name. A female form ("Kriegerin", "Prêtresse", "Жрица") is not there: the class whose
-- name shares the longest beginning with it wins, 2 bytes at least; a tie gives none.
local CLASS_TOKENS = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
local function classToken(name)
	if not name or name == "" then return nil end
	local best, bestLength, tie = nil, 1, false
	for _, token in ipairs(CLASS_TOKENS) do
		local male = string.match(_G[token .. "_DISABLED"] or "", "^[^\n]+") or ""
		if male == name then return token end
		local l = 0
		while l < #name and l < #male and string.byte(name, l + 1) == string.byte(male, l + 1) do
			l = l + 1
		end
		if l > bestLength then
			best, bestLength, tie = token, l, false
		elseif l == bestLength and best then
			tie = true
		end
	end
	return not tie and best or nil
end

-- Class color by token (G.CLASSES: English name -> token, color)
local colors
local function classColor(className)
	if not colors then
		colors = {}
		for _, c in pairs(G.CLASSES) do colors[c[1]] = c end
	end
	local token = classToken(className)
	return token and colors[token]
end

local function faction(i, race)
	local token = GetSelectBackgroundModel(i)
	return FACTIONS[token] or FACTIONS[raceToken(race) or ""] or FACTIONS[race]
end

local function populateCard(c, i)
	local name, race, className, level, location, _, ghost, PCC, PRC, PFC = GetCharacterInfo(i)
	c.index = i
	c.name:SetText(name or "")
	c.name:SetTextColor(1, 0.82, 0)
	local color = classColor(className)
	local classText = className or ""
	if color then
		classText = string.format("|cff%02x%02x%02x%s|r", color[2] * 255, color[3] * 255, color[4] * 255, classText)
	end
	c.info:SetFormattedText(ghost and CHARACTER_SELECT_INFO_GHOST or CHARACTER_SELECT_INFO, level or 0, classText)
	c.info:SetTextColor(1, 1, 1)
	c.zone:SetText(location or "")
	c.zone:SetTextColor(0.5, 0.5, 0.5)

	c.faction = faction(i, race)
	for _, t in ipairs({ c.emblem, c.emblemHover, c.selectedEmblem }) do t:Hide() end
	if c.faction then
		local base = c.faction == "Alliance" and "glues-characterselect-icon-faction-alliance" or "glues-characterselect-icon-faction-horde"
		G.PlaceAtlas(c.emblem, base, true)
		G.PlaceAtlas(c.emblemHover, base .. "-hover", true)
		G.PlaceAtlas(c.selectedEmblem, base .. "-selected", true)
	end

	-- Paid service (UpdateCharacterList: faction, else race, else appearance)
	local service
	if PFC then service = SERVICES[1] elseif PRC then service = SERVICES[2] elseif PCC then service = SERVICES[3] end
	if service then
		local s = c.service
		s:SetID(i)
		s.type = service[2]
		s.tooltip = service[4]
		-- The image fills the button (the normal texture has no anchor)
		local n = G.StateTexture(s, "SetNormalTexture", "GetNormalTexture")
		G.PlaceAtlas(n, service[3])
		n:ClearAllPoints()
		n:SetAllPoints(s)
		local h = G.StateTexture(s, "SetHighlightTexture", "GetHighlightTexture")
		G.PlaceAtlas(h, service[3] .. "-hover")
		h:ClearAllPoints()
		h:SetAllPoints(s)
		s:Show()
	else
		c.service:Hide()
	end
end

-- Selection: selected card, selected emblem
local function mark()
	local selected = CharacterSelect.selectedIndex or 0
	for _, c in ipairs(state.maps) do
		c.selectedItem = (c.index == selected)
		G.SetShown(c.selected, c.selectedItem)
		hoverCard(c, c.hovered and c:IsShown())
	end
end

-- Layout: cards in a column, centered when there is no scroll bar
-- (the bar is configured before they are placed).
local function arrange()
	local n = 0
	state.visibleCount = {}
	for i = 1, MAX_CHARACTERS_DISPLAYED do
		local c = state.maps[i]
		local name = i <= GetNumCharacters() and GetCharacterInfo(i)
		if name then
			n = n + 1
			state.visibleCount[n] = c
		else
			c:Hide()
		end
	end
	local total = n > 0 and (n * CARD_H + (n - 1) * GAP) or 0
	content:SetHeight(math.max(1, total))
	-- Rounded: 10 cards fill the area exactly, and float noise must not show the bar.
	local view = math.floor((zone:GetTop() or 0) - (zone:GetBottom() or 0) + 0.5)
	scrollBar:Configure(total, view, state.offset)
	state.offset = scrollBar.position
	zone:SetVerticalScroll(state.offset)
	local x = LEFT_MARGIN + (scrollBar:IsShown() and 0 or CENTERING)
	for k, c in ipairs(state.visibleCount) do
		c:ClearAllPoints()
		c:SetPoint("TOPLEFT", content, "TOPLEFT", x, -(k - 1) * (CARD_H + GAP))
		c:Show()
	end
	mark()
end

-- Keep the selected card in view (arrow keys)
local function showSelected()
	local selected = CharacterSelect.selectedIndex or 0
	for n, c in ipairs(state.visibleCount) do
		if c.index == selected then
			local top = (n - 1) * (CARD_H + GAP)
			local view = math.floor((zone:GetTop() or 0) - (zone:GetBottom() or 0) + 0.5)
			if top < state.offset then
				scrollBar:MoveTo(top)
			elseif top + CARD_H > state.offset + view then
				scrollBar:MoveTo(top + CARD_H - view)
			end
		end
	end
end

-- ---------- Buttons under the list

local create = CharSelectCreateCharacterButton
G.ThreeSliceButton(create, "128-RedButton", { "GlueFontNormal", "GlueFontHighlight", "GlueFontDisable" })
create:SetWidth(205)
create:SetHeight(42)
create:SetText(CREATE_CHARACTER)
create:ClearAllPoints()
create:SetPoint("BOTTOM", list, "BOTTOM", -57, 23 - DROP)

local deleteButton = CharacterSelectDeleteButton
G.ButtonArt(deleteButton, "128-RedButton-Delete")
deleteButton:SetWidth(42)
deleteButton:SetHeight(42)
deleteButton:ClearAllPoints()
deleteButton:SetPoint("LEFT", create, "RIGHT", 6, 0)

-- ---------- List toggle

local collapse = CreateFrame("Button", "ForeverLoginCharacterSelectListToggle", ui)
collapse:SetWidth(385)
collapse:SetHeight(50)
collapse:SetPoint("BOTTOMRIGHT", ui, "BOTTOMRIGHT", -10, 6)
local collapseBackground = collapse:CreateTexture(nil, "BACKGROUND")
G.PlaceAtlas(collapseBackground, "glues-characterselect-listlauncher-bg", true)
collapseBackground:SetPoint("RIGHT", collapse, "RIGHT", -11, 0)
local arrow = CreateFrame("Button", nil, collapse)
arrow:SetWidth(42)
arrow:SetHeight(42)
arrow:SetPoint("RIGHT", collapse, "RIGHT", 0, 0)
local collapseText = collapse:CreateFontString(nil, "BORDER")
collapseText:SetFontObject(G.Font("GlueFontHighlightLarge"))
collapseText:SetPoint("RIGHT", arrow, "LEFT", -10, -1)
collapseText:SetText(TEXT.TOGGLE)

list:ClearAllPoints()
list:SetPoint("TOPRIGHT", ui, "TOPRIGHT", -9, -69)
list:SetPoint("BOTTOMRIGHT", collapse, "TOPRIGHT", 0, 10)

local expanded = true
local function toggleList(isOpen)
	expanded = isOpen
	G.SetShown(list, isOpen)
	G.SetShown(deleteButton, isOpen)
	G.ButtonArt(arrow, isOpen and "128-RedButton-ArrowDown" or "128-RedButton-ArrowUpGlow")
end
toggleList(true)
local function onCollapse()
	PlaySound("igMainMenuOptionCheckBoxOn")
	toggleList(not expanded)
end
collapse:SetScript("OnClick", onCollapse)
arrow:SetScript("OnClick", onCollapse)

-- ---------- Bottom of the screen

CharSelectCharacterName:SetFontObject(G.Font("GameFontNormalHuge4Outline"))
CharSelectCharacterName:ClearAllPoints()
CharSelectCharacterName:SetPoint("BOTTOM", ui, "BOTTOM", 0, 114)

local onEnter = CharSelectEnterWorldButton
G.ThreeSliceButton(onEnter, "128-RedButton", { "GameFontNormalOutline22", "GameFontHighlightOutline22", "GameFontDisableOutline22" })
onEnter:SetWidth(250)
onEnter:SetHeight(66)
onEnter:ClearAllPoints()
onEnter:SetPoint("BOTTOM", ui, "BOTTOM", 0, 45)

-- Icon in OVERLAY: in ARTWORK it shares the layer of the button's gray background
-- and can be drawn under it.
G.SquareIconButton(CharacterSelectRotateLeft, "common-icon-rotateleft", 24, "OVERLAY")
CharacterSelectRotateLeft:ClearAllPoints()
CharacterSelectRotateLeft:SetPoint("TOP", onEnter, "BOTTOM", -21, 4)
G.SquareIconButton(CharacterSelectRotateRight, "common-icon-rotateright", 24, "OVERLAY")
CharacterSelectRotateRight:ClearAllPoints()
CharacterSelectRotateRight:SetPoint("LEFT", CharacterSelectRotateLeft, "RIGHT", -11, 0)

local backButton = CharacterSelectBackButton
G.ThreeSliceButton(backButton, "128-RedButton", { "GlueFontNormal", "GlueFontHighlight", "GlueFontDisable" })
backButton:SetWidth(188)
backButton:SetHeight(42)
backButton:ClearAllPoints()
backButton:SetPoint("BOTTOMLEFT", ui, "BOTTOMLEFT", 12, 12)
local backArrow = backButton:CreateTexture(nil, "ARTWORK")
G.PlaceAtlas(backArrow, "common-icon-backarrow")
backArrow:SetWidth(11)
backArrow:SetHeight(16)
backArrow:SetPoint("RIGHT", backButton:GetFontString(), "LEFT")

-- Eye button: hides the whole interface except itself (VisibilityFramesContainer)
local eyeButton = CreateFrame("Button", "ForeverLoginCharacterSelectVisibilityToggle", ui)
eyeButton:SetWidth(42)
eyeButton:SetHeight(42)
eyeButton:SetPoint("BOTTOMLEFT", ui, "BOTTOMLEFT", 205, 12)
G.ButtonArt(eyeButton, "128-RedButton-VisibilityOn")
local interfaceVisible = true
local HIDEABLE = { nav, collapse, CharSelectCharacterName, onEnter, CharacterSelectRotateLeft, CharacterSelectRotateRight, backButton }
eyeButton:SetScript("OnClick", function()
	PlaySound("igMainMenuOptionCheckBoxOn")
	interfaceVisible = not interfaceVisible
	for _, f in ipairs(HIDEABLE) do G.SetShown(f, interfaceVisible) end
	if interfaceVisible then
		toggleList(expanded)
	else
		list:Hide()
		deleteButton:Hide()
	end
	G.ButtonArt(eyeButton, interfaceVisible and "128-RedButton-VisibilityOn" or "128-RedButton-VisibilityOff")
end)

-- ---------- Hidden client parts

local function hideClient()
	for i = 1, MAX_CHARACTERS_DISPLAYED do
		for _, name in ipairs({ "CharSelectCharacterButton", "CharSelectCharacterCustomize", "CharSelectRaceChange", "CharSelectFactionChange" }) do
			local b = _G[name .. i]
			if b then
				b:SetAlpha(0)
				b:EnableMouse(false)
			end
		end
	end
	CharacterSelectAddonsButton:Hide()
	CharSelectRealmName:Hide()
	CharSelectChangeRealmButton:Hide()
end
hideClient()

-- ---------- After the client updates

G.HookFunction("UpdateCharacterList", function()
	hideClient()
	for i = 1, math.min(GetNumCharacters(), MAX_CHARACTERS_DISPLAYED) do
		populateCard(state.maps[i], i)
	end
	-- Create Character stays in place; grayed when no slot is free
	create:Show()
	if (CharacterSelect.createIndex or 0) > 0 and IsConnectedToServer() then
		create:SetID(CharacterSelect.createIndex)
		create:Enable()
	else
		create:Disable()
	end
	arrange()
	showSelected()
end)
G.HookFunction("UpdateCharacterSelection", function()
	mark()
	showSelected()
end)
G.HookFunction("UpdateAddonButton", function()
	CharacterSelectAddonsButton:Hide()
	arrangeNav()
end)
G.Hook(CharacterSelect, "OnShow", function()
	placeListBackground()
	arrangeNav()
	arrange()
end)
G.Hook(list, "OnSizeChanged", placeListBackground)

-- ---------- Short screens

-- Blocks kept apart on a short screen (G.FitOnShow, after the OnShow above); the cards
-- follow the list's new height
G.FitOnShow(CharacterSelect, function()
	return { { CharacterSelectLogo, tray, { list, zone }, collapse, CharSelectCharacterName, onEnter, backButton, eyeButton } }
end, function()
	placeListBackground()
	arrange()
end)
