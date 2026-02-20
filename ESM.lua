local PREFIX = "|cff33ff99ESM|r "
local SLOT_FIRST = 1
local SLOT_LAST = 19
local NUM_SETS = 5

local db
local buttons = {}

local function GetSetName(index)
  if db and db.names and db.names[index] then
    return db.names[index]
  end
  return "Set " .. index
end

local function SetSetName(index, name)
  if not db.names then db.names = {} end
  if name and name ~= "" then
    db.names[index] = name
  else
    db.names[index] = nil
  end
end

local function Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. msg)
end

local function GetCharacterKey()
  local name = UnitName("player") or "Unknown"
  local realm = GetRealmName() or "Unknown"
  return name .. "-" .. realm
end

local function EnsureDB()
  if type(ESMDB) ~= "table" then
    ESMDB = {}
  end
  local key = GetCharacterKey()
  if type(ESMDB[key]) ~= "table" then
    ESMDB[key] = {}
  end
  db = ESMDB[key]
end

local function CaptureGear()
  local gear = {}
  for slot = SLOT_FIRST, SLOT_LAST do
    gear[slot] = GetInventoryItemLink("player", slot)
  end
  return gear
end

local function EquipGear(gear)
  for slot = SLOT_FIRST, SLOT_LAST do
    if gear[slot] then
      EquipItemByName(gear[slot], slot)
    end
  end
end

local function UpdateButtons()
  EnsureDB()
  for i = 1, NUM_SETS do
    local btn = buttons[i]
    if btn then
      local saved = type(db[i]) == "table"
      local name = db.names and db.names[i]
      btn:SetText(name or i)
      local w = btn:GetFontString():GetStringWidth() + 16
      if w < 26 then w = 26 end
      btn:SetWidth(w)
      local fs = btn:GetFontString()
      if saved then
        fs:SetTextColor(0.2, 1, 0.2)
      else
        fs:SetTextColor(0.5, 0.5, 0.5)
      end
    end
  end
  -- reposition after width changes
  if buttons[1] then
    for i = 2, NUM_SETS do
      if buttons[i] then
        buttons[i]:ClearAllPoints()
        buttons[i]:SetPoint("LEFT", buttons[i - 1], "RIGHT", 2, 0)
      end
    end
  end
end

local function SaveSet(index)
  EnsureDB()
  db[index] = CaptureGear()
  Print(("%s saved."):format(GetSetName(index)))
  UpdateButtons()
end

local function SwitchSet(index)
  EnsureDB()
  if InCombatLockdown() then
    Print("Cannot switch in combat.")
    return
  end
  local gear = db[index]
  if type(gear) ~= "table" then
    Print(("%s is empty. Right-click to save."):format(GetSetName(index)))
    return
  end
  EquipGear(gear)
  Print(("Equipping %s."):format(GetSetName(index)))
end

StaticPopupDialogs["ESM_RENAME"] = {
  text = "Rename set %d:",
  button1 = "OK",
  button2 = "Cancel",
  hasEditBox = true,
  editBoxWidth = 200,
  OnShow = function(self)
    local eb = _G[self:GetName() .. "EditBox"]
    local name = ""
    if db and db.names and db.names[self.data] then
      name = db.names[self.data]
    end
    eb:SetText(name)
    eb:HighlightText()
  end,
  OnAccept = function(self)
    local eb = _G[self:GetName() .. "EditBox"]
    local text = strtrim(eb:GetText())
    SetSetName(self.data, text)
    UpdateButtons()
    if text ~= "" then
      Print(("Set %d renamed: %s"):format(self.data, text))
    else
      Print(("Set %d name cleared."):format(self.data))
    end
  end,
  EditBoxOnEnterPressed = function(self)
    local parent = self:GetParent()
    local text = strtrim(self:GetText())
    SetSetName(parent.data, text)
    UpdateButtons()
    if text ~= "" then
      Print(("Set %d renamed: %s"):format(parent.data, text))
    else
      Print(("Set %d name cleared."):format(parent.data))
    end
    parent:Hide()
  end,
  EditBoxOnEscapePressed = function(self)
    self:GetParent():Hide()
  end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  preferredIndex = 3,
}

local function CreateUI()
  for i = 1, NUM_SETS do
    local btn = CreateFrame("Button", "ESMBtn" .. i, PaperDollFrame, "UIPanelButtonTemplate")
    btn:SetHeight(22)
    btn:SetText(i)  -- default, UpdateButtons() will override

    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    btn:SetScript("OnClick", function(self, button)
      if IsShiftKeyDown() and button == "LeftButton" then
        EnsureDB()
        StaticPopup_Show("ESM_RENAME", i, nil, i)
      elseif button == "RightButton" then
        SaveSet(i)
      else
        SwitchSet(i)
      end
    end)

    btn:SetScript("OnEnter", function(self)
      EnsureDB()
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine(GetSetName(i), 1, 1, 1)
      if type(db[i]) == "table" then
        local count = 0
        for slot = SLOT_FIRST, SLOT_LAST do
          if db[i][slot] then count = count + 1 end
        end
        GameTooltip:AddLine(count .. " items", 0.7, 0.7, 0.7)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Left-click to equip", 0, 1, 0)
        GameTooltip:AddLine("Right-click to overwrite", 1, 0.5, 0)
      else
        GameTooltip:AddLine("Empty", 0.5, 0.5, 0.5)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Right-click to save", 0, 1, 0)
      end
      GameTooltip:AddLine("Shift+click to rename", 0.7, 0.7, 1)
      GameTooltip:Show()
    end)

    btn:SetScript("OnLeave", function()
      GameTooltip:Hide()
    end)

    buttons[i] = btn
  end

  -- horizontal row at the top of character frame
  buttons[1]:SetPoint("TOPLEFT", CharacterFrame, "TOPLEFT", 74, -2)
  for i = 2, NUM_SETS do
    buttons[i]:SetPoint("LEFT", buttons[i - 1], "RIGHT", 2, 0)
  end
end

-- slash command (backup)
SLASH_ESM1 = "/esm"
SlashCmdList.ESM = function(input)
  EnsureDB()
  local cmd, raw = string.match(input or "", "^(%S+)%s*(.-)$")
  cmd = string.lower(cmd or "")

  if cmd == "save" then
    local idx = tonumber(raw)
    if idx then SaveSet(idx) else Print("/esm save N") end
  elseif cmd == "equip" then
    local idx = tonumber(raw)
    if idx then SwitchSet(idx) else Print("/esm equip N") end
  elseif cmd == "delete" then
    local idx = tonumber(raw)
    if not idx then Print("/esm delete N"); return end
    if type(db[idx]) ~= "table" then
      Print(("%s not found."):format(GetSetName(idx)))
    else
      db[idx] = nil
      Print(("Set %d deleted."):format(idx))
      UpdateButtons()
    end
  elseif cmd == "rename" then
    local idx, name = string.match(raw, "^(%d+)%s*(.*)")
    idx = tonumber(idx)
    if not idx then Print("/esm rename N name"); return end
    SetSetName(idx, name)
    UpdateButtons()
    if name and name ~= "" then
      Print(("Set %d renamed: %s"):format(idx, name))
    else
      Print(("Set %d name cleared."):format(idx))
    end
  elseif cmd == "list" then
    local found = false
    for idx, gear in pairs(db) do
      if type(idx) == "number" and type(gear) == "table" then
        found = true
        local count = 0
        for slot = SLOT_FIRST, SLOT_LAST do
          if gear[slot] then count = count + 1 end
        end
        Print(("  %d — %s (%d items)"):format(idx, GetSetName(idx), count))
      end
    end
    if not found then Print("No saved sets.") end
  else
    Print("Commands: /esm save|equip|delete|rename|list N")
    Print("Or use buttons 1-5 in character frame (C).")
  end
end

-- init
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function()
  EnsureDB()
  CreateUI()
  UpdateButtons()
  Print("Ready. Buttons 1-5 in character frame (C).")
end)

PaperDollFrame:HookScript("OnShow", function()
  UpdateButtons()
end)
