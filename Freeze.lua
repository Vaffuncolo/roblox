-- Freeze Tool GUI
local ScreenGui = Instance.new("ScreenGui")
local Dragger = Instance.new("Frame")        
local VisualFrame = Instance.new("Frame")   
local ImageLabel = Instance.new("ImageLabel")
local TextLabel = Instance.new("TextLabel")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local dragging = false
local dragStart = nil
local startPos = nil
local holdStartTime = nil
local isHolding = false

ScreenGui.Parent = player:WaitForChild("PlayerGui")
ScreenGui.ResetOnSpawn = false

-- ===== حاوية السحب (شفافة، كبيرة) =====
Dragger.Parent = ScreenGui
Dragger.Size = UDim2.new(0, 80, 0, 80)      
Dragger.Position = UDim2.new(0.5, -40, 0.5, -40)
Dragger.BackgroundTransparency = 1             
Dragger.BorderSizePixel = 0
Dragger.Active = true

VisualFrame.Parent = Dragger
VisualFrame.Size = UDim2.new(0, 30, 0, 30)
VisualFrame.Position = UDim2.new(0.5, -15, 0.5, -15)
VisualFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
VisualFrame.BorderSizePixel = 0
VisualFrame.BackgroundTransparency = 0


local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0.2, 0)
UICorner.Parent = VisualFrame

local UIStroke = Instance.new("UIStroke")
UIStroke.Thickness = 2
UIStroke.Color = Color3.fromRGB(0, 170, 255)
UIStroke.Parent = VisualFrame

-- ===== الأيقونة (ثلج) =====
ImageLabel.Parent = VisualFrame
ImageLabel.Size = UDim2.new(0.6, 0, 0.6, 0)
ImageLabel.Position = UDim2.new(0.5, 0, 0.45, 0)
ImageLabel.AnchorPoint = Vector2.new(0.5, 0.5)
ImageLabel.BackgroundTransparency = 1
ImageLabel.Image = "rbxassetid://6034831242"
ImageLabel.ImageColor3 = Color3.fromRGB(0, 220, 255)

-- ===== النص ON/OFF =====
TextLabel.Parent = VisualFrame
TextLabel.Size = UDim2.new(1, 0, 0.25, 0)
TextLabel.Position = UDim2.new(0, 0, 0.7, 0)
TextLabel.BackgroundTransparency = 1
TextLabel.Text = "OFF"
TextLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
TextLabel.TextScaled = true
TextLabel.Font = Enum.Font.GothamBold

local frozen = false
local freezeConnection = nil
local frozenCFrame = nil

local function updateUI()
    if frozen then
        VisualFrame.BackgroundColor3 = Color3.fromRGB(0, 100, 0)
        UIStroke.Color = Color3.fromRGB(0, 255, 100)
        ImageLabel.ImageColor3 = Color3.fromRGB(0, 255, 150)
        TextLabel.Text = "ON"
        TextLabel.TextColor3 = Color3.fromRGB(0, 255, 100)
    else
        VisualFrame.BackgroundColor3 = Color3.fromRGB(100, 0, 0)
        UIStroke.Color = Color3.fromRGB(255, 80, 80)
        ImageLabel.ImageColor3 = Color3.fromRGB(255, 100, 100)
        TextLabel.Text = "OFF"
        TextLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
    end
end

local function getRoot()
    local char = player.Character or player.CharacterAdded:Wait()
    return char:WaitForChild("HumanoidRootPart", 5)
end

local function startFreeze()
    local hrp = getRoot()
    if not hrp then return end
    frozenCFrame = hrp.CFrame

    if freezeConnection then freezeConnection:Disconnect() end
    freezeConnection = RunService.RenderStepped:Connect(function()
        if frozen and player.Character then
            local root = player.Character:FindFirstChild("HumanoidRootPart")
            if root and frozenCFrame then
                root.Anchored = true
                root.CFrame = frozenCFrame
                root.AssemblyLinearVelocity = Vector3.zero
                root.AssemblyAngularVelocity = Vector3.zero
            end
        end
    end)
end

local function stopFreeze()
    if freezeConnection then
        freezeConnection:Disconnect()
        freezeConnection = nil
    end
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if root then root.Anchored = false end
    frozenCFrame = nil
end

local function toggleFreeze()
    frozen = not frozen
    if frozen then startFreeze() else stopFreeze() end
    updateUI()
end

Dragger.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        isHolding = true
        holdStartTime = tick()
        dragStart = input.Position
        startPos = Dragger.Position
    end
end)

Dragger.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        if isHolding then
            local holdDuration = tick() - holdStartTime
            if holdDuration < 0.3 then
                toggleFreeze()
            end
        end
        isHolding = false
        dragging = false
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if isHolding and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local holdDuration = tick() - holdStartTime
        if holdDuration >= 0.25 then dragging = true end

        if dragging then
            local delta = input.Position - dragStart
            Dragger.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end
end)

player.CharacterAdded:Connect(function(char)
    if frozen then
        task.delay(0.2, function()
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then frozenCFrame = hrp.CFrame end
        end)
    end
end)

updateUI()
