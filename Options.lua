-- Options: the addon's page in the game's options (Esc > Options > AddOns >
-- Old People's Toolkit), with a heading per tool. Everything writes straight
-- into OldPeoplesToolkitDB, and the tools read from there every time, so a
-- change counts right away.

local _, ns = ...

local category, layout

-- A heading on the options page. Skipped quietly if the game doesn't have them.
local function Heading(text)
	if layout and CreateSettingsListSectionHeaderInitializer then
		layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(text))
	end
end

-- section: the part of OldPeoplesToolkitDB, like "stretch". The default comes
-- from Core.lua. onChange: optional, called after a change.
local function Checkbox(section, key, name, tooltip, onChange)
	local variable = "OldPeoplesToolkit_" .. section .. "_" .. key
	local setting = Settings.RegisterAddOnSetting(category, variable, key, OldPeoplesToolkitDB[section],
		Settings.VarType.Boolean, name, ns.DEFAULTS[section][key])
	local CreateCheckbox = Settings.CreateCheckbox or Settings.CreateCheckBox -- renamed in The War Within
	CreateCheckbox(category, setting, tooltip)
	if onChange then Settings.SetOnValueChangedCallback(variable, onChange) end
end

-- limits: { lowest, highest }. Label(value): how the value is shown, like "23:00".
local function Slider(section, key, name, limits, step, Label, tooltip, onChange)
	local variable = "OldPeoplesToolkit_" .. section .. "_" .. key
	local setting = Settings.RegisterAddOnSetting(category, variable, key, OldPeoplesToolkitDB[section],
		Settings.VarType.Number, name, ns.DEFAULTS[section][key])
	local options = Settings.CreateSliderOptions(limits[1], limits[2], step)
	options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, Label)
	Settings.CreateSlider(category, setting, options, tooltip)
	if onChange then Settings.SetOnValueChangedCallback(variable, onChange) end
end

local function Minutes(value) return value .. " min" end
local function Seconds(value) return value .. " sec" end
local function Hours(value) return value .. " h" end
local function Percent(value) return value == 0 and "off" or (value .. "%") end

local function Register()
	category, layout = Settings.RegisterVerticalLayoutCategory("Old People's Toolkit")
	local db = OldPeoplesToolkitDB

	Heading("Clock and alarm")
	-- Off for people who only want the other tools.
	Checkbox("clock", "show", "Show the clock",
		"A bigger clock with an alarm, that you can put anywhere.",
		function() ns.SetClockShown(db.clock.show) end)
	Checkbox("clock", "hideBlizzardClock", "Replace Blizzard's minimap clock",
		"While our clock is showing, Blizzard's small clock on the minimap is hidden.",
		ns.ApplyBlizzardClock)
	Checkbox("alarm", "showDebuff", "Show the alarm as a debuff",
		"While an alarm is set, \"Responsibilities\" sits with your debuffs and counts down. "
			.. "Right-click it to clear the alarm.",
		ns.UpdateAuras)

	Heading("Old People's Stretch")
	-- Turning it back on starts the time over, so it doesn't pop up right away.
	Checkbox("stretch", "enabled", "Enabled",
		"A pop-up that reminds you to stand up and get those old bones moving.",
		function() ns.SetStretchEnabled(db.stretch.enabled) end)
	Checkbox("stretch", "showBuff", "Show the stretch timer as a buff",
		"Fresh as a Daisy when you start playing, Spring in Your Step after you've stretched, "
			.. "Stiff Joints when it's time to stretch. Right-click it when you've stretched.",
		ns.UpdateAuras)
	Slider("stretch", "intervalMinutes", "Remind me every", ns.STRETCH_LIMITS.intervalMinutes, 1, Minutes,
		"How long you can play before the stretch pop-up shows up.")
	Slider("stretch", "snoozeMinutes", "After no stretch, ask again in", ns.STRETCH_LIMITS.snoozeMinutes, 1, Minutes,
		"When you click \"Remind me\" instead of stretching, the pop-up comes back after this long.")
	Slider("stretch", "waitSeconds", "Stretch button unlocks after", ns.STRETCH_LIMITS.waitSeconds, 1, Seconds,
		"\"I stood up and stretched\" stays greyed out this long, so you actually stretch first. 0 turns it off.")

	Heading("Bedtime")
	Checkbox("bedtime", "enabled", "Enabled",
		"A heads-up 15 minutes before your bedtime, and a reminder when it's time.",
		ns.UpdateAuras)
	Slider("bedtime", "minutes", "Bedtime", ns.BEDTIME_LIMITS, 15, ns.MinutesText,
		"On work nights: Sunday to Thursday.", ns.UpdateAuras)
	Checkbox("bedtime", "weekends", "Weekends too",
		"Also on Friday and Saturday night.", ns.UpdateAuras)
	Checkbox("bedtime", "showDebuff", "Show bedtime as a debuff",
		"\"Past Your Bedtime\" sits with your debuffs until morning. Right-click it to hide it for tonight.",
		ns.UpdateAuras)

	Heading("Quiet hours")
	Checkbox("quiet", "enabled", "Enabled",
		"Turns WoW's volume down at night, so you don't wake the house, and back up in the morning. "
			.. "If you change the volume yourself in between, that's left alone.",
		ns.CheckQuietHours)
	Checkbox("quiet", "showBuff", "Show quiet hours as a buff",
		"\"Earmuffs\" while the volume is down. Right-click them to skip quiet hours for tonight.",
		ns.UpdateAuras)
	Slider("quiet", "start", "From", ns.QUIET_LIMITS.start, 15, ns.MinutesText, nil, ns.CheckQuietHours)
	Slider("quiet", "stop", "Until", ns.QUIET_LIMITS.stop, 15, ns.MinutesText,
		"The next morning.", ns.CheckQuietHours)
	Slider("quiet", "volume", "Volume during quiet hours", ns.QUIET_LIMITS.volume, 5, Percent,
		"Of the full volume. Off mutes the game.", ns.CheckQuietHours)

	Heading("Where was I?")
	Checkbox("whereWasI", "enabled", "Enabled",
		"After a while away: when and where you last played, and the quests you were busy with.")
	Slider("whereWasI", "awayHours", "When I've been away for", ns.WHERE_LIMITS, 1, Hours,
		"/oldperson whereami shows it any time.")

	Heading("Toolkit")
	Checkbox("minimapButton", "show", "Show the minimap button",
		"A round button on the minimap that opens these options.",
		function() ns.SetMinimapButtonShown(db.minimapButton.show) end)

	Settings.RegisterAddOnCategory(category)
end

function ns.OpenOptions()
	if category then
		Settings.OpenToCategory(category:GetID())
	else
		ns.Print("the options page isn't available.")
	end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function()
	-- The options API changes between game versions. If it doesn't work on
	-- Forever, the tools still work and so do the /oldperson commands.
	local ok, err = pcall(Register)
	if not ok then
		category = nil
		ns.Print("couldn't add the options page (" .. tostring(err) .. ").")
	end
end)
