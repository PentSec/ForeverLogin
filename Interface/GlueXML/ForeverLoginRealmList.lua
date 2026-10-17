-- Realm list: our own screen. GlueXML.toc no longer loads the client's RealmList.xml, so this
-- file is the whole realm list: a row of realm cards, the category the list is showing with an
-- arrow either side of it, and the arrows that turn the page. Only the C side of the list is
-- used (GetRealmCategories, GetRealmInfo, ChangeRealm).

local G = ForeverLogin

-- The realms are read through these two: one place to look at, and one place to stand in for the
-- client's list while testing the screen.
local function countRealms(category)
	return GetNumRealms(category) or 0
end

local function realmInfo(category, index)
	return GetRealmInfo(category, index)
end


-- Four realms in view. The card keeps the proportions of its art, so it is scaled to fit.
local SLOTS, CARD_W, CARD_H, GAP = 4, 300, 633, 40
local PITCH = CARD_W + GAP
local SIDE, TOP, BOTTOM = 96, 104, 168
local ARROW_W, ARROW_H = 42, 67    -- the page arrow art's proportions (68 x 108)
local CAT_ARROW_W, CAT_ARROW_H = 26, 41    -- the category arrows
local RIBBON = 95                          -- half the state ribbon's width, in the card's middle
local HOVER_ZOOM = 1.02                    -- how much a card grows while the mouse is over it
local HOVER_SPEED = 9                      -- how fast it gets there, per second
local CARD_PAD_TOP = 48                    -- room above the cards: the selection pointer lives there
local CARD_PAD_BOTTOM = 12                 -- and a little below, for the zoom
local TWEEN = 0.18

-- Realm type and load, as the client's own list shows them.
local function typeText(pvp, rp)
	if pvp and rp then
		return RPPVP_PARENTHESES, NORMAL_FONT_COLOR
	elseif rp then
		return RP_PARENTHESES, GREEN_FONT_COLOR
	elseif pvp then
		return PVP_PARENTHESES, RED_FONT_COLOR
	end
	return GAMETYPE_NORMAL, NORMAL_FONT_COLOR
end

-- Realm types have no icon of their own in the client (its list writes them out as text), so
-- the badge is the mode select ring with the closest glyph the game ships: crossed swords for
-- PvP, the die for a roleplay realm, the anvil for a development one. Change a line to swap.
local BADGE = {
	pvp = { "realmlist-swords" },
	rp = { "charactercreate-icon-dice" },
	rppvp = { "charactercreate-icon-dice", "realmlist-swords" },
	dev = { "realmlist-anvil" },
}

-- The realm's own type wins: a pvp realm in a category named after development still wears the
-- swords, which is what the category name cannot tell apart.
local function badgeFor(card)
	if card.pvp and card.rp then
		return BADGE.rppvp
	elseif card.pvp then
		return BADGE.pvp
	elseif card.rp then
		return BADGE.rp
	elseif card.dev then
		return BADGE.dev
	end
end

local function loadText(realmDown, locked, load)
	load = load or 0
	if realmDown then
		return REALM_DOWN, GRAY_FONT_COLOR
	elseif locked then
		return REALM_LOCKED, RED_FONT_COLOR
	elseif load == -3 then
		return LOAD_RECOMMENDED, BLUE_FONT_COLOR
	elseif load == -2 then
		return LOAD_NEW, GREEN_FONT_COLOR
	elseif load == 2 then
		return LOAD_FULL, RED_FONT_COLOR
	elseif load > 0 then
		return LOAD_HIGH, RED_FONT_COLOR
	elseif load < 0 then
		return LOAD_LOW, GREEN_FONT_COLOR
	end
	return LOAD_MEDIUM, NORMAL_FONT_COLOR
end

-- Green if the realm holds characters, gold if not, grey once it is down
local function nameColor(realmDown, numCharacters)
	numCharacters = numCharacters or 0
	if realmDown then
		return 0.5, 0.5, 0.5
	elseif numCharacters > 0 then
		return 0.1, 1, 0.1
	end
	return 1, 0.78, 0
end


-- ------------------------------------------------------------ The screen

-- A dark veil over the login scene, so the cards read against it, and nothing else: the frame
-- only keeps the clicks (the screen stays modal, as the client's was). The veil's alpha is the
-- one value to raise or lower to taste.
local VEIL_ALPHA = 0.5
local VEIL_BAND = 260      -- how far the dark bands reach from the top and the bottom
local VEIL_CAP = 110       -- solid black right at the top and the bottom, over the bands
local VEIL_BANDS = 2       -- the bands are stacked, so the one under the cap starts nearly black

local screen = CreateFrame("Frame", "RealmList", GlueParent)
screen:SetAllPoints(GlueParent)
screen:SetFrameStrata("DIALOG")
screen:SetToplevel(true)
screen:EnableMouse(true)
screen:EnableMouseWheel(true)
screen:EnableKeyboard(true)
screen:Hide()
screen.veil = screen:CreateTexture(nil, "BACKGROUND")
screen.veil:SetAllPoints(screen)
screen.veil:SetTexture(0, 0, 0, VEIL_ALPHA)

-- Each end gets a solid black cap and, under it, a band of the client's own gradient: together
-- the title and the bottom buttons sit over black that fades into the veil towards the middle.
local gradEntry = G.atlas["_creditsscreen-gradient-tile"]
local function veilEnd(fromTop)
	local cap = screen:CreateTexture(nil, "BACKGROUND")
	cap:SetTexture(0, 0, 0, 1)
	cap:SetHeight(VEIL_CAP)
	local band
	for _ = 1, VEIL_BANDS do
		band = screen:CreateTexture(nil, "BACKGROUND")
		G.PlaceAtlas(band, "_creditsscreen-gradient-tile")
		band:SetHeight(VEIL_BAND)
		if fromTop then
			band:SetPoint("TOPLEFT", screen, "TOPLEFT", 0, -VEIL_CAP)
			band:SetPoint("TOPRIGHT", screen, "TOPRIGHT", 0, -VEIL_CAP)
		else
			-- the bottom bands are the same art flipped (texcoords top 1, bottom 0)
			band:SetTexCoord(gradEntry[2], gradEntry[3], gradEntry[5], gradEntry[4])
			band:SetPoint("BOTTOMLEFT", screen, "BOTTOMLEFT", 0, VEIL_CAP)
			band:SetPoint("BOTTOMRIGHT", screen, "BOTTOMRIGHT", 0, VEIL_CAP)
		end
	end
	if fromTop then
		cap:SetPoint("TOPLEFT", screen, "TOPLEFT")
		cap:SetPoint("TOPRIGHT", screen, "TOPRIGHT")
	else
		cap:SetPoint("BOTTOMLEFT", screen, "BOTTOMLEFT")
		cap:SetPoint("BOTTOMRIGHT", screen, "BOTTOMRIGHT")
	end
	return cap
end
screen.capTop = veilEnd(true)
screen.capBottom = veilEnd(false)
screen.selectedCategory = 1
screen.currentRealm = 0
screen.scrollX = 0
screen.scrollTarget = 0
screen.fit = 1
screen.step = PITCH
screen.view = SLOTS * PITCH

-- 3.3.5 hands a key to the frame under the mouse, so every part that can be under it passes the
-- keys on to the screen: without this, ESCAPE with the cursor over a card does nothing and the
-- client applies its own meaning to the key.
local function keyed(frame)
	if not frame then
		return
	end
	frame:EnableKeyboard(true)
	frame:SetScript("OnKeyUp", function()
	end)
	frame:SetScript("OnKeyDown", function(_, key)
		screen:OnKeyDown(key)
	end)
end

-- ------------------------------------------------------------ Header

-- What this screen is and what to do on it, in the client's own words: nobody should have to
-- guess where they are or which button moves them on.
local title = screen:CreateFontString("ForeverLoginRealmTitle", "OVERLAY")
title:SetFontObject(G.Font("GlueFontNormalGigantor"))
title:SetPoint("TOP", screen, "TOP", 0, -18)
title:SetText(SERVER_SELECTION)

local subtitle = screen:CreateFontString("ForeverLoginRealmSubtitle", "OVERLAY")
subtitle:SetFontObject(G.Font("GlueFontNormal"))
subtitle:SetPoint("TOP", title, "BOTTOM", 0, -6)
subtitle:SetText(REALM_DESCRIPTION)

local keyHint = screen:CreateFontString("ForeverLoginRealmKeys", "OVERLAY")
keyHint:SetFontObject(G.Font("GlueFontNormalSmall"))
keyHint:SetTextColor(0.7, 0.7, 0.7, 1)
keyHint:SetPoint("TOP", subtitle, "BOTTOM", 0, -6)
keyHint:SetText("[ENTER] " .. (ENTER_WORLD or OKAY) .. "        [ESC] " .. CANCEL)

local position = screen:CreateFontString("ForeverLoginRealmPosition", "OVERLAY")
position:SetFontObject(G.Font("GlueFontNormalSmall"))
position:SetTextColor(0.7, 0.7, 0.7, 1)
position:SetPoint("BOTTOMRIGHT", screen, "BOTTOMRIGHT", -18, 26)

-- Shown over the row when it is empty: either the client has not answered yet or the category
-- really has no realms.
local notice = screen:CreateFontString("ForeverLoginRealmNotice", "OVERLAY")
notice:SetFontObject(G.Font("GlueFontNormalLarge"))
notice:SetPoint("CENTER", screen, "CENTER", 0, (BOTTOM - TOP) / 2)
notice:Hide()

-- ------------------------------------------------------------ The row

local scroll = CreateFrame("ScrollFrame", "ForeverLoginRealmScroll", screen)
local content = CreateFrame("Frame", nil, scroll)
content:SetWidth(1)
content:SetHeight(1)
scroll:SetScrollChild(content)
keyed(scroll)

-- ------------------------------------------------------------ The arrows

-- The left arrow is the art; the right one is the same art mirrored. Both dim when there is
-- nothing further to scroll to.
local function makeArrow(name, forward, w, h, action)
	local b = CreateFrame("Button", name, screen)
	b:SetWidth(w)
	b:SetHeight(h)
	b.tex = b:CreateTexture(nil, "ARTWORK")
	local e = G.PlaceAtlas(b.tex, "realmlist-arrow")
	b.tex:SetAllPoints(b)
	if forward then
		-- mirrored: the piece keeps its row, the columns swap
		b.tex:SetTexCoord(e[3], e[2], e[4], e[5])
	end
	b:SetScript("OnClick", action)
	keyed(b)
	return b
end

local leftArrow = makeArrow("ForeverLoginRealmPrev", false, ARROW_W, ARROW_H, function()
	screen:Turn(-1)
end)
local rightArrow = makeArrow("ForeverLoginRealmNext", true, ARROW_W, ARROW_H, function()
	screen:Turn(1)
end)

local cardsBuilt = {}

-- How far the row can still scroll, and the arrows that follow that.
local function scrollRange()
	local most = (screen.contentWidth or screen.view) - screen.view
	return most > 0 and most or 0
end

local function updateArrows()
	local most = scrollRange()
	local at = screen.scrollX or 0
	G.SetShown(leftArrow, most > 1)
	G.SetShown(rightArrow, most > 1)
	leftArrow.tex:SetVertexColor(1, 1, 1, at > 1 and 0.9 or 0.25)
	rightArrow.tex:SetVertexColor(1, 1, 1, at < most - 1 and 0.9 or 0.25)
end

-- ------------------------------------------------------------ One card

-- The badge: the ring, grey once the realm is down, and the glyphs of its type inside. Declared
-- before paint, which calls it.
local paintBadge

-- Puts a card on the row at a size factor (1 is its resting size). It is anchored by its centre,
-- so it grows the same to both sides and towards the top and the bottom when the mouse is over
-- it: no compensating offsets to get wrong.
-- (not "place": the layout has a place() of its own, and a second local would shadow it)
local function placeCard(card, factor)
	local scale = (screen.fit or 1) * (factor or 1)
	card:SetScale(scale)
	card:ClearAllPoints()
	card:SetPoint("CENTER", content, "CENTER", card.centerX or 0, (CARD_PAD_TOP - CARD_PAD_BOTTOM) / 2)
end

-- A realm card: the mode select card as background, the dark card once the realm is down and
-- the glow on the focused one. The cards are always solid; the mouse over one zooms it a bit.
local function paint(card)
	local focused = card.focused
	G.SetShown(card.art, not card.offline)
	G.SetShown(card.dark, card.offline)
	G.SetShown(card.glow, focused)
	G.SetShown(card.pointer, focused)
	card.title:SetTextColor(card.nameColor())
	paintBadge(card)
	-- the zoom is a target: the refresh loop walks the card up to it, so it is smooth
	card.zoom = card.zoom or 1
	card.zoomTarget = card.hovered and HOVER_ZOOM or 1
	placeCard(card, card.zoom)
	if card.hovered or focused then
		card:Raise()
	end
end

-- The badge: the ring, grey once the realm is down, and the glyphs of its type inside.
paintBadge = function(card)
	local glyphs = badgeFor(card)
	G.SetShown(card.badge, glyphs and true or false)
	if not glyphs then
		return
	end
	G.PlaceAtlas(card.ring, card.offline and "realmlist-ring-off" or "realmlist-ring")
	local count = #glyphs
	local width = count > 1 and 20 or 30
	local step = width + 2
	for i, slot in ipairs(card.glyphs) do
		local key = glyphs[i]
		G.SetShown(slot, key and true or false)
		if key then
			G.PlaceAtlas(slot, key)
			slot:SetWidth(width)
			slot:SetHeight(width)
			slot:ClearAllPoints()
			-- centred on the ring's hole: with one glyph in the middle, with two either side of it
			slot:SetPoint("CENTER", card.badge, "CENTER", (i - (count + 1) / 2) * step, 0)
		end
	end
end

local function createCard(n)
	local c = CreateFrame("Button", "ForeverLoginRealmCard" .. n, content)
	c:SetWidth(CARD_W)
	c:SetHeight(CARD_H)
	c:RegisterForClicks("LeftButtonUp")
	c.art = c:CreateTexture(nil, "BACKGROUND")
	G.PlaceAtlas(c.art, "realmlist-card")
	c.art:SetAllPoints(c)
	c.dark = c:CreateTexture(nil, "BACKGROUND")
	G.PlaceAtlas(c.dark, "realmlist-card-dark")
	c.dark:SetAllPoints(c)
	c.glow = c:CreateTexture(nil, "ARTWORK")
	G.PlaceAtlas(c.glow, "realmlist-card-glow")
	-- the glow art is a little larger than the card it wraps
	c.glow:SetPoint("TOPLEFT", c, "TOPLEFT", -4, 4)
	c.glow:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", 4, -4)
	local function text(font, w, h)
		local f = c:CreateFontString(nil, "OVERLAY")
		f:SetFontObject(G.Font(font))
		f:SetWidth(w)
		f:SetHeight(h)
		f:SetJustifyH("CENTER")
		return f
	end
	-- title, not name: name is the realm name the client's handlers read
	c.title = text("GlueFontNormalHuge", 244, 48)
	c.title:SetPoint("TOP", c, "TOP", 0, -46)
	c.count = text("GlueFontNormalLarge", 200, 18)
	c.count:SetPoint("TOP", c.title, "BOTTOM", 0, -8)
	c.info = text("GlueFontNormalLarge", 200, 18)
	c.info:SetPoint("TOP", c.count, "BOTTOM", 0, -2)
	c.loadFont = text("GlueFontDisableLarge", 244, 18)
	c.loadFont:SetPoint("BOTTOM", c, "BOTTOM", 0, 40)

	-- the ribbon across the middle: what a player has to know before trying to enter, so it is
	-- not left in the small line at the bottom. It is two halves of the client's side vignette
	-- facing each other, so it is dark behind the text and fades out at both ends.
	c.state = text("GlueFontNormalLarge", RIBBON * 2, 20)
	c.state:SetPoint("CENTER", c, "CENTER", 0, 1)
	local vignette = G.atlas["charactercreate-vignette-sides"]
	local function ribbonHalf(flip)
		local t = c:CreateTexture(nil, "ARTWORK")
		G.PlaceAtlas(t, "charactercreate-vignette-sides")
		if flip then
			t:SetTexCoord(vignette[3], vignette[2], vignette[4], vignette[5])
		end
		t:SetVertexColor(0, 0, 0, 1)
		t:SetWidth(RIBBON)
		t:SetHeight(32)
		t:Hide()
		return t
	end
	c.ribbonLeft = ribbonHalf(true)
	c.ribbonLeft:SetPoint("RIGHT", c, "CENTER")
	c.ribbonRight = ribbonHalf(false)
	c.ribbonRight:SetPoint("LEFT", c, "CENTER")
	c.state:Hide()

	-- the game's own pointer, above the card that holds the focus
	c.pointer = c:CreateTexture(nil, "OVERLAY")
	G.PlaceAtlas(c.pointer, "realmlist-select-arrow")
	c.pointer:SetWidth(34)
	c.pointer:SetHeight(34)
	c.pointer:SetPoint("CENTER", c, "TOP", 0, 10)
	c.pointer:Hide()

	-- the type badge: ring plus up to two glyphs
	c.badge = CreateFrame("Frame", "ForeverLoginRealmBadge" .. n, c)
	c.badge.card = c
	c.badge:SetWidth(56)
	c.badge:SetHeight(56)
	c.badge:SetPoint("TOP", c, "TOP", 0, -152)
	c.ring = c.badge:CreateTexture(nil, "ARTWORK")
	c.ring:SetAllPoints(c.badge)
	c.glyphs = {}
	for i = 1, 2 do
		local g = c.badge:CreateTexture(nil, "OVERLAY")
		c.glyphs[i] = g
		g:Hide()
	end
	c.badge:Hide()

	-- the ring answers what the glyph means, in the client's own words
	c.badge:EnableMouse(true)
	c.badge:SetScript("OnEnter", function(self)
		self.card.hovered = true
		paint(self.card)
		GlueTooltip_SetOwner(self, nil, -60, 0)
		GlueTooltip_SetText(REALMLIST_TYPE_TOOLTIP or "")
	end)
	c.badge:SetScript("OnLeave", function(self)
		self.card.hovered = false
		paint(self.card)
		GlueTooltip:Hide()
	end)
	-- the ring takes the mouse to explain itself, so it has to pass the clicks on to the card
	c.badge:SetScript("OnMouseUp", function(self, button)
		if button ~= "LeftButton" then
			return
		end
		local now = GetTime()
		if self.clicked and now - self.clicked < 0.4 then
			self.clicked = nil
			self.card:GetScript("OnDoubleClick")(self.card)
		else
			self.clicked = now
			self.card:GetScript("OnClick")(self.card)
		end
	end)

	c.nameColor = function()
		return nameColor(c.offline, c.characters)
	end

	c:SetScript("OnEnter", function(self)
		self.hovered = true
		paint(self)
		if self.major then
			GlueTooltip_SetOwner(self, nil, -50, 0)
			GlueTooltip_SetText(self.major .. "." .. self.minor .. "." .. self.revision .. "  "
				.. self.build .. " Type: " .. tostring(self.realmType))
		end
	end)
	c:SetScript("OnLeave", function(self)
		self.hovered = false
		paint(self)
		GlueTooltip:Hide()
	end)
	c:SetScript("OnClick", function(self)
		if self.index then
			PlaySound("igMainMenuOptionCheckBoxOn")
			screen:Focus(self)
		end
	end)
	c:SetScript("OnDoubleClick", function(self)
		if self.index then
			screen:Focus(self)
			screen:Select()
		end
	end)
	c.glow:Hide()
	c.dark:Hide()
	keyed(c)
	return c
end

-- ------------------------------------------------------------ Category

-- Two pieces here: a strip with the category being listed and an arrow either side to move to
-- the previous or the next one (they hide when the server only has one), and the action button
-- below it, drawn like the character select's Enter World: same art, size and place. That
-- button is what enters the focused realm, and it stays disabled until there is one to enter,
-- exactly like the card's double click.
local categoryButton = CreateFrame("Button", "ForeverLoginRealmCategory", screen)
categoryButton:SetWidth(250)
categoryButton:SetHeight(66)
G.ThreeSliceButton(categoryButton, "128-RedButton", { "GameFontNormalOutline22", "GameFontHighlightOutline22", "GameFontDisableOutline22" })
categoryButton:SetPoint("BOTTOM", screen, "BOTTOM", 0, 45)
categoryButton:SetScript("OnClick", function()
	PlaySound("igMainMenuContinue")
	screen:Select()
end)
categoryButton:SetScript("OnEnter", function(self)
	if G.Truthy(self:IsEnabled()) then
		return
	end
	-- disabled: say why, with the realm's own state
	local card = screen.focused
	GlueTooltip_SetOwner(self, nil, 40, -40)
	GlueTooltip_SetText(card and card.index and (card.loadText or "") or (VAS_SELECT_REALM or ""))
end)
categoryButton:SetScript("OnLeave", function()
	GlueTooltip:Hide()
end)
categoryButton:Disable()
keyed(categoryButton)

local categoryLabel = screen:CreateFontString("ForeverLoginRealmCategoryLabel", "OVERLAY")
categoryLabel:SetFontObject(G.Font("GlueFontNormal"))
categoryLabel:SetWidth(220)
categoryLabel:SetPoint("BOTTOM", screen, "BOTTOM", 0, 130)

local categoryPrev = makeArrow("ForeverLoginRealmCategoryPrev", false, CAT_ARROW_W, CAT_ARROW_H, function()
	screen:StepCategory(-1)
end)
local categoryNext = makeArrow("ForeverLoginRealmCategoryNext", true, CAT_ARROW_W, CAT_ARROW_H, function()
	screen:StepCategory(1)
end)

-- Declared here because buildCategory asks for it and it is written further down.
local updateEnter

-- Names the category in the strip, puts the arrows against it and lets updateEnter write the
-- action button (the realm, when one is focused).
local function buildCategory()
	local names = { GetRealmCategories() }
	screen.categoryName = names[screen.selectedCategory or 1] or ""
	categoryLabel:SetText(screen.categoryName)
	updateEnter()
	categoryPrev:ClearAllPoints()
	categoryPrev:SetPoint("RIGHT", categoryLabel, "LEFT", -6, 0)
	categoryNext:ClearAllPoints()
	categoryNext:SetPoint("LEFT", categoryLabel, "RIGHT", 6, 0)
	G.SetShown(categoryPrev, #names > 1)
	G.SetShown(categoryNext, #names > 1)
end

-- Moves to the next category, wrapping around, skipping any the client has no realms for.
function screen:StepCategory(delta)
	local names = { GetRealmCategories() }
	local count = #names
	if count < 2 then
		return
	end
	local at = self.selectedCategory or 1
	for step = 1, count do
		local next = ((at + delta * step - 1) % count) + 1
		if next ~= at and realmInfo(next, 1) then
			PlaySound("igMainMenuOptionCheckBoxOn")
			self:SelectCategory(next)
			return
		end
	end
end

-- ------------------------------------------------------------ Buttons

-- One button: cancel, drawn like the character select's Back (same art, size and place, with
-- its little arrow at the left of the text). Connecting is the card's double click or ENTER,
-- so there is no OKAY.
local closeButton = CreateFrame("Button", "ForeverLoginRealmClose", screen)
closeButton:SetWidth(188)
closeButton:SetHeight(42)
G.ThreeSliceButton(closeButton, "128-RedButton", { "GlueFontNormal", "GlueFontHighlight", "GlueFontDisable" })
closeButton:SetText(CANCEL)
closeButton:SetPoint("BOTTOMLEFT", screen, "BOTTOMLEFT", 12, 12)
local backArrow = closeButton:CreateTexture(nil, "ARTWORK")
G.PlaceAtlas(backArrow, "common-icon-backarrow")
backArrow:SetWidth(11)
backArrow:SetHeight(16)
local closeText = closeButton:GetFontString()
if closeText then
	backArrow:SetPoint("RIGHT", closeText, "LEFT")
else
	backArrow:SetPoint("RIGHT", closeButton, "LEFT", 60, 0)
end
closeButton:SetScript("OnClick", function()
	screen:Cancel()
end)
keyed(closeButton)

-- The middle button names the category being listed, and the realm once one is focused: the
-- same button enters it. It only lights up while that realm can be entered. 3.3.5 enables a
-- button with Enable / Disable (SetEnabled is a later API, which the client's own addons use).
updateEnter = function()
	local card = screen.focused
	if card and card.index then
		categoryButton:SetText(card.name or "")
	else
		categoryButton:SetText(VAS_SELECT_REALM or REALM_DESCRIPTION or OKAY)
	end
	if G.Truthy(card and card.index and not card.offline) then
		categoryButton:Enable()
	else
		categoryButton:Disable()
	end
end

-- ------------------------------------------------------------ Layout

-- The row is centred between the top of the screen and the tabs, shrunk until four cards fit;
-- the arrows sit in the margins either side of it.
local function place()
	local w = GlueParent:GetWidth() or 0
	local h = GlueParent:GetHeight() or 0
	if w < 1 then
		w = GetScreenWidth() / G.SCALE
	end
	if h < 1 then
		h = GetScreenHeight() / G.SCALE
	end
	local fit = math.min(1, (w - 2 * SIDE) / (SLOTS * PITCH - GAP),
		(h - TOP - BOTTOM - CARD_PAD_TOP - CARD_PAD_BOTTOM) / CARD_H)
	if fit < 0.3 then
		fit = 0.3
	end
	screen.fit = fit
	-- whole units, so every card sits on the same subpixel of the screen and the zoom looks the
	-- same on the first cards and on the ones the row scrolls to
	screen.step = math.floor(PITCH * fit + 0.5)
	local view = w - 2 * SIDE
	if view < PITCH then
		view = PITCH
	end
	screen.view = view

	scroll:ClearAllPoints()
	scroll:SetPoint("CENTER", screen, "CENTER", 0, (BOTTOM - TOP) / 2)
	scroll:SetWidth(view)
	scroll:SetHeight(CARD_H * fit + CARD_PAD_TOP + CARD_PAD_BOTTOM)

	local arrow = math.min(1, fit)
	leftArrow:ClearAllPoints()
	leftArrow:SetPoint("CENTER", scroll, "LEFT", -SIDE / 2, (CARD_PAD_BOTTOM - CARD_PAD_TOP) / 2)
	leftArrow:SetScale(arrow)
	rightArrow:ClearAllPoints()
	rightArrow:SetPoint("CENTER", scroll, "RIGHT", SIDE / 2, (CARD_PAD_BOTTOM - CARD_PAD_TOP) / 2)
	rightArrow:SetScale(arrow)
end

-- ------------------------------------------------------------ Data

-- One card per realm of the category, laid out in a row inside the scroll area.
local function fill()
	place()
	local category = screen.selectedCategory or 1
	local step = screen.step
	-- the client's count and its rows can disagree: the row is built from the realms it actually
	-- returns, so one missing row does not leave the list off centre
	-- GetRealmInfo returns 14 values and several of them are nil (invalid, locked, the version
	-- numbers), so the table keeps the holes and has to be unpacked with its length spelled out
	local REALM_INFO = 14
	local realms = {}
	for i = 1, countRealms(category) do
		local info = { realmInfo(category, i) }
		if info[1] then
			realms[#realms + 1] = { index = i, info = info }
		end
	end
	local total = #realms
	local rowWidth = total > 0 and ((total - 1) * step + CARD_W * screen.fit) or 1
	-- when the realms do not fill the view, the row is centred in it; when they do, it starts at
	-- the left edge as any list would
	local lead = 0
	local contentWidth = rowWidth
	if rowWidth < screen.view then
		lead = math.floor((screen.view - rowWidth) / 2 + 0.5)
		contentWidth = screen.view
	end
	screen.lead = lead
	screen.contentWidth = contentWidth
	-- a development realm is one the server puts in a category named after it
	local names = { GetRealmCategories() }
	local dev = ((names[category] or ""):lower():find("dev", 1, true)) and true or false
	local width = 0
	local current
	for slot = 1, total do
		local card = cardsBuilt[slot]
		if not card then
			card = createCard(slot)
			cardsBuilt[slot] = card
		end
		local entry = realms[slot]
		local name, characters, invalid, realmDown, isCurrent, pvp, rp, load, locked,
			major, minor, revision, buildNumber, realmType = unpack(entry.info, 1, REALM_INFO)
		do
			card.slot = slot
			card.index = entry.index
			card.name = name
			card.characters = characters or 0
			card.offline = G.Truthy(realmDown)
			card.pvp = G.Truthy(pvp)
			card.rp = G.Truthy(rp)
			card.dev = dev
			card.major, card.minor, card.revision, card.build, card.realmType = major, minor, revision, buildNumber, realmType
			card.title:SetText(name)
			card.count:SetText(card.characters > 0 and ("(" .. card.characters .. ")") or "")
			local text, color = typeText(pvp, rp)
			card.info:SetText(text)
			card.info:SetTextColor(color.r, color.g, color.b)
			text, color = loadText(realmDown, locked, load)
			card.loadText = text
			card.loadFont:SetText(text)
			card.loadFont:SetTextColor(color.r, color.g, color.b)
			-- the ribbon is the realm's state, so it is always on: the ones that stop you (or warn
			-- you) in their own colour, and a realm that is up as online in green. The small line
			-- keeps the load, and hides when the ribbon would only repeat it.
			local banner, bannerColor, repeated
			if realmDown then
				banner, bannerColor, repeated = REALM_DOWN, GRAY_FONT_COLOR, true
			elseif locked then
				banner, bannerColor, repeated = REALM_LOCKED, RED_FONT_COLOR, true
			elseif load == 2 then
				banner, bannerColor, repeated = LOAD_FULL, RED_FONT_COLOR, true
			else
				banner, bannerColor = G.L.REALM_ONLINE, GREEN_FONT_COLOR
			end
			card.state:SetText(banner)
			card.state:SetTextColor(bannerColor.r, bannerColor.g, bannerColor.b)
			card.ribbonLeft:Show()
			card.ribbonRight:Show()
			card.state:Show()
			G.SetShown(card.loadFont, not repeated)
			-- where the card's middle sits in the content: the row is centred because the content
			-- is as wide as the view when it is narrower than it, so no offset is added here
			card.centerX = (slot - 1) * step + CARD_W * screen.fit / 2 - rowWidth / 2
			card:Show()
			paint(card)
			width = contentWidth
			-- the slot is where it goes in the row, the index is the client's realm
			if isCurrent and (screen.currentRealm or 0) < 1 then
				current = slot
			end
		end
	end
	for slot = total + 1, #cardsBuilt do
		local card = cardsBuilt[slot]
		card:Hide()
		card.index = nil
		card.slot = nil
		if card.focused then
			card.focused = false
			screen.focused = nil
		end
	end
	if width < 1 then
		width = 1
	end
	content:SetWidth(width)
	content:SetHeight(CARD_H * screen.fit + CARD_PAD_TOP + CARD_PAD_BOTTOM)
	scroll:SetHorizontalScroll(screen.scrollX)
	updateArrows()
	-- nothing of ours on this category (a new account, or a realm list without our realm): start
	-- on the first one that can actually be entered, so the action button is ready to use
	if not current and not screen.focused then
		for i = 1, total do
			local card = cardsBuilt[i]
			if card and card.index and not card.offline then
				current = i
				break
			end
		end
	end
	if current then
		screen:Focus(cardsBuilt[current])
		screen:EnsureVisible(cardsBuilt[current], true)
	end
	local at = screen.focused and screen.focused.index or 0
	position:SetText(at > 0 and (at .. " / " .. total) or "")
	if total < 1 then
		-- say whether the list is still on its way or this category is simply empty
		notice:SetText(screen.gotList and (WOW_ERROR_309 or REALM_LIST_IN_PROGRESS) or REALM_LIST_IN_PROGRESS)
		notice:Show()
	else
		notice:Hide()
	end
	updateEnter()
	return total
end

-- ------------------------------------------------------------ Scrolling

function screen:ScrollTo(x)
	local most = scrollRange()
	if x < 0 then
		x = 0
	elseif x > most then
		x = most
	end
	-- whole units as well: a fractional offset is what made the row look different when scrolled
	x = math.floor(x + 0.5)
	self.scrollTarget = x
	self.tween = TWEEN
	updateArrows()
end

function screen:Turn(direction)
	self:ScrollTo((self.scrollTarget or self.scrollX or 0) + direction * SLOTS * self.step)
end

-- Brings a card into view without moving the row when it already is.
function screen:EnsureVisible(card, centre)
	local step = self.step
	local view = self.view
	local left = (screen.lead or 0) + ((card.slot or card.index) - 1) * step
	local right = left + step
	local at = self.scrollTarget or self.scrollX or 0
	if centre then
		self:ScrollTo(left - (view - step) / 2)
	elseif left < at then
		self:ScrollTo(left)
	elseif right > at + view then
		self:ScrollTo(right - view)
	end
end

-- ------------------------------------------------------------ Focus, select, cancel

function screen:Focus(card)
	if self.focused == card then
		return
	end
	if self.focused then
		self.focused.focused = false
		paint(self.focused)
	end
	card.focused = true
	self.focused = card
	self.currentRealm = card.index or 0
	paint(card)
	updateEnter()
end

-- The C side needs the category and the realm index; GlueDialog reads both off this frame.
function screen:Select()
	local index = self.currentRealm or 0
	if index < 1 then
		return
	end
	local name, numCharacters, invalid, realmDown, _, _, _, load = realmInfo(self.selectedCategory, index)
	if not name or realmDown then
		return
	end
	if IsInvalidLocale(self.selectedCategory) then
		GlueDialog_Show("REALM_LOCALE_WARNING")
		return
	end
	self:Hide()
	if load == 2 and (numCharacters or 0) == 0 then
		GlueDialog_Show("REALM_IS_FULL")
		return
	end
	ChangeRealm(self.selectedCategory, index)
end

function screen:Cancel()
	PlaySound("igMainMenuOptionCheckBoxOff")
	self:Hide()
	RealmListDialogCancelled()
	local name, isPVP, isRP, isDown = GetServerName()
	if not name or isDown or (countRealms(self.selectedCategory or 1) == 0) then
		SetGlueScreen("realmwizard")
	end
end

function screen:SelectCategory(category)
	if category == self.selectedCategory or not realmInfo(category, 1) then
		return
	end
	self.selectedCategory = category
	self.currentRealm = 0
	self.focused = nil
	self.scrollX, self.scrollTarget = 0, 0
	fill()
	buildCategory()
end

-- ------------------------------------------------------------ Refresh

function screen:Refresh()
	fill()
end

screen:SetScript("OnEvent", function(self)
	self.gotList = true
	if self:IsShown() then
		self:Refresh()
	else
		self:Show()
	end
end)
screen:RegisterEvent("OPEN_REALM_LIST")

screen:SetScript("OnShow", function(self)
	self.scrollX, self.scrollTarget = 0, 0
	self:SetScript("OnUpdate", self.OnUpdate)
	self:Refresh()
	buildCategory()
	self.polling = RealmListUpdateRate() or 60
end)

screen:SetScript("OnHide", function(self)
	CancelRealmListQuery()
	self.polling = nil
	self.tween = nil
	self:SetScript("OnUpdate", nil)
	if self.focused then
		self.focused.focused = false
		paint(self.focused)
		self.focused = nil
	end
	updateEnter()
end)

-- The realm list is asked for again on a timer while the screen is up, and the row slides to
-- its target in between.
function screen:OnUpdate(elapsed)
	if self.polling then
		self.polling = self.polling - elapsed
		if self.polling <= 0 then
			self.polling = RealmListUpdateRate() or 60
			RequestRealmList()
		end
	end
	-- cards walk towards their hover size
	for i = 1, #cardsBuilt do
		local card = cardsBuilt[i]
		local target, now = card.zoomTarget, card.zoom
		if target and now and math.abs(target - now) > 0.0005 then
			now = now + (target - now) * math.min(1, elapsed * HOVER_SPEED)
			if math.abs(target - now) <= 0.0005 then
				now = target
			end
			card.zoom = now
			placeCard(card, now)
		end
	end
	if self.tween then
		local to = self.scrollTarget or 0
		self.tween = self.tween - elapsed
		if self.tween <= 0 then
			self.scrollX = to
			self.tween = nil
		else
			self.scrollX = self.scrollX + (to - self.scrollX) * math.min(1, elapsed / TWEEN)
			self.scrollX = math.floor(self.scrollX + 0.5)
		end
		scroll:SetHorizontalScroll(self.scrollX)
		updateArrows()
	end
end

scroll:EnableMouseWheel(true)
scroll:SetScript("OnMouseWheel", function(_, direction)
	screen:Turn(-direction)
end)

screen:SetScript("OnMouseWheel", function(_, direction)
	screen:Turn(-direction)
end)

-- LEFT / RIGHT and UP / DOWN move the focus, ENTER connects, ESCAPE cancels.
function screen:OnKeyDown(key)
	if key == "ESCAPE" then
		self:Cancel()
	elseif key == "PRINTSCREEN" then
		Screenshot()
	elseif key == "ENTER" then
		self:Select()
	elseif key == "LEFT" or key == "UP" or key == "RIGHT" or key == "DOWN" then
		local step = (key == "RIGHT" or key == "DOWN") and 1 or -1
		local total = countRealms(self.selectedCategory)
		local next = (self.currentRealm or 0) + step
		if next < 1 then
			next = 1
		elseif next > total then
			next = total
		end
		local card = cardsBuilt[next]
		if card and card:IsShown() then
			PlaySound("igMainMenuOptionCheckBoxOn")
			self:Focus(card)
			self:EnsureVisible(card)
		end
	end
end

-- The client sends the keys of a glue screen to <screen>_OnKeyDown: with the client's RealmList
-- no longer loaded, explaining ESCAPE here keeps it cancelling instead of falling through.
function RealmList_OnKeyDown(key)
	screen:OnKeyDown(key)
end

G.RealmList = screen
