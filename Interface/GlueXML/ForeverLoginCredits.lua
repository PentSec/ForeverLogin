-- Credits screen over the client's texts (GetCreditsText), music
-- (SetGlueScreen) and expansion switch (CreditsFrame_Switch).
-- A fixed key art per expansion replaces the 3.3.5 slideshow.

local G = ForeverLogin
local L = G.L
local F = CreditsFrame

-- Texts missing from 3.3.5: G.L (ForeverLoginTexts)
local TEXT = { EXPANSION = L.GLUECREDITS_EXPANSION }

-- Indexed by the client's creditsType (1, 2, 3) over expansions 0, 1, 2.
local EXPANSIONS = {
	{ name = WORLD_OF_WARCRAFT, logo = "Interface\\Glues\\Common\\Glues-WoW-Logo" },
	{ name = BURNING_CRUSADE, logo = "Interface\\Glues\\Common\\Glues-WoW-BCLogo" },
	{ name = WRATH_OF_THE_LICH_KING, logo = "Interface\\Glues\\Common\\Glues-WoW-WotLKLogo" },
}
-- Scroll speeds per second (rewind, pause, reading, fast-forward).
local SPEEDS = { rewind = -160, pause = 0, reading = 40, fastForward = 160 }

local state = { position = 0, speed = SPEEDS.reading }

-- ------------------------------------------------------------ client screen

-- Hides all client art (parchment, slideshow, strips, logo)
local function hideClientArt()
	for _, r in ipairs({ F:GetRegions() }) do
		if r:GetObjectType() == "Texture" and not r.forever then
			r:SetAlpha(0)
			r:Hide()
		end
	end
	-- Top and bottom fades of the column (a child frame); not the text, which is also a child
	-- (ScrollChild)
	for _, c in ipairs({ CreditsScrollFrame:GetChildren() }) do
		if c ~= CreditsText then
			for _, r in ipairs({ c:GetRegions() }) do
				r:SetAlpha(0)
				r:Hide()
			end
		end
	end
	CreditsFrameSwitchButton1:Hide()
	CreditsFrameSwitchButton2:Hide()
end

-- ------------------------------------------------------------ background

-- Creates a texture on the frame, tagged so hideClientArt leaves it alone
local function texture(layer)
	local t = F:CreateTexture(nil, layer)
	t.forever = true
	return t
end

local background = texture("BACKGROUND")
local tiles = { texture("BORDER"), texture("BORDER") }
local topGradient = texture("ARTWORK")
local bottomGradient = texture("ARTWORK")
local logo = texture("OVERLAY")
logo:SetWidth(340)
logo:SetHeight(170)
logo:SetPoint("TOPLEFT", F, "TOPLEFT", 35, -25)

-- Background and gradients cover the whole screen, side strips included. The key art
-- (1425 x 966) is drawn in two tiles (3.3.5 shows no texture wider than 1024) and is
-- scaled to the screen height minus 120.
local function placeArt()
	local kind = F.creditsType or 3
	local extension = kind - 1
	local strip = G.STRIP or 0
	local width, height = F:GetWidth() or 0, F:GetHeight() or 0

	background:ClearAllPoints()
	background:SetPoint("TOPLEFT", F, "TOPLEFT", -strip, 0)
	background:SetPoint("BOTTOMRIGHT", F, "BOTTOMRIGHT", strip, 0)
	G.Tile(background, "CreditsScreen-Background-" .. extension, width + 2 * strip, height)

	local ill = G.illustrations[extension]
	if ill and height > 0 then
		local k = (height - 120) / ill.height
		local x = -((F:GetRight() or 0) - (CreditsScrollFrame:GetLeft() or 0) + 100) / 2
		local left = x - ill.width * k / 2
		for i, t in ipairs(tiles) do
			local tu = ill.tiles[i]
			if tu then
				t:SetTexture(tu[1])
				t:SetTexCoord(0, tu[2], 0, tu[3])
				t:SetWidth(tu[4] * k)
				t:SetHeight(ill.height * k)
				t:ClearAllPoints()
				t:SetPoint("TOPLEFT", F, "TOP", left, -50)
				left = left + tu[4] * k
				t:Show()
			else
				t:Hide()
			end
		end
	end

	for _, t in ipairs({ topGradient, bottomGradient }) do
		G.PlaceAtlas(t, "_CreditsScreen-Gradient-Tile")
		t:SetHeight(64)
		t:ClearAllPoints()
		t:SetPoint("LEFT", F, "LEFT", -strip, 0)
		t:SetPoint("RIGHT", F, "RIGHT", strip, 0)
	end
	topGradient:SetPoint("TOP", F, "TOP")
	bottomGradient:SetPoint("BOTTOM", F, "BOTTOM")
	-- The bottom gradient is flipped (TexCoords top 1, bottom 0)
	local e = G.atlas["_creditsscreen-gradient-tile"]
	bottomGradient:SetTexCoord(e[2], e[3], e[5], e[4])

	logo:SetTexture(EXPANSIONS[kind] and EXPANSIONS[kind].logo or EXPANSIONS[3].logo)
end
G.onScale[#G.onScale + 1] = function()
	if F:IsShown() then
		placeArt()
	end
end

-- ------------------------------------------------------------ text

-- Column over the whole screen height, 50 from the right edge
CreditsScrollFrame:ClearAllPoints()
CreditsScrollFrame:SetWidth(250)
CreditsScrollFrame:SetPoint("TOPRIGHT", F, "TOPRIGHT", -50, 0)
CreditsScrollFrame:SetPoint("BOTTOMRIGHT", F, "BOTTOMRIGHT", -50, 0)
for _, v in ipairs({ { "P", "GlueFontHighlightSmall", 2 }, { "H1", "GlueFontNormalLarge", 4 },
		{ "H2", "GlueFontHighlight", 4 } }) do
	pcall(CreditsText.SetFontObject, CreditsText, v[1], G.Font(v[2]))
	pcall(CreditsText.SetSpacing, CreditsText, v[1], v[3])
end

-- ------------------------------------------------------------ speed

local speedButtons = {}

-- Repaints the speed buttons from the current scroll state.
local function paintSpeedButtons()
	for _, b in ipairs(speedButtons) do
		local active = b.speed == state.speed
		if active then
			b:LockHighlight()
			b:GetHighlightTexture():SetAlpha(0.5)
		else
			b:UnlockHighlight()
			b:GetHighlightTexture():SetAlpha(1)
		end
	end
end

local function applySpeed(v)
	PlaySound("igMainMenuOptionCheckBoxOff")
	state.speed = v
	paintSpeedButtons()
end

-- CreditsSpeedButtonTemplate: 43 x 43 square button with an icon and an ADD glow
local function speedButton(icon, speed)
	local b = CreateFrame("Button", nil, F)
	b:SetWidth(43)
	b:SetHeight(43)
	b.speed = speed
	local n = G.StateTexture(b, "SetNormalTexture", "GetNormalTexture")
	G.PlaceAtlas(n, "common-button-square-gray-up", true)
	n:ClearAllPoints()
	n:SetPoint("CENTER", b, "CENTER")
	local p = G.StateTexture(b, "SetPushedTexture", "GetPushedTexture")
	G.PlaceAtlas(p, "common-button-square-gray-down", true)
	p:ClearAllPoints()
	p:SetPoint("CENTER", b, "CENTER")
	b.icon = b:CreateTexture(nil, "OVERLAY")
	G.PlaceAtlas(b.icon, icon, true)
	b.icon:SetPoint("CENTER", b, "CENTER")
	local h = G.StateTexture(b, "SetHighlightTexture", "GetHighlightTexture")
	G.PlaceAtlas(h, icon, true)
	h:ClearAllPoints()
	h:SetPoint("CENTER", b.icon, "CENTER")
	h:SetBlendMode("ADD")
	h:SetAlpha(0.4)
	b:SetScript("OnClick", function(self)
		applySpeed(self.speed)
	end)
	speedButtons[#speedButtons + 1] = b
	return b
end

local rewind = speedButton("CreditsScreen-Assets-Buttons-Rewind", SPEEDS.rewind)
rewind:SetPoint("BOTTOM", F, "BOTTOM", -50, 20)
local previous = rewind
for _, v in ipairs({ { "CreditsScreen-Assets-Buttons-Pause", SPEEDS.pause },
		{ "CreditsScreen-Assets-Buttons-Play", SPEEDS.reading },
		{ "CreditsScreen-Assets-Buttons-FastForward", SPEEDS.fastForward } }) do
	local b = speedButton(v[1], v[2])
	b:SetPoint("LEFT", previous, "RIGHT", 5, 0)
	previous = b
end

-- ------------------------------------------------------------ scrolling

-- Replaces the client's CreditsFrame_OnUpdate (fixed speed, slideshow): uses the chosen
-- speed, pauses at the start when rewinding, and returns to login at the end like the client
F:SetScript("OnUpdate", function(_, elapsed)
	if not CreditsScrollFrame:IsShown() then
		return
	end
	state.position = state.position + state.speed * (elapsed or 0)
	if state.position <= 0 then
		state.position = 0
		if state.speed < 0 then
			state.speed = SPEEDS.pause
			paintSpeedButtons()
		end
	end
	local finish = CreditsScrollFrame:GetVerticalScrollRange() + (CreditsScrollFrame:GetHeight() or 0)
	if state.position >= finish then
		SetGlueScreen("login")
		return
	end
	CreditsScrollFrame:SetVerticalScroll(state.position)
end)

-- ------------------------------------------------------------ expansion list

local SMALL_FONTS = { "GlueFontNormalSmall", "GlueFontHighlightSmall", "GlueFontDisableSmall" }

local list = CreateFrame("Frame", "ForeverLoginCreditsExpansionList", F)
list:SetFrameStrata("DIALOG")
list:EnableMouse(true)
list:SetPoint("CENTER", F, "CENTER")
list:Hide()
do
	local black = list:CreateTexture(nil, "BACKGROUND")
	black:SetTexture(0, 0, 0, 0.8)
	black:SetPoint("TOPLEFT", list, "TOPLEFT", 7, -7)
	black:SetPoint("BOTTOMRIGHT", list, "BOTTOMRIGHT", -7, 7)
	G.NineSlice(list, "Dialog")
end
G.DialogHeader(list, TEXT.EXPANSION, "GameFontNormal")

local rows = {}
local choice

-- Shows the selection mark on the chosen row
local function mark()
	for _, b in ipairs(rows) do
		G.SetShown(b.selectedItem, b:GetID() == choice)
	end
end

for i, ext in ipairs(EXPANSIONS) do
	local b = CreateFrame("Button", nil, list)
	b:SetID(i)
	b:SetHeight(28)
	b:SetNormalFontObject(G.Font("GlueFontHighlightSmall"))
	b:SetHighlightFontObject(G.Font("GlueFontHighlightSmall"))
	b:SetDisabledFontObject(G.Font("GlueFontDisableSmall"))
	b:SetText(ext.name)
	b.selectedItem = b:CreateTexture(nil, "ARTWORK")
	G.PlaceAtlas(b.selectedItem, "CreditsScreen-Selected")
	b.selectedItem:SetAllPoints(b)
	b.selectedItem:SetVertexColor(1, 1, 1, 0.8)
	b.selectedItem:Hide()
	b.hover = b:CreateTexture(nil, "ARTWORK")
	G.PlaceAtlas(b.hover, "CreditsScreen-Highlight")
	b.hover:SetAllPoints(b)
	b.hover:Hide()
	b:SetScript("OnEnter", function(self)
		if not self.selectedItem:IsShown() then
			self.hover:Show()
		end
	end)
	b:SetScript("OnLeave", function(self) self.hover:Hide() end)
	b:SetScript("OnClick", function(self)
		choice = self:GetID()
		mark()
		self.hover:Hide()
	end)
	if i == 1 then
		b:SetPoint("TOP", list, "TOP", 0, -35)
	else
		b:SetPoint("TOP", rows[i - 1], "BOTTOM", 0, -5)
	end
	rows[i] = b
end

local ok = G.CreateThreeSliceButton("ForeverLoginCreditsExpansionOkay", list, 100, 28, "128-RedButton", SMALL_FONTS, OKAY)
ok:SetPoint("BOTTOMRIGHT", list, "BOTTOM", -2, 20)
local cancel = G.CreateThreeSliceButton("ForeverLoginCreditsExpansionCancel", list, 100, 28, "128-RedButton", SMALL_FONTS, CANCEL)
cancel:SetPoint("LEFT", ok, "RIGHT", 4, 0)
ok:SetScript("OnClick", function()
	PlaySound("igMainMenuOptionCheckBoxOff")
	list:Hide()
	if choice and choice ~= F.creditsType then
		CreditsFrame_Switch(F, choice)
	end
end)
cancel:SetScript("OnClick", function()
	PlaySound("igMainMenuOptionCheckBoxOff")
	list:Hide()
end)

-- Opens the expansion list dropdown.
local function openList()
	choice = F.creditsType or 3
	local widest = 200
	for _, b in ipairs(rows) do
		widest = math.max(widest, b:GetTextWidth() or 0)
	end
	for _, b in ipairs(rows) do
		b:SetWidth(widest)
	end
	local buttonTextWidth = math.max(ok:GetTextWidth() or 0, cancel:GetTextWidth() or 0)
	local lb = math.max(80, buttonTextWidth) + 10 * 2
	ok:SetWidth(lb)
	cancel:SetWidth(lb)
	list:SetWidth(math.max(widest, 2 * lb) + 60)
	list:SetHeight(#rows * (28 + 5) + 100)
	mark()
	list:Show()
end

-- ------------------------------------------------------------ Back and Expansion

local backButton = G.CreateThreeSliceButton("ForeverLoginCreditsBackButton", F, 150, 28, "128-RedButton", SMALL_FONTS, BACK)
backButton:SetPoint("BOTTOMLEFT", GlueParent, "BOTTOMLEFT", 50, 50)
backButton:SetScript("OnClick", function()
	SetGlueScreen("login")
end)
local extension = G.CreateThreeSliceButton("ForeverLoginCreditsExpansionButton", F, 150, 28, "128-RedButton", SMALL_FONTS, TEXT.EXPANSION)
extension:SetPoint("BOTTOM", backButton, "TOP", 0, 10)
extension:SetScript("OnClick", function()
	if list:IsShown() then
		list:Hide()
	else
		openList()
	end
end)

F:SetScript("OnKeyDown", function(_, pressedKey)
	if pressedKey == "ESCAPE" then
		if list:IsShown() then
			list:Hide()
		else
			SetGlueScreen("login")
		end
	elseif pressedKey == "PRINTSCREEN" then
		Screenshot()
	end
end)

-- ------------------------------------------------------------ on each show

-- Runs after the client's CreditsFrame_OnShow (text, scroll reset to 0)
G.Hook(F, "OnShow", function()
	hideClientArt()
	list:Hide()
	state.position = 0
	state.speed = SPEEDS.reading
	paintSpeedButtons()
	placeArt()
end)
hideClientArt()
