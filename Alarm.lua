-- Alarm: for "I've got 15 minutes" or "I can play until 22:30". It folds out
-- under the clock, gives a heads-up 5 minutes before, and while it's set
-- "Responsibilities" sits with your debuffs. It keeps working while the clock
-- is hidden.
--
-- Saved in OldPeoplesToolkitDB.alarm:
--   at         when it goes off, as a real-world timestamp, so it survives
--              /reload and logging out. nil means no alarm.
--   setAs      "duration" ("15", "1h30") or "time" ("22:30"), so it's shown
--              the same way you typed it
--   warned     the 5-minute heads-up was given
--   finished   it went off and is waiting for you to clear it
--   rowShown   the alarm row under the clock is folded out (Clock.lua)
--   showDebuff show "Responsibilities"

local _, ns = ...

local HEADS_UP = 5 * 60 -- warn this long before the alarm goes off

local row

---------------------------------------------------------------------------
-- Reading what you type
---------------------------------------------------------------------------

-- The next time the clock shows hour:minute (today, or else tomorrow).
local function NextTimeOfDay(hour, minute)
	local t = date("*t")
	t.hour, t.min, t.sec = hour, minute, 0
	local at = time(t)
	if at <= time() then at = at + 24 * 3600 end
	return at
end

-- What you type, turned into the moment the alarm goes off, and whether you
-- typed a duration or a time:
--   "15", "15m", "1h", "1h30"    -> that long from now ("duration")
--   "22:30", "9:30pm", "10pm"     -> at that time ("time")
-- On a 12-hour clock "9:30" means whichever 9:30 comes first.
local function ParseAlarm(text)
	text = strtrim(text or ""):lower():gsub("%s+", "")
	local minutes = tonumber(text:match("^(%d+)m?$"))
	if minutes then
		if minutes == 0 then return nil end
		return time() + minutes * 60, "duration"
	end
	local hours, mins = text:match("^(%d+)h(%d*)m?$")
	if hours then return time() + (tonumber(hours) * 60 + (tonumber(mins) or 0)) * 60, "duration" end

	local hour, minute, ampm = text:match("^(%d%d?)[:%.](%d%d)([ap]?)m?$")
	if not hour then
		hour, ampm = text:match("^(%d%d?)([ap])m?$")
		minute = "0"
	end
	hour, minute = tonumber(hour), tonumber(minute)
	if not hour or hour > 23 or minute > 59 then return nil end
	if ampm ~= "" then
		if hour < 1 or hour > 12 then return nil end
		return NextTimeOfDay(hour % 12 + (ampm == "p" and 12 or 0), minute), "time"
	end
	if GetCVarBool("timeMgrUseMilitaryTime") or hour > 12 or hour == 0 then
		return NextTimeOfDay(hour, minute), "time"
	end
	return math.min(NextTimeOfDay(hour % 12, minute), NextTimeOfDay(hour % 12 + 12, minute)), "time"
end

---------------------------------------------------------------------------
-- Setting it and going off
---------------------------------------------------------------------------

-- Colors: grey = no alarm, green = running, orange = last 5 minutes,
-- red = time's up.
local function UpdateRow()
	if not row or not row:IsShown() then return end
	local alarm = OldPeoplesToolkitDB.alarm
	if not alarm.at then
		row.text:SetText("--:--")
		row.text:SetTextColor(ns.RGB(ns.GREY))
		row.untilText:SetText("no alarm")
		row.button:SetText("Set")
		return
	end
	local left = math.max(alarm.at - time(), 0)
	row.text:SetText(ns.Countdown(left))
	if alarm.finished then
		row.text:SetTextColor(ns.RGB(ns.RED))
	elseif left <= HEADS_UP then
		row.text:SetTextColor(ns.RGB(ns.ORANGE))
	else
		row.text:SetTextColor(ns.RGB(ns.GREEN))
	end
	row.untilText:SetText("until " .. ns.ClockText(alarm.at))
	row.button:SetText("Clear")
end

local function SetAlarm(at, setAs)
	local alarm = OldPeoplesToolkitDB.alarm
	alarm.at, alarm.setAs, alarm.finished = at, at and (setAs or "duration"), false
	-- No heads-up for alarms that are already less than 5 minutes away.
	alarm.warned = not at or at - time() <= HEADS_UP
	if at then ns.ShowAlarmRow(true) end
	UpdateRow()
	ns.UpdateAuras()
end

local function Check()
	local alarm = OldPeoplesToolkitDB.alarm
	if alarm.at and not alarm.finished then
		local left = alarm.at - time()
		if left <= 0 then
			alarm.finished = true
			ns.Alert("Time's up! I must go, my people need me!", SOUNDKIT and SOUNDKIT.RAID_WARNING)
			ns.ShowAlarmRow(true) -- so you see the red 00:00, even if it was folded away
		elseif left <= HEADS_UP and not alarm.warned then
			alarm.warned = true
			ns.Alert("5 minutes left! Time to wrap up.", SOUNDKIT and SOUNDKIT.ALARM_CLOCK_WARNING_2)
		end
	end
	UpdateRow()
end

---------------------------------------------------------------------------
-- The alarm row under the clock
---------------------------------------------------------------------------

-- Clock.lua puts it in place and folds it out or in.
function ns.CreateAlarmRow(parent, width)
	row = CreateFrame("Frame", nil, parent)
	row:SetSize(width, 30)
	row:SetScript("OnShow", UpdateRow)

	local box -- for typing a time, created below

	-- "Set" opens the box to type a time, "Clear" stops the alarm.
	row.button = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
	row.button:SetSize(46, 20)
	row.button:SetPoint("RIGHT", -8, 0)
	row.button:SetNormalFontObject("GameFontNormalSmall")
	row.button:SetHighlightFontObject("GameFontHighlightSmall")
	row.button:SetScript("OnClick", function()
		if OldPeoplesToolkitDB.alarm.at then
			SetAlarm(nil)
		else
			box:Show()
		end
	end)

	-- The time left is a button too: click it to type a time, scroll to adjust.
	local timeButton = CreateFrame("Button", nil, row)
	timeButton:SetSize(66, 24)
	timeButton:SetPoint("LEFT", 6, 0)
	timeButton:EnableMouseWheel(true)

	row.text = timeButton:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
	row.text:SetPoint("LEFT", 4, 0)

	row.untilText = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	row.untilText:SetPoint("LEFT", timeButton, "RIGHT", 2, 0)

	box = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
	box:SetSize(90, 20)
	box:SetPoint("LEFT", 14, 0)
	box:SetAutoFocus(true)
	box:Hide()
	box:SetScript("OnShow", function(self)
		self:SetText("")
		timeButton:Hide()
		row.untilText:Hide()
	end)
	box:SetScript("OnHide", function()
		timeButton:Show()
		row.untilText:Show()
	end)
	box:SetScript("OnEnterPressed", function(self)
		ns.SetAlarmFromText(self:GetText())
		self:Hide()
	end)
	box:SetScript("OnEscapePressed", box.Hide)
	box:SetScript("OnEditFocusLost", box.Hide)

	timeButton:SetScript("OnClick", function() box:Show() end)
	-- Scrolling moves the alarm 1 minute (5 with Shift). With no alarm set,
	-- it starts one that many minutes from now.
	timeButton:SetScript("OnMouseWheel", function(_, delta)
		local alarm = OldPeoplesToolkitDB.alarm
		local step = (IsShiftKeyDown() and 5 or 1) * 60 * delta
		local base = (alarm.at and not alarm.finished) and alarm.at or time()
		local at = base + step
		SetAlarm(at > time() and at or nil, alarm.at and alarm.setAs) -- keeps how you set it
	end)
	timeButton:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
		GameTooltip:AddLine("Alarm")
		local r, g, b = ns.RGB(ns.WHITE)
		GameTooltip:AddLine("For \"I've got 15 minutes\" or \"I can play until 22:30\".", r, g, b, true)
		GameTooltip:AddLine(" ")
		ns.AddHint("Click: type 15, 1h30, 22:30 or 10pm")
		ns.AddHint("Scroll: 1 minute later or earlier (Shift: 5)")
		ns.AddHint("You get a heads-up 5 minutes before.")
		GameTooltip:Show()
	end)
	timeButton:SetScript("OnLeave", GameTooltip_Hide)

	return row
end

---------------------------------------------------------------------------
-- "Responsibilities", the alarm's debuff (drawn by Auras.lua)
---------------------------------------------------------------------------

ns.AddIconSlot("alarm", "Responsibilities", "Interface\\Icons\\INV_Eng_UnstableTemporalTimeShifter")

ns.AddAura({
	key = "alarm",
	State = function()
		local alarm = OldPeoplesToolkitDB.alarm
		if not alarm.at or not alarm.showDebuff then return nil end
		return true, "alarm", alarm.finished and 0 or math.max(alarm.at - time(), 0)
	end,
	-- Like a real debuff: what it does, then how long it lasts, the way you
	-- set it ("23 minutes remaining" or "Until 22:30").
	Tooltip = function(_, remaining)
		local alarm = OldPeoplesToolkitDB.alarm
		if alarm.finished then return "I must go, my people need me!" end
		local left = alarm.setAs == "time" and ("Until " .. ns.ClockText(alarm.at))
			or (ns.Duration(remaining + 59) .. " remaining") -- rounded up, so never "0 minutes"
		return "Calls from another dimension, growing louder.", left
	end,
	hint = "Right-click: clear the alarm",
	OnRightClick = function() ns.SetAlarmFromText("off") end,
})

---------------------------------------------------------------------------
-- Used by the clock and /oldperson alarm
---------------------------------------------------------------------------

-- When it goes off, and whether it already has.
function ns.AlarmInfo()
	local alarm = OldPeoplesToolkitDB.alarm
	return alarm.at, alarm.finished
end

function ns.SetAlarmFromText(text)
	if text == "off" or text == "clear" then
		SetAlarm(nil)
		ns.Print("alarm cleared. No responsibilities, for now.")
		return
	end
	local at, setAs = ParseAlarm(text)
	if not at then
		ns.Print("type 15 for 15 minutes, 1h30, or a time like 22:30 or 10pm.")
		return
	end
	SetAlarm(at, setAs)
	ns.Print("responsibilities at " .. ns.ClockText(at) .. ". That's " .. ns.Duration(at - time() + 59) .. ".")
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function()
	Check() -- went off while you were logged out? You hear it now.
	C_Timer.NewTicker(1, Check)
end)
