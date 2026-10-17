-- Scrolls of Remembering: a notebook for the things you'll definitely forget.
-- "What is this meat for?", "someone said Mankrik, go look", "something weird
-- here, come back some time". Each note quietly remembers where you were
-- standing.
--
-- A notebook, not a to-do list: no titles, dates, tags or sorting. Click a
-- note to cross it out, right-click a crossed-out note to tear it off,
-- shift-click it for a pin on your map. You open the scroll, take your time,
-- and roll it up again: it never stays on screen while you play.
--
-- This file: the notes and the scroll window. Creatures.lua: your
-- target and its face. Spell.lua: the scroll as a "spell" (action bar,
-- spellbook, "You have learned"). WhereWasI.lua shows your last scribble.
--
-- Saved in OldPeoplesToolkitDB.scrolls, for your whole account (you remember
-- things, not your character): enabled, learned, point (where you dragged the
-- scroll) and
--   notes = { { text, when, zone, subZone, mapID, x, y, by, crossed, creature }, ... }, newest first

local _, ns = ...

ns.SCROLLS_NAME = "Scrolls of Remembering"
ns.SCROLLS_ICON = "Interface\\Icons\\INV_Scroll_03"

local PER_PAGE = 5
local WIDTH = 380
local ROW_HEIGHT = 54
local CLOSE_AFTER = 1.2 -- seconds the new note stays in view before the scroll rolls up

-- Colors of the scroll. In chat and tooltips it uses the toolkit's (Core.lua).
ns.SPELL = "|cff71d5ff" -- how WoW colors a spell's name in chat
ns.INK = { 0.24, 0.15, 0.05 } -- writing on the parchment
ns.FADED = { 0.48, 0.38, 0.26 } -- the small print, crossed-out notes
ns.RUBRIC = "|cffa8321e" -- the red ink for items and names

local Safe = ns.Safe

-- A yellow line in chat without "Toolkit:" in front, like WoW's own
-- "You have learned...": the scroll talks like the game does.
function ns.Say(msg)
	local info = ChatTypeInfo and ChatTypeInfo.SYSTEM
	DEFAULT_CHAT_FRAME:AddMessage(msg, info and info.r or 1, info and info.g or 1, info and info.b or 0)
end

function ns.Sound(name)
	if SOUNDKIT and SOUNDKIT[name] then PlaySound(SOUNDKIT[name]) end
end

function ns.ScrollsOn()
	return OldPeoplesToolkitDB.scrolls.enabled
end

-- Turned off, the scroll is put away, and says so when you reach for it.
local function PackedAway()
	ns.Say("Your " .. ns.SPELL .. ns.SCROLLS_NAME .. "|r are packed away. Unpack them in "
		.. ns.ACTION .. "/opt|r.")
end

-- Item links are colored for chat, and most of those colors don't show on
-- parchment. On paper every link is written in red ink, like a scribe marks
-- what matters; the rarity is in the item's tooltip when you hover it.
-- Links can be "|cffffffff|H..." or "|cnIQ1:|H...". Names you added from
-- your target are written as "[Mankrik]" and get the same ink.
-- note: optional; with it, the creature you added from your target becomes a
-- link you can hover for its tooltip and face ("|Hscrolls:npc:3061|h[...]|h").
function ns.OnPaper(text, note)
	local creature = note and note.creature
	if creature and creature.id then
		local name = "[" .. creature.name .. "]"
		local at = text:find(name, 1, true)
		if at then
			text = text:sub(1, at - 1) .. ns.RUBRIC .. "|Hscrolls:npc:" .. creature.id .. "|h" .. name .. "|h|r"
				.. text:sub(at + #name)
		end
	end
	text = text:gsub("|c%x%x%x%x%x%x%x%x(|H)", ns.RUBRIC .. "%1")
	text = text:gsub("|cn[^:|]+:(|H)", ns.RUBRIC .. "%1")
	-- Plain [brackets]; a link's own brackets come right after "|h".
	return ((" " .. text):gsub("([^h])(%[[^%]|]+%])", "%1" .. ns.RUBRIC .. "%2|r"):sub(2))
end

---------------------------------------------------------------------------
-- The notes
---------------------------------------------------------------------------

-- Where you're standing: zone, subzone and map coordinates. Inside dungeons
-- WoW often gives no coordinates; then it's just the zone.
local function Here()
	local here = { zone = Safe(GetZoneText), subZone = Safe(GetSubZoneText) }
	local mapID = C_Map and Safe(C_Map.GetBestMapForUnit, "player")
	local pos = mapID and Safe(C_Map.GetPlayerMapPosition, mapID, "player")
	if pos then
		local ok, x, y = pcall(pos.GetXY, pos)
		if ok and ns.Usable(x) and ns.Usable(y) and (x > 0 or y > 0) then
			here.mapID, here.x, here.y = mapID, x, y
		end
	end
	return here
end

function ns.Notes()
	return OldPeoplesToolkitDB.scrolls.notes
end

-- Your newest note that isn't crossed out (for Where was I?).
function ns.LastScribble()
	for _, note in ipairs(ns.Notes()) do
		if not note.crossed then return note end
	end
end

function ns.Jot(text)
	if not ns.ScrollsOn() then
		PackedAway()
		return false
	end
	text = strtrim((text or ""):gsub("  +", " ")) -- the target button adds a space, so do you
	if text == "" then return false end
	local target = ns.TargetName()
	-- %t: your target's name, like in chat.
	if target then text = text:gsub("%%t", function() return "[" .. target .. "]" end) end
	local note = Here()
	note.text, note.when, note.by = text, time(), GetUnitName("player", true)
	if target and text:find("[" .. target .. "]", 1, true) then
		note.creature = ns.TargetDetails(target)
	end
	table.insert(ns.Notes(), 1, note)
	ns.Sound("IG_ABILITY_PAGE_TURN")
	ns.Say("You scribble a note on your " .. ns.SPELL .. ns.SCROLLS_NAME .. "|r.")
	ns.RefreshScroll()
	return true
end

local function Ago(seconds)
	local function Plural(n, word) return n .. " " .. word .. (n == 1 and "" or "s") .. " ago" end
	if seconds < 60 then return "just now" end
	if seconds < 3600 then return Plural(math.floor(seconds / 60), "minute") end
	if seconds < 86400 then return Plural(math.floor(seconds / 3600), "hour") end
	local days = math.floor(seconds / 86400)
	if days == 1 then return "yesterday" end
	if days < 14 then return Plural(days, "day") end
	if days < 60 then return Plural(math.floor(days / 7), "week") end
	return Plural(math.floor(days / 30), "month")
end

-- "Raven Hill, Duskwood"
local function Place(note)
	local zone, sub = note.zone, note.subZone
	if zone and zone ~= "" and sub and sub ~= "" and sub ~= zone then return sub .. ", " .. zone end
	if zone and zone ~= "" then return zone end
	return "Somewhere"
end

-- "Raven Hill, Duskwood (34, 62), 3 days ago"
local function WhereText(note)
	local text = Place(note)
	if note.x then
		text = text .. string.format(" (%d, %d)", math.floor(note.x * 100 + 0.5), math.floor(note.y * 100 + 0.5))
	end
	text = text .. ", " .. Ago(time() - note.when)
	if note.by and note.by ~= GetUnitName("player", true) then text = text .. ", by " .. note.by end
	return text
end

-- Blizzard's own map pin, the one you'd set by ctrl-clicking the map.
local function PinOnMap(note)
	if not (note.mapID and C_Map and C_Map.SetUserWaypoint and UiMapPoint) then
		ns.Say("You don't remember exactly where that was.")
		return
	end
	if C_Map.CanSetUserWaypointOnMap and not Safe(C_Map.CanSetUserWaypointOnMap, note.mapID) then
		ns.Say("You can't put a pin on that map.")
		return
	end
	local ok = pcall(C_Map.SetUserWaypoint, UiMapPoint.CreateFromCoordinates(note.mapID, note.x, note.y))
	if not ok then return end
	if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
		pcall(C_SuperTrack.SetSuperTrackedUserWaypoint, true)
	end
	ns.Sound("UI_MAP_WAYPOINT_CONTROL_CLICK")
	ns.Say("You put a pin on your map: " .. Place(note) .. ".")
end

---------------------------------------------------------------------------
-- The parchment look, shared with the face sketch, the spellbook bookmark
-- and the scrap under Where was I?
---------------------------------------------------------------------------

function ns.Ink(fontString, fontObject, faded)
	fontString:SetFontObject(_G[fontObject] or GameFontHighlight)
	fontString:SetTextColor(unpack(faded and ns.FADED or ns.INK))
	fontString:SetShadowOffset(0, 0)
end

local function Band(frame, point, flip)
	local band = frame:CreateTexture(nil, "BORDER")
	band:SetHeight(12)
	band:SetPoint(point .. "LEFT", -6, 0)
	band:SetPoint(point .. "RIGHT", 6, 0)
	band:SetColorTexture(1, 1, 1)
	local dark, light = CreateColor(0.36, 0.23, 0.11, 1), CreateColor(0.66, 0.5, 0.3, 1)
	if flip then dark, light = light, dark end
	pcall(band.SetGradient, band, "VERTICAL", dark, light)
	return band
end

-- rolls: the dark rolled-up ends at the top and bottom of a scroll.
function ns.Parchment(frame, rolls)
	local bg = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
	bg:SetAllPoints()
	bg:SetColorTexture(0.88, 0.8, 0.63)
	local grain = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
	grain:SetAllPoints()
	if not (grain.SetAtlas and grain:SetAtlas("QuestBG-Parchment")) then grain:Hide() end
	grain:SetAlpha(0.7)
	-- A thin brown edge all round.
	for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
		local edge = frame:CreateTexture(nil, "BORDER")
		edge:SetColorTexture(0.45, 0.32, 0.18, 0.9)
		if side == "TOP" or side == "BOTTOM" then
			edge:SetHeight(1)
			edge:SetPoint(side .. "LEFT")
			edge:SetPoint(side .. "RIGHT")
		else
			edge:SetWidth(1)
			edge:SetPoint("TOP" .. side)
			edge:SetPoint("BOTTOM" .. side)
		end
	end
	if rolls and CreateColor then
		Band(frame, "TOP", true)
		Band(frame, "BOTTOM")
	end
end

---------------------------------------------------------------------------
-- The scroll window
---------------------------------------------------------------------------

local window, input, placeholder, tip, rows, empty, pageText, prevPage, nextPage
local page = 1

local function NoteAt(row)
	return ns.Notes()[(page - 1) * PER_PAGE + row.index]
end

-- Crossing out: a line of ink through each line of the note.
local function Strike(row, crossed)
	local text = row.text
	local lines = crossed and math.min(text:GetNumLines() or 1, #row.strokes) or 0
	local width = text:GetWidth()
	local total = (text.GetUnboundedStringWidth and text:GetUnboundedStringWidth()) or text:GetStringWidth()
	local _, size = text:GetFont()
	local lineHeight = (size or 13) + text:GetSpacing()
	for i, stroke in ipairs(row.strokes) do
		if i <= lines then
			local w = i < lines and width or math.max(20, math.min(width, total - (lines - 1) * width))
			stroke:ClearAllPoints()
			stroke:SetPoint("LEFT", text, "TOPLEFT", -2, -(i - 1) * lineHeight - lineHeight / 2)
			stroke:SetWidth(w + 4)
			stroke:Show()
		else
			stroke:Hide()
		end
	end
end

local function ShowRowHints(row)
	local note = NoteAt(row)
	if not note then return end
	GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
	GameTooltip:SetText(note.crossed and "Crossed out" or "A scribble", 1, 1, 1)
	ns.AddHint(note.crossed and "Click: un-cross it" or "Click: cross it out")
	if note.crossed then ns.AddHint("Right-click: tear it off") end
	if note.x then ns.AddHint("Shift-click: put a pin on your map") end
	GameTooltip:Show()
end

local function OnRowClick(row, button)
	local index = (page - 1) * PER_PAGE + row.index
	local note = ns.Notes()[index]
	if not note then return end
	if IsShiftKeyDown() then
		PinOnMap(note)
	elseif button == "RightButton" then
		if not note.crossed then return end -- tearing off needs crossing out first: no accidents
		table.remove(ns.Notes(), index)
		ns.Sound("IG_ABILITY_PAGE_TURN")
	else
		note.crossed = not note.crossed or nil
		ns.Sound("IG_QUEST_LOG_ABANDON_QUEST")
	end
	ns.RefreshScroll()
	if row:IsMouseOver() then ShowRowHints(row) end
end

local function CreateRow(index)
	local row = CreateFrame("Button", nil, window)
	row.index = index
	row:SetSize(WIDTH - 56, ROW_HEIGHT - 6)
	row:SetPoint("TOPLEFT", 28, -124 - (index - 1) * ROW_HEIGHT)
	row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

	row.text = row:CreateFontString(nil, "ARTWORK")
	ns.Ink(row.text, "QuestFont")
	row.text:SetPoint("TOPLEFT")
	row.text:SetWidth(WIDTH - 56)
	row.text:SetJustifyH("LEFT")
	row.text:SetMaxLines(2)

	row.where = row:CreateFontString(nil, "ARTWORK")
	ns.Ink(row.where, "GameFontNormalSmall", true)
	row.where:SetPoint("TOPLEFT", row.text, "BOTTOMLEFT", 0, -3)
	row.where:SetWidth(WIDTH - 56)
	row.where:SetJustifyH("LEFT")
	row.where:SetMaxLines(1)

	row.strokes = {}
	for i = 1, 2 do
		local stroke = row:CreateTexture(nil, "OVERLAY")
		stroke:SetHeight(2)
		stroke:SetColorTexture(ns.INK[1], ns.INK[2], ns.INK[3], 0.8)
		stroke:Hide()
		row.strokes[i] = stroke
	end

	local hover = row:CreateTexture(nil, "HIGHLIGHT")
	hover:SetPoint("TOPLEFT", -6, 3)
	hover:SetPoint("BOTTOMRIGHT", 6, -3)
	hover:SetColorTexture(0.55, 0.4, 0.2, 0.12)

	row:SetScript("OnClick", OnRowClick)
	row:SetScript("OnEnter", ShowRowHints)
	row:SetScript("OnLeave", GameTooltip_Hide)
	-- Item links and creature names in a note show their tooltip.
	if pcall(row.SetHyperlinksEnabled, row, true) then
		row:SetScript("OnHyperlinkEnter", function(self, link)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			local note = NoteAt(self)
			if link:match("^scrolls:npc:") and note and note.creature then
				ns.ShowCreature(note.creature)
				return
			end
			pcall(GameTooltip.SetHyperlink, GameTooltip, link)
			GameTooltip:Show()
		end)
		row:SetScript("OnHyperlinkLeave", function(self)
			if self:IsMouseOver() then ShowRowHints(self) else GameTooltip:Hide() end
		end)
		-- Clicking a link does what clicking the note does: links are for hovering.
		row:SetScript("OnHyperlinkClick", function(self, _, _, button) OnRowClick(self, button) end)
	end
	return row
end

local function PageButton(direction, x)
	local button = CreateFrame("Button", nil, window)
	button:SetSize(28, 28)
	button:SetPoint("BOTTOM", x, 20)
	local base = "Interface\\Buttons\\UI-SpellbookIcon-" .. direction .. "Page-"
	button:SetNormalTexture(base .. "Up")
	button:SetPushedTexture(base .. "Down")
	button:SetDisabledTexture(base .. "Disabled")
	button:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
	button:SetScript("OnClick", function()
		page = page + (direction == "Next" and 1 or -1)
		ns.Sound("IG_ABILITY_PAGE_TURN")
		ns.RefreshScroll()
	end)
	return button
end

local function UpdatePlaceholder()
	placeholder:SetShown(input:GetText() == "" and not input:HasFocus())
end

-- The line under the writing line: a tip, or with a target, a button that
-- adds its name.
local function UpdateTip()
	if not tip then return end
	local name = ns.TargetName()
	if name then
		tip.text:SetText("Click here to add your target: " .. ns.RUBRIC .. "[" .. name .. "]|r")
	else
		tip.text:SetText("Shift-click an item, or target someone, to add them.")
	end
	tip:EnableMouse(name ~= nil)
end

local function CreateWindow()
	local db = OldPeoplesToolkitDB.scrolls
	window = CreateFrame("Frame", "OldPeoplesToolkitScroll", UIParent)
	window:SetSize(WIDTH, 124 + PER_PAGE * ROW_HEIGHT + 48)
	window:SetPoint("CENTER", 260, 40)
	if db.point then
		window:ClearAllPoints()
		window:SetPoint(db.point[1], UIParent, db.point[2], db.point[3], db.point[4])
	end
	window:SetFrameStrata("DIALOG")
	window:SetToplevel(true)
	window:EnableMouse(true)
	window:SetMovable(true)
	window:SetClampedToScreen(true)
	window:RegisterForDrag("LeftButton")
	window:SetScript("OnDragStart", window.StartMoving)
	window:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local point, _, relativePoint, x, y = self:GetPoint()
		db.point = { point, relativePoint, x, y }
	end)
	window:SetScript("OnHide", function() ns.Sound("IG_QUEST_LOG_CLOSE") end)
	window:Hide()
	table.insert(UISpecialFrames, "OldPeoplesToolkitScroll") -- close with Escape
	ns.Parchment(window, true)

	local close = CreateFrame("Button", nil, window, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", -2, -12)

	local ability = ns.AbilityButton(window, 34)
	ability:SetPoint("TOPLEFT", 20, -22)

	local title = window:CreateFontString(nil, "ARTWORK")
	ns.Ink(title, "QuestTitleFont")
	title:SetPoint("LEFT", ability, "RIGHT", 10, 0)
	title:SetText(ns.SCROLLS_NAME)

	-- Where you write. Enter: write it down. Escape: roll up the scroll.
	input = CreateFrame("EditBox", nil, window)
	input:SetSize(WIDTH - 56, 22)
	input:SetPoint("TOPLEFT", 28, -70)
	input:SetAutoFocus(false)
	input:SetMaxLetters(255)
	input:SetFontObject(_G.QuestFont or GameFontHighlight)
	input:SetTextColor(unpack(ns.INK))
	input:SetShadowOffset(0, 0)
	local line = input:CreateTexture(nil, "BORDER")
	line:SetHeight(1)
	line:SetPoint("BOTTOMLEFT", 0, -1)
	line:SetPoint("BOTTOMRIGHT", 0, -1)
	line:SetColorTexture(ns.INK[1], ns.INK[2], ns.INK[3], 0.5)
	placeholder = input:CreateFontString(nil, "ARTWORK")
	ns.Ink(placeholder, "QuestFont", true)
	placeholder:SetPoint("LEFT", 2, 0)
	placeholder:SetText("Write something down...")

	tip = CreateFrame("Button", nil, window)
	tip:SetPoint("TOPLEFT", input, "BOTTOMLEFT", 0, -3)
	tip:SetSize(WIDTH - 56, 16)
	tip.text = tip:CreateFontString(nil, "ARTWORK")
	ns.Ink(tip.text, "GameFontNormalSmall", true)
	tip.text:SetPoint("LEFT")
	tip:SetScript("OnClick", function()
		local name = ns.TargetName()
		if not name then return end
		local text = input:GetText()
		input:SetText(text .. ((text == "" or text:sub(-1) == " ") and "" or " ") .. "[" .. name .. "] ")
		input:SetFocus()
		input:SetCursorPosition(#input:GetText())
	end)
	tip:SetScript("OnEnter", function(self)
		if ns.TargetName() then self.text:SetAlpha(0.7) end
	end)
	tip:SetScript("OnLeave", function(self) self.text:SetAlpha(1) end)
	window:RegisterEvent("PLAYER_TARGET_CHANGED")
	window:SetScript("OnEvent", UpdateTip)

	input:SetScript("OnEditFocusGained", UpdatePlaceholder)
	input:SetScript("OnEditFocusLost", UpdatePlaceholder)
	input:SetScript("OnTextChanged", UpdatePlaceholder)
	input:SetScript("OnEscapePressed", function() window:Hide() end) -- what you typed stays, as a draft
	input:SetScript("OnEnterPressed", function(self)
		page = 1 -- the new note goes on top of the first page
		if not ns.Jot(self:GetText()) then return self:ClearFocus() end
		self:SetText("")
		self:ClearFocus()
		-- Let the new note sink in, then roll up. Unless you're using the scroll.
		C_Timer.After(CLOSE_AFTER, function()
			if window:IsShown() and not window:IsMouseOver() and not input:HasFocus() then window:Hide() end
		end)
	end)

	rows = {}
	for i = 1, PER_PAGE do rows[i] = CreateRow(i) end

	empty = window:CreateFontString(nil, "ARTWORK")
	ns.Ink(empty, "QuestFont", true)
	empty:SetPoint("TOP", 0, -160)
	empty:SetWidth(WIDTH - 80)
	empty:SetText("Nothing written down yet.\n\nWhat was it you wanted to remember?")

	prevPage = PageButton("Prev", -70)
	nextPage = PageButton("Next", 70)
	pageText = window:CreateFontString(nil, "ARTWORK")
	ns.Ink(pageText, "GameFontNormalSmall", true)
	pageText:SetPoint("BOTTOM", 0, 29)
end

-- After a note changed: the scroll and the scrap under Where was I?.
function ns.RefreshScroll()
	if ns.RefreshScrap then ns.RefreshScrap() end
	if not window or not window:IsShown() then return end
	local notes = ns.Notes()
	local pages = math.max(1, math.ceil(#notes / PER_PAGE))
	page = math.min(math.max(page, 1), pages)
	for _, row in ipairs(rows) do
		local note = NoteAt(row)
		row:SetShown(note ~= nil)
		if note then
			row.text:SetText(ns.OnPaper(note.text, note))
			row.where:SetText(WhereText(note))
			row.text:SetAlpha(note.crossed and 0.55 or 1)
			row.where:SetAlpha(note.crossed and 0.55 or 1)
			Strike(row, note.crossed)
		end
	end
	empty:SetShown(#notes == 0)
	pageText:SetText(pages > 1 and ("Page " .. page .. " of " .. pages) or "")
	prevPage:SetShown(pages > 1)
	nextPage:SetShown(pages > 1)
	prevPage:SetEnabled(page > 1)
	nextPage:SetEnabled(page < pages)
end

function ns.CloseScroll()
	if window then window:Hide() end
end

-- Opens the scroll with the pen ready, or rolls it up again.
function ns.ToggleScroll()
	if window and window:IsShown() then
		window:Hide()
		return
	end
	if not ns.ScrollsOn() then
		PackedAway()
		return
	end
	if not window then CreateWindow() end
	page = 1
	window:Show()
	ns.Sound("IG_QUEST_LOG_OPEN")
	ns.RefreshScroll()
	UpdateTip()
	UpdatePlaceholder()
	-- A frame later: opened with a key (keybind, action bar), that same key
	-- would otherwise be typed into the note.
	C_Timer.After(0, function()
		if window:IsShown() then input:SetFocus() end
	end)
end

-- Shift-clicking an item while you're writing puts its link in your note.
-- Mainline moved this from ChatEdit_InsertLink to ChatFrameUtil.InsertLink;
-- hook whichever is there (if both, the same click comes in once per frame).
local lastLink, lastTime
local function InsertLink(link)
	if not (link and input and input:IsVisible() and input:HasFocus()) then return end
	if link == lastLink and lastTime == GetTime() then return end
	lastLink, lastTime = link, GetTime()
	input:Insert(link)
end
if ChatFrameUtil and ChatFrameUtil.InsertLink then hooksecurefunc(ChatFrameUtil, "InsertLink", InsertLink) end
if ChatEdit_InsertLink then hooksecurefunc("ChatEdit_InsertLink", InsertLink) end
