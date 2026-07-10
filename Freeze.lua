local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer

local freezeEnabled = false
local frozenCFrame = nil
local freezeConnection = nil

local gui = Instance.new("ScreenGui")
gui.Name = "FreezeGui"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local button = Instance.new("TextButton")
button.Name = "FreezeButton"
button.Size = UDim2.new(0, 60, 0, 60)

button.Position = UDim2.new(0, 20, 0.5, -30)
button.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
button.Text = "OFF"
button.TextColor3 = Color3.fromRGB(255, 255, 255)
button.Font = Enum.Font.GothamBold
button.TextSize = 22 
button.BorderSizePixel = 0
button.AutoButtonColor = false
button.Active = true
button.Parent = gui

local corner = Instance.new("UICorner")

corner.CornerRadius = UDim.new(1, 0)
corner.Parent = button

local function updateButton()
    if freezeEnabled then
        button.BackgroundColor3 = Color3.fromRGB(50, 180, 90)
        button.Text = "ON" 
    else
        button.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
        button.Text = "OFF" 
    end
end

local function startFreeze()
    local char = player.Character or player.CharacterAdded:Wait()
    local hrp = char:WaitForChild("HumanoidRootPart")
    frozenCFrame = hrp.CFrame

    if freezeConnection then
        freezeConnection:Disconnect()
        freezeConnection = nil
    end

    freezeConnection = RunService.RenderStepped:Connect(function()
        local c = player.Character
        if c and frozenCFrame then
            local root = c:FindFirstChild("HumanoidRootPart")
            if root then
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
    frozenCFrame = nil
end

local function toggleFreeze()
    freezeEnabled = not freezeEnabled
    if freezeEnabled then
        startFreeze()
    else
        stopFreeze()
    end
    updateButton()
end

button.Activated:Connect(function()
    toggleFreeze()
end)

local dragging = false
local dragStart = nil
local startPos = nil
local holdStart = 0
local longPressThreshold = 0.25
local dragReady = false
local dragInput = nil

button.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        holdStart = tick()
        dragReady = false
        dragStart = input.Position
        startPos = button.Position

        delay(longPressThreshold, function()
            if dragStart and (tick() - holdStart) >= longPressThreshold then
                dragReady = true
                dragging = true
            end
        end)

        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
                dragReady = false
                dragStart = nil
                startPos = nil
            end
        end)
    end
end)

button.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and dragReady and dragStart and startPos and input == dragInput then
        local delta = input.Position - dragStart
        button.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end
end)

updateButton()    end

    freezeConnection = RunService.RenderStepped:Connect(function()
        local c = player.Character
        if c and frozenCFrame then
            local root = c:FindFirstChild("HumanoidRootPart")
            if root then
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
    frozenCFrame = nil
end

local function toggleFreeze()
    freezeEnabled = not freezeEnabled
    if freezeEnabled then
        startFreeze()
    else
        stopFreeze()
    end
    updateButton()
end

button.Activated:Connect(function()
    toggleFreeze()
end)

local dragging = false
local dragStart = nil
local startPos = nil
local holdStart = 0
local longPressThreshold = 0.25
local dragReady = false
local dragInput = nil

button.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        holdStart = tick()
        dragReady = false
        dragStart = input.Position
        startPos = button.Position

        delay(longPressThreshold, function()
            if dragStart and (tick() - holdStart) >= longPressThreshold then
                dragReady = true
                dragging = true
            end
        end)

        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
                dragReady = false
                dragStart = nil
                startPos = nil
            end
        end)
    end
end)

button.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and dragReady and dragStart and startPos and input == dragInput then
        local delta = input.Position - dragStart
        button.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end
end)

updateButton()
