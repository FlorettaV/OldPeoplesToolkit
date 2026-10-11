-- Bedtime: on work nights (Sunday to Thursday, weekends too if you like) a
-- heads-up 15 minutes before your bedtime, an alert when it's time, and the
-- debuff "Past Your Bedtime" until morning.
--
-- Saved in OldPeoplesToolkitDB.bedtime: enabled, minutes (bedtime, see the
-- note on times in Core.lua), weekends, showDebuff, warnedFor/alertedFor/
-- hiddenFor (which night the heads-up, the alert and right-click "hide it"
-- were for).

local _, ns = ...

local HEADS_UP = 15 * 60
local MORNING = 30 * 60 -- the night ends at 06:00 (in minutes after the evening's midnight)
local LIMITS = { 19 * 60, 27 * 60 } -- the bedtime slider: 19:00 to 03:00
ns.BEDTIME_LIMITS = LIMITS

-- Friday and Saturday evenings only count with "Weekends too".
local function CountsFor(evening)
	local weekday = date("*t", evening).wday -- 1 = Sunday ... 7 = Saturday
	return OldPeoplesToolkitDB.bedtime.weekends or (weekday ~= 6 and weekday ~= 7)
end

-- If it's past your bedtime right now: when bedtime was.
local function PastBedtime()
	local db = OldPeoplesToolkitDB.bedtime
	if not db.enabled then return nil end
	return (ns.Night(db.minutes, MORNING, CountsFor))
end

-- If bedtime is less than 15 minutes away: when it is.
local function BedtimeSoon()
	local db = OldPeoplesToolkitDB.bedtime
	if not db.enabled then return nil end
	local from = ns.Night(db.minutes - HEADS_UP / 60, db.minutes, CountsFor)
	return from and from + HEADS_UP
end

local function Check()
	local db = OldPeoplesToolkitDB.bedtime
	local soon = BedtimeSoon()
	if soon and db.warnedFor ~= soon then
		db.warnedFor = soon
		ns.Alert("Bedtime in " .. ns.Duration(soon - time() + 59) .. ". Time to wrap up.",
			SOUNDKIT and SOUNDKIT.ALARM_CLOCK_WARNING_2)
	end
	local past = PastBedtime()
	if past and db.alertedFor ~= past then
		db.alertedFor = past
		-- Only right at bedtime, not when you log in at 01:00 (you know).
		if time() - past < 5 * 60 then
			ns.Alert("It's past your bedtime!", SOUNDKIT and SOUNDKIT.RAID_WARNING)
		end
	end
end

---------------------------------------------------------------------------
-- "Past Your Bedtime" (drawn by Auras.lua)
---------------------------------------------------------------------------

ns.AddIconSlot("bedtime", "Past Your Bedtime", "Interface\\Icons\\Spell_Nature_Sleep")

ns.AddAura({
	key = "bedtime",
	State = function()
		local db, past = OldPeoplesToolkitDB.bedtime, PastBedtime()
		if not past or not db.showDebuff or db.hiddenFor == past then return nil end
		return true, "bedtime", 0
	end,
	Tooltip = function()
		return "Tomorrow's Stamina reduced by 5% for every minute you stay up.",
			"Bedtime was " .. ns.Duration(time() - PastBedtime()) .. " ago"
	end,
	hint = "Right-click: hide it for tonight",
	OnRightClick = function()
		OldPeoplesToolkitDB.bedtime.hiddenFor = PastBedtime()
		ns.UpdateAuras()
	end,
})

---------------------------------------------------------------------------
-- Used by the clock's tooltip and /oldperson bedtime
---------------------------------------------------------------------------

-- "Bedtime at 23:00", or nil when it's off or not tonight.
function ns.BedtimeText()
	local db = OldPeoplesToolkitDB.bedtime
	if not db.enabled or PastBedtime() or not CountsFor(ns.Midnight()) then return nil end
	return "Bedtime at " .. ns.MinutesText(db.minutes)
end

-- A time like "23:30" or "11:30pm". Returns false if it isn't one.
function ns.BedtimeCommand(args)
	local hour, minute, ampm = args:gsub("%s+", ""):match("^(%d%d?)[:%.]?(%d*)([ap]?)m?$")
	hour, minute = tonumber(hour), tonumber(minute) or 0
	if not hour or hour > 23 or minute > 59 then return false end
	if ampm == "p" and hour < 12 then hour = hour + 12 elseif ampm == "a" and hour == 12 then hour = 0 end
	local minutes = hour * 60 + minute
	if minutes < LIMITS[1] then minutes = minutes + 24 * 60 end -- 00:30 is after midnight
	if minutes < LIMITS[1] or minutes > LIMITS[2] then
		ns.Print("bedtime can be from " .. ns.MinutesText(LIMITS[1]) .. " to " .. ns.MinutesText(LIMITS[2]) .. ".")
		return true
	end
	local db = OldPeoplesToolkitDB.bedtime
	db.minutes, db.enabled = minutes, true
	ns.Print("bedtime at " .. ns.MinutesText(minutes) .. ". No staying up late!")
	ns.UpdateAuras()
	return true
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function()
	Check()
	C_Timer.NewTicker(10, Check)
end)
