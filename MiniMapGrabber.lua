local addonName = "MiniMapGrabber"
local BUTTON_SIZE = 33
local PADDING = 5
local isRefreshing = false

local BG_COLOR = { r = 0.4, g = 0.2, b = 0.1 }
local TEXT_LABEL = "MMG"
local TEXT_COLOR = { r = 1, g = 0.82, b = 0 }

local BLIZZ_NAMES = {
    ["MiniMapTracking"] = "Tracking", ["MiniMapMailFrame"] = "Mail Icon",
    ["MiniMapBattlefieldFrame"] = "PvP / BG Status", ["MiniMapWorldMapButton"] = "World Map Button",
    ["GameTimeFrame"] = "Calendar", ["TimeManagerClockButton"] = "Clock",
    ["MiniMapLFGFrame"] = "Dungeon Finder (Eye)", ["MiniMapInstanceDifficulty"] = "Dungeon Difficulty",
    ["MiniMapVoiceChatFrame"] = "Voice Chat",
}

local FORBIDDEN_FRAMES = {
    ["MinimapBackdrop"] = true, ["MinimapZoomIn"] = true, ["MinimapZoomOut"] = true,
    ["MiniMapPing"] = true, ["MinimapNorthTag"] = true, ["MMG_Button"] = true,
}

local originalButtonPositions = {}

local MMG_ButtonMenu = CreateFrame("Frame", "MMG_ButtonMenu", UIParent)
MMG_ButtonMenu:SetFrameStrata("HIGH")
MMG_ButtonMenu:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 3, right = 3, top = 3, bottom = 3 }
})
MMG_ButtonMenu:SetBackdropColor(0, 0, 0, 0.9)
MMG_ButtonMenu:SetClampedToScreen(true)
MMG_ButtonMenu:EnableMouse(true)
MMG_ButtonMenu:Hide()
tinsert(UISpecialFrames, "MMG_ButtonMenu")

local MMG_Button = CreateFrame("Button", "MMG_Button", UIParent)
MMG_Button:SetSize(34, 34)
MMG_Button:SetFrameStrata("MEDIUM")
MMG_Button:SetClampedToScreen(true)
MMG_Button:SetMovable(true)
MMG_Button:RegisterForDrag("LeftButton")
MMG_Button:RegisterForClicks("LeftButtonUp", "RightButtonUp")

local MMG_ButtonBG = MMG_Button:CreateTexture(nil, "BACKGROUND")
MMG_ButtonBG:SetTexture("Interface\\Minimap\\UI-Minimap-Background") 
MMG_ButtonBG:SetVertexColor(BG_COLOR.r, BG_COLOR.g, BG_COLOR.b, 1)
MMG_ButtonBG:SetSize(21, 21)
MMG_ButtonBG:SetPoint("CENTER", 0, 0)

local MMG_ButtonLabel = MMG_Button:CreateFontString(nil, "OVERLAY")
MMG_ButtonLabel:SetFont("Fonts\\FRIZQT__.TTF", 9, "OUTLINE")
MMG_ButtonLabel:SetPoint("CENTER", 0, 0)
MMG_ButtonLabel:SetText(TEXT_LABEL)
MMG_ButtonLabel:SetTextColor(TEXT_COLOR.r, TEXT_COLOR.g, TEXT_COLOR.b)

local MMG_ButtonBorder = MMG_Button:CreateTexture(nil, "OVERLAY")
MMG_ButtonBorder:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
MMG_ButtonBorder:SetSize(52, 52)
MMG_ButtonBorder:SetPoint("TOPLEFT", 0, 0)
MMG_Button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

local function GetCleanName(name)
    if BLIZZ_NAMES[name] then return BLIZZ_NAMES[name] end
    local cleanName = name
    local techStrings = { "LibDBIcon10_", "LibDBIcon_", "LDBIcon_", "LDB_", "FuBarPlugin-3.0_", "FuBarPlugin-2.0_", "FuBar_", "MinimapButton", "MiniMapButton", "Minimap", "MiniMap", "Button", "Launcher", "Broker", "Icon" }
    for _, pattern in ipairs(techStrings) do cleanName = cleanName:gsub(pattern, "") end
    cleanName = cleanName:gsub("_", " "):match("^%s*(.-)%s*$")
    return (cleanName == "" and name) or cleanName
end

local function CheckSavedSettings()
    if not MMG_CustomSettings then MMG_CustomSettings = {} end
    if not MMG_CustomSettings.settings then MMG_CustomSettings.settings = {} end
    if MMG_CustomSettings.isLocked == nil then MMG_CustomSettings.isLocked = false end
    if MMG_CustomSettings.showOnHover == nil then MMG_CustomSettings.showOnHover = false end
end

local function UpdateMenuPosition()
    MMG_ButtonMenu:ClearAllPoints()
    local x, y = MMG_Button:GetCenter()
    if x and x > (GetScreenWidth() / 2) then
        MMG_ButtonMenu:SetPoint("TOPRIGHT", MMG_Button, "TOPLEFT", -10, 10)
    else
        MMG_ButtonMenu:SetPoint("TOPLEFT", MMG_Button, "TOPRIGHT", 10, 10)
    end
end

local function GrabMinimapButtons()
    CheckSavedSettings()
    local buttonData, processedButtons = {}, {}
    local parentContainers = { Minimap, MMG_ButtonMenu }
    
    for _, parent in ipairs(parentContainers) do
        local children = { parent:GetChildren() }
        for _, child in ipairs(children) do
            local name = child:GetName()
            if child:IsObjectType("Button") and name and not FORBIDDEN_FRAMES[name] and not name:match("^pfMiniMapPin") and not processedButtons[name] then
                processedButtons[name] = true
                local isBlizz = BLIZZ_NAMES[name] ~= nil
                local userPref = MMG_CustomSettings.settings[name]
                local shouldBeGrabbed = (isBlizz and userPref == true) or (not isBlizz and userPref ~= false)

                local isAlreadyInMenu = (child:GetParent() == MMG_ButtonMenu)
                if shouldBeGrabbed and (isAlreadyInMenu or (child:IsVisible() and child:GetWidth() > 0)) then
                    if not originalButtonPositions[name] and not isAlreadyInMenu then
                        originalButtonPositions[name] = {}
                        for i = 1, child:GetNumPoints() do
                            table.insert(originalButtonPositions[name], {child:GetPoint(i)})
                        end
                    end
                    table.insert(buttonData, { frame = child, cleanName = GetCleanName(name) })
                else
                    if isAlreadyInMenu then
                        child:SetParent(Minimap)
                        child:ClearAllPoints()
                        if originalButtonPositions[name] then
                            for _, pointData in ipairs(originalButtonPositions[name]) do
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

    table.sort(buttonData, function(a, b) return a.cleanName:lower() < b.cleanName:lower() end)

    local columns = 4
    if #buttonData > 0 then
        for i, data in ipairs(buttonData) do
            local btn = data.frame
            btn:SetParent(MMG_ButtonMenu)
            btn:ClearAllPoints()
            local row, col = math.floor((i-1) / columns), (i-1) % columns
            btn:SetPoint("TOPLEFT", MMG_ButtonMenu, "TOPLEFT", (col * (BUTTON_SIZE + PADDING)) + PADDING, -(row * (BUTTON_SIZE + PADDING)) - PADDING)
        end
        local totalRows = math.ceil(#buttonData / columns)
        MMG_ButtonMenu:SetSize((columns * (BUTTON_SIZE + PADDING)) + PADDING, (totalRows * (BUTTON_SIZE + PADDING)) + PADDING)
    else
        MMG_ButtonMenu:SetSize(10, 10)
        MMG_ButtonMenu:Hide()
    end
end

local MMG_MenuFrame = CreateFrame("Frame", "MMG_MenuFrame", UIParent, "UIDropDownMenuTemplate")

local function PopulateRightClickMenu()
    CheckSavedSettings()
    
    local function RefreshUI()
        isRefreshing = true
        GrabMinimapButtons()
        CloseMenus()
        EasyMenu(PopulateRightClickMenu(), MMG_MenuFrame, MMG_Button, 0, 0, "MENU")
        isRefreshing = false
    end

    local menuOptions = {
        { text = "Main Settings", isTitle = true, notCheckable = true },
        { text = "Lock UI Position", checked = MMG_CustomSettings.isLocked, keepShownOnClick = true, func = function() MMG_CustomSettings.isLocked = not MMG_CustomSettings.isLocked; RefreshUI() end },
        { text = "Show on Hover", checked = MMG_CustomSettings.showOnHover, keepShownOnClick = true, func = function() MMG_CustomSettings.showOnHover = not MMG_CustomSettings.showOnHover; RefreshUI() end },
        { text = "Addon Buttons", isTitle = true, notCheckable = true },
    }

    local addonList = {}
    for _, parent in ipairs({Minimap, MMG_ButtonMenu}) do
        for _, child in ipairs({parent:GetChildren()}) do
            local name = child:GetName()
            -- Added: not name:match("^pfPin") keeps them out of the right-click list
            if child:IsObjectType("Button") and name and not FORBIDDEN_FRAMES[name] and not name:find("MinimapZoom") and not name:match("^pfPin") and not BLIZZ_NAMES[name] then
                local found = false
                for _, item in ipairs(addonList) do if item.name == name then found = true break end end
                if not found then table.insert(addonList, { name = name, display = GetCleanName(name) }) end
            end
        end
    end

    table.sort(addonList, function(a, b) return a.display:lower() < b.display:lower() end)

    for _, addon in ipairs(addonList) do
        table.insert(menuOptions, {
            text = addon.display, checked = (MMG_CustomSettings.settings[addon.name] ~= false), keepShownOnClick = true,
            func = function() MMG_CustomSettings.settings[addon.name] = not (MMG_CustomSettings.settings[addon.name] ~= false); RefreshUI() end
        })
    end

    table.insert(menuOptions, { text = "Blizzard Buttons", isTitle = true, notCheckable = true })
    local blizzList = {}
    for internal, display in pairs(BLIZZ_NAMES) do table.insert(blizzList, { name = internal, display = display }) end
    table.sort(blizzList, function(a, b) return a.display:lower() < b.display:lower() end)

    for _, blizz in ipairs(blizzList) do
        table.insert(menuOptions, {
            text = blizz.display, checked = (MMG_CustomSettings.settings[blizz.name] == true), keepShownOnClick = true,
            func = function() MMG_CustomSettings.settings[blizz.name] = not (MMG_CustomSettings.settings[blizz.name] == true); RefreshUI() end
        })
    end
    return menuOptions
end

hooksecurefunc("CloseMenus", function()
    if isRefreshing then return end
    if MMG_ButtonMenu:IsShown() then
        if not MMG_CustomSettings.showOnHover or not (MouseIsOver(MMG_Button) or MouseIsOver(MMG_ButtonMenu)) then
            MMG_ButtonMenu:Hide()
        end
    end
end)

local function HideIfNecessary()
    if MMG_CustomSettings.showOnHover then
        C_Timer.After(0.05, function()
            local menuOpen = DropDownList1 and DropDownList1:IsShown() and UIDROPDOWNMENU_OPEN_MENU == MMG_MenuFrame
            if not MouseIsOver(MMG_Button) and not MouseIsOver(MMG_ButtonMenu) and not menuOpen then
                MMG_ButtonMenu:Hide()
            end
        end)
    end
end

MMG_Button:SetScript("OnEnter", function()
    if MMG_CustomSettings.showOnHover then
        GrabMinimapButtons()
        UpdateMenuPosition()
        MMG_ButtonMenu:Show()
    end
end)

MMG_Button:SetScript("OnLeave", HideIfNecessary)
MMG_ButtonMenu:SetScript("OnLeave", HideIfNecessary)

MMG_Button:SetScript("OnDragStart", function(self) if not MMG_CustomSettings.isLocked then self:StartMoving(); MMG_ButtonMenu:Hide() end end)
MMG_Button:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    MMG_CustomSettings.buttonPos = { x = self:GetLeft(), y = self:GetTop() }
end)

MMG_Button:SetScript("OnClick", function(self, clickType)
    if clickType == "LeftButton" then
        if MMG_ButtonMenu:IsShown() then MMG_ButtonMenu:Hide() else GrabMinimapButtons(); UpdateMenuPosition(); MMG_ButtonMenu:Show() end
    elseif clickType == "RightButton" then
        if DropDownList1:IsShown() and UIDROPDOWNMENU_OPEN_MENU == MMG_MenuFrame then
            CloseMenus()
        else
            GrabMinimapButtons()
            UpdateMenuPosition()
            MMG_ButtonMenu:Show()
            EasyMenu(PopulateRightClickMenu(), MMG_MenuFrame, self, 0, 0, "MENU")
        end
    end
end)

MMG_ButtonMenu:SetScript("OnHide", function()
    CloseMenus()
end)

SLASH_MMG1 = "/mmg"
SlashCmdList["MMG"] = function(msg)
    if msg == "reset" then
        MMG_CustomSettings.buttonPos = nil
        MMG_Button:ClearAllPoints()
        MMG_Button:SetPoint("RIGHT", Minimap, "LEFT", -10, 0)
        MMG_ButtonMenu:Hide()
    end
end

local EventDelegate = CreateFrame("Frame")
EventDelegate:RegisterEvent("ADDON_LOADED")
EventDelegate:RegisterEvent("PLAYER_ENTERING_WORLD")
EventDelegate:RegisterEvent("PLAYER_REGEN_DISABLED")
EventDelegate:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        CheckSavedSettings()
        if MMG_CustomSettings.buttonPos then
            MMG_Button:ClearAllPoints()
            MMG_Button:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", MMG_CustomSettings.buttonPos.x, MMG_CustomSettings.buttonPos.y)
        else
            MMG_Button:SetPoint("RIGHT", Minimap, "LEFT", -10, 0)
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(2, GrabMinimapButtons)
    elseif event == "PLAYER_REGEN_DISABLED" then
        MMG_ButtonMenu:Hide()
        CloseMenus()
    end
end)