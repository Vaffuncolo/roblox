--[[
    Unified Script Hub v2.2 - Fixed Dragging + Smaller Size
    Fixes:
    - Drag system completely rewritten (no Tween during drag)
    - TitleBar drags MainFrame
    - MiniBar fully draggable
    - Size reduced by 20% (440x420 -> 352x336)
    - Freeze tool included
    - All connections properly cleaned up
--]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")
local TeleportService = game:GetService("TeleportService")
local Lighting = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local mainScreenGui = nil
local menuElements = nil
local miniBar = nil

-- Tool states
local noclipEnabled = false
local fullbrightEnabled = false
local infiniteJumpEnabled = false
local freezeEnabled = false

-- Connections for cleanup
local noclipConnection = nil
local freezeConnection = nil
local frozenPosition = nil

-- Menu size constants (20% smaller than original 440x420)
local MENU_WIDTH = 352
local MENU_HEIGHT = 336

local originalLighting = {
    Brightness = Lighting.Brightness,
    ClockTime = Lighting.ClockTime,
    FogEnd = Lighting.FogEnd,
    GlobalShadows = Lighting.GlobalShadows
}

--=============================
-- NOTIFICATIONS
--=============================
local function Notify(title, text, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title,
            Text = text,
            Duration = duration or 3
        })
    end)
end

--=============================
-- TWEEN HELPERS
--=============================
local function SmoothSize(obj, targetSize, duration)
    local tween = TweenService:Create(
        obj,
        TweenInfo.new(duration or 0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
        {Size = targetSize}
    )
    tween:Play()
    return tween
end

local function SmoothPosition(obj, targetPos, duration)
    local tween = TweenService:Create(
        obj,
        TweenInfo.new(duration or 0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
        {Position = targetPos}
    )
    tween:Play()
    return tween
end

local function SmoothColor(obj, targetColor, duration)
    local tween = TweenService:Create(
        obj,
        TweenInfo.new(duration or 0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
        {BackgroundColor3 = targetColor}
    )
    tween:Play()
    return tween
end

--=============================
-- DRAG SYSTEM (FIXED - No Tween, direct position update)
--=============================
local function MakeDraggable(dragHandle, moveTarget)
    local frameToMove = moveTarget or dragHandle
    local dragging = false
    local dragStart, startPos

    dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frameToMove.Position

            local conn
            conn = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    if conn then conn:Disconnect() end
                end
            end)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            frameToMove.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
end

--=============================
-- UI HELPERS
--=============================
local function AddCorner(parent, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius or 10)
    corner.Parent = parent
    return corner
end

local function AddShadow(parent)
    local shadow = Instance.new("ImageLabel")
    shadow.Name = "Shadow"
    shadow.AnchorPoint = Vector2.new(0.5, 0.5)
    shadow.BackgroundTransparency = 1
    shadow.Position = UDim2.new(0.5, 0, 0.5, 4)
    shadow.Size = UDim2.new(1, 30, 1, 30)
    shadow.ZIndex = parent.ZIndex - 1
    shadow.Image = "rbxassetid://6014261993"
    shadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
    shadow.ImageTransparency = 0.5
    shadow.ScaleType = Enum.ScaleType.Slice
    shadow.SliceCenter = Rect.new(49, 49, 450, 450)
    shadow.Parent = parent
    return shadow
end

--=============================
-- MINI BAR (FIXED DRAGGING)
--=============================
local function createMiniBar()
    if miniBar then miniBar:Destroy() end

    miniBar = Instance.new("Frame")
    miniBar.Name = "MiniBar"
    miniBar.Size = UDim2.new(0, 50, 0, 50)
    miniBar.Position = UDim2.new(0, 10, 0.5, -25)
    miniBar.BackgroundColor3 = Color3.fromRGB(22, 22, 35)
    miniBar.BorderSizePixel = 0
    miniBar.Active = true
    miniBar.Parent = mainScreenGui
    AddCorner(miniBar, 25)
    AddShadow(miniBar)

    -- Make frame draggable FIRST
    MakeDraggable(miniBar, miniBar)

    -- Expand button (smaller than frame so drag area exists around edges)
    local expandBtn = Instance.new("TextButton")
    expandBtn.Name = "ExpandBtn"
    expandBtn.Size = UDim2.new(0.7, 0, 0.7, 0)
    expandBtn.Position = UDim2.new(0.15, 0, 0.15, 0)
    expandBtn.BackgroundTransparency = 1
    expandBtn.Text = "⚡"
    expandBtn.TextSize = 18
    expandBtn.TextColor3 = Color3.fromRGB(130, 170, 255)
    expandBtn.Font = Enum.Font.GothamBold
    expandBtn.Parent = miniBar

    expandBtn.MouseButton1Click:Connect(function()
        if menuElements and menuElements.MainFrame then
            menuElements.MainFrame.Visible = true
            menuElements.MainFrame.Size = UDim2.new(0, 0, 0, 0)
            SmoothSize(menuElements.MainFrame, UDim2.new(0, MENU_WIDTH, 0, MENU_HEIGHT), 0.4)
        end
        if miniBar then miniBar:Destroy() end
        miniBar = nil
    end)

    -- Pulse animation
    task.spawn(function()
        while miniBar and miniBar.Parent do
            local t1 = TweenService:Create(miniBar,
                TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
                {Size = UDim2.new(0, 54, 0, 54)}
            )
            t1:Play()
            t1.Completed:Wait()
            if not miniBar or not miniBar.Parent then break end

            local t2 = TweenService:Create(miniBar,
                TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
                {Size = UDim2.new(0, 50, 0, 50)}
            )
            t2:Play()
            t2.Completed:Wait()
            if not miniBar or not miniBar.Parent then break end
        end
    end)
end

--=============================
-- MAIN MENU
--=============================
local function createMainMenu()
    local old = PlayerGui:FindFirstChild("UnifiedScriptHub")
    if old then old:Destroy() end

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "UnifiedScriptHub"
    ScreenGui.Parent = PlayerGui
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    mainScreenGui = ScreenGui

    -- Main frame (starts at size 0 for pop-up animation)
    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0, 0, 0, 0)
    MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    MainFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 28)
    MainFrame.BorderSizePixel = 0
    MainFrame.ClipsDescendants = true
    MainFrame.Active = true
    MainFrame.Parent = ScreenGui
    AddCorner(MainFrame, 14)
    AddShadow(MainFrame)

    -- Pop-up animation with new smaller size
    task.delay(0.05, function()
        SmoothSize(MainFrame, UDim2.new(0, MENU_WIDTH, 0, MENU_HEIGHT), 0.5)
    end)

    -- Title bar (THIS is the drag handle)
    local TitleBar = Instance.new("Frame")
    TitleBar.Name = "TitleBar"
    TitleBar.Size = UDim2.new(1, 0, 0, 42)
    TitleBar.BackgroundColor3 = Color3.fromRGB(22, 22, 35)
    TitleBar.BorderSizePixel = 0
    TitleBar.Active = true
    TitleBar.Parent = MainFrame
    AddCorner(TitleBar, 14)

    -- Bottom fix for title bar rounded corners
    local TitleBarFix = Instance.new("Frame")
    TitleBarFix.Size = UDim2.new(1, 0, 0, 14)
    TitleBarFix.Position = UDim2.new(0, 0, 1, -14)
    TitleBarFix.BackgroundColor3 = Color3.fromRGB(22, 22, 35)
    TitleBarFix.BorderSizePixel = 0
    TitleBarFix.Parent = TitleBar

    local TitleLabel = Instance.new("TextLabel")
    TitleLabel.Size = UDim2.new(1, -100, 1, 0)
    TitleLabel.Position = UDim2.new(0, 14, 0, 0)
    TitleLabel.BackgroundTransparency = 1
    TitleLabel.Text = "⚡ Script Hub"
    TitleLabel.TextColor3 = Color3.fromRGB(130, 170, 255)
    TitleLabel.TextSize = 16
    TitleLabel.Font = Enum.Font.GothamBold
    TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
    TitleLabel.Parent = TitleBar

    -- Minimize button
    local MinimizeButton = Instance.new("TextButton")
    MinimizeButton.Name = "MinBtn"
    MinimizeButton.Size = UDim2.new(0, 28, 0, 28)
    MinimizeButton.Position = UDim2.new(1, -66, 0, 7)
    MinimizeButton.Text = "—"
    MinimizeButton.BackgroundColor3 = Color3.fromRGB(50, 55, 75)
    MinimizeButton.TextColor3 = Color3.fromRGB(200, 200, 220)
    MinimizeButton.Font = Enum.Font.GothamBold
    MinimizeButton.TextSize = 14
    MinimizeButton.BorderSizePixel = 0
    MinimizeButton.AutoButtonColor = false
    MinimizeButton.ZIndex = 10
    MinimizeButton.Parent = TitleBar
    AddCorner(MinimizeButton, 7)

    MinimizeButton.MouseEnter:Connect(function()
        SmoothColor(MinimizeButton, Color3.fromRGB(70, 75, 100), 0.2)
    end)
    MinimizeButton.MouseLeave:Connect(function()
        SmoothColor(MinimizeButton, Color3.fromRGB(50, 55, 75), 0.2)
    end)

    -- Close button
    local CloseButton = Instance.new("TextButton")
    CloseButton.Name = "CloseBtn"
    CloseButton.Size = UDim2.new(0, 28, 0, 28)
    CloseButton.Position = UDim2.new(1, -34, 0, 7)
    CloseButton.Text = "✕"
    CloseButton.BackgroundColor3 = Color3.fromRGB(180, 50, 60)
    CloseButton.TextColor3 = Color3.new(1, 1, 1)
    CloseButton.Font = Enum.Font.GothamBold
    CloseButton.TextSize = 12
    CloseButton.BorderSizePixel = 0
    CloseButton.AutoButtonColor = false
    CloseButton.ZIndex = 10
    CloseButton.Parent = TitleBar
    AddCorner(CloseButton, 7)

    CloseButton.MouseEnter:Connect(function()
        SmoothColor(CloseButton, Color3.fromRGB(220, 60, 70), 0.2)
    end)
    CloseButton.MouseLeave:Connect(function()
        SmoothColor(CloseButton, Color3.fromRGB(180, 50, 60), 0.2)
    end)

    -- Connect Minimize & Close buttons
    MinimizeButton.MouseButton1Click:Connect(function()
        SmoothSize(MainFrame, UDim2.new(0, 0, 0, 0), 0.35)
        task.delay(0.35, function()
            MainFrame.Visible = false
            createMiniBar()
        end)
    end)

    CloseButton.MouseButton1Click:Connect(function()
        SmoothSize(MainFrame, UDim2.new(0, 0, 0, 0), 0.3)
        task.delay(0.3, function()
            if noclipConnection then noclipConnection:Disconnect() end
            if freezeConnection then freezeConnection:Disconnect() end
            if miniBar then miniBar:Destroy() end
            if mainScreenGui then mainScreenGui:Destroy() end
        end)
    end)

    -- Search bar
    local SearchBar = Instance.new("Frame")
    SearchBar.Size = UDim2.new(1, -20, 0, 30)
    SearchBar.Position = UDim2.new(0, 10, 0, 48)
    SearchBar.BackgroundColor3 = Color3.fromRGB(28, 28, 42)
    SearchBar.BorderSizePixel = 0
    SearchBar.Parent = MainFrame
    AddCorner(SearchBar, 8)

    local SearchIcon = Instance.new("TextLabel")
    SearchIcon.Size = UDim2.new(0, 26, 1, 0)
    SearchIcon.Position = UDim2.new(0, 4, 0, 0)
    SearchIcon.BackgroundTransparency = 1
    SearchIcon.Text = "🔍"
    SearchIcon.TextSize = 12
    SearchIcon.Font = Enum.Font.Gotham
    SearchIcon.Parent = SearchBar

    local SearchBox = Instance.new("TextBox")
    SearchBox.Size = UDim2.new(1, -36, 1, 0)
    SearchBox.Position = UDim2.new(0, 30, 0, 0)
    SearchBox.BackgroundTransparency = 1
    SearchBox.PlaceholderText = "Search scripts..."
    SearchBox.PlaceholderColor3 = Color3.fromRGB(100, 100, 130)
    SearchBox.Text = ""
    SearchBox.TextColor3 = Color3.new(1, 1, 1)
    SearchBox.Font = Enum.Font.Gotham
    SearchBox.TextSize = 13
    SearchBox.TextXAlignment = Enum.TextXAlignment.Left
    SearchBox.ClearTextOnFocus = false
    SearchBox.Parent = SearchBar

    -- Tab bar
    local TabBar = Instance.new("Frame")
    TabBar.Size = UDim2.new(1, -20, 0, 28)
    TabBar.Position = UDim2.new(0, 10, 0, 82)
    TabBar.BackgroundTransparency = 1
    TabBar.Parent = MainFrame

    local TabLayout = Instance.new("UIListLayout")
    TabLayout.FillDirection = Enum.FillDirection.Horizontal
    TabLayout.Padding = UDim.new(0, 5)
    TabLayout.Parent = TabBar

    -- Content frame builder
    local function makeContentFrame(visible)
        local f = Instance.new("ScrollingFrame")
        f.Size = UDim2.new(1, -20, 1, -120)
        f.Position = UDim2.new(0, 10, 0, 114)
        f.BackgroundColor3 = Color3.fromRGB(22, 22, 34)
        f.BackgroundTransparency = 0.3
        f.BorderSizePixel = 0
        f.CanvasSize = UDim2.new(0, 0, 0, 0)
        f.AutomaticCanvasSize = Enum.AutomaticSize.Y
        f.ScrollBarThickness = 4
        f.ScrollBarImageColor3 = Color3.fromRGB(100, 130, 255)
        f.ClipsDescendants = true
        f.Visible = visible
        f.Parent = MainFrame
        AddCorner(f, 10)

        local layout = Instance.new("UIListLayout")
        layout.Padding = UDim.new(0, 5)
        layout.Parent = f

        local padding = Instance.new("UIPadding")
        padding.PaddingTop = UDim.new(0, 5)
        padding.PaddingBottom = UDim.new(0, 5)
        padding.PaddingLeft = UDim.new(0, 5)
        padding.PaddingRight = UDim.new(0, 5)
        padding.Parent = f

        return f
    end

    local ScriptsFrame = makeContentFrame(true)
    local ToolsFrame = makeContentFrame(false)
    local SettingsFrame = makeContentFrame(false)

    -- Tab switching
    local tabs = {}
    local frames = {Scripts = ScriptsFrame, Tools = ToolsFrame, Settings = SettingsFrame}

    local function switchTab(tabName)
        for name, frame in pairs(frames) do
            frame.Visible = (name == tabName)
        end
        for name, btn in pairs(tabs) do
            if name == tabName then
                SmoothColor(btn, Color3.fromRGB(80, 100, 200), 0.2)
                btn.TextColor3 = Color3.new(1, 1, 1)
            else
                SmoothColor(btn, Color3.fromRGB(35, 35, 52), 0.2)
                btn.TextColor3 = Color3.fromRGB(150, 150, 170)
            end
        end
    end

    local tabData = {
        {key = "Scripts", display = "📜 Scripts"},
        {key = "Tools", display = "🔧 Tools"},
        {key = "Settings", display = "⚙ Settings"}
    }

    for _, td in ipairs(tabData) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 90, 0, 24)
        btn.BackgroundColor3 = Color3.fromRGB(35, 35, 52)
        btn.Text = td.display
        btn.TextColor3 = Color3.fromRGB(150, 150, 170)
        btn.Font = Enum.Font.GothamSemibold
        btn.TextSize = 11
        btn.BorderSizePixel = 0
        btn.AutoButtonColor = false
        btn.Parent = TabBar
        AddCorner(btn, 7)
        tabs[td.key] = btn
        btn.MouseButton1Click:Connect(function()
            switchTab(td.key)
        end)
    end

    switchTab("Scripts")

    -- Search filter
    SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
        local query = string.lower(SearchBox.Text)
        for _, child in pairs(ScriptsFrame:GetChildren()) do
            if child:IsA("TextButton") then
                local nameL = child:FindFirstChild("NameLabel")
                if nameL then
                    child.Visible = query == "" or
                        string.find(string.lower(nameL.Text), query) ~= nil
                end
            end
        end
    end)

    -- DRAG: TitleBar is the handle, MainFrame moves
    MakeDraggable(TitleBar, MainFrame)

    return {
        ScreenGui = ScreenGui,
        MainFrame = MainFrame,
        ScriptsFrame = ScriptsFrame,
        ToolsFrame = ToolsFrame,
        SettingsFrame = SettingsFrame,
        MinimizeButton = MinimizeButton,
        CloseButton = CloseButton
    }
end

--=============================
-- SCRIPT BUTTON
--=============================
local function createScriptButton(parent, scriptData, index)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, -4, 0, 38)
    button.BackgroundColor3 = Color3.fromRGB(32, 32, 50)
    button.BorderSizePixel = 0
    button.Text = ""
    button.AutoButtonColor = false
    button.Parent = parent
    AddCorner(button, 8)

    local accent = Instance.new("Frame")
    accent.Size = UDim2.new(0, 3, 0.6, 0)
    accent.Position = UDim2.new(0, 0, 0.2, 0)
    accent.BackgroundColor3 = Color3.fromRGB(80, 130, 255)
    accent.BorderSizePixel = 0
    accent.Parent = button
    AddCorner(accent, 2)

    local numLabel = Instance.new("TextLabel")
    numLabel.Size = UDim2.new(0, 26, 1, 0)
    numLabel.Position = UDim2.new(0, 10, 0, 0)
    numLabel.BackgroundTransparency = 1
    numLabel.Text = tostring(index)
    numLabel.TextColor3 = Color3.fromRGB(80, 130, 255)
    numLabel.Font = Enum.Font.GothamBold
    numLabel.TextSize = 14
    numLabel.Parent = button

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "NameLabel"
    nameLabel.Size = UDim2.new(1, -85, 1, 0)
    nameLabel.Position = UDim2.new(0, 38, 0, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = scriptData.Name
    nameLabel.TextColor3 = Color3.fromRGB(220, 220, 240)
    nameLabel.Font = Enum.Font.GothamSemibold
    nameLabel.TextSize = 12
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
    nameLabel.Parent = button

    local runIcon = Instance.new("TextLabel")
    runIcon.Size = UDim2.new(0, 32, 0, 24)
    runIcon.Position = UDim2.new(1, -40, 0.5, -12)
    runIcon.BackgroundColor3 = Color3.fromRGB(50, 180, 100)
    runIcon.BackgroundTransparency = 0.2
    runIcon.Text = "▶"
    runIcon.TextColor3 = Color3.new(1, 1, 1)
    runIcon.TextSize = 11
    runIcon.Font = Enum.Font.GothamBold
    runIcon.Parent = button
    AddCorner(runIcon, 6)

    button.MouseEnter:Connect(function()
        SmoothColor(button, Color3.fromRGB(42, 42, 65), 0.2)
        SmoothColor(accent, Color3.fromRGB(100, 160, 255), 0.2)
    end)
    button.MouseLeave:Connect(function()
        SmoothColor(button, Color3.fromRGB(32, 32, 50), 0.2)
        SmoothColor(accent, Color3.fromRGB(80, 130, 255), 0.2)
    end)

    button.MouseButton1Click:Connect(function()
        SmoothColor(button, Color3.fromRGB(50, 180, 100), 0.1)
        nameLabel.Text = "⏳ Loading..."
        task.delay(0.15, function()
            SmoothColor(button, Color3.fromRGB(32, 32, 50), 0.3)
        end)

        local success, err = pcall(scriptData.Run)
        if success then
            nameLabel.Text = "✅ " .. scriptData.Name
            Notify("✅ Success", scriptData.Name .. " executed!", 3)
        else
            nameLabel.Text = "❌ " .. scriptData.Name
            Notify("❌ Error", "Failed: " .. scriptData.Name, 4)
        end
        task.delay(2, function()
            if nameLabel and nameLabel.Parent then
                nameLabel.Text = scriptData.Name
            end
        end)
    end)
end

--=============================
-- TOGGLE TOOL
--=============================
local function createToolToggle(parent, name, description, callback)
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, -4, 0, 46)
    holder.BackgroundColor3 = Color3.fromRGB(32, 32, 50)
    holder.BorderSizePixel = 0
    holder.Parent = parent
    AddCorner(holder, 8)

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, -70, 0, 22)
    nameLabel.Position = UDim2.new(0, 12, 0, 4)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = name
    nameLabel.TextColor3 = Color3.fromRGB(220, 220, 240)
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextSize = 12
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.Parent = holder

    local descLabel = Instance.new("TextLabel")
    descLabel.Size = UDim2.new(1, -70, 0, 14)
    descLabel.Position = UDim2.new(0, 12, 0, 25)
    descLabel.BackgroundTransparency = 1
    descLabel.Text = description
    descLabel.TextColor3 = Color3.fromRGB(120, 120, 150)
    descLabel.Font = Enum.Font.Gotham
    descLabel.TextSize = 10
    descLabel.TextXAlignment = Enum.TextXAlignment.Left
    descLabel.Parent = holder

    local toggleBG = Instance.new("Frame")
    toggleBG.Size = UDim2.new(0, 40, 0, 20)
    toggleBG.Position = UDim2.new(1, -52, 0.5, -10)
    toggleBG.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
    toggleBG.BorderSizePixel = 0
    toggleBG.Parent = holder
    AddCorner(toggleBG, 10)

    local toggleCircle = Instance.new("Frame")
    toggleCircle.Size = UDim2.new(0, 16, 0, 16)
    toggleCircle.Position = UDim2.new(0, 2, 0.5, -8)
    toggleCircle.BackgroundColor3 = Color3.fromRGB(180, 180, 200)
    toggleCircle.BorderSizePixel = 0
    toggleCircle.Parent = toggleBG
    AddCorner(toggleCircle, 8)

    local toggled = false
    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Size = UDim2.new(1, 0, 1, 0)
    toggleBtn.BackgroundTransparency = 1
    toggleBtn.Text = ""
    toggleBtn.Parent = holder

    toggleBtn.MouseButton1Click:Connect(function()
        toggled = not toggled
        if toggled then
            SmoothColor(toggleBG, Color3.fromRGB(70, 170, 110), 0.25)
            SmoothPosition(toggleCircle, UDim2.new(1, -18, 0.5, -8), 0.25)
            SmoothColor(toggleCircle, Color3.new(1, 1, 1), 0.25)
        else
            SmoothColor(toggleBG, Color3.fromRGB(60, 60, 80), 0.25)
            SmoothPosition(toggleCircle, UDim2.new(0, 2, 0.5, -8), 0.25)
            SmoothColor(toggleCircle, Color3.fromRGB(180, 180, 200), 0.25)
        end
        callback(toggled)
    end)

    holder.MouseEnter:Connect(function()
        SmoothColor(holder, Color3.fromRGB(38, 38, 58), 0.2)
    end)
    holder.MouseLeave:Connect(function()
        SmoothColor(holder, Color3.fromRGB(32, 32, 50), 0.2)
    end)
    return holder
end

--=============================
-- ACTION BUTTON TOOL
--=============================
local function createToolButton(parent, name, description, callback)
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, -4, 0, 46)
    holder.BackgroundColor3 = Color3.fromRGB(32, 32, 50)
    holder.BorderSizePixel = 0
    holder.Parent = parent
    AddCorner(holder, 8)

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, -70, 0, 22)
    nameLabel.Position = UDim2.new(0, 12, 0, 4)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = name
    nameLabel.TextColor3 = Color3.fromRGB(220, 220, 240)
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextSize = 12
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.Parent = holder

    local descLabel = Instance.new("TextLabel")
    descLabel.Size = UDim2.new(1, -70, 0, 14)
    descLabel.Position = UDim2.new(0, 12, 0, 25)
    descLabel.BackgroundTransparency = 1
    descLabel.Text = description
    descLabel.TextColor3 = Color3.fromRGB(120, 120, 150)
    descLabel.Font = Enum.Font.Gotham
    descLabel.TextSize = 10
    descLabel.TextXAlignment = Enum.TextXAlignment.Left
    descLabel.Parent = holder

    local actionBtn = Instance.new("TextButton")
    actionBtn.Size = UDim2.new(0, 44, 0, 22)
    actionBtn.Position = UDim2.new(1, -56, 0.5, -11)
    actionBtn.BackgroundColor3 = Color3.fromRGB(80, 100, 200)
    actionBtn.Text = "Run"
    actionBtn.TextColor3 = Color3.new(1, 1, 1)
    actionBtn.Font = Enum.Font.GothamBold
    actionBtn.TextSize = 10
    actionBtn.BorderSizePixel = 0
    actionBtn.AutoButtonColor = false
    actionBtn.Parent = holder
    AddCorner(actionBtn, 6)

    actionBtn.MouseEnter:Connect(function()
        SmoothColor(actionBtn, Color3.fromRGB(100, 120, 230), 0.2)
    end)
    actionBtn.MouseLeave:Connect(function()
        SmoothColor(actionBtn, Color3.fromRGB(80, 100, 200), 0.2)
    end)
    actionBtn.MouseButton1Click:Connect(function()
        SmoothColor(actionBtn, Color3.fromRGB(50, 180, 100), 0.1)
        task.delay(0.3, function()
            SmoothColor(actionBtn, Color3.fromRGB(80, 100, 200), 0.3)
        end)
        callback()
    end)

    holder.MouseEnter:Connect(function()
        SmoothColor(holder, Color3.fromRGB(38, 38, 58), 0.2)
    end)
    holder.MouseLeave:Connect(function()
        SmoothColor(holder, Color3.fromRGB(32, 32, 50), 0.2)
    end)
    return holder
end

--=============================
-- SCRIPT LIST
--=============================
local Scripts = {
    {Name = "99 Nights in the Forest", Run = function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/Rx1m/CpsHub/refs/heads/main/Hub"))()
    end},
    {Name = "Jump & Teleport", Run = function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/Vaffuncolo/SPEED/main/TPnJump.lua"))()
    end},
    {Name = "Escape Tsunami", Run = function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/Ratkinator/RatX/refs/heads/main/Loader.lua"))()
    end},
    {Name = "Brainrot Farming", Run = function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/ywxoofc/LoaderNew/refs/heads/main/loader.lua"))()
    end},
    {Name = "JinHub Brainrot", Run = function()
        loadstring(game:HttpGet("https://jinhub.my.id/scripts/BrainrotEvolution.lua"))()
    end},
    {Name = "Speed Hack", Run = function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/Vaffuncolo/SPEED/main/Speed.lua"))()
    end},
    {Name = "NoClip (Walk through walls)", Run = function()
        local char = LocalPlayer.Character
        RunService.Stepped:Connect(function()
            if char then
                for _, v in pairs(char:GetDescendants()) do
                    if v:IsA("BasePart") then v.CanCollide = false end
                end
            end
        end)
    end},
    {Name = "Anti AFK", Run = function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/Vaffuncolo/SPEED/main/AFK.lua"))()
    end},
    {Name = "Brainrot Evolution Teleport", Run = function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/gumanba/Scripts/main/BrainrotEvolution"))()
    end},
    {Name = "Break Your Bones", Run = function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/gumanba/Scripts/main/BreakyourBones"))()
    end},
    {Name = "BrainrotEvolution keyless", Run = function()
        loadstring(game:HttpGet('https://pastebin.com/raw/hUGqeR78'))()
    end},
    {Name = "Keyboard Map", Run = function()
        loadstring(game:HttpGet("https://www.luxyhub.space/api/loader/luxyhub"))()
    end},
    {Name = "Flying Boot/Wing", Run = function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/gumanba/Scripts/main/FlyingWings"))()
    end},
}

--=============================
-- TOOL FUNCTIONS
--=============================
local function setupNoClip()
    if noclipConnection then
        noclipConnection:Disconnect()
        noclipConnection = nil
    end
    if noclipEnabled then
        noclipConnection = RunService.Stepped:Connect(function()
            local char = LocalPlayer.Character
            if char then
                for _, v in pairs(char:GetDescendants()) do
                    if v:IsA("BasePart") then v.CanCollide = false end
                end
            end
        end)
    end
end

local function setFullBright(enabled)
    if enabled then
        originalLighting.Brightness = Lighting.Brightness
        originalLighting.ClockTime = Lighting.ClockTime
        originalLighting.FogEnd = Lighting.FogEnd
        originalLighting.GlobalShadows = Lighting.GlobalShadows
        Lighting.Brightness = 3
        Lighting.ClockTime = 14
        Lighting.FogEnd = 100000
        Lighting.GlobalShadows = false
        local atm = Lighting:FindFirstChildOfClass("Atmosphere")
        if atm then atm.Density = 0 end
    else
        Lighting.Brightness = originalLighting.Brightness
        Lighting.ClockTime = originalLighting.ClockTime
        Lighting.FogEnd = originalLighting.FogEnd
        Lighting.GlobalShadows = originalLighting.GlobalShadows
    end
end

local function setupFreeze()
    if freezeConnection then
        freezeConnection:Disconnect()
        freezeConnection = nil
    end
    if freezeEnabled then
        local char = LocalPlayer.Character
        if char then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then
                frozenPosition = hrp.CFrame
                freezeConnection = RunService.Heartbeat:Connect(function()
                    local c = LocalPlayer.Character
                    if c and frozenPosition then
                        local root = c:FindFirstChild("HumanoidRootPart")
                        if root then
                            root.CFrame = frozenPosition
                            root.Velocity = Vector3.new(0, 0, 0)
                            root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                            root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                        end
                    end
                end)
            end
        end
    else
        frozenPosition = nil
    end
end

--=============================
-- BUILD THE UI
--=============================
menuElements = createMainMenu()

-- Populate scripts
for i, scriptData in ipairs(Scripts) do
    createScriptButton(menuElements.ScriptsFrame, scriptData, i)
end

-- Tools: Toggles
createToolToggle(menuElements.ToolsFrame, "🚫 NoClip", "Walk through walls", function(enabled)
    noclipEnabled = enabled
    setupNoClip()
    Notify("NoClip", enabled and "Enabled" or "Disabled", 2)
end)

createToolToggle(menuElements.ToolsFrame, "💡 FullBright", "Maximum brightness", function(enabled)
    fullbrightEnabled = enabled
    setFullBright(enabled)
    Notify("FullBright", enabled and "Enabled" or "Disabled", 2)
end)

createToolToggle(menuElements.ToolsFrame, "🦘 Infinite Jump", "Jump in mid-air", function(enabled)
    infiniteJumpEnabled = enabled
    Notify("Infinite Jump", enabled and "Enabled (press Space)" or "Disabled", 2)
end)

createToolToggle(menuElements.ToolsFrame, "🧊 Freeze", "Lock character in current position", function(enabled)
    freezeEnabled = enabled
    setupFreeze()
    Notify("Freeze", enabled and "Character frozen!" or "Character unfrozen!", 2)
end)

-- Tools: Action buttons
createToolButton(menuElements.ToolsFrame, "🔄 Rejoin", "Rejoin current server", function()
    Notify("Rejoin", "Teleporting...", 2)
    task.delay(1, function()
        TeleportService:Teleport(game.PlaceId, LocalPlayer)
    end)
end)

createToolButton(menuElements.ToolsFrame, "💀 Reset Character", "Kill your character", function()
    local char = LocalPlayer.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then hum.Health = 0 end
    end
    Notify("Reset", "Character reset", 2)
end)

createToolButton(menuElements.ToolsFrame, "📋 Copy Game ID", "Copy place ID", function()
    if setclipboard then
        setclipboard(tostring(game.PlaceId))
        Notify("Copied", "Game ID: " .. game.PlaceId, 2)
    else
        Notify("Error", "Clipboard not supported", 2)
    end
end)

createToolButton(menuElements.ToolsFrame, "📸 Server Info", "Show server details", function()
    local ok, info = pcall(function()
        local pInfo = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId)
        return "Game: " .. pInfo.Name
            .. "\nPlayers: " .. #Players:GetPlayers() .. "/" .. Players.MaxPlayers
            .. "\nPlace ID: " .. game.PlaceId
            .. "\nJob ID: " .. string.sub(game.JobId, 1, 12) .. "..."
    end)
    Notify("Server Info", ok and info or "Could not fetch info", 6)
end)

-- Settings tab
local function createSettingsLabel(parent, text)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -4, 0, 26)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(130, 170, 255)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 12
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = parent
end

createSettingsLabel(menuElements.SettingsFrame, "ℹ️  Script Hub v2.2")
createSettingsLabel(menuElements.SettingsFrame, "👤  Player: " .. LocalPlayer.Name)
createSettingsLabel(menuElements.SettingsFrame, "🎮  Game ID: " .. tostring(game.PlaceId))

createToolButton(menuElements.SettingsFrame, "🗑️ Destroy Menu", "Remove GUI completely", function()
    if noclipConnection then noclipConnection:Disconnect() end
    if freezeConnection then freezeConnection:Disconnect() end
    if miniBar then miniBar:Destroy() end
    if mainScreenGui then mainScreenGui:Destroy() end
end)

--=============================
-- KEYBOARD SHORTCUT (RightCtrl or F6)
--=============================
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.RightControl
        or input.KeyCode == Enum.KeyCode.F6 then
        if menuElements and menuElements.MainFrame then
            if menuElements.MainFrame.Visible then
                SmoothSize(menuElements.MainFrame, UDim2.new(0, 0, 0, 0), 0.35)
                task.delay(0.35, function()
                    menuElements.MainFrame.Visible = false
                    createMiniBar()
                end)
            else
                menuElements.MainFrame.Visible = true
                menuElements.MainFrame.Size = UDim2.new(0, 0, 0, 0)
                SmoothSize(menuElements.MainFrame, UDim2.new(0, MENU_WIDTH, 0, MENU_HEIGHT), 0.4)
                if miniBar then miniBar:Destroy() end
                miniBar = nil
            end
        end
    end
end)

-- Infinite Jump listener
UserInputService.JumpRequest:Connect(function()
    if infiniteJumpEnabled then
        local char = LocalPlayer.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                hum:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end
    end
end)

Notify("⚡ Script Hub", "Loaded! RightCtrl or F6 to toggle", 5)
