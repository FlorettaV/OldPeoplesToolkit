-- Scrolls of Remembering, your target: "I wonder what this one is for".
-- Target anyone (a creature, a vendor, another player) and the scroll offers
-- to add their name to your note. For a creature, the note also keeps what
-- WoW's tooltip said about it, and hovering its name later shows that
-- tooltip with a sketch of its face under it.

local _, ns = ...

local Safe = ns.Safe
local SKETCH_TRIES = 8 -- every quarter second, so 2 seconds for WoW to find a face
local CLASSIFICATION = { rare = "Rare ", elite = "Elite ", rareelite = "Rare Elite ", worldboss = "Boss " }

-- The name of what you have targeted, not yourself. Nil without a target,
-- or when WoW keeps it secret.
function ns.TargetName()
	if not UnitExists("target") or UnitIsUnit("target", "player") then return nil end
	local name = Safe(UnitName, "target")
	if name and name ~= "" then return name end
end

-- The creature's ID, from its GUID ("Creature-0-...-<npcID>-...").
local function TargetCreature()
	local guid = Safe(UnitGUID, "target")
	if not guid then return nil end
	local kind, id = guid:match("^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)")
	if kind == "Creature" or kind == "Vehicle" then return tonumber(id) end
end

-- What WoW's own tooltip would say about your target, saved with the note:
-- the creature may be long gone (or uncached) when you hover it later.
function ns.TargetDetails(name)
	local id = TargetCreature()
	if not id then return { name = name } end -- a player, or WoW won't say
	return {
		name = name, id = id,
		level = Safe(UnitLevel, "target"),
		type = Safe(UnitCreatureType, "target"),
		classification = Safe(UnitClassification, "target"),
		reaction = Safe(UnitReaction, "target", "player"),
	}
end

---------------------------------------------------------------------------
-- The creature's tooltip, with a sketch of its face under it
---------------------------------------------------------------------------

local sketch
local hovers = 0

-- Its name in the color WoW's tooltip would use: red hostile, yellow
-- neutral, green friendly.
local function ReactionColor(reaction)
	if not reaction then return 1, 1, 1 end
	if reaction <= 3 then return 1, 0.25, 0.25 end
	if reaction == 4 then return 1, 1, 0 end
	return 0.25, 1, 0.25
end

-- creature: a note's creature (ns.TargetDetails). GameTooltip already has its owner.
function ns.ShowCreature(creature)
	GameTooltip:SetText(creature.name, ReactionColor(creature.reaction))
	if creature.level then
		local level = creature.level < 0 and "??" or tostring(creature.level)
		local kind = (CLASSIFICATION[creature.classification or ""] or "") .. (creature.type or "")
		GameTooltip:AddLine(strtrim("Level " .. level .. " " .. kind), 1, 1, 1)
	end
	GameTooltip:Show()

	if not sketch then
		sketch = CreateFrame("Frame", "OldPeoplesToolkitScrollSketch", UIParent)
		sketch:SetSize(120, 120)
		sketch:SetFrameStrata("TOOLTIP")
		ns.Parchment(sketch)
		sketch.model = CreateFrame("PlayerModel", nil, sketch)
		sketch.model:SetPoint("TOPLEFT", 4, -4)
		sketch.model:SetPoint("BOTTOMRIGHT", -4, 4)
		GameTooltip:HookScript("OnHide", function() sketch:Hide() end)
	end
	sketch:ClearAllPoints()
	sketch:SetPoint("TOPLEFT", GameTooltip, "BOTTOMLEFT", 0, -2)
	sketch.model:ClearModel()
	hovers = hovers + 1 -- only the latest hover keeps trying
	local hover = hovers
	sketch:SetAlpha(0)
	sketch:Show()
	-- A creature that isn't in WoW's cache (after a patch, or a cleared Cache
	-- folder) has no model the first time: WoW asks the server for it. So try
	-- again a few times, and only fade the sketch in once there's a face.
	local tries = 0
	local function Draw()
		if not sketch:IsShown() or hovers ~= hover then return end
		local model = sketch.model
		model:SetCreature(creature.id)
		model:SetPortraitZoom(0.75)
		model:SetFacing(0.35)
		local ok, file = pcall(model.GetModelFileID, model)
		if (ok and file and file ~= 0) or not model.GetModelFileID then
			if UIFrameFadeIn then UIFrameFadeIn(sketch, 0.2, sketch:GetAlpha(), 1) else sketch:SetAlpha(1) end
			if model.GetModelFileID then return end -- can't tell if it's there: keep redrawing a bit
		end
		tries = tries + 1
		if tries < SKETCH_TRIES then C_Timer.After(0.25, Draw) end
	end
	Draw()
end
