loadstring(httpget("https://raw.githubusercontent.com/kaiii-alt/LarpUI/refs/heads/main/larp.lua"))()

local library = _G.Larp
local larp = library.new("Larp", 5013109572)

local ADD_IMAGES_HERE = {
    [==[PASTE_BASE64_FOR_image1]==],
    [==[PASTE_BASE64_FOR_image2]==],
}

for _, data in ipairs(ADD_IMAGES_HERE) do
    if string.sub(data, 1, 5) ~= "PASTE" then
        larp:addImage(data)
    end
end

local themes = {
    Background = Color3.fromRGB(24, 24, 24),
    Glow = Color3.fromRGB(0, 0, 0),
    Accent = Color3.fromRGB(10, 10, 10),
    LightContrast = Color3.fromRGB(20, 20, 20),
    DarkContrast = Color3.fromRGB(14, 14, 14),
    TextColor = Color3.fromRGB(255, 255, 255),
}

local page = larp:addPage("Test", 5012544693)
local section1 = page:addSection("Section 1")
local section2 = page:addSection("Section 2")

section1:addToggle("Toggle", nil)

section1:addButton("Button")

section1:addTextbox("Notification", "Default", function(value, focusLost)
    if focusLost then larp:Notify("Title", value) end
end)

section2:addKeybind("Toggle Keybind", Enum.KeyCode.One, function()
    larp:toggle()
end)

section2:addColorPicker("ColorPicker", Color3.fromRGB(50, 50, 50))
section2:addColorPicker("ColorPicker2")

section2:addSlider("Slider", 0, -100, 100)

section2:addDropdown("Dropdown", {"Hello", "World", "Hello World", "Word", 1, 2, 3})

section2:addDropdown("Dropdown 2", {"Hello", "World", "Hello World", "Word", 1, 2, 3})

section2:addButton("Button 2")

local theme = larp:addPage("Theme", 5012544693)
local colors = theme:addSection("Colors")

for name, color in pairs(themes) do
    colors:addColorPicker(name, color, function(color3)
        larp:setTheme(name, color3)
    end)
end

larp:SelectPage(larp.pages[1], true)
