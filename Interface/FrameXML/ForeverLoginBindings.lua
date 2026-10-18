-- The key bindings window (KeyBindingFrame, which the client loads on demand with
-- Blizzard_BindingUI) in our style. The client keeps its rows, its buttons and its logic: the
-- window, the inner frame and the silver binding buttons are drawn over them.

local G = ForeverLogin

local N = {
	grow = 30, shift = 24,
	window = { g = 4, h = -4, d = -44, b = 12 },   -- the visible part of the 3.3.5 art
	command = { 26, -35 }, list = { 27, -53 }, scroll = { 2, -53 },
	checkboxXY = { -245, -12 },
	inner = { g = 15, h = -49, d = -50, b = 3 },   -- b: below the last row
	rows = 17, rowH = 25, rowStep = 23,
	button = { 130, 22 }, edge = 16, gap = 2,
	selectionH = 20, selectionY = -3,
}

local B = {}
G.Bindings = B

-- The mark of the chosen binding button, from KeyBindingFrame.selected and keyID.
function B.Paint()
	local f = KeyBindingFrame
	if not f then
		return
	end
	for i = 1, N.rows do
		for k = 1, 2 do
			local b = _G["KeyBindingFrameBinding" .. i .. "Key" .. k .. "Button"]
			if b and b.foreverChoice then
				local selected = f.selected ~= nil and b.commandName == f.selected and f.keyID == b:GetID()
				G.SetShown(b.foreverChoice, selected)
			end
		end
	end
end

-- one of our buttons with its hidden selection mark
local KEY_FONTS = { "GameFontHighlightSmall", "GameFontHighlightSmall", "GameFontDisableSmall" }

local function skinButton(b)
	G.ThreeSliceButton(b, "128-redbutton", KEY_FONTS)
	local t = b:CreateTexture(nil, "OVERLAY")
	G.PlaceAtlas(t, "ui-silver-button-select")
	t:SetBlendMode("ADD")
	t:SetWidth(b:GetWidth())
	t:SetHeight(N.selectionH)
	t:SetPoint("CENTER", b, "CENTER", 0, N.selectionY)
	t:Hide()
	b.foreverChoice = t
end

function B.Skin()
	local f = KeyBindingFrame
	if not f or f.foreverSkin then
		return
	end
	-- the visible part, plus room for the per character checkbox that 3.3.5 keeps in the title
	f:SetHeight(f:GetHeight() + N.grow)
	local win = CreateFrame("Frame", nil, f)
	win:SetFrameLevel(f:GetFrameLevel())
	win:SetPoint("TOPLEFT", f, "TOPLEFT", N.window.g, N.window.h)
	win:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", N.window.d, N.window.b)
	-- the 3.3.5 art goes to alpha 0: it stays, so its scripts keep working
	for _, r in ipairs({ f:GetRegions() }) do
		if r:GetObjectType() == "Texture" then
			r:SetAlpha(0)
		end
	end
	local skin = G.Window(win, KeyBindingFrameHeaderText:GetText())
	skin.stripes:Hide()
	-- the window moves by its title bar
	G.Movable(f, skin.container)
	f.foreverSkin = skin
	KeyBindingFrameHeaderText:SetAlpha(0)
	-- close acts as Cancel, which is what Escape does
	local closeButton = CreateFrame("Button", "ForeverLoginBindingsClose", f)
	closeButton:SetFrameLevel(f:GetFrameLevel() + 20)
	G.WindowCloseButton(closeButton, win)
	closeButton:SetScript("OnClick", function()
		KeyBindingFrameCancelButton:Click()
	end)
	f.foreverCloseButton = closeButton

	-- the content moves down to leave room for our title bar
	local d = N.shift
	KeyBindingFrameCommandLabel:ClearAllPoints()
	KeyBindingFrameCommandLabel:SetPoint("TOPLEFT", f, "TOPLEFT", N.command[1], N.command[2] - d)
	KeyBindingFrameBinding1:ClearAllPoints()
	KeyBindingFrameBinding1:SetPoint("TOPLEFT", f, "TOPLEFT", N.list[1], N.list[2] - d)
	KeyBindingFrameScrollFrame:ClearAllPoints()
	KeyBindingFrameScrollFrame:SetPoint("TOPLEFT", f, "TOPLEFT", N.scroll[1], N.scroll[2] - d)
	KeyBindingFrameCharacterButton:ClearAllPoints()
	KeyBindingFrameCharacterButton:SetPoint("TOPLEFT", f, "TOPRIGHT", N.checkboxXY[1], N.checkboxXY[2] - d)

	-- the inner frame around the rows
	local I = N.inner
	local listBottom = N.list[2] - d - (N.rows - 1) * N.rowStep - N.rowH
	local rect = CreateFrame("Frame", nil, win)
	rect:SetPoint("TOPLEFT", f, "TOPLEFT", I.g, I.h - d)
	rect:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", I.d, listBottom - I.b)
	win.foreverRect = rect
	skin.inner = G.Inset(win, rect)

	-- the client's texts are covered by our frame, so they are mirrored above it
	skin.texts = {}
	for _, fs in ipairs({ KeyBindingFrameCommandLabel, KeyBindingFrameKey1Label,
			KeyBindingFrameKey2Label, KeyBindingFrameOutputText }) do
		skin.texts[#skin.texts + 1] = G.Mirror(fs, skin.container, "GameFontNormal")
	end

	for i = 1, N.rows do
		for k = 1, 2 do
			local b = _G["KeyBindingFrameBinding" .. i .. "Key" .. k .. "Button"]
			if b then
				skinButton(b)
			end
		end
	end

	G.Bar(KeyBindingFrameScrollFrameScrollBar)
	G.Checkbox(KeyBindingFrameCharacterButton)

	-- the buttons along the bottom, and Default on the other side
	local previous
	for _, b in ipairs({ KeyBindingFrameCancelButton, KeyBindingFrameOkayButton, KeyBindingFrameUnbindButton }) do
		b:SetWidth(N.button[1])
		b:SetHeight(N.button[2])
		G.ThreeSliceButton(b, "128-redbutton", { "GameFontNormal", "GameFontHighlight", "GameFontDisable" })
		b:ClearAllPoints()
		if previous then
			b:SetPoint("RIGHT", previous, "LEFT", -N.gap, 0)
		else
			b:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -N.edge, N.edge)
		end
		previous = b
	end
	local default = KeyBindingFrameDefaultButton
	default:SetWidth(N.button[1])
	default:SetHeight(N.button[2])
	G.ThreeSliceButton(default, "128-redbutton", { "GameFontNormal", "GameFontHighlight", "GameFontDisable" })
	default:ClearAllPoints()
	default:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", N.edge, N.edge)

	hooksecurefunc("KeyBindingFrame_Update", B.Paint)
	hooksecurefunc("KeyBindingFrame_SetSelected", B.Paint)
	B.Paint()
end

-- the window is load on demand: skin it when the client loads it, or now if it is already there
if KeyBindingFrame then
	B.Skin()
end
local watcher = CreateFrame("Frame")
watcher:RegisterEvent("ADDON_LOADED")
watcher:SetScript("OnEvent", function(self, _, name)
	if name == "Blizzard_BindingUI" then
		B.Skin()
		self:UnregisterEvent("ADDON_LOADED")
	end
end)
B.watcher = watcher
