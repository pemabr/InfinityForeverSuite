local ADDON, D = ...
local C = D.Config

---------------------------------------------------------------------------
-- Look: dark slate panels, gold accent, item names in their quality colour
---------------------------------------------------------------------------
local BD = BackdropTemplateMixin and "BackdropTemplate" or nil
local WHITE = "Interface\\Buttons\\WHITE8X8"
local COL = {
  bg = { 0.09, 0.105, 0.133, 0.97 }, head = { 0.12, 0.14, 0.176, 1 }, line = { 0.22, 0.255, 0.306, 1 },
  row = { 0.15, 0.17, 0.21, 1 }, sel = { 0.165, 0.14, 0.08, 1 },
  gold = { 0.878, 0.69, 0.31 }, text = { 0.925, 0.906, 0.863 }, muted = { 0.655, 0.686, 0.729 },
  blue = { 0.61, 0.79, 1 }, orange = { 0.95, 0.65, 0.29 }, red = { 1, 0.48, 0.42 }, teal = { 0.56, 0.88, 0.77 },
}
D.COL = COL

-- v0.3.0: faction theme for the main window (Horde red / Alliance blue, gold trim)
-- v0.8.0: own artwork (Media\\Brand, Media\\Menu): crest, wordmark and plaque per faction
local MEDIA = "Interface\\AddOns\\GuildLadderDKP\\Media\\"
local THEME = {
  Horde = { deep = { 0.23, 0.07, 0.055, 1 }, accent = { 0.72, 0.2, 0.16, 1 }, title = "ff6b5e",
    crest = MEDIA .. "Brand\\Crest_Horde.tga", wordmark = MEDIA .. "Brand\\Wordmark_Horde.tga", plaque = MEDIA .. "Brand\\Plaque_Horde.tga",
    corner = MEDIA .. "Brand\\Corner_Horde.tga", close = MEDIA .. "Brand\\Close_Horde.tga" },
  Alliance = { deep = { 0.078, 0.15, 0.29, 1 }, accent = { 0.18, 0.39, 0.77, 1 }, title = "6fa3ff",
    crest = MEDIA .. "Brand\\Crest_Alliance.tga", wordmark = MEDIA .. "Brand\\Wordmark_Alliance.tga", plaque = MEDIA .. "Brand\\Plaque_Alliance.tga",
    corner = MEDIA .. "Brand\\Corner_Alliance.tga", close = MEDIA .. "Brand\\Close_Alliance.tga" },
}
-- every picture the window uses (a test checks they all exist)
D.ART = {
  "Menu\\Standings.tga", "Menu\\RaidNight.tga", "Menu\\Readiness.tga", "Menu\\Raids.tga", "Menu\\Logs.tga",
  "Menu\\HallOfFame.tga", "Menu\\MyDKP.tga", "Menu\\LootQueue.tga", "Menu\\Settings.tga",
  "Brand\\Crest_Horde.tga", "Brand\\Crest_Alliance.tga", "Brand\\Wordmark_Horde.tga", "Brand\\Wordmark_Alliance.tga",
  "Brand\\Plaque_Horde.tga", "Brand\\Plaque_Alliance.tga",
  "Brand\\Corner_Horde.tga", "Brand\\Corner_Alliance.tga", "Brand\\Close_Horde.tga", "Brand\\Close_Alliance.tga",
}
local function Theme()
  local f = UnitFactionGroup and UnitFactionGroup("player")
  return THEME[f or ""] or THEME.Horde
end
D.Theme = Theme
local TITLE_FONT = "Fonts\\MORPHEUS.TTF"
local GOLD_DIM = { 0.35, 0.29, 0.165, 1 }
local PANEL = { 0.071, 0.075, 0.094, 1 }

-- the game's own class icons
local function SetClassIcon(tex, class)
  local c = class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
  if c then
    tex:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
    tex:SetTexCoord(c[1], c[2], c[3], c[4])
    tex:Show()
  else
    tex:Hide()
  end
end

local function Skin(f, bg, border)
  if not f.SetBackdrop then return end
  f:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
  f:SetBackdropColor(unpack(bg or COL.bg))
  f:SetBackdropBorderColor(unpack(border or COL.line))
end

local function Text(parent, size, color, template)
  local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlight")
  if size then
    local font, _, flags = fs:GetFont()
    if font then fs:SetFont(font, size, flags) end
  end
  fs:SetTextColor(unpack(color or COL.text))
  fs:SetJustifyH("LEFT")
  fs:SetWordWrap(false)
  return fs
end

-- kind: "primary" (gold), "secondary" (dark), "ghost" (outline)
local function Btn(parent, label, w, h, kind, onClick)
  local b = CreateFrame("Button", nil, parent, BD)
  b:SetSize(w, h or 26)
  kind = kind or "secondary"
  local bg = kind == "primary" and { COL.gold[1], COL.gold[2], COL.gold[3], 1 }
    or kind == "ghost" and { 0, 0, 0, 0 } or { 0.15, 0.17, 0.21, 1 }
  Skin(b, bg, kind == "primary" and { COL.gold[1], COL.gold[2], COL.gold[3], 1 } or COL.line)
  b.label = Text(b, 12, kind == "primary" and { 0.1, 0.08, 0.03 } or (kind == "ghost" and COL.muted or COL.text), "GameFontNormal")
  b.label:SetPoint("CENTER")
  b.label:SetJustifyH("CENTER")
  b.label:SetText(label)
  function b:SetLabel(t) self.label:SetText(t) end
  b:SetScript("OnEnter", function(self) if self:IsEnabled() then self:SetBackdropBorderColor(COL.gold[1], COL.gold[2], COL.gold[3], 1) end end)
  b:SetScript("OnLeave", function(self)
    if kind == "primary" then self:SetBackdropBorderColor(COL.gold[1], COL.gold[2], COL.gold[3], 1)
    else self:SetBackdropBorderColor(unpack(COL.line)) end
  end)
  b:SetScript("OnDisable", function(self) self:SetAlpha(0.4) end)
  b:SetScript("OnEnable", function(self) self:SetAlpha(1) end)
  if onClick then b:SetScript("OnClick", onClick) end
  return b
end
D.Btn = Btn

local function Edit(parent, w, numeric)
  local eb = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
  eb:SetSize(w, 20)
  eb:SetAutoFocus(false)
  if numeric then eb:SetNumeric(true) end
  eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  eb:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
  return eb
end

local function Check(parent, label, get, set)
  local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  cb:SetSize(22, 22)
  local fs = Text(cb, 12, COL.text)
  fs:SetPoint("LEFT", cb, "RIGHT", 2, 0)
  fs:SetText(label)
  cb:SetScript("OnShow", function(self) self:SetChecked(get() and true or false) end)
  cb:SetScript("OnClick", function(self) set(self:GetChecked() and true or false) end)
  return cb
end

---------------------------------------------------------------------------
-- v0.2.30: window scale and resize
--   Every window: drag the corner grip to scale it (Standings / Loot Queue:
--   drag = taller or shorter, Shift-drag = scale), Ctrl + mouse wheel on the
--   title bar to scale, right-click the grip to reset. Saved per window.
---------------------------------------------------------------------------
local SCALE_MIN, SCALE_MAX, SCALE_STEP = 0.6, 1.6, 0.05
local GRIP = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-"

local function SavedScale(key)
  return D.settings.scales and D.settings.scales[key]
end

-- top-left corner in screen units (nil if the frame has no rect yet)
local function ScreenTopLeft(f)
  local l, t = f:GetLeft(), f:GetTop()
  if not l or not t then return end
  local e = f:GetEffectiveScale()
  return l * e, t * e
end

-- pin the frame's top-left to a screen point and save that as its position,
-- in the same { point, x, y } shape Window() already restores
local function AnchorAt(f, key, lx, ty)
  local e, pe = f:GetEffectiveScale(), UIParent:GetEffectiveScale()
  local x = (lx - (UIParent:GetLeft() or 0) * pe) / e
  local y = (ty - UIParent:GetTop() * pe) / e
  f:ClearAllPoints()
  f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", x, y)
  if key then D.settings.pos[key] = { "TOPLEFT", x, y } end
end

-- change scale without the window jumping: its top-left corner stays put
local function ApplyScale(f, key, s)
  s = math.max(SCALE_MIN, math.min(SCALE_MAX, math.floor(s * 100 + 0.5) / 100))
  if math.abs(s - f:GetScale()) < 0.001 then return end
  local lx, ty = ScreenTopLeft(f)
  f:SetScale(s)
  if lx then AnchorAt(f, key, lx, ty) end
  D.settings.scales = D.settings.scales or {}
  D.settings.scales[key] = (math.abs(s - 1) > 0.001) and s or nil
end

local function WheelScale(region, f, key)
  region:EnableMouseWheel(true)
  region:SetScript("OnMouseWheel", function(_, delta)
    if IsControlKeyDown() then ApplyScale(f, key, f:GetScale() + delta * SCALE_STEP) end
  end)
end

-- corner grip. g.onSize (set by HeightResizable) turns a plain drag into a
-- height resize; without it every drag scales.
local function Grip(f, key)
  local g = CreateFrame("Button", nil, f)
  g:SetSize(14, 14)
  g:SetPoint("BOTTOMRIGHT", -2, 2)
  g:SetFrameLevel(f:GetFrameLevel() + 20)
  g:SetNormalTexture(GRIP .. "Up")
  g:SetHighlightTexture(GRIP .. "Highlight")
  g:SetPushedTexture(GRIP .. "Down")
  g:RegisterForClicks("RightButtonUp")
  local function Stop(self)
    if self.mode == "size" then
      f:StopMovingOrSizing()
      if self.onSize then self.onSize("final") end
      local lx, ty = ScreenTopLeft(f)
      if lx then AnchorAt(f, key, lx, ty) end
    end
    self:SetScript("OnUpdate", nil)
    self.mode = nil
  end
  g:SetScript("OnMouseDown", function(self, button)
    if button ~= "LeftButton" then return end
    f:Raise()
    if self.onSize and not IsShiftKeyDown() then
      self.mode = "size"
      f:StartSizing("BOTTOMRIGHT")
    else
      self.mode = "scale"
      self.x0, self.s0 = GetCursorPosition(), f:GetScale()
      self.w0 = f:GetWidth() * f:GetEffectiveScale()
      self:SetScript("OnUpdate", function()
        local x = GetCursorPosition()
        ApplyScale(f, key, self.s0 * (self.w0 + (x - self.x0)) / self.w0)
      end)
    end
  end)
  g:SetScript("OnMouseUp", function(self, button) if button == "LeftButton" then Stop(self) end end)
  g:SetScript("OnHide", function(self) if self.mode then Stop(self) end end)
  g:SetScript("OnClick", function(self)
    ApplyScale(f, key, 1)
    if self.onSize then self.onSize("reset") end
  end)
  g:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if self.onSize then
      GameTooltip:AddLine("Drag: taller / shorter", 1, 1, 1)
      GameTooltip:AddLine("Shift-drag: scale", 1, 1, 1)
    else
      GameTooltip:AddLine("Drag: scale", 1, 1, 1)
    end
    if f.head then GameTooltip:AddLine("Ctrl + mouse wheel on the title bar: scale", 1, 1, 1) end
    GameTooltip:AddLine("Right-click: reset size", 0.65, 0.65, 0.68)
    GameTooltip:Show()
  end)
  g:SetScript("OnLeave", function() GameTooltip:Hide() end)
  f.grip = g
  return g
end

-- v0.9.1: the round close button (art per faction); lights up on hover, darkens while pressed
local function CloseButton(parent, onClick)
  local th = Theme()
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(28, 28)
  b.art = b:CreateTexture(nil, "ARTWORK"); b.art:SetAllPoints(); b.art:SetTexture(th.close)
  b.glow = b:CreateTexture(nil, "OVERLAY"); b.glow:SetAllPoints(); b.glow:SetTexture(th.close)
  b.glow:SetBlendMode("ADD"); b.glow:SetAlpha(0)
  b:SetScript("OnEnter", function(self) self.glow:SetAlpha(0.45) end)
  b:SetScript("OnLeave", function(self) self.glow:SetAlpha(0); self.art:SetVertexColor(1, 1, 1) end)
  b:SetScript("OnMouseDown", function(self) self.art:SetVertexColor(0.72, 0.72, 0.72) end)
  b:SetScript("OnMouseUp", function(self) self.art:SetVertexColor(1, 1, 1) end)
  b:SetScript("OnClick", onClick)
  return b
end

local function Window(name, title, w, h, point, x, y)
  local th = Theme()
  local f = CreateFrame("Frame", name, UIParent, BD)
  f:SetSize(w, h)
  if SavedScale(name) then f:SetScale(SavedScale(name)) end -- v0.2.30
  Skin(f, { 0.055, 0.059, 0.075, 1 }, GOLD_DIM) -- v0.9.0: opaque and gold-trimmed like the main window (the windows behind no longer show through)
  f:SetFrameStrata("HIGH")
  f:SetToplevel(true) -- click (or drag) brings this window in front of the others, like Blizzard's own windows
  f:SetClampedToScreen(true)
  f:SetMovable(true)
  f:EnableMouse(true)
  local pos = D.settings.pos[name]
  if pos then f:SetPoint(pos[1], UIParent, pos[1], pos[2], pos[3]) else f:SetPoint(point or "CENTER", x or 0, y or 0) end
  local head = CreateFrame("Frame", nil, f, BD)
  head:SetPoint("TOPLEFT", 1, -1)
  head:SetPoint("TOPRIGHT", -1, -1)
  head:SetHeight(46)
  Skin(head, { 0.071, 0.075, 0.094, 1 }, { 0, 0, 0, 0 })
  local hline = head:CreateTexture(nil, "ARTWORK"); hline:SetColorTexture(unpack(GOLD_DIM))
  hline:SetHeight(2); hline:SetPoint("BOTTOMLEFT"); hline:SetPoint("BOTTOMRIGHT")
  head:EnableMouse(true)
  head:RegisterForDrag("LeftButton")
  head:SetScript("OnDragStart", function() f:Raise(); f:StartMoving() end)
  head:SetScript("OnDragStop", function()
    f:StopMovingOrSizing()
    local p, _, _, x, y = f:GetPoint()
    D.settings.pos[name] = { p, x, y }
  end)
  -- v0.9.0: faction crest + Morpheus title, same look as the main window's pages
  f.crest = head:CreateTexture(nil, "ARTWORK")
  f.crest:SetSize(30, 30); f.crest:SetPoint("LEFT", 10, 0); f.crest:SetTexture(th.crest)
  f.title = Text(head, 20, COL.gold, "GameFontNormalLarge")
  f.title:SetFont(TITLE_FONT, 21)
  f.title:SetPoint("TOPLEFT", 48, -7)
  f.title:SetText(title)
  f.sub = Text(head, 11, COL.muted)
  f.sub:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -2)
  local close = CloseButton(head, function() f:Hide() end)
  close:SetPoint("RIGHT", -10, 0)
  f.close = close
  f.head = head
  -- v0.9.1: the gold corner ornament, flipped for each corner, sitting just outside the frame
  local ov = CreateFrame("Frame", nil, f)
  ov:SetAllPoints()
  ov:SetFrameLevel(f:GetFrameLevel() + 30)
  local function Corner(point, dx, dy, l, r, t, bt)
    local c = ov:CreateTexture(nil, "OVERLAY")
    c:SetSize(40, 40); c:SetPoint(point, f, point, dx, dy)
    c:SetTexture(th.corner); c:SetTexCoord(l, r, t, bt)
  end
  Corner("TOPLEFT", -8, 8, 0, 1, 0, 1); Corner("TOPRIGHT", 8, 8, 1, 0, 0, 1)
  Corner("BOTTOMLEFT", -8, -8, 0, 1, 1, 0); Corner("BOTTOMRIGHT", 8, -8, 1, 0, 1, 0)
  f.corners = ov
  WheelScale(head, f, name) -- v0.2.30
  Grip(f, name)             -- v0.2.30
  tinsert(UISpecialFrames, name)
  f:Hide()
  return f
end

-- Simple scrolling list: fixed rows, mouse wheel moves the window over the data
-- v0.2.30: l.count = rows in use; SetRows() grows it (rows are made on demand) or shrinks it
local function List(parent, rowH, n, make)
  local l = CreateFrame("Frame", nil, parent)
  l.rows, l.offset, l.data, l.count = {}, 0, {}, n
  local function Add(i)
    local r = make(l, i)
    r:SetHeight(rowH)
    r:SetPoint("TOPLEFT", 0, -(i - 1) * rowH)
    r:SetPoint("TOPRIGHT", 0, -(i - 1) * rowH)
    l.rows[i] = r
  end
  for i = 1, n do Add(i) end
  function l:SetRows(k)
    if k == self.count then return end
    for i = #self.rows + 1, k do Add(i) end
    self.count = k
    local max = math.max(0, #self.data - k)
    if self.offset > max then self.offset = max end
    self:Redraw()
  end
  l:EnableMouseWheel(true)
  l:SetScript("OnMouseWheel", function(self, delta)
    local max = math.max(0, #self.data - self.count)
    self.offset = math.max(0, math.min(max, self.offset - delta * 2))
    self:Redraw()
  end)
  function l:SetData(data, fill)
    self.data, self.fill = data, fill
    local max = math.max(0, #data - self.count)
    if self.offset > max then self.offset = max end
    self:Redraw()
  end
  function l:Redraw()
    for i, r in ipairs(self.rows) do
      local item = i <= self.count and self.data[i + self.offset]
      if item then r:Show(); self.fill(r, item, i + self.offset) else r:Hide() end
    end
  end
  return l
end

-- v0.2.30: let a single-list window grow or shrink in whole rows (width stays fixed)
local function HeightResizable(f, key, list, rowH, minRows, maxRows)
  local defRows = list.count
  local chrome = f:GetHeight() - list:GetHeight()
  local w = f:GetWidth()
  local minH, maxH = chrome + minRows * rowH, chrome + maxRows * rowH
  f:SetResizable(true)
  if f.SetResizeBounds then
    f:SetResizeBounds(w, minH, w, maxH)
  else
    if f.SetMinResize then f:SetMinResize(w, minH) end
    if f.SetMaxResize then f:SetMaxResize(w, maxH) end
  end
  local function Fit(n, final)
    n = math.max(minRows, math.min(maxRows, n))
    list:SetRows(n)
    list:SetHeight(n * rowH)
    if final then
      f:SetHeight(chrome + n * rowH)
      D.settings.sizes = D.settings.sizes or {}
      D.settings.sizes[key] = (n ~= defRows) and n or nil
    end
  end
  f:HookScript("OnSizeChanged", function()
    if f.grip and f.grip.mode == "size" then Fit(math.floor((f:GetHeight() - chrome) / rowH)) end
  end)
  f.grip.onSize = function(how)
    if how == "reset" then Fit(defRows, true)
    else Fit(math.floor((f:GetHeight() - chrome) / rowH + 0.5), true) end
  end
  local saved = D.settings.sizes and D.settings.sizes[key]
  if saved then Fit(saved, true) end
end

local function Line(parent)
  local t = parent:CreateTexture(nil, "ARTWORK")
  t:SetColorTexture(unpack(COL.line))
  t:SetHeight(1)
  return t
end

local function Clock(secs)
  secs = math.max(0, math.floor(secs or 0))
  local h, m = math.floor(secs / 3600), math.floor(secs % 3600 / 60)
  if secs < 60 then return ("0:%02d"):format(secs) end
  return ("%d:%02d"):format(h, m)
end

function D.Ago(t)
  if not t then return "None" end
  local days = math.floor((GetServerTime() - t) / 86400)
  if days <= 0 then return "today" end
  if days == 1 then return "1 day" end
  if days < 14 then return days .. " days" end
  return math.floor(days / 7) .. " weeks"
end

local function Ticker(f, fn, every)
  local acc = 0
  f:HookScript("OnUpdate", function(_, el)
    acc = acc + el
    if acc >= (every or 1) then acc = 0; fn() end
  end)
end

---------------------------------------------------------------------------
-- Toasts
---------------------------------------------------------------------------
local toast, toastQ = nil, {}
local function NextToast()
  local it = table.remove(toastQ, 1)
  if not it then return end
  toast.title:SetText(it.title)
  toast.text:SetText(it.text or "")
  toast.lastKey, toast.lastAt = it.key, GetTime() -- v0.2.37
  toast.onClick, toast.elapsed = it.onClick, 0
  toast.duration = it.onClick and 20 or 6
  toast:SetAlpha(1)
  toast:Show()
end

function D.Toast(title, text, onClick)
  if not toast then
    toast = CreateFrame("Button", "GuildLadderDKPToast", UIParent, BD)
    toast:SetSize(340, 64)
    toast:SetPoint("TOP", 0, -190)
    toast:SetFrameStrata("DIALOG")
    Skin(toast, COL.bg, { COL.gold[1], COL.gold[2], COL.gold[3], 1 })
    toast.title = Text(toast, 14, COL.gold, "GameFontNormalLarge")
    toast.title:SetPoint("TOPLEFT", 14, -12)
    toast.text = Text(toast, 12, COL.text)
    toast.text:SetPoint("TOPLEFT", toast.title, "BOTTOMLEFT", 0, -5)
    toast.text:SetWidth(310)
    toast:SetScript("OnClick", function(self)
      local fn = self.onClick
      self.onClick = nil
      if fn then fn() end -- a real click: chat posting is allowed here
      self.elapsed = math.max(self.elapsed, self.duration)
    end)
    toast:SetScript("OnUpdate", function(self, el)
      self.elapsed = self.elapsed + el
      if self.elapsed > self.duration then
        local a = 1 - (self.elapsed - self.duration)
        if a <= 0 then self:Hide(); NextToast() else self:SetAlpha(a) end
      end
    end)
    toast:Hide()
  end
  -- v0.2.37: drop a toast identical to one already waiting or shown in the
  -- last 30 seconds, so nothing pops up again right after it clears
  local key = (title or "") .. "|" .. (text or "")
  for _, q in ipairs(toastQ) do if q.key == key then return end end
  if toast.lastKey == key and GetTime() - (toast.lastAt or 0) < 30 then return end
  table.insert(toastQ, { title = title, text = text, onClick = onClick, key = key })
  if not toast:IsShown() then NextToast() end
end

---------------------------------------------------------------------------
-- Post chat on the next key press (Forever needs a key press or click)
---------------------------------------------------------------------------
local keyFrame
function D.ArmKeyPost() if keyFrame then keyFrame:Show() end end
function D.DisarmKeyPost() if keyFrame then keyFrame:Hide() end end
local function BuildKeyFrame()
  keyFrame = CreateFrame("Frame", "GuildLadderDKPKeyPost", UIParent)
  keyFrame:SetSize(1, 1)
  keyFrame:SetPoint("TOPLEFT")
  keyFrame:EnableKeyboard(true)
  if keyFrame.SetPropagateKeyboardInput then keyFrame:SetPropagateKeyboardInput(true) end
  keyFrame:SetScript("OnKeyDown", function(self) self:Hide(); D.PostPendingChat() end)
  keyFrame:Hide()
end

---------------------------------------------------------------------------
-- Popups
---------------------------------------------------------------------------
local function PopupEdit(self) return self.editBox or self.EditBox end
local function EnterAccepts(name)
  return function(self)
    local parent = self:GetParent()
    StaticPopupDialogs[name].OnAccept(parent, parent.data)
    parent:Hide()
  end
end

StaticPopupDialogs.GLDKP_UNDO = {
  text = "Undo this entry?\n\n%s\n\nA correction is added to the ledger; nothing is deleted.",
  button1 = "Undo", button2 = CANCEL, timeout = 0, whileDead = 1, hideOnEscape = 1,
  -- v0.3.0: a merged log line (an award stored in parts) undoes every part
  OnAccept = function(_, id)
    if type(id) == "table" then for _, x in ipairs(id) do D.Undo(x) end else D.Undo(id) end
  end,
}
StaticPopupDialogs.GLDKP_LINK = {
  text = "Link Discord sign-up \"%s\" to which character?",
  button1 = "Link", button2 = CANCEL, hasEditBox = 1, timeout = 0, whileDead = 1, hideOnEscape = 1,
  OnAccept = function(self, discordId)
    local name = D.ResolveName(PopupEdit(self):GetText())
    if name ~= "" then D.LinkDiscord(name, discordId) end
  end,
  EditBoxOnEnterPressed = EnterAccepts("GLDKP_LINK"),
}
StaticPopupDialogs.GLDKP_CUSTOM = {
  text = "Custom award to everyone in the raid + bench.\nType: amount reason  (e.g. 15 World boss)",
  button1 = "Award", button2 = CANCEL, hasEditBox = 1, timeout = 0, whileDead = 1, hideOnEscape = 1,
  OnAccept = function(self)
    local amt, reason = PopupEdit(self):GetText():match("^%s*(%-?%d+)%s*(.*)$")
    if not amt then D.Print("Type an amount first, e.g. 15 World boss") return end
    local chk = D.RaidCheck()
    local names = {}
    for _, k in ipairs({ "onTime", "late", "bench" }) do for _, n in ipairs(chk[k]) do names[#names + 1] = n end end
    D.Award(names, tonumber(amt), reason ~= "" and reason or "Custom award", "CUSTOM")
  end,
  EditBoxOnEnterPressed = EnterAccepts("GLDKP_CUSTOM"),
}
StaticPopupDialogs.GLDKP_ADJUST = {
  text = "Adjust %s\nType: amount reason  (e.g. -20 Mis-click refund)",
  button1 = "Save", button2 = CANCEL, hasEditBox = 1, timeout = 0, whileDead = 1, hideOnEscape = 1,
  OnAccept = function(self, name)
    local amt, reason = PopupEdit(self):GetText():match("^%s*(%-?%d+)%s*(.*)$")
    if amt then D.Adjust(name, tonumber(amt), reason ~= "" and reason or "Adjustment") end
  end,
  EditBoxOnEnterPressed = EnterAccepts("GLDKP_ADJUST"),
}
StaticPopupDialogs.GLDKP_REMOVE = {
  text = "Remove %s from standings?\n\nTheir DKP history stays in the log - this just takes them off the list. \"+ Add player\" brings them straight back with their balance intact, any time.",
  button1 = "Remove", button2 = CANCEL, timeout = 0, whileDead = 1, hideOnEscape = 1,
  OnAccept = function(_, name) D.SetHidden(name, true) end,
}
-- v0.3.1: Raid night's "+ Add" on the bench strip
StaticPopupDialogs.GLDKP_ADDBENCH = {
  text = "Add to the bench (they get standby awards):",
  button1 = "Add", button2 = CANCEL, hasEditBox = 1, timeout = 0, whileDead = 1, hideOnEscape = 1,
  OnShow = function(self) local eb = PopupEdit(self); eb:SetText(""); eb:SetFocus() end,
  OnAccept = function(self)
    local nm = PopupEdit(self):GetText()
    if nm and nm:match("%S") then D.AddBench(nm) end
  end,
  EditBoxOnEnterPressed = EnterAccepts("GLDKP_ADDBENCH"),
}
StaticPopupDialogs.GLDKP_ADDPLAYER = {
  text = "Add a player to standings - works even if they're offline.\nType: Name [amount] [reason]  (e.g. Girthynotch 64 Restored after accidental undo)\nLeave the amount off (or use 0) to just make them visible again at 0.",
  button1 = "Add", button2 = CANCEL, hasEditBox = 1, timeout = 0, whileDead = 1, hideOnEscape = 1,
  OnShow = function(self) local eb = PopupEdit(self); eb:SetText(""); eb:SetFocus() end,
  OnAccept = function(self)
    local raw = PopupEdit(self):GetText()
    local nm, rest = raw:match("^%s*(%S+)%s*(.-)$")
    if not nm or nm == "" then D.Print("Type a player name.") return end
    local amt, reason = rest:match("^(%-?%d+)%s*(.*)$")
    if not amt then amt, reason = "0", rest end
    D.AddPlayer(D.ResolveName(nm), tonumber(amt), reason ~= "" and reason or nil)
  end,
  EditBoxOnEnterPressed = EnterAccepts("GLDKP_ADDPLAYER"),
}
StaticPopupDialogs.GLDKP_BOSS = {
  text = "Which boss?",
  button1 = "Award", button2 = CANCEL, hasEditBox = 1, timeout = 0, whileDead = 1, hideOnEscape = 1,
  OnAccept = function(self)
    local b = PopupEdit(self):GetText()
    if b and b ~= "" then D.AwardRaid("BOSS", b) end
  end,
  EditBoxOnEnterPressed = EnterAccepts("GLDKP_BOSS"),
}
StaticPopupDialogs.GLDKP_AUCNOSALE = {
  text = "There are bids on this item. %s it anyway?\nNobody is charged.",
  button1 = YES, button2 = NO,
  OnAccept = function(_, outcome) D.NoBidsAuction(outcome) end,
  timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

StaticPopupDialogs.GLDKP_AUCAWARD = {
  text = "Award %s to:\nType: Name price  (e.g. Thuro 40). Anyone, even if they didn't bid.",
  button1 = "Award", button2 = CANCEL, hasEditBox = 1, timeout = 0, whileDead = 1, hideOnEscape = 1,
  OnShow = function(self)
    local eb = PopupEdit(self)
    local who, price = D.AuctionPick()
    if eb and who then eb:SetText(("%s %d"):format(D.FirstName(who), price or 0)); eb:HighlightText() end
  end,
  OnAccept = function(self)
    local name, price = PopupEdit(self):GetText():match("^%s*(.-)%s+(%d+)%s*$")
    if not name or name == "" then D.Print("Type a name and a price, e.g. Thuro 40") return end
    D.AwardAuction(true, D.ResolveName(name), tonumber(price))
  end,
  EditBoxOnEnterPressed = EnterAccepts("GLDKP_AUCAWARD"),
}
StaticPopupDialogs.GLDKP_CREATERAID = {
  text = "Create raid\nName it (Raid-Helper's title is filled in). Nothing is awarded until you press Start raid.",
  button1 = "Create", button2 = CANCEL, hasEditBox = 1, timeout = 0, whileDead = 1, hideOnEscape = 1,
  OnShow = function(self)
    local ev = D.TonightEvent()
    local eb = PopupEdit(self)
    if eb then eb:SetText((ev and ev.title) or ("Raid " .. D.RealmDate())); eb:HighlightText() end
  end,
  OnAccept = function(self) D.CreateRaid(PopupEdit(self):GetText()) end,
  EditBoxOnEnterPressed = EnterAccepts("GLDKP_CREATERAID"),
}
StaticPopupDialogs.GLDKP_HANDOFF = {
  text = "Hand off %s to which officer?\n(Trade them the item after.)",
  button1 = "Hand off", button2 = CANCEL, hasEditBox = 1, timeout = 0, whileDead = 1, hideOnEscape = 1,
  OnAccept = function(self, uid) D.HandOff(uid, PopupEdit(self):GetText()) end,
  EditBoxOnEnterPressed = EnterAccepts("GLDKP_HANDOFF"),
}
StaticPopupDialogs.GLDKP_DECAY = {
  text = "Weekly decay: %s\n\nRun it for the whole guild?",
  button1 = "Run decay", button2 = CANCEL, timeout = 0, whileDead = 1, hideOnEscape = 1,
  OnAccept = function() D.Decay() end,
}
StaticPopupDialogs.GLDKP_IMPORT = {
  text = "Write starting balances from Guild Ladder points for everyone who doesn't have one yet?",
  button1 = YES, button2 = NO, timeout = 0, whileDead = 1, hideOnEscape = 1,
  OnAccept = function() D.ImportLadder() end,
}
StaticPopupDialogs.GLDKP_PHASE = {
  text = "Start a new phase now? \"Items this phase\" counts from today.",
  button1 = YES, button2 = NO, timeout = 0, whileDead = 1, hideOnEscape = 1,
  OnAccept = function() D.SetConfig("PHASE_START", GetServerTime()) end,
}

-- Shift-click an item into our boxes (the hook moved in newer clients)
local linkHooks = {}
function D.OnInsertLink(fn)
  if #linkHooks == 0 then
    local function Run(link)
      if type(link) ~= "string" then return end
      for _, h in ipairs(linkHooks) do h(link) end
    end
    if ChatEdit_InsertLink then hooksecurefunc("ChatEdit_InsertLink", Run) end
    if ChatFrameUtil and ChatFrameUtil.InsertLink then hooksecurefunc(ChatFrameUtil, "InsertLink", Run) end
  end
  linkHooks[#linkHooks + 1] = fn
end


StaticPopupDialogs.GLDKP_CLAIM = {
  text = "This character is an alt of which character?\n(They'll get a popup to accept.)",
  button1 = "Link", button2 = CANCEL, hasEditBox = 1, timeout = 0, whileDead = 1, hideOnEscape = 1,
  OnAccept = function(self) D.ClaimMain(PopupEdit(self):GetText()) end,
  EditBoxOnEnterPressed = EnterAccepts("GLDKP_CLAIM"),
}
StaticPopupDialogs.GLDKP_ALTOF = {
  text = "Link %s as an alt of which main?\n(Leave empty to unlink.)",
  button1 = "Save", button2 = CANCEL, hasEditBox = 1, timeout = 0, whileDead = 1, hideOnEscape = 1,
  OnAccept = function(self, alt) D.OfficerLink(alt, PopupEdit(self):GetText()) end,
  EditBoxOnEnterPressed = EnterAccepts("GLDKP_ALTOF"),
}

---------------------------------------------------------------------------
-- Small right-click menu for a player (officers)
---------------------------------------------------------------------------
local menu
-- items: { { "Label", function() end }, ... }
-- A menu can now hold more items than fit on screen (e.g. "Add to standings"
-- on a large guild roster) - MENU_MAX_ROWS caps how tall it ever grows, and
-- the rest scrolls with the mouse wheel, same windowed-redraw idea as List().
local MENU_MAX_ROWS = 10
function D.ShowMenu(anchor, title, items)
  if not menu then
    menu = CreateFrame("Frame", "GuildLadderDKPMenu", UIParent, BD)
    Skin(menu, COL.head, { COL.gold[1], COL.gold[2], COL.gold[3], 1 })
    menu:SetFrameStrata("TOOLTIP")
    menu.title = Text(menu, 11, COL.gold); menu.title:SetPoint("TOPLEFT", 10, -8)
    menu.buttons, menu.offset = {}, 0
    for i = 1, MENU_MAX_ROWS do
      local b = Btn(menu, "", 210, 22, "ghost")
      b.label:ClearAllPoints(); b.label:SetPoint("LEFT", 6, 0)
      b:SetPoint("TOPLEFT", 10, -26 - (i - 1) * 24)
      menu.buttons[i] = b
    end
    function menu:RedrawRows()
      for i, b in ipairs(self.buttons) do
        local it = self.items and self.items[i + self.offset]
        if it then
          b:SetLabel(it[1])
          b.label:SetTextColor(unpack(it.danger and COL.red or COL.text))
          b:SetScript("OnClick", function() menu:Hide(); it[2]() end)
          b:Show()
        else
          b:Hide()
        end
      end
    end
    menu:EnableMouseWheel(true)
    menu:SetScript("OnMouseWheel", function(self, delta)
      local max = math.max(0, #(self.items or {}) - MENU_MAX_ROWS)
      self.offset = math.max(0, math.min(max, self.offset - delta))
      self:RedrawRows()
    end)
    menu:SetScript("OnUpdate", function(self)
      if not self:IsMouseOver(20, -20, -20, 20) and not (self.anchor and self.anchor:IsMouseOver()) then self.idle = (self.idle or 0) + 1 else self.idle = 0 end
      if (self.idle or 0) > 90 then self:Hide() end
    end)
    tinsert(UISpecialFrames, "GuildLadderDKPMenu")
  end
  local w = 230
  for _, b in ipairs(menu.buttons) do b:SetWidth(w - 20) end
  menu.items, menu.offset = items, 0
  menu:RedrawRows()
  local visible = math.min(#items, MENU_MAX_ROWS)
  menu:SetSize(w, 32 + visible * 24)
  menu.title:SetWidth(w - 20)
  menu.title:SetText(title .. (#items > MENU_MAX_ROWS and (" (" .. #items .. " - scroll for more)") or ""))
  menu.anchor, menu.idle = anchor, 0
  menu:ClearAllPoints()
  local x, y = GetCursorPosition()
  local sc = UIParent:GetEffectiveScale()
  menu:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / sc - 10, y / sc + 10)
  menu:Show()
end

-- End raid: with or without the full clear award
function D.ShowEndMenu(anchor)
  local ses = D.OpenSession()
  if not ses then return end
  local clear = tonumber(D.Cfg("CLEAR")) or 0
  local items = {}
  if clear > 0 and not D.RaidAwardGiven("CLEAR", ses.id) then
    items[#items + 1] = { ("End raid + full clear (+%d)"):format(clear), function() D.EndSession(true) end }
  end
  items[#items + 1] = { "End raid (no full clear)", function() D.EndSession(false) end }
  D.ShowMenu(anchor, ses.title or "End raid", items)
end

-- The raid button on Raid night: Create raid -> Start raid -> End raid
function D.RaidButtonClick(anchor)
  if D.OpenSession() then
    D.ShowEndMenu(anchor)
  elseif D.PlannedRaid() then
    D.StartSession()
  else
    StaticPopup_Show("GLDKP_CREATERAID")
  end
end

local CLASS_LIST = { "Warrior", "Paladin", "Hunter", "Rogue", "Priest", "Shaman", "Mage", "Warlock", "Druid" }
function D.ShowPlayerMenu(anchor, name)
  D.ShowMenu(anchor, name, {
    { "Adjust DKP...", function()
      local dlg = StaticPopup_Show("GLDKP_ADJUST", name)
      if dlg then dlg.data = name end
    end },
    { "Link as alt of...", function()
      local dlg = StaticPopup_Show("GLDKP_ALTOF", name)
      if dlg then dlg.data = name end
    end },
    { "Add to bench", function() D.AddBench(name) end },
    { "Set class...", function()
      local items = {}
      for _, c in ipairs(CLASS_LIST) do
        local token = c:upper()
        items[#items + 1] = { c, function() D.SetClassOverride(name, token) end }
      end
      D.ShowMenu(anchor, "Set class: " .. (D.FirstName(name) or name), items)
    end },
    { "Remove from standings...", function()
      local dlg = StaticPopup_Show("GLDKP_REMOVE", D.FirstName(name) or name)
      if dlg then dlg.data = name end
    end, danger = true },
  })
end

StaticPopupDialogs.GLDKP_DELRAID = {
  text = "%s\n\nNothing is erased: it's an undo, and the log shows who did it.",
  button1 = "Delete", button2 = CANCEL, timeout = 0, whileDead = 1, hideOnEscape = 1, showAlert = 1,
  OnAccept = function(_, data) if data then D.DeleteRaid(data.key, data.withDKP) end end,
}

local function ConfirmDelete(key, title, withDKP)
  local text = withDKP
    and ("Delete \"%s\" AND undo every award and item spend from it?\nDKP goes back to how it was before the raid."):format(title)
    or ("Delete \"%s\"?\nIts awards and loot stay on everyone's DKP."):format(title)
  local dlg = StaticPopup_Show("GLDKP_DELRAID", text)
  if dlg then dlg.data = { key = key, withDKP = withDKP } end
end
D.ConfirmDeleteRaid = ConfirmDelete

---------------------------------------------------------------------------
-- "Is this character an alt?" (asked once per character, or from My DKP)
---------------------------------------------------------------------------
local altAsk
function D.AskAltLink(fromButton)
  local others = D.MyOtherChars()
  if not altAsk then
    altAsk = CreateFrame("Frame", "GuildLadderDKPAltAsk", UIParent, BD)
    altAsk:SetSize(320, 100)
    Skin(altAsk, COL.bg, { COL.gold[1], COL.gold[2], COL.gold[3], 1 })
    altAsk:SetFrameStrata("DIALOG")
    altAsk:SetPoint("CENTER", 0, 120)
    altAsk:EnableMouse(true)
    altAsk.title = Text(altAsk, 14, COL.gold, "GameFontNormalLarge"); altAsk.title:SetPoint("TOPLEFT", 14, -12)
    altAsk.text = Text(altAsk, 11, COL.muted); altAsk.text:SetPoint("TOPLEFT", altAsk.title, "BOTTOMLEFT", 0, -4)
    altAsk.text:SetWidth(292); altAsk.text:SetWordWrap(true)
    altAsk.text:SetText("Alts share their main's DKP. Pick its main, or say it's a main.")
    altAsk.buttons = {}
    tinsert(UISpecialFrames, "GuildLadderDKPAltAsk")
  end
  for _, b in ipairs(altAsk.buttons) do b:Hide() end
  altAsk.title:SetText(("Is %s an alt?"):format(D.FirstName(D.Me())))
  local y, i = -60, 0
  local function Add(label, kind, fn)
    i = i + 1
    local b = altAsk.buttons[i]
    if not b then b = Btn(altAsk, "", 292, 26, kind); altAsk.buttons[i] = b end
    b:SetLabel(label)
    b:SetScript("OnClick", function() altAsk:Hide(); fn() end)
    b:ClearAllPoints(); b:SetPoint("TOPLEFT", 14, y)
    b:Show()
    y = y - 30
  end
  for n = 1, math.min(5, #others) do
    local main = others[n]
    Add("Alt of " .. main, "secondary", function() D.ClaimMain(main) end)
  end
  Add("Alt of a character on another account...", "ghost", function() StaticPopup_Show("GLDKP_CLAIM") end)
  Add("No, this is a main", "primary", function() D.MarkMain() end)
  if not fromButton then Add("Ask me later", "ghost", function() end) end
  altAsk:SetHeight(-y + 10)
  altAsk:Show()
end

---------------------------------------------------------------------------
-- Import from CLM: paste box for the `/clm export` JSON string.
-- A normal StaticPopup edit box is single-line and some templates cap
-- around 255 characters, which a guild-sized JSON export blows past -
-- so this is its own scrollable, multi-line box.
-- Loot history can run to ~1 MB, and an EditBox laying out that much text
-- freezes the game. So pastes are caught a character at a time in OnChar
-- (it still fires for every pasted character) while the box itself only
-- keeps the first few KB - the same trick WeakAuras' import uses.
---------------------------------------------------------------------------
local clmImport
function D.AskImportCLM()
  if not D.IsGM() then Print("Only the guild master can import CLM standings.") return end
  if not clmImport then
    local f = CreateFrame("Frame", "GuildLadderDKPCLMImport", UIParent, BD)
    f:SetSize(420, 340)
    Skin(f, COL.bg, { COL.gold[1], COL.gold[2], COL.gold[3], 1 })
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:SetPoint("CENTER")
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function() f:Raise(); f:StartMoving() end)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f.title = Text(f, 14, COL.gold, "GameFontNormalLarge"); f.title:SetPoint("TOPLEFT", 14, -12)
    f.title:SetText("Import from CLM")
    f.text = Text(f, 11, COL.muted); f.text:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -6)
    f.text:SetWidth(392); f.text:SetWordWrap(true)
    f.text:SetText("In CLM: /clm export, pick Standings and/or Loot History + JSON, copy the string, then paste it below. Loot history is a record only - it never changes anyone's DKP.")

    local box = CreateFrame("Frame", nil, f, BD)
    box:SetPoint("TOPLEFT", 14, -86)
    box:SetPoint("BOTTOMRIGHT", -14, 46)
    Skin(box, { 0.05, 0.06, 0.08, 1 }, COL.line)

    local scroll = CreateFrame("ScrollFrame", "GuildLadderDKPCLMImportScroll", box, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 4, -4)
    scroll:SetPoint("BOTTOMRIGHT", -24, 4)

    local eb = CreateFrame("EditBox", nil, scroll)
    eb:SetMultiLine(true)
    eb:SetAutoFocus(false)
    eb:SetFontObject(ChatFontNormal)
    eb:SetMaxLetters(0) -- the default InputBox limit (~255) is far too small for a guild export
    eb:SetMaxBytes(4000) -- what the box shows; the whole paste goes to f.pasted (below)
    eb:SetWidth(380)
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    eb:SetScript("OnTextChanged", function(self) scroll:UpdateScrollChildRect() end)
    local buf, nbuf, pasteAt = {}, 0, nil
    local function EndPaste(self)
      self:SetScript("OnUpdate", nil)
      local text = table.concat(buf, "", 1, nbuf)
      buf, nbuf = {}, 0
      if #text > 3000 then -- a paste, not typing
        f.pasted = text
        f.size:SetText(("Pasted %d KB - click Import."):format(math.ceil(#text / 1024)))
      end
    end
    eb:SetScript("OnChar", function(self, c)
      if pasteAt ~= GetTime() then -- first character this frame: a new paste (or a key press)
        buf, nbuf, pasteAt = {}, 0, GetTime()
        self:SetScript("OnUpdate", EndPaste)
      end
      nbuf = nbuf + 1
      buf[nbuf] = c
    end)
    scroll:SetScrollChild(eb)
    f.editBox = eb

    f.size = Text(f, 11, COL.teal); f.size:SetPoint("BOTTOMLEFT", 16, 18); f.size:SetWidth(170)

    f.importBtn = Btn(f, "Import", 100, 26, "primary", function()
      local text = f.pasted or eb:GetText()
      f.pasted = nil
      f:Hide()
      D.ImportCLM(text)
    end)
    f.importBtn:SetPoint("BOTTOMRIGHT", -14, 12)
    f.cancelBtn = Btn(f, "Cancel", 100, 26, "ghost", function() f:Hide() end)
    f.cancelBtn:SetPoint("RIGHT", f.importBtn, "LEFT", -6, 0)

    tinsert(UISpecialFrames, "GuildLadderDKPCLMImport")
    clmImport = f
  end
  clmImport.editBox:SetText("")
  clmImport.pasted = nil
  clmImport.size:SetText("")
  clmImport:Show()
  clmImport.editBox:SetFocus()
end

---------------------------------------------------------------------------
-- Tooltips: item -> min bid, note, wishlist, queue · player -> DKP
---------------------------------------------------------------------------
local BIS_COL -- v0.6.0: BiS line colours (COL is ready by the time a tooltip shows)
local function ItemLines(tt, itemID)
  if not itemID or not D.data then return end
  local lines = {}
  -- v0.6.0: what this item means for MY BiS list (nothing for items on none of my lists)
  if D.BiS then
    -- v0.6.1: Loon-style colours: the text carries its own colour codes, base = the rest
    BIS_COL = BIS_COL or { text = COL.text, muted = COL.muted, good = { 0.56, 0.88, 0.56 }, blue = COL.blue, gold = COL.gold }
    local ok, bl = pcall(D.BiS.TooltipLines, itemID)
    if ok then for _, l in ipairs(bl) do lines[#lines + 1] = { l[1], BIS_COL[l.base] or COL.text, right = l.right } end end
  end
  local note = D.ItemNote(itemID)
  if note and note.note then lines[#lines + 1] = { "Note: " .. note.note, COL.text } end
  local min = math.max(tonumber(note and note.min) or 0, tonumber(D.Cfg("MIN_BID")) or 0)
  if note and note.min then lines[#lines + 1] = { "Minimum bid: " .. min, COL.text } end
  local w = D.Wishers(itemID)
  if #w > 0 then
    local names = {}
    for i = 1, math.min(4, #w) do names[i] = D.FirstName(w[i]) end
    lines[#lines + 1] = { ("Wishlisted by %d: %s%s"):format(#w, table.concat(names, ", "), #w > 4 and ", ..." or ""), COL.blue }
  end
  -- v0.2.39: who's won it before, CLM-style - one line per win, newest
  -- first: class-coloured name on the left, price and date on the right
  local wins = {}
  for _, w in ipairs(D.WinsFor(itemID)) do wins[#wins + 1] = w end -- v0.7.2: a tier piece shows its token's wins
  table.sort(wins, function(a, b) return (a.t or 0) > (b.t or 0) end)
  if #wins > 0 then
    local MAX = 5
    lines[#lines + 1] = { "Won by:", COL.muted }
    for i = 1, math.min(MAX, #wins) do
      local w = wins[i]
      local class = D.ClassOf(w.who)
      local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
      local hex = c and (c.colorStr or ("ff%02x%02x%02x"):format(c.r * 255, c.g * 255, c.b * 255)) or "ffffffff"
      lines[#lines + 1] = {
        "  |c" .. hex .. (D.FirstName(w.who) or w.who or "?") .. "|r" .. (w.os and " |cffa7afba(OS)|r" or "") .. (w.via and " |cffa7afba(token)|r" or ""), COL.text,
        right = ("%s DKP · %s"):format(w.price and tostring(w.price) or "?", date("%b %d", w.t or 0)),
      }
    end
    if #wins > MAX then lines[#lines + 1] = { ("  +%d earlier"):format(#wins - MAX), COL.muted } end
  end
  for _, r in ipairs(D.QueueRows()) do
    if r.item == itemID then
      lines[#lines + 1] = { ("In loot queue · %s"):format(r.status == "won" and ("won by " .. (r.winner or "?")) or ("held by " .. (D.FirstName(r.holder) or "?"))), COL.orange }
      break
    end
  end
  if #lines == 0 then return end
  tt:AddLine(" ")
  tt:AddLine("Guild Ladder DKP", COL.gold[1], COL.gold[2], COL.gold[3])
  for _, l in ipairs(lines) do
    if l.right then
      tt:AddDoubleLine(l[1], l.right, l[2][1], l[2][2], l[2][3], COL.gold[1], COL.gold[2], COL.gold[3])
    else
      tt:AddLine(l[1], l[2][1], l[2][2], l[2][3], true)
    end
  end
end

local function UnitLines(tt, unit)
  if not unit or not D.data or not UnitIsPlayer(unit) then return end
  local name = UnitName(unit)
  if not name or D.Secret(name) then return end
  local full = D.Canon(name)
  if unit == "player" then full = D.Me() end
  local pool = D.Pool(full)
  local known = D.data.bal[pool] ~= nil
  if not known then for n in pairs(D.snap) do if D.SameName(n, name) then known = true end end end
  if not known then return end
  local main = D.MainOf(full)
  tt:AddLine(("DKP: %d%s"):format(D.Balance(full), main and (" (alt of " .. D.FirstName(main) .. ")") or ""),
    COL.gold[1], COL.gold[2], COL.gold[3])
end

local function HookTooltips()
  -- v0.2.40: hook every way the client might announce an item tooltip, and
  -- add our lines once per showing. Before, only TooltipDataProcessor was
  -- used when it existed, and on TBC Anniversary item tooltips didn't get
  -- our section at all.
  local reported
  local function Safe(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok and not reported then -- say so once instead of failing silently
      reported = true
      D.Print("Tooltip error (please report): " .. tostring(err))
    end
  end
  local function AddItem(tt, id)
    if not tt or tt.gldkpDone or not id then return end
    tt.gldkpDone = true
    Safe(ItemLines, tt, id)
    tt:Show() -- resize to fit the new lines
  end
  local function FromLink(tt)
    local ok, _, link = pcall(tt.GetItem, tt)
    return ok and link and tonumber(link:match("item:(%d+)")) or nil
  end
  local function AddUnit(tt)
    if tt.gldkpUnit then return end
    tt.gldkpUnit = true
    Safe(function() local _, unit = tt:GetUnit(); UnitLines(tt, unit) end)
  end
  for _, tt in ipairs({ GameTooltip, ItemRefTooltip }) do
    if tt then
      tt:HookScript("OnTooltipCleared", function(self) self.gldkpDone, self.gldkpUnit = nil, nil end)
      pcall(tt.HookScript, tt, "OnTooltipSetItem", function(self) AddItem(self, FromLink(self)) end)
    end
  end
  pcall(GameTooltip.HookScript, GameTooltip, "OnTooltipSetUnit", AddUnit)
  if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tt, data)
      if tt ~= GameTooltip and tt ~= ItemRefTooltip then return end
      local id = data and data.id
      if id and D.Secret(id) then return end
      AddItem(tt, tonumber(id) or FromLink(tt))
    end)
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tt)
      if tt == GameTooltip then AddUnit(tt) end
    end)
  end
end

---------------------------------------------------------------------------
-- Item tooltip helper
---------------------------------------------------------------------------
-- v0.2.32: hold Shift (or have "always compare" on) to see what you have
-- equipped in that slot, and Shift / Ctrl-click links or previews the item
local function WantCompare()
  if GetCVarBool and GetCVarBool("alwaysCompareItems") then return true end
  if IsModifiedClick then return IsModifiedClick("COMPAREITEMS") end
  return IsShiftKeyDown()
end
local function HideCompare()
  for _, t in ipairs({ ShoppingTooltip1, ShoppingTooltip2, ShoppingTooltip3 }) do
    if t and t.Hide then t:Hide() end
  end
end
local function ShowCompare()
  if not GameTooltip_ShowCompareItem then return end
  if not pcall(GameTooltip_ShowCompareItem, GameTooltip) then pcall(GameTooltip_ShowCompareItem) end
end

local function ItemTooltip(frame, itemID)
  frame:SetScript("OnEnter", function(self)
    local id = self.itemID or itemID
    if not id then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetHyperlink("item:" .. id)
    GameTooltip:Show()
    self.comparing = nil
    self:SetScript("OnUpdate", function(s)
      local want = WantCompare()
      if want ~= s.comparing and GameTooltip:IsOwned(s) then
        s.comparing = want
        if want then ShowCompare() else HideCompare() end
      end
    end)
  end)
  frame:SetScript("OnLeave", function(self)
    self:SetScript("OnUpdate", nil)
    self.comparing = nil
    HideCompare()
    GameTooltip:Hide()
  end)
  frame:SetScript("OnMouseUp", function(self)
    local id = self.itemID or itemID
    if id and HandleModifiedItemClick and IsModifiedClick() then
      local link = D.ItemLink(id)
      if link then HandleModifiedItemClick(link) end
    end
  end)
end

local function ClassColor(class)
  local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
  if c then return c.r, c.g, c.b end
  return unpack(COL.text)
end

-- Clip a FontString's text to its anchored width, adding "..." if it
-- overflows. Plain SetWordWrap(false) + two-point anchors does NOT auto-
-- truncate in WoW's API - text just draws past the frame - so log rows with
-- long item/reason names need this done by hand.
local function Fit(fs, text)
  fs:SetText(text or "")
  local w = fs:GetWidth()
  if w <= 0 or fs:GetStringWidth() <= w then return end
  local lo, hi = 0, #text
  while lo < hi do
    local mid = math.ceil((lo + hi) / 2)
    fs:SetText(text:sub(1, mid) .. "...")
    if fs:GetStringWidth() <= w then lo = mid else hi = mid - 1 end
  end
  fs:SetText(lo > 0 and (text:sub(1, lo) .. "...") or "...")
end

local function Icon(parent, size)
  local f = CreateFrame("Frame", nil, parent, BD)
  f:SetSize(size, size)
  Skin(f, { 0.15, 0.17, 0.21, 1 }, COL.line)
  f.tex = f:CreateTexture(nil, "ARTWORK")
  f.tex:SetPoint("TOPLEFT", 2, -2)
  f.tex:SetPoint("BOTTOMRIGHT", -2, 2)
  f.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  function f:SetItem(id)
    self.itemID = id
    self.tex:SetTexture(D.ItemIcon(id))
    local r, g, b = D.QualityColor(id)
    self:SetBackdropBorderColor(r, g, b, 1)
  end
  f:EnableMouse(true)
  ItemTooltip(f)
  return f
end

local function Chip(parent)
  local f = CreateFrame("Frame", nil, parent, BD)
  f:SetHeight(16)
  Skin(f, { 0.17, 0.19, 0.23, 1 }, { 0, 0, 0, 0 })
  f.text = Text(f, 10, COL.text, "GameFontNormalSmall")
  f.text:SetPoint("CENTER")
  function f:Set(label, bg, fg)
    self.text:SetText(label)
    self.text:SetTextColor(unpack(fg))
    self:SetBackdropColor(bg[1], bg[2], bg[3], 1)
    self:SetWidth(self.text:GetStringWidth() + 14)
  end
  return f
end

---------------------------------------------------------------------------
-- Loot queue window
---------------------------------------------------------------------------
local queueWin, selectedUid
local CHIP = {
  auction = { "Auctioning", { 0.29, 0.23, 0.07 }, { 0.95, 0.8, 0.48 } },
  pending = { "Pending", { 0.17, 0.19, 0.23 }, { 0.8, 0.83, 0.86 } },
  won = { "Awaiting trade", { 0.086, 0.19, 0.31 }, COL.blue },
}

local function RowDetail(r)
  if r.holder ~= D.Me() then
    if r.status == "won" then return ("Held by %s · won by %s"):format(D.FirstName(r.holder), r.winner or "?") end
    return "Held by " .. (D.FirstName(r.holder) or "?")
  end
  if r.status == "auction" and D.auction then
    local left = D.auction.endsLocal - GetTime()
    return D.auction.closed and "Bidding closed" or ("Bidding closes in %s"):format(Clock(left))
  end
  if r.status == "won" then return ("Won by %s · %d DKP"):format(r.winner or "?", r.price or 0) end
  local w = #D.Wishers(r.item)
  local note = D.ItemNote(r.item)
  if note and note.note then return "Note: " .. note.note end
  if w > 0 then return w .. " on wishlist" end
  if note and note.min then return "Min bid " .. note.min end
  if r.inBags == false then return "Not in your bags" end
  return ""
end

local function BuildQueue()
  local f = Window("GuildLadderDKPQueue", "Loot Queue", 440, 520, "TOPRIGHT", -16, -90)
  local strip = CreateFrame("Frame", nil, f, BD) -- v0.9.0: the hint / auto-start row sits on its own band
  strip:SetPoint("TOPLEFT", 1, -48); strip:SetPoint("TOPRIGHT", -1, -48); strip:SetHeight(28)
  Skin(strip, { 0.071, 0.075, 0.094, 1 }, { 0, 0, 0, 0 })
  local tip = Text(f, 11, COL.muted)
  tip:SetPoint("TOPLEFT", 14, -56)
  tip:SetText("Alt-click items in bags, loot or chat to add them")
  local auto = Check(f, "Auto-start next", function() return D.settings.autoNext end, function(v) D.settings.autoNext = v end)
  auto:SetPoint("TOPRIGHT", -110, -50)
  f.practice = Text(f, 11, COL.orange)
  f.practice:SetPoint("TOPRIGHT", -14, -46)
  local l1 = Line(f); l1:SetPoint("TOPLEFT", 1, -76); l1:SetPoint("TOPRIGHT", -1, -76)

  f.list = List(f, 56, 6, function(parent)
    local r = CreateFrame("Button", nil, parent, BD)
    Skin(r, { 0, 0, 0, 0 }, { 0, 0, 0, 0 })
    r.bar = r:CreateTexture(nil, "ARTWORK"); r.bar:SetColorTexture(COL.gold[1], COL.gold[2], COL.gold[3], 1) -- v0.9.0: selected row edge, like the main Standings
    r.bar:SetPoint("TOPLEFT"); r.bar:SetPoint("BOTTOMLEFT"); r.bar:SetWidth(3)
    r.icon = Icon(r, 38); r.icon:SetPoint("LEFT", 12, 0)
    r.name = Text(r, 13, COL.text, "GameFontNormal"); r.name:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 10, -1); r.name:SetWidth(240)
    r.chip = Chip(r); r.chip:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -5)
    r.detail = Text(r, 11, COL.muted); r.detail:SetPoint("LEFT", r.chip, "RIGHT", 8, 0); r.detail:SetWidth(170)
    r.timer = Text(r, 14, COL.text, "GameFontNormal"); r.timer:SetPoint("TOPRIGHT", -14, -12); r.timer:SetJustifyH("RIGHT")
    r.timerLbl = Text(r, 10, COL.muted); r.timerLbl:SetPoint("TOPRIGHT", r.timer, "BOTTOMRIGHT", 0, -3)
    r.timerLbl:SetText("trade window"); r.timerLbl:SetJustifyH("RIGHT")
    local ln = Line(r); ln:SetPoint("BOTTOMLEFT"); ln:SetPoint("BOTTOMRIGHT")
    r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    r:SetScript("OnClick", function(self, button)
      selectedUid = self.uid
      if button == "RightButton" then
        local row = D.FindRow(self.uid)
        if row and row.holder == D.Me() and row.status ~= "auction" then
          D.ShowMenu(self, D.ItemName(row.item), {
            { "Start auction", function() D.StartAuction(row.uid, true) end },
            { "Skip for now", function() D.RowOutcome(row.uid, "skip") end },
            { "Remove from queue", function() D.RowOutcome(row.uid, "remove") end, danger = true },
          })
        elseif row and row.holder == D.Me() and row.status == "auction" and D.auction then
          D.ShowMenu(self, D.ItemName(row.item), {
            { "Show auction window", function() D.ShowAuction() end },
            { "Cancel auction (back to queue)", function() D.CancelAuction() end, danger = true },
          })
        elseif row and row.holder ~= D.Me() then
          D.Print(("%s is holding that item - only they can change its row."):format(row.holder or "?"))
        end
      else
        -- clicking the row that's being auctioned brings the bids back up (v0.2.22)
        local row = D.FindRow(self.uid)
        if row and row.holder == D.Me() and row.status == "auction" and D.auction then
          D.ShowAuction()
        elseif IsAltKeyDown() then
          D.StartAuction(self.uid, true)
        end
      end
      D.RefreshQueue()
    end)
    return r
  end)
  f.list:SetPoint("TOPLEFT", 1, -77)
  f.list:SetPoint("TOPRIGHT", -1, -77)
  f.list:SetHeight(56 * 6)
  HeightResizable(f, "GuildLadderDKPQueue", f.list, 56, 4, 14) -- v0.2.30

  f.emptyIcon = f:CreateTexture(nil, "ARTWORK") -- v0.9.0: an empty-state picture instead of bare text
  f.emptyIcon:SetSize(80, 80); f.emptyIcon:SetPoint("TOP", f.list, "TOP", 0, -50)
  f.emptyIcon:SetTexture(MEDIA .. "Menu\\LootQueue.tga"); f.emptyIcon:SetAlpha(0.55)
  f.empty = Text(f, 12, COL.muted)
  f.empty:SetPoint("TOP", f.emptyIcon, "BOTTOM", 0, -12)
  f.empty:SetJustifyH("CENTER")
  f.empty:SetText("Queue is empty.\nLooted epics show up here automatically.")
  f.empty:SetWordWrap(true)

  local foot = CreateFrame("Frame", nil, f, BD)
  foot:SetPoint("BOTTOMLEFT", 1, 1); foot:SetPoint("BOTTOMRIGHT", -1, 1); foot:SetHeight(104)
  Skin(foot, { 0.071, 0.075, 0.094, 1 }, { 0, 0, 0, 0 })
  local fline = foot:CreateTexture(nil, "ARTWORK"); fline:SetColorTexture(unpack(GOLD_DIM)) -- v0.9.0: gold-dim rule like the main window's footer
  fline:SetHeight(2); fline:SetPoint("TOPLEFT"); fline:SetPoint("TOPRIGHT")
  f.selected = Text(foot, 11, COL.muted); f.selected:SetPoint("TOPLEFT", 14, -10); f.selected:SetWidth(410)
  local W = 98
  -- v0.2.31: top row re-spaced so "Remove from Queue" fits (was "Bank")
  f.start = Btn(foot, "START AUCTION", 150, 32, "primary", function()
    if D.auction then D.ShowAuction() return end -- v0.2.22: reopen the bids
    local sel = selectedUid and D.FindRow(selectedUid)
    if sel and sel.status == "won" then D.TradeWinner(sel, true) return end -- v1.2.0: the same button opens the trade
    if selectedUid then D.StartAuction(selectedUid, true) end
  end)
  f.start:SetPoint("TOPLEFT", 14, -28)
  f.de = Btn(foot, "Disenchant", W, 32, "secondary", function() if selectedUid then D.RowOutcome(selectedUid, "de") end end)
  f.de:SetPoint("LEFT", f.start, "RIGHT", 6, 0)
  f.remove = Btn(foot, "Remove from Queue", 150, 32, "secondary", function()
    if selectedUid then D.RowOutcome(selectedUid, "remove") end
  end)
  f.remove:SetPoint("LEFT", f.de, "RIGHT", 6, 0)
  f.nobids = Btn(foot, "No bids", W, 26, "ghost", function() if selectedUid then D.RowOutcome(selectedUid, "nobids") end end)
  f.nobids:SetPoint("TOPLEFT", f.start, "BOTTOMLEFT", 0, -6)
  f.skip = Btn(foot, "Skip", W, 26, "ghost", function() if selectedUid then D.RowOutcome(selectedUid, "skip") end end)
  f.skip:SetPoint("LEFT", f.nobids, "RIGHT", 6, 0)
  f.handoff = Btn(foot, "Hand off to officer...", W * 2 + 6, 26, "ghost", function()
    local r = selectedUid and D.FindRow(selectedUid)
    if r then
      local dlg = StaticPopup_Show("GLDKP_HANDOFF", D.ItemName(r.item))
      if dlg then dlg.data = r.uid end
    end
  end)
  f.handoff:SetPoint("LEFT", f.skip, "RIGHT", 6, 0)

  f:SetScript("OnShow", function() D.RefreshQueue() end)
  f:HookScript("OnHide", function() if D.RefreshDock then D.RefreshDock() end end) -- v1.1.0: the tracker takes over
  -- v1.1.0: minimize = close this window and let the small tracker show the items
  local mini = Btn(f.head, "_", 26, 26, "ghost", function() f:Hide() end)
  mini:SetPoint("RIGHT", f.close, "LEFT", -6, 0)
  mini:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_BOTTOM"); GameTooltip:SetText("Minimize to the loot tracker", 1, 1, 1); GameTooltip:Show() end)
  mini:SetScript("OnLeave", function() GameTooltip:Hide() end)
  Ticker(f, function() if f:IsShown() then D.RefreshQueue() end end, 1)
  queueWin = f
end

function D.RefreshQueue()
  if D.RefreshDock then D.RefreshDock() end -- v1.1.0
  local f = queueWin
  if not f or not f:IsShown() then return end
  local rows = D.QueueRows()
  local mine = 0
  for _, r in ipairs(rows) do if r.holder == D.Me() then mine = mine + 1 end end
  f.sub:SetText(("Held by you: %d · %d in queue"):format(mine, #rows))
  f.practice:SetText(D.practice and "PRACTICE" or "")
  local found = false
  for _, r in ipairs(rows) do if r.uid == selectedUid then found = true end end
  if not found then
    selectedUid = nil
    for _, r in ipairs(rows) do if r.holder == D.Me() and r.status == "pending" then selectedUid = r.uid break end end
  end
  local now = GetServerTime()
  local yellow, red = tonumber(D.Cfg("WARN_YELLOW")) or 1800, tonumber(D.Cfg("WARN_RED")) or 600
  -- v0.2.31: "(1 of 2)" when the same item is in the queue more than once
  local total, nth = {}, {}
  for _, r in ipairs(rows) do
    total[r.item] = (total[r.item] or 0) + 1
    nth[r.uid] = total[r.item]
  end
  f.list:SetData(rows, function(row, r)
    row.uid = r.uid
    row.icon:SetItem(r.item)
    local copy = (total[r.item] or 0) > 1 and (" |cffa7afba(%d of %d)|r"):format(nth[r.uid], total[r.item]) or ""
    row.name:SetText(D.ItemName(r.item) .. copy)
    row.name:SetTextColor(D.QualityColor(r.item))
    local c = CHIP[r.status] or CHIP.pending
    row.chip:Set(c[1], c[2], c[3])
    row.detail:SetText(RowDetail(r))
    local left = (r.expires or 0) - now
    row.timer:SetText(r.expires and Clock(left) or "--")
    row.timer:SetTextColor(unpack(left < red and COL.red or left < yellow and COL.orange or COL.text))
    row:SetBackdropColor(unpack(r.uid == selectedUid and Theme().deep or { 0, 0, 0, 0 }))
    row.bar:SetShown(r.uid == selectedUid)
  end)
  f.empty:SetShown(#rows == 0)
  f.emptyIcon:SetShown(#rows == 0)
  local sel = selectedUid and D.FindRow(selectedUid)
  local mineSel = sel and sel.holder == D.Me()
  f.selected:SetText(sel and ("Selected: |cffece7dc%s|r"):format(D.ItemName(sel.item)) or "Select an item")
  if D.auction then
    f.start:SetLabel("SHOW AUCTION")
    f.start:SetEnabled(true)
  elseif mineSel and sel.status == "won" and sel.winner then
    f.start:SetLabel(("TRADE TO %s"):format((D.FirstName(sel.winner) or sel.winner):upper())) -- v1.2.0
    f.start:SetEnabled(true)
  else
    f.start:SetLabel("START AUCTION")
    f.start:SetEnabled(mineSel and sel.status == "pending" or false)
  end
  for _, b in ipairs({ f.de, f.remove, f.nobids, f.skip, f.handoff }) do
    b:SetEnabled(mineSel and sel.status ~= "auction" or false)
  end
end

function D.ShowQueue()
  if not queueWin then BuildQueue() end
  queueWin:Show()
  if D.RefreshDock then D.RefreshDock() end -- v1.1.0: the small tracker steps aside while the queue is open
end
function D.ToggleQueue()
  if not queueWin then BuildQueue() end
  queueWin:SetShown(not queueWin:IsShown())
  if D.RefreshDock then D.RefreshDock() end
end

---------------------------------------------------------------------------
-- v1.1.0: Loot tracker - a small strip on screen with the items I'm holding and how long their trade window has
-- left (the compact version of the Loot Queue; same rows, same actions). Shows up by itself when I hold items,
-- hides when the Loot Queue window is open or I hold nothing.
---------------------------------------------------------------------------
local dock
local DOCK_NAME, DOCK_W, DOCK_ROW, DOCK_MAX, DOCK_HEAD = "GuildLadderDKPDock", 300, 24, 6, 26

function D.SelectQueueRow(uid)
  selectedUid = uid
  D.ShowQueue()
  D.RefreshQueue()
end

local function DockUrgency(left)
  local yellow, red = tonumber(D.Cfg("WARN_YELLOW")) or 1800, tonumber(D.Cfg("WARN_RED")) or 600
  return left < red and COL.red or (left < yellow and COL.orange or COL.text)
end

local function DockMenu(anchor, r)
  local items = {}
  if r.status == "won" and r.winner then
    items[#items + 1] = { "Trade to " .. (D.FirstName(r.winner) or r.winner), function() D.TradeWinner(r, true) end }
  end
  if D.auction then
    items[#items + 1] = { "Show auction", function() D.ShowAuction() end }
  elseif r.status == "pending" then
    items[#items + 1] = { "Start auction", function() D.StartAuction(r.uid, true) end }
  end
  if r.status ~= "auction" then
    items[#items + 1] = { "Disenchant", function() D.RowOutcome(r.uid, "de") end }
    items[#items + 1] = { "No bids", function() D.RowOutcome(r.uid, "nobids") end }
    items[#items + 1] = { "Skip", function() D.RowOutcome(r.uid, "skip") end }
    items[#items + 1] = { "Hand off to officer...", function()
      local dlg = StaticPopup_Show("GLDKP_HANDOFF", D.ItemName(r.item))
      if dlg then dlg.data = r.uid end
    end }
    items[#items + 1] = { "Remove from queue", function() D.RowOutcome(r.uid, "remove") end, danger = true }
  end
  items[#items + 1] = { "Open Loot Queue", function() D.SelectQueueRow(r.uid) end }
  D.ShowMenu(anchor, D.ItemName(r.item), items)
end

local function BuildDock()
  local th = Theme()
  local f = CreateFrame("Frame", DOCK_NAME, UIParent, BD)
  f:SetSize(DOCK_W, DOCK_HEAD + 8)
  Skin(f, { 0.055, 0.059, 0.075, 0.97 }, GOLD_DIM)
  f:SetFrameStrata("MEDIUM")
  f:SetClampedToScreen(true)
  f:SetMovable(true)
  f:EnableMouse(true)
  if SavedScale(DOCK_NAME) then f:SetScale(SavedScale(DOCK_NAME)) end
  local pos = D.settings.pos[DOCK_NAME]
  if pos then f:SetPoint(pos[1], UIParent, pos[1], pos[2], pos[3]) else f:SetPoint("LEFT", 24, 140) end

  local head = CreateFrame("Frame", nil, f, BD)
  head:SetPoint("TOPLEFT", 1, -1); head:SetPoint("TOPRIGHT", -1, -1); head:SetHeight(DOCK_HEAD)
  Skin(head, { 0.071, 0.075, 0.094, 1 }, { 0, 0, 0, 0 })
  local hline = head:CreateTexture(nil, "ARTWORK"); hline:SetColorTexture(unpack(GOLD_DIM))
  hline:SetHeight(1); hline:SetPoint("BOTTOMLEFT"); hline:SetPoint("BOTTOMRIGHT")
  head:EnableMouse(true)
  head:RegisterForDrag("LeftButton")
  head:SetScript("OnDragStart", function() f:StartMoving() end)
  head:SetScript("OnDragStop", function()
    f:StopMovingOrSizing()
    local p, _, _, x, y = f:GetPoint()
    D.settings.pos[DOCK_NAME] = { p, x, y }
  end)
  WheelScale(head, f, DOCK_NAME) -- Ctrl + wheel resizes it, like the other windows
  f.head = head
  f.crest = head:CreateTexture(nil, "ARTWORK"); f.crest:SetSize(18, 18); f.crest:SetPoint("LEFT", 6, 0); f.crest:SetTexture(th.crest)
  f.title = Text(head, 13, COL.gold); f.title:SetFont(TITLE_FONT, 14); f.title:SetPoint("LEFT", f.crest, "RIGHT", 6, 0); f.title:SetText("Loot")
  f.count = Text(head, 11, COL.muted); f.count:SetPoint("LEFT", f.title, "RIGHT", 8, 0)

  local function HeadButton(text, tip, onClick)
    local b = Btn(head, text, 20, 20, "ghost", onClick)
    b:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_BOTTOM"); GameTooltip:SetText(tip, 1, 1, 1); GameTooltip:Show() end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
  end
  f.hide = HeadButton("x", "Hide the tracker (/dkp dock on brings it back)", function()
    D.settings.lootDock = false
    D.Print("Loot tracker hidden. /dkp dock on brings it back.")
    D.RefreshDock()
  end)
  f.hide:SetPoint("RIGHT", -4, 0)
  f.open = HeadButton("Q", "Open the Loot Queue", function() D.ShowQueue() end)
  f.open:SetPoint("RIGHT", f.hide, "LEFT", -3, 0)
  f.fold = HeadButton("-", "Collapse / expand", function()
    D.settings.dockCollapsed = not D.settings.dockCollapsed
    D.RefreshDock()
  end)
  f.fold:SetPoint("RIGHT", f.open, "LEFT", -3, 0)

  f.rows = {}
  for i = 1, DOCK_MAX do
    local r = CreateFrame("Button", nil, f, BD)
    r:SetPoint("TOPLEFT", 1, -DOCK_HEAD - 3 - (i - 1) * DOCK_ROW); r:SetPoint("TOPRIGHT", -1, -DOCK_HEAD - 3 - (i - 1) * DOCK_ROW)
    r:SetHeight(DOCK_ROW)
    Skin(r, { 0, 0, 0, 0 }, { 0, 0, 0, 0 })
    r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    r.iconF = CreateFrame("Frame", nil, r, BD); r.iconF:SetSize(20, 20); r.iconF:SetPoint("LEFT", 5, 0)
    Skin(r.iconF, { 0, 0, 0, 1 }, { 0.5, 0.5, 0.5, 1 })
    r.tex = r.iconF:CreateTexture(nil, "ARTWORK"); r.tex:SetPoint("TOPLEFT", 1, -1); r.tex:SetPoint("BOTTOMRIGHT", -1, 1); r.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    r.name = Text(r, 12, COL.text); r.name:SetPoint("LEFT", r.iconF, "RIGHT", 6, 0); r.name:SetWidth(140)
    r.tag = Text(r, 10, COL.muted); r.tag:SetPoint("RIGHT", -58, 0); r.tag:SetWidth(56); r.tag:SetJustifyH("RIGHT")
    r.timer = Text(r, 12, COL.text); r.timer:SetPoint("RIGHT", -8, 0); r.timer:SetJustifyH("RIGHT")
    r:SetScript("OnEnter", function(self)
      self:SetBackdropColor(1, 1, 1, 0.05)
      local row = self.uid and D.FindRow(self.uid)
      if row then GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetHyperlink(D.ItemLink(row.item)); GameTooltip:Show() end
    end)
    r:SetScript("OnLeave", function(self) self:SetBackdropColor(0, 0, 0, 0); GameTooltip:Hide() end)
    r:SetScript("OnClick", function(self, button)
      local row = self.uid and D.FindRow(self.uid)
      if not row then return end
      if button == "RightButton" then DockMenu(self, row)
      elseif IsShiftKeyDown() then if ChatEdit_InsertLink then ChatEdit_InsertLink(D.ItemLink(row.item)) end
      elseif IsAltKeyDown() then
        if D.auction then D.ShowAuction() elseif row.status == "pending" then D.StartAuction(row.uid, true) end
      elseif row.status == "won" then D.TradeWinner(row, true) -- v1.2.0: click a won item = open the trade with the winner
      else D.SelectQueueRow(row.uid) end
    end)
    f.rows[i] = r
  end
  f.more = Text(f, 10, COL.muted); f.more:SetJustifyH("LEFT")
  f.hint = Text(f, 9, COL.muted)
  f.hint:SetText("Alt-click: auction  ·  Click a won item: trade  ·  Right-click: more")
  Ticker(f, function() if f:IsShown() then D.RefreshDock() end end, 1)
  f:Hide()
  return f
end

function D.RefreshDock()
  local off = not D.settings or D.settings.lootDock == false
  local rows = {}
  if not off then
    for _, r in ipairs(D.QueueRows()) do if r.holder == D.Me() then rows[#rows + 1] = r end end
  end
  if off or #rows == 0 or (queueWin and queueWin:IsShown()) then
    if dock then dock:Hide() end
    return
  end
  if not dock then dock = BuildDock() end
  local f = dock
  f:Show()
  local now = GetServerTime()
  local soonest
  for _, r in ipairs(rows) do if r.expires and (not soonest or r.expires < soonest) then soonest = r.expires end end
  local collapsed = D.settings.dockCollapsed == true
  f.fold:SetLabel(collapsed and "+" or "-")
  if collapsed then
    local left = soonest and (soonest - now) or nil
    f.count:SetText(("%d  ·  %s"):format(#rows, left and Clock(left) or "--"))
    f.count:SetTextColor(unpack(left and DockUrgency(left) or COL.muted))
    for _, r in ipairs(f.rows) do r:Hide() end
    f.more:Hide(); f.hint:Hide()
    f:SetHeight(DOCK_HEAD + 2)
    return
  end
  f.count:SetText(#rows == 1 and "1 item" or (#rows .. " items"))
  f.count:SetTextColor(unpack(COL.muted))
  local shown = math.min(#rows, DOCK_MAX)
  local total, nth = {}, {}
  for _, r in ipairs(rows) do total[r.item] = (total[r.item] or 0) + 1; nth[r.uid] = total[r.item] end
  for i, row in ipairs(f.rows) do
    local r = rows[i]
    if i <= shown and r then
      row:Show()
      row.uid = r.uid
      row.tex:SetTexture(D.ItemIcon(r.item))
      local qr, qg, qb = D.QualityColor(r.item)
      row.iconF:SetBackdropBorderColor(qr, qg, qb, 1)
      row.name:SetTextColor(qr, qg, qb)
      local tag = ""
      if r.status == "won" then tag = "|cff7fb2ff> " .. (D.FirstName(r.winner) or "?") .. "|r"
      elseif r.status == "auction" then tag = "|cffe0b04fAuction|r" end
      row.tag:SetText(tag)
      row.name:SetWidth(tag == "" and 196 or 140) -- a row with no tag gives its room to the item name
      Fit(row.name, D.ItemName(r.item) .. ((total[r.item] or 0) > 1 and (" (" .. nth[r.uid] .. ")") or ""))
      local left = (r.expires or 0) - now
      row.timer:SetText(r.expires and Clock(left) or "--")
      row.timer:SetTextColor(unpack(r.expires and DockUrgency(left) or COL.muted))
    else
      row:Hide(); row.uid = nil
    end
  end
  local y = DOCK_HEAD + 3 + shown * DOCK_ROW
  if #rows > shown then
    f.more:ClearAllPoints(); f.more:SetPoint("TOPLEFT", 10, -y - 2)
    f.more:SetText(("+%d more in the Loot Queue"):format(#rows - shown)); f.more:Show()
    y = y + 16
  else
    f.more:Hide()
  end
  f.hint:ClearAllPoints(); f.hint:SetPoint("TOPLEFT", 10, -y - 2); f.hint:Show()
  f:SetHeight(y + 18)
end

function D.DockSlash(rest)
  rest = (rest or ""):lower()
  if rest == "reset" then
    D.settings.pos[DOCK_NAME] = nil
    D.settings.dockCollapsed = false
    D.settings.lootDock = true
    if dock then dock:ClearAllPoints(); dock:SetPoint("LEFT", 24, 140) end
    D.Print("Loot tracker moved back to its default spot.")
  elseif rest == "on" or rest == "off" then
    D.settings.lootDock = (rest == "on")
    D.Print("Loot tracker " .. (D.settings.lootDock and "on." or "off."))
  elseif rest == "collapse" then
    D.settings.dockCollapsed = not D.settings.dockCollapsed
  else
    D.settings.lootDock = (D.settings.lootDock == false)
    D.Print("Loot tracker " .. (D.settings.lootDock and "on." or "off."))
  end
  D.RefreshDock()
end

---------------------------------------------------------------------------
-- Auction control (officer running it)
---------------------------------------------------------------------------
local aucWin
local function BuildAuction()
  local f = Window("GuildLadderDKPAuction", "AUCTION", 600, 550, "BOTTOMRIGHT", -16, 16)
  -- v0.2.22: Escape (clearing a target mid-raid) used to close this and lose
  -- sight of the bids. Only the X closes it now.
  for i = #UISpecialFrames, 1, -1 do
    if UISpecialFrames[i] == "GuildLadderDKPAuction" then table.remove(UISpecialFrames, i) end
  end
  f.title:Hide(); f.crest:Hide() -- v0.9.0: the auction head shows the item
  f.icon = Icon(f.head, 36); f.icon:SetPoint("LEFT", 12, 0)
  f.item = Text(f.head, 15, COL.text, "GameFontNormal"); f.item:SetPoint("TOPLEFT", f.icon, "TOPRIGHT", 10, -2); f.item:SetWidth(380)
  f.sub:ClearAllPoints(); f.sub:SetPoint("TOPLEFT", f.item, "BOTTOMLEFT", 0, -4); f.sub:SetWidth(380)
  f.clock = Text(f.head, 24, COL.gold, "GameFontNormalLarge"); f.clock:SetPoint("RIGHT", -46, 0); f.clock:SetJustifyH("RIGHT")

  f.rules = Text(f, 11, COL.muted); f.rules:SetPoint("TOPLEFT", 14, -58)
  local cols = { { "Bidder", 14 }, { "Bid", 250 }, { "Balance", 310 }, { "Items", 385 }, { "Last item", 435 }, { "Attend", 530 } }
  for _, c in ipairs(cols) do
    local h = Text(f, 10, COL.muted, "GameFontNormalSmall"); h:SetPoint("TOPLEFT", c[2], -82); h:SetText(c[1]:upper())
  end
  local l1 = Line(f); l1:SetPoint("TOPLEFT", 1, -98); l1:SetPoint("TOPRIGHT", -1, -98)

  f.list = List(f, 40, 7, function(parent)
    local r = CreateFrame("Button", nil, parent, BD)
    Skin(r, { 0, 0, 0, 0 }, { 0, 0, 0, 0 })
    -- left-click: pick this bidder as the winner; right-click: award options
    r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    r:SetScript("OnClick", function(self, button)
      local b = self.bid
      if not b or b.rejected or not D.auction then return end
      if button == "RightButton" then
        local price = D.PriceFor(D.auction, b.name) or b.amount
        D.ShowMenu(self, b.name, {
          { ("Award to %s for %d DKP"):format(D.FirstName(b.name), price), function() D.AwardAuction(true, b.name, price) end },
          { "Award to them for a different price...", function()
            D.auction.pick = b.name
            StaticPopup_Show("GLDKP_AUCAWARD", D.ItemName(D.auction.item))
          end },
          { D.auction.pick == b.name and "Unpick (back to highest bid)" or "Pick as winner", function() D.PickBidder(b.name) end },
        })
      else
        D.PickBidder(b.name)
      end
    end)
    r.name = Text(r, 12, COL.text, "GameFontNormal"); r.name:SetPoint("TOPLEFT", 14, -5); r.name:SetWidth(220)
    r.tags = Text(r, 10, COL.muted); r.tags:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -3); r.tags:SetWidth(230)
    r.c = {}
    for i, x in ipairs({ 250, 310, 385, 435, 530 }) do
      r.c[i] = Text(r, 12, COL.text); r.c[i]:SetPoint("LEFT", x, 0)
    end
    local ln = Line(r); ln:SetPoint("BOTTOMLEFT"); ln:SetPoint("BOTTOMRIGHT")
    return r
  end)
  f.list:SetPoint("TOPLEFT", 1, -99); f.list:SetPoint("TOPRIGHT", -1, -99); f.list:SetHeight(280)
  f.counts = Text(f, 11, COL.muted); f.counts:SetPoint("TOPLEFT", 14, -384)

  local foot = CreateFrame("Frame", nil, f, BD)
  foot:SetPoint("BOTTOMLEFT", 1, 1); foot:SetPoint("BOTTOMRIGHT", -1, 1); foot:SetHeight(140)
  Skin(foot, COL.head, { 0, 0, 0, 0 })
  f.lead = Text(foot, 13, COL.text); f.lead:SetPoint("TOPLEFT", 14, -12); f.lead:SetWidth(570)
  f.award = Btn(foot, "AWARD", 280, 34, "primary", function()
    if D.auction and D.auction.closed and not D.AuctionResult() then D.NoBidsAuction() else D.AwardAuction(true) end
  end)
  f.award:SetPoint("TOPLEFT", 14, -36)
  f.closeNow = Btn(foot, "Close now", 140, 34, "secondary", function() D.CloseAuctionNow() end)
  f.closeNow:SetPoint("LEFT", f.award, "RIGHT", 6, 0)
  f.extend = Btn(foot, "+10 sec", 132, 34, "secondary", function() D.ExtendAuction(10) end)
  f.extend:SetPoint("LEFT", f.closeNow, "RIGHT", 6, 0)
  f.other = Btn(foot, "Other winner / price...", 280, 24, "secondary", function()
    if D.auction then StaticPopup_Show("GLDKP_AUCAWARD", D.ItemName(D.auction.item)) end
  end)
  f.other:SetPoint("TOPLEFT", f.award, "BOTTOMLEFT", 0, -6)
  f.cancel = Btn(foot, "Cancel auction (back to queue)", 284, 24, "ghost", function() D.CancelAuction() end)
  f.cancel:SetPoint("LEFT", f.other, "RIGHT", 6, 0)
  -- v0.2.29: send it to DE / the bank right from here
  local function NoSale(outcome)
    local a = D.auction
    if not a then return end
    if D.AuctionResult(a) then
      StaticPopup_Show("GLDKP_AUCNOSALE", outcome == "de" and "Disenchant" or "Send to the guild bank", nil, outcome)
    else
      D.NoBidsAuction(outcome)
    end
  end
  f.de = Btn(foot, "Disenchant", 280, 24, "secondary", function() NoSale("de") end)
  f.de:SetPoint("TOPLEFT", f.other, "BOTTOMLEFT", 0, -6)
  f.bank = Btn(foot, "Guild bank", 284, 24, "secondary", function() NoSale("bank") end)
  f.bank:SetPoint("LEFT", f.de, "RIGHT", 6, 0)
  f:SetScript("OnShow", function() D.RefreshAuction() end)
  aucWin = f
end

function D.ShowAuction() if not aucWin then BuildAuction() end aucWin:Show() end

function D.RefreshAuction()
  local f = aucWin
  if not f or not f:IsShown() then return end
  local a = D.auction
  if not a then
    f.item:SetText("No auction running")
    f.item:SetTextColor(unpack(COL.muted))
    f.sub:SetText("Start one from the loot queue (Alt-click a row or press Start auction)")
    f.clock:SetText("")
    f.rules:SetText("")
    f.list:SetData({}, function() end)
    f.counts:SetText("")
    f.lead:SetText("")
    for _, b in ipairs({ f.award, f.closeNow, f.extend, f.cancel, f.other, f.de, f.bank }) do b:Disable() end
    return
  end
  f.icon:SetItem(a.item)
  f.item:SetText(D.ItemName(a.item))
  f.item:SetTextColor(D.QualityColor(a.item))
  local note = D.ItemNote(a.item)
  local equipLoc = D.GetItemInfoInstant and select(4, D.GetItemInfoInstant(a.item))
  f.sub:SetText(((equipLoc and _G[equipLoc]) or "") .. (note and note.note and (" · Officer note: " .. note.note) or ""))
  local left = a.endsLocal - GetTime()
  f.clock:SetText(a.closed and "CLOSED" or Clock(left))
  f.rules:SetText(("%s · min %d · +%d steps · raid + whisper bids%s"):format(
    a.mode == "sealed" and "Sealed · winner pays 2nd-highest bid" or "Open · highest bid pays", a.min, a.step,
    a.practice and " · PRACTICE" or ""))

  local rows = {}
  local _, _, sorted = D.AuctionResult(a)
  local who, price, wspec, picked = D.AuctionPick(a)
  local roll = a.roll
  for _, b in ipairs(sorted or {}) do rows[#rows + 1] = b end
  for name, why in pairs(a.rejected) do rows[#rows + 1] = { name = name, rejected = why } end
  local wishers = {}
  for _, n in ipairs(D.Wishers(a.item)) do wishers[n] = true end
  f.list:SetData(rows, function(r, b)
    r.bid = b
    local class = D.ClassOf(b.name)
    local cname = class and LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[class] or ""
    r.name:SetText(b.name .. (cname ~= "" and ("  |cffa7afba" .. cname .. "|r") or ""))
    local items, last = D.ItemsThisPhase(b.name)
    local tags = {}
    if b.rejected then tags[#tags + 1] = "|cffff7a6b" .. b.rejected .. "|r" end
    if roll and roll.score[b.name] then
      if roll.rolled[b.name] then tags[#tags + 1] = ("|cffe0b04fRolled %d|r"):format(roll.rolled[b.name])
      elseif roll.waiting[b.name] and not roll.done then tags[#tags + 1] = "|cffe0b04fWaiting to roll|r"
      else tags[#tags + 1] = "|cffa7afbaLost the roll|r" end
    end
    if picked and who == b.name then tags[#tags + 1] = "|cff8fe0c4Picked by you|r" end
    if wishers[b.name] then tags[#tags + 1] = "|cff9ccaffOn wishlist|r" end
    if b.spec == "OS" then tags[#tags + 1] = "|cff9ccaffOff spec|r" end
    if b.via == "whisper" then tags[#tags + 1] = "|cfff2a54aWhisper bid|r" end
    local main = D.MainOf(b.name)
    if main then tags[#tags + 1] = "alt of " .. D.FirstName(main) end
    if not D.roster[b.name] then tags[#tags + 1] = "|cfff2a54aNot in guild|r" end
    r.tags:SetText(table.concat(tags, " · "))
    r.c[1]:SetText(b.rejected and "-" or tostring(b.amount))
    r.c[2]:SetText(tostring(D.Balance(b.name)))
    r.c[3]:SetText(tostring(items))
    r.c[4]:SetText(D.Ago(last))
    r.c[5]:SetText(D.Attendance(b.name) .. "%")
    r:SetBackdropColor(unpack((who == b.name and not b.rejected) and COL.sel or { 0, 0, 0, 0 }))
    r:SetAlpha(b.rejected and 0.6 or 1)
  end)
  local passes = 0
  for _ in pairs(a.passes) do passes = passes + 1 end
  f.counts:SetText(("%d passed · click a bidder to pick the winner, right-click for more"):format(passes))
  local rolling = roll and not roll.done
  if who then
    f.lead:SetText(("%s |cffffffff%s|r   pays |cffe0b04f%d|r%s"):format(picked and "Picked:" or roll and "Won the roll:" or "Leading:",
      who, price, wspec == "OS" and " (off spec)" or a.mode == "sealed" and " (second-highest bid)" or ""))
    f.award:SetLabel(("AWARD TO %s · %d"):format(D.FirstName(who):upper(), price))
  elseif rolling then
    local wait = {}
    for n in pairs(roll.waiting) do if not roll.rolled[n] then wait[#wait + 1] = D.FirstName(n) end end
    table.sort(wait)
    f.lead:SetText(("Tie at %d - roll-off%s: waiting for |cffffffff%s|r"):format(roll.amount,
      roll.round > 1 and (" (round %d)"):format(roll.round) or "", table.concat(wait, ", ")))
    f.award:SetLabel("WAITING FOR ROLLS")
  else
    f.lead:SetText(a.closed and "No bids." or "Waiting for bids...")
    f.award:SetLabel(a.closed and "NO BIDS" or "AWARD")
  end
  f.award:SetEnabled(who ~= nil or (a.closed and not rolling and not sorted))
  f.other:SetEnabled(true)
  f.closeNow:SetEnabled(not a.closed)
  f.extend:Enable()
  f.cancel:Enable()
  -- once bidding is closed (Close now ends it early if you already know)
  f.de:SetEnabled(a.closed and not rolling or false)
  f.bank:SetEnabled(a.closed and not rolling or false)
end

---------------------------------------------------------------------------
-- Bid popup (every raider)
---------------------------------------------------------------------------
local pop
local function BuildPopup()
  local f = CreateFrame("Frame", "GuildLadderDKPBid", UIParent, BD)
  f:SetSize(380, 268)
  Skin(f)
  f:SetFrameStrata("DIALOG")
  f:SetToplevel(true)
  f:SetClampedToScreen(true)
  f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
  if SavedScale("GuildLadderDKPBid") then f:SetScale(SavedScale("GuildLadderDKPBid")) end -- v0.2.30
  local pos = D.settings.pos.GuildLadderDKPBid
  if pos then f:SetPoint(pos[1], UIParent, pos[1], pos[2], pos[3]) else f:SetPoint("CENTER", 0, -30) end
  Grip(f, "GuildLadderDKPBid") -- v0.2.30: drag the corner to scale
  f:SetScript("OnDragStart", function() f:Raise(); f:StartMoving() end)
  f:SetScript("OnDragStop", function()
    f:StopMovingOrSizing()
    local p, _, _, x, y = f:GetPoint()
    D.settings.pos.GuildLadderDKPBid = { p, x, y }
  end)
  f.icon = Icon(f, 40); f.icon:SetPoint("TOPLEFT", 14, -14)
  f.item = Text(f, 14, COL.text, "GameFontNormal"); f.item:SetPoint("TOPLEFT", f.icon, "TOPRIGHT", 10, -2); f.item:SetWidth(270)
  f.chip1 = Chip(f); f.chip1:SetPoint("TOPLEFT", f.item, "BOTTOMLEFT", 0, -5)
  f.chip2 = Chip(f); f.chip2:SetPoint("LEFT", f.chip1, "RIGHT", 6, 0)
  local x = Btn(f, "X", 24, 24, "ghost", function() f:Hide() end); x:SetPoint("TOPRIGHT", -8, -8)

  f.bar = CreateFrame("StatusBar", nil, f)
  f.bar:SetPoint("TOPLEFT", 14, -66); f.bar:SetPoint("TOPRIGHT", -14, -66); f.bar:SetHeight(5)
  f.bar:SetStatusBarTexture(WHITE); f.bar:SetStatusBarColor(COL.gold[1], COL.gold[2], COL.gold[3])
  f.bar:SetMinMaxValues(0, 1)
  local bbg = f.bar:CreateTexture(nil, "BACKGROUND"); bbg:SetAllPoints(); bbg:SetColorTexture(0.17, 0.19, 0.23, 1)
  f.rules = Text(f, 10, COL.muted); f.rules:SetPoint("TOPLEFT", f.bar, "BOTTOMLEFT", 0, -5); f.rules:SetWidth(290)
  f.clock = Text(f, 11, COL.text); f.clock:SetPoint("TOPRIGHT", f.bar, "BOTTOMRIGHT", 0, -5); f.clock:SetJustifyH("RIGHT")

  -- v0.2.32: quick buttons first, then the bid box with Your DKP right under it
  f.eb = Edit(f, 96, true); f.eb:SetPoint("TOPLEFT", 22, -146)
  local yl = Text(f, 12, COL.muted); yl:SetPoint("TOPLEFT", f.eb, "BOTTOMLEFT", -8, -10); yl:SetText("Your DKP:")
  f.bal = Text(f, 16, COL.gold, "GameFontNormalLarge"); f.bal:SetPoint("LEFT", yl, "RIGHT", 6, 0)
  local function Cur() return tonumber(f.eb:GetText()) or 0 end
  -- v0.2.26: flash the box so a click always visibly lands, even when the
  -- amount was already the minimum (which is why "Min" looked dead before)
  local flash = f.eb:CreateTexture(nil, "OVERLAY")
  flash:SetAllPoints(); flash:SetColorTexture(COL.gold[1], COL.gold[2], COL.gold[3], 0.35); flash:Hide()
  local function SetBid(v)
    f.eb:SetText(tostring(math.max(0, math.floor(v))))
    flash:Show(); C_Timer.After(0.25, function() flash:Hide() end)
  end
  -- v0.2.27: Min is the item's configured minimum, never "beat the high bid".
  -- Bids are sealed - a Min click must never turn into a winning bid.
  local function Floor(i)
    return tonumber(i.min) or 0
  end
  D.BidFloor = Floor
  local qb = {
    -- v0.2.28: one click places a main-spec bid at the configured minimum
    { "Bid Min", function(i)
      SetBid(Floor(i))
      i.passed = nil
      D.SendBid(i.aid, Floor(i), "MS")
    end },
    { "+10", function(i) SetBid(math.max(Cur(), Floor(i)) + 10) end },
    { "+25", function(i) SetBid(math.max(Cur(), Floor(i)) + 25) end },
    -- v0.2.32: places the bid like Bid Min does. +10 / +25 only change the amount.
    { "Bid All-in", function(i)
      local bal = math.floor(i.myBal or D.Balance(D.Me()) or 0)
      SetBid(bal)
      if bal > 0 then
        i.passed = nil
        D.SendBid(i.aid, bal, "MS")
      end
    end },
  }
  local prev
  for _, q in ipairs(qb) do
    local b = Btn(f, q[1], 84, 30, "secondary", function() if f.info then q[2](f.info) end end)
    if prev then b:SetPoint("LEFT", prev, "RIGHT", 6, 0) else b:SetPoint("TOPLEFT", 14, -100) end
    prev = b
  end
  f.bid = Btn(f, "BID MS", 116, 28, "primary", function()
    if f.info and Cur() > 0 then f.info.passed = nil; D.SendBid(f.info.aid, Cur(), "MS") end
  end)
  f.bid:SetPoint("LEFT", f.eb, "RIGHT", 8, 0)
  f.os = Btn(f, "BID OS", 116, 28, "secondary", function()
    if f.info and (Cur() > 0 or (f.info.osPrice or 0) > 0) then f.info.passed = nil; D.SendBid(f.info.aid, Cur(), "OS") end
  end)
  f.os:SetPoint("LEFT", f.bid, "RIGHT", 6, 0)
  f.pass = Btn(f, "Pass", 70, 24, "ghost", function() if f.info then D.SendPass(f.info.aid) end end)
  f.pass:SetPoint("TOPRIGHT", f.os, "BOTTOMRIGHT", 0, -6)
  f.eb:SetScript("OnEnterPressed", function(self) self:ClearFocus(); f.bid:Click() end)
  f.status = Text(f, 11, COL.teal); f.status:SetPoint("TOPLEFT", 14, -208); f.status:SetWidth(350)
  local foot = Line(f); foot:SetPoint("BOTTOMLEFT", 1, 32); foot:SetPoint("BOTTOMRIGHT", -1, 32)
  f.hint = Text(f, 10, COL.muted); f.hint:SetPoint("BOTTOMLEFT", 14, 12); f.hint:SetWidth(350)
  Ticker(f, function() if f:IsShown() then D.UpdateBidPopup() end end, 0.25)
  f:Hide()
  -- v0.2.25: closed while bidding is still open (the X, or anything other
  -- than Pass / the auction ending) -> leave the click-to-reopen bar on screen
  f:HookScript("OnHide", function(self)
    if self.quiet then self.quiet = nil return end
    local i = self.info
    if i and D.bidding[i.aid] and i.endsLocal > GetTime() and D.ShowBidBar then D.ShowBidBar(i) end
  end)
  pop = f
end

---------------------------------------------------------------------------
-- Reopen bar (v0.2.25): a small countdown with the item name, CLM-style.
-- Left-click brings the bid window back exactly as you left it.
-- Right-drag moves it.
---------------------------------------------------------------------------
local bar
local function BuildBidBar()
  local b = CreateFrame("Button", "GuildLadderDKPBidBar", UIParent, BD)
  b:SetSize(280, 40)
  Skin(b, COL.bg, { COL.gold[1], COL.gold[2], COL.gold[3], 1 })
  b:SetFrameStrata("HIGH")
  b:SetClampedToScreen(true)
  b:SetMovable(true)
  b:RegisterForClicks("LeftButtonUp")
  b:RegisterForDrag("RightButton")
  if SavedScale("GuildLadderDKPBidBar") then b:SetScale(SavedScale("GuildLadderDKPBidBar")) end -- v0.2.30
  local pos = D.settings.pos.GuildLadderDKPBidBar
  if pos then b:SetPoint(pos[1], UIParent, pos[1], pos[2], pos[3]) else b:SetPoint("TOP", 0, -262) end
  WheelScale(b, b, "GuildLadderDKPBidBar") -- v0.2.30: Ctrl + mouse wheel to scale
  b:SetScript("OnDragStart", function(self) self:StartMoving() end)
  b:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local p, _, _, x, y = self:GetPoint()
    D.settings.pos.GuildLadderDKPBidBar = { p, x, y }
  end)
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetSize(28, 28); b.icon:SetPoint("LEFT", 7, 1)
  b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  b.item = Text(b, 12, COL.text, "GameFontNormal")
  b.item:SetPoint("TOPLEFT", b.icon, "TOPRIGHT", 8, -1); b.item:SetWidth(180)
  b.item:SetWordWrap(false)
  b.sub = Text(b, 10, COL.muted)
  b.sub:SetPoint("TOPLEFT", b.item, "BOTTOMLEFT", 0, -3); b.sub:SetWidth(180)
  b.sub:SetWordWrap(false)
  b.clock = Text(b, 16, COL.gold, "GameFontNormalLarge")
  b.clock:SetPoint("RIGHT", -10, 1); b.clock:SetJustifyH("RIGHT")
  b.prog = CreateFrame("StatusBar", nil, b)
  b.prog:SetPoint("BOTTOMLEFT", 1, 1); b.prog:SetPoint("BOTTOMRIGHT", -1, 1); b.prog:SetHeight(3)
  b.prog:SetStatusBarTexture(WHITE); b.prog:SetStatusBarColor(COL.gold[1], COL.gold[2], COL.gold[3])
  b.prog:SetMinMaxValues(0, 1)
  b:SetScript("OnClick", function(self) D.ReopenBid(self.info and self.info.aid) end)
  b:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(1, 0.85, 0.45, 1) end)
  b:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(COL.gold[1], COL.gold[2], COL.gold[3], 1) end)
  Ticker(b, function() if b:IsShown() then D.UpdateBidBar() end end, 0.25)
  b:Hide()
  bar = b
end

function D.ShowBidBar(info)
  if not bar then BuildBidBar() end
  bar.info = info
  bar.icon:SetTexture(D.ItemIcon(info.item))
  bar.item:SetText(info.itemName or D.ItemName(info.item))
  if info.itemQuality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[info.itemQuality] then
    local c = ITEM_QUALITY_COLORS[info.itemQuality]
    bar.item:SetTextColor(c.r, c.g, c.b)
  else
    bar.item:SetTextColor(D.QualityColor(info.item))
  end
  bar:Show()
  D.UpdateBidBar()
end

function D.HideBidBar(aid)
  if bar and (not aid or (bar.info and bar.info.aid == aid)) then bar:Hide() end
end

function D.UpdateBidBar()
  if not bar or not bar:IsShown() then return end
  local i = bar.info
  local left = i and (i.endsLocal - GetTime()) or 0
  -- gone: auction over, cancelled, or the bid window is back up
  if not i or not D.bidding[i.aid] or left <= 0 or (pop and pop:IsVisible()) then bar:Hide() return end
  bar.clock:SetText(Clock(left))
  bar.prog:SetValue(left / (i.total or 1))
  if i.passed then
    bar.sub:SetText("Passed  ·  click to bid after all")
    bar.sub:SetTextColor(unpack(COL.muted))
  elseif i.status and i.ok ~= false then
    bar.sub:SetText(i.status .. "  ·  click to change")
    bar.sub:SetTextColor(unpack(COL.teal))
  else
    bar.sub:SetText("Bidding open  ·  click to bid")
    bar.sub:SetTextColor(unpack(COL.muted))
  end
end

-- Bring a bid window back. With no aid, the newest auction still open.
function D.ReopenBid(aid)
  local info = aid and D.bidding[aid]
  if not info then
    for _, x in pairs(D.bidding) do
      if x.endsLocal > GetTime() and (not info or x.endsLocal > info.endsLocal) then info = x end
    end
  end
  if not info or info.endsLocal <= GetTime() then D.Print("No bidding open right now.") return end
  D.HideBidBar()
  if pop and pop.info == info then
    pop:Show() -- same auction: keep the amount typed and the bid status
    D.UpdateBidPopup()
  else
    D.ShowBidPopup(info)
  end
end

function D.ShowBidPopup(info)
  if not pop then BuildPopup() end
  D.HideBidBar()
  info.total = math.max(1, info.endsLocal - GetTime())
  pop.info = info
  pop.icon:SetItem(info.item)
  -- name/quality from the auctioneer's broadcast if my own item cache came up
  -- empty (an item I've never personally seen before)
  pop.item:SetText(info.itemName or D.ItemName(info.item))
  if info.itemQuality then
    local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[info.itemQuality]
    pop.item:SetTextColor(c and c.r or 1, c and c.g or 1, c and c.b or 1)
  else
    pop.item:SetTextColor(D.QualityColor(info.item))
  end
  local wish = false
  for _, n in ipairs(D.Wishers(info.item)) do if D.SameName(n, D.Me()) then wish = true end end
  if wish then pop.chip1:Set("On your wishlist", { 0.086, 0.19, 0.31 }, COL.blue); pop.chip1:Show() else pop.chip1:Hide() end
  local ok, why = D.CanUse(info.item, select(2, UnitClass("player")))
  local upgrade = ok and D.IsUpgrade(info.item, info.itemLevel, info.equipLoc)
  -- v0.6.0: BiS verdict for my spec beats the plain item-level check when we have one
  local bv
  if ok and D.BiS then
    local okv, res = pcall(D.BiS.Verdict, info.item, { ilvl = info.itemLevel, equipLoc = info.equipLoc })
    if okv then bv = res end
  end
  if not ok then
    pop.chip2:Set("Can't use: " .. why, { 0.3, 0.12, 0.1 }, COL.red)
  elseif bv then
    local text, style = D.BiS.Chip(bv)
    local CS = {
      bis = { { 0.30, 0.17, 0.05 }, COL.orange }, alt = { { 0.11, 0.23, 0.2 }, COL.teal },
      soft = { { 0.086, 0.19, 0.31 }, COL.blue }, muted = { { 0.17, 0.19, 0.23 }, COL.muted },
    }
    local c = CS[style] or CS.muted
    pop.chip2:Set(text, c[1], c[2])
  elseif upgrade == nil then
    pop.chip2:Set("Upgrade: unknown (never seen this item)", { 0.17, 0.19, 0.23 }, COL.muted)
  elseif upgrade then
    pop.chip2:Set("Upgrade", { 0.11, 0.23, 0.2 }, COL.teal)
  else
    pop.chip2:Set("Not an item-level upgrade", { 0.17, 0.19, 0.23 }, COL.muted)
  end
  pop.chip2:ClearAllPoints()
  if wish then pop.chip2:SetPoint("LEFT", pop.chip1, "RIGHT", 6, 0) else pop.chip2:SetPoint("TOPLEFT", pop.item, "BOTTOMLEFT", 0, -5) end
  pop.eb:SetText(tostring(info.min or 0))
  info.status, info.ok, info.passed = nil, nil, nil
  pop.hint:SetText(("No add-on? Whisper %s  !bid %d  ·  !os %d  ·  !pass"):format(D.FirstName(info.from) or "the loot officer", info.min or 0, info.min or 0))
  pop:Show()
  D.UpdateBidPopup()
end

function D.UpdateBidPopup()
  local f = pop
  if not f or not f:IsShown() or not f.info then return end
  local i = f.info
  local left = math.max(0, i.endsLocal - GetTime())
  f.bar:SetValue(left / (i.total or 1))
  f.clock:SetText(Clock(left))
  local rule = i.mode == "sealed" and "Sealed · winner pays second-highest bid" or "Open bidding"
  if i.high then rule = ("Open · high bid %d (%s)"):format(i.high, D.FirstName(i.highName) or "?") end
  if i.practice then rule = rule .. " · PRACTICE" end
  f.rules:SetText(rule)
  f.bal:SetText(tostring(i.myBal or D.Balance(D.Me())))
  f.status:SetText(i.status or "")
  f.status:SetTextColor(unpack(i.ok == false and COL.red or COL.teal))
  local open = left > 0
  f.bid:SetEnabled(open)
  f.os:SetEnabled(open)
  -- v0.2.32: say what each button costs. A fixed off-spec price is a flat
  -- charge, not a minimum, so it reads "flat".
  f.bid:SetLabel(("BID MS (min %d)"):format(i.min or 0))
  if (i.osPrice or 0) > 0 then
    f.os:SetLabel(("BID OS (%d flat)"):format(i.osPrice))
  else
    f.os:SetLabel(("BID OS (min %d)"):format(i.min or 0))
  end
end

function D.HideBidPopup(aid)
  if pop and pop.info and (not aid or pop.info.aid == aid) then
    if pop:IsShown() then pop.quiet = true end
    pop:Hide()
  end
  D.HideBidBar(aid)
end

---------------------------------------------------------------------------
-- Trade window helper
---------------------------------------------------------------------------
local tradeBtn
function D.ShowTradeButton(rows)
  if not TradeFrame then return end
  if not tradeBtn then
    tradeBtn = Btn(TradeFrame, "", 260, 30, "primary", function()
      if not D.PlaceNextTradeItem() then tradeBtn:Hide() end
    end)
    tradeBtn:SetPoint("BOTTOM", TradeFrame, "TOP", 0, 6)
  end
  tradeBtn:SetLabel(("ADD %s TO TRADE"):format(D.ItemName(rows[1].item):upper()) .. (#rows > 1 and (" (+" .. (#rows - 1) .. ")") or ""))
  tradeBtn:Show()
end
function D.HideTradeButton() if tradeBtn then tradeBtn:Hide() end end

---------------------------------------------------------------------------
-- Main window: Standings + log / Raid night / Wishlists / Settings
---------------------------------------------------------------------------
local main, pages, tabs, filterName = nil, {}, {}, nil

local function LogLine(e)
  local amt, text = tonumber(e.v) or 0, ""
  local names = D.SplitNames(e.p)
  if e.k == "AW" then
    text = ("%s · %d player%s"):format(e.r or "Award", #names, #names == 1 and "" or "s")
    return text, "+" .. amt, COL.teal
  elseif e.k == "AD" then
    return ("%s: %s"):format(e.p or "?", e.r or "Adjustment"), (amt >= 0 and "+" or "") .. amt, amt >= 0 and COL.teal or COL.red
  elseif e.k == "SP" then
    return ("%s won %s%s"):format(e.p or "?", e.r or D.ItemName(tonumber(e.x)), e.u == "OS" and " (off spec)" or ""), "-" .. amt, COL.red
  elseif e.k == "HL" then
    return ("%s won %s%s · from CLM"):format(e.p or "?", e.r or D.ItemName(tonumber(e.x)), e.u == "OS" and " (off spec)" or ""), amt .. " (CLM)", COL.muted
  elseif e.k == "SB" then
    return ("%s: starting balance"):format(e.p or "?"), "+" .. amt, COL.teal
  elseif e.k == "DC" then
    return "Weekly decay", "-" .. amt .. "%", COL.red
  elseif e.k == "UN" then
    local t
    for _, x in ipairs(D.data.log) do if x.id == e.u then t = x end end
    return "Undo: " .. (t and (LogLine(t)) or "entry"), "undo", COL.muted
  elseif e.k == "IN" then
    return ("Item note: %s %s%s"):format(D.ItemName(tonumber(e.x)), e.r or "", e.v and (" (min " .. e.v .. ")") or ""), "", COL.muted
  elseif e.k == "SN" then
    return "Raid started: " .. (e.r or "?"), "", COL.gold
  elseif e.k == "SE" then
    return ("Raid ended: %s · %d attended"):format(e.r or "?", #names), "", COL.gold
  elseif e.k == "AO" then
    return (e.x and e.x ~= "") and ("%s linked as alt of %s"):format(e.p or "?", e.x) or ("%s unlinked"):format(e.p or "?"), "", COL.muted
  elseif e.k == "LK" then
    if not e.x or e.x == "" then return ("Unlinked %s from Discord"):format(e.p or "?"), "", COL.muted end
    return ("Linked %s to Discord"):format(e.p or "?"), "", COL.muted
  elseif e.k == "HD" then
    return (e.v == "1" and "%s: removed from standings" or "%s: restored to standings"):format(e.p or "?"), "", COL.muted
  elseif e.k == "PD" then -- v1.5.0
    return ("Raid award: %s · %s"):format(e.p or "?", D.PodiumAwardName and D.PodiumAwardName(e.u) or e.u or "?"), "", COL.gold
  end
  return e.k, "", COL.muted
end

local function Involves(e, name)
  if not name then return true end
  -- v0.2.36: decay has no name list - it involves everyone it took DKP from
  if e.k == "DC" then
    local loss = D.data.decayLoss and D.data.decayLoss[e.id]
    return loss and loss[name] ~= nil or false
  end
  for _, n in ipairs(D.SplitNames(e.p)) do if n == name then return true end end
  return false
end

-- v0.3.0: an award for a big raid is stored in parts (one add-on message
-- can't hold 26 names). The log shows those parts as one line.
local MERGE = { AW = true, SE = true, UN = true, PD = true } -- v1.5.0: PD = one raid award each
local function TypeOf(e)
  if e.k == "SP" or e.k == "HL" then return "loot" end
  if e.k == "AW" then return e.x == "BOSS" and "boss" or "award" end
  if e.k == "AD" or e.k == "SB" then return "adjust" end
  if e.k == "DC" then return "decay" end
  if e.k == "SN" or e.k == "SE" or e.k == "PD" then return "raid" end
  if e.k == "UN" then return "undo" end
  return "other"
end
local function MergeKey(e, byId)
  if not MERGE[e.k] then return nil end
  local t = e
  if e.k == "UN" then
    t = byId[e.u]
    if not t or not MERGE[t.k] then return nil end
  end
  return table.concat({ e.k, e.by or "", t.k or "", t.r or "", tostring(t.v or ""), t.x or "", t.g or "" }, "\1")
end
-- newest first: { e = newest part, ids = { ... }, n = players across parts, undone = every part undone }
function D.LogGroups(keep, limit)
  local byId = {}
  for _, e in ipairs(D.data.log) do byId[e.id] = e end
  local out, last = {}, nil
  for i = #D.data.log, 1, -1 do
    local e = D.data.log[i]
    if keep(e) then
      local key = MergeKey(e, byId)
      local names = #D.SplitNames((e.k == "UN" and byId[e.u] or e).p)
      if key and last and last.key == key and math.abs((last.e.t or 0) - (e.t or 0)) <= 10 then
        last.ids[#last.ids + 1] = e.id
        last.n = last.n + names
        if not D.data.undone[e.id] then last.undone = false end
      else
        if #out >= (limit or 500) then break end
        last = { e = e, key = key, ids = { e.id }, n = names, undone = D.data.undone[e.id] and true or false }
        out[#out + 1] = last
      end
    end
  end
  return out, byId
end

local function GroupLine(g, byId)
  local e = g.e
  if #g.ids > 1 or e.k == "UN" then
    local t = e.k == "UN" and byId[e.u] or e
    local base
    if t and t.k == "AW" then base = ("%s · %d player%s"):format(t.r or "Award", g.n, g.n == 1 and "" or "s")
    elseif t and t.k == "SE" then base = ("Raid ended: %s · %d attended"):format(t.r or "?", g.n)
    elseif t and t.k == "PD" then base = ("Raid awards: %s · %d award%s"):format(t.r or "?", g.n, g.n == 1 and "" or "s") -- v1.5.0
    elseif t then base = (LogLine(t))
    else base = "entry" end
    if e.k == "UN" then return "Undo: " .. base, "undo", COL.muted end
    local _, amt, color = LogLine(e)
    return base, amt, color
  end
  return LogLine(e)
end

-- the add-player menu (Standings), shared
local function AddPlayerMenu(self)
  local hidden, missing = D.HiddenPlayers(), D.MissingPlayers()
  if #hidden == 0 and #missing == 0 then
    StaticPopup_Show("GLDKP_ADDPLAYER")
    return
  end
  local items = { { "Type a name...", function() StaticPopup_Show("GLDKP_ADDPLAYER") end } }
  for _, n in ipairs(hidden) do
    items[#items + 1] = { (D.FirstName(n) or n) .. " (restore)", function() D.SetHidden(n, false) end }
  end
  for _, n in ipairs(missing) do
    items[#items + 1] = { D.FirstName(n) or n, function() D.AddPlayer(n, 0, "Added to standings") end }
  end
  D.ShowMenu(self, "Add to standings", items)
end

-- a gold-trimmed button in the faction colour
local function ThemeBtn(parent, label, w, h, onClick)
  local th = Theme()
  local b = Btn(parent, label, w, h, "secondary", onClick)
  b:SetBackdropColor(unpack(th.deep))
  b:SetBackdropBorderColor(unpack(GOLD_DIM))
  b.label:SetTextColor(0.95, 0.84, 0.54)
  b:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(unpack(GOLD_DIM)) end)
  return b
end

---------------------------------------------------------------------------
-- v0.3.0 Standings: the whole list, plus a card for the selected player.
-- The log moved to its own Logs page.
---------------------------------------------------------------------------
local function BuildStandings(p)
  local th = Theme()
  local panel = CreateFrame("Frame", nil, p, BD)
  panel:SetPoint("TOPLEFT", 10, -10); panel:SetPoint("BOTTOMLEFT", 10, 10); panel:SetWidth(460)
  Skin(panel, PANEL, COL.line)
  local title = Text(panel, 18, COL.gold); title:SetFont(TITLE_FONT, 20); title:SetPoint("TOPLEFT", 12, -9); title:SetText("Standings")
  p.count = Text(panel, 10, COL.muted); p.count:SetPoint("BOTTOMLEFT", title, "BOTTOMRIGHT", 10, 3)
  p.addBtn = Btn(panel, "+ Add player", 110, 22, "secondary", AddPlayerMenu)
  p.addBtn:SetPoint("TOPRIGHT", -8, -8)
  local h1 = Text(panel, 10, COL.muted, "GameFontNormalSmall"); h1:SetPoint("TOPLEFT", 14, -42); h1:SetText("#")
  local h2 = Text(panel, 10, COL.muted, "GameFontNormalSmall"); h2:SetPoint("TOPLEFT", 68, -42); h2:SetText("PLAYER")
  local h3 = Text(panel, 10, COL.muted, "GameFontNormalSmall"); h3:SetPoint("TOPRIGHT", -14, -42); h3:SetJustifyH("RIGHT"); h3:SetText("DKP")
  local hl = Line(panel); hl:SetPoint("TOPLEFT", 1, -55); hl:SetPoint("TOPRIGHT", -1, -55)

  p.list = List(panel, 26, 14, function(parent)
    local r = CreateFrame("Button", nil, parent, BD)
    Skin(r, { 0, 0, 0, 0 }, { 0, 0, 0, 0 })
    r.bar = r:CreateTexture(nil, "ARTWORK"); r.bar:SetColorTexture(COL.gold[1], COL.gold[2], COL.gold[3], 1)
    r.bar:SetPoint("TOPLEFT"); r.bar:SetPoint("BOTTOMLEFT"); r.bar:SetWidth(3)
    r.rank = Text(r, 11, COL.muted); r.rank:SetPoint("LEFT", 12, 0); r.rank:SetWidth(28)
    r.cls = r:CreateTexture(nil, "ARTWORK"); r.cls:SetSize(18, 18); r.cls:SetPoint("LEFT", 42, 0)
    r.name = Text(r, 13, COL.text); r.name:SetPoint("LEFT", 68, 0); r.name:SetWidth(290)
    r.dkp = Text(r, 13, COL.gold, "GameFontNormal"); r.dkp:SetPoint("RIGHT", -14, 0); r.dkp:SetJustifyH("RIGHT")
    -- v0.7.3: badge icons right after the name; hover for what each one is
    r.badges = Text(r, 11, COL.text); r.badges:SetJustifyH("LEFT")
    r:SetScript("OnEnter", function(self)
      local bs = self.player and D.Badges(self.player)
      if not bs or #bs == 0 then return end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine((D.FirstName(self.player) or self.player) .. "  ·  badges", 1, 1, 1)
      for _, b in ipairs(bs) do
        GameTooltip:AddLine(D.BadgeInline(b.label, 16) .. " |c" .. b.hex .. b.label .. "|r  |cffa7afba" .. b.tip .. "|r", 1, 1, 1)
      end
      GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    r:SetScript("OnClick", function(self, button)
      if button == "RightButton" then
        if D.IsAdmin() or D.practice then D.ShowPlayerMenu(self, self.player) end
      else
        filterName = self.player
        D.Refresh()
      end
    end)
    return r
  end)
  p.list:SetPoint("TOPLEFT", 1, -57); p.list:SetPoint("TOPRIGHT", -1, -57); p.list:SetHeight(26 * 14)

  -- selected player card
  local card = CreateFrame("Frame", nil, p, BD)
  card:SetPoint("TOPLEFT", 480, -10); card:SetPoint("BOTTOMRIGHT", -10, 10)
  Skin(card, PANEL, COL.line)
  local ch = Text(card, 10, COL.muted, "GameFontNormalSmall"); ch:SetPoint("TOPLEFT", 14, -12); ch:SetText("SELECTED PLAYER")
  local iconFrame = CreateFrame("Frame", nil, card, BD)
  iconFrame:SetSize(44, 44); iconFrame:SetPoint("TOPLEFT", 14, -32)
  Skin(iconFrame, { 0.1, 0.1, 0.12, 1 }, GOLD_DIM)
  card.icon = iconFrame:CreateTexture(nil, "ARTWORK"); card.icon:SetPoint("TOPLEFT", 2, -2); card.icon:SetPoint("BOTTOMRIGHT", -2, 2)
  card.name = Text(card, 20, COL.text); card.name:SetFont(TITLE_FONT, 20)
  card.name:SetPoint("TOPLEFT", iconFrame, "TOPRIGHT", 10, -2); card.name:SetWidth(165)
  card.sub = Text(card, 11, COL.muted); card.sub:SetPoint("TOPLEFT", card.name, "BOTTOMLEFT", 0, -4); card.sub:SetWidth(165)
  local box = CreateFrame("Frame", nil, card, BD)
  box:SetPoint("TOPLEFT", 14, -90); box:SetPoint("TOPRIGHT", -14, -90); box:SetHeight(72)
  Skin(box, { 0.1, 0.105, 0.13, 1 }, GOLD_DIM)
  local bl = Text(box, 11, COL.muted); bl:SetPoint("TOPLEFT", 12, -9); bl:SetText("Current DKP")
  card.dkp = Text(box, 32, COL.gold); card.dkp:SetFont(TITLE_FONT, 32); card.dkp:SetPoint("BOTTOMLEFT", 12, 6)
  card.alts = Text(card, 11, COL.muted); card.alts:SetPoint("TOPLEFT", 14, -176); card.alts:SetWidth(220)
  card.alts:SetWordWrap(true); card.alts:SetJustifyV("TOP"); card.alts:SetHeight(44)
  -- v1.5.0: Podium awards (how often each was won) replace the old hint line; the full history is one click away (View in Logs)
  local pdh = Text(card, 10, COL.muted, "GameFontNormalSmall"); pdh:SetPoint("TOPLEFT", 14, -224); pdh:SetText("PODIUM AWARDS")
  card.awards = Text(card, 11, COL.text); card.awards:SetPoint("TOPLEFT", 14, -238); card.awards:SetWidth(221)
  card.awards:SetWordWrap(true); card.awards:SetJustifyV("TOP"); card.awards:SetHeight(38)
  -- v1.6.0: award icons with counts; hover for the full list
  card.awardHit = CreateFrame("Frame", nil, card)
  card.awardHit:SetPoint("TOPLEFT", 14, -238); card.awardHit:SetSize(221, 38); card.awardHit:EnableMouse(true)
  card.awardHit:SetScript("OnEnter", function(self) if card.player and D.ShowPodiumAwardTip then D.ShowPodiumAwardTip(self, card.player) end end)
  card.awardHit:SetScript("OnLeave", function() GameTooltip:Hide() end)
  card.logs = ThemeBtn(card, "View in Logs", 221, 30, function() if card.player then D.ShowLogsFor(card.player) end end)
  card.logs:SetPoint("BOTTOMLEFT", 14, 52)
  card.adjust = Btn(card, "Adjust DKP...", 221, 30, "secondary", function(self) if card.player then D.ShowPlayerMenu(self, card.player) end end)
  card.adjust:SetPoint("BOTTOMLEFT", 14, 14)
  -- v0.5.0: badges earned (from the ledger) and a shortcut to this player's recap
  local bgh = Text(card, 10, COL.muted, "GameFontNormalSmall"); bgh:SetPoint("TOPLEFT", 14, -278); bgh:SetText("BADGES")
  card.badges = Text(card, 11, COL.text); card.badges:SetPoint("TOPLEFT", 14, -293); card.badges:SetWidth(221)
  card.badges:SetWordWrap(true); card.badges:SetJustifyV("TOP"); card.badges:SetHeight(64)
  card.recap = Btn(card, "Recap", 64, 20, "secondary", function()
    if card.player then
      D.recapName = card.player
      D.SetHallView("recap")
      D.Toggle("fame", true)
    end
  end)
  card.recap:SetPoint("TOPRIGHT", -14, -8)
  p.card = card

  function p:Update()
    local admin = D.IsAdmin() or D.practice
    self.addBtn:SetShown(admin)
    local st = D.Standings()
    self.count:SetText(("%d player%s"):format(#st, #st == 1 and "" or "s"))
    local selName = filterName
    if selName then
      local found
      for _, s in ipairs(st) do if s.name == selName then found = true end end
      if not found then selName = nil end
    end
    if not selName then
      for _, s in ipairs(st) do if D.SameName(s.name, D.Me()) then selName = s.name end end
    end
    selName = selName or (st[1] and st[1].name)
    local selRow, selRank
    for i, s in ipairs(st) do if s.name == selName then selRow, selRank = s, i end end
    self.list:SetData(st, function(r, s, i)
      r.player = s.name
      r.rank:SetText(i)
      SetClassIcon(r.cls, D.ClassOf(s.name))
      local alts = D.AltsOf(s.name)
      r.name:SetText(s.name .. (#alts > 0 and (" |cffa7afba+" .. #alts .. " alt" .. (#alts > 1 and "s" or "") .. "|r") or ""))
      r.name:SetTextColor(ClassColor(D.ClassOf(s.name)))
      r.badges:SetText(D.BadgeStrip(s.name, 16, 5)) -- v0.7.3
      r.badges:ClearAllPoints()
      r.badges:SetPoint("LEFT", r, "LEFT", 68 + (r.name:GetStringWidth() or 0) + 8, 0)
      r.dkp:SetText(s.dkp)
      local on = s.name == selName
      r.bar:SetShown(on)
      if on then r:SetBackdropColor(unpack(th.deep))
      elseif i % 2 == 0 then r:SetBackdropColor(0.082, 0.086, 0.106, 1)
      else r:SetBackdropColor(0, 0, 0, 0) end
    end)
    local c = self.card
    c.player = selRow and selRow.name or nil
    if selRow then
      local class = D.ClassOf(selRow.name)
      SetClassIcon(c.icon, class)
      c.name:SetText(D.FirstName(selRow.name) or selRow.name)
      c.name:SetTextColor(ClassColor(class))
      local cname = class and LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[class] or "Raider"
      c.sub:SetText(("%s · rank #%d of %d"):format(cname, selRank, #st))
      c.dkp:SetText(selRow.dkp)
      local alts = D.AltsOf(selRow.name)
      local list = {}
      for i, a in ipairs(alts) do list[i] = D.FirstName(a) or a end
      c.alts:SetText(#list > 0 and ("Alts: " .. table.concat(list, ", ")) or "No alts linked")
      -- v0.5.0: badges
      local bLines, bs = {}, D.Badges(selRow.name)
      for i, b in ipairs(bs) do
        if i > 4 then bLines[#bLines + 1] = ("|cffa7afba+%d more on the Hall of Fame|r"):format(#bs - 4) break end
        bLines[#bLines + 1] = ("%s |c%s%s|r |cffa7afba%s|r"):format(D.BadgeInline(b.label, 15), b.hex, b.label, b.tip)
      end
      c.badges:SetText(#bLines > 0 and table.concat(bLines, "\n") or "|cffa7afbaNone yet|r")
      local aws = D.PodiumAwardStrip and D.PodiumAwardStrip(selRow.name, 16, 10) or "" -- v1.5.0, icons in v1.6.0
      c.awards:SetText(aws ~= "" and aws or "|cffa7afbaNone yet|r")
    else
      c.icon:Hide(); c.name:SetText("Nobody yet"); c.sub:SetText(""); c.dkp:SetText("-"); c.alts:SetText("")
      c.badges:SetText("")
      c.awards:SetText("")
    end
    c.recap:SetShown(selRow ~= nil)
    c.logs:SetShown(selRow ~= nil)
    c.adjust:SetShown(admin and selRow ~= nil)
  end
end

local function Block(p, title, color, x, y, w)
  local t = Text(p, 10, color, "GameFontNormalSmall"); t:SetPoint("TOPLEFT", x, y); t:SetText(title)
  local b = Text(p, 12, COL.text); b:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -4); b:SetWidth(w)
  b:SetWordWrap(true); b:SetJustifyV("TOP"); b:SetHeight(44)
  return b, t
end

---------------------------------------------------------------------------
-- v0.3.1 Raid night: status bar, the raid by class, sign-up check, bench
---------------------------------------------------------------------------
local CLASS_ORDER = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
local PILL = {
  green = { { 0.075, 0.153, 0.114, 1 }, { 0.18, 0.42, 0.29, 1 }, { 0.62, 0.89, 0.74 } },
  orange = { { 0.17, 0.13, 0.07, 1 }, { 0.42, 0.32, 0.14, 1 }, { 0.95, 0.77, 0.43 } },
  plain = { { 0.1, 0.105, 0.13, 1 }, { 0.23, 0.19, 0.13, 1 }, COL.text },
  grey = { { 0.1, 0.105, 0.13, 1 }, { 0.23, 0.19, 0.13, 1 }, { 0.6, 0.62, 0.66 } },
  blue = { { 0.1, 0.105, 0.13, 1 }, { 0.23, 0.19, 0.13, 1 }, { 0.61, 0.77, 1 } },
}
local CLOCK = "|TInterface\\Icons\\INV_Misc_PocketWatch_01:12:12:0:0:64:64:6:58:6:58|t"

local function Pill(parent, size)
  local f = CreateFrame("Frame", nil, parent, BD)
  f:SetHeight(size == "big" and 22 or 20)
  Skin(f, PILL.plain[1], PILL.plain[2])
  f.text = Text(f, 11, COL.text); f.text:SetPoint("CENTER")
  function f:Set(text, style)
    local st = PILL[style or "plain"]
    self.text:SetText(text)
    self:SetBackdropColor(unpack(st[1])); self:SetBackdropBorderColor(unpack(st[2]))
    self.text:SetTextColor(unpack(st[3]))
    self:SetWidth(self.text:GetStringWidth() + 20)
  end
  return f
end

local function ClassHex(class)
  local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
  if not c then return "ffe8e6e3" end
  return c.colorStr or ("ff%02x%02x%02x"):format(c.r * 255, c.g * 255, c.b * 255)
end
local function Colored(name)
  return "|c" .. ClassHex(D.ClassOf(name)) .. (D.FirstName(name) or name) .. "|r"
end

local function BuildRaid(p)
  -- 1. status bar
  local bar = CreateFrame("Frame", nil, p, BD)
  bar:SetPoint("TOPLEFT", 10, -10); bar:SetPoint("TOPRIGHT", -10, -10); bar:SetHeight(54)
  Skin(bar, PANEL, COL.line)
  -- v0.4.6: the title has its own line (a long one shrinks, then ends in "..."),
  -- the status tag and details sit underneath, clear of the buttons
  p.title = Text(bar, 20, COL.gold); p.title:SetFont(TITLE_FONT, 20); p.title:SetPoint("TOPLEFT", 12, -6)
  p.title:SetWidth(370)
  p.pill = Pill(bar); p.pill:SetPoint("TOPLEFT", 12, -30)
  p.sub = Text(bar, 10, COL.muted); p.sub:SetPoint("LEFT", p.pill, "RIGHT", 8, 0); p.sub:SetWidth(250)

  p.session = Btn(bar, "CREATE RAID", 118, 30, "primary", function(self) D.RaidButtonClick(self) end)
  p.session:SetPoint("RIGHT", -10, 0)
  -- give again only after a confirm: Start / End raid already hand these out
  local function GiveRaidAward(anchor, cat, label)
    if D.CurrentRaid() and D.RaidAwardGiven(cat) then
      D.ShowMenu(anchor, label .. " was already given for this raid", {
        { "Give it again anyway", function() D.AwardRaid(cat) end, danger = true },
      })
    else
      D.AwardRaid(cat)
    end
  end
  p.award = ThemeBtn(bar, "Award DKP  v", 108, 30, function(self)
    local cur = D.CurrentRaid()
    local onTime, clear = tostring(D.Cfg("ONTIME")), tostring(D.Cfg("CLEAR"))
    local items = {
      { ("On-time +%s%s"):format(onTime, (cur and D.RaidAwardGiven("ONTIME")) and "  (given)" or ""),
        function() GiveRaidAward(self, "ONTIME", "On-time") end },
      { "Boss kill...  (usually automatic)", function()
        local name = UnitExists("target") and UnitName("target")
        local dlg = StaticPopup_Show("GLDKP_BOSS")
        local eb = dlg and (dlg.editBox or dlg.EditBox)
        if eb and name and not D.Secret(name) then eb:SetText(name) end
      end },
      { ("Full clear +%s%s"):format(clear, (cur and D.RaidAwardGiven("CLEAR")) and "  (given)" or ""),
        function() GiveRaidAward(self, "CLEAR", "Full clear") end },
    }
    if (tonumber(D.Cfg("BENCH")) or 0) > 0 then
      items[#items + 1] = { ("Bench / standby +%s"):format(tostring(D.Cfg("BENCH"))), function() GiveRaidAward(self, "BENCH", "Bench / standby") end }
    end
    items[#items + 1] = { "Custom amount...", function() StaticPopup_Show("GLDKP_CUSTOM") end }
    D.ShowMenu(self, "Award to everyone here + bench", items)
  end)
  p.award:SetPoint("RIGHT", p.session, "LEFT", -8, 0)
  p.recheck = Btn(bar, "Re-check", 72, 30, "ghost", function() D.UpdateRaid(); p:Update() end)
  p.recheck:SetPoint("RIGHT", p.award, "LEFT", -8, 0)

  -- summary pills
  p.pills = {}
  for i = 1, 6 do p.pills[i] = Pill(p) end

  -- 2. the raid by class: a 3 x 3 grid
  local GRID_W, BOX_GAP = 489, 8
  local boxW = math.floor((GRID_W - 2 * BOX_GAP) / 3)
  local boxH = 96
  p.boxes = {}
  for i, class in ipairs(CLASS_ORDER) do
    local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
    local b = CreateFrame("Frame", nil, p, BD)
    b:SetSize(boxW, boxH)
    b:SetPoint("TOPLEFT", 10 + col * (boxW + BOX_GAP), -104 - row * (boxH + BOX_GAP))
    Skin(b, PANEL, COL.line)
    b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetSize(18, 18); b.icon:SetPoint("TOPLEFT", 8, -6)
    SetClassIcon(b.icon, class)
    b.name = Text(b, 13, COL.text); b.name:SetFont(TITLE_FONT, 14); b.name:SetPoint("LEFT", b.icon, "RIGHT", 6, 0)
    b.name:SetText(LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[class] or class)
    b.name:SetTextColor(ClassColor(class))
    b.count = Text(b, 13, COL.gold, "GameFontNormal"); b.count:SetPoint("TOPRIGHT", -9, -8); b.count:SetJustifyH("RIGHT")
    local ln = Line(b); ln:SetPoint("TOPLEFT", 6, -29); ln:SetPoint("TOPRIGHT", -6, -29)
    -- v0.3.5: two columns of five names (signed up + in the raid)
    local colW = math.floor((boxW - 20) / 2)
    b.cells = {}
    for i = 1, 10 do
      local c = Text(b, 11, COL.text)
      local col, row = math.floor((i - 1) / 5), (i - 1) % 5
      c:SetPoint("TOPLEFT", 9 + col * (colW + 4), -34 - row * 12)
      c:SetWidth(colW)
      b.cells[i] = c
    end
    b.class = class
    p.boxes[class] = b
  end

  -- 4. bench strip
  local bench = CreateFrame("Frame", nil, p, BD)
  bench:SetPoint("BOTTOMLEFT", 10, 10); bench:SetSize(GRID_W, 40)
  Skin(bench, PANEL, COL.line)
  local bt = Text(bench, 10, COL.blue, "GameFontNormalSmall"); bt:SetPoint("LEFT", 10, 0); bt:SetText("BENCH")
  p.benchAdd = Btn(bench, "+ Add", 60, 24, "secondary", function() StaticPopup_Show("GLDKP_ADDBENCH") end)
  p.benchAdd:SetPoint("RIGHT", -8, 0)
  p.benchChips = {}
  for i = 1, 5 do
    local c = CreateFrame("Button", nil, bench, BD)
    c:SetHeight(24)
    Skin(c, { 0.1, 0.105, 0.13, 1 }, { 0.23, 0.19, 0.13, 1 })
    c.text = Text(c, 11, COL.text); c.text:SetPoint("LEFT", 8, 0)
    c:SetScript("OnClick", function(self)
      if self.removable and (D.IsAdmin() or D.practice) then D.RemoveBench(self.player) end
    end)
    c:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:AddLine(D.FirstName(self.player) or self.player or "")
      GameTooltip:AddLine(self.removable and "Click to take them off the bench" or "Benched in their Raid-Helper sign-up", 1, 1, 1)
      GameTooltip:Show()
    end)
    c:SetScript("OnLeave", function() GameTooltip:Hide() end)
    p.benchChips[i] = c
  end
  p.benchMore = Text(bench, 11, COL.muted)
  p.benchEmpty = Text(bench, 11, COL.muted); p.benchEmpty:SetPoint("LEFT", bt, "RIGHT", 12, 0)
  p.benchEmpty:SetText("Nobody benched · bench players get standby awards")

  -- 3. sign-up check
  local sc = CreateFrame("Frame", nil, p, BD)
  sc:SetPoint("TOPLEFT", 10 + GRID_W + 10, -104); sc:SetPoint("BOTTOMRIGHT", -10, 10)
  Skin(sc, PANEL, COL.line)
  local st = Text(sc, 15, COL.gold); st:SetFont(TITLE_FONT, 16); st:SetPoint("TOPLEFT", 12, -10); st:SetText("Sign-up check")
  -- v0.3.3: fix who a sign-up belongs to, matched or not ("Raj" -> Jarts)
  p.links = Btn(sc, "Links...", 58, 20, "ghost", function(self)
    local ev = D.TonightEvent()
    if not ev then return end
    local items = {}
    local list = {}
    for _, su in ipairs(ev.signups or {}) do if su.status ~= "absent" then list[#list + 1] = su end end
    table.sort(list, function(a, b) return tostring(a.name):lower() < tostring(b.name):lower() end)
    for _, su in ipairs(list) do
      local char = D.MatchSignup(su)
      local label = ("%s  |cffa7afba->|r  %s"):format(su.name or "?", char and Colored(char) or "|cfff2a54anot matched|r")
      items[#items + 1] = { label, function()
        local dlg = StaticPopup_Show("GLDKP_LINK", su.name or "?")
        if dlg then dlg.data = su.discordId end
      end }
    end
    D.ShowMenu(self, "Click a sign-up to set its character", items)
  end)
  p.links:SetPoint("TOPRIGHT", -8, -10)
  p.scSub = Text(sc, 10, COL.muted); p.scSub:SetPoint("TOPLEFT", 12, -30); p.scSub:SetWidth(196)
  local y = -52
  local function Section(label, color, h)
    local t = Text(sc, 9, color, "GameFontNormalSmall"); t:SetPoint("TOPLEFT", 12, y); t:SetText(label)
    local b = Text(sc, 11, COL.text); b:SetPoint("TOPLEFT", 12, y - 14); b:SetWidth(196)
    b:SetWordWrap(true); b:SetJustifyV("TOP"); b:SetHeight(h)
    y = y - 14 - h - 8
    return b, t
  end
  p.noShow, p.noShowHead = Section("SIGN-UPS", COL.gold, 62)
  p.walkIn, p.walkInHead = Section("HERE WITHOUT A SIGN-UP", COL.text, 30)
  p.umHead = Text(sc, 9, COL.orange, "GameFontNormalSmall"); p.umHead:SetPoint("TOPLEFT", 12, y); p.umHead:SetText("UNMATCHED SIGN-UPS")
  p.unmatched = {}
  for i = 1, 2 do
    local row = CreateFrame("Frame", nil, sc)
    row:SetSize(196, 22); row:SetPoint("TOPLEFT", 12, y - 14 - (i - 1) * 24)
    row.text = Text(row, 11, COL.text); row.text:SetPoint("LEFT"); row.text:SetWidth(140)
    row.btn = Btn(row, "Link...", 52, 20, "secondary", function(self)
      local s = self:GetParent().signup
      if s then
        local dlg = StaticPopup_Show("GLDKP_LINK", s.name or "?")
        if dlg then dlg.data = s.discordId end
      end
    end)
    row.btn:SetPoint("RIGHT", 0, 0)
    p.unmatched[i] = row
  end
  local legend = Text(sc, 10, COL.muted); legend:SetPoint("BOTTOMLEFT", 12, 10); legend:SetWidth(196)
  legend:SetWordWrap(true); legend:SetJustifyV("BOTTOM"); legend:SetHeight(40)
  p.legend = legend

  local function Sorted(set)
    local list = {}
    for n in pairs(set) do list[#list + 1] = n end
    table.sort(list)
    return list
  end

  function p:Update()
    local admin = D.IsAdmin() or D.practice
    local chk = D.RaidCheck()
    local ev = chk.event
    local ses, planned = D.OpenSession(), D.PlannedRaid()

    -- status bar
    local rule
    if ses then
      local mins = math.floor((GetServerTime() - (ses.start or GetServerTime())) / 60)
      self.title:SetText(ses.title or "Raid")
      self.pill:Set(("Live · since %s · %dh %02dm"):format(date("%H:%M", ses.start), math.floor(mins / 60), mins % 60), "green")
      self.sub:SetText(("Started by %s · bosses award automatically"):format(D.FirstName(ses.by) or "?"))
      rule = "on time = here when the raid started"
    elseif planned then
      self.title:SetText(planned.title or "Raid")
      self.pill:Set("Created · not started", "orange")
      self.sub:SetText(("Created %s by %s · on-time +%s at Start"):format(
        date("%H:%M", planned.created), D.FirstName(planned.createdBy) or "?", tostring(D.Cfg("ONTIME"))))
      rule = "on time = here when you press Start raid"
    else
      self.title:SetText(ev and ev.title or "Raid night")
      self.pill:Set("No raid yet", "plain")
      self.sub:SetText(ev and ("Raid-Helper at %s · create when forming up"):format(date("%H:%M", ev.start or 0))
        or "No Raid-Helper raid in the next 12 hours")
      rule = ("on-time cutoff %s realm time"):format(tostring(D.Cfg("ONTIME_CUTOFF")))
    end
    self.title:SetFont(TITLE_FONT, 20) -- v0.4.6: keep the title clear of the buttons
    local tw = self.title.GetUnboundedStringWidth and self.title:GetUnboundedStringWidth() or self.title:GetStringWidth()
    if tw > 370 then self.title:SetFont(TITLE_FONT, 16) end
    self.sub:SetWidth(math.max(80, 370 - (self.pill:GetWidth() or 0) - 8))
    self.session:SetLabel(ses and "END RAID" or planned and "START RAID" or "CREATE RAID")
    self.session:SetShown(admin); self.award:SetShown(admin)
    if admin then self.recheck:SetPoint("RIGHT", self.award, "LEFT", -8, 0) else self.recheck:SetPoint("RIGHT", self.session, "RIGHT", 0, 0) end

    -- v0.3.5: each class box = everyone signed up for that class plus
    -- everyone in the raid. Class colour = here, grey = signed up but not
    -- here yet, "zz" = here but offline, clock = late, "*" = no sign-up,
    -- "?" = tentative, orange = sign-up not linked to a character yet.
    local lateSet, walkSet = {}, {}
    for _, n in ipairs(chk.late) do lateSet[n] = true end
    for _, n in ipairs(chk.walkIn) do walkSet[n] = true end
    local boxes = {}
    for _, class in ipairs(CLASS_ORDER) do boxes[class] = { here = {}, away = {} } end
    local total, offline = 0, 0
    local inRaidPool = {}
    for _, n in ipairs(Sorted(D.raid)) do
      local info = D.raid[n]
      local class = info.class or D.ClassOf(n)
      total = total + 1
      inRaidPool[D.Pool(n)] = true
      local name = D.FirstName(n) or n
      local x = { sort = (info.online == false and "1" or "0") .. name, name = name, color = ClassHex(class), post = "" }
      if info.online == false then
        offline = offline + 1
        x.color, x.post = "ff8a9099", "|cff8a9099 zz|r"
      end
      if lateSet[n] then x.post = x.post .. CLOCK end
      if walkSet[n] then x.post = x.post .. "|cff8a9099*|r" end
      local bx = boxes[class]
      if bx then table.insert(bx.here, x) end
    end
    local notHere, tentative = 0, 0
    if ev then
      for _, su in ipairs(ev.signups or {}) do
        if su.status ~= "absent" and su.status ~= "bench" then
          local char = D.MatchSignup(su)
          if not (char and (D.raid[char] or inRaidPool[D.Pool(char)])) then
            local class = (char and D.ClassOf(char)) or su.class
            local bx = class and boxes[class]
            if bx then
              local name = char and (D.FirstName(char) or char) or (su.name or "?")
              table.insert(bx.away, { sort = name, name = name, color = char and "ff6f7680" or "fff2a54a",
                post = su.status == "tentative" and "|cff6f7680?|r" or "" })
              notHere = notHere + 1
              if su.status == "tentative" then tentative = tentative + 1 end
            end
          end
        end
      end
    end
    for _, class in ipairs(CLASS_ORDER) do
      local b, bx = self.boxes[class], boxes[class]
      table.sort(bx.here, function(x, y) return x.sort < y.sort end)
      table.sort(bx.away, function(x, y) return x.sort < y.sort end)
      local all = {}
      for _, x in ipairs(bx.here) do all[#all + 1] = x end
      for _, x in ipairs(bx.away) do all[#all + 1] = x end
      local expected = #bx.here + #bx.away
      if ev then
        b.count:SetText(("%d / %d"):format(#bx.here, expected))
        b.count:SetTextColor(unpack(#bx.here >= expected and expected > 0 and COL.teal or (#bx.here > 0 and COL.gold or COL.muted)))
      else
        b.count:SetText(#bx.here)
        b.count:SetTextColor(unpack(#bx.here > 0 and COL.gold or COL.muted))
      end
      for i, c in ipairs(b.cells) do
        local x = all[i]
        if i == 10 and #all > 10 then
          c:SetText(("|cffa7afba+%d more|r"):format(#all - 9))
        elseif x then
          -- shorten only the name, so the markers and colour codes stay whole
          local name = x.name
          c:SetText("|c" .. x.color .. name .. "|r" .. x.post)
          while c:GetStringWidth() > c:GetWidth() and #name > 3 do
            name = name:sub(1, -2)
            while #name > 0 and name:byte(#name) >= 128 and name:byte(#name) < 192 do name = name:sub(1, -2) end
            if #name > 0 and name:byte(#name) >= 192 then name = name:sub(1, -2) end
            c:SetText("|c" .. x.color .. name .. "..|r" .. x.post)
          end
        else
          c:SetText("")
        end
      end
      if #all == 0 then b.cells[1]:SetText(ev and "|cff6f7680Nobody signed up|r" or "|cff6f7680None in the raid|r") end
    end

    -- summary pills
    local pills = {}
    pills[#pills + 1] = { ("%d in the raid"):format(total), "plain" }
    if ev then pills[#pills + 1] = { ("%d of %d sign-ups here"):format(math.max(0, total - #chk.walkIn), chk.signed), "green" } end
    if #chk.late > 0 then pills[#pills + 1] = { ("%d late"):format(#chk.late), "orange" } end
    if ev and #chk.walkIn > 0 then pills[#pills + 1] = { ("%d walk-in%s"):format(#chk.walkIn, #chk.walkIn == 1 and "" or "s"), "plain" } end
    if offline > 0 then pills[#pills + 1] = { ("%d offline"):format(offline), "grey" } end
    if #chk.bench > 0 then pills[#pills + 1] = { ("%d on bench"):format(#chk.bench), "blue" } end
    local prev
    for i, pill in ipairs(self.pills) do
      local d = pills[i]
      if d then
        pill:Set(d[1], d[2])
        pill:ClearAllPoints()
        if prev then pill:SetPoint("LEFT", prev, "RIGHT", 6, 0) else pill:SetPoint("TOPLEFT", 10, -74) end
        pill:Show()
        prev = pill
      else
        pill:Hide()
      end
    end

    -- bench strip
    local inGame = {}
    for _, n in ipairs(D.Bench()) do inGame[n] = true end
    local prevChip
    for i, c in ipairs(self.benchChips) do
      local n = chk.bench[i]
      if n then
        c.player, c.removable = n, inGame[n] and true or false
        c.text:SetText(Colored(n) .. (c.removable and admin and "  |cffa7afbax|r" or ""))
        c:SetWidth(c.text:GetStringWidth() + 16)
        c:ClearAllPoints()
        if prevChip then c:SetPoint("LEFT", prevChip, "RIGHT", 6, 0) else c:SetPoint("LEFT", 62, 0) end
        c:Show()
        prevChip = c
      else
        c:Hide()
      end
    end
    self.benchMore:ClearAllPoints()
    if #chk.bench > #self.benchChips then
      self.benchMore:SetPoint("LEFT", prevChip, "RIGHT", 6, 0)
      self.benchMore:SetText(("+%d"):format(#chk.bench - #self.benchChips))
      self.benchMore:Show()
    else
      self.benchMore:Hide()
    end
    self.benchEmpty:SetShown(#chk.bench == 0)
    self.benchAdd:SetShown(admin)

    -- sign-up check
    self.links:SetShown(admin and ev ~= nil)
    local bridge = D.Bridge()
    local up = bridge.updated
    if not ev then
      self.scSub:SetText((not up or up == 0) and "No sign-ups yet" or "No Raid-Helper raid in the next 12 hours")
    else
      Fit(self.scSub, ("%s · updated %s"):format(ev.title or "Raid-Helper", up and up > 0 and date("%H:%M", up) or "?"))
    end
    if ev then
      self.noShow:SetText(("Signed up: |cffffffff%d|r\nHere: |cff8fe0c4%d|r   Not here yet: |cffa7afba%d|r%s"):format(
        chk.signed, math.max(0, total - #chk.walkIn), notHere,
        tentative > 0 and ("\nTentative: |cffa7afba%d|r"):format(tentative) or ""))
    else
      self.noShow:SetText("|cffa7afba-|r")
    end
    local walk = {}
    for i, n in ipairs(chk.walkIn) do walk[i] = Colored(n) end
    self.walkIn:SetText(not ev and "|cffa7afba-|r" or (#walk > 0 and table.concat(walk, ", ") or "|cffa7afbaNobody|r"))
    for i, row in ipairs(self.unmatched) do
      local s = chk.unmatched[i]
      row.signup = s
      if s then
        Fit(row.text, s.name or "?")
        row.btn:SetShown(admin)
        row:Show()
      elseif i == 1 then
        row.text:SetText(#chk.unmatched == 0 and "|cffa7afbaAll matched|r" or "")
        row.btn:Hide()
        row:Show()
      else
        row:Hide()
      end
    end
    if #chk.unmatched > #self.unmatched then
      self.umHead:SetText(("UNMATCHED SIGN-UPS (%d)"):format(#chk.unmatched))
    else
      self.umHead:SetText("UNMATCHED SIGN-UPS")
    end
    self.legend:SetText("|cff6f7680grey|r not here yet · |cff8a9099zz|r offline · " .. CLOCK .. " late\n|cff8a9099*|r no sign-up · ? tentative · |cfff2a54aorange|r not linked")
  end
end

---------------------------------------------------------------------------
-- v0.3.1 My DKP: wishlist (won items get a green check + Clear), my
-- characters, the guild's most wanted, my settings - in the new panels
---------------------------------------------------------------------------
local READY = "Interface\\RaidFrame\\ReadyCheck-Ready"

local function Panel(p, title)
  local f = CreateFrame("Frame", nil, p, BD)
  Skin(f, PANEL, COL.line)
  f.title = Text(f, 17, COL.gold); f.title:SetFont(TITLE_FONT, 17); f.title:SetPoint("TOPLEFT", 12, -9)
  f.title:SetText(title)
  return f
end

local function BuildWish(p)
  -- wishlist
  local wl = Panel(p, "My wishlist")
  wl:SetPoint("TOPLEFT", 10, -10); wl:SetSize(400, 312)
  local hint = Text(wl, 10, COL.muted); hint:SetPoint("LEFT", wl.title, "RIGHT", 10, -1)
  hint:SetText("shift-click an item into the box")
  p.box = Edit(wl, 270); p.box:SetPoint("TOPLEFT", 18, -38)
  D.OnInsertLink(function(link) if p.box:HasFocus() then p.box:SetText(link) end end)
  local function Add()
    local id = D.ItemIDFromText(p.box:GetText())
    if id then D.Wish(id, true); p.box:SetText(""); p.box:ClearFocus() end
  end
  p.box:SetScript("OnEnterPressed", Add)
  Btn(wl, "Add", 70, 22, "primary", Add):SetPoint("LEFT", p.box, "RIGHT", 8, 0)
  p.clearWon = Btn(wl, "Clear won", 90, 20, "secondary", function() D.ClearWonWishes() end)
  p.clearWon:SetPoint("TOPRIGHT", -10, -8)
  p.clearWon.label:SetTextColor(0.56, 0.88, 0.6)
  p.mine = List(wl, 34, 7, function(parent)
    local r = CreateFrame("Frame", nil, parent)
    r.icon = Icon(r, 26); r.icon:SetPoint("LEFT", 12, 0)
    r.check = r:CreateTexture(nil, "OVERLAY"); r.check:SetSize(16, 16)
    r.check:SetPoint("BOTTOMRIGHT", r.icon, "BOTTOMRIGHT", 5, -4); r.check:SetTexture(READY)
    r.name = Text(r, 12, COL.text); r.name:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 8, 1); r.name:SetWidth(250)
    r.sub = Text(r, 10, COL.muted); r.sub:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -2); r.sub:SetWidth(250)
    r.rm = Btn(r, "Remove", 60, 20, "ghost", function(self) D.Wish(self:GetParent().itemID, false) end)
    r.rm:SetPoint("RIGHT", -10, 0)
    return r
  end)
  p.mine:SetPoint("TOPLEFT", 1, -68); p.mine:SetPoint("TOPRIGHT", -1, -68); p.mine:SetHeight(34 * 7)
  p.empty = Text(wl, 11, COL.muted); p.empty:SetPoint("TOPLEFT", 14, -76); p.empty:SetWidth(370)
  p.empty:SetWordWrap(true)
  p.empty:SetText("Nothing yet. Items you add here show on their tooltips and in the auction window, so officers know you want them.")

  -- my characters
  local ch = Panel(p, "My characters")
  ch:SetPoint("TOPLEFT", 10, -330); ch:SetPoint("BOTTOMLEFT", 10, 10); ch:SetWidth(400)
  local cs = Text(ch, 10, COL.muted); cs:SetPoint("LEFT", ch.title, "RIGHT", 10, -1); cs:SetText("alts share their main's DKP")
  p.chars = Text(ch, 12, COL.text); p.chars:SetPoint("TOPLEFT", 14, -34); p.chars:SetWidth(370)
  p.chars:SetWordWrap(true); p.chars:SetJustifyV("TOP"); p.chars:SetHeight(40)
  p.linkBtn = Btn(ch, "This is an alt of...", 150, 24, "secondary", function() D.AskAltLink(true) end)
  p.linkBtn:SetPoint("BOTTOMLEFT", 14, 10)
  p.unlinkBtn = Btn(ch, "Unlink", 80, 24, "ghost", function() D.UnlinkMe() end)
  p.unlinkBtn:SetPoint("LEFT", p.linkBtn, "RIGHT", 6, 0)
  -- v0.6.1: gear plan (BiS targets per slot, BiS spec picker)
  p.gearBtn = Btn(ch, "Gear plan", 110, 24, "primary", function() D.ToggleGearPlan(true) end)
  p.gearBtn:SetPoint("BOTTOMRIGHT", -14, 10)

  -- most wanted
  local mw = Panel(p, "Most wanted in the guild")
  mw:SetPoint("TOPLEFT", 420, -10); mw:SetPoint("TOPRIGHT", -10, -10); mw:SetHeight(250)
  p.guild = List(mw, 34, 6, function(parent)
    local r = CreateFrame("Frame", nil, parent)
    r.icon = Icon(r, 26); r.icon:SetPoint("LEFT", 12, 0)
    r.name = Text(r, 12, COL.text); r.name:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 8, 1); r.name:SetWidth(240)
    r.who = Text(r, 10, COL.muted); r.who:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -2); r.who:SetWidth(240)
    return r
  end)
  p.guild:SetPoint("TOPLEFT", 1, -38); p.guild:SetPoint("TOPRIGHT", -1, -38); p.guild:SetHeight(34 * 6)

  -- my settings
  local ms = Panel(p, "My settings")
  ms:SetPoint("TOPLEFT", 420, -268); ms:SetPoint("BOTTOMRIGHT", -10, 10)
  local checks = {
    { "Show the bid popup", "popup" }, { "Sounds", "sound" }, { "Minimap button", "minimap" },
    { "Open live standings when I join a raid", "liveOnRaid" },
    { "Toast when I earn DKP (boss kills etc.)", "awardToasts" },
  }
  for i, c in ipairs(checks) do
    local cb = Check(ms, c[1], function() return D.settings[c[2]] end, function(v)
      D.settings[c[2]] = v
      if c[2] == "minimap" and D.UpdateMinimap then D.UpdateMinimap() end
    end)
    cb:SetPoint("TOPLEFT", 10, -32 - (i - 1) * 22)
  end
  local resetPos = Btn(ms, "Reset window layout", 140, 22, "ghost", function()
    wipe(D.settings.pos)
    -- v0.2.30: sizes and scales too
    if D.settings.scales then wipe(D.settings.scales) end
    if D.settings.sizes then wipe(D.settings.sizes) end
    D.Print("Window positions, sizes and scales reset - reloading...")
    ReloadUI()
  end)
  resetPos:SetPoint("BOTTOMLEFT", 10, 10)
  local resetMini = Btn(ms, "Reset minimap icon", 130, 22, "ghost", function()
    if D.ResetMinimap then D.ResetMinimap() end
  end)
  resetMini:SetPoint("LEFT", resetPos, "RIGHT", 6, 0)

  function p:Update()
    local main, alts = D.MainOf(D.Me()), D.AltsOf(D.Me())
    local pending = D.data.claim[D.Me()]
    local lines = { ("|cffe0b04f%s|r · %d DKP"):format(D.Me(), D.Balance(D.Me())) }
    if main then lines[#lines + 1] = "Alt of " .. main .. " (shared DKP)"
    elseif pending then lines[#lines + 1] = "|cfff2a54aWaiting for " .. pending .. " to accept|r"
    elseif #alts > 0 then lines[#lines + 1] = "Main · alts: " .. table.concat(alts, ", ")
    else lines[#lines + 1] = "|cffa7afbaNot linked to any other character|r" end
    self.chars:SetText(table.concat(lines, "\n"))
    self.unlinkBtn:SetEnabled(main ~= nil or pending ~= nil or #alts > 0)

    -- my wishlist: won items first, each with a check mark and Clear
    local list, won = {}, 0
    for _, id in ipairs(D.MyWishes()) do
      local w = D.WishWon(id, D.Me())
      if w then won = won + 1 end
      list[#list + 1] = { id = id, won = w }
    end
    table.sort(list, function(a, b)
      if (a.won ~= nil) ~= (b.won ~= nil) then return a.won ~= nil end
      return a.id < b.id
    end)
    self.clearWon:SetShown(won > 1)
    self.clearWon:SetLabel(("Clear won (%d)"):format(won))
    self.empty:SetShown(#list == 0)
    self.mine:SetData(list, function(r, x)
      local id = x.id
      r.itemID = id
      r.icon:SetItem(id)
      r.name:SetText(D.ItemName(id)); r.name:SetTextColor(D.QualityColor(id))
      if x.won then
        r.check:Show()
        local who = D.SameName(x.won.who or "", D.Me()) and "" or (" on " .. (D.FirstName(x.won.who) or x.won.who))
        r.sub:SetText(("|cff8fe0a0Won%s · %s DKP · %s|r"):format(who, x.won.price and tostring(x.won.price) or "?", date("%b %d", x.won.t or 0)))
        r.rm:SetLabel("Clear")
        r.rm.label:SetTextColor(0.56, 0.88, 0.6)
      else
        r.check:Hide()
        local others = 0
        for _, n in ipairs(D.Wishers(id)) do if not D.SameName(n, D.Me()) then others = others + 1 end end
        r.sub:SetText(others > 0 and ("Also wanted by %d other%s"):format(others, others == 1 and "" or "s") or "Nobody else has it on their list")
        r.rm:SetLabel("Remove")
        r.rm.label:SetTextColor(unpack(COL.muted))
      end
    end)

    -- the guild's most wanted (wishes already fulfilled don't count)
    local all = {}
    for id in pairs(D.data.wishes) do
      local n = D.Wishers(id)
      if #n > 0 then all[#all + 1] = { id = id, names = n } end
    end
    table.sort(all, function(a, b)
      if #a.names ~= #b.names then return #a.names > #b.names end
      return a.id < b.id
    end)
    self.guild:SetData(all, function(r, w)
      r.icon:SetItem(w.id)
      r.name:SetText(D.ItemName(w.id)); r.name:SetTextColor(D.QualityColor(w.id))
      local short = {}
      for i, n in ipairs(w.names) do short[i] = D.FirstName(n) or n end
      Fit(r.who, #w.names .. ": " .. table.concat(short, ", "))
    end)
  end
end

---------------------------------------------------------------------------
-- Dropdowns (our own: the game's dropdown API differs between clients)
---------------------------------------------------------------------------
local dropList
local function BuildDropList()
  local f = CreateFrame("Frame", "GuildLadderDKPDropList", UIParent, BD)
  Skin(f, COL.head, { COL.gold[1], COL.gold[2], COL.gold[3], 1 })
  f:SetFrameStrata("FULLSCREEN_DIALOG")
  f:EnableMouse(true)
  f.list = List(f, 22, 10, function(parent)
    local b = CreateFrame("Button", nil, parent, BD)
    Skin(b, { 0, 0, 0, 0 }, { 0, 0, 0, 0 })
    b.text = Text(b, 12, COL.text); b.text:SetPoint("LEFT", 8, 0); b.text:SetPoint("RIGHT", -8, 0)
    b:SetScript("OnEnter", function(self) self:SetBackdropColor(unpack(COL.sel)) end)
    b:SetScript("OnLeave", function(self) self:SetBackdropColor(0, 0, 0, 0) end)
    b:SetScript("OnClick", function(self)
      f:Hide()
      if f.onPick then f.onPick(self.value) end
    end)
    return b
  end)
  f.list:SetPoint("TOPLEFT", 1, -1); f.list:SetPoint("TOPRIGHT", -1, -1)
  f:SetScript("OnUpdate", function(self) -- click anywhere else closes it
    if IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton") then
      if not self:IsMouseOver() and not (self.owner and self.owner:IsMouseOver()) then self:Hide() end
    end
  end)
  tinsert(UISpecialFrames, "GuildLadderDKPDropList")
  f:Hide()
  dropList = f
end

-- options(): { { value, "label" }, ... }; onPick(value)
local function Dropdown(parent, width, options, onPick)
  local b = Btn(parent, "", width, 22, "secondary")
  b.label:ClearAllPoints(); b.label:SetPoint("LEFT", 8, 0); b.label:SetPoint("RIGHT", -20, 0); b.label:SetJustifyH("LEFT")
  local arrow = Text(b, 11, COL.gold); arrow:SetPoint("RIGHT", -8, 0); arrow:SetText("v")
  b:SetScript("OnClick", function(self)
    if not dropList then BuildDropList() end
    if dropList:IsShown() and dropList.owner == self then dropList:Hide() return end
    local opts = options()
    local data = {}
    for _, o in ipairs(opts) do data[#data + 1] = o end
    dropList.owner, dropList.onPick = self, onPick
    dropList:SetWidth(math.max(width, 120))
    dropList:SetHeight(math.min(#data, 10) * 22 + 2)
    dropList.list:SetHeight(math.min(#data, 10) * 22)
    dropList.list.offset = 0
    dropList.list:SetData(data, function(row, o)
      row.value = o[1]
      row.text:SetText(o[2])
      row.text:SetTextColor(unpack(tostring(o[1]) == tostring(self.value) and COL.gold or COL.text))
    end)
    -- start scrolled to the current value
    for i, o in ipairs(data) do
      if tostring(o[1]) == tostring(self.value) and i > 10 then dropList.list.offset = math.min(i - 5, #data - 10); dropList.list:Redraw() end
    end
    dropList:ClearAllPoints()
    dropList:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)
    dropList:Show()
  end)
  function b:SetValue(v, label) self.value = v; self:SetLabel(label or tostring(v)) end
  return b
end
D.UIDropdown = Dropdown -- v0.6.0: for pages defined above this point (My DKP)

-- Choices for each guild setting
local function Nums(list, fmt)
  local t = {}
  for _, n in ipairs(list) do t[#t + 1] = { n, fmt and fmt(n) or tostring(n) } end
  return t
end
local YESNO = { { 1, "Yes" }, { 0, "No" } }
local function Times()
  local t = {}
  for m = 17 * 60, 22 * 60, 15 do t[#t + 1] = { ("%d:%02d"):format(math.floor(m / 60), m % 60), ("%d:%02d"):format(math.floor(m / 60), m % 60) } end
  return t
end
local function Ranks()
  local t = {}
  local n = GuildControlGetNumRanks and GuildControlGetNumRanks() or 10
  for i = 0, n - 1 do
    local name = GuildControlGetRankName and GuildControlGetRankName(i + 1) or ("Rank " .. i)
    t[#t + 1] = { i, i == 0 and (name .. " only") or (name .. " and up") }
  end
  return t
end
local SETTING_OPTIONS = {
  ADMIN_RANK = Ranks,
  ONTIME = Nums({ 0, 5, 10, 15, 20, 25, 30, 40, 50 }),
  CLEAR = Nums({ 0, 5, 10, 15, 20, 25, 30, 40, 50 }),
  BENCH = Nums({ 0, 5, 10, 15, 20, 25, 30, 40, 50 }),
  ONTIME_CUTOFF = Times,
  BOSS_DEFAULT = Nums({ 0, 5, 10, 15, 20, 25, 30, 40, 50 }),
  AUCTION_MODE = { { "sealed", "Sealed (2nd-price)" }, { "open", "Open" } },
  MIN_BID = Nums({ 0, 5, 10, 15, 20, 25, 30, 40, 50 }),
  BID_STEP = Nums({ 1, 5, 10, 25 }),
  AUCTION_TIME = Nums({ 15, 20, 30, 45, 60, 90 }, function(n) return n .. " seconds" end),
  VICKREY_PLUS = Nums({ 0, 1, 5 }, function(n) return n == 0 and "Exactly 2nd bid" or ("2nd bid +" .. n) end),
  TIE_RULE = { { "roll", "Roll-off (/roll 1-100)" }, { "first", "Earliest bid wins" }, { "balance", "Higher balance wins" } },
  OS_PRICE = Nums({ 0, 5, 10, 15, 20, 25, 50 }, function(n) return n == 0 and "Bid normally" or ("Fixed " .. n .. " DKP") end),
  SNIPE_WINDOW = Nums({ 0, 3, 5, 10 }, function(n) return n == 0 and "Off" or ("Last " .. n .. " sec") end),
  SNIPE_EXTEND = Nums({ 0, 3, 5, 10, 15 }, function(n) return n == 0 and "Off" or ("Reset to " .. n .. " sec") end),
  USABLE_ONLY = YESNO,
  ALLOW_NEGATIVE = YESNO,
  DECAY_PCT = Nums({ 0, 5, 10, 15, 20, 25, 50 }, function(n) return n .. "%" end),
  DKP_RATE = Nums({ 0.1, 0.2, 0.25, 0.5, 1 }, function(n) return n .. " DKP per point" end),
  DKP_CAP = Nums({ 50, 100, 150, 200, 250, 300, 500, 1000 }),
}
local BOSS_OPTIONS = Nums({ 5, 10, 15, 20, 25, 30, 40, 50, 75, 100 })
local MINBID_OPTIONS = Nums({ 0, 10, 20, 30, 40, 50, 75, 100 }, function(n) return n == 0 and "No minimum" or ("Min " .. n) end)

-- The choices plus the current value if it isn't one of them (set before dropdowns)
local function OptionsFor(key)
  return function()
    local o = SETTING_OPTIONS[key]
    o = type(o) == "function" and o() or o or {}
    local cur, found = D.Cfg(key), false
    for _, x in ipairs(o) do if tostring(x[1]) == tostring(cur) then found = true end end
    if not found and cur ~= nil then
      local copy = { { cur, "Custom: " .. tostring(cur) } }
      for _, x in ipairs(o) do copy[#copy + 1] = x end
      return copy
    end
    return o
  end
end
local function LabelFor(key, value)
  for _, x in ipairs(OptionsFor(key)()) do if tostring(x[1]) == tostring(value) then return x[2] end end
  return tostring(value)
end

---------------------------------------------------------------------------
-- v0.4.0 Settings: four sections - General / Loot / Readiness / Data.
-- The controls and what they save are the same as before (D.SetConfig and
-- friends); only the layout changed. Readiness is new.
---------------------------------------------------------------------------
SETTING_OPTIONS.RD_MINILVL = Nums({ 0, 70, 90, 100, 105, 110, 115, 120 },
  function(n) return n == 0 and "Check every item" or ("Skip items under " .. n) end)
SETTING_OPTIONS.RD_BONUS = Nums({ 1, 2, 3, 5, 10, 15, 20 }, function(n) return n .. " DKP per boss" end)
SETTING_OPTIONS.RD_DEFAULT = { { "off", "Off" }, { "std", "Standard" }, { "strict", "Strict" } }
SETTING_OPTIONS.BIS_PHASE = { -- v0.6.0
  { 0, "BiS: Pre-raid" }, { 1, "BiS: P1 (Kara, Gruul, Mag)" }, { 2, "BiS: P2 (SSC, TK)" },
  { 3, "BiS: P3 (Hyjal, BT)" }, { 4, "BiS: P4 (Zul'Aman)" }, { 5, "BiS: P5 (Sunwell)" },
}
SETTING_OPTIONS.DECAY_DAY = { { 1, "Sunday" }, { 2, "Monday" }, { 3, "Tuesday" }, { 4, "Wednesday" }, { 5, "Thursday" },
  { 6, "Friday" }, { 7, "Saturday" } }
SETTING_OPTIONS.DECAY_TIME = function()
  local t = {}
  for h = 0, 23 do
    local s = ("%02d:00"):format(h)
    t[#t + 1] = { s, s }
  end
  return t
end

-- a button that looks "pressed" when it is the current choice
local function SegStyle(b, on)
  b.on = on
  b.baseLevel = b.baseLevel or b:GetFrameLevel()
  -- v0.4.1: a second thin line just inside the border, so the selected button
  -- has a solid edge on every side (the left edge used to look thin)
  if not b.hl then
    local h = CreateFrame("Frame", nil, b, BD)
    h:SetPoint("TOPLEFT", 1, -1); h:SetPoint("BOTTOMRIGHT", -1, 1)
    if h.SetBackdrop then h:SetBackdrop({ edgeFile = WHITE, edgeSize = 1 }) end
    b.hl = h
  end
  if on then
    b:SetFrameLevel(b.baseLevel + 2)
    b:SetBackdropColor(unpack(Theme().deep))
    b:SetBackdropBorderColor(COL.gold[1], COL.gold[2], COL.gold[3], 1)
    if b.hl.SetBackdropBorderColor then b.hl:SetBackdropBorderColor(COL.gold[1], COL.gold[2], COL.gold[3], 0.55) end
    b.hl:Show()
    b.label:SetTextColor(0.95, 0.84, 0.54)
  else
    b:SetFrameLevel(b.baseLevel)
    b:SetBackdropColor(0.15, 0.17, 0.21, 1)
    b:SetBackdropBorderColor(unpack(COL.line))
    b.hl:Hide()
    b.label:SetTextColor(unpack(COL.muted))
  end
end

-- a row of choice buttons: opts = { { value, "label", width }, ... }
local function Seg(parent, opts, get, set)
  local f = CreateFrame("Frame", nil, parent)
  local w = 0
  f.buttons = {}
  for _, o in ipairs(opts) do
    local value = o[1]
    local b = Btn(f, o[2], o[3], 22, "secondary", function()
      if f.enabled == false then return end
      set(value)
      for _, x in ipairs(f.buttons) do SegStyle(x, x.value == value) end
    end)
    b:SetPoint("LEFT", f, "LEFT", w, 0)
    b:SetScript("OnLeave", function(self) SegStyle(self, self.on) end)
    b.value = value
    w = w + o[3] - 1
    f.buttons[#f.buttons + 1] = b
  end
  f:SetSize(w + 1, 22)
  function f:Refresh()
    local cur = tostring(get())
    for _, b in ipairs(self.buttons) do SegStyle(b, tostring(b.value) == cur) end
  end
  function f:SetEnabled(on)
    self.enabled = on
    for _, b in ipairs(self.buttons) do b:SetEnabled(on) end
  end
  f:Refresh()
  return f
end

local function BuildSettings(p)
  local R = D.Rd
  p.drops, p.segs, p.chips, p.sec, p.rdRows = {}, {}, {}, {}, {}
  p.section = "general"

  local label = {}
  for _, st in ipairs(D.SETTING_ORDER) do label[st[1]] = st[2] end
  label.RD_MINILVL = "Gear checks"
  label.RD_BONUS = "Bonus per boss"
  label.RD_DEFAULT = "Other bosses"
  label.DECAY_DAY = "Day"
  label.DECAY_TIME = "Time (realm)"

  -- header with the section buttons
  local bar = CreateFrame("Frame", nil, p, BD)
  bar:SetPoint("TOPLEFT", 10, -10); bar:SetPoint("TOPRIGHT", -10, -10); bar:SetHeight(44)
  Skin(bar, PANEL, COL.line)
  local ttl = Text(bar, 20, COL.gold); ttl:SetFont(TITLE_FONT, 20); ttl:SetPoint("LEFT", 12, 0); ttl:SetText("Settings")
  local SECTIONS = { { "general", "General" }, { "loot", "Loot" }, { "ready", "Readiness" }, { "data", "Data" } }
  for i, s in ipairs(SECTIONS) do
    local key = s[1]
    local b = Btn(bar, s[2], 84, 26, "secondary", function() p.section = key; p:Update() end)
    b:SetPoint("LEFT", 118 + (i - 1) * 88, 0)
    b:SetScript("OnLeave", function(self) SegStyle(self, self.on) end)
    p.chips[key] = b
    local sec = CreateFrame("Frame", nil, p)
    sec:SetPoint("TOPLEFT", 10, -62); sec:SetPoint("BOTTOMRIGHT", -10, 10)
    sec:Hide()
    p.sec[key] = sec
  end
  p.readOnly = Text(bar, 10, COL.orange)
  p.readOnly:SetPoint("RIGHT", -12, 0); p.readOnly:SetWidth(230); p.readOnly:SetJustifyH("RIGHT")

  -- one setting = a label and a dropdown
  local function Row(panel, y, key)
    local l = Text(panel, 11, COL.text); l:SetPoint("TOPLEFT", 12, y - 4); l:SetWidth(168)
    l:SetText(label[key] or key)
    local dd = Dropdown(panel, 140, OptionsFor(key), function(v)
      if tostring(v) ~= tostring(D.Cfg(key)) then
        D.SetConfig(key, v)
        D.Print(("%s set to %s."):format(label[key] or key, LabelFor(key, v)))
      end
    end)
    dd:SetPoint("TOPLEFT", 190, y)
    dd.key = key
    p.drops[#p.drops + 1] = dd
    return dd
  end
  local function Rows(panel, keys, y0)
    for i, k in ipairs(keys) do Row(panel, y0 - (i - 1) * 28, k) end
  end
  local function Note(panel, x, y, w, h, text)
    local t = Text(panel, 10, COL.muted, "GameFontNormalSmall")
    t:SetPoint("TOPLEFT", x, y); t:SetWidth(w); t:SetWordWrap(true); t:SetJustifyV("TOP"); t:SetHeight(h)
    t:SetText(text)
    return t
  end

  -- ----------------------------------------------------------------- General
  local g = p.sec.general
  local awards = Panel(g, "Awards"); awards:SetPoint("TOPLEFT", 0, 0); awards:SetSize(350, 190)
  Rows(awards, { "ONTIME", "CLEAR", "BENCH", "ONTIME_CUTOFF", "BOSS_DEFAULT" }, -38)
  local ladder = Panel(g, "Ladder and ranks"); ladder:SetPoint("TOPLEFT", 0, -198); ladder:SetSize(350, 162)
  Rows(ladder, { "ADMIN_RANK", "DECAY_PCT", "DKP_RATE", "DKP_CAP" }, -38)
  local boss = Panel(g, "Boss kill values"); boss:SetPoint("TOPLEFT", 358, 0); boss:SetSize(361, 360)
  p.bvDD = Dropdown(boss, 210, function()
    local t = {}
    for i, raid in ipairs(R.RAIDS) do t[#t + 1] = { i, raid.name } end
    return t
  end, function(v) p.bvRaid = v; p:Update() end)
  p.bvDD:SetPoint("TOPLEFT", 12, -34)
  p.bvReset = Btn(boss, "Reset raid", 90, 22, "ghost", function()
    local raid = R.RAIDS[p.bvRaid or R.CurrentRaid() or 1]
    for _, b in ipairs(raid.bosses) do
      if D.BossValue(b) ~= nil then D.SetBossValue(D.BossValueKey(b), nil) end
    end
  end)
  p.bvReset:SetPoint("TOPRIGHT", -12, -34)
  p.bvRows = {}
  for i = 1, 9 do
    local y = -66 - (i - 1) * 25
    local row = {}
    row.name = Text(boss, 11, COL.text); row.name:SetPoint("TOPLEFT", 12, y - 4); row.name:SetWidth(190)
    row.dd = Dropdown(boss, 120, function() return BOSS_OPTIONS end, function(v)
      if row.boss then
        D.SetBossValue(D.BossValueKey(row.boss), v)
        row.dd:SetValue(v, tostring(v))
      end
    end)
    row.dd:SetPoint("TOPLEFT", 214, y)
    p.bvRows[i] = row
  end
  Note(boss, 12, -296, 335, 14, "A boss that is not in the list? Type its name:")
  p.bossName = Edit(boss, 150); p.bossName:SetPoint("TOPLEFT", 18, -318)
  p.bossVal = Dropdown(boss, 70, function() return BOSS_OPTIONS end, function(v) p.bossVal:SetValue(v) end)
  p.bossVal:SetPoint("LEFT", p.bossName, "RIGHT", 8, 0)
  p.bossVal:SetValue(10)
  p.setBoss = Btn(boss, "Set", 50, 22, "secondary", function()
    if p.bossName:GetText() ~= "" then
      D.SetBossValue(D.BossValueKey(p.bossName:GetText()), p.bossVal.value)
      p.bossName:SetText("")
    end
  end)
  p.setBoss:SetPoint("LEFT", p.bossVal, "RIGHT", 6, 0)

  -- -------------------------------------------------------------------- Loot
  local l = p.sec.loot
  local auc = Panel(l, "Auctions"); auc:SetPoint("TOPLEFT", 0, 0); auc:SetSize(350, 360)
  Rows(auc, { "AUCTION_MODE", "MIN_BID", "BID_STEP", "AUCTION_TIME", "VICKREY_PLUS", "TIE_RULE", "OS_PRICE",
    "SNIPE_WINDOW", "SNIPE_EXTEND", "USABLE_ONLY", "ALLOW_NEGATIVE" }, -36)
  local notes = Panel(l, "Item notes and minimum bids"); notes:SetPoint("TOPLEFT", 358, 0); notes:SetSize(361, 130)
  Note(notes, 12, -34, 335, 28, "Shift-click an item into the first box, add a note and/or a minimum bid, press Set. Officers can do this.")
  p.noteItem = Edit(notes, 110); p.noteItem:SetPoint("TOPLEFT", 18, -74)
  D.OnInsertLink(function(link) if p.noteItem:HasFocus() then p.noteItem:SetText(link) end end)
  p.noteText = Edit(notes, 80); p.noteText:SetPoint("LEFT", p.noteItem, "RIGHT", 8, 0)
  p.noteMin = Dropdown(notes, 76, function() return MINBID_OPTIONS end,
    function(v) p.noteMin:SetValue(v, v == 0 and "No min" or ("Min " .. v)) end)
  p.noteMin:SetPoint("LEFT", p.noteText, "RIGHT", 6, 0)
  p.noteMin:SetValue(0, "No min")
  Btn(notes, "Set", 36, 22, "secondary", function()
    local id = D.ItemIDFromText(p.noteItem:GetText())
    if id then
      D.SetItemNote(id, p.noteText:GetText(), (p.noteMin.value or 0) > 0 and p.noteMin.value or nil)
      p.noteItem:SetText(""); p.noteText:SetText(""); p.noteMin:SetValue(0, "No min")
    end
  end):SetPoint("LEFT", p.noteMin, "RIGHT", 4, 0)
  local mine = Panel(l, "Just for me"); mine:SetPoint("TOPLEFT", 358, -138); mine:SetSize(361, 70)
  local cb = Check(mine, "Auto-start the next auction after awarding", function() return D.settings.autoNext end,
    function(v) D.settings.autoNext = v end)
  cb:SetPoint("TOPLEFT", 12, -34)

  -- --------------------------------------------------------------- Readiness
  local rd = p.sec.ready
  local rules = Panel(rd, "What counts"); rules:SetPoint("TOPLEFT", 0, 0); rules:SetSize(350, 238)
  Note(rules, 12, -30, 330, 14, "Req = red  |  Rec = amber (red on Strict bosses)  |  Off = ignored")
  for i, r in ipairs(R.RULES) do
    local short, key = r[1], "RD_" .. r[1]
    local y = -48 - (i - 1) * 26
    local t = Text(rules, 11, COL.text); t:SetPoint("TOPLEFT", 12, y - 4); t:SetWidth(190); t:SetText(r[2])
    local s = Seg(rules, { { "req", "Req", 44 }, { "rec", "Rec", 44 }, { "off", "Off", 44 } },
      function() return R.Rule(short) end, function(v) D.SetConfig(key, v) end)
    s:SetPoint("TOPLEFT", 206, y)
    p.segs[#p.segs + 1] = s
  end
  Row(rules, -48 - 6 * 26 - 2, "RD_MINILVL")

  local bonus = Panel(rd, "Prepared bonus"); bonus:SetPoint("TOPLEFT", 0, -246); bonus:SetSize(350, 144)
  local bt = Text(bonus, 11, COL.text); bt:SetPoint("TOPLEFT", 12, -40); bt:SetWidth(190); bt:SetText("Bonus for being prepared")
  local on = Seg(bonus, { { 1, "On", 44 }, { 0, "Off", 44 } },
    function() return tonumber(D.Cfg("RD_BONUS_ON")) or 0 end, function(v) D.SetConfig("RD_BONUS_ON", v) end)
  on:SetPoint("TOPLEFT", 206, -36)
  p.segs[#p.segs + 1] = on
  Row(bonus, -64, "RD_BONUS")
  local jt = Text(bonus, 11, COL.text); jt:SetPoint("TOPLEFT", 12, -96); jt:SetWidth(190); jt:SetText("Judged on")
  local judge = Seg(bonus, { { "kill", "Kill pull", 66 }, { "first", "First pull", 66 } },
    function() return D.Cfg("RD_JUDGE") end, function(v) D.SetConfig("RD_JUDGE", v) end)
  judge:SetPoint("TOPLEFT", 206, -92)
  p.segs[#p.segs + 1] = judge
  Note(bonus, 12, -120, 330, 20, "Officers confirm the list before anything is posted. Needs every Req item.")

  local per = Panel(rd, "Per-boss strictness"); per:SetPoint("TOPLEFT", 358, 0); per:SetSize(361, 392)
  p.rdDD = Dropdown(per, 210, function()
    local t = {}
    for i, raid in ipairs(R.RAIDS) do t[#t + 1] = { i, raid.name } end
    return t
  end, function(v) p.rdRaid = v; p:Update() end)
  p.rdDD:SetPoint("TOPLEFT", 12, -34)
  p.rdReset = Btn(per, "Reset raid", 90, 22, "ghost", function()
    local raid = R.RAIDS[p.rdRaid or R.CurrentRaid() or 1]
    for _, b in ipairs(raid.bosses) do
      local v = D.Cfg("RB:" .. R.BossKey(b))
      if v ~= nil and v ~= "" then D.SetConfig("RB:" .. R.BossKey(b), "") end
    end
  end)
  p.rdReset:SetPoint("TOPRIGHT", -12, -34)
  for i = 1, 10 do
    local y = -66 - (i - 1) * 26
    local row = {}
    row.name = Text(per, 11, COL.text); row.name:SetPoint("TOPLEFT", 12, y - 4); row.name:SetWidth(152)
    row.seg = Seg(per, { { "off", "Off", 42 }, { "std", "Standard", 74 }, { "strict", "Strict", 58 } },
      function() return row.boss and R.BossLevel(row.boss) or "std" end,
      function(v) if row.boss then R.SetBossLevel(row.boss, v) end end)
    row.seg:SetPoint("TOPLEFT", 170, y)
    p.rdRows[i] = row
    p.segs[#p.segs + 1] = row.seg
  end
  p.rdNote = Note(per, 12, -328, 335, 36, "")
  Row(per, -366, "RD_DEFAULT")

  -- -------------------------------------------------------------------- Data
  local d = p.sec.data
  local tools = Panel(d, "Tools"); tools:SetPoint("TOPLEFT", 0, 0); tools:SetSize(350, 150)
  p.decay = Btn(tools, "Weekly decay (preview)", 160, 26, "secondary", function()
    local prev = D.DecayPreview()
    local lines = { ("%s%%"):format(tostring(D.Cfg("DECAY_PCT"))) }
    for i = 1, math.min(6, #prev) do
      lines[#lines + 1] = ("%s  %d -> %d"):format(prev[i].name, prev[i].before, prev[i].after)
    end
    if #prev > 6 then lines[#lines + 1] = ("...and %d more"):format(#prev - 6) end
    StaticPopup_Show("GLDKP_DECAY", table.concat(lines, "\n"))
  end)
  p.decay:SetPoint("TOPLEFT", 12, -38)
  p.import = Btn(tools, "Import ladder balances", 160, 26, "secondary", function() StaticPopup_Show("GLDKP_IMPORT") end)
  p.import:SetPoint("LEFT", p.decay, "RIGHT", 6, 0)
  p.importClm = Btn(tools, "Import from CLM...", 160, 26, "secondary", function() D.AskImportCLM() end)
  p.importClm:SetPoint("TOPLEFT", 12, -70)
  p.phase = Btn(tools, "Start new phase", 160, 26, "secondary", function() StaticPopup_Show("GLDKP_PHASE") end)
  p.phase:SetPoint("LEFT", p.importClm, "RIGHT", 6, 0)
  p.practice = Btn(tools, "Practice mode", 160, 26, "secondary", function() D.SetPractice(not D.practice) end)
  p.practice:SetPoint("TOPLEFT", 12, -102)
  -- v0.6.0: the BiS list phase everyone's upgrade verdicts use (guild master)
  local bisDD = Dropdown(tools, 160, OptionsFor("BIS_PHASE"), function(v)
    if tostring(v) ~= tostring(D.Cfg("BIS_PHASE")) then
      D.SetConfig("BIS_PHASE", v)
      D.Print(("BiS phase set to %s."):format(LabelFor("BIS_PHASE", v)))
    end
  end)
  bisDD:SetPoint("LEFT", p.practice, "RIGHT", 6, 0)
  bisDD.key = "BIS_PHASE"
  p.drops[#p.drops + 1] = bisDD
  local who = Panel(d, "Who can change what"); who:SetPoint("TOPLEFT", 358, 0); who:SetSize(361, 150)
  local wt = Text(who, 11, COL.text); wt:SetPoint("TOPLEFT", 12, -36); wt:SetWidth(335); wt:SetWordWrap(true); wt:SetJustifyV("TOP")
  wt:SetHeight(104)
  wt:SetText("Guild master: guild settings, boss values, readiness rules, importing balances, starting a new phase, the BiS phase.\n\n" ..
    "Officers: item notes and minimum bids, practice mode, awards and loot.\n\n" ..
    "Practice mode keeps everything you do on your own computer; nothing is sent to the guild.")

  -- v0.4.6: automatic weekly decay
  local auto = Panel(d, "Automatic weekly decay"); auto:SetPoint("TOPLEFT", 0, -158); auto:SetSize(719, 160)
  local at = Text(auto, 11, COL.text); at:SetPoint("TOPLEFT", 12, -40); at:SetWidth(190); at:SetText("Run it automatically")
  local autoSeg = Seg(auto, { { 1, "On", 44 }, { 0, "Off", 44 } },
    function() return tonumber(D.Cfg("DECAY_AUTO")) or 0 end, function(v) D.SetConfig("DECAY_AUTO", v) end)
  autoSeg:SetPoint("TOPLEFT", 206, -36)
  p.segs[#p.segs + 1] = autoSeg
  Row(auto, -64, "DECAY_DAY")
  Row(auto, -92, "DECAY_TIME")
  p.decayStatus = Text(auto, 11, COL.gold); p.decayStatus:SetPoint("TOPLEFT", 12, -128); p.decayStatus:SetWidth(330)
  Note(auto, 368, -38, 335, 112, "Once a week at this realm time, an officer's add-on applies the Weekly decay % (General). "
    .. "If no officer is online then, the first one to log in afterwards does it - once, however many weeks were missed. "
    .. "It waits while a raid is running or an auction is open, and never runs twice in the same week. "
    .. "Everyone should be on 0.4.6 or later before you switch it on.")

  function p:Update()
    local gm = D.IsGM()
    for key, s in pairs(self.sec) do s:SetShown(key == self.section) end
    for key, b in pairs(self.chips) do SegStyle(b, key == self.section) end
    for _, dd in ipairs(self.drops) do
      local v = D.Cfg(dd.key)
      dd:SetValue(v, LabelFor(dd.key, v))
      dd:SetEnabled(gm)
    end
    -- per-boss rows follow the raid picked in the dropdown (default: the one we are in)
    local idx = self.rdRaid or R.CurrentRaid() or 1
    local raid = R.RAIDS[idx]
    self.rdDD:SetValue(idx, raid.name)
    self.rdDD:SetEnabled(true)
    self.rdReset:SetEnabled(gm)
    for i, row in ipairs(self.rdRows) do
      local b = raid.bosses[i]
      row.boss = b
      row.name:SetText(b or "")
      row.seg:SetShown(b ~= nil)
    end
    for _, s in ipairs(self.segs) do
      s:Refresh()
      s:SetEnabled(gm)
    end
    self.setBoss:SetEnabled(gm)
    self.decay:SetEnabled(gm or D.practice)
    self.import:SetEnabled(gm)
    self.phase:SetEnabled(gm)
    self.importClm:SetEnabled(gm)
    self.readOnly:SetText(gm and "" or "Only the guild master can change guild settings.")
    self.practice:SetLabel(D.practice and "Practice mode: ON" or "Practice mode: off")
    self.decayStatus:SetText(D.DecayStatusText and D.DecayStatusText() or "")
    -- boss kill values: one row per boss of the raid picked in the dropdown
    local bidx = self.bvRaid or R.CurrentRaid() or 1
    local braid = R.RAIDS[bidx]
    self.bvDD:SetValue(bidx, braid.name)
    self.bvReset:SetEnabled(gm)
    local def = tonumber(D.Cfg("BOSS_DEFAULT")) or 0
    for i, row in ipairs(self.bvRows) do
      local b = braid.bosses[i]
      row.boss = b
      row.name:SetText(b or "")
      row.dd:SetShown(b ~= nil)
      if b then
        local v = D.BossValue(b)
        row.dd:SetValue(v or def, v and tostring(v) or (tostring(def) .. " (default)"))
        row.dd:SetEnabled(gm)
      end
    end
    -- what Standard and Strict mean right now
    local SHORT = { FLASK = "Flask / elixirs", FOOD = "Food", ENCH = "Enchants", GEMS = "Gems", SCROLL = "Scrolls", OIL = "Weapon oil" }
    local std, extra = {}, {}
    for _, r in ipairs(R.RULES) do
      local rule = R.Rule(r[1])
      if rule == "req" then std[#std + 1] = SHORT[r[1]] elseif rule == "rec" then extra[#extra + 1] = SHORT[r[1]] end
    end
    self.rdNote:SetText(("Standard checks: %s.\nStrict also checks: %s.\nTrash is never checked. Off skips the boss."):format(
      #std > 0 and table.concat(std, ", ") or "nothing", #extra > 0 and table.concat(extra, ", ") or "nothing extra"))
  end
end

---------------------------------------------------------------------------
-- v0.4.0 Readiness: a picker window (tick who, see the message, confirm),
-- used for reminders and for the prepared bonus.
---------------------------------------------------------------------------
local picker
local function BuildPicker()
  local f = CreateFrame("Frame", "GuildLadderDKPPicker", UIParent, BD)
  f:SetSize(500, 450)
  Skin(f, COL.bg, { COL.gold[1], COL.gold[2], COL.gold[3], 1 })
  f:SetFrameStrata("DIALOG"); f:SetToplevel(true); f:SetPoint("CENTER"); f:EnableMouse(true)
  f:SetMovable(true); f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
  f.title = Text(f, 18, COL.gold); f.title:SetFont(TITLE_FONT, 18); f.title:SetPoint("TOPLEFT", 16, -14)
  f.sub = Text(f, 11, COL.muted); f.sub:SetPoint("TOPLEFT", 16, -40); f.sub:SetWidth(468)
  f.list = List(f, 24, 8, function(parent)
    local r = CreateFrame("Frame", nil, parent)
    r.cb = CreateFrame("CheckButton", nil, r, "UICheckButtonTemplate")
    r.cb:SetSize(22, 22); r.cb:SetPoint("LEFT", 2, 0)
    r.cb:SetScript("OnClick", function(self)
      if r.item then r.item.checked = self:GetChecked() and true or false end
      f:Refresh()
    end)
    r.name = Text(r, 12, COL.text); r.name:SetPoint("LEFT", 30, 0); r.name:SetWidth(100)
    r.text = Text(r, 11, COL.muted); r.text:SetPoint("LEFT", 136, 0); r.text:SetWidth(320)
    return r
  end)
  f.list:SetPoint("TOPLEFT", 16, -62); f.list:SetSize(468, 192)

  f.optBtns = {}
  for i = 1, 3 do
    local cb = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    cb:SetSize(22, 22); cb:SetPoint("TOPLEFT", 16, -262 - (i - 1) * 22)
    cb.text = Text(cb, 12, COL.text); cb.text:SetPoint("LEFT", cb, "RIGHT", 2, 0)
    cb:SetScript("OnClick", function(self)
      f.optState[self.key] = self:GetChecked() and true or false
      f:Rebuild()
    end)
    f.optBtns[i] = cb
  end

  local pl = Text(f, 10, COL.muted, "GameFontNormalSmall"); pl:SetPoint("TOPLEFT", 16, -336); pl:SetText("PREVIEW")
  local pb = CreateFrame("Frame", nil, f, BD)
  pb:SetPoint("TOPLEFT", 16, -350); pb:SetSize(468, 46)
  Skin(pb, PANEL, COL.line)
  f.prev = Text(pb, 11, COL.text); f.prev:SetPoint("TOPLEFT", 8, -6); f.prev:SetWidth(452)
  f.prev:SetWordWrap(true); f.prev:SetJustifyV("TOP"); f.prev:SetHeight(36)

  Btn(f, "Cancel", 90, 28, "ghost", function() f:Hide() end):SetPoint("BOTTOMRIGHT", -16, 14)
  f.confirm = Btn(f, "", 190, 28, "primary", function()
    local sel = {}
    for _, r in ipairs(f.rows or {}) do if r.checked then sel[#sel + 1] = r end end
    f:Hide()
    if f.spec and f.spec.onConfirm then f.spec.onConfirm(sel, f.optState) end
  end)
  f.confirm:SetPoint("BOTTOMRIGHT", -114, 14)

  function f:Rebuild(first)
    local rows = self.spec.build(self.optState)
    if not first then
      for _, r in ipairs(rows) do
        local k = self.keep[r.name]
        if k ~= nil then r.checked = k end
      end
    end
    self.rows = rows
    self.list:SetData(rows, function(row, item)
      row.item = item
      row.cb:SetChecked(item.checked and true or false)
      row.name:SetText(D.FirstName(item.name) or item.name)
      row.name:SetTextColor(ClassColor(item.class))
      row.text:SetText(item.shortText or item.text or "")
    end)
    self:Refresh()
  end
  function f:Refresh()
    local n, prev = 0, nil
    for _, r in ipairs(self.rows or {}) do
      self.keep[r.name] = r.checked
      if r.checked then
        n = n + 1
        if not prev and r.text then prev = r.text end
      end
    end
    self.confirm:SetLabel(self.spec.confirm(n))
    self.confirm:SetEnabled(n > 0)
    self.prev:SetText(prev or "")
  end
  tinsert(UISpecialFrames, "GuildLadderDKPPicker")
  f:Hide()
  picker = f
end

-- spec = { title, sub, opts = { { key, label, default } }, build(optState) -> rows,
--          confirm(n) -> label, onConfirm(selectedRows, optState) }
-- a row = { name, class, text, shortText, checked }
function D.ShowPicker(spec)
  if not picker then BuildPicker() end
  local f = picker
  f.spec, f.keep, f.optState = spec, {}, {}
  f.title:SetText(spec.title or "")
  f.sub:SetText(spec.sub or "")
  for i, cb in ipairs(f.optBtns) do
    local o = spec.opts and spec.opts[i]
    if o then
      cb.key = o.key
      cb.text:SetText(o.label)
      f.optState[o.key] = o.default and true or false
      cb:SetChecked(o.default and true or false)
      cb:Show()
    else
      cb:Hide()
    end
  end
  f:Rebuild(true)
  f:Show()
end

---------------------------------------------------------------------------
-- v0.4.0 Readiness tab (officers + GM)
---------------------------------------------------------------------------
local NOTREADY = "Interface\\RaidFrame\\ReadyCheck-NotReady"
local ICON_OK = "|T" .. READY .. ":13:13|t"
local ICON_BAD = "|T" .. NOTREADY .. ":13:13|t"
PILL.red = { { 0.2, 0.08, 0.07, 1 }, { 0.5, 0.2, 0.17, 1 }, { 1, 0.55, 0.5 } }

-- key, heading, centre x within the row
local RD_COLS = {
  { "flask", "Flask", 168 }, { "food", "Food", 220 }, { "scroll", "Scroll", 270 }, { "oil", "Oil", 316 },
  { "ench", "Ench.", 356 }, { "gems", "Gems", 408 }, { "ilvl", "iLvl", 458 },
}
local LEVEL_NAME = { off = "Off", std = "Standard", strict = "Strict" }

local function CellText(c, showTime)
  local s = c.state
  if s == "ok" then
    if showTime and c.left then
      return ("|cff%s%s|r"):format(c.left < 600 and "f2a54a" or "8fe0c4", D.Rd.TimeLeft(c.left))
    end
    return ICON_OK
  elseif s == "bad" then
    return ICON_BAD .. (c.n and (" " .. c.n) or "")
  elseif s == "warn" then
    return "|cfff2a54a!|r"
  elseif s == "none" then
    return "|cff8a8174?|r"
  end
  return "|cff5d564c-|r"
end

local function RdRow(parent)
  local r = CreateFrame("Button", nil, parent, BD)
  Skin(r, { 0, 0, 0, 0 }, { 0, 0, 0, 0 })
  r.icon = r:CreateTexture(nil, "ARTWORK"); r.icon:SetSize(14, 14); r.icon:SetPoint("LEFT", 6, 0)
  r.name = Text(r, 12, COL.text); r.name:SetPoint("LEFT", 26, 0); r.name:SetWidth(120)
  r.cells = {}
  for _, c in ipairs(RD_COLS) do
    local fs = Text(r, 11, COL.text)
    fs:SetPoint("CENTER", r, "LEFT", c[3], 0); fs:SetJustifyH("CENTER")
    r.cells[c[1]] = fs
  end
  r:SetScript("OnClick", function(self)
    local pg = pages.ready
    if self.player and pg then pg.sel = self.player; pg:Update() end
  end)
  return r
end

local function FillRdRow(r, row, selName, showTime)
  r.player = row.name
  SetClassIcon(r.icon, row.class)
  r.name:SetText(D.FirstName(row.name) or row.name)
  r.name:SetTextColor(ClassColor(row.class))
  for _, c in ipairs(RD_COLS) do
    local fs = r.cells[c[1]]
    if c[1] == "ilvl" then
      fs:SetText((row.ilvl and row.ilvl > 0) and tostring(row.ilvl) or "|cff8a8174?|r")
    else
      fs:SetText(CellText(row[c[1]], showTime))
    end
  end
  if row.name == selName then
    r:SetBackdropColor(unpack(COL.sel))
    r:SetBackdropBorderColor(COL.gold[1], COL.gold[2], COL.gold[3], 1)
  else
    local bg = (row.bad > 0 and { 0.2, 0.08, 0.07, 0.9 }) or (row.nodata and { 0.14, 0.14, 0.16, 0.9 }) or { 0, 0, 0, 0 }
    r:SetBackdropColor(unpack(bg))
    r:SetBackdropBorderColor(0, 0, 0, 0)
  end
end

local function OpenWhisper(p)
  local R = D.Rd
  local rows, boss = p.rows or {}, p.curBoss or "the next boss"
  D.ShowPicker({
    title = "Send reminders",
    sub = boss .. "  |  whispers come from your character; a player can be reminded once every 2 minutes",
    opts = {
      { key = "runout", label = "Also warn players whose flask or food runs out soon", default = false },
      { key = "nodata", label = "Also ask players with no gear data to update the add-on", default = false },
      { key = "raid", label = "Also post a short summary to raid chat", default = false },
    },
    build = function(o)
      local out = {}
      local seen = {}
      for _, x in ipairs(R.WhisperList(rows, boss, { runout = o.runout })) do
        seen[x.name] = true
        out[#out + 1] = { name = x.name, class = x.class, text = x.text, shortText = x.short, checked = true }
      end
      if o.nodata then
        for _, row in ipairs(rows) do
          if not row.hasGear and not seen[row.name] and not D.SameName(row.name, D.Me()) then
            out[#out + 1] = { name = row.name, class = row.class, shortText = "no gear data - needs the add-on", checked = true,
              text = "[Guild Ladder DKP] Please install or update the Guild Ladder DKP add-on so your gear can be checked before raids." }
          end
        end
      end
      return out
    end,
    confirm = function(n) return ("Send %d whisper%s"):format(n, n == 1 and "" or "s") end,
    onConfirm = function(sel, o)
      local list = {}
      for _, x in ipairs(sel) do list[#list + 1] = { name = x.name, text = x.text } end
      local sent = R.SendWhispers(list)
      if o.raid then R.PostSummary(rows, boss) end
      D.Print(("Reminded %d player%s."):format(sent, sent == 1 and "" or "s"))
    end,
  })
end

local function OpenBonus(p)
  local R = D.Rd
  local snap = p.snap
  if not snap then return end
  local amount = tonumber(D.Cfg("RD_BONUS")) or 0
  local use = R.BonusSnapshot(snap.boss) or snap
  local given = R.BonusGiven(snap.boss)
  local judge = D.Cfg("RD_JUDGE") == "first" and "first pull" or "kill pull"
  D.ShowPicker({
    title = "Prepared bonus",
    sub = ("%s  |  +%d DKP each  |  judged on the %s%s"):format(snap.boss, amount, judge,
      given and "  |  |cfff2a54aalready given tonight: posting again adds it twice|r" or ""),
    build = function()
      local out = {}
      for _, row in ipairs(use.rows) do
        local why = row.prepared and "prepared" or (#row.short > 0 and table.concat(row.short, ", ")) or "could not be checked"
        out[#out + 1] = { name = row.name, class = row.class, shortText = why, text = why, checked = row.prepared and true or false,
          sort = row.prepared and 0 or 1 }
      end
      table.sort(out, function(a, b)
        if a.sort ~= b.sort then return a.sort < b.sort end
        return a.name < b.name
      end)
      return out
    end,
    confirm = function(n) return ("Give +%d DKP to %d player%s"):format(amount, n, n == 1 and "" or "s") end,
    onConfirm = function(sel)
      local names = {}
      for _, x in ipairs(sel) do names[#names + 1] = x.name end
      R.PostBonus(names, snap.boss)
    end,
  })
end

local function BuildReadiness(p)
  local R = D.Rd
  p.mode = "pre"
  p.rows = {}

  -- status bar
  local bar = CreateFrame("Frame", nil, p, BD)
  bar:SetPoint("TOPLEFT", 10, -10); bar:SetPoint("TOPRIGHT", -10, -10); bar:SetHeight(54)
  Skin(bar, PANEL, COL.line)
  p.title = Text(bar, 20, COL.gold); p.title:SetFont(TITLE_FONT, 20); p.title:SetPoint("TOPLEFT", 12, -8)
  p.title:SetText("Readiness")
  p.pill = Pill(bar); p.pill:SetPoint("LEFT", p.title, "RIGHT", 10, 0)
  p.subLabel = Text(bar, 10, COL.muted); p.subLabel:SetPoint("TOPLEFT", 12, -36); p.subLabel:SetWidth(70)
  p.bossDD = Dropdown(bar, 220, function()
    local t = {}
    if p.mode == "last" then
      for i, s in ipairs(R.hist) do
        t[#t + 1] = { i, ("%s - pull %d%s - %s"):format(s.boss, s.pull, s.kill and " (kill)" or "", date("%H:%M", s.t)) }
      end
      if #t == 0 then t[1] = { 0, "No boss pulls yet" } end
      return t
    end
    t[1] = { "", "Any boss (default rules)" }
    local _, raid = R.CurrentRaid()
    local function Add(list) for _, b in ipairs(list) do t[#t + 1] = { b, b } end end
    if raid then Add(raid.bosses) else for _, rd in ipairs(R.RAIDS) do Add(rd.bosses) end end
    return t
  end, function(v)
    if p.mode == "last" then
      if v ~= 0 then p.histIndex = v; p.sel = nil end
    else
      p.boss = (v ~= "") and v or nil
    end
    p:Update()
  end)
  p.bossDD:SetPoint("TOPLEFT", 84, -29)
  p.levelText = Text(bar, 10, COL.muted); p.levelText:SetPoint("LEFT", p.bossDD, "RIGHT", 8, 0); p.levelText:SetWidth(100)

  p.recheck = Btn(bar, "Re-check", 72, 30, "ghost", function()
    if D.InRaid() then R.ScanRaid(); R.RequestGear(true) end
    p:Update()
  end)
  p.recheck:SetPoint("RIGHT", -10, 0)
  p.mLast = Btn(bar, "Last pull", 90, 26, "secondary", function() p.mode = "last"; p.sel = nil; p:Update() end)
  p.mLast:SetPoint("RIGHT", p.recheck, "LEFT", -8, 0)
  p.mPre = Btn(bar, "Pre-pull check", 104, 26, "secondary", function() p.mode = "pre"; p.sel = nil; p:Update() end)
  p.mPre:SetPoint("RIGHT", p.mLast, "LEFT", 1, 0)
  for _, b in ipairs({ p.mLast, p.mPre }) do b:SetScript("OnLeave", function(self) SegStyle(self, self.on) end) end

  -- summary pills
  p.pills = {}
  for i = 1, 6 do p.pills[i] = Pill(p) end

  -- the table
  local tp = CreateFrame("Frame", nil, p, BD)
  tp:SetPoint("TOPLEFT", 10, -100); tp:SetPoint("BOTTOMLEFT", 10, 10); tp:SetWidth(516)
  Skin(tp, PANEL, COL.line)
  local hn = Text(tp, 10, COL.gold, "GameFontNormalSmall"); hn:SetPoint("TOPLEFT", 26, -8); hn:SetText("PLAYER")
  for _, c in ipairs(RD_COLS) do
    local h = Text(tp, 10, COL.gold, "GameFontNormalSmall")
    h:SetPoint("CENTER", tp, "TOPLEFT", c[3] + 1, -14); h:SetJustifyH("CENTER"); h:SetText(c[2]:upper())
  end
  local hl = Line(tp); hl:SetPoint("TOPLEFT", 4, -25); hl:SetPoint("TOPRIGHT", -4, -25)
  p.list = List(tp, 24, 12, function(parent) return RdRow(parent) end)
  p.list:SetPoint("TOPLEFT", 1, -27); p.list:SetPoint("TOPRIGHT", -1, -27); p.list:SetHeight(288)
  p.empty = Text(tp, 12, COL.muted); p.empty:SetPoint("TOP", 0, -120); p.empty:SetWidth(440); p.empty:SetJustifyH("CENTER")
  p.empty:SetWordWrap(true)
  p.count = Text(tp, 10, COL.muted); p.count:SetPoint("BOTTOMLEFT", 10, 14); p.count:SetWidth(200)

  p.bWhisper = Btn(tp, "Whisper...", 110, 24, "primary", function() OpenWhisper(p) end)
  p.bWhisper:SetPoint("BOTTOMRIGHT", -10, 8)
  p.bPost = Btn(tp, "Post to raid...", 110, 24, "secondary", function()
    local R2 = D.Rd
    local lines = R2.RaidSummary(p.rows, p.curBoss or "the next boss")
    if #lines == 0 then D.Print("Nobody is missing anything.") return end
    for _, line in ipairs(lines) do D.Chat(line, "RAID", nil, true) end
  end)
  p.bPost:SetPoint("RIGHT", p.bWhisper, "LEFT", -6, 0)
  p.bBonus = Btn(tp, "Prepared bonus...", 140, 24, "primary", function() OpenBonus(p) end)
  p.bBonus:SetPoint("BOTTOMRIGHT", -10, 8)

  -- the "why" panel
  local dp = CreateFrame("Frame", nil, p, BD)
  dp:SetPoint("TOPLEFT", tp, "TOPRIGHT", 8, 0); dp:SetPoint("BOTTOMRIGHT", -10, 10)
  Skin(dp, PANEL, COL.line)
  p.dName = Text(dp, 16, COL.text); p.dName:SetFont(TITLE_FONT, 16); p.dName:SetPoint("TOPLEFT", 12, -10); p.dName:SetWidth(171)
  p.dSub = Text(dp, 10, COL.muted); p.dSub:SetPoint("TOPLEFT", 12, -32); p.dSub:SetWidth(171)
  p.dBody = Text(dp, 11, COL.text); p.dBody:SetPoint("TOPLEFT", 12, -52); p.dBody:SetWidth(171)
  p.dBody:SetWordWrap(true); p.dBody:SetJustifyV("TOP"); p.dBody:SetHeight(210)
  p.bOne = Btn(dp, "Whisper", 171, 24, "secondary", function()
    local row = p.selRow
    if not row then return end
    local text = D.Rd.WhisperText(row, p.curBoss or "the next boss", true)
    if text then
      D.Rd.SendWhispers({ { name = row.name, text = text } })
    end
  end)
  p.bOne:SetPoint("BOTTOM", 0, 40)
  p.bSkip = Btn(dp, "Exclude tonight", 171, 24, "ghost", function()
    local row = p.selRow
    if not row then return end
    D.Rd.excluded[row.name] = not D.Rd.excluded[row.name] or nil
    p.sel = nil
    p:Update()
  end)
  p.bSkip:SetPoint("BOTTOM", 0, 10)

  local function Section(title, hex, list)
    if #list == 0 then return "" end
    return ("|cff%s%s|r\n%s\n\n"):format(hex, title, table.concat(list, "\n"))
  end

  function p:Update()
    local pre = self.mode == "pre"
    local rows, sum = {}, { total = 0, ready = 0, flask = 0, food = 0, gear = 0, expiring = 0, nodata = 0 }
    local boss, level, snap
    local inRaid = D.InRaid()
    if pre then
      boss = self.boss
      level = boss and R.BossLevel(boss) or "std"
      if level == "off" then level = "std" end
      if inRaid then rows, sum = R.BuildRows(level) end
    else
      snap = R.hist[self.histIndex or 1]
      if snap then rows, sum, boss, level = snap.rows, snap.sum, snap.boss, snap.level end
    end
    self.rows, self.snap, self.curBoss, self.curLevel = rows, snap, boss, level

    SegStyle(self.mPre, pre); SegStyle(self.mLast, not pre)
    self.bossDD:Show()
    if pre then
      self.pill:Set("Live check", "green")
      self.subLabel:SetText("Checking for")
      self.bossDD:SetValue(self.boss or "", self.boss or "Any boss (default rules)")
      self.levelText:SetText(inRaid and (LEVEL_NAME[level] or "") or "not in a raid")
    else
      self.pill:Set(snap and (snap.kill and "Kill pull" or "Pull snapshot") or "No pulls yet", snap and "plain" or "grey")
      self.subLabel:SetText("Showing")
      local i = self.histIndex or 1
      self.bossDD:SetValue(snap and i or 0, snap and ("%s - pull %d%s - %s"):format(snap.boss, snap.pull, snap.kill and " (kill)" or "",
        date("%H:%M", snap.t)) or "No boss pulls yet")
      self.levelText:SetText(snap and LEVEL_NAME[level] or "")
    end

    -- pills
    local list = { { ("Ready  %d / %d"):format(sum.ready, sum.total), (sum.total > 0 and sum.ready == sum.total) and "green" or "plain" } }
    if sum.flask > 0 then list[#list + 1] = { "No flask / elixir  " .. sum.flask, "red" } end
    if sum.food > 0 then list[#list + 1] = { "No food  " .. sum.food, "red" } end
    if sum.gear > 0 then list[#list + 1] = { "Gear  " .. sum.gear, "red" } end
    if pre and sum.expiring > 0 then list[#list + 1] = { "Running out  " .. sum.expiring, "orange" } end
    if sum.nodata > 0 then list[#list + 1] = { "No data  " .. sum.nodata, "grey" } end
    local prev
    for i, pill in ipairs(self.pills) do
      local it = list[i]
      if it then
        pill:Set(it[1], it[2])
        pill:ClearAllPoints()
        if prev then pill:SetPoint("LEFT", prev, "RIGHT", 6, 0) else pill:SetPoint("TOPLEFT", 10, -72) end
        pill:Show()
        prev = pill
      else
        pill:Hide()
      end
    end

    -- selection
    local selRow
    for _, row in ipairs(rows) do if row.name == self.sel then selRow = row end end
    if not selRow and rows[1] then selRow = rows[1]; self.sel = selRow.name end
    self.selRow = selRow

    self.list:SetData(rows, function(r, row) FillRdRow(r, row, self.sel, pre) end)
    if #rows == 0 then
      self.empty:SetText(pre and (inRaid and "Nobody to check yet." or "Join a raid group to check who is ready.")
        or "No boss has been pulled yet tonight. A snapshot is taken at every boss pull.")
      self.empty:Show()
    else
      self.empty:Hide()
    end
    self.count:SetText(#rows > 0 and (("%d raider%s%s"):format(#rows, #rows == 1 and "" or "s", #rows > 12 and " - scroll for more" or "")) or "")

    -- buttons
    local wl = pre and R.WhisperList(rows, boss or "the next boss") or {}
    self.bWhisper:SetShown(pre); self.bPost:SetShown(pre)
    self.bWhisper:SetLabel(("Whisper %d..."):format(#wl))
    self.bWhisper:SetEnabled(#wl > 0)
    self.bPost:SetEnabled(#wl > 0)
    local bonusOn = (tonumber(D.Cfg("RD_BONUS_ON")) or 0) == 1
    self.bBonus:SetShown(not pre and bonusOn and snap ~= nil)

    -- why panel
    if selRow then
      self.dName:SetText(D.FirstName(selRow.name) or selRow.name)
      self.dName:SetTextColor(ClassColor(selRow.class))
      self.dSub:SetText(selRow.hasGear and "gear reported" or "no gear report (needs the add-on)")
      local body = Section(pre and "MISSING NOW" or "MISSING AT PULL", "ff7a6b", selRow.missing)
        .. Section("RECOMMENDED", "f2a54a", selRow.recs)
        .. Section("RUNNING OUT", "f2a54a", pre and selRow.runout or {})
        .. Section("OK", "a7afba", selRow.oks)
      if not selRow.hasBuffs then body = body .. "|cff8a8174The game is not showing this player's buffs.|r" end
      self.dBody:SetText(body)
      self.bOne:SetLabel("Whisper " .. (D.FirstName(selRow.name) or selRow.name))
      self.bOne:SetEnabled(pre and #selRow.short > 0)
      self.bSkip:SetLabel(D.Rd.excluded[selRow.name] and "Include again" or "Exclude tonight")
      self.bSkip:SetEnabled(pre)
    else
      self.dName:SetText(""); self.dSub:SetText(""); self.dBody:SetText("")
      self.bOne:SetEnabled(false); self.bSkip:SetEnabled(false)
    end
  end

  p:SetScript("OnShow", function(self)
    if D.InRaid() and D.IsAdmin() then R.ScanRaid(); R.RequestGear() end
    self:Update()
  end)
  local acc = 0
  p:SetScript("OnUpdate", function(self, dt)
    acc = acc + dt
    if acc < 3 then return end
    acc = 0
    if self.mode == "pre" and D.InRaid() and D.IsAdmin() then
      pcall(R.ScanRaid)
      self:Update()
    end
  end)
end

function D.RefreshReadyUI()
  if main and main:IsShown() and main.tab == "ready" and pages.ready and pages.ready.Update then pages.ready:Update() end
end

---------------------------------------------------------------------------
-- Raids: upcoming (Raid-Helper), running and past raids, with loot + awards
---------------------------------------------------------------------------
local STATUS_LABEL = { signed = "Signed", late = "Late", tentative = "Tentative", bench = "Bench", absent = "Absent" }

local function Duration(secs)
  secs = math.max(0, secs or 0)
  return ("%dh %02dm"):format(math.floor(secs / 3600), math.floor(secs % 3600 / 60))
end

-- Everything the list shows, with headers in between
local function RaidRows()
  local rows, now = {}, GetServerTime()
  local up = {}
  for _, e in ipairs(D.BridgeEvents()) do
    local hidden = D.settings.hiddenEvents and D.settings.hiddenEvents[tostring(e.id)]
    -- v0.4.6: once a raid is made from an event, it shows as that raid instead
    if (e.start or 0) > now - 3 * 3600 and not hidden and not D.EventHasRaid(e.id) then up[#up + 1] = e end
  end
  local open, planned = D.OpenSession(), D.PlannedRaid()
  if open then
    rows[#rows + 1] = { header = "RUNNING NOW" }
    rows[#rows + 1] = { kind = "live", key = open.id, title = open.title, t = open.start, ses = open }
  end
  if planned then
    rows[#rows + 1] = { header = "CREATED · NOT STARTED" }
    rows[#rows + 1] = { kind = "planned", key = planned.id, title = planned.title, t = planned.created, ses = planned }
  end
  if #up > 0 then
    rows[#rows + 1] = { header = "UPCOMING (RAID-HELPER)" }
    for _, e in ipairs(up) do rows[#rows + 1] = { kind = "up", key = "up:" .. tostring(e.id), title = e.title, t = e.start, ev = e } end
  end
  -- past: ended sessions, plus older raid nights from before sessions existed
  local past = {}
  for id, ses in pairs(D.data.sessions) do
    if ses.ended then past[#past + 1] = { kind = "past", key = id, title = ses.title, t = ses.start or ses.created, ses = ses } end
  end
  for g, info in pairs(D.data.byNight) do
    if not D.data.sessions[g] and g:match("^%d%d%d%d%-%d%d%-%d%d$") then
      past[#past + 1] = { kind = "past", key = g, title = "Raid night " .. g, t = D.data.nightT[g] or 0 }
    elseif g:match("^CLM%-%d%d%d%d%-%d%d%-%d%d$") and #info.spends > 0 then
      -- imported loot history; drops off the list once every item on it is undone
      local live = 0
      for _, e in ipairs(info.spends) do if not D.data.undone[e.id] then live = live + 1 end end
      if live > 0 then
        past[#past + 1] = { kind = "past", clm = true, key = g, title = "Raid night " .. g:sub(5) .. " (CLM)", t = D.data.nightT[g] or 0 }
      end
    end
  end
  table.sort(past, function(a, b) return a.t > b.t end)
  if #past > 0 then
    rows[#rows + 1] = { header = "PAST RAIDS" }
    for _, r in ipairs(past) do rows[#rows + 1] = r end
  end
  return rows
end

local function BuildRaids(p)
  p.list = List(p, 36, 12, function(parent)
    local r = CreateFrame("Button", nil, parent, BD)
    Skin(r, { 0, 0, 0, 0 }, { 0, 0, 0, 0 })
    r.title = Text(r, 12, COL.text, "GameFontNormal"); r.title:SetPoint("TOPLEFT", 14, -5); r.title:SetWidth(200)
    r.sub = Text(r, 10, COL.muted); r.sub:SetPoint("TOPLEFT", r.title, "BOTTOMLEFT", 0, -3); r.sub:SetWidth(200)
    r.head = Text(r, 10, COL.gold, "GameFontNormalSmall"); r.head:SetPoint("BOTTOMLEFT", 14, 6)
    r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    r:SetScript("OnClick", function(self, button)
      if not self.key then return end
      p.selected = self.key
      p:Update()
      if button == "RightButton" then p:RowMenu(self, self.row) end
    end)
    return r
  end)
  p.list:SetPoint("TOPLEFT", 0, -6); p.list:SetSize(240, 36 * 12)
  local hint = Text(p, 10, COL.muted); hint:SetPoint("BOTTOMLEFT", 14, 8); hint:SetText("Right-click a raid for options")
  local vline = p:CreateTexture(nil, "ARTWORK"); vline:SetColorTexture(unpack(COL.line))
  vline:SetWidth(1); vline:SetPoint("TOPLEFT", 240, 0); vline:SetPoint("BOTTOMLEFT", 240, 0)

  local x = 256
  p.title = Text(p, 16, COL.gold, "GameFontNormalLarge"); p.title:SetPoint("TOPLEFT", x, -10); p.title:SetWidth(470)
  p.sub = Text(p, 11, COL.muted); p.sub:SetPoint("TOPLEFT", x, -32); p.sub:SetWidth(470)
  p.stats = Text(p, 12, COL.text); p.stats:SetPoint("TOPLEFT", x, -50); p.stats:SetWidth(470)

  p.aHead = Text(p, 10, COL.muted, "GameFontNormalSmall"); p.aHead:SetPoint("TOPLEFT", x, -74)
  p.attend = Text(p, 11, COL.text); p.attend:SetPoint("TOPLEFT", x, -88); p.attend:SetWidth(470)
  p.attend:SetWordWrap(true); p.attend:SetJustifyV("TOP"); p.attend:SetHeight(52)

  -- v0.3.0: loot and the WHOLE night's awards in one scrolling list (the old
  -- awards box stopped at 5 lines and showed big awards as two half-lines)
  p.detail = List(p, 24, 13, function(parent)
    local r = CreateFrame("Frame", nil, parent)
    r.head = Text(r, 10, COL.gold, "GameFontNormalSmall"); r.head:SetPoint("BOTTOMLEFT", 0, 4)
    r.icon = Icon(r, 20); r.icon:SetPoint("LEFT", 0, 0)
    r.item = Text(r, 12, COL.text); r.item:SetPoint("LEFT", 28, 0); r.item:SetWidth(210)
    r.who = Text(r, 12, COL.text); r.who:SetPoint("LEFT", 246, 0); r.who:SetWidth(150)
    r.price = Text(r, 12, COL.gold, "GameFontNormal"); r.price:SetPoint("RIGHT", -10, 0); r.price:SetJustifyH("RIGHT")
    r.line = Text(r, 11, COL.text); r.line:SetPoint("LEFT", 0, 0); r.line:SetPoint("RIGHT", -70, 0)
    return r
  end)
  p.detail:SetPoint("TOPLEFT", x, -144); p.detail:SetSize(470, 24 * 13)
  local function FillDetail(r, x)
    r.head:SetText(x.head or "")
    local loot, award = x.loot, x.award
    r.icon:SetShown(loot ~= nil); r.item:SetShown(loot ~= nil); r.who:SetShown(loot ~= nil)
    r.price:SetShown(loot ~= nil or award ~= nil)
    r.line:SetShown(x.line ~= nil or award ~= nil)
    if loot then
      local id = tonumber(loot.x)
      if id then r.icon:SetItem(id) end
      r.item:SetText(loot.r or (id and D.ItemName(id)) or "?")
      if id then r.item:SetTextColor(D.QualityColor(id)) else r.item:SetTextColor(unpack(COL.text)) end
      local main = D.MainOf(loot.p)
      r.who:SetText((loot.p or "?") .. (loot.u == "OS" and " |cff9ccaff(OS)|r" or "") .. (main and (" |cffa7afbaalt of " .. D.FirstName(main) .. "|r") or ""))
      r.price:SetText((tonumber(loot.v) or 0) .. " DKP")
      r.price:SetTextColor(unpack(COL.gold))
    elseif award then
      Fit(r.line, ("%s  |cffa7afba· %d player%s · %s|r"):format(award.r, award.n, award.n == 1 and "" or "s", award.time))
      r.price:SetText("+" .. award.v)
      r.price:SetTextColor(unpack(COL.teal))
    elseif x.line then
      Fit(r.line, x.line)
    end
  end
  -- award parts written together (same award, officer, minute) become one line
  local function MergedAwards(list)
    local sorted = {}
    for _, e in ipairs(list) do sorted[#sorted + 1] = e end
    table.sort(sorted, function(a, b) return (a.t or 0) < (b.t or 0) end)
    local out, last = {}, nil
    for _, e in ipairs(sorted) do
      local key = table.concat({ e.r or "", tostring(e.v or ""), e.x or "", e.by or "" }, "\1")
      local n = #D.SplitNames(e.p)
      if last and last.key == key and math.abs((e.t or 0) - last.t) <= 10 then
        last.n = last.n + n
      else
        last = { key = key, r = e.r or "Award", v = e.v or "0", n = n, t = e.t or 0, time = date("%H:%M", e.t or 0) }
        out[#out + 1] = last
      end
    end
    return out
  end

  -- right-click a raid
  function p:RowMenu(anchor, row)
    if not row then return end
    local officer = D.IsAdmin() or D.practice
    local items = {}
    if row.kind == "up" then
      items[#items + 1] = { "Hide this raid (just for me)", function() D.HideEvent(row.ev.id) end }
    elseif officer and row.ses then
      if row.kind == "live" then
        local clear = tonumber(D.Cfg("CLEAR")) or 0
        if clear > 0 and not D.RaidAwardGiven("CLEAR", row.key) then
          items[#items + 1] = { ("End raid + full clear (+%d)"):format(clear), function() D.EndSession(true) end }
        end
        items[#items + 1] = { "End raid (no full clear)", function() D.EndSession(false) end }
      elseif row.kind == "planned" then
        items[#items + 1] = { ("Start raid (on-time +%s)"):format(tostring(D.Cfg("ONTIME"))), function() D.StartSession() end }
      end
      items[#items + 1] = { "Delete raid (keep its DKP)", function() ConfirmDelete(row.key, row.title, false) end, danger = true }
      items[#items + 1] = { "Delete raid + undo its DKP", function() ConfirmDelete(row.key, row.title, true) end, danger = true }
    elseif row.clm then
      if D.IsGM() then
        items[#items + 1] = { "Remove this night's imported CLM loot", function() ConfirmDelete(row.key, row.title, true) end, danger = true }
      end
    elseif officer then
      items[#items + 1] = { "Undo all DKP + loot from this night", function() ConfirmDelete(row.key, row.title, true) end, danger = true }
    end
    if #items == 0 then return end
    D.ShowMenu(anchor, row.title or "Raid", items)
  end

  local function Names(set)
    local list = {}
    for n in pairs(set) do list[#list + 1] = n end
    table.sort(list)
    return list
  end

  function p:Update()
    local rows = RaidRows()
    if not self.selected then
      for _, r in ipairs(rows) do if r.key then self.selected = r.key break end end
    end
    local sel
    self.list:SetData(rows, function(r, x)
      r.key, r.row = x.key, x
      if x.header then
        r.title:SetText(""); r.sub:SetText(""); r.head:SetText(x.header)
        r:SetBackdropColor(0, 0, 0, 0)
        return
      end
      r.head:SetText("")
      r.title:SetText(x.title or "Raid")
      local when = date("%a %b %d · %H:%M", x.t or 0)
      if x.kind == "live" then when = "|cff8fe0c4Live|r · since " .. date("%H:%M", x.t or 0)
      elseif x.kind == "planned" then when = "|cffe0b04fNot started|r · created " .. date("%H:%M", x.t or 0)
      elseif x.kind == "up" then when = when .. (" · %d signed up"):format(#((x.ev and x.ev.signups) or {})) end
      r.sub:SetText(when)
      r:SetBackdropColor(unpack(x.key == self.selected and COL.sel or { 0, 0, 0, 0 }))
    end)
    for _, r in ipairs(rows) do if r.key == self.selected then sel = r end end

    if not sel then
      self.title:SetText("No raids yet")
      self.sub:SetText("Raids appear here once an officer starts a raid session, or Raid-Helper sign-ups come in.")
      self.stats:SetText(""); self.aHead:SetText(""); self.attend:SetText("")
      self.detail:SetData({}, FillDetail)
      return
    end
    self.title:SetText(sel.title or "Raid")

    if sel.kind == "up" then
      local ev = sel.ev
      local groups = {}
      for _, su in ipairs(ev.signups or {}) do
        local st = su.status or "signed"
        groups[st] = groups[st] or {}
        local char = D.MatchSignup(su)
        table.insert(groups[st], char and D.FirstName(char) or ("|cfff2a54a" .. (su.name or "?") .. "|r"))
      end
      self.sub:SetText(date("%A %B %d · %H:%M", ev.start or 0) .. ((D.bridge and D.bridge.test and D.bridge.updated == (D.Bridge().updated or 0)) and "  ·  |cfff2a54atest sign-ups|r" or ""))
      local counts = {}
      for _, st in ipairs({ "signed", "late", "tentative", "bench", "absent" }) do
        if groups[st] then counts[#counts + 1] = ("%s %d"):format(STATUS_LABEL[st], #groups[st]) end
      end
      self.stats:SetText(#counts > 0 and table.concat(counts, " · ") or "No sign-ups yet")
      self.aHead:SetText("SIGNED UP · orange = not matched to a character yet")
      self.attend:SetText(groups.signed and table.concat(groups.signed, ", ") or "|cffa7afbaNobody yet|r")
      local rows = { { head = "LATE · TENTATIVE · BENCH · ABSENT" } }
      for _, st in ipairs({ "late", "tentative", "bench", "absent" }) do
        if groups[st] then rows[#rows + 1] = { line = ("|cffe0b04f%s:|r %s"):format(STATUS_LABEL[st], table.concat(groups[st], ", ")) } end
      end
      if #rows == 1 then rows[2] = { line = "|cffa7afbaNone|r" } end
      self.detail.offset = 0
      self.detail:SetData(rows, FillDetail)
      return
    end

    -- live or past raid
    local ses = sel.ses
    local night = D.data.byNight[sel.key] or { awards = {}, spends = {} }
    if ses then
      if not ses.start and not ses.ended then
        self.sub:SetText(("Created %s by %s · not started yet"):format(date("%A %B %d, %H:%M", ses.created), D.FirstName(ses.createdBy) or "?"))
      else
        local begin = ses.start or ses.created
        local finish = ses.ended or GetServerTime()
        local by = ses.by or ses.createdBy
        self.sub:SetText(("%s · %s · started by %s%s"):format(date("%A %B %d, %H:%M", begin), Duration(finish - begin),
          D.FirstName(by) or "?", ses.endedBy and ses.endedBy ~= by and (", ended by " .. D.FirstName(ses.endedBy)) or ""))
      end
    elseif sel.clm then
      self.sub:SetText("Loot history imported from Core Loot Manager · a record only, no DKP was changed")
    else
      self.sub:SetText("Raid night from before raid sessions (grouped by date)")
    end
    -- attendance: the end-of-raid list, or everyone awarded so far
    local set = {}
    if ses and ses.ended then
      for n in pairs(ses.attendees) do set[n] = true end
    else
      for _, e in ipairs(night.awards) do for _, n in ipairs(D.SplitNames(e.p)) do set[D.Pool(n)] = true end end
      if sel.kind == "live" or sel.kind == "planned" then for n in pairs(D.raid) do set[D.Pool(n)] = true end end
    end
    local attendees = Names(set)
    local given, spent = 0, 0
    for _, e in ipairs(night.awards) do given = given + (tonumber(e.v) or 0) * #D.SplitNames(e.p) end
    for _, e in ipairs(night.spends) do spent = spent + (tonumber(e.v) or 0) end
    if sel.clm then
      self.stats:SetText(("%d item%s · %d DKP spent in CLM"):format(#night.spends, #night.spends == 1 and "" or "s", spent))
      self.aHead:SetText("ATTENDANCE")
      self.attend:SetText("|cffa7afbaNot part of CLM's loot export|r")
    else
      self.stats:SetText(("%d attended · %d DKP awarded · %d item%s · %d DKP spent"):format(
        #attendees, given, #night.spends, #night.spends == 1 and "" or "s", spent))
      self.aHead:SetText(ses and ses.ended and "ATTENDANCE" or "IN THE RAID / AWARDED SO FAR")
      local short = {}
      for i, n in ipairs(attendees) do short[i] = D.FirstName(n) end
      self.attend:SetText(#short > 0 and table.concat(short, ", ") or "|cffa7afbaNobody recorded|r")
    end

    local loot = {}
    for _, e in ipairs(night.spends) do loot[#loot + 1] = e end
    table.sort(loot, function(a, b) return a.t < b.t end)
    local rows = { { head = "LOOT · who won it and what they paid" } }
    for _, e in ipairs(loot) do rows[#rows + 1] = { loot = e } end
    if #loot == 0 then rows[#rows + 1] = { line = "|cffa7afbaNo loot awarded.|r" } end
    rows[#rows + 1] = { head = "AWARDS" }
    local awards = MergedAwards(night.awards)
    for _, a in ipairs(awards) do rows[#rows + 1] = { award = a } end
    if #awards == 0 then rows[#rows + 1] = { line = "|cffa7afbaNo awards.|r" } end
    if self.shownKey ~= sel.key then self.detail.offset = 0; self.shownKey = sel.key end
    self.detail:SetData(rows, FillDetail)
  end
end

---------------------------------------------------------------------------
-- v0.3.0 Logs: the whole ledger with CLM-style filters across the top
---------------------------------------------------------------------------
local logF = { type = "all", time = "all" }
function D.ShowLogsFor(name)
  logF.char = name
  D.Toggle("logs", true)
end

local LOG_TYPES = { { "all", "All types" }, { "loot", "Loot" }, { "boss", "Boss kills" }, { "award", "Other awards" },
  { "adjust", "Adjustments" }, { "decay", "Decay" }, { "raid", "Raids" }, { "undo", "Undos" }, { "other", "Other" } }
local LOG_TIMES = { { "all", "All time" }, { "night", "Last 12 hours" }, { "week", "Last 7 days" }, { "month", "Last 30 days" } }
local LOG_CUT = { night = 12 * 3600, week = 7 * 86400, month = 30 * 86400 }

local function LabelOf(opts, v)
  for _, o in ipairs(opts) do if o[1] == v then return o[2] end end
  return opts[1] and opts[1][2] or ""
end

local function BuildLogs(p)
  local bar = CreateFrame("Frame", nil, p, BD)
  bar:SetPoint("TOPLEFT", 10, -10); bar:SetPoint("TOPRIGHT", -10, -10); bar:SetHeight(54)
  Skin(bar, PANEL, COL.line)

  local function CharOpts()
    local o, names = { { "", "Everyone" } }, {}
    for _, st in ipairs(D.Standings()) do names[#names + 1] = st.name end
    table.sort(names)
    for _, n in ipairs(names) do o[#o + 1] = { n, D.FirstName(n) or n } end
    return o
  end
  local function RaidOpts()
    local o = { { "", "Any raid" } }
    for _, r in ipairs(RaidRows()) do
      if r.key and r.kind ~= "up" and #o < 25 then
        o[#o + 1] = { r.key, ("%s (%s)"):format(r.title or "Raid", date("%b %d", r.t or 0)) }
      end
    end
    return o
  end
  local function ByOpts()
    local o, seen, list = { { "", "Anyone" } }, {}, {}
    for _, e in ipairs(D.data.log) do
      if e.by and not seen[e.by] then seen[e.by] = true; list[#list + 1] = e.by end
    end
    table.sort(list)
    for _, n in ipairs(list) do o[#o + 1] = { n, D.FirstName(n) or n } end
    return o
  end
  local opts = {
    char = CharOpts, type = function() return LOG_TYPES end, time = function() return LOG_TIMES end,
    raid = RaidOpts, by = ByOpts,
  }

  local x = 10
  p.drops = {}
  local function Filter(key, label, w)
    local l = Text(bar, 9, COL.muted, "GameFontNormalSmall"); l:SetPoint("TOPLEFT", x, -7); l:SetText(label)
    local d = Dropdown(bar, w, opts[key], function(v)
      if key == "type" or key == "time" then logF[key] = v else logF[key] = (v ~= "" and v) or nil end
      p.list.offset = 0
      p:Update()
    end)
    d:SetPoint("TOPLEFT", x, -21)
    p.drops[key] = d
    x = x + w + 10
  end
  Filter("char", "CHARACTER", 140)
  Filter("type", "TYPE", 116)
  Filter("time", "TIME", 110)
  Filter("raid", "RAID", 170)
  Filter("by", "OFFICER", 110)

  p.count = Text(p, 11, COL.muted); p.count:SetPoint("TOPLEFT", 14, -74)
  p.clear = Btn(p, "Clear filters", 96, 20, "ghost", function()
    logF.char, logF.raid, logF.by, logF.type, logF.time = nil, nil, nil, "all", "all"
    p.list.offset = 0
    p:Update()
  end)
  p.clear:SetPoint("TOPRIGHT", -10, -70)

  local panel = CreateFrame("Frame", nil, p, BD)
  panel:SetPoint("TOPLEFT", 10, -94); panel:SetPoint("BOTTOMRIGHT", -10, 10)
  Skin(panel, PANEL, COL.line)
  p.list = List(panel, 36, 10, function(parent)
    local r = CreateFrame("Frame", nil, parent)
    r.time = Text(r, 10, COL.muted); r.time:SetPoint("TOPLEFT", 12, -5); r.time:SetWidth(70)
    r.icon = Icon(r, 24); r.icon:SetPoint("TOPLEFT", 86, -6)
    r.text = Text(r, 12, COL.text)
    r.text:SetPoint("TOPRIGHT", -160, -5)
    r.who = Text(r, 10, COL.muted)
    r.who:SetPoint("TOPLEFT", r.text, "BOTTOMLEFT", 0, -2)
    r.who:SetPoint("TOPRIGHT", r.text, "BOTTOMRIGHT", 0, -2)
    r.amt = Text(r, 12, COL.text, "GameFontNormal"); r.amt:SetPoint("RIGHT", -74, 0); r.amt:SetJustifyH("RIGHT")
    r.undo = Btn(r, "Undo", 54, 22, "ghost", function(self)
      local row = self:GetParent()
      local ids = {}
      for _, id in ipairs(row.ids or {}) do if not D.data.undone[id] then ids[#ids + 1] = id end end
      if #ids == 0 then return end
      local dlg = StaticPopup_Show("GLDKP_UNDO", row.desc)
      if dlg then dlg.data = #ids > 1 and ids or ids[1] end
    end)
    r.undo:SetPoint("RIGHT", -10, 0)
    local ln = Line(r); ln:SetPoint("BOTTOMLEFT"); ln:SetPoint("BOTTOMRIGHT")
    return r
  end)
  p.list:SetPoint("TOPLEFT", 1, -1); p.list:SetPoint("TOPRIGHT", -1, -1); p.list:SetHeight(36 * 10)

  function p:Update()
    local now = GetServerTime()
    local cut = LOG_CUT[logF.time]
    cut = cut and (now - cut) or nil
    local function keep(e)
      if cut and (e.t or 0) < cut then return false end
      if logF.type ~= "all" and TypeOf(e) ~= logF.type then return false end
      if logF.by and e.by ~= logF.by then return false end
      if logF.raid and e.g ~= logF.raid and e.x ~= logF.raid then return false end
      if logF.char and not Involves(e, logF.char) then return false end
      return true
    end
    local groups, byId = D.LogGroups(keep, 500)
    for key, d in pairs(self.drops) do
      local v = logF[key]
      if v == nil then v = "" end
      d:SetValue(v, LabelOf(opts[key](), v))
    end
    local filtered = logF.char or logF.raid or logF.by or logF.type ~= "all" or logF.time ~= "all"
    self.count:SetText(("%d entr%s · newest first%s"):format(#groups, #groups == 1 and "y" or "ies",
      #groups >= 500 and " · showing the newest 500" or ""))
    self.clear:SetShown(filtered and true or false)
    local admin = D.IsAdmin() or D.practice
    self.list:SetData(groups, function(r, g)
      local e = g.e
      local text, amt, color = GroupLine(g, byId)
      if e.k == "DC" and logF.char then
        local loss = D.data.decayLoss and D.data.decayLoss[e.id]
        if loss and loss[logF.char] then amt = ("-%d (%s%%)"):format(loss[logF.char], tostring(e.v or "?")) end
      end
      r.ids, r.desc = g.ids, text
      r.time:SetText(date("%b %d %H:%M", e.t))
      local itemID = (e.k == "SP" or e.k == "HL") and tonumber(e.x) or nil
      if itemID then
        r.icon:Show(); r.icon:SetItem(itemID)
        r.text:SetPoint("TOPLEFT", 118, -5)
        r.text:SetTextColor(D.QualityColor(itemID))
        Fit(r.text, e.r or D.ItemName(itemID))
        local spec = e.u == "OS" and " (OS)" or ""
        local src = e.k == "HL" and " · from CLM" or ""
        Fit(r.who, ("Won by %s%s%s"):format(D.FirstName(e.p) or e.p or "?", spec, src))
      else
        r.icon:Hide()
        r.text:SetPoint("TOPLEFT", 88, -5)
        r.text:SetTextColor(unpack(COL.text))
        Fit(r.text, text)
        Fit(r.who, (D.FirstName(e.by) or e.by or "?") .. (g.undone and " · undone" or "")
          .. (D.practice and D.db.practice[e.id] and " · practice" or ""))
      end
      r.amt:SetText(amt)
      r.amt:SetTextColor(unpack(color))
      r:SetAlpha(g.undone and 0.5 or 1)
      r.undo:SetShown(admin and not g.undone and e.k ~= "UN")
    end)
  end
end

---------------------------------------------------------------------------
-- v0.5.0: Hall of Fame (records, first kills), season recap, loot reveal
-- banner. All numbers come from D.data.fame, which D.Compute works out of the
-- ledger - nothing here is stored or synced.
---------------------------------------------------------------------------
local hallView, hallScope = "records", "all"
function D.SetHallView(v) hallView = (v == "recap" and "recap") or (v == "awards" and "awards") or "records" end

local ZERO = { earned = 0, spent = 0, items = 0, bosses = 0, prepared = 0, nights = 0 }
local REC_ROWS = {
  { "spent", "Most DKP spent", function(v) return v .. " DKP" end },
  { "items", "Most items won", function(v) return v .. (v == 1 and " item" or " items") end },
  { "earned", "Top earner", function(v) return v .. " DKP earned" end },
  { "streak", "Longest attendance streak", function(v) return v .. " in a row" end },
  { "nights", "Most raids attended", function(v) return v .. " raids" end },
  { "bosses", "Most boss kills", function(v) return v .. " kills" end },
  { "prepared", "Most prepared pulls", function(v) return v .. " pulls" end },
}

local function BuildHall(p)
  local th = Theme()
  p.viewSeg = Seg(p, { { "records", "Records", 92 }, { "recap", "Recap", 92 }, { "awards", "Awards", 92 } },
    function() return hallView end, function(v) hallView = v; D.Refresh() end)
  p.viewSeg:SetPoint("TOPLEFT", 10, -10)
  p.scopeSeg = Seg(p, { { "all", "All time", 84 }, { "phase", "This phase", 96 } },
    function() return hallScope end, function(v) hallScope = v; D.Refresh() end)
  p.scopeSeg:SetPoint("TOPRIGHT", -10, -10)

  -- records
  local rec = Panel(p, "Records")
  rec:SetPoint("TOPLEFT", 10, -42); rec:SetSize(360, 388)
  rec.note = Text(rec, 10, COL.muted); rec.note:SetPoint("LEFT", rec.title, "RIGHT", 10, -1)
  rec.rows = {}
  for i = 1, 8 do
    local r = CreateFrame("Frame", nil, rec)
    r:SetPoint("TOPLEFT", 1, -38 - (i - 1) * 43); r:SetPoint("TOPRIGHT", -1, -38 - (i - 1) * 43); r:SetHeight(43)
    if i > 1 then local ln = Line(r); ln:SetPoint("TOPLEFT", 8, 0); ln:SetPoint("TOPRIGHT", -8, 0) end
    r.label = Text(r, 10, COL.muted, "GameFontNormalSmall"); r.label:SetPoint("TOPLEFT", 12, -7); r.label:SetWidth(215)
    r.cls = r:CreateTexture(nil, "ARTWORK"); r.cls:SetSize(18, 18); r.cls:SetPoint("BOTTOMLEFT", 12, 5)
    r.name = Text(r, 14, COL.text); r.name:SetPoint("LEFT", r.cls, "RIGHT", 6, 0); r.name:SetWidth(170)
    r.value = Text(r, 14, COL.gold, "GameFontNormal"); r.value:SetPoint("RIGHT", -12, -6); r.value:SetJustifyH("RIGHT")
    rec.rows[i] = r
  end

  -- priciest wins
  local wins = Panel(p, "Priciest wins")
  wins:SetPoint("TOPLEFT", 380, -42); wins:SetSize(349, 204)
  wins.rows = {}
  for i = 1, 5 do
    local r = CreateFrame("Frame", nil, wins)
    r:SetPoint("TOPLEFT", 1, -38 - (i - 1) * 32); r:SetPoint("TOPRIGHT", -1, -38 - (i - 1) * 32); r:SetHeight(32)
    r.icon = Icon(r, 26); r.icon:SetPoint("LEFT", 10, 0)
    r.item = Text(r, 12, COL.text); r.item:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 8, 1); r.item:SetWidth(205)
    r.who = Text(r, 10, COL.muted); r.who:SetPoint("BOTTOMLEFT", r.icon, "BOTTOMRIGHT", 8, -1); r.who:SetWidth(205)
    r.price = Text(r, 13, COL.gold, "GameFontNormal"); r.price:SetPoint("RIGHT", -12, 0); r.price:SetJustifyH("RIGHT")
    wins.rows[i] = r
  end
  wins.empty = Text(wins, 11, COL.muted); wins.empty:SetPoint("TOPLEFT", 14, -50); wins.empty:SetText("No item wins recorded yet.")

  -- first logged kills
  local fk = Panel(p, "First logged kills")
  fk:SetPoint("TOPLEFT", 380, -252); fk:SetSize(349, 178)
  fk.sub = Text(fk, 10, COL.muted); fk.sub:SetPoint("LEFT", fk.title, "RIGHT", 10, -1)
  fk.sub:SetText("since this add-on's ledger began")
  p.kills = List(fk, 28, 5, function(parent)
    local r = CreateFrame("Frame", nil, parent)
    r.boss = Text(r, 12, COL.text); r.boss:SetPoint("LEFT", 12, 0); r.boss:SetWidth(145)
    r.date = Text(r, 11, COL.muted); r.date:SetPoint("LEFT", 165, 0); r.date:SetWidth(80)
    r.n = Text(r, 11, COL.gold); r.n:SetPoint("RIGHT", -12, 0); r.n:SetJustifyH("RIGHT")
    return r
  end)
  p.kills:SetPoint("TOPLEFT", 1, -38); p.kills:SetPoint("TOPRIGHT", -1, -38); p.kills:SetHeight(28 * 5)
  fk.empty = Text(fk, 11, COL.muted); fk.empty:SetPoint("TOPLEFT", 14, -50); fk.empty:SetText("No boss kills logged yet.")

  -- recap
  local rc = Panel(p, "Recap")
  rc:SetPoint("TOPLEFT", 10, -42); rc:SetSize(719, 388)
  p.recap = rc
  rc.iconF = CreateFrame("Frame", nil, rc, BD); rc.iconF:SetSize(48, 48); rc.iconF:SetPoint("TOPLEFT", 14, -40)
  Skin(rc.iconF, { 0.1, 0.1, 0.12, 1 }, GOLD_DIM)
  rc.icon = rc.iconF:CreateTexture(nil, "ARTWORK"); rc.icon:SetPoint("TOPLEFT", 2, -2); rc.icon:SetPoint("BOTTOMRIGHT", -2, 2)
  rc.name = Text(rc, 22, COL.text); rc.name:SetFont(TITLE_FONT, 24)
  rc.name:SetPoint("TOPLEFT", rc.iconF, "TOPRIGHT", 12, -2); rc.name:SetWidth(300)
  rc.sub = Text(rc, 11, COL.muted); rc.sub:SetPoint("TOPLEFT", rc.name, "BOTTOMLEFT", 0, -5); rc.sub:SetWidth(420)
  rc.share = ThemeBtn(rc, "Share to guild chat", 170, 28, function()
    if rc.line then D.Chat(rc.line, "GUILD", nil, true) end
  end)
  rc.share:SetPoint("TOPRIGHT", -14, -40)
  rc.mine = Btn(rc, "Mine", 56, 28, "secondary", function() D.recapName = nil; D.Refresh() end)
  rc.mine:SetPoint("RIGHT", rc.share, "LEFT", -8, 0)
  rc.tiles = {}
  for i = 1, 8 do
    local col, row = (i - 1) % 4, math.floor((i - 1) / 4)
    local t = CreateFrame("Frame", nil, rc, BD)
    t:SetSize(164, 60); t:SetPoint("TOPLEFT", 14 + col * 175, -108 - row * 68) -- v1.6.0: 74 / 84 before, to make room for the awards line
    Skin(t, { 0.1, 0.105, 0.13, 1 }, GOLD_DIM)
    t.label = Text(t, 10, COL.muted, "GameFontNormalSmall"); t.label:SetPoint("TOPLEFT", 10, -9)
    t.value = Text(t, 24, COL.gold); t.value:SetFont(TITLE_FONT, 24); t.value:SetPoint("BOTTOMLEFT", 10, 8)
    t.sub = Text(t, 10, COL.muted); t.sub:SetPoint("BOTTOMRIGHT", -10, 11); t.sub:SetJustifyH("RIGHT")
    rc.tiles[i] = t
  end
  rc.bestIcon = Icon(rc, 32); rc.bestIcon:SetPoint("TOPLEFT", 14, -246)
  rc.best = Text(rc, 12, COL.text); rc.best:SetPoint("LEFT", rc.bestIcon, "RIGHT", 10, 0); rc.best:SetWidth(640)
  local bh = Text(rc, 10, COL.muted, "GameFontNormalSmall"); bh:SetPoint("TOPLEFT", 14, -288); bh:SetText("BADGES")
  rc.badges = Text(rc, 12, COL.text); rc.badges:SetPoint("TOPLEFT", 14, -302); rc.badges:SetWidth(690)
  rc.badges:SetWordWrap(true); rc.badges:SetJustifyV("TOP"); rc.badges:SetHeight(36)
  -- v1.6.0: podium awards (all time: they are not split by phase)
  local awh = Text(rc, 10, COL.muted, "GameFontNormalSmall"); awh:SetPoint("TOPLEFT", 14, -344); awh:SetText("PODIUM AWARDS  ·  all time")
  rc.awards = Text(rc, 12, COL.text); rc.awards:SetPoint("TOPLEFT", 14, -358); rc.awards:SetWidth(690)
  rc.awards:SetWordWrap(true); rc.awards:SetJustifyV("TOP"); rc.awards:SetHeight(24)
  rc.awardHit = CreateFrame("Frame", nil, rc)
  rc.awardHit:SetPoint("TOPLEFT", 14, -358); rc.awardHit:SetSize(690, 24); rc.awardHit:EnableMouse(true)
  rc.awardHit:SetScript("OnEnter", function(self) if rc.shownName and D.ShowPodiumAwardTip then D.ShowPodiumAwardTip(self, rc.shownName) end end)
  rc.awardHit:SetScript("OnLeave", function() GameTooltip:Hide() end)

  -- v1.6.0: Awards view: who holds each podium award. Good awards left, roasts right.
  local aw = Panel(p, "Podium awards")
  aw:SetPoint("TOPLEFT", 10, -42); aw:SetSize(719, 388)
  p.awards = aw
  aw.note = Text(aw, 10, COL.muted); aw.note:SetPoint("LEFT", aw.title, "RIGHT", 10, -1)
  aw.rows, aw.sum = {}, {}
  local function AwardRow(parent, x, y, first)
    local r = CreateFrame("Frame", nil, parent)
    r:SetSize(357, 38); r:SetPoint("TOPLEFT", x, y)
    if not first then local ln = Line(r); ln:SetPoint("TOPLEFT", 8, 0); ln:SetPoint("TOPRIGHT", -8, 0) end
    return r
  end
  for i = 1, 16 do
    local right = i > 9
    local idx = right and (i - 9) or i
    local r = AwardRow(aw, right and 359 or 1, -38 - (idx - 1) * 38, idx == 1)
    r.icon = r:CreateTexture(nil, "ARTWORK"); r.icon:SetSize(30, 30); r.icon:SetPoint("LEFT", 10, 0)
    r.name = Text(r, 12, COL.text); r.name:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 8, -1); r.name:SetWidth(170)
    r.who = Text(r, 11, COL.muted); r.who:SetPoint("BOTTOMLEFT", r.icon, "BOTTOMRIGHT", 8, 1); r.who:SetWidth(215)
    r.count = Text(r, 14, COL.gold, "GameFontNormal"); r.count:SetPoint("TOPRIGHT", -12, -6); r.count:SetJustifyH("RIGHT")
    r.total = Text(r, 10, COL.muted); r.total:SetPoint("BOTTOMRIGHT", -12, 5); r.total:SetJustifyH("RIGHT")
    r:EnableMouse(true)
    r:SetScript("OnEnter", function(self)
      if not self.code then return end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      local rr, gg, bb = D.AwardColor(self.code)
      GameTooltip:AddLine(D.AwardInline(self.code, 16) .. " " .. D.PodiumAwardName(self.code), rr, gg, bb)
      GameTooltip:AddLine(D.AwardFlavor(self.code), 0.8, 0.82, 0.86, true)
      GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    aw.rows[i] = r
  end
  for i = 1, 2 do -- the two summary rows under the roasts
    local r = AwardRow(aw, 359, -38 - (6 + i) * 38, false)
    r.label = Text(r, 10, COL.muted, "GameFontNormalSmall"); r.label:SetPoint("TOPLEFT", 12, -6)
    r.cls = r:CreateTexture(nil, "ARTWORK"); r.cls:SetSize(18, 18); r.cls:SetPoint("BOTTOMLEFT", 12, 3)
    r.name = Text(r, 13, COL.text); r.name:SetPoint("LEFT", r.cls, "RIGHT", 6, 0); r.name:SetWidth(170)
    r.value = Text(r, 13, COL.gold, "GameFontNormal"); r.value:SetPoint("RIGHT", -12, -6); r.value:SetJustifyH("RIGHT")
    aw.sum[i] = r
  end
  aw.roastsOff = Text(aw, 11, COL.muted); aw.roastsOff:SetPoint("TOPLEFT", 375, -50)
  aw.roastsOff:SetText("Roast awards are switched off by the Guild Master.")

  -- banner options live here, next to the feature
  local cb1 = Check(p, "Loot reveal banner", function() return D.settings.lootReveal ~= false end,
    function(v) D.settings.lootReveal = v end)
  cb1:SetPoint("BOTTOMLEFT", 10, 4)
  local cb2 = Check(p, "Sound when I win", function() return D.settings.revealSound ~= false end,
    function(v) D.settings.revealSound = v end)
  cb2:SetPoint("BOTTOMLEFT", 200, 4)
  local test = Btn(p, "Preview banner", 120, 22, "ghost", function()
    D.ShowReveal({ item = 32837, name = "Warglaive of Azzinoth", who = D.Me(), price = 250, mine = true, left = D.Balance(D.Me()) })
  end)
  test:SetPoint("BOTTOMRIGHT", -10, 6)

  function p:Update()
    self.viewSeg:Refresh(); self.scopeSeg:Refresh()
    local f = D.data and D.data.fame
    local scope = hallScope
    local showRec = hallView == "records"
    rec:SetShown(showRec); wins:SetShown(showRec); fk:SetShown(showRec); rc:SetShown(hallView == "recap")
    aw:SetShown(hallView == "awards")
    self.scopeSeg:SetShown(hallView ~= "awards") -- awards are not split by phase
    if not f then return end
    local since = f.phaseStart or 0
    local scopeText = scope == "all" and "everything in the ledger"
      or (since > 0 and ("since " .. date("%d %b %Y", since)) or "no phase started yet: same as all time")

    if showRec then
      rec.note:SetText(scopeText)
      local rows = {}
      local w = f.wins[scope][1]
      rows[1] = { "Biggest single bid", w and w.who, w and (w.price .. " DKP"), w and w.name }
      for _, spec in ipairs(REC_ROWS) do
        local top = f.top[scope][spec[1]]
        rows[#rows + 1] = { spec[2], top and top.pool, top and spec[3](top.v) }
      end
      for i, r in ipairs(rec.rows) do
        local d = rows[i]
        if d then
          r:Show()
          Fit(r.label, d[4] and (d[1] .. "  ·  " .. d[4]) or d[1])
          if d[2] then
            SetClassIcon(r.cls, D.ClassOf(d[2]))
            r.name:SetText(D.FirstName(d[2]) or d[2])
            r.name:SetTextColor(ClassColor(D.ClassOf(d[2])))
            r.value:SetText(d[3] or "")
          else
            r.cls:Hide(); r.name:SetText("-"); r.name:SetTextColor(unpack(COL.muted)); r.value:SetText("")
          end
        else
          r:Hide()
        end
      end
      local list = f.wins[scope]
      wins.empty:SetShown(#list == 0)
      for i, r in ipairs(wins.rows) do
        local x = list[i]
        if x then
          r:Show()
          if x.item then r.icon:SetItem(x.item); r.icon:Show() else r.icon:Hide() end
          r.item:SetText(x.name or (x.item and D.ItemName(x.item)) or "Item")
          if x.item then r.item:SetTextColor(D.QualityColor(x.item)) else r.item:SetTextColor(unpack(COL.text)) end
          r.who:SetText(Colored(x.who) .. (x.os and " (OS)" or "") .. "  ·  " .. date("%d %b %Y", x.t or 0) .. (x.clm and "  ·  CLM history" or ""))
          r.price:SetText(x.price .. " DKP")
        else
          r:Hide()
        end
      end
      fk.empty:SetShown(#f.firstKills == 0)
      self.kills:SetData(f.firstKills, function(r, k)
        Fit(r.boss, k.boss)
        r.date:SetText(date("%d %b %Y", k.t))
        r.n:SetText(("%d raiders · %dx"):format(k.raiders, k.kills))
      end)
    elseif hallView == "awards" then
      local leaders, sums = D.PodiumAwardLeaders()
      local roastsOn = D.PodiumRoastsOn()
      aw.note:SetText("all time, from the raid awards officers have shared")
      aw.roastsOff:SetShown(not roastsOn)
      for i, o in ipairs(leaders) do
        local r = aw.rows[i]
        if o.def.kind == "roast" and not roastsOn then
          r:Hide()
        else
          r:Show()
          r.code = o.code
          r.icon:SetTexture(D.AwardIcon(o.code))
          r.name:SetText(o.def.name)
          r.name:SetTextColor(D.AwardColor(o.code))
          if #o.who > 0 then
            local names = {}
            for k = 1, math.min(2, #o.who) do names[k] = Colored(o.who[k]) end
            r.who:SetText(table.concat(names, ", ") .. (#o.who > 2 and ("  |cffa7afba+" .. (#o.who - 2) .. " tied|r") or (#o.who == 2 and "  |cffa7afbatied|r" or "")))
            r.count:SetText("x" .. o.best)
            r.total:SetText(o.total .. " given in total")
          else
            r.who:SetText("|cffa7afbaNot won yet|r")
            r.count:SetText("")
            r.total:SetText("")
          end
        end
      end
      local function Sum(r, label, s, unit)
        r:Show()
        r.label:SetText(label)
        if s then
          SetClassIcon(r.cls, D.ClassOf(s[1]))
          r.name:SetText(D.FirstName(s[1]) or s[1]); r.name:SetTextColor(ClassColor(D.ClassOf(s[1])))
          r.value:SetText(s[2] .. " " .. unit .. (s[2] == 1 and "" or "s"))
        else
          r.cls:Hide(); r.name:SetText("-"); r.name:SetTextColor(unpack(COL.muted)); r.value:SetText("")
        end
      end
      Sum(aw.sum[1], "MOST DECORATED", sums.decorated, "award")
      Sum(aw.sum[2], "MOST ROASTED", sums.roasted, "roast")
      aw.sum[2]:SetShown(roastsOn)
    else
      local name = D.recapName or D.Me()
      local pool = D.Pool(name)
      local st, sk = D.FameStats(name, scope)
      st = st or ZERO
      sk = sk or { best = 0, cur = 0 }
      local class = D.ClassOf(pool)
      SetClassIcon(rc.icon, class)
      rc.name:SetText(D.FirstName(pool) or pool)
      rc.name:SetTextColor(ClassColor(class))
      local cname = class and LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[class] or "Raider"
      local standing = D.Standings()
      local rank
      for i, s2 in ipairs(standing) do if s2.name == pool then rank = i end end
      rc.sub:SetText(("%s · %s · %d DKP now · %s"):format(cname,
        rank and ("rank #" .. rank .. " of " .. #standing) or "not on Standings", D.Balance(pool),
        scope == "all" and "all time" or "this phase"))
      rc.mine:SetShown(D.recapName ~= nil)
      local N = tonumber(D.Cfg("ATTENDANCE_RAIDS")) or 10
      local T = {
        { "RAIDS ATTENDED", st.nights, "of " .. f.nightCount[scope] },
        { "ATTENDANCE", D.Attendance(name) .. "%", "last " .. N .. " raids" },
        { "BEST STREAK", sk.best, sk.cur > 0 and ("now " .. sk.cur) or "" },
        { "BOSS KILLS", st.bosses, "" },
        { "ITEMS WON", st.items, "" },
        { "DKP SPENT", st.spent, "" },
        { "DKP EARNED", st.earned, "" },
        { "PREPARED PULLS", st.prepared, "" },
      }
      for i, t in ipairs(rc.tiles) do
        t.label:SetText(T[i][1]); t.value:SetText(T[i][2]); t.sub:SetText(T[i][3])
      end
      local best
      for _, it in ipairs(D.data.items[pool] or {}) do
        if (scope == "all" or (it.t or 0) >= since) and (not best or (tonumber(it.price) or 0) > (tonumber(best.price) or 0)) then best = it end
      end
      if best and (tonumber(best.price) or 0) > 0 then
        if best.item then rc.bestIcon:SetItem(best.item); rc.bestIcon:Show() else rc.bestIcon:Hide() end
        rc.best:SetText(("Priciest win: %s for |cffe0b04f%d DKP|r%s · %s"):format(best.name or (best.item and D.ItemName(best.item)) or "an item",
          tonumber(best.price), best.os and " (OS)" or "", date("%d %b %Y", best.t or 0)))
      else
        rc.bestIcon:Hide()
        rc.best:SetText("|cffa7afbaNo item wins in this period yet.|r")
      end
      local bs, parts = D.Badges(name), {}
      for _, b in ipairs(bs) do parts[#parts + 1] = ("%s |c%s%s|r |cffa7afba%s|r"):format(D.BadgeInline(b.label, 20), b.hex, b.label, b.tip) end
      rc.badges:SetText(#parts > 0 and table.concat(parts, "     ") or "|cffa7afbaNone earned yet.|r")
      rc.shownName = name
      local aws = D.PodiumAwardStrip and D.PodiumAwardStrip(name, 20, 16) or ""
      rc.awards:SetText(aws ~= "" and aws or "|cffa7afbaNone yet.|r")
      rc.line = ("%s's recap (%s): %d raids, %d%% attendance, best streak %d, %d items won, %d DKP spent. - Guild Ladder DKP"):format(
        D.FirstName(pool) or pool, scope == "all" and "all time" or "this phase", st.nights, D.Attendance(name), sk.best, st.items, st.spent)
    end
  end
end
D.BuildHall = BuildHall

-- loot reveal banner: item icon, class-coloured winner, price. Fades in and
-- out, never more than a few waiting (a run of awards shows the latest ones).
local reveal, revealQ, NextReveal = nil, {}, nil
NextReveal = function()
  local it = table.remove(revealQ, 1)
  if not it or not reveal then return end
  local f = reveal
  if it.item then f.icon:SetItem(it.item) else f.icon.tex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark") end
  f.item:SetText(it.name or (it.item and D.ItemName(it.item)) or "Item")
  if it.item then f.item:SetTextColor(D.QualityColor(it.item)) else f.item:SetTextColor(unpack(COL.text)) end
  f.who:SetText(it.mine and "Congratulations, you won it!" or ("won by " .. Colored(it.who)))
  f.price:SetText(("for |cffe0b04f%d DKP|r%s%s"):format(it.price or 0, it.os and "  (off-spec)" or "",
    it.left and ("  ·  " .. it.left .. " DKP left") or ""))
  f:SetBackdropBorderColor(COL.gold[1], COL.gold[2], COL.gold[3], it.mine and 1 or 0.5)
  f.t = 0
  f.hold = it.mine and 9 or ((#revealQ >= 2) and 3 or 6)
  f:SetAlpha(0)
  f:Show()
  if it.mine and D.settings.revealSound ~= false and SOUNDKIT and SOUNDKIT.UI_EPICLOOT_TOAST then
    pcall(PlaySound, SOUNDKIT.UI_EPICLOOT_TOAST)
  end
end

local function BuildReveal()
  local f = CreateFrame("Button", "GuildLadderDKPReveal", UIParent, BD)
  f:SetSize(430, 92); f:SetPoint("TOP", 0, -110); f:SetFrameStrata("DIALOG")
  Skin(f, { 0.055, 0.059, 0.075, 0.97 }, GOLD_DIM)
  local bar = f:CreateTexture(nil, "ARTWORK"); bar:SetColorTexture(COL.gold[1], COL.gold[2], COL.gold[3], 1)
  bar:SetHeight(3); bar:SetPoint("TOPLEFT", 1, -1); bar:SetPoint("TOPRIGHT", -1, -1)
  f.head = Text(f, 10, COL.gold, "GameFontNormalSmall"); f.head:SetPoint("TOPLEFT", 84, -11); f.head:SetText("LOOT AWARDED")
  f.icon = Icon(f, 56); f.icon:SetPoint("LEFT", 14, 0)
  f.item = Text(f, 18, COL.text); f.item:SetFont(TITLE_FONT, 18); f.item:SetPoint("TOPLEFT", 84, -26); f.item:SetWidth(335)
  f.who = Text(f, 13, COL.text); f.who:SetPoint("TOPLEFT", f.item, "BOTTOMLEFT", 0, -5); f.who:SetWidth(335)
  f.price = Text(f, 12, COL.muted); f.price:SetPoint("TOPLEFT", f.who, "BOTTOMLEFT", 0, -3); f.price:SetWidth(335)
  f.t, f.hold = 0, 6
  f:SetScript("OnClick", function(self) self.t = 0.25 + self.hold end) -- click = start fading now
  f:SetScript("OnUpdate", function(self, el)
    self.t = self.t + el
    local a
    if self.t < 0.25 then a = self.t / 0.25
    elseif self.t < 0.25 + self.hold then a = 1
    else a = 1 - (self.t - 0.25 - self.hold) / 0.8 end
    if a <= 0 then self:Hide(); NextReveal() else self:SetAlpha(math.min(1, a)) end
  end)
  f:Hide()
  reveal = f
end

-- info = { item, name, who, price, os, mine, left }
function D.ShowReveal(info)
  if not reveal then BuildReveal() end
  if #revealQ >= 4 then table.remove(revealQ, 1) end
  revealQ[#revealQ + 1] = info
  if not reveal:IsShown() then NextReveal() end
end

---------------------------------------------------------------------------
-- v0.6.1: Gear plan window (data from BiS.lua's B.Plan). One row per slot:
-- what I wear and its tier, then the BIS / Alt targets for the phase.
-- Click a target to add it to / remove it from my wishlist; shift-click links.
---------------------------------------------------------------------------
local gear
local gearPhase -- nil = follow the guild's BiS phase
-- v0.6.2: polished layout - header with class icon + progress bar, framed
-- controls, rows with a status edge, slot icons, tier pills, tier-coloured
-- target borders, and non-upgrades faded.
local SLOT_INV = { head = "HeadSlot", neck = "NeckSlot", shoulder = "ShoulderSlot", back = "BackSlot", chest = "ChestSlot",
  wrist = "WristSlot", hands = "HandsSlot", waist = "WaistSlot", legs = "LegsSlot", feet = "FeetSlot",
  ring = "Finger0Slot", trinket = "Trinket0Slot", mh = "MainHandSlot", oh = "SecondaryHandSlot", ranged = "RangedSlot" }
local function SlotTexture(key)
  if not GetInventorySlotInfo or not SLOT_INV[key] then return nil end
  local ok, _, tex = pcall(GetInventorySlotInfo, SLOT_INV[key])
  return ok and tex or nil
end
local TIER_RGB = { BIS = { 1, 0.5, 0 }, Alt = { 0.31, 0.82, 0.77 } }
local TIER_RANK = { BIS = 3, Alt = 2 }
local PILL = {
  BIS = { "BIS", { 0.30, 0.17, 0.05 }, { 1, 0.62, 0.25 } },
  Alt = { "Alt", { 0.07, 0.21, 0.2 }, { 0.56, 0.88, 0.77 } },
  off = { "Off list", { 0.17, 0.19, 0.23 }, { 0.655, 0.686, 0.729 } },
  empty = { "Empty", { 0.27, 0.09, 0.08 }, { 1, 0.48, 0.42 } },
}
local ACCENT = { BIS = { 1, 0.5, 0 }, Alt = { 0.31, 0.82, 0.77 }, off = { 0.4, 0.42, 0.46 }, empty = { 0.8, 0.27, 0.22 } }
local GEAR_X = { slotIcon = 14, label = 38, worn = 148, pills = 208, targets = 336 }
local MAX_TARGETS = 11

local function GearBuild()
  local B = D.BiS
  local f = Window("GuildLadderDKPGear", "Gear plan", 800, 664, "CENTER", 140, 0) -- v1.3.0: 60 wider for the Enchants & Gems button; v1.4.0: 20 more for Enchants + Gems

  -- header: class icon, title, spec / phase line, progress
  f.head:SetHeight(58)
  f.crest:SetSize(42, 42); f.crest:ClearAllPoints(); f.crest:SetPoint("LEFT", 12, 0) -- v0.9.0: the faction crest (class icon moved into the subtitle)
  f.title:ClearAllPoints(); f.title:SetFont(TITLE_FONT, 24); f.title:SetPoint("TOPLEFT", f.crest, "TOPRIGHT", 10, 1)
  f.sub:ClearAllPoints(); f.sub:SetPoint("BOTTOMLEFT", f.crest, "BOTTOMRIGHT", 10, 1)
  f.prog = CreateFrame("Frame", nil, f.head, BD); f.prog:SetSize(150, 10); f.prog:SetPoint("RIGHT", -56, -8)
  Skin(f.prog, { 0.06, 0.065, 0.08, 1 }, GOLD_DIM)
  f.progBis = f.prog:CreateTexture(nil, "ARTWORK"); f.progBis:SetColorTexture(1, 0.5, 0, 1)
  f.progBis:SetPoint("TOPLEFT", 1, -1); f.progBis:SetPoint("BOTTOMLEFT", 1, 1)
  f.progAlt = f.prog:CreateTexture(nil, "ARTWORK"); f.progAlt:SetColorTexture(0.31, 0.82, 0.77, 1)
  f.progAlt:SetPoint("TOPLEFT", f.progBis, "TOPRIGHT"); f.progAlt:SetPoint("BOTTOMLEFT", f.progBis, "BOTTOMRIGHT")
  f.progText = Text(f.head, 12, COL.text); f.progText:SetPoint("BOTTOMRIGHT", f.prog, "TOPRIGHT", 0, 5); f.progText:SetJustifyH("RIGHT")
  f.raidBtn = Btn(f.head, "Raid loot", 96, 26, "secondary", function() D.ShowRaidLoot() end) -- v0.7.0
  f.raidBtn:SetPoint("RIGHT", f.prog, "LEFT", -70, 0)
  -- v1.4.0: Enchants and Gems are separate windows now
  f.gemsBtn = Btn(f.head, "Gems", 56, 26, "secondary", function() D.ToggleGems(true) end)
  f.gemsBtn:SetPoint("RIGHT", f.raidBtn, "LEFT", -8, 0)
  f.enchBtn = Btn(f.head, "Enchants", 76, 26, "secondary", function() D.ToggleEnchants(true) end)
  f.enchBtn:SetPoint("RIGHT", f.gemsBtn, "LEFT", -6, 0)

  -- controls bar
  local bar = CreateFrame("Frame", nil, f, BD)
  bar:SetPoint("TOPLEFT", 10, -68); bar:SetPoint("TOPRIGHT", -10, -68); bar:SetHeight(38)
  Skin(bar, PANEL, COL.line)
  local pl = Text(bar, 10, COL.muted, "GameFontNormalSmall"); pl:SetPoint("LEFT", 12, 0); pl:SetText("PHASE")
  local opts = {}
  for ph = 0, 5 do opts[#opts + 1] = { ph, ph == 0 and "Pre-raid" or ("P" .. ph), ph == 0 and 64 or 36 } end
  f.phaseSeg = Seg(bar, opts, function() return gearPhase or B.Phase() end, function(v)
    gearPhase = (v ~= B.Phase()) and v or nil
    D.RefreshGearPlan()
  end)
  f.phaseSeg:SetPoint("LEFT", pl, "RIGHT", 10, 0)
  f.guildChip = Chip(bar); f.guildChip:SetPoint("LEFT", f.phaseSeg, "RIGHT", 12, 0)
  f.back = Btn(bar, "Back to guild phase", 118, 22, "ghost", function() gearPhase = nil; D.RefreshGearPlan() end)
  f.back:SetPoint("LEFT", f.guildChip, "RIGHT", 8, 0)
  f.specDD = Dropdown(bar, 140, function() return B.SpecOptions() end, function(v)
    B.SetSpec(v ~= "auto" and v or nil)
    D.RefreshGearPlan()
  end)
  f.specDD:SetPoint("RIGHT", -10, 0)

  -- body
  local body = CreateFrame("Frame", nil, f, BD)
  body:SetPoint("TOPLEFT", 10, -114); body:SetPoint("BOTTOMRIGHT", -10, 44)
  Skin(body, PANEL, COL.line)
  f.body = body
  local function Head(x, text)
    local t = Text(body, 10, COL.muted, "GameFontNormalSmall"); t:SetPoint("TOPLEFT", x, -10); t:SetText(text)
    return t
  end
  Head(GEAR_X.slotIcon, "SLOT"); Head(GEAR_X.worn, "WEARING"); local th = Head(GEAR_X.targets, "TARGETS")
  -- legend: BIS / Alt squares, wishlisted tick, faded = not an upgrade
  local lx = GEAR_X.targets + 70
  local function Square(rgb, label)
    local sq = body:CreateTexture(nil, "ARTWORK"); sq:SetSize(9, 9); sq:SetPoint("TOPLEFT", lx, -11); sq:SetColorTexture(rgb[1], rgb[2], rgb[3], 1)
    local t = Text(body, 10, COL.muted, "GameFontNormalSmall"); t:SetPoint("LEFT", sq, "RIGHT", 4, 0); t:SetText(label)
    lx = lx + 13 + math.max(24, #label * 6)
  end
  Square(TIER_RGB.BIS, "BIS"); Square(TIER_RGB.Alt, "Alt")
  local tick = body:CreateTexture(nil, "ARTWORK"); tick:SetSize(12, 12); tick:SetPoint("TOPLEFT", lx, -9); tick:SetTexture(READY)
  local tt = Text(body, 10, COL.muted, "GameFontNormalSmall"); tt:SetPoint("LEFT", tick, "RIGHT", 3, 0); tt:SetText("wishlisted   ·   faded = no upgrade for you")
  local hl = Line(body); hl:SetPoint("TOPLEFT", 8, -26); hl:SetPoint("TOPRIGHT", -8, -26)

  f.rows = {}
  for i, g in ipairs(B.GROUPS) do
    local r = CreateFrame("Frame", nil, body)
    r:SetPoint("TOPLEFT", 1, -30 - (i - 1) * 31); r:SetPoint("TOPRIGHT", -1, -30 - (i - 1) * 31); r:SetHeight(31)
    if i % 2 == 0 then local bg = r:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(1, 1, 1, 0.03) end
    r.accent = r:CreateTexture(nil, "ARTWORK"); r.accent:SetWidth(3)
    r.accent:SetPoint("TOPLEFT", 1, -4); r.accent:SetPoint("BOTTOMLEFT", 1, 4)
    r.slotIcon = r:CreateTexture(nil, "ARTWORK"); r.slotIcon:SetSize(18, 18); r.slotIcon:SetPoint("LEFT", GEAR_X.slotIcon, 0)
    r.slotIcon:SetTexture(SlotTexture(g[1])); r.slotIcon:SetAlpha(0.8)
    r.label = Text(r, 12, COL.text); r.label:SetPoint("LEFT", GEAR_X.label, 0); r.label:SetWidth(104)
    r.worn, r.pills = {}, {}
    for k = 1, 2 do
      local ic = Icon(r, 24); ic:SetPoint("LEFT", GEAR_X.worn + (k - 1) * 28, 0); r.worn[k] = ic
      r.pills[k] = Chip(r)
    end
    r.pills[1]:SetPoint("LEFT", GEAR_X.pills, 0)
    r.pills[2]:SetPoint("LEFT", r.pills[1], "RIGHT", 4, 0)
    r.tg = {}
    for k = 1, MAX_TARGETS do
      local ic = Icon(r, 25)
      ic.wish = ic:CreateTexture(nil, "OVERLAY"); ic.wish:SetSize(13, 13); ic.wish:SetPoint("TOPRIGHT", 5, 5); ic.wish:SetTexture(READY)
      local orig = ic:GetScript("OnMouseUp")
      ic:SetScript("OnMouseUp", function(self, btn)
        if IsModifiedClick and IsModifiedClick() then
          if orig then orig(self, btn) end
        elseif self.gearID then
          D.Wish(self.gearID, not self.wished)
        end
      end)
      r.tg[k] = ic
    end
    r.more = Text(r, 10, COL.muted)
    r.none = Text(r, 11, COL.muted); r.none:SetPoint("LEFT", GEAR_X.targets, 0)
    f.rows[i] = r
  end
  f.msg = Text(body, 13, COL.muted); f.msg:SetPoint("TOP", 0, -120); f.msg:SetWidth(560); f.msg:SetWordWrap(true)

  -- footer
  local c1 = Check(f, "BiS lines on tooltips", function() return D.settings.bisTooltip ~= false end,
    function(v) D.settings.bisTooltip = v end)
  c1:SetPoint("BOTTOMLEFT", 10, 10)
  local c2 = Check(f, "\"Best for\" list", function() return D.settings.bisBestFor ~= false end,
    function(v) D.settings.bisBestFor = v end)
  c2:SetPoint("BOTTOMLEFT", 190, 10)
  local c3 = Check(f, "Show Alts", function() return D.settings.gearAlts ~= false end,
    function(v) D.settings.gearAlts = v; D.RefreshGearPlan() end)
  c3:SetPoint("BOTTOMLEFT", 330, 10)
  f.src = Text(f, 10, COL.muted); f.src:SetPoint("BOTTOMRIGHT", -16, 16); f.src:SetJustifyH("RIGHT"); f.src:SetWidth(220)
  f:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
  f:SetScript("OnEvent", function() if f:IsShown() then D.RefreshGearPlan() end end)
  return f
end

function D.RefreshGearPlan()
  local f = gear
  if not f or not f:IsShown() or not D.BiS then return end
  local B = D.BiS
  local d = B.Data()
  local gp = B.Phase()
  local class, spec = B.MySpec()
  f.phaseSeg:Refresh()
  f.phaseSeg:SetShown(d ~= nil)
  f.guildChip:SetShown(d ~= nil)
  f.guildChip:Set("Guild: " .. (B.PHASE_NAME[gp] or "?"), { 0.165, 0.14, 0.08 }, COL.gold)
  f.back:SetShown(d ~= nil and gearPhase ~= nil)
  if d then f.specDD:Show(); f.specDD:SetValue(B.SpecValue()) else f.specDD:Hide() end
  f.src:SetText(d and ("Lists: Loon Best In Slot · " .. tostring(d.version)) or "")
  local rows, info = B.Plan(gearPhase or gp, D.settings.gearAlts ~= false)
  if not rows then
    for _, r in ipairs(f.rows) do r:Hide() end
    f.prog:Hide(); f.progText:SetText("")
    f.msg:Show()
    f.msg:SetText(info == "nodata" and "No BiS lists loaded.\nThey come with Guild Ladder DKP: reinstall the add-on if BiSData_TBC.lua is missing."
      or info == "era" and "The BiS lists are for TBC, and this game isn't TBC."
      or "No spec found from your talents. Pick your spec at the top right.")
    f.sub:SetText("")
    return
  end
  f.msg:Hide()
  f.sub:SetText(("%s|c%s%s|r  ·  %s"):format(B.ClassIcon(info.class), B.ClassHex(info.class), B.SpecLabel(info.spec), B.PHASE_RAIDS[info.phase] or "?"))
  local mine = {}
  for _, id in ipairs(D.MyWishes()) do mine[id] = true end
  local nBis, nAlt, nAll = 0, 0, 0
  for i, r in ipairs(f.rows) do
    local row = rows[i]
    r:Show()
    r.label:SetText(row.label)
    -- what I wear
    local worst, worstKey = 9, "off"
    for k, ic in ipairs(r.worn) do
      local w = row.worn[k]
      local pill = r.pills[k]
      if w then
        ic:Show()
        if w.id then
          ic:SetItem(w.id)
        else
          ic.itemID = nil
          ic.tex:SetTexture(SlotTexture(row.key))
          ic:SetBackdropBorderColor(unpack(COL.line))
        end
        local key = not w.id and "empty" or (w.tier or "off")
        local pc = PILL[key]
        pill:Set(pc[1], pc[2], pc[3]); pill:Show()
        local rank = not w.id and 0 or (TIER_RANK[w.tier] or 1)
        if rank < worst then worst, worstKey = rank, key end
        nAll = nAll + 1
        if w.tier == "BIS" then nBis = nBis + 1 elseif w.tier == "Alt" then nAlt = nAlt + 1 end
      else
        ic:Hide(); pill:Hide()
      end
    end
    local ac = ACCENT[worstKey] or ACCENT.off
    r.accent:SetColorTexture(ac[1], ac[2], ac[3], 1)
    -- targets: BIS, a small gap, then Alt. Faded when it's no upgrade over what I wear.
    local x, prevTier = GEAR_X.targets, nil
    for k, ic in ipairs(r.tg) do
      local e = row.targets[k]
      if e then
        if prevTier and prevTier ~= e.tier then x = x + 8 end
        prevTier = e.tier
        ic:ClearAllPoints(); ic:SetPoint("LEFT", x, 0)
        x = x + 29
        ic:SetItem(e.id)
        local rgb = TIER_RGB[e.tier] or TIER_RGB.Alt
        ic:SetBackdropBorderColor(rgb[1], rgb[2], rgb[3], 1)
        ic.gearID, ic.wished = e.id, mine[e.id] and true or false
        ic.wish:SetShown(ic.wished)
        ic:SetAlpha(((TIER_RANK[e.tier] or 1) > worst or ic.wished) and 1 or 0.38)
        ic:Show()
      else
        ic.gearID = nil
        ic:Hide()
      end
    end
    local n = #row.targets
    r.more:ClearAllPoints(); r.more:SetPoint("LEFT", x + 2, 0)
    r.more:SetText(n > MAX_TARGETS and ("+" .. (n - MAX_TARGETS)) or "")
    r.none:SetShown(n == 0)
    r.none:SetText(worst >= 3 and "|cffff9e40At BIS|r  ·  nothing better on your list" or "Nothing on your list for this slot")
  end
  -- progress: BIS orange, then Alt teal, over every equipment slot
  f.prog:Show()
  local W = 148
  local wb, wa = W * nBis / math.max(1, nAll), W * nAlt / math.max(1, nAll)
  f.progBis:SetWidth(math.max(0.01, wb)); f.progBis:SetShown(nBis > 0)
  f.progAlt:SetWidth(math.max(0.01, wa)); f.progAlt:SetShown(nAlt > 0)
  if nBis == 0 then f.progAlt:ClearAllPoints(); f.progAlt:SetPoint("TOPLEFT", f.prog, "TOPLEFT", 1, -1); f.progAlt:SetPoint("BOTTOMLEFT", f.prog, "BOTTOMLEFT", 1, 1)
  else f.progAlt:ClearAllPoints(); f.progAlt:SetPoint("TOPLEFT", f.progBis, "TOPRIGHT"); f.progAlt:SetPoint("BOTTOMLEFT", f.progBis, "BOTTOMRIGHT") end
  f.progText:SetText(("|cffff9e40%d BIS|r  ·  |cff8fe0c4%d Alt|r  ·  %d slots"):format(nBis, nAlt, nAll))
end

function D.ToggleGearPlan(show)
  if not D.BiS then return end
  if not gear then
    gear = GearBuild()
    gear:HookScript("OnShow", function() if D.RefreshGearStrip then D.RefreshGearStrip() end end) -- v1.4.0
    gear:HookScript("OnHide", function() if D.RefreshGearStrip then D.RefreshGearStrip() end end)
  end
  if show == nil then show = not gear:IsShown() end
  if show then gear:Show(); gear:Raise(); D.RefreshGearPlan() else gear:Hide() end
end

---------------------------------------------------------------------------
-- v0.7.0: Raid loot window. Which items from a raid are upgrades for ME, per
-- boss (BiS.lua's B.RaidLoot). Pops up by itself when I zone into a raid in a
-- group (once per raid per 4 hours); /dkp raidloot or the Gear plan button
-- opens it for any raid.
---------------------------------------------------------------------------
local rl
local rlZone
local RL_MAXROWS, RL_ICONS = 12, 11

local function RaidLootBuild()
  local B = D.BiS
  local f = Window("GuildLadderDKPRaidLoot", "Raid loot", 600, 300, "CENTER", -80, 40)
  f.raidDD = Dropdown(f, 210, function()
    local t = {}
    for _, r in ipairs(B.RAIDS) do t[#t + 1] = { r[1], ("%s  ·  P%d"):format(r[1], r[2]) } end
    return t
  end, function(v) rlZone = v; D.RefreshRaidLoot() end)
  f.raidDD:SetPoint("TOPLEFT", 14, -56)
  f.summary = Text(f, 12, COL.text); f.summary:SetPoint("LEFT", f.raidDD, "RIGHT", 14, 0)
  f.gearBtn = Btn(f, "Gear plan", 90, 22, "ghost", function() D.ToggleGearPlan(true) end)
  f.gearBtn:SetPoint("TOPRIGHT", -14, -57)

  local body = CreateFrame("Frame", nil, f, BD)
  body:SetPoint("TOPLEFT", 10, -90); body:SetPoint("TOPRIGHT", -10, -90)
  Skin(body, PANEL, COL.line)
  f.body = body
  f.rows = {}
  for i = 1, RL_MAXROWS do
    local r = CreateFrame("Frame", nil, body)
    r:SetPoint("TOPLEFT", 1, -6 - (i - 1) * 34); r:SetPoint("TOPRIGHT", -1, -6 - (i - 1) * 34); r:SetHeight(34)
    if i % 2 == 0 then local bg = r:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(1, 1, 1, 0.03) end
    r.accent = r:CreateTexture(nil, "ARTWORK"); r.accent:SetWidth(3)
    r.accent:SetPoint("TOPLEFT", 1, -4); r.accent:SetPoint("BOTTOMLEFT", 1, 4)
    r.boss = Text(r, 12, COL.text); r.boss:SetPoint("LEFT", 14, 0); r.boss:SetWidth(168)
    r.tg = {}
    for k = 1, RL_ICONS do
      local ic = Icon(r, 26); ic:SetPoint("LEFT", 190 + (k - 1) * 32, 0)
      ic.wish = ic:CreateTexture(nil, "OVERLAY"); ic.wish:SetSize(13, 13); ic.wish:SetPoint("TOPRIGHT", 5, 5); ic.wish:SetTexture(READY)
      ic.tag = Text(ic, 9, COL.gold); ic.tag:SetPoint("BOTTOMRIGHT", -1, 1); ic.tag:SetText("T")
      local orig = ic:GetScript("OnMouseUp")
      ic:SetScript("OnMouseUp", function(self, btn)
        if IsModifiedClick and IsModifiedClick() then
          if orig then orig(self, btn) end
        elseif self.lootID then
          D.Wish(self.lootID, not self.wished)
        end
      end)
      r.tg[k] = ic
    end
    r.more = Text(r, 10, COL.muted)
    f.rows[i] = r
  end
  f.msg = Text(body, 13, COL.muted); f.msg:SetPoint("TOP", 0, -30); f.msg:SetWidth(520); f.msg:SetWordWrap(true)

  f.foot = Line(f); f.foot:SetPoint("BOTTOMLEFT", 1, 34); f.foot:SetPoint("BOTTOMRIGHT", -1, 34)
  local c1 = Check(f, "Show when I enter a raid", function() return D.settings.raidPopup ~= false end,
    function(v) D.settings.raidPopup = v end)
  c1:SetPoint("BOTTOMLEFT", 10, 6)
  local c2 = Check(f, "BIS only", function() return D.settings.raidBisOnly == true end,
    function(v) D.settings.raidBisOnly = v; D.RefreshRaidLoot() end)
  c2:SetPoint("BOTTOMLEFT", 210, 6)
  f.legend = Text(f, 10, COL.muted); f.legend:SetPoint("BOTTOMRIGHT", -14, 14); f.legend:SetJustifyH("RIGHT")
  f.legend:SetText("|cffff8000BIS|r  |cff4fd1c5Alt|r   click = wish   |cffe0b04fT|r = drops as a tier token")
  return f
end

function D.RefreshRaidLoot()
  local f = rl
  if not f or not f:IsShown() or not D.BiS then return end
  local B = D.BiS
  local zone = rlZone or B.DefaultRaid()
  f.raidDD:SetValue(zone, zone)
  local bosses, sum = B.RaidLoot(zone, { bisOnly = D.settings.raidBisOnly == true })
  local nrows = 0
  for _, r in ipairs(f.rows) do r:Hide() end
  f.msg:Hide()
  if not bosses then
    local why = sum
    f.msg:Show()
    f.msg:SetText(why == "nodata" and "No BiS lists loaded."
      or why == "nosources" and "No raid drop data loaded."
      or why == "era" and "The BiS lists are for TBC, and this game isn't TBC."
      or why == "nospec" and "No spec found from your talents. Pick your spec in the gear plan."
      or "No data for this raid.")
    f.summary:SetText("")
    f.sub:SetText("")
    nrows = 1
  else
    local gp = B.Phase()
    f.sub:SetText(("%s|c%s%s|r  ·  %s list"):format(B.ClassIcon(sum.class), B.ClassHex(sum.class), B.SpecLabel(sum.spec), B.PHASE_NAME[gp] or "?"))
    if sum.upgrades == 0 then
      f.summary:SetText("|cffa7afbaNothing here upgrades your gear|r")
      f.msg:Show()
      f.msg:SetText(("Nothing in %s is an upgrade for your %s in this phase's list.\nPick another raid above, or check the gear plan."):format(zone, B.SpecLabel(sum.spec)))
      nrows = 1
    else
      f.summary:SetText(("|cff8fe08f%d upgrade%s|r from %d boss%s  ·  |cffff8000%d BIS|r"):format(sum.upgrades,
        sum.upgrades == 1 and "" or "s", sum.bosses, sum.bosses == 1 and "" or "es", sum.bis))
      local mine = {}
      for _, id in ipairs(D.MyWishes()) do mine[id] = true end
      for i, b in ipairs(bosses) do
        local r = f.rows[i]
        if not r then break end
        nrows = i
        r:Show()
        r.boss:SetText(b.label)
        local top = b.items[1].tier
        local ac = top == "BIS" and TIER_RGB.BIS or TIER_RGB.Alt
        r.accent:SetColorTexture(ac[1], ac[2], ac[3], 1)
        for k, ic in ipairs(r.tg) do
          local it = b.items[k]
          if it then
            ic:SetItem(it.id)
            local rgb = TIER_RGB[it.tier] or TIER_RGB.Alt
            ic:SetBackdropBorderColor(rgb[1], rgb[2], rgb[3], 1)
            ic.lootID, ic.wished = it.id, mine[it.id] and true or false
            ic.wish:SetShown(ic.wished)
            ic.tag:SetShown(it.srcKind == "t")
            ic:Show()
          else
            ic.lootID = nil
            ic:Hide()
          end
        end
        local n = #b.items
        local lastIcon = math.min(n, RL_ICONS)
        r.more:ClearAllPoints(); r.more:SetPoint("LEFT", 190 + lastIcon * 32, 0)
        r.more:SetText(n > RL_ICONS and ("+" .. (n - RL_ICONS)) or "")
      end
    end
  end
  nrows = math.max(1, nrows)
  local bodyH = nrows * 34 + 12
  if f.msg:IsShown() then bodyH = math.max(bodyH, 96) end
  f.body:SetHeight(bodyH)
  f:SetHeight(90 + bodyH + 8 + 38)
end

-- zone: a raid name (nil = the raid I'm in, else the one for the guild's phase)
function D.ShowRaidLoot(zone, auto)
  if not D.BiS then return end
  if not rl then rl = RaidLootBuild() end
  local z = zone and D.BiS.ZoneFor(zone)
  if zone and not z then D.Print("I don't know a raid called \"" .. tostring(zone) .. "\".") return end
  rlZone = z or D.BiS.CurrentRaidZone() or rlZone or D.BiS.DefaultRaid()
  rl:Show(); rl:Raise()
  D.RefreshRaidLoot()
end

-- pop up on entering a raid, once per raid per 4 hours, only if something in it is an upgrade
function D.CheckRaidEntry()
  if not D.settings or D.settings.raidPopup == false or not D.BiS or not D.data then return end
  if not (IsInGroup and IsInGroup()) then return end
  local zone = D.BiS.CurrentRaidZone()
  if not zone then return end
  D.settings.raidSeen = D.settings.raidSeen or {}
  local key = (D.Me() or "?") .. "|" .. zone
  local now = GetServerTime()
  if D.settings.raidSeen[key] and now - D.settings.raidSeen[key] < 4 * 3600 then return end
  local bosses, sum = D.BiS.RaidLoot(zone, { bisOnly = D.settings.raidBisOnly == true })
  if not bosses then return end
  D.settings.raidSeen[key] = now
  if sum.upgrades == 0 then return end
  D.ShowRaidLoot(zone, true)
end

local raidWatch = CreateFrame("Frame")
raidWatch:RegisterEvent("PLAYER_ENTERING_WORLD")
raidWatch:RegisterEvent("ZONE_CHANGED_NEW_AREA")
raidWatch:SetScript("OnEvent", function() C_Timer.After(3, D.CheckRaidEntry) end)

do -- v1.4.0: own scope (UI.lua is at Lua's 200-locals limit for one file)
-- v1.3.0: Enchants & Gems window. v1.4.0: split into an Enchants window and a Gems window.
-- (Blizzard's enchant number on an item can't be matched to Loon's spell ids, so "Enchanted" means any enchant is on
-- the slot and the list beside it says what is best; gems are compared exactly.)
local ench, gemsWin, checkPhase -- checkPhase: nil = the guild's BiS phase; shared by both windows
local ENCH_ICONS = 3
-- v1.4.0: head glyphs are items, and the spell behind some of them carries a placeholder picture, so they get the
-- head slot's own icon instead
local function SpellOrItemIcon(id)
  local info = D.BiS and D.BiS.EnchantInfo(id)
  if info and tostring(info.name or ""):find("^Glyph of") then
    local t = SlotTexture("head")
    if t then return t end
  end
  local t = GetSpellTexture and GetSpellTexture(id)
  if not t and GetItemIcon then t = GetItemIcon(id) end
  return t or "Interface\\Icons\\INV_Misc_QuestionMark"
end
local function EnchantShort(name)
  name = tostring(name or "")
  return (name:gsub("^Enchant [%a%s]+ %- ", ""):gsub("^Enchant ", ""))
end
local ENCH_PILL = {
  ok = { "Enchanted", { 0.07, 0.21, 0.2 }, { 0.56, 0.88, 0.77 } },
  missing = { "No enchant", { 0.27, 0.09, 0.08 }, { 1, 0.48, 0.42 } },
  muted = { "Enchanted", { 0.17, 0.19, 0.23 }, { 0.655, 0.686, 0.729 } },
  na = { "-", { 0.1, 0.105, 0.13 }, { 0.45, 0.48, 0.52 } },
  empty = { "Empty", { 0.27, 0.09, 0.08 }, { 1, 0.48, 0.42 } },
}

-- v1.4.0: where an enchant comes from, only when that helps: nothing for a trainer recipe, "Formula: ..." for an
-- Enchanting formula that drops, "From: ..." for glyphs, inscriptions and other bought / earned enchants
local function EnchantSource(info)
  if not info or (info.source or "") == "" then return nil end
  if info.source:find("Trainer") then return nil end
  local where = info.source .. ((info.location or "") ~= "" and (" · " .. info.location) or "")
  if tostring(info.name or ""):find("^Enchant ") then return "Formula: " .. where end
  return "From: " .. where
end

-- v1.4.0: the game's own tooltip for the enchant (it lists the reagents, red when they aren't in my bags), then the
-- source line where it helps and which phase the list has it from
local function EnchantTooltip(owner, eid, phase, top)
  if not eid then return end
  local B = D.BiS
  local info = B.EnchantInfo(eid)
  GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
  local ok = pcall(GameTooltip.SetHyperlink, GameTooltip, "enchant:" .. eid)
  if not ok or GameTooltip:NumLines() == 0 then
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:AddLine(info and info.name or ("Enchant " .. eid), 1, 1, 1)
  end
  local src = EnchantSource(info)
  if src then GameTooltip:AddLine(src, 0.5, 0.7, 1, true) end
  GameTooltip:AddLine((top and "Best from " or "Earlier option from ") .. (B.PHASE_NAME[phase or 0] or "?"), 0.65, 0.69, 0.73)
  GameTooltip:Show()
end

local function EnchantButton(parent, size)
  local b = CreateFrame("Button", nil, parent, BD)
  b:SetSize(size, size)
  Skin(b, { 0, 0, 0, 1 }, { 0.5, 0.5, 0.5, 1 })
  b.tex = b:CreateTexture(nil, "ARTWORK")
  b.tex:SetPoint("TOPLEFT", 1, -1); b.tex:SetPoint("BOTTOMRIGHT", -1, 1); b.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  b:SetScript("OnEnter", function(self) EnchantTooltip(self, self.eid, self.phase, self.top) end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return b
end

-- phase switch + spec picker, the same at the top of both windows
local function CheckControls(f, refresh)
  local B = D.BiS
  local opts = {}
  for ph = 0, 5 do opts[#opts + 1] = { ph, ph == 0 and "Pre-raid" or ("P" .. ph), ph == 0 and 64 or 36 } end
  f.phaseSeg = Seg(f, opts, function() return checkPhase or B.Phase() end, function(v)
    checkPhase = (v ~= B.Phase()) and v or nil
    if D.RefreshEnchants then D.RefreshEnchants() end
    if D.RefreshGems then D.RefreshGems() end
  end)
  f.phaseSeg:SetPoint("TOPLEFT", 14, -56)
  f.specDD = Dropdown(f, 150, function() return B.SpecOptions() end, function(v)
    B.SetSpec(v ~= "auto" and v or nil)
    if D.RefreshEnchants then D.RefreshEnchants() end
    if D.RefreshGems then D.RefreshGems() end
  end)
  f.specDD:SetPoint("TOPRIGHT", -14, -56)
  f:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
  f:SetScript("OnEvent", function() if f:IsShown() then refresh() end end)
end

-- the shared top of both windows; returns the gear check, or nil after showing why there is none
local function CheckHeader(f, title)
  local B = D.BiS
  local d = B.Data()
  local ph = checkPhase or B.Phase()
  f.phaseSeg:Refresh()
  f.phaseSeg:SetShown(d ~= nil)
  if d then f.specDD:Show(); f.specDD:SetValue(B.SpecValue()) else f.specDD:Hide() end
  local rows, sum = B.GearCheck(ph)
  if not rows then
    f.sub:SetText("")
    f.msg:Show()
    f.msg:SetText(sum == "nodata" and "No BiS lists loaded.\nThey come with Guild Ladder DKP: reinstall the add-on if BiSData_TBC.lua is missing."
      or sum == "era" and "The BiS lists are for TBC, and this game isn't TBC."
      or "No spec found from your talents. Pick your spec at the top right.")
    return nil
  end
  f.msg:Hide()
  f.sub:SetText(("%s|c%s%s|r  ·  %s list"):format(B.ClassIcon(sum.class), B.ClassHex(sum.class), B.SpecLabel(sum.spec), B.PHASE_NAME[ph] or "?"))
  return rows, sum, ph
end

---------------------------------------------------------------------------
-- Enchants window
---------------------------------------------------------------------------
local function EnchantsBuild()
  local B = D.BiS
  local f = Window("GuildLadderDKPEnchants", "Enchants", 640, 600, "CENTER", 60, 0)
  CheckControls(f, function() D.RefreshEnchants() end)

  local body = CreateFrame("Frame", nil, f, BD)
  body:SetPoint("TOPLEFT", 10, -92); body:SetPoint("TOPRIGHT", -10, -92); body:SetHeight(26 + #B.GEARROWS * 28 + 6)
  Skin(body, PANEL, COL.line)
  local function Head(x, text)
    local t = Text(body, 10, COL.muted, "GameFontNormalSmall"); t:SetPoint("TOPLEFT", x, -9); t:SetText(text)
    return t
  end
  Head(10, "SLOT"); Head(112, "WORN"); Head(146, "ENCHANT"); f.encHead = Head(236, "BIS ENCHANT")
  local hl = Line(body); hl:SetPoint("TOPLEFT", 8, -24); hl:SetPoint("TOPRIGHT", -8, -24)

  f.rows = {}
  for i, def in ipairs(B.GEARROWS) do
    local r = CreateFrame("Frame", nil, body)
    r:SetPoint("TOPLEFT", 1, -26 - (i - 1) * 28); r:SetPoint("TOPRIGHT", -1, -26 - (i - 1) * 28); r:SetHeight(28)
    if i % 2 == 0 then local bg = r:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(1, 1, 1, 0.03) end
    r.slotIcon = r:CreateTexture(nil, "ARTWORK"); r.slotIcon:SetSize(18, 18); r.slotIcon:SetPoint("LEFT", 10, 0)
    r.slotIcon:SetTexture(SlotTexture(def[1]:gsub("%d$", ""))); r.slotIcon:SetAlpha(0.8)
    r.label = Text(r, 12, COL.text); r.label:SetPoint("LEFT", 34, 0); r.label:SetWidth(74)
    r.worn = Icon(r, 22); r.worn:SetPoint("LEFT", 112, 0)
    r.status = Chip(r); r.status:SetPoint("LEFT", 146, 0)
    r.enc = {}
    for k = 1, ENCH_ICONS do
      local b = EnchantButton(r, 22); b:SetPoint("LEFT", 236 + (k - 1) * 26, 0); r.enc[k] = b
    end
    r.encName = Text(r, 11, COL.text); r.encName:SetWidth(270)
    -- v1.4.0: the name shows the same tooltip as the first icon
    r.nameHit = CreateFrame("Frame", nil, r)
    r.nameHit:SetPoint("TOPLEFT", r.encName, "TOPLEFT", 0, 4); r.nameHit:SetPoint("BOTTOMRIGHT", r.encName, "BOTTOMRIGHT", 0, -4)
    r.nameHit:EnableMouse(true)
    r.nameHit:SetScript("OnEnter", function(self) local b = r.enc[1]; if b.eid then EnchantTooltip(self, b.eid, b.phase, b.top) end end)
    r.nameHit:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f.rows[i] = r
  end
  f.msg = Text(body, 13, COL.muted); f.msg:SetPoint("TOP", 0, -140); f.msg:SetWidth(560); f.msg:SetWordWrap(true)

  f.sum = Text(f, 12, COL.text); f.sum:SetPoint("BOTTOMLEFT", 14, 16); f.sum:SetWidth(240); f.sum:SetJustifyH("LEFT")
  f.note = Text(f, 10, COL.muted); f.note:SetPoint("BOTTOMRIGHT", -30, 16); f.note:SetWidth(340); f.note:SetJustifyH("RIGHT")
  f.note:SetText("Enchanted = an enchant is on the slot. Hover an enchant for what it needs.")
  return f
end

function D.RefreshEnchants()
  local f = ench
  if not f or not f:IsShown() or not D.BiS then return end
  local B = D.BiS
  local rows, sum, ph = CheckHeader(f)
  if not rows then
    for _, r in ipairs(f.rows) do r:Hide() end
    f.sum:SetText("")
    return
  end
  f.encHead:SetText("BIS ENCHANT · " .. (B.PHASE_NAME[ph] or "?"))
  for i, r in ipairs(f.rows) do
    local row = rows[i]
    r:Show()
    r.label:SetText(row.label)
    if row.itemId then r.worn:SetItem(row.itemId); r.worn:Show() else r.worn:Hide() end
    local key = not row.itemId and "empty" or (row.needs and (row.enchanted and "ok" or "missing") or (row.enchanted and "muted" or "na"))
    local pc = ENCH_PILL[key]
    r.status:Set(pc[1], pc[2], pc[3])
    -- the list's enchants for this slot (newest first), name of the first beside the icons
    for k, b in ipairs(r.enc) do
      local e = row.bis[k]
      if e then
        b.eid, b.phase, b.top = e.id, e.phase, e.top
        b.tex:SetTexture(SpellOrItemIcon(e.id))
        if e.top then b:SetBackdropBorderColor(1, 0.5, 0, 1) else b:SetBackdropBorderColor(0.45, 0.45, 0.45, 1) end
        b:Show()
      else
        b.eid = nil
        b:Hide()
      end
    end
    local first = row.bis[1]
    r.encName:ClearAllPoints()
    r.encName:SetPoint("LEFT", 236 + math.max(1, math.min(#row.bis, ENCH_ICONS)) * 26 + 4 - (#row.bis == 0 and 26 or 0), 0)
    if first then
      local info = B.EnchantInfo(first.id)
      r.encName:SetText(EnchantShort(info and info.name or ("Enchant " .. first.id)) .. (#row.bis > 1 and ("  |cffa7afba+" .. (#row.bis - 1) .. "|r") or ""))
      r.encName:SetTextColor(unpack(COL.text))
    else
      r.encName:SetText("none on the list")
      r.encName:SetTextColor(unpack(COL.muted))
    end
  end
  f.sum:SetText(("Enchants |cff%s%d/%d|r"):format(sum.done >= sum.needed and "8fe08f" or "ff7a6b", sum.done, sum.needed))
end

function D.ToggleEnchants(show)
  if not D.BiS then return end
  if not ench then
    ench = EnchantsBuild()
    ench:HookScript("OnShow", function() if D.RefreshGearStrip then D.RefreshGearStrip() end end)
    ench:HookScript("OnHide", function() if D.RefreshGearStrip then D.RefreshGearStrip() end end)
  end
  if show == nil then show = not ench:IsShown() end
  if show then ench:Show(); ench:Raise(); D.RefreshEnchants() else ench:Hide() end
end

---------------------------------------------------------------------------
-- v1.4.0: Gems window. Left: my sockets slot by slot, gems by name (green = on the BiS list, orange = not), empty
-- sockets by colour with the list's gem for that colour, and the socket bonus. Right: the phase's BiS gems by name,
-- grouped by the socket colour they fit.
---------------------------------------------------------------------------
local GEMS_W, GEMS_LEFT = 800, 470
local GEM_LINE, GEM_ROWPAD, GEM_MINROW = 18, 8, 28
local GEM_LINES = 6 -- most a row can need: 3 sockets + 1 extra gem + socket bonus, with room to spare
local SOCKET_RGB = { meta = { 0.75, 0.75, 0.8 }, red = { 1, 0.35, 0.3 }, yellow = { 1, 0.85, 0.3 }, blue = { 0.4, 0.6, 1 },
  prismatic = { 0.85, 0.85, 0.85 }, other = { 0.6, 0.6, 0.6 } }
local SOCKET_LABEL = { meta = "META SOCKET", red = "RED SOCKETS", yellow = "YELLOW SOCKETS", blue = "BLUE SOCKETS",
  other = "OTHER GEMS ON THE LIST" }
local GEM_GREEN, GEM_ORANGE = { 0.45, 0.9, 0.55 }, { 1, 0.62, 0.25 }

-- a gem's name: the list's name first (always there), else the game's
local function GemName(id)
  local info = D.BiS.GemInfo(id)
  return info and info.name or D.ItemName(id)
end

-- item tooltip on hover (ItemTooltip), plus where the gem comes from when the list knows and it isn't just "World Drop"
local function GemHover(frame)
  ItemTooltip(frame)
  frame:HookScript("OnEnter", function(self)
    if not self.itemID or not GameTooltip:IsOwned(self) then return end
    local info = D.BiS.GemInfo(self.itemID)
    if info and (info.source or "") ~= "" and info.source ~= "World Drop" then
      GameTooltip:AddLine("From: " .. info.source .. ((info.location or "") ~= "" and (" · " .. info.location) or ""), 0.5, 0.7, 1, true)
      GameTooltip:Show()
    end
  end)
end

-- one line in a slot row: a 16 px picture (gem icon or an empty socket box) and a name
local function GemLine(parent)
  local l = CreateFrame("Frame", nil, parent)
  l:SetHeight(GEM_LINE); l:EnableMouse(true)
  l.icon = Icon(l, 16); l.icon:SetPoint("LEFT", 0, 0); l.icon:EnableMouse(false)
  l.box = CreateFrame("Frame", nil, l, BD); l.box:SetSize(16, 16); l.box:SetPoint("LEFT", 0, 0)
  Skin(l.box, { 0.1, 0.105, 0.13, 1 }, { 0.8, 0.27, 0.22, 1 })
  l.text = Text(l, 11, COL.text); l.text:SetPoint("LEFT", 22, 0); l.text:SetPoint("RIGHT", 0, 0)
  l.hint = Text(l, 11, COL.muted) -- the list's gem beside an empty socket (its own string, so clipping it is safe)
  GemHover(l)
  return l
end

local function GemsBuild()
  local f = Window("GuildLadderDKPGems", "Gems", GEMS_W, 640, "CENTER", 80, 0)
  CheckControls(f, function() D.RefreshGems() end)

  -- left: my sockets
  local body = CreateFrame("Frame", nil, f, BD)
  body:SetPoint("TOPLEFT", 10, -92); body:SetWidth(GEMS_LEFT); body:SetHeight(100)
  Skin(body, PANEL, COL.line)
  local function Head(parent, x, text)
    local t = Text(parent, 10, COL.muted, "GameFontNormalSmall"); t:SetPoint("TOPLEFT", x, -9); t:SetText(text)
    return t
  end
  Head(body, 10, "SLOT"); Head(body, 112, "WORN"); Head(body, 144, "GEMS AND SOCKETS")
  local hl = Line(body); hl:SetPoint("TOPLEFT", 8, -24); hl:SetPoint("TOPRIGHT", -8, -24)
  f.body = body
  f.rows = {}
  for i, def in ipairs(D.BiS.GEARROWS) do
    local r = CreateFrame("Frame", nil, body)
    r.bg = r:CreateTexture(nil, "BACKGROUND"); r.bg:SetAllPoints(); r.bg:SetColorTexture(1, 1, 1, i % 2 == 0 and 0.03 or 0)
    r.slotIcon = r:CreateTexture(nil, "ARTWORK"); r.slotIcon:SetSize(18, 18); r.slotIcon:SetPoint("TOPLEFT", 10, -5)
    r.slotIcon:SetTexture(SlotTexture(def[1]:gsub("%d$", ""))); r.slotIcon:SetAlpha(0.8)
    r.label = Text(r, 12, COL.text); r.label:SetPoint("TOPLEFT", 34, -8); r.label:SetWidth(74)
    r.worn = Icon(r, 22); r.worn:SetPoint("TOPLEFT", 112, -3)
    r.lines = {}
    for k = 1, GEM_LINES do
      local l = GemLine(r)
      l:SetPoint("TOPLEFT", 144, -5 - (k - 1) * GEM_LINE); l:SetPoint("RIGHT", r, "RIGHT", -10, 0)
      r.lines[k] = l
    end
    f.rows[i] = r
  end
  f.msg = Text(f, 13, COL.muted); f.msg:SetPoint("TOP", 0, -200); f.msg:SetWidth(560); f.msg:SetWordWrap(true)
  f.msg:SetJustifyH("CENTER")

  -- right: the phase's BiS gems, by socket colour
  local side = CreateFrame("Frame", nil, f, BD)
  side:SetPoint("TOPLEFT", body, "TOPRIGHT", 8, 0); side:SetPoint("TOPRIGHT", -10, -92); side:SetHeight(100)
  Skin(side, PANEL, COL.line)
  f.sideHead = Head(side, 10, "BIS GEMS")
  local sl = Line(side); sl:SetPoint("TOPLEFT", 8, -24); sl:SetPoint("TOPRIGHT", -8, -24)
  f.side, f.groupHeads, f.entries = side, {}, {}

  f.sum = Text(f, 12, COL.text); f.sum:SetPoint("BOTTOMLEFT", 14, 16); f.sum:SetWidth(460); f.sum:SetJustifyH("LEFT")
  f.note = Text(f, 10, COL.muted); f.note:SetPoint("BOTTOMRIGHT", -30, 16); f.note:SetWidth(280); f.note:SetJustifyH("RIGHT")
  f.note:SetText("|cff73e68cGreen|r = on the BiS list  ·  |cffff9e40orange|r = not on it")
  return f
end

-- a group header / an entry on the right, made on demand
local function GroupHead(f, i)
  local h = f.groupHeads[i]
  if h then return h end
  h = CreateFrame("Frame", nil, f.side); h:SetHeight(18)
  h.swatch = h:CreateTexture(nil, "ARTWORK"); h.swatch:SetSize(10, 10); h.swatch:SetPoint("LEFT", 0, 0)
  h.text = Text(h, 10, COL.gold, "GameFontNormalSmall"); h.text:SetPoint("LEFT", 16, 0)
  f.groupHeads[i] = h
  return h
end
local function Entry(f, i)
  local e = f.entries[i]
  if e then return e end
  e = CreateFrame("Frame", nil, f.side); e:SetHeight(20); e:EnableMouse(true)
  e.icon = Icon(e, 18); e.icon:SetPoint("LEFT", 0, 0); e.icon:EnableMouse(false)
  e.metaTag = Text(e.icon, 9, COL.gold); e.metaTag:SetPoint("BOTTOMRIGHT", -1, 1); e.metaTag:SetText("M")
  e.phase = Text(e, 10, COL.muted); e.phase:SetPoint("RIGHT", 0, 0); e.phase:SetJustifyH("RIGHT")
  e.text = Text(e, 11, COL.text); e.text:SetPoint("LEFT", 24, 0); e.text:SetPoint("RIGHT", e.phase, "LEFT", -6, 0)
  GemHover(e)
  f.entries[i] = e
  return e
end

local function SetLine(l, kind, id, text, color, hint)
  l:Show()
  l.itemID = id
  if kind == "gem" then
    l.icon:SetItem(id); l.icon:Show(); l.box:Hide()
    l.icon:SetBackdropBorderColor(color[1], color[2], color[3], 1)
  elseif kind == "empty" then
    l.icon:Hide(); l.box:Show()
    l.box:SetBackdropBorderColor(color[1], color[2], color[3], 1)
  else
    l.icon:Hide(); l.box:Hide()
  end
  l.text:ClearAllPoints()
  l.text:SetPoint("LEFT", (kind == "gem" or kind == "empty") and 22 or 0, 0)
  l.text:SetTextColor(unpack(kind == "empty" and COL.red or color))
  if hint then
    l.text:SetWidth(0); l.text:SetText(text)
    l.hint:ClearAllPoints(); l.hint:SetPoint("LEFT", l.text, "RIGHT", 6, 0); l.hint:SetPoint("RIGHT", 0, 0)
    l.hint:Show(); Fit(l.hint, "· " .. hint)
  else
    l.text:SetPoint("RIGHT", 0, 0)
    l.hint:Hide()
    Fit(l.text, text)
  end
end

function D.RefreshGems()
  local f = gemsWin
  if not f or not f:IsShown() or not D.BiS then return end
  local B = D.BiS
  local rows, sum, ph = CheckHeader(f)
  if not rows then
    f.body:Hide(); f.side:Hide(); f.sum:SetText("")
    f:SetHeight(400)
    return
  end
  f.body:Show(); f.side:Show()
  local groups = B.GemsBySocket(sum.class, sum.spec, ph)

  -- left: one row per slot, as tall as its lines
  local y = -26
  for i, r in ipairs(f.rows) do
    local row = rows[i]
    r.label:SetText(row.label)
    if row.itemId then r.worn:SetItem(row.itemId); r.worn:Show() else r.worn:Hide() end
    local n = 0
    local function Add(kind, id, text, color, hint)
      n = n + 1
      if r.lines[n] then SetLine(r.lines[n], kind, id, text, color, hint) end
    end
    if not row.itemId then
      Add("note", nil, "Empty slot", COL.muted)
    else
      for _, g in ipairs(row.gems) do
        Add("gem", g.id, GemName(g.id), g.bis and GEM_GREEN or GEM_ORANGE)
      end
      local colors = row.emptyColors or {}
      for k = 1, row.empty do
        local c = colors[k]
        local pick = c and B.GemForSocket(groups, c)
        local label = c and ("Empty " .. c .. " socket") or "Empty socket"
        Add("empty", pick and pick.id or nil, label, SOCKET_RGB[c or "other"] or SOCKET_RGB.other, pick and GemName(pick.id) or nil)
      end
      if n == 0 then Add("note", nil, "No sockets", COL.muted)
      elseif row.bonus then
        Add("note", nil, "Socket bonus: " .. row.bonus .. (row.bonusOn and "" or "  (not active)"), row.bonusOn and GEM_GREEN or COL.muted)
      end
    end
    for k = n + 1, GEM_LINES do r.lines[k]:Hide() end
    local h = math.max(GEM_MINROW, GEM_ROWPAD + math.min(n, GEM_LINES) * GEM_LINE + 2)
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", 1, y); r:SetPoint("TOPRIGHT", -1, y); r:SetHeight(h)
    r:Show()
    y = y - h
  end
  local leftH = -y + 6
  f.body:SetHeight(leftH)

  -- right: BiS gems by socket colour
  f.sideHead:SetText("BIS GEMS · " .. (B.PHASE_NAME[ph] or "?") .. " and earlier")
  local sy, gi, ei = -32, 0, 0
  for _, grp in ipairs(groups) do
    if #grp.gems > 0 then
      gi = gi + 1
      local h = GroupHead(f, gi)
      h:ClearAllPoints(); h:SetPoint("TOPLEFT", 10, sy); h:SetPoint("TOPRIGHT", -10, sy)
      local c = SOCKET_RGB[grp.socket] or SOCKET_RGB.other
      h.swatch:SetColorTexture(c[1], c[2], c[3], 1)
      h.text:SetText(SOCKET_LABEL[grp.socket] or grp.socket:upper())
      h:Show()
      sy = sy - 20
      for _, g in ipairs(grp.gems) do
        ei = ei + 1
        local e = Entry(f, ei)
        e:ClearAllPoints(); e:SetPoint("TOPLEFT", 10, sy); e:SetPoint("TOPRIGHT", -10, sy)
        e.itemID = g.id
        e.icon:SetItem(g.id)
        e.metaTag:SetShown(g.meta)
        if g.phase == ph then e.icon:SetBackdropBorderColor(1, 0.5, 0, 1) end
        Fit(e.text, GemName(g.id))
        e.text:SetTextColor(unpack(COL.text))
        e.phase:SetText(B.PHASE_NAME[g.phase] or "")
        e:Show()
        sy = sy - 22
      end
      sy = sy - 8
    end
  end
  for k = gi + 1, #f.groupHeads do f.groupHeads[k]:Hide() end
  for k = ei + 1, #f.entries do f.entries[k]:Hide() end
  if ei == 0 then
    gi = gi + 1
    local h = GroupHead(f, gi)
    h:ClearAllPoints(); h:SetPoint("TOPLEFT", 10, sy); h:SetPoint("TOPRIGHT", -10, sy)
    h.swatch:SetColorTexture(0, 0, 0, 0); h.text:SetText("No gems on this list"); h:Show()
    sy = sy - 26
  end
  local rightH = -sy + 2
  f.side:SetHeight(math.max(leftH, rightH))
  f:SetHeight(92 + math.max(leftH, rightH) + 46)

  local pct = sum.sockets > 0 and (sum.bisGems .. "/" .. sum.sockets) or "none"
  f.sum:SetText(("Sockets filled |cff%s%d/%d|r  ·  Empty |cff%s%d|r  ·  On the BiS list |cff8fe0c4%s|r"):format(
    sum.empty == 0 and "8fe08f" or "ff7a6b", sum.filled, sum.sockets, sum.empty == 0 and "8fe08f" or "ff7a6b", sum.empty, pct))
end

function D.ToggleGems(show)
  if not D.BiS then return end
  if not gemsWin then
    gemsWin = GemsBuild()
    gemsWin:HookScript("OnShow", function() if D.RefreshGearStrip then D.RefreshGearStrip() end end)
    gemsWin:HookScript("OnHide", function() if D.RefreshGearStrip then D.RefreshGearStrip() end end)
  end
  if show == nil then show = not gemsWin:IsShown() end
  if show then gemsWin:Show(); gemsWin:Raise(); D.RefreshGems() else gemsWin:Hide() end
end
end -- Enchants / Gems

-- v1.0.0: items load a moment after the first look. When the client says one arrived and a list was showing
-- "Item 12345", refresh the windows once (batched) so the real names and colours appear without scrolling.
local itemWatch = CreateFrame("Frame")
itemWatch:RegisterEvent("GET_ITEM_INFO_RECEIVED")
local itemBatch
itemWatch:SetScript("OnEvent", function()
  if not D.itemPending or itemBatch then return end
  itemBatch = true
  C_Timer.After(0.3, function()
    itemBatch = nil
    if D.itemPending then
      D.itemPending = false
      if D.Refresh then D.Refresh() end
    end
  end)
end)

local TABS = {
  { "standings", "Standings", BuildStandings, MEDIA .. "Menu\\Standings.tga" },
  { "raid", "Raid night", BuildRaid, MEDIA .. "Menu\\RaidNight.tga" },
  { "ready", "Readiness", BuildReadiness, MEDIA .. "Menu\\Readiness.tga" },
  { "raids", "Raids", BuildRaids, MEDIA .. "Menu\\Raids.tga" },
  { "logs", "Logs", BuildLogs, MEDIA .. "Menu\\Logs.tga" },
  { "fame", "Hall of Fame", function(pg) return D.BuildHall(pg) end, MEDIA .. "Menu\\HallOfFame.tga" }, -- v0.5.0
  { "wish", "My DKP", BuildWish, MEDIA .. "Menu\\MyDKP.tga" },
  { "queue", "Loot queue", nil, MEDIA .. "Menu\\LootQueue.tga" },
  { "settings", "Settings", BuildSettings, MEDIA .. "Menu\\Settings.tga" },
}

-- v0.3.0: a menu button on the left - game icon in a gold frame, label beside it
local function NavButton(parent, label, icon, onClick)
  local th = Theme()
  local b = CreateFrame("Button", nil, parent, BD)
  b:SetSize(190, 40) -- v0.5.0: 40 (was 42) so nine tabs fit
  Skin(b, { 0.086, 0.09, 0.11, 1 }, { 0.18, 0.165, 0.13, 1 })
  local custom = type(icon) == "string" and icon:find("\\Media\\", 1, true) ~= nil -- v0.8.0: art with its own frame
  local fr = CreateFrame("Frame", nil, b, BD)
  b.frame, b.custom = fr, custom
  b.icon = fr:CreateTexture(nil, "ARTWORK")
  if custom then
    fr:SetSize(36, 36); fr:SetPoint("LEFT", 5, 0)
    b.icon:SetAllPoints()
    b.icon:SetTexture(icon)
  else
    fr:SetSize(34, 34); fr:SetPoint("LEFT", 6, 0)
    Skin(fr, { 0, 0, 0, 1 }, GOLD_DIM)
    b.icon:SetPoint("TOPLEFT", 2, -2); b.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    b.icon:SetTexture(icon); b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  end
  b.label = Text(b, 15, COL.text); b.label:SetFont(TITLE_FONT, 16)
  b.label:SetPoint("LEFT", fr, "RIGHT", 10, 0)
  b.label:SetText(label)
  function b:SetActive(on)
    self.active = on
    if on then
      self:SetBackdropColor(unpack(th.deep))
      self:SetBackdropBorderColor(COL.gold[1], COL.gold[2], COL.gold[3], 1)
      if self.custom then self.icon:SetAlpha(1) else self.frame:SetBackdropBorderColor(0.95, 0.84, 0.54, 1) end
      self.label:SetTextColor(0.95, 0.84, 0.54)
    else
      self:SetBackdropColor(0.086, 0.09, 0.11, 1)
      self:SetBackdropBorderColor(0.18, 0.165, 0.13, 1)
      if self.custom then self.icon:SetAlpha(0.88) else self.frame:SetBackdropBorderColor(unpack(GOLD_DIM)) end
      self.label:SetTextColor(0.85, 0.83, 0.8)
    end
  end
  b:SetScript("OnEnter", function(self) if not self.active then self:SetBackdropBorderColor(unpack(GOLD_DIM)) end end)
  b:SetScript("OnLeave", function(self) self:SetActive(self.active) end)
  b:SetScript("OnClick", onClick)
  b:SetActive(false)
  return b
end

do -- v1.4.0: own scope (Lua's 200-locals limit)
-- v1.4.0: the gear strip under the main window. A button looks pressed while its window is open; a click opens or
-- closes that window.
local STRIP_BW, STRIP_H = 150, 38
local function StripButton(parent, label, onClick)
  local th = Theme()
  local b = CreateFrame("Button", nil, parent, BD)
  b:SetSize(STRIP_BW, STRIP_H - 9)
  Skin(b, { 0.09, 0.095, 0.115, 1 }, COL.line)
  b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetSize(20, 20); b.icon:SetPoint("LEFT", 8, 0)
  b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  b.label = Text(b, 14, COL.gold); b.label:SetFont(TITLE_FONT, 14)
  b.label:SetPoint("LEFT", b.icon, "RIGHT", 8, 0); b.label:SetText(label)
  function b:SetOn(on)
    self.on = on
    if on then
      self:SetBackdropColor(unpack(th.deep)); self:SetBackdropBorderColor(COL.gold[1], COL.gold[2], COL.gold[3], 1)
      self.label:SetTextColor(0.98, 0.88, 0.6)
    else
      self:SetBackdropColor(0.09, 0.095, 0.115, 1); self:SetBackdropBorderColor(unpack(COL.line))
      self.label:SetTextColor(unpack(COL.gold))
    end
  end
  b:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(COL.gold[1], COL.gold[2], COL.gold[3], 1) end)
  b:SetScript("OnLeave", function(self) self:SetOn(self.on) end)
  b:SetScript("OnClick", onClick)
  b:SetOn(false)
  return b
end

local function WornIcon(slot)
  return GetInventoryItemTexture and GetInventoryItemTexture("player", slot) or nil
end

function D.RefreshGearStrip()
  local f = main
  local strip = f and f.gearStrip
  if not strip then return end
  local B = D.BiS
  local on = B and (B.Data()) ~= nil
  strip:SetShown(on and true or false)
  -- keep the strip on screen too when the window is pushed against the bottom edge
  if f.SetClampRectInsets then f:SetClampRectInsets(0, 0, 0, on and -(STRIP_H - 1) or 0) end
  if not on then return end
  local function Open(name) local w = _G[name]; return w and w:IsShown() and true or false end
  strip.btns.gear:SetOn(Open("GuildLadderDKPGear"))
  strip.btns.ench:SetOn(Open("GuildLadderDKPEnchants"))
  strip.btns.gems:SetOn(Open("GuildLadderDKPGems"))
  -- pictures: what I wear on the chest, a well known enchant, a well known gem (all from the game's own data)
  strip.btns.gear.icon:SetTexture(WornIcon(5) or SlotTexture("chest") or "Interface\\Icons\\INV_Misc_QuestionMark")
  strip.btns.ench.icon:SetTexture((GetSpellTexture and GetSpellTexture(27984)) or "Interface\\Icons\\INV_Misc_QuestionMark")
  strip.btns.gems.icon:SetTexture(D.ItemIcon(24027))
end

-- v1.4.0: gear strip hanging off the bottom of the main window: Gear plan, Enchants, Gems (TBC only)
function D.BuildGearStrip(f, SIDE)
  local strip = CreateFrame("Frame", nil, f, BD)
  strip:SetSize(STRIP_BW * 3 + 6 * 2 + 16, STRIP_H)
  strip:SetPoint("TOP", f, "BOTTOM", SIDE / 2, 1) -- centred under the pages, overlapping the window's bottom edge
  Skin(strip, { 0.055, 0.059, 0.075, 1 }, GOLD_DIM)
  local cover = strip:CreateTexture(nil, "OVERLAY") -- hides the strip's top edge so it reads as part of the window
  cover:SetColorTexture(0.055, 0.059, 0.075, 1); cover:SetHeight(1)
  cover:SetPoint("TOPLEFT", 1, 0); cover:SetPoint("TOPRIGHT", -1, 0)
  strip.btns = {}
  local defs = {
    { "gear", "Gear plan", function() D.ToggleGearPlan() end },
    { "ench", "Enchants", function() D.ToggleEnchants() end },
    { "gems", "Gems", function() D.ToggleGems() end },
  }
  for i, d in ipairs(defs) do
    local b = StripButton(strip, d[2], d[3])
    b:SetPoint("TOPLEFT", 8 + (i - 1) * (STRIP_BW + 6), -4)
    strip.btns[d[1]] = b
  end
  f.gearStrip = strip
end
end -- gear strip

local function BuildMain()
  local th = Theme()
  local W, H, SIDE, HEAD, FOOT = 952, 586, 212, 72, 50 -- v0.8.0: header 72 (was 64), window 8 taller so the pages keep their 464
  local f = Window("GuildLadderDKPMain", "", W, H, "TOPLEFT", 16, -90)
  Skin(f, { 0.055, 0.059, 0.075, 1 }, GOLD_DIM)
  f.crest:Hide() -- v0.9.0: the main window has its own big crest + wordmark
  -- title bar: faction crest + "Guild Ladder DKP"
  f.head:SetHeight(HEAD - 2)
  Skin(f.head, { 0.071, 0.075, 0.094, 1 }, { 0, 0, 0, 0 })
  local hl = f.head:CreateTexture(nil, "ARTWORK"); hl:SetColorTexture(unpack(GOLD_DIM))
  hl:SetHeight(2); hl:SetPoint("BOTTOMLEFT"); hl:SetPoint("BOTTOMRIGHT")
  local crest = f.head:CreateTexture(nil, "ARTWORK")
  crest:SetSize(54, 54); crest:SetPoint("LEFT", 10, 0)
  crest:SetTexture(th.crest)
  f.title:SetText("") -- v0.8.0: the name is a picture now
  local wordmark = f.head:CreateTexture(nil, "ARTWORK")
  wordmark:SetSize(256, 64); wordmark:SetPoint("LEFT", crest, "RIGHT", 8, 0)
  wordmark:SetTexture(th.wordmark)

  -- left menu
  local side = CreateFrame("Frame", nil, f, BD)
  side:SetPoint("TOPLEFT", 1, -HEAD); side:SetPoint("BOTTOMLEFT", 1, FOOT)
  side:SetWidth(SIDE - 1)
  Skin(side, { 0.063, 0.067, 0.086, 1 }, { 0, 0, 0, 0 })
  local sl = side:CreateTexture(nil, "ARTWORK"); sl:SetColorTexture(0.23, 0.19, 0.13, 1)
  sl:SetWidth(2); sl:SetPoint("TOPRIGHT"); sl:SetPoint("BOTTOMRIGHT")

  local y = -10
  for _, t in ipairs(TABS) do
    local key = t[1]
    local b = NavButton(side, t[2], t[4], function()
      if key == "queue" then D.ToggleQueue() else D.Toggle(key, true) end
    end)
    b:SetPoint("TOPLEFT", 10, y)
    y = y - 46
    tabs[key] = b
    if t[3] then
      local page = CreateFrame("Frame", nil, f)
      page:SetPoint("TOPLEFT", SIDE + 1, -HEAD)
      page:SetPoint("BOTTOMRIGHT", -1, FOOT)
      t[3](page)
      page:Hide()
      pages[key] = page
    end
  end

  -- faction banner under the menu
  local banner = CreateFrame("Frame", nil, side)
  banner:SetSize(190, 48); banner:SetPoint("BOTTOM", 0, 10)
  local plaque = banner:CreateTexture(nil, "ARTWORK")
  plaque:SetAllPoints(); plaque:SetTexture(th.plaque)
  f.guildName = Text(banner, 13, COL.gold); f.guildName:SetFont(TITLE_FONT, 13)
  f.guildName:SetPoint("CENTER", 0, 0); f.guildName:SetWidth(100); f.guildName:SetJustifyH("CENTER"); f.guildName:SetWordWrap(false)
  Fit(f.guildName, (GetGuildInfo and GetGuildInfo("player")) or "Guild Ladder")

  -- footer
  local foot = f:CreateTexture(nil, "ARTWORK"); foot:SetColorTexture(0.23, 0.19, 0.13, 1)
  foot:SetHeight(2); foot:SetPoint("BOTTOMLEFT", 1, FOOT); foot:SetPoint("BOTTOMRIGHT", -1, FOOT)
  f.status = Text(f, 10, COL.muted); f.status:SetPoint("BOTTOMLEFT", 14, 18); f.status:SetWidth(330)
  f.status:SetText(("Undo adds a correction entry; nothing is ever deleted.%s"):format(
    D.Version and ("  ·  v" .. D.Version) or ""))
  local lb = ThemeBtn(f, "Live standings", 120, 26, function() D.ToggleLive() end)
  lb:SetPoint("BOTTOMRIGHT", -30, 12)
  f.sub:ClearAllPoints()
  f.sub:SetPoint("RIGHT", lb, "LEFT", -14, 0)
  f.sub:SetJustifyH("RIGHT")
  -- FontStrings can't take mouse scripts: an invisible frame over the sync
  -- text catches the hover for its tooltip.
  f.syncHit = CreateFrame("Frame", nil, f)
  f.syncHit:SetAllPoints(f.sub)

  D.BuildGearStrip(f, SIDE) -- v1.4.0
  main = f
  D.RefreshGearStrip()
end

-- v0.4.0: officer-only tabs (Readiness, Settings) leave no gap in the menu
local function LayoutTabs()
  local y, shown = -10, 0
  for _, t in ipairs(TABS) do
    local b = tabs[t[1]]
    if b and b:IsShown() then shown = shown + 1 end
  end
  local step = shown > 8 and 42 or 46 -- v0.5.0: nine tabs (officers) get tighter spacing
  for _, t in ipairs(TABS) do
    local b = tabs[t[1]]
    if b and b:IsShown() then
      b:ClearAllPoints()
      b:SetPoint("TOPLEFT", b:GetParent(), "TOPLEFT", 10, y)
      y = y - step
    end
  end
end

function D.Toggle(tab, keepOpen)
  if not main then BuildMain() end
  if (tab == "settings" or tab == "ready") and not D.IsAdmin() then tab = "standings" end
  if tab == "log" then tab = "logs" end
  if tab or keepOpen then
    main.tab = tab or main.tab or "standings"
    main:Show()
  else
    main.tab = main.tab or "standings"
    main:SetShown(not main:IsShown())
  end
  D.Refresh()
end

function D.Refresh()
  if D.RefreshGearPlan then D.RefreshGearPlan() end -- v0.6.1
  if D.RefreshRaidLoot then D.RefreshRaidLoot() end -- v0.7.0
  if D.RefreshEnchants then D.RefreshEnchants() end -- v1.3.0
  if D.RefreshGems then D.RefreshGems() end -- v1.4.0
  if D.RefreshGearStrip then D.RefreshGearStrip() end -- v1.4.0
  if main and main.guildName then Fit(main.guildName, (GetGuildInfo and GetGuildInfo("player")) or "Guild Ladder") end -- v0.8.0
  if main and D.data then
    -- the Settings tab is for the guild master and officers only
    local officer = D.IsAdmin()
    tabs.settings:SetShown(officer)
    if tabs.ready then tabs.ready:SetShown(officer) end
    LayoutTabs()
    if (main.tab == "settings" or main.tab == "ready") and not officer then main.tab = "standings" end
  end
  if main and main:IsShown() and D.data then
    for k, page in pairs(pages) do page:SetShown(k == main.tab) end
    for k, b in pairs(tabs) do b:SetActive(k == main.tab) end -- v0.3.0 left menu
    local page = pages[main.tab]
    if page and page.Update then page:Update() end
    local online = 0
    for n, r in pairs(D.roster) do if r.online and D.IsAdmin(n) then online = online + 1 end end
    local officers, synced, stale, mismatched = D.SyncSummary()
    local sync
    if #officers == 0 then
      sync = "no other officers online"
    elseif mismatched > 0 then
      sync = ("|cfff2a54a%d of %d officers out of sync|r"):format(mismatched, #officers)
    elseif stale > 0 then
      sync = ("%d/%d officers synced, %d not heard from yet"):format(synced, #officers, stale)
    else
      sync = ("|cff8fe0c4in sync with %d officer%s|r"):format(#officers, #officers == 1 and "" or "s")
    end
    main.sub:SetText((D.practice and "|cfff2a54aPRACTICE MODE|r · " or "") ..
      ("%d entries · %d officers online · Sync: %s"):format(#D.data.log, online, sync))
    if not main.sub.hooked then
      main.sub.hooked = true
      main.syncHit:SetScript("OnEnter", function(self)
        local off, syn, stl, mis = D.SyncSummary()
        GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT")
        GameTooltip:AddLine("Sync with officers")
        if #off == 0 then GameTooltip:AddLine("No other officers online right now.", 1, 1, 1) end
        local now = GetServerTime()
        for _, n in ipairs(off) do
          local st = D.SyncStatus()[n]
          local line, r, g, b
          if not st or now - st.t > 300 then line, r, g, b = (D.FirstName(n) .. ": not heard from yet"), 0.65, 0.65, 0.68
          elseif st.diff == 0 then line, r, g, b = (D.FirstName(n) .. ": in sync"), 0.56, 0.88, 0.77
          else line, r, g, b = (("%s: %d entr%s different"):format(D.FirstName(n), st.diff, st.diff == 1 and "y" or "ies")), 0.95, 0.65, 0.29 end
          GameTooltip:AddLine(line, r, g, b)
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Catches up automatically - /dkp sync to nudge it.", 0.65, 0.65, 0.68)
        GameTooltip:Show()
      end)
      main.syncHit:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
  end
  D.RefreshQueue()
  D.RefreshLive()
  if aucWin and aucWin:IsShown() then D.RefreshAuction() end
end

---------------------------------------------------------------------------
-- Live standings (everyone, pugs included)
---------------------------------------------------------------------------
local liveWin
local prevBal, deltas = {}, {}

local function BuildLive()
  local f = Window("GuildLadderDKPStandings", "Live Standings", 290, 468, "BOTTOMLEFT", 16, 16)
  f.mode = D.InRaid() and "raid" or "guild"
  -- v0.9.1: the header only holds crest, title, subtitle and close; Raid | Guild sits on its own band below it
  local band = CreateFrame("Frame", nil, f, BD)
  band:SetPoint("TOPLEFT", 1, -48); band:SetPoint("TOPRIGHT", -1, -48); band:SetHeight(30)
  Skin(band, { 0.071, 0.075, 0.094, 1 }, { 0, 0, 0, 0 })
  f.seg = Seg(band, { { "raid", "Raid", 58 }, { "guild", "Guild", 62 } }, function() return f.mode end,
    function(v) f.mode = v; D.RefreshLive() end)
  f.seg:SetPoint("LEFT", 10, 0)

  f.list = List(f, 24, 14, function(parent)
    local r = CreateFrame("Frame", nil, parent, BD)
    Skin(r, { 0, 0, 0, 0 }, { 0, 0, 0, 0 })
    r.bar = r:CreateTexture(nil, "ARTWORK"); r.bar:SetColorTexture(COL.gold[1], COL.gold[2], COL.gold[3], 1) -- v0.9.0: my row gets the gold edge
    r.bar:SetPoint("TOPLEFT"); r.bar:SetPoint("BOTTOMLEFT"); r.bar:SetWidth(3)
    r.rank = Text(r, 11, COL.muted); r.rank:SetPoint("LEFT", 10, 0); r.rank:SetWidth(22)
    r.cls = r:CreateTexture(nil, "ARTWORK"); r.cls:SetSize(16, 16); r.cls:SetPoint("LEFT", 34, 0)
    r.name = Text(r, 12, COL.text); r.name:SetPoint("LEFT", 56, 0); r.name:SetWidth(132)
    r.delta = Text(r, 11, COL.teal); r.delta:SetPoint("RIGHT", -62, 0); r.delta:SetJustifyH("RIGHT")
    r.dkp = Text(r, 13, COL.text, "GameFontNormal"); r.dkp:SetPoint("RIGHT", -14, 0); r.dkp:SetJustifyH("RIGHT")
    return r
  end)
  f.list:SetPoint("TOPLEFT", 1, -80); f.list:SetPoint("TOPRIGHT", -1, -80); f.list:SetHeight(24 * 14)
  HeightResizable(f, "GuildLadderDKPStandings", f.list, 24, 6, 36) -- v0.2.30

  f.emptyIcon = f:CreateTexture(nil, "ARTWORK") -- v0.9.0
  f.emptyIcon:SetSize(72, 72); f.emptyIcon:SetPoint("TOP", f.list, "TOP", 0, -40)
  f.emptyIcon:SetTexture(MEDIA .. "Menu\\Standings.tga"); f.emptyIcon:SetAlpha(0.55)
  f.empty = Text(f, 12, COL.muted)
  f.empty:SetPoint("TOP", f.emptyIcon, "BOTTOM", 0, -12); f.empty:SetWidth(250)
  f.empty:SetJustifyH("CENTER"); f.empty:SetWordWrap(true)

  local foot = CreateFrame("Frame", nil, f, BD)
  foot:SetPoint("BOTTOMLEFT", 1, 1); foot:SetPoint("BOTTOMRIGHT", -1, 1); foot:SetHeight(40)
  Skin(foot, { 0.071, 0.075, 0.094, 1 }, { 0, 0, 0, 0 })
  local fline = foot:CreateTexture(nil, "ARTWORK"); fline:SetColorTexture(unpack(GOLD_DIM))
  fline:SetHeight(2); fline:SetPoint("TOPLEFT"); fline:SetPoint("TOPRIGHT")
  f.me = Text(foot, 12, COL.text); f.me:SetFont(TITLE_FONT, 15); f.me:SetPoint("LEFT", 14, 0); f.me:SetWidth(262)

  f:SetScript("OnShow", function() D.RefreshLive() end)
  Ticker(f, function() if f:IsShown() then D.RefreshLive() end end, 2)
  liveWin = f
end

function D.RefreshLive()
  local f = liveWin
  if not f or not f:IsShown() then return end
  if f.mode == "raid" and not D.InRaid() and not D.InGroup() then f.mode = "guild" end
  local list, sub
  if f.mode == "raid" then
    list = D.RaidStandings()
    local bench = 0
    for _, x in ipairs(list) do if x.bench then bench = bench + 1 end end
    sub = ("Raid · %d players%s · live"):format(#list - bench, bench > 0 and (" + " .. bench .. " bench") or "")
  else
    list = D.Standings()
    sub = ("Guild · %d raiders"):format(#list)
  end
  f.sub:SetText(sub)
  f.seg:Refresh()
  local now = GetTime()
  for _, x in ipairs(list) do
    local before = prevBal[x.name]
    if before and before ~= x.dkp then deltas[x.name] = { d = x.dkp - before, t = now } end
    prevBal[x.name] = x.dkp
  end
  local myRank
  for i, x in ipairs(list) do if D.SameName(x.name, D.Me()) then myRank = i end end
  f.list:SetData(list, function(r, x, i)
    r.rank:SetText(i)
    r.rank:SetTextColor(unpack(i == 1 and COL.gold or COL.muted))
    SetClassIcon(r.cls, x.class or D.ClassOf(x.name))
    local main = D.MainOf(x.name)
    r.name:SetText(x.name .. (main and (" |cffa7afba(" .. D.FirstName(main) .. ")|r") or "") .. (x.bench and " |cff9ccaff(bench)|r" or ""))
    r.name:SetTextColor(ClassColor(x.class or D.ClassOf(x.name)))
    r.dkp:SetText(x.dkp)
    local dl = deltas[x.name]
    if dl and now - dl.t < 60 then
      r.delta:SetText((dl.d > 0 and "+" or "") .. dl.d)
      r.delta:SetTextColor(unpack(dl.d > 0 and COL.teal or COL.red))
    else
      r.delta:SetText("")
    end
    r:SetBackdropColor(unpack(i == myRank and Theme().deep or (i % 2 == 0 and { 0.082, 0.086, 0.106, 1 } or { 0, 0, 0, 0 })))
    r.bar:SetShown(i == myRank)
  end)
  f.emptyIcon:SetShown(#list == 0)
  if #list == 0 then
    f.empty:SetText(f.mode == "guild" and "No guild ledger here.\nIn a raid, standings come from the officers." or "Waiting for standings from an officer...")
    f.empty:Show()
  else
    f.empty:Hide()
  end
  f.me:SetText(("You: |cffe0b04f%d DKP|r%s"):format(D.Balance(D.Me()), myRank and (" · #" .. myRank) or ""))
end

function D.ShowLive() if not liveWin then BuildLive() end liveWin:Show() end
function D.ToggleLive()
  if not liveWin then BuildLive() end
  liveWin:SetShown(not liveWin:IsShown())
end

---------------------------------------------------------------------------
-- Minimap button
---------------------------------------------------------------------------
local mmb
local DEFAULT_MINIMAP_ANGLE = 160
local function PositionMinimap()
  local a = math.rad(D.settings.minimapAngle or DEFAULT_MINIMAP_ANGLE)
  -- Radius was a flat 80px, which only sits just outside the edge for
  -- Blizzard's own default minimap size. Anyone who's resized their minimap
  -- bigger (a common Interface Options slider, or another add-on) ends up
  -- with the icon landing inside it instead, since 80 no longer reaches the
  -- actual edge. Deriving it from the minimap's own current size fixes that
  -- regardless of size/zoom/shape.
  local radius = (Minimap:GetWidth() / 2) + 6
  mmb:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * radius, math.sin(a) * radius)
end

function D.UpdateMinimap()
  if mmb then mmb:SetShown(D.settings.minimap) end
end

-- Puts the icon back at its default spot - for whenever a drag (or the old
-- fixed-radius bug) leaves it somewhere awkward, or just stuck inside the
-- map with no visible handle left to drag it back out by.
function D.ResetMinimap()
  D.settings.minimapAngle = DEFAULT_MINIMAP_ANGLE
  D.settings.minimap = true
  if mmb then
    mmb:ClearAllPoints()
    PositionMinimap()
    D.UpdateMinimap()
  end
end

local function BuildMinimap()
  mmb = CreateFrame("Button", "GuildLadderDKPMinimap", Minimap)
  mmb:SetSize(31, 31)
  mmb:SetFrameStrata("MEDIUM")
  mmb:SetFrameLevel(8)
  local icon = mmb:CreateTexture(nil, "BACKGROUND")
  icon:SetTexture("Interface\\Icons\\INV_Misc_Coin_02")
  icon:SetSize(20, 20)
  icon:SetPoint("CENTER", 0, 1)
  local border = mmb:CreateTexture(nil, "OVERLAY")
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  border:SetSize(53, 53)
  border:SetPoint("TOPLEFT")
  mmb:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
  mmb:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  mmb:RegisterForDrag("LeftButton")
  mmb:SetScript("OnClick", function(_, button)
    if IsShiftKeyDown() then D.ToggleQueue()
    elseif button == "RightButton" then D.ToggleLive()
    else D.Toggle() end
  end)
  mmb:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
      local mx, my = Minimap:GetCenter()
      local cx, cy = GetCursorPosition()
      local s = Minimap:GetEffectiveScale()
      D.settings.minimapAngle = math.deg(math.atan2(cy / s - my, cx / s - mx))
      self:ClearAllPoints()
      PositionMinimap()
    end)
  end)
  mmb:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
  mmb:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    -- v0.2.30: installed version, plus a heads-up if a guildmate is on a newer one
    GameTooltip:AddDoubleLine("Guild Ladder DKP", "v" .. (D.Version or "?"), 1, 0.82, 0, 0.65, 0.69, 0.73)
    if D.newestSeen and D.VerCmp and D.VerCmp(D.newestSeen, D.Version) > 0 then
      GameTooltip:AddLine(("Newer version seen: v%s - update on CurseForge"):format(D.newestSeen), 0.95, 0.65, 0.29)
    end
    GameTooltip:AddLine(("Your DKP: %d"):format(D.Balance(D.Me())), 1, 1, 1)
    GameTooltip:AddLine("Left-click: standings, raid night, settings", 1, 1, 1)
    GameTooltip:AddLine("Right-click: live standings", 1, 1, 1)
    GameTooltip:AddLine("Shift-click: loot queue", 1, 1, 1)
    GameTooltip:Show()
  end)
  mmb:SetScript("OnLeave", function() GameTooltip:Hide() end)
  PositionMinimap()
  D.UpdateMinimap()
end

function D.InitUI()
  BuildKeyFrame()
  BuildMinimap()
  pcall(HookTooltips)
end
