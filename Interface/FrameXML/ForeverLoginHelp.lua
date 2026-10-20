-- The Help window (HelpFrame) and its Knowledge Base in our style: our metal window, title,
-- close button, buttons, fields, dropdowns, scroll bars and list rows over the client's frames.
-- The client keeps its panels, its pages, its data and its clicks; nothing here replaces its
-- logic, and its 2004 cardboard (the frame art, the header and the dividers) is hidden.

local G = ForeverLogin

if not HelpFrame then
	return
end

local f = HelpFrame
local kb = KnowledgeBaseFrame

local M = {}
G.Help = M

local N = {
	button = { "GameFontNormalSmall", "GameFontHighlightSmall", "GameFontDisableSmall" },
	paging = { 74, 20 },
	gap = 6,
}

-- ------------------------------------------------------------ Pieces

-- A button of the client in our red three slice. GameMenuButtonTemplate and UIPanelButtonTemplate2
-- draw three pieces as textures of the button; UIPanelButtonTemplate draws a single file. Both
-- are cleared first, so the client's hover and press art never shows through ours.
local function skinButton(b)
	if b.foreverHelpButton then
		return b
	end
	b.foreverHelpButton = true
	local name = b:GetName()
	for _, suffix in ipairs({ "Left", "Middle", "Right" }) do
		local piece = name and _G[name .. suffix]
		if piece then
			piece:SetAlpha(0)
		end
	end
	G.ThreeSliceButton(b, "128-redbutton", N.button)
	return b
end

-- A field of the client: its Common-Input-Border pieces go, a dark fill and our border stay.
local function skinEdit(e)
	if e.foreverHelpEdit then
		return e
	end
	-- A field that is the scroll child of a scroll frame scrolls with its own text: a border
	-- drawn on it would scroll away, so it keeps the frame it is in.
	local parent = e:GetParent()
	if parent and parent.GetObjectType and parent:GetObjectType() == "ScrollFrame" then
		return e
	end
	e.foreverHelpEdit = true
	local name = e:GetName()
	for _, suffix in ipairs({ "Left", "Middle", "Right" }) do
		local piece = name and _G[name .. suffix]
		if piece then
			piece:SetAlpha(0)
		end
	end
	-- the multi line boxes draw their border as named pieces of their own
	for _, r in ipairs({ e:GetRegions() }) do
		if r:GetObjectType() == "Texture" then
			local file = r:GetTexture()
			if type(file) == "string" and string.find(string.lower(file), "common%-input%-border") then
				r:SetAlpha(0)
			end
		end
	end
	local fill = e:CreateTexture(nil, "BACKGROUND")
	fill:SetTexture(0, 0, 0, 0.35)
	fill:SetAllPoints(e)
	G.Border(e)
	return e
end

-- A divider of the client: its three pieces go and a hair line takes their place.
local function skinDivider(d)
	if d.foreverHelpDivider then
		return d
	end
	d.foreverHelpDivider = true
	local name = d:GetName()
	for _, suffix in ipairs({ "Left", "Middle", "Right" }) do
		local piece = name and _G[name .. suffix]
		if piece then
			piece:SetAlpha(0)
		end
	end
	local line = d:CreateTexture(nil, "ARTWORK")
	line:SetTexture(1, 1, 1, 0.07)
	line:SetHeight(1)
	line:SetPoint("LEFT", d, "LEFT", 0, 0)
	line:SetPoint("RIGHT", d, "RIGHT", 0, 0)
	return d
end

-- A row of the article list: the client's glow goes, a soft fill follows the mouse.
local function skinRow(b)
	if b.foreverHelpRow then
		return b
	end
	b.foreverHelpRow = true
	local glow = b.GetHighlightTexture and b:GetHighlightTexture()
	if glow then
		glow:SetTexture(nil)
		glow:SetAlpha(0)
	end
	local bar = b:CreateTexture(nil, "BACKGROUND")
	bar:SetTexture(1, 1, 1, 0.06)
	bar:SetPoint("TOPLEFT", b, "TOPLEFT", -3, 1)
	bar:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 3, -1)
	bar:Hide()
	G.Hook(b, "OnEnter", function()
		bar:Show()
	end)
	G.Hook(b, "OnLeave", function()
		bar:Hide()
	end)
	return b
end

-- The paging buttons: the client's spellbook arrows go, the caption becomes the button.
local function skinPaging(b)
	if b.foreverHelpPaging then
		return b
	end
	b.foreverHelpPaging = true
	G.ClearClientArt(b)
	local name = b:GetName()
	local label = name and _G[name .. "Text"]
	b:SetWidth(N.paging[1])
	b:SetHeight(N.paging[2])
	G.ThreeSliceButton(b, "128-redbutton", N.button)
	if label then
		label:ClearAllPoints()
		label:SetPoint("CENTER", b, "CENTER", 0, -1)
		label:SetJustifyH("CENTER")
		label:SetFontObject(G.Font("GameFontNormalSmall"))
	end
	return b
end

-- A UIDropDownMenuTemplate: its own Button child and three pieces give it away. The pieces are
-- asked for their parent, so a name that belongs to another frame does not count.
local function isDropdown(o)
	local name = o:GetName()
	local button = name and _G[name .. "Button"]
	local left = name and _G[name .. "Left"]
	if not (button and left and left.GetParent and button.GetParent) then
		return false
	end
	return button:GetParent() == o and left:GetParent() == o
end

-- ------------------------------------------------------------ Window

-- the client's cardboard: the frame art, the header and the title it carries
local helpTitle = _G.HELP_FRAME_TITLE
for _, r in ipairs({ f:GetRegions() }) do
	local kind = r:GetObjectType()
	if kind == "Texture" or (helpTitle and kind == "FontString" and r:GetText() == helpTitle) then
		r:SetAlpha(0)
	end
end
-- the Knowledge Base brings a header of its own, on top of the same spot
if kb then
	local title = _G.KNOWLEDGEBASE_FRAME_TITLE
	for _, r in ipairs({ kb:GetRegions() }) do
		local kind = r:GetObjectType()
		if kind == "Texture" or (title and kind == "FontString" and r:GetText() == title) then
			r:SetAlpha(0)
		end
	end
end

M.skin = G.Window(f, HELP_FRAME_TITLE)
G.Movable(f, M.skin.container)
-- The client keeps 44 px on the right and 13 at the bottom out of its own hit area, where the
-- close button of its cardboard sat: the window is ours, so it takes the mouse whole (the close
-- button is in that strip).
f:SetHitRectInsets(0, 0, 0, 0)
if kb then
	kb:SetHitRectInsets(0, 0, 0, 0)
end
-- the title bar takes the mouse to move the window, so the close button goes over it
HelpFrameCloseButton:SetFrameLevel(f:GetFrameLevel() + 20)
G.WindowCloseButton(HelpFrameCloseButton, f)

-- ------------------------------------------------------------ Controls

if KnowledgeBaseArticleListFrameNextButton and KnowledgeBaseArticleListFramePreviousButton then
	local nextButton = KnowledgeBaseArticleListFrameNextButton
	local previousButton = KnowledgeBaseArticleListFramePreviousButton
	skinPaging(nextButton)
	skinPaging(previousButton)
	-- the client anchored the pair on the text widths of its arrows: ours sit side by side
	nextButton:ClearAllPoints()
	nextButton:SetPoint("TOPRIGHT", KnowledgeBaseArticleListFrame, "TOPRIGHT", 0, 0)
	previousButton:ClearAllPoints()
	previousButton:SetPoint("RIGHT", nextButton, "LEFT", -N.gap, 0)
end

-- ------------------------------------------------------------ Knowledge Base box

-- The content box of the reference windows, around the article list and the article itself: from
-- the divider under the search row to above the action buttons. It is a child of the Knowledge
-- Base frame, so it shows and hides with it, and the client's two cardboard separators go: the
-- box and the fields themselves mark the sections.
local divider = KnowledgeBaseFrameDivider2
M.box = kb and divider and CreateFrame("Frame", nil, kb)
if M.box then
	local box = M.box
	box:SetPoint("TOPLEFT", divider, "BOTTOMLEFT", 0, 8)
	box:SetPoint("BOTTOMRIGHT", kb, "BOTTOMRIGHT", -46, 74)
	-- at the level of the Knowledge Base itself, not over its children: the list title, the rows
	-- and the article are children and have to stay in front of the box
	box:SetFrameLevel(kb:GetFrameLevel())
	G.ContentBox(box, box)
	for _, d in ipairs({ KnowledgeBaseFrameDivider, KnowledgeBaseFrameDivider2 }) do
		if d then
			d:Hide()
		end
	end
end

-- The two buttons of the Knowledge Base header sit on the window's top edge as the client
-- leaves them: they clear it, and line up with the content box (list at 19, box at 594).
if KnowledgeBaseFrameTopIssuesButton then
	KnowledgeBaseFrameTopIssuesButton:ClearAllPoints()
	KnowledgeBaseFrameTopIssuesButton:SetPoint("TOPRIGHT", kb, "TOPRIGHT", -46, -30)
end
if GMChatOpenLog then
	GMChatOpenLog:ClearAllPoints()
	GMChatOpenLog:SetPoint("TOPLEFT", kb, "TOPLEFT", 19, -30)
end

-- The article and the error views take the width of the article list and stop above the box's
-- bottom edge, so the scroll bar stays inside it and the lists line up.
if M.box then
	local W = (KnowledgeBaseArticleListFrame and KnowledgeBaseArticleListFrame:GetWidth()) or 0
	if W <= 0 then
		W = 569
	end
	local H = M.box:GetHeight() - 9
	if H <= 0 then
		H = 321
	end
	local scroll = KnowledgeBaseArticleScrollFrame
	local child = KnowledgeBaseArticleScrollChildFrame
	if scroll then
		scroll:SetWidth(W)
		scroll:SetHeight(H)
	end
	if child then
		child:SetWidth(W)
		local back = _G["KnowledgeBaseArticleScrollChildFrameBackButton"]
		local title = KnowledgeBaseArticleScrollChildFrameTitle
		if title then
			title:SetWidth(W - (back and back:GetWidth() or 85) - 10)
		end
		local text = KnowledgeBaseArticleScrollChildFrameText
		if text then
			text:SetWidth(W - 10)
		end
	end
	if KnowledgeBaseErrorFrame then
		KnowledgeBaseErrorFrame:SetWidth(W)
		KnowledgeBaseErrorFrame:SetHeight(H)
	end
end

-- The header names the screen: the Knowledge Base has a name of its own, the other panels are
-- the Customer Support window.
if kb then
	G.Hook(kb, "OnShow", function()
		M.skin.title:SetText(KNOWLEDGEBASE_FRAME_TITLE)
	end)
	G.Hook(kb, "OnHide", function()
		M.skin.title:SetText(HELP_FRAME_TITLE)
	end)
end

-- Every control of the window and of its panels, at any depth. The dropdowns are not walked
-- through: their Button child and their pieces are theirs.
local function skin(frame)
	for _, c in ipairs({ frame:GetChildren() }) do
		local kind = c:GetObjectType()
		local name = c:GetName() or ""
		if kind == "Button" then
			if name == "HelpFrameCloseButton" then
				-- done with the window
			elseif string.find(name, "^KnowledgeBaseArticleListItem") then
				skinRow(c)
			elseif c == KnowledgeBaseArticleListFrameNextButton or c == KnowledgeBaseArticleListFramePreviousButton then
				-- placed above
			else
				skinButton(c)
			end
		elseif kind == "EditBox" then
			skinEdit(c)
		elseif kind == "ScrollFrame" then
			-- the decoration some of them draw behind their bar
			for _, r in ipairs({ c:GetRegions() }) do
				if r:GetObjectType() == "Texture" then
					r:SetAlpha(0)
				end
			end
			G.Bar(_G[name .. "ScrollBar"])
			skin(c)
		elseif kind == "Frame" then
			if isDropdown(c) then
				G.DropDown(c, 1)
			else
				if string.find(name, "Divider") then
					skinDivider(c)
				end
				skin(c)
			end
		end
	end
end

skin(f)
