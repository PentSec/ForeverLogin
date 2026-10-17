-- Login options: the Options menu and the Video and Sound windows. The client keeps its
-- screens, panels, CVars and buttons; this file only lays art and fonts over them after the
-- client (dialog border, settings frame, settings checkbox, minimal slider, style 2 dropdowns).

local G = ForeverLogin

-- 3.3.5 returns 1 / nil, sometimes 0 / 1: zero is true in Lua
local function truthy(v)
	return v and v ~= 0 and true or false
end

-- Font object matching a client font by name, or nil
local function fontObject(object)
	local name = object and object.GetName and object:GetName()
	if not name or string.find(name, "^ForeverLogin_") then
		return nil
	end
	return _G["ForeverLogin_" .. name]
end

local function swapFont(fs)
	local p = fontObject(fs:GetFontObject())
	if p then
		fs:SetFontObject(p)
	end
end

-- All fonts of a frame: its FontStrings and its button fonts
local function swapFonts(frame)
	for _, r in ipairs({ frame:GetRegions() }) do
		if r:GetObjectType() == "FontString" then
			swapFont(r)
		end
	end
	if frame.GetNormalFontObject then
		for _, v in ipairs({ { "GetNormalFontObject", "SetNormalFontObject" },
				{ "GetHighlightFontObject", "SetHighlightFontObject" },
				{ "GetDisabledFontObject", "SetDisabledFontObject" } }) do
			local p = fontObject(frame[v[1]](frame))
			if p then
				frame[v[2]](frame, p)
			end
		end
	end
end

-- ------------------------------------------------------------ Tooltip

-- OptionsTooltip as the login screen tooltip (GlueTooltip: TooltipDefaultLayout, background
-- 0.09); lines GlueFontNormal then GlueFontNormalSmall
OptionsTooltip:SetBackdrop(nil)
G.TooltipBackground(OptionsTooltip, "TooltipDefaultLayout", G.GLUE_BACKDROP_COLOR)
OptionsTooltipText1:SetFontObject(G.Font("GlueFontNormal"))
OptionsTooltipText2:SetFontObject(G.Font("GlueFontNormalSmall"))

-- ------------------------------------------------------------ Controls

-- Sets a button state texture to an atlas element stretched over the button.
-- set / get: texture setter and getter names; name: atlas element; mode: blend mode or nil
local function applyState(b, set, get, name, mode)
	b[set](b, G.atlas[string.lower(name)][1])
	local t = b[get](b)
	G.PlaceAtlas(t, name)
	t:ClearAllPoints()
	t:SetAllPoints(b)
	if mode then
		t:SetBlendMode(mode)
	end
	return t
end

-- SettingsCheckboxTemplate at the client's checkbox size (26), no hover glow
local function skinCell(c)
	applyState(c, "SetNormalTexture", "GetNormalTexture", "checkbox-minimal")
	applyState(c, "SetPushedTexture", "GetPushedTexture", "checkbox-minimal")
	local glow = c:GetHighlightTexture()
	if glow then
		glow:SetTexture(nil)
		glow:SetAlpha(0)
	end
	applyState(c, "SetCheckedTexture", "GetCheckedTexture", "checkmark-minimal")
	applyState(c, "SetDisabledCheckedTexture", "GetDisabledCheckedTexture", "checkmark-minimal-disabled")
	swapFonts(c)
end

-- Box border in the client's grey (0.4), no background.
local function skinBox(f)
	f:SetBackdrop(nil)
	local p = G.NineSlice(f, "TooltipDefaultLayout")
	G.NineSliceColors(p, nil, { 0.4, 0.4, 0.4 })
	p.Center:Hide()
	swapFonts(f)
end

-- MinimalSliderTemplate over the client's slider, at the client's height (17). The thumb is
-- 16 x 15 instead of 20 x 19, with art refined x4 (minimalsliderbarc60-hd). No stepper
-- arrows: the client has none.
local sliders = {}
local function skinSlider(s)
	s:SetBackdrop(nil)
	local g = s:CreateTexture(nil, "ARTWORK")
	G.PlaceAtlas(g, "minimal_sliderbar_left", true)
	g:SetPoint("LEFT", s, "LEFT")
	local d = s:CreateTexture(nil, "ARTWORK")
	G.PlaceAtlas(d, "minimal_sliderbar_right", true)
	d:SetPoint("RIGHT", s, "RIGHT")
	local m = s:CreateTexture(nil, "ARTWORK")
	G.PlaceAtlas(m, "_minimal_sliderbar_middle", true)
	m:SetPoint("TOPLEFT", g, "TOPRIGHT")
	m:SetPoint("TOPRIGHT", d, "TOPLEFT")
	local button = G.StateTexture(s, "SetThumbTexture", "GetThumbTexture")
	G.PlaceAtlas(button, "minimal_sliderbar_button")
	button:SetWidth(16)
	button:SetHeight(15)
	swapFonts(s)
	sliders[#sliders + 1] = s
end

-- Thumb at 0.7 when the slider is disabled (MinimalSliderWithSteppers:ConfigureSlider).
-- The client disables its sliders through a function it keeps on each one, so their state
-- is polled while the windows are open.
local watcher = CreateFrame("Frame", nil, GlueParent)
watcher.t = 0
watcher:SetScript("OnUpdate", function(self, elapsed)
	self.t = self.t + (elapsed or 0)
	if self.t < 0.1 then
		return
	end
	self.t = 0
	if not (VideoOptionsFrame:IsShown() or AudioOptionsFrame:IsShown()) then
		return
	end
	for _, s in ipairs(sliders) do
		local active = not s.IsEnabled or truthy(s:IsEnabled())
		s:GetThumbTexture():SetAlpha(active and 1 or 0.7)
	end
end)

-- A whole panel: its texts, then each control by its template
local function skinPanel(panel)
	swapFonts(panel)
	for _, c in ipairs({ panel:GetChildren() }) do
		local name = c:GetName()
		local kind = c:GetObjectType()
		if kind == "CheckButton" then
			skinCell(c)
		elseif kind == "Slider" then
			skinSlider(c)
		elseif name and _G[name .. "Button"] and _G[name .. "Middle"] then
			G.SkinDropDown(c, 2)
			swapFonts(c)
		elseif (name and _G[name .. "Title"]) or (c.GetBackdrop and c:GetBackdrop()) then
			skinBox(c)
		else
			swapFonts(c)
		end
	end
end

-- ------------------------------------------------------------ Options menu
-- Red buttons (128-RedButton) over the visible part of the 3.3.5 buttons: the
-- Glue-Panel-Button-* art is opaque from 8 to 140 of 148 and from 6 to 40 of 48.

local FONTS = { "GlueFontNormal", "GlueFontHighlight", "GlueFontDisable" }

local background = OptionsSelectFrameBackground
background:SetBackdrop(nil)
G.DialogFrame(background)
OptionsSelectFrameBackgroundHeader:SetAlpha(0)
OptionsSelectFrameBackgroundHeaderText:SetAlpha(0)
G.DialogHeader(background, OPTIONS, "GlueFontNormal")
local video = OptionsSelectFrameBackgroundContainerVideoOptionsButton
local audio = OptionsSelectFrameBackgroundContainerAudioOptionsButton
local reset = OptionsSelectResetSettingsButton
local close = OptionsSelectFrameBackgroundOkayButton
for _, b in ipairs({ video, audio }) do
	b:SetWidth(196)
	b:SetHeight(32)
	G.ThreeSliceButton(b, "128-RedButton", FONTS)
end
for _, b in ipairs({ reset, close }) do
	b:SetHeight(27)
	G.ThreeSliceButton(b, "128-RedButton", { "GlueFontNormalSmall", "GlueFontHighlightSmall", "GlueFontDisableSmall" })
end
reset:SetWidth(196)
close:SetWidth(112)
video:ClearAllPoints()
video:SetPoint("TOP", OptionsSelectFrameBackgroundContainer, "TOP", 0, -16)
audio:ClearAllPoints()
audio:SetPoint("TOP", video, "BOTTOM", 0, -3)
reset:ClearAllPoints()
reset:SetPoint("BOTTOMLEFT", background, "BOTTOMLEFT", 20, 12)
close:ClearAllPoints()
close:SetPoint("BOTTOMRIGHT", background, "BOTTOMRIGHT", -15, 12)

-- ------------------------------------------------------------ Categories
-- No list frame: one would not fit inside Options_InnerFrame (886 x 618).

-- Repaints a category button, run after the client (OptionsCategoryFrame_Update and
-- OptionsListButton_OnClick reset its fonts and selection).
local function paintCategories(list)
	for _, b in ipairs(list.buttons) do
		local el = b.element
		local selected = el ~= nil and list.selection == el
		G.SetShown(b.foreverActive, selected)
		G.SetShown(b.foreverHover, not selected and b.foreverHovered)
		local font
		if selected or (el and el.parent) then
			font = G.Font("GameFontHighlight")
		else
			font = G.Font("GameFontNormal")
		end
		b:SetNormalFontObject(font)
		b:SetHighlightFontObject(font)
	end
end

local function skinCategories(list)
	list.foreverCategories = true
	local name = list:GetName()
	for _, suffix in ipairs({ "TopLeft", "TopRight", "BottomLeft", "BottomRight", "Left", "Right", "Top", "Bottom" }) do
		local t = _G[name .. suffix]
		if t then
			t:SetAlpha(0)
		end
	end
	for _, b in ipairs(list.buttons) do
		local glow = b:GetHighlightTexture()
		if glow then
			glow:SetTexture(nil)
			glow:SetAlpha(0)
		end
		b.foreverActive = b:CreateTexture(nil, "BACKGROUND")
		G.PlaceAtlas(b.foreverActive, "options_list_active", true)
		b.foreverActive:SetPoint("CENTER", b, "CENTER")
		b.foreverActive:Hide()
		b.foreverHover = b:CreateTexture(nil, "BACKGROUND")
		G.PlaceAtlas(b.foreverHover, "options_list_hover", true)
		b.foreverHover:SetPoint("CENTER", b, "CENTER")
		b.foreverHover:Hide()
		G.Hook(b, "OnEnter", function(self)
			self.foreverHovered = true
			paintCategories(list)
		end)
		G.Hook(b, "OnLeave", function(self)
			self.foreverHovered = false
			paintCategories(list)
		end)
	end
	paintCategories(list)
end

G.HookFunction("OptionsCategoryFrame_Update", function(list)
	if list and list.foreverCategories then
		paintCategories(list)
	end
end)
G.HookFunction("OptionsListButton_OnClick", function(b)
	local list = b and b:GetParent()
	if list and list.foreverCategories then
		paintCategories(list)
	end
end)

-- ------------------------------------------------------------ Windows

-- Settings frame over a client options window.
-- rightButtons: bottom-right buttons, rightmost first; default: the Defaults button
local function skinWindow(f, rightButtons, default)
	local name = f:GetName()
	f:SetBackdrop(nil)
	_G[name .. "Header"]:SetAlpha(0)
	local title = _G[name .. "HeaderText"]
	title:SetAlpha(0)
	-- The new window shares the client window's level, so its children (list, panels,
	-- buttons) stay in front
	local win = CreateFrame("Frame", nil, f)
	win:SetFrameLevel(f:GetFrameLevel())
	win:SetAllPoints(f)
	local skin = G.Window(win, title:GetText(), true)
	skin.stripes:Hide()
	-- The close button does what Cancel does
	local closeButton = CreateFrame("Button", name .. "ForeverLoginCloseButton", f)
	closeButton:SetFrameLevel(f:GetFrameLevel() + 20)
	G.WindowCloseButton(closeButton, f)
	closeButton:SetScript("OnClick", function()
		rightButtons[#rightButtons == 3 and 2 or 1]:Click()
	end)
	-- The panel frame becomes an inset; category list
	local container = _G[name .. "PanelContainer"]
	container:SetBackdrop(nil)
	G.Inset(win, container, true)
	local categories = _G[name .. "CategoryFrame"]
	skinCategories(categories)
	-- OptionsFrame_OnShow redraws the list through categoryFrame:update(), a reference taken at
	-- load time, so a hook on the global function misses it; repaint after the window opens
	G.Hook(f, "OnShow", function()
		paintCategories(categories)
	end)
	-- Buttons: UIPanelButtonTemplate 96 x 22, as SettingsPanel's Close and Apply
	local previous
	for _, b in ipairs(rightButtons) do
		b:SetWidth(96)
		b:SetHeight(22)
		G.PanelButton(b)
		b:ClearAllPoints()
		if previous then
			b:SetPoint("RIGHT", previous, "LEFT", -2, 0)
		else
			b:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 16)
		end
		previous = b
	end
	default:SetWidth(96)
	default:SetHeight(22)
	G.PanelButton(default)
	default:ClearAllPoints()
	default:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16, 16)
	return skin
end

skinWindow(VideoOptionsFrame, { VideoOptionsFrameApply, VideoOptionsFrameCancel, VideoOptionsFrameOkay },
	VideoOptionsFrameDefault)
skinWindow(AudioOptionsFrame, { AudioOptionsFrameCancel, AudioOptionsFrameOkay }, AudioOptionsFrameDefault)

for _, p in ipairs({ VideoOptionsResolutionPanel, VideoOptionsEffectsPanel, VideoOptionsStereoPanel,
		AudioOptionsSoundPanel }) do
	skinPanel(p)
end
