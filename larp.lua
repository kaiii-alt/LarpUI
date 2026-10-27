if _G.LarpCleanup then
    pcall(_G.LarpCleanup)
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Cam = workspace.CurrentCamera
local Mouse = Players.LocalPlayer:GetMouse()

local Font = Drawing.Fonts.System
local BoldFont = Drawing.Fonts.SystemBold

local Theme = {
    Background = Color3.fromRGB(24, 24, 24),
    Glow = Color3.fromRGB(0, 0, 0),
    Accent = Color3.fromRGB(10, 10, 10),
    LightContrast = Color3.fromRGB(20, 20, 20),
    DarkContrast = Color3.fromRGB(14, 14, 14),
    TextColor = Color3.fromRGB(255, 255, 255),
}

local State = { active = nil, focus = nil, listen = nil, focusHit = false }
local Input = {x = 0, y = 0, down = false, click = false}
local Pools = { Square = {}, Text = {}, Circle = {} }
local Used = {Square = 0, Text = 0, Circle = 0}
local Notes = {}
local PrevDown = {}
local FrameDown = {}
local Hold = {}
local Depth = 0
local Alpha = 1
local PanelA = 1
local Icons = {}
local FrameNo = 0
local Clip0 = nil
local Clip1 = nil
local Current = nil
local Conn = nil
local Blocked = false
local Debug = false

local function mix(a, b, t)
    return Color3.new(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t)
end

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then
        return hi
    end
    return v
end

local function approach(a, b, step)
    if a < b then return math.min(a + step, b) end
    return math.max(a - step, b)
end

local function call(fn, ...)
    if fn then
        local ok, err = pcall(fn, ...)
        if not ok and Debug then warn(tostring(err)) end
    end
end

local function dim()
    return mix(Theme.Background, Theme.TextColor, 0.6)
end

local function tw(s, size)
    return #s * size * 0.5
end

local function ty(y, h, size)
    return math.floor(y + (h - size) / 2 + 0.5)
end

local function fit(s, size, room)
    local n = math.floor(room / (size * 0.5))
    if #s <= n then return s end
    if n <= 2 then return "" end
    return string.sub(s, 1, n - 2) .. ".."
end

local Keys = {}
local NameVK = {}
local ScanList = {}

local function addKey(vk, enumName, label)
    Keys[vk] = { enum = enumName, label = label or enumName }
    NameVK[enumName] = vk
    ScanList[#ScanList + 1] = vk
end

local DigitNames = {"Zero", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine"}

for i = 0, 25 do
    addKey(0x41 + i, string.char(65 + i))
end

for i = 0, 9 do
    addKey(0x30 + i, DigitNames[i + 1], tostring(i))
end

for i = 1, 12 do
    addKey(0x6F + i, "F" .. i)
end

local Extra = {
    { 0x20, "Space", "Space" },
    {0x0D, "Return", "Enter"},
    { 0x09, "Tab", "Tab" },
    {0x08, "Backspace", "Backspace"},
    { 0xA0, "LeftShift", "LShift" },
    {0xA1, "RightShift", "RShift"},
    { 0xA2, "LeftControl", "LCtrl" },
    {0xA3, "RightControl", "RCtrl"},
    { 0xA4, "LeftAlt", "LAlt" },
    {0xA5, "RightAlt", "RAlt"},
    { 0x26, "Up", "Up" },
    {0x28, "Down", "Down"},
    { 0x25, "Left", "Left" },
    {0x27, "Right", "Right"},
    { 0x2D, "Insert", "Insert" },
    {0x2E, "Delete", "Delete"},
    { 0x24, "Home", "Home" },
    {0x23, "End", "End"},
    { 0x21, "PageUp", "PageUp" },
    {0x22, "PageDown", "PageDown"},
    { 0xBD, "Minus", "-" },
    {0xBB, "Equals", "="},
    { 0xBC, "Comma", "," },
    {0xBE, "Period", "."},
    { 0xBF, "Slash", "/" },
    {0xBA, "Semicolon", ";"},
    { 0xDE, "Quote", "'" },
    {0xDB, "LeftBracket", "["},
    { 0xDD, "RightBracket", "]" },
    {0xDC, "BackSlash", "\\"},
    { 0xC0, "Backquote", "`" },
}

for _, k in ipairs(Extra) do
    addKey(k[1], k[2], k[3])
end

local TypeKeys = {}

for i = 0, 25 do
    TypeKeys[0x41 + i] = { string.lower(string.char(65 + i)), string.char(65 + i) }
end

local Shifted = {")", "!", "@", "#", "$", "%", "^", "&", "*", "("}

for i = 0, 9 do
    TypeKeys[0x30 + i] = { tostring(i), Shifted[i + 1] }
end

TypeKeys[0x20] = {" ", " "}
TypeKeys[0xBA] = { ";", ":" }
TypeKeys[0xBB] = {"=", "+"}
TypeKeys[0xBC] = { ",", "<" }
TypeKeys[0xBD] = {"-", "_"}
TypeKeys[0xBE] = { ".", ">" }
TypeKeys[0xBF] = {"/", "?"}
TypeKeys[0xC0] = { "`", "~" }
TypeKeys[0xDB] = {"[", "{"}
TypeKeys[0xDC] = { "\\", "|" }
TypeKeys[0xDD] = {"]", "}"}
TypeKeys[0xDE] = { "'", "\"" }

local function toVK(key)
    if key == nil then return nil end
    if type(key) == "number" then return key end

    if type(key) == "string" then
        return NameVK[key]
    end

    local ok, name = pcall(function()
        return key.Name
    end)

    if ok and type(name) == "string" then return NameVK[name] end
    return NameVK[string.match(tostring(key), "([%w_]+)$") or ""]
end

local function keyValue(vk)
    if not vk then return nil end

    local name = Keys[vk] and Keys[vk].enum or tostring(vk)
    local ok, value = pcall(function()
        return Enum.KeyCode[name]
    end)
    if ok and value then return value end
    return name
end

local function down(vk)
    local v = FrameDown[vk]
    if v == nil then
        v = iskeypressed(vk) == true
        FrameDown[vk] = v
    end
    return v
end

local function edge(vk)
    return down(vk) and not PrevDown[vk]
end

local function take(kind)
    local n = Used[kind] + 1
    Used[kind] = n
    local e = Pools[kind][n]
    if not e then
        local o = Drawing.new(kind)
        if kind == "Circle" then
            o.NumSides = 32
            o.Filled = true
        elseif kind == "Square" then
            o.Filled = true
        else
            o.Outline = false
            o.Center = false
        end

        e = { o = o, c = {} }
        Pools[kind][n] = e
    end

    Depth = Depth + 1
    return e
end

local function put(e, key, value)
    if e.c[key] ~= value then
        e.c[key] = value
        e.o[key] = value
    end
end

local function place(e, x, y)
    if e.c.px ~= x or e.c.py ~= y then
        e.c.px = x
        e.c.py = y
        e.o.Position = Vector2.new(x, y)
    end
end

local function rect(x, y, w, h, color, radius, alpha)
    if w <= 0 or h <= 0 then return end
    radius = radius or 0
    if Clip0 then
        if y + h <= Clip0 or y >= Clip1 then return end

        if y < Clip0 or y + h > Clip1 then
            local top = math.max(y, Clip0)
            local bottom = math.min(y + h, Clip1)

            y = top
            h = bottom - top
            radius = 0
        end
    end
    radius = math.min(radius, w / 2, h / 2)

    local e = take("Square")
    put(e, "Color", color)
    put(e, "Transparency", (alpha or 1) * Alpha)
    put(e, "Corner", radius)
    put(e, "ZIndex", Depth)
    place(e, x, y)

    if e.c.sw ~= w or e.c.sh ~= h then
        e.c.sw = w
        e.c.sh = h
        e.o.Size = Vector2.new(w, h)
    end
    put(e, "Visible", true)
end

local function text(str, x, y, color, size, alpha, bold)
    if str == "" then
        return
    end
    if Clip0 and (y < Clip0 or y + size + 2 > Clip1) then return end

    local e = take("Text")
    put(e, "Text", str)
    put(e, "Color", color)
    put(e, "Size", size)
    put(e, "Font", bold and BoldFont or Font)
    put(e, "Transparency", (alpha or 0.9) * Alpha)
    put(e, "ZIndex", Depth)
    place(e, x, y)
    put(e, "Visible", true)
end

local function circle(cx, cy, r, color, alpha)
    if Clip0 and (cy - r < Clip0 or cy + r > Clip1) then
        return
    end
    local e = take("Circle")
    put(e, "Color", color)
    put(e, "Transparency", (alpha or 1) * Alpha)
    put(e, "Radius", r)
    put(e, "ZIndex", Depth)
    place(e, cx, cy)
    put(e, "Visible", true)
end

local function sweep()
    for kind, list in pairs(Pools) do
        for i = Used[kind] + 1, #list do
            local e = list[i]

            if e.c.Visible ~= false then
                e.c.Visible = false
                e.o.Visible = false
            end
        end
        Used[kind] = 0
    end
    for _, pg in ipairs(Icons) do
        if pg.icon and pg.iconSeen ~= FrameNo and pg.iconHidden ~= FrameNo then pg.icon.Visible = false end
    end
    Depth = 0
end

local function inside(x, y, w, h)
    local mx = Input.x
    local my = Input.y

    if mx < x or mx > x + w or my < y or my > y + h then return false end
    if Clip0 and (my < Clip0 or my > Clip1) then
        return false
    end
    return true
end

local function ease(p)
    return 1 - (1 - p) * (1 - p)
end

local function decay(it, dt)
    it.pop = math.max(0, (it.pop or 0) - dt)
    it.fpop = math.max(0, (it.fpop or 0) - dt)
    it.cpop = math.max(0, (it.cpop or 0) - dt)
end

local function inset(t, amount)
    local p = (t or 0) / 0.2
    return amount * p * p
end

local function rowBg(x, y, w, h, hot, boost, pad)
    local i = pad or 0

    rect(x + i, y + i, w - 2 * i, h - 2 * i, mix(Theme.DarkContrast, Theme.TextColor, (hot and 0.04 or 0) + (boost or 0)), 2, PanelA)
end

local function hsv(h, s, v)
    local i = math.floor(h * 6)
    local f = h * 6 - i
    local p = v * (1 - s)
    local q = v * (1 - f * s)
    local t = v * (1 - (1 - f) * s)
    i = i % 6

    if i == 0 then
        return Color3.new(v, t, p)
    elseif i == 1 then
        return Color3.new(q, v, p)
    elseif i == 2 then
        return Color3.new(p, v, t)
    elseif i == 3 then
        return Color3.new(p, q, v)
    elseif i == 4 then
        return Color3.new(t, p, v)
    end

    return Color3.new(v, p, q)
end

local function toHsv(c)
    local r = c.R
    local g = c.G
    local b = c.B
    local mx = math.max(r, g, b)
    local mn = math.min(r, g, b)
    local d = mx - mn
    local h = 0

    if d > 0 then
        if mx == r then
            h = ((g - b) / d) % 6
        elseif mx == g then
            h = (b - r) / d + 2
        else
            h = (r - g) / d + 4
        end
        h = h / 6
    end

    return h, mx == 0 and 0 or d / mx, mx
end

local function matches(it)
    local out = {}
    local q = string.lower(it.buf or "")
    for _, v in ipairs(it.list) do
        if q == "" or string.find(string.lower(v), q, 1, true) then out[#out + 1] = v end
    end
    return out
end

local function commit(it)
    State.focus = nil
    if it.kind == "slider" then
        if not tonumber(it.buf or "") then
            it.value = it.default
            call(it.cb, it.value, it.up)
        end
        it.buf = nil
        return
    end
    if it.kind == "dropdown" then
        it.buf = nil
        it.open = false
        return
    end
    if it.kind == "rgbbox" then
        it.buf = nil
        return
    end
    call(it.cb, it.value, true, it.up)
end

local function dropExtra(it)
    local n = math.min(#matches(it), 3)

    if n == 0 then
        return 0
    end

    return n * 34 + 8
end

local function heightOf(it)
    local k = it.kind
    if k == "slider" then return 50 end

    if k == "dropdown" then return 30 + dropExtra(it) * ease(it.op or 0) end
    return 30
end

local function openPicker(it, sx, sy)
    local vp = Cam.ViewportSize
    local h, s, v = toHsv(it.color)
    local px = sx + 50
    if px + 162 > vp.X then px = sx - 172 end

    local p = {
        it = it,
        open = true,
        anim = 0,
        hue = h,
        sat = s,
        val = v,
        last = it.color,
        x = clamp(px, 0, vp.X - 162),
        y = clamp(sy, 0, vp.Y - 169),
        boxes = {
            {kind = "rgbbox", ch = 1},
            { kind = "rgbbox", ch = 2 },
            {kind = "rgbbox", ch = 3},
        },
    }
    for _, b in ipairs(p.boxes) do
        b.picker = p
    end
    p.lh = h
    p.ls = s
    p.lv = v
    State.picker = p
end

local function closePicker(revert)
    local p = State.picker
    if not p or not p.open then return end
    p.open = false
    local f = State.focus
    if f and f.picker == p then
        f.buf = nil
        State.focus = nil
    end
    if revert then
        p.it.color = p.last
        call(p.it.cb, p.last, p.it.up)
    end
end

local function pushColor(p)
    if p.hue == p.lh and p.sat == p.ls and p.val == p.lv then
        return
    end
    p.lh = p.hue
    p.ls = p.sat
    p.lv = p.val
    local c = hsv(p.hue, p.sat, p.val)
    p.it.color = c
    call(p.it.cb, c, p.it.up)
end

local Draw = {}

Draw.toggle = function(it, x, y, w, dt)
    local T = Theme

    decay(it, dt)
    local hot = inside(x, y, w, 30) and not State.active

    if hot and Input.click then
        it.value = not it.value
        it.sq = 0.2
        call(it.cb, it.value, it.up)
    end
    it.t = approach(it.t or (it.value and 1 or 0), it.value and 1 or 0, dt / 0.2)
    it.sq = math.max(0, (it.sq or 0) - dt)
    local age = 0.2 - it.sq
    local s = 0

    if it.sq > 0 then
        if age < 0.1 then
            s = age / 0.1 * 0.6
        else
            s = 0.6 * (1 - (age - 0.1) / 0.1)
        end
    end

    rowBg(x, y, w, 30, hot)
    text(it.title, x + 10, ty(y, 30, 12), T.TextColor, 12)
    local sx = x + w - 50
    rect(sx, y + 7, 40, 16, T.LightContrast, 2)
    rect(sx + 2 + 18 * ease(it.t), y + 9 + 2.5 * s, 18, 12 - 5 * s, T.TextColor, 2)
end

Draw.button = function(it, x, y, w, dt)
    local T = Theme

    decay(it, dt)
    local hot = inside(x, y, w, 30) and not State.active

    if hot and Input.click then
        it.pop = 0.2
        call(it.cb, it.up)
    end
    it.hv = approach(it.hv or 0, hot and 1 or 0, dt / 0.2)
    rowBg(x, y, w, 30, hot, 0, inset(it.pop, 5))
    local size = 12 + 2 * it.hv
    text(it.title, x + (w - tw(it.title, size)) / 2, ty(y, 30, size), T.TextColor, size)
end

Draw.textbox = function(it, x, y, w, dt)
    local T = Theme
    decay(it, dt)
    local hot = inside(x, y, w, 30) and not State.active
    local focused = State.focus == it
    if hot and Input.click then
        if State.focus and State.focus ~= it then commit(State.focus) end
        State.focus = it
        focused = true
        State.focusHit = true
    end
    it.fw = approach(it.fw or 100, focused and 200 or 100, dt * 500)

    local fw = it.fw
    local fx = x + w - 10 - fw
    local fy = y + 7
    local pad = inset(it.fpop, 3)
    rowBg(x, y, w, 30, hot)
    text(it.title, x + 10, ty(y, 30, 12), T.TextColor, 12)
    rect(fx + pad, fy + pad, fw - 2 * pad, 16 - 2 * pad, T.LightContrast, 2)
    local n = math.floor((fw - 10) / 6)
    local shown = it.value

    if focused then
        if #shown > n - 1 then shown = string.sub(shown, #shown - n + 2) end
        if math.floor(tick() * 2) % 2 == 0 then shown = shown .. "|" end
    elseif #shown > n then
        shown = string.sub(shown, 1, n - 2) .. ".."
    end

    text(shown, fx + 5, ty(fy, 16, 12), T.TextColor, 12)
end

Draw.keybind = function(it, x, y, w, dt)
    local T = Theme
    decay(it, dt)

    local hot = inside(x, y, w, 30) and not State.active
    rowBg(x, y, w, 30, hot)
    text(it.title, x + 10, ty(y, 30, 12), T.TextColor, 12)
    local listening = State.listen == it
    local label = listening and "..." or (it.vk and (Keys[it.vk] and Keys[it.vk].label or "?") or "None")
    local cx = x + w - 110
    local chot = inside(cx, y + 7, 100, 16) and not State.active
    if chot and Input.click then
        if State.focus then commit(State.focus) end
        State.listen = it
        label = "..."
    end
    local pad = inset(it.cpop, 3)
    rect(cx + pad, y + 7 + pad, 100 - 2 * pad, 16 - 2 * pad, T.LightContrast, 2)
    text(label, cx + (100 - tw(label, 12)) / 2, ty(y + 7, 16, 12), T.TextColor, 12, 1, true)
end

Draw.slider = function(it, x, y, w, dt)
    local T = Theme
    decay(it, dt)

    local row = inside(x, y, w, 50) and not State.active
    local onBox = inside(x + w - 60, y + 4, 56, 20)
    local focused = State.focus == it
    local tx = x + 10
    local trackW = w - 20
    if Input.click and not State.active and row then
        if onBox then
            if State.focus and State.focus ~= it then commit(State.focus) end
            it.buf = tostring(it.value)
            State.focus = it
            focused = true
            State.focusHit = true
        else
            State.active = { kind = "slider", it = it, tx = tx, tw = trackW }
        end
    end
    rowBg(x, y, w, 50, row, 0, inset(it.pop, 5))
    text(it.title, x + 10, y + 8, T.TextColor, 12)
    local shown = focused and (it.buf or "") or tostring(it.value)

    if focused and math.floor(tick() * 2) % 2 == 0 then shown = shown .. "|" end
    text(shown, x + w - 10 - tw(shown, 12), y + 8, T.TextColor, 12, 1, true)

    local span = it.max - it.min
    local f = span == 0 and 0 or clamp((it.value - it.min) / span, 0, 1)
    local cur = it.f or f

    it.f = cur + (f - cur) * math.min(1, dt * 18)
    local dragging = State.active and State.active.it == it

    if dragging then
        it.ca = approach(it.ca or 0, 1, dt / 0.1)
        it.hold = 0.5
    elseif (it.hold or 0) > 0 then
        it.hold = it.hold - dt
    else
        it.ca = approach(it.ca or 0, 0, dt / 0.2)
    end
    rect(tx, y + 34, trackW, 4, T.LightContrast, 2)
    rect(tx, y + 34, trackW * it.f, 4, T.TextColor, 2)

    if (it.ca or 0) > 0.02 then
        circle(tx + trackW * it.f, y + 36, 5, T.TextColor, it.ca)
    end
end

Draw.dropdown = function(it, x, y, w, dt)
    local T = Theme

    decay(it, dt)
    local extra = dropExtra(it)
    local hot = inside(x, y, w, 30) and not State.active
    local focused = State.focus == it
    if hot and Input.click then
        if it.open then
            it.open = false
            if focused then
                State.focus = nil
                it.buf = nil
                focused = false
            end
        else
            if State.focus and State.focus ~= it then
                commit(State.focus)
            end

            it.open = true
            it.buf = ""
            it.off = 0
            State.focus = it
            State.focusHit = true
            focused = true
        end
    end
    it.op = approach(it.op or 0, it.open and 1 or 0, dt / 0.3)
    local m = matches(it)
    if it.open and inside(x, y, w, 30 + extra) then
        State.dropNow = true

        if edge(0x28) then
            it.off = (it.off or 0) + 1
        elseif edge(0x26) then
            it.off = (it.off or 0) - 1
        end
    end
    it.off = clamp(it.off or 0, 0, math.max(0, #m - 3))
    rowBg(x, y, w, 30, hot, 0, inset(it.pop, 5))
    local head = it.selected or it.title
    local headAlpha = 0.9
    if focused then
        head = (it.buf or "") .. (math.floor(tick() * 2) % 2 == 0 and "|" or "")
        if head == "" then
            head = it.title
            headAlpha = 0.4
        end
    end
    text(fit(head, 12, w - 50), x + 10, ty(y, 30, 12), T.TextColor, 12, headAlpha)
    text(it.op > 0.5 and "^" or "v", x + w - 18, ty(y, 30, 12), T.TextColor, 12)
    if it.op > 0 and extra > 0 then
        local oc1 = Clip1
        local n = math.min(#m, 3)
        local ly0 = y + 34
        Clip1 = math.min(oc1, y + 30 + extra * ease(it.op))
        rect(x, ly0, w, n * 34 + 4, T.Background, 4)
        for i = 1, n do
            local v = m[it.off + i]
            local ly = ly0 + 4 + (i - 1) * 34
            local lhot = it.op > 0.6 and inside(x + 4, ly, w - 8, 30) and not State.active
            local chosen = it.selected == v
            rect(x + 4, ly, w - 8, 30, mix(T.DarkContrast, T.TextColor, lhot and 0.1 or (chosen and 0.05 or 0)), 2)
            text(fit(v, 12, w - 40), x + 14, ty(ly, 30, 12), T.TextColor, 12, chosen and 1 or 0.7)

            if lhot and Input.click then
                Input.click = false
                it.selected = v
                it.open = false
                it.buf = nil
                it.pop = 0.2
                if State.focus == it then State.focus = nil end
                call(it.cb, v, it.up)
            end
        end
        Clip1 = oc1
    end
end

Draw.color = function(it, x, y, w, dt)
    local T = Theme

    decay(it, dt)
    local hot = inside(x, y, w, 30) and not State.active
    local sx = x + w - 50
    if hot and Input.click then
        it.cpop = 0.2

        local p = State.picker
        if p and p.open and p.it == it then
            closePicker(false)
        else
            if p then
                closePicker(false)
            end
            openPicker(it, sx, y)
        end
    end
    it.sc = it.sc and mix(it.sc, it.color, math.min(1, dt * 5)) or it.color
    rowBg(x, y, w, 30, hot)
    text(it.title, x + 10, ty(y, 30, 12), T.TextColor, 12)
    local pad = inset(it.cpop, 3)

    rect(sx + pad, y + 7 + pad, 40 - 2 * pad, 16 - 2 * pad, it.sc, 2)
end

local function applyActive()
    local a = State.active
    if not a then
        return
    end
    if not Input.down then
        State.active = nil
        return
    end
    if a.kind == "slider" then
        local it = a.it
        local f = clamp((Input.x - a.tx) / a.tw, 0, 1)
        local v = math.floor(it.min + (it.max - it.min) * f)

        if v ~= it.value then
            it.value = v
            it.pop = 0.2
            call(it.cb, v, it.up)
        end
    elseif a.kind == "resize" then
        Current.w = clamp(a.w0 + Input.x - a.mx, 400, 1000)
        Current.h = clamp(a.h0 + Input.y - a.my, 300, 800)
    elseif a.kind == "bgop" then
        Current.bgOp = math.floor(clamp((Input.x - a.x) / a.w, 0, 1) * 100 + 0.5)
    elseif a.kind == "sv" then
        a.p.sat = clamp((Input.x - a.x) / a.w, 0, 1)
        a.p.val = 1 - clamp((Input.y - a.y) / a.h, 0, 1)
        pushColor(a.p)
    elseif a.kind == "hue" then
        a.p.hue = clamp((Input.x - a.x) / a.w, 0, 0.999)
        pushColor(a.p)
    end
end

local function wrap(s, n)
    local lines = {}
    local line = ""
    for word in string.gmatch(s, "%S+") do
        if line ~= "" and #line + #word + 1 > n then
            lines[#lines + 1] = line
            line = word
        elseif line == "" then
            line = word
        else
            line = line .. " " .. word
        end
    end
    if line ~= "" then lines[#lines + 1] = line end
    while #lines > 4 do
        table.remove(lines)
    end
    return lines
end

local function updateNotes(dt)
    local vp = Cam.ViewportSize
    local cur = vp.Y - 10
    local i = 1
    while i <= #Notes do
        local n = Notes[i]
        n.t = n.t + dt

        if n.closing then
            n.ct = n.ct + dt
        elseif not n.cb and n.t > 5 then
            n.closing = true
            n.ct = 0
        end
        if n.closing and n.ct >= 0.4 then
            table.remove(Notes, i)
        else
            local grow = ease(clamp(n.t / 0.2, 0, 1))
            local shrink = n.closing and ease(clamp((n.ct - 0.2) / 0.2, 0, 1)) or 0
            n.bw = n.w * grow * (1 - shrink)
            n.bx = 10 + n.w * shrink
            n.y = cur - n.h
            cur = n.y - 8
            if n.cb and not n.closing and n.t >= 0.4 and Input.click then
                local by = n.y + n.h - 30
                local cancelX = n.bx + n.w - 12 - 64
                local acceptX = cancelX - 8 - 64
                if inside(acceptX, by, 64, 22) then
                    n.closing = true
                    n.ct = 0
                    Input.click = false
                    call(n.cb, true)
                elseif inside(cancelX, by, 64, 22) then
                    n.closing = true
                    n.ct = 0
                    Input.click = false
                    call(n.cb, false)
                end
            end

            i = i + 1
        end
    end
end

local function drawNotes()
    local T = Theme

    for _, n in ipairs(Notes) do
        if n.bw > 1 then
            for i = 1, 8 do
                rect(n.bx - i, n.y - i, n.bw + 2 * i, n.h + 2 * i, T.Glow, 4 + i, 0.022)
            end
            rect(n.bx, n.y, n.bw, n.h, T.Background, 4)

            if n.t >= 0.2 and (not n.closing or n.ct < 0.2) then
                text(fit(n.title, 14, n.w - 28), n.bx + 12, n.y + 10, T.TextColor, 14, 1, true)
                for i, line in ipairs(n.lines) do
                    text(line, n.bx + 12, n.y + 30 + (i - 1) * 14, dim(), 12)
                end
                if n.cb and n.t >= 0.4 then
                    local by = n.y + n.h - 30
                    local cancelX = n.bx + n.w - 12 - 64
                    local acceptX = cancelX - 8 - 64
                    local ha = inside(acceptX, by, 64, 22)
                    local hc = inside(cancelX, by, 64, 22)
                    rect(acceptX, by, 64, 22, mix(T.DarkContrast, T.TextColor, ha and 0.2 or 0.1), 2)
                    text("Accept", acceptX + (64 - tw("Accept", 12)) / 2, ty(by, 22, 12), T.TextColor, 12)
                    rect(cancelX, by, 64, 22, mix(T.DarkContrast, T.TextColor, hc and 0.2 or 0.1), 2)
                    text("Cancel", cancelX + (64 - tw("Cancel", 12)) / 2, ty(by, 22, 12), T.TextColor, 12)
                end
            end
            local fx = n.bx
            local fw = 0

            if n.t < 0.2 then
                fw = n.bw
            elseif n.t < 0.4 then
                fw = n.bw * (1 - ease((n.t - 0.2) / 0.2))
                fx = n.bx + n.bw - fw
            end
            if n.closing then
                fx = n.bx
                fw = n.ct < 0.2 and n.bw * ease(n.ct / 0.2) or n.bw
            end

            if fw > 0.5 then
                rect(fx, n.y, fw, n.h, T.TextColor, 4)
            end
        end
    end
end

local function updatePicker(dt)
    local p = State.picker
    if not p then return end

    p.anim = approach(p.anim, p.open and 1 or 0, dt / 0.2)
    if not p.open and p.anim <= 0 then
        State.picker = nil
        return
    end
    if not (Input.click and p.open and p.anim >= 0.98) then
        return
    end
    local x = p.x
    local y = p.y
    if not inside(x, y, 162, 169) then return end

    Input.click = false
    if State.focus and State.focus.picker ~= p then commit(State.focus) end

    if inside(x + 162 - 26, y + 6, 20, 20) then
        closePicker(true)
    elseif inside(x + 8, y + 32, 146, 60) then
        State.active = {kind = "sv", p = p, x = x + 8, y = y + 32, w = 146, h = 60}
    elseif inside(x + 8, y + 96, 146, 16) then
        State.active = {kind = "hue", p = p, x = x + 8, y = y + 96, w = 146}
    elseif inside(x + 8, y + 140, 146, 20) then
        p.it.cpop = 0.2
        closePicker(false)
    else
        for i, b in ipairs(p.boxes) do
            if inside(x + 8 + (i - 1) * 50, y + 118, 46, 16) then
                local c = p.it.color
                local v = math.floor((i == 1 and c.R or (i == 2 and c.G or c.B)) * 255 + 0.5)
                if State.focus and State.focus ~= b then commit(State.focus) end
                b.buf = tostring(v)
                State.focus = b
                State.focusHit = true
            end
        end
    end
end

local function drawPicker(dt)
    local p = State.picker

    if not p then return end
    local T = Theme
    local e = ease(p.anim)
    local x = p.x
    local y = p.y
    local w = 162 * e
    local h = 169 * e
    for i = 1, 8 do
        rect(x - i, y - i, w + 2 * i, h + 2 * i, T.Glow, 4 + i, 0.022 * e)
    end

    rect(x, y, w, h, T.Background, 4)
    if p.anim < 0.98 then
        return
    end
    text(p.it.title, x + 10, y + 9, T.TextColor, 14, 1, true)
    text("x", x + 162 - 22, y + 8, T.TextColor, 14, inside(x + 162 - 26, y + 6, 20, 20) and 1 or 0.6)
    local cx = math.floor(x + 8 + 0.5)
    local cy = math.floor(y + 32 + 0.5)
    local hy = math.floor(y + 96 + 0.5)
    local base = hsv(p.hue, 1, 1)
    local white = Color3.new(1, 1, 1)
    local black = Color3.new(0, 0, 0)

    for i = 0, 145 do
        rect(cx + i, cy, 1, 60, mix(white, base, (i + 0.5) / 146), 0)
    end

    for j = 1, 59 do
        rect(cx, cy + j, 146, 1, black, 0, j / 59)
    end

    local kx = cx + p.sat * 146
    local ky = cy + (1 - p.val) * 60
    circle(kx, ky, 5, T.TextColor)
    circle(kx, ky, 3.5, p.it.color)
    for i = 0, 145 do
        rect(cx + i, hy, 1, 16, hsv((i + 0.5) / 146, 1, 1), 0)
    end
    rect(cx + p.hue * 146 - 1, hy, 2, 16, T.TextColor, 0)

    local c = p.it.color
    local labels = { "R:", "G:", "B:" }
    local vals = {c.R, c.G, c.B}

    for i, b in ipairs(p.boxes) do
        local bx = x + 8 + (i - 1) * 50
        local focused = State.focus == b
        local shown = focused and (b.buf or "") or tostring(math.floor(vals[i] * 255 + 0.5))
        if focused and math.floor(tick() * 2) % 2 == 0 then shown = shown .. "|" end
        rect(bx, y + 118, 46, 16, T.DarkContrast, 2)
        text(labels[i], bx + 5, ty(y + 118, 16, 10), dim(), 10)
        text(shown, bx + 20, ty(y + 118, 16, 10), T.TextColor, 10)
    end

    local sh = inside(x + 8, y + 140, 146, 20)
    rect(x + 8, y + 140, 146, 20, mix(T.DarkContrast, T.TextColor, sh and 0.08 or 0), 2)
    text("Submit", x + 8 + (146 - tw("Submit", 11)) / 2, ty(y + 140, 20, 11), T.TextColor, 11)
end

local function panelRows(lib)
    local n = #lib.images
    if n == 0 then return 0 end
    return math.min(4, math.ceil((n + 1) / 2))
end

local function togglePanel()
    local p = State.panel
    if p and p.open then
        p.open = false
    else
        State.panel = { open = true, anim = 0, off = 0, x = 0, y = 0, h = 100 }
    end
end

local function updatePanel(lib, dt)
    local p = State.panel
    if not p then return end
    p.anim = approach(p.anim, p.open and 1 or 0, dt / 0.2)
    if not p.open and p.anim <= 0 then
        State.panel = nil
        return
    end
    local vp = Cam.ViewportSize
    local rows = panelRows(lib)
    p.h = rows == 0 and 100 or 86 + rows * 26
    local px = lib.x + lib.w + 10
    if px + 162 > vp.X then px = lib.x - 172 end
    p.x = clamp(px, 0, vp.X - 162)
    p.y = clamp(lib.y, 0, vp.Y - p.h)
    if not p.open or p.anim < 0.98 then return end
    local x, y = p.x, p.y
    if not inside(x, y, 162, p.h) then return end
    State.dropNow = true
    local total = math.ceil((#lib.images + 1) / 2)
    if edge(0x28) then p.off = p.off + 1 elseif edge(0x26) then p.off = p.off - 1 end
    p.off = clamp(p.off, 0, math.max(0, total - rows))
    if not Input.click then return end
    Input.click = false
    if State.focus then commit(State.focus) end
    if inside(x + 162 - 26, y + 6, 20, 20) then
        p.open = false
        return
    end
    if rows == 0 then return end
    for r = 0, rows - 1 do
        for c = 0, 1 do
            local e = (p.off + r) * 2 + c + 1
            if e <= #lib.images + 1 and inside(x + 8 + c * 76, y + 32 + r * 26, 70, 22) then
                if e == 1 then lib:setBackground(nil) else lib:setBackground(e - 1) end
            end
        end
    end
    local sy = y + 32 + rows * 26 + 6
    if inside(x + 2, sy + 18, 158, 22) then
        State.active = { kind = "bgop", x = x + 8, w = 146 }
    end
end

local function drawPanel(lib)
    local p = State.panel
    if not p then return end
    local T = Theme
    local e = ease(p.anim)
    local x, y = p.x, p.y
    local w, h = 162 * e, p.h * e
    for i = 1, 8 do
        rect(x - i, y - i, w + 2 * i, h + 2 * i, T.Glow, 4 + i, 0.022 * e)
    end
    rect(x, y, w, h, T.Background, 4)
    if p.anim < 0.98 then return end
    text("feet panel", x + 10, y + 9, T.TextColor, 14, 1, true)
    text("x", x + 162 - 22, y + 8, T.TextColor, 14, inside(x + 162 - 26, y + 6, 20, 20) and 1 or 0.6)
    local rows = panelRows(lib)
    if rows == 0 then
        text("no images added", x + 10, y + 40, dim(), 12)
        text("paste Base64 into", x + 10, y + 56, dim(), 12)
        text("ADD_IMAGES_HERE", x + 10, y + 70, dim(), 12)
        return
    end
    for r = 0, rows - 1 do
        for c = 0, 1 do
            local k = (p.off + r) * 2 + c + 1
            if k <= #lib.images + 1 then
                local name = k == 1 and "off" or lib.images[k - 1].name
                local bx, by = x + 8 + c * 76, y + 32 + r * 26
                local sel = (k == 1 and not lib.bg) or (k > 1 and lib.bg == k - 1)
                local hot = inside(bx, by, 70, 22)
                rect(bx, by, 70, 22, mix(T.DarkContrast, T.TextColor, sel and 0.14 or (hot and 0.08 or 0)), 2)
                text(name, bx + (70 - tw(name, 12)) / 2, ty(by, 22, 12), T.TextColor, 12, sel and 1 or 0.7)
            end
        end
    end
    local sy = y + 32 + rows * 26 + 6
    local v = tostring(lib.bgOp)
    text("Opacity", x + 10, sy + 2, T.TextColor, 12)
    text(v, x + 152 - tw(v, 12), sy + 2, T.TextColor, 12, 1, true)
    rect(x + 8, sy + 26, 146, 4, T.LightContrast, 2)
    rect(x + 8, sy + 26, 146 * lib.bgOp / 100, 4, T.TextColor, 2)
    circle(x + 8 + 146 * lib.bgOp / 100, sy + 28, 5, T.TextColor)
end

local function drawWindow(lib, dt)
    local T = Theme
    local a = lib.anim
    local animating = a < 1
    local saved = Input.click

    if animating then Input.click = false end
    if lib.drag then
        if Input.down then
            lib.x = Input.x - lib.drag.x
            lib.y = Input.y - lib.drag.y
        else
            lib.drag = nil
        end
    end
    local x = lib.x
    local y = lib.y
    local W = lib.w
    local H = lib.h
    local top = y
    local Hc = H
    local Tb = 38
    if a < 0.5 then
        Hc = H * ease(a / 0.5)
        top = y + H - Hc
        Tb = Hc
    elseif a < 1 then
        Tb = 38 + (H - 38) * (1 - ease((a - 0.5) / 0.5))
    end
    for i = 1, 14 do
        rect(x - i, top - i, W + 2 * i, Hc + 2 * i, T.Glow, 4 + i, 0.016)
    end
    rect(x, top, W, Hc, T.Background, 4)
    local bgi = lib.bg and lib.images[lib.bg]
    PanelA = 1
    if bgi and bgi.bytes then
        if not bgi.icon then
            bgi.icon = Drawing.new("Image")
            bgi.icon.Data = bgi.bytes
            Icons[#Icons + 1] = bgi
        end
        Depth = Depth + 1
        bgi.icon.Size = Vector2.new(W, Hc)
        bgi.icon.Position = Vector2.new(x, top)
        bgi.icon.Transparency = lib.bgOp / 100
        bgi.icon.Rounding = 4
        bgi.icon.ZIndex = Depth
        bgi.icon.Visible = true
        bgi.iconSeen = FrameNo
        PanelA = 1 - 0.5 * lib.bgOp / 100
    end
    local gx = x + W - 14
    local gy = y + H - 14

    if a >= 0.5 then
        if Input.click and not State.active and inside(gx, gy, 14, 14) then
            State.active = { kind = "resize", mx = Input.x, my = Input.y, w0 = W, h0 = H }
        end
        if Input.click and not State.active and inside(x, y + H - 16, 16, 16) then
            Input.click = false
            togglePanel()
        end
        if Input.click and not State.active and inside(x, y, W, 38) then
            lib.drag = {x = Input.x - x, y = Input.y - y}
        end
        rect(x, y + 38, 126, H - 42, T.DarkContrast, 0, PanelA)
        rect(x, y + H - 20, 126, 20, T.DarkContrast, 4, PanelA)

        for i, page in ipairs(lib.pages) do
            local by = y + 48 + (i - 1) * 36
            local sel = lib.page == page
            local hot = inside(x, by, 126, 26) and not State.active and not lib.drag
            if hot and Input.click then
                lib.page = page

                if State.focus then commit(State.focus) end
                sel = true
            end
            local hasIcon = page.iconId ~= nil and not page.iconFailed
            local alpha = sel and 1 or (hot and 0.6 or 0.35)

            text(fit(page.title, 12, hasIcon and 76 or 100), hasIcon and x + 40 or x + 14, ty(by, 26, 12), T.TextColor, 12, alpha, sel)
            if hasIcon and page.iconBytes then
                if not page.icon then
                    page.icon = Drawing.new("Image")
                    page.icon.Data = page.iconBytes
                    Icons[#Icons + 1] = page
                end
                Depth = Depth + 1
                page.icon.Size = Vector2.new(16, 16)
                page.icon.Position = Vector2.new(x + 12, by + 5)
                page.icon.Transparency = alpha
                page.icon.ZIndex = Depth
                page.icon.Visible = true
                page.iconSeen = FrameNo
            end
        end

        local page = lib.page
        if page then
            if lib.lastPage ~= page then
                lib.lastPage = page
                lib.fage = 0
            end

            lib.fage = lib.fage + dt
            local cx = x + 134
            local cy = y + 46
            local cw = W - 152
            local vh = H - 56
            Clip0 = cy
            Clip1 = cy + vh
            local maxScroll = math.max(0, page.contentH - vh)

            if (not State.focus or State.focus.kind == "dropdown") and not State.listen and not State.dropSeen and inside(cx, cy, cw + 8, vh) then
                if down(0x28) then
                    page.scroll = page.scroll + 420 * dt
                elseif down(0x26) then
                    page.scroll = page.scroll - 420 * dt
                end
            end

            page.scroll = clamp(page.scroll, 0, maxScroll)
            if maxScroll > 0 then
                local trackX = x + W - 11
                local thumbH = math.max(24, vh * vh / page.contentH)
                local thumbY = cy + (page.scroll / maxScroll) * (vh - thumbH)
                if Input.click and not State.active and inside(trackX - 5, cy, 12, vh) then
                    State.active = { kind = "scroll", grab = clamp(Input.y - thumbY, 0, thumbH) }
                    if State.focus then State.focusHit = true end
                end
                local act = State.active
                if act and act.kind == "scroll" and Input.down then
                    page.scroll = clamp((Input.y - act.grab - cy) / (vh - thumbH), 0, 1) * maxScroll
                    thumbY = cy + (page.scroll / maxScroll) * (vh - thumbH)
                end

                rect(trackX, thumbY, 3, thumbH, T.DarkContrast, 1)
            end
            local cursor = cy - page.scroll
            local total = 0
            for si, section in ipairs(page.sections) do
                local k = clamp((lib.fage - (si - 1) * 0.05) / 0.15, 0, 1)
                local lift = (1 - ease(k)) * 8
                local sh = 36
                for _, it in ipairs(section.items) do
                    sh = sh + heightOf(it) + 4
                end
                Alpha = k
                local sy = cursor + lift
                rect(cx, sy, cw, sh, T.LightContrast, 4, PanelA)
                text(section.title, cx + 8, sy + 12, T.TextColor, 12, 1, true)
                local iy = sy + 32

                for _, it in ipairs(section.items) do
                    local h = heightOf(it)
                    Draw[it.kind](it, cx + 8, iy, cw - 16, dt)
                    iy = iy + h + 4
                end
                cursor = cursor + sh + 10
                total = total + sh + 10
            end
            Alpha = 1
            page.contentH = total
            Clip0 = nil
            Clip1 = nil
        end
    end
    local cut = math.min(20, Tb / 2)

    rect(x, top, W, Tb, T.Accent, 4)
    rect(x, top + cut, W, Tb - cut, T.Accent, 0)
    if Hc >= 26 then
        text(lib.title, x + 12, top + 12, T.TextColor, 14, 1, true)
    end
    if a >= 1 then
        local on = (State.active and State.active.kind == "resize") or inside(gx, gy, 14, 14)
        rect(x + W - 6, y + H - 6, 2, 2, T.TextColor, 1, on and 0.9 or 0.35)
        rect(x + W - 11, y + H - 6, 2, 2, T.TextColor, 1, on and 0.9 or 0.35)
        rect(x + W - 6, y + H - 11, 2, 2, T.TextColor, 1, on and 0.9 or 0.35)
    end
    PanelA = 1
    Input.click = saved
end

local function eachItem(lib, fn)
    for _, page in ipairs(lib.pages) do
        for _, section in ipairs(page.sections) do
            for _, it in ipairs(section.items) do
                fn(it)
            end
        end
    end
end

local function runKeybinds(lib)
    if State.listen or State.focus then return end
    eachItem(lib, function(it)
        if it.kind == "keybind" and it.vk and edge(it.vk) then call(it.cb, it.up) end
    end)
end

local function captureKey()
    local it = State.listen
    if edge(0x1B) then
        State.listen = nil
        it.vk = nil
        it.cpop = 0.2
        call(it.changed, nil, it.up)
        return
    end
    for _, vk in ipairs(ScanList) do
        if edge(vk) then
            State.listen = nil
            it.vk = vk
            it.cpop = 0.2
            call(it.changed, keyValue(vk), it.up)
            return
        end
    end
end

local SliderKeys = {[0xBD] = "-", [0xBE] = "."}

for i = 0, 9 do
    SliderKeys[0x30 + i] = tostring(i)
end

local function typing(it)
    local now = tick()
    local shift = down(0x10)
    local numeric = it.kind == "slider" or it.kind == "rgbbox"
    local key = (numeric or it.kind == "dropdown") and "buf" or "value"
    local cur = it[key] or ""
    local function pressed(vk)
        if down(vk) then
            if not PrevDown[vk] then
                Hold[vk] = now + 0.4
                return true
            end
            if Hold[vk] and now >= Hold[vk] then
                Hold[vk] = now + 0.04
                return true
            end
        else
            Hold[vk] = nil
        end
        return false
    end
    local changed = false
    for vk, v in pairs(numeric and SliderKeys or TypeKeys) do
        if pressed(vk) and #cur < (numeric and 8 or 64) then
            cur = cur .. (numeric and v or (shift and v[2] or v[1]))
            changed = true
        end
    end
    if pressed(0x08) and #cur > 0 then
        cur = string.sub(cur, 1, #cur - 1)
        changed = true
    end
    it[key] = cur
    if changed then
        if it.kind == "slider" then
            local n = tonumber(cur)
            if n then
                it.value = clamp(n, it.min, it.max)
                it.pop = 0.2
                call(it.cb, it.value, it.up)
            end
        elseif it.kind == "rgbbox" then
            local n = tonumber(cur)
            if n then
                local p = it.picker
                local c = p.it.color
                local rgb = {
                    math.floor(c.R * 255 + 0.5),
                    math.floor(c.G * 255 + 0.5),
                    math.floor(c.B * 255 + 0.5),
                }
                rgb[it.ch] = clamp(math.floor(n), 0, 255)
                p.it.color = Color3.fromRGB(rgb[1], rgb[2], rgb[3])
                local h, s, v = toHsv(p.it.color)
                if s > 0 and v > 0 then
                    p.hue = h
                end
                p.sat = s
                p.val = v
                p.lh = p.hue
                p.ls = s
                p.lv = v
                call(p.it.cb, p.it.color, p.it.up)
            end
        elseif it.kind == "dropdown" then
            it.off = 0
        else
            it.fpop = 0.2
            call(it.cb, it.value, false, it.up)
        end
    end
    if it.kind == "dropdown" and edge(0x0D) then
        local m = matches(it)
        if m[1] then
            it.selected = m[1]
            it.pop = 0.2
            call(it.cb, m[1], it.up)
        end
        commit(it)
        return
    end
    if edge(0x0D) or edge(0x1B) then commit(it) end
end

local function blocking(lib)
    if State.focus or State.listen then return true end
    if lib.anim > 0 and (State.active or lib.drag) then
        return true
    end
    local mx = Input.x
    local my = Input.y

    if lib.anim > 0 then
        if mx >= lib.x - 6 and mx <= lib.x + lib.w + 6 and my >= lib.y - 6 and my <= lib.y + lib.h + 6 then
            return true
        end
    end
    local p = State.picker

    if p and mx >= p.x - 6 and mx <= p.x + 168 and my >= p.y - 6 and my <= p.y + 175 then
        return true
    end

    local q = State.panel
    if q and mx >= q.x - 6 and mx <= q.x + 168 and my >= q.y - 6 and my <= q.y + q.h + 6 then
        return true
    end

    for _, n in ipairs(Notes) do
        if mx >= n.bx and mx <= n.bx + n.bw and my >= n.y and my <= n.y + n.h then return true end
    end

    return false
end

local function frame(dt)
    local lib = Current
    if not lib then return end

    local was = Input.down
    Input.x = Mouse.X
    Input.y = Mouse.Y
    Input.down = ismouse1pressed()
    Input.click = Input.down and not was
    FrameDown = {}
    FrameNo = FrameNo + 1
    State.dropSeen = State.dropNow
    State.dropNow = false
    State.focusHit = false
    applyActive()
    updateNotes(dt)
    updatePicker(dt)
    updatePanel(lib, dt)
    lib.anim = approach(lib.anim, lib.open and 1 or 0, dt / 0.4)
    if not lib.open then
        closePicker(false)
        if State.panel then State.panel.open = false end
        if State.focus then
            commit(State.focus)
        end
        State.listen = nil
        State.active = nil
        lib.drag = nil
    end
    runKeybinds(lib)
    if State.listen then captureKey() end
    if State.focus then
        typing(State.focus)
    end
    if lib.anim > 0 then drawWindow(lib, dt) end
    if Input.click and State.focus and not State.focusHit then commit(State.focus) end
    drawPicker(dt)
    drawPanel(lib)
    drawNotes()
    local want = blocking(lib)

    if want ~= Blocked then
        Blocked = want
        setrobloxinput(not want)
    end
    for vk, v in pairs(FrameDown) do
        PrevDown[vk] = v
    end
    sweep()
end

local function cleanup()
    if Conn then
        pcall(function()
            Conn:Disconnect()
        end)
        Conn = nil
    end
    for kind, list in pairs(Pools) do
        for _, e in ipairs(list) do
            pcall(function()
                e.o:Remove()
            end)
        end

        Pools[kind] = {}
        Used[kind] = 0
    end

    for _, pg in ipairs(Icons) do
        pcall(function()
            pg.icon:Remove()
        end)
        pg.icon = nil
    end

    Icons = {}
    Notes = {}
    Current = nil
    State.picker = nil
    State.panel = nil
    State.active = nil
    State.focus = nil
    State.listen = nil
    Depth = 0
    if Blocked then
        Blocked = false
        pcall(setrobloxinput, true)
    end
end

_G.LarpCleanup = cleanup

local function isPng(bytes)
    if type(bytes) ~= "string" or #bytes < 24 then
        return false
    end
    local a, b = string.byte(bytes, 1, 2)

    return (a == 137 and b == 80) or (a == 255 and b == 216)
end

local AssetUrls = {
    "https://thumbnails.roblox.com/v1/assets?assetIds=%s&returnPolicy=PlaceHolder&size=%s&format=Png&isCircular=false",
    "https://thumbnails.roproxy.com/v1/assets?assetIds=%s&returnPolicy=PlaceHolder&size=%s&format=Png&isCircular=false",
}

local function fetchAsset(id, size, tag)
    local name = "larp_" .. tag .. "_" .. id .. ".dat"
    if isfile(name) then
        local cached = readfile(name)
        if isPng(cached) then return cached end
    end
    for _ = 1, 3 do
        for _, pattern in ipairs(AssetUrls) do
            local reply = httpget(string.format(pattern, id, size))
            local url = string.match(reply, '"imageUrl":"([^"]+)"')
            if url then
                local bytes = httpget((string.gsub(url, "\\/", "/")))
                if isPng(bytes) then
                    writefile(name, bytes)
                    return bytes
                end
            end
        end
        task.wait(0.7)
    end
    return nil
end

local function fetchIcon(id)
    return fetchAsset(id, "110x110", "icon")
end

local function fetchImage(id)
    return fetchAsset(id, "420x420", "img")
end

local function decodeImage(src)
    src = string.gsub(src, "^data:image/%w+;base64,", "")
    src = string.gsub(src, "%s", "")
    local bytes = base64decode(src)
    if isPng(bytes) then return bytes end
    return nil
end

local function isAssetId(src)
    return string.match(src, "^%d+$") ~= nil and #src < 20
end

local LastErr = nil
local Library = {}
Library.__index = Library

local Page = {}
Page.__index = Page

local Section = {}
Section.__index = Section

function Library.new(title, icon)
    cleanup()

    local lib = setmetatable({}, Library)
    local vp = Cam.ViewportSize
    lib.title = tostring(title or "Larp")
    lib.pages = {}
    lib.w = 511
    lib.h = 428
    lib.x = math.floor((vp.X - lib.w) / 2)
    lib.y = math.floor((vp.Y - lib.h) / 2)
    lib.open = true
    lib.anim = 1
    lib.fade = 1
    lib.images = {}
    lib.bgOp = 35
    Current = lib
    Conn = RunService.RenderStepped:Connect(function(dt)
        local ok, err = pcall(frame, dt)
        if not ok then
            pcall(sweep)
            if tostring(err) ~= LastErr then
                LastErr = tostring(err)
                if Debug then warn(LastErr) end
            end
        end
    end)

    return lib
end

function Library:addPage(title, icon)
    local page = setmetatable({}, Page)
    page.library = self
    page.title = tostring(title)
    page.sections = {}
    page.scroll = 0
    page.contentH = 0
    if icon ~= nil and tostring(icon) ~= "" then
        local src = tostring(icon)
        page.iconId = src
        if isAssetId(src) then
            task.spawn(function()
                local ok, bytes = pcall(fetchIcon, src)
                if ok and bytes then page.iconBytes = bytes else page.iconFailed = true end
            end)
        else
            local ok, bytes = pcall(decodeImage, src)
            if ok and bytes then page.iconBytes = bytes else page.iconFailed = true end
        end
    end
    table.insert(self.pages, page)
    if not self.page then self.page = page end
    return page
end

function Library:toggle(state)
    if type(state) == "boolean" then
        self.open = state
    else
        self.open = not self.open
    end
end

function Library:setTheme(theme, color)
    if Theme[theme] and color then
        Theme[theme] = color
    end
end

function Library:SelectPage(page, toggle)
    if type(page) == "number" then
        page = self.pages[page]
    end

    if page then self.page = page end
end

function Library:Notify(title, context, callback)
    local label = tostring(title or "")
    local lines = wrap(tostring(context or ""), 40)
    local longest = #label * 7 / 6

    for _, line in ipairs(lines) do
        longest = math.max(longest, #line)
    end

    table.insert(Notes, {
        title = label,
        lines = lines,
        cb = callback,
        t = 0,
        ct = 0,
        closing = false,
        w = clamp(longest * 6 + 70, 200, 330),
        h = 44 + #lines * 14 + (callback and 34 or 4),
        bx = 10,
        bw = 0,
        y = 0,
    })
    while #Notes > 6 do
        table.remove(Notes, 1)
    end
end

function Library:setDebug(on)
    Debug = on == true
end

function Library:addImage(source)
    local n = #self.images + 1
    local im = { name = "image" .. n }
    local src = tostring(source)
    self.images[n] = im
    if isAssetId(src) then
        task.spawn(function()
            local ok, bytes = pcall(fetchImage, src)
            if ok and bytes then im.bytes = bytes else im.failed = true end
        end)
    else
        local ok, bytes = pcall(decodeImage, src)
        if ok and bytes then im.bytes = bytes else im.failed = true end
    end
    return n
end

function Library:setBackground(which)
    if which == nil or which == false or which == "off" then
        self.bg = nil
        self.bgOff = true
        return
    end
    for i, im in ipairs(self.images) do
        if i == which or im.name == which then
            self.bg = i
            self.bgOff = false
            return
        end
    end
end

function Library:setBackgroundOpacity(v)
    self.bgOp = clamp(math.floor(tonumber(v) or 35), 0, 100)
end

function Library:Destroy()
    cleanup()
end

function Page:addSection(title)
    local section = setmetatable({}, Section)
    section.page = self
    section.title = tostring(title)
    section.items = {}
    section.lookup = {}
    table.insert(self.sections, section)
    return section
end

function Page:Resize()
end

function Section:Resize()
end

local UpdateName = {
    toggle = "updateToggle",
    button = "updateButton",
    textbox = "updateTextbox",
    keybind = "updateKeybind",
    color = "updateColorPicker",
    slider = "updateSlider",
    dropdown = "updateDropdown",
}

function Section:push(it)
    it.section = self
    it.up = function(...)
        return self[UpdateName[it.kind]](self, it, ...)
    end
    table.insert(self.items, it)
    self.lookup[it.title] = it
    return it
end

function Section:find(item)
    if type(item) == "string" then return self.lookup[item] end
    return item
end

function Section:addToggle(title, default, callback)
    return self:push({ kind = "toggle", title = tostring(title), value = default == true, cb = callback })
end

function Section:updateToggle(toggle, title, value)
    local it = self:find(toggle)
    if not it then return end
    if title then it.title = tostring(title) end
    if value ~= nil then
        it.value = value == true
    end
    return it
end

function Section:addButton(title, callback)
    return self:push({ kind = "button", title = tostring(title), cb = callback })
end

function Section:updateButton(button, title)
    local it = self:find(button)
    if it and title then it.title = tostring(title) end
    return it
end

function Section:addTextbox(title, default, callback)
    return self:push({ kind = "textbox", title = tostring(title), value = tostring(default or ""), cb = callback })
end

function Section:updateTextbox(textbox, title, value)
    local it = self:find(textbox)
    if not it then return end
    if title then it.title = tostring(title) end
    if value ~= nil then
        it.value = tostring(value)
    end
    return it
end

function Section:addKeybind(title, default, callback, changed)
    return self:push({ kind = "keybind", title = tostring(title), vk = toVK(default), cb = callback, changed = changed })
end

function Section:updateKeybind(keybind, title, key)
    local it = self:find(keybind)
    if not it then return end
    if title then
        it.title = tostring(title)
    end
    if key ~= nil then it.vk = toVK(key) end
    return it
end

function Section:addColorPicker(title, default, callback)
    return self:push({ kind = "color", title = tostring(title), color = default or Color3.fromRGB(255, 255, 255), cb = callback, open = false })
end

function Section:updateColorPicker(colorpicker, title, color)
    local it = self:find(colorpicker)
    if not it then
        return
    end
    if title then it.title = tostring(title) end
    if color ~= nil then
        it.color = color
    end
    return it
end

function Section:addSlider(title, default, min, max, callback)
    min = min or 0
    max = max or 100

    return self:push({kind = "slider", title = tostring(title), value = clamp(default or min, min, max), default = default or min, min = min, max = max, cb = callback})
end

function Section:updateSlider(slider, title, value, min, max)
    local it = self:find(slider)
    if not it then return end

    if title then it.title = tostring(title) end
    if min ~= nil then
        it.min = min
    end
    if max ~= nil then it.max = max end

    if value ~= nil then it.value = clamp(value, it.min, it.max) end
    return it
end

local function strings(list)
    local out = {}

    for i, v in ipairs(list or {}) do
        out[i] = tostring(v)
    end

    return out
end

function Section:addDropdown(title, list, callback)
    return self:push({kind = "dropdown", title = tostring(title), list = strings(list), cb = callback, open = false})
end

function Section:updateDropdown(dropdown, title, list, callback)
    local it = self:find(dropdown)
    if not it then return end

    if title then
        it.title = tostring(title)
    end

    if list then it.list = strings(list) end
    if callback then it.cb = callback end

    return it
end

_G.Larp = Library
