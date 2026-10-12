-- Options: the addon's pages in the game's options (Esc > Options > AddOns >
-- Old People's Toolkit). The main page has the toolkit's own settings, and
-- each tool has a page of its own under it. Everything writes straight into
-- OldPeoplesToolkitDB, and the tools read from there every time, so a change
-- counts right away.

local _, ns = ...

local category, layout -- the main page
local page -- the page the settings below go on
local pages = {} -- [tool] = its page, for ns.OpenOptions

-- A heading on the main page. Skipped quietly if the game doesn't have them.
local function Heading(text)
	if layout and CreateSettingsListSectionHeaderInitializer then
		layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(text))
	end
end

-- Starts a tool's own page. If the game can't do pages under pages, the
-- tool gets a heading on the main page instead.
local function Page(tool, name)
	if Settings.RegisterVerticalLayoutSubcategory then
		page = Settings.RegisterVerticalLayoutSubcategory(category, name)
	else
		page = category
		Heading(name)
	end
	pages[tool] = page
end

-- section: the part of OldPeoplesToolkitDB, like "stretch". The default comes
-- from Core.lua. onChange: optional, called after a change.
local function Checkbox(section, key, name, tooltip, onChange)
	local variable = "OldPeoplesToolkit_" .. section .. "_" .. key
	local setting = Settings.RegisterAddOnSetting(page, variable, key, OldPeoplesToolkitDB[section],
		Settings.VarType.Boolean, name, ns.DEFAULTS[section][key])
	local CreateCheckbox = Settings.CreateCheckbox or Settings.CreateCheckBox -- renamed in The War Within
	CreateCheckbox(page, setting, tooltip)
	if onChange then Settings.SetOnValueChangedCallback(variable, onChange) end
end

-- limits: { lowest, highest }. Label(value): how the value is shown, like "23:00".
local function Slider(section, key, name, limits, step, Label, tooltip, onChange)
	local variable = "OldPeoplesToolkit_" .. section .. "_" .. key
	local setting = Settings.RegisterAddOnSetting(page, variable, key, OldPeoplesToolkitDB[section],
		Settings.VarType.Number, name, ns.DEFAULTS[section][key])
	local options = Settings.CreateSliderOptions(limits[1], limits[2], step)
	options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, Label)
	Settings.CreateSlider(page, setting, options, tooltip)
	if onChange then Settings.SetOnValueChangedCallback(variable, onChange) end
end

local function Minutes(value) return value .. " min" end
local function Seconds(value) return value .. " sec" end
local function Hours(value) return value .. " h" end
local function Percent(value) return value == 0 and "off" or (value .. "%") end

local function Register()
	category, layout = Settings.RegisterVerticalLayoutCategory("Old People's Toolkit")
	local db = OldPeoplesToolkitDB

	page = category
	Checkbox("minimapButton", "show", "Show the minimap button",
		"The little pocket watch on the minimap, which opens these options.",
		function() ns.SetMinimapButtonShown(db.minimapButton.show) end)

	Page("whereami", "Where was I?")
	Checkbox("whereWasI", "enabled", "Enabled",
		"Helps you remember what you were doing before! After a while away, a window tells you when and "
			.. "where you last played, your quests, and what your bags were filling up with.")
	Slider("whereWasI", "awayHours", "When I've been away for", ns.WHERE_LIMITS, 1, Hours,
		"/oldperson whereami shows it any time.")

	Page("scrolls", "Scrolls of Remembering")
	Checkbox("scrolls", "enabled", "Enabled",
		"For everything you'll definitely forget! A notebook for what that meat is for, who someone told "
			.. "you to find, or where you saw something odd. Each note remembers where you were standing. "
			.. "It's tucked in your spellbook, or type /oldperson notes.",
		function() ns.SetScrollsEnabled(db.scrolls.enabled) end)

	Page("quiet", "Quiet hours")
	Checkbox("quiet", "enabled", "Enabled",
		"Shh, the house is asleep! WoW's volume goes down at night and back up in the morning. "
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

	Page("stretch", "Old People's Stretch")
	-- Turning it back on starts the time over, so it doesn't pop up right away.
	Checkbox("stretch", "enabled", "Enabled",
		"Your back will thank you! After a while of playing, a pop-up reminds you to stand up and get "
			.. "those old bones moving.",
		function() ns.SetStretchEnabled(db.stretch.enabled) end)
	Checkbox("stretch", "showBuff", "Show the stretch timer as a buff",
		"Fresh as a Daisy when you start playing, Second Wind after you've stretched, "
			.. "Stiff Joints when it's time to stretch. Right-click it when you've stretched.",
		ns.UpdateAuras)
	Slider("stretch", "intervalMinutes", "Remind me every", ns.STRETCH_LIMITS.intervalMinutes, 1, Minutes,
		"How long you can play before the stretch pop-up shows up.")
	Slider("stretch", "snoozeMinutes", "After no stretch, ask again in", ns.STRETCH_LIMITS.snoozeMinutes, 1, Minutes,
		"When you click \"Remind me\" instead of stretching, the pop-up comes back after this long.")
	Slider("stretch", "waitSeconds", "Stretch button unlocks after", ns.STRETCH_LIMITS.waitSeconds, 1, Seconds,
		"\"I stood up and stretched\" stays greyed out this long, so you actually stretch first. 0 turns it off.")

	Page("alarm", "Clock and alarm")
	-- Off for people who only want the other tools.
	Checkbox("clock", "show", "Show the clock",
		"Never lose track of time again! A bigger clock with an alarm, that you can put anywhere.",
		function() ns.SetClockShown(db.clock.show) end)
	Checkbox("clock", "hideBlizzardClock", "Replace the minimap clock",
		"While our clock is showing, Blizzard's small clock on the minimap is hidden.",
		ns.ApplyBlizzardClock)
	Checkbox("alarm", "showDebuff", "Show the alarm as a debuff",
		"While an alarm is set, \"Responsibilities\" sits with your debuffs and counts down. "
			.. "Right-click it to clear the alarm.",
		ns.UpdateAuras)

	Page("bedtime", "Bedtime")
	Checkbox("bedtime", "enabled", "Enabled",
		"Because tomorrow is a work day! A heads-up 15 minutes before your bedtime, and a reminder when it's time.",
		ns.UpdateAuras)
	Slider("bedtime", "minutes", "Bedtime", ns.BEDTIME_LIMITS, 15, ns.MinutesText,
		"On work nights: Sunday to Thursday.", ns.UpdateAuras)
	Checkbox("bedtime", "weekends", "Weekends too",
		"Also on Friday and Saturday night. No exceptions!", ns.UpdateAuras)
	Checkbox("bedtime", "showDebuff", "Show bedtime as a debuff",
		"\"Past Your Bedtime\" sits with your debuffs until morning. Right-click it to hide it for tonight.",
		ns.UpdateAuras)

	Settings.RegisterAddOnCategory(category)
end

-- tool: optional, open that tool's page ("whereami", "scrolls", "quiet",
-- "stretch", "alarm", "bedtime") instead of the main page.
function ns.OpenOptions(tool)
	if category then
		Settings.OpenToCategory((pages[tool] or category):GetID())
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
