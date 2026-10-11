-- Where was I?: when you log in after a while away (8 hours by default), a
-- small window tells you when and where you last played, which quests you
-- were busy with, and what your bags were filling up with (farming meat,
-- crafting bandages). Nothing to write down: it watches your quest log and
-- your bags.
--
-- Saved in OldPeoplesToolkitDB.whereWasI: enabled, awayHours, and per
-- character (by GUID: Forever characters can share a first name):
--   characters[guid] = { name, lastSeen, zone, subZone, level,
--                        quests = { [questID] = when you last made progress },
--                        gains = { { id = itemID, link, count, when }, ... } }

local _, ns = ...

local SHOW_QUESTS = 3 -- how many recent quests the window lists
local GAINS_WINDOW = 30 * 60 -- what you gained in the last 30 minutes before logging out
local GAINS_MIN = 10 -- at least this many of one item, or it's not farming
local SHOW_ITEMS = 2 -- how many items the window lists
ns.WHERE_LIMITS = { 1, 48 } -- the options slider: away for 1 to 48 hours

local char -- this character's saved data
local awayFor -- seconds since you last played, at this login (nil: first time)
local lastSession -- when you last played (char.lastSeen at this login)
local lastLog -- the quest log as we last saw it: [questID] = its progress, as text
local ready = false -- the quest log has had time to load after logging in
local window

---------------------------------------------------------------------------
-- Watching the quest log
---------------------------------------------------------------------------

local function Safe(fn, ...)
	if not fn then return nil end
	local ok, result = pcall(fn, ...)
	if ok and ns.Usable(result) then return result end
end

-- Every quest in your log, with its progress written out, so we can see which
-- ones changed: { [questID] = "8/12 Raptor Head;done" }.
local function ReadQuestLog()
	local log = {}
	for i = 1, Safe(C_QuestLog.GetNumQuestLogEntries) or 0 do
		local info = Safe(C_QuestLog.GetInfo, i)
		if info and not info.isHeader and not info.isHidden and info.questID then
			local parts = {}
			for _, objective in ipairs(Safe(C_QuestLog.GetQuestObjectives, info.questID) or {}) do
				table.insert(parts, tostring(objective.text) .. (objective.finished and "+" or ""))
			end
			table.insert(parts, Safe(C_QuestLog.IsComplete, info.questID) and "done" or "")
			log[info.questID] = table.concat(parts, ";")
		end
	end
	return log
end

local function OnQuestLogChanged()
	if not ready then return end
	local log = ReadQuestLog()
	-- The first time we see quests is our starting point, not progress. (New
	-- quests are noted by QUEST_ACCEPTED below, so a log that loads late
	-- doesn't make every quest look new.)
	if lastLog and next(lastLog) then
		for questID, progress in pairs(log) do
			if lastLog[questID] and lastLog[questID] ~= progress then
				char.quests[questID] = time() -- made progress
			end
		end
	end
	-- Quests that left the log (turned in, abandoned) aren't "where you were"
	-- anymore. An empty log might just not be loaded, so then we keep them.
	if next(log) then
		for questID in pairs(char.quests) do
			if not log[questID] then char.quests[questID] = nil end
		end
	end
	lastLog = log
end

-- QUEST_LOG_UPDATE comes in bursts; look once they've settled.
local pending = false
local function QuestLogChangedSoon()
	if pending then return end
	pending = true
	C_Timer.After(1, function()
		pending = false
		OnQuestLogChanged()
	end)
end

---------------------------------------------------------------------------
-- Watching the bags
---------------------------------------------------------------------------

-- We count what's in your bags after every change and remember what went up.
-- Looting, gathering and crafting all end up there. What goes down (selling,
-- crafting reagents, using things) doesn't count, and neither does anything
-- while a bank, mailbox, vendor, trade or auction window is open: that only
-- moves things you already had, and it's how you close up shop.

local lastBags -- { [itemID] = how many } as we last counted
local busy = {} -- [interaction type] = true while one of those windows is open

local function Interactions()
	local types, kinds = Enum and Enum.PlayerInteractionType, {}
	if not types then return kinds end
	for _, name in ipairs({ "Banker", "AccountBanker", "GuildBanker", "MailInfo", "Merchant", "TradePartner",
		"Auctioneer", "VoidStorage" }) do
		if types[name] then kinds[types[name]] = true end
	end
	return kinds
end
local CLOSE_UP = Interactions()

-- Grey junk and quest items (those already show with the quests) never count.
local function Counts(info)
	if not (info and ns.Usable(info.itemID) and ns.Usable(info.stackCount)) then return false end
	if ns.Usable(info.quality) and info.quality == 0 then return false end -- Enum.ItemQuality.Poor
	local ok, _, _, _, _, _, classID = pcall(C_Item.GetItemInfoInstant, info.itemID)
	return not (ok and classID == 12) -- Enum.ItemClass.Questitem
end

local function CountBags()
	local counts, links = {}, {}
	local lastBag = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4 -- with the reagent bag, if there is one
	for bag = 0, lastBag do
		for slot = 1, Safe(C_Container.GetContainerNumSlots, bag) or 0 do
			local info = Safe(C_Container.GetContainerItemInfo, bag, slot)
			if Counts(info) then
				counts[info.itemID] = (counts[info.itemID] or 0) + info.stackCount
				links[info.itemID] = info.hyperlink
			end
		end
	end
	return counts, links
end

local function OnBagsChanged()
	if not ready or not char then return end
	local counts, links = CountBags()
	-- The first count is our starting point. So is an empty one: the bags
	-- might not be loaded yet, and then everything would look new.
	if lastBags and next(lastBags) and not next(busy) then
		local now = time()
		for itemID, count in pairs(counts) do
			local gained = count - (lastBags[itemID] or 0)
			if gained > 0 then
				table.insert(char.gains, { id = itemID, link = links[itemID], count = gained, when = now })
			end
		end
		-- Only the last half hour matters.
		for i = #char.gains, 1, -1 do
			if char.gains[i].when < now - GAINS_WINDOW then table.remove(char.gains, i) end
		end
	end
	lastBags = counts
end

-- What you gained most of in the half hour before the end (your last logout,
-- or now): { { link, icon, count }, ... }, at most SHOW_ITEMS.
local function TopGains(ending)
	local totals, links = {}, {}
	for _, gain in ipairs(char.gains) do
		if gain.when >= ending - GAINS_WINDOW and gain.when <= ending then
			totals[gain.id] = (totals[gain.id] or 0) + gain.count
			links[gain.id] = gain.link or links[gain.id]
		end
	end
	local list = {}
	for itemID, count in pairs(totals) do
		if count >= GAINS_MIN then table.insert(list, { id = itemID, link = links[itemID], count = count }) end
	end
	table.sort(list, function(a, b) return a.count > b.count end)
	for i = #list, SHOW_ITEMS + 1, -1 do list[i] = nil end
	return list
end

local function RememberWhere()
	if not char then return end
	char.lastSeen = time()
	local zone, subZone, level = GetRealZoneText(), GetSubZoneText(), UnitLevel("player")
	if ns.Usable(zone) and zone ~= "" then char.zone = zone end
	if ns.Usable(subZone) then char.subZone = subZone ~= "" and subZone ~= char.zone and subZone or nil end
	if ns.Usable(level) then char.level = level end
end

---------------------------------------------------------------------------
-- The window
---------------------------------------------------------------------------

local GOLD, WHITE, GREEN, GREY = ns.GOLD, ns.WHITE, ns.GREEN, ns.GREY

-- "3 days", "5 hours", "20 minutes"
local function Ago(seconds)
	local function Plural(n, word) return n .. " " .. word .. (n == 1 and "" or "s") end
	if seconds >= 2 * 86400 then return Plural(math.floor(seconds / 86400), "day") end
	if seconds >= 2 * 3600 then return Plural(math.floor(seconds / 3600), "hour") end
	return Plural(math.max(1, math.floor(seconds / 60)), "minute")
end

-- The quests you were busy with that are still in your log: most recent first.
local function RecentQuests()
	local list = {}
	for questID, when in pairs(char.quests) do
		if not lastLog or lastLog[questID] then table.insert(list, { id = questID, when = when }) end
	end
	table.sort(list, function(a, b) return a.when > b.when end)
	return list
end

local function QuestLines(questID)
	local title = Safe(C_QuestLog.GetTitleForQuestID, questID) or ("Quest " .. questID)
	if Safe(C_QuestLog.IsComplete, questID) then
		return { WHITE .. title .. "|r  " .. GREEN .. "ready to turn in|r" }
	end
	local lines = { WHITE .. title .. "|r" }
	for _, objective in ipairs(Safe(C_QuestLog.GetQuestObjectives, questID) or {}) do
		if not objective.finished and ns.Usable(objective.text) then
			table.insert(lines, "   " .. GREY .. "- " .. objective.text .. "|r")
		end
	end
	return lines
end

-- away: seconds since you last played, or nil to say where you are now.
local function WindowText(away)
	local lines = {}
	local where = char.zone and (char.subZone and (char.subZone .. ", " .. char.zone) or char.zone)
	if away then
		table.insert(lines, "Last played " .. GOLD .. Ago(away) .. " ago|r"
			.. (where and (" in " .. GOLD .. where .. "|r") or "")
			.. (char.level and (", at level " .. char.level) or "") .. ".")
	elseif where then
		table.insert(lines, "You're in " .. GOLD .. where .. "|r.")
	end
	table.insert(lines, " ")

	local quests = RecentQuests()
	local gains = TopGains(away and lastSession or time())
	if #quests == 0 and #gains == 0 then
		table.insert(lines, GREY .. "Nothing on your plate. A fresh start!" .. "|r")
	end
	if #quests > 0 then
		table.insert(lines, GOLD .. (away and "You were working on:" or "You're working on:") .. "|r")
		for i = 1, math.min(SHOW_QUESTS, #quests) do
			for _, line in ipairs(QuestLines(quests[i].id)) do table.insert(lines, line) end
		end
	end
	if #gains > 0 then
		if #quests > 0 then table.insert(lines, " ") end
		table.insert(lines, GOLD .. (away and "Your bags were filling up with:" or "Your bags are filling up with:") .. "|r")
		for _, gain in ipairs(gains) do
			local icon = Safe(C_Item.GetItemIconByID, gain.id)
			table.insert(lines, (icon and ("|T" .. icon .. ":16|t ") or "")
				.. (gain.link or ("Item " .. gain.id)) .. WHITE .. "  x" .. gain.count .. "|r")
		end
	end
	return table.concat(lines, "\n")
end

local function CreateWindow()
	window = ns.CreateDialog("OldPeoplesToolkitWhereWasI", 400) -- the height follows the text
	window:SetPoint("CENTER", 0, 160)
	table.insert(UISpecialFrames, "OldPeoplesToolkitWhereWasI") -- close with Escape

	window.title = window:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	window.title:SetPoint("TOP", 0, -24)
	window.title:SetText("Where was I?")

	window.text = window:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	window.text:SetPoint("TOPLEFT", 28, -24 - 24 - 8)
	window.text:SetWidth(344)
	window.text:SetJustifyH("LEFT")
	window.text:SetSpacing(2)

	local ok = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
	ok:SetSize(110, 24)
	ok:SetPoint("BOTTOM", 0, 22)
	ok:SetText("Got it")
	ok:SetScript("OnClick", function() window:Hide() end)
end

local function ShowWindow(away)
	if not window then CreateWindow() end
	window.text:SetText(WindowText(away))
	-- Top border, title, text, button, bottom border.
	window:SetHeight(24 + 24 + 8 + window.text:GetStringHeight() + 16 + 24 + 22)
	window:Show()
end

---------------------------------------------------------------------------
-- Used by /oldperson whereami
---------------------------------------------------------------------------

local TEST_AWAY = 3 * 86400 -- /oldperson whereami test: as if you'd been away 3 days

-- test: show the welcome-back window as if you'd been away, instead of
-- where you are now.
function ns.ShowWhereWasI(test)
	if not ready then return end
	RememberWhere()
	OnQuestLogChanged()
	OnBagsChanged()
	ShowWindow(test and TEST_AWAY or nil)
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_LOGOUT")
events:RegisterEvent("QUEST_LOG_UPDATE")
events:RegisterEvent("QUEST_ACCEPTED")
events:RegisterEvent("BAG_UPDATE_DELAYED")
-- Mainline: one pair of events for the bank, mailbox, vendor and so on.
pcall(events.RegisterEvent, events, "PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
pcall(events.RegisterEvent, events, "PLAYER_INTERACTION_MANAGER_FRAME_HIDE")
events:SetScript("OnEvent", function(_, event, arg)
	if event == "PLAYER_LOGIN" then
		local key = UnitGUID("player")
		local db = OldPeoplesToolkitDB.whereWasI
		char = db.characters[key] or { quests = {} }
		db.characters[key] = char
		char.gains = char.gains or {}
		char.name = GetUnitName("player", true)
		lastSession = char.lastSeen
		awayFor = char.lastSeen and time() - char.lastSeen
		-- Give the quest log a few seconds to load before reading it.
		C_Timer.After(5, function()
			ready = true
			OnQuestLogChanged()
			if db.enabled and awayFor and awayFor >= db.awayHours * 3600 then ShowWindow(awayFor) end
			-- The starting count, after the window: it also forgets gains older
			-- than half an hour, like the ones from last time.
			OnBagsChanged()
			RememberWhere()
		end)
		C_Timer.NewTicker(60, RememberWhere)
	elseif event == "PLAYER_LOGOUT" then
		RememberWhere()
	elseif event == "BAG_UPDATE_DELAYED" then
		OnBagsChanged()
	elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" or event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" then
		local kind = arg -- which kind of window
		if not CLOSE_UP[kind] then return end
		-- Count the bags first: whatever changed before it opened was real.
		if event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" then OnBagsChanged() end
		busy[kind] = event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" or nil
		-- Closing it: take the bags as they are now, so what moved in doesn't count.
		if not busy[kind] and ready then lastBags = CountBags() end
	elseif event == "QUEST_ACCEPTED" then
		if char and ns.Usable(arg) then char.quests[arg] = time() end -- arg: the questID
		QuestLogChangedSoon()
	else
		QuestLogChangedSoon()
	end
end)
