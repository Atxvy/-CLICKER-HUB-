--!strict
--==============================================================================
-- [CLICKER HUB] UI Library
-- Sleek Electric Purple Dark Glass UI Framework for Clicker Simulator
-- Designed for Desktop & Mobile executor environments
--==============================================================================

local UILibrary = {}
UILibrary.__index = UILibrary

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

local function getRootGui(): Instance
    local lp = LocalPlayer or Players.LocalPlayer or Players.PlayerAdded:Wait()
    local pg = lp and (lp:FindFirstChildOfClass("PlayerGui") or lp:WaitForChild("PlayerGui", 5))
    if pg then return pg end
    if gethui then
        local ok, h = pcall(gethui)
        if ok and h then return h end
    end
    local ok, cg = pcall(function() return game:GetService("CoreGui") end)
    if ok and cg then return cg end
    return pg
end

local function tween(inst: Instance, info: TweenInfo, props: {[string]: any})
    local t = TweenService:Create(inst, info, props)
    t:Play()
    return t
end

function UILibrary.CreateWindow(...)
    local args = {...}
    local config = {}
    for _, arg in ipairs(args) do
        if type(arg) == "table" and arg ~= UILibrary then
            config = arg
            break
        end
    end

    local Title = config.Title or "CLICKER SIMULATOR — AUTO PROGRESSION"
    local SubTitle = config.SubTitle or config.Subtitle or "Zero-To-Hero Speedrun Engine [AUTOPROG]"
    local ToggleKey = config.ToggleKey or Enum.KeyCode.RightControl
    local camera = workspace.CurrentCamera
    local vp = camera and camera.ViewportSize or Vector2.new(1920, 1080)
    
    local targetWidth = 700
    local targetHeight = 520
    if config.Size and typeof(config.Size) == "UDim2" then
        targetWidth = config.Size.X.Offset
        targetHeight = config.Size.Y.Offset
    end
    local maxWidth = math.clamp(math.floor(vp.X - 24), 300, targetWidth)
    local maxHeight = math.clamp(math.floor(vp.Y - 36), 260, targetHeight)
    local Size = UDim2.new(0, maxWidth, 0, maxHeight)
    local Connections = {}

    -- Clean up previous instances across all potential roots
    pcall(function()
        if gethui then
            local ok, h = pcall(gethui)
            if ok and h and h:FindFirstChild("ClickerHub_UI") then
                h.ClickerHub_UI:Destroy()
            end
        end
        local ok, cg = pcall(function() return game:GetService("CoreGui") end)
        if ok and cg then
            local oldCg = cg:FindFirstChild("ClickerHub_UI", true)
            if oldCg then oldCg:Destroy() end
        end
        if LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui") then
            local oldPg = LocalPlayer.PlayerGui:FindFirstChild("ClickerHub_UI")
            if oldPg then oldPg:Destroy() end
        end
    end)

    local root = getRootGui()

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "ClickerHub_UI"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.DisplayOrder = 999999
    ScreenGui:SetAttribute("Immune", true)
    ScreenGui:SetAttribute("NoScaling", true)
    -- Parent to root FIRST, then set Enabled = true so game engine does not suppress it
    ScreenGui.Parent = root
    ScreenGui.Enabled = true

    -- Notifications Overlay Frame
    local NotifContainer = Instance.new("Frame")
    NotifContainer.Name = "Notifications"
    NotifContainer.Size = UDim2.new(0, 260, 1, -20)
    NotifContainer.Position = UDim2.new(1, -270, 0, 10)
    NotifContainer.BackgroundTransparency = 1
    NotifContainer.ZIndex = 100
    NotifContainer.Parent = ScreenGui

    local NotifLayout = Instance.new("UIListLayout")
    NotifLayout.SortOrder = Enum.SortOrder.LayoutOrder
    NotifLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
    NotifLayout.Padding = UDim.new(0, 8)
    NotifLayout.Parent = NotifContainer

    -- Main Frame (Electric Purple Dark Glass - perfectly centered)
    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    MainFrame.Size = Size
    MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    MainFrame.BackgroundColor3 = Color3.fromRGB(18, 15, 25)
    MainFrame.BorderSizePixel = 0
    MainFrame.ClipsDescendants = false
    MainFrame.Visible = true
    MainFrame.Parent = ScreenGui

    local MainCorner = Instance.new("UICorner")
    MainCorner.CornerRadius = UDim.new(0, 10)
    MainCorner.Parent = MainFrame

    local MainStroke = Instance.new("UIStroke")
    MainStroke.Color = Color3.fromRGB(85, 45, 125)
    MainStroke.Thickness = 1.2
    MainStroke.Transparency = 0.35
    MainStroke.Parent = MainFrame

    -- Top Header Bar
    local Header = Instance.new("Frame")
    Header.Name = "Header"
    Header.Size = UDim2.new(1, 0, 0, 42)
    Header.BackgroundColor3 = Color3.fromRGB(25, 20, 35)
    Header.BorderSizePixel = 0
    Header.Parent = MainFrame

    local HeaderCorner = Instance.new("UICorner")
    HeaderCorner.CornerRadius = UDim.new(0, 10)
    HeaderCorner.Parent = Header

    -- Fix bottom roundness of header
    local HeaderCover = Instance.new("Frame")
    HeaderCover.Size = UDim2.new(1, 0, 0, 10)
    HeaderCover.Position = UDim2.new(0, 0, 1, -10)
    HeaderCover.BackgroundColor3 = Color3.fromRGB(25, 20, 35)
    HeaderCover.BorderSizePixel = 0
    HeaderCover.Parent = Header

    local TitleLabel = Instance.new("TextLabel")
    TitleLabel.Name = "Title"
    TitleLabel.Size = UDim2.new(1, -90, 1, 0)
    TitleLabel.Position = UDim2.new(0, 16, 0, 0)
    TitleLabel.BackgroundTransparency = 1
    TitleLabel.Text = Title .. "  <font color=\"rgb(140,130,165)\">|</font>  <font color=\"rgb(192,132,252)\">" .. SubTitle .. "</font>"
    TitleLabel.RichText = true
    TitleLabel.TextColor3 = Color3.fromRGB(245, 240, 255)
    TitleLabel.TextSize = 15
    TitleLabel.Font = Enum.Font.GothamBold
    TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
    TitleLabel.Parent = Header

    -- Close & Minimize Buttons
    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Name = "CloseBtn"
    CloseBtn.Size = UDim2.new(0, 30, 0, 30)
    CloseBtn.Position = UDim2.new(1, -36, 0.5, -15)
    CloseBtn.BackgroundColor3 = Color3.fromRGB(38, 30, 50)
    CloseBtn.BackgroundTransparency = 1
    CloseBtn.Text = "✕"
    CloseBtn.TextColor3 = Color3.fromRGB(190, 180, 205)
    CloseBtn.TextSize = 14
    CloseBtn.Font = Enum.Font.GothamBold
    CloseBtn.Parent = Header

    local CloseCorner = Instance.new("UICorner")
    CloseCorner.CornerRadius = UDim.new(0, 6)
    CloseCorner.Parent = CloseBtn

    local MinBtn = Instance.new("TextButton")
    MinBtn.Name = "MinBtn"
    MinBtn.Size = UDim2.new(0, 30, 0, 30)
    MinBtn.Position = UDim2.new(1, -70, 0.5, -15)
    MinBtn.BackgroundColor3 = Color3.fromRGB(38, 30, 50)
    MinBtn.BackgroundTransparency = 1
    MinBtn.Text = "─"
    MinBtn.TextColor3 = Color3.fromRGB(190, 180, 205)
    MinBtn.TextSize = 14
    MinBtn.Font = Enum.Font.GothamBold
    MinBtn.Parent = Header

    local MinCorner = Instance.new("UICorner")
    MinCorner.CornerRadius = UDim.new(0, 6)
    MinCorner.Parent = MinBtn

    -- Hover effects
    CloseBtn.MouseEnter:Connect(function() tween(CloseBtn, TweenInfo.new(0.15), {BackgroundTransparency = 0, TextColor3 = Color3.fromRGB(255, 90, 100)}) end)
    CloseBtn.MouseLeave:Connect(function() tween(CloseBtn, TweenInfo.new(0.15), {BackgroundTransparency = 1, TextColor3 = Color3.fromRGB(190, 180, 205)}) end)
    MinBtn.MouseEnter:Connect(function() tween(MinBtn, TweenInfo.new(0.15), {BackgroundTransparency = 0, TextColor3 = Color3.fromRGB(245, 240, 255)}) end)
    MinBtn.MouseLeave:Connect(function() tween(MinBtn, TweenInfo.new(0.15), {BackgroundTransparency = 1, TextColor3 = Color3.fromRGB(190, 180, 205)}) end)

    local BodyFrame = Instance.new("Frame")
    BodyFrame.Name = "Body"
    BodyFrame.Size = UDim2.new(1, 0, 1, -42)
    BodyFrame.Position = UDim2.new(0, 0, 0, 42)
    BodyFrame.BackgroundTransparency = 1
    BodyFrame.Parent = MainFrame

    -- Sidebar for Tabs
    local Sidebar = Instance.new("Frame")
    Sidebar.Name = "Sidebar"
    Sidebar.Size = UDim2.new(0, 160, 1, 0)
    Sidebar.BackgroundColor3 = Color3.fromRGB(20, 17, 28)
    Sidebar.BorderSizePixel = 0
    Sidebar.Parent = BodyFrame

    local SidebarCorner = Instance.new("UICorner")
    SidebarCorner.CornerRadius = UDim.new(0, 10)
    SidebarCorner.Parent = Sidebar

    local SidebarDivider = Instance.new("Frame")
    SidebarDivider.Size = UDim2.new(0, 1, 1, 0)
    SidebarDivider.Position = UDim2.new(1, -1, 0, 0)
    SidebarDivider.BackgroundColor3 = Color3.fromRGB(45, 35, 60)
    SidebarDivider.BorderSizePixel = 0
    SidebarDivider.Parent = Sidebar

    local TabContainer = Instance.new("ScrollingFrame")
    TabContainer.Name = "TabContainer"
    TabContainer.Size = UDim2.new(1, 0, 1, -16)
    TabContainer.Position = UDim2.new(0, 0, 0, 8)
    TabContainer.BackgroundTransparency = 1
    TabContainer.ScrollBarThickness = 2
    TabContainer.ScrollBarImageColor3 = Color3.fromRGB(80, 55, 110)
    TabContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y
    TabContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
    TabContainer.Parent = Sidebar

    local TabLayout = Instance.new("UIListLayout")
    TabLayout.SortOrder = Enum.SortOrder.LayoutOrder
    TabLayout.Padding = UDim.new(0, 4)
    TabLayout.Parent = TabContainer

    TabLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        TabContainer.CanvasSize = UDim2.new(0, 0, 0, TabLayout.AbsoluteContentSize.Y + 20)
    end)

    local TabPadding = Instance.new("UIPadding")
    TabPadding.PaddingLeft = UDim.new(0, 8)
    TabPadding.PaddingRight = UDim.new(0, 8)
    TabPadding.Parent = TabContainer

    -- Content Area
    local ContentArea = Instance.new("Frame")
    ContentArea.Name = "ContentArea"
    ContentArea.Size = UDim2.new(1, -160, 1, 0)
    ContentArea.Position = UDim2.new(0, 160, 0, 0)
    ContentArea.BackgroundTransparency = 1
    ContentArea.ClipsDescendants = true
    ContentArea.Parent = BodyFrame

    -- Toggle State
    local isMinimized = false
    local function setMinimized(state)
        isMinimized = state
        if isMinimized then
            BodyFrame.Visible = false
            MinBtn.Text = "＋"
            MinBtn.TextColor3 = Color3.fromRGB(192, 132, 252)
            tween(MainFrame, TweenInfo.new(0.2), {Size = UDim2.new(0, Size.X.Offset, 0, 42)})
        else
            MinBtn.Text = "─"
            MinBtn.TextColor3 = Color3.fromRGB(190, 180, 205)
            tween(MainFrame, TweenInfo.new(0.2), {Size = Size})
            task.delay(0.2, function()
                if not isMinimized then BodyFrame.Visible = true end
            end)
        end
    end

    MinBtn.MouseButton1Click:Connect(function()
        setMinimized(not isMinimized)
    end)
    MinBtn.TouchTap:Connect(function()
        setMinimized(not isMinimized)
    end)

    -- Draggable Window (Only by clicking the Header bar)
    local headerDragging = false
    local headerDragStart, headerStartPos
    Header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if isMinimized then
                setMinimized(false)
            end
            headerDragging = true
            headerDragStart = input.Position
            headerStartPos = MainFrame.Position

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    headerDragging = false
                end
            end)
        end
    end)
    table.insert(Connections, UserInputService.InputChanged:Connect(function(input)
        if headerDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - headerDragStart
            MainFrame.Position = UDim2.new(headerStartPos.X.Scale, headerStartPos.X.Offset + delta.X, headerStartPos.Y.Scale, headerStartPos.Y.Offset + delta.Y)
        end
    end))

    -- Floating Mobile Toggle Button (Draggable & Accessible on all devices)
    local FloatingBtn = Instance.new("ImageButton")
    FloatingBtn.Name = "FloatingToggleBtn"
    FloatingBtn.Size = UDim2.new(0, 44, 0, 44)
    FloatingBtn.Position = UDim2.new(0, 16, 0.45, 0)
    FloatingBtn.BackgroundColor3 = Color3.fromRGB(28, 20, 44)
    FloatingBtn.BorderSizePixel = 0
    FloatingBtn.ZIndex = 10000
    FloatingBtn.Parent = ScreenGui

    local FloatCorner = Instance.new("UICorner")
    FloatCorner.CornerRadius = UDim.new(1, 0)
    FloatCorner.Parent = FloatingBtn

    local FloatStroke = Instance.new("UIStroke")
    FloatStroke.Color = Color3.fromRGB(168, 85, 247)
    FloatStroke.Thickness = 1.8
    FloatStroke.Parent = FloatingBtn

    local FloatIcon = Instance.new("TextLabel")
    FloatIcon.Size = UDim2.new(1, 0, 1, 0)
    FloatIcon.BackgroundTransparency = 1
    FloatIcon.Text = "⚡"
    FloatIcon.TextSize = 20
    FloatIcon.TextColor3 = Color3.fromRGB(245, 240, 255)
    FloatIcon.Parent = FloatingBtn

    -- Draggable Floating Button
    local floatDragging = false
    local floatDragStart, floatStartPos
    FloatingBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            floatDragging = true
            floatDragStart = input.Position
            floatStartPos = FloatingBtn.Position

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    floatDragging = false
                end
            end)
        end
    end)
    table.insert(Connections, UserInputService.InputChanged:Connect(function(input)
        if floatDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - floatDragStart
            FloatingBtn.Position = UDim2.new(floatStartPos.X.Scale, floatStartPos.X.Offset + delta.X, floatStartPos.Y.Scale, floatStartPos.Y.Offset + delta.Y)
        end
    end))

    local function toggleUI()
        MainFrame.Visible = not MainFrame.Visible
        ScreenGui.Enabled = true
        if MainFrame.Visible then
            if isMinimized then
                setMinimized(false)
            end
            tween(FloatingBtn, TweenInfo.new(0.15), {BackgroundTransparency = 0.5})
        else
            tween(FloatingBtn, TweenInfo.new(0.15), {BackgroundTransparency = 0})
        end
    end

    FloatingBtn.MouseButton1Click:Connect(toggleUI)
    FloatingBtn.TouchTap:Connect(toggleUI)

    CloseBtn.MouseButton1Click:Connect(function()
        MainFrame.Visible = false
        tween(FloatingBtn, TweenInfo.new(0.15), {BackgroundTransparency = 0})
    end)
    CloseBtn.TouchTap:Connect(function()
        MainFrame.Visible = false
        tween(FloatingBtn, TweenInfo.new(0.15), {BackgroundTransparency = 0})
    end)

    -- Toggle Hotkey
    table.insert(Connections, UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end
        if input.KeyCode == ToggleKey then
            toggleUI()
        end
    end))

    -- Anti-suppression listener: Ensure ScreenGui.Enabled stays true while MainFrame is visible
    table.insert(Connections, ScreenGui:GetPropertyChangedSignal("Enabled"):Connect(function()
        if MainFrame.Visible and not ScreenGui.Enabled then
            task.defer(function()
                if MainFrame.Visible and ScreenGui and ScreenGui.Parent then
                    ScreenGui.Enabled = true
                end
            end)
        end
    end))

    ScreenGui.Destroying:Connect(function()
        for _, conn in ipairs(Connections) do
            pcall(function() conn:Disconnect() end)
        end
    end)

    -- Window Object
    local Window = {
        ScreenGui = ScreenGui,
        MainFrame = MainFrame,
        FloatingBtn = FloatingBtn,
        Options = {},
        Tabs = {},
        ActiveTab = nil,
    }

    function Window:Toggle()
        toggleUI()
    end

    function Window:Show()
        ScreenGui.Enabled = true
        MainFrame.Visible = true
        if isMinimized then
            setMinimized(false)
        end
        tween(FloatingBtn, TweenInfo.new(0.15), {BackgroundTransparency = 0.5})
    end

    function Window:Hide()
        MainFrame.Visible = false
        tween(FloatingBtn, TweenInfo.new(0.15), {BackgroundTransparency = 0})
    end

    function Window:Notify(opts)
        pcall(function()
            opts = opts or {}
            local nTitle = opts.Title or "Notification"
            local nContent = opts.Content or ""
            local nDuration = opts.Duration or 3

            local notif = Instance.new("Frame")
            notif.Size = UDim2.new(1, 0, 0, 56)
            notif.BackgroundColor3 = Color3.fromRGB(28, 22, 38)
            notif.BackgroundTransparency = 1
            notif.BorderSizePixel = 0
            notif.Parent = NotifContainer

            local nCorner = Instance.new("UICorner")
            nCorner.CornerRadius = UDim.new(0, 8)
            nCorner.Parent = notif

            local nStroke = Instance.new("UIStroke")
            nStroke.Color = Color3.fromRGB(168, 85, 247)
            nStroke.Thickness = 1
            nStroke.Transparency = 1
            nStroke.Parent = notif

            local tLabel = Instance.new("TextLabel")
            tLabel.Size = UDim2.new(1, -16, 0, 18)
            tLabel.Position = UDim2.new(0, 12, 0, 8)
            tLabel.BackgroundTransparency = 1
            tLabel.Text = nTitle
            tLabel.TextColor3 = Color3.fromRGB(192, 132, 252)
            tLabel.TextSize = 12
            tLabel.Font = Enum.Font.GothamBold
            tLabel.TextXAlignment = Enum.TextXAlignment.Left
            tLabel.TextTransparency = 1
            tLabel.Parent = notif

            local cLabel = Instance.new("TextLabel")
            cLabel.Size = UDim2.new(1, -16, 0, 20)
            cLabel.Position = UDim2.new(0, 12, 0, 26)
            cLabel.BackgroundTransparency = 1
            cLabel.Text = nContent
            cLabel.TextColor3 = Color3.fromRGB(225, 220, 235)
            cLabel.TextSize = 11
            cLabel.Font = Enum.Font.Gotham
            cLabel.TextXAlignment = Enum.TextXAlignment.Left
            cLabel.TextTransparency = 1
            cLabel.Parent = notif

            -- Fade in
            tween(notif, TweenInfo.new(0.2), {BackgroundTransparency = 0})
            tween(nStroke, TweenInfo.new(0.2), {Transparency = 0.4})
            tween(tLabel, TweenInfo.new(0.2), {TextTransparency = 0})
            tween(cLabel, TweenInfo.new(0.2), {TextTransparency = 0})

            task.delay(nDuration, function()
                if notif and notif.Parent then
                    tween(notif, TweenInfo.new(0.2), {BackgroundTransparency = 1})
                    tween(nStroke, TweenInfo.new(0.2), {Transparency = 1})
                    tween(tLabel, TweenInfo.new(0.2), {TextTransparency = 1})
                    tween(cLabel, TweenInfo.new(0.2), {TextTransparency = 1})
                    task.wait(0.25)
                    pcall(function() notif:Destroy() end)
                end
            end)
        end)
    end

    local tabIndex = 0
    function Window:AddTab(opts)
        tabIndex = tabIndex + 1
        local tabTitle = opts.Title or ("Tab " .. tabIndex)
        local tabIcon = opts.Icon or "⚡"

        -- Tab Button
        local TabBtn = Instance.new("TextButton")
        TabBtn.Name = "Tab_" .. tabTitle
        TabBtn.Size = UDim2.new(1, 0, 0, 34)
        TabBtn.BackgroundColor3 = Color3.fromRGB(38, 30, 52)
        TabBtn.BackgroundTransparency = 1
        TabBtn.Text = ""
        TabBtn.Parent = TabContainer

        local TabBtnCorner = Instance.new("UICorner")
        TabBtnCorner.CornerRadius = UDim.new(0, 6)
        TabBtnCorner.Parent = TabBtn

        local TabIndicator = Instance.new("Frame")
        TabIndicator.Name = "Indicator"
        TabIndicator.Size = UDim2.new(0, 3, 0, 18)
        TabIndicator.Position = UDim2.new(0, 0, 0.5, -9)
        TabIndicator.BackgroundColor3 = Color3.fromRGB(168, 85, 247)
        TabIndicator.BorderSizePixel = 0
        TabIndicator.BackgroundTransparency = 1
        TabIndicator.Parent = TabBtn

        local IndCorner = Instance.new("UICorner")
        IndCorner.CornerRadius = UDim.new(1, 0)
        IndCorner.Parent = TabIndicator

        local TabLabel = Instance.new("TextLabel")
        TabLabel.Size = UDim2.new(1, -24, 1, 0)
        TabLabel.Position = UDim2.new(0, 14, 0, 0)
        TabLabel.BackgroundTransparency = 1
        TabLabel.Text = tabIcon .. "  " .. tabTitle
        TabLabel.TextColor3 = Color3.fromRGB(160, 150, 175)
        TabLabel.TextSize = 13
        TabLabel.Font = Enum.Font.GothamBold
        TabLabel.TextXAlignment = Enum.TextXAlignment.Left
        TabLabel.Parent = TabBtn

        -- Content Scrolling Frame
        local ContentScroll = Instance.new("ScrollingFrame")
        ContentScroll.Name = "Scroll_" .. tabTitle
        ContentScroll.Size = UDim2.new(1, 0, 1, 0)
        ContentScroll.BackgroundTransparency = 1
        ContentScroll.ScrollBarThickness = 4
        ContentScroll.ScrollBarImageColor3 = Color3.fromRGB(90, 60, 125)
        ContentScroll.Visible = false
        ContentScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
        ContentScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
        ContentScroll.Parent = ContentArea

        local ContentPadding = Instance.new("UIPadding")
        ContentPadding.PaddingTop = UDim.new(0, 12)
        ContentPadding.PaddingLeft = UDim.new(0, 14)
        ContentPadding.PaddingRight = UDim.new(0, 14)
        ContentPadding.PaddingBottom = UDim.new(0, 50)
        ContentPadding.Parent = ContentScroll

        local ContentLayout = Instance.new("UIListLayout")
        ContentLayout.SortOrder = Enum.SortOrder.LayoutOrder
        ContentLayout.Padding = UDim.new(0, 8)
        ContentLayout.Parent = ContentScroll

        ContentLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            ContentScroll.CanvasSize = UDim2.new(0, 0, 0, ContentLayout.AbsoluteContentSize.Y + 65)
        end)

        local TabObj = {
            Title = tabTitle,
            Button = TabBtn,
            Indicator = TabIndicator,
            Label = TabLabel,
            Scroll = ContentScroll,
        }

        local function selectThisTab()
            for _, t in pairs(Window.Tabs) do
                t.Scroll.Visible = false
                tween(t.Button, TweenInfo.new(0.18), {BackgroundTransparency = 1})
                tween(t.Indicator, TweenInfo.new(0.18), {BackgroundTransparency = 1})
                tween(t.Label, TweenInfo.new(0.18), {TextColor3 = Color3.fromRGB(160, 150, 175)})
            end
            Window.ActiveTab = TabObj
            ContentScroll.Visible = true
            tween(TabBtn, TweenInfo.new(0.18), {BackgroundTransparency = 0})
            tween(TabIndicator, TweenInfo.new(0.18), {BackgroundTransparency = 0})
            tween(TabLabel, TweenInfo.new(0.18), {TextColor3 = Color3.fromRGB(255, 255, 255)})
        end

        TabBtn.MouseButton1Click:Connect(selectThisTab)
        table.insert(Window.Tabs, TabObj)

        -- If first tab, select by default
        if #Window.Tabs == 1 then
            selectThisTab()
        end

        -- Component Builders with proper Electric Purple & Text Wrapping
        local function createBaseRow(titleText, descText)
            local hasDesc = descText and descText ~= ""
            local el = Instance.new("Frame")
            el.Size = UDim2.new(1, 0, 0, hasDesc and 64 or 46)
            el.BackgroundColor3 = Color3.fromRGB(25, 22, 35)
            el.BorderSizePixel = 0
            el.Parent = ContentScroll

            local c = Instance.new("UICorner")
            c.CornerRadius = UDim.new(0, 7)
            c.Parent = el

            local s = Instance.new("UIStroke")
            s.Color = Color3.fromRGB(55, 40, 75)
            s.Thickness = 1
            s.Transparency = 0.5
            s.Parent = el

            local title = Instance.new("TextLabel")
            title.Size = UDim2.new(1, -165, 0, 20)
            title.Position = hasDesc and UDim2.new(0, 12, 0, 9) or UDim2.new(0, 12, 0.5, -10)
            title.BackgroundTransparency = 1
            title.Text = titleText
            title.TextColor3 = Color3.fromRGB(245, 240, 255)
            title.TextSize = 14
            title.Font = Enum.Font.GothamBold
            title.TextXAlignment = Enum.TextXAlignment.Left
            title.TextWrapped = true
            title.RichText = true
            title.Parent = el

            if hasDesc then
                local desc = Instance.new("TextLabel")
                desc.Size = UDim2.new(1, -165, 0, 30)
                desc.Position = UDim2.new(0, 12, 0, 30)
                desc.BackgroundTransparency = 1
                desc.Text = descText
                desc.TextColor3 = Color3.fromRGB(165, 155, 185)
                desc.TextSize = 12
                desc.Font = Enum.Font.GothamMedium
                desc.TextXAlignment = Enum.TextXAlignment.Left
                desc.TextYAlignment = Enum.TextYAlignment.Top
                desc.TextWrapped = true
                desc.RichText = true
                desc.Parent = el
            end

            return el, title
        end

        -- Tab Methods
        local TabMethods = {}

        function TabMethods:AddSection(text)
            local sec = Instance.new("TextLabel")
            sec.Size = UDim2.new(1, 0, 0, 28)
            sec.BackgroundTransparency = 1
            sec.Text = string.upper(text)
            sec.TextColor3 = Color3.fromRGB(192, 132, 252)
            sec.TextSize = 13
            sec.Font = Enum.Font.GothamBold
            sec.TextXAlignment = Enum.TextXAlignment.Left
            sec.Parent = ContentScroll
            return sec
        end

        function TabMethods:AddParagraph(opts)
            opts = opts or {}
            local el = Instance.new("Frame")
            local minHeight = opts.Height or 84
            el.Size = UDim2.new(1, 0, 0, minHeight)
            el.AutomaticSize = Enum.AutomaticSize.Y
            el.BackgroundColor3 = Color3.fromRGB(25, 21, 35)
            el.BorderSizePixel = 0
            el.Parent = ContentScroll

            local c = Instance.new("UICorner")
            c.CornerRadius = UDim.new(0, 7)
            c.Parent = el

            local s = Instance.new("UIStroke")
            s.Color = Color3.fromRGB(55, 40, 75)
            s.Thickness = 1
            s.Transparency = 0.5
            s.Parent = el

            local pad = Instance.new("UIPadding")
            pad.PaddingTop = UDim.new(0, 10)
            pad.PaddingBottom = UDim.new(0, 12)
            pad.PaddingLeft = UDim.new(0, 14)
            pad.PaddingRight = UDim.new(0, 14)
            el.Name = "Paragraph_" .. tostring((opts.Title or "Card"):gsub("%s+", ""))
            pad.Parent = el

            local titleSize = opts.TitleSize or 16
            local bodySize = opts.BodySize or 14

            local title = Instance.new("TextLabel")
            title.Name = "ParagraphTitle"
            title.Size = UDim2.new(1, 0, 0, titleSize + 6)
            title.Position = UDim2.new(0, 0, 0, 0)
            title.BackgroundTransparency = 1
            title.Text = opts.Title or ""
            title.TextColor3 = Color3.fromRGB(192, 132, 252)
            title.TextSize = titleSize
            title.Font = Enum.Font.GothamBold
            title.TextXAlignment = Enum.TextXAlignment.Left
            title.Parent = el

            local body = Instance.new("TextLabel")
            body.Name = "ParagraphBody"
            body.AutomaticSize = Enum.AutomaticSize.Y
            body.Size = UDim2.new(1, 0, 0, 0)
            body.Position = UDim2.new(0, 0, 0, titleSize + 8)
            body.BackgroundTransparency = 1
            body.Text = opts.Content or ""
            body.TextColor3 = Color3.fromRGB(230, 225, 245)
            body.TextSize = bodySize
            body.Font = Enum.Font.GothamMedium
            body.TextXAlignment = Enum.TextXAlignment.Left
            body.TextYAlignment = Enum.TextYAlignment.Top
            body.TextWrapped = true
            body.RichText = true
            body.Parent = el

            local ParaObj = {
                Frame = el,
                TitleLabel = title,
                BodyLabel = body,
            }
            function ParaObj:Set(newOpts)
                if type(newOpts) == "string" then
                    body.Text = newOpts
                elseif type(newOpts) == "table" then
                    if newOpts.Title then title.Text = tostring(newOpts.Title) end
                    if newOpts.Content then body.Text = tostring(newOpts.Content) end
                end
            end
            function ParaObj:SetText(content)
                body.Text = tostring(content or "")
            end
            return ParaObj
        end

        function TabMethods:AddButton(opts)
            opts = opts or {}
            local el = createBaseRow(opts.Title or "Button", opts.Description)

            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(0, 96, 0, 30)
            btn.Position = UDim2.new(1, -108, 0.5, -15)
            btn.BackgroundColor3 = Color3.fromRGB(42, 32, 58)
            btn.Text = "Execute"
            btn.TextColor3 = Color3.fromRGB(230, 225, 240)
            btn.TextSize = 13
            btn.Font = Enum.Font.GothamBold
            btn.Parent = el

            local btnCorner = Instance.new("UICorner")
            btnCorner.CornerRadius = UDim.new(0, 6)
            btnCorner.Parent = btn

            btn.MouseEnter:Connect(function() tween(btn, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(65, 45, 95)}) end)
            btn.MouseLeave:Connect(function() tween(btn, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(42, 32, 58)}) end)

            btn.MouseButton1Click:Connect(function()
                tween(btn, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(168, 85, 247)})
                task.delay(0.12, function()
                    tween(btn, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(42, 32, 58)})
                end)
                if opts.Callback then
                    pcall(opts.Callback)
                end
            end)

            return btn
        end

        function TabMethods:AddToggle(id, opts)
            opts = opts or {}
            local el = createBaseRow(opts.Title or "Toggle", opts.Description)
            local state = opts.Default or false

            local toggleBg = Instance.new("TextButton")
            toggleBg.Size = UDim2.new(0, 44, 0, 22)
            toggleBg.Position = UDim2.new(1, -56, 0.5, -11)
            toggleBg.BackgroundColor3 = state and Color3.fromRGB(168, 85, 247) or Color3.fromRGB(38, 32, 48)
            toggleBg.Text = ""
            toggleBg.Parent = el

            local bgCorner = Instance.new("UICorner")
            bgCorner.CornerRadius = UDim.new(1, 0)
            bgCorner.Parent = toggleBg

            local knob = Instance.new("Frame")
            knob.Size = UDim2.new(0, 16, 0, 16)
            knob.Position = state and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
            knob.BackgroundColor3 = state and Color3.fromRGB(20, 15, 28) or Color3.fromRGB(160, 150, 180)
            knob.BorderSizePixel = 0
            knob.Parent = toggleBg

            local knobCorner = Instance.new("UICorner")
            knobCorner.CornerRadius = UDim.new(1, 0)
            knobCorner.Parent = knob

            Window.Options[id] = { Value = state }

            local callbacks = {}
            if opts.Callback then table.insert(callbacks, opts.Callback) end

            local function setState(val)
                state = val
                Window.Options[id].Value = state
                if state then
                    tween(toggleBg, TweenInfo.new(0.18), {BackgroundColor3 = Color3.fromRGB(168, 85, 247)})
                    tween(knob, TweenInfo.new(0.18), {Position = UDim2.new(1, -19, 0.5, -8), BackgroundColor3 = Color3.fromRGB(20, 15, 28)})
                else
                    tween(toggleBg, TweenInfo.new(0.18), {BackgroundColor3 = Color3.fromRGB(38, 32, 48)})
                    tween(knob, TweenInfo.new(0.18), {Position = UDim2.new(0, 3, 0.5, -8), BackgroundColor3 = Color3.fromRGB(160, 150, 180)})
                end
                for _, cb in ipairs(callbacks) do
                    task.spawn(pcall, cb, state)
                end
            end

            toggleBg.MouseButton1Click:Connect(function()
                setState(not state)
            end)

            local ToggleObj = {}
            function ToggleObj:SetValue(val) setState(val) end
            function ToggleObj:OnChanged(cb) table.insert(callbacks, cb) end
            return ToggleObj
        end

        function TabMethods:AddSlider(id, opts)
            opts = opts or {}
            local minVal = opts.Min or 0
            local maxVal = opts.Max or 100
            local rounding = opts.Rounding or 1
            local suffix = opts.Suffix or ""
            local currentVal = math.clamp(opts.Default or minVal, minVal, maxVal)

            local el = Instance.new("Frame")
            el.Size = UDim2.new(1, 0, 0, 56)
            el.BackgroundColor3 = Color3.fromRGB(25, 22, 35)
            el.BorderSizePixel = 0
            el.Parent = ContentScroll

            local c = Instance.new("UICorner")
            c.CornerRadius = UDim.new(0, 7)
            c.Parent = el

            local s = Instance.new("UIStroke")
            s.Color = Color3.fromRGB(55, 40, 75)
            s.Thickness = 1
            s.Transparency = 0.5
            s.Parent = el

            local title = Instance.new("TextLabel")
            title.Size = UDim2.new(1, -120, 0, 18)
            title.Position = UDim2.new(0, 12, 0, 8)
            title.BackgroundTransparency = 1
            title.Text = opts.Title or "Slider"
            title.TextColor3 = Color3.fromRGB(245, 240, 255)
            title.TextSize = 14
            title.Font = Enum.Font.GothamBold
            title.TextXAlignment = Enum.TextXAlignment.Left
            title.Parent = el

            local valLabel = Instance.new("TextLabel")
            valLabel.Size = UDim2.new(0, 100, 0, 18)
            valLabel.Position = UDim2.new(1, -112, 0, 8)
            valLabel.BackgroundTransparency = 1
            valLabel.Text = tostring(currentVal) .. suffix
            valLabel.TextColor3 = Color3.fromRGB(192, 132, 252)
            valLabel.TextSize = 13
            valLabel.Font = Enum.Font.GothamBold
            valLabel.TextXAlignment = Enum.TextXAlignment.Right
            valLabel.Parent = el

            local sliderTrack = Instance.new("Frame")
            sliderTrack.Size = UDim2.new(1, -24, 0, 6)
            sliderTrack.Position = UDim2.new(0, 12, 0, 36)
            sliderTrack.BackgroundColor3 = Color3.fromRGB(38, 32, 48)
            sliderTrack.BorderSizePixel = 0
            sliderTrack.Parent = el

            local trackCorner = Instance.new("UICorner")
            trackCorner.CornerRadius = UDim.new(1, 0)
            trackCorner.Parent = sliderTrack

            local fill = Instance.new("Frame")
            local initPct = (currentVal - minVal) / (maxVal - minVal)
            fill.Size = UDim2.new(initPct, 0, 1, 0)
            fill.BackgroundColor3 = Color3.fromRGB(168, 85, 247)
            fill.BorderSizePixel = 0
            fill.Parent = sliderTrack

            local fillCorner = Instance.new("UICorner")
            fillCorner.CornerRadius = UDim.new(1, 0)
            fillCorner.Parent = fill

            Window.Options[id] = { Value = currentVal }
            local callbacks = {}
            if opts.Callback then table.insert(callbacks, opts.Callback) end

            local function updateSlider(inputPos)
                local absX = sliderTrack.AbsolutePosition.X
                local absWidth = sliderTrack.AbsoluteSize.X
                local pct = math.clamp((inputPos.X - absX) / absWidth, 0, 1)
                local rawVal = minVal + (maxVal - minVal) * pct
                local stepped = math.floor(rawVal / rounding + 0.5) * rounding
                stepped = math.clamp(stepped, minVal, maxVal)
                currentVal = stepped
                Window.Options[id].Value = currentVal
                valLabel.Text = tostring(currentVal) .. suffix
                fill.Size = UDim2.new((currentVal - minVal) / (maxVal - minVal), 0, 1, 0)
                for _, cb in ipairs(callbacks) do
                    task.spawn(pcall, cb, currentVal)
                end
            end

            local isSliding = false
            sliderTrack.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    isSliding = true
                    updateSlider(input.Position)
                end
            end)
            UserInputService.InputChanged:Connect(function(input)
                if isSliding and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                    updateSlider(input.Position)
                end
            end)
            UserInputService.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    isSliding = false
                end
            end)

            local SliderObj = {}
            function SliderObj:SetValue(val)
                val = math.clamp(val, minVal, maxVal)
                currentVal = val
                Window.Options[id].Value = currentVal
                valLabel.Text = tostring(currentVal) .. suffix
                fill.Size = UDim2.new((currentVal - minVal) / (maxVal - minVal), 0, 1, 0)
                for _, cb in ipairs(callbacks) do
                    task.spawn(pcall, cb, currentVal)
                end
            end
            function SliderObj:OnChanged(cb) table.insert(callbacks, cb) end
            return SliderObj
        end

        function TabMethods:AddDropdown(id, opts)
            opts = opts or {}
            local values = opts.Values or {}
            local selected = opts.Default or values[1] or ""
            local callbacks = {}
            if opts.Callback then table.insert(callbacks, opts.Callback) end

            local el = createBaseRow(opts.Title or "Dropdown", opts.Description)

            local dropBtn = Instance.new("TextButton")
            dropBtn.Size = UDim2.new(0, 140, 0, 28)
            dropBtn.Position = UDim2.new(1, -152, 0.5, -14)
            dropBtn.BackgroundColor3 = Color3.fromRGB(36, 28, 48)
            dropBtn.Text = "  " .. tostring(selected)
            dropBtn.TextColor3 = Color3.fromRGB(230, 225, 240)
            dropBtn.TextSize = 13
            dropBtn.Font = Enum.Font.GothamBold
            dropBtn.TextXAlignment = Enum.TextXAlignment.Left
            dropBtn.Parent = el

            local dropCorner = Instance.new("UICorner")
            dropCorner.CornerRadius = UDim.new(0, 6)
            dropCorner.Parent = dropBtn

            local arrow = Instance.new("TextLabel")
            arrow.Size = UDim2.new(0, 20, 1, 0)
            arrow.Position = UDim2.new(1, -22, 0, 0)
            arrow.BackgroundTransparency = 1
            arrow.Text = "▾"
            arrow.TextColor3 = Color3.fromRGB(192, 132, 252)
            arrow.TextSize = 13
            arrow.Parent = dropBtn

            -- Dropdown menu overlay attached to ScreenGui
            local dropMenu = Instance.new("ScrollingFrame")
            dropMenu.Name = "DropMenu_" .. id
            dropMenu.Size = UDim2.new(0, 140, 0, math.min(#values * 28 + 4, 160))
            dropMenu.BackgroundColor3 = Color3.fromRGB(26, 20, 36)
            dropMenu.BorderSizePixel = 0
            dropMenu.ScrollBarThickness = 2
            dropMenu.ScrollBarImageColor3 = Color3.fromRGB(80, 55, 110)
            dropMenu.ZIndex = 80
            dropMenu.Visible = false
            dropMenu.Parent = ScreenGui

            local menuCorner = Instance.new("UICorner")
            menuCorner.CornerRadius = UDim.new(0, 6)
            menuCorner.Parent = dropMenu

            local menuStroke = Instance.new("UIStroke")
            menuStroke.Color = Color3.fromRGB(75, 45, 110)
            menuStroke.Thickness = 1
            menuStroke.Parent = dropMenu

            local menuLayout = Instance.new("UIListLayout")
            menuLayout.SortOrder = Enum.SortOrder.LayoutOrder
            menuLayout.Padding = UDim.new(0, 2)
            menuLayout.Parent = dropMenu

            local menuPadding = Instance.new("UIPadding")
            menuPadding.PaddingTop = UDim.new(0, 3)
            menuPadding.PaddingBottom = UDim.new(0, 3)
            menuPadding.PaddingLeft = UDim.new(0, 3)
            menuPadding.PaddingRight = UDim.new(0, 3)
            menuPadding.Parent = dropMenu

            Window.Options[id] = { Value = selected }

            local function rebuildOptions()
                for _, ch in ipairs(dropMenu:GetChildren()) do
                    if ch:IsA("TextButton") then ch:Destroy() end
                end
                dropMenu.Size = UDim2.new(0, 140, 0, math.min(#values * 28 + 6, 160))
                dropMenu.CanvasSize = UDim2.new(0, 0, 0, #values * 28 + 6)

                for _, val in ipairs(values) do
                    local itemBtn = Instance.new("TextButton")
                    itemBtn.Size = UDim2.new(1, 0, 0, 26)
                    itemBtn.BackgroundColor3 = Color3.fromRGB(48, 36, 68)
                    itemBtn.BackgroundTransparency = 1
                    itemBtn.Text = "  " .. tostring(val)
                    itemBtn.TextColor3 = Color3.fromRGB(220, 215, 235)
                    itemBtn.TextSize = 12
                    itemBtn.Font = Enum.Font.GothamMedium
                    itemBtn.TextXAlignment = Enum.TextXAlignment.Left
                    itemBtn.ZIndex = 81
                    itemBtn.Parent = dropMenu

                    local itemCorner = Instance.new("UICorner")
                    itemCorner.CornerRadius = UDim.new(0, 4)
                    itemCorner.Parent = itemBtn

                    itemBtn.MouseEnter:Connect(function() tween(itemBtn, TweenInfo.new(0.1), {BackgroundTransparency = 0}) end)
                    itemBtn.MouseLeave:Connect(function() tween(itemBtn, TweenInfo.new(0.1), {BackgroundTransparency = 1}) end)

                    itemBtn.MouseButton1Click:Connect(function()
                        selected = val
                        dropBtn.Text = "  " .. tostring(val)
                        dropMenu.Visible = false
                        Window.Options[id].Value = val
                        for _, cb in ipairs(callbacks) do
                            task.spawn(pcall, cb, val)
                        end
                    end)
                end
            end
            rebuildOptions()

            dropBtn.MouseButton1Click:Connect(function()
                if not dropMenu.Visible then
                    dropMenu.Position = UDim2.new(0, dropBtn.AbsolutePosition.X, 0, dropBtn.AbsolutePosition.Y + dropBtn.AbsoluteSize.Y + 4)
                    dropMenu.Visible = true
                else
                    dropMenu.Visible = false
                end
            end)

            local DropObj = {}
            function DropObj:SetValue(val)
                selected = val
                dropBtn.Text = "  " .. tostring(val)
                Window.Options[id].Value = val
                for _, cb in ipairs(callbacks) do
                    task.spawn(pcall, cb, val)
                end
            end
            function DropObj:SetValues(newVals)
                values = newVals or {}
                rebuildOptions()
            end
            function DropObj:OnChanged(cb) table.insert(callbacks, cb) end
            return DropObj
        end

        function TabMethods:AddInput(id, opts)
            opts = opts or {}
            local el = createBaseRow(opts.Title or "Input", opts.Description)
            local currentVal = opts.Default or ""
            local callbacks = {}
            if opts.Callback then table.insert(callbacks, opts.Callback) end

            local box = Instance.new("TextBox")
            box.Size = UDim2.new(0, 140, 0, 28)
            box.Position = UDim2.new(1, -152, 0.5, -14)
            box.BackgroundColor3 = Color3.fromRGB(36, 28, 48)
            box.Text = " " .. tostring(currentVal)
            box.PlaceholderText = opts.Placeholder or "Type here..."
            box.TextColor3 = Color3.fromRGB(230, 225, 240)
            box.PlaceholderColor3 = Color3.fromRGB(130, 120, 150)
            box.TextSize = 13
            box.Font = Enum.Font.GothamMedium
            box.TextXAlignment = Enum.TextXAlignment.Left
            box.Parent = el

            local boxCorner = Instance.new("UICorner")
            boxCorner.CornerRadius = UDim.new(0, 6)
            boxCorner.Parent = box

            Window.Options[id] = { Value = currentVal }

            box.FocusLost:Connect(function()
                local text = box.Text:gsub("^%s+", ""):gsub("%s+$", "")
                if opts.Numeric then
                    local num = tonumber(text)
                    if num then
                        currentVal = num
                    end
                else
                    currentVal = text
                end
                Window.Options[id].Value = currentVal
                for _, cb in ipairs(callbacks) do
                    task.spawn(pcall, cb, currentVal)
                end
            end)

            local InputObj = {}
            function InputObj:SetValue(val)
                currentVal = val
                box.Text = " " .. tostring(val)
                Window.Options[id].Value = currentVal
            end
            function InputObj:OnChanged(cb) table.insert(callbacks, cb) end
            return InputObj
        end

        return TabMethods
    end

    function Window:Destroy()
        pcall(function()
            for _, conn in ipairs(Connections) do
                pcall(function() conn:Disconnect() end)
            end
            if ScreenGui and ScreenGui.Parent then
                ScreenGui:Destroy()
            end
        end)
    end

    -- Explicit initial visibility guarantee
    ScreenGui.Enabled = true
    MainFrame.Visible = true
    BodyFrame.Visible = true

    task.defer(function()
        if ScreenGui and ScreenGui.Parent then
            ScreenGui.Enabled = true
            MainFrame.Visible = true
            BodyFrame.Visible = true
        end
    end)

    task.delay(0.1, function()
        if ScreenGui and ScreenGui.Parent then
            ScreenGui.Enabled = true
            MainFrame.Visible = true
            BodyFrame.Visible = true
        end
    end)

    task.delay(0.35, function()
        if ScreenGui and ScreenGui.Parent then
            ScreenGui.Enabled = true
            MainFrame.Visible = true
            BodyFrame.Visible = true
        end
    end)

    return Window
end

return UILibrary
