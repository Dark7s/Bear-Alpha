--[[
    Bear Alpha V1 - Matcha (Full Version with Auto Quidz Farm)
]]

-- ==================== WAIFU UI LIBRARY ====================
local DrawingNew = Drawing.new
local V2 = Vector2.new
local C3 = Color3.fromRGB
local C3N = Color3.new
local C3HEX = Color3.fromHex
local HSV = Color3.fromHSV

local abs = math.abs
local floor = math.floor
local max = math.max
local min = math.min
local sin = math.sin
local clock = os.clock
local remove = table.remove
local concat = table.concat

local function clamp(value, low, high)
    if value < low then return low end
    if value > high then return high end
    return value
end

local function bool(value) return value == true end

local Players = game:GetService("Players")
local Workspace = workspace
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer and LocalPlayer:GetMouse()

local Fonts = (type(Drawing) == "table" and Drawing.Fonts) or {}
local FontSystem = Fonts.System or Fonts.UI or 0
local FontBold = Fonts.SystemBold or FontSystem
local FontUI = Fonts.UI or FontSystem
local FontMono = Fonts.Monospace or FontUI
local FontWidths = {[FontSystem] = 0.52, [FontBold] = 0.56, [FontUI] = 0.48, [FontMono] = 0.56}

local DRAW_VISIBLE = 1
local MENU_KEY = "f1"

local PAD = 10
local TITLE_H = 36
local TAB_H = 30
local ROW_H = 28
local CONTROL_H = 22
local SECTION_HEAD_H = 22
local CONTENT_PAD = 8
local DEFAULT_W = 430
local DEFAULT_H = 500
local MINIMIZED_H = 42
local TAB_MIN_W = 80

local SHADOW_ALPHA = {0.10, 0.07, 0.05, 0.03, 0.015}
local KEYBIND_MODES = {"Hold", "Toggle", "Always"}

local Theme = {
    bg = C3(16, 22, 18), surface = C3(24, 32, 26), surface2 = C3(34, 44, 36),
    surface3 = C3(44, 56, 46), text = C3(235, 245, 235), sub = C3(130, 160, 130),
    accent = C3(88, 196, 120), green = C3(52, 199, 89), red = C3(255, 69, 58),
    yellow = C3(255, 204, 0), border = C3(48, 62, 52),
    toggleOn = C3(88, 196, 120), toggleOff = C3(65, 85, 68),
    knob = C3(255, 255, 255), white = C3(255, 255, 255), black = C3(0, 0, 0),
}

local ProjectState = {
    alive = true, destroyed = false, rendering = false, open = true,
    x = 100, y = 80, w = DEFAULT_W, h = DEFAULT_H, defaultH = DEFAULT_H,
    minimized = false, title = "Bear Alpha V1", tabs = {}, activeTab = nil, activeIndex = 0,
    drag = nil, sliderDrag = nil, scrollDrag = nil, focus = nil,
    dropdown = nil, colorpicker = nil, activities = {}, activityId = 0,
    mouseX = 0, mouseY = 0, hasMouse = false, focusedWindow = true,
    inputState = nil, tooltipText = nil, tooltipAt = 0, tooltipX = 0, tooltipY = 0,
    searchOpen = false, searchQuery = "", tabScrollX = 0, tabTargetScrollX = 0, tabScrollToActive = false,
    diagnosticsEnabled = false, watermarkEnabled = false,
    watermarkTitle = "", watermarkX = 20, watermarkY = 20, watermarkDrag = nil,
    activityText = "", errorCount = 0, windowControlsStyle = "Windows",
    customControls = {align = "right", closeColor = C3(255, 95, 87), minColor = C3(255, 189, 46), restoreColor = C3(39, 201, 63)},
    lastFrame = clock()
}

local Pool = {sq = {}, tx = {}, ln = {}, ci = {}, tr = {}, im = {}}
local PoolIndex = {sq = 0, tx = 0, ln = 0, ci = 0, tr = 0, im = 0}
local PoolHighWater = {sq = 0, tx = 0, ln = 0, ci = 0, tr = 0, im = 0}
local Cleanup = {drawings = Pool}
local TypeMap = {sq = "Square", tx = "Text", ln = "Line", ci = "Circle", tr = "Triangle", im = "Image"}

local Input = {}
local InputOrder = {}

local function addInput(name, id, char, shifted)
    name = string.lower(tostring(name))
    if not Input[name] then InputOrder[#InputOrder + 1] = name end
    Input[name] = {id = id, held = false, click = false, released = false, char = char, shifted = shifted}
end

addInput("m1", 0x01); addInput("m2", 0x02); addInput("backspace", 0x08)
addInput("tab", 0x09); addInput("enter", 0x0D); addInput("shift", 0x10)
addInput("ctrl", 0x11); addInput("alt", 0x12); addInput("esc", 0x1B)
addInput("space", 0x20, " ", " "); addInput("pageup", 0x21); addInput("pagedown", 0x22)
addInput("end", 0x23); addInput("home", 0x24); addInput("left", 0x25)
addInput("up", 0x26); addInput("right", 0x27); addInput("down", 0x28)
addInput("delete", 0x2E)
for i = 0, 9 do addInput(tostring(i), 0x30 + i, tostring(i), ("))!@#$%^&*("):sub(i+1, i+1)) end
for i = 0, 25 do local ch = string.char(97 + i); addInput(ch, 0x41 + i, ch, string.upper(ch)) end
for i = 1, 12 do addInput("f" .. tostring(i), 0x6F + i) end

local UI = {}

local function viewportSize()
    local camera = Workspace.CurrentCamera
    if camera and camera.ViewportSize then return camera.ViewportSize.X, camera.ViewportSize.Y end
    return 1920, 1080
end

local function colorChanged(a, b)
    if not a or not b then return a ~= b end
    return abs(a.R - b.R) > 0.001 or abs(a.G - b.G) > 0.001 or abs(a.B - b.B) > 0.001
end

local function copyArray(source)
    local out = {}
    if type(source) == "table" then for i = 1, #source do out[i] = source[i] end
    elseif source ~= nil then out[1] = source end
    return out
end

local function normalizeKey(value)
    if value == nil then return nil end
    value = string.lower(tostring(value))
    if value == "" or value == "-" or value == "none" or value == "nil" or value == "unbound" then return nil end
    return value
end

local function normalizeMode(value)
    if value == "Toggle" or value == "Always" then return value end
    return "Hold"
end

local function safeCallback(callback, ...)
    if type(callback) ~= "function" then return end
    local ok, result = pcall(callback, ...)
    if not ok then warn("UI callback error: " .. tostring(result)) end
    return result
end

local function setOpen(open)
    open = bool(open)
    if ProjectState.open == open then return end
    ProjectState.open = open
    ProjectState.drag = nil; ProjectState.sliderDrag = nil; ProjectState.scrollDrag = nil
    ProjectState.dropdown = nil; ProjectState.colorpicker = nil; ProjectState.focus = nil
end

local function clampWindow()
    local vw, vh = viewportSize()
    ProjectState.x = clamp(ProjectState.x, 0, max(0, vw - min(80, ProjectState.w)))
    ProjectState.y = clamp(ProjectState.y, 0, max(0, vh - min(40, ProjectState.h)))
end

local function getMouse()
    if not Mouse then LocalPlayer = Players.LocalPlayer; Mouse = LocalPlayer and LocalPlayer:GetMouse() end
    if Mouse then ProjectState.mouseX = Mouse.X; ProjectState.mouseY = Mouse.Y; ProjectState.hasMouse = true; return Mouse.X, Mouse.Y end
    ProjectState.hasMouse = false; return nil, nil
end

local function over(x, y, w, h)
    return ProjectState.hasMouse and ProjectState.mouseX >= x and ProjectState.mouseX <= x + w and ProjectState.mouseY >= y and ProjectState.mouseY <= y + h
end

local function resetPool()
    PoolIndex.sq = 0; PoolIndex.tx = 0; PoolIndex.ln = 0; PoolIndex.ci = 0; PoolIndex.tr = 0; PoolIndex.im = 0
end

local function getDrawing(kind)
    if not ProjectState.alive or ProjectState.destroyed then return nil end
    PoolIndex[kind] = PoolIndex[kind] + 1
    local index = PoolIndex[kind]; local list = Pool[kind]; local object = list[index]
    if not object then
        local ok, created = pcall(DrawingNew, TypeMap[kind])
        if not ok or not created then return nil end
        object = created; list[index] = object
    end
    if index > PoolHighWater[kind] then PoolHighWater[kind] = index end
    object.Visible = true; return object
end

local function hideUnused()
    for kind, list in pairs(Pool) do
        local current = PoolIndex[kind]; local high = PoolHighWater[kind]
        if current < high then for i = current + 1, high do list[i].Visible = false end end
        if current > high then PoolHighWater[kind] = current end
    end
end

local function hideAll()
    for kind, list in pairs(Pool) do for i = 1, #list do list[i].Visible = false end end
end

local function removeAllDrawings()
    for _, list in pairs(Cleanup.drawings) do
        for i = 1, #list do local obj = list[i]; if obj then pcall(function() obj.Visible = false; obj:Remove() end); list[i] = nil end end
    end
end

local function rect(x, y, w, h, color, z, radius, transparency)
    if w <= 0 or h <= 0 then return end
    local d = getDrawing("sq"); if not d then return end
    d.Position = V2(x, y); d.Size = V2(w, h); d.Color = color; d.Filled = true
    d.Corner = radius or 0; d.ZIndex = z or 1; d.Transparency = transparency or DRAW_VISIBLE
end

local function strokeRect(x, y, w, h, color, z, radius, transparency)
    if w <= 0 or h <= 0 then return end
    local d = getDrawing("sq"); if not d then return end
    d.Position = V2(x, y); d.Size = V2(w, h); d.Color = color; d.Filled = false
    d.Corner = radius or 0; d.ZIndex = z or 1; d.Transparency = transparency or DRAW_VISIBLE
end

local function textWidth(value, size, font)
    return #tostring(value or "") * ((size or 13) * (FontWidths[font] or 0.52))
end

local function trimText(value, maxWidth, size, font)
    value = tostring(value or "")
    if maxWidth <= 0 then return "" end
    local multiplier = FontWidths[font] or 0.52
    local maxChars = floor(maxWidth / ((size or 13) * multiplier))
    if maxChars <= 0 then return "" end
    if #value <= maxChars then return value end
    if maxChars <= 2 then return "" end
    return string.sub(value, 1, maxChars - 2) .. ".."
end

local function txt(value, x, y, color, size, font, z, centered, outline, maxWidth, transparency)
    if value == nil or value == "" then return end
    if maxWidth then value = trimText(value, maxWidth, size, font); if value == "" then return end end
    local d = getDrawing("tx"); if not d then return end
    d.Text = tostring(value); d.Position = V2(x, y); d.Color = color; d.Size = size or 13
    d.Font = font or FontSystem; d.ZIndex = (z or 1) + 10; d.Center = centered == true
    d.Outline = outline == true; d.Transparency = transparency or DRAW_VISIBLE
end

local function centerY(y, h) return y + h / 2 end
local function textTop(y, h, size) return floor(y + (h - (size or 13)) / 2 + 0.5) end

local function line(x1, y1, x2, y2, color, z, thickness, transparency)
    local d = getDrawing("ln"); if not d then return end
    d.From = V2(x1, y1); d.To = V2(x2, y2); d.Color = color; d.Thickness = thickness or 1
    d.ZIndex = z or 1; d.Transparency = transparency or DRAW_VISIBLE
end

local function circle(x, y, radius, color, z, filled, thickness, sides, transparency)
    local d = getDrawing("ci"); if not d then return end
    d.Position = V2(x, y); d.Radius = radius; d.Color = color; d.Filled = filled ~= false
    d.Thickness = thickness or 1; d.NumSides = sides or 32; d.ZIndex = z or 1
    d.Transparency = transparency or DRAW_VISIBLE
end

local function triangle(a, b, c, color, z, filled, transparency)
    local d = getDrawing("tr"); if not d then return end
    d.PointA = a; d.PointB = b; d.PointC = c; d.Color = color; d.Filled = filled ~= false
    d.Thickness = 1; d.ZIndex = z or 1; d.Transparency = transparency or DRAW_VISIBLE
end

local function drawChevronDown(x, y, color, z)
    triangle(V2(x, y), V2(x + 8, y), V2(x + 4, y + 5), color, z, true)
end

local function snapValue(raw, item)
    local minValue = item.min or 0; local maxValue = item.max or 100; local step = item.step or 1
    if step <= 0 then step = 1 end
    return clamp(minValue + step * floor(((raw - minValue) / step) + 0.5 + 0.0001), minValue, maxValue)
end

local function setDropdownValue(item, value, fire)
    local newValue = copyArray(value)
    local changed = #newValue ~= #item.value
    for i = 1, max(#item.value, #newValue) do if item.value[i] ~= newValue[i] then changed = true; break end end
    for i = #item.value, 1, -1 do item.value[i] = nil end
    for i = 1, #newValue do item.value[i] = newValue[i] end
    if changed and fire ~= false then safeCallback(item.callback, item.value) end
end

local function setItemValue(item, value, fire)
    if item.type == "dropdown" then setDropdownValue(item, value, fire); return end
    if item.type == "slider" then value = snapValue(tonumber(value) or item.value or item.min or 0, item)
    elseif item.type == "toggle" then value = value == true
    elseif item.type == "textbox" then value = tostring(value or "") end
    local changed = item.value ~= value; item.value = value
    if changed and fire ~= false then safeCallback(item.callback, value) end
end

local keybindItems = {}

local function makeItem(section, item)
    section.items[#section.items + 1] = item
    local handle = {item = item}; item.handle = handle
    function handle:Set(value) setItemValue(item, value, true); return self end
    if item.type == "toggle" then
        function handle:AddKeybind(defaultKey, mode, canChange, callback)
            local keybind = {value = normalizeKey(defaultKey), mode = normalizeMode(mode), canChange = canChange ~= false, callback = callback, listening = false, listenAt = 0}
            item.keybind = keybind; keybindItems[#keybindItems + 1] = item
            local keyHandle = {}
            function keyHandle:Set(newKey, newMode) keybind.value = normalizeKey(newKey); if newMode then keybind.mode = normalizeMode(newMode) end; safeCallback(keybind.callback, keybind.value and Input[keybind.value] and Input[keybind.value].id or nil, keybind.mode); return self end
            return keyHandle
        end
        function handle:AddColorpicker(label, defaultColor, overwrite, callback)
            local picker = {label = tostring(label or "Color"), value = defaultColor or Theme.accent, overwrite = overwrite == true, callback = callback}
            item.colorpicker = picker
            local colorHandle = {}
            function colorHandle:Set(newColor) if newColor and colorChanged(picker.value, newColor) then picker.value = newColor; safeCallback(picker.callback, newColor) end; return self end
            return colorHandle
        end
    elseif item.type == "dropdown" then
        function handle:UpdateChoices(newChoices) item.choices = copyArray(newChoices); return self end
    end
    return handle
end

local function createSection(tab, name)
    local section = {name = tostring(name or "Section"), items = {}, collapsed = false}
    tab.sections[#tab.sections + 1] = section
    local sectionApi = {}
    function sectionApi:Label(label, color) return makeItem(section, {type = "label", label = tostring(label or ""), color = color or Theme.text}) end
    function sectionApi:Toggle(label, default, callback) return makeItem(section, {type = "toggle", label = tostring(label or "Toggle"), value = default == true, callback = callback}) end
    function sectionApi:Slider(label, default, step, minValue, maxValue, suffix, callback)
        local item = {type = "slider", label = tostring(label or "Slider"), value = tonumber(default) or 0, step = tonumber(step) or 1, min = tonumber(minValue) or 0, max = tonumber(maxValue) or 100, suffix = suffix or "", callback = callback}
        item.value = snapValue(item.value, item); return makeItem(section, item)
    end
    function sectionApi:Dropdown(label, default, choices, multi, callback) return makeItem(section, {type = "dropdown", label = tostring(label or "Dropdown"), value = copyArray(default), choices = copyArray(choices), multi = multi == true, callback = callback}) end
    function sectionApi:Button(label, callback) return makeItem(section, {type = "button", label = tostring(label or "Button"), callback = callback}) end
    function sectionApi:Textbox(label, default, callback) return makeItem(section, {type = "textbox", label = tostring(label or "Textbox"), value = tostring(default or ""), callback = callback}) end
    function sectionApi:Divider(label) return makeItem(section, {type = "divider", label = label and tostring(label) or nil}) end
    return sectionApi
end

function UI:SetMenuKey(key) MENU_KEY = normalizeKey(tostring(key or "f1")) or "f1"; return self end
function UI:SetTheme(overrides) if type(overrides) == "table" then for k, v in pairs(overrides) do if Theme[k] ~= nil then Theme[k] = v end end end; return self end
function UI:SetOpen(bool) setOpen(bool == true); return self end
function UI:SetTitle(text) ProjectState.title = tostring(text or "Bear Alpha V1"); return self end
function UI:SetSize(w, h) ProjectState.w = max(300, tonumber(w) or ProjectState.w); ProjectState.h = max(120, tonumber(h) or ProjectState.h); if ProjectState.h > MINIMIZED_H then ProjectState.defaultH = ProjectState.h; ProjectState.minimized = false end; clampWindow(); return self end
function UI:Center() local vw, vh = viewportSize(); ProjectState.x = floor(vw / 2 - ProjectState.w / 2); ProjectState.y = floor(vh / 2 - ProjectState.h / 2); clampWindow(); return self end

function UI:Tab(name)
    local tab = {name = tostring(name or ("Tab " .. tostring(#ProjectState.tabs + 1))), sections = {}, scrollY = 0, targetScrollY = 0, maxScroll = 0}
    ProjectState.tabs[#ProjectState.tabs + 1] = tab
    if not ProjectState.activeTab then ProjectState.activeTab = tab; ProjectState.activeIndex = #ProjectState.tabs end
    local tabApi = {}
    function tabApi:Section(sectionName) return createSection(tab, sectionName) end
    return tabApi
end

function UI:RegisterActivity(callback)
    ProjectState.activityId = ProjectState.activityId + 1
    local activity = {id = ProjectState.activityId, callback = callback, alive = true}
    ProjectState.activities[#ProjectState.activities + 1] = activity
    return {Remove = function() activity.alive = false end}
end

function UI:CreateSettingsTab(name)
    local tab = self:Tab(name or "Settings")
    local menuSec = tab:Section("Menu Settings")
    menuSec:Toggle("Menu Keybind", true):AddKeybind(MENU_KEY or "f1", "Toggle", true, function(keyId) if keyId then UI:SetMenuKey(keyId) end end)
    menuSec:Textbox("Menu Title", ProjectState.title or "Bear Alpha V1", function(val) UI:SetTitle(val) end)
    menuSec:Button("Center Window", function() UI:Center() end)
    menuSec:Toggle("Watermark Enabled", ProjectState.watermarkEnabled, function(val) ProjectState.watermarkEnabled = val end)
    return tab
end

local stepConnection
local function finalDestroy()
    if ProjectState.destroyed then return end
    ProjectState.destroyed = true; ProjectState.open = false
    ProjectState.dropdown = nil; ProjectState.colorpicker = nil; ProjectState.focus = nil
    ProjectState.drag = nil; ProjectState.sliderDrag = nil; ProjectState.scrollDrag = nil
    if stepConnection then stepConnection:Disconnect(); stepConnection = nil end
    if type(setrobloxinput) == "function" then setrobloxinput(true) end
    ProjectState.inputState = true
    removeAllDrawings()
end

function UI:Destroy() ProjectState.alive = false; ProjectState.open = false; if not ProjectState.rendering then finalDestroy() end; return self end

local function updateInput()
    local active = true
    if type(isrbxactive) == "function" then 
        local success, result = pcall(isrbxactive)
        if success then active = result == true end
    end
    ProjectState.focusedWindow = active
    for i = 1, #InputOrder do local input = Input[InputOrder[i]]; input.click = false; input.released = false end
    
    local m1 = false
    local m2 = false
    if active then
        local success1, r1 = pcall(ismouse1pressed)
        if success1 then m1 = r1 == true end
        local success2, r2 = pcall(ismouse2pressed)
        if success2 then m2 = r2 == true end
    end
    
    Input.m1.click = m1 and not Input.m1.held
    Input.m1.released = (not m1) and Input.m1.held
    Input.m1.held = m1
    Input.m2.click = m2 and not Input.m2.held
    Input.m2.released = (not m2) and Input.m2.held
    Input.m2.held = m2
    
    for i = 1, #InputOrder do
        local name = InputOrder[i]
        if name ~= "m1" and name ~= "m2" then
            local input = Input[name]
            local down = false
            if active then
                local success, result = pcall(iskeypressed, input.id)
                if success then down = result == true end
            end
            input.click = down and not input.held
            input.released = (not down) and input.held
            input.held = down
        end
    end
end

local function lerpColor(c1, c2, t) return C3N(c1.R + (c2.R - c1.R) * t, c1.G + (c2.G - c1.G) * t, c1.B + (c2.B - c1.B) * t) end

local function smoothValue(current, target, speed)
    local dtValue = ProjectState.dt or 1/60
    if dtValue <= 0 then dtValue = 1/60 end
    return current + (target - current) * (1 - math.exp(-(speed or 15) * dtValue))
end

local function isItemDisabled(item)
    if not item then return false end
    local dep = item.dependsOn
    if dep and dep.item then if not dep.item.value or isItemDisabled(dep.item) then return true end end
    return false
end

local function processTextInput()
    if ProjectState.focus and ProjectState.focus.type == "textbox" then
        local item = ProjectState.focus
        if Input.enter.click or Input.esc.click then ProjectState.focus = nil; return end
        local value = item.value or ""
        local changed = false
        if Input.backspace.click then value = string.sub(value, 1, max(0, #value - 1)); changed = true end
        for i = 1, #InputOrder do
            local input = Input[InputOrder[i]]
            if input.click and input.char then value = value .. input.char; changed = true; break end
        end
        if changed then item.value = value; safeCallback(item.callback, value) end
    end
end

local function processKeybinds()
    if ProjectState.focus then return end
    for i = 1, #keybindItems do
        local item = keybindItems[i]
        local keybind = item.keybind
        if item.type == "toggle" and keybind and keybind.value and not keybind.listening and not isItemDisabled(item) then
            local input = Input[keybind.value]
            if input then
                if keybind.mode == "Always" then setItemValue(item, true, true)
                elseif keybind.mode == "Toggle" and input.click then setItemValue(item, not item.value, true)
                else setItemValue(item, input.held, true) end
            end
        end
    end
end

local function runActivities(dt, now)
    local parts = {}
    for i = 1, #ProjectState.activities do
        local activity = ProjectState.activities[i]
        if activity and activity.alive then
            local result = safeCallback(activity.callback, UI, dt, now)
            if result ~= nil and result ~= "" then parts[#parts + 1] = tostring(result) end
        end
    end
    ProjectState.activityText = #parts > 0 and concat(parts, " | ") or ""
end

local function renderTabs(click, px, py, pw)
    local count = #ProjectState.tabs
    if count == 0 then return click end
    rect(px, py, pw, TAB_H, Theme.surface2, 20, 7)
    local totalW = count * TAB_MIN_W
    local needsScroll = totalW > pw
    local tabW = needsScroll and TAB_MIN_W or (pw / count)
    local maxScroll = max(0, totalW - pw)
    local current = ProjectState.tabScrollX or 0
    current = clamp(current + (ProjectState.tabTargetScrollX - current) * 0.3, 0, maxScroll)
    ProjectState.tabScrollX = current
    local scrollX = current
    local contentX = px + (needsScroll and 18 or 0)
    for i = 1, count do
        local tab = ProjectState.tabs[i]
        local tx = contentX + tabW * (i - 1) - scrollX
        local active = ProjectState.activeTab == tab
        if active then rect(tx + 3, py + 3, tabW - 6, TAB_H - 6, Theme.accent, 22, 6) end
        local hovered = over(tx, py, tabW, TAB_H)
        if hovered and not active then rect(tx + 3, py + 3, tabW - 6, TAB_H - 6, Theme.surface3, 21, 6) end
        txt(tab.name, tx + tabW / 2, centerY(py, TAB_H), active and Theme.white or (hovered and Theme.text or Theme.sub), 13, active and FontBold or FontSystem, 25, true, false, tabW - 12)
        if click and hovered then
            ProjectState.activeTab = tab
            ProjectState.activeIndex = i
            ProjectState.dropdown = nil
            ProjectState.colorpicker = nil
            ProjectState.focus = nil
            click = false
        end
    end
    return click
end

local function renderSections(tab, click, held, rightClick, px, contY, pw, contH)
    if not tab then return click, held, rightClick end
    local contentH = CONTENT_PAD
    for si = 1, #tab.sections do
        local section = tab.sections[si]
        local h = SECTION_HEAD_H + CONTENT_PAD
        if not section.collapsed then h = h + #section.items * ROW_H end
        contentH = contentH + h
    end
    local viewH = max(1, contH - CONTENT_PAD * 2)
    tab.maxScroll = max(0, contentH - viewH)
    tab.scrollY = clamp(tab.scrollY + (tab.targetScrollY - tab.scrollY) * 0.3, 0, tab.maxScroll)
    local sy = contY + CONTENT_PAD - tab.scrollY
    local clipTop = contY + 4
    local clipBottom = contY + contH - 4
    local rowX = px + 12
    local rowW = pw - 24
    for si = 1, #tab.sections do
        local section = tab.sections[si]
        local sectionH = SECTION_HEAD_H + CONTENT_PAD
        if not section.collapsed then sectionH = sectionH + #section.items * ROW_H end
        if sy + sectionH >= clipTop and sy <= clipBottom then
            if sy >= clipTop and sy + SECTION_HEAD_H <= clipBottom then
                local textX = rowX + 16
                local headerMidY = centerY(sy, SECTION_HEAD_H)
                if section.collapsed then
                    triangle(V2(rowX, headerMidY - 4), V2(rowX, headerMidY + 4), V2(rowX + 6, headerMidY), Theme.sub, 35, true)
                else
                    triangle(V2(rowX, headerMidY - 3), V2(rowX + 8, headerMidY - 3), V2(rowX + 4, headerMidY + 2), Theme.sub, 35, true)
                end
                txt(string.upper(section.name), textX, textTop(sy, SECTION_HEAD_H, 12), Theme.sub, 12, FontBold, 35, false, false, rowW - 16)
                if click and over(rowX, sy, rowW, SECTION_HEAD_H) then
                    section.collapsed = not section.collapsed
                    click = false
                end
            end
            if not section.collapsed then
                local rowY = sy + SECTION_HEAD_H
                for ii = 1, #section.items do
                    local item = section.items[ii]
                    if rowY >= clipTop and rowY + ROW_H <= clipBottom then
                        local disabled = isItemDisabled(item)
                        local trans = disabled and 0.4 or nil
                        local hoveredRow = over(rowX, rowY, rowW, ROW_H - 2)
                        if hoveredRow and item.type ~= "divider" then
                            rect(rowX - 3, rowY, rowW + 6, ROW_H - 2, C3(42, 42, 49), 36, 5, trans)
                        end
                        if item.type == "label" then
                            txt(item.label, rowX, textTop(rowY, ROW_H - 2, 13), item.color or Theme.text, 13, FontSystem, 42, false, false, rowW, trans)
                        elseif item.type == "toggle" then
                            local labelColor = item.value and Theme.text or Theme.sub
                            if item.colorpicker and item.colorpicker.overwrite then labelColor = item.colorpicker.value end
                            txt(item.label, rowX, textTop(rowY, ROW_H - 2, 14), labelColor, 14, FontSystem, 42, false, false, rowW - 60, trans)
                            local tx, ty = rowX + rowW - 42, rowY + 6
                            local hovered = over(tx - 4, ty - 5, 38, 24)
                            rect(tx, ty, 30, 16, item.value and Theme.toggleOn or Theme.toggleOff, 42, 8, trans)
                            circle(tx + 6 + 18 * (item.value and 1 or 0), ty + 8, 6, Theme.knob, 44, true, 0, 32, trans)
                            if click and hovered and not disabled then
                                setItemValue(item, not item.value, true)
                                click = false
                            end
                        elseif item.type == "slider" then
                            txt(item.label, rowX, textTop(rowY, ROW_H - 2, 14), Theme.text, 14, FontSystem, 42, false, false, rowW - 170, trans)
                            local sx, sw = rowX + rowW - 150, 104
                            local denom = max(0.0001, (item.max or 100) - (item.min or 0))
                            local frac = clamp(((item.value or 0) - (item.min or 0)) / denom, 0, 1)
                            local hot = over(sx - 6, rowY + 4, sw + 12, 22)
                            local active = (hot or ProjectState.sliderDrag == item) and not disabled
                            rect(sx, rowY + 12, sw, 4, C3(58, 58, 64), 42, 2, trans)
                            if frac > 0 then rect(sx, rowY + 12, sw * frac, 4, Theme.accent, 43, 2, trans) end
                            circle(sx + sw * frac, rowY + 14, 5, active and Theme.accent or Theme.text, 44, true, 0, 32, trans)
                            txt(tostring(item.value) .. tostring(item.suffix or ""), sx + sw + 8, textTop(rowY, ROW_H - 2, 13), Theme.text, 13, FontSystem, 44, false, false, 42, trans)
                            if click and hot and not disabled then
                                ProjectState.sliderDrag = item
                                click = false
                            end
                            if held and not disabled and (ProjectState.sliderDrag == item or hot) then
                                ProjectState.sliderDrag = item
                                local snapped = snapValue((item.min or 0) + denom * clamp((ProjectState.mouseX - sx) / sw, 0, 1), item)
                                if snapped ~= item.value then
                                    item.value = snapped
                                    safeCallback(item.callback, snapped)
                                end
                            end
                        elseif item.type == "dropdown" then
                            txt(item.label, rowX, textTop(rowY, ROW_H - 2, 14), Theme.text, 14, FontSystem, 42, false, false, rowW - 170, trans)
                            local dx, dw = rowX + rowW - 150, 130
                            local controlY = rowY + 3
                            local hovered = over(dx, controlY, dw, CONTROL_H)
                            rect(dx, controlY, dw, CONTROL_H, hovered and C3(55, 55, 62) or C3(42, 42, 48), 42, 4, trans)
                            strokeRect(dx, controlY, dw, CONTROL_H, Theme.border, 43, 4, trans)
                            local display = item.multi and (#item.value > 0 and concat(item.value, ", ") or "-") or (item.value[1] or "-")
                            txt(display, dx + 6, textTop(controlY, CONTROL_H, 13), Theme.text, 13, FontUI, 44, false, false, dw - 24, trans)
                            drawChevronDown(dx + dw - 15, centerY(controlY, CONTROL_H) - 2, Theme.sub, 45)
                        elseif item.type == "button" then
                            local controlY = rowY + 2
                            local hovered = over(rowX, controlY, rowW, CONTROL_H)
                            rect(rowX, controlY, rowW, CONTROL_H, hovered and Theme.accent or C3(42, 42, 48), 42, 6, trans)
                            txt(item.label, rowX + rowW / 2, centerY(controlY, CONTROL_H), Theme.text, 14, FontSystem, 44, true, false, rowW - 16, trans)
                            if click and hovered and not disabled then
                                safeCallback(item.callback)
                                click = false
                            end
                        elseif item.type == "textbox" then
                            txt(item.label, rowX, textTop(rowY, ROW_H - 2, 14), Theme.text, 14, FontSystem, 42, false, false, rowW - 170, trans)
                            local bx, bw = rowX + rowW - 150, 130
                            local controlY = rowY + 3
                            local hovered = over(bx, controlY, bw, CONTROL_H)
                            rect(bx, controlY, bw, CONTROL_H, hovered and C3(55, 55, 62) or C3(42, 42, 48), 42, 4, trans)
                            txt(item.value ~= "" and item.value or item.label, bx + 6, textTop(controlY, CONTROL_H, 13), (item.value ~= "") and Theme.text or Theme.sub, 13, FontUI, 44, false, false, bw - 12, trans)
                            if click and hovered and not disabled then
                                ProjectState.focus = (ProjectState.focus == item) and nil or item
                                click = false
                            end
                        elseif item.type == "divider" then
                            if item.label and item.label ~= "" then
                                local textVal = item.label
                                local textW = textWidth(textVal, 11, FontSystem)
                                local lineW = max(4, (rowW - textW - 16) / 2)
                                local lineY = centerY(rowY, ROW_H)
                                rect(rowX, lineY, lineW, 1, Theme.border, 42, 1)
                                txt(textVal, rowX + lineW + 8, textTop(rowY, ROW_H, 11), Theme.sub, 11, FontSystem, 43, false, false, textW + 4)
                                rect(rowX + lineW + textW + 16, lineY, lineW, 1, Theme.border, 42, 1)
                            else
                                rect(rowX, centerY(rowY, ROW_H), rowW, 1, Theme.border, 42, 1)
                            end
                        end
                    end
                    rowY = rowY + ROW_H
                end
            end
        end
        sy = sy + sectionH
    end
    return click, held, rightClick
end

local function renderWindow(click, held, rightClick)
    local x, y, w, h = ProjectState.x, ProjectState.y, ProjectState.w, ProjectState.h
    for i = 1, #SHADOW_ALPHA do
        rect(x - i*2, y - i*2 + 6, w + i*4, h + i*4, Theme.black, 0, 12, SHADOW_ALPHA[i])
    end
    rect(x, y, w, h, Theme.surface, 5, 12)
    strokeRect(x, y, w, h, Theme.border, 6, 12)
    rect(x + 2, y + 2, w - 4, TITLE_H - 2, Theme.surface2, 7, 10)
    local titleMidY = centerY(y, TITLE_H)
    local closeHot = over(x + w - 30, y + 2, 28, TITLE_H - 4)
    local restoreHot = over(x + w - 60, y + 2, 28, TITLE_H - 4)
    local minHot = over(x + w - 90, y + 2, 28, TITLE_H - 4)
    local by = y + 2
    local bh = TITLE_H - 4
    rect(x + w - 30, by, 28, bh, closeHot and C3(232, 17, 35) or Theme.surface2, 14, 4)
    rect(x + w - 60, by, 28, bh, restoreHot and Theme.surface3 or Theme.surface2, 14, 4)
    rect(x + w - 90, by, 28, bh, minHot and Theme.surface3 or Theme.surface2, 14, 4)
    local cx = x + w - 16
    local cy = titleMidY
    line(cx - 4, cy - 4, cx + 4, cy + 4, closeHot and Theme.white or Theme.text, 15, 1.5)
    line(cx + 4, cy - 4, cx - 4, cy + 4, closeHot and Theme.white or Theme.text, 15, 1.5)
    local rx = x + w - 46
    local ry = titleMidY
    strokeRect(rx - 4, ry - 4, 8, 8, restoreHot and Theme.accent or Theme.text, 15)
    local mx = x + w - 76
    local my = titleMidY
    line(mx - 5, my + 3, mx + 5, my + 3, minHot and Theme.accent or Theme.text, 15, 1.5)
    if click then
        if closeHot then
            setOpen(false)
            click = false
        elseif minHot then
            ProjectState.minimized = true
            ProjectState.h = MINIMIZED_H
            clampWindow()
            click = false
        elseif restoreHot then
            ProjectState.minimized = false
            ProjectState.h = ProjectState.defaultH
            clampWindow()
            click = false
        elseif over(x, y, w, TITLE_H) then
            ProjectState.drag = {ProjectState.mouseX - x, ProjectState.mouseY - y}
            click = false
        end
    end
    if held and ProjectState.drag then
        ProjectState.x = ProjectState.mouseX - ProjectState.drag[1]
        ProjectState.y = ProjectState.mouseY - ProjectState.drag[2]
        clampWindow()
        x, y = ProjectState.x, ProjectState.y
    elseif not held then
        ProjectState.drag = nil
    end
    local titleMaxW = w - 130
    txt(ProjectState.title, x + 14, textTop(y, TITLE_H, 14), Theme.text, 14, FontBold, 16, false, false, titleMaxW)
    if ProjectState.minimized or h <= MINIMIZED_H then return click, held, rightClick end
    local px, py = x + PAD, y + TITLE_H + PAD
    local pw, ph = w - PAD * 2, h - TITLE_H - PAD * 2
    click = renderTabs(click, px, py, pw)
    local contY = py + TAB_H + 8
    local contH = ph - TAB_H - 8
    rect(px, contY, pw, contH, Theme.surface2, 20, 8)
    strokeRect(px, contY, pw, contH, Theme.border, 21, 8)
    click, held, rightClick = renderSections(ProjectState.activeTab, click, held, rightClick, px, contY, pw, contH)
    return click, held, rightClick
end

local function step()
    resetPool()
    ProjectState.tooltipText = nil
    local now = clock()
    local dt = now - (ProjectState.lastFrame or now)
    if dt < 0 then dt = 0.016 end
    ProjectState.lastFrame = now
    ProjectState.dt = dt
    getMouse()
    updateInput()
    if Input[MENU_KEY] and Input[MENU_KEY].click then setOpen(not ProjectState.open) end
    processTextInput()
    processKeybinds()
    runActivities(dt, now)
    if Input.m1.released then
        ProjectState.sliderDrag = nil
        ProjectState.scrollDrag = nil
    end
    if not ProjectState.open or not ProjectState.focusedWindow or #ProjectState.tabs == 0 then
        hideUnused()
        return
    end
    if not ProjectState.hasMouse then
        hideUnused()
        return
    end
    clampWindow()
    local click = Input.m1.click
    local held = Input.m1.held
    local rightClick = Input.m2.click
    renderWindow(click, held, rightClick)
    hideUnused()
end

local RunService = game:GetService("RunService")
local function runStepSafe()
    if not ProjectState.alive then
        if stepConnection then stepConnection:Disconnect(); stepConnection = nil end
        finalDestroy()
        return
    end
    ProjectState.rendering = true
    local ok, err = pcall(step)
    ProjectState.rendering = false
    if not ok then
        warn("UI step error: " .. tostring(err))
        ProjectState.alive = false
        finalDestroy()
    end
end

if RunService and RunService.RenderStepped then
    stepConnection = RunService.RenderStepped:Connect(runStepSafe)
else
    task.spawn(function()
        while ProjectState.alive do
            runStepSafe()
            task.wait(1/240)
        end
    end)
end

_G.UI = UI

-- ==================== BEAR ALPHA V1 FEATURES ====================
local settings = {
    esp = false, noClip = false, hitboxExpand = false, hitboxSize = 10,
    freezeSurvivors = false, bringSurvivors = false, puzzleESP = false,
    autoCheese = false, autoQuidz = false
}

local TEAM_COLORS = {
    Bear = Color3.fromRGB(255, 80, 80), Survivor = Color3.fromRGB(80, 200, 255),
    Neutral = Color3.fromRGB(255, 255, 80), Unknown = Color3.fromRGB(180, 180, 180)
}

local function getPlayerTeamColor(player)
    if player.Team then
        local tn = player.Team.Name
        if tn == "Bear" or tn == "Bears" then
            return TEAM_COLORS.Bear, "BEAR"
        elseif tn == "Survivor" or tn == "Survivors" then
            return TEAM_COLORS.Survivor, "SURV"
        elseif tn == "Neutral" or tn == "Spectator" then
            return TEAM_COLORS.Neutral, "NEUT"
        end
    end
    return TEAM_COLORS.Unknown, "?"
end

-- ==================== SAFE TELEPORT FUNCTION ====================
local function safeTeleport(position)
    local char = LocalPlayer.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    local success = pcall(function()
        local currentPos = hrp.Position
        local offset = position - currentPos
        hrp.CFrame = hrp.CFrame + offset
    end)
    if success then task.wait(0.1) end
    return success
end

-- ==================== AUTO QUIDZ FARM (MATCHA VERSION) ====================
local autoQuidzActive = false
local autoQuidzTask = nil
local quidzPosition = Vector3.new(408.13, 31.94, -26.91) -- Adjust these coordinates as needed

local function teleportToQuidz()
    local char = LocalPlayer.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    
    local success = pcall(function()
        local currentPos = hrp.Position
        local offset = quidzPosition - currentPos
        hrp.CFrame = hrp.CFrame + offset
    end)
    
    if success then
        print("[Auto Quidz] Teleported to Quidz location")
        return true
    end
    return false
end

local function startAutoQuidz()
    if autoQuidzActive then return end
    autoQuidzActive = true
    
    print("[Auto Quidz] Started - Teleporting to Quidz every 9 seconds")
    
    autoQuidzTask = task.spawn(function()
        local quidzCollected = 0
        local level = 1
        local quidzPerLevel = 10
        local quidzIncreaseAmount = 5
        
        while autoQuidzActive do
            -- Teleport to Quidz
            local success = teleportToQuidz()
            
            if success then
                quidzCollected = quidzCollected + quidzIncreaseAmount
                print("[Auto Quidz] Collected! Total: " .. quidzCollected .. " Quidz")
                
                -- Level up check
                if quidzCollected >= level * quidzPerLevel then
                    level = level + 1
                    print("[Auto Quidz] Level up! Now level " .. level)
                end
            end
            
            -- Wait 9 seconds before next collection
            local waitTime = 0
            while waitTime < 9 and autoQuidzActive do
                task.wait(0.5)
                waitTime = waitTime + 0.5
            end
        end
    end)
end

local function stopAutoQuidz()
    autoQuidzActive = false
    if autoQuidzTask then
        autoQuidzTask = nil
    end
    print("[Auto Quidz] Stopped")
end

-- ==================== PUZZLE ESP ====================
local puzzleObjs = {}
local function addPuzzleESP(part, color, label)
    if not part or not settings.puzzleESP then return end
    local pos, on = WorldToScreen(part.Position)
    if not on then return end
    local d = Drawing.new("Square")
    d.Position = Vector2.new(pos.X - 15, pos.Y - 15)
    d.Size = Vector2.new(30, 30)
    d.Color = color
    d.Filled = false
    d.Thickness = 2
    d.Visible = true
    d.ZIndex = 60
    table.insert(puzzleObjs, d)
    if label then
        local t = Drawing.new("Text")
        t.Text = label
        t.Position = Vector2.new(pos.X, pos.Y - 22)
        t.Size = 11
        t.Color = color
        t.Center = true
        t.Outline = true
        t.Visible = true
        t.ZIndex = 61
        table.insert(puzzleObjs, t)
    end
end

local function clearPuzzleESP() 
    for _, d in ipairs(puzzleObjs) do 
        pcall(function() d:Remove() end) 
    end 
    puzzleObjs = {} 
end

local function updatePuzzleESP()
    clearPuzzleESP() 
    if not settings.puzzleESP then return end
    local PuzzleBin = Workspace:FindFirstChild("PuzzleBin") 
    if not PuzzleBin then return end
    
    -- Color Code Puzzle
    local cc = PuzzleBin:FindFirstChild("ColorCode")
    if cc then
        if cc:FindFirstChild("Base") then 
            addPuzzleESP(cc.Base, Color3.fromRGB(0, 255, 255), "Color Code") 
        end
        local cp = cc:FindFirstChild("CodePositions") 
        if cp and cp:FindFirstChild("Clue") then 
            addPuzzleESP(cp.Clue, Color3.fromRGB(0, 255, 255), "Clue") 
        end
        -- Color Puzzle Decor
        local decor = cc:FindFirstChild("Decor")
        if decor and decor:FindFirstChild("Part") then
            addPuzzleESP(decor.Part, Color3.fromRGB(255, 0, 255), "Color Puzzle")
        end
    end
    
    -- Cheese Altar
    local altar = PuzzleBin:FindFirstChild("CheeseAltar")
    if altar then
        if altar:FindFirstChild("Base") then 
            addPuzzleESP(altar.Base, Color3.fromRGB(255, 170, 0), "Cheese Altar") 
        end
        local items = altar:FindFirstChild("Items")
        if items then
            for _, item in ipairs(items:GetChildren()) do
                if item:IsA("BasePart") then 
                    addPuzzleESP(item, Color3.fromRGB(255, 220, 50), "Cheese") 
                end
            end
        end
        if altar:FindFirstChild("RootPart") then 
            addPuzzleESP(altar.RootPart, Color3.fromRGB(255, 255, 0), "Place Cheese") 
        end
    end
    
    -- Wire Puzzle
    for _, child in ipairs(PuzzleBin:GetChildren()) do
        if child:IsA("BasePart") and (child.Name:lower():find("wire") or child.Name:lower():find("part")) then
            addPuzzleESP(child, Color3.fromRGB(255, 0, 0), "Wire")
        end
    end
end

-- ==================== AUTO CHEESE ALTAR ====================
local solvingCheese = false
local function solveCheeseAltar()
    if not settings.autoCheese or solvingCheese then return end
    solvingCheese = true
    
    task.spawn(function()
        local PuzzleBin = Workspace:FindFirstChild("PuzzleBin")
        if not PuzzleBin then solvingCheese = false; return end
        
        local altar = PuzzleBin:FindFirstChild("CheeseAltar")
        if not altar then solvingCheese = false; return end
        
        local rootPart = altar:FindFirstChild("RootPart")
        local items = altar:FindFirstChild("Items")
        if not rootPart or not items then solvingCheese = false; return end
        
        local cheesePiece = nil
        for _, item in ipairs(items:GetChildren()) do
            if item:IsA("BasePart") and item.Name == "Part" then 
                cheesePiece = item
                break 
            end
        end
        if not cheesePiece then solvingCheese = false; return end
        
        local char = LocalPlayer.Character
        if not char then solvingCheese = false; return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then solvingCheese = false; return end
        
        local cheesePos = cheesePiece.Position
        hrp.CFrame = CFrame.new(cheesePos.X, cheesePos.Y + 3, cheesePos.Z)
        task.wait(0.3)
        
        local rootPos = rootPart.Position
        cheesePiece.CFrame = CFrame.new(rootPos.X, rootPos.Y + 1, rootPos.Z)
        task.wait(0.3)
        
        hrp.CFrame = CFrame.new(rootPos.X, rootPos.Y + 3, rootPos.Z)
        task.wait(0.3)
        
        solvingCheese = false
    end)
end

-- ==================== ESP FUNCTIONS ====================
local espDrawings = {}
local function clearESP() 
    for _, d in ipairs(espDrawings) do 
        pcall(function() d:Remove() end) 
    end 
    espDrawings = {} 
end

local function updateESP()
    clearESP() 
    if not settings.esp then return end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local char = plr.Character
            if char then
                local head = char:FindFirstChild("Head")
                local hrp = char:FindFirstChild("HumanoidRootPart")
                local hum = char:FindFirstChild("Humanoid")
                if head and hrp then
                    local hp, ho = WorldToScreen(head.Position)
                    local rp, ro = WorldToScreen(hrp.Position)
                    if ho and ro then
                        local tc, tt = getPlayerTeamColor(plr)
                        local bh = math.abs(hp.Y - rp.Y)
                        local bw = bh * 0.55
                        local bx = rp.X - bw / 2
                        local by = hp.Y - bh * 0.05
                        
                        local box = Drawing.new("Square")
                        box.Position = Vector2.new(bx, by)
                        box.Size = Vector2.new(bw, bh)
                        box.Color = tc
                        box.Filled = false
                        box.Thickness = 2
                        box.Visible = true
                        box.ZIndex = 50
                        table.insert(espDrawings, box)
                        
                        local nm = Drawing.new("Text")
                        nm.Text = "[" .. tt .. "] " .. plr.Name
                        nm.Position = Vector2.new(rp.X, by - 18)
                        nm.Size = 12
                        nm.Color = Color3.fromRGB(255, 255, 255)
                        nm.Center = true
                        nm.Outline = true
                        nm.Visible = true
                        nm.ZIndex = 52
                        table.insert(espDrawings, nm)
                        
                        if hum and hum.MaxHealth > 0 then
                            local hpct = hum.Health / hum.MaxHealth
                            local by2 = by - 8
                            local bg = Drawing.new("Square")
                            bg.Position = Vector2.new(bx, by2)
                            bg.Size = Vector2.new(bw, 3)
                            bg.Color = Color3.fromRGB(40, 40, 40)
                            bg.Filled = true
                            bg.Visible = true
                            bg.ZIndex = 49
                            table.insert(espDrawings, bg)
                            
                            local hc = hpct > 0.5 and Color3.fromRGB(50, 200, 50) or (hpct > 0.25 and Color3.fromRGB(255, 180, 50) or Color3.fromRGB(255, 50, 50))
                            local bf = Drawing.new("Square")
                            bf.Position = Vector2.new(bx, by2)
                            bf.Size = Vector2.new(bw * hpct, 3)
                            bf.Color = hc
                            bf.Filled = true
                            bf.Visible = true
                            bf.ZIndex = 49
                            table.insert(espDrawings, bf)
                        end
                        
                        local mc = LocalPlayer.Character
                        if mc then
                            local mh = mc:FindFirstChild("HumanoidRootPart")
                            if mh then
                                local dist = (mh.Position - hrp.Position).Magnitude
                                local dt = Drawing.new("Text")
                                dt.Text = string.format("%.0f studs", dist)
                                dt.Position = Vector2.new(rp.X, by + bh + 4)
                                dt.Size = 10
                                dt.Color = Color3.fromRGB(200, 200, 200)
                                dt.Center = true
                                dt.Outline = true
                                dt.Visible = true
                                dt.ZIndex = 52
                                table.insert(espDrawings, dt)
                            end
                        end
                    end
                end
            end
        end
    end
end

-- ==================== BEAR FEATURES ====================
local noClipActive = false
local function updateNoClip() 
    if not noClipActive then return end
    local char = LocalPlayer.Character
    if not char then return end
    for _, p in ipairs(char:GetDescendants()) do 
        if p:IsA("BasePart") then 
            pcall(function() p.CanCollide = false end)
        end 
    end 
end

local hitboxExpandActive = false
local function updateHitbox() 
    if not hitboxExpandActive then return end
    for _, plr in ipairs(Players:GetPlayers()) do 
        if plr ~= LocalPlayer then
            local char = plr.Character
            if char then
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if hrp then 
                    pcall(function()
                        hrp.Size = Vector3.new(settings.hitboxSize, settings.hitboxSize, settings.hitboxSize)
                        hrp.Transparency = 0.5
                        hrp.CanCollide = false 
                    end)
                end 
            end
        end
    end 
end

local freezeSurvivorsActive = false
local function updateFreeze() 
    if not freezeSurvivorsActive then return end
    for _, plr in ipairs(Players:GetPlayers()) do 
        if plr.Team and plr.Team.Name == "Survivors" and plr.Character then 
            for _, p in ipairs(plr.Character:GetDescendants()) do 
                if p:IsA("BasePart") then 
                    pcall(function() p.Anchored = true end)
                end 
            end 
        end 
    end 
end

local bringSurvivorsActive = false
local function updateBring() 
    if not bringSurvivorsActive then return end
    local char = LocalPlayer.Character
    if not char then return end
    local torso = char:FindFirstChild("Torso") or char:FindFirstChild("HumanoidRootPart")
    if not torso then return end
    for _, plr in ipairs(Players:GetPlayers()) do 
        if plr.Team and plr.Team.Name == "Survivors" and plr.Character then 
            local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
            if hrp then 
                pcall(function()
                    hrp.CFrame = torso.CFrame + Vector3.new(0, 5, 0) 
                end)
            end 
        end 
    end 
end

-- ==================== BUILD UI ====================
UI:SetTitle("Bear Alpha V1")
UI:SetSize(580, 520)
UI:Center()

local InfoTab = UI:Tab("Info")
local MainTab = UI:Tab("Main")
local BearTab = UI:Tab("Bear")
local SurvivorTab = UI:Tab("Survivor")

InfoTab:Section("Welcome"):Label("Bear Alpha V1 - Matcha")
InfoTab:Section("Player"):Label(LocalPlayer and LocalPlayer.Name or "Unknown")

MainTab:Section("Main Features"):Toggle("Toggle ESP", false, function(s) 
    settings.esp = s 
end)
MainTab:Section("Main Features"):Toggle("NoClip", false, function(s) 
    noClipActive = s
    settings.noClip = s
end)
MainTab:Section("Main Features"):Toggle("Auto Quidz Farm", false, function(s)
    if s then
        startAutoQuidz()
        print("[Auto Quidz] Started!")
    else
        stopAutoQuidz()
        print("[Auto Quidz] Stopped!")
    end
    settings.autoQuidz = s
end)

local bearSec = BearTab:Section("Bear Features")
bearSec:Toggle("Hitbox Expand", false, function(s) 
    hitboxExpandActive = s
    settings.hitboxExpand = s 
end)
bearSec:Slider("Hitbox Size", 10, 1, 3, 30, "", function(v) 
    settings.hitboxSize = v 
end)
bearSec:Toggle("Freeze Survivors", false, function(s) 
    freezeSurvivorsActive = s
    settings.freezeSurvivors = s 
end)
bearSec:Toggle("Bring Survivors", false, function(s) 
    bringSurvivorsActive = s
    settings.bringSurvivors = s 
    if not s then
        print("[Bear Features] Bring Survivors disabled")
    else
        print("[Bear Features] Bring Survivors enabled")
    end
end)

local survSec = SurvivorTab:Section("Survivor Features")
survSec:Toggle("Puzzle ESP", false, function(s) 
    settings.puzzleESP = s 
end)
survSec:Toggle("Auto Cheese Altar", false, function(s) 
    settings.autoCheese = s 
    if s then
        print("[Auto Cheese] Enabled")
    end
end)

-- ==================== MAIN LOOP ====================
task.spawn(function()
    while true do
        pcall(function()
            updateESP()
            updateNoClip()
            updateHitbox()
            updateFreeze()
            updateBring()
            
            if settings.puzzleESP then 
                updatePuzzleESP() 
            else 
                clearPuzzleESP() 
            end
            
            if settings.autoCheese then 
                solveCheeseAltar() 
            end
            
            -- Auto Quidz is handled by its own task
        end)
        task.wait(0.1)
    end
end)

print("Bear Alpha V1 Loaded")