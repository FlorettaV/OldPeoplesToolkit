-- Core: what all the tools share. Chat messages, the saved settings (with
-- their defaults) and the ways we write times.
--
-- The tools, one file each:
--   WhereWasI.lua   after a while away: where you were, your quests and your bags
--   Scrolls.lua     Scrolls of Remembering, a notebook for things you'll forget
--                   (with ScrollsCreatures.lua and ScrollsSpell.lua)
--   QuietHours.lua  turns the volume down at night
--   Stretch.lua     Old People's Stretch, the stretch reminder
--   Clock.lua       the clock (and hiding Blizzard's small minimap clock)
--   Alarm.lua       "I've got 15 minutes" / "I can play until 22:30"
--   Bedtime.lua     a heads-up and "Past Your Bedtime" on work nights
-- Shared by them:
--   Auras.lua    pretend buffs and debuffs next to your real ones
--   Minimap.lua, Options.lua, Commands.lua

local ADDON_NAME, ns = ...
-- For helper addons that aren't released, like OldPeoplesToolkit_Screenshots.
OldPeoplesToolkit_Internal = ns

-- Everything saved in OldPeoplesToolkitDB. Each tool's comments explain its part.
local defaults = {
	clock = { show = true, point = "TOP", x = 0, y = -12, scale = 1.2, hideBlizzardClock = true },
	alarm = { rowShown = false, at = nil, setAs = nil, warned = false, finished = false, showDebuff = true },
	stretch = { enabled = true, intervalMinutes = 60, snoozeMinutes = 5, waitSeconds = 10, showBuff = true },
	-- Times of day are in minutes after midnight; for the evening ones a value
	-- over 1440 means after midnight (1470 = 00:30).
	bedtime = { enabled = true, minutes = 23 * 60, weekends = false, showDebuff = true },
	quiet = { enabled = true, start = 23 * 60, stop = 7 * 60, volume = 25, showBuff = true },
	whereWasI = { enabled = true, awayHours = 8, characters = {} },
	-- Also learned (the "You have learned a new spell" line was shown) and
	-- point (where you dragged the scroll); see Scrolls.lua.
	scrolls = { enabled = true, notes = {} },
	icons = {}, -- your own picks for the pretend (de)buffs, see Auras.lua
	minimapButton = { show = true, angle = 200 },
}
ns.DEFAULTS = defaults

-- Colors, the same in every tool, each with one meaning. In text:
-- ns.GOLD .. "word" .. "|r". For SetTextColor or AddLine: ns.RGB(ns.GOLD).
ns.GOLD = "|cffffd100" -- names, the important bit of a sentence, a buff's description
ns.WHITE = "|cffffffff" -- plain facts: a buff's time left, the date
ns.GREEN = "|cff40ff40" -- good or running: an alarm that's set, "ready to turn in"
ns.ORANGE = "|cffff8c1a" -- almost: the alarm's last 5 minutes
ns.RED = "|cffff4040" -- time's up, and a debuff's name
ns.GREY = "|cff999999" -- dimmed: no alarm, quest objectives
ns.HINT = "|cffcccccc" -- tooltip lines that explain how things work
ns.ACTION = "|cff66ccff" -- what you do: the "Right-click:" in a hint, a command to type

-- "|cffffd100" -> 1, 0.82, 0
function ns.RGB(color)
	local r, g, b = color:match("^|cff(%x%x)(%x%x)(%x%x)$")
	return tonumber(r, 16) / 255, tonumber(g, 16) / 255, tonumber(b, 16) / 255
end

-- A tooltip line like "Right-click: clear the alarm": what you do in blue,
-- what it does in grey. A line without "Action:" is all grey.
function ns.AddHint(text)
	local action, result = text:match("^(.-): (.*)$")
	GameTooltip:AddLine(action and (ns.ACTION .. action .. ":|r " .. result) or text, ns.RGB(ns.HINT))
end

function ns.Print(msg)
	print(ns.GOLD .. "Toolkit:|r " .. msg)
end

local function ApplyDefaults(target, source)
	for key, value in pairs(source) do
		if type(value) == "table" then
			if type(target[key]) ~= "table" then target[key] = {} end
			ApplyDefaults(target[key], value)
		elseif target[key] == nil then
			target[key] = value
		end
	end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(_, _, name)
	if name ~= ADDON_NAME then return end
	OldPeoplesToolkitDB = OldPeoplesToolkitDB or {}
	-- Settings of tools that no longer exist go.
	for key in pairs(OldPeoplesToolkitDB) do
		if defaults[key] == nil then OldPeoplesToolkitDB[key] = nil end
	end
	ApplyDefaults(OldPeoplesToolkitDB, defaults)
	events:UnregisterEvent("ADDON_LOADED")
end)

---------------------------------------------------------------------------
-- Writing times. Each place uses the one that reads best there.
---------------------------------------------------------------------------

-- The time of day, "22:30" or "10:30 PM", following Blizzard's own 24-hour
-- setting (right-click the clock to change it). Without t: right now.
function ns.ClockText(t)
	if GetCVarBool("timeMgrUseMilitaryTime") then
		return date("%H:%M", t)
	end
	return (date("%I:%M %p", t):gsub("^0", "")) -- "9:05 PM", not "09:05 PM"
end

-- A countdown, like on a timer: "14:32", "1:02:03".
function ns.Countdown(seconds)
	local hours, minutes, secs = math.floor(seconds / 3600), math.floor(seconds / 60) % 60, seconds % 60
	if hours > 0 then
		return string.format("%d:%02d:%02d", hours, minutes, secs)
	end
	return string.format("%02d:%02d", minutes, secs)
end

-- In a sentence: "1 hour", "1 hour 5 minutes", "45 minutes", "less than a minute".
function ns.Duration(seconds)
	if seconds < 60 then return "less than a minute" end
	local minutes = math.floor(seconds / 60)
	local hours, rest = math.floor(minutes / 60), minutes % 60
	local parts = {}
	if hours > 0 then table.insert(parts, hours == 1 and "1 hour" or (hours .. " hours")) end
	if rest > 0 or hours == 0 then table.insert(parts, rest == 1 and "1 minute" or (rest .. " minutes")) end
	return table.concat(parts, " ")
end

-- Short, like under Blizzard's buff icons: "23 m", "45 s".
function ns.ShortTime(seconds)
	if SecondsToTimeAbbrev then
		return string.format(SecondsToTimeAbbrev(seconds))
	end
	if seconds >= 3600 then return math.ceil(seconds / 3600) .. " h" end
	if seconds >= 60 then return math.ceil(seconds / 60) .. " m" end
	return seconds .. " s"
end

-- Minutes after midnight as a time of day: 1380 -> "23:00", 1470 -> "00:30".
function ns.MinutesText(minutes)
	return ns.ClockText(ns.Midnight() + minutes * 60)
end

-- The timestamp of midnight at the start of the day t is in (default: today).
function ns.Midnight(t)
	local d = date("*t", t)
	d.hour, d.min, d.sec = 0, 0, 0
	return time(d)
end

-- For things that happen at night, from an evening time until a time the
-- next morning (both in minutes after the evening's midnight, so the end is
-- over 1440). If it's that time of night right now, returns when it started
-- and when it ends. Nights started yesterday evening count too (it's 01:00).
-- countsFor(evening): optional, whether that evening's night counts at all.
function ns.Night(startMinutes, endMinutes, countsFor)
	local today = ns.Midnight()
	for _, evening in ipairs({ today, ns.Midnight(today - 12 * 3600) }) do
		local from, to = evening + startMinutes * 60, evening + endMinutes * 60
		if time() >= from and time() < to and (not countsFor or countsFor(evening)) then
			return from, to
		end
	end
end

-- Sound, a big message in the middle of the screen, a line in chat and a
-- blinking taskbar icon if you're tabbed out.
function ns.Alert(message, sound)
	if sound then PlaySound(sound, "Master") end
	if RaidNotice_AddMessage and RaidWarningFrame and ChatTypeInfo then
		RaidNotice_AddMessage(RaidWarningFrame, message, ChatTypeInfo["RAID_WARNING"])
	end
	if FlashClientIcon then FlashClientIcon() end
	ns.Print(message)
end

-- Forever uses Midnight's "secret values": some API results can't be read by
-- addons (mostly during combat). Treat those as missing.
function ns.Usable(value)
	if value == nil then return false end
	if issecretvalue and issecretvalue(value) then return false end
	return true
end

-- Calls a WoW function that may be missing, fail or give a secret value.
-- Returns its first result, or nil.
function ns.Safe(fn, ...)
	if not fn then return nil end
	local ok, result = pcall(fn, ...)
	if ok and ns.Usable(result) then return result end
end

-- A window in the style of Blizzard's dialogs, that you can drag around. The
-- height is up to the tool, so it can grow to fit the text.
function ns.CreateDialog(name, width)
	local dialog = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
	dialog:SetWidth(width)
	dialog:SetFrameStrata("DIALOG")
	dialog:SetToplevel(true)
	dialog:EnableMouse(true)
	dialog:SetMovable(true)
	dialog:SetClampedToScreen(true)
	dialog:RegisterForDrag("LeftButton")
	dialog:SetScript("OnDragStart", dialog.StartMoving)
	dialog:SetScript("OnDragStop", dialog.StopMovingOrSizing)
	dialog:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = true, tileSize = 32, edgeSize = 32,
		insets = { left = 11, right = 12, top = 12, bottom = 11 },
	})
	dialog:Hide()
	return dialog
end
