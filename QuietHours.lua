-- Quiet hours: at night (23:00 to 07:00 by default) WoW's master volume goes
-- down, so you don't wake the house, and back up in the morning.
-- If you change the volume yourself during quiet hours, that's left alone:
-- it isn't lowered again, and isn't "restored" over your choice afterwards.
-- Meanwhile you wear "Earmuffs" with your buffs (until you change the
-- volume yourself); right-click them to skip quiet hours for tonight
-- (headphones on, say).
--
-- Saved in OldPeoplesToolkitDB.quiet: enabled, start and stop (see the note on
-- times in Core.lua), volume (in %, 0 = off), showBuff, skippedFor (which
-- night you right-clicked), and while it's quiet: savedVolume (yours, to put
-- back) and setVolume (what we turned it down to).

local _, ns = ...

local CVAR = "Sound_MasterVolume" -- "0" to "1"
ns.QUIET_LIMITS = {
	start = { 19 * 60, 27 * 60 }, -- 19:00 to 03:00
	stop = { 5 * 60, 12 * 60 }, -- 05:00 to 12:00 (the next morning)
	volume = { 0, 100 },
}

local GetCVarValue = C_CVar and C_CVar.GetCVar or GetCVar
local SetCVarValue = C_CVar and C_CVar.SetCVar or SetCVar

local function GetVolume()
	return tonumber(GetCVarValue(CVAR)) or 1
end

local function SetVolume(volume)
	SetCVarValue(CVAR, string.format("%.2f", volume))
end

-- If it's quiet hours right now: when they started and end.
local function QuietNight()
	local db = OldPeoplesToolkitDB.quiet
	if not db.enabled then return nil end
	local from, to = ns.Night(db.start, 24 * 60 + db.stop)
	if from and db.skippedFor ~= from then return from, to end
end

local function IsQuietTime()
	return QuietNight() ~= nil
end

local function Check()
	local db = OldPeoplesToolkitDB.quiet
	local quiet = IsQuietTime()
	if quiet and not db.savedVolume then
		db.savedVolume = GetVolume()
		local volume = math.min(db.savedVolume, db.volume / 100)
		if volume < db.savedVolume then
			SetVolume(volume)
			ns.Print("shh, the house is asleep. Volume down to " .. db.volume .. "% until " .. ns.MinutesText(db.stop) .. ".")
		end
		db.setVolume = volume
	elseif quiet and math.abs(GetVolume() - db.setVolume) < 0.01 then
		-- Moved the slider in the options during quiet hours: use the new volume.
		local volume = math.min(db.savedVolume, db.volume / 100)
		if math.abs(volume - db.setVolume) >= 0.01 then
			SetVolume(volume)
			db.setVolume = volume
		end
	elseif not quiet and db.savedVolume then
		-- Only put it back if you didn't change it yourself in the meantime.
		if math.abs(GetVolume() - db.setVolume) < 0.01 and db.setVolume < db.savedVolume then
			SetVolume(db.savedVolume)
			ns.Print("good morning! Volume back to " .. math.floor(db.savedVolume * 100 + 0.5) .. "%.")
		end
		db.savedVolume, db.setVolume = nil, nil
	end
end
ns.CheckQuietHours = Check -- the options call this right after a change

---------------------------------------------------------------------------
-- "Earmuffs" (drawn by Auras.lua)
---------------------------------------------------------------------------

-- Horde or Alliance earmuffs, whichever side you're on.
ns.AddIconSlot("quiet", "Earmuffs", function()
	return "Interface\\Icons\\INV_Helm_Armor_Earmuffs_B_01_"
		.. (UnitFactionGroup("player") == "Alliance" and "Alliance" or "Horde")
end)

ns.AddAura({
	key = "quiet",
	State = function()
		local db = OldPeoplesToolkitDB.quiet
		local _, to = QuietNight()
		-- Changed the volume yourself? Then the earmuffs are off too.
		if not to or not db.showBuff or not db.setVolume or math.abs(GetVolume() - db.setVolume) >= 0.01 then
			return nil
		end
		return false, "quiet", to - time()
	end,
	Tooltip = function()
		local db = OldPeoplesToolkitDB.quiet
		local volume = math.floor(db.setVolume * 100 + 0.5)
		return (volume == 0 and "Game sound muted" or ("Game volume reduced to " .. volume .. "%"))
			.. ", so you don't wake the house.", "Until " .. ns.MinutesText(db.stop)
	end,
	hint = "Right-click: not tonight (volume back up)",
	OnRightClick = function()
		OldPeoplesToolkitDB.quiet.skippedFor = QuietNight()
		Check()
		ns.UpdateAuras()
	end,
})

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function()
	Check()
	C_Timer.NewTicker(10, Check)
end)
