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
- Optional image background with an opacity control

## Load

```lua
loadstring(httpget("https://raw.githubusercontent.com/kaiii-alt/LarpUI/refs/heads/main/larp.lua"))()

local library = _G.Larp
local larp = library.new("Larp")
```

Matcha drops the return value of `loadstring`, so the library is exposed as `_G.Larp`.

## Example

```lua
loadstring(httpget("https://raw.githubusercontent.com/kaiii-alt/LarpUI/refs/heads/main/larp.lua"))()

local larp = _G.Larp.new("Larp")

local page = larp:addPage("Main", 5012544693)
local section = page:addSection("Section")

section:addToggle("Toggle", false, function(value)
    larp:Notify("Value", tostring(value))
end)

section:addSlider("Speed", 16, 0, 100, function(value)
    larp:Notify("Value", tostring(value))
end)

section:addKeybind("Menu Key", Enum.KeyCode.RightControl, function()
    larp:toggle()
end)
```

A full demo is in `example.lua`.

## Images

Larp can show an image behind the window. Put the picture inside your script as Base64 text, so there is nothing to download or place by hand.

```lua
larp:addImage("iVBORw0KGgoAAAANSUhEUg...")
larp:addImage("iVBORw0KGgoAAAANSUhEUg...")
```

Images are named `image1`, `image2` and so on in the order you add them. The background is off by default, so nothing shows until you pick an image.

To get the Base64 text of a PNG, run this in PowerShell. It shrinks the picture to 320 by 268 and copies the text to your clipboard:

```
Add-Type -AssemblyName System.Drawing
$src = [System.Drawing.Image]::FromFile("C:\path\to\image1.png")
$bmp = New-Object System.Drawing.Bitmap 320, 268
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.DrawImage($src, 0, 0, 320, 268)
$ms = New-Object System.IO.MemoryStream
$bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
[Convert]::ToBase64String($ms.ToArray()) | Set-Clipboard
```

Paste the result between the square brackets in `[==[ ]==]`. Pasted text can have line breaks in it.

Base64 makes a file about a third bigger, so a 225 KB picture becomes about 300,000 characters. The window is only about 500 pixels wide and the picture sits faintly behind it, so a small picture looks the same and keeps your script small. The picture is stretched to fit the window.

You can also pass a Roblox asset id, such as `larp:addImage(1234567890)`. It is downloaded once and saved in your workspace folder.

### Make an image the default

Call `setBackground` after adding your images. Use the number or the name of the image you want, and set the opacity if you like:

```lua
larp:addImage("...")
larp:addImage("...")

larp:setBackground(2)
larp:setBackgroundOpacity(50)
```

`larp:setBackground("image2")` does the same thing. Without a `setBackground` call the background stays off.

### library:addImage(source)

Adds an image from Base64 text or an asset id and returns its number.

### library:setBackground(which)

Picks the background by number or name, such as `2` or `"image2"`. Pass `nil` or `"off"` to turn it off.

### library:setBackgroundOpacity(percent)

Sets how strong the image is, from 0 to 100.

## Library

### library.new(title)

Creates the window and returns the library object. Calling it again removes the old window first.

### library:addPage(title, icon)

Adds a page. `icon` is optional and can be a Base64 PNG or a Roblox asset id. Asset ids are downloaded once and cached as `larp_icon_<id>.dat`. If an icon fails to load, the page shows only its name.

Returns a page.

### library:toggle(state)

Shows or hides the window. With no argument it flips. With a boolean it sets the state.

### library:setTheme(theme, color)

Changes a theme color. `theme` is one of `Background`, `Glow`, `Accent`, `LightContrast`, `DarkContrast`, `TextColor`. `color` is a `Color3`.

### library:Notify(title, context, callback)

Shows a notification at the bottom left. Without a callback it closes after 5 seconds. With a callback it shows Accept and Cancel buttons and calls `callback(true)` or `callback(false)`.

### library:SelectPage(page)

Opens a page. Accepts a page object or its index in `library.pages`.

### library:setDebug(state)

Turns error messages in the console on or off. They are off by default.

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
