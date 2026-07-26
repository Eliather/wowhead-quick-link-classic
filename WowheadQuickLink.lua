local addonName, nameSpace = ...
local localePathByLocale = {
    deDE = 'de/',
    esES = 'es/',
    esMX = 'mx/',
    frFR = 'fr/',
    itIT = 'it/',
    koKR = 'ko/',
    ptBR = 'pt/',
    ruRU = 'ru/',
    zhCN = 'cn/',
    zhTW = 'tw/',
}
local function GetWowheadLocalePath()
    local locale = GetLocale and GetLocale()
    if locale and localePathByLocale[locale] then
        return localePathByLocale[locale]
    end
    return ''
end
nameSpace.localePath = GetWowheadLocalePath()
nameSpace.baseWowheadUrl = 'https://%swowhead.com/classic/%s%s=%s%s'

local popupText = '%s Link\nCTRL-C to copy'

local function ShowUrlPopup(header, url)
    StaticPopup_Show('WowheadQuickLinkUrl', header, _, url)
end

local function CreateUrl(dataSources, strategies)
    for _, strategy in pairs(strategies) do
        local header, url = strategy(dataSources)
        if header and url then
            ShowUrlPopup(header, url)
            return
        end
    end
end

local function GetDataSources()
    local focus = {}
    local foci = GetMouseFoci()
    if foci[1] then
        focus = foci[1]
    end
    local tooltip = GameTooltip
    return {focus = focus, tooltip = tooltip}
end

function RunWowheadQuickLink()
    CreateUrl(GetDataSources(), nameSpace.strategies)
end

StaticPopupDialogs['WowheadQuickLinkUrl'] = {
    text = popupText,
    button1 = 'Close',
    OnShow = function(self, data)
        local function HidePopup(self) self:GetParent():Hide() end
        local editBox = self.EditBox or self.editBox
        if not editBox then return end
        editBox:SetScript('OnEscapePressed', HidePopup)
        editBox:SetScript('OnEnterPressed', HidePopup)
        editBox:SetScript('OnKeyUp', function(self, key)
            if IsControlKeyDown() and key == 'C' then HidePopup(self) end
        end)
        editBox:SetMaxLetters(0)
        editBox:SetText(data)
        editBox:HighlightText()
    end,
    hasEditBox = true,
    editBoxWidth = 240,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}
