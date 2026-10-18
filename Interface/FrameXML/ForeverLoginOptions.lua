-- The client's own options windows (video, sound and interface) in our style. The client keeps
-- its screens, its panels, its CVars and its buttons: our window, title bar, close button,
-- category lists, tabs and controls are drawn over them and none of its logic is replaced. The
-- panels of other addons (the AddOns tab) keep their controls.

local G = ForeverLogin

local N = {
	button = { 96, 22 }, edge = 16, gap = 2,
	watcher = 0.1, disabledHandle = 0.7,
	tabGap = 5,
}

local O = {}
G.Options = O

-- ------------------------------------------------------------ Panels

-- One panel: each control by its type. A group box holds others, so those are walked through.
local function skinPanel(panel)
	for _, c in ipairs({ panel:GetChildren() }) do
		local kind = c:GetObjectType()
		local name = c:GetName()
		-- the client's dropdowns carry their own Left / Middle / Button children
		local button = name and _G[name .. "Button"]
		if kind == "CheckButton" then
			G.Checkbox(c)
		elseif kind == "Slider" then
			G.Slider(c)
		elseif button and button.GetParent and button:GetParent() == c and _G[name .. "Middle"] and _G[name .. "Left"] then
			G.DropDown(c, 2)
		else
			G.Box(c)
			if kind == "Frame" then
				skinPanel(c)
			end
		end
	end
end

-- The client's own panels, by name: a panel of another addon keeps its controls.
local CLIENT = { "VideoOptions", "AudioOptions", "InterfaceOptions" }

local function clientPanel(c)
	local name = c:GetName()
	if not name or not string.find(name, "Panel$") then
		return false
	end
	for _, prefix in ipairs(CLIENT) do
		if string.sub(name, 1, #prefix) == prefix then
			return true
		end
	end
	return false
end

-- ------------------------------------------------------------ Windows

-- One of the client's options windows. rightButtons: bottom right, rightmost first; default:
-- the Defaults button; lists: its category lists (one, or the two of the interface window).
function O.Window(f, rightButtons, default, lists)
	local name = f:GetName()
	local header = _G[name .. "Header"]
	local title = _G[name .. "HeaderText"]
	f:SetBackdrop(nil)
	if header then
		header:SetAlpha(0)
	end
	if title then
		title:SetAlpha(0)
	end
	-- at the window's own level, so its children (the lists, the panels, the buttons) stay in
	-- front of what we draw
	local win = CreateFrame("Frame", nil, f)
	win:SetFrameLevel(f:GetFrameLevel())
	win:SetAllPoints(f)
	local skin = G.Window(win, title and title:GetText())
	skin.stripes:Hide()
	-- the window moves by its title bar
	G.Movable(f, skin.container)
	f.foreverSkin = skin
	-- The close button hides the window (HideUIPanel) instead of running the client's cancel
	-- code, which would taint the CVars and the UI variables it rewrites: a change that is not
	-- confirmed is not applied, and the client reads it again on the next open.
	local closeButton = CreateFrame("Button", name .. "ForeverLoginCloseButton", f)
	closeButton:SetFrameLevel(f:GetFrameLevel() + 20)
	G.WindowCloseButton(closeButton, win)
	closeButton:SetScript("OnClick", function()
		HideUIPanel(f)
	end)
	f.foreverCloseButton = closeButton
	-- the panel container keeps no border of its own: the inner frame frames it, and it is also
	-- what the tabs of the interface window hang from (as the reference mod does)
	if _G[name .. "PanelContainer"] and _G[name .. "PanelContainer"].SetBackdrop then
		_G[name .. "PanelContainer"]:SetBackdrop(nil)
	end
	f.foreverInner = G.Interior(win, f, lists[1])
	for _, list in ipairs(lists) do
		G.CategoryList(list)
	end
	-- The client redraws its list on show through a reference it took at load time, which a hook
	-- on the global function does not see: repaint after the window opens.
	G.Hook(f, "OnShow", function()
		for _, list in ipairs(lists) do
			G.PaintCategoryList(list)
		end
	end)
	-- buttons: UIPanelButtonTemplate 96 x 22
	local previous
	for _, b in ipairs(rightButtons) do
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
	default:SetWidth(N.button[1])
	default:SetHeight(N.button[2])
	G.ThreeSliceButton(default, "128-redbutton", { "GameFontNormal", "GameFontHighlight", "GameFontDisable" })
	default:ClearAllPoints()
	default:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", N.edge, N.edge)
	return skin
end

-- ------------------------------------------------------------ Setup

if VideoOptionsFrame then
	O.Window(VideoOptionsFrame, { VideoOptionsFrameApply, VideoOptionsFrameCancel, VideoOptionsFrameOkay },
		VideoOptionsFrameDefaults, { VideoOptionsFrameCategoryFrame })
end
if AudioOptionsFrame then
	O.Window(AudioOptionsFrame, { AudioOptionsFrameCancel, AudioOptionsFrameOkay },
		AudioOptionsFrameDefaults, { AudioOptionsFrameCategoryFrame })
end
if InterfaceOptionsFrame then
	local f = InterfaceOptionsFrame
	-- The interface window in the reference mod's layout: in 3.3.5 the lists start at -40,
	-- leaving 19 px under the title bar for 24 px tabs. As in the mod: lists at -76, tabs (37
	-- high) on top of the inner frame (-64), 15 from the window's left edge, and the window
	-- grows by 36 to keep the list height and the gap to the bottom buttons.
	f:SetHeight(f:GetHeight() + 36)
	for _, l in ipairs({ InterfaceOptionsFrameCategories, InterfaceOptionsFrameAddOns }) do
		local x = select(4, l:GetPoint(1))
		l:ClearAllPoints()
		l:SetPoint("TOPLEFT", f, "TOPLEFT", x or 22, -76)
	end
	O.Window(f, { InterfaceOptionsFrameCancel, InterfaceOptionsFrameOkay },
		InterfaceOptionsFrameDefaults, { InterfaceOptionsFrameCategories, InterfaceOptionsFrameAddOns })
	-- the client's shelf under the tabs goes with the client's tabs
	for _, s in ipairs({ "Tab1TabSpacer", "Tab2TabSpacer1", "Tab2TabSpacer2" }) do
		local t = _G["InterfaceOptionsFrame" .. s]
		if t then
			t:SetAlpha(0)
		end
	end
	G.Tab(InterfaceOptionsFrameTab1)
	G.Tab(InterfaceOptionsFrameTab2)
	-- the tabs sit on the top left of the inner frame, not on the list: that is what keeps them
	-- clear of the border the list used to draw there
	InterfaceOptionsFrameTab1:ClearAllPoints()
	InterfaceOptionsFrameTab1:SetPoint("BOTTOMLEFT", f.foreverInner, "TOPLEFT", 15, 0)
	InterfaceOptionsFrameTab2:ClearAllPoints()
	InterfaceOptionsFrameTab2:SetPoint("TOPLEFT", InterfaceOptionsFrameTab1, "TOPRIGHT", N.tabGap, 0)
end

for _, window in ipairs({ VideoOptionsFrame, AudioOptionsFrame, InterfaceOptionsFrame }) do
	local container = window and _G[window:GetName() .. "PanelContainer"]
	if container then
		for _, p in ipairs({ container:GetChildren() }) do
			if clientPanel(p) then
				skinPanel(p)
			end
		end
	end
end

-- The client disables its sliders from a function it keeps on each one, so their state is
-- polled while the windows are open (a disabled thumb at 0.7, as the client's own sliders).
local watcher = CreateFrame("Frame")
watcher.t = 0
watcher:SetScript("OnUpdate", function(self, elapsed)
	self.t = self.t + (elapsed or 0)
	if self.t < N.watcher then
		return
	end
	self.t = 0
	local a, b, c = VideoOptionsFrame, AudioOptionsFrame, InterfaceOptionsFrame
	if not ((a and a:IsShown()) or (b and b:IsShown()) or (c and c:IsShown())) then
		return
	end
	for _, s in ipairs(G.sliders) do
		local thumb = s.GetThumbTexture and s:GetThumbTexture()
		if thumb then
			local active = not s.IsEnabled or G.Truthy(s:IsEnabled())
			thumb:SetAlpha(active and 1 or N.disabledHandle)
		end
	end
end)
O.watcher = watcher
