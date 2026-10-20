-- The client's static popups (the confirmation dialogs) in our style: our dialog frame and red
-- buttons over its frames. The client keeps its texts, its layouts, its timeouts and its
-- callbacks: it sizes and places everything again on every show, so the skin is applied once and
-- the parts it rewrites are put back on show. Its own dialog backdrop and button art go.

local G = ForeverLogin

local FONTS = { "GameFontNormal", "GameFontHighlight", "GameFontDisable" }

local M = {}
G.StaticPopup = M

-- ------------------------------------------------------------ Pieces

local function skinButton(b)
	if not b or b.foreverPopupButton then
		return b
	end
	b.foreverPopupButton = true
	G.ThreeSliceButton(b, "128-redbutton", FONTS)
	return b
end

-- The close button is the client's "close" or "hide" button of a few dialogs: it writes its art
-- again in StaticPopup_Show, before the frame shows, so ours goes back on show.
local function skinClose(f)
	local name = f:GetName()
	local b = name and _G[name .. "CloseButton"]
	if not b then
		return nil
	end
	G.WindowCloseButton(b, f)
	return b
end

-- ------------------------------------------------------------ Dialogs

for i = 1, 4 do
	local f = _G["StaticPopup" .. i]
	if f then
		-- the client's DialogBox backdrop goes: the diamond dialog frame takes its place
		f:SetBackdrop(nil)
		G.DialogFrame(f)
		skinButton(f.button1)
		skinButton(f.button2)
		skinButton(f.button3)
		G.EditBox(f.editBox)
		G.EditBox(f.wideEditBox)
		if skinClose(f) then
			G.Hook(f, "OnShow", function()
				skinClose(f)
			end)
		end
	end
end
