--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local _, NAG        = ...
NAG.HL              = NAG.HL or {}
local HL            = NAG.HL
HL.Utils            = NAG.Utils or {}

--- ============================ CONTENT ============================

local function _GetBuildInfo()
  local _, _, _, tocversion = GetBuildInfo()
  return tocversion
end

function HL.isRetail()
  return select(4,GetBuildInfo()) >= 100000
end
function HL.isEra()
  return select(4,GetBuildInfo()) < 20000
end

function HL.isClassic()
  local build = select(4,GetBuildInfo())
  return build >= 20000 and build < 50000
end

function HL.isTBC()
  local build = select(4,GetBuildInfo())
  return build >= 20000 and build < 30000
end

function HL.isWotLK()
  local build = select(4,GetBuildInfo())
  return build >= 30000 and build < 40000
end

function HL.isCata()
  local build = select(4,GetBuildInfo())
  return build >= 40000 and build < 50000
end

HL.VERSION = GetAddOnMetadata(select(1, ...), "Version")

HL.IS_CLASSIC_ERA = WOW_PROJECT_ID == WOW_PROJECT_CLASSIC
HL.IS_CLASSIC_ERA_SOD = HL.IS_CLASSIC_ERA and C_Engraving.IsEngravingEnabled()
HL.IS_CLASSIC_WRATH = WOW_PROJECT_ID == WOW_PROJECT_WRATH_CLASSIC
HL.IS_CLASSIC_CATA = WOW_PROJECT_ID == WOW_PROJECT_CATACLYSM_CLASSIC
HL.IS_CLIENT_SUPPORTED = HL.IS_CLASSIC_ERA_SOD or HL.IS_CLASSIC_WRATH or HL.IS_CLASSIC_CATA