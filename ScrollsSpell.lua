-- Scrolls of Remembering as a "spell": a scroll icon you can drag to your
-- action bar, with a tooltip like a real spell's. The toolkit makes a macro
-- for it only when you drag it there, so it never takes one of your macro
-- slots uninvited. The scroll is also tucked in your spellbook, and the first
-- time you log in you "learn" it.
--
-- Also here: turning the scroll on and off (the options), and its keybind
-- (Bindings.xml: Esc > Options > Keybindings > AddOns).

local _, ns = ...

local MACRO_NAME = "Remembering" -- macro names are short; the tooltip has the full name
local MACRO_BODY = "/opt notes"
local OLD_MACRO_BODY = "/scrolls" -- the prototype's, before the scroll joined the toolkit

---------------------------------------------------------------------------
-- The spell
---------------------------------------------------------------------------

-- Like a real spell's tooltip: name, cast time, reagents, what it does.
local function FillSpellTooltip(dragHint)
	GameTooltip:ClearLines()
	GameTooltip:AddLine(ns.SCROLLS_NAME, 1, 1, 1)
	GameTooltip:AddDoubleLine("Instant", "No cooldown", 1, 1, 1, 1, 1, 1)
	GameTooltip:AddLine("Reagents: Something Important", 1, 1, 1)
	local r, g, b = ns.RGB(ns.GOLD) -- not inline: only the last argument passes all three
	GameTooltip:AddLine("Write down something you'll definitely forget otherwise. Remembers where you were standing.",
		r, g, b, true)
	if dragHint then
		ns.AddHint("Click: open or roll up the scroll")
		ns.AddHint("Drag: put it on your action bar")
	end
end

-- Makes the macro (if it isn't there yet) and puts it on your cursor.
local function PickUp()
	if InCombatLockdown() then
		ns.Say("You can't do that while in combat.")
		return
	end
	local index = GetMacroIndexByName(MACRO_NAME)
	if index == 0 then
		if GetNumMacros() >= (MAX_ACCOUNT_MACROS or 120) then
			ns.Say("Your macros are full. Make room for one more to put the scroll on your bar.")
			return
		end
		local icon = GetFileIDFromPath and GetFileIDFromPath(ns.SCROLLS_ICON) or "INV_Scroll_03"
		index = CreateMacro(MACRO_NAME, icon, MACRO_BODY, false)
	end
	if index and index > 0 then PickupMacro(index) end
end

-- The scroll icon: click to open the scroll, drag to your action bar.
function ns.AbilityButton(parent, size)
	local button = CreateFrame("Button", nil, parent)
	button:SetSize(size, size)
	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetAllPoints()
	icon:SetTexture(ns.SCROLLS_ICON)
	button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
	button:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
	button:RegisterForDrag("LeftButton")
	button:SetScript("OnClick", ns.ToggleScroll)
	button:SetScript("OnDragStart", PickUp)
	button:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		FillSpellTooltip(true)
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", GameTooltip_Hide)
	return button
end

-- On your action bar the macro's tooltip would only say "Remembering".
hooksecurefunc(GameTooltip, "SetAction", function(tooltip, slot)
	if tooltip ~= GameTooltip then return end
	local ok, kind, id = pcall(GetActionInfo, slot)
	if not ok or kind ~= "macro" or not ns.Usable(id) then return end
	if GetMacroInfo(id) ~= MACRO_NAME then return end
	FillSpellTooltip()
	GameTooltip:Show()
end)

-- The prototype's macro ran /scrolls, which is gone: point it at /opt notes.
-- Only when it's exactly that, so your own edits are left alone.
local function UpdateOldMacro()
	local index = GetMacroIndexByName(MACRO_NAME)
	if index == 0 or InCombatLockdown() then return end
	local name, icon, body = GetMacroInfo(index)
	if body and strtrim(body) == OLD_MACRO_BODY then EditMacro(index, name, icon, MACRO_BODY) end
end

local function Learn()
	ns.Say("You have learned a new spell: " .. ns.SPELL .. "[" .. ns.SCROLLS_NAME .. "]|r.")
	ns.Say("It's tucked in your spellbook, or type " .. ns.ACTION .. "/opt notes|r."
		.. " Drag the scroll icon to your action bar to cast it.")
	ns.Sound("UI_PROFESSIONS_NEW_RECIPE_LEARNED_TOAST")
	OldPeoplesToolkitDB.scrolls.learned = true
end

---------------------------------------------------------------------------
-- A bookmark in the spellbook
---------------------------------------------------------------------------

local bookmark, Follow

-- Addons can't add spells to the spellbook (and shouldn't touch its buttons:
-- they cast spells). So the scroll sticks out of the book's right edge, like
-- the old Classic spellbook's tabs: tucked behind the book, shown with it.
local function AddBookmark()
	local book = PlayerSpellsFrame
	local pages = book and book.SpellBookFrame
	if not pages or bookmark then return end
	bookmark = CreateFrame("Frame", nil, UIParent)
	bookmark:SetSize(54, 46)
	bookmark:SetPoint("TOPLEFT", book, "TOPRIGHT", -14, -150)
	ns.Parchment(bookmark)
	local ability = ns.AbilityButton(bookmark, 32)
	ability:SetPoint("RIGHT", -7, 0)
	function Follow()
		bookmark:SetShown(ns.ScrollsOn() and pages:IsVisible())
		bookmark:SetFrameStrata(book:GetFrameStrata())
		bookmark:SetFrameLevel(math.max(1, book:GetFrameLevel() - 1)) -- behind the book's edge
	end
	pages:HookScript("OnShow", Follow)
	pages:HookScript("OnHide", Follow)
	book:HookScript("OnHide", Follow)
	Follow()
end

-- The spellbook loads the first time you open it.
if C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Blizzard_PlayerSpells") then
	AddBookmark()
elseif EventUtil and EventUtil.ContinueOnAddOnLoaded then
	EventUtil.ContinueOnAddOnLoaded("Blizzard_PlayerSpells", AddBookmark)
end

---------------------------------------------------------------------------
-- On and off, the keybind, logging in
---------------------------------------------------------------------------

-- Used by the options. Off: the scroll is packed away (no bookmark, nothing
-- under Where was I?); the keybind, the macro and /opt notes say so.
-- On again: if you never learned it, you learn it now.
function ns.SetScrollsEnabled(on)
	if not on then ns.CloseScroll() end
	if Follow then Follow() end
	if ns.RefreshScrap then ns.RefreshScrap() end
	if on and not OldPeoplesToolkitDB.scrolls.learned then Learn() end
end

-- /opt notes            open or roll up the scroll
-- /opt notes <text>     write it down without opening the scroll
function ns.NotesCommand(text)
	if text == "" then ns.ToggleScroll() else ns.Jot(text) end
end

BINDING_HEADER_OLDPEOPLESTOOLKIT = "Old People's Toolkit"
BINDING_NAME_OLDPEOPLESTOOLKIT_SCROLL = ns.SCROLLS_NAME .. ": open or roll up"

function OldPeoplesToolkit_ToggleScroll() ns.ToggleScroll() end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function()
	UpdateOldMacro()
	-- After Where was I? (5 seconds), so the chat lines come after its window.
	C_Timer.After(7, function()
		local db = OldPeoplesToolkitDB.scrolls
		if db.enabled and not db.learned then Learn() end
	end)
end)
