--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local _, NAG          = ...
local HL                     = NAG.HL
-- HeroLib
local Cache, Utils           = NAG.Cache, HL.Utils
-- Lua
local print         = print
-- File Locals


HL.MAXIMUM = 40 -- Max # Buffs and Max # Nameplates.


--- ============================ CONTENT ============================
--- Build Infos
local LiveVersion, PTRVersion, BetaVersion = "11.0.0", "11.0.0", "11.0.0"
-- version, build, date, tocversion
HL.BuildInfo = { GetBuildInfo() }
-- Get the current build version.
function HL.BuildVersion()
  return HL.BuildInfo[1]
end

-- Get if we are on the Live or not.
function HL.LiveRealm()
  return HL.BuildVersion() == LiveVersion
end

-- Get if we are on the PTR or not.
function HL.PTRRealm()
  return HL.BuildVersion() == PTRVersion
end

-- Get if we are on the Beta or not.
function HL.BetaRealm()
  return HL.BuildVersion() == BetaVersion
end

-- Print with HL Prefix
function HL.Print(...)
  print("[|cFFFF6600Hero Lib|r]", ...)
end

do
  local Setting = HL.GUISettings.General
  -- Debug print with HL Prefix
  function HL.Debug(...)
    if Setting.DebugMode then
      print("[|cFFFF6600Hero Lib Debug|r]", ...)
    end
  end
end
if HL.isRetail() then
  HL.SpecID_ClassesSpecs = {
    -- Death Knight
    [250] = { "DeathKnight", "Blood" },
    [251] = { "DeathKnight", "Frost" },
    [252] = { "DeathKnight", "Unholy" },
    -- Demon Hunter
    [577] = { "DemonHunter", "Havoc" },
    [581] = { "DemonHunter", "Vengeance" },
    -- Druid
    [102] = { "Druid", "Balance" },
    [103] = { "Druid", "Feral" },
    [104] = { "Druid", "Guardian" },
    [105] = { "Druid", "Restoration" },
    -- Evoker
    [1467] = { "Evoker", "Devastation" },
    [1468] = { "Evoker", "Preservation" },
    [1473] = { "Evoker", "Augmentation" },
    -- Hunter
    [253] = { "Hunter", "Beast Mastery" },
    [254] = { "Hunter", "Marksmanship" },
    [255] = { "Hunter", "Survival" },
    -- Mage
    [62] = { "Mage", "Arcane" },
    [63] = { "Mage", "Fire" },
    [64] = { "Mage", "Frost" },
    -- Monk
    [268] = { "Monk", "Brewmaster" },
    [269] = { "Monk", "Windwalker" },
    [270] = { "Monk", "Mistweaver" },
    -- Paladin
    [65] = { "Paladin", "Holy" },
    [66] = { "Paladin", "Protection" },
    [70] = { "Paladin", "Retribution" },
    -- Priest
    [256] = { "Priest", "Discipline" },
    [257] = { "Priest", "Holy" },
    [258] = { "Priest", "Shadow" },
    -- Rogue
    [259] = { "Rogue", "Assassination" },
    [260] = { "Rogue", "Outlaw" },
    [261] = { "Rogue", "Subtlety" },
    -- Shaman
    [262] = { "Shaman", "Elemental" },
    [263] = { "Shaman", "Enhancement" },
    [264] = { "Shaman", "Restoration" },
    -- Warlock
    [265] = { "Warlock", "Affliction" },
    [266] = { "Warlock", "Demonology" },
    [267] = { "Warlock", "Destruction" },
    -- Warrior
    [71] = { "Warrior", "Arms" },
    [72] = { "Warrior", "Fury" },
    [73] = { "Warrior", "Protection" }
  }
elseif HL.isClassic() then
  HL.SpecID_ClassesSpecs = {
    -- Death Knight
    [398] = { "DeathKnight", "Blood" },
    [399] = { "DeathKnight", "Frost" },
    [400] = { "DeathKnight", "Unholy" },
    -- Druid
    [752] = { "Druid", "Balance" },
    [750] = { "Druid", "Feral" },
    [104] = { "Druid", "Guardian" },
    [748] = { "Druid", "Restoration" },
    -- Hunter
    [811] = { "Hunter", "Beast Mastery" },
    [807] = { "Hunter", "Marksmanship" },
    [809] = { "Hunter", "Survival" },
    -- Mage
    [799] = { "Mage", "Arcane" },
    [851] = { "Mage", "Fire" },
    [823] = { "Mage", "Frost" },
    -- Paladin
    [831] = { "Paladin", "Holy" },
    [839] = { "Paladin", "Protection" },
    [855] = { "Paladin", "Retribution" },
    -- Priest
    [760] = { "Priest", "Discipline" },
    [813] = { "Priest", "Holy" },
    [795] = { "Priest", "Shadow" },
    -- Rogue
    [182] = { "Rogue", "Assassination" },
    [181] = { "Rogue", "Combat" },
    [183] = { "Rogue", "Subtlety" },
    -- Shaman
    [261] = { "Shaman", "Elemental" },
    [263] = { "Shaman", "Enhancement" },
    [262] = { "Shaman", "Restoration" },
    -- Warlock
    [871] = { "Warlock", "Affliction" },
    [867] = { "Warlock", "Demonology" },
    [865] = { "Warlock", "Destruction" },
    -- Warrior
    [746] = { "Warrior", "Arms" },
    [815] = { "Warrior", "Fury" },
    [845] = { "Warrior", "Protection" }
  }
else
  HL.SpecID_ClassesSpecs = setmetatable({}, {
    __index = function(t, k)
      return { "Unknown", "Unknown" }
    end
  })

end



