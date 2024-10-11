--- ============================ HEADER ============================
--- ======= LOCALIZE =======
-- Addon
local addonName, NAG          = ...
local HL                      = NAG.HL

--- ============================ CONTENT ============================

local function _GetBuildInfo()
  local _, _, _, tocversion = GetBuildInfo()
  return tocversion
end

function HL.isRetail()
  return select(4,GetBuildInfo()) >= 100000
end

function HL.isClassic()
  return select(4,GetBuildInfo()) < 20000
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
