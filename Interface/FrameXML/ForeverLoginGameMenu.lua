-- The Esc menu (GameMenuFrame) in our style. The client's buttons stay, in their order: their
-- clicks are secure (Log Out, Quit) and a button of ours would not be. A button another addon
-- adds to the frame is skinned by the layout when it first shows.

local G = ForeverLogin

local N = {
	top = 48, down = 34, side = 28, section = 20,
	button = { 200, 36 },
}

local FONTS = { "GameFontHighlightLarge", "GameFontHighlightLarge", "GameFontDisableLarge" }

local M = {}
G.GameMenu = M

-- The client's own buttons, top to bottom; section: a gap above the button; foreign: the addon
-- buttons go in just before this one.
local ORDER = {
	"GameMenuButtonOptions",
	"GameMenuButtonSoundOptions",
	"GameMenuButtonMacOptions",
	"GameMenuButtonUIOptions",
	"GameMenuButtonKeybindings",
	"GameMenuButtonMacros",
	"GameMenuButtonRatings",
	"GameMenuButtonAddOns",
	{ "GameMenuButtonHelp", section = true },
	{ "GameMenuButtonLogout", section = true, foreign = true },
	"GameMenuButtonQuit",
	{ "GameMenuButtonContinue", section = true },
}

-- The buttons another addon put in the menu: Buttons of the frame that are not the client's. The
-- client does not lay them out itself, so they arrive at whatever size the addon chose. Matched
-- by name, because an addon may also replace one of the client's buttons with one of its own.
local function foreignButtons(f, known)
	local list = {}
	for _, c in ipairs({ f:GetChildren() }) do
		if c:GetObjectType() == "Button" and not known[c:GetName()] then
			list[#list + 1] = c
		end
	end
	return list
end

local function skinButton(b)
	if b.foreverThreeSlice then
		return
	end
	b:SetWidth(N.button[1])
	b:SetHeight(N.button[2])
	G.ThreeSliceButton(b, "128-redbutton", FONTS)
	b:HookScript("OnShow", M.Layout)
end

-- Lays out the column: every shown button in place and at our size, the addon buttons with the
-- options, then the size of the menu. Runs on every button's OnShow, because another addon may
-- re-anchor a button after us.
function M.Layout()
	local f = GameMenuFrame
	local known = {}
	local order = {}
	for _, e in ipairs(ORDER) do
		local name = type(e) == "table" and e[1] or e
		known[name] = true
		order[#order + 1] = {
			button = _G[name],
			section = type(e) == "table" and e.section or nil,
			foreign = type(e) == "table" and e.foreign or nil,
		}
	end
	local foreign = foreignButtons(f, known)
	local y = N.top
	local function place(b, section)
		if not (b and b:IsShown()) then
			return
		end
		skinButton(b)
		if section then
			y = y + N.section
		end
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", f, "TOPLEFT", N.side, -y)
		y = y + N.button[2]
	end
	for _, e in ipairs(order) do
		if e.foreign then
			for _, b in ipairs(foreign) do
				place(b)
			end
		end
		place(e.button, e.section)
	end
	f:SetWidth(N.side + N.button[1] + N.side)
	f:SetHeight(y + N.down)
	-- what the column looks like now, so the watcher does not lay it out again for our own work
	f.foreverSig = M.Signature(f)
end

-- While the menu is open a button can appear (another addon adding one), change size or be
-- re-anchored somewhere else: the column is laid out again when the set does. A sum of the
-- buttons' size, shown state and vertical offset is enough to notice, and nothing happens when
-- it does not change.
function M.Signature(f)
	local sig = 0
	for _, c in ipairs({ f:GetChildren() }) do
		if c:GetObjectType() == "Button" then
			sig = sig + (c:GetWidth() or 0) * 10000 + (c:GetHeight() or 0) * 100
				+ (c:IsShown() and 1 or 0) + (c:GetTop() or 0) * 10 + 1
		end
	end
	return sig
end

-- The client fires the buttons' OnShow after the frame's, so a button that another addon
-- re-anchors in its own OnShow lands out of place and our layout on show has already run: the
-- column is put back on the next frame. That is why this is not throttled.
function M.Watch(self, elapsed)
	if M.Signature(self) ~= self.foreverSig then
		M.Layout()
	end
end

if GameMenuFrame then
	local f = GameMenuFrame
	f:SetBackdrop(nil)
	-- the client's own header and title are hidden: ours say the same
	if GameMenuFrameHeader then
		GameMenuFrameHeader:SetAlpha(0)
	end
	for _, r in ipairs({ f:GetRegions() }) do
		if r:GetObjectType() == "FontString" and r:GetText() == MAIN_MENU then
			r:SetAlpha(0)
		end
	end
	G.DialogFrame(f)
	M.header = G.Header(f, MAINMENU_BUTTON, "GameFontNormalLarge")
	f:HookScript("OnShow", M.Layout)
	-- a button another addon adds while the menu is open is caught by the watcher, and one that
	-- is added while it is closed by the layout on show
	f:HookScript("OnUpdate", M.Watch)
	M.Layout()
end
