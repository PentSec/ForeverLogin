-- Templates for the login screens (continues ForeverLogin.lua): stretched atlas
-- with its nine-slice margins, tiled atlas, art-kit button, square icon button,
-- minimal scroll bar and panel button.

local G = ForeverLogin

-- Run func after a client global function; uses hooksecurefunc when the client has it.
function G.HookFunction(name, func)
	if hooksecurefunc then
		hooksecurefunc(name, func)
		return
	end
	local before = _G[name]
	_G[name] = function(...)
		local r1, r2, r3, r4 = before(...)
		func(...)
		return r1, r2, r3, r4
	end
end

-- ------------------------------------------------------------ Stretched atlas

-- An atlas element with slice data: it draws as nine pieces when stretched, the margins
-- keeping their size and the rest stretching. 3.3.5 has no slicing, so the pieces are regions
-- of the host around an invisible rect the caller anchors.
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

-- host: frame that owns the pieces; name: atlas name; layer: draw layer (ARTWORK)
function G.StretchedAtlas(host, name, layer)
	local obj = { host = host, layer = layer or "ARTWORK", pieces = {} }
	obj.rect = host:CreateTexture(nil, obj.layer)
	function obj:Place(n)
		self.e = G.atlas[string.lower(n)]
		if not self.e then
			error(G.L.GLUE_ERROR_MISSING_ATLAS .. tostring(n))
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

-- ------------------------------------------------------------ Tiled atlas

-- A tiled element (UiTextureAtlasMember flags) repeats at native size instead of stretching.
-- In 3.3.5 the element must fill its whole file; we read the part of the image the frame
-- covers, from its top left corner. width, height: size of the covered area
function G.Tile(texture, name, width, height)
	local e = G.atlas[string.lower(name)]
	texture:SetTexture(e[1], true)
	texture:SetTexCoord(0, width / e[6], 0, height / e[7])
end

-- ------------------------------------------------------------ Art-kit button

-- UIButtonTemplate (shared/button/uibuttontemplate.lua, SetButtonArtKit): the artKit element
-- and its -Pressed, -Disabled, -Highlight variants over the whole button, highlight in ADD.
-- Re-applied when CharacterSelect_DeathKnightSwap puts the client art back.
local function placeArt(b)
	local kit = b.foreverArt
	for _, v in ipairs({
		{ "SetNormalTexture", "GetNormalTexture", "" },
		{ "SetPushedTexture", "GetPushedTexture", "-Pressed" },
		{ "SetDisabledTexture", "GetDisabledTexture", "-Disabled" },
		{ "SetHighlightTexture", "GetHighlightTexture", "-Highlight" },
	}) do
		local name = kit .. v[3]
		local t = G.StateTexture(b, v[1], v[2])
		G.PlaceAtlas(t, name)
		t:ClearAllPoints()
		t:SetAllPoints(b)
		if v[3] == "-Highlight" then
			t:SetBlendMode("ADD")
		end
	end
	b.foreverArtFile = b:GetNormalTexture():GetTexture()
end

function G.ButtonArt(b, artKit)
	b.foreverArt = artKit
	placeArt(b)
	local text = b:GetFontString()
	if text then
		text:SetText("")
	end
	if not b.foreverArtHooked then
		b.foreverArtHooked = true
		G.Hook(b, "OnUpdate", function(self)
			local n = self:GetNormalTexture()
			if not n or n:GetTexture() ~= self.foreverArtFile then
				placeArt(self)
			end
		end)
	end
	return b
end

-- ------------------------------------------------------------ Square icon button

-- Square icon button: 48 x 48, hit rect inset 6; up/down states shifted (1, -1); the icon
-- of iconSize (24) centered; highlight is the icon in ADD at 0.4. layer: icon layer;
-- pass "OVERLAY" because ARTWORK is shared with the normal texture, whose order varies.
function G.SquareIconButton(b, icon, iconSize, layer)
	G.ClearClientArt(b)
	b:SetWidth(48)
	b:SetHeight(48)
	b:SetHitRectInsets(6, 6, 6, 6)
	local function background(place, read, name)
		local t = G.StateTexture(b, place, read)
		G.PlaceAtlas(t, name)
		t:ClearAllPoints()
		return t
	end
	background("SetNormalTexture", "GetNormalTexture", "common-button-square-gray-up"):SetAllPoints(b)
	local p = background("SetPushedTexture", "GetPushedTexture", "common-button-square-gray-down")
	p:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1)
	p:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 1, -1)
	background("SetDisabledTexture", "GetDisabledTexture", "common-button-square-gray-up"):SetAllPoints(b)

	local ic = b:CreateTexture(nil, layer or "ARTWORK")
	G.PlaceAtlas(ic, icon)
	ic:SetWidth(iconSize or 24)
	ic:SetHeight(iconSize or 24)
	ic:SetPoint("CENTER", b, "CENTER")
	b.foreverIcon = ic

	local h = G.StateTexture(b, "SetHighlightTexture", "GetHighlightTexture")
	G.PlaceAtlas(h, icon)
	h:SetBlendMode("ADD")
	h:SetAlpha(0.4)
	h:ClearAllPoints()
	h:SetPoint("TOPLEFT", ic, "TOPLEFT")
	h:SetPoint("BOTTOMRIGHT", ic, "BOTTOMRIGHT")

	G.Hook(b, "OnMouseDown", function(self)
		if G.Truthy(self:IsEnabled()) then
			ic:SetPoint("CENTER", self, "CENTER", 1, -1)
		end
	end)
	G.Hook(b, "OnMouseUp", function(self)
		ic:SetPoint("CENTER", self, "CENTER")
	end)
	return b
end

-- ------------------------------------------------------------ Scroll bar

-- Minimal scroll bar: 8 wide; track from (0, -19) to (0, 19); thumb sized to the visible
-- part (at least 23); arrows shifted (1, -1) when pressed, desaturated when disabled, the
-- whole bar hidden when everything fits (bar.hideIfUnneeded). Caller: Configure(total, visible, position).
function G.MinimalBar(parent, name)
	local bar = CreateFrame("Frame", name, parent)
	bar:SetWidth(8)
	bar.total, bar.visible, bar.position, bar.step = 0, 0, 0, 0

	local track = CreateFrame("Frame", nil, bar)
	track:SetWidth(8)
	track:SetPoint("TOP", bar, "TOP", 0, -19)
	track:SetPoint("BOTTOM", bar, "BOTTOM", 0, 19)
	track:EnableMouse(true)
	local ph = track:CreateTexture(nil, "ARTWORK")
	G.PlaceAtlas(ph, "minimal-scrollbar-track-top", true)
	ph:SetPoint("TOPLEFT", track, "TOPLEFT")
	local pb = track:CreateTexture(nil, "ARTWORK")
	G.PlaceAtlas(pb, "minimal-scrollbar-track-bottom", true)
	pb:SetPoint("BOTTOMLEFT", track, "BOTTOMLEFT")
	local pm = track:CreateTexture(nil, "ARTWORK")
	G.PlaceAtlas(pm, "!minimal-scrollbar-track-middle", true)
	pm:SetPoint("TOPLEFT", ph, "BOTTOMLEFT")
	pm:SetPoint("BOTTOMRIGHT", pb, "TOPRIGHT")

	local cursor = CreateFrame("Button", nil, track)
	cursor:SetWidth(8)
	cursor:SetHitRectInsets(-4, -4, -4, -4)
	local ch = cursor:CreateTexture(nil, "ARTWORK")
	ch:SetPoint("TOPLEFT", cursor, "TOPLEFT")
	local cb = cursor:CreateTexture(nil, "ARTWORK")
	cb:SetPoint("BOTTOMLEFT", cursor, "BOTTOMLEFT")
	local cm = cursor:CreateTexture(nil, "ARTWORK")
	cm:SetPoint("TOPLEFT", ch, "BOTTOMLEFT")
	cm:SetPoint("BOTTOMRIGHT", cb, "TOPRIGHT")
	local function paintCursor(state)
		local s = state and ("-" .. state) or ""
		G.PlaceAtlas(ch, "minimal-scrollbar-small-thumb-top" .. s, true)
		G.PlaceAtlas(cb, "minimal-scrollbar-small-thumb-bottom" .. s, true)
		local e = G.PlaceAtlas(cm, "minimal-scrollbar-small-thumb-middle" .. s, true)
		-- the middle keeps its native scale instead of stretching (thumb OnSizeChanged)
		local h = math.max(0, (cursor:GetHeight() or 0) - ch:GetHeight() - cb:GetHeight())
		cm:SetTexCoord(e[2], e[3], e[4], e[4] + (e[5] - e[4]) * math.min(1, h / e[7]))
	end
	bar.cursor = cursor

	local function arrow(top)
		local base = top and "minimal-scrollbar-arrow-top" or "minimal-scrollbar-arrow-bottom"
		local f = CreateFrame("Button", nil, bar)
		local t = f:CreateTexture(nil, "ARTWORK")
		local e = G.PlaceAtlas(t, base, true)
		f:SetWidth(e[6])
		f:SetHeight(e[7])
		t:SetPoint("CENTER", f, "CENTER")
		f:SetPoint(top and "TOP" or "BOTTOM", bar, top and "TOP" or "BOTTOM")
		local function paint()
			local n = base
			local enabled = G.Truthy(f:IsEnabled())
			if enabled then
				if f.down then n = base .. "-down" elseif f.hovered then n = base .. "-over" end
			end
			G.PlaceAtlas(t, n, true)
			t:SetDesaturated(not enabled)
			t:ClearAllPoints()
			if f.down and enabled then
				t:SetPoint("CENTER", f, "CENTER", 1, -1)
			else
				t:SetPoint("CENTER", f, "CENTER")
			end
		end
		f:SetScript("OnEnter", function() f.hovered = true; paint() end)
		f:SetScript("OnLeave", function() f.hovered = false; paint() end)
		f:SetScript("OnMouseDown", function() f.down = true; paint() end)
		f:SetScript("OnMouseUp", function() f.down = false; paint() end)
		f:SetScript("OnClick", function()
			bar:MoveTo(bar.position + (top and -bar.step or bar.step))
		end)
		f.paint = paint
		return f
	end
	local build, descend = arrow(true), arrow(false)

	local function maximum()
		return math.max(0, bar.total - bar.visible)
	end

	function bar:Reposition()
		local travel = track:GetHeight() or 0
		local maxValue = maximum()
		if self.hideIfUnneeded then
			G.SetShown(self, maxValue > 0)
			-- when the bar appears or hides, bar.onVisibility(hasBar) lets the content resize
			if (maxValue > 0) ~= self.wasNeeded then
				self.wasNeeded = maxValue > 0
				if self.onVisibility then self.onVisibility(self.wasNeeded) end
			end
		end
		if maxValue <= 0 or travel <= 0 then
			cursor:Hide()
			build:Disable()
			descend:Disable()
		else
			local h = math.max(23, travel * self.visible / self.total)
			if h > travel then h = travel end
			cursor:SetHeight(h)
			cursor:ClearAllPoints()
			cursor:SetPoint("TOP", track, "TOP", 0, -(travel - h) * self.position / maxValue)
			cursor:Show()
			paintCursor(cursor.down and "down" or (cursor.hovered and "over" or nil))
			if self.position > 0 then build:Enable() else build:Disable() end
			if self.position < maxValue then descend:Enable() else descend:Disable() end
		end
		build.paint()
		descend.paint()
	end

	function bar:MoveTo(to)
		to = math.max(0, math.min(to, maximum()))
		if to == self.position then return end
		self.position = to
		self:Reposition()
		if self.onScroll then self.onScroll(to) end
	end

	function bar:Configure(total, visible, position)
		self.total, self.visible = total, visible
		self.position = math.max(0, math.min(position or 0, maximum()))
		self:Reposition()
	end

	-- drag the thumb (3.3.5 has no mouse tracking: poll in OnUpdate)
	local function mouseY()
		local _, y = GetCursorPosition()
		return y / (track:GetEffectiveScale() or 1)
	end
	cursor:SetScript("OnEnter", function(self) self.hovered = true; bar:Reposition() end)
	cursor:SetScript("OnLeave", function(self) self.hovered = false; bar:Reposition() end)
	cursor:SetScript("OnMouseDown", function(self)
		self.down = true
		self.grab, self.grabPos = mouseY(), bar.position
		self:SetScript("OnUpdate", function(me)
			local travel = (track:GetHeight() or 0) - (me:GetHeight() or 0)
			if travel > 0 then
				bar:MoveTo(me.grabPos + (me.grab - mouseY()) / travel * maximum())
			end
		end)
		bar:Reposition()
	end)
	cursor:SetScript("OnMouseUp", function(self)
		self.down = false
		self:SetScript("OnUpdate", nil)
		bar:Reposition()
	end)
	-- clicking the track moves one page toward the click
	track:SetScript("OnMouseDown", function()
		local y = mouseY()
		if cursor:IsShown() then
			if y > (cursor:GetTop() or 0) then
				bar:MoveTo(bar.position - bar.visible)
			elseif y < (cursor:GetBottom() or 0) then
				bar:MoveTo(bar.position + bar.visible)
			end
		end
	end)
	G.Hook(bar, "OnSizeChanged", function() bar:Reposition() end)
	return bar
end

-- ------------------------------------------------------------ Panel button

-- 3.3.5 returns 1 / nil, sometimes 0 / 1: zero is true in Lua
local function truthy(v)
	return v and v ~= 0 and true or false
end

-- UIPanelButtonTemplate: three pieces of UI-Panel-Button-Up (12 / rest / 12), -Down when
-- pressed, -Disabled when disabled; UI-Panel-Button-Highlight in ADD; centered text
local PANEL = "Interface\\Buttons\\UI-Panel-Button-"
function G.PanelButton(b)
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
	local function file(name)
		for _, v in ipairs(pieces) do
			v[1]:SetTexture(PANEL .. name)
			v[1]:SetTexCoord(v[2], v[3], 0, 0.6875)
		end
	end
	local function idle()
		file(truthy(b:IsEnabled()) and "Up" or "Disabled")
	end
	idle()
	G.Hook(b, "OnMouseDown", function()
		if truthy(b:IsEnabled()) then file("Down") end
	end)
	G.Hook(b, "OnMouseUp", idle)
	G.Hook(b, "OnShow", idle)
	G.Hook(b, "OnDisable", idle)
	G.Hook(b, "OnEnable", idle)
	local h = G.StateTexture(b, "SetHighlightTexture", "GetHighlightTexture")
	h:SetTexCoord(0, 0.625, 0, 0.6875)
	h:SetBlendMode("ADD")
	h:ClearAllPoints()
	h:SetAllPoints(b)
	b:SetNormalFontObject(G.Font("GameFontNormal"))
	b:SetHighlightFontObject(G.Font("GameFontHighlight"))
	b:SetDisabledFontObject(G.Font("GameFontDisable"))
	local text = b:GetFontString()
	if text then
		text:ClearAllPoints()
		text:SetPoint("CENTER", b, "CENTER", 0, 0)
	end
end
