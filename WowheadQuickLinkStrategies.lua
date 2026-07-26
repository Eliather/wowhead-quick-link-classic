local addonName, nameSpace = ...
nameSpace.strategies = {}
local strategies = {
    wowhead = {}
}
local tooltipStates = {}

function nameSpace.strategies.GetWowheadUrl(dataSources)
    for _, strategy in pairs(strategies.wowhead) do
        local id, type = strategy(dataSources)
        if id and type then
            local typeStr
            if type == "npc" then
                typeStr = type:upper()
            else
                typeStr = type:sub(1, 1):upper() .. type:sub(2)
            end
            return "Wowhead " .. typeStr,
                string.format(nameSpace.baseWowheadUrl, WowheadQuickLinkCfg.prefix, nameSpace.localePath, type, id, WowheadQuickLinkCfg.suffix)
        end
    end
end

local function GetFromLink(link)
    if not link then return end
    local _, _, type, id = link:find("%|?H?(%a+):(%d+):")
    if type == "questie" then return id, "quest" end
    return id, type
end

function strategies.wowhead.GetHyperlinkFromTooltip()
    for _, tooltip in pairs(tooltipStates) do
        if tooltip.hyperlink then
            return GetFromLink(tooltip.hyperlink)
        end
    end
end

function strategies.wowhead.GetAuraFromTooltip()
    for _, tooltip in pairs(tooltipStates) do
        if tooltip.aura then
            return tooltip.aura, "spell"
        end
    end
end

function strategies.wowhead.GetAuraFromInstanceID(data)
    if not data.focus.auraInstanceID or not data.focus.unit then return end
    local aura = C_UnitAuras.GetAuraDataByAuraInstanceID(data.focus.unit, data.focus.auraInstanceID)
    if not aura then return end
    return aura.spellId, "spell"
end

function strategies.wowhead.GetItemFromTooltip(data)
    if not data.tooltip then return end
    local _, link = data.tooltip:GetItem()
    return GetFromLink(link)
end

function strategies.wowhead.GetSpellFromTooltip(data)
    if not data.tooltip then return end
    return select(2, data.tooltip:GetSpell()), "spell"
end

function strategies.wowhead.GetAchievementFromFocus(data)
    if not data.focus.id or not data.focus.dateCompleted then return end
    return data.focus.id, "achievement"
end

function strategies.wowhead.GetKrowisAchievementFromFocus(data)
    if not data.focus.Achievement or not data.focus.Achievement.Id then return end
    return data.focus.Achievement.Id, "achievement"
end

function strategies.wowhead.GetQuestFromFocus(data)
    if not data.focus.questID then return end
    return data.focus.questID, "quest"
end

function strategies.wowhead.GetQuestFromClassicLogTitleFocus(data)
    if not (CheckFrameName("QuestLogTitle%d+", data) and not data.focus.isHeader) then return end
    local questIndex = data.focus:GetID()
    local _, _, _, _, _, _, _, questID = GetQuestLogTitle(questIndex)
    if questID == 0 then return end
    return questID, "quest"
end

function strategies.wowhead.GetQuestFromQuestieTracker(data)
    if not (data.focus.Quest and type(data.focus.Quest) == "table") then return end
    return data.focus.Quest.Id, "quest"
end

function strategies.wowhead.GetQuestFromQuestieFrame(data)
    if not CheckFrameName("QuestieFrame%d+", data) then return end
    if data.focus.data.QuestData then return data.focus.data.QuestData.Id, "quest" end
    if data.focus.data.npcData then return data.focus.data.npcData.id, "npc" end
end

function strategies.wowhead.GetRuneEnchantmentFromRuneFocus(data)
    if not CheckFrameName("EngravingFrameScrollFrameButton%d+", data) then return end
    local abilityID = data.focus.skillLineAbilityID
    for _, category in ipairs(C_Engraving.GetRuneCategories(true, true)) do
        for _, rune in ipairs(C_Engraving.GetRunesForCategory(category, true)) do
            if rune.skillLineAbilityID == abilityID and #rune.learnedAbilitySpellIDs > 0 then
                return rune.learnedAbilitySpellIDs[1], "spell"
            end
        end
    end
end

function strategies.wowhead.GetTrackerFromFocus(data)
    if not data.focus.GetParent then return end
    local parent = data.focus:GetParent()
    if not parent or not parent.parentModule then return end
    local name = parent.parentModule:GetName()

    if parent.poiQuestID then
        return parent.poiQuestID, "quest"
    end

    if name == "BonusObjectiveTracker" then
        return parent.id, "quest"
    end

    if name == "ProfessionsRecipeTracker" then
        return parent.id, "spell"
    end

    if name == "AchievementObjectiveTracker" or
        (data.focus.module and data.focus.module.friendlyName == "ACHIEVEMENT_TRACKER_MODULE") then
        return parent.id, "achievement"
    end
end

function strategies.wowhead.GetNpcFromTooltip(data)
    if not data.tooltip then return end
    local _, unit = data.tooltip:GetUnit()
    if not unit then return end
    return select(6, strsplit("-", UnitGUID(unit))), "npc"
end

function strategies.wowhead.GetMountFromFocus(data)
    if not data.focus.spellID then return end
    return data.focus.spellID, "spell"
end

function strategies.wowhead.GetLearntMountFromFocus(data)
    if not data.focus.mountID then return end
    return select(2, C_MountJournal.GetMountInfoByID(data.focus.mountID)), "spell"
end

function strategies.wowhead.GetItemFromAuctionHouseClassic(data)
    if not data.focus.itemIndex and (not data.focus.GetParent or not data.focus:GetParent().itemIndex) then return end
    local index = data.focus.itemIndex or data.focus:GetParent().itemIndex
    local link = GetAuctionItemLink("list", index)
    return GetFromLink(link)
end

function strategies.wowhead.GetRecipeFromFocus(data)
    if not data.focus.tradeSkillInfo then return end
    return data.focus.tradeSkillInfo.recipeID, "spell"
end

function strategies.wowhead.GetClassicMistsFactionFromFocus(data)
    if not data.focus.index or not data.focus.standingText then return end
    return select(14, GetFactionInfo(data.focus.index)), "faction"
end

function CheckFrameName(name, data)
    if not name or not data.focus or not data.focus.GetName then return false end
    local focusName = data.focus:GetName()
    if not focusName then return false end
    return string.find(focusName, name)
end

local function HookTooltip(tooltip)
    tooltipStates[tooltip] = {}
    hooksecurefunc(tooltip, "SetHyperlink", function(tooltip, hyperlink)
        tooltipStates[tooltip].hyperlink = hyperlink
    end)

    hooksecurefunc(tooltip, "SetUnitAura", function(tooltip, unit, index, filter)
        if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
            local aura = C_UnitAuras.GetAuraDataByIndex(unit, index, filter)
            if aura then
                tooltipStates[tooltip].aura = aura.spellId
            end
        else
            tooltipStates[tooltip].aura = select(10, UnitAura(unit, index, filter))
        end
    end)

    tooltip:HookScript("OnTooltipCleared", function(tooltip)
        tooltipStates[tooltip] = {}
    end)
end

local eventHookFrame = CreateFrame("Frame")
eventHookFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

eventHookFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "PLAYER_ENTERING_WORLD" then
        HookTooltip(GameTooltip)
        HookTooltip(ItemRefTooltip)
    end
end)
