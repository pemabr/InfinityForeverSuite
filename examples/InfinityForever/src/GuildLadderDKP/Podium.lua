local ADDON, D = ...
local Print = D.Print

--[[
  v1.5.0 PODIUM, part 2: the awards screen.
  U.Show(screen) with screen = { title, summary, picks = {5 awards, first = headline}, extra = {up to 2},
  preview (officer reviewing, not shared yet), test, onReroll, onPost }.
  Each pick = { code, name, class, award, kind ("pos"/"roast"), flavor, text }.
  Full screen, no art files: colour gradients, the winners' own 3D models (PlayerModel on their unit
  when they are in range) and the class icon when a model can't load.
]]

local U = {}
D.Podium = U

local TITLE_FONT = "Fonts\\MORPHEUS.TTF"
local GOLD = { 0.878, 0.69, 0.31 }

local function Short(n) return n and (tostring(n):gsub("%-.*$", "")) end

-- animation ids are guesses until tried in game: /dkp podium anim <id> plays one on every model
local ANIM_DEFAULT = { head = { 68 }, pos = { 68, 80, 82 }, roast = { 77, 83, 79 } }
local CAM_DEFAULT = { scale = 1.25, z = -0.05 }

local function Settings() D.settings = D.settings or {}; return D.settings end
local function Anims(group)
  local s = Settings().podiumAnims
  local l = s and s[group]
  if type(l) == "table" and #l > 0 then return l end
  return ANIM_DEFAULT[group]
end
local function Cam()
  local c = Settings().podiumCam
  if type(c) == "table" then return { scale = tonumber(c.scale) or CAM_DEFAULT.scale, z = tonumber(c.z) or CAM_DEFAULT.z } end
  return CAM_DEFAULT
end

---------------------------------------------------------------------------
-- small helpers
---------------------------------------------------------------------------
local function Grad(tex, r1, g1, b1, a1, r2, g2, b2, a2) -- colour 1 on top, colour 2 at the bottom
  tex:SetColorTexture(1, 1, 1, 1)
  if tex.SetGradient and CreateColor then
    local ok = pcall(tex.SetGradient, tex, "VERTICAL", CreateColor(r2, g2, b2, a2), CreateColor(r1, g1, b1, a1))
    if ok then return end
  end
  if tex.SetGradientAlpha then
    if pcall(tex.SetGradientAlpha, tex, "VERTICAL", r2, g2, b2, a2, r1, g1, b1, a1) then return end
  end
  tex:SetColorTexture(r1, g1, b1, a1)
end

local function Text(parent, size, r, g, b, font, layer)
  local fs = parent:CreateFontString(nil, layer or "OVERLAY")
  fs:SetFont(font or "Fonts\\FRIZQT__.TTF", size, "")
  fs:SetTextColor(r or 1, g or 1, b or 1)
  return fs
end

local function ClassColor(class)
  local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
  if c then return c.r, c.g, c.b end
  return 0.9, 0.9, 0.9
end

local function FindUnit(name)
  local s = Short(name)
  if UnitName("player") == s then return "player" end
  if IsInRaid and IsInRaid() then
    for i = 1, GetNumGroupMembers() do
      local u = "raid" .. i
      if UnitExists(u) and UnitName(u) == s then return u end
    end
  elseif IsInGroup and IsInGroup() then
    for i = 1, 4 do
      local u = "party" .. i
      if UnitExists(u) and UnitName(u) == s then return u end
    end
  end
  return nil
end

-- card colours: the headline is gold, good awards cool colours, roasts pink / olive
local POS = { { 0.10, 0.42, 0.55 }, { 0.32, 0.28, 0.66 }, { 0.50, 0.40, 0.12 }, { 0.22, 0.48, 0.28 } }
local ROAST = { { 0.58, 0.18, 0.42 }, { 0.46, 0.44, 0.14 } }
local function Palette(pick, big)
  if big then return { 0.86, 0.68, 0.22 }, { 1, 0.82, 0.30 } end
  local list = pick.kind == "roast" and ROAST or POS
  local h = 0
  for i = 1, #pick.code do h = h + pick.code:byte(i) end
  local c = list[(h % #list) + 1]
  if pick.kind == "roast" then return c, { 1, 0.35, 0.65 } end
  return c, { 0.35, 0.82, 1 }
end

---------------------------------------------------------------------------
-- the frame
---------------------------------------------------------------------------
local win
local ORDER = { 2, 3, 1, 4, 5 } -- left to right; pick 1 (the headline) in the middle

local function MakeButton(parent, label, w)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(w or 150, 30)
  local bg = b:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(0.06, 0.09, 0.13, 0.95)
  local line = b:CreateTexture(nil, "BORDER"); line:SetPoint("BOTTOMLEFT"); line:SetPoint("BOTTOMRIGHT"); line:SetHeight(2)
  line:SetColorTexture(0.16, 0.55, 0.72, 1)
  b.label = Text(b, 12, 0.42, 0.82, 1)
  b.label:SetPoint("CENTER"); b.label:SetText(label)
  b:SetScript("OnEnter", function() bg:SetColorTexture(0.1, 0.16, 0.22, 1) end)
  b:SetScript("OnLeave", function() bg:SetColorTexture(0.06, 0.09, 0.13, 0.95) end)
  return b
end

local function MakeCard(stage, slot)
  local big = slot == 3
  local w, mh, ph = big and 250 or 200, big and 350 or 310, big and 140 or 130 -- v1.5.1: centre card 30 px shorter so it clears the header
  local c = { big = big, w = w, mh = mh, ph = ph }
  local f = CreateFrame("Frame", nil, stage)
  f:SetSize(w, mh + ph)
  c.frame = f
  c.bg = f:CreateTexture(nil, "BACKGROUND"); c.bg:SetPoint("TOPLEFT"); c.bg:SetPoint("TOPRIGHT"); c.bg:SetHeight(mh)
  c.icon = f:CreateTexture(nil, "ARTWORK"); c.icon:SetSize(88, 88); c.icon:SetPoint("CENTER", c.bg, "CENTER", 0, 10)
  c.model = CreateFrame("PlayerModel", nil, f)
  c.model:SetPoint("TOPLEFT"); c.model:SetSize(w, mh)
  -- v1.6.0: the award's medallion in the card's top-left corner. Its own frame, above the 3D model
  -- (a texture on the card itself would be drawn underneath the model).
  c.seal = CreateFrame("Frame", nil, f)
  local sz = big and 70 or 56
  c.seal:SetSize(sz, sz); c.seal:SetPoint("TOPLEFT", 8, -8)
  c.seal:SetFrameLevel(c.model:GetFrameLevel() + 5)
  c.sealTex = c.seal:CreateTexture(nil, "OVERLAY"); c.sealTex:SetAllPoints()
  local panel = f:CreateTexture(nil, "BACKGROUND")
  panel:SetPoint("BOTTOMLEFT"); panel:SetPoint("BOTTOMRIGHT"); panel:SetHeight(ph)
  panel:SetColorTexture(0.05, 0.06, 0.09, 0.96)
  c.top = f:CreateTexture(nil, "BORDER"); c.top:SetPoint("BOTTOMLEFT", panel, "TOPLEFT"); c.top:SetPoint("BOTTOMRIGHT", panel, "TOPRIGHT")
  c.top:SetHeight(3)
  c.kind = Text(f, 9, 1, 1, 1); c.kind:SetPoint("TOP", panel, "TOP", 0, -8)
  c.award = Text(f, big and 24 or 19, 1, 1, 1, TITLE_FONT); c.award:SetPoint("TOP", panel, "TOP", 0, -20)
  c.who = Text(f, big and 15 or 14, 1, 1, 1); c.who:SetPoint("TOP", panel, "TOP", 0, big and -50 or -46)
  c.flavor = Text(f, 10, 0.72, 0.74, 0.78); c.flavor:SetPoint("TOP", panel, "TOP", 0, big and -70 or -65)
  c.flavor:SetWidth(w - 16); c.flavor:SetHeight(26); c.flavor:SetJustifyV("TOP"); c.flavor:SetWordWrap(true)
  c.pill = f:CreateTexture(nil, "ARTWORK"); c.pill:SetPoint("BOTTOM", panel, "BOTTOM", 0, 9); c.pill:SetSize(w - 24, 22)
  c.stat = Text(f, 11, 1, 1, 1); c.stat:SetPoint("CENTER", c.pill, "CENTER")
  return c
end

local function Build()
  local f = CreateFrame("Frame", "GuildLadderDKPPodium", UIParent)
  f:SetAllPoints(UIParent)
  f:SetFrameStrata("FULLSCREEN_DIALOG")
  f:EnableMouse(true)
  f:Hide()
  local dim = f:CreateTexture(nil, "BACKGROUND"); dim:SetAllPoints(); dim:SetColorTexture(0.01, 0.01, 0.05, 0.88)
  local stage = CreateFrame("Frame", nil, f)
  stage:SetSize(1140, 720); stage:SetPoint("CENTER")
  f.stage = stage
  f.kicker = Text(stage, 13, GOLD[1], GOLD[2], GOLD[3]); f.kicker:SetPoint("TOP", 0, -14)
  f.title = Text(stage, 40, 0.96, 0.94, 0.9, TITLE_FONT); f.title:SetPoint("TOP", 0, -34)
  local rule = stage:CreateTexture(nil, "ARTWORK"); rule:SetSize(420, 2); rule:SetPoint("TOP", 0, -84); rule:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.8)
  f.summary = Text(stage, 13, 0.75, 0.78, 0.84); f.summary:SetPoint("TOP", 0, -94)
  f.banner = Text(stage, 12, 0.95, 0.65, 0.29); f.banner:SetPoint("TOP", 0, -112)
  f.tag = Text(f, 12, 0.85, 0.88, 0.95); f.tag:SetPoint("TOPRIGHT", -24, -18)
  f.cards = {}
  local x = 0
  for pos = 1, 5 do
    local slot = pos
    local c = MakeCard(stage, slot)
    c.frame:SetPoint("BOTTOMLEFT", stage, "BOTTOMLEFT", 0, 90)
    f.cards[pos] = c
  end
  -- left to right: 200, 200, 250, 200, 200 with 16 px gaps
  local total, xs = 0, {}
  for pos = 1, 5 do xs[pos] = total; total = total + f.cards[pos].w + 16 end
  total = total - 16
  local start = (1140 - total) / 2
  for pos = 1, 5 do
    f.cards[pos].frame:ClearAllPoints()
    f.cards[pos].frame:SetPoint("BOTTOMLEFT", stage, "BOTTOMLEFT", start + xs[pos], 92)
  end
  f.mentions = Text(stage, 11, 0.75, 0.78, 0.84); f.mentions:SetPoint("BOTTOM", 0, 62); f.mentions:SetWidth(1100)
  f.btns = {}
  f.btns.reroll = MakeButton(stage, "REROLL", 130)
  f.btns.post = MakeButton(stage, "SHARE TO RAID", 170)
  f.btns.send = MakeButton(stage, "SEND TO PARTY", 170)
  f.btns.close = MakeButton(stage, "CLOSE", 130)
  f.btns.close:SetScript("OnClick", function() f:Hide() end)
  f:SetScript("OnHide", function(self) if type(self.ticker) == "table" then self.ticker:Cancel(); self.ticker = nil end end)
  tinsert(UISpecialFrames, "GuildLadderDKPPodium")
  return f
end

local function Layout(f, list)
  local gap, total = 12, 0
  for _, b in ipairs(list) do total = total + b:GetWidth() + gap end
  total = total - gap
  local x = -total / 2
  for _, key in ipairs({ "reroll", "post", "send", "close" }) do f.btns[key]:Hide() end
  for _, b in ipairs(list) do
    b:ClearAllPoints()
    b:SetPoint("BOTTOMLEFT", f.stage, "BOTTOM", x, 18)
    b:Show()
    x = x + b:GetWidth() + gap
  end
end

function U.TextFor(screen)
  local parts = {}
  for _, p in ipairs(screen.picks) do parts[#parts + 1] = ("%s: %s (%s)"):format(p.award, p.name, p.text) end
  local s = ("Raid awards, %s - %s"):format(screen.title or "tonight", table.concat(parts, "; "))
  return s:sub(1, 250)
end

local function ApplyModel(c, unit, anim, big)
  local m = c.model
  local cam = Cam()
  m:Show()
  c.icon:Hide()
  local ok = pcall(m.SetUnit, m, unit)
  if not ok then m:Hide(); return false end
  pcall(m.SetCamDistanceScale, m, cam.scale * (big and 0.92 or 1))
  pcall(m.SetPosition, m, 0, 0, cam.z)
  pcall(m.SetFacing, m, 0)
  m.anim = anim
  local function Play() if m.anim then pcall(m.SetAnimation, m, m.anim) end end
  Play()
  pcall(m.SetScript, m, "OnModelLoaded", Play)
  return true
end

local function Fill(c, pick, big, idx, screen)
  local pal, accent = Palette(pick, big)
  Grad(c.bg, pal[1] * 1.15, pal[2] * 1.15, pal[3] * 1.15, 0.95, pal[1] * 0.35, pal[2] * 0.35, pal[3] * 0.35, 0.95)
  c.top:SetColorTexture(accent[1], accent[2], accent[3], 1)
  c.pill:SetColorTexture(accent[1] * 0.25, accent[2] * 0.25, accent[3] * 0.25, 0.9)
  c.kind:SetText(big and "TOP HONOR" or (pick.kind == "roast" and "ROAST" or "AWARD"))
  c.kind:SetTextColor(accent[1], accent[2], accent[3])
  c.award:SetText((pick.award or "?"):upper())
  c.award:SetTextColor(big and 1 or accent[1] * 0.35 + 0.65, big and 0.84 or accent[2] * 0.35 + 0.65, big and 0.4 or accent[3] * 0.35 + 0.65)
  local nm = Short(pick.name) or "?"
  if D.SameName and D.Me and D.SameName(pick.name, D.Me()) then nm = nm .. " (you)" end
  c.who:SetText(nm)
  c.who:SetTextColor(ClassColor(pick.class))
  c.flavor:SetText(pick.flavor or "")
  if D.AwardIcon and pick.code then c.sealTex:SetTexture(D.AwardIcon(pick.code)); c.seal:Show() else c.seal:Hide() end -- v1.6.0
  c.stat:SetText(pick.text or "")
  c.stat:SetTextColor(0.92, 0.95, 1)
  -- model or class icon
  local unit = FindUnit(pick.name)
  if not unit and (screen.test or screen.demo) then unit = "player" end -- the test screen shows your own character on every card
  local group = big and "head" or (pick.kind == "roast" and "roast" or "pos")
  local list = Anims(group)
  local anim = list[((idx or 1) % #list) + 1]
  local shown = false
  if unit and UnitIsVisible and (unit == "player" or UnitIsVisible(unit)) then shown = ApplyModel(c, unit, anim, big) end
  if not shown then
    c.model:Hide()
    local cc = pick.class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[pick.class]
    if cc then
      c.icon:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
      c.icon:SetTexCoord(cc[1], cc[2], cc[3], cc[4])
      c.icon:Show()
    else
      c.icon:Hide()
    end
  end
end

function U.Show(screen)
  if not screen or not screen.picks or #screen.picks == 0 then return end
  win = win or Build()
  local f = win
  f.screen = screen
  local sc = math.min(1, UIParent:GetWidth() / 1200, UIParent:GetHeight() / 780)
  f.stage:SetScale(sc > 0 and sc or 1)
  f.kicker:SetText((screen.test or screen.demo) and "TEST RAID REPORT" or "RAID REPORT")
  f.title:SetText(screen.title or "Raid")
  f.summary:SetText(screen.summary or "")
  f.banner:SetText(screen.preview and "PREVIEW  -  only you can see this until you share it" or "")
  f.tag:SetText((screen.test or screen.demo) and "TEST SCREEN" or "")
  local n = #screen.picks
  for pos = 1, 5 do
    local c = f.cards[pos]
    local idx = ORDER[pos]
    local pick = screen.picks[idx]
    if pick and (n >= 5 or idx <= n) then
      c.frame:Show()
      Fill(c, pick, idx == 1, idx, screen)
      c.frame:SetAlpha(0)
      local delay = (pos == 3) and 1.1 or (math.abs(pos - 3) == 1 and 0.3 or 0.55)
      C_Timer.After(delay, function()
        if win == f and f:IsShown() and f.screen == screen then
          if UIFrameFadeIn then UIFrameFadeIn(c.frame, 0.4, 0, 1) else c.frame:SetAlpha(1) end
        end
      end)
    else
      c.frame:Hide()
    end
  end
  -- honourable mentions
  if screen.extra and #screen.extra > 0 then
    local parts = {}
    for _, p in ipairs(screen.extra) do
      local ic = (D.AwardInline and p.code) and (D.AwardInline(p.code, 14) .. " ") or "" -- v1.6.0
      parts[#parts + 1] = ("%s%s: %s (%s)"):format(ic, p.award, Short(p.name), p.text)
    end
    f.mentions:SetText("ALSO NOTABLE    " .. table.concat(parts, "     "))
  else
    f.mentions:SetText("")
  end
  -- buttons
  local list = {}
  if screen.onReroll and (screen.preview or screen.test) then
    f.btns.reroll:SetScript("OnClick", function() screen.onReroll() end)
    list[#list + 1] = f.btns.reroll
  end
  if screen.onPost and screen.preview then
    f.btns.post.label:SetText(D.practice and "SHARE (PRACTICE)" or "SHARE TO RAID")
    f.btns.post:SetScript("OnClick", function() screen.onPost() end)
    list[#list + 1] = f.btns.post
  end
  if not screen.preview and not screen.test then
    f.btns.send:SetScript("OnClick", function() D.Chat(U.TextFor(screen), "RAID", nil, true) end)
    list[#list + 1] = f.btns.send
  end
  list[#list + 1] = f.btns.close
  Layout(f, list)
  -- emotes play once, so replay them now and then
  if type(f.ticker) == "table" then f.ticker:Cancel() end
  f.ticker = C_Timer.NewTicker(5, function()
    for pos = 1, 5 do
      local m = f.cards[pos].model
      if m:IsShown() and m.anim then pcall(m.SetAnimation, m, m.anim) end
    end
  end)
  f:Show()
end

function U.OpenSaved(i)
  local h = D.db and D.db.stats and D.db.stats.history
  local s = h and h[i or 1]
  if not s then Print("No awards screen saved yet. They are kept for the last 5 raids.") return end
  U.Show({ title = s.title, summary = s.summary, picks = s.picks, extra = s.extra })
end

-- /dkp podium anim <id> | anims <head|pos|roast> <ids> | cam <scale> <height>
function U.Tune(sub, arg)
  local st = Settings()
  if sub == "anim" then
    local id = tonumber(arg)
    if not id then Print("/dkp podium anim <number> plays that animation on every model of the open screen (try /dkp podium test first).") return end
    if not win or not win:IsShown() then Print("Open the test screen first: /dkp podium test") return end
    for pos = 1, 5 do
      local m = win.cards[pos].model
      if m:IsShown() then m.anim = id; pcall(m.SetAnimation, m, id) end
    end
    Print("Playing animation " .. id .. ". Keep the ones you like: /dkp podium anims pos 68,80  (groups: head, pos, roast)")
  elseif sub == "anims" then
    local group, ids = arg:match("^(%a+)%s+(.+)$")
    if not group or not ANIM_DEFAULT[group:lower()] then
      Print("/dkp podium anims <head|pos|roast> <ids, comma separated>   e.g. /dkp podium anims roast 77,83")
      return
    end
    local list = {}
    for n in ids:gmatch("%d+") do list[#list + 1] = tonumber(n) end
    if #list == 0 then return end
    st.podiumAnims = st.podiumAnims or {}
    st.podiumAnims[group:lower()] = list
    Print(group .. " animations set to " .. table.concat(list, ", "))
  elseif sub == "cam" then
    local s, z = arg:match("^(%S+)%s*(%S*)$")
    s = tonumber(s)
    if not s then
      local c = Cam()
      Print(("Camera: scale %.2f, height %.2f. /dkp podium cam <scale> <height>  (bigger scale = further away). /dkp podium cam reset"):format(c.scale, c.z))
      if arg == "reset" then st.podiumCam = nil end
      return
    end
    st.podiumCam = { scale = s, z = tonumber(z) or Cam().z }
    if win and win:IsShown() and win.screen then U.Show(win.screen) end
    Print(("Camera set: scale %.2f, height %.2f"):format(s, st.podiumCam.z))
  end
end
