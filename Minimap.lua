-- Minimap: a round pocket-watch button on the minimap's edge.
--   Click: options    Drag: move it around the minimap's edge

local _, ns = ...

local ICON = "Interface\\Icons\\INV_Misc_PocketWatch_01"
local button

local function UpdatePosition()
	local angle = math.rad(OldPeoplesToolkitDB.minimapButton.angle)
	local radius = Minimap:GetWidth() / 2 + 10
	button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

-- While dragging, follow the cursor around the minimap's edge.
local function OnDragUpdate()
	local mx, my = Minimap:GetCenter()
	local cx, cy = GetCursorPosition()
	local scale = Minimap:GetEffectiveScale()
	OldPeoplesToolkitDB.minimapButton.angle = math.deg(math.atan2(cy / scale - my, cx / scale - mx))
	UpdatePosition()
end

local function CreateButton()
	button = CreateFrame("Button", "OldPeoplesToolkitMinimapButton", Minimap)
	button:SetSize(31, 31)
	button:SetFrameStrata("MEDIUM")
	button:SetFrameLevel(8)
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	button:RegisterForDrag("LeftButton")
	button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

	local background = button:CreateTexture(nil, "BACKGROUND")
	background:SetSize(20, 20)
	background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
	background:SetPoint("TOPLEFT", 7, -5)

	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetSize(17, 17)
	icon:SetTexture(ICON)
	icon:SetPoint("TOPLEFT", 7, -6)

	local border = button:CreateTexture(nil, "OVERLAY")
	border:SetSize(53, 53)
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	border:SetPoint("TOPLEFT")

	button:SetScript("OnClick", function() ns.OpenOptions() end)
	button:SetScript("OnDragStart", function(self) self:SetScript("OnUpdate", OnDragUpdate) end)
	button:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
	button:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:AddLine("Old People's Toolkit")
		ns.AddHint("Click: options")
		ns.AddHint("Drag: move this button")
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", GameTooltip_Hide)

	UpdatePosition()
	button:SetShown(OldPeoplesToolkitDB.minimapButton.show)
end

-- Used by the options.
function ns.SetMinimapButtonShown(shown)
	OldPeoplesToolkitDB.minimapButton.show = shown
	if button then button:SetShown(shown) end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", CreateButton)
