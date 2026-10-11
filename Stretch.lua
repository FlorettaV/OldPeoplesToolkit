-- Stretch (Old People's Stretch): after a while of playing (an hour by
-- default), a pop-up asks you to stand up and stretch.
--   "Remind me in 5 min"       -> it asks again in a few minutes (5 by default)
--   "I stood up and stretched" -> the timer starts over
-- It never pops up during a fight; it waits until the fight is over.
-- Logging out for a while counts as a break too.
-- The times can be changed in Options > AddOns > Old People's Toolkit.
-- With "Show the stretch timer as a buff", a buff sits with your buffs: "Fresh
-- as a Daisy" when you just started playing, "Second Wind" once you've
-- stretched. When it's time to stretch it turns into the debuff "Stiff Joints".
--
-- Saved in OldPeoplesToolkitDB.stretch: enabled, intervalMinutes, snoozeMinutes,
-- waitSeconds (how long "I stretched" stays greyed out), showBuff, lastBreak
-- (when you last stretched or started playing), stretched (true: lastBreak was
-- a stretch), snoozeUntil (after "Remind me"), lastSeen.

local _, ns = ...

local BREAK = 10 * 60 -- logged out at least this long = you had a break

local popup

local function Interval()
	return OldPeoplesToolkitDB.stretch.intervalMinutes * 60
end

-- When the pop-up should show next. Worked out every time instead of saved,
-- so changing a setting counts right away.
local function DueAt()
	local s = OldPeoplesToolkitDB.stretch
	return s.snoozeUntil or ((s.lastBreak or time()) + Interval())
end

-- stretched: true if you stretched, nil if you just started playing.
local function StartOver(stretched)
	local s = OldPeoplesToolkitDB.stretch
	s.lastBreak, s.stretched, s.snoozeUntil = time(), stretched, nil
	ns.UpdateAuras()
end

-- Seconds until the next pop-up, and whether you're overdue (time's up, or
-- you clicked "Remind me" instead of stretching).
local function Remaining()
	local remaining = math.max(DueAt() - time(), 0)
	return remaining, remaining == 0 or OldPeoplesToolkitDB.stretch.snoozeUntil ~= nil
end

-- "I stood up and stretched", from the pop-up, the buff or /oldperson stretch done.
local function Stretched()
	StartOver(true)
	if popup then popup:Hide() end
	ns.Print("nice! Next reminder in " .. ns.Duration(Interval()) .. ".")
end

---------------------------------------------------------------------------
-- The pop-up
---------------------------------------------------------------------------

local function CreatePopup()
	popup = ns.CreateDialog("OldPeoplesToolkitPopup", 360) -- the height follows the text, see Layout()
	popup:SetPoint("CENTER", 0, 120)
	-- Not added to UISpecialFrames on purpose: Escape doesn't close it.

	popup.title = popup:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	popup.title:SetPoint("TOP", 12, -24) -- a bit to the right, to make room for the icon

	popup.icon = popup:CreateTexture(nil, "ARTWORK")
	popup.icon:SetSize(24, 24)
	popup.icon:SetPoint("RIGHT", popup.title, "LEFT", -6, 0)
	popup.icon:SetTexture("Interface\\Icons\\INV_Misc_PocketWatch_01")
	popup.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

	popup.text = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	popup.text:SetPoint("TOP", 0, -24 - 24 - 10)
	popup.text:SetWidth(300)
	popup.text:SetSpacing(2)

	popup.hint = popup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	popup.hint:SetPoint("TOP", popup.text, "BOTTOM", 0, -10)
	popup.hint:SetTextColor(ns.RGB(ns.GREEN))
	popup.hint:SetText("Time to stand up and get those old bones moving!")

	-- Its text ("Remind me in 5 min") is set in ShowPopup, since the time can change.
	local later = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
	later:SetSize(150, 26)
	later:SetPoint("TOP", popup.hint, "BOTTOM", 0, -16)
	popup.later = later
	later:SetScript("OnClick", function()
		OldPeoplesToolkitDB.stretch.snoozeUntil = time() + OldPeoplesToolkitDB.stretch.snoozeMinutes * 60
		popup:Hide()
		ns.UpdateAuras()
	end)

	local stretched = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
	stretched:SetSize(190, 20) -- room for the "(10)" countdown
	stretched:SetPoint("TOP", later, "BOTTOM", 0, -4)
	stretched:SetText("I stood up and stretched")
	stretched:SetNormalFontObject("GameFontNormalSmall")
	stretched:SetHighlightFontObject("GameFontHighlightSmall")
	stretched:SetDisabledFontObject("GameFontDisableSmall")
	stretched:SetScript("OnClick", function() Stretched() end)
	popup.stretched = stretched
end

-- Greys out "I stood up and stretched" for a few seconds (go stretch first!),
-- counting down on the button. 0 seconds means it's never greyed out.
local waitTicker

local function LockStretchButton()
	local button = popup.stretched
	if waitTicker then
		waitTicker:Cancel()
		waitTicker = nil
	end
	local left = OldPeoplesToolkitDB.stretch.waitSeconds
	if left <= 0 then
		button:SetText("I stood up and stretched")
		button:Enable()
		return
	end
	button:Disable()
	button:SetText("I stood up and stretched (" .. left .. ")")
	waitTicker = C_Timer.NewTicker(1, function()
		left = left - 1
		if left > 0 then
			button:SetText("I stood up and stretched (" .. left .. ")")
		else
			button:SetText("I stood up and stretched")
			button:Enable()
			waitTicker = nil
		end
	end, left)
end

-- The pop-up grows to fit the text: top border, title, text, hint, buttons, bottom border.
local function Layout()
	local height = 24 + 24 + 10 + popup.text:GetStringHeight() + 10 + popup.hint:GetStringHeight()
		+ 16 + 26 + 4 + 20 + 24
	popup:SetHeight(height)
end

local function ShowPopup()
	if not popup then CreatePopup() end
	local s = OldPeoplesToolkitDB.stretch
	local played = time() - (s.lastBreak or time())
	if not s.snoozeUntil and played < Interval() - 60 then
		-- Not time yet, so this is "/oldperson stretch test".
		popup.title:SetText("Old People's Stretch")
		popup.text:SetText("This is a preview. After " .. ns.GOLD .. ns.Duration(Interval()) .. "|r of playing\n"
			.. "you'll see this pop-up.")
	else
		local title = Interval() == 3600 and "An hour has passed!" or (ns.Duration(Interval()) .. " have passed!")
		popup.title:SetText(s.snoozeUntil and "Still sitting, old timer?" or title)
		popup.text:SetText("You've been playing for " .. ns.GOLD .. ns.Duration(played) .. "|r\nwithout a break.")
	end
	popup.later:SetText("Remind me in " .. s.snoozeMinutes .. " min")
	LockStretchButton()
	Layout()
	popup:Show()
	if SOUNDKIT and SOUNDKIT.READY_CHECK then PlaySound(SOUNDKIT.READY_CHECK, "Master") end
	if FlashClientIcon then FlashClientIcon() end -- blinks WoW in the taskbar if you're tabbed out
end

---------------------------------------------------------------------------
-- Checking the time
---------------------------------------------------------------------------

local function Check()
	local s = OldPeoplesToolkitDB.stretch
	s.lastSeen = time()
	if not s.enabled or (popup and popup:IsShown()) then return end
	if time() < DueAt() then return end
	if InCombatLockdown() or UnitAffectingCombat("player") then return end -- try again next check
	ShowPopup()
end

-- For the clock's tooltip: "Old People's Stretch in 23 minutes"
function ns.StretchText()
	if not OldPeoplesToolkitDB.stretch.enabled then return "Old People's Stretch is off" end
	local left = DueAt() - time()
	if left <= 0 then return "Time to stretch!" end
	return "Old People's Stretch in " .. ns.Duration(left + 59) -- round up, so never "0 minutes"
end

function ns.SetStretchEnabled(enabled)
	local s = OldPeoplesToolkitDB.stretch
	s.enabled = enabled
	if enabled then StartOver() end
	if not enabled and popup then popup:Hide() end
	ns.UpdateAuras()
end

-- The same limits as the sliders in the options.
ns.STRETCH_LIMITS = {
	intervalMinutes = { 15, 180 },
	snoozeMinutes = { 1, 30 },
	waitSeconds = { 0, 60 },
}

-- /oldperson stretch test or done (see Commands.lua). Returns true if it knew
-- the command.
function ns.StretchCommand(args)
	if args == "test" then
		ShowPopup()
	elseif args == "done" then
		Stretched()
	else
		return false
	end
	return true
end

---------------------------------------------------------------------------
-- "Fresh as a Daisy", "Second Wind" and "Stiff Joints" (drawn by Auras.lua)
---------------------------------------------------------------------------

ns.AddIconSlot("stretchBuff", "Second Wind", 1386545) -- spell_priest_pontifex: a praying figure in golden light
ns.AddIconSlot("stretchDebuff", "Stiff Joints", "Interface\\Icons\\INV_Misc_Head_Gnome_02") -- a gnome head, for fun

ns.AddAura({
	key = "stretch",
	State = function()
		local s = OldPeoplesToolkitDB.stretch
		if not s.enabled or not s.showBuff then return nil end
		local remaining, overdue = Remaining()
		if overdue then return true, "stretchDebuff", remaining end
		-- The same icon either way, but you have to earn your Second Wind.
		return false, "stretchBuff", remaining, not s.stretched and "Fresh as a Daisy" or nil
	end,
	Tooltip = function(isDebuff, remaining)
		if isDebuff then
			return "Your old bones take 50 Nature damage every minute. Stand up and stretch!",
				remaining > 0 and ("Next reminder in " .. ns.Duration(remaining + 59)) or nil
		end
		-- Like a real buff: what it does, then how long it lasts. (Rounded up, so never "0 minutes".)
		local left = ns.Duration(remaining + 59) .. " remaining"
		if OldPeoplesToolkitDB.stretch.stretched then
			return "You stretched! Feeling like a young god.", left
		end
		return "You just sat down. Your bones haven't noticed yet.", left
	end,
	hint = "Right-click: I stood up and stretched",
	OnRightClick = function() Stretched() end,
})

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_LOGOUT")
events:SetScript("OnEvent", function(_, event)
	local s = OldPeoplesToolkitDB.stretch
	if event == "PLAYER_LOGOUT" then
		s.lastSeen = time()
		return
	end
	-- Away for a while (or the first time ever)? Start over.
	-- A quick /reload keeps counting where it was.
	if not s.lastBreak or not s.lastSeen or time() - s.lastSeen >= BREAK then
		StartOver()
	end
	C_Timer.NewTicker(10, Check)
end)
