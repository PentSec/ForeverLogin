-- Login screen: fields, buttons and their layout. The scale is set once on GlueParent.
-- Texts come from the client's strings; MAINMENU is missing from 3.3.5, so it falls back to
-- G.L.ACCOUNTLOGIN_MENU.

local G = ForeverLogin
local L = G.L
local ui = AccountLoginUI
local count = AccountLoginAccountEdit
local password = AccountLoginPasswordEdit
local loginButton = AccountLoginLoginButton
local checkbox = AccountLoginSaveAccountName
-- the saved accounts dropdown and its warning, built by ForeverLoginAccounts.lua (loaded before
-- this file)
local dropdown = G.Accounts.DropDown
local notice = G.Accounts.Notice

-- ------------------------------------------------------------ Footer

local disclaimer
for _, r in ipairs({ ui:GetRegions() }) do
	if r:GetObjectType() == "FontString" and r:GetText() == BLIZZ_DISCLAIMER then
		r:SetFontObject(G.Font("GlueFontNormalSmall"))
		r:ClearAllPoints()
		r:SetPoint("BOTTOM", ui, "BOTTOM", 0, 10)
		disclaimer = r
	end
end
AccountLoginVersion:SetFontObject(G.Font("GlueFontNormalSmall"))
AccountLoginVersion:SetJustifyH("LEFT")
AccountLoginVersion:ClearAllPoints()
AccountLoginVersion:SetPoint("BOTTOMLEFT", ui, "BOTTOMLEFT", 10, 10)

-- ------------------------------------------------------------ Fields

-- Styles a login field. caption: its label; captionWidth: label width
local function field(edit, caption, captionWidth)
	edit:SetBackdrop(nil)
	edit:SetWidth(320)
	edit:SetHeight(50)
	G.TooltipBackground(edit, "TooltipMixedLayout", G.GLUE_BACKDROP_COLOR, G.GLUE_BACKDROP_BORDER_COLOR)
	edit:SetFontObject(G.Font("GlueLoginEditBoxFont"))
	edit:SetTextInsets(12, 5, 0, 5)
	caption:SetFontObject(G.Font("GlueFontNormalLogin"))
	caption:SetJustifyH("CENTER")
	caption:SetWidth(captionWidth)
	caption:SetHeight(64)
	caption:ClearAllPoints()
	caption:SetPoint("BOTTOM", edit, "TOP", 0, -19)
end

local passwordCaption
for _, r in ipairs({ password:GetRegions() }) do
	if r:GetObjectType() == "FontString" and r:GetText() == PASSWORD then
		passwordCaption = r
	end
end
field(count, AccountLoginAccountEditLabel, 600)
field(password, passwordCaption, 256)
-- The 3.3.5 hint in the empty field, shown and hidden by the client itself:
-- made invisible here.
AccountLoginAccountEditFill:SetAlpha(0)

-- ------------------------------------------------------------ Buttons

G.ThreeSliceButton(loginButton, "128-RedButton", { "GlueFontNormalLogin", "GlueFontHighlightLogin", "GlueFontDisableLogin" })
loginButton:SetWidth(250)
loginButton:SetHeight(66)

local quit = AccountLoginExitButton
G.ThreeSliceButton(quit, "128-RedButton", { "GlueFontNormal", "GlueFontHighlight", "GlueFontDisable" })
quit:SetWidth(200)
quit:SetHeight(30)

local create = G.CreateThreeSliceButton("ForeverLoginAccountLoginCreateAccountButton", ui, 200, 30, "128-RedButton",
	{ "GlueFontNormal", "GlueFontHighlight", "GlueFontDisable" }, CREATE_ACCOUNT)
create:SetScript("OnClick", function()
	AccountLoginManageAccountButton:Click()
end)

local menu = G.CreateThreeSliceButton("ForeverLoginAccountLoginMenuButton", ui, 200, 30, "128-RedButton",
	{ "GlueFontNormal", "GlueFontHighlight", "GlueFontDisable" }, L.ACCOUNTLOGIN_MENU)
menu:SetScript("OnClick", function()
	G.ShowMenu()
end)

-- Buttons absent from this screen: their functions go through the menu
local HIDDEN = {
	"AccountLoginTOSButton", "AccountLoginCreditsButton", "AccountLoginCinematicsButton",
	"OptionsButton", "AccountLoginCommunityButton", "AccountLoginManageAccountButton",
	"AccountLoginShowLauncher", "AccountLoginUpgradeAccountButton",
	-- the client's own saved account list, replaced by our dropdown
	"AccountLoginDropDown",
}

-- ------------------------------------------------------------ Check box

local checkboxCaption = AccountLoginSaveAccountNameText
checkboxCaption:SetFontObject(G.Font("GlueFontNormalLogin"))
checkbox:SetWidth(28)
checkbox:SetHeight(28)
local block = CreateFrame("Frame", nil, ui)

local savePassword = AccountLoginSavePassword
local savePasswordCaption = AccountLoginSavePasswordText
-- GAP between the two check box rows; ABOVE from the password field to the block
local GAP, ABOVE = 4, 20

-- ResizeLayoutFrame: check box at TOPLEFT, caption 2 to its right, the password check box
-- (when the client shows it) a row below; the block is as wide and tall as its content. The
-- block hangs from the password field and the login button follows it, so the button drops
-- while the password check box is shown.
local function placeCheckbox()
	local lw, lh = checkboxCaption:GetStringWidth(), checkboxCaption:GetStringHeight()
	local rowH = math.max(28, lh)
	block:SetWidth(28 + 2 + lw)
	block:SetHeight(rowH)
	if savePassword and savePassword:IsShown() then
		local plw, plh = savePasswordCaption:GetStringWidth(), savePasswordCaption:GetStringHeight()
		block:SetWidth(math.max(block:GetWidth(), 28 + 2 + plw))
		block:SetHeight(rowH + GAP + math.max(28, plh))
		savePassword:ClearAllPoints()
		savePassword:SetPoint("TOPLEFT", block, "TOPLEFT", 0, -(rowH + GAP))
		savePasswordCaption:ClearAllPoints()
		savePasswordCaption:SetPoint("LEFT", savePassword, "RIGHT", 2, 0)
	end
	block:ClearAllPoints()
	block:SetPoint("TOP", password, "BOTTOM", 0, -ABOVE)
	loginButton:ClearAllPoints()
	loginButton:SetPoint("TOP", block, "BOTTOM", 0, -2)
	checkbox:ClearAllPoints()
	checkbox:SetPoint("TOPLEFT", block, "TOPLEFT")
	checkboxCaption:ClearAllPoints()
	checkboxCaption:SetPoint("LEFT", checkbox, "RIGHT", 2, 0)
end

if savePassword then
	savePassword:SetWidth(28)
	savePassword:SetHeight(28)
	savePasswordCaption:SetFontObject(G.Font("GlueFontNormalLogin"))
	G.Hook(savePassword, "OnShow", placeCheckbox)
	G.Hook(savePassword, "OnHide", placeCheckbox)
end

-- ------------------------------------------------------------ Layout

local function place()
	count:ClearAllPoints()
	count:SetPoint("CENTER", ui, "CENTER", 0, -15)
	-- The accounts warning (ForeverLoginAccounts.lua) sits at the top of the stack, over the
	-- account label, so showing it grows upwards and moves nothing else. The label box is 64
	-- tall with its text centred, so 32 clears the glyphs.
	notice:ClearAllPoints()
	notice:SetPoint("BOTTOM", count, "TOP", 0, 32)
	password:ClearAllPoints()
	if dropdown:IsShown() then
		dropdown:ClearAllPoints()
		dropdown:SetPoint("TOP", count, "BOTTOM", 0, -6)
		password:SetPoint("TOP", dropdown, "BOTTOM", 0, -32)
	else
		-- nothing saved: the stack closes up as if the dropdown were not there
		password:SetPoint("TOP", count, "BOTTOM", 0, -43)
	end
	placeCheckbox()
	quit:ClearAllPoints()
	quit:SetPoint("BOTTOMRIGHT", ui, "BOTTOMRIGHT", -24, 56)
	create:ClearAllPoints()
	create:SetPoint("BOTTOM", quit, "TOP", 0, 10)
	menu:ClearAllPoints()
	menu:SetPoint("BOTTOM", create, "TOP", 0, 10)
	for _, name in ipairs(HIDDEN) do
		local f = _G[name]
		if f then f:Hide() end
	end
	-- The launcher check box caption is a region of the screen frame
	for _, r in ipairs({ ui:GetRegions() }) do
		if r:GetObjectType() == "FontString" and r:GetText() == SHOW_LAUNCHER then
			r:Hide()
		end
	end
end
place()

-- Fade in over 0.75 s (AccountLoginUI FadeIn)
local fade = CreateFrame("Frame", nil, ui)
fade:Hide()
fade:SetScript("OnUpdate", function(self, elapsed)
	self.t = self.t + (elapsed or 0)
	local k = math.min(1, self.t / 0.75)
	ui:SetAlpha(k)
	if k >= 1 then self:Hide() end
end)

-- On each show, after the client: AccountLogin_SetupAccountListDDL adds its own anchors to
-- the password field and the button, and the client shows some of its buttons again
G.Hook(AccountLogin, "OnShow", function()
	place()
end)

-- On each show, after the client: its own fade (GlueFrameFadeIn with LOGIN_FADE_IN,
-- 1.5 s, in AccountLoginUI's OnShow) would fight ours over the alpha, so the frame is
-- removed from the client's fade list and only our fade remains.
G.Hook(ui, "OnShow", function()
	GlueFrameFadeRemoveFrame(ui)
	fade.t = 0
	ui:SetAlpha(0)
	fade:Show()
end)
-- The client keeps its own fade-out (to character select); ours stops if still running
G.HookFunction("GlueFrameFadeOut", function(frame)
	if frame == ui then
		fade:Hide()
	end
end)

-- Escape keeps its 3.3.5 meaning (AccountLogin_OnKeyDown: quit the game) instead of
-- opening the menu (TOGGLEGAMEMENU); the keyboard handling stays with the client.

-- ------------------------------------------------------------ Short screens

-- Blocks kept apart on a short screen (G.FitOnShow, after the OnShow above)
G.FitOnShow(AccountLogin, function()
	return { { count, dropdown, password, block, G.Accounts.Notice, loginButton, menu, create, quit, AccountLoginVersion, disclaimer } }
end)
