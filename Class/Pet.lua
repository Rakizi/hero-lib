--- ============================ HEADER ============================
--- ======= LOCALIZE =======
  -- Addon
  local addonName, AC = ...;
  -- AethysCore
  local Cache = AethysCore_Cache;
  local Unit = AC.Unit;
  local Player = Unit.Player;
  local Pet = Unit.Pet;
  local Target = Unit.Target;
  local Spell = AC.Spell;
  local Item = AC.Item;
  -- Lua
  -- File Locals
  


--- ============================ CONTENT ============================
  -- Get if there is a pet currently active or not
  -- TODO: Cache
  function Unit:IsActive ()
    return IsPetActive();
  end
