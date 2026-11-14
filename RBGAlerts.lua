-- RBG Alerts: watch the rated battleground advertisements received by the client.
-- Searches are never initiated by the background listener.

local ADDON_NAME = ...
local RBG_CATEGORY_ID = 9
local MAX_VISIBLE_GROUPS = 8
local STALE_AFTER_SECONDS = 20 * 60
local RECENT_LISTING_SECONDS = 2 * 60
local WIDGET_WIDTH = 256
local HEADER_HEIGHT = 30
local ROW_HEIGHT = 39
local THEME_HEX = "b69e86"
local THEME_R, THEME_G, THEME_B = 182 / 255, 158 / 255, 134 / 255
local RATED_STATS_LOGO = "Interface\\AddOns\\RatedStats_RBGAlerts\\RatedStats.tga"
local headerIconText = ""

local defaults = {
    showWidget = true,
    showGroups = true,
    expanded = true,
    showAchievements = true,
    notifyChat = true,
    notifySound = true,
    lockPosition = false,
    x = 0,
    y = 160,
}

local db
local widget
local countText
local expandButton
local rows = {}
local footer
local settingsCategoryID
local known = {}         -- Current observed listing details, keyed by party GUID.
local announced = {}     -- Avoid repeating first-seen alerts for the same party.
local resultToParty = {} -- Resolve delisted updates by result ID.

local function Say(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cff" .. THEME_HEX .. "RBG Alerts:|r |cffffffff" .. message .. "|r")
end

local function IsSecret(value)
    return issecretvalue and issecretvalue(value)
end

local function IsReadableTable(value)
    if IsSecret(value) or type(value) ~= "table" then return false end
    return not canaccesstable or canaccesstable(value)
end

local function IsRBG(info)
    local ids = info.activityIDs
    if IsSecret(ids) then return nil end
    if ids == nil then return false end
    if not IsReadableTable(ids) then return nil end
    local matched = false
    for _, activityID in ipairs(ids) do
        if IsSecret(activityID) then return nil end
        if activityID == 19 then
            matched = true
        else
            local activity = C_LFGList.GetActivityInfoTable(activityID)
            if IsSecret(activity) then return nil end
            if activity ~= nil then
                if not IsReadableTable(activity) or IsSecret(activity.categoryID) then return nil end
                if activity.categoryID == RBG_CATEGORY_ID then matched = true end
            end
        end
    end
    return matched
end

local function IsAchievementsAvailable()
    return db.showAchievements
        and C_AddOns.IsAddOnLoaded("RatedStats_Achiev")
        and type(_G.RSTATS_Achiev_GetHighestPvpRank) == "function"
end

local function GetAchievement(leader)
    if leader and IsAchievementsAvailable() then
        return _G.RSTATS_Achiev_GetHighestPvpRank(leader)
    end
end

local function ShowRBGFinderHelp()
    -- Keep Blizzard's PvP panel state and protected queue controls untouched.
    -- Navigate using Blizzard's own buttons instead of addon-driven clicks.
    Say("Open Group Finder, select Player vs. Player > Premade Groups > Rated Battlegrounds, then click Find a Group.")
end

local function SavePosition()
    local x, y = widget:GetCenter()
    local parentX, parentY = UIParent:GetCenter()
    if x and y and parentX and parentY then
        db.x, db.y = x - parentX, y - parentY
    end
end

local function FormatAge(seconds)
    seconds = math.max(0, seconds or 0)
    if seconds < 60 then
        return math.floor(seconds) .. "s"
    end
    return math.floor(seconds / 60) .. "m"
end

local function ListingAge(entry)
    return (entry.age or 0) + math.max(0, GetTime() - entry.lastSeen)
end

local function SortedListings()
    local list = {}
    for _, entry in pairs(known) do
        list[#list + 1] = entry
    end
    table.sort(list, function(a, b)
        local aAge, bAge = ListingAge(a), ListingAge(b)
        if aAge ~= bAge then
            return aAge < bAge
        end
        return a.key < b.key
    end)
    return list
end

local function AddTooltip(target, entry)
    GameTooltip:SetOwner(target, "ANCHOR_RIGHT")
    GameTooltip:AddLine(entry.name or "Unnamed group", THEME_R, THEME_G, THEME_B)
    GameTooltip:AddDoubleLine("Leader", entry.leader or "Unknown", 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine("Members", tostring(entry.members), 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine("Listing age", FormatAge(ListingAge(entry)), 1, 1, 1, 1, 1, 1)
    GameTooltip:AddDoubleLine("Last observed", FormatAge(GetTime() - entry.lastSeen) .. " ago", 1, 1, 1, 1, 1, 1)
    GameTooltip:AddLine("Click for instructions to find Rated Battleground groups", 0.65, 0.79, 1)
    GameTooltip:Show()
end

local function CreateRow(index)
    local button = CreateFrame("Button", nil, widget)
    button:SetSize(WIDGET_WIDTH - 12, ROW_HEIGHT)
    button:SetPoint("TOP", widget, "TOP", 0, -HEADER_HEIGHT - 2 - (index - 1) * ROW_HEIGHT)

    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(THEME_R, THEME_G, THEME_B, index % 2 == 0 and 0.50 or 0.30)

    local name = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    name:SetPoint("TOPLEFT", 8, -5)
    name:SetWidth(WIDGET_WIDTH - 52)
    name:SetJustifyH("LEFT")
    name:SetWordWrap(false)
    name:SetTextColor(THEME_R, THEME_G, THEME_B)

    local detail = button:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    detail:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -3)
    detail:SetWidth(WIDGET_WIDTH - 52)
    detail:SetJustifyH("LEFT")
    detail:SetWordWrap(false)

    local achievement = CreateFrame("Frame", nil, button)
    achievement:SetSize(17, 17)
    achievement:SetPoint("RIGHT", button, "RIGHT", -7, 0)
    achievement:EnableMouse(true)
    local texture = achievement:CreateTexture(nil, "OVERLAY")
    texture:SetAllPoints()

    achievement:SetScript("OnEnter", function(self)
        local entry = button.entry
        if not entry or not IsAchievementsAvailable()
            or type(_G.RSTATS_Achiev_AddAchievementInfoToTooltip) ~= "function" then
            return
        end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local playerName, realm = strsplit("-", entry.leader or "")
        _G.RSTATS_Achiev_AddAchievementInfoToTooltip(GameTooltip, playerName, realm or GetRealmName())
        GameTooltip:Show()
    end)
    achievement:SetScript("OnLeave", GameTooltip_Hide)

    button:SetScript("OnEnter", function(self)
        if self.entry then AddTooltip(self, self.entry) end
    end)
    button:SetScript("OnLeave", GameTooltip_Hide)
    button:SetScript("OnClick", ShowRBGFinderHelp)

    button.nameText = name
    button.detailText = detail
    button.achievement = achievement
    button.achievementTexture = texture
    return button
end

local function UpdateWidget()
    if not widget then return end
    widget:SetShown(db.showWidget)
    local list = SortedListings()
    countText:SetText(headerIconText .. "|cff" .. THEME_HEX .. "RBG Groups:|r |cffffffff" .. #list .. "|r")

    local showRows = db.showGroups and db.expanded
    expandButton:SetShown(db.showGroups)
    expandButton:SetText("|cff" .. THEME_HEX .. (db.expanded and "-" or "+") .. "|r")

    local visible = showRows and math.min(#list, MAX_VISIBLE_GROUPS) or 0
    for i = 1, MAX_VISIBLE_GROUPS do
        local row = rows[i]
        if i <= visible then
            local entry = list[i]
            row.entry = entry
            row.nameText:SetText(entry.name)
            row.detailText:SetText(string.format("%s  |  %d members  |  %s old",
                entry.leader or "Unknown", entry.members, FormatAge(ListingAge(entry))))

            local iconPath, _, tint = GetAchievement(entry.leader)
            row.achievement:SetShown(iconPath ~= nil)
            if iconPath then
                row.achievementTexture:SetTexture(iconPath)
                if type(tint) == "table" then
                    row.achievementTexture:SetVertexColor(tint[1] or 1, tint[2] or 1, tint[3] or 1)
                else
                    row.achievementTexture:SetVertexColor(1, 1, 1)
                end
            end
            row:Show()
        else
            row.entry = nil
            row:Hide()
        end
    end

    local remaining = showRows and (#list - visible) or 0
    footer:SetShown(remaining > 0)
    if remaining > 0 then
        footer:SetText("+" .. remaining .. " more (open finder)")
    end
    widget:SetHeight(HEADER_HEIGHT + 6 + visible * ROW_HEIGHT + (remaining > 0 and 20 or 0))
end

local function RemoveOldListings()
    local now = GetTime()
    local changed = false
    for key, entry in pairs(known) do
        if now - entry.lastSeen > STALE_AFTER_SECONDS then
            known[key] = nil
            changed = true
        end
    end
    if changed then UpdateWidget() end
end

local function InspectResult(id)
    -- Validate before branching, indexing, formatting or caching API values.
    -- The second return value marks an incomplete/restricted observation.
    if IsSecret(id) or type(id) ~= "number" then return nil, true end
    local info = C_LFGList.GetSearchResultInfo(id)
    if not IsReadableTable(info) then return nil, true end
    if IsSecret(info.partyGUID) or IsSecret(info.isDelisted) then return nil, true end
    local key = info.partyGUID or tostring(id)
    if info.isDelisted then
        local oldKey = resultToParty[id] or key
        known[oldKey] = nil
        resultToParty[id] = nil
        return nil
    end
    local isRBG = IsRBG(info)
    if isRBG == nil then return nil, true end
    if not isRBG then return nil end
    if IsSecret(info.name) or IsSecret(info.leaderName)
        or IsSecret(info.numMembers) or IsSecret(info.age) then
        return nil, true
    end

    resultToParty[id] = key
    local previouslySeen = announced[key]
    known[key] = {
        key = key,
        id = id,
        name = info.name or "Unnamed group",
        leader = info.leaderName,
        members = info.numMembers or 0,
        age = info.age or 0,
        lastSeen = GetTime(),
    }
    announced[key] = true

    if not previouslySeen then
        if db.notifyChat then
            Say(string.format("Newly observed: %s | %s | %d members | %s old",
                known[key].name, known[key].leader or "Unknown",
                known[key].members, FormatAge(known[key].age)))
        end
        -- Do not sound an alert for an old listing merely discovered at login.
        if db.notifySound and known[key].age <= RECENT_LISTING_SECONDS then
            PlaySound(SOUNDKIT.READY_CHECK, "Master")
        end
    end
    return key
end

local function ReadResults()
    local _, ids = C_LFGList.GetSearchResults()
    if not IsReadableTable(ids) then return end
    local observed = {}
    local complete = true
    for _, id in ipairs(ids) do
        local key, unavailable = InspectResult(id)
        if unavailable then complete = false end
        if key then observed[key] = true end
    end

    -- Only treat a search as authoritative for RBGs while Blizzard's rated
    -- battleground search panel is actually visible. Other searches must not
    -- erase our observed RBG groups.
    local panel = LFGListFrame and LFGListFrame.SearchPanel
    if complete and panel and panel:IsVisible()
        and not IsSecret(panel.categoryID) and panel.categoryID == RBG_CATEGORY_ID then
        for key in pairs(known) do
            if not observed[key] then known[key] = nil end
        end
    end
    RemoveOldListings()
    UpdateWidget()
end

local function MakeWidget()
    widget = CreateFrame("Frame", "RBGAlertsWidget", UIParent, "BackdropTemplate")
    widget:SetSize(WIDGET_WIDTH, HEADER_HEIGHT + 6)
    widget:SetPoint("CENTER", UIParent, "CENTER", db.x, db.y)
    widget:SetFrameStrata("MEDIUM")
    widget:SetMovable(true)
    widget:SetClampedToScreen(true)
    widget:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = {left = 3, right = 3, top = 3, bottom = 3},
    })
    widget:SetBackdropColor(0.055, 0.045, 0.035, 0.93)
    widget:SetBackdropBorderColor(THEME_R, THEME_G, THEME_B, 0.9)

    local move = CreateFrame("Button", nil, widget)
    move:SetSize(21, 24)
    move:SetPoint("TOPLEFT", 4, -3)
    move:RegisterForDrag("LeftButton")
    move:SetNormalFontObject("GameFontNormalSmall")
    move:SetText("|cff" .. THEME_HEX .. "::|r")
    move:SetScript("OnDragStart", function()
        if not db.lockPosition then widget:StartMoving() end
    end)
    move:SetScript("OnDragStop", function()
        widget:StopMovingOrSizing()
        SavePosition()
    end)
    move:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(db.lockPosition and "Position locked" or "Drag to move RBG Alerts")
        GameTooltip:Show()
    end)
    move:SetScript("OnLeave", GameTooltip_Hide)

    local open = CreateFrame("Button", nil, widget)
    open:SetPoint("TOPLEFT", 26, -4)
    open:SetSize(WIDGET_WIDTH - 52, 23)
    open:SetScript("OnClick", ShowRBGFinderHelp)
    open:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
        GameTooltip:AddLine("Rated Battleground listings", THEME_R, THEME_G, THEME_B)
        GameTooltip:AddLine("Click for RBG Group Finder instructions", 1, 1, 1)
        GameTooltip:AddLine("Counts reflect listings received by the client; not a live global feed.", 0.65, 0.79, 1, true)
        GameTooltip:Show()
    end)
    open:SetScript("OnLeave", GameTooltip_Hide)

    headerIconText = "|T" .. RATED_STATS_LOGO .. ":22:22:0:0|t "

    countText = open:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    countText:SetPoint("LEFT", open, "LEFT", 4, 0)
    countText:SetJustifyH("LEFT")
    countText:SetTextColor(1, 1, 1)

    expandButton = CreateFrame("Button", nil, widget)
    expandButton:SetPoint("TOPRIGHT", -5, -5)
    expandButton:SetSize(22, 22)
    expandButton:SetNormalFontObject("GameFontNormalLarge")
    expandButton:SetScript("OnClick", function()
        db.expanded = not db.expanded
        UpdateWidget()
    end)
    expandButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(db.expanded and "Collapse group list" or "Expand group list")
        GameTooltip:Show()
    end)
    expandButton:SetScript("OnLeave", GameTooltip_Hide)

    for i = 1, MAX_VISIBLE_GROUPS do
        rows[i] = CreateRow(i)
    end
    footer = widget:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    footer:SetPoint("BOTTOM", widget, "BOTTOM", 0, 6)
    UpdateWidget()
end

local function MakeSettings()
    local panel = CreateFrame("Frame")
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("|cff" .. THEME_HEX .. "RatedStats - RBG Alerts|r")

    local description = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    description:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
    description:SetWidth(540)
    description:SetJustifyH("LEFT")
    description:SetText("Shows rated battleground advertisements received through Blizzard's Group Finder events. Does not run automatic searches; results can be incomplete or stale.")

    local options = {
        {"showWidget", "Show floating widget"},
        {"showGroups", "Show expandable group list"},
        {"showAchievements", "Show Rated Stats achievement badges when available"},
        {"notifyChat", "Announce newly observed groups in chat"},
        {"notifySound", "Play a sound for newly observed groups less than 2 minutes old"},
        {"lockPosition", "Lock widget position"},
    }
    for i, option in ipairs(options) do
        local key, text = option[1], option[2]
        local check = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
        check:SetPoint("TOPLEFT", 13, -83 - (i - 1) * 31)
        check.Text:SetText(text)
        check:SetScript("OnClick", function(self)
            db[key] = self:GetChecked() and true or false
            UpdateWidget()
        end)
        panel:HookScript("OnShow", function()
            check:SetChecked(db[key])
        end)
    end

    local reset = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    reset:SetSize(170, 23)
    reset:SetPoint("TOPLEFT", 17, -292)
    reset:SetText("Reset widget position")
    reset:SetScript("OnClick", function()
        db.x, db.y = defaults.x, defaults.y
        widget:ClearAllPoints()
        widget:SetPoint("CENTER", UIParent, "CENTER", db.x, db.y)
    end)

    -- OptionalDeps loads RatedStats first when enabled; it remains optional.
    local parentID = _G.RSTATS and _G.RSTATS.SettingsCategoryID
    local parent = parentID and Settings.GetCategory(parentID)
    local category
    if parent then
        category = Settings.RegisterCanvasLayoutSubcategory(parent, panel, "RBG Alerts")
    else
        category = Settings.RegisterCanvasLayoutCategory(panel, "RBG Alerts")
        Settings.RegisterAddOnCategory(category)
    end
    settingsCategoryID = category:GetID()
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("LFG_LIST_SEARCH_RESULT_UPDATED")
eventFrame:RegisterEvent("LFG_LIST_SEARCH_RESULTS_RECEIVED")
eventFrame:RegisterEvent("LFG_LIST_UPDATE_SEARCH_RESULTS")
eventFrame:SetScript("OnEvent", function(_, event, arg)
    if event == "ADDON_LOADED" then
        if arg ~= ADDON_NAME then return end
        RBGAlertsDB = RBGAlertsDB or {}
        db = RBGAlertsDB
        for key, value in pairs(defaults) do
            if db[key] == nil then db[key] = value end
        end
        MakeWidget()
        MakeSettings()
        eventFrame:UnregisterEvent("ADDON_LOADED")
        C_Timer.NewTicker(30, function()
            RemoveOldListings()
            UpdateWidget()
        end)
        ReadResults()
    elseif not db then
        return
    elseif event == "LFG_LIST_SEARCH_RESULT_UPDATED" then
        if not IsSecret(arg) and type(arg) == "number" then
            InspectResult(arg)
            RemoveOldListings()
            UpdateWidget()
        end
    else
        ReadResults()
    end
end)

SLASH_RBGALERTS1 = "/rbgalerts"
SlashCmdList.RBGALERTS = function(command)
    if not db then return end
    command = (command or ""):lower()
    if command == "toggle" then
        db.showWidget = not db.showWidget
        UpdateWidget()
    elseif command == "reset" then
        db.x, db.y = defaults.x, defaults.y
        widget:ClearAllPoints()
        widget:SetPoint("CENTER", UIParent, "CENTER", db.x, db.y)
    elseif command == "finder" then
        ShowRBGFinderHelp()
    else
        Settings.OpenToCategory(settingsCategoryID)
    end
end
