-- Unified GetSpellCooldown function with fallback
-- Accepts: spellIdentifier; Returns spellCooldownInfo table (SpellCooldownInfo: isEnabled, startTime, modRate, duration)
function GetUnifiedSpellCooldown(spellID)
    if C_Spell and C_Spell.GetSpellCooldown then
        local cdInfo = C_Spell.GetSpellCooldown(spellID)
        return {
            isEnabled = cdInfo.isEnabled,
            startTime = cdInfo.startTime,
            modRate = cdInfo.modRate,
            duration = cdInfo.duration
        }
    else
        -- Fallback to global API for Classic-like versions
        local startTime, duration, isEnabled, modRate = GetSpellCooldown(spellID)
        return {
            isEnabled = isEnabled or true,  -- Assume it's enabled if not returned
            startTime = startTime,
            modRate = modRate or 1,  -- Mod rate may not exist, so default to 1
            duration = duration
        }
    end
end
    
-- Unified GetSpellCharges function with fallback
-- Accepts: spellIdentifier; Returns: chargeInfo table (SpellChargeInfo: maxCharges, cooldownStartTime, chargeModRate, currentCharges, cooldownDuration)
function GetUnifiedSpellCharges(spellID)
    if C_Spell and C_Spell.GetSpellCharges then
        local chargesInfo = C_Spell.GetSpellCharges(spellID)
        -- Non-charged spells now return nil, so let's return default values to avoid a nil error.
        if not chargesInfo then return nil end
        return {
            currentCharges = chargesInfo.currentCharges,
            maxCharges = chargesInfo.maxCharges,
            cooldownStartTime = chargesInfo.cooldownStartTime,
            cooldownDuration = chargesInfo.cooldownDuration,
            chargeModRate = chargesInfo.chargeModRate
        }
    else
        -- Fallback to global API for Classic-like versions
        local charges, maxCharges, startTime, duration, modRate = GetSpellCharges(spellID)
        if not charges then return nil end
        return {
            currentCharges = charges,
            maxCharges = maxCharges,
            cooldownStartTime = startTime,
            cooldownDuration = duration,
            chargeModRate = modRate
        }
    end
end
-- Accepts: itemInfo
-- Returns: itemName (cstring), itemLink (cstring), itemQuality (ItemQuality), itemLevel (number), itemMinLevel(number), itemType (cstring), itemSubType (cstring), itemStackCound (number),
-- itemEquipLoc (cstring), itemTexture (fileID), sellPrice (number), classID (number), subclassID (number), bindType (number), expansionID (number), setID (number), isCraftingReagent(bool)
function GetUnifiedItemInfo(itemID)
    if C_Item and C_Item.GetItemInfo then
        local itemInfo = C_Item.GetItemInfo(itemID)
        return {
            itemName = itemInfo.name,
            link = itemInfo.link,
            quality = itemInfo.quality,
            iconFileDataID = itemInfo.iconFileDataID,
            binding = itemInfo.binding,
            itemID = itemInfo.itemID
        }
    else
        -- Fallback to global API for Classic-like versions
        local name, link, quality, _, _, _, _, _, _, iconFileDataID = GetItemInfo(itemID)
        return {
            name = name,
            link = link,
            quality = quality,
            iconFileDataID = iconFileDataID
        }
    end
end

-- Unified GetSpellInfo function with fallback
-- Accepts: spellIdentifier; Returns: spellInfo table (SpellInfo: castTime, name, minRange, originalIconID, iconID, maxRange, spellID)
function GetUnifiedSpellInfo(spellID)
    if (C_Spell and C_Spell.GetSpellInfo) or (C_SpellBook and C_SpellBook.GetSpellInfo) then
        -- Use C_Spell.GetSpellInfo in Retail if available
        local spellInfo = (C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(spellID)) or (C_SpellBook.GetSpellInfo and C_SpellBook.GetSpellInfo(spellID))
        if not spellInfo then return nil end
        return {
            name = spellInfo.name,
            iconID = spellInfo.iconID,
            originalIconID = spellInfo.originalIconID,
            castTime = spellInfo.castTime,
            minRange = spellInfo.minRange,
            maxRange = spellInfo.maxRange,
            spellID = spellInfo.spellID
        }
    else
        -- Fallback to global GetSpellInfo for Classic-like versions
        local name, rank, iconID, castTime, minRange, maxRange, spellID, originalIconID = GetSpellInfo(spellID)
        if not name then return nil end
        return {
            name = name,
            iconID = iconID,
            originalIconID = originalIconID or iconID,  -- Use iconID if originalIconID isn't available
            castTime = castTime,
            minRange = minRange,
            maxRange = maxRange,
            spellID = spellID
        }
    end
end

-- Unified IsDelveInProgress function
-- Accepts: nil; Returns: isDelveComplete (bool)
function GetUnifiedIsDelveInProgress()
    if C_PartyInfo and C_PartyInfo.IsDelveInProgress then
        -- Use the actual C_PartyInfo.IsDelveInProgress function in Retail
        return C_PartyInfo.IsDelveInProgress()
    else
        -- In Classic/Cata or when the function is not available, return false
        return false
    end
end

-- Unified GetAuraDataByIndex function
-- Accepts: unitToken, index, filter
-- Returns: auraData table (AuraData: spellId, isBossAura, duration, expirationTime, isFromPlayerOrPet, icon, name, applications, sourceUnit, isStealable, etc.)
function GetUnifiedAuraData(unitToken, index, filter)
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        -- Retail: Use C_UnitAuras.GetAuraDataByIndex if available
        local auraData = C_UnitAuras.GetAuraDataByIndex(unitToken, index, filter)
        if not auraData then return nil end  -- Return nil if no aura is found
        return {
            spellId = auraData.spellId,
            isBossAura = auraData.isBossAura,
            duration = auraData.duration,
            expirationTime = auraData.expirationTime,
            isFromPlayerOrPet = auraData.isFromPlayerOrPlayerPet,
            icon = auraData.icon,
            name = auraData.name,
            applications = auraData.applications,
            sourceUnit = auraData.sourceUnit,
            isStealable = auraData.isStealable,
            isHarmful = auraData.isHarmful,
            isHelpful = auraData.isHelpful,
            canApplyAura = auraData.canApplyAura,
            isRaid = auraData.isRaid,
            nameplateShowAll = auraData.nameplateShowAll,
            nameplateShowPersonal = auraData.nameplateShowPersonal,
            timeMod = auraData.timeMod
        }
    else
        -- Classic-like: Use UnitAura (or UnitBuff/UnitDebuff) if C_UnitAuras is not available
        local name, icon, count, dispelType, duration, expirationTime, source, isStealable, nameplateShowPersonal, spellId, canApplyAura, isBossDebuff, castByPlayer, nameplateShowAll, timeMod = UnitAura(unitToken, index, filter)
        if not name then return nil end  -- Return nil if no aura is found
        return {
            spellId = spellId,
            isBossAura = isBossDebuff,
            duration = duration,
            expirationTime = expirationTime,
            isFromPlayerOrPet = castByPlayer,
            icon = icon,
            name = name,
            applications = count,
            sourceUnit = source,
            isStealable = isStealable,
            isHarmful = filter == "HARMFUL",  -- Infer isHarmful from filter
            isHelpful = filter == "HELPFUL",  -- Infer isHelpful from filter
            canApplyAura = canApplyAura,
            isRaid = nil,  -- Not available in Classic-like API, so leave nil
            nameplateShowAll = nameplateShowAll,
            nameplateShowPersonal = nameplateShowPersonal,
            timeMod = timeMod
        }
    end
end

-- Unified GetPlayerAuraBySpellID function
-- Accepts: spellID
-- Returns: auraData table (name, icon, count, dispelType, duration, expirationTime, source, isStealable, spellId, etc.)
function GetUnifiedPlayerAuraBySpellID(spellID)
    if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
        -- Retail: Use C_UnitAuras.GetPlayerAuraBySpellID if available
        local auraData = C_UnitAuras.GetPlayerAuraBySpellID(spellID)
        if not auraData then return nil end  -- Return nil if no aura is found
        return {
            name = auraData.name,
            icon = auraData.icon,
            count = auraData.applications or 1,
            dispelType = auraData.dispelName,
            duration = auraData.duration,
            expirationTime = auraData.expirationTime,
            source = auraData.sourceUnit,
            isStealable = auraData.isStealable,
            nameplateShowPersonal = auraData.nameplateShowPersonal,
            spellId = auraData.spellId,
            canApplyAura = auraData.canApplyAura,
            isBossDebuff = auraData.isBossAura,
            castByPlayer = auraData.isFromPlayerOrPlayerPet,
            nameplateShowAll = auraData.nameplateShowAll,
            timeMod = auraData.timeMod
        }
    else
        -- Classic-like: Use UnitAura to iterate and find the aura by spellID
        for i = 1, 40 do  -- Maximum of 40 auras
            local name, icon, count, dispelType, duration, expirationTime, source, isStealable, nameplateShowPersonal, foundSpellId, canApplyAura, isBossDebuff, castByPlayer, nameplateShowAll, timeMod = UnitAura("player", i)
            if foundSpellId == spellID then
                -- Return the aura details in a similar structure to Retail's auraData
                return {
                    name = name,
                    icon = icon,
                    count = count,
                    dispelType = dispelType,
                    duration = duration,
                    expirationTime = expirationTime,
                    source = source,
                    isStealable = isStealable,
                    nameplateShowPersonal = nameplateShowPersonal,
                    spellId = foundSpellId,
                    canApplyAura = canApplyAura,
                    isBossDebuff = isBossDebuff,
                    castByPlayer = castByPlayer,
                    nameplateShowAll = nameplateShowAll,
                    timeMod = timeMod
                }
            end
        end
        -- Return nil if no matching aura is found
        return nil
    end
end
-- Unified IsSpellInRange function
-- Accepts: spellIdentifier (spellID or spellName), targetUnit (unitID)
-- Returns: inRange (boolean)
function GetUnifiedIsSpellInRange(spellIdentifier, targetUnit)
    if C_Spell and C_Spell.IsSpellInRange then
        -- Retail: Use C_Spell.IsSpellInRange if available
        return C_Spell.IsSpellInRange(spellIdentifier, targetUnit)
    else
        -- Classic-like: Use the global IsSpellInRange function
        return IsSpellInRange(spellIdentifier, targetUnit) == 1
    end
end

-- Unified GetSpellBookSkillLineInfo function
-- Accepts: skillLineIndex (number)
-- Returns: skillLineInfo table (name, iconID, itemIndexOffset, numSpellBookItems, isGuild, shouldHide, specID, offSpecID)
function GetUnifiedSpellBookSkillLineInfo(skillLineIndex)
    if C_SpellBook and C_SpellBook.GetSpellBookSkillLineInfo then
        -- Retail: Use C_SpellBook.GetSpellBookSkillLineInfo
        return C_SpellBook.GetSpellBookSkillLineInfo(skillLineIndex)
    else
        -- Classic-like: Use GetSpellTabInfo and format it like Retail's response
        local name, iconID, itemIndexOffset, numSpellBookItems, isGuild, offSpecID = GetSpellTabInfo(skillLineIndex)
        return {
            name = name,
            iconID = iconID,
            itemIndexOffset = itemIndexOffset or 0,
            numSpellBookItems = numSpellBookItems or 0,
            isGuild = isGuild or false,
            shouldHide = false,  -- GetSpellTabInfo doesn't return this, assume false
            specID = nil,  -- Not applicable in Classic-like versions
            offSpecID = offSpecID
        }
    end
end

-- Unified GetSpellBookItemInfo function
-- Accepts: spellBookItemSlotIndex (number), spellBookItemSpellBank (optional in Classic-like)
-- Returns: spellBookItemInfo table (actionID, spellID, itemType, name, subName, iconID, isPassive, isOffSpec, skillLineIndex)
function GetUnifiedSpellBookItemInfo(spellBookItemSlotIndex, spellBookItemSpellBank)
    if C_SpellBook and C_SpellBook.GetSpellBookItemInfo then
        -- Retail: Use C_SpellBook.GetSpellBookItemInfo
        local spellBookItemInfo = C_SpellBook.GetSpellBookItemInfo(spellBookItemSlotIndex, spellBookItemSpellBank)
        return {
            actionID = spellBookItemInfo.actionID,
            spellID = spellBookItemInfo.spellID,
            itemType = spellBookItemInfo.itemType,
            name = spellBookItemInfo.name,
            subName = spellBookItemInfo.subName,
            iconID = spellBookItemInfo.iconID,
            isPassive = spellBookItemInfo.isPassive,
            isOffSpec = spellBookItemInfo.isOffSpec,
            skillLineIndex = spellBookItemInfo.skillLineIndex
        }
    else
        -- Classic-like: Use GetSpellBookItemInfo and normalize the return structure
        local spellType, id = GetSpellBookItemInfo(spellBookItemSlotIndex, "spell")
        local name, rank, icon, castTime, minRange, maxRange, spellID = GetSpellInfo(id)

        -- Map the item type from spellType to match Retail's Enum.SpellBookItemType
        local itemType
        if spellType == "SPELL" then
            itemType = 1 -- Enum.SpellBookItemType.Spell
        elseif spellType == "FUTURESPELL" then
            itemType = 2 -- Enum.SpellBookItemType.FutureSpell
        elseif spellType == "PETACTION" then
            itemType = 3 -- Enum.SpellBookItemType.PetAction
        elseif spellType == "FLYOUT" then
            itemType = 4 -- Enum.SpellBookItemType.Flyout
        else
            itemType = 0 -- Enum.SpellBookItemType.None
        end

        -- Return the normalized structure similar to Retail
        return {
            actionID = id,
            spellID = spellID,
            itemType = itemType,
            name = name or "",       -- Classic version may not have the full name data
            subName = rank or "",    -- SubName (rank) is returned in Classic, may be empty in Retail
            iconID = icon or 0,      -- Icon ID from GetSpellInfo
            isPassive = false,       -- Classic API doesn't return this, assume false
            isOffSpec = false,       -- Not applicable in Classic-like versions
            skillLineIndex = nil     -- Classic-like versions don't return this
        }
    end
end
-- Unified GetActiveConfigID function
-- Returns: configID (number or nil)
function GetUnifiedActiveConfigID()
    if C_ClassTalents and C_ClassTalents.GetActiveConfigID then
        -- Modern: Use C_ClassTalents.GetActiveConfigID
        return C_ClassTalents.GetActiveConfigID()
    else
        -- Classic-like: No active talent config system, return nil
        return nil
    end
end
-- Unified GetSpecialization function
-- Returns: currentSpec (number or nil)
function GetUnifiedSpecialization()
    if GetSpecialization then
        -- Retail: Use GetSpecialization to get the active spec index
        return GetSpecialization()
    else
        -- Classic-like: No direct specialization system, return nil
        return nil
    end
end

-- Unified GetSpecializationInfo function
-- Accepts: specIndex (number); Returns: id, name, description, icon, role, primaryStat
function GetUnifiedSpecializationInfo(specIndex)
    if GetSpecializationInfo then
        -- Retail: Use GetSpecializationInfo to get spec details
        return GetSpecializationInfo(specIndex)
    else
        -- Classic/Cata: Fallback to GetTalentTabInfo to approximate the spec info
        local name, icon, pointsSpent = GetTalentTabInfo(specIndex or 1)
        if not name then
            return nil
        end
        
        -- Map the data to Retail's structure
        local id = specIndex or 1 -- Use specIndex or default to first tab
        local description = "This is an approximation of the current specialization."
        local role = "NONE"  -- Role info doesn't exist in Classic/Cata
        local primaryStat = 0 -- Primary stat info doesn't exist in Classic/Cata
        
        return id, name, description, icon, role, primaryStat
    end
end
-- Unified GetSpellPowerCost function
-- Accepts: spellIdentifier; Returns: powerCosts table (table of costs: hasRequiredAura, type, name, cost, minCost, requiredAuraID, costPercent, costPerSec)
function GetUnifiedSpellPowerCost(spellID)
    local powerCosts = {}

    if C_Spell and C_Spell.GetSpellPowerCost then
        -- Retail: Use C_Spell.GetSpellPowerCost
        local costs = C_Spell.GetSpellPowerCost(spellID)
        if costs then
            for _, cost in ipairs(costs) do
                table.insert(powerCosts, {
                    hasRequiredAura = cost.hasRequiredAura,
                    type = cost.type,
                    name = cost.name,
                    cost = cost.cost,
                    minCost = cost.minCost,
                    requiredAuraID = cost.requiredAuraID,
                    costPercent = cost.costPercent,
                    costPerSec = cost.costPerSec
                })
            end
        end
    else
        -- Classic/Cata: Use GetSpellPowerCost (spellName or index and bookType)
        local costs = GetSpellPowerCost(spellID)
        if costs then
            for _, cost in ipairs(costs) do
                table.insert(powerCosts, {
                    hasRequiredAura = cost.hasRequiredAura or false, -- No aura requirement in Classic/Cata
                    type = cost.type,
                    name = cost.name,
                    cost = cost.cost,
                    minCost = cost.minCost,
                    requiredAuraID = cost.requiredAuraID or 0, -- Not supported in Classic/Cata
                    costPercent = cost.costPercent or 0,
                    costPerSec = cost.costPerSec or 0
                })
            end
        end
    end

    return powerCosts
end
