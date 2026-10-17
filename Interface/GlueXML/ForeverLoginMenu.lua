-- The glue screens' main menu. Each button clicks the 3.3.5 client button that
-- does the same thing. A black veil at 0.5 (GlueParent_AddModalFrame) blocks
-- the screen behind; Escape closes the menu.

local G = ForeverLogin
local L = G.L

-- MAINMENU_BUTTON does not exist in 3.3.5: the title comes from G.L (ForeverLoginTexts)
local TITLE = L.GLUEMENU_TITLE

local veil = CreateFrame("Frame", "ForeverLoginMenuVeil", GlueParent)
veil:SetAllPoints(GlueParent)
veil:SetFrameStrata("HIGH")
veil:EnableMouse(true)
veil:EnableKeyboard(true)
veil:Hide()
local black = veil:CreateTexture(nil, "BACKGROUND")
black:SetAllPoints(veil)
black:SetTexture(0, 0, 0, 0.5)

local menu = CreateFrame("Frame", "ForeverLoginMenuFrame", GlueParent)
menu:SetFrameStrata("DIALOG")
menu:SetToplevel(true)
menu:EnableMouse(true)
menu:SetPoint("CENTER", GlueParent, "CENTER")
menu:SetWidth(260)
menu:SetHeight(1)
menu:Hide()
G.DialogFrame(menu)
G.DialogHeader(menu, TITLE, "GlueFontNormal")

-- Menu margins and button size; a section adds a 20 gap above its button
local TOP_MARGIN, BOTTOM_MARGIN, SIDE_MARGIN = 48, 34, 28
local BUTTON_W, BUTTON_H, SECTION = 200, 36, 20

local buttons = {}
local entries = {}

local function close()
	PlaySound("igMainMenuContinue")
	menu:Hide()
end

-- Places one button per entry (buttons are reused), then sizes the menu to fit
local function paginate()
	local y = TOP_MARGIN
	for i, entry in ipairs(entries) do
		local b = buttons[i]
		if not b then
			b = G.CreateThreeSliceButton("ForeverLoginMenuButton" .. i, menu, BUTTON_W, BUTTON_H,
				"128-RedButton", { "GlueFontNormal", "GlueFontHighlight", "GlueFontDisable" })
			buttons[i] = b
		end
		y = y + (entry.section and SECTION or 0)
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", menu, "TOPLEFT", SIDE_MARGIN, -y)
		b:SetText(entry.text)
		b:SetScript("OnClick", entry.action)
		b:Show()
		y = y + BUTTON_H
	end
	for i = #entries + 1, #buttons do
		buttons[i]:Hide()
	end
	menu:SetWidth(SIDE_MARGIN + BUTTON_W + SIDE_MARGIN)
	menu:SetHeight(y + BOTTOM_MARGIN)
end

-- Menu action: hide the menu, then click the matching client button
local function clickAction(button)
	return function()
		menu:Hide()
		button:Click()
	end
end

local function fillLoginEntries()
	entries = {
		{ text = OPTIONS, action = clickAction(OptionsButton) },
		{ text = CREDITS, action = clickAction(AccountLoginCreditsButton), section = true },
		{ text = CINEMATICS, action = clickAction(AccountLoginCinematicsButton) },
		{ text = MANAGE_ACCOUNT, action = clickAction(AccountLoginManageAccountButton) },
		{ text = COMMUNITY_SITE, action = clickAction(AccountLoginCommunityButton) },
		{ text = EXIT_GAME, action = function() AccountLoginExitButton:Click() end },
		{ text = CLOSE, action = close, section = true },
	}
end

-- Character select entries: Options | AddOns (if any), Exit Game | Close. 3.3.5 has no
-- shop, and its Credits and Cinematics return to the login screen, so they are left out.
local function fillSelectEntries()
	entries = { { text = OPTIONS, action = clickAction(OptionsButton) } }
	local first = true
	if GetNumAddOns() > 0 then
		table.insert(entries, { text = ADDONS, action = clickAction(CharacterSelectAddonsButton), section = first })
		first = false
	end
	table.insert(entries, { text = EXIT_GAME, action = function() QuitGame() end, section = first })
	table.insert(entries, { text = CLOSE, action = close, section = true })
end

G.Hook(menu, "OnShow", function()
	if GetCurrentGlueScreenName() == "charselect" then
		fillSelectEntries()
	else
		fillLoginEntries()
	end
	paginate()
	veil:Show()
end)
G.Hook(menu, "OnHide", function()
	veil:Hide()
end)

veil:SetScript("OnKeyDown", function(_, pressedKey)
	if pressedKey == "ESCAPE" then
		close()
	elseif pressedKey == "PRINTSCREEN" then
		Screenshot()
	end
end)

function G.ShowMenu()
	menu:Show()
end

function G.ToggleMenu()
	if menu:IsShown() then
		close()
	else
		menu:Show()
	end
end

G.Menu = menu
