-- Auras: pretend buffs and debuffs next to your real ones. The tools add their
-- own (Stretch.lua: Fresh as a Daisy / Second Wind / Stiff Joints, Alarm.lua:
-- Responsibilities, Bedtime.lua: Past Your Bedtime, QuietHours.lua:
-- Earmuffs); this file only draws and places them.
--
-- Addons can't give your character real buffs (those come from the server),
-- so these are our own icons that look like them. They sit at the end of
-- Blizzard's buff or debuff row and follow it as auras come and go. We can't
-- put them *in* Blizzard's rows (those buttons are protected), so real ones
-- don't make room for them.

local _, ns = ...

local auras = {} -- in the order they were added, which is the order they line up in
local frames = {} -- [aura] = its icon

---------------------------------------------------------------------------
-- For the tools
---------------------------------------------------------------------------

-- aura = {
--   key = "stretch",
--   State = function() return nil (hidden) or isDebuff, kind (its icon slot), secondsLeft,
--                              name (optional: instead of the icon slot's name) end,
--   Tooltip = function(isDebuff, secondsLeft) return description, extra (optional) end,
--   hint = "Right-click: ...",
--   OnRightClick = function() end,
-- }
-- The tooltip shows the name (white for a buff, red for a debuff),
-- the description in yellow, the extra line in white, and the hint.
-- Like a real buff: the description is what it "does" ("Game volume reduced
-- to 25%"), the extra line is about time ("23 minutes remaining", "Until 07:00").
function ns.AddAura(aura)
	table.insert(auras, aura)
end

-- Icons you can pick with /oldperson ... icon. Saved in OldPeoplesToolkitDB.icons[kind].
local iconSlots = {} -- [kind] = { name = "Stiff Joints", default = icon }

-- default: an icon, or a function that picks one (like per faction).
function ns.AddIconSlot(kind, name, default)
	iconSlots[kind] = { name = name, default = default }
end

local function Icon(kind)
	local default = iconSlots[kind].default
	if type(default) == "function" then default = default() end
	return OldPeoplesToolkitDB.icons[kind] or default
end

-- name: an icon name from wowhead.com/icons, a file ID number, or "reset" for
-- the default.
function ns.SetIcon(kind, name)
	local icon
	if name ~= "reset" then
		icon = tonumber(name) or ("Interface\\Icons\\" .. (name:gsub("^.*[/\\]", ""))) -- drop any folder part
	end
	OldPeoplesToolkitDB.icons[kind] = icon
	-- A preview right in chat. An empty or green square means the game
	-- doesn't have an icon by that name.
	ns.Print(string.format("%s icon is now |T%s:24|t%s", iconSlots[kind].name, tostring(Icon(kind)),
		icon and "" or " (the default)"))
	ns.UpdateAuras()
end

---------------------------------------------------------------------------
-- Finding the end of Blizzard's buff and debuff rows
---------------------------------------------------------------------------

-- The placeholder slots Blizzard keeps for special ("private") debuffs, like
-- DebuffFrame.privateAuraAnchor1. They aren't real debuffs, so we skip them.
local function PrivateAnchors(container)
	local anchors = {}
	for key, value in pairs(container) do
		if key == "privateAuraAnchors" and type(value) == "table" then -- a list of them
			for _, anchor in pairs(value) do anchors[anchor] = true end
		elseif type(key) == "string" and key:find("^privateAuraAnchor%d") then -- privateAuraAnchor1, 2, ...
			anchors[value] = true
		end
	end
	return anchors
end

-- A real aura button shows a picture. Empty slots don't.
local function HasIcon(f)
	local icon = f.Icon or f.icon
	if not (icon and icon.GetTexture) then return true end -- can't tell, so count it
	local ok, texture = pcall(icon.GetTexture, icon)
	if not ok or (issecretvalue and issecretvalue(texture)) then return true end
	return texture ~= nil
end

-- The icons showing right now in BuffFrame or DebuffFrame.
local function AuraIcons(container)
	local icons = {}
	if not container then return icons end
	local list = container.auraFrames
	if type(list) ~= "table" and container.AuraContainer then
		list = { container.AuraContainer:GetChildren() }
	end
	local private = PrivateAnchors(container)
	for _, f in ipairs(type(list) == "table" and list or {}) do
		if type(f) == "table" and not private[f] and f.IsShown and f:IsShown() and f:GetLeft() and f:GetTop()
			and HasIcon(f) then
			table.insert(icons, f)
		end
	end
	return icons
end

-- The last icon of the top row: they grow to the left, so the leftmost one.
local function LastIcon(container)
	local last
	for _, f in ipairs(AuraIcons(container)) do
		if not last or f:GetTop() > last:GetTop() + 5 then
			last = f -- a higher row
		elseif math.abs(f:GetTop() - last:GetTop()) <= 5 and f:GetLeft() < last:GetLeft() then
			last = f
		end
	end
	return last
end

-- Where something is on screen, in UIParent's coordinates.
local function ScreenPoint(frame, x, y)
	local scale = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
	return x * scale, y * scale
end

-- The top-right corner where the first pretend aura in this row goes.
local function RowEnd(container)
	local last = LastIcon(container)
	if last then
		local x, y = ScreenPoint(last, last:GetLeft(), last:GetTop())
		return x - 6, y
	elseif container and container:GetRight() then
		-- None at all: take the spot where the first one would be.
		return ScreenPoint(container, container:GetRight(), container:GetTop())
	end
	return UIParent:GetRight() - 220, UIParent:GetTop() - 12
end

---------------------------------------------------------------------------
-- Our icons
---------------------------------------------------------------------------

local SIZE, GAP = 30, 6

local function ShowTooltip(f)
	GameTooltip:SetOwner(f, "ANCHOR_BOTTOMLEFT")
	local description, extra = f.aura.Tooltip(f.isDebuff, f.remaining)
	GameTooltip:AddLine(f.name or iconSlots[f.kind].name, ns.RGB(f.isDebuff and ns.RED or ns.WHITE))
	local r, g, b = ns.RGB(ns.GOLD)
	GameTooltip:AddLine(description, r, g, b, true) -- true: wrap long lines
	if extra then GameTooltip:AddLine(extra, ns.RGB(ns.WHITE)) end
	ns.AddHint(f.aura.hint)
	GameTooltip:Show()
end

local function CreateIcon(aura)
	local f = CreateFrame("Button", "OldPeoplesToolkitAura_" .. aura.key, UIParent)
	f:SetSize(SIZE, SIZE)
	f:SetFrameStrata("LOW")
	f:RegisterForClicks("RightButtonUp")
	f.aura = aura

	f.icon = f:CreateTexture(nil, "ARTWORK")
	f.icon:SetAllPoints()

	-- The red border Blizzard puts around debuffs.
	f.border = f:CreateTexture(nil, "OVERLAY")
	f.border:SetTexture("Interface\\Buttons\\UI-Debuff-Overlays")
	f.border:SetTexCoord(0.296875, 0.5703125, 0, 0.515625)
	f.border:SetPoint("TOPLEFT", -1, 1)
	f.border:SetPoint("BOTTOMRIGHT", 1, -1)
	f.border:SetVertexColor(0.8, 0, 0)

	f.time = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	f.time:SetPoint("TOP", f, "BOTTOM", 0, -2)

	f:SetScript("OnClick", function() aura.OnRightClick() end)
	f:SetScript("OnEnter", ShowTooltip)
	f:SetScript("OnLeave", GameTooltip_Hide)
	f:Hide()
	frames[aura] = f
end

-- Lines up the shown icons after the real buffs and debuffs, one after
-- another. We only read where Blizzard's icons are and never anchor to them,
-- so they stay untouched.
local function Place()
	-- In combat the game may hide where Blizzard's buttons are, so icons that
	-- already have a spot stay put until the fight is over (the 1-second
	-- update moves them right after). New ones still get a spot.
	local inCombat = InCombatLockdown()
	local nextSpot = {} -- [container] = x, y for the next icon in that row
	for _, aura in ipairs(auras) do
		local f = frames[aura]
		if f:IsShown() then
			local container = f.isDebuff and DebuffFrame or BuffFrame
			local spot = nextSpot[container] or { RowEnd(container) }
			if not (inCombat and f:GetNumPoints() > 0) then
				f:ClearAllPoints()
				f:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", spot[1], spot[2])
			end
			nextSpot[container] = { spot[1] - SIZE - GAP, spot[2] }
		end
	end
end

local function Update()
	for _, aura in ipairs(auras) do
		local f = frames[aura]
		local isDebuff, kind, remaining, name = aura.State()
		if isDebuff == nil then
			f:Hide()
		else
			f.isDebuff, f.kind, f.remaining, f.name = isDebuff, kind, remaining, name
			f.icon:SetTexture(Icon(kind))
			f.border:SetShown(isDebuff)
			f.time:SetText(remaining > 0 and ns.ShortTime(remaining) or "")
			f:Show()
			if GameTooltip:IsOwned(f) then ShowTooltip(f) end -- keep the tooltip's time ticking
		end
	end
	Place() -- also catches Edit Mode moving the buff frames
end

-- The tools call this when something changed, so it shows right away
-- instead of at the next 1-second update.
function ns.UpdateAuras()
	if next(frames) then Update() end
end

-- /oldperson debug: what we think is in each row, to check the placement.
function ns.DebugAuras()
	for _, name in ipairs({ "BuffFrame", "DebuffFrame" }) do
		local container = _G[name]
		if not container then
			print(name .. ": not found")
		else
			print(name .. string.format(": right edge %.0f, auraFrames is a %s", container:GetRight() or -1,
				type(container.auraFrames)))
			for i, f in ipairs(AuraIcons(container)) do
				print(string.format("  %d. %s at left %.0f, top %.0f", i, f:GetDebugName(), f:GetLeft(), f:GetTop()))
			end
		end
	end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterUnitEvent("UNIT_AURA", "player")
events:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_LOGIN" then
		for _, aura in ipairs(auras) do CreateIcon(aura) end
		Update()
		C_Timer.NewTicker(1, Update)
	elseif next(frames) then
		-- A buff came or went: move along once Blizzard has redrawn the row.
		C_Timer.After(0.1, Place)
	end
end)
