--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local _, NAG                 = ...
local HL                     = NAG.HL
-- HeroLib
local Cache, Utils           = NAG.Cache, HL.Utils
local Unit                   = HL.Unit
local Player, Pet, Target    = Unit.Player, Unit.Pet, Unit.Target
local Focus, MouseOver       = Unit.Focus, Unit.MouseOver
local Arena, Boss, Nameplate = Unit.Arena, Unit.Boss, Unit.Nameplate
local Party, Raid            = Unit.Party, Unit.Raid
local Spell                  = HL.Spell
local Item                   = HL.Item

-- Lua locals
local tableinsert = table.insert
-- File Locals


--- ============================ CONTENT ============================
-- Get if the player is stealthed or not
--TODO: Verify
do
  local StealthSpellsByType = {
    -- Normal Stealth
    {
      -- Rogue
      Spell(1784), -- Stealth
      Spell(11327), -- Vanish
      -- Feral
      Spell(5215) -- Prowl
    },
    -- Combat Stealth
    {
    },
    -- Special Stealth
    {
      -- Night Elf
      Spell(58984) -- Shadowmeld
    }
  }
  if HL.isRetail() then
    -- Normal Stealth
    -- Rogue
    tableinsert(StealthSpellsByType[1], Spell(115191)) -- Stealth w/ Subterfuge Talent
    tableinsert(StealthSpellsByType[1], Spell(115193)) -- Vanish w/ Subterfuge Talent

    -- Combat Stealth
    --Rogue
    tableinsert(StealthSpellsByType[2], Spell(115192)) -- Subterfuge Buff
    tableinsert(StealthSpellsByType[2], Spell(185422)) -- Stealth from Shadow Dance
    -- Druid
    tableinsert(StealthSpellsByType[2], Spell(102543)) -- Incarnation: King of the Jungle

    -- Special Stealth
    -- Rogue
    tableinsert(StealthSpellsByType[3], Spell(375939)) -- Sepsis stance mask buff

  elseif HL.isClassic() then
    -- Normal Stealth

    -- Combat Stealth

    -- Special Stealth

  end

  function Player:StealthRemains(CheckCombat, CheckSpecial, BypassRecovery)
    -- Considering there is a small delay between the ability cast and the buff trigger we also look at the time since last cast.
    if Spell.Rogue then
      if (CheckCombat and (Spell.Rogue.Commons.ShadowDance:TimeSinceLastCast() < 0.3 or Spell.Rogue.Commons.Vanish:TimeSinceLastCast() < 0.3))
        or (CheckSpecial and Spell.Rogue.Commons.Shadowmeld:TimeSinceLastCast() < 0.3) then
          return 1
      end
    end

    if Spell.Druid then
      local Feral = Spell.Druid.Feral

      if Feral then
        if (CheckCombat and Feral.Incarnation:TimeSinceLastCast() < 0.3)
          or (CheckSpecial and Feral.Shadowmeld:TimeSinceLastCast() < 0.3) then
          return 1
        end
      end
    end

    for i = 1, #StealthSpellsByType do
      if i == 1 or (i == 2 and CheckCombat) or (i == 3 and CheckSpecial) then
        local StealthSpells = StealthSpellsByType[i]
        for j = 1, #StealthSpells do
          local StealthSpell = StealthSpells[j]
          if Player:BuffUp(StealthSpell, nil, BypassRecovery) then
            return Player:BuffRemains(StealthSpell, nil, BypassRecovery)
          end
        end
      end
    end

    return 0
  end

  function Player:StealthUp(CheckCombat, CheckSpecial, BypassRecovery)
    return self:StealthRemains(CheckCombat, CheckSpecial, BypassRecovery) > 0
  end

  function Player:StealthDown(CheckCombat, CheckSpecial, BypassRecovery)
    return not self:StealthUp(CheckCombat, CheckSpecial, BypassRecovery)
  end
end
