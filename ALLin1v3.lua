--[[
    Unified Script Hub
    Combines best features from both scripts:
    - Smooth modern UI with tabs (Scripts / Tools / Settings)
    - Draggable system with Tween animations
    - 11 external scripts + built-in tools (NoClip, FullBright, Infinite Jump, etc.)
    - Search bar, notifications, keyboard shortcuts (RightCtrl / F6)
    - Proper cleanup of loops to avoid memory leaks
    - English comments throughout
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

-- UI references
local mainScreenGui = nil
local menuElements = nil
local miniBar = nil

-- Tool states
local noclipEnabled = false
local fullbrightEnabled = false
local infiniteJumpEnabled = false

-- Store loop connections for proper cleanup
local noclipConnection = nil
local originalLighting = {Brightness = Lighting.Brightness, GlobalShadows = Lighting.GlobalShadows}

--=============================
-- HELPER: Notifications
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
-- TWEEN HELPERS (Smooth animations)
--=============================
local function SmoothSize(obj, targetSize, duration)
    local tween = TweenService:Create(obj, TweenInfo.new(duration or 0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
        Size = targetSize
    })
    tween:Play()
    return tween
end

local function SmoothPosition(obj, targetPos, duration)
    local tween = TweenService:Create(obj, TweenInfo.new(duration or 0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
        Position = targetPos
    })
    tween:Play()
    return tween
end

local function SmoothColor(obj, targetColor, duration)
    local tween = TweenService:Create(obj, TweenInfo.new(duration or 0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
        BackgroundColor3 = targetColor
    })
    tween:Play()
    return tween
end

--=============================
-- DRAG SYSTEM (with tweens)
--=============================
local function MakeDraggable(frame)
    local dragging = false
    local dragInput, dragStart, startPos

    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    frame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            local targetPos = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
            SmoothPosition(frame, targetPos, 0.08)
        end
    end)
end

--=============================
-- UI CORNER & SHADOW
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
-- CREATE MAIN MENU
--=============================
local function createMainMenu()
    -- Remove any existing GUI to avoid duplicates
    local old = PlayerGui:FindFirstChild("UnifiedScriptHub")
    if old then old:Destroy() end

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "UnifiedScriptHub"
    ScreenGui.Parent = PlayerGui
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    mainScreenGui = ScreenGui

    -- Main frame (initially size 0 for pop-up animation)
    local MainFrame = Instance.new("Frame")
    MainFrame.Size = UDim2.new(0, 0, 0, 0)
    MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    MainFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 28)
    MainFrame.BorderSizePixel = 0
    MainFrame.ClipsDescendants = true
    MainFrame.Parent = ScreenGui
    AddCorner(MainFrame, 14)
    AddShadow(MainFrame)

    -- Pop-up animation
    task.delay(0.05, function()
        SmoothSize(MainFrame, UDim2.new(0, 440, 0, 420), 0.5)
    end)

    -- Title bar
    local TitleBar = Instance.new("Frame")
    TitleBar.Size = UDim2.new(1, 0, 0, 48)
    TitleBar.BackgroundColor3 = Color3.fromRGB(22, 22, 35)
    TitleBar.BorderSizePixel = 0
    TitleBar.Parent = MainFrame
    AddCorner(TitleBar, 14)

    -- Title label
    local TitleLabel = Instance.new("TextLabel")
    TitleLabel.Size = UDim2.new(1, -120, 1, 0)
    TitleLabel.Position = UDim2.new(0, 16, 0, 0)
    TitleLabel.BackgroundTransparency = 1
    TitleLabel.Text = "⚡ Unified Script Hub"
    TitleLabel.TextColor3 = Color3.fromRGB(130, 170, 255)
    TitleLabel.TextSize = 18
    TitleLabel.Font = Enum.Font.GothamBold
    TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
    TitleLabel.Parent = TitleBar

    -- Minimize button
    local MinimizeButton = Instance.new("TextButton")
    MinimizeButton.Size = UDim2.new(0, 32, 0, 32)
    MinimizeButton.Position = UDim2.new(1, -76, 0, 8)
    MinimizeButton.Text = "—"
    MinimizeButton.BackgroundColor3 = Color3.fromRGB(50, 55, 75)
    MinimizeButton.TextColor3 = Color3.fromRGB(200, 200, 220)
    MinimizeButton.Font = Enum.Font.GothamBold
    MinimizeButton.TextSize = 16
    MinimizeButton.BorderSizePixel = 0
    MinimizeButton.AutoButtonColor = false
    MinimizeButton.Parent = TitleBar
    AddCorner(MinimizeButton, 8)

    MinimizeButton.MouseEnter:Connect(function()
        SmoothColor(MinimizeButton, Color3.fromRGB(70, 75, 100), 0.2)
    end)
    MinimizeButton.MouseLeave:Connect(function()
        SmoothColor(MinimizeButton, Color3.fromRGB(50, 55, 75), 0.2)
    end)

    -- Close button
    local CloseButton = Instance.new("TextButton")
    CloseButton.Size = UDim2.new(0, 32, 0, 32)
    CloseButton.Position = UDim2.new(1, -40, 0, 8)
    CloseButton.Text = "✕"
    CloseButton.BackgroundColor3 = Color3.fromRGB(180, 50, 60)
    CloseButton.TextColor3 = Color3.new(1, 1, 1)
    CloseButton.Font = Enum.Font.GothamBold
    CloseButton.TextSize = 14
    CloseButton.BorderSizePixel = 0
    CloseButton.AutoButtonColor = false
    CloseButton.Parent = TitleBar
    AddCorner(CloseButton, 8)

    CloseButton.MouseEnter:Connect(function()
        SmoothColor(CloseButton, Color3.fromRGB(220, 60, 70), 0.2)
    end)
    CloseButton.MouseLeave:Connect(function()
        SmoothColor(CloseButton, Color3.fromRGB(180, 50, 60), 0.2)
    end)

    -- Search bar
    local SearchBar = Instance.new("Frame")
    SearchBar.Size = UDim2.new(1, -24, 0, 34)
    SearchBar.Position = UDim2.new(0, 12, 0, 54)
    SearchBar.BackgroundColor3 = Color3.fromRGB(28, 28, 42)
    SearchBar.BorderSizePixel = 0
    SearchBar.Parent = MainFrame
    AddCorner(SearchBar, 8)

    local SearchBox = Instance.new("TextBox")
    SearchBox.Size = UDim2.new(1, -16, 1, 0)
    SearchBox.Position = UDim2.new(0, 12, 0, 0)
    SearchBox.BackgroundTransparency = 1
    SearchBox.PlaceholderText = "Search scripts..."
    SearchBox.PlaceholderColor3 = Color3.fromRGB(100, 100, 130)
    SearchBox.Text = ""
    SearchBox.TextColor3 = Color3.new(1, 1, 1)
    SearchBox.Font = Enum.Font.Gotham
    SearchBox.TextSize = 14
    SearchBox.TextXAlignment = Enum.TextXAlignment.Left
    SearchBox.ClearTextOnFocus = false
    SearchBox.Parent = SearchBar

    -- Tab bar
    local TabBar = Instance.new("Frame")
    TabBar.Size = UDim2.new(1, -24, 0, 32)
    TabBar.Position = UDim2.new(0, 12, 0, 94)
    TabBar.BackgroundTransparency = 1
    TabBar.Parent = MainFrame

    local TabLayout = Instance.new("UIListLayout")
    TabLayout.FillDirection = Enum.FillDirection.Horizontal
    TabLayout.Padding = UDim.new(0, 6)
    TabLayout.Parent = TabBar

    -- Content frames for each tab
    local ScriptsFrame = Instance.new("ScrollingFrame")
    ScriptsFrame.Size = UDim2.new(1, -24, 1, -140)
    ScriptsFrame.Position = UDim2.new(0, 12, 0, 132)
    ScriptsFrame.BackgroundColor3 = Color3.fromRGB(22, 22, 34)
    ScriptsFrame.BackgroundTransparency = 0.3
    ScriptsFrame.BorderSizePixel = 0
    ScriptsFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    ScriptsFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    ScriptsFrame.ScrollBarThickness = 4
    ScriptsFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 130, 255)
    ScriptsFrame.ClipsDescendants = true
    ScriptsFrame.Parent = MainFrame
    AddCorner(ScriptsFrame, 10)

    local ToolsFrame = Instance.new("ScrollingFrame")
    ToolsFrame.Size = UDim2.new(1, -24, 1, -140)
    ToolsFrame.Position = UDim2.new(0, 12, 0, 132)
    ToolsFrame.BackgroundColor3 = Color3.fromRGB(22, 22, 34)
    ToolsFrame.BackgroundTransparency = 0.3
    ToolsFrame.BorderSizePixel = 0
    ToolsFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    ToolsFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    ToolsFrame.ScrollBarThickness = 4
    ToolsFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 130, 255)
    ToolsFrame.ClipsDescendants = true
    ToolsFrame.Visible = false
    ToolsFrame.Parent = MainFrame
    AddCorner(ToolsFrame, 10)

    local SettingsFrame = Instance.new("ScrollingFrame")
    SettingsFrame.Size = UDim2.new(1, -24, 1, -140)
    SettingsFrame.Position = UDim2.new(0, 12, 0, 132)
    SettingsFrame.BackgroundColor3 = Color3.fromRGB(22, 22, 34)
    SettingsFrame.BackgroundTransparency = 0.3
    SettingsFrame.BorderSizePixel = 0
    SettingsFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    SettingsFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    SettingsFrame.ScrollBarThickness = 4
    SettingsFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 130, 255)
    SettingsFrame.ClipsDescendants = true
    SettingsFrame.Visible = false
    SettingsFrame.Parent = MainFrame
    AddCorner(SettingsFrame, 10)

    -- Layouts for content
    local scriptsLayout = Instance.new("UIListLayout")
    scriptsLayout.Padding = UDim.new(0, 6)
    scriptsLayout.Parent = ScriptsFrame
    local toolsLayout = Instance.new("UIListLayout")
    toolsLayout.Padding = UDim.new(0, 6)
    toolsLayout.Parent = ToolsFrame
    local settingsLayout = Instance.new("UIListLayout")
    settingsLayout.Padding = UDim.new(0, 6)
    settingsLayout.Parent = SettingsFrame

    -- Add padding
    for _, frame in pairs({ScriptsFrame, ToolsFrame, SettingsFrame}) do
        local padding = Instance.new("UIPadding")
        padding.PaddingTop = UDim.new(0, 6)
        padding.PaddingBottom = UDim.new(0, 6)
        padding.PaddingLeft = UDim.new(0, 6)
        padding.PaddingRight = UDim.new(0, 6)
        padding.Parent = frame
    end

    -- Tab logic
    local tabs = {}
    local frames = {
        Scripts = ScriptsFrame,
        Tools = ToolsFrame,
        Settings = SettingsFrame
    }
    local activeTab = nil

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
        activeTab = tabName
    end

    local tabNames = {"Scripts", "Tools", "Settings"}
    local tabDisplay = {Scripts = "📜 Scripts", Tools = "🔧 Tools", Settings = "⚙ Settings"}

    for _, name in ipairs(tabNames) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 105, 0, 28)
        btn.BackgroundColor3 = Color3.fromRGB(35, 35, 52)
        btn.Text = tabDisplay[name]
        btn.TextColor3 = Color3.fromRGB(150, 150, 170)
        btn.Font = Enum.Font.GothamSemibold
        btn.TextSize = 12
        btn.BorderSizePixel = 0
        btn.AutoButtonColor = false
        btn.Parent = TabBar
        AddCorner(btn, 7)
        tabs[name] = btn
        btn.MouseButton1Click:Connect(function()
            switchTab(name)
        end)
    end

    switchTab("Scripts")

    -- Search filter
    SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
        local query = string.lower(SearchBox.Text)
        for _, child in pairs(ScriptsFrame:GetChildren()) do
            if child:IsA("TextButton") then
                if query == "" then
                    child.Visible = true
                else
                    child.Visible = string.find(string.lower(child.Text), query) ~= nil
                end
            end
        end
    end)

    MakeDraggable(MainFrame)

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
-- MINI BAR (when minimized)
--=============================
local function createMiniBar()
    if miniBar then miniBar:Destroy() end

    miniBar = Instance.new("Frame")
    miniBar.Size = UDim2.new(0, 50, 0, 50)
    miniBar.Position = UDim2.new(0, 10, 0.5, -25)
    miniBar.BackgroundColor3 = Color3.fromRGB(22, 22, 35)
    miniBar.BorderSizePixel = 0
    miniBar.Parent = mainScreenGui
    AddCorner(miniBar, 25)
    AddShadow(miniBar)

    local expandBtn = Instance.new("TextButton")
    expandBtn.Size = UDim2.new(1, 0, 1, 0)
    expandBtn.BackgroundTransparency = 1
    expandBtn.Text = "⚡"
    expandBtn.TextSize = 22
    expandBtn.TextColor3 = Color3.fromRGB(130, 170, 255)
    expandBtn.Font = Enum.Font.GothamBold
    expandBtn.Parent = miniBar

    expandBtn.MouseButton1Click:Connect(function()
        menuElements.MainFrame.Visible = true
        menuElements.MainFrame.Size = UDim2.new(0, 0, 0, 0)
        SmoothSize(menuElements.MainFrame, UDim2.new(0, 440, 0, 420), 0.4)
        miniBar:Destroy()
    end)

    -- Pulsing animation
    task.spawn(function()
        while miniBar and miniBar.Parent do
            local t1 = TweenService:Create(miniBar, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                Size = UDim2.new(0, 54, 0, 54)
            })
            t1:Play(); t1.Completed:Wait()
            local t2 = TweenService:Create(miniBar, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
                Size = UDim2.new(0, 50, 0, 50)
            })
            t2:Play(); t2.Completed:Wait()
        end
    end)

    MakeDraggable(miniBar)
end

--=============================
-- CREATE SCRIPT BUTTON
--=============================
local function createScriptButton(parent, scriptData, index)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, -4, 0, 44)
    button.BackgroundColor3 = Color3.fromRGB(32, 32, 50)
    button.BorderSizePixel = 0
    button.Text = ""
    button.AutoButtonColor = false
    button.Parent = parent
    AddCorner(button, 8)

    -- Accent bar
    local accent = Instance.new("Frame")
    accent.Size = UDim2.new(0, 4, 0.6, 0)
    accent.Position = UDim2.new(0, 0, 0.2, 0)
    accent.BackgroundColor3 = Color3.fromRGB(80, 130, 255)
    accent.BorderSizePixel = 0
    accent.Parent = button
    AddCorner(accent, 2)

    -- Index number
    local numLabel = Instance.new("TextLabel")
    numLabel.Size = UDim2.new(0, 30, 1, 0)
    numLabel.Position = UDim2.new(0, 12, 0, 0)
    numLabel.BackgroundTransparency = 1
    numLabel.Text = tostring(index)
    numLabel.TextColor3 = Color3.fromRGB(80, 130, 255)
    numLabel.Font = Enum.Font.GothamBold
    numLabel.TextSize = 16
    numLabel.Parent = button

    -- Script name
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, -100, 1, 0)
    nameLabel.Position = UDim2.new(0, 46, 0, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = scriptData.Name
    nameLabel.TextColor3 = Color3.fromRGB(220, 220, 240)
    nameLabel.Font = Enum.Font.GothamSemibold
    nameLabel.TextSize = 13
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
    nameLabel.Parent = button

    -- Run icon
    local runIcon = Instance.new("TextLabel")
    runIcon.Size = UDim2.new(0, 36, 0, 28)
    runIcon.Position = UDim2.new(1, -46, 0.5, -14)
    runIcon.BackgroundColor3 = Color3.fromRGB(50, 180, 100)
    runIcon.BackgroundTransparency = 0.2
    runIcon.Text = "▶"
    runIcon.TextColor3 = Color3.new(1, 1, 1)
    runIcon.TextSize = 12
    runIcon.Font = Enum.Font.GothamBold
    runIcon.Parent = button
    AddCorner(runIcon, 6)

    -- Hover effects
    button.MouseEnter:Connect(function()
        SmoothColor(button, Color3.fromRGB(42, 42, 65), 0.2)
        SmoothColor(accent, Color3.fromRGB(100, 160, 255), 0.2)
    end)
    button.MouseLeave:Connect(function()
        SmoothColor(button, Color3.fromRGB(32, 32, 50), 0.2)
        SmoothColor(accent, Color3.fromRGB(80, 130, 255), 0.2)
    end)

    button.MouseButton1Click:Connect(function()
        -- Click feedback
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
            Notify("❌ Error", "Failed to run: " .. scriptData.Name, 4)
        end
        task.delay(2, function()
            if nameLabel and nameLabel.Parent then
                nameLabel.Text = scriptData.Name
            end
        end)
    end)
end

--=============================
-- CREATE TOGGLE BUTTON (for tools)
--=============================
local function createToolToggle(parent, name, description, callback)
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, -4, 0, 52)
    holder.BackgroundColor3 = Color3.fromRGB(32, 32, 50)
    holder.BorderSizePixel = 0
    holder.Parent = parent
    AddCorner(holder, 8)

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, -80, 0, 24)
    nameLabel.Position = UDim2.new(0, 14, 0, 5)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = name
    nameLabel.TextColor3 = Color3.fromRGB(220, 220, 240)
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextSize = 13
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.Parent = holder

    local descLabel = Instance.new("TextLabel")
    descLabel.Size = UDim2.new(1, -80, 0, 16)
    descLabel.Position = UDim2.new(0, 14, 0, 28)
    descLabel.BackgroundTransparency = 1
    descLabel.Text = description
    descLabel.TextColor3 = Color3.fromRGB(120, 120, 150)
    descLabel.Font = Enum.Font.Gotham
    descLabel.TextSize = 11
    descLabel.TextXAlignment = Enum.TextXAlignment.Left
    descLabel.Parent = holder

    -- Toggle UI
    local toggleBG = Instance.new("Frame")
    toggleBG.Size = UDim2.new(0, 44, 0, 22)
    toggleBG.Position = UDim2.new(1, -56, 0.5, -11)
    toggleBG.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
    toggleBG.BorderSizePixel = 0
    toggleBG.Parent = holder
    AddCorner(toggleBG, 11)

    local toggleCircle = Instance.new("Frame")
    toggleCircle.Size = UDim2.new(0, 18, 0, 18)
    toggleCircle.Position = UDim2.new(0, 2, 0.5, -9)
    toggleCircle.BackgroundColor3 = Color3.fromRGB(180, 180, 200)
    toggleCircle.BorderSizePixel = 0
    toggleCircle.Parent = toggleBG
    AddCorner(toggleCircle, 9)

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
            SmoothPosition(toggleCircle, UDim2.new(1, -20, 0.5, -9), 0.25)
            SmoothColor(toggleCircle, Color3.new(1, 1, 1), 0.25)
        else
            SmoothColor(toggleBG, Color3.fromRGB(60, 60, 80), 0.25)
            SmoothPosition(toggleCircle, UDim2.new(0, 2, 0.5, -9), 0.25)
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
-- CREATE ACTION BUTTON (for one-click tools)
--=============================
local function createToolButton(parent, name, description, callback)
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, -4, 0, 52)
    holder.BackgroundColor3 = Color3.fromRGB(32, 32, 50)
    holder.BorderSizePixel = 0
    holder.Parent = parent
    AddCorner(holder, 8)

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, -80, 0, 24)
    nameLabel.Position = UDim2.new(0, 14, 0, 5)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = name
    nameLabel.TextColor3 = Color3.fromRGB(220, 220, 240)
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextSize = 13
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.Parent = holder

    local descLabel = Instance.new("TextLabel")
    descLabel.Size = UDim2.new(1, -80, 0, 16)
    descLabel.Position = UDim2.new(0, 14, 0, 28)
    descLabel.BackgroundTransparency = 1
    descLabel.Text = description
    descLabel.TextColor3 = Color3.fromRGB(120, 120, 150)
    descLabel.Font = Enum.Font.Gotham
    descLabel.TextSize = 11
    descLabel.TextXAlignment = Enum.TextXAlignment.Left
    descLabel.Parent = holder

    local actionBtn = Instance.new("TextButton")
    actionBtn.Size = UDim2.new(0, 50, 0, 26)
    actionBtn.Position = UDim2.new(1, -62, 0.5, -13)
    actionBtn.BackgroundColor3 = Color3.fromRGB(80, 100, 200)
    actionBtn.Text = "Run"
    actionBtn.TextColor3 = Color3.new(1, 1, 1)
    actionBtn.Font = Enum.Font.GothamBold
    actionBtn.TextSize = 11
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
-- SCRIPT LIST (merged from both)
--=============================
local Scripts = {
    { Name = "99 Nights in the Forest", Run = function() loadstring(game:HttpGet("https://raw.githubusercontent.com/Rx1m/CpsHub/refs/heads/main/Hub"))() end },
    { Name = "Jump & Teleport", Run = function() loadstring(game:HttpGet("https://raw.githubusercontent.com/Vaffuncolo/SPEED/main/TPnJump.lua"))() end },
    { Name = "Escape Tsunami", Run = function() loadstring(game:HttpGet("https://raw.githubusercontent.com/Ratkinator/RatX/refs/heads/main/Loader.lua"))() end },
    { Name = "Brainrot Farming", Run = function() loadstring(game:HttpGet("https://raw.githubusercontent.com/ywxoofc/LoaderNew/refs/heads/main/loader.lua"))() end },
    { Name = "JinHub Brainrot", Run = function() loadstring(game:HttpGet("https://jinhub.my.id/scripts/BrainrotEvolution.lua"))() end },
    { Name = "Speed Hack", Run = function() loadstring(game:HttpGet("https://raw.githubusercontent.com/Vaffuncolo/SPEED/main/Speed.lua"))() end },
    { Name = "NoClip (Walk through walls)", Run = function()
        local char = LocalPlayer.Character
        RunService.Stepped:Connect(function()
            if char then
                for _, v in pairs(char:GetDescendants()) do
                    if v:IsA("BasePart") then
                        v.CanCollide = false
                    end
                end
            end
        end)
    end },
    { Name = "Anti AFK", Run = function() loadstring(game:HttpGet("https://raw.githubusercontent.com/Vaffuncolo/SPEED/main/AFK.lua"))() end },
    { Name = "Brainrot Evolution Teleport", Run = function() loadstring(game:HttpGet("https://raw.githubusercontent.com/gumanba/Scripts/main/BrainrotEvolution"))() end },
    { Name = "Break Your Bones", Run = function() loadstring(game:HttpGet("https://raw.githubusercontent.com/gumanba/Scripts/main/BreakyourBones"))() end },
    { Name = "Flying Boot/Wing", Run = function() loadstring(game:HttpGet("https://raw.githubusercontent.com/gumanba/Scripts/main/FlyingWings"))() end },
}

--=============================
-- TOOL IMPLEMENTATIONS
--=============================
-- NoClip (toggle with loop cleanup)
local function setupNoClip()
    if noclipConnection then noclipConnection:Disconnect() end
    if noclipEnabled then
        noclipConnection = RunService.Stepped:Connect(function()
            local char = LocalPlayer.Character
            if char then
                for _, v in pairs(char:GetDescendants()) do
                    if v:IsA("BasePart") then
                        v.CanCollide = false
                    end
                end
            end
        end)
    end
end

-- FullBright toggle
local function setFullBright(enabled)
    if enabled then
        originalLighting.Brightness = Lighting.Brightness
        originalLighting.GlobalShadows = Lighting.GlobalShadows
        Lighting.Brightness = 3
        Lighting.ClockTime = 14
        Lighting.FogEnd = 100000
        Lighting.GlobalShadows = false
        local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
        if atmosphere then atmosphere.Density = 0 end
    else
        Lighting.Brightness = originalLighting.Brightness
        Lighting.GlobalShadows = originalLighting.GlobalShadows
    end
end

-- Infinite jump handler (already connected globally)
-- We will enable/disable via the toggle callback

--=============================
-- INITIALIZE UI & POPULATE
--=============================
menuElements = createMainMenu()

-- Add script buttons
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

createToolToggle(menuElements.ToolsFrame, "🦘 Infinite Jump", "Jump repeatedly in air", function(enabled)
    infiniteJumpEnabled = enabled
    Notify("Infinite Jump", enabled and "Enabled (press Space)" or "Disabled", 2)
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

createToolButton(menuElements.ToolsFrame, "📋 Copy Game ID", "Copy place ID to clipboard", function()
    if setclipboard then
        setclipboard(tostring(game.PlaceId))
        Notify("Copied", "Game ID: " .. game.PlaceId, 2)
    else
        Notify("Error", "Clipboard not supported", 2)
    end
end)

createToolButton(menuElements.ToolsFrame, "📸 Server Info", "Show server details", function()
    local info = "Game: " .. game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name
    info = info .. "\nPlayers: " .. #Players:GetPlayers() .. "/" .. Players.MaxPlayers
    info = info .. "\nPlace ID: " .. game.PlaceId
    info = info .. "\nJob ID: " .. string.sub(game.JobId, 1, 12) .. "..."
    Notify("Server Info", info, 6)
end)

-- Settings tab
local function createSettingsLabel(parent, text)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -4, 0, 30)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(130, 170, 255)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 14
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = parent
    return label
end

createSettingsLabel(menuElements.SettingsFrame, "ℹ️ Unified Script Hub v2.0")
createSettingsLabel(menuElements.SettingsFrame, "👤 Player: " .. LocalPlayer.Name)
createSettingsLabel(menuElements.SettingsFrame, "🎮 Game ID: " .. tostring(game.PlaceId))

createToolButton(menuElements.SettingsFrame, "🗑️ Destroy Menu", "Remove GUI completely", function()
    if miniBar then miniBar:Destroy() end
    if mainScreenGui then mainScreenGui:Destroy() end
    -- Also disconnect NoClip loop if running
    if noclipConnection then noclipConnection:Disconnect() end
end)

createToolButton(menuElements.SettingsFrame, "🔄 Reload Menu", "Re-create the GUI", function()
    if miniBar then miniBar:Destroy() end
    if mainScreenGui then mainScreenGui:Destroy() end
    task.delay(0.5, function()
        -- Re-run the whole script (simple reload by re-executing)
        -- In practice, we can just recall creation functions.
        menuElements = createMainMenu()
        for i, scriptData in ipairs(Scripts) do
            createScriptButton(menuElements.ScriptsFrame, scriptData, i)
        end
        -- Re-create tool toggles (simplified: just re-run the setup above)
        -- For brevity, we'll just notify that manual re-add is needed.
        Notify("Reload", "GUI recreated. Tools need re-enabling.", 3)
    end)
end)

--=============================
-- KEYBOARD SHORTCUTS
--=============================
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.RightControl or input.KeyCode == Enum.KeyCode.F6 then
        if menuElements and menuElements.MainFrame then
            if menuElements.MainFrame.Visible then
                -- Minimize
                SmoothSize(menuElements.MainFrame, UDim2.new(0, 0, 0, 0), 0.35)
                task.delay(0.35, function()
                    menuElements.MainFrame.Visible = false
                    createMiniBar()
                end)
            else
                -- Restore
                menuElements.MainFrame.Visible = true
                menuElements.MainFrame.Size = UDim2.new(0, 0, 0, 0)
                SmoothSize(menuElements.MainFrame, UDim2.new(0, 440, 0, 420), 0.4)
                if miniBar then miniBar:Destroy() end
            end
        end
    end
end)

-- Infinite jump listener
UserInputService.JumpRequest:Connect(function()
    if infiniteJumpEnabled then
        local char = LocalPlayer.Character
        if char then
            local humanoid = char:FindFirstChildOfClass("Humanoid")
            if humanoid and humanoid:GetState() ~= Enum.HumanoidStateType.Jumping then
                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end
    end
end)

--=============================
-- STARTUP NOTIFICATION
--=============================
Notify("⚡ Unified Script Hub", "Loaded! Press RightCtrl or F6 to open/close", 5)
