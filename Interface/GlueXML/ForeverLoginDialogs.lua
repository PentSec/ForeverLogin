-- Glue screen dialogs and tooltip. No 3.3.5 dialog type is vertical or has an edit box, so
-- the delete dialog keeps the client anchors and height. The client frames and scripts stay:
-- they are reskinned and re-placed after the client.

local G = ForeverLogin

local BUTTON_FONTS = { "GlueFontNormal", "GlueFontHighlight", "GlueFontDisable" }
local BUTTON_W, BUTTON_H = 200, 30

-- Builds a dialog container (GlueDialog BG.Top and BG.Bottom) from regions of host;
-- returns the function that sizes it (width, height)
local function container(host)
	host:SetBackdrop(nil)
	local background = host:CreateTexture(nil, "BACKGROUND")
	background:SetPoint("TOPLEFT", host, "TOPLEFT", 8, -9)
	background:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -8, 9)
	local edge = G.StretchedAtlas(host, "UI-DiamondDialogBox-Border", "BORDER")
	edge.rect:SetAllPoints(host)
	return function(width, height)
		host:SetWidth(width)
		host:SetHeight(height)
		G.Tile(background, "UI-Frame-DialogBox-BackgroundTile", width - 16, height - 18)
	end
end

-- GlueDialogButtonTemplate: the 200 x 30 red button
local function skinDialogButton(b)
	b:SetWidth(BUTTON_W)
	b:SetHeight(BUTTON_H)
	G.ThreeSliceButton(b, "128-RedButton", BUTTON_FONTS)
end

-- ------------------------------------------------------------ Dialog

local sizeDialog = container(GlueDialogBackground)
GlueDialogText:SetFontObject(G.Font("GlueFontNormalLarge"))
-- SimpleHTML: one font per element; if 3.3.5 rejects the per-element form, the text
-- keeps the client font
for _, e in ipairs({ { "P", "GlueFontNormalLarge" }, { "H1", "GlueFontNormalLarge" }, { "H2", "GlueFontHighlight" } }) do
	pcall(GlueDialogHTML.SetFontObject, GlueDialogHTML, e[1], G.Font(e[2]))
end
for i = 1, 3 do
	skinDialogButton(_G["GlueDialogButton" .. i])
end
-- GlueDialog_OnUpdate only re-applies the 3.3.5 button art, every frame
GlueDialog:SetScript("OnUpdate", nil)

-- Sizes the dialog, run after the client's GlueDialog_Show.
local function layoutDialog()
	local info = GlueDialogTypes[GlueDialog.which]
	if not info then
		return
	end
	local background = GlueDialogBackground
	local buttons = {}
	for i = 1, 3 do
		local b = _G["GlueDialogButton" .. i]
		b:ClearAllPoints()
		if b:IsShown() then
			table.insert(buttons, b)
		end
	end
	local n = #buttons
	if n == 3 then
		buttons[2]:SetPoint("BOTTOM", background, "BOTTOM", 0, 18)
		buttons[1]:SetPoint("RIGHT", buttons[2], "LEFT", -15, 0)
		buttons[3]:SetPoint("LEFT", buttons[2], "RIGHT", 15, 0)
	elseif n == 2 then
		buttons[1]:SetPoint("BOTTOMRIGHT", background, "BOTTOM", -6, 18)
		buttons[2]:SetPoint("LEFT", buttons[1], "RIGHT", 15, 0)
	elseif n == 1 then
		buttons[1]:SetPoint("BOTTOM", background, "BOTTOM", 0, 18)
	end

	local width, textWidth = info.showAlert and 600 or 512, 450
	if n == 3 then
		width = 75 + 3 * BUTTON_W + 2 * 15 + 75
		textWidth = width - 40
	end
	GlueDialogAlertIcon:ClearAllPoints()
	GlueDialogAlertIcon:SetPoint("LEFT", background, "LEFT", 17, 0)

	local textHeight
	if info.html then
		GlueDialogHTML:ClearAllPoints()
		GlueDialogHTML:SetPoint("TOP", background, "TOP", 0, -23)
		textHeight = select(4, GlueDialogHTML:GetBoundsRect()) or 0
	else
		GlueDialogText:ClearAllPoints()
		GlueDialogText:SetPoint("TOP", background, "TOP", 0, -23)
		GlueDialogText:SetWidth(textWidth)
		textHeight = GlueDialogText:GetHeight()
	end
	local height = 16 + textHeight + ((n > 0) and (13 + BUTTON_H + 25) or 25)
	sizeDialog(width, math.floor(height + 0.5))
end

G.HookFunction("GlueDialog_Show", layoutDialog)
-- UPDATE_STATUS_DIALOG changes the text and the height
G.Hook(GlueDialog, "OnEvent", function(_, event)
	if event == "UPDATE_STATUS_DIALOG" then
		layoutDialog()
	end
end)

-- ------------------------------------------------------------ Delete dialog

CharacterDeleteBackground:SetBackdrop(nil)
G.DialogFrame(CharacterDeleteBackground)
CharacterDeleteText1:SetFontObject(G.Font("GlueFontNormalLarge"))
CharacterDeleteText2:SetFontObject(G.Font("GlueFontNormalSmall"))
CharacterDeleteEditBox:SetFontObject(G.Font("GlueFontHighlight"))
skinDialogButton(CharacterDeleteButton1)
skinDialogButton(CharacterDeleteButton2)

-- ------------------------------------------------------------ Forced rename

local sizeRename = container(CharacterRenameBackground)
local renameText = CharacterRenameText1
renameText:SetFontObject(G.Font("GlueFontNormalLarge"))
renameText:SetWidth(450)
renameText:ClearAllPoints()
renameText:SetPoint("TOP", CharacterRenameBackground, "TOP", 0, -23)
-- the instructions join the main text (the layout has a single text)
CharacterRenameText2:SetAlpha(0)
CharacterRenameText2:Hide()
CharacterRenameAlertIcon:ClearAllPoints()
CharacterRenameAlertIcon:SetPoint("LEFT", CharacterRenameBackground, "LEFT", 17, 0)

local field = CharacterRenameEditBox
for _, r in ipairs({ field:GetRegions() }) do
	if r:GetObjectType() == "Texture" then
		r:SetTexture(nil)
		r:SetAlpha(0)
		r:Hide()
	end
end
field:SetWidth(130)
field:SetHeight(32)
field:SetTextInsets(12, 5, 0, 5)
field:SetFontObject(G.Font("GlueFontHighlight"))
field:ClearAllPoints()
field:SetPoint("CENTER", CharacterRenameDialog, "CENTER")
G.TooltipBackground(field, "TooltipDefaultLayout", G.GLUE_BACKDROP_COLOR)

skinDialogButton(CharacterRenameButton1)
skinDialogButton(CharacterRenameButton2)
CharacterRenameButton1:ClearAllPoints()
CharacterRenameButton1:SetPoint("BOTTOMRIGHT", CharacterRenameBackground, "BOTTOM", -6, 18)
CharacterRenameButton2:ClearAllPoints()
CharacterRenameButton2:SetPoint("LEFT", CharacterRenameButton1, "RIGHT", 15, 0)

-- Sizes the rename dialog: text, buttons, then 13 + edit box (FORCE_RENAME_CHARACTER)
local function layoutRename()
	local height = 16 + renameText:GetHeight() + 13 + BUTTON_H + 25 + 13 + field:GetHeight()
	sizeRename(600, math.floor(height + 0.5))
end
layoutRename()

-- the client shows the dialog, then writes the message into it
G.Hook(CharacterSelect, "OnEvent", function(_, event, message)
	if event == "FORCE_RENAME_CHARACTER" then
		renameText:SetText(string.format("%s\n%s", _G[message] or "", CHAR_RENAME_INSTRUCTIONS))
		layoutRename()
	end
end)
G.Hook(CharacterRenameDialog, "OnShow", function()
	field:SetFocus()
end)

-- ------------------------------------------------------------ Tooltip

GlueTooltip:SetBackdrop(nil)
G.TooltipBackground(GlueTooltip, "TooltipDefaultLayout", G.GLUE_BACKDROP_COLOR)
for _, v in ipairs({ { "TextLeft1", "GlueFontNormal" }, { "TextRight1", "GlueFontNormal" },
		{ "TextLeft2", "GlueFontNormalSmall" }, { "TextRight2", "GlueFontNormalSmall" } }) do
	_G["GlueTooltip" .. v[1]]:SetFontObject(G.Font(v[2]))
end
-- GlueTooltip_SetOwner adds a point without clearing the others: clear them on hide,
-- so an anchor of another kind does not stretch the tooltip between two points.
GlueTooltip:ClearAllPoints()
G.Hook(GlueTooltip, "OnHide", function(self)
	self:ClearAllPoints()
end)
