-- Clock: a bigger clock with your real (local) time that you can put anywhere.
-- The alarm folds out underneath (Alarm.lua). While it's showing, it hides
-- Blizzard's small clock on the minimap (unless you turn that off).
--
-- Click: show or hide the alarm       Drag: move it
-- Scroll: bigger or smaller           Right-click: Blizzard's clock settings
--                                     (24-hour mode)
--
-- Saved in OldPeoplesToolkitDB.clock: show, point/x/y (where it is), scale,
-- hideBlizzardClock.

local _, ns = ...

local WIDTH = 190 -- room for the alarm row: "1:02:03", "until 22:30" and a button
local HEIGHT = 40 -- without the alarm row

local frame, timeText, alarmRow

local function Update()
	timeText:SetText(ns.ClockText())
end

-- Folds the alarm row out (or back in) under the clock.
function ns.ShowAlarmRow(shown)
	OldPeoplesToolkitDB.alarm.rowShown = shown
	if not frame then return end
	alarmRow:SetShown(shown)
	frame:SetHeight(HEIGHT + (shown and alarmRow:GetHeight() or 0))
end

local function SavePosition()
	local point, _, _, x, y = frame:GetPoint()
	local db = OldPeoplesToolkitDB.clock
	db.point, db.x, db.y = point, x, y
end

local function Place()
	local db = OldPeoplesToolkitDB.clock
	frame:SetScale(db.scale)
	frame:ClearAllPoints()
	frame:SetPoint(db.point, UIParent, db.point, db.x, db.y)
end

local function OpenBlizzardClockSettings()
	if not TimeManager_Toggle and C_AddOns and C_AddOns.LoadAddOn then
		C_AddOns.LoadAddOn("Blizzard_TimeManager")
	end
	if TimeManager_Toggle then
		TimeManager_Toggle()
	else
		ns.Print("couldn't find Blizzard's clock settings.")
	end
end

local function ShowTooltip(self)
	GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
	GameTooltip:AddLine("Clock")
	GameTooltip:AddLine(date("%A %d %B %Y"), ns.RGB(ns.WHITE))
	local at, finished = ns.AlarmInfo()
	if at and not finished then
		GameTooltip:AddLine("Alarm at " .. ns.ClockText(at), ns.RGB(ns.GREEN)) -- green like the running alarm
	end
	GameTooltip:AddLine(ns.StretchText(), ns.RGB(ns.WHITE))
	local bedtime = ns.BedtimeText()
	if bedtime then GameTooltip:AddLine(bedtime, ns.RGB(ns.WHITE)) end
	GameTooltip:AddLine(" ")
	ns.AddHint("Click: show or hide the alarm")
	ns.AddHint("Right-click: 24-hour setting")
	ns.AddHint("Drag: move")
	ns.AddHint("Scroll: bigger or smaller")
	ns.AddHint("Type /oldperson for the options.")
	GameTooltip:Show()
end

local function CreateClock()
	frame = CreateFrame("Button", "OldPeoplesToolkitClock", UIParent, "BackdropTemplate")
	frame:SetSize(WIDTH, HEIGHT)
	frame:SetFrameStrata("MEDIUM")
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	frame:RegisterForDrag("LeftButton")
	frame:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	frame:EnableMouseWheel(true)
	frame:SetBackdrop({
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		edgeSize = 12,
		insets = { left = 3, right = 3, top = 3, bottom = 3 },
	})
	frame:SetBackdropColor(0, 0, 0, 0.6)
	frame:SetBackdropBorderColor(0.6, 0.6, 0.6, 0.8)

	timeText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightHuge")
	timeText:SetPoint("TOP", 0, -10)

	alarmRow = ns.CreateAlarmRow(frame, WIDTH)
	alarmRow:SetPoint("TOP", 0, -HEIGHT + 4)

	frame:SetScript("OnClick", function(_, mouseButton)
		if mouseButton == "RightButton" then
			OpenBlizzardClockSettings()
		else
			ns.ShowAlarmRow(not OldPeoplesToolkitDB.alarm.rowShown)
		end
	end)
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		SavePosition()
	end)
	frame:SetScript("OnMouseWheel", function(_, delta)
		local db = OldPeoplesToolkitDB.clock
		db.scale = math.min(3, math.max(0.6, db.scale + delta * 0.1))
		frame:SetScale(db.scale)
	end)
	frame:SetScript("OnEnter", ShowTooltip)
	frame:SetScript("OnLeave", GameTooltip_Hide)

	Place()
	ns.ShowAlarmRow(OldPeoplesToolkitDB.alarm.rowShown)
	frame:SetShown(OldPeoplesToolkitDB.clock.show)
	Update()
	C_Timer.NewTicker(1, Update)
end

---------------------------------------------------------------------------
-- Blizzard's small clock on the minimap
---------------------------------------------------------------------------

local hooked = false

-- Only while our clock is showing: if you hide ours, you get Blizzard's back.
local function ShouldHideBlizzardClock()
	local db = OldPeoplesToolkitDB.clock
	return db.hideBlizzardClock and db.show
end

-- Only hides it; it isn't removed, so turning the option off brings it back.
local function ApplyBlizzardClock()
	local blizz = TimeManagerClockButton
	if not blizz then return end
	if not hooked then
		blizz:HookScript("OnShow", function(self)
			if ShouldHideBlizzardClock() then self:Hide() end
		end)
		hooked = true
	end
	blizz:SetShown(not ShouldHideBlizzardClock())
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(_, event, name)
	if event == "PLAYER_LOGIN" then
		CreateClock()
		ApplyBlizzardClock()
	elseif name == "Blizzard_TimeManager" then
		ApplyBlizzardClock() -- in case Blizzard's clock loads after us
	end
end)

---------------------------------------------------------------------------
-- Used by the options and /oldperson clock reset
---------------------------------------------------------------------------

-- Hiding the clock is for people who only want the other tools. They keep
-- working without it.
function ns.SetClockShown(shown)
	OldPeoplesToolkitDB.clock.show = shown
	frame:SetShown(shown)
	ApplyBlizzardClock()
end

ns.ApplyBlizzardClock = ApplyBlizzardClock

function ns.ResetClock()
	local db, default = OldPeoplesToolkitDB.clock, ns.DEFAULTS.clock
	db.point, db.x, db.y, db.scale = default.point, default.x, default.y, default.scale
	Place()
	ns.Print("clock moved back to the top of the screen.")
end
