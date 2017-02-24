--- Localize Vars
-- Addon
local addonName, AC = ...;
-- Lua
local error = error;
local mathfloor = math.floor;
local mathmin = math.min;
local pairs = pairs;
local print = print;
local select = select;
local setmetatable = setmetatable;
local tableinsert = table.insert;
local tableremove = table.remove;
local tonumber = tonumber;
local tostring = tostring;
local type = type;
local unpack = unpack;
local wipe = table.wipe;
-- Core Locals
local _T = { -- Temporary Vars
  Argument, -- CmdHandler
  Parts, -- NPCID
  ThisUnit, -- GetEnemies / TTDRefresh
  DistanceValues = {}, -- GetEnemies
  Start, End, -- CastPercentage
  Infos, -- GetBuffs / GetDebuffs
  ExpirationTime, -- BuffRemains / DebuffRemains
  Charges, MaxCharges, CDTime, CDValue, -- Cooldown / Recharge
  CD -- Cooldown / Recharge
};
-- Max # Buffs and Max # Nameplates.
AC.MAXIMUM = 40;
-- Defines our cached tables.
local Cache = {
  -- Temporary
  APLVar = {},
  Enemies = {},
  EnemiesCount = {},
  GUIDInfo = {},
  MiscInfo = {},
  SpellInfo = {},
  ItemInfo = {},
  UnitInfo = {},

  -- Persistent
  Persistent = {
    Equipment = {},
    Player = {
      Class = {UnitClass("player")},
      Spec = {}
    },
    SpellLearned = {Pet = {}, Player = {}},
    Texture = {Spell = {}, Item = {}, Custom = {}}
  }
};

--- Globalize Vars
-- Addon
AethysCore = AC;
AethysCore_Cache = Cache;

--- ============== CORE FUNCTIONS ==============

-- Wipe a table while keeping the structure
-- i.e. wipe every sub-table as long it doesn't contain a table
function AC.WipeTableRecursively (Table)
  for Key, Value in pairs(Table) do
    if type(Value) == "table" then
      AC.WipeTableRecursively(Value);
    else
      wipe(Table);
    end
  end
end

-- Reset the cache
AC.CacheHasBeenReset = false;
function AC.CacheReset ()
  if not AC.CacheHasBeenReset then
    --[[-- foreach method
    for Key, Value in pairs(AC.Cache) do
      wipe(AC.Cache[Key]);
    end]]

    wipe(Cache.APLVar);
    wipe(Cache.Enemies);
    wipe(Cache.EnemiesCount);
    wipe(Cache.GUIDInfo);
    wipe(Cache.MiscInfo);
    wipe(Cache.SpellInfo);
    wipe(Cache.ItemInfo);
    wipe(Cache.UnitInfo);

    AC.CacheHasBeenReset = true;
  end
end

-- Get the GetTime and cache it.
function AC.GetTime (Reset)
  if not Cache.MiscInfo then Cache.MiscInfo = {}; end
  if not Cache.MiscInfo.GetTime or Reset then
    Cache.MiscInfo.GetTime = GetTime();
  end
  return Cache.MiscInfo.GetTime;
end

-- Print with AC Prefix
function AC.Print (...)
  print("[|cFFFF6600Aethys Core|r]", ...);
end

--- ============== CLASS FUNCTIONS ==============
  -- Class
  local function Class ()
    local Table, MetaTable = {}, {};
    Table.__index = Table;
    MetaTable.__call = function (self, ...)
      local Object = {};
      setmetatable(Object, self);
      if Object.Constructor then Object:Constructor(...); end
      return Object;
    end;
    setmetatable(Table, MetaTable);
    return Table;
  end

  -- Defines the Unit Class.
  AC.Unit = Class();
  local Unit = AC.Unit;
  -- Unit Constructor
  function Unit:Constructor (UnitID)
    self.UnitID = UnitID;
  end
  -- Defines Unit Objects.
  Unit.Player = Unit("Player");
  Unit.Pet = Unit("Pet");
  Unit.Target = Unit("Target");
  Unit.Focus = Unit("Focus");
  Unit.Vehicle = Unit("Vehicle");
  -- TODO: Make a map containing all UnitId that have multiple possiblites + the possibilites then a master for loop checking this
  -- Something like { {"Nameplate", 40}, {"Boss", 4}, {"Arena", 5}, ....}
  for i = 1, AC.MAXIMUM do
    Unit["Nameplate"..tostring(i)] = Unit("Nameplate"..tostring(i));
  end
  for i = 1, 4 do
    Unit["Boss"..tostring(i)] = Unit("Boss"..tostring(i));
  end
  -- Locals
  local Player = Unit.Player;
  local Pet = Unit.Pet;
  local Target = Unit.Target;
  local Focus = Unit.Focus;
  local Vehicle = Unit.Vehicle;

  -- Defines the Spell Class.
  AC.Spell = Class();
  local Spell = AC.Spell;
  -- Spell Constructor
  function Spell:Constructor (ID, Type)
    self.SpellID = ID;
    self.SpellType = Type or "Player"; -- For Pet, put "Pet". Default is "Player".
    self.LastCastTime = 0;
    self.LastDisplayTime = 0;
  end

  -- Defines the Item Class.
  AC.Item = Class();
  local Item = AC.Item;
  -- Item Constructor
  function Item:Constructor (ID)
    self.ItemID = ID;
    self.LastCastTime = 0;
  end


--- ============== UNIT CLASS ==============

  -- Get the unit GUID.
  function Unit:GUID ()
    if not Cache.GUIDInfo[self.UnitID] then
      Cache.GUIDInfo[self.UnitID] = UnitGUID(self.UnitID);
    end
    return Cache.GUIDInfo[self.UnitID];
  end

  -- Get if the unit Exists and is visible.
  function Unit:Exists ()
    if self:GUID() then
      if not Cache.UnitInfo[self:GUID()] then Cache.UnitInfo[self:GUID()] = {}; end
      if Cache.UnitInfo[self:GUID()].Exists == nil then
        Cache.UnitInfo[self:GUID()].Exists = UnitExists(self.UnitID) and UnitIsVisible(self.UnitID);
      end
      return Cache.UnitInfo[self:GUID()].Exists;
    end
    return nil;
  end

  -- Get the unit NPC ID.
  function Unit:NPCID ()
    if self:GUID() then
      if not Cache.UnitInfo[self:GUID()] then Cache.UnitInfo[self:GUID()] = {}; end
      if not Cache.UnitInfo[self:GUID()].NPCID then
        _T.Parts = {};
        for Part in string.gmatch(self:GUID(), "([^-]+)") do
          tableinsert(_T.Parts, Part);
        end
        if _T.Parts[1] == "Creature" or _T.Parts[1] == "Pet" or _T.Parts[1] == "Vehicle" then
          Cache.UnitInfo[self:GUID()].NPCID = tonumber(_T.Parts[6]);
        else
          Cache.UnitInfo[self:GUID()].NPCID = -2;
        end
      end
      return Cache.UnitInfo[self:GUID()].NPCID;
    end
    return -1;
  end

  -- Get if an unit with a given NPC ID is in the Boss list and has less HP than the given ones.
  function Unit:IsInBossList (NPCID, HP)
    for i = 1, 4 do
      if Unit["Boss"..tostring(i)]:NPCID() == NPCID and Unit["Boss"..tostring(i)]:HealthPercentage() <= HP then
        return true;
      end
    end
    return false;
  end

  -- Get if the unit CanAttack the other one.
  function Unit:CanAttack (Other)
    if self:GUID() and Other:GUID() then
      if not Cache.UnitInfo[self:GUID()] then Cache.UnitInfo[self:GUID()] = {}; end
      if not Cache.UnitInfo[self:GUID()].CanAttack then Cache.UnitInfo[self:GUID()].CanAttack = {}; end
      if Cache.UnitInfo[self:GUID()].CanAttack[Other:GUID()] == nil then
        Cache.UnitInfo[self:GUID()].CanAttack[Other:GUID()] = UnitCanAttack(self.UnitID, Other.UnitID);
      end
      return Cache.UnitInfo[self:GUID()].CanAttack[Other:GUID()];
    end
    return nil;
  end

  local DummyUnits = {
    [31146] = true,
    -- Rogue Class Order Hall
    [92164] = true, -- Training Dummy
    [92165] = true, -- Dungeoneer's Training Dummy
    [92166] = true  -- Raider's Training Dummy
  };
  function Unit:IsDummy ()
    return self:NPCID() >= 0 and DummyUnits[self:NPCID()] == true;
  end

  -- Get the unit Health.
  function Unit:Health ()
    if self:GUID() then
      if not Cache.UnitInfo[self:GUID()] then Cache.UnitInfo[self:GUID()] = {}; end
      if not Cache.UnitInfo[self:GUID()].Health then
        Cache.UnitInfo[self:GUID()].Health = UnitHealth(self.UnitID);
      end
      return Cache.UnitInfo[self:GUID()].Health;
    end
    return -1;
  end

  -- Get the unit MaxHealth.
  function Unit:MaxHealth ()
    if self:GUID() then
      if not Cache.UnitInfo[self:GUID()] then Cache.UnitInfo[self:GUID()] = {}; end
      if not Cache.UnitInfo[self:GUID()].MaxHealth then
        Cache.UnitInfo[self:GUID()].MaxHealth = UnitHealthMax(self.UnitID);
      end
      return Cache.UnitInfo[self:GUID()].MaxHealth;
    end
    return -1;
  end

  -- Get the unit Health Percentage
  function Unit:HealthPercentage ()
    return self:Health() ~= -1 and self:MaxHealth() ~= -1 and self:Health()/self:MaxHealth()*100;
  end

  -- Get if the unit Is Dead Or Ghost.
  function Unit:IsDeadOrGhost ()
    if self:GUID() then
      if not Cache.UnitInfo[self:GUID()] then Cache.UnitInfo[self:GUID()] = {}; end
      if Cache.UnitInfo[self:GUID()].IsDeadOrGhost == nil then
        Cache.UnitInfo[self:GUID()].IsDeadOrGhost = UnitIsDeadOrGhost(self.UnitID);
      end
      return Cache.UnitInfo[self:GUID()].IsDeadOrGhost;
    end
    return nil;
  end

  -- Get if the unit Affecting Combat.
  function Unit:AffectingCombat ()
    if self:GUID() then
      if not Cache.UnitInfo[self:GUID()] then Cache.UnitInfo[self:GUID()] = {}; end
      if Cache.UnitInfo[self:GUID()].AffectingCombat == nil then
        Cache.UnitInfo[self:GUID()].AffectingCombat = UnitAffectingCombat(self.UnitID);
      end
      return Cache.UnitInfo[self:GUID()].AffectingCombat;
    end
    return nil;
  end

  -- Get if two unit are the same.
  function Unit:IsUnit (Other)
    if self:GUID() and Other:GUID() then
      if not Cache.UnitInfo[self:GUID()] then Cache.UnitInfo[self:GUID()] = {}; end
      if not Cache.UnitInfo[self:GUID()].IsUnit then Cache.UnitInfo[self:GUID()].IsUnit = {}; end
      if Cache.UnitInfo[self:GUID()].IsUnit[Other:GUID()] == nil then
        Cache.UnitInfo[self:GUID()].IsUnit[Other:GUID()] = UnitIsUnit(self.UnitID, Other.UnitID);
      end
      return Cache.UnitInfo[self:GUID()].IsUnit[Other:GUID()];
    end
    return nil;
  end

  -- Get unit classification
  function Unit:Classification ()
    if self:GUID() then
      if not Cache.UnitInfo[self:GUID()] then Cache.UnitInfo[self:GUID()] = {}; end
      if Cache.UnitInfo[self:GUID()].Classification == nil then
        Cache.UnitInfo[self:GUID()].Classification = UnitClassification(self.UnitID);
      end
      return Cache.UnitInfo[self:GUID()].Classification;
    end
    return "";
  end

  -- Get if we are in range of the unit.
  AC.IsInRangeItemTable = {
    [5]    =  37727,  -- Ruby Acorn
    [6]    =  63427,  -- Worgsaw
    [8]    =  34368,  -- Attuned Crystal Cores
    [10]  =  32321,  -- Sparrowhawk Net
    [15]  =  33069,  -- Sturdy Rope
    [20]  =  10645,  -- Gnomish Death Ray
    [25]  =  41509,  -- Frostweave Net
    [30]  =  34191,  -- Handful of Snowflakes
    [35]  =  18904,  -- Zorbin's Ultra-Shrinker
    [40]  =  28767,  -- The Decapitator
    [45]  =  23836,  -- Goblin Rocket Launcher
    [50]  =  116139,  -- Haunting Memento
    [60]  =  32825,  -- Soul Cannon
    [70]  =  41265,  -- Eyesore Blaster
    [80]  =  35278,  -- Reinforced Net
    [100]  =  33119  -- Malister's Frost Wand
  };
  -- Get if the unit is in range, you can use a number or a spell as argument.
  function Unit:IsInRange (Distance)
    if self:GUID() then
      if not Cache.UnitInfo[self:GUID()] then Cache.UnitInfo[self:GUID()] = {}; end
      if not Cache.UnitInfo[self:GUID()].IsInRange then Cache.UnitInfo[self:GUID()].IsInRange = {}; end
      if Cache.UnitInfo[self:GUID()].IsInRange[Distance] == nil then
        if type(Distance) == "number" then
          Cache.UnitInfo[self:GUID()].IsInRange[Distance] = IsItemInRange(AC.IsInRangeItemTable[Distance], self.UnitID) or false;
        else
          Cache.UnitInfo[self:GUID()].IsInRange[Distance] = IsSpellInRange(Distance:Name(), self.UnitID) or false;
        end
      end
      return Cache.UnitInfo[self:GUID()].IsInRange[Distance];
    end
    return nil;
  end

  -- Get if we are Tanking or not the Unit.
  -- TODO: Use both GUID like CanAttack / IsUnit for better management.
  function Unit:IsTanking (Other)
    if self:GUID() then
      if not Cache.UnitInfo[self:GUID()] then Cache.UnitInfo[self:GUID()] = {}; end
      if Cache.UnitInfo[self:GUID()].Tanked == nil then
        Cache.UnitInfo[self:GUID()].Tanked = UnitThreatSituation(self.UnitID, Other.UnitID) and UnitThreatSituation(self.UnitID, Other.UnitID) >= 2 and true or false;
      end
      return Cache.UnitInfo[self:GUID()].Tanked;
    end
    return nil;
  end

  --- Get all the casting infos from an unit and put it into the Cache.
  function Unit:GetCastingInfo ()
    if not Cache.UnitInfo[self:GUID()] then Cache.UnitInfo[self:GUID()] = {}; end
    Cache.UnitInfo[self:GUID()].Casting = {UnitCastingInfo(self.UnitID)};
  end

  -- Get the Casting Infos from the Cache.
  function Unit:CastingInfo (Index)
    if self:GUID() then
      if not Cache.UnitInfo[self:GUID()] or not Cache.UnitInfo[self:GUID()].Casting then
        self:GetCastingInfo();
      end
      if Index then
        return Cache.UnitInfo[self:GUID()].Casting[Index];
      else
        return unpack(Cache.UnitInfo[self:GUID()].Casting);
      end
    end
    return nil;
  end

  -- Get if the unit is casting or not.
  function Unit:IsCasting ()
    return self:CastingInfo(1) and true or false;
  end

  -- Get the unit cast's name if there is any.
  function Unit:CastName ()
    return self:IsCasting() and self:CastingInfo(1) or "";
  end

  --- Get all the Channeling Infos from an unit and put it into the Cache.
  function Unit:GetChannelingInfo ()
    if not Cache.UnitInfo[self:GUID()] then Cache.UnitInfo[self:GUID()] = {}; end
    Cache.UnitInfo[self:GUID()].Channeling = {UnitChannelInfo(self.UnitID)};
  end

  -- Get the Channeling Infos from the Cache.
  function Unit:ChannelingInfo (Index)
    if self:GUID() then
      if not Cache.UnitInfo[self:GUID()] or not Cache.UnitInfo[self:GUID()].Channeling then
        self:GetChannelingInfo();
      end
      if Index then
        return Cache.UnitInfo[self:GUID()].Channeling[Index];
      else
        return unpack(Cache.UnitInfo[self:GUID()].Channeling);
      end
    end
    return nil;
  end

  -- Get if the unit is xhanneling or not.
  function Unit:IsChanneling ()
    return self:ChannelingInfo(1) and true or false;
  end

  -- Get the unit channel's name if there is any.
  function Unit:ChannelName ()
    return self:IsChanneling() and self:ChannelingInfo(1) or "";
  end

  -- Get if the unit cast is interruptible if there is any.
  function Unit:IsInterruptible ()
    return (self:CastingInfo(9) == false or self:ChannelingInfo(8) == false) and true or false;
  end

  -- Get the progression of the cast in percentage if there is any.
  -- By default for channeling, it returns total - progress, if ReverseChannel is true it'll return only progress.
  function Unit:CastPercentage (ReverseChannel)
    if self:IsCasting() then
      _T.Start, _T.End = select(5, self:CastingInfo());
      return (AC.GetTime()*1000 - _T.Start)/(_T.End - _T.Start)*100;
    end
    if self:IsChanneling() then
      _T.Start, _T.End = select(5, self:ChannelingInfo());
      return ReverseChannel and (AC.GetTime()*1000 - _T.Start)/(_T.End - _T.Start)*100 or 100-(AC.GetTime()*1000 - _T.Start)/(_T.End - _T.Start)*100;
    end
    return -1;
  end

  --- Get all the buffs from an unit and put it into the Cache.
  function Unit:GetBuffs ()
    if not Cache.UnitInfo[self:GUID()] then Cache.UnitInfo[self:GUID()] = {}; end
    Cache.UnitInfo[self:GUID()].Buffs = {};
    for i = 1, AC.MAXIMUM do
      _T.Infos = {UnitBuff(self.UnitID, i)};
      if not _T.Infos[11] then break; end
      tableinsert(Cache.UnitInfo[self:GUID()].Buffs, _T.Infos);
    end
  end

  -- buff.foo.up (does return the buff table and not only true/false)
  function Unit:Buff (Spell, Index, AnyCaster)
    if self:GUID() then
      if not Cache.UnitInfo[self:GUID()] or not Cache.UnitInfo[self:GUID()].Buffs then
        self:GetBuffs();
      end
      for i = 1, #Cache.UnitInfo[self:GUID()].Buffs do
        if Spell:ID() == Cache.UnitInfo[self:GUID()].Buffs[i][11] then
          if AnyCaster or (Cache.UnitInfo[self:GUID()].Buffs[i][8] and Player:IsUnit(Unit(Cache.UnitInfo[self:GUID()].Buffs[i][8]))) then
            if Index then
              return Cache.UnitInfo[self:GUID()].Buffs[i][Index];
            else
              return unpack(Cache.UnitInfo[self:GUID()].Buffs[i]);
            end
          end
        end
      end
    end
    return nil;
  end

  -- buff.foo.remains
  function Unit:BuffRemains (Spell, AnyCaster)
    _T.ExpirationTime = self:Buff(Spell, 7, AnyCaster);
    return _T.ExpirationTime and _T.ExpirationTime - AC.GetTime() or 0;
  end

  -- buff.foo.duration
  function Unit:BuffDuration (Spell, AnyCaster)
    return self:Buff(Spell, 6, AnyCaster) or 0;
  end

  -- buff.foo.stack
  function Unit:BuffStack (Spell, AnyCaster)
    return self:Buff(Spell, 4, AnyCaster) or 0;
  end

  -- buff.foo.refreshable (doesn't exists on SimC atm tho)
  function Unit:BuffRefreshable (Spell, PandemicThreshold, AnyCaster)
    if not self:Buff(Spell, nil, AnyCaster) then return true; end
    return PandemicThreshold and self:BuffRemains(Spell, AnyCaster) <= PandemicThreshold;
  end

  --- Get all the debuffs from an unit and put it into the Cache.
  function Unit:GetDebuffs ()
    if not Cache.UnitInfo[self:GUID()] then Cache.UnitInfo[self:GUID()] = {}; end
    Cache.UnitInfo[self:GUID()].Debuffs = {};
    for i = 1, AC.MAXIMUM do
      _T.Infos = {UnitDebuff(self.UnitID, i)};
      if not _T.Infos[11] then break; end
      tableinsert(Cache.UnitInfo[self:GUID()].Debuffs, _T.Infos);
    end
  end

  -- debuff.foo.up or dot.foo.up (does return the debuff table and not only true/false)
  function Unit:Debuff (Spell, Index, AnyCaster)
    if self:GUID() then
      if not Cache.UnitInfo[self:GUID()] or not Cache.UnitInfo[self:GUID()].Debuffs then
        self:GetDebuffs();
      end
      for i = 1, #Cache.UnitInfo[self:GUID()].Debuffs do
        if Spell:ID() == Cache.UnitInfo[self:GUID()].Debuffs[i][11] then
          if AnyCaster or (Cache.UnitInfo[self:GUID()].Debuffs[i][8] and Player:IsUnit(Unit(Cache.UnitInfo[self:GUID()].Debuffs[i][8]))) then
            if Index then
              return Cache.UnitInfo[self:GUID()].Debuffs[i][Index];
            else
              return unpack(Cache.UnitInfo[self:GUID()].Debuffs[i]);
            end
          end
        end
      end
    end
    return nil;
  end

  -- debuff.foo.remains or dot.foo.remains
  function Unit:DebuffRemains (Spell, AnyCaster)
    _T.ExpirationTime = self:Debuff(Spell, 7, AnyCaster);
    return _T.ExpirationTime and _T.ExpirationTime - AC.GetTime() or 0;
  end

  -- debuff.foo.duration or dot.foo.duration
  function Unit:DebuffDuration (Spell, AnyCaster)
    return self:Debuff(Spell, 6, AnyCaster) or 0;
  end

  -- debuff.foo.stack or dot.foo.stack
  function Unit:DebuffStack (Spell, AnyCaster)
    return self:Debuff(Spell, 4, AnyCaster) or 0;
  end

  -- debuff.foo.refreshable or dot.foo.refreshable
  function Unit:DebuffRefreshable (Spell, PandemicThreshold, AnyCaster)
    if not self:Debuff(Spell, nil, AnyCaster) then return true; end
    return PandemicThreshold and self:DebuffRemains(Spell, AnyCaster) <= PandemicThreshold;
  end

  -- Check if the unit is coded as blacklisted or not.
  local SpecialBlacklistDataSpells = {
    D_DHT_Submerged = Spell(220519)
  }
  local SpecialBlacklistData = {
    --- Legion
      ----- Dungeons (7.0 Patch) -----
      --- Darkheart Thicket
        -- Strangling roots can't be hit while this buff is present
        [100991] = function (self) return self:Buff(SpecialBlacklistDataSpells.D_DHT_Submerged, nil, true); end,
      ----- Trial of Valor (T19 - 7.1 Patch) -----
      --- Helya
        -- Striking Tentacle cannot be hit.
        [114881] = true
  }
  function Unit:IsBlacklisted ()
    if SpecialBlacklistData[self:NPCID()] then
      if type(SpecialBlacklistData[self:NPCID()]) == "boolean" then
        return true;
      else
        return SpecialBlacklistData[self:NPCID()](self);
      end
    end
    return false;
  end

  -- Check if the unit is coded as blacklisted by the user or not.
  function Unit:IsUserBlacklisted ()
    if AC.GUISettings.General.Blacklist.UserDefined[self:NPCID()] then
      if type(AC.GUISettings.General.Blacklist.UserDefined[self:NPCID()]) == "boolean" then
        return true;
      else
        return AC.GUISettings.General.Blacklist.UserDefined[self:NPCID()](self);
      end
    end
    return false;
  end

  -- Check if the unit is coded as blacklisted for cycling by the user or not.
  function Unit:IsUserCycleBlacklisted ()
    if AC.GUISettings.General.Blacklist.CycleUserDefined[self:NPCID()] then
      if type(AC.GUISettings.General.Blacklist.CycleUserDefined[self:NPCID()]) == "boolean" then
        return true;
      else
        return AC.GUISettings.General.Blacklist.CycleUserDefined[self:NPCID()](self);
      end
    end
    return false;
  end

  --- Check if the unit is coded as blacklisted for Marked for Death (Rogue) or not.
  -- Most of the time if the unit doesn't really die and isn't the last unit of an instance.
  local SpecialMfdBlacklistData = {
    --- Legion
      ----- Dungeons (7.0 Patch) -----
      --- Halls of Valor
        -- Hymdall leaves the fight at 10%.
        [94960] = true,
        -- Solsten and Olmyr doesn't "really" die
        [102558] = true,
        [97202] = true,
        -- Fenryr leaves the fight at 60%. We take 50% as check value since it doesn't get immune at 60%.
        [95674] = function (self) return self:HealthPercentage() > 50 and true or false; end,

      ----- Trial of Valor (T19 - 7.1 Patch) -----
      --- Odyn
        -- Hyrja & Hymdall leaves the fight at 25% during first stage and 85%/90% during second stage (HM/MM)
        [114360] = true,
        [114361] = true,

    --- Warlord of Draenor (WoD)
      ----- HellFire Citadel (T18 - 6.2 Patch) -----
      --- Hellfire Assault
        -- Mar'Tak doesn't die and leave fight at 50% (blocked at 1hp anyway).
        [93023] = true,

      ----- Dungeons (6.0 Patch) -----
      --- Shadowmoon Burial Grounds
        -- Carrion Worm : They doesn't die but leave the area at 10%.
        [88769] = true,
        [76057] = true
  };
  function Unit:IsMfdBlacklisted ()
    if SpecialMfdBlacklistData[self:NPCID()] then
      if type(SpecialMfdBlacklistData[self:NPCID()]) == "boolean" then
        return true;
      else
        return SpecialMfdBlacklistData[self:NPCID()](self);
      end
    end
    return false;
  end

  function Unit:IsFacingBlacklisted ()
    if self:IsUnit(AC.UnitNotInFront) and AC.GetTime()-AC.UnitNotInFrontTime <= Player:GCD()*AC.GUISettings.General.Blacklist.NotFacingExpireMultiplier then
      return true;
    end
    return false;
  end

  -- Get if the unit is stunned or not
  local IsStunnedDebuff = {
    -- Demon Hunter
    -- Druid
      -- General
      Spell(5211), -- Mighty Bash
      -- Feral
      Spell(203123), -- Maim
      Spell(163505), -- Rake
    -- Paladin
      -- General
      Spell(853), -- Hammer of Justice
      -- Retribution
      Spell(205290), -- Wake of Ashes
    -- Rogue
      -- General
      Spell(199804), -- Between the Eyes
      Spell(1833), -- Cheap Shot
      Spell(408), -- Kidney Shot
      Spell(196958), -- Strike from the Shadows
    -- Warrior
      -- General
      Spell(132168), -- Shockwave
      Spell(132169) -- Storm Bolt
  };
  function Unit:IterateStunDebuffs ()
    for i = 1, #IsStunnedDebuff[1] do
      if self:Debuff(IsStunnedDebuff[1][i], nil, true) then
        return true;
      end
    end
    return false;
  end
  function Unit:IsStunned ()
    if self:GUID() then
      if not Cache.UnitInfo[self:GUID()] then Cache.UnitInfo[self:GUID()] = {}; end
      if Cache.UnitInfo[self:GUID()].IsStunned == nil then
        Cache.UnitInfo[self:GUID()].IsStunned = self:IterateStunDebuffs();
      end
      return Cache.UnitInfo[self:GUID()].IsStunned;
    end
    return nil;
  end

  -- Get if an unit is not immune to stuns
  local IsStunnableClassification = {
    ["trivial"] = true,
    ["minus"] = true,
    ["normal"] = true,
    ["rare"] = true,
    ["rareelite"] = false,
    ["elite"] = false,
    ["worldboss"] = false,
    [""] = false
  };
  function Unit:IsStunnable ()
    -- TODO: Add DR Check
    if self:GUID() then
      if not Cache.UnitInfo[self:GUID()] then Cache.UnitInfo[self:GUID()] = {}; end
      if Cache.UnitInfo[self:GUID()].IsStunnable == nil then
        Cache.UnitInfo[self:GUID()].IsStunnable = IsStunnableClassification[self:Classification()];
      end
      return Cache.UnitInfo[self:GUID()].IsStunnable;
    end
    return nil;
  end

  -- Get if an unit can be stunned or not
  function Unit:CanBeStunned (IgnoreClassification)
    return (IgnoreClassification or self:IsStunnable()) and not self:IsStunned() or false;
  end

  --- TimeToDie
    AC.TTD = {
      Settings = {
        Refresh = 0.1, -- Refresh time (seconds) : min=0.1, max=2, default = 0.2, Aethys = 0.1
        HistoryTime = 10+0.4, -- History time (seconds) : min=5, max=120, default = 20, Aethys = 10
        HistoryCount = 100 -- Max history count : min=20, max=500, default = 120, Aethys = 100
      },
      _T = {
        -- Both
        Values,
        -- TTDRefresh
        UnitFound,
        Time,
        -- TimeToX
        Seconds,
        MaxHealth, StartingTime,
        UnitTable,
        MinSamples, -- In TimeToDie aswell
        a, b,
        n,
        x, y,
        Ex2, Ex, Exy, Ey,
        Invariant
      },
      Units = {},
      Throttle = 0
    };
    local TTD = AC.TTD;
    function AC.TTDRefresh ()
      for Key, Value in pairs(TTD.Units) do -- TODO: Need to be optimized
        TTD._T.UnitFound = false;
        for i = 1, AC.MAXIMUM do
          _T.ThisUnit = Unit["Nameplate"..tostring(i)];
          if Key == _T.ThisUnit:GUID() and _T.ThisUnit:Exists() then
            TTD._T.UnitFound = true;
          end
        end
        if not TTD._T.UnitFound then
          TTD.Units[Key] = nil;
        end
      end
      for i = 1, AC.MAXIMUM do
        _T.ThisUnit = Unit["Nameplate"..tostring(i)];
        if _T.ThisUnit:Exists() and Player:CanAttack(_T.ThisUnit) and _T.ThisUnit:Health() < _T.ThisUnit:MaxHealth() then
          if not TTD.Units[_T.ThisUnit:GUID()] or _T.ThisUnit:Health() > TTD.Units[_T.ThisUnit:GUID()][1][1][2] then
            TTD.Units[_T.ThisUnit:GUID()] = {{}, _T.ThisUnit:MaxHealth(), AC.GetTime(), -1};
          end
          TTD._T.Values = TTD.Units[_T.ThisUnit:GUID()][1];
          TTD._T.Time = AC.GetTime() - TTD.Units[_T.ThisUnit:GUID()][3];
          if _T.ThisUnit:Health() ~= TTD.Units[_T.ThisUnit:GUID()][4] then
            tableinsert(TTD._T.Values, 1, {TTD._T.Time, _T.ThisUnit:Health()});
            while (#TTD._T.Values > TTD.Settings.HistoryCount) or (TTD._T.Time - TTD._T.Values[#TTD._T.Values][1] > TTD.Settings.HistoryTime) do
              tableremove(TTD._T.Values);
            end
            TTD.Units[_T.ThisUnit:GUID()][4] = _T.ThisUnit:Health();
          end
        end
      end
    end

    -- Get the estimated time to reach a Percentage
    -- TODO : Cache the result, not done yet since we mostly use TimeToDie that cache for TimeToX 0%.
    -- Returns Codes :
    --  11111 : No GUID    9999 : Negative TTD    8888 : Not Enough Samples or No Health Change    7777 : No DPS    6666 : Dummy
    function Unit:TimeToX (Percentage, MinSamples) -- TODO : See with Skasch how accuracy & prediction can be improved.
      if self:IsDummy() then return 6666; end
      TTD._T.Seconds = 8888;
      TTD._T.UnitTable = TTD.Units[self:GUID()];
      TTD._T.MinSamples = MinSamples or 3;
      TTD._T.a, TTD._T.b = 0, 0;
      -- Simple linear regression
      -- ( E(x^2)  E(x) )  ( a )  ( E(xy) )
      -- ( E(x)     n  )  ( b ) = ( E(y)  )
      -- Format of the above: ( 2x2 Matrix ) * ( 2x1 Vector ) = ( 2x1 Vector )
      -- Solve to find a and b, satisfying y = a + bx
      -- Matrix arithmetic has been expanded and solved to make the following operation as fast as possible
      if TTD._T.UnitTable then
        TTD._T.Values = TTD._T.UnitTable[1];
        TTD._T.n = #TTD._T.Values;
        if TTD._T.n > MinSamples then
          TTD._T.MaxHealth = TTD._T.UnitTable[2];
          TTD._T.StartingTime = TTD._T.UnitTable[3];
          TTD._T.x, TTD._T.y = 0, 0;
          TTD._T.Ex2, TTD._T.Ex, TTD._T.Exy, TTD._T.Ey = 0, 0, 0, 0;
          
          for _, Value in pairs(TTD._T.Values) do
            TTD._T.x, TTD._T.y = unpack(Value);

            TTD._T.Ex2 = TTD._T.Ex2 + TTD._T.x * TTD._T.x;
            TTD._T.Ex = TTD._T.Ex + TTD._T.x;
            TTD._T.Exy = TTD._T.Exy + TTD._T.x * TTD._T.y;
            TTD._T.Ey = TTD._T.Ey + TTD._T.y;
          end
          -- Invariant to find matrix inverse
          TTD._T.Invariant = TTD._T.Ex2*TTD._T.n - TTD._T.Ex*TTD._T.Ex;
          -- Solve for a and b
          TTD._T.a = (-TTD._T.Ex * TTD._T.Exy / TTD._T.Invariant) + (TTD._T.Ex2 * TTD._T.Ey / TTD._T.Invariant);
          TTD._T.b = (TTD._T.n * TTD._T.Exy / TTD._T.Invariant) - (TTD._T.Ex * TTD._T.Ey / TTD._T.Invariant);
        end
      end
      if TTD._T.b ~= 0 then
        -- Use best fit line to calculate estimated time to reach target health
        TTD._T.Seconds = (Percentage * 0.01 * TTD._T.MaxHealth - TTD._T.a) / TTD._T.b;
        -- Subtract current time to obtain "time remaining"
        TTD._T.Seconds = mathmin(7777, TTD._T.Seconds - (AC.GetTime() - TTD._T.StartingTime));
        if TTD._T.Seconds < 0 then TTD._T.Seconds = 9999; end
      end
      return mathfloor(TTD._T.Seconds);
    end

    -- Get the unit TTD Percentage
    local SpecialTTDPercentageData = {
      --- Legion
        ----- Dungeons (7.0 Patch) -----
        --- Halls of Valor
          -- Hymdall leaves the fight at 10%.
          [94960] = 10,
          -- Fenryr leaves the fight at 60%. We take 50% as check value since it doesn't get immune at 60%.
          [95674] = function (self) return (self:HealthPercentage() > 50 and 60) or 0 end,
          -- Odyn leaves the fight at 80%.
          [95676] = 80,
        --- Maw of Souls
          -- Helya leaves the fight at 70%.
          [96759] = 70,

        ----- Trial of Valor (T19 - 7.1 Patch) -----
        --- Odyn
          -- Hyrja & Hymdall leaves the fight at 25% during first stage and 85%/90% during second stage (HM/MM).
          -- TODO : Put GetInstanceInfo into PersistentCache.
          [114360] = function (self) return (not self:IsInBossList(114263, 99) and 25) or (select(3, GetInstanceInfo()) == 16 and 85) or 90; end,
          [114361] = function (self) return (not self:IsInBossList(114263, 99) and 25) or (select(3, GetInstanceInfo()) == 16 and 85) or 90; end,
          -- Odyn leaves the fight at 10%.
          [114263] = 10,

      --- Warlord of Draenor (WoD)
        ----- HellFire Citadel (T18 - 6.2 Patch) -----
        --- Hellfire Assault
          -- Mar'Tak doesn't die and leave fight at 50% (blocked at 1hp anyway).
          [93023] = 50,

        ----- Dungeons (6.0 Patch) -----
        --- Shadowmoon Burial Grounds
          -- Carrion Worm : They doesn't die but leave the area at 10%.
          [88769] = 10,
          [76057] = 10
    };
    function Unit:SpecialTTDPercentage (NPCID)
      if SpecialTTDPercentageData[NPCID] then
        if type(SpecialTTDPercentageData[NPCID]) == "number" then
          return SpecialTTDPercentageData[NPCID];
        else
          return SpecialTTDPercentageData[NPCID](self);
        end
      end
      return 0;
    end

    -- Get the unit TimeToDie
    function Unit:TimeToDie (MinSamples)
      if self:GUID() then
        TTD._T.MinSamples = MinSamples or 3;
        if not Cache.UnitInfo[self:GUID()] then Cache.UnitInfo[self:GUID()] = {}; end
        if not Cache.UnitInfo[self:GUID()].TTD then Cache.UnitInfo[self:GUID()].TTD = {}; end
        if not Cache.UnitInfo[self:GUID()].TTD[TTD._T.MinSamples] then
          Cache.UnitInfo[self:GUID()].TTD[TTD._T.MinSamples] = self:TimeToX(self:SpecialTTDPercentage(self:NPCID()), TTD._T.MinSamples)
        end
        return Cache.UnitInfo[self:GUID()].TTD[TTD._T.MinSamples];
      end
      return 11111;
    end

  --- PLAYER SPECIFIC

    -- Get if the player is mounted on a non-combat mount.
    function Unit:IsMounted ()
      return IsMounted() and not self:IsOnCombatMount();
    end

    -- Get if the player is on a combat mount or not.
    local CombatMountBuff = {
      --- Classes
        Spell(131347), -- Demon Hunter Glide
        Spell(783), -- Druid Travel Form
        Spell(165962), -- Druid Flight Form
        Spell(220509), -- Paladin Divine Steed
        Spell(221883), -- Paladin Divine Steed
        Spell(221884), -- Paladin Divine Steed
        Spell(221886), -- Paladin Divine Steed
        Spell(221887), -- Paladin Divine Steed
      --- Legion
        -- Class Order Hall
        Spell(220480), -- Death Knight Ebon Blade Deathcharger
        Spell(220484), -- Death Knight Nazgrim's Deathcharger
        Spell(220488), -- Death Knight Trollbane's Deathcharger
        Spell(220489), -- Death Knight Whitemane's Deathcharger
        Spell(220491), -- Death Knight Mograine's Deathcharger
        Spell(220504), -- Paladin Silver Hand Charger
        Spell(220507), -- Paladin Silver Hand Charger
        -- Stormheim PVP Quest (Bareback Brawl)
        Spell(221595), -- Storm's Reach Cliffwalker
        Spell(221671), -- Storm's Reach Warbear
        Spell(221672), -- Storm's Reach Greatstag
        Spell(221673), -- Storm's Reach Worg
        Spell(218964), -- Stormtalon
      --- Warlord of Draenor (WoD)
        -- Nagrand
        Spell(164222), -- Frostwolf War Wolf
        Spell(165803) -- Telaari Talbuk
    };
    function Unit:IsOnCombatMount ()
      for i = 1, #CombatMountBuff do
        if self:Buff(CombatMountBuff[i], nil, true) then
          return true;
        end
      end
      return false;
    end

    -- gcd
    local GCD_OneSecond = {
      [103] = true, -- Feral
      [259] = true, -- Assassination
      [260] = true, -- Outlaw
      [261] = true, -- Subtlety
      [268] = true, -- Brewmaster
      [269] = true  -- Windwalker
    };
    local GCD_Value = 1.5;
    function Unit:GCD ()
      if self:GUID() then
        if not Cache.UnitInfo[self:GUID()] then Cache.UnitInfo[self:GUID()] = {}; end
        if not Cache.UnitInfo[self:GUID()].GCD then
          if GCD_OneSecond[Cache.Persistent.Player.Spec[1]] then
            Cache.UnitInfo[self:GUID()].GCD = 1;
          else
            GCD_Value = 1.5/(1+self:HastePct()/100);
            Cache.UnitInfo[self:GUID()].GCD = GCD_Value > 0.75 and GCD_Value or 0.75;
          end
        end
        return Cache.UnitInfo[self:GUID()].GCD;
      end
    end
    
    -- gcd.remains
    local GCDSpell = Spell(61304);
    function Unit:GCDRemains ()
      return GCDSpell:Cooldown(true);
    end

    -- attack_power
    -- TODO : Use Cache
    function Unit:AttackPower ()
      return UnitAttackPower(self.UnitID);
    end

    -- crit_chance
    -- TODO : Use Cache
    function Unit:CritChancePct ()
      return GetCritChance();
    end

    -- haste
    -- TODO : Use Cache
    function Unit:HastePct ()
      return GetHaste();
    end

    -- mastery
    -- TODO : Use Cache
    function Unit:MasteryPct ()
      return GetMasteryEffect();
    end

    -- versatility
    -- TODO : Use Cache
    function Unit:VersatilityDmgPct ()
      return GetCombatRatingBonus(CR_VERSATILITY_DAMAGE_DONE) + GetVersatilityBonus(CR_VERSATILITY_DAMAGE_DONE);
    end
	
	-- Get the level of the unit
	function Unit:Level()
	  if self:GUID() then
        if not Cache.UnitInfo[self:GUID()] then Cache.UnitInfo[self:GUID()] = {}; end
        if Cache.UnitInfo[self:GUID()].UnitLevel == nil then
          Cache.UnitInfo[self:GUID()].UnitLevel = UnitLevel(self.UnitID);
        end
        return Cache.UnitInfo[self:GUID()].UnitLevel;
      end
      return nil;
	end

    --------------------------
    --- 1 | Rage Functions ---
    --------------------------
      -- rage.max
    function Unit:RageMax ()
      if self:GUID() then
        if not Cache.UnitInfo[self:GUID()] then Cache.UnitInfo[self:GUID()] = {}; end
        if not Cache.UnitInfo[self:GUID()].RageMax then
          Cache.UnitInfo[self:GUID()].RageMax = UnitPowerMax(self.UnitID, SPELL_POWER_RAGE);
        end
        return Cache.UnitInfo[self:GUID()].RageMax;
      end
    end
    -- rage
    function Unit:Rage ()
      if self:GUID() then
        if not Cache.UnitInfo[self:GUID()] then Cache.UnitInfo[self:GUID()] = {}; end
        if not Cache.UnitInfo[self:GUID()].Rage then
          Cache.UnitInfo[self:GUID()].Rage = UnitPower(self.UnitID, SPELL_POWER_RAGE);
        end
        return Cache.UnitInfo[self:GUID()].Rage;
      end
    end
    -- rage.pct
    function Unit:RagePercentage ()
      return (self:Rage() / self:RageMax()) * 100;
    end
    -- rage.deficit
    function Unit:RageDeficit ()
      return self:RageMax() - self:Rage();
    end
    -- "rage.deficit.pct"
    function Unit:RageDeficitPercentage ()
      return (self:RageDeficit() / self:RageMax()) * 100;
    end

    ---------------------------
    --- 2 | Focus Functions ---
    ---------------------------
    -- focus.max
    function Unit:FocusMax ()
      if self:GUID() then
        if not Cache.UnitInfo[self:GUID()] then Cache.UnitInfo[self:GUID()] = {}; end
        if not Cache.UnitInfo[self:GUID()].FocusMax then
          Cache.UnitInfo[self:GUID()].FocusMax = UnitPowerMax(self.UnitID, SPELL_POWER_FOCUS);
        end
        return Cache.UnitInfo[self:GUID()].FocusMax;
      end
    end
    -- focus
    function Unit:Focus ()
      if self:GUID() then
        if not Cache.UnitInfo[self:GUID()] then Cache.UnitInfo[self:GUID()] = {}; end
        if not Cache.UnitInfo[self:GUID()].Focus then
          Cache.UnitInfo[self:GUID()].Focus = UnitPower(self.UnitID, SPELL_POWER_FOCUS);
        end
        return Cache.UnitInfo[self:GUID()].Focus;
      end
    end
    -- focus.regen
    function Unit:FocusRegen ()
      if self:GUID() then
        if not Cache.UnitInfo[self:GUID()] then Cache.UnitInfo[self:GUID()] = {}; end
        if not Cache.UnitInfo[self:GUID()].FocusRegen then
          Cache.UnitInfo[self:GUID()].FocusRegen = select(2, GetPowerRegen(self.UnitID));
        end
        return Cache.UnitInfo[self:GUID()].FocusRegen;
      end
    end
    -- focus.pct
    function Unit:FocusPercentage ()
      return (self:Focus() / self:FocusMax()) * 100;
    end
    -- focus.deficit
    function Unit:FocusDeficit ()
      return self:FocusMax() - self:Focus();
    end
    -- "focus.deficit.pct"
    function Unit:FocusDeficitPercentage ()
      return (self:FocusDeficit() / self:FocusMax()) * 100;
    end
    -- "focus.regen.pct"
    function Unit:FocusRegenPercentage ()
      return (self:FocusRegen() / self:FocusMax()) * 100;
    end
    -- focus.time_to_max
    function Unit:FocusTimeToMax ()
      if self:FocusRegen() == 0 then return -1; end
      return self:FocusDeficit() * (1 / self:FocusRegen());
    end
    -- "focus.time_to_x"
    function Unit:FocusTimeToX (Amount)
      if self:FocusRegen() == 0 then return -1; end
      return Amount > self:Focus() and (Amount - self:Focus()) * (1 / self:FocusRegen()) or 0;
    end
    -- "focus.time_to_x.pct"
    function Unit:FocusTimeToXPercentage (Amount)
      if self:FocusRegen() == 0 then return -1; end
      return Amount > self:FocusPercentage() and (Amount - self:FocusPercentage()) * (1 / self:FocusRegenPercentage()) or 0;
    end

    ----------------------------
    --- 3 | Energy Functions ---
    ----------------------------
    -- energy.max
    function Unit:EnergyMax ()
      if self:GUID() then
        if not Cache.UnitInfo[self:GUID()] then Cache.UnitInfo[self:GUID()] = {}; end
        if not Cache.UnitInfo[self:GUID()].EnergyMax then
          Cache.UnitInfo[self:GUID()].EnergyMax = UnitPowerMax(self.UnitID, SPELL_POWER_ENERGY);
        end
        return Cache.UnitInfo[self:GUID()].EnergyMax;
      end
    end
    -- energy
    function Unit:Energy ()
      if self:GUID() then
        if not Cache.UnitInfo[self:GUID()] then Cache.UnitInfo[self:GUID()] = {}; end
        if not Cache.UnitInfo[self:GUID()].Energy then
          Cache.UnitInfo[self:GUID()].Energy = UnitPower(self.UnitID, SPELL_POWER_ENERGY);
        end
        return Cache.UnitInfo[self:GUID()].Energy;
      end
    end
    -- energy.regen
    function Unit:EnergyRegen ()
      if self:GUID() then
        if not Cache.UnitInfo[self:GUID()] then Cache.UnitInfo[self:GUID()] = {}; end
        if not Cache.UnitInfo[self:GUID()].EnergyRegen then
          Cache.UnitInfo[self:GUID()].EnergyRegen = select(2, GetPowerRegen(self.UnitID));
        end
        return Cache.UnitInfo[self:GUID()].EnergyRegen;
      end
    end
    -- energy.pct
    function Unit:EnergyPercentage ()
      return (self:Energy() / self:EnergyMax()) * 100;
    end
    -- energy.deficit
    function Unit:EnergyDeficit ()
      return self:EnergyMax() - self:Energy();
    end
    -- "energy.deficit.pct"
    function Unit:EnergyDeficitPercentage ()
      return (self:EnergyDeficit() / self:EnergyMax()) * 100;
    end
    -- "energy.regen.pct"
    function Unit:EnergyRegenPercentage ()
      return (self:EnergyRegen() / self:EnergyMax()) * 100;
    end
    -- energy.time_to_max
    function Unit:EnergyTimeToMax ()
      if self:EnergyRegen() == 0 then return -1; end
      return self:EnergyDeficit() * (1 / self:EnergyRegen());
    end
    -- "energy.time_to_x"
    function Unit:EnergyTimeToX (Amount)
      if self:EnergyRegen() == 0 then return -1; end
      return Amount > self:Energy() and (Amount - self:Energy()) * (1 / self:EnergyRegen()) or 0;
    end
    -- "energy.time_to_x.pct"
    function Unit:EnergyTimeToXPercentage (Amount)
      if self:EnergyRegen() == 0 then return -1; end
      return Amount > self:EnergyPercentage() and (Amount - self:EnergyPercentage()) * (1 / self:EnergyRegenPercentage()) or 0;
    end

    ----------------------------------
    --- 4 | Combo Points Functions ---
    ----------------------------------
    -- combo_points.max
    function Unit:ComboPointsMax ()
      if self:GUID() then
        if not Cache.UnitInfo[self:GUID()] then Cache.UnitInfo[self:GUID()] = {}; end
        if not Cache.UnitInfo[self:GUID()].ComboPointsMax then
          Cache.UnitInfo[self:GUID()].ComboPointsMax = UnitPowerMax(self.UnitID, SPELL_POWER_COMBO_POINTS);
        end
        return Cache.UnitInfo[self:GUID()].ComboPointsMax;
      end
    end
    -- combo_points
    function Unit:ComboPoints ()
      if self:GUID() then
        if not Cache.UnitInfo[self:GUID()] then Cache.UnitInfo[self:GUID()] = {}; end
        if not Cache.UnitInfo[self:GUID()].ComboPoints then
          Cache.UnitInfo[self:GUID()].ComboPoints = UnitPower(self.UnitID, SPELL_POWER_COMBO_POINTS);
        end
        return Cache.UnitInfo[self:GUID()].ComboPoints;
      end
    end
    -- combo_points.deficit
    function Unit:ComboPointsDeficit ()
      return self:ComboPointsMax() - self:ComboPoints();
    end
	
	--------------------------------
    ------- 8 | Astral Power -------
    --------------------------------
	-- AstralPower.Max
	function Unit:AstralPowerMax ()
      if self:GUID() then
        if not Cache.UnitInfo[self:GUID()] then Cache.UnitInfo[self:GUID()] = {}; end
        if not Cache.UnitInfo[self:GUID()].AstralPowerMax then
          Cache.UnitInfo[self:GUID()].AstralPowerMax = UnitPowerMax(self.UnitID, SPELL_POWER_LUNAR_POWER);
        end
        return Cache.UnitInfo[self:GUID()].AstralPowerMax;
      end
    end
    -- astral_power
    function Unit:AstralPower ()
      if self:GUID() then
        if not Cache.UnitInfo[self:GUID()] then Cache.UnitInfo[self:GUID()] = {}; end
        if not Cache.UnitInfo[self:GUID()].AstralPower then
          Cache.UnitInfo[self:GUID()].AstralPower = UnitPower(self.UnitID, SPELL_POWER_LUNAR_POWER);
        end
        return Cache.UnitInfo[self:GUID()].AstralPower;
      end
    end
    -- astral_power.pct
    function Unit:AstralPowerPercentage ()
      return (self:AstralPower() / self:AstralPowerMax()) * 100;
    end
    -- astral_power.deficit
    function Unit:AstralPowerDeficit ()
      return self:AstralPowerMax() - self:AstralPower();
    end
    -- "astral_power.deficit.pct"
    function Unit:AstralPowerDeficitPercentage ()
      return (self:AstralPowerDeficit() / self:AstralPowerMax()) * 100;
    end

    --------------------------------
    --- 9 | Holy Power Functions ---
    --------------------------------
    -- holy_power.max
    function Unit:HolyPowerMax ()
      if self:GUID() then
        if not Cache.UnitInfo[self:GUID()] then Cache.UnitInfo[self:GUID()] = {}; end
        if not Cache.UnitInfo[self:GUID()].HolyPowerMax then
          Cache.UnitInfo[self:GUID()].HolyPowerMax = UnitPowerMax(self.UnitID, SPELL_POWER_HOLY_POWAC);
        end
        return Cache.UnitInfo[self:GUID()].HolyPowerMax;
      end
    end
    -- holy_power
    function Unit:HolyPower ()
      if self:GUID() then
        if not Cache.UnitInfo[self:GUID()] then Cache.UnitInfo[self:GUID()] = {}; end
        if not Cache.UnitInfo[self:GUID()].HolyPower then
          Cache.UnitInfo[self:GUID()].HolyPower = UnitPower(self.UnitID, SPELL_POWER_HOLY_POWAC);
        end
        return Cache.UnitInfo[self:GUID()].HolyPower;
      end
    end
    -- holy_power.pct
    function Unit:HolyPowerPercentage ()
      return (self:HolyPower() / self:HolyPowerMax()) * 100;
    end
    -- holy_power.deficit
    function Unit:HolyPowerDeficit ()
      return self:HolyPowerMax() - self:HolyPower();
    end
    -- "holy_power.deficit.pct"
    function Unit:HolyPowerDeficitPercentage ()
      return (self:HolyPowerDeficit() / self:HolyPowerMax()) * 100;
    end
	
	---------------------------
    -- 11 | Maelstrom Functions --
    ---------------------------
    -- Maelstrom.max
    function Unit:MaelstromMax ()
      if self:GUID() then
        if not Cache.UnitInfo[self:GUID()] then Cache.UnitInfo[self:GUID()] = {}; end
        if not Cache.UnitInfo[self:GUID()].MaelstromMax then
          Cache.UnitInfo[self:GUID()].MaelstromMax = UnitPowerMax(self.UnitID, SPELL_POWER_MAELSTROM);
        end
        return Cache.UnitInfo[self:GUID()].MaelstromMax;
      end
    end
    -- Maelstrom
    function Unit:Maelstrom ()
      if self:GUID() then
        if not Cache.UnitInfo[self:GUID()] then Cache.UnitInfo[self:GUID()] = {}; end
        if not Cache.UnitInfo[self:GUID()].MaelstromMax then
          Cache.UnitInfo[self:GUID()].MaelstromMax = UnitPower(self.UnitID, SPELL_POWER_MAELSTROM);
        end
        return Cache.UnitInfo[self:GUID()].MaelstromMax;
      end
    end
    -- Maelstrom.pct
    function Unit:MaelstromPercentage ()
      return (self:Maelstrom() / self:MaelstromMax()) * 100;
    end
    -- Maelstrom.deficit
    function Unit:MaelstromDeficit ()
      return self:MaelstromMax() - self:Maelstrom();
    end
    -- "Maelstrom.deficit.pct"
    function Unit:MaelstromDeficitPercentage ()
      return (self:MaelstromDeficit() / self:MaelstromMax()) * 100;
    end

	------------------------------
    -- 13 | Insanity Functions ---
    ------------------------------
	-- insanity.max
    function Unit:InsanityMax ()
      if self:GUID() then
        if not Cache.UnitInfo[self:GUID()] then Cache.UnitInfo[self:GUID()] = {}; end
        if not Cache.UnitInfo[self:GUID()].InsanityMax then
          Cache.UnitInfo[self:GUID()].InsanityMax = UnitPowerMax(self.UnitID, SPELL_POWER_INSANITY);
        end
        return Cache.UnitInfo[self:GUID()].InsanityMax;
      end
    end
    -- insanity
    function Unit:Insanity ()
      if self:GUID() then
        if not Cache.UnitInfo[self:GUID()] then Cache.UnitInfo[self:GUID()] = {}; end
        if not Cache.UnitInfo[self:GUID()].Insanity then
          Cache.UnitInfo[self:GUID()].Insanity = UnitPower(self.UnitID, SPELL_POWER_INSANITY);
        end
        return Cache.UnitInfo[self:GUID()].Insanity;
      end
    end
	-- insanity.pct
    function Unit:InsanityPercentage ()
      return (self:Insanity() / self:InsanityMax()) * 100;
    end
    -- insanity.deficit
    function Unit:InsanityDeficit ()
      return self:InsanityMax() - self:Insanity();
    end
    -- "insanity.deficit.pct"
    function Unit:InsanityDeficitPercentage ()
      return (self:InsanityDeficit() / self:InsanityMax()) * 100;
    end
	-- Insanity Drain
	function Unit:Insanityrain ()
		--TODO : calculate insanitydrain
      return 1;
    end

    --------------------------------
    --- 11 | Maelstrom Functions ---
    --------------------------------
    -- maelstrom.max
    function Unit:MaelstromMax ()
      if self:GUID() then
        if not Cache.UnitInfo[self:GUID()] then Cache.UnitInfo[self:GUID()] = {}; end
        if not Cache.UnitInfo[self:GUID()].MaelstromMax then
          Cache.UnitInfo[self:GUID()].MaelstromMax = UnitPowerMax(self.UnitID, SPELL_POWER_MAELSTROM);
        end
        return Cache.UnitInfo[self:GUID()].MaelstromMax;
      end
    end
    -- maelstrom
    function Unit:Maelstrom ()
      if self:GUID() then
        if not Cache.UnitInfo[self:GUID()] then Cache.UnitInfo[self:GUID()] = {}; end
        if not Cache.UnitInfo[self:GUID()].MaelstromMax then
          Cache.UnitInfo[self:GUID()].MaelstromMax = UnitPower(self.UnitID, SPELL_POWER_MAELSTROM);
        end
        return Cache.UnitInfo[self:GUID()].MaelstromMax;
      end
    end
    -- maelstrom.pct
    function Unit:MaelstromPercentage ()
      return (self:Maelstrom() / self:MaelstromMax()) * 100;
    end
    -- maelstrom.deficit
    function Unit:MaelstromDeficit ()
      return self:MaelstromMax() - self:Maelstrom();
    end
    -- "maelstrom.deficit.pct"
    function Unit:MaelstromDeficitPercentage ()
      return (self:MaelstromDeficit() / self:MaelstromMax()) * 100;
    end

    ---------------------------
    --- 17 | Fury Functions ---
    ---------------------------
    -- fury.max
    function Unit:FuryMax ()
      if self:GUID() then
        if not Cache.UnitInfo[self:GUID()] then Cache.UnitInfo[self:GUID()] = {}; end
        if not Cache.UnitInfo[self:GUID()].FuryMax then
          Cache.UnitInfo[self:GUID()].FuryMax = UnitPowerMax(self.UnitID, SPELL_POWER_FURY);
        end
        return Cache.UnitInfo[self:GUID()].FuryMax;
      end
    end
    -- fury
    function Unit:Fury ()
      if self:GUID() then
        if not Cache.UnitInfo[self:GUID()] then Cache.UnitInfo[self:GUID()] = {}; end
        if not Cache.UnitInfo[self:GUID()].Fury then
          Cache.UnitInfo[self:GUID()].Fury = UnitPower(self.UnitID, SPELL_POWER_FURY);
        end
        return Cache.UnitInfo[self:GUID()].Fury;
      end
    end
    -- fury.pct
    function Unit:FuryPercentage ()
      return (self:Fury() / self:FuryMax()) * 100;
    end
    -- fury.deficit
    function Unit:FuryDeficit ()
      return self:FuryMax() - self:Fury();
    end
    -- "fury.deficit.pct"
    function Unit:FuryDeficitPercentage ()
      return (self:FuryDeficit() / self:FuryMax()) * 100;
    end

    ---------------------------
    --- 18 | Pain Functions ---
    ---------------------------
    -- pain.max
    function Unit:PainMax ()
      if self:GUID() then
        if not Cache.UnitInfo[self:GUID()] then Cache.UnitInfo[self:GUID()] = {}; end
        if not Cache.UnitInfo[self:GUID()].PainMax then
          Cache.UnitInfo[self:GUID()].PainMax = UnitPowerMax(self.UnitID, SPELL_POWER_PAIN);
        end
        return Cache.UnitInfo[self:GUID()].PainMax;
      end
    end
    -- pain
    function Unit:Pain ()
      if self:GUID() then
        if not Cache.UnitInfo[self:GUID()] then Cache.UnitInfo[self:GUID()] = {}; end
        if not Cache.UnitInfo[self:GUID()].PainMax then
          Cache.UnitInfo[self:GUID()].PainMax = UnitPower(self.UnitID, SPELL_POWER_PAIN);
        end
        return Cache.UnitInfo[self:GUID()].PainMax;
      end
    end
    -- pain.pct
    function Unit:PainPercentage ()
      return (self:Pain() / self:PainMax()) * 100;
    end
    -- pain.deficit
    function Unit:PainDeficit ()
      return self:PainMax() - self:Pain();
    end
    -- "pain.deficit.pct"
    function Unit:PainDeficitPercentage ()
      return (self:PainDeficit() / self:PainMax()) * 100;
    end

    -- Get if the player is stealthed or not
    local IsStealthedBuff = {
      -- Normal Stealth
      {
        -- Rogue
        Spell(1784), -- Stealth
        Spell(115191), -- Stealth w/ Subterfuge Talent
        -- Feral
        Spell(5215), -- Prowl
      },
      -- Combat Stealth
      {
        -- Rogue
        Spell(11327), -- Vanish
        Spell(115193), -- Vanish w/ Subterfuge Talent
        Spell(115192), -- Subterfuge Buff
        Spell(185422), -- Stealth from Shadow Dance
      },
      -- Special Stealth
      {
        -- Night Elf
        Spell(58984) -- Shadowmeld
      }
    };
    function Unit:IterateStealthBuffs (Abilities, Special, Duration)
      -- TODO: Add Assassination Spells when it'll be done and improve code
      -- TODO: Add Feral if we do supports it some day
      if  Spell.Rogue.Outlaw.Vanish:TimeSinceLastCast() < 0.3 or
        Spell.Rogue.Subtlety.ShadowDance:TimeSinceLastCast() < 0.3 or
        Spell.Rogue.Subtlety.Vanish:TimeSinceLastCast() < 0.3 or
        (Special and (
          Spell.Rogue.Outlaw.Shadowmeld:TimeSinceLastCast() < 0.3 or
          Spell.Rogue.Subtlety.Shadowmeld:TimeSinceLastCast() < 0.3
        ))
      then
        return Duration and 1 or true;
      end
      -- Normal Stealth
      for i = 1, #IsStealthedBuff[1] do
        if self:Buff(IsStealthedBuff[1][i]) then
          return Duration and self:BuffRemains(IsStealthedBuff[1][i]) or true;
        end
      end
      -- Combat Stealth
      if Abilities then
        for i = 1, #IsStealthedBuff[2] do
          if self:Buff(IsStealthedBuff[2][i]) then
            return Duration and self:BuffRemains(IsStealthedBuff[2][i]) or true;
          end
        end
      end
      -- Special Stealth
      if Special then
        for i = 1, #IsStealthedBuff[3] do
          if self:Buff(IsStealthedBuff[3][i]) then
            return Duration and self:BuffRemains(IsStealthedBuff[3][i]) or true;
          end
        end
      end
      return false;
    end
    local IsStealthedKey;
    function Unit:IsStealthed (Abilities, Special)
      IsStealthedKey = tostring(Abilites).."-"..tostring(Special);
      if not Cache.MiscInfo then Cache.MiscInfo = {}; end
      if not Cache.MiscInfo.IsStealthed then Cache.MiscInfo.IsStealthed = {}; end
      if Cache.MiscInfo.IsStealthed[IsStealthedKey] == nil then
        Cache.MiscInfo.IsStealthed[IsStealthedKey] = self:IterateStealthBuffs(Abilities, Special);
      end
      return Cache.MiscInfo.IsStealthed[IsStealthedKey];
    end

    -- buff.bloodlust.up
    function Unit:HasHeroism ()
      -- TODO: Make a table with all the bloodlust spells then do a for loop checking them (with AnyCaster as true in buff)
      return false;
    end

    -- Save the current player's equipment.
    AC.Equipment = {};
    function AC.GetEquipment ()
      local Item;
      for i = 1, 19 do
        Item = select(1, GetInventoryItemID("Player", i));
        -- If there is an item in that slot
        if Item ~= nil then
          AC.Equipment[i] = Item;
        end
      end
    end

    -- Check player set bonuses (call AC.GetEquipment before to refresh the current gear)
    HasTierSets = {
      ["T18"] = {
        [0]     =  function (Count) return Count > 1, Count > 3; end,                -- Return Function
        [1]     =  {[5] = 124319, [10] = 124329, [1] = 124334, [7] = 124340, [3] = 124346},    -- Warrior: Chest, Hands, Head, Legs, Shoulder
        [2]     =  {[5] = 124318, [10] = 124328, [1] = 124333, [7] = 124339, [3] = 124345},    -- Paladin: Chest, Hands, Head, Legs, Shoulder
        [3]     =  {[5] = 124284, [10] = 124292, [1] = 124296, [7] = 124301, [3] = 124307},    -- Hunter: Chest, Hands, Head, Legs, Shoulder
        [4]     =  {[5] = 124248, [10] = 124257, [1] = 124263, [7] = 124269, [3] = 124274},    -- Rogue: Chest, Hands, Head, Legs, Shoulder
        [5]     =  {[5] = 124172, [10] = 124155, [1] = 124161, [7] = 124166, [3] = 124178},    -- Priest: Chest, Hands, Head, Legs, Shoulder
        [6]     =  {[5] = 124317, [10] = 124327, [1] = 124332, [7] = 124338, [3] = 124344},    -- Death Knight: Chest, Hands, Head, Legs, Shoulder
        [7]     =  {[5] = 124303, [10] = 124293, [1] = 124297, [7] = 124302, [3] = 124308},    -- Shaman: Chest, Hands, Head, Legs, Shoulder
        [8]     =  {[5] = 124171, [10] = 124154, [1] = 124160, [7] = 124165, [3] = 124177},    -- Mage: Chest, Hands, Head, Legs, Shoulder
        [9]     =  {[5] = 124173, [10] = 124156, [1] = 124162, [7] = 124167, [3] = 124179},    -- Warlock: Chest, Hands, Head, Legs, Shoulder
        [10]    =  {[5] = 124247, [10] = 124256, [1] = 124262, [7] = 124268, [3] = 124273},    -- Monk: Chest, Hands, Head, Legs, Shoulder
        [11]    =  {[5] = 124246, [10] = 124255, [1] = 124261, [7] = 124267, [3] = 124272},    -- Druid: Chest, Hands, Head, Legs, Shoulder
        [12]    =  nil                                        -- Demon Hunter: Chest, Hands, Head, Legs, Shoulder
      },
      ["T18_ClassTrinket"] = {
        [0]     =  function (Count) return Count > 0; end,    -- Return Function
        [1]     =  {[13] = 124523, [14] = 124523},        -- Warrior : Worldbreaker's Resolve
        [2]     =  {[13] = 124518, [14] = 124518},        -- Paladin : Libram of Vindication
        [3]     =  {[13] = 124515, [14] = 124515},        -- Hunter : Talisman of the Master Tracker
        [4]     =  {[13] = 124520, [14] = 124520},        -- Rogue : Bleeding Hollow Toxin Vessel
        [5]     =  {[13] = 124519, [14] = 124519},        -- Priest : Repudiation of War
        [6]     =  {[13] = 124513, [14] = 124513},        -- Death Knight : Reaper's Harvest
        [7]     =  {[13] = 124521, [14] = 124521},        -- Shaman : Core of the Primal Elements
        [8]     =  {[13] = 124516, [14] = 124516},        -- Mage : Tome of Shifting Words
        [9]     =  {[13] = 124522, [14] = 124522},        -- Warlock : Fragment of the Dark Star
        [10]    =  {[13] = 124517, [14] = 124517},        -- Monk : Sacred Draenic Incense
        [11]    =  {[13] = 124514, [14] = 124514},        -- Druid : Seed of Creation
        [12]    =  {[13] = 139630, [14] = 139630}        -- Demon Hunter : Etching of Sargeras
      },
      ["T19"] = {
        [0]     =  function (Count) return Count > 1, Count > 3; end,                      -- Return Function
        [1]     =  {[5] = 138351, [10] = 138354, [1] = 138357, [7] = 138360, [3] = 138363, [15] = 138374},    -- Warrior: Chest, Hands, Head, Legs, Shoulder, Back
        [2]     =  {[5] = 138350, [10] = 138353, [1] = 138356, [7] = 138359, [3] = 138362, [15] = 138369},    -- Paladin: Chest, Hands, Head, Legs, Shoulder, Back
        [3]     =  {[5] = 138339, [10] = 138340, [1] = 138342, [7] = 138344, [3] = 138347, [15] = 138368},    -- Hunter: Chest, Hands, Head, Legs, Shoulder, Back
        [4]     =  {[5] = 138326, [10] = 138329, [1] = 138332, [7] = 138335, [3] = 138338, [15] = 138371},    -- Rogue: Chest, Hands, Head, Legs, Shoulder, Back
        [5]     =  {[5] = 138319, [10] = 138310, [1] = 138313, [7] = 138316, [3] = 138322, [15] = 138370},    -- Priest: Chest, Hands, Head, Legs, Shoulder, Back
        [6]     =  {[5] = 138349, [10] = 138352, [1] = 138355, [7] = 138358, [3] = 138361, [15] = 138364},    -- Death Knight: Chest, Hands, Head, Legs, Shoulder, Back
        [7]     =  {[5] = 138346, [10] = 138341, [1] = 138343, [7] = 138345, [3] = 138348, [15] = 138372},    -- Shaman: Chest, Hands, Head, Legs, Shoulder, Back
        [8]     =  {[5] = 138318, [10] = 138309, [1] = 138312, [7] = 138315, [3] = 138321, [15] = 138365},    -- Mage: Chest, Hands, Head, Legs, Shoulder, Back
        [9]     =  {[5] = 138320, [10] = 138311, [1] = 138314, [7] = 138317, [3] = 138323, [15] = 138373},    -- Warlock: Chest, Hands, Head, Legs, Shoulder, Back
        [10]    =  {[5] = 138325, [10] = 138328, [1] = 138331, [7] = 138334, [3] = 138337, [15] = 138367},    -- Monk: Chest, Hands, Head, Legs, Shoulder, Back
        [11]    =  {[5] = 138324, [10] = 138327, [1] = 138330, [7] = 138333, [3] = 138336, [15] = 138366},    -- Druid: Chest, Hands, Head, Legs, Shoulder, Back
        [12]    =  {[5] = 138376, [10] = 138377, [1] = 138378, [7] = 138379, [3] = 138380, [15] = 138375}     -- Demon Hunter: Chest, Hands, Head, Legs, Shoulder, Back
      }
    };
    function AC.HasTier (Tier)
      -- Set Bonuses are disabled in Challenge Mode (Diff = 8) and in Proving Grounds (Map = 1148).
      local DifficultyID, _, _, _, _, MapID = select(3, GetInstanceInfo());
      if DifficultyID == 8 or MapID == 1148 then return false; end
      -- Check gear
      if HasTierSets[Tier][Cache.Persistent.Player.Class[3]] then
        local Count = 0;
        local Item;
        for Slot, ItemID in pairs(HasTierSets[Tier][Cache.Persistent.Player.Class[3]]) do
          Item = AC.Equipment[Slot];
          if Item and Item == ItemID then
            Count = Count + 1;
          end
        end
        return HasTierSets[Tier][0](Count);
      else
        return false;
      end
    end

    -- Mythic Dungeon Abilites
    local MDA = {
      PlayerBuff = {
      },
      PlayerDebuff = {
        --- Legion
          ----- Dungeons (7.0 Patch) -----
          --- Vault of the Wardens
            -- Inquisitor Tormentorum
            {Spell(200904), "Sapped Soul"}
      },
      EnemiesBuff = {
        --- Legion
          ----- Dungeons (7.0 Patch) -----
          --- Black Rook Hold
            -- Trashes
            {Spell(200291), "Blade Dance Buff"} -- Risen Scout
      },
      EnemiesCast = {
        --- Legion
          ----- Dungeons (7.0 Patch) -----
          --- Black Rook Hold
            -- Trashes
            {Spell(200291), "Blade Dance Cast"} -- Risen Scout
      },
      EnemiesDebuff = {
      }
    }
    function AC.MythicDungeon ()
      -- TODO: Optimize
      for Key, Value in pairs(MDA) do
        if Key == "PlayerBuff" then
          for i = 1, #Value do
            if Player:Buff(Value[i][1], nil, true) then
              return Value[i][2];
            end
          end
        elseif Key == "PlayerDebuff" then
          for i = 1, #Value do
            if Player:Debuff(Value[i][1], nil, true) then
              return Value[i][2];
            end
          end
        elseif Key == "EnemiesBuff" then

        elseif Key == "EnemiesCast" then

        elseif Key == "EnemiesDebuff" then

        end
      end
      return "";
    end

---- UNIT MISC

-- Fill the Enemies Cache table.
function AC.GetEnemies (Distance)
  -- Prevent building the same table if it's already cached.
  if Cache.Enemies[Distance] then return; end
  -- Init the Variables used to build the table.
  Cache.Enemies[Distance] = {};
  -- Check if there is another Enemies table with a greater Distance to filter from it.
  if #Cache.Enemies >= 1 then
    wipe(_T.DistanceValues);
    for Key, Value in pairs(Cache.Enemies) do
      if Key > Distance then
        tableinsert(_T.DistanceValues, Key);
      end
    end
    -- Check if we have caught a table that we can use.
    if #_T.DistanceValues >= 1 then
      if #_T.DistanceValues >= 2 then
        table.sort(_T.DistanceValues, function(a, b) return a < b; end);
      end
      for Key, Value in pairs(Cache.Enemies[_T.DistanceValues[1]]) do
        if Value:IsInRange(Distance) then
          tableinsert(Cache.Enemies[Distance], Value);
        end
      end
      return;
    end
  end
  -- Else build from all the nameplates.
  for i = 1, AC.MAXIMUM do
    _T.ThisUnit = Unit["Nameplate"..tostring(i)];
    if _T.ThisUnit:Exists() and
      not _T.ThisUnit:IsBlacklisted() and
      not _T.ThisUnit:IsUserBlacklisted() and
      not _T.ThisUnit:IsDeadOrGhost() and
      Player:CanAttack(_T.ThisUnit) and
      _T.ThisUnit:IsInRange(Distance) then
      tableinsert(Cache.Enemies[Distance], _T.ThisUnit);
    end
  end
  -- Cache the count of enemies
  Cache.EnemiesCount[Distance] = #Cache.Enemies[Distance];
end

--- ============== SPELL CLASS ==============

  -- Get the spell ID.
  function Spell:ID ()
    return self.SpellID;
  end

  -- Get the spell Type.
  function Spell:Type ()
    return self.SpellType;
  end

  -- Get the Time since Last spell Cast.
  function Spell:TimeSinceLastCast ()
    return AC.GetTime() - self.LastCastTime;
  end

  -- Get the Time since Last spell Display.
  function Spell:TimeSinceLastDisplay ()
    return AC.GetTime() - self.LastDisplayTime;
  end

  -- Register the spell damage formula.
  function Spell:RegisterDamage (Function)
    self.DamageFormula = Function;
  end

  -- Get the spell damage formula if it exists.
  function Spell:Damage ()
    return self.DamageFormula and self.DamageFormula() or 0;
  end

  --- WoW Specific Function
    -- Get the spell Info.
    function Spell:Info (Type, Index)
      local Identifier;
      if Type == "ID" then
        Identifier = self:ID();
      elseif Type == "Name" then
        Identifier = self:Name();
      else
        error("Spell Info Type Missing.");
      end
      if Identifier then
        if not Cache.SpellInfo[Identifier] then Cache.SpellInfo[Identifier] = {}; end
        if not Cache.SpellInfo[Identifier].Info then
          Cache.SpellInfo[Identifier].Info = {GetSpellInfo(Identifier)};
        end
        if Index then
          return Cache.SpellInfo[Identifier].Info[Index];
        else
          return unpack(Cache.SpellInfo[Identifier].Info);
        end
      else
        error("Identifier Not Found.");
      end
    end

    -- Get the spell Info from the spell ID.
    function Spell:InfoID (Index)
      return self:Info("ID", Index);
    end

    -- Get the spell Info from the spell Name.
    function Spell:InfoName (Index)
      return self:Info("Name", Index);
    end

    -- Get the spell Name.
    function Spell:Name ()
      return self:Info("ID", 1);
    end

    -- Get the spell BookIndex along with BookType.
    function Spell:BookIndex ()
      local CurrentSpellID;
      -- Pet Book
      local NumPetSpells = HasPetSpells();
      if NumPetSpells then
        for i = 1, NumPetSpells do
          CurrentSpellID = select(7, GetSpellInfo(i, BOOKTYPE_PET));
          if CurrentSpellID and CurrentSpellID == self:ID() then
            return i, BOOKTYPE_PET;
          end
        end
      end
      -- Player Book
      local Offset, NumSpells, OffSpec;
      for i = 1, GetNumSpellTabs() do
        Offset, NumSpells, _, OffSpec = select(3, GetSpellTabInfo(i));
        -- GetSpellTabInfo has been updated, it now returns the OffSpec ID.
        -- If the OffSpec ID is set to 0, then it's the Main Spec.
        if OffSpec == 0 then
          for j = 1, (Offset + NumSpells) do
            CurrentSpellID = select(7, GetSpellInfo(j, BOOKTYPE_SPELL));
            if CurrentSpellID and CurrentSpellID == self:ID() then
              return j, BOOKTYPE_SPELL;
            end
          end
        end
      end
    end

    -- Check if the spell Is Available or not.
    function Spell:IsAvailable ()
      if not Cache.SpellInfo[self.SpellID] then Cache.SpellInfo[self.SpellID] = {}; end
      if Cache.SpellInfo[self.SpellID].IsAvailable == nil then
        Cache.SpellInfo[self.SpellID].IsAvailable = IsPlayerSpell(self.SpellID);
      end
      return Cache.SpellInfo[self.SpellID].IsAvailable;
    end

    -- Check if the spell Is Known or not.
    function Spell:IsKnown (CheckPet)
      return IsSpellKnown(self.SpellID, CheckPet and CheckPet or false); 
    end

    -- Check if the spell Is Known (including Pet) or not.
    function Spell:IsPetKnown ()
      return self:IsKnown(true);
    end

    -- Check if the spell Is Usable or not.
    function Spell:IsUsable ()
      if not Cache.SpellInfo[self.SpellID] then Cache.SpellInfo[self.SpellID] = {}; end
      if Cache.SpellInfo[self.SpellID].IsUsable == nil then
        Cache.SpellInfo[self.SpellID].IsUsable = IsUsableSpell(self.SpellID);
      end
      return Cache.SpellInfo[self.SpellID].IsUsable;
    end

    -- Get the spell Minimum Range.
    function Spell:MinimumRange ()
      return self:InfoID(5);
    end

    -- Get the spell Maximum Range.
    function Spell:MaximumRange ()
      return self:InfoID(6);
    end

    -- Check if the spell Is Melee or not.
    function Spell:IsMelee ()
      return self:MinimumRange() == 0 and self:MaximumRange() == 0;
    end

    -- Scan the Book to cache every Spell Learned.
    function Spell:BookScan ()
      local CurrentSpellID, CurrentSpell;
      -- Pet Book
      local NumPetSpells = HasPetSpells();
      if NumPetSpells then
        for i = 1, NumPetSpells do
          CurrentSpellID = select(7, GetSpellInfo(i, BOOKTYPE_PET))
          if CurrentSpellID then
            CurrentSpell = Spell(CurrentSpellID);
            if CurrentSpell:IsAvailable() and (CurrentSpell:IsKnown() or IsTalentSpell(i, BOOKTYPE_PET)) then
              Cache.Persistent.SpellLearned.Pet[CurrentSpell:ID()] = true;
            end
          end
        end
      end
      -- Player Book (except Flyout Spells)
      local Offset, NumSpells, OffSpec;
      for i = 1, GetNumSpellTabs() do
        Offset, NumSpells, _, OffSpec = select(3, GetSpellTabInfo(i));
        -- GetSpellTabInfo has been updated, it now returns the OffSpec ID.
        -- If the OffSpec ID is set to 0, then it's the Main Spec.
        if OffSpec == 0 then
          for j = 1, (Offset + NumSpells) do
            CurrentSpellID = select(7, GetSpellInfo(j, BOOKTYPE_SPELL))
            if CurrentSpellID and GetSpellBookItemInfo(j, BOOKTYPE_SPELL) == "SPELL" then
              --[[ Debug Code
              CurrentSpell = Spell(CurrentSpellID);
              print(
                tostring(CurrentSpell:ID()) .. " | " .. 
                tostring(CurrentSpell:Name()) .. " | " .. 
                tostring(CurrentSpell:IsAvailable()) .. " | " .. 
                tostring(CurrentSpell:IsKnown()) .. " | " .. 
                tostring(IsTalentSpell(j, BOOKTYPE_SPELL)) .. " | " .. 
                tostring(GetSpellBookItemInfo(j, BOOKTYPE_SPELL)) .. " | " .. 
                tostring(GetSpellLevelLearned(CurrentSpell:ID()))
              );
              ]]
              Cache.Persistent.SpellLearned.Player[CurrentSpellID] = true;
            end
          end
        end
      end
      -- Flyout Spells
      local FlyoutID, NumSlots, IsKnown, IsKnownSpell;
      for i = 1, GetNumFlyouts() do
        FlyoutID = GetFlyoutID(i);
        NumSlots, IsKnown = select(3, GetFlyoutInfo(FlyoutID));
        if IsKnown and NumSlots > 0 then
          for j = 1, NumSlots do
            CurrentSpellID, _, IsKnownSpell = GetFlyoutSlotInfo(FlyoutID, j);
            if CurrentSpellID and IsKnownSpell then
              Cache.Persistent.SpellLearned.Player[CurrentSpellID] = true;
            end
          end
        end
      end
    end

    -- Check if the spell is in the Spell Learned Cache.
    function Spell:IsLearned ()
      return Cache.Persistent.SpellLearned[self:Type()][self:ID()] or false;
    end

    -- Check if the spell Is Castable or not.
    function Spell:IsCastable ()
      return self:IsLearned() and not self:IsOnCooldown();
    end

    --- Artifact Traits Scan
    -- Fills the PowerTable with every traits informations.
    local ArtifactUI, HasArtifactEquipped  = _G.C_ArtifactUI, _G.HasArtifactEquipped;
    local ArtifactFrame = _G.ArtifactFrame;
    local PowerTable, Powers = {}, {};
    --- PowerTable Schema :
    --   1    2      3       4      5     6  7    8       9      10      11
    -- SpellID, Cost, CurrentRank, MaxRank, BonusRanks, x, y, PreReqsMet, IsStart, IsGoldMedal, IsFinal
    function Spell:ArtifactScan ()
      ArtifactFrame = _G.ArtifactFrame;
      -- Does the scan only if the Artifact is Equipped and the Frame not Opened.
      if HasArtifactEquipped() and not (ArtifactFrame and ArtifactFrame:IsShown()) then
        -- Unregister the events to prevent unwanted call.
        UIParent:UnregisterEvent("ARTIFACT_UPDATE");
        SocketInventoryItem(INVSLOT_MAINHAND);
        Powers = ArtifactUI.GetPowers();
        if Powers then
          wipe(PowerTable);
          for Index, Power in pairs(Powers) do
            tableinsert(PowerTable, {ArtifactUI.GetPowerInfo(Power)});
          end
        end
        ArtifactUI.Clear();
        -- Register back the event.
        UIParent:RegisterEvent("ARTIFACT_UPDATE");
      end
    end

  --- Simulationcraft Aliases
    -- action.foo.cast_time
    function Spell:CastTime ()
      if not self:InfoID(4) then 
        return 0;
      else
        return self:InfoID(4)/1000;
      end
    end

    -- action.foo.charges or cooldown.foo.charges
    function Spell:Charges ()
      if not Cache.SpellInfo[self.SpellID] then Cache.SpellInfo[self.SpellID] = {}; end
      if not Cache.SpellInfo[self.SpellID].Charges then
        Cache.SpellInfo[self.SpellID].Charges = {GetSpellCharges(self.SpellID)};
      end
      return unpack(Cache.SpellInfo[self.SpellID].Charges);
    end

    -- action.foo.recharge_time or cooldown.foo.recharge_time
    function Spell:Recharge ()
      if not Cache.SpellInfo[self.SpellID] then Cache.SpellInfo[self.SpellID] = {}; end
      if not Cache.SpellInfo[self.SpellID].Recharge then
        -- Get Spell Recharge Infos
        _T.Charges, _T.MaxCharges, _T.CDTime, _T.CDValue = self:Charges();
        -- Return 0 if the Spell isn't in CD.
        if _T.Charges == _T.MaxCharges then
          return 0;
        end
        -- Compute the CD.
        _T.CD = _T.CDTime + _T.CDValue - AC.GetTime() - AC.RecoveryOffset();
        -- Return the Spell CD
        Cache.SpellInfo[self.SpellID].Recharge = _T.CD > 0 and _T.CD or 0;
      end
      return Cache.SpellInfo[self.SpellID].Recharge;
    end

    -- action.foo.charges_fractional or cooldown.foo.charges_fractional
    -- TODO : Changes function to avoid using the cache directly
    function Spell:ChargesFractional ()
      if not Cache.SpellInfo[self.SpellID] then Cache.SpellInfo[self.SpellID] = {}; end
      if not Cache.SpellInfo[self.SpellID].ChargesFractional then
        self:Charges(); -- Cache the charges infos to use the cache directly after. 
        if Cache.SpellInfo[self.SpellID].Charges[1] == Cache.SpellInfo[self.SpellID].Charges[2] then
          Cache.SpellInfo[self.SpellID].ChargesFractional = Cache.SpellInfo[self.SpellID].Charges[1];
        else
          Cache.SpellInfo[self.SpellID].ChargesFractional = Cache.SpellInfo[self.SpellID].Charges[1] + (Cache.SpellInfo[self.SpellID].Charges[4]-self:Recharge())/Cache.SpellInfo[self.SpellID].Charges[4];
        end
      end
      return Cache.SpellInfo[self.SpellID].ChargesFractional;
    end

    -- cooldown.foo.remains
    -- TODO: Swap Cooldown() to CooldownRemains() and then make a Cooldown() for cooldown.foo.up (and keep IsOnCooldown() for !cooldown.foo.up)
    function Spell:Cooldown (BypassRecovery)
      if not Cache.SpellInfo[self.SpellID] then Cache.SpellInfo[self.SpellID] = {}; end
      if (not BypassRecovery and not Cache.SpellInfo[self.SpellID].Cooldown) or (BypassRecovery and not Cache.SpellInfo[self.SpellID].CooldownNoRecovery) then
        -- Get Spell Cooldown Infos
        _T.CDTime, _T.CDValue = GetSpellCooldown(self.SpellID);
        -- Return 0 if the Spell isn't in CD.
        if _T.CDTime == 0 then
          return 0;
        end
        -- Compute the CD.
        _T.CD = _T.CDTime + _T.CDValue - AC.GetTime() - (BypassRecovery and 0 or AC.RecoveryOffset());
        if BypassRecovery then
          -- Return the Spell CD
          Cache.SpellInfo[self.SpellID].CooldownNoRecovery = _T.CD > 0 and _T.CD or 0;
        else
          -- Return the Spell CD
          Cache.SpellInfo[self.SpellID].Cooldown = _T.CD > 0 and _T.CD or 0;
        end
      end
      return BypassRecovery and Cache.SpellInfo[self.SpellID].CooldownNoRecovery or Cache.SpellInfo[self.SpellID].Cooldown;
    end

    -- !cooldown.foo.up
    function Spell:IsOnCooldown (BypassRecovery)
      return self:Cooldown(BypassRecovery) ~= 0;
    end

    -- artifact.foo.rank
    function Spell:ArtifactRank ()
      if #PowerTable > 0 then
        for Index, Table in pairs(PowerTable) do
          if self.SpellID == Table[1] and Table[3] > 0 then
            return Table[3];
          end
        end
      end
      return 0;
    end

    -- artifact.foo.enabled
    function Spell:ArtifactEnabled ()
      return self:ArtifactRank() > 0;
    end

--- ============== ITEM CLASS ==============

  -- Inventory slots
  -- INVSLOT_HEAD       = 1;
  -- INVSLOT_NECK       = 2;
  -- INVSLOT_SHOULDAC   = 3;
  -- INVSLOT_BODY       = 4;
  -- INVSLOT_CHEST      = 5;
  -- INVSLOT_WAIST      = 6;
  -- INVSLOT_LEGS       = 7;
  -- INVSLOT_FEET       = 8;
  -- INVSLOT_WRIST      = 9;
  -- INVSLOT_HAND       = 10;
  -- INVSLOT_FINGAC1    = 11;
  -- INVSLOT_FINGAC2    = 12;
  -- INVSLOT_TRINKET1   = 13;
  -- INVSLOT_TRINKET2   = 14;
  -- INVSLOT_BACK       = 15;
  -- INVSLOT_MAINHAND   = 16;
  -- INVSLOT_OFFHAND    = 17;
  -- INVSLOT_RANGED     = 18;
  -- INVSLOT_TABARD     = 19;
  -- Check if a given item is currently equipped in the given slot.
  function Item:IsEquipped (Slot)
    if not Cache.ItemInfo[self.ItemID] then Cache.ItemInfo[self.ItemID] = {}; end
    if Cache.ItemInfo[self.ItemID].IsEquipped == nil then
      Cache.ItemInfo[self.ItemID].IsEquipped = AC.Equipment[Slot] == self.ItemID and true or false;
    end
    return Cache.ItemInfo[self.ItemID].IsEquipped;  
  end

  -- Get the item Last Cast Time.
  function Item:LastCastTime ()
    return self.LastCastTime;
  end

--- ============== MISC FUNCTIONS ==============

-- Get the Latency (it's updated every 30s).
-- TODO: Cache it in Persistent Cache and update it only when it changes
function AC.Latency ()
  return select(4, GetNetStats());
end

-- Retrieve the Recovery Timer based on Settings.
-- TODO: Optimize, to see how we'll implement it in the GUI.
function AC.RecoveryTimer ()
  return AC.GUISettings.General.RecoveryMode == "GCD" and Player:GCDRemains()*1000 or AC.GUISettings.General.RecoveryTimer;
end

-- Compute the Recovery Offset with Lag Compensation.
function AC.RecoveryOffset ()
  return (AC.Latency() + AC.RecoveryTimer())/1000;
end

-- Get the time since combat has started.
function AC.CombatTime ()
  return AC.CombatStarted ~= 0 and AC.GetTime()-AC.CombatStarted or 0;
end

-- Get the time since combat has ended.
function AC.OutOfCombatTime ()
  return AC.CombatEnded ~= 0 and AC.GetTime()-AC.CombatEnded or 0;
end

-- Get the Boss Mod Pull Timer.
function AC.BMPullTime ()
  if not AC.BossModTime or AC.BossModTime == 0 or AC.BossModEndTime-AC.GetTime() < 0 then
    return 60;
  else
    return AC.BossModEndTime-AC.GetTime();
  end
end

AC.SpecID_ClassesSpecs = {
-- Death Knight
  [250]   = {"DeathKnight", "Blood"},
  [251]   = {"DeathKnight", "Frost"},
  [252]   = {"DeathKnight", "Unholy"},
-- Demon Hunter
  [577]   = {"DemonHunter", "Havoc"},
  [581]   = {"DemonHunter", "Vengeance"};
-- Druid
  [102]   = {"Druid", "Balance"},
  [103]   = {"Druid", "Feral"},
  [104]   = {"Druid", "Guardian"},
  [105]   = {"Druid", "Restoration"},
-- Hunter
  [253]   = {"Hunter", "Beast Mastery"},
  [254]   = {"Hunter", "Marksmanship"},
  [255]   = {"Hunter", "Survival"},
-- Mage
  [62]    = {"Mage", "Arcane"},
  [63]    = {"Mage", "Fire"},
  [64]    = {"Mage", "Frost"},
-- Monk
  [268]   = {"Monk", "Brewmaster"},
  [269]   = {"Monk", "Windwalker"},
  [270]   = {"Monk", "Mistweaver"},
-- Paladin
  [65]    = {"Paladin", "Holy"},
  [66]    = {"Paladin", "Protection"},
  [70]    = {"Paladin", "Retribution"},
-- Priest
  [256]   = {"Priest", "Discipline"},
  [257]   = {"Priest", "Holy"},
  [258]   = {"Priest", "Shadow"},
-- Rogue
  [259]   = {"Rogue", "Assassination"},
  [260]   = {"Rogue", "Outlaw"},
  [261]   = {"Rogue", "Subtlety"},
-- Shaman
  [262]   = {"Shaman", "Elemental"},
  [263]   = {"Shaman", "Enhancement"},
  [264]   = {"Shaman", "Restoration"},
-- Warlock
  [265]   = {"Warlock", "Affliction"},
  [266]   = {"Warlock", "Demonology"},
  [267]   = {"Warlock", "Destruction"},
-- Warrior
  [71]    = {"Warrior", "Arms"},
  [72]    = {"Warrior", "Fury"},
  [73]    = {"Warrior", "Protection"}
};