--
-- HorrorClown (PewX)
-- Using: IntelliJ IDEA 14 Ultimate
-- Date: 26.07.2015 - Time: 04:18
-- pewx.de // iGaming-mta.de // iRace-mta.de // iSurvival.de // mtasa.de
--
requestBrowserDomains({"youtube.de", "lh5.googleusercontent.com", "mta-sa.org", "google.com", "www.google.com", "google.de", "www.google.de", "accounts.google.com", "yt3.ggpht.com",  "www.mta-sa.org", "www.pewx.de", "pewx.de", "mtasa.de", "irace-mta.de", "www.irace-mta.de", })
CBrowser = {}

function CBrowser:constructor(startX, startY)
    --Browser start properties
    self.browserDefaultSizeX = startX or 640
    self.browserDefaultSizeY = startY or 480
    self.state = true
    self.isActive = true

    self.tabCloseHoveredIndex = 0
    self.currentTab = 0
    self.tabs = {}

    ---
    --Colors
    ---
    if not self:initColors() then
        return
    end

    ---
    --Browser size configuration
    ---
    self:initBrowserSize()

    ---
    --Function handles
    ---
    self:initFunctionHandles()

    ------------------------------------
    --Development
    -----------------------------------
    self.commandFunc = bind(CBrowser.navigateTo, self)
    addCommandHandler("navigate", self.commandFunc)

    self:toggleBrowser()
    self:createTab()

    self.subElements = {}
    self.urlBar = new(CDXEdit, "URL", self.menuOffset + 5 + 36*4, self.browserTabHeight + 5, - 36*4 + self.browserSizeX - self.menuOffset*2 - 5*2, 24, false, false, self)
    self.urlBar:addClickHandler()
end

function CBrowser:destructor()
    removeCommandHandler("navigate", self.commandFunc)
    removeEventHandler("onClientCursorMove", root, self.cursorMoveFunc)
    removeEventHandler("onClientRender", root, self.renderFunc)
    removeEventHandler("onClientClick", root, self.onClickFunc)
    removeEventHandler("onClientPreRender", root, self.preRenderFunc)
    removeEventHandler("onClientKey", root, self.clientKeyFunc)
    removeEventHandler("onClientBrowserNavigate", root, self.navigateFunc)
    removeEventHandler("onClientBrowserDocumentReady", root, self.documentReadyFunc)
	removeEventHandler("onClientBrowserWhitelistChange", root, self.whitelistChangeFunc)

    showCursor(false)

    for _, v in pairs(self) do
        v = nil
    end
end

function CBrowser:initColors()
    local colors = Core:getManager("CBrowserManager"):getColors()
    if not colors then
        return false
    end

    self.colors = {}
    for masterKey, subTable in pairs(colors) do
        self.colors[masterKey] = {}
       for subKey, sValue in pairs(subTable) do
          local color = split(sValue, ",")
          --outputChatBox(("[%s][%s]: [%s], [%s], [%s]"):format(tostring(masterKey), tostring(subKey), tostring(color[1]), tostring(color[2]), tostring(color[3])))
          self.colors[masterKey][subKey] = tocolor(color[1], color[2], color[3], color[4] or 255)
       end
    end
    self.colors.browserWindow.browser = self.colors.browserWindow.browser_active

    return true
end

function CBrowser:initBrowserSize()
    self.isMaximized = false

    self.browserSizeX = self.browserDefaultSizeX/1920*x
    self.browserSizeY = self.browserDefaultSizeY/1080*y
    self.browserStartX = x/2-self.browserSizeX/2
    self.browserStartY = y/2-self.browserSizeY/2
    self.browserTabHeight = 35/1920*x
    self.browserMenuHeight = 34
    self.menuIconSizeX = 80/1920*x
    self.menuIconSizeY = 30/1920*x

    self.defaultMenuOffset = 5/1920*x
    self.menuOffset = self.defaultMenuOffset

    self.defaultTabSize = 180
    self.defaultTabHeight = self.menuIconSizeY + 5
    self.tabSize = self.defaultTabSize
    self.tabHeight = self.defaultTabHeight
end

function CBrowser:initFunctionHandles()
    self.renderFunc = bind(CBrowser.renderBrowser, self)
    self.preRenderFunc = bind(CBrowser.preRenderBrowser, self)

    self.onClickFunc = bind(CBrowser.onClick, self)
    self.cursorMoveFunc = bind(CBrowser.onCursorMove, self)
    self.clientKeyFunc = bind(CBrowser.onClientKey, self)
    self.navigateFunc = bind(CBrowser.onBrowserNavigate, self)
    self.documentReadyFunc = bind(CBrowser.onDocumentReady, self)
    self.whitelistChangeFunc = bind(CBrowser.onWhitelistChange, self)
end

---
-- Event: onClientClick | Handle all browser Clicks.. not rly nice.. but.. it works :X
---
function CBrowser:onClick(sButton, sState)
    if sButton == "right" then return end

    if sState == "down" then
        --Check, if the browser was clicked, if not, return all inputs
        if isHover(self.browserStartX, self.browserStartY, self.browserSizeX, self.browserSizeY) then
            self.colors.browserWindow.browser = self.colors.browserWindow.browser_active
            self.isActive = true
            guiSetInputEnabled(false)
        else
            guiSetInputEnabled(true)
            self.colors.browserWindow.browser = self.colors.browserWindow.browser_nonActive
            self.isActive = false
            self.mouseClickActive = false
            self:defocus()
            return
        end

        --If click was in browser, inject click to CEF
        if isHover(self.browserElementStartX, self.browserElementStartY, self.browserSizeX, self.browserSizeY) then
            guiSetInputEnabled(false)
            self.tabs[self.currentTab].browser:injectMouseDown(sButton)
            self.tabs[self.currentTab].browser:focus()
        end

        --if sButton ~= "left" then return end
        if not self.isActive then return end

        --Get current browser size
        self.currentBrowserSize = {self.browserSizeX, self.browserSizeY}
        self.mouseClickActive = true

        --If close button was clicked... R.I.P. Browser
        if sButton == "left" and isHover(self.browserStartX + self.browserSizeX - self.defaultMenuOffset - 40, self.browserStartY, 40, self.menuIconSizeY) then
            self:close()
            return
        end

        if sButton == "left" and isHover(self.browserStartX + self.browserSizeX - self.defaultMenuOffset - 40*2, self.browserStartY, 40, self.menuIconSizeY) then
            self.bypassClicks = true
            self:toggleBrowserSize()
            --self.bypassClicks = false
            return
        end

        --Navigation button: back
        if isHover(self.browserStartX + self.menuOffset + 5 + 36*0, self.browserStartY + self.browserTabHeight + 5, 24, 24) then
            self:navigateBack()
            self.mouseClickActive = false
            return
        end

        --Navigation button: forward
        if isHover(self.browserStartX + self.menuOffset + 5 + 36*1, self.browserStartY + self.browserTabHeight + 5, 24, 24) then
            self:navigateForward()
            self.mouseClickActive = false
            return
        end

        --Navigation button: reload
        if isHover(self.browserStartX + self.menuOffset + 5 + 36*2, self.browserStartY + self.browserTabHeight + 5, 24, 24) then
            self:pageReload()
            self.mouseClickActive = false
            return
        end

        --Navigation button: SpeedDial/start
        if isHover(self.browserStartX + self.menuOffset + 5 + 36*3, self.browserStartY + self.browserTabHeight + 5, 24, 24) then
            --self:pageReload()
            self.mouseClickActive = false
            return
        end


        --Check if a tab was clicked
        for i, tab in ipairs(self.tabs) do
            local tabStartX =  self.browserStartX + self.menuOffset + self.menuIconSizeX + 5 + (self.tabSize*(i-1))

            if sButton == "left" and isHover(tabStartX + self.tabSize - 14 - 5, self.browserStartY + self.tabHeight/2-14/2, 14, 14) then
                self.mouseClickActive = false
                self:closeTab(i)
                return
            end

            if isHover(tabStartX, self.browserStartY, self.tabSize, self.menuIconSizeY + 5) then
                if sButton == "middle" then
                    self.mouseClickActive = false
                    self:closeTab(i)
                    return
                end

                self.currentTab = i
                self.tabChanged = true
                self.mouseClickActive = false
                if tab.resize then
                    self:reloadCurrentTab()
                end

                if self.tabs[self.currentTab].browser:getURL() then
                    self.urlBar:setText(self.tabs[self.currentTab].browser:getURL())
                elseif self.tabs[self.currentTab].URL then
                    self.urlBar:setText(self.tabs[self.currentTab].URL)
                end

                return
            end

            if i == #self.tabs then
                if isHover(tabStartX + self.tabSize + 5, self.browserStartY + 18/2, 18, 18) then
                    self:createTab()
                end
            end
        end

        --If browser bar was clicked, where the browser can be moved
        if isHover(self.browserStartX, self.browserStartY, self.browserSizeX, self.browserTabHeight) then
            self.moving = true
            local cX, cY = getCursorPosition()
            self.diff = {cX*x-self.browserStartX, cY*y-self.browserStartY}
        else
            self.moving = false
        end

        --If the area was clicked to change the size
        if isHover(self.browserStartX + self.browserSizeX - 20, self.browserStartY + self.browserSizeY - 20, 20, 20) then
            self.browserChangingSize = true
        else
            self.browserChangingSize = false
        end
    else
        self.tabs[self.currentTab].browser:injectMouseUp(sButton)
        guiSetInputEnabled(true)
        self.mouseClickActive = false
        if self.currentBrowserSize and (self.currentBrowserSize[1] ~= self.browserSizeX or self.currentBrowserSize[2] ~= self.browserSizeY) then
            if isElement(self.tabs[self.currentTab].browser) then
                self.tabs[self.currentTab].URL = self.tabs[self.currentTab].browser:getURL()
                destroyElement(self.tabs[self.currentTab].browser)
            end

            self.tabs[self.currentTab].browser = Browser(self.browserSizeX - self.menuOffset*2, self.browserSizeY - self.browserTabHeight - self.browserMenuHeight - self.menuOffset, false, false)
            addEventHandler("onClientBrowserCreated", self.tabs[self.currentTab].browser,
                function()
                    --self.tabs[self.currentTab].browser:loadURL(self.tabs[self.currentTab].URL)
                    source:loadURL(self.tabs[self.currentTab].URL)
                end
            )

            for i, tab in ipairs(self.tabs) do
                if i ~= self.currentTab then
                    tab.resize = true
                end
            end
        end
    end
end

---
-- Event: onClientCursorMove | Calculate and inject cursor position | Hover effects
---
function CBrowser:onCursorMove(_, _, nCursorPosX, nCursorPosY)
    if not isCursorShowing() then return end
    if not self.isActive then return end

    if isHover(self.browserElementStartX, self.browserElementStartY, self.browserSizeX, self.browserSizeY) then
        local browser = self.tabs[self.currentTab].browser
        if browser then
            browser:injectMouseMove(nCursorPosX - self.browserElementStartX, nCursorPosY - self.browserElementStartY)
        end
    end

    ---Close Icon
    if isHover(self.browserStartX + self.browserSizeX - self.defaultMenuOffset - 40, self.browserStartY, 40, self.menuIconSizeY) then
        self.colors.browserWindow.close = self.colors.browserWindow.close_hover
        self.colors.browserWindow.closeBackground = self.colors.browserWindow.closeBackground_hover
        return
    else
        self.colors.browserWindow.close = self.colors.browserWindow.close_nonHover
        self.colors.browserWindow.closeBackground = self.colors.browserWindow.closeBackground_nonHover
    end

    ---Maximize Icon
    if isHover(self.browserStartX + self.browserSizeX - self.defaultMenuOffset - 40*2, self.browserStartY, 40, self.menuIconSizeY) then
        self.colors.browserWindow.maximize = self.colors.browserWindow.maximize_hover
        self.colors.browserWindow.maximizeBackground = self.colors.browserWindow.maximizeBackground_hover
        return
    else
        self.colors.browserWindow.maximize = self.colors.browserWindow.maximize_nonHover
        self.colors.browserWindow.maximizeBackground = self.colors.browserWindow.maximizeBackground_nonHover
    end

    ---Favo Icon
    if isHover(self.browserStartX + self.menuOffset + 5 + self.browserSizeX - self.menuOffset*2 - 5*2 - 24, self.browserStartY + self.browserTabHeight + 5, 24, 24) then
        self.colors.favoButton.background = self.colors.favoButton.background_hover
        self.colors.favoButton.icon = self.colors.favoButton.icon_hover
        return
    else
        self.colors.favoButton.background = self.colors.favoButton.background_nonHover
        self.colors.favoButton.icon = self.colors.favoButton.icon_nonHover
    end

    ---Navigation button: back
    if isHover(self.browserStartX + self.menuOffset + 5 + 36*0, self.browserStartY + self.browserTabHeight + 5, 24, 24) then
        self.navigationButtonBackHovered = true
        return
    else
        self.navigationButtonBackHovered = false
    end

    ---Navigation button: forward
    if isHover(self.browserStartX + self.menuOffset + 5 + 36*1, self.browserStartY + self.browserTabHeight + 5, 24, 24) then
        self.navigationButtonForwardHovered = true
        return
    else
        self.navigationButtonForwardHovered = false
    end

    ---Navigation button: reloads
    if isHover(self.browserStartX + self.menuOffset + 5 + 36*2, self.browserStartY + self.browserTabHeight + 5, 24, 24) then
        self.navigationButtonReloadHovered = true
        return
    else
        self.navigationButtonReloadHovered = false
    end

    ---Navigation button: SpeedDial/start
    if isHover(self.browserStartX + self.menuOffset + 5 + 36*3, self.browserStartY + self.browserTabHeight + 5, 24, 24) then
        self.navigationButtonHomeHovered = true
        return
    else
        self.navigationButtonHomeHovered = false
    end

    ---Tabs
    for i, tab in ipairs(self.tabs) do
        local tabStartX =  self.browserStartX + self.menuOffset + self.menuIconSizeX + 5 + (self.tabSize*(i-1))

        if isHover(tabStartX + self.tabSize - 14 - 5, self.browserStartY + self.tabHeight/2-14/2, 14, 14) then
            self.tabCloseHoveredIndex = i

            self.colors.tabs.closeBackground = self.colors.tabs.closeBackground_hover
            self.colors.tabs.close = self.colors.tabs.close_hover
            return
        else
            self.colors.tabs.closeBackground = self.colors.tabs.closeBackground_nonHover
            self.colors.tabs.close = self.colors.tabs.close_nonHover
        end

        if i == #self.tabs then
            if isHover(tabStartX + self.tabSize + 2, self.browserStartY + 2, 18, 18) then
                self.colors.tabs.newTab = self.colors.tabs.newTab_hover
                return
            else
                self.colors.tabs.newTab = self.colors.tabs.newTab_nonHover
            end
        end
    end
end

---
-- Event: onClientKey | Vertical scrolling
---
function CBrowser:onClientKey(sButton, bState)
    if bState and sButton == "enter" then
        if self.urlBar.clicked then
            local navigateTo = self.urlBar:getText()
			if not navigateTo:find("http://") or not navigateTo:find("https://") then
				navigateTo = "http://"..navigateTo
			end
            self:loadURL(navigateTo)
        end
        return
    end

    if sButton == "mouse_wheel_down" or sButton == "mouse_wheel_up" then
        --Todo: Interpolation
        local browser = self.tabs[self.currentTab].browser
        if browser then
            local scrollDirection = sButton == "mouse_wheel_up" and 1 or -1
            browser:injectMouseWheel(scrollDirection*80, 0)
        end
    end
end

---
-- Event: onClientBrowserNavigate | If the navigated url is blocked (not in whitelist), request the domain
---
function CBrowser:onBrowserNavigate(sURL, bBlocked)
    if bBlocked then
        --Todo: Color the URL bar red for some seconds
        Browser.requestDomains({sURL}, true)
        return
    end
end

---
-- Event: onClientBrowserDocumentReady | Save the navigated urls for history
---
function CBrowser:onDocumentReady(sURL)
    self.urlBar:setText(sURL)
    local currentTab = self.tabs[self.currentTab]
    if currentTab.history[currentTab.historyIndex] == sURL then
        return
    end

    if currentTab.historyIndex < #currentTab.history then
        for i = #currentTab.history, currentTab.historyIndex + 1, -1 do
            table.remove(currentTab.history, i)
        end
    end

    table.insert(currentTab.history, sURL)
    currentTab.historyIndex = #currentTab.history
end


---
-- Event: onClientBrowserWhitelistChange | Reload the current tab if the URL got whitelisted
---

function CBrowser:onWhitelistChange(tblGrantedURLs)
	local sURL = self.tabs[self.currentTab].previousBlockedURL
	if sURL then
		for i, v in pairs(tblGrantedURLs) do
			if sURL:gfind(v) then
				outputChatBox(sURL)
				self.tabs[self.currentTab].URL = sURL
				self:reloadCurrentTab()
			end
		end
	end
end

---
-- Todo: navigateTO
---
function CBrowser:navigateTo(_, sNavigateTo)
    if not self.isActive then return end
    if Browser.isDomainBlocked(sNavigateTo, true) then
		Browser.requestDomains({sNavigateTo}, true)
        outputChatBox("Returned: Domain is blocked!")
		self.tabs[self.currentTab].previousBlockedURL = sNavigateTo
        return
    end

    self:loadURL(sNavigateTo)
end

function CBrowser:navigateBack()
    local currentTab = self.tabs[self.currentTab]

    if currentTab.historyIndex <= 1 then return end

    currentTab.historyIndex = currentTab.historyIndex - 1
    local url = currentTab.history[currentTab.historyIndex]
    self:loadURL(url)
end

function CBrowser:navigateForward()
    local currentTab = self.tabs[self.currentTab]

    if currentTab.historyIndex >= #currentTab.history then return end

    currentTab.historyIndex = currentTab.historyIndex + 1
    local url = currentTab.history[currentTab.historyIndex]
    self:loadURL(url)
end

function CBrowser:pageReload()
    local currentTab = self.tabs[self.currentTab]
    local url = currentTab.history[currentTab.historyIndex]
    self:loadURL(url)
end

---
-- Todo: toggleBrowser
---
function CBrowser:toggleBrowser()
    if self.isVisible then
        self.isVisible = false
        removeEventHandler("onClientPreRender", root, self.preRenderFunc)
        removeEventHandler("onClientRender", root, self.renderFunc)
        removeEventHandler("onClientClick", root, self.onClickFunc)
        removeEventHandler("onClientCursorMove", root, self.cursorMoveFunc)
        removeEventHandler("onClientKey", root, self.clientKeyFunc)
        removeEventHandler("onClientBrowserNavigate", root, self.navigateFunc)
        removeEventHandler("onClientBrowserDocumentReady", root, self.documentReadyFunc)
        removeEventHandler("onClientBrowserWhitelistChange", root, self.whitelistChangeFunc)
        showCursor(false)
        return
    end

    if not self.isVisible then
        self.isVisible = true
        addEventHandler("onClientPreRender", root, self.preRenderFunc)
        addEventHandler("onClientRender", root, self.renderFunc)
        addEventHandler("onClientClick", root, self.onClickFunc)
        addEventHandler("onClientCursorMove", root, self.cursorMoveFunc)
        addEventHandler("onClientKey", root, self.clientKeyFunc)
        addEventHandler("onClientBrowserNavigate", root, self.navigateFunc)
        addEventHandler("onClientBrowserDocumentReady", root, self.documentReadyFunc)
        addEventHandler("onClientBrowserWhitelistChange", root, self.whitelistChangeFunc)
        showCursor(true)
        return
    end
end

---
-- Todo: toggleBrowserSize
---
function CBrowser:toggleBrowserSize()
    if self.isMaximized then
        if self.lastMinimizedPosition then
            self.moveDelay = getTickCount() + 200
            self.browserStartX = self.lastMinimizedPosition.startX
            self.browserStartY = self.lastMinimizedPosition.startY
            self.browserSizeX = self.lastMinimizedPosition.sizeX
            self.browserSizeY = self.lastMinimizedPosition.sizeY
        else
            self.browserSizeX = self.browserDefaultSizeX/1920*x
            self.browserSizeY = self.browserDefaultSizeY/1080*y
            self.browserStartX = x/2-self.browserSizeX/2
            self.browserStartY = y/2-self.browserSizeY/2
        end
        self.isMaximized = false
        self.menuOffset = self.defaultMenuOffset

        self.urlBar:setProperty("w", - 36*4 + self.browserSizeX - self.menuOffset*2 - 5*2)
		self:calculateTabSize()
        return
    end

    if not self.isMaximized then
        self.lastMinimizedPosition = {startX = self.browserStartX, startY = self.browserStartY, sizeX = self.browserSizeX, sizeY = self.browserSizeY}
        self.browserStartX = 0
        self.browserStartY = 0
        self.browserSizeX = x
        self.browserSizeY = y
        self.isMaximized = true
        self.menuOffset = 0

        self.urlBar:setProperty("w", - 36*4 + self.browserSizeX - self.menuOffset*2 - 5*2)
		self:calculateTabSize()
        return
    end
end

---
-- Todo: close
---
function CBrowser:close()
    for _, tab in ipairs(self.tabs) do
        if isElement(tab.browser) then
            tab.browser:destroy()
        end
    end

    self:destructor()
end

---
-- LoadURL
---
function CBrowser:loadURL(sURL)
    --self.tabs[self.currentTab].URL = sURL
    if Browser.isDomainBlocked(sURL, true) then
        outputChatBox(sURL.." is blocked")
		Browser.requestDomains({sURL}, true)
		self.tabs[self.currentTab].previousBlockedURL = sURL
        return
    end
    self.tabs[self.currentTab].browser:loadURL(sURL)
end

---
-- Returns the windows position
---
function CBrowser:getPosition()
    return self.browserStartX, self.browserStartY
end

---
-- Reload tab; re create browser element to fix size and load last known website
----
function CBrowser:reloadCurrentTab()
    self.tabs[self.currentTab].resize = false
    if isElement(self.tabs[self.currentTab].browser) then
        destroyElement(self.tabs[self.currentTab].browser)
    end
    self.tabs[self.currentTab].browser = Browser(self.browserSizeX - self.menuOffset*2, self.browserSizeY - self.browserTabHeight - self.browserMenuHeight - self.menuOffset, false, false)
    addEventHandler("onClientBrowserCreated", self.tabs[self.currentTab].browser,
        function()
            source:loadURL(self.tabs[self.currentTab].URL)
            self.urlBar:setText(self.tabs[self.currentTab].URL)
        end
    )
end

---
-- Create tab; create browser element and navigate to default website
----
function CBrowser:createTab()
    --Check tab limit
    local maxTabCount = tonumber(Core:getManager("CBrowserManager").tBrowserDefinitions.maxTabCount)
    if maxTabCount and maxTabCount ~= 0 and #self.tabs >= maxTabCount then
        return
    end

    --Create the Tab
    local tab = {}

    tab.history = {}
    tab.historyIndex = 0
    tab.browser = Browser(self.browserSizeX - self.menuOffset*2, self.browserSizeY - self.browserTabHeight - self.browserMenuHeight - self.menuOffset, false, false)
    if not tab.browser then outputChatBox("Anything is going wrong!") return end
    addEventHandler("onClientBrowserCreated", tab.browser,
        function()
            --ToDo: Set default/home page local
            tab.URL = "http://pewx.de/res/pab/index.htm"
            tab.browser:loadURL(tab.URL)
            self:calculateTabSize()
        end
    )

    table.insert(self.tabs, tab)
    self.currentTab = #self.tabs
end

---
-- Close tab; if only one tab open, load default page | If necessary, select a new valid tab, and close the "old" one | Let resize tabs
---
function CBrowser:closeTab(nTabIndex)
    if #self.tabs <= 1 then self.tabs[1].browser:loadURL("http://pewx.de/res/pab/index.htm") return end

    local browser = self.tabs[nTabIndex].browser
    if browser then browser:destroy() end

    if self.currentTab == nTabIndex then
        if #self.tabs == nTabIndex then
            self.currentTab = self.currentTab - 1
        end
    else
        if self.currentTab > #self.tabs - 1 then
            self.currentTab = #self.tabs - 1
        end
    end

    table.remove(self.tabs, nTabIndex)

    if self.tabs[self.currentTab].resize then
        self:reloadCurrentTab()
    end

    self:calculateTabSize()
end

---
-- Calculate tab size, to fit all tabs in browser window
---
function CBrowser:calculateTabSize()
    --The first tab start at this point:
    local tabStartX = self.browserStartX + self.menuOffset + self.menuIconSizeX + 5
    --A tab has to stop at this point:
    local tabStopX = self.browserStartX + self.browserSizeX - self.defaultMenuOffset - 150
    --Substract startX from stopX to get the max tab range
    local maxTabRange = tabStopX - tabStartX

    if #self.tabs*self.tabSize > maxTabRange then
        self.tabSize = maxTabRange/#self.tabs
    else
        if #self.tabs*self.defaultTabSize > maxTabRange then
            self.tabSize = maxTabRange/#self.tabs
        else
            self.tabSize = self.defaultTabSize
        end
    end
end

---
-- Let us render the browser
---
function CBrowser:renderBrowser()
    local bx, by = self.browserStartX, self.browserStartY   --Shortcut for browser start position

    --Main Window
    dxDrawRectangle(bx, by, self.browserSizeX, self.browserSizeY, self.colors.browserWindow.browser)

    --Navigation bar bar for navigation elements
    dxDrawRectangle(bx + self.menuOffset, by + self.browserTabHeight, self.browserSizeX  - self.menuOffset*2, self.browserMenuHeight, self.colors.browserWindow.navigationBar)

    --Menu Button
    dxDrawImage(bx + self.menuOffset, by, self.menuIconSizeX, self.menuIconSizeY, "res/img/menu.png")
    --dxDrawRectangle(bx + self.menuOffset, by, self.menuIconSizeX, self.menuIconSizeY, tocolor(240, 240, 240))

    --Window buttons
    dxDrawRectangle(bx + self.browserSizeX - self.defaultMenuOffset - 40, by, 40, self.menuIconSizeY, self.colors.browserWindow.closeBackground)            --Close
    dxDrawRectangle(bx + self.browserSizeX - self.defaultMenuOffset - 40*2, by, 40, self.menuIconSizeY, self.colors.browserWindow.maximizeBackground)       --Maximize
    dxDrawImage(bx + self.browserSizeX - self.defaultMenuOffset - 40/2-18/2, by + self.menuIconSizeY/2-18/2, 18, 18, "res/img/close.png", 0, 0, 0, self.colors.browserWindow.close)
    dxDrawImage(bx + self.browserSizeX - self.defaultMenuOffset - 40 - 40/2-18/2, by + self.menuIconSizeY/2-18/2, 18, 18, "res/img/maximize.png", 0, 0, 0, self.colors.browserWindow.maximize)

    --Buttons (back, forward, refresh, home, favo)
    local mbx, mby = bx + self.menuOffset + 5, self.browserStartY + self.browserTabHeight --Start positions for menu buttons (tabBrowserX/Y)
    dxDrawImage(mbx + 36*0, mby + 5, 24, 24, "res/img/back.png", 0, 0, 0, tocolor(120, 120, 120))
    dxDrawImage(mbx + 36*1, mby + 5, 24, 24, "res/img/forward.png", 0, 0, 0, tocolor(120, 120, 120))
	if isBrowserLoading(self.tabs[self.currentTab].browser) then
	    dxDrawImage(mbx + 36*2, mby + 5, 24, 24, "res/img/refresh.png", (getTickCount()/2)%360, 0, 0, tocolor(120, 120, 120))
	else
		dxDrawImage(mbx + 36*2, mby + 5, 24, 24, "res/img/refresh.png", 0, 0, 0, tocolor(120, 120, 120))
	end
    dxDrawImage(mbx + 36*3, mby + 5, 24, 24, "res/img/home.png", 0, 0, 0, tocolor(120, 120, 120))

    local itemTable = {"navigationButtonBackHovered", "navigationButtonForwardHovered", "navigationButtonReloadHovered", "navigationButtonHomeHovered"}
    for i, itemName in ipairs(itemTable) do
        if self[itemName] then
            dxDrawLine(mbx + 36*(i-1), mby + 5, mbx+ 36*(i-1) + 24, mby + 5, self.colors.browserWindow.lines)
            dxDrawLine(mbx + 36*(i-1), mby + 5 + 24, mbx+ 36*(i-1) + 24, mby + 5 + 24, self.colors.browserWindow.lines)
            dxDrawLine(mbx + 36*(i-1), mby + 5, mbx+ 36*(i-1), mby + 5 + 24, self.colors.browserWindow.lines)
            dxDrawLine(mbx + 36*(i-1) + 24, mby + 5, mbx+ 36*(i-1) + 24, mby + 5 + 24, self.colors.browserWindow.lines)
        end
    end

    --URL edir bar
    dxDrawRectangle(mbx + 36*4, mby + 5,  - 36*4 + self.browserSizeX - self.menuOffset*2 - 5*2, 24, self.urlColor)
    self.urlBar:render()

    --Favo image
    dxDrawRectangle(mbx + self.browserSizeX - self.menuOffset*2 - 5*2 - 24, mby + 5, 24, 24, self.colors.favoButton.background)
    dxDrawImage(mbx + self.browserSizeX - self.menuOffset*2 - 5*2 - 21, mby + 5 + 3, 18, 18, "res/img/favo.png", 0, 0, 0, self.colors.favoButton.icon)

    local lineColor = tocolor(160, 160, 160)
    dxDrawLine(mbx + 36*4, mby + 5, - 36*4 + self.browserSizeX - self.menuOffset*2 - 5*2 + mbx + 36*4, mby + 5, lineColor)
    dxDrawLine(mbx + 36*4, mby + 5 + 24, - 36*4 + self.browserSizeX - self.menuOffset*2 - 5*2 + mbx + 36*4, mby + 5 + 24, lineColor)
    dxDrawLine(mbx + 36*4,  mby + 5, mbx + 36*4, mby + 5 + 24, lineColor)
    dxDrawLine(- 36*4 + self.browserSizeX - self.menuOffset*2 - 5*2 + mbx + 36*4, mby + 5, - 36*4 + self.browserSizeX - self.menuOffset*2 - 5*2 + mbx + 36*4, mby + 5 + 24, lineColor)
    dxDrawLine(- 36*4 + self.browserSizeX - self.menuOffset*2 - 5*2 + mbx + 36*4 - 24, mby + 5, - 36*4 + self.browserSizeX - self.menuOffset*2 - 5*2 + mbx + 36*4 - 24, mby + 5 + 24, lineColor)

    --Draw some awesome epic supi dupi lines :>
    --Upper line for menu bar, draw from left window to first tab
    local lpfat = bx + self.menuOffset + self.menuIconSizeX + 6 + (self.tabSize*(self.currentTab-1)) --left position from active tab
    dxDrawLine(bx + self.menuOffset, by + self.browserTabHeight, lpfat, by + self.browserTabHeight, self.colors.browserWindow.lines)

    --Upper line for menu bar, draw from active tab to right window
    local rpfat = bx + self.menuOffset + self.menuIconSizeX + 5 + (self.tabSize*(self.currentTab))  --right position from active tab
    dxDrawLine(rpfat, by + self.browserTabHeight, bx + self.menuOffset + self.browserSizeX  - self.menuOffset*2, by + self.browserTabHeight, self.colors.browserWindow.lines)

    --Lower line for menu bar, draw from left window to right window
    dxDrawLine(bx + self.menuOffset, by + self.browserTabHeight + self.browserMenuHeight - 1, bx + self.menuOffset + self.browserSizeX  - self.menuOffset*2, by + self.browserTabHeight + self.browserMenuHeight - 1, self.colors.browserWindow.lines, 1)

    --Draw Tabs
    local tx, ty = bx + self.menuOffset + self.menuIconSizeX + 5, by
    for i, tab in ipairs(self.tabs) do
        local tabStartX = tx + (self.tabSize*(i-1))
        local tabColor = i == self.currentTab and self.colors.tabs.tab_active or self.colors.tabs.tab_nonActive

        dxDrawRectangle(tabStartX, ty, self.tabSize, self.menuIconSizeY + 5, tabColor)
        dxDrawLine(tabStartX, ty, tabStartX, ty + self.menuIconSizeY + 5, self.colors.browserWindow.lines)
        dxDrawText(tostring(tab.browser:getTitle()), tabStartX + 5, ty, tabStartX + self.tabSize - 14 - 5*2, ty + self.menuIconSizeY + 5, tocolor(0, 0, 0), 1, "default", "left", "center", true)

        --Close button
        if self.tabCloseHoveredIndex == i and self.colors.tabs.closeBackground then
            dxDrawRectangle(tabStartX + self.tabSize - 14 - 5, ty + self.tabHeight/2-14/2, 14, 14, self.colors.tabs.closeBackground)
        end
        dxDrawImage(tabStartX + self.tabSize - 14 - 5, ty + self.tabHeight/2-14/2, 14, 14, "res/img/close.png", 0, 0, 0, self.tabCloseHoveredIndex == i and self.colors.tabs.close or self.colors.tabs.close_nonHover)

        if i == #self.tabs then
            dxDrawLine(tabStartX + self.tabSize, ty, tabStartX + self.tabSize, ty + self.menuIconSizeY + 5, self.colors.browserWindow.lines)
            --Draw 'createTab' image
            dxDrawImage(tabStartX + self.tabSize + 5, ty + self.tabHeight/2-18/2, 18, 18, "res/img/create_tab.png", 0, 0, 0, self.colors.tabs.newTab)
        end
    end

    --Last but not least.. render browser^^.
    self.browserElementStartX = bx + self.menuOffset
    self.browserElementStartY = by + self.browserTabHeight + self.browserMenuHeight
    dxDrawImage(self.browserElementStartX, self.browserElementStartY, self.browserSizeX - self.menuOffset*2, self.browserSizeY - self.browserTabHeight - self.browserMenuHeight - self.menuOffset, self.tabs[self.currentTab].browser)
end

---
-- Pre Rendering for browser position/size
---
function CBrowser:preRenderBrowser()
    --If the browser is maximized, end here and do not change position/size
    if self.isMaximized then return end

    if self.mouseClickActive then
        if self.moveDelay and getTickCount() < self.moveDelay then self.mouseClickActive = false return end

        if self.moving then
            local cX, cY = getCursorPosition()
            self.browserStartX, self.browserStartY = cX*x-self.diff[1], cY*y-self.diff[2]
            -- self.browserElementStartX = self.browserSizeX - self.menuOffset*2
            -- self.browserElementStartY = self.browserSizeY - self.browserTabHeight - self.browserMenuHeight - self.menuOffset
        end

        if self.browserChangingSize then
            local fx, fy = getCursorPosition()
            local x, y = fx*x, fy*y
            local tmpX, tmpY = x - self.browserStartX, y - self.browserStartY


            if tmpX < 400 then
                tmpX = 400
            end

            if tmpY < 150 then
                tmpY = 150
            end

            self.browserSizeX = tmpX
            self.browserSizeY = tmpY

            self.urlBar:setProperty("w", - 36*4 + self.browserSizeX - self.menuOffset*2 - 5*2)

            self:calculateTabSize()
        end
    end
end

---
-- A workaround to defocus the browser
---
function CBrowser:defocus()
    focusBrowser(nil)
    --[[local browser = createBrowser(0, 0, true, true)
    browser:focus()
    destroyElement(browser)]]
end
