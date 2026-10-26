# Larp

A UI library for Matcha, drawn entirely with the Drawing API. Pages, sections, toggles, buttons, textboxes, keybinds, sliders, dropdowns, color pickers and notifications.

## Features

- Dark, clean look with simple function names
- Animated window open and close, pop effects, toggle squash, page fades
- Color picker popup with saturation and brightness canvas, hue bar and typed RGB
- Dropdown with search
- Resizable from the bottom right corner, draggable from the title bar
- Only blocks game clicks while your mouse is over the menu
- Page icons from Roblox asset ids

## Load

```lua
loadstring(httpget("https://raw.githubusercontent.com/YOUR_USER/larp/main/larp.lua"))()

local library = _G.Larp
local larp = library.new("Larp")
```

Matcha drops the return value of `loadstring`, so the library is exposed as `_G.Larp`.

## Example

```lua
loadstring(httpget("https://raw.githubusercontent.com/YOUR_USER/larp/main/larp.lua"))()

local larp = _G.Larp.new("Larp")

local page = larp:addPage("Main", 5012544693)
local section = page:addSection("Section")

section:addToggle("Toggle", false, function(value)
    print(value)
end)

section:addSlider("Speed", 16, 0, 100, function(value)
    print(value)
end)

section:addKeybind("Menu Key", Enum.KeyCode.RightControl, function()
    larp:toggle()
end)
```

A full demo is in `example.lua`.

## Library

### library.new(title)

Creates the window and returns the library object. Calling it again removes the old window first.

### library:addPage(title, icon)

Adds a page. `icon` is an optional Roblox asset id. It is downloaded once and cached as `larp_icon_<id>.dat`. If it fails to load, the page shows only its name.

Returns a page.

### library:toggle(state)

Shows or hides the window. With no argument it flips. With a boolean it sets the state.

### library:setTheme(theme, color)

Changes a theme color. `theme` is one of `Background`, `Glow`, `Accent`, `LightContrast`, `DarkContrast`, `TextColor`. `color` is a `Color3`.

### library:Notify(title, context, callback)

Shows a notification at the bottom left. Without a callback it closes after 5 seconds. With a callback it shows Accept and Cancel buttons and calls `callback(true)` or `callback(false)`.

### library:SelectPage(page)

Opens a page. Accepts a page object or its index in `library.pages`.

### library:Destroy()

Removes the window and all drawings.

## Page

### page:addSection(title)

Adds a section card to the page. Returns a section.

## Section

Every `add` function returns an item. Every `update` function accepts that item or its title as a string.

### section:addToggle(title, default, callback)

`callback(value, update)`

### section:addButton(title, callback)

`callback(update)`

### section:addTextbox(title, default, callback)

`callback(text, focusLost, update)`

Fires on every change with `focusLost` false, then once more with `focusLost` true when the box is left.

### section:addKeybind(title, default, callback, changedCallback)

`callback(update)` fires when the key is pressed, even while the window is hidden.

`changedCallback(key, update)` fires after the key is rebound. Click the key box to rebind. Escape clears it.

`default` can be an `Enum.KeyCode` or a key name such as `"F"`.

### section:addColorPicker(title, default, callback)

`callback(color, update)`

Click the swatch to open the picker. Submit keeps the color. The close button restores the color it had when opened.

### section:addSlider(title, default, min, max, callback)

`callback(value, update)`

Values are whole numbers. Click the number on the right to type a value.

### section:addDropdown(title, list, callback)

`callback(text, update)`

Click the header and type to search. The list shows 3 entries at a time. Use Up and Down while the mouse is over it to move through the rest.

### Update functions

```
section:updateToggle(toggle, title, value)
section:updateButton(button, title)
section:updateTextbox(textbox, title, text)
section:updateKeybind(keybind, title, key)
section:updateColorPicker(colorpicker, title, color)
section:updateSlider(slider, title, value, min, max)
section:updateDropdown(dropdown, title, list, callback)
```

Pass `nil` for anything you do not want to change.

## Notes

- Scrolling uses the scrollbar, or Up and Down while the mouse is over the page. There is no mouse wheel input in Matcha.
- Text uses the System font.
- Page icons and the first load of an icon need internet access.
