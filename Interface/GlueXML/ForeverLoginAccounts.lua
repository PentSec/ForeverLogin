-- Saved accounts: a dropdown between the account and the password fields, one row per account
-- logged into, newest first; picking one fills both fields. The list lives in the client's own
-- saved account list (SetSavedAccountList / GetSavedAccountList, the accountList CVar of
-- Config.wtf): that is the one string a glue screen can persist, as a custom CVar cannot be
-- registered here. Records are name|password joined by ;, with %, ;, | and " escaped as %XX.
-- The password is stored in clear text there, like the client's own saved account.

local G = ForeverLogin
local ui = AccountLoginUI
local count = AccountLoginAccountEdit
local password = AccountLoginPasswordEdit
local rememberName = AccountLoginSaveAccountName
-- the "remember password" toggle is not on every 3.3.5 client
local rememberPassword = AccountLoginSavePassword

local MAX = 8
local WIDTH = 320
-- GlueDropDownMenuTemplate boxes its text between two 25 wide caps
local CAPS = 50

-- ------------------------------------------------------------ Store

-- Pure over the list string: encode and decode round-trip, no duplicates, newest first.

local function escape(s)
	return (string.gsub(s, "[%%;|\"]", function(c) return string.format("%%%02X", string.byte(c)) end))
end

local function unescape(s)
	return (string.gsub(s, "%%(%x%x)", function(hex) return string.char(tonumber(hex, 16)) end))
end

local function encode(accounts)
	local records = {}
	for i, account in ipairs(accounts) do
		records[i] = escape(account.name) .. "|" .. escape(account.password or "")
	end
	return table.concat(records, ";")
end

local function decode(raw)
	local accounts = {}
	for record in string.gmatch(raw or "", "([^;]+)") do
		local name, pass = string.match(record, "^([^|]*)|(.*)$")
		-- the client marks the account it has selected with a leading !
		name = name and string.gsub(name, "^!", "") or nil
		if name and name ~= "" then
			name, pass = unescape(name), unescape(pass)
			accounts[#accounts + 1] = { name = name, password = pass ~= "" and pass or nil }
		end
	end
	return accounts
end

-- The client's saved account list, read and written whole. It is a list of strings, so it takes
-- our records as they are; the client only ever clears it (see the OnHide hook below).
local accounts = {}

local function read()
	if not GetSavedAccountList then
		return nil
	end
	local ok, value = pcall(GetSavedAccountList)
	return ok and value or nil
end

local function write(value)
	if not SetSavedAccountList then
		return
	end
	pcall(SetSavedAccountList, value or "")
end

local function load()
	accounts = decode(read())
	return accounts
end

-- The screen is read on every show, but the client can log in on its own on the first one
-- (auto login), before the OnShow hooks: the list is read here when it was never read.
local function current()
	if #accounts == 0 then
		load()
	end
	return accounts
end

local function store()
	write(encode(accounts))
	return accounts
end

-- The account goes first, an older entry of the same name is dropped and the oldest fall off
-- at MAX.
local function save(name, pass)
	current()
	if not name or name == "" then
		return accounts
	end
	for i = #accounts, 1, -1 do
		if accounts[i].name == name then
			table.remove(accounts, i)
		end
	end
	table.insert(accounts, 1, { name = name, password = pass })
	while #accounts > MAX do
		table.remove(accounts)
	end
	return store()
end

local function remove(name)
	current()
	if not name or name == "" then
		return accounts
	end
	for i = #accounts, 1, -1 do
		if accounts[i].name == name then
			table.remove(accounts, i)
		end
	end
	return store()
end

-- ------------------------------------------------------------ Dropdown

local dd = CreateFrame("Frame", "ForeverLoginAccountsDropDown", ui, "GlueDropDownMenuTemplate")
dd:SetWidth(WIDTH)
dd:SetHeight(32)
local middle = _G[dd:GetName() .. "Middle"]
if middle then
	middle:SetWidth(WIDTH - CAPS)
end
G.SkinDropDown(dd)
dd:Hide()

-- ------------------------------------------------------------ Warning
-- A pick only fills the fields: the two toggles stay as the user left them, so the account (or
-- its saved password) can be gone at login. When that is about to happen, the sentence says so;
-- the layout in ForeverLoginAccountLogin.lua keeps it above the account label.

local notice = ui:CreateFontString(nil, "ARTWORK")
notice:SetFontObject(G.Font("GlueFontNormalSmall"))
notice:SetTextColor(1, 0.25, 0.25)
notice:SetWidth(WIDTH)
notice:SetJustifyH("CENTER")
notice:Hide()

-- the caption the client shows next to a check box
local function caption(frame)
	local text = frame and _G[frame:GetName() .. "Text"]
	return text and text:GetText() or ""
end

local function ticked(frame)
	return frame and G.Truthy(frame:GetChecked()) or false
end

-- Which of the saved accounts is in the field, if any
local function inField()
	local name = count:GetText()
	for _, account in ipairs(accounts) do
		if account.name == name then
			return account
		end
	end
end

local function warn()
	local account = rememberName and inField()
	local text
	if account then
		if not ticked(rememberName) then
			text = G.L.ACCOUNTLOGIN_DROPS_ACCOUNT:format(caption(rememberName))
		elseif account.password and not ticked(rememberPassword) then
			text = G.L.ACCOUNTLOGIN_DROPS_PASSWORD:format(caption(rememberPassword))
		end
	end
	notice:SetText(text or "")
	G.SetShown(notice, text ~= nil)
end

local function pick(account)
	count:SetText(account.name)
	password:SetText(account.password or "")
	dd.selectedName = account.name
	GlueDropDownMenu_SetText(account.name, dd)
	warn()
end

-- Called on every open: the list is rebuilt from the store, so a saved account shows at once.
local function initialize()
	for _, account in ipairs(load()) do
		local info = GlueDropDownMenu_CreateInfo()
		info.text = account.name
		info.value = account.name
		info.func = function()
			pick(account)
		end
		GlueDropDownMenu_AddButton(info)
	end
end

GlueDropDownMenu_Initialize(dd, initialize)

-- Nothing saved: the dropdown goes away and the password field moves back up (what the client
-- itself does with its own list dropdown). Otherwise it names the account already in the field,
-- or the newest one, and hands the list over to the menu.
local function refresh()
	local button = _G[dd:GetName() .. "Button"]
	if #accounts == 0 then
		if button then button:Disable() end
		dd:Hide()
		warn()
		return
	end
	if button then button:Enable() end
	local shown = count:GetText()
	local named = false
	for _, account in ipairs(accounts) do
		named = named or account.name == shown
	end
	local selected = named and shown or accounts[1].name
	dd.selectedName = selected
	GlueDropDownMenu_SetText(selected, dd)
	dd:Show()
	warn()
end

-- After the client's own save: with "remember account name" the account is kept in the list
-- (the password only with "remember password"), otherwise it is dropped, as the client drops
-- its own saved account.
local function onLogin()
	local name = count:GetText()
	if not name or name == "" then
		return
	end
	if rememberName and G.Truthy(rememberName:GetChecked()) then
		local pass
		if rememberPassword and G.Truthy(rememberPassword:GetChecked()) then
			pass = password:GetText()
		end
		save(name, pass)
	else
		remove(name)
	end
	refresh()
end

G.HookFunction("AccountLogin_Login", onLogin)

-- ticking or unticking either box changes what the login will do with the account in the field
G.Hook(rememberName, "OnClick", warn)
if rememberPassword then
	G.Hook(rememberPassword, "OnClick", warn)
end

-- On each show, after the client has filled the fields and built its own list: ours is read
-- back and the dropdown follows the field.
G.Hook(AccountLogin, "OnShow", function()
	load()
	refresh()
end)

-- The client clears the list on hide when "remember account name" is off: ours is written back
-- after it, so only the account that login dropped is gone, not all of them.
G.Hook(AccountLogin, "OnHide", function()
	if #accounts > 0 then
		store()
	end
end)

G.Accounts = {
	DropDown = dd,
	Notice = notice,
	Refresh = refresh,
	Warn = warn,
	OnLogin = onLogin,
	Load = load,
	Save = save,
	Remove = remove,
	Encode = encode,
	Decode = decode,
}
