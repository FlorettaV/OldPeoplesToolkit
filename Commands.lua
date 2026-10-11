-- Commands: everything under /oldperson (or /opt, short for Old People's
-- Toolkit), grouped per tool.

local _, ns = ...

-- Settings live in the options; commands are for doing things. Picking your
-- own icons is an extra, only in the README.
local HELP = {
	{ "/oldperson", "open the options" },
	"Old People's Stretch",
	{ "/oldperson stretch test", "show the stretch pop-up now" },
	{ "/oldperson stretch done", "I stood up and stretched: start the timer over" },
	"Alarm",
	{ "/oldperson alarm 15", "alarm in 15 minutes (or 1h30)" },
	{ "/oldperson alarm 22:30", "alarm at 22:30 (or 10pm)" },
	{ "/oldperson alarm off", "clear the alarm" },
	"Bedtime",
	{ "/oldperson bedtime 23:30", "set your bedtime" },
	"Where was I?",
	{ "/oldperson whereami", "where you are, your quests, and what your bags are filling up with" },
	{ "/oldperson whereami test", "the welcome-back window, as if you'd been away 3 days" },
	"Clock",
	{ "/oldperson clock reset", "move the clock back to the top, at the normal size" },
}

local function Help()
	ns.Print("commands (/opt works too):")
	for _, line in ipairs(HELP) do
		if type(line) == "string" then
			print(ns.GOLD .. line .. "|r")
		else
			print("  " .. ns.ACTION .. line[1] .. "|r - " .. line[2])
		end
	end
end

local function Stretch(args)
	local kind, name = args:match("^icon (%a+) (%S+)$")
	if args == "icon reset" then
		ns.SetIcon("stretchBuff", "reset")
		ns.SetIcon("stretchDebuff", "reset")
	elseif kind == "buff" or kind == "debuff" then
		ns.SetIcon(kind == "buff" and "stretchBuff" or "stretchDebuff", name)
	elseif not ns.StretchCommand(args) then
		Help()
	end
end

local function Alarm(args)
	local name = args:match("^icon (%S+)$")
	if name then
		ns.SetIcon("alarm", name)
	elseif args == "" then
		Help()
	else
		ns.SetAlarmFromText(args)
	end
end

local function Bedtime(args)
	local name = args:match("^icon (%S+)$")
	if name then
		ns.SetIcon("bedtime", name)
	elseif not ns.BedtimeCommand(args) then
		Help()
	end
end

local function Quiet(args)
	local name = args:match("^icon (%S+)$")
	if name then
		ns.SetIcon("quiet", name)
	else
		Help()
	end
end

SLASH_OLDPEOPLESTOOLKIT1 = "/oldperson"
SLASH_OLDPEOPLESTOOLKIT2 = "/opt"
SlashCmdList.OLDPEOPLESTOOLKIT = function(msg)
	msg = strtrim(msg or ""):lower()
	local tool, args = msg:match("^(%S*)%s*(.-)$")
	if msg == "" or msg == "options" then
		ns.OpenOptions()
	elseif tool == "stretch" then
		Stretch(args)
	elseif tool == "alarm" then
		Alarm(args)
	elseif msg == "clock reset" then
		ns.ResetClock()
	elseif tool == "bedtime" then
		Bedtime(args)
	elseif tool == "quiet" then
		Quiet(args)
	elseif msg == "whereami" or msg == "whereami test" then
		ns.ShowWhereWasI(args == "test")
	elseif msg == "debug" then -- for checking where the pretend (de)buffs go
		ns.DebugAuras()
	else
		Help() -- "help", or anything we don't know
	end
end

-- Called by the addon compartment (the addons button next to the minimap).
function OldPeoplesToolkit_OnAddonCompartmentClick()
	ns.OpenOptions()
end
