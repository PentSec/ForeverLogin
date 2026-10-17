-- Character creation: step 1 picks race, class and body, step 2 customizes and names.
-- The client owns the state, so our buttons drive its hidden buttons and we re-read it after
-- CharacterChangeFixup. Mode 1 shows setting names, mode 2 adds numbers, swatches and lists.

local G = ForeverLogin
local L = G.L
local frame = CharacterCreateFrame

-- Strings missing from the client come from G.L; faction names are the client's own
local TEXT = {
	CUSTOMIZE = L.GLUECHARACTERCREATE_CUSTOMIZE,
	FINISH = L.GLUECHARACTERCREATE_FINISH,
	RACIAL_TRAITS = L.GLUECHARACTERCREATE_RACIAL_TRAITS,
	FACTION = { Alliance = ALLIANCE, Horde = HORDE },
	LORE = {
		Alliance = L.GLUECHARACTERCREATE_LORE_ALLIANCE,
		Horde = L.GLUECHARACTERCREATE_LORE_HORDE,
	},
	BODY = { [SEX_MALE] = L.GLUECHARACTERCREATE_BODY_1, [SEX_FEMALE] = L.GLUECHARACTERCREATE_BODY_2 },
	RANDOMIZE_APPEARANCE = L.GLUECHARACTERCREATE_RANDOMIZE_APPEARANCE,
	RESET_CAMERA = L.GLUECHARACTERCREATE_RESET_CAMERA,
	ROTATE_LEFT = L.GLUECHARACTERCREATE_ROTATE_LEFT,
	ROTATE_RIGHT = L.GLUECHARACTERCREATE_ROTATE_RIGHT,
}

local ART = "Interface\\ForeverLogin\\charactercreate\\"
-- Race icon file names, keyed by the client fileString in upper case
local RACE_FILE = {
	HUMAN = "human", ORC = "orc", DWARF = "dwarf", NIGHTELF = "nightelf", SCOURGE = "undead",
	TAUREN = "tauren", GNOME = "gnome", TROLL = "troll", BLOODELF = "bloodelf", DRAENEI = "draenei",
}
local CLASS_ORDER = {
	WARRIOR = 1, HUNTER = 2, MAGE = 3, ROGUE = 4, PRIEST = 5, WARLOCK = 6,
	PALADIN = 7, DRUID = 8, SHAMAN = 9, DEATHKNIGHT = 12,
}
-- Background alpha by class, falling back to the faction
local BACKGROUND_ALPHA = { className = { DEATHKNIGHT = 0.8 }, faction = { Horde = 0.6 } }

local state = { mode = 1, races = {}, classes = {}, fade = nil }

-- IsEnabled returns 1 or nil in 3.3.5
local function active(b)
	local e = b:IsEnabled()
	return e and e ~= 0
end

local function sex()
	return (GetSelectedSex() == SEX_FEMALE) and "female" or "male"
end

-- ------------------------------------------------------------ Root

local root = CreateFrame("Frame", "ForeverLoginCharacterCreate", frame)
root:SetAllPoints(frame)

-- ------------------------------------------------------------ Vignettes

-- Vignette texture on root; points: anchors shared with root; flip: mirror it
local function vignette(name, points, width, height, flip)
	local t = root:CreateTexture(nil, "BACKGROUND")
	local e = G.PlaceAtlas(t, name)
	if flip then
		t:SetTexCoord(e[3], e[2], e[4], e[5])
	end
	for _, p in ipairs(points) do
		t:SetPoint(p, root, p)
	end
	if width then t:SetWidth(width) end
	if height then t:SetHeight(height) end
	return t
end

-- Top, left, right and bottom vignette textures
local backgrounds = {
	vignette("charactercreate-vignette-top", { "TOPLEFT", "TOPRIGHT" }, nil, 451),
	vignette("charactercreate-vignette-sides", { "TOPLEFT", "BOTTOMLEFT" }, 703),
	vignette("charactercreate-vignette-sides", { "TOPRIGHT", "BOTTOMRIGHT" }, 703, nil, true),
	vignette("charactercreate-vignette-bottom", { "BOTTOMLEFT", "BOTTOMRIGHT" }, nil, 577),
}
local backgroundBottom = backgrounds[4]
local wideVignettes = {
	vignette("charactercreate-vignette-sides-widescreen", { "TOPLEFT", "BOTTOMLEFT" }, 89),
	vignette("charactercreate-vignette-sides-widescreen", { "TOPRIGHT", "BOTTOMRIGHT" }, 89, nil, true),
}
-- Black bars filling the area outside the frame
local blackBars = {}
for i, side in ipairs({ { "TOPRIGHT", "TOPLEFT", "BOTTOMRIGHT", "BOTTOMLEFT" }, { "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" } }) do
	local t = root:CreateTexture(nil, "BACKGROUND")
	t:SetTexture(0, 0, 0)
	t:SetPoint(side[1], root, side[2])
	t:SetPoint(side[3], root, side[4])
	blackBars[i] = t
end

-- Shows the black bars and the widescreen vignettes for the current screen shape
local function placeEdges()
	local strip = G.STRIP or 0
	for _, t in ipairs(blackBars) do
		t:SetWidth(math.max(strip, 1))
		G.SetShown(t, strip > 0)
	end
	local wide = (GetScreenWidth() / GetScreenHeight()) - 16 / 9 > 0.001
	for _, t in ipairs(wideVignettes) do
		G.SetShown(t, wide)
	end
end
-- Re-laid out on resolution change through G.onScale
G.onScale[#G.onScale + 1] = placeEdges

-- ------------------------------------------------------------ Round button

-- Round button: icon inside a circular mask, a veil for disabled states, a ring, a selection
-- glow and a hovering glow in ADD at 0.5. size is the button size; ring and glow their own
-- sizes; veil the veil alpha.
local function roundButton(parent, size, ring, glow, veil)
	local b = CreateFrame("Button", nil, parent)
	b:SetWidth(size)
	b:SetHeight(size)
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetAllPoints(b)
	b.veil = b:CreateTexture(nil, "ARTWORK")
	b.veil:SetAllPoints(b.icon)
	b.veil:SetVertexColor(0, 0, 0)
	b.veil:SetAlpha(veil)
	b.ring = b:CreateTexture(nil, "OVERLAY")
	G.PlaceAtlas(b.ring, "character-create-icon-frame")
	b.ring:SetWidth(ring)
	b.ring:SetHeight(ring)
	b.glow = b:CreateTexture(nil, "OVERLAY")
	G.PlaceAtlas(b.glow, "character-create-icon-selectedglow")
	b.glow:SetWidth(glow)
	b.glow:SetHeight(glow)
	b.hover = b:CreateTexture(nil, "HIGHLIGHT")
	b.hover:SetBlendMode("ADD")
	b.hover:SetAlpha(0.5)
	local function place(dx, dy)
		b.icon:ClearAllPoints()
		b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", dx, dy)
		b.icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", dx, dy)
		b.ring:ClearAllPoints()
		b.ring:SetPoint("CENTER", b, "CENTER", dx, dy)
		b.glow:ClearAllPoints()
		b.glow:SetPoint("CENTER", b, "CENTER", dx, dy)
	end
	place(0, 0)
	b:SetScript("OnMouseDown", function(self)
		if active(self) then place(1, -1) end
	end)
	b:SetScript("OnMouseUp", function() place(0, 0) end)
	-- Selection and availability state of the button
	function b:State(selected, allowed)
		self.selected = selected
		G.SetShown(self.glow, selected)
		if allowed then self:Enable() else self:Disable() end
		self.icon:SetDesaturated(not allowed)
		G.SetShown(self.veil, not allowed)
		self.hover:ClearAllPoints()
		if selected then
			G.PlaceAtlas(self.hover, "character-create-icon-selectedglow")
			self.hover:SetAllPoints(self.glow)
		else
			G.PlaceAtlas(self.hover, "character-create-icon-frame")
			self.hover:SetAllPoints(self.ring)
		end
	end
	return b
end

-- Round-button icon from a baked file, mirrored for the Horde
local function applyFileIcon(b, file, flip)
	for _, t in ipairs({ b.icon, b.veil }) do
		t:SetTexture(file)
		if flip then
			t:SetTexCoord(1, 0, 0, 1)
		else
			t:SetTexCoord(0, 1, 0, 1)
		end
	end
end

-- ------------------------------------------------------------ Heavybronze frame

-- Adds a heavybronze border, corner brackets and tiled background to f; returns a resize
-- function. brackets: { atlas, point } pairs; margin: background inset (default 10)
local function bronzeFrame(f, brackets, margin)
	margin = margin or 10
	local background = f:CreateTexture(nil, "BACKGROUND")
	background:SetPoint("TOPLEFT", f, "TOPLEFT", margin, -margin)
	background:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -margin, margin)
	local edge = G.StretchedAtlas(f, "heavybronze-frame-basic", "BORDER")
	edge.rect:SetAllPoints(f)
	for _, e in ipairs(brackets) do
		local t = f:CreateTexture(nil, "BORDER")
		G.PlaceAtlas(t, e[1], true)
		t:SetPoint(e[2], f, e[2])
	end
	return function(width, height)
		f:SetWidth(width)
		f:SetHeight(height)
		G.Tile(background, "heavybronze-frame-background", width - 2 * margin, height - 2 * margin)
	end
end

-- ------------------------------------------------------------ Navigation buttons

local function navButton(name, direction)
	local b = G.CreateThreeSliceButton(name, root, 250, 66, "128-RedButton",
		{ "GameFontNormalOutline22", "GameFontHighlightOutline22", "GameFontDisableOutline22" })
	b.direction = direction
	return b
end

-- Arrow size, matching the character select back arrow but larger than 8 x 13 to stay
-- legible on a short screen
local ARROW_W, ARROW_H = 11, 16

-- The arrow is part of the text, so both arrows are drawn alike and centered on their word
local function setNavText(b, text)
	local forward = (b.direction == "forward")
	local grayed = active(b) and "" or "-disable"
	local e = G.atlas["common-icon-" .. (forward and "forward" or "back") .. "arrow" .. grayed]
	local arrow = "|T" .. e[1] .. ":" .. ARROW_H .. ":" .. ARROW_W .. "|t"
	b:SetText(forward and (text .. "  " .. arrow) or (arrow .. "  " .. text))
	local fs = b:GetFontString()
	fs:ClearAllPoints()
	fs:SetPoint("CENTER", b, "CENTER")
end

local backButton = navButton("ForeverLoginCharacterCreateBackButton", "backward")
backButton:SetPoint("BOTTOMLEFT", root, "BOTTOMLEFT", 46, 28)
local forwardButton = navButton("ForeverLoginCharacterCreateForwardButton", "forward")
forwardButton:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", -46, 28)

-- ------------------------------------------------------------ Race and class

local raceClass = CreateFrame("Frame", nil, root)
raceClass:SetAllPoints(root)

-- A faction column: banner, emblem, name and a holder for the race buttons
local function column(faction)
	local f = CreateFrame("Frame", nil, raceClass)
	f:SetWidth(168)
	f:SetHeight(794)
	local key = string.lower(faction)
	local bannerTexture = f:CreateTexture(nil, "BACKGROUND")
	G.PlaceAtlas(bannerTexture, "charactercreate-factionflag-" .. key, true)
	bannerTexture:SetPoint("TOP", f, "TOP")
	local logo = f:CreateTexture(nil, "ARTWORK")
	G.PlaceAtlas(logo, "charactercreate-icon-" .. key, true)
	logo:SetPoint("TOP", f, "TOP")
	local name = f:CreateFontString(nil, "ARTWORK")
	name:SetFontObject(G.Font("GameFontNormalLarge2"))
	name:SetPoint("TOP", logo, "BOTTOM", 0, 10)
	name:SetText(string.upper(TEXT.FACTION[faction]))
	f.races = CreateFrame("Frame", nil, f)
	f.races:SetWidth(79)
	f.races:SetHeight(1)
	f.races:SetPoint("TOP", name, "BOTTOM", 0, -10)
	f.buttons = {}
	return f
end

local alliance = column("Alliance")
alliance:SetPoint("TOPLEFT", raceClass, "TOPLEFT", 3, 0)
local horde = column("Horde")
horde:SetPoint("TOPLEFT", alliance, "TOPRIGHT", 20, 0)
local COLUMNS = { Alliance = alliance, Horde = horde }

-- Race button i of a column, created on first use; it clicks the client's button
local function raceButton(col, i)
	local b = col.buttons[i]
	if not b then
		b = roundButton(col.races, 79, 86, 116, 0.5)
		b:SetScript("OnClick", function(self)
			local client = _G["CharacterCreateRaceButton" .. self.index]
			if client then client:Click() end
		end)
		col.buttons[i] = b
	end
	return b
end

-- Lays the race buttons out vertically with an 18 gap, shrinking it when the column would
-- reach the Back button
local function arrangeRaces(col, n)
	local gap = 18
	local top, backButtonTop = col.races:GetTop(), backButton:GetTop()
	if top and backButtonTop and n > 0 then
		local rest = (top - backButtonTop - 20) - n * 79
		if rest < gap * n then
			gap = math.floor(rest / n)
		end
	end
	for i = 1, n do
		local b = col.buttons[i]
		b:ClearAllPoints()
		b:SetPoint("TOP", col.races, "TOP", 0, -(i - 1) * (79 + gap))
	end
end

-- Body types
local body = CreateFrame("Frame", nil, raceClass)
-- Shifted right so tall characters' heads stay clear of the class bar
local BODY_OFFSET = 250
body:SetPoint("TOP", raceClass, "TOP", BODY_OFFSET, 0)
local sizeBody = bronzeFrame(body, { { "heavybronze-horz-cornerbracket-tr", "TOPRIGHT" }, { "heavybronze-horz-cornerbracket-tl", "TOPLEFT" } })
-- Width 25 + 55 + 22 + 55 = 157 -> 180; height 20 + 55 + 20 = 95
sizeBody(math.max(180, 25 + 55 + 22 + 55), math.max(90, 20 + 55 + 20))
local bodyButtons = {}
for i, sexId in ipairs({ SEX_MALE, SEX_FEMALE }) do
	local b = roundButton(body, 55, 60, 80, 0.75)
	b:SetPoint("TOPLEFT", body, "TOPLEFT", 25 + (i - 1) * (55 + 22), -20)
	-- Round 56 x 56 black background behind the icon
	local black = b:CreateTexture(nil, "BACKGROUND")
	G.PlaceAtlas(black, "character-create-icon-mask")
	black:SetVertexColor(0, 0, 0)
	black:SetWidth(56)
	black:SetHeight(56)
	black:SetPoint("CENTER", b, "CENTER")
	b.sex = sexId
	b:SetScript("OnClick", function(self)
		if self.sex == SEX_MALE then
			CharacterCreateGenderButtonMale:Click()
		else
			CharacterCreateGenderButtonFemale:Click()
		end
	end)
	-- Tooltip anchored (10, 0) at the bottom right of the button
	b:SetScript("OnEnter", function(self)
		GlueTooltip_SetOwner(self, nil, 10, 0, "TOPLEFT", "BOTTOMRIGHT")
		GlueTooltip_SetText(TEXT.BODY[self.sex], nil, 1.0, 1.0, 1.0)
	end)
	b:SetScript("OnLeave", function() GlueTooltip:Hide() end)
	bodyButtons[i] = b
end

-- Classes
local classes = CreateFrame("Frame", nil, raceClass)
classes:SetFrameLevel(raceClass:GetFrameLevel() + 4)
classes:SetPoint("BOTTOM", raceClass, "BOTTOM")
local sizeClasses = bronzeFrame(classes, { { "heavybronze-horz-cornerbracket-br", "BOTTOMRIGHT" }, { "heavybronze-horz-cornerbracket-bl", "BOTTOMLEFT" } })
sizeClasses(900, 140)
local classButtons = {}

-- Class button i, created on first use; it clicks the client's button
local function classButton(i)
	local b = classButtons[i]
	if not b then
		b = roundButton(classes, 66, 73, 103, 0.75)
		b.name = b:CreateFontString(nil, "OVERLAY")
		b.name:SetWidth(85)
		b.name:SetHeight(48)
		b.name:SetJustifyH("CENTER")
		b.name:SetJustifyV("MIDDLE")
		b.name:SetPoint("TOP", b, "BOTTOM", 2, 3)
		b:SetScript("OnClick", function(self)
			local client = _G["CharacterCreateClassButton" .. self.index]
			if client then client:Click() end
		end)
		classButtons[i] = b
	end
	return b
end

-- Positions the n class buttons in one or two rows
local function arrangeClasses(n)
	local gapX, icon, nameGap = 30, 66, 50
	local buttonWidth, buttonHeight = icon, icon + nameGap
	-- Space from 10 right of the Horde column to 10 left of the Customize button
	local position = 900
	local edge, right = root:GetLeft(), forwardButton:GetLeft()
	if edge and right then
		position = (right - 10) - (edge + 3 + 168 + 20 + 168 + 10)
	end
	local rowLines = math.ceil((n * buttonWidth + (n - 1) * gapX) / position)
	local width, height = 900, 140
	if rowLines <= 1 then
		rowLines = 1
		position = width
	else
		height = 140 * 2 - 20
	end
	if position < 900 then
		gapX = 20
		position = position - 40
		width = position
	end
	if rowLines > 2 then
		rowLines = 2
	end
	local step = math.ceil(n / rowLines)
	local rowLine = (step * buttonWidth) + ((step - 1) * gapX)
	-- The 900 base leaves a 33 margin per side; the ten-class row keeps it and the frame
	-- grows to fit
	local margin = (900 - (9 * buttonWidth + 8 * 30)) / 2
	if rowLine + 2 * margin > width then
		width = rowLine + 2 * margin
		position = width
	end
	sizeClasses(width, height)
	local x0 = (position - rowLine) / 2
	local y0 = (height - buttonHeight) * 0.5
	for i = 1, n do
		local b = classButtons[i]
		local col, row = (i - 1) % step, math.floor((i - 1) / step)
		b:ClearAllPoints()
		b:SetPoint("LEFT", classes, "LEFT", x0 + col * (buttonWidth + gapX), y0 - row * (icon + nameGap))
	end
end

-- ------------------------------------------------------------ Detail boxes

-- A detail box (faction, race or class) with a portrait and scrolling text;
-- index: position in the right column
local function frameBox(name, index)
	local f = CreateFrame("Frame", name, root)
	f:SetFrameLevel(root:GetFrameLevel() + 4)
	f:EnableMouse(true)
	f:SetPoint("TOPRIGHT", root, "TOPRIGHT", 0, -40 - (index - 1) * (260 + 10))
	local resize = bronzeFrame(f, { { "heavybronze-vert-cornerbracket-tr", "TOPRIGHT" }, { "heavybronze-vert-cornerbracket-br", "BOTTOMRIGHT" } })
	resize(390, 260)

	-- Portrait container, raised above the box
	local p = CreateFrame("Frame", nil, f)
	p:SetFrameLevel(400)
	p:SetWidth(1)
	p:SetHeight(1)
	p:SetPoint("TOPLEFT", f, "TOPLEFT", -25, 5)
	f.portrait = p:CreateTexture(nil, "OVERLAY")
	f.portrait:SetWidth(62)
	f.portrait:SetHeight(62)
	f.portrait:SetPoint("TOPLEFT", p, "TOPLEFT", -5, 7)
	local ring = p:CreateTexture(nil, "OVERLAY")
	G.PlaceAtlas(ring, "character-create-icon-circle-frame")
	ring:SetWidth(64)
	ring:SetHeight(64)
	ring:SetPoint("CENTER", f.portrait, "CENTER")

	-- Scroll box and its content, rows spaced 10 apart
	local zone = CreateFrame("ScrollFrame", nil, f)
	zone:SetPoint("TOPLEFT", f, "TOPLEFT", 44, -14)
	zone:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -35, 15)
	local content = CreateFrame("Frame", nil, zone)
	content:SetWidth(310)
	content:SetHeight(1)
	zone:SetScrollChild(content)
	f.zone, f.content, f.rows = zone, content, {}

	local bar = G.MinimalBar(f, name .. "ScrollBar")
	bar:SetPoint("TOP", f, "TOPRIGHT", -25.5, -14 - 16)
	bar:SetPoint("BOTTOM", f, "BOTTOMRIGHT", -25.5, 15 + 16)
	bar.step = 50
	-- The bar appears only when needed; without it the zone, and the text, extend to its
	-- right edge at -21.5
	bar.hideIfUnneeded = true
	bar.onVisibility = function(hasBar)
		zone:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", hasBar and -35 or -21.5, 15)
	end
	bar.onScroll = function(position)
		zone:SetVerticalScroll(position)
	end
	zone:EnableMouseWheel(true)
	zone:SetScript("OnMouseWheel", function(_, direction)
		bar:MoveTo(bar.position - direction * 50 * 2)
	end)
	f.bar = bar
	return f
end

-- Text width: 310 with the bar, up to the bar's right edge without it
local TEXT_W, TEXT_W_NO_BAR, VIEW_H = 310, 324.5, 260 - 14 - 15

-- Fills a detail box; rows: { "space" } | { "title", text } | { "text", text }
local function populate(f, rows)
	for _, fs in ipairs(f.rows) do
		fs:Hide()
	end
	-- One pass at a given width; returns the content height
	local function layout(width)
		local y, n = 0, 0
		for i, l in ipairs(rows) do
			if i > 1 then
				y = y + 10
			end
			if l[1] == "space" then
				y = y + 14
			else
				n = n + 1
				local fs = f.rows[n]
				if not fs then
					fs = f.content:CreateFontString(nil, "ARTWORK")
					fs:SetJustifyH("LEFT")
					f.rows[n] = fs
				end
				fs:SetWidth(width)
				if l[1] == "title" then
					fs:SetFontObject(G.Font("GameFontNormalLarge2"))
					fs:SetTextColor(1, 1, 1)
				else
					fs:SetFontObject(G.Font("GameFontNormalLarge"))
					fs:SetTextColor(1, 0.82, 0)
				end
				fs:SetText(l[2] or "")
				fs:ClearAllPoints()
				fs:SetPoint("TOPLEFT", f.content, "TOPLEFT", 0, -y)
				fs:Show()
				y = y + fs:GetHeight()
			end
		end
		f.content:SetWidth(width)
		return y
	end
	-- Try without the bar first; if the text overflows, retry with it
	local y = layout(TEXT_W_NO_BAR)
	if y > VIEW_H then
		y = layout(TEXT_W)
	end
	f.content:SetHeight(math.max(1, y))
	f.bar:Configure(y, VIEW_H, 0)
	f.zone:SetVerticalScroll(0)
end

local factionFrameBox = frameBox("ForeverLoginCharacterCreateFactionDetails", 1)
local raceFrameBox = frameBox("ForeverLoginCharacterCreateRaceDetails", 2)
local classFrameBox = frameBox("ForeverLoginCharacterCreateClassDetails", 3)
local FRAME_BOXES = { factionFrameBox, raceFrameBox, classFrameBox }

-- ------------------------------------------------------------ Reading the client

-- Races from GetAvailableRaces, indexed like the client's race buttons
local function readRaces()
	local t = { GetAvailableRaces() }
	local races = {}
	for i = 1, #t, 3 do
		local n = (i + 2) / 3
		local client = _G["CharacterCreateRaceButton" .. n]
		local _, faction = GetFactionForRace(n)
		races[n] = {
			index = n, name = t[i], file = string.upper(t[i + 1] or ""), faction = faction,
			allowed = client and client.enable and active(client),
		}
	end
	return races
end

-- Classes from GetAvailableClasses, sorted by our display order
local function readClasses()
	local t = { GetAvailableClasses() }
	local list = {}
	for i = 1, #t, 3 do
		local n = (i + 2) / 3
		local client = _G["CharacterCreateClassButton" .. n]
		table.insert(list, {
			index = n, name = t[i], file = string.upper(t[i + 1] or ""),
			allowed = client and client.enable and active(client),
		})
	end
	table.sort(list, function(a, b)
		return (CLASS_ORDER[a.file] or 99) < (CLASS_ORDER[b.file] or 99)
	end)
	return list
end

-- Mirrors the client's selection on our buttons, detail boxes and backgrounds
local function refresh()
	if not CharacterCreate:IsShown() then
		return
	end
	local raceChoice = GetSelectedRace()
	local _, classFile, classChoice = GetSelectedClass()
	local sexChoice = GetSelectedSex()
	local races = readRaces()

	-- Races per faction, in client order
	local count = { Alliance = 0, Horde = 0 }
	local selectedRace
	for _, r in ipairs(races) do
		local col = COLUMNS[r.faction]
		if col then
			count[r.faction] = count[r.faction] + 1
			local b = raceButton(col, count[r.faction])
			b.index = r.index
			applyFileIcon(b, ART .. "button-raceicon128-" .. (RACE_FILE[r.file] or "human") .. "-" .. sex(), r.faction == "Horde")
			b:State(r.index == raceChoice, r.allowed)
			b:Show()
		end
		if r.index == raceChoice then
			selectedRace = r
		end
	end
	for faction, col in pairs(COLUMNS) do
		for i = count[faction] + 1, #col.buttons do
			col.buttons[i]:Hide()
		end
		arrangeRaces(col, count[faction])
	end

	-- Body types
	for _, b in ipairs(bodyButtons) do
		local sexName = (b.sex == SEX_FEMALE) and "female" or "male"
		local selected = (b.sex == sexChoice)
		G.PlaceAtlas(b.icon, "charactercreate-gendericon-" .. sexName .. (selected and "-selected" or ""))
		G.PlaceAtlas(b.veil, "charactercreate-gendericon-" .. sexName)
		b:State(selected, true)
	end

	-- Classes
	local list = readClasses()
	for i, c in ipairs(list) do
		local b = classButton(i)
		b.index = c.index
		applyFileIcon(b, ART .. "button-classicon-" .. string.lower(c.file))
		b:State(c.index == classChoice, c.allowed)
		b.name:SetFontObject(G.Font(c.allowed and "GameFontNormalMed2" or "GameFontDisableMed2"))
		b.name:SetText(c.name)
		b:Show()
	end
	for i = #list + 1, #classButtons do
		classButtons[i]:Hide()
	end
	arrangeClasses(#list)

	-- Detail boxes
	if selectedRace then
		local faction = selectedRace.faction
		-- The "bg" suffix is part of the texture file name
		factionFrameBox.portrait:SetTexture(ART .. "portrait-charactercreate-icon-" .. string.lower(faction or "alliance") .. "bg")
		populate(factionFrameBox, { { "space" }, { "title", TEXT.FACTION[faction] }, { "text", TEXT.LORE[faction] }, { "space" } })

		raceFrameBox.portrait:SetTexture(ART .. "portrait-raceicon128-" .. (RACE_FILE[selectedRace.file] or "human") .. "-" .. sex())
		local rows = { { "space" }, { "title", selectedRace.name }, { "text", TEXT.RACIAL_TRAITS } }
		local i = 1
		while _G["ABILITY_INFO_" .. selectedRace.file .. i] do
			table.insert(rows, { "text", _G["ABILITY_INFO_" .. selectedRace.file .. i] })
			i = i + 1
		end
		table.insert(rows, { "text", GetFlavorText("RACE_INFO_" .. selectedRace.file, sexChoice) })
		table.insert(rows, { "space" })
		populate(raceFrameBox, rows)
	end
	if classFile then
		local classDisplayName = GetSelectedClass()
		-- Class portrait from the client's class icon sheet
		classFrameBox.portrait:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
		local c = CLASS_ICON_TCOORDS[string.upper(classFile)]
		if c then
			classFrameBox.portrait:SetTexCoord(c[1], c[2], c[3], c[4])
		end
		populate(classFrameBox, { { "space" }, { "title", classDisplayName }, { "text", GetFlavorText("CLASS_" .. string.upper(classFile), sexChoice) }, { "space" } })
	end

	-- Background alpha
	local a = BACKGROUND_ALPHA.className[string.upper(classFile or "")]
		or (selectedRace and BACKGROUND_ALPHA.faction[selectedRace.faction]) or 1
	state.backgroundAlpha = a
	for _, t in ipairs(backgrounds) do
		t:SetAlpha(a)
	end
	if state.mode == 2 then
		backgroundBottom:SetAlpha(0)
	end
end

-- ------------------------------------------------------------ Customization

local character = CreateFrame("Frame", nil, root)
character:SetAllPoints(root)

-- Customization panel
local container = CreateFrame("Frame", nil, character)
container:SetFrameLevel(character:GetFrameLevel() + 4)
container:EnableMouse(true)
container:SetPoint("TOPRIGHT", character, "TOPRIGHT", 0, -137)
local sizeContainer = bronzeFrame(container, { { "heavybronze-vert-cornerbracket-tr", "TOPRIGHT" }, { "heavybronze-vert-cornerbracket-br", "BOTTOMRIGHT" } })

-- Tooltip anchored to the left of the button
local function leftTooltip(b, text)
	b:SetScript("OnEnter", function(self)
		GlueTooltip_SetOwner(self, nil, 9, -9, "BOTTOMRIGHT", "TOPLEFT")
		GlueTooltip_SetText(text, nil, 1.0, 1.0, 1.0)
	end)
	b:SetScript("OnLeave", function() GlueTooltip:Hide() end)
end

-- Randomize appearance button
local randomAppearance = CreateFrame("Button", "ForeverLoginCharacterCreateRandomizeButton", container)
G.SquareIconButton(randomAppearance, "charactercreate-icon-dice", 24, "OVERLAY")
randomAppearance:SetPoint("TOPLEFT", container, "TOPLEFT", 12, -12)
local refreshSettings
randomAppearance:SetScript("OnClick", function()
	CharacterCreate_Randomize()
	refreshSettings()
end)
leftTooltip(randomAppearance, TEXT.RANDOMIZE_APPEARANCE)

-- Rows are 46 apart while the panel keeps the 48 spacing it was sized for, leaving more
-- room at the bottom
local ROW_W, ROW_H, ROW_GAP, REFERENCE_GAP = 265, 38, 46, 48
local settings = CreateFrame("Frame", nil, container)
settings:SetWidth(300)
settings:SetHeight(5 * ROW_H + 4 * ROW_GAP)
settings:SetPoint("TOPRIGHT", container, "TOPRIGHT", -10, -80)
sizeContainer(360, 80 + 5 * ROW_H + 4 * REFERENCE_GAP + 20)

-- Stepper arrow: background per state, icon nudged when pressed.
-- direction: "back" or "next"; action: OnClick handler
local function settingArrow(parent, direction, action)
	local b = CreateFrame("Button", nil, parent)
	b:SetScale(1.7)
	b:SetWidth(26)
	b:SetHeight(25)
	b.background = b:CreateTexture(nil, "BACKGROUND")
	b.background:SetPoint("CENTER", b, "CENTER")
	b.icon = b:CreateTexture(nil, "OVERLAY")
	local function paint()
		local background = "common-dropdown-c-button"
		if b.down and b.hovered then
			background = "common-dropdown-c-button-pressedhover-2"
		elseif b.hovered then
			background = "common-dropdown-c-button-hover-2"
		elseif b.down then
			background = "common-dropdown-c-button-pressed-2"
		end
		G.PlaceAtlas(b.background, background, true)
		G.PlaceAtlas(b.icon, "common-dropdown-icon-" .. direction, true)
		b.icon:ClearAllPoints()
		b.icon:SetPoint("CENTER", b, "CENTER", b.down and 2 or 0, b.down and -1 or 0)
	end
	b:SetScript("OnEnter", function() b.hovered = true; paint() end)
	b:SetScript("OnLeave", function() b.hovered = false; paint() end)
	b:SetScript("OnMouseDown", function() b.down = true; paint() end)
	b:SetScript("OnMouseUp", function() b.down = false; paint() end)
	b:SetScript("OnClick", action)
	paint()
	return b
end

-- One row: [<] [box] [>]
local rows = {}
for i = 1, 5 do
	local row = CreateFrame("Frame", nil, settings)
	row.i = i
	row:SetWidth(ROW_W)
	row:SetHeight(ROW_H)
	row:SetPoint("TOPLEFT", settings, "TOPLEFT", 0, -(i - 1) * (ROW_H + ROW_GAP))
	local cell = CreateFrame("Frame", nil, row)
	cell:SetScale(1.55)
	cell:SetWidth(122)
	cell:SetHeight(25)
	cell:SetPoint("CENTER", row, "CENTER")
	local background = G.StretchedAtlas(cell, "common-dropdown-c-button", "BACKGROUND")
	background.rect:SetPoint("TOPLEFT", cell, "TOPLEFT", -7, 7)
	background.rect:SetPoint("BOTTOMRIGHT", cell, "BOTTOMRIGHT", 7, -7)
	row.cell, row.background = cell, background
	row.text = cell:CreateFontString(nil, "OVERLAY")
	row.text:SetFontObject(G.Font("GameFontNormal"))
	row.text:SetTextColor(1, 0.82, 0)
	row.text:SetJustifyH("CENTER")
	row.text:SetHeight(20)
	row.text:SetPoint("LEFT", cell, "LEFT", 13, 0)
	row.text:SetPoint("RIGHT", cell, "RIGHT", -13, 0)
	local minus = settingArrow(row, "back", function()
		CharacterCustomization_Left(i)
		refreshSettings(i)
	end)
	minus:SetPoint("RIGHT", cell, "LEFT", -5, 0)
	local plus = settingArrow(row, "next", function()
		CharacterCustomization_Right(i)
		refreshSettings(i)
	end)
	plus:SetPoint("LEFT", cell, "RIGHT", 4, 0)
	-- Mode 2: setting name above the row, choice number or swatch inside the box, a hover
	-- arrow below it and a button that opens the choice list
	row.title = row:CreateFontString(nil, "ARTWORK")
	row.title:SetFontObject(G.Font("SystemFont_Shadow_Large"))
	row.title:SetPoint("BOTTOMLEFT", minus, "TOPLEFT", 2, 4)
	row.number = cell:CreateFontString(nil, "OVERLAY")
	row.number:SetFontObject(G.Font("GameFontNormal"))
	row.number:SetTextColor(1, 0.82, 0)
	row.number:SetJustifyH("LEFT")
	row.number:SetWidth(25)
	row.number:SetHeight(20)
	row.number:SetPoint("CENTER", cell, "CENTER")
	-- Swatch and its ADD glow; when shown it replaces the number in the box, centered
	row.swatch = cell:CreateTexture(nil, "ARTWORK")
	G.PlaceAtlas(row.swatch, "charactercreate-customize-palette", true)
	row.swatch:SetPoint("CENTER", cell, "CENTER")
	row.swatch:Hide()
	row.glow = cell:CreateTexture(nil, "ARTWORK")
	G.PlaceAtlas(row.glow, "charactercreate-customize-palette-glow", true)
	row.glow:SetBlendMode("ADD")
	row.glow:SetPoint("CENTER", row.swatch, "CENTER")
	row.glow:Hide()
	row.arrow = cell:CreateTexture(nil, "OVERLAY")
	G.PlaceAtlas(row.arrow, "common-dropdown-c-button-hover-arrow")
	row.arrow:SetWidth(12)
	row.arrow:SetHeight(5)
	row.arrow:SetPoint("BOTTOM", cell, "BOTTOM", 0, -5)
	row.arrow:Hide()
	row.button = CreateFrame("Button", nil, cell)
	row.button:SetAllPoints(cell)
	row.button:EnableMouseWheel(true)
	row.button:Hide()
	rows[i] = row
end

-- ------------------------------------------------------------ Mode 2: choices

-- On a patched client CycleCharCustomization(setting, offset) returns the setting's index,
-- so we can show each choice's rank. Valid choices are computed from client data; enumerating
-- the engine instead is a last resort, since stepping it redraws the character every time.
local lists = {}

-- Current engine index of setting i (patched client only), or nil
local function index(i)
	local v = CycleCharCustomization(i, 0)
	if type(v) == "number" then
		return v
	end
end

local function rank(list, v)
	for k, x in ipairs(list) do
		if x == v then
			return k
		end
	end
end

-- Walks a setting through a full cycle back to its starting choice
local function enumerate(i)
	local origin = index(i)
	if not origin then
		return nil
	end
	local loop, position = { origin }, { [origin] = 1 }
	for _ = 1, 255 do
		local v = CycleCharCustomization(i, 1)
		if type(v) ~= "number" or v == origin then
			break
		end
		if position[v] then
			-- Start outside the cycle (should not happen): keep the cycle only
			local cycle = {}
			for k = position[v], #loop do
				cycle[#cycle + 1] = loop[k]
			end
			loop = cycle
			break
		end
		loop[#loop + 1] = v
		position[v] = #loop
	end
	-- In engine order, from the lowest index
	local first = 1
	for k = 2, #loop do
		if loop[k] < loop[first] then
			first = k
		end
	end
	local list = {}
	for k = 0, #loop - 1 do
		list[#list + 1] = loop[(first - 1 + k) % #loop + 1]
	end
	return list
end

-- Valid choices of setting i (1 skin, 2 face, 3 hair style, 4 hair color, 5 facial hair),
-- from the CharSections cells [section][variation][color] (0 skin, 1 face, 2 facial hair,
-- 3 hair, 4 underwear) and the engine's own rules, in ascending order
local function compute(i)
	local race = G.choice and readRaces()[GetSelectedRace()]
	local d = race and G.choice[race.file]
	d = d and d[(GetSelectedSex() == SEX_FEMALE) and 1 or 0]
	if not d then
		return nil
	end
	-- Flags: one bit for regular classes, another for the death knight
	local _, className = GetSelectedClass()
	local weight = (className == "DEATHKNIGHT") and 2 or 1
	local function count(section, var)
		local s = var and d[section][var]
		return s and string.len(s) or 0
	end
	local function isAvailable(section, var, col)
		local s = var and d[section][var]
		local c = s and string.byte(s, col + 1)
		c = c and c - 48                -- "0".."3"; "." (no row) gives < 0
		return c ~= nil and c >= 0 and math.floor(c / weight) % 2 == 1
	end
	local function hasColor(section, var, test)
		for c = 0, count(section, var) - 1 do
			if test(c) then
				return true
			end
		end
		return false
	end
	local list = {}
	if i == 1 then
		-- Skin: must fit the current face and the underwear
		local face = index(2)
		for c = 0, count(0, 0) - 1 do
			if isAvailable(0, 0, c) and isAvailable(1, face, c) and isAvailable(4, 0, c) then
				list[#list + 1] = c
			end
		end
	elseif i == 2 then
		-- Face: at least one skin color fits it
		for v = 0, d[1].n - 1 do
			if hasColor(1, v, function(c) return isAvailable(1, v, c) and isAvailable(0, 0, c) and isAvailable(4, 0, c) end) then
				list[#list + 1] = v
			end
		end
	elseif i == 3 then
		-- Hair style: at least one color
		for s = 0, d[3].n - 1 do
			if hasColor(3, s, function(c) return isAvailable(3, s, c) end) then
				list[#list + 1] = s
			end
		end
	elseif i == 4 then
		-- Hair color: those of the current hair style
		local hairStyle = index(3)
		for c = 0, count(3, hairStyle) - 1 do
			if isAvailable(3, hairStyle, c) then
				list[#list + 1] = c
			end
		end
	else
		-- Facial hair: if the (facial hair, hair color) cell exists, the styles with at least one
		-- color; otherwise all styles
		local facialHair, color = index(5), index(4)
		if facialHair and color and facialHair < d[2].n and color < count(2, facialHair) then
			for v = 0, d[2].n - 1 do
				if hasColor(2, v, function(c) return isAvailable(2, v, c) end) then
					list[#list + 1] = v
				end
			end
		else
			for v = 0, (d.facialHairs or 0) - 1 do
				list[#list + 1] = v
			end
		end
	end
	return list
end

-- Moves setting i to choice target (an engine index) by the shortest path
local function goTo(i, target)
	local list = lists[i]
	if not list then
		return
	end
	local n, p, q = #list, rank(list, index(i)), rank(list, target)
	if not p or not q then
		return
	end
	local forward, backward = (q - p) % n, (p - q) % n
	if forward <= backward then
		for _ = 1, forward do
			CycleCharCustomization(i, 1)
		end
	else
		for _ = 1, backward do
			CycleCharCustomization(i, -1)
		end
	end
end

-- Which settings have a color swatch, read from the choice textures in ForeverLoginColors.
-- Only skin and hair color have one.
local SWATCHES = { [1] = "skinColor", [4] = "hair" }

-- Each scenery lights the character with its RaceLights, which can tint pale skin (death
-- knight) or cyan (orc). The skin swatch is tinted to match: full ambient plus half
-- directional, normalized to 1 on the strongest component.
local DIRECTIONAL_SHARE = 0.5
local function sceneryTint()
	local name = GetCreateBackgroundModel and GetCreateBackgroundModel()
	local lights = name and RaceLights and RaceLights[string.upper(name)]
	if not lights then
		return nil
	end
	local r, g, b = 0, 0, 0
	for _, l in ipairs(lights) do
		-- { enabled, omni, direction x3, ambient (intensity, r, g, b),
		-- directional (intensity, r, g, b) }
		if l[1] == 1 then
			r = r + l[6] * l[7] + l[10] * l[11] * DIRECTIONAL_SHARE
			g = g + l[6] * l[8] + l[10] * l[12] * DIRECTIONAL_SHARE
			b = b + l[6] * l[9] + l[10] * l[13] * DIRECTIONAL_SHARE
		end
	end
	local m = math.max(r, g, b)
	if m <= 0 then
		return nil
	end
	return r / m, g / m, b / m
end

-- Swatch color { r, g, b } of choice v of setting i, or nil
local function colorOf(i, v)
	local kind = SWATCHES[i]
	local race = kind and v and G.colors and readRaces()[GetSelectedRace()]
	local t = race and G.colors[race.file]
	t = t and t[(GetSelectedSex() == SEX_FEMALE) and 1 or 0]
	t = t and t[kind]
	local c = t and t[v]
	if c and kind == "skinColor" then
		local r, g, b = sceneryTint()
		if r then
			return { c[1] * r, c[2] * g, c[3] * b }
		end
	end
	return c
end

-- Name of a choice, from CycleCharCustomization(setting, 0, n) on a patched client, which
-- returns the index and then the name. Only a two-value answer counts, and only skin, hair
-- style and facial hair have names.
local NAMED = { [1] = true, [3] = true, [5] = true }
local function second(...)
	if select("#", ...) == 2 then
		return (select(2, ...))
	end
end
local function nameOf(i, v)
	if not (NAMED[i] and v) then
		return nil
	end
	local name = second(CycleCharCustomization(i, 0, v))
	if type(name) == "string" and name ~= "" then
		return name
	end
end

-- ------------------------------------------------------------ Mode 2: open list

-- Dropdown list: 1 column up to 10 choices, 2 up to 24, 3 up to 36, 4 beyond, more if it
-- would come within 100 of the bottom. Entries are 20 high and show a number and an optional
-- name or swatch; hover previews on the character and a click selects and closes.
local menu = CreateFrame("Frame", "ForeverLoginCharacterCreateChoiceMenu", character)
menu:SetFrameStrata("FULLSCREEN_DIALOG")
menu:SetFrameLevel(20)
menu:SetScale(1.55)
menu:EnableMouse(true)
menu:Hide()
local menuBackground = G.StretchedAtlas(menu, "common-dropdown-c-bg", "BACKGROUND")
menuBackground.rect:SetPoint("TOPLEFT", menu, "TOPLEFT", -17, 12)
menuBackground.rect:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", 17, -22)
-- A click outside the list closes it without choosing
local catcher = CreateFrame("Button", nil, character)
catcher:SetFrameStrata("FULLSCREEN_DIALOG")
catcher:SetFrameLevel(10)
catcher:SetAllPoints(GlueParent)
catcher:Hide()
-- Dedicated string for measuring name widths; a reused entry would measure within its own
-- current width
local measure = menu:CreateFontString(nil, "OVERLAY")
measure:SetFontObject(G.Font("GameFontNormal"))
measure:SetAlpha(0)

local isOpen        -- { row, selected } while a list is open
local entries = {}
local paintDropdown

-- A row previews only after resting PREVIEW_DELAY on it, since each preview makes the engine
-- rebuild the character textures and stalls; sweeping the list then triggers just one. The
-- frame after a stall is capped at PREVIEW_MAX_STEP so it cannot empty the delay at once.
local PREVIEW_DELAY = 0.1
local PREVIEW_MAX_STEP = 0.05
local preview        -- { k, pending, fresh }: hovered entry, not shown yet
menu:SetScript("OnUpdate", function(_, elapsed)
	if not preview then
		return
	end
	if preview.fresh then
		preview.fresh = false
		return
	end
	preview.pending = preview.pending - math.min(elapsed, PREVIEW_MAX_STEP)
	if preview.pending <= 0 then
		local k = preview.k
		preview = nil
		if isOpen then
			goTo(isOpen.row.i, lists[isOpen.row.i][k])
		end
	end
end)

local function forgetMenu()
	isOpen = nil
	preview = nil
	menu:Hide()
	catcher:Hide()
end

-- keep: retain the hovered choice; otherwise go back to the current choice
local function closeMenu(keep)
	local o = isOpen
	if not o then
		return
	end
	forgetMenu()
	if keep then
		refreshSettings(o.row.i)
	else
		goTo(o.row.i, o.selected)
		paintDropdown(o.row)
	end
end
catcher:SetScript("OnClick", function() closeMenu(false) end)

-- List entry k, created on first use
local function entry(k)
	if entries[k] then
		return entries[k]
	end
	local e = CreateFrame("Button", nil, menu)
	e:SetHeight(20)
	e.hover = G.StretchedAtlas(e, "common-dropdown-customize-mouseover", "BACKGROUND")
	e.hover.rect:SetAllPoints(e)
	e.hover.rect:SetAlpha(0.15)
	for _, t in ipairs(e.hover.pieces) do
		t:SetAlpha(0.15)
	end
	e.hover:SetShown(false)
	e.number = e:CreateFontString(nil, "OVERLAY")
	e.number:SetFontObject(G.Font("GameFontNormal"))
	e.number:SetJustifyH("LEFT")
	e.number:SetWidth(25)
	e.number:SetHeight(20)
	e.number:SetPoint("TOPLEFT", e, "TOPLEFT", 14, 0)
	e.name = e:CreateFontString(nil, "OVERLAY")
	e.name:SetFontObject(G.Font("GameFontNormal"))
	e.name:SetJustifyH("LEFT")
	e.name:SetHeight(20)
	e.name:SetPoint("LEFT", e.number, "RIGHT", 0, 0)
	-- Swatch right of the number, its ADD glow, and a selection mark left of the swatch
	e.swatch = e:CreateTexture(nil, "ARTWORK")
	G.PlaceAtlas(e.swatch, "charactercreate-customize-palette", true)
	e.swatch:SetPoint("LEFT", e.number, "RIGHT", 0, 0)
	e.glow = e:CreateTexture(nil, "ARTWORK")
	G.PlaceAtlas(e.glow, "charactercreate-customize-palette-glow", true)
	e.glow:SetBlendMode("ADD")
	e.glow:SetPoint("CENTER", e.swatch, "CENTER")
	e.selected = e:CreateTexture(nil, "ARTWORK")
	G.PlaceAtlas(e.selected, "charactercreate-customize-palette-selected", true)
	e.selected:SetPoint("LEFT", e.swatch, "LEFT", -4, 0)
	e:SetScript("OnEnter", function(self)
		self.hover:SetShown(true)
		if isOpen then
			preview = { k = self.k, pending = PREVIEW_DELAY, fresh = true }
		end
	end)
	e:SetScript("OnLeave", function(self)
		self.hover:SetShown(false)
		if preview and preview.k == self.k then
			preview = nil
		end
	end)
	e:SetScript("OnClick", function(self)
		if isOpen then
			preview = nil
			PlaySound("gsCharacterCreationLook")
			goTo(isOpen.row.i, lists[isOpen.row.i][self.k])
			closeMenu(true)
		end
	end)
	entries[k] = e
	return e
end

local function openMenu(row)
	local list = lists[row.i]
	if not list then
		return
	end
	local n = #list
	local selected = rank(list, index(row.i)) or 1
	local columns = (n > 36 and 4) or (n > 24 and 3) or (n > 10 and 2) or 1
	local rowLines = math.ceil(n / columns)
	-- The list starts at the box's bottom, so cap how many rows fit above the screen bottom
	local top = row.cell:GetBottom()
	if top then
		local maxValue = math.max(1, math.floor((top - 100) / 20))
		if rowLines > maxValue then
			columns = math.ceil(n / maxValue)
			rowLines = math.ceil(n / columns)
		end
	end
	-- Entry width on several columns: 25 + 36 + 18 with colors, or 42 without
	local colors = colorOf(row.i, list[1]) and true
	local names = {}
	local anyNamed = false
	if not colors then
		for k = 1, n do
			names[k] = nameOf(row.i, list[k])
			anyNamed = anyNamed or names[k] ~= nil
		end
	end
	local details = 116
	if columns > 1 then
		details = (colors and (25 + 36 + 18)) or (anyNamed and 108) or 42
	end
	local width = 14 + details + 14
	menu:ClearAllPoints()
	menu:SetPoint("TOPRIGHT", row.cell, "BOTTOMRIGHT")
	menu:SetWidth(3 + columns * width + 3)
	menu:SetHeight(6 + rowLines * 20 + 7)
	for k = 1, n do
		local e = entry(k)
		e.k = k
		e:SetWidth(width)
		e:ClearAllPoints()
		e:SetPoint("TOPLEFT", menu, "TOPLEFT", 3 + math.floor((k - 1) / rowLines) * width, -(6 + ((k - 1) % rowLines) * 20))
		e.number:SetText(k)
		local name = names[k]
		if name then
			measure:SetText(name)
			e.name:SetWidth(math.min(measure:GetStringWidth(), width - 2 - 25))
			e.name:SetText(name)
		end
		G.SetShown(e.name, name)
		if k == selected then
			e.number:SetTextColor(1, 0.82, 0)
			e.name:SetTextColor(1, 0.82, 0)
		else
			e.number:SetTextColor(0.5, 0.5, 0.5)
			e.name:SetTextColor(0.5, 0.5, 0.5)
		end
		e.hover:SetShown(false)
		local color = colorOf(row.i, list[k])
		if color then
			e.swatch:SetVertexColor(color[1], color[2], color[3])
		end
		G.SetShown(e.swatch, color)
		G.SetShown(e.glow, color)
		G.SetShown(e.selected, color and k == selected)
		e:Show()
	end
	for k = n + 1, #entries do
		entries[k]:Hide()
	end
	isOpen = { row = row, selected = list[selected] }
	menu:Show()
	catcher:Show()
	paintDropdown(row)
end

-- Box background per state (pressed, hovered, open), arrow on hover and its contents
-- nudged (1, -1) when pressed
paintDropdown = function(row)
	local b = row.button
	local name = "common-dropdown-c-button"
	if b.down and b.hovered then
		name = "common-dropdown-c-button-pressedhover-1"
	elseif b.down then
		name = "common-dropdown-c-button-pressed-1"
	elseif b.hovered then
		name = "common-dropdown-c-button-hover-1"
	elseif isOpen and isOpen.row == row then
		name = "common-dropdown-c-button-open"
	end
	row.background:Place(name)
	G.SetShown(row.arrow, b.hovered)
	local dx, dy = b.down and 1 or 0, b.down and -1 or 0
	row.number:ClearAllPoints()
	row.number:SetPoint("CENTER", row.cell, "CENTER", dx, dy)
	row.swatch:ClearAllPoints()
	row.swatch:SetPoint("CENTER", row.cell, "CENTER", dx, dy)
	row.text:ClearAllPoints()
	row.text:SetPoint("LEFT", row.cell, "LEFT", 13 + dx, dy)
	row.text:SetPoint("RIGHT", row.cell, "RIGHT", -13 + dx, dy)
end

for _, row in ipairs(rows) do
	local b, i = row.button, row.i
	b:SetScript("OnEnter", function(self) self.hovered = true; paintDropdown(row) end)
	b:SetScript("OnLeave", function(self) self.hovered = nil; paintDropdown(row) end)
	b:SetScript("OnMouseDown", function(self) self.down = true; paintDropdown(row) end)
	b:SetScript("OnMouseUp", function(self) self.down = nil; paintDropdown(row) end)
	b:SetScript("OnHide", function(self) self.hovered, self.down = nil, nil end)
	b:SetScript("OnClick", function()
		if isOpen and isOpen.row == row then
			closeMenu(false)
		else
			closeMenu(false)
			openMenu(row)
		end
	end)
	-- Mouse wheel on the box: down selects the next choice
	b:SetScript("OnMouseWheel", function(_, direction)
		closeMenu(false)
		if direction < 0 then
			CharacterCustomization_Right(i)
		else
			CharacterCustomization_Left(i)
		end
		refreshSettings(i)
	end)
end

-- Setting names come from the client; in mode 2 each row also shows its choice number.
-- Lists are recomputed on every refresh, which is instant without the engine.
refreshSettings = function()
	local hair, facialHair = GetHairCustomization(), GetFacialHairCustomization()
	local names = {
		CHAR_CUSTOMIZATION1_DESC, CHAR_CUSTOMIZATION2_DESC,
		_G["HAIR_" .. hair .. "_STYLE"], _G["HAIR_" .. hair .. "_COLOR"],
		_G["FACIAL_HAIR_" .. facialHair],
	}
	for i, row in ipairs(rows) do
		local v = index(i)
		if not v then
			lists[i] = nil
		else
			lists[i] = compute(i)
			-- Fallback: the engine value is missing from the computed list
			if not (lists[i] and rank(lists[i], v)) then
				lists[i] = enumerate(i)
			end
		end
		local position = v and lists[i] and rank(lists[i], v)
		local color = position and colorOf(i, v)
		if color then
			row.swatch:SetVertexColor(color[1], color[2], color[3])
		end
		G.SetShown(row.swatch, color)
		G.SetShown(row.glow, color)
		-- Choice name in the box (skin: the swatch takes precedence)
		local name = position and not color and nameOf(i, v)
		if position then
			row.title:SetText(names[i] or "")
			row.number:SetText(position)
			row.text:SetText(name or "")
			G.SetShown(row.text, name)
			row.title:Show()
			G.SetShown(row.number, not color and not name)
			row.button:Show()
		else
			row.text:SetText(names[i] or "")
			row.text:Show()
			row.title:Hide()
			row.number:Hide()
			row.button:Hide()
		end
		paintDropdown(row)
	end
end

-- Name entry panel
local nameChoice = CreateFrame("Frame", "ForeverLoginCharacterCreateNameChoice", character)
nameChoice:SetFrameLevel(character:GetFrameLevel() + 4)
-- Anchored at the bottom of the screen: brackets below, title under the field, dice and
-- field raised
nameChoice:SetPoint("BOTTOM", character, "BOTTOM", 0, 0)
local sizeName = bronzeFrame(nameChoice, { { "heavybronze-horz-cornerbracket-br", "BOTTOMRIGHT" }, { "heavybronze-horz-cornerbracket-bl", "BOTTOMLEFT" } })
-- Width 10 + 48 (dice) + 343 (field) + 48 + 10, the field centered under the title
sizeName(10 + 48 + 343 + 48 + 10, 90)
local nameTitle = nameChoice:CreateFontString(nil, "ARTWORK")
nameTitle:SetFontObject(G.Font("GameFontHighlightLarge2"))
nameTitle:SetPoint("BOTTOM", nameChoice, "BOTTOM", 0, 16)
nameTitle:SetText(NAME)

-- RandomNameButton: the client's random name, when it allows it
local randomName = CreateFrame("Button", "ForeverLoginCharacterCreateRandomNameButton", nameChoice)
G.SquareIconButton(randomName, "charactercreate-icon-dice", 24, "OVERLAY")
randomName:SetPoint("LEFT", nameChoice, "LEFT", 10, 10)
randomName:SetScript("OnClick", function()
	CharacterCreateNameEdit:SetText(GetRandomName())
	PlaySound("gsCharacterCreationLook")
end)
leftTooltip(randomName, RANDOMIZE)

-- The client's name field, restyled and anchored in the panel without changing its parent
local nameField = CharacterCreateNameEdit
nameField:SetBackdrop(nil)
-- Hide only the client's "Name" label: GetRegions also returns the field's own text
for _, r in ipairs({ nameField:GetRegions() }) do
	if r:GetObjectType() == "FontString" and r:GetText() == NAME then
		r:SetAlpha(0)
		r:Hide()
	end
end
local edgeLeft = nameField:CreateTexture(nil, "BACKGROUND")
G.PlaceAtlas(edgeLeft, "common-gray-button-entrybox-left", true)
edgeLeft:SetPoint("LEFT", nameField, "LEFT")
local edgeRight = nameField:CreateTexture(nil, "BACKGROUND")
G.PlaceAtlas(edgeRight, "common-gray-button-entrybox-right", true)
edgeRight:SetPoint("RIGHT", nameField, "RIGHT")
local middleEdge = nameField:CreateTexture(nil, "BACKGROUND")
G.PlaceAtlas(middleEdge, "common-gray-button-entrybox-center")
middleEdge:SetPoint("TOPLEFT", edgeLeft, "TOPRIGHT")
middleEdge:SetPoint("BOTTOMRIGHT", edgeRight, "BOTTOMLEFT")
nameField:SetWidth(343)
nameField:SetHeight(48)
nameField:SetFontObject(G.Font("NumberFont_Shadow_Large"))
nameField:SetJustifyH("CENTER")
nameField:SetTextInsets(0, 0, 0, 0)
nameField:SetFrameLevel(nameChoice:GetFrameLevel() + 2)
nameField:ClearAllPoints()
nameField:SetPoint("LEFT", randomName, "RIGHT", 0, 0)
-- Escape goes back and Enter goes forward. The field keeps focus in step 2, so Escape first
-- closes an open list, as OnKeyDown does
nameField:SetScript("OnEscapePressed", function()
	if isOpen then
		closeMenu(false)
	else
		backButton:Click()
	end
end)
nameField:SetScript("OnEnterPressed", function() forwardButton:Click() end)

-- Small buttons without the zoom button; at creation the scenery camera belongs to the model
-- and follows it
local DEFAULT_FACING = -15    -- client's CharacterCreate_OnShow
local smallButtons = CreateFrame("Frame", nil, character)
smallButtons:SetFrameLevel(character:GetFrameLevel() + 4)
smallButtons:SetPoint("TOPLEFT", character, "TOPLEFT", 40, -30)
local sizeSmallButtons = bronzeFrame(smallButtons, {}, 8)
-- 10, then 48 per button with -5 spacing and 30 more before rotation, then 10
local SMALL_BUTTONS_X = { 10, 10 + 43 + 30, 10 + 86 + 30 }
sizeSmallButtons(SMALL_BUTTONS_X[3] + 48 + 10, 10 + 48 + 10)

-- Square button in the small-button frame; x: left offset; text: tooltip
local function smallButton(icon, x, text)
	local b = CreateFrame("Button", nil, smallButtons)
	G.SquareIconButton(b, icon, 24, "OVERLAY")
	b:SetPoint("TOPLEFT", smallButtons, "TOPLEFT", x, -10)
	b:SetScript("OnEnter", function(self)
		GlueTooltip_SetOwner(self, nil, -5, -5, "TOPLEFT", "BOTTOMRIGHT")
		GlueTooltip_SetText(text, nil, 1.0, 1.0, 1.0)
	end)
	b:SetScript("OnLeave", function() GlueTooltip:Hide() end)
	return b
end

-- Turns back to the default facing over 0.25 s
local resetButton = smallButton("common-icon-undo", SMALL_BUTTONS_X[1], TEXT.RESET_CAMERA)
resetButton:SetScript("OnClick", function(self)
	PlaySound("igMainMenuOptionCheckBoxOn")
	local origin, t = GetCharacterCreateFacing(), 0
	local gap = ((DEFAULT_FACING - origin + 180) % 360) - 180
	self:SetScript("OnUpdate", function(me, elapsed)
		t = t + elapsed
		local p = math.min(1, t / 0.25)
		SetCharacterCreateFacing(origin + gap * p)
		if p >= 1 then
			me:SetScript("OnUpdate", nil)
		end
	end)
end)

-- A click turns by step; holding over 0.25 s turns by perSecond degrees per second
local function rotate(b, step, perSecond)
	G.Hook(b, "OnMouseDown", function(self)
		self.held = false
		self.pending = 0.25
		self:SetScript("OnUpdate", function(me, elapsed)
			if me.pending then
				me.pending = me.pending - elapsed
				if me.pending >= 0 then
					return
				end
				elapsed = elapsed + me.pending
				me.pending = nil
			end
			me.held = true
			SetCharacterCreateFacing(GetCharacterCreateFacing() + perSecond * elapsed)
		end)
	end)
	G.Hook(b, "OnMouseUp", function(self)
		self.pending = nil
		self:SetScript("OnUpdate", nil)
	end)
	G.Hook(b, "OnHide", function(self)
		self.pending = nil
		self:SetScript("OnUpdate", nil)
	end)
	b:SetScript("OnClick", function(self)
		PlaySound("igMainMenuOptionCheckBoxOn")
		if not self.held then
			SetCharacterCreateFacing(GetCharacterCreateFacing() + step)
		end
	end)
end
rotate(smallButton("common-icon-rotateleft", SMALL_BUTTONS_X[2], TEXT.ROTATE_LEFT), -10, -100)
rotate(smallButton("common-icon-rotateright", SMALL_BUTTONS_X[3], TEXT.ROTATE_RIGHT), 10, 100)

-- ------------------------------------------------------------ Steps

-- Client elements we replace; its race, class and sex buttons stay hidden with their panel
-- but remain clickable through :Click()
local CLIENT_HIDDEN = {
	CharacterCreateWoWLogo, CharacterCreateCharacterRace, CharacterCreateCharacterClass,
	CharacterCreateConfigurationFrame, CharacterCreateRandomName,
	CharacterCreateRotateLeft, CharacterCreateRotateRight, CharCreateOkayButton, CharCreateBackButton,
}

-- Fade of the bottom vignette (FadeOut / FadeIn, 0.25 s)
local function fadeTo(to)
	state.fade = { origin = backgroundBottom:GetAlpha(), to = to, t = 0 }
	root:SetScript("OnUpdate", function(_, elapsed)
		local f = state.fade
		f.t = f.t + elapsed
		local p = math.min(1, f.t / 0.25)
		backgroundBottom:SetAlpha(f.origin + (f.to - f.origin) * p)
		if p >= 1 then
			root:SetScript("OnUpdate", nil)
		end
	end)
end

-- Switches step; mode: 1 race and class, 2 customization
local function showMode(mode)
	local forward = state.mode
	state.mode = mode
	local one = (mode == 1)
	forgetMenu()
	for _, f in ipairs(CLIENT_HIDDEN) do
		f:Hide()
	end
	G.SetShown(raceClass, one)
	for _, f in ipairs(FRAME_BOXES) do
		G.SetShown(f, one)
	end
	G.SetShown(character, not one)
	G.SetShown(CharacterCreateNameEdit, not one)
	G.SetShown(randomName, ALLOW_RANDOM_NAME_BUTTON and true or false)
	if one then
		CharacterCreateNameEdit:ClearFocus()
	else
		refreshSettings()
	end
	setNavText(backButton, BACK)
	setNavText(forwardButton, one and TEXT.CUSTOMIZE or TEXT.FINISH)
	if forward ~= mode then
		fadeTo(one and (state.backgroundAlpha or 1) or 0)
	end
	-- the other step's blocks may need more room; the scale never grows back meanwhile
	G.Rescale()
end

-- NavBack / NavForward
backButton:SetScript("OnClick", function()
	PlaySound("igMainMenuOptionCheckBoxOn")
	if state.mode == 1 then
		CharacterCreate_Back()
	else
		PlaySound("gsCharacterCreationCancel")
		showMode(1)
	end
end)
forwardButton:SetScript("OnClick", function()
	PlaySound("igMainMenuOptionCheckBoxOn")
	if state.mode == 1 then
		PlaySound("gsCharacterSelectionCreateNew")
		showMode(2)
	else
		CharacterCreate_Okay()
	end
end)

-- Escape goes back, Enter goes forward, PrintScreen captures a screenshot
CharacterCreate:SetScript("OnKeyDown", function(_, pressedKey)
	if pressedKey == "ESCAPE" and isOpen then
		closeMenu(false)
	elseif pressedKey == "ESCAPE" then
		backButton:Click()
	elseif pressedKey == "ENTER" then
		forwardButton:Click()
	elseif pressedKey == "PRINTSCREEN" then
		Screenshot()
	end
end)

-- ------------------------------------------------------------ After the client

G.HookFunction("CharacterChangeFixup", refresh)
G.Hook(CharacterCreate, "OnShow", function()
	placeEdges()
	state.mode = 0
	refresh()
	showMode(1)
	backgroundBottom:SetAlpha(state.backgroundAlpha or 1)
	root:SetScript("OnUpdate", nil)
	-- Column and class positions can be read only once laid out, so refresh again
	refresh()
end)

-- ------------------------------------------------------------ Short screens

-- Blocks kept apart on a short screen, step by step (G.FitOnShow, after the OnShow above);
-- the race buttons and the class bar follow the area's new size
G.FitOnShow(CharacterCreate, function()
	return {
		{ COLUMNS.Alliance, COLUMNS.Horde, body, classes, factionFrameBox, raceFrameBox, classFrameBox, backButton, forwardButton },
		{ container, nameChoice, smallButtons, backButton, forwardButton },
	}
end, refresh)
