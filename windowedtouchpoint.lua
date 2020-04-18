--[[
The MIT License (MIT)
 
Copyright (c) 2013 Lyqyd
Copyright (c) 2020 drummeur
 
Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:
 
The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.
 
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
--]]

local function setupLabel(buttonLen, minY, maxY, name, inactiveText, activeText)
    local labelTable = {}
    if type(name) == "table" then
        for i=1, #name do
            labelTable[i] = {}
            labelTable[i][true] = name[i]
            labelTable[i][false] = name[i]
        end
        name = name.label
    elseif type(name) == "string" then
        inactiveText = inactiveText or name
        activeText = activeText or name
        
        local inactiveButtonText = string.sub(inactiveText, 1, buttonLen-2)
        local activeButtonText = string.sub(activeText, 1, buttonLen-2)
        
        -- todo: I think we can make the active/inactive padding code more efficient
        
        -- pad inactiveButtonText with spaces
        if  #inactiveButtonText < #inactiveText then
            inactiveButtonText = " " .. inactiveButtonText .. " "
        else
            local labelLine = string.rep(" ", math.floor((buttonLen - #inactiveButtonText) / 2)) .. inactiveButtonText
            inactiveButtonText = labelLine .. string.rep(" ", buttonLen - #labelLine)
        end
            
        -- pad activeButtonText with spaces
        if  #activeButtonText < #activeText then
            activeButtonText = " " .. activeButtonText .. " "
        else
            local labelLine = string.rep(" ", math.floor((buttonLen - #activeButtonText) / 2)) .. activeButtonText
            activeButtonText = labelLine .. string.rep(" ", buttonLen - #labelLine)
        end
        
        -- add the active and inactive text to the table
        for i = 1, maxY - minY + 1 do
                labelTable[i] = {}
            if maxY == minY or i == math.floor((maxY - minY) / 2) + 1 then
                labelTable[i][true] = activeButtonText
                labelTable[i][false] = inactiveButtonText
            else
                labelTable[i][true] = string.rep(" ", buttonLen)
                labelTable[i][false] = string.rep(" ", buttonLen)
            end
        end
    end
    
    return labelTable, name
end
 
local Button = {
    draw = function(self)
        local old = term.redirect(self.mon)
        term.setTextColor(colors.white)
        term.setBackgroundColor(colors.black)
        term.clear()
        for name, buttonData in pairs(self.buttonList) do
            if buttonData.active then
                term.setBackgroundColor(buttonData.activeBackgroundColor)
                term.setTextColor(buttonData.activeTextColor)
            else
                term.setBackgroundColor(buttonData.inactiveBackgroundColor)
                term.setTextColor(buttonData.inactiveTextColorColor)
            end
        
            for i = buttonData.yMin, buttonData.yMax do
                term.setCursorPos(buttonData.xMin, i)
                term.write(buttonData.label[i - buttonData.yMin + 1][buttonData.active])
            end
        end
        if old then
            term.redirect(old)
        else
            term.restore()
        end
    end,
    
    add = function(self, name, func, xMin, yMin, xMax, yMax, inactiveBackgroundColor, activeBackgroundColor, inactiveTextColorColor, activeTextColor, inactiveText, activeText, active)
        local x, y = self.mon.getSize()

        -- check if the button is out of bounds anywhere
        if xMin < 1 then
            error("button '" .. name .. "' out of bounds left: xMin=" .. xMin .. "<1", 2)
        end
        if yMin < 1 then
            error("button  '" .. name .. "' out of bounds above: yMin=" .. yMin .. "<1", 2)
        end
        if xMax > x then
            error("button  '" .. name .. "' out of bounds right: xMax=" .. xMax .. ">x=" .. x, 2)
        end
        if yMax > y then
            error("button  '" .. name .. "' out of bounds below: yMax=" .. yMax .. ">y=" .. y, 2)
        end

        local offsetX, offsetY = self.mon.getPosition()

        local label, name = setupLabel(xMax-xMin+1, yMin, yMax, name, inactiveText, activeText)
        if self.buttonList[name] then 
            error("button '" .. name .. "' already exists", 2) 
        end

        self.buttonList[name] = {
            func = func,
            xMin = xMin,
            yMin = yMin,
            xMax = xMax,
            yMax = yMax,
            active = active or false,
            inactiveBackgroundColor = inactiveBackgroundColor or colors.red,
            activeBackgroundColor = activeBackgroundColor or colors.lime,
            inactiveTextColorColor = inactiveTextColorColor or colors.white,
            activeTextColor = activeTextColor or colors.white,
            label = label,
        }
        local overlap = nil
        for i=xMin, xMax do
            for j=yMin, yMax do
                -- check for overlapping buttons
                if self.clickMap[i+offsetX][j+offsetY] ~= nil then
                    overlap = self.clickMap[i+offsetX][j+offsetY]
                    -- undo changes we might have done
                    for k=xMin, xMax do
                        for m = yMin, yMax do
                            if self.clickMap[k+offsetX][m+offsetY] == name then
                                self.clickMap[k+offsetX][m+offsetY] = nil
                            end
                        end
                    end
                    self.buttonList[name] = nil
                    error("existing button '" .. overlap .. "' overlaps with new button '" .. name .."'", 2)
                end
                self.clickMap[i+offsetX][j+offsetY] = name
            end
        end
    end,
    
    remove = function(self, name)
        if self.buttonList[name] then
            local button = self.buttonList[name]
            for i = button.xMin, button.xMax do
                for j = button.yMin, button.yMax do
                    self.clickMap[i][j] = nil
                end
            end
            self.buttonList[name] = nil
        end
    end,
    run = function(self)
        while true do
            self:draw()
            local event = {self:handleEvents(os.pullEvent(self.side == "term" and "mouse_click" or "monitor_touch"))}
            if event[1] == "button_click" then
                self.buttonList[event[2]].func()
            end
        end
    end,
    
    handleEvents = function(self, ...)
        local event = {...}
        if #event == 0 then 
            event = {os.pullEvent()} 
        end
        if (self.side == "term" and event[1] == "mouse_click") or (self.side ~= "term" and event[1] == "monitor_touch" and event[2] == self.side) then
            local clicked = self.clickMap[event[3]][event[4]]
            if clicked and self.buttonList[clicked] then
                return "button_click", clicked
            end
        end
        return unpack(event)
    end,
    
    toggleButton = function(self, name, noDraw)
        self.buttonList[name].active = not self.buttonList[name].active
        if not noDraw then
            self:draw()
        end
    end,
    
    flash = function(self, name, duration)
        self:toggleButton(name)
        sleep(tonumber(duration) or 0.15)
        self:toggleButton(name)
    end,
    
    rename = function(self, name, newName)
        self.buttonList[name].label, newName = setupLabel(self.buttonList[name].xMax - self.buttonList[name].xMin + 1, self.buttonList[name].yMin, self.buttonList[name].yMax, newName)
        if not self.buttonList[name] then 
            error("no such button '" .. name .. "'", 2) 
        end
        if name ~= newName then
            self.buttonList[newName] = self.buttonList[name]
            self.buttonList[name] = nil
            for i = self.buttonList[newName].xMin, self.buttonList[newName].xMax do
                for j = self.buttonList[newName].yMin, self.buttonList[newName].yMax do
                    self.clickMap[i][j] = newName
                end
            end
        end
        self:draw()
    end,
}
 
function new(side, monitor)
    local buttonInstance = {
        side = side or "term",
        mon = monitor or peripheral.wrap(side),
        buttonList = {},
        clickMap = {}
    }
    local xMin, _ = buttonInstance.mon.getPosition()
    local xMax, _ = buttonInstance.mon.getSize()
    
    for i = 1, xMin + xMax do
        buttonInstance.clickMap[i] = {}
    end
    
    setmetatable(buttonInstance, {__index = Button})
    
    return buttonInstance
end
