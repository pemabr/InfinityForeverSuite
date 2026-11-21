local addonName = "TrokkosGatherMate2FilterHelper"
local savedVarName = "TrokkosGatherMate2HelperDB"
local GetNumSkillLines = _G.GetNumSkillLines
local GetSkillLineInfo = _G.GetSkillLineInfo

local herb_data = {
  -- Classic
  ["Peacebloom"] = {min = 1, gray = 75},
  ["Wilted Peacebloom"] = {min = 1, gray = 75},
  ["Silverleaf"] = {min = 1, gray = 75},
  ["Stunted Silverleaf"] = {min = 1, gray = 75},
  ["Earthroot"] = {min = 15, gray = 95},
  ["Mageroyal"] = {min = 50, gray = 115},
  ["Briarthorn"] = {min = 70, gray = 125},
  ["Stranglekelp"] = {min = 85, gray = 145},
  ["Bruiseweed"] = {min = 85, gray = 135},
  ["Grave Moss"] = {min = 105, gray = 170},
  ["Wild Steelbloom"] = {min = 115, gray = 165},
  ["Kingsblood"] = {min = 125, gray = 175},
  ["Liferoot"] = {min = 150, gray = 200},
  ["Fadeleaf"] = {min = 160, gray = 210},
  ["Goldthorn"] = {min = 170, gray = 220},
  ["Khadgar's Whisker"] = {min = 185, gray = 235},
  ["Wintersbite"] = {min = 195, gray = 245},
  ["Firebloom"] = {min = 205, gray = 255},
  ["Purple Lotus"] = {min = 210, gray = 255},
  ["Arthas' Tears"] = {min = 220, gray = 270},
  ["Sungrass"] = {min = 230, gray = 280},
  ["Blindweed"] = {min = 235, gray = 285},
  ["Ghost Mushroom"] = {min = 245, gray = 295},
  ["Gromsblood"] = {min = 250, gray = 300},
  ["Golden Sansam"] = {min = 260, gray = 310},
  ["Dreamfoil"] = {min = 270, gray = 320},
  ["Mountain Silversage"] = {min = 280, gray = 330},
  ["Plaguebloom"] = {min = 285, gray = 335},
  ["Icecap"] = {min = 290, gray = 340},
  ["Black Lotus"] = {min = 300, gray = 350},
  -- The Burning Crusade
  ["Felweed"] = {min = 300, gray = 375},
  ["Dreaming Glory"] = {min = 315, gray = 375},
  ["Ragveil"] = {min = 325, gray = 375},
  ["Terocone"] = {min = 325, gray = 375},
  ["Ancient Lichen"] = {min = 340, gray = 360},
  ["Netherbloom"] = {min = 350, gray = 415},
  ["Nightmare Vine"] = {min = 365, gray = 415},
  ["Mana Thistle"] = {min = 375, gray = 425},
  -- Wrath of the Lich King
  ["Goldclover"] = {min = 350, gray = 400},
  ["Tiger Lily"] = {min = 375, gray = 450},
  ["Talandra's Rose"] = {min = 385, gray = 450},
  ["Adder's Tongue"] = {min = 400, gray = 475},
  ["Lichbloom"] = {min = 425, gray = 475},
  ["Icethorn"] = {min = 435, gray = 475},
  ["Frost Lotus"] = {min = 450, gray = 500},
  -- Cataclysm
  ["Cinderbloom"] = {min = 425, gray = 525},
  ["Azshara's Veil"] = {min = 425, gray = 525},
  ["Heartblossom"] = {min = 475, gray = 550},
  ["Stormvine"] = {min = 475, gray = 550},
  ["Whiptail"] = {min = 500, gray = 575},
  ["Twilight Jasmine"] = {min = 525, gray = 600},
  -- Mists of Pandaria
  ["Green Tea Leaf"] = {min = 500, gray = 600},
  ["Rain Poppy"] = {min = 525, gray = 625},
  ["Silkweed"] = {min = 545, gray = 650},
  ["Golden Lotus"] = {min = 550, gray = 650},
  ["Snow Lily"] = {min = 575, gray = 675},
  ["Fool's Cap"] = {min = 600, gray = 700},
}

local mining_data = {
  -- Classic
  ["Copper Vein"] = {min = 1, gray = 50},
  ["Tin Vein"] = {min = 65, gray = 115},
  ["Silver Vein"] = {min = 75, gray = 125},
  ["Iron Deposit"] = {min = 125, gray = 175},
  ["Gold Vein"] = {min = 155, gray = 205},
  ["Mithril Deposit"] = {min = 175, gray = 230},
  ["Truesilver Deposit"] = {min = 230, gray = 285},
  ["Small Thorium Vein"] = {min = 245, gray = 300},
  ["Rich Thorium Vein"] = {min = 275, gray = 330},
  ["Dark Iron Deposit"] = {min = 230, gray = 300},
  -- The Burning Crusade
  ["Fel Iron Deposit"] = {min = 300, gray = 460},
  ["Adamantite Deposit"] = {min = 325, gray = 425},
  ["Rich Adamantite Deposit"] = {min = 350, gray = 425},
  ["Khorium Vein"] = {min = 375, gray = 425},
  -- Wrath of the Lich King
  ["Cobalt Deposit"] = {min = 350, gray = 450},
  ["Rich Cobalt Deposit"] = {min = 375, gray = 475},
  ["Saronite Deposit"] = {min = 400, gray = 500},
  ["Rich Saronite Deposit"] = {min = 425, gray = 525},
  ["Titanium Vein"] = {min = 450, gray = 550},
  -- Cataclysm
  ["Obsidium Deposit"] = {min = 425, gray = 525},
  ["Rich Obsidium Deposit"] = {min = 450, gray = 550},
  ["Elementium Vein"] = {min = 475, gray = 575},
  ["Rich Elementium Vein"] = {min = 500, gray = 600},
  ["Pyrite Deposit"] = {min = 525, gray = 625},
  ["Rich Pyrite Deposit"] = {min = 550, gray = 650},
  -- Mists of Pandaria
  ["Ghost Iron Deposit"] = {min = 500, gray = 600},
  ["Rich Ghost Iron Deposit"] = {min = 550, gray = 650},
  ["Kyparite Deposit"] = {min = 575, gray = 675},
  ["Rich Kyparite Deposit"] = {min = 600, gray = 700},
  ["Trillium Vein"] = {min = 600, gray = 700},
  ["Black Trillium Vein"] = {min = 600, gray = 700},
  ["White Trillium Vein"] = {min = 600, gray = 700},
}

local frame = CreateFrame("Frame")
local GetGatherMate

local function GetAddonDB()
  if type(_G[savedVarName]) ~= "table" then
    _G[savedVarName] = {}
  end

  local db = _G[savedVarName]
  db.autoState = db.autoState or {}
  return db
end

local function normalizeNodeName(name)
  if not name then return "" end
  name = name:lower()
  name = name:gsub("['\"]", "")
  name = name:gsub("[^%w]", " ")
  name = name:gsub("%s+", " "):match("^%s*(.-)%s*$") or name
  return name
end

local function GetProfessionSkill(keyword)
  if GetProfessions and GetProfessionInfo then
    local profs = {GetProfessions()}
    for _, pid in ipairs(profs) do
      if pid then
        local name, _, rank = GetProfessionInfo(pid)
        if name and rank then
          local lname = name:lower()
          if lname:find(keyword) or lname == keyword then
            return rank
          end
        end
      end
    end
  elseif GetProfessionInfo then
    for i = 1, 4 do
      local ok, name, _, rank = pcall(GetProfessionInfo, i)
      if ok and name and rank then
        local lname = name:lower()
        if lname:find(keyword) or lname == keyword then
          return rank
        end
      end
    end
  end

  if GetNumSkillLines and GetSkillLineInfo then
    local num = GetNumSkillLines()
    for i = 1, num do
      local info = {GetSkillLineInfo(i)}
      local name = info[1]
      local isHeader = info[2]
      if name and not isHeader then
        local lname = name:lower()
        if lname:find(keyword) or lname == keyword then
          local nums = {}
          for k = 3, #info do
            if type(info[k]) == "number" then
              tinsert(nums, info[k])
            end
          end
          for _, value in ipairs(nums) do
            if value > 0 then
              return value
            end
          end
          if #nums > 0 then return nums[1] end
        end
      end
    end
  end

  return nil
end

local function UpdateCategoryFilters(category, skill, sourceData)
  local gm = GetGatherMate()
  if not gm or not gm.db or not gm.db.profile or not skill then return end

  local db = gm.db.profile
  db.filter = db.filter or {}
  db.filter[category] = db.filter[category] or {}

  local nodeMap = gm.nodeIDs and gm.nodeIDs[category]
  if not nodeMap then return end

  local addonDB = GetAddonDB()
  addonDB.autoState[category] = addonDB.autoState[category] or {}
  local autoState = addonDB.autoState[category]

  local lookup = {}
  for name, info in pairs(sourceData) do
    lookup[normalizeNodeName(name)] = info
  end

  local changed = false
  for nodeName, nodeID in pairs(nodeMap) do
    local info = lookup[normalizeNodeName(nodeName)]
    if info then
      local desired = not (skill < info.min or skill >= info.gray)
      local current = db.filter[category][nodeID]
      local previousAuto = autoState[nodeID]

      if previousAuto == nil then
        if current == nil or current == desired then
          if current ~= desired then
            db.filter[category][nodeID] = desired
            changed = true
          end
        end
        autoState[nodeID] = desired
      elseif current == previousAuto then
        if current ~= desired then
          db.filter[category][nodeID] = desired
          changed = true
        end
        autoState[nodeID] = desired
      end
    end
  end

  if changed and gm.SendMessage then
    gm:SendMessage("GatherMate2ConfigChanged")
  end
end

local function GetHerbalismSkill()
  return GetProfessionSkill("herbal")
end

GetGatherMate = function()
  if _G and _G["GatherMate2"] then return _G["GatherMate2"] end
  if LibStub then
    local ok, gm = pcall(function() return LibStub("AceAddon-3.0"):GetAddon("GatherMate2") end)
    if ok then return gm end
  end
  return nil
end

local function UpdateHerbFilters()
  local skill = GetHerbalismSkill()
  UpdateCategoryFilters("Herb Gathering", skill, herb_data)
end

local function UpdateMiningFilters()
  local skill = GetProfessionSkill("mining")
  UpdateCategoryFilters("Mining", skill, mining_data)
end

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("SKILL_LINES_CHANGED")
frame:SetScript("OnEvent", function(self, event, arg1, ...)
  if event == "ADDON_LOADED" then
    if arg1 == "GatherMate2" then
      UpdateHerbFilters()
      UpdateMiningFilters()
    end
  else
    UpdateHerbFilters()
    UpdateMiningFilters()
  end
end)

SLASH_TROKOSGM1 = "/trokkosgm"
SlashCmdList["TROKKOSGM"] = function(msg)
  UpdateHerbFilters()
  UpdateMiningFilters()
  print("TrokkosGatherMate2Helper: updated herb and mining filters based on current skill.")
end