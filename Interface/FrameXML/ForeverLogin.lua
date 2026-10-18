-- Base of the in game windows. Same idea as the login screens: the atlas table above holds every
-- piece by name, and each window describes layout, not art. The client owns the frames, their
-- logic and their CVars; these files only draw over them.

ForeverLogin = ForeverLogin or {}
local G = ForeverLogin

-- ---------- Helpers

function G.SetShown(region, yes)
	if yes then region:Show() else region:Hide() end
end

-- 3.3.5 returns 1 / nil, sometimes 0 / 1 (IsEnabled): zero is true in Lua
function G.Truthy(v)
	return v and v ~= 0 and true or false
end

-- adds a handler to a script without replacing the client's
function G.Hook(frame, script, func)
	if frame.HookScript then
		frame:HookScript(script, func)
		return
	end
	local before = frame:GetScript(script)
	frame:SetScript(script, function(...)
		if before then
			before(...)
		end
		func(...)
	end)
end

-- runs func after a client global function, without replacing it
function G.HookFunction(name, func)
	if hooksecurefunc then
		hooksecurefunc(name, func)
		return
	end
	local before = _G[name]
	_G[name] = function(...)
		local a, b, c, d = before(...)
		func(...)
		return a, b, c, d
	end
end

-- the client's own font objects, by name
function G.Font(name)
	return _G[name]
end

-- Setting a path lets the client create the region, but a client that cannot resolve the path
-- leaves it nil, so create it here instead.
local STATE_LAYER = {
	SetNormalTexture = "ARTWORK",
	SetPushedTexture = "ARTWORK",
	SetDisabledTexture = "ARTWORK",
	SetCheckedTexture = "ARTWORK",
	SetDisabledCheckedTexture = "ARTWORK",
	SetHighlightTexture = "HIGHLIGHT",
}

function G.StateTexture(b, setter, getter)
	local t = b[getter](b)
	if not t then
		t = b:CreateTexture(nil, STATE_LAYER[setter] or "ARTWORK")
		b[setter](b, t)
	end
	return t
end

-- ---------- Atlas

-- Places an atlas element; atlasSize also applies its official size. Returns the entry.
function G.PlaceAtlas(texture, name, atlasSize)
	local e = G.atlas[string.lower(name)]
	if not e then
		error("ForeverLogin: missing atlas element: " .. tostring(name))
	end
	texture:SetTexture(e[1])
	texture:SetTexCoord(e[2], e[3], e[4], e[5])
	if atlasSize then
		texture:SetWidth(e[6])
		texture:SetHeight(e[7])
	end
	return e
end

-- ---------- Nine slice

-- 3.3.5 can only tile a whole image: an element that fills its sheet tiles, others stretch
local function tile(texture, e)
	local isWhole = e[2] == 0 and e[3] == 1 and e[4] == 0 and e[5] == 1
	if isWhole and (e[8] or e[9]) and texture.SetHorizTile then
		texture:SetTexture(e[1], true)
		texture:SetHorizTile(e[8] and true or false)
		texture:SetVertTile(e[9] and true or false)
	end
end

G.LAYOUTS = {
	-- ButtonFrameTemplate without portrait (the client's window frame)
	WindowFrame = {
		TopLeftCorner = { layer = "OVERLAY", atlas = "UI-Frame-Metal-CornerTopLeft", x = -8, y = 16 },
		TopRightCorner = { layer = "OVERLAY", atlas = "UI-Frame-Metal-CornerTopRight", x = 2, y = 16 },
		BottomLeftCorner = { layer = "OVERLAY", atlas = "UI-Frame-Metal-CornerBottomLeft", x = -8, y = -8 },
		BottomRightCorner = { layer = "OVERLAY", atlas = "UI-Frame-Metal-CornerBottomRight", x = 2, y = -8 },
		TopEdge = { layer = "OVERLAY", atlas = "_UI-Frame-Metal-EdgeTop" },
		BottomEdge = { layer = "OVERLAY", atlas = "_UI-Frame-Metal-EdgeBottom" },
		LeftEdge = { layer = "OVERLAY", atlas = "!UI-Frame-Metal-EdgeLeft" },
		RightEdge = { layer = "OVERLAY", atlas = "!UI-Frame-Metal-EdgeRight" },
	},
	Inset = {
		TopLeftCorner = { atlas = "UI-Frame-InnerTopLeft" },
		TopRightCorner = { atlas = "UI-Frame-InnerTopRight" },
		BottomLeftCorner = { atlas = "UI-Frame-InnerBotLeftCorner", x = 0, y = -1 },
		BottomRightCorner = { atlas = "UI-Frame-InnerBotRight", x = 0, y = -1 },
		TopEdge = { atlas = "_UI-Frame-InnerTopTile" },
		BottomEdge = { atlas = "_UI-Frame-InnerBotTile" },
		LeftEdge = { atlas = "!UI-Frame-InnerLeftTile" },
		RightEdge = { atlas = "!UI-Frame-InnerRightTile" },
	},
	Dialog = {
		TopLeftCorner = { atlas = "UI-Frame-DiamondMetal-CornerTopLeft" },
		TopRightCorner = { atlas = "UI-Frame-DiamondMetal-CornerTopRight" },
		BottomLeftCorner = { atlas = "UI-Frame-DiamondMetal-CornerBottomLeft" },
		BottomRightCorner = { atlas = "UI-Frame-DiamondMetal-CornerBottomRight" },
		TopEdge = { atlas = "_UI-Frame-DiamondMetal-EdgeTop" },
		BottomEdge = { atlas = "_UI-Frame-DiamondMetal-EdgeBottom" },
		LeftEdge = { atlas = "!UI-Frame-DiamondMetal-EdgeLeft" },
		RightEdge = { atlas = "!UI-Frame-DiamondMetal-EdgeRight" },
	},
	-- the tooltip border, for the group boxes of the client's panels
	Tooltip = {
		TopLeftCorner = { atlas = "Tooltip-NineSlice-CornerTopLeft" },
		TopRightCorner = { atlas = "Tooltip-NineSlice-CornerTopRight" },
		BottomLeftCorner = { atlas = "Tooltip-NineSlice-CornerBottomLeft" },
		BottomRightCorner = { atlas = "Tooltip-NineSlice-CornerBottomRight" },
		TopEdge = { atlas = "_Tooltip-NineSlice-EdgeTop" },
		BottomEdge = { atlas = "_Tooltip-NineSlice-EdgeBottom" },
		LeftEdge = { atlas = "!Tooltip-NineSlice-EdgeLeft" },
		RightEdge = { atlas = "!Tooltip-NineSlice-EdgeRight" },
		Center = { layer = "BACKGROUND", atlas = "Tooltip-NineSlice-Center", x = -4, y = 4, x1 = 4, y1 = -4 },
	},
}

local PIECES = {
	{ "TopLeftCorner", "TOPLEFT" },
	{ "TopRightCorner", "TOPRIGHT" },
	{ "BottomLeftCorner", "BOTTOMLEFT" },
	{ "BottomRightCorner", "BOTTOMRIGHT" },
	{ "TopEdge", "TOPLEFT", "TOPRIGHT", "TopLeftCorner", "TopRightCorner" },
	{ "BottomEdge", "BOTTOMLEFT", "BOTTOMRIGHT", "BottomLeftCorner", "BottomRightCorner" },
	{ "LeftEdge", "TOPLEFT", "BOTTOMLEFT", "TopLeftCorner", "BottomLeftCorner" },
	{ "RightEdge", "TOPRIGHT", "BOTTOMRIGHT", "TopRightCorner", "BottomRightCorner" },
	{ "Center" },
}

-- Applies a layout to a frame as regions of that frame. Returns the pieces by name.
function G.NineSlice(host, layoutName, target)
	local layout = G.LAYOUTS[layoutName]
	local p = {}
	for _, m in ipairs(PIECES) do
		local l = layout[m[1]]
		if l then
			local t = host:CreateTexture(nil, l.layer or "BORDER")
			p[m[1]] = t
			if m[1] == "Center" then
				local e = G.PlaceAtlas(t, l.atlas, true)
				t:SetPoint("TOPLEFT", p.TopLeftCorner, "BOTTOMRIGHT", l.x or 0, l.y or 0)
				t:SetPoint("BOTTOMRIGHT", p.BottomRightCorner, "TOPLEFT", l.x1 or 0, l.y1 or 0)
				tile(t, e)
			elseif m[3] then
				local e = G.PlaceAtlas(t, l.atlas, true)
				t:SetPoint(m[2], p[m[4]], m[3], l.x or 0, l.y or 0)
				t:SetPoint(m[3], p[m[5]], m[2], l.x1 or 0, l.y1 or 0)
				tile(t, e)
			else
				G.PlaceAtlas(t, l.atlas, true)
				t:SetPoint(l.point or m[2], target or host, l.relativePoint or l.point or m[2], l.x or 0, l.y or 0)
			end
		end
	end
	return p
end

-- ---------- Stretched atlas

-- An atlas element with slice data: nine pieces when stretched, the margins keeping their size
-- and the rest stretching. 3.3.5 has no slicing, so the pieces are regions of the host around
-- an invisible rect the caller anchors.
local function cut(obj)
	local e = obj.e
	local d = e[10]
	for _, t in ipairs(obj.pieces) do
		t:Hide()
	end
	if not d then
		obj.rect:SetTexture(e[1])
		obj.rect:SetTexCoord(e[2], e[3], e[4], e[5])
		return
	end
	obj.rect:SetTexture(nil)
	local W, H = e[6], e[7]
	local g, h, dr, b = d[1], d[2], d[3], d[4]
	local us = { e[2], e[2] + (e[3] - e[2]) * g / W, e[3] - (e[3] - e[2]) * dr / W, e[3] }
	local vs = { e[4], e[4] + (e[5] - e[4]) * h / H, e[5] - (e[5] - e[4]) * b / H, e[5] }
	local widths = { g, nil, dr }
	local heights = { h, nil, b }
	local r = obj.rect
	local n = 0
	for row = 1, 3 do
		for col = 1, 3 do
			local lw, lh = widths[col], heights[row]
			if (lw == nil or lw > 0) and (lh == nil or lh > 0) then
				n = n + 1
				local t = obj.pieces[n]
				if not t then
					t = obj.host:CreateTexture(nil, obj.layer)
					obj.pieces[n] = t
				end
				t:SetTexture(e[1])
				t:SetTexCoord(us[col], us[col + 1], vs[row], vs[row + 1])
				t:ClearAllPoints()
				if col == 1 then
					t:SetPoint("LEFT", r, "LEFT")
					t:SetWidth(lw)
				elseif col == 3 then
					t:SetPoint("RIGHT", r, "RIGHT")
					t:SetWidth(lw)
				else
					t:SetPoint("LEFT", r, "LEFT", g, 0)
					t:SetPoint("RIGHT", r, "RIGHT", -dr, 0)
				end
				if row == 1 then
					t:SetPoint("TOP", r, "TOP")
					t:SetHeight(lh)
				elseif row == 3 then
					t:SetPoint("BOTTOM", r, "BOTTOM")
					t:SetHeight(lh)
				else
					t:SetPoint("TOP", r, "TOP", 0, -h)
					t:SetPoint("BOTTOM", r, "BOTTOM", 0, b)
				end
				if obj.visible ~= false then
					t:Show()
				end
			end
		end
	end
	obj.count = n
end

-- host: frame that owns the pieces; name: atlas element; layer: draw layer (ARTWORK).
-- The caller anchors obj.rect and may Place another element on the same object.
function G.StretchedAtlas(host, name, layer)
	local obj = { host = host, layer = layer or "ARTWORK", pieces = {} }
	obj.rect = host:CreateTexture(nil, obj.layer)
	function obj:Place(n)
		self.e = G.atlas[string.lower(n)]
		if not self.e then
			error("ForeverLogin: missing atlas element: " .. tostring(n))
		end
		cut(self)
	end
	function obj:SetShown(yes)
		self.visible = yes and true or false
		if self.e[10] then
			for i = 1, self.count or 0 do
				G.SetShown(self.pieces[i], yes)
			end
		else
			G.SetShown(self.rect, yes)
		end
	end
	obj:Place(name)
	return obj
end

-- ---------- Three slice button

local function cropTexture(t, e, leftToRight, part)
	-- keep a part of the element's width; leftToRight: keep its left side
	local u1, u2 = e[2], e[3]
	if leftToRight then
		t:SetTexCoord(u1, u1 + (u2 - u1) * part, e[4], e[5])
	else
		t:SetTexCoord(u2 - (u2 - u1) * part, u2, e[4], e[5])
	end
end

local function paintThreeSlices(b, state)
	local r = b.foreverThreeSlice
	if not G.Truthy(b:IsEnabled()) then
		state = "DISABLED"
	end
	local suffix = ""
	if state == "DISABLED" then
		suffix = "-Disabled"
	elseif state == "PUSHED" then
		suffix = "-Pressed"
	end
	local eg = G.PlaceAtlas(r.left, r.atlas .. "-Left" .. suffix)
	G.PlaceAtlas(r.center, "_" .. r.atlas .. "-Center" .. suffix)
	local ed = G.PlaceAtlas(r.right, r.atlas .. "-Right" .. suffix)

	-- scaled to the button's height, then cropped when both ends do not fit
	local height, width = b:GetHeight(), b:GetWidth()
	local scale = height / eg[7]
	local lg, ld = eg[6] * scale, ed[6] * scale
	if lg + ld > width then
		local excess = lg + ld - width
		local ng, nd = lg, ld
		if (lg - excess) > ld then
			ng = lg - excess
		elseif (ld - excess) > lg then
			nd = ld - excess
		else
			if lg ~= ld then
				excess = excess - math.abs(lg - ld)
				ng = math.min(lg, ld)
				nd = ng
			end
			ng = ng - excess / 2
			nd = nd - excess / 2
		end
		cropTexture(r.left, eg, true, ng / lg)
		cropTexture(r.right, ed, false, nd / ld)
		lg, ld = ng, nd
	end
	r.left:SetWidth(lg)
	r.left:SetHeight(height)
	r.right:SetWidth(ld)
	r.right:SetHeight(height)
	r.active = G.Truthy(b:IsEnabled())
end

-- clears the art the 3.3.5 client puts on its own buttons
function G.ClearClientArt(b)
	for _, read in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture", "GetHighlightTexture" }) do
		local t = b[read] and b[read](b)
		if t then
			t:SetTexture(nil)
		end
	end
end

-- Three slice button: Left and Right at their atlas size scaled to the button height, Center
-- stretched between them. fonts: { normal, highlight, disabled }
function G.ThreeSliceButton(b, atlas, fonts)
	G.ClearClientArt(b)
	local r = { atlas = atlas }
	r.left = b:CreateTexture(nil, "BACKGROUND")
	r.left:SetPoint("TOPLEFT", b, "TOPLEFT")
	r.right = b:CreateTexture(nil, "BACKGROUND")
	r.right:SetPoint("TOPRIGHT", b, "TOPRIGHT")
	r.center = b:CreateTexture(nil, "BACKGROUND")
	r.center:SetPoint("TOPLEFT", r.left, "TOPRIGHT")
	r.center:SetPoint("BOTTOMRIGHT", r.right, "BOTTOMLEFT")
	b.foreverThreeSlice = r

	local h = G.StateTexture(b, "SetHighlightTexture", "GetHighlightTexture")
	G.PlaceAtlas(h, atlas .. "-Highlight")
	h:ClearAllPoints()
	h:SetAllPoints(b)
	h:SetBlendMode("ADD")

	if fonts then
		b:SetNormalFontObject(G.Font(fonts[1]))
		b:SetHighlightFontObject(G.Font(fonts[2] or fonts[1]))
		b:SetDisabledFontObject(G.Font(fonts[3] or fonts[1]))
	end
	local text = b:GetFontString()
	if text then
		text:ClearAllPoints()
		text:SetPoint("CENTER", b, "CENTER", 0, 0)
	end
	b:SetPushedTextOffset(-2, -1)

	G.Hook(b, "OnMouseDown", function(self)
		if G.Truthy(self:IsEnabled()) then
			paintThreeSlices(self, "PUSHED")
		end
	end)
	G.Hook(b, "OnMouseUp", function(self)
		paintThreeSlices(self, "NORMAL")
	end)
	G.Hook(b, "OnShow", function(self)
		paintThreeSlices(self, "NORMAL")
	end)
	G.Hook(b, "OnSizeChanged", function(self)
		paintThreeSlices(self, "NORMAL")
	end)
	G.Hook(b, "OnEnable", function(self)
		paintThreeSlices(self, "NORMAL")
	end)
	G.Hook(b, "OnDisable", function(self)
		paintThreeSlices(self, "NORMAL")
	end)
	paintThreeSlices(b, "NORMAL")
	return b
end

-- ---------- Window pieces

-- The dialog window: tiled background and the diamond metal frame as regions of the host.
function G.DialogFrame(host)
	local background = host:CreateTexture(nil, "BACKGROUND")
	G.PlaceAtlas(background, "UI-Frame-DialogBox-BackgroundTile", true)
	background:SetPoint("TOPLEFT", host, "TOPLEFT", 7, -7)
	background:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -7, 7)
	tile(background, G.atlas["ui-frame-dialogbox-backgroundtile"])
	return G.NineSlice(host, "Dialog"), background
end

-- The metal header across the top of a window. Returns the frame, with Place(text) to resize it.
function G.Header(parent, text, font, margin)
	local f = CreateFrame("Frame", nil, parent)
	f:SetWidth(200)
	f:SetHeight(39)
	f:SetPoint("TOP", parent, "TOP", 0, 11)
	local g = f:CreateTexture(nil, "ARTWORK")
	G.PlaceAtlas(g, "UI-Frame-DiamondMetal-Header-CornerLeft", true)
	g:SetPoint("LEFT", f, "LEFT")
	local d = f:CreateTexture(nil, "ARTWORK")
	G.PlaceAtlas(d, "UI-Frame-DiamondMetal-Header-CornerRight", true)
	d:SetPoint("RIGHT", f, "RIGHT")
	local c = f:CreateTexture(nil, "ARTWORK")
	G.PlaceAtlas(c, "_UI-Frame-DiamondMetal-Header-Tile")
	c:SetPoint("TOPLEFT", g, "TOPRIGHT")
	c:SetPoint("BOTTOMRIGHT", d, "BOTTOMLEFT")
	local t = f:CreateFontString(nil, "ARTWORK")
	t:SetFontObject(G.Font(font) or G.Font("GameFontNormal"))
	t:SetPoint("TOP", f, "TOP", 0, -13)
	f.Text = t
	function f:Place(other)
		self.Text:SetText(other or "")
		self:SetWidth(self.Text:GetStringWidth() + (margin or 64))
	end
	f:Place(text)
	return f
end

-- ---------- Windows

-- Framed window: rock background, top tile streaks, metal frame and a title, all as regions of
-- the host. Returns { title, frame, background, stripes }.
function G.Window(host, title)
	-- a translucent black panel, the same the mod draws and the same our other windows use
	local background = host:CreateTexture(nil, "BACKGROUND")
	background:SetTexture(0, 0, 0, 0.8)
	background:SetPoint("TOPLEFT", host, "TOPLEFT", 7, -21)
	background:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -2, 2)
	local stripes = host:CreateTexture(nil, "BORDER")
	G.PlaceAtlas(stripes, "_UI-Frame-TopTileStreaks", true)
	stripes:SetPoint("TOPLEFT", host, "TOPLEFT", 6, -21)
	stripes:SetPoint("TOPRIGHT", host, "TOPRIGHT", -2, -21)
	local frame = G.NineSlice(host, "WindowFrame")
	local container = CreateFrame("Frame", nil, host)
	container:SetFrameLevel(host:GetFrameLevel() + 10)
	container:SetHeight(20)
	container:SetPoint("TOPLEFT", host, "TOPLEFT", 0, -1)
	container:SetPoint("TOPRIGHT", host, "TOPRIGHT", 0, -1)
	local t = container:CreateFontString(nil, "OVERLAY")
	t:SetFontObject(G.Font("GameFontNormal"))
	t:SetPoint("TOP", container, "TOP", 0, -5)
	t:SetPoint("LEFT", container, "LEFT")
	t:SetPoint("RIGHT", container, "RIGHT")
	t:SetText(title or "")
	return { title = t, frame = frame, background = background, stripes = stripes, container = container }
end

-- Inset: border and, unless translucent, the marble background, drawn on the target rectangle.
function G.Inset(host, target, translucent)
	local background
	if not translucent then
		background = host:CreateTexture(nil, "BORDER")
		background:SetTexture("interface\\ForeverLogin\\framegeneral\\ui-background-marble", true)
		if background.SetHorizTile then
			background:SetHorizTile(true)
			background:SetVertTile(true)
		end
		background:SetAllPoints(target)
	end
	return G.NineSlice(host, "Inset", target), background
end

-- Close button: 24 x 24 with the client's exit art, anchored at the window's top right.
function G.WindowCloseButton(b, window)
	b:SetWidth(24)
	b:SetHeight(24)
	b:ClearAllPoints()
	b:SetPoint("TOPRIGHT", window, "TOPRIGHT", -2, 1)
	for _, v in ipairs({
		{ "SetNormalTexture", "GetNormalTexture", "128-redbutton-exit" },
		{ "SetPushedTexture", "GetPushedTexture", "128-redbutton-exit-pressed" },
		{ "SetDisabledTexture", "GetDisabledTexture", "128-redbutton-exit-disabled" },
		{ "SetHighlightTexture", "GetHighlightTexture", "128-redbutton-exit-highlight" },
	}) do
		local t = G.StateTexture(b, v[1], v[2])
		G.PlaceAtlas(t, v[3])
		t:ClearAllPoints()
		t:SetAllPoints(b)
		if v[1] == "SetHighlightTexture" then
			t:SetBlendMode("ADD")
		end
	end
	return b
end

-- ---------- Buttons of the client's own art

-- UI-Panel-Button, the client's file: two 12 wide ends and a stretched middle
function G.PanelButton(b)
	local file = "Interface\\Buttons\\UI-Panel-Button-"
	G.ClearClientArt(b)
	local g = b:CreateTexture(nil, "BACKGROUND")
	g:SetWidth(12)
	g:SetPoint("TOPLEFT", b, "TOPLEFT")
	g:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT")
	local d = b:CreateTexture(nil, "BACKGROUND")
	d:SetWidth(12)
	d:SetPoint("TOPRIGHT", b, "TOPRIGHT")
	d:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT")
	local m = b:CreateTexture(nil, "BACKGROUND")
	m:SetPoint("TOPLEFT", g, "TOPRIGHT")
	m:SetPoint("BOTTOMRIGHT", d, "BOTTOMLEFT")
	local pieces = { { g, 0, 0.09375 }, { m, 0.09375, 0.53125 }, { d, 0.53125, 0.625 } }
	local function state(name)
		for _, v in ipairs(pieces) do
			v[1]:SetTexture(file .. name)
			v[1]:SetTexCoord(v[2], v[3], 0, 0.6875)
		end
	end
	local function idle()
		state(G.Truthy(b:IsEnabled()) and "Up" or "Disabled")
	end
	idle()
	local h = G.StateTexture(b, "SetHighlightTexture", "GetHighlightTexture")
	h:SetTexture(file .. "Highlight")
	h:SetBlendMode("ADD")
	h:ClearAllPoints()
	h:SetAllPoints(b)
	G.Hook(b, "OnMouseDown", function()
		if G.Truthy(b:IsEnabled()) then
			state("Down")
		end
	end)
	G.Hook(b, "OnMouseUp", idle)
	G.Hook(b, "OnShow", idle)
	G.Hook(b, "OnDisable", idle)
	G.Hook(b, "OnEnable", idle)
	return b
end

-- UI-Silver-Button, the client's file: a 3 x 3 of ends and middles
local SILVER = { us = { 0, 0.09375, 0.53125, 0.625 }, vs = { 0, 0.1875, 0.625, 0.8125 }, corner = { 12, 6 } }

function G.SilverButton(b)
	if b.foreverSilver then
		return b
	end
	local file = "Interface\\Buttons\\UI-Silver-Button-"
	local name = b:GetName()
	-- the client's own pieces are hidden by alpha: its scripts retexture them
	for _, s in ipairs({ "Left", "Middle", "Right" }) do
		local t = name and _G[name .. s]
		if t then
			t:SetAlpha(0)
		end
	end
	G.ClearClientArt(b)
	local A = SILVER
	local p = {}
	for row = 1, 3 do
		for col = 1, 3 do
			local t = b:CreateTexture(nil, "BACKGROUND")
			t:SetTexCoord(A.us[col], A.us[col + 1], A.vs[row], A.vs[row + 1])
			p[#p + 1] = t
			t.foreverCol, t.foreverRow = col, row
		end
	end
	local function piece(col, row)
		return p[(row - 1) * 3 + col]
	end
	for _, t in ipairs(p) do
		local col, row = t.foreverCol, t.foreverRow
		if col == 1 then
			t:SetPoint("LEFT", b, "LEFT", 0, 0)
			t:SetWidth(A.corner[1])
		elseif col == 3 then
			t:SetPoint("RIGHT", b, "RIGHT", 0, 0)
			t:SetWidth(A.corner[1])
		else
			t:SetPoint("LEFT", piece(1, row), "RIGHT", 0, 0)
			t:SetPoint("RIGHT", piece(3, row), "LEFT", 0, 0)
		end
		if row == 1 then
			t:SetPoint("TOP", b, "TOP", 0, 0)
			t:SetHeight(A.corner[2])
		elseif row == 3 then
			t:SetPoint("BOTTOM", b, "BOTTOM", 0, 0)
			t:SetHeight(A.corner[2])
		else
			t:SetPoint("TOP", piece(col, 1), "BOTTOM", 0, 0)
			t:SetPoint("BOTTOM", piece(col, 3), "TOP", 0, 0)
		end
	end
	local function state(suffix)
		for _, t in ipairs(p) do
			t:SetTexture(file .. suffix)
		end
	end
	state("Up")
	local h = G.StateTexture(b, "SetHighlightTexture", "GetHighlightTexture")
	h:SetTexture(file .. "Highlight")
	h:SetTexCoord(0, 1, 0.03, 0.7175)
	h:SetBlendMode("ADD")
	h:SetAlpha(1)
	h:ClearAllPoints()
	h:SetAllPoints(b)
	G.Hook(b, "OnMouseDown", function(self)
		if G.Truthy(self:IsEnabled()) then
			state("Down")
		end
	end)
	G.Hook(b, "OnMouseUp", function()
		state("Up")
	end)
	G.Hook(b, "OnShow", function()
		state("Up")
	end)
	G.Hook(b, "OnEnable", function()
		state("Up")
	end)
	b:SetNormalFontObject(G.Font("GameFontHighlightSmall"))
	b:SetHighlightFontObject(G.Font("GameFontHighlightSmall"))
	b:SetDisabledFontObject(G.Font("GameFontDisableSmall"))
	local text = b:GetFontString()
	if text then
		text:ClearAllPoints()
		text:SetPoint("CENTER", b, "CENTER", 0, -1)
	end
	b.foreverSilver = p
	return b
end

-- ---------- Checkbox and scroll bar

-- The client's checkbox, in our minimal art
local function stateAtlas(c, setter, getter, atlas)
	local t = G.StateTexture(c, setter, getter)
	G.PlaceAtlas(t, atlas, true)
	return t
end

function G.Checkbox(c)
	if c.foreverCell then
		return c
	end
	c.foreverCell = true
	stateAtlas(c, "SetNormalTexture", "GetNormalTexture", "checkbox-minimal")
	stateAtlas(c, "SetPushedTexture", "GetPushedTexture", "checkbox-minimal")
	local glow = c:GetHighlightTexture()
	if glow then
		glow:SetTexture(nil)
		glow:SetAlpha(0)
	end
	stateAtlas(c, "SetCheckedTexture", "GetCheckedTexture", "checkmark-minimal")
	stateAtlas(c, "SetDisabledCheckedTexture", "GetDisabledCheckedTexture", "checkmark-minimal-disabled")
	return c
end

-- The client's slider in our minimal art: its backdrop goes (the client's own slider bar), the
-- bar is drawn as regions of it and the thumb becomes ours, 16 x 15 instead of 20 x 19. The
-- client has no stepper arrows, so there are none here either. The slider keeps its logic.
G.sliders = {}

function G.Slider(s)
	if s.foreverSlider then
		return s
	end
	s.foreverSlider = true
	if s.SetBackdrop then
		s:SetBackdrop(nil)
	end
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
	G.sliders[#G.sliders + 1] = s
	return s
end

local BAR = {
	width = 8, tip = 8,
	upArrow = "minimal-scrollbar-arrow-top", upArrowHover = "minimal-scrollbar-arrow-top-over",
	downArrow = "minimal-scrollbar-arrow-bottom", downArrowHover = "minimal-scrollbar-arrow-bottom-over",
	trackTop = "minimal-scrollbar-track-top", trackMiddle = "!minimal-scrollbar-track-middle",
	trackBottom = "minimal-scrollbar-track-bottom",
	cursorTip = "minimal-scrollbar-small-thumb-top", cursorMiddle = "minimal-scrollbar-small-thumb-middle",
}

-- A scroll bar of the client, in our minimal art: arrows over its buttons, the track and the
-- cursor drawn on top of the pieces it already has.
function G.Bar(sb)
	if not sb or sb.foreverBar then
		return sb and sb.foreverBar
	end
	local thumb = sb:GetThumbTexture()
	if thumb then
		thumb:SetAlpha(0)
	end
	local v = CreateFrame("Frame", nil, sb)
	v:SetAllPoints(sb)
	v:SetFrameLevel(sb:GetFrameLevel() + 5)
	local function arrow(button, atlas, hover)
		if not button then
			return nil
		end
		G.ClearClientArt(button)
		local t = v:CreateTexture(nil, "ARTWORK")
		G.PlaceAtlas(t, atlas, true)
		t:SetPoint("CENTER", button, "CENTER", 0, 0)
		G.Hook(button, "OnEnter", function()
			G.PlaceAtlas(t, hover, true)
		end)
		G.Hook(button, "OnLeave", function()
			G.PlaceAtlas(t, atlas, true)
		end)
		return t
	end
	local name = sb:GetName()
	v.top = arrow(name and _G[name .. "ScrollUpButton"], BAR.upArrow, BAR.upArrowHover)
	v.down = arrow(name and _G[name .. "ScrollDownButton"], BAR.downArrow, BAR.downArrowHover)
	local function slice(atlas, layer)
		local t = v:CreateTexture(nil, layer)
		G.PlaceAtlas(t, atlas, true)
		t:SetWidth(BAR.width)
		return t
	end
	local ph = slice(BAR.trackTop, "BACKGROUND")
	ph:SetPoint("TOP", sb, "TOP", 0, 0)
	local pb = slice(BAR.trackBottom, "BACKGROUND")
	pb:SetPoint("BOTTOM", sb, "BOTTOM", 0, 0)
	local pm = slice(BAR.trackMiddle, "BACKGROUND")
	pm:SetPoint("TOP", ph, "BOTTOM", 0, 0)
	pm:SetPoint("BOTTOM", pb, "TOP", 0, 0)
	if thumb then
		local ch = slice(BAR.cursorTip, "ARTWORK")
		ch:SetWidth(BAR.width)
		ch:SetHeight(BAR.tip)
		ch:SetPoint("TOP", thumb, "TOP", 0, 0)
		local cb = slice(BAR.cursorTip, "ARTWORK")
		local e = G.atlas[BAR.cursorTip]
		cb:SetTexCoord(e[2], e[3], e[5], e[4])
		cb:SetWidth(BAR.width)
		cb:SetHeight(BAR.tip)
		cb:SetPoint("BOTTOM", thumb, "BOTTOM", 0, 0)
		local cm = slice(BAR.cursorMiddle, "ARTWORK")
		cm:SetPoint("TOP", ch, "BOTTOM", 0, 0)
		cm:SetPoint("BOTTOM", cb, "TOP", 0, 0)
		v.cursor = { ch, cm, cb }
	end
	sb.foreverBar = v
	return v
end

-- A copy of a client FontString, on top of what covers it, following its text.
function G.Mirror(fs, host, font)
	local copy = host:CreateFontString(nil, "OVERLAY")
	copy:SetFontObject(G.Font(font) or G.Font("GameFontNormal"))
	copy:SetPoint("CENTER", fs, "CENTER", 0, 0)
	copy:SetText(fs:GetText() or "")
	fs:SetAlpha(0)
	local function follow()
		copy:SetText(fs:GetText() or "")
	end
	if fs.HookScript then
		fs:HookScript("OnShow", follow)
	end
	return copy
end

-- ---------- Inner frame of a window

-- The frame the reference mod draws inside its big windows: around the category list and the
-- settings, with the separator where the list ends. One element (886 x 618) cut into 5 x 3
-- pieces: the edges and the gradients keep their size and the rest stretches.
local INNER = {
	cols = { 0, 29, 199, 201, 857, 886 },
	ranks = { 0, 82, 451, 618 },
	left = -1, top = 12, down = -4, right = -17,
}

-- host: frame that owns the pieces; f: the window; list: the category list it fits on. Returns
-- the rectangle (an empty frame, for anchors: the tabs of the interface window hang from it).
function G.Interior(host, f, list)
	local I = INNER
	local e = G.atlas["options_innerframe"]
	local rect = CreateFrame("Frame", nil, host)
	rect:SetPoint("TOPLEFT", list, "TOPLEFT", I.left, I.top)
	rect:SetPoint("BOTTOMLEFT", list, "BOTTOMLEFT", I.left, I.down)
	rect:SetPoint("RIGHT", f, "RIGHT", I.right, 0)
	local du, dv = (e[3] - e[2]) / e[6], (e[5] - e[4]) / e[7]
	-- separator where the client's own list ends
	local sep = list:GetWidth() - I.left - 1
	local xs = { 0, I.cols[2], sep, sep + 2 }
	local pieces = {}
	for c = 1, 5 do
		for r = 1, 3 do
			local t = host:CreateTexture(nil, "ARTWORK")
			t:SetTexture(e[1])
			t:SetTexCoord(e[2] + I.cols[c] * du, e[2] + I.cols[c + 1] * du,
				e[4] + I.ranks[r] * dv, e[4] + I.ranks[r + 1] * dv)
			if c == 5 then
				t:SetPoint("RIGHT", rect, "RIGHT", 0, 0)
				t:SetWidth(I.cols[6] - I.cols[5])
			elseif c == 4 then
				t:SetPoint("LEFT", rect, "LEFT", xs[4], 0)
				t:SetPoint("RIGHT", rect, "RIGHT", -(I.cols[6] - I.cols[5]), 0)
			else
				t:SetPoint("LEFT", rect, "LEFT", xs[c], 0)
				t:SetWidth(xs[c + 1] - xs[c])
			end
			if r == 1 then
				t:SetPoint("TOP", rect, "TOP", 0, 0)
				t:SetHeight(I.ranks[2])
			elseif r == 3 then
				t:SetPoint("BOTTOM", rect, "BOTTOM", 0, 0)
				t:SetHeight(I.ranks[4] - I.ranks[3])
			else
				t:SetPoint("TOP", rect, "TOP", 0, -I.ranks[2])
				t:SetPoint("BOTTOM", rect, "BOTTOM", 0, I.ranks[4] - I.ranks[3])
			end
			pieces[#pieces + 1] = t
		end
	end
	rect.pieces = pieces
	return rect
end

-- ---------- Group box

-- Our tooltip border over a frame, in the grey the client uses (0.4) and with no fill, as the
-- reference mod does. The client's edge file cannot be swapped for one of our sheets: it draws
-- the edge file repeated all around, so a sheet comes out as a row of scraps.
function G.Border(f)
	if f.foreverBorder then
		return f.foreverBorder
	end
	if f.SetBackdrop and f.GetBackdrop and f:GetBackdrop() then
		f:SetBackdrop(nil)
	end
	local p = G.NineSlice(f, "Tooltip")
	for name, t in pairs(p) do
		if name == "Center" then
			t:Hide()
		else
			t:SetVertexColor(0.4, 0.4, 0.4)
		end
	end
	f.foreverBorder = p
	return p
end

-- A group box of the client: the ones that carry a tooltip border backdrop get ours. Returns
-- the frame when it was one, nil when it was not.
function G.Box(f)
	if f.foreverBox or not f.GetBackdrop then
		return nil
	end
	local b = f:GetBackdrop()
	if type(b) ~= "table" or type(b.edgeFile) ~= "string" or not string.find(string.lower(b.edgeFile), "tooltip%-border") then
		return nil
	end
	f.foreverBox = true
	G.Border(f)
	return f
end

-- ---------- Moving a window

-- Lets one of our frames drag a client window. The handle is enabled for the mouse and gives the
-- window the drag; the client re-centers its windows every time they are shown, so the place it
-- was left at is remembered and put back on show. The window is also marked as user placed, which
-- is how the client saves it with the layout for the next session.
function G.Movable(window, handle)
	window:SetMovable(true)
	window:SetClampedToScreen(true)
	window:SetUserPlaced(true)
	handle:EnableMouse(true)
	handle:RegisterForDrag("LeftButton")
	handle:SetScript("OnDragStart", function()
		window:StartMoving()
	end)
	handle:SetScript("OnDragStop", function()
		window:StopMovingOrSizing()
		-- after this the window has a real anchor: keep it to put the window back on show
		local point, relativeTo, relativePoint, x, y = window:GetPoint(1)
		window.foreverPlace = { point = point, relativeTo = relativeTo, relativePoint = relativePoint, x = x, y = y }
	end)
	G.Hook(window, "OnShow", function(self)
		local p = self.foreverPlace
		if p and p.point then
			self:SetUserPlaced(false)
			self:ClearAllPoints()
			self:SetPoint(p.point, p.relativeTo or UIParent, p.relativePoint or p.point, p.x, p.y)
			self:SetUserPlaced(true)
		end
	end)
	return handle
end

-- ---------- Options list and tabs

-- Repaints one category row: our selection and hover (the client's own glow is gone), the
-- client's fonts. Run after the client, whose update resets both.
local function paintRow(list, b)
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

-- One category row, once: the client reuses its buttons across elements.
local function skinRow(list, b)
	if b.foreverRow then
		return b
	end
	b.foreverRow = true
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
		paintRow(list, self)
	end)
	G.Hook(b, "OnLeave", function(self)
		self.foreverHovered = false
		paintRow(list, self)
	end)
	return b
end

-- Repaints the whole list; also where rows created after the addon loaded are skinned.
function G.PaintCategoryList(list)
	if not list then
		return
	end
	for _, b in ipairs(list.buttons or {}) do
		paintRow(list, skinRow(list, b))
	end
end

-- A client category list: our rows, our scroll bar. The rows, their order and their clicks stay
-- the client's, and its own border is left alone.
function G.CategoryList(list)
	if list.foreverCategories then
		return list
	end
	list.foreverCategories = true
	-- the client draws this frame's border with eight of its own textures: they go, because the
	-- inner frame of the window frames the list (as the reference mod does)
	local name = list:GetName()
	for _, suffix in ipairs({ "TopLeft", "TopRight", "BottomLeft", "BottomRight", "Left", "Right", "Top", "Bottom" }) do
		local t = _G[name .. suffix]
		if t then
			t:SetAlpha(0)
		end
	end
	local scroll = (list.scrollFrame or _G[name .. "List"])
	if scroll and scroll.SetBackdrop and scroll:GetBackdrop() then
		scroll:SetBackdrop(nil)
	end
	G.Bar(scroll and _G[scroll:GetName() .. "ScrollBar"])
	G.PaintCategoryList(list)
	return list
end

-- The client's own hooks: its update and its selection reset what we drew, and the interface
-- list redraw restores the selection at the end, after clearing every row.
G.HookFunction("OptionsList_DisplayButton", function(b)
	local list = b and b:GetParent()
	if list and list.foreverCategories then
		paintRow(list, skinRow(list, b))
	end
end)
for _, name in ipairs({ "OptionsList_SelectButton", "OptionsList_ClearSelection", "OptionsCategoryFrame_Update" }) do
	G.HookFunction(name, function(list)
		if list and list.foreverCategories then
			G.PaintCategoryList(list)
		end
	end)
end
for _, name in ipairs({ "InterfaceCategoryList_Update", "InterfaceAddOnsList_Update" }) do
	G.HookFunction(name, function()
		G.PaintCategoryList(InterfaceOptionsFrameCategories)
		G.PaintCategoryList(InterfaceOptionsFrameAddOns)
	end)
end

-- Tabs over a client tab button (PanelTemplates: the selected tab is disabled). The pieces,
-- the height and the offsets are the ones the reference mod uses on this same client.
local TAB = { height = 37, margin = 40, text = 4, selectedText = 6 }

local function paintTab(o)
	local selected = not G.Truthy(o:IsEnabled())
	local prefix = selected and "options_tab_active_" or "options_tab_"
	G.PlaceAtlas(o.foreverArt.left, prefix .. "left", true)
	G.PlaceAtlas(o.foreverArt.middle, prefix .. "middle", true)
	G.PlaceAtlas(o.foreverArt.right, prefix .. "right", true)
	local text = o:GetFontString()
	if text then
		text:ClearAllPoints()
		text:SetPoint("BOTTOM", o, "BOTTOM", 0, selected and TAB.selectedText or TAB.text)
	end
	o:SetNormalFontObject(G.Font((selected or o.foreverHovered) and "GameFontHighlightSmall" or "GameFontNormalSmall"))
	o:SetWidth((text and text:GetStringWidth() or 0) + TAB.margin)
end

-- A client tab button in our art: its six pieces go and ours are drawn as regions of the tab.
function G.Tab(o)
	if o.foreverArt then
		return o
	end
	local name = o:GetName()
	for _, suffix in ipairs({ "Left", "Middle", "Right", "LeftDisabled", "MiddleDisabled", "RightDisabled" }) do
		local t = _G[name .. suffix]
		if t then
			t:SetAlpha(0)
		end
	end
	local glow = o:GetHighlightTexture()
	if glow then
		glow:SetTexture(nil)
		glow:SetAlpha(0)
	end
	o:SetHeight(TAB.height)
	local a = {}
	a.left = o:CreateTexture(nil, "BACKGROUND")
	a.left:SetPoint("BOTTOMLEFT", o, "BOTTOMLEFT")
	a.right = o:CreateTexture(nil, "BACKGROUND")
	a.right:SetPoint("BOTTOMRIGHT", o, "BOTTOMRIGHT")
	a.middle = o:CreateTexture(nil, "BACKGROUND")
	a.middle:SetPoint("TOPLEFT", a.left, "TOPRIGHT")
	a.middle:SetPoint("TOPRIGHT", a.right, "TOPLEFT")
	o.foreverArt = a
	o:SetDisabledFontObject(G.Font("GameFontHighlightSmall"))
	G.Hook(o, "OnEnter", function(self)
		self.foreverHovered = true
		paintTab(self)
	end)
	G.Hook(o, "OnLeave", function(self)
		self.foreverHovered = false
		paintTab(self)
	end)
	G.Hook(o, "OnShow", paintTab)
	G.Hook(o, "OnEnable", paintTab)
	G.Hook(o, "OnDisable", paintTab)
	paintTab(o)
	return o
end
