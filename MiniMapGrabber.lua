local addonName = "MiniMapGrabber"
local BUTTON_SIZE = 33
local PADDING = 5

-- MMG_ToggleButton style i use instead of an icon(for the button), to make it look like it's part of the default UI
local BG_COLOR = { r = 0.4, g = 0.2, b = 0.1 }
local TEXT_LABEL = "MMG"
local TEXT_COLOR = { r = 1, g = 0.82, b = 0 }

-- some default blizz frames i saw(tested on some wotlk based server)
local BLIZZ_NAMES = {
    ["MiniMapTracking"] = "Tracking", ["MiniMapMailFrame"] = "Mail Icon",
    ["MiniMapBattlefieldFrame"] = "PvP / BG Status", ["MiniMapWorldMapButton"] = "World Map Button",
    ["GameTimeFrame"] = "Calendar", ["TimeManagerClockButton"] = "Clock",
    ["MiniMapLFGFrame"] = "Dungeon Finder (Eye)", ["MiniMapInstanceDifficulty"] = "Dungeon Difficulty",
    ["MiniMapVoiceChatFrame"] = "Voice Chat",
}

local FORBIDDEN = {
    ["MinimapBackdrop"] = true, ["MinimapZoomIn"] = true, ["MinimapZoomOut"] = true,
    ["MiniMapPing"] = true, ["MinimapNorthTag"] = true, ["MMG_ToggleButton"] = true,
}

local originalPoints = {}

local Bag = CreateFrame("Frame", "MMG_Bag", UIParent)
Bag:SetFrameStrata("HIGH")
Bag:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 3, right = 3, top = 3, bottom = 3 }
})
Bag:SetBackdropColor(0, 0, 0, 0.9)
Bag:SetClampedToScreen(true)
Bag:Hide()

local Toggle = CreateFrame("Button", "MMG_ToggleButton", UIParent)
Toggle:SetSize(34, 34)
Toggle:SetFrameStrata("MEDIUM")
Toggle:SetClampedToScreen(true)
Toggle:SetMovable(true)
Toggle:RegisterForDrag("LeftButton")
Toggle:RegisterForClicks("LeftButtonUp", "RightButtonUp")

local bg = Toggle:CreateTexture(nil, "BACKGROUND")
bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background") 
bg:SetVertexColor(BG_COLOR.r, BG_COLOR.g, BG_COLOR.b, 1)
bg:SetSize(21, 21)
bg:SetPoint("CENTER", 0, 0)

local label = Toggle:CreateFontString(nil, "OVERLAY")
label:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
label:SetPoint("CENTER", 0, 0)
label:SetText(TEXT_LABEL)
label:SetTextColor(TEXT_COLOR.r, TEXT_COLOR.g, TEXT_COLOR.b)

local border = Toggle:CreateTexture(nil, "OVERLAY")
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
border:SetSize(52, 52)
border:SetPoint("TOPLEFT", 0, 0)
Toggle:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

local function CheckSettings()
    if not MMG_CustomSettings then MMG_CustomSettings = {} end
    if not MMG_CustomSettings.settings then MMG_CustomSettings.settings = {} end
    if MMG_CustomSettings.isLocked == nil then MMG_CustomSettings.isLocked = false end
end

local function UpdateBagPosition()
    Bag:ClearAllPoints()
    local x, y = Toggle:GetCenter()
    if x and x > (GetScreenWidth() / 2) then
        Bag:SetPoint("TOPRIGHT", Toggle, "TOPLEFT", -10, 10)
    else
        Bag:SetPoint("TOPLEFT", Toggle, "TOPRIGHT", 10, 10)
    end
end

local function GrabButtons()
    CheckSettings()
    local foundButtons = {}
    local parents = { Minimap, Bag }
    
    for _, parent in ipairs(parents) do
        local children = { parent:GetChildren() }
        for _, child in ipairs(children) do
            local name = child:GetName()
            if child:IsObjectType("Button") and name and not FORBIDDEN[name] then
                local isBlizzard = BLIZZ_NAMES[name] ~= nil
                local userSetting = MMG_CustomSettings.settings[name]
                local shouldGrab = (isBlizzard and userSetting == true) or (not isBlizzard and userSetting ~= false)

                if shouldGrab then
                    if not originalPoints[name] and child:GetParent() ~= Bag then
                        originalPoints[name] = {}
                        for i = 1, child:GetNumPoints() do
                            table.insert(originalPoints[name], {child:GetPoint(i)})
                        end
                    end
                    table.insert(foundButtons, child)
                else
                    if child:GetParent() == Bag then
                        child:SetParent(Minimap)
                        child:ClearAllPoints()
                        if originalPoints[name] then
                            for _, pointData in ipairs(originalPoints[name]) do
                                child:SetPoint(unpack(pointData))
                            end
                        else
                            child:SetPoint("CENTER", Minimap, "CENTER")
                        end
                    end
                end
            end
        end
    end

    local cols = 4
    if #foundButtons > 0 then
        for i, btn in ipairs(foundButtons) do
            btn:SetParent(Bag)
            btn:ClearAllPoints()
            local row, col = math.floor((i-1) / cols), (i-1) % cols
            btn:SetPoint("TOPLEFT", Bag, "TOPLEFT", (col * (BUTTON_SIZE + PADDING)) + PADDING, -(row * (BUTTON_SIZE + PADDING)) - PADDING)
        end
        local rowCount = math.ceil(#foundButtons / cols)
        Bag:SetSize((cols * (BUTTON_SIZE + PADDING)) + PADDING, (rowCount * (BUTTON_SIZE + PADDING)) + PADDING)
    else
        Bag:SetSize(10, 10)
        Bag:Hide()
    end
end

-- menu(right click)
local menuFrame = CreateFrame("Frame", "MMG_MenuFrame", UIParent, "UIDropDownMenuTemplate")
local function CreateMenu()
    CheckSettings()
    local menu = {
        { text = "Main Settings", isTitle = true, notCheckable = true },
        { text = "Lock UI Position", checked = MMG_CustomSettings.isLocked, func = function() MMG_CustomSettings.isLocked = not MMG_CustomSettings.isLocked end },
        { text = "Addon Buttons", isTitle = true, notCheckable = true },
    }

    local allButtons = {}
    for _, parent in ipairs({Minimap, Bag}) do
        for _, child in ipairs({parent:GetChildren()}) do
            local name = child:GetName()
            if child:IsObjectType("Button") and name and not FORBIDDEN[name] and not name:find("MinimapZoom") then
                allButtons[name] = true
            end
        end
    end

    local function RefreshMenu()
        GrabButtons()
        CloseMenus()
        EasyMenu(CreateMenu(), menuFrame, Toggle, 0, 0, "MENU")
    end

    for name in pairs(allButtons) do
        if not BLIZZ_NAMES[name] then
            local displayName = name
            local trash = { "LibDBIcon10_", "LibDBIcon_", "LDBIcon_", "LDB_", 
                            "FuBarPlugin-3.0_", "FuBarPlugin-2.0_", "FuBar_",
                            "MinimapButton", "MiniMapButton", "Minimap", "MiniMap", "Button",
                            "Launcher", "Broker", "Icon"}
            for _, pattern in ipairs(trash) do displayName = displayName:gsub(pattern, "") end
            displayName = displayName:gsub("_", " "):match("^%s*(.-)%s*$")
            if displayName == "" then displayName = name end

            table.insert(menu, {
                text = displayName, checked = (MMG_CustomSettings.settings[name] ~= false), keepShownOnClick = true,
                func = function()
                    MMG_CustomSettings.settings[name] = not (MMG_CustomSettings.settings[name] ~= false)
                    RefreshMenu()
                end
            })
        end
    end

    table.insert(menu, { text = "Blizzard Buttons", isTitle = true, notCheckable = true })
    for name, friendlyName in pairs(BLIZZ_NAMES) do
        table.insert(menu, {
            text = friendlyName, checked = (MMG_CustomSettings.settings[name] == true), keepShownOnClick = true,
            func = function()
                MMG_CustomSettings.settings[name] = not (MMG_CustomSettings.settings[name] == true)
                RefreshMenu()
            end
        })
    end
    return menu
end

Toggle:SetScript("OnDragStart", function(self) if not MMG_CustomSettings.isLocked then self:StartMoving(); Bag:Hide() end end)
Toggle:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    MMG_CustomSettings.buttonPos = { x = self:GetLeft(), y = self:GetTop() }
end)

Toggle:SetScript("OnClick", function(self, button)
    if button == "LeftButton" then
        if Bag:IsShown() then Bag:Hide() else UpdateBagPosition(); Bag:Show() end
    elseif button == "RightButton" then
        EasyMenu(CreateMenu(), menuFrame, self, 0, 0, "MENU")
    end
end)

-- Slash Commands
SLASH_MINIMAPGRABBER1 = "/mmg"
SlashCmdList["MINIMAPGRABBER"] = function(msg)
    if msg == "reset" then
        MMG_CustomSettings.buttonPos = nil
        Toggle:ClearAllPoints()
        Toggle:SetPoint("RIGHT", Minimap, "LEFT", -10, 0)
        Bag:Hide()
    end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_ENTERING_WORLD")
loader:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        CheckSettings()
        if MMG_CustomSettings.buttonPos then
            Toggle:ClearAllPoints()
            Toggle:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", MMG_CustomSettings.buttonPos.x, MMG_CustomSettings.buttonPos.y)
        else
            Toggle:SetPoint("RIGHT", Minimap, "LEFT", -10, 0)
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(2, GrabButtons)
    end
end)