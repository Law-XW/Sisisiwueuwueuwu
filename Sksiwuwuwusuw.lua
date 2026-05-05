local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

local Options = Library.Options
local Toggles = Library.Toggles

Library.ShowToggleFrameInKeybinds = true

local Window = Library:CreateWindow({
    Title = "CounterBlox",
    Footer = "Xeioa",
    NotifySide = "Right",
    ShowCustomCursor = true,
    MobileButtonsSide = "Right",
})

local Tabs = {
    Combat = Window:AddTab("Combat", "crosshair"),
    Visual = Window:AddTab("Visual", "eye"),
    Movement = Window:AddTab("Movement", "wind"),
    Misc = Window:AddTab("Misc", "wrench"),
    UISettings = Window:AddTab("UI Settings", "settings"),
}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

local WorldToViewportPoint = Camera.WorldToViewportPoint
local GetPartsObscuringTarget = Camera.GetPartsObscuringTarget
local GetPlayers = Players.GetPlayers
local GetPlayerFromCharacter = Players.GetPlayerFromCharacter
local FindFirstChild = game.FindFirstChild
local FindFirstChildOfClass = game.FindFirstChildOfClass

local function WorldToScreen(pos)
    local screenPos, onScreen = WorldToViewportPoint(Camera, pos)
    return Vector2.new(screenPos.X, screenPos.Y), onScreen, screenPos.Z
end

local ESPObjects = {}

local function GetCharacter(player)
    return player and player.Character
end

local function GetRootPart(player)
    local char = GetCharacter(player)
    if not char then return nil end
    return FindFirstChild(char, "HumanoidRootPart") or FindFirstChild(char, "Torso")
end

local function GetHumanoid(player)
    local char = GetCharacter(player)
    if not char then return nil end
    return FindFirstChildOfClass(char, "Humanoid")
end

local function IsTeammate(player)
    if not Toggles.TeamCheck or not Toggles.TeamCheck.Value then return false end
    return player.Team ~= nil and player.Team == LocalPlayer.Team
end

local function IsAlive(player)
    local hum = GetHumanoid(player)
    return hum and hum.Health > 0
end

local SilentAimSettings = {
    Enabled = false,
    HitChance = 100,
    VisibleCheck = false,
}

local function IsPlayerVisible(player)
    local playerChar = player.Character
    local localChar = LocalPlayer.Character
    if not playerChar or not localChar then return false end
    local head = FindFirstChild(playerChar, "Head")
    if not head then return false end
    local castPoints = { head.Position, localChar, playerChar }
    local ignoreList = { localChar, playerChar }
    local obscuring = GetPartsObscuringTarget(Camera, castPoints, ignoreList)
    return #obscuring == 0
end

local FovCircle = Drawing.new("Circle")
FovCircle.Visible = false
FovCircle.Color = Color3.fromRGB(255, 255, 255)
FovCircle.Thickness = 1
FovCircle.Filled = false
FovCircle.NumSides = 64

local FovTracer = Drawing.new("Line")
FovTracer.Visible = false
FovTracer.Color = Color3.fromRGB(255, 255, 255)
FovTracer.Thickness = 1

local TargetHighlight = nil
local CurrentTarget = nil

local function ClearTargetHighlight()
    if TargetHighlight then
        TargetHighlight:Destroy()
        TargetHighlight = nil
    end
    CurrentTarget = nil
end

local function ApplyTargetHighlight(player)
    if CurrentTarget == player then return end
    ClearTargetHighlight()
    local char = GetCharacter(player)
    if not char then return end
    local hl = Instance.new("Highlight")
    hl.FillColor = Color3.fromRGB(255, 50, 50)
    hl.FillTransparency = 0.5
    hl.OutlineColor = Color3.fromRGB(255, 255, 255)
    hl.OutlineTransparency = 0
    hl.Adornee = char
    hl.Parent = game:GetService("CoreGui")
    TargetHighlight = hl
    CurrentTarget = player
end

local function GetFovOrigin()
    if Options.FovMode and Options.FovMode.Value == "Mouse" then
        return Vector2.new(Mouse.X, Mouse.Y)
    end
    return Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
end

local function GetClosestPlayer()
    local closest = nil
    local closestDist = nil
    local fovRadius = Options.FovRadius and Options.FovRadius.Value or 120
    local viewportCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)

    for _, player in next, GetPlayers(Players) do
        if player == LocalPlayer then continue end
        if IsTeammate(player) then continue end

        local character = player.Character
        if not character then continue end

        local humanoid = FindFirstChildOfClass(character, "Humanoid")
        if not humanoid or humanoid.Health <= 0 then continue end

        local head = FindFirstChild(character, "Head")
        if not head then continue end

        if SilentAimSettings.VisibleCheck and not IsPlayerVisible(player) then continue end

        local screenPos, onScreen = WorldToScreen(head.Position)
        if not onScreen then continue end

        local dist = (viewportCenter - screenPos).Magnitude
        if dist <= (closestDist or fovRadius) then
            closest = head
            closestDist = dist
        end
    end
    return closest
end

local function GetDirection(origin, target)
    return (target - origin).Unit * 1000
end

local function CalculateChance(Percentage)
    return math.random(1, 100) <= math.floor(Percentage)
end

local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(...)
    local Method = getnamecallmethod()
    local Arguments = {...}
    local self = Arguments[1]

    if SilentAimSettings.Enabled
        and self == workspace
        and not checkcaller()
        and Method == "FindPartOnRayWithIgnoreList"
        and CalculateChance(SilentAimSettings.HitChance)
    then
        local A_Ray = Arguments[2]
        if typeof(A_Ray) == "Ray" then
            local HitPart = GetClosestPlayer()
            if HitPart then
                local Origin = A_Ray.Origin
                local Direction = GetDirection(Origin, HitPart.Position)
                Arguments[2] = Ray.new(Origin, Direction)
                return oldNamecall(unpack(Arguments))
            end
        end
    end

    return oldNamecall(...)
end))

local function AimbotStep()
    if not Toggles.AimbotEnabled or not Toggles.AimbotEnabled.Value then return end

    local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
    local holding = false

    if isMobile then
        holding = true
    else
        holding = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
    end

    if not holding then
        ClearTargetHighlight()
        return
    end

    local target = GetClosestPlayer()
    if not target then
        ClearTargetHighlight()
        return
    end

    local targetPlayer = Players:GetPlayerFromCharacter(target.Parent)
    if targetPlayer and Toggles.TargetHighlight and Toggles.TargetHighlight.Value then
        ApplyTargetHighlight(targetPlayer)
    elseif not (Toggles.TargetHighlight and Toggles.TargetHighlight.Value) then
        ClearTargetHighlight()
    end

    local smoothing = Options.AimbotSmoothing and Options.AimbotSmoothing.Value or 1
    local currentCF = Camera.CFrame
    local targetCF = CFrame.lookAt(currentCF.Position, target.Position)
    Camera.CFrame = currentCF:Lerp(targetCF, 1 / smoothing)
end

local function CreateESPForPlayer(player)
    local objs = {}

    local corners = {}
    for i = 1, 8 do
        local line = Drawing.new("Line")
        line.Visible = false
        line.Color = Color3.fromRGB(255, 255, 255)
        line.Thickness = 1
        corners[i] = line
    end
    objs.Corners = corners

    objs.Box = Drawing.new("Square")
    objs.Box.Visible = false
    objs.Box.Color = Color3.fromRGB(255, 255, 255)
    objs.Box.Thickness = 1
    objs.Box.Filled = false

    objs.Name = Drawing.new("Text")
    objs.Name.Visible = false
    objs.Name.Color = Color3.fromRGB(255, 255, 255)
    objs.Name.Size = 13
    objs.Name.Outline = true
    objs.Name.Center = true
    objs.Name.Text = player.Name

    objs.Distance = Drawing.new("Text")
    objs.Distance.Visible = false
    objs.Distance.Color = Color3.fromRGB(200, 200, 200)
    objs.Distance.Size = 12
    objs.Distance.Outline = true
    objs.Distance.Center = true

    objs.HealthBar = Drawing.new("Square")
    objs.HealthBar.Visible = false
    objs.HealthBar.Color = Color3.fromRGB(0, 255, 0)
    objs.HealthBar.Filled = true
    objs.HealthBar.Thickness = 1

    objs.HealthBarBg = Drawing.new("Square")
    objs.HealthBarBg.Visible = false
    objs.HealthBarBg.Color = Color3.fromRGB(0, 0, 0)
    objs.HealthBarBg.Filled = false
    objs.HealthBarBg.Thickness = 1

    objs.HealthText = Drawing.new("Text")
    objs.HealthText.Visible = false
    objs.HealthText.Color = Color3.fromRGB(255, 255, 255)
    objs.HealthText.Size = 11
    objs.HealthText.Outline = true
    objs.HealthText.Center = true

    objs.HeadDot = Drawing.new("Circle")
    objs.HeadDot.Visible = false
    objs.HeadDot.Color = Color3.fromRGB(255, 255, 255)
    objs.HeadDot.Radius = 3
    objs.HeadDot.Filled = true
    objs.HeadDot.Thickness = 1
    objs.HeadDot.NumSides = 16

    ESPObjects[player] = objs
end

local function RemoveESPForPlayer(player)
    local objs = ESPObjects[player]
    if not objs then return end
    objs.Box:Remove()
    objs.Name:Remove()
    objs.Distance:Remove()
    objs.HealthBar:Remove()
    objs.HealthBarBg:Remove()
    objs.HealthText:Remove()
    objs.HeadDot:Remove()
    for _, line in ipairs(objs.Corners) do line:Remove() end
    ESPObjects[player] = nil
end

local function HideESP(objs)
    objs.Box.Visible = false
    objs.Name.Visible = false
    objs.Distance.Visible = false
    objs.HealthBar.Visible = false
    objs.HealthBarBg.Visible = false
    objs.HealthText.Visible = false
    objs.HeadDot.Visible = false
    for _, line in ipairs(objs.Corners) do line.Visible = false end
end

local function DrawCornerBox(objs, topLeft, topRight, botLeft, botRight, cornerSize)
    local lines = objs.Corners
    local cs = cornerSize
    local color = Options.BoxColor and Options.BoxColor.Value or Color3.fromRGB(255, 255, 255)

    lines[1].From = topLeft;  lines[1].To = topLeft + Vector2.new(cs, 0)
    lines[2].From = topLeft;  lines[2].To = topLeft + Vector2.new(0, cs)
    lines[3].From = topRight; lines[3].To = topRight - Vector2.new(cs, 0)
    lines[4].From = topRight; lines[4].To = topRight + Vector2.new(0, cs)
    lines[5].From = botLeft;  lines[5].To = botLeft + Vector2.new(cs, 0)
    lines[6].From = botLeft;  lines[6].To = botLeft - Vector2.new(0, cs)
    lines[7].From = botRight; lines[7].To = botRight - Vector2.new(cs, 0)
    lines[8].From = botRight; lines[8].To = botRight - Vector2.new(0, cs)

    for _, line in ipairs(lines) do
        line.Visible = true
        line.Color = color
        line.Thickness = 1
    end
end

local function RenderESP()
    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end

        local objs = ESPObjects[player]
        if not objs then continue end

        if not Toggles.ESPEnabled or not Toggles.ESPEnabled.Value then
            HideESP(objs)
            continue
        end

        if IsTeammate(player) then
            HideESP(objs)
            continue
        end

        local char = GetCharacter(player)
        local root = GetRootPart(player)
        local hum = GetHumanoid(player)

        if not char or not root or not hum or hum.Health <= 0 then
            HideESP(objs)
            continue
        end

        local headPart = char:FindFirstChild("Head")
        local headPos = headPart and headPart.Position or (root.Position + Vector3.new(0, 2.5, 0))
        local feetPos = root.Position - Vector3.new(0, 3, 0)

        local topScreen, onTop = WorldToScreen(headPos)
        local bottomScreen, onBottom = WorldToScreen(feetPos)

        if not onTop and not onBottom then
            HideESP(objs)
            continue
        end

        local height = math.abs(topScreen.Y - bottomScreen.Y)
        local width = height * 0.5
        local x = topScreen.X - width / 2
        local y = topScreen.Y
        local boxColor = Options.BoxColor and Options.BoxColor.Value or Color3.fromRGB(255, 255, 255)

        if Toggles.CornerBox and Toggles.CornerBox.Value then
            objs.Box.Visible = false
            local cs = width * 0.25
            DrawCornerBox(objs,
                Vector2.new(x, y),
                Vector2.new(x + width, y),
                Vector2.new(x, y + height),
                Vector2.new(x + width, y + height),
                cs
            )
        else
            for _, line in ipairs(objs.Corners) do line.Visible = false end
            objs.Box.Visible = true
            objs.Box.Position = Vector2.new(x, y)
            objs.Box.Size = Vector2.new(width, height)
            objs.Box.Color = boxColor
        end

        if Toggles.ESPName and Toggles.ESPName.Value then
            objs.Name.Visible = true
            objs.Name.Text = player.Name
            objs.Name.Position = Vector2.new(topScreen.X, topScreen.Y - 16)
            objs.Name.Color = Options.NameColor and Options.NameColor.Value or Color3.fromRGB(255, 255, 255)
        else
            objs.Name.Visible = false
        end

        local localRoot = GetRootPart(LocalPlayer)
        local dist = localRoot and math.floor((root.Position - localRoot.Position).Magnitude) or 0
        if Toggles.ESPDistance and Toggles.ESPDistance.Value then
            objs.Distance.Visible = true
            objs.Distance.Text = dist .. " studs"
            objs.Distance.Position = Vector2.new(topScreen.X, bottomScreen.Y + 2)
            objs.Distance.Color = Color3.fromRGB(200, 200, 200)
        else
            objs.Distance.Visible = false
        end

        local maxHp = math.max(hum.MaxHealth, 1)
        local hpPct = math.clamp(hum.Health / maxHp, 0, 1)
        local barH = math.max(height, 1)
        local barW = 4
        local barX = x - barW - 2
        local barY = y

        if Toggles.ESPHealthBar and Toggles.ESPHealthBar.Value then
            local fillH = math.max(barH * hpPct, 1)
            local fillY = barY + (barH - fillH)
            objs.HealthBar.Visible = true
            objs.HealthBar.Position = Vector2.new(barX, fillY)
            objs.HealthBar.Size = Vector2.new(barW, fillH)
            objs.HealthBar.Color = Color3.fromRGB(
                math.clamp(math.floor((1 - hpPct) * 255), 0, 255),
                math.clamp(math.floor(hpPct * 255), 0, 255),
                0
            )
            objs.HealthBarBg.Visible = true
            objs.HealthBarBg.Position = Vector2.new(barX, barY)
            objs.HealthBarBg.Size = Vector2.new(barW, barH)
        else
            objs.HealthBar.Visible = false
            objs.HealthBarBg.Visible = false
        end

        if Toggles.ESPHealthText and Toggles.ESPHealthText.Value then
            objs.HealthText.Visible = true
            objs.HealthText.Text = math.floor(hum.Health) .. " HP"
            objs.HealthText.Position = Vector2.new(barX + barW / 2, barY + barH + 2)
            objs.HealthText.Color = Color3.fromRGB(255, 255, 255)
        else
            objs.HealthText.Visible = false
        end

        local headScreenPos, headOnScreen = WorldToScreen(headPos)
        if Toggles.HeadDot and Toggles.HeadDot.Value and headOnScreen then
            objs.HeadDot.Visible = true
            objs.HeadDot.Position = headScreenPos
            objs.HeadDot.Color = boxColor
        else
            objs.HeadDot.Visible = false
        end
    end
end

local function RenderFOV()
    local showFov = Toggles.ShowFov and Toggles.ShowFov.Value
    FovCircle.Visible = showFov and true or false

    if showFov then
        local origin = GetFovOrigin()
        FovCircle.Position = origin
        FovCircle.Radius = Options.FovRadius and Options.FovRadius.Value or 120
        FovCircle.Color = Options.FovColor and Options.FovColor.Value or Color3.fromRGB(255, 255, 255)
        FovCircle.Thickness = Options.FovThickness and Options.FovThickness.Value or 1
    end

    local showTracer = Toggles.FovTracer and Toggles.FovTracer.Value
    if showTracer then
        local target = GetClosestPlayer()
        if target then
            local targetScreen, onScreen = WorldToScreen(target.Position)
            if onScreen then
                local origin = GetFovOrigin()
                FovTracer.Visible = true
                FovTracer.From = origin
                FovTracer.To = targetScreen
                FovTracer.Color = Options.FovTracerColor and Options.FovTracerColor.Value or Color3.fromRGB(255, 80, 80)
                FovTracer.Thickness = 1
            else
                FovTracer.Visible = false
            end
        else
            FovTracer.Visible = false
        end
    else
        FovTracer.Visible = false
    end
end

local NoClipConn = nil
local CFSpeedConn = nil
local InfiniteJumpConn = nil
local BhopConn = nil

local IsMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local function StartCFSpeed()
    CFSpeedConn = RunService.RenderStepped:Connect(function()
        if not Toggles.CFSpeedEnabled or not Toggles.CFSpeedEnabled.Value then return end
        local char = LocalPlayer.Character
        if not char then return end
        local root = FindFirstChild(char, "HumanoidRootPart")
        if not root then return end
        local speed = Options.CFSpeed and Options.CFSpeed.Value or 50
        local moveDir = Vector3.zero
        local cf = Camera.CFrame
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + cf.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - cf.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - cf.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + cf.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDir = moveDir + Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then moveDir = moveDir - Vector3.new(0, 1, 0) end
        if moveDir.Magnitude > 0 then
            root.CFrame = root.CFrame + moveDir.Unit * speed * 0.05
        end
    end)
end
StartCFSpeed()

local function StartNoClip()
    NoClipConn = RunService.Stepped:Connect(function()
        if not Toggles.NoClip or not Toggles.NoClip.Value then return end
        local char = LocalPlayer.Character
        if not char then return end
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end)
end
StartNoClip()

local function StartInfiniteJump()
    InfiniteJumpConn = UserInputService.JumpRequest:Connect(function()
        if not Toggles.InfiniteJump or not Toggles.InfiniteJump.Value then return end
        local char = LocalPlayer.Character
        local hum = char and FindFirstChildOfClass(char, "Humanoid")
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end)
end
StartInfiniteJump()

local function StartBhop()
    BhopConn = RunService.Stepped:Connect(function()
        if not Toggles.BhopEnabled or not Toggles.BhopEnabled.Value then return end
        local char = LocalPlayer.Character
        if not char then return end
        local hum = FindFirstChildOfClass(char, "Humanoid")
        local root = FindFirstChild(char, "HumanoidRootPart")
        if not hum or not root then return end

        local state = hum:GetState()
        local spaceHeld = IsMobile or UserInputService:IsKeyDown(Enum.KeyCode.Space)

        if spaceHeld and (state == Enum.HumanoidStateType.Landed or state == Enum.HumanoidStateType.Running) then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end

        if state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Jumping then
            local speed = Options.BhopSpeed and Options.BhopSpeed.Value or 30
            local cf = Camera.CFrame
            local moveDir = Vector3.zero

            if IsMobile then
                moveDir = hum.MoveDirection
            else
                if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + cf.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - cf.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - cf.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + cf.RightVector end
            end

            if moveDir.Magnitude > 0 then
                local flat = Vector3.new(moveDir.X, 0, moveDir.Z).Unit
                local vel = root.AssemblyLinearVelocity
                root.AssemblyLinearVelocity = Vector3.new(flat.X * speed, vel.Y, flat.Z * speed)
            end
        end
    end)
end
StartBhop()

RunService.RenderStepped:Connect(function()
    RenderESP()
    RenderFOV()
    AimbotStep()

    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then
        if Toggles.WalkSpeedEnabled and Toggles.WalkSpeedEnabled.Value then
            hum.WalkSpeed = Options.WalkSpeed and Options.WalkSpeed.Value or 16
        end
        if Toggles.JumpPowerEnabled and Toggles.JumpPowerEnabled.Value then
            hum.JumpPower = Options.JumpPower and Options.JumpPower.Value or 50
        end
    end
end)

Players.PlayerAdded:Connect(function(player)
    CreateESPForPlayer(player)
end)
Players.PlayerRemoving:Connect(function(player)
    RemoveESPForPlayer(player)
    if CurrentTarget == player then ClearTargetHighlight() end
end)
for _, player in ipairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then
        CreateESPForPlayer(player)
    end
end

local CombatLeft = Tabs.Combat:AddLeftGroupbox("ESP Box", "box")
local CombatRight = Tabs.Combat:AddRightGroupbox("Silent Aim", "target")
local CombatRight2 = Tabs.Combat:AddRightGroupbox("Aimbot", "crosshair")

CombatLeft:AddToggle("ESPEnabled", {
    Text = "Enable ESP",
    Default = false,
})

CombatLeft:AddToggle("ESPName", {
    Text = "Show Name",
    Default = true,
})

CombatLeft:AddToggle("ESPDistance", {
    Text = "Show Distance",
    Default = true,
})

CombatLeft:AddToggle("CornerBox", {
    Text = "Corner Box",
    Default = false,
})

CombatLeft:AddToggle("ESPHealthBar", {
    Text = "Health Bar",
    Default = true,
})

CombatLeft:AddToggle("ESPHealthText", {
    Text = "Health Text",
    Default = false,
})

CombatLeft:AddDivider()

CombatLeft:AddLabel("Box Color"):AddColorPicker("BoxColor", {
    Default = Color3.fromRGB(255, 255, 255),
    Title = "Box Color",
})

CombatLeft:AddLabel("Name Color"):AddColorPicker("NameColor", {
    Default = Color3.fromRGB(255, 255, 255),
    Title = "Name Color",
})

CombatLeft:AddDivider()

CombatLeft:AddToggle("TeamCheck", {
    Text = "Team Check",
    Default = true,
})

CombatRight:AddToggle("SilentAimEnabled", {
    Text = "Silent Aim",
    Default = false,
    Risky = true,
})

Toggles.SilentAimEnabled:OnChanged(function()
    SilentAimSettings.Enabled = Toggles.SilentAimEnabled.Value
end)

CombatRight:AddSlider("SilentAimChance", {
    Text = "Hit Chance (%)",
    Default = 100,
    Min = 1,
    Max = 100,
    Rounding = 0,
})

Options.SilentAimChance:OnChanged(function()
    SilentAimSettings.HitChance = Options.SilentAimChance.Value
end)

CombatRight:AddToggle("SilentAimVisCheck", {
    Text = "Visible Check",
    Default = false,
})

Toggles.SilentAimVisCheck:OnChanged(function()
    SilentAimSettings.VisibleCheck = Toggles.SilentAimVisCheck.Value
end)

CombatRight:AddDivider()

CombatRight:AddToggle("ShowFov", {
    Text = "Show FOV Circle",
    Default = true,
})

CombatRight:AddSlider("FovRadius", {
    Text = "FOV Radius",
    Default = 120,
    Min = 10,
    Max = 500,
    Rounding = 0,
})

CombatRight:AddSlider("FovThickness", {
    Text = "FOV Thickness",
    Default = 1,
    Min = 1,
    Max = 5,
    Rounding = 0,
})

CombatRight:AddLabel("FOV Color"):AddColorPicker("FovColor", {
    Default = Color3.fromRGB(255, 255, 255),
    Title = "FOV Circle Color",
})

CombatRight:AddDropdown("FovMode", {
    Values = { "Center", "Mouse" },
    Default = "Center",
    Text = "FOV Origin",
})

CombatRight:AddDivider()

CombatRight:AddToggle("FovTracer", {
    Text = "FOV Tracer",
    Default = false,
})

CombatRight:AddLabel("Tracer Color"):AddColorPicker("FovTracerColor", {
    Default = Color3.fromRGB(255, 80, 80),
    Title = "FOV Tracer Color",
})

CombatRight2:AddToggle("AimbotEnabled", {
    Text = "Aimbot",
    Default = false,
    Risky = true,
})

CombatRight2:AddToggle("TargetHighlight", {
    Text = "Highlight Target",
    Default = false,
})

CombatRight2:AddSlider("AimbotSmoothing", {
    Text = "Smoothing",
    Default = 5,
    Min = 1,
    Max = 20,
    Rounding = 1,
})

CombatRight2:AddLabel("Keybind"):AddKeyPicker("AimbotKey", {
    Default = "MB2",
    Mode = "Hold",
    Text = "Aimbot Key",
    SyncToggleState = false,
})

local VisualLeft = Tabs.Visual:AddLeftGroupbox("Players", "users")
local VisualRight = Tabs.Visual:AddRightGroupbox("World", "globe")

VisualLeft:AddToggle("ChamsEnabled", {
    Text = "Chams (Highlight)",
    Default = false,
})

VisualLeft:AddLabel("Chams Color"):AddColorPicker("ChamsColor", {
    Default = Color3.fromRGB(255, 0, 0),
    Title = "Chams Color",
    Transparency = 0.5,
})

local ChamsPool = {}

local function RemoveChams(player)
    if ChamsPool[player] then
        ChamsPool[player]:Destroy()
        ChamsPool[player] = nil
    end
end

local function ApplyChams(player)
    RemoveChams(player)
    local char = GetCharacter(player)
    if not char then return end
    local hl = Instance.new("Highlight")
    hl.FillColor = Options.ChamsColor and Options.ChamsColor.Value or Color3.fromRGB(255, 0, 0)
    hl.FillTransparency = Options.ChamsColor and Options.ChamsColor.Transparency or 0.5
    hl.OutlineColor = Color3.fromRGB(255, 255, 255)
    hl.OutlineTransparency = 0
    hl.Adornee = char
    hl.Parent = game:GetService("CoreGui")
    ChamsPool[player] = hl
end

local function RefreshAllChams()
    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        if IsTeammate(player) then continue end
        if Toggles.ChamsEnabled.Value then
            ApplyChams(player)
        else
            RemoveChams(player)
        end
    end
end

Toggles.ChamsEnabled:OnChanged(function()
    RefreshAllChams()
end)

Options.ChamsColor:OnChanged(function()
    if not Toggles.ChamsEnabled or not Toggles.ChamsEnabled.Value then return end
    for _, hl in pairs(ChamsPool) do
        hl.FillColor = Options.ChamsColor.Value
        hl.FillTransparency = Options.ChamsColor.Transparency or 0.5
    end
end)

Players.PlayerRemoving:Connect(function(player)
    RemoveChams(player)
end)

VisualLeft:AddDivider()

VisualLeft:AddToggle("HeadDot", {
    Text = "Head Dot",
    Default = false,
})

VisualLeft:AddSlider("MaxESPDistance", {
    Text = "Max ESP Distance",
    Default = 1000,
    Min = 50,
    Max = 3000,
    Rounding = 0,
    Suffix = " studs",
})

VisualRight:AddToggle("FullbrightEnabled", {
    Text = "Fullbright",
    Default = false,
})

local Lighting = game:GetService("Lighting")
Toggles.FullbrightEnabled:OnChanged(function()
    if Toggles.FullbrightEnabled.Value then
        Lighting.Brightness = 2
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 100000
    else
        Lighting.Brightness = 1
        Lighting.GlobalShadows = true
    end
end)

VisualRight:AddToggle("CrosshairEnabled", {
    Text = "Custom Crosshair",
    Default = false,
})

VisualRight:AddDropdown("CrosshairStyle", {
    Values = { "Cross", "T-Cross", "Dot", "Circle" },
    Default = "Cross",
    Text = "Style",
})

VisualRight:AddSlider("CrosshairSize", {
    Text = "Size",
    Default = 10,
    Min = 2,
    Max = 60,
    Rounding = 0,
})

VisualRight:AddSlider("CrosshairGap", {
    Text = "Gap",
    Default = 3,
    Min = 0,
    Max = 20,
    Rounding = 0,
})

VisualRight:AddSlider("CrosshairThickness", {
    Text = "Thickness",
    Default = 1,
    Min = 1,
    Max = 6,
    Rounding = 0,
})

VisualRight:AddSlider("CrosshairRotation", {
    Text = "Rotation",
    Default = 0,
    Min = 0,
    Max = 360,
    Rounding = 0,
    Suffix = "°",
})

VisualRight:AddToggle("CrosshairSpin", {
    Text = "Auto-Rotate (Spin)",
    Default = false,
})

VisualRight:AddSlider("CrosshairSpinSpeed", {
    Text = "Spin Speed",
    Default = 90,
    Min = 5,
    Max = 720,
    Rounding = 0,
    Suffix = "°/s",
})

VisualRight:AddDivider()

VisualRight:AddToggle("CrosshairLabel", {
    Text = "Label under Crosshair",
    Default = false,
})

VisualRight:AddToggle("CrosshairOutline", {
    Text = "Outline",
    Default = true,
})

VisualRight:AddLabel("Color"):AddColorPicker("CrosshairColor", {
    Default = Color3.fromRGB(255, 255, 255),
    Title = "Crosshair Color",
})

VisualRight:AddLabel("Outline Color"):AddColorPicker("CrosshairOutlineColor", {
    Default = Color3.fromRGB(0, 0, 0),
    Title = "Crosshair Outline Color",
})

local CH = { Lines = {}, Outlines = {}, SpinAngle = 0 }
for i = 1, 4 do
    local l = Drawing.new("Line"); l.Visible = false; l.Thickness = 1
    local o = Drawing.new("Line"); o.Visible = false; o.Thickness = 3
    CH.Lines[i] = l; CH.Outlines[i] = o
end
CH.Dot     = Drawing.new("Circle"); CH.Dot.Filled = true;  CH.Dot.Visible = false; CH.Dot.NumSides = 32
CH.DotOut  = Drawing.new("Circle"); CH.DotOut.Filled = true;  CH.DotOut.Visible = false; CH.DotOut.NumSides = 32
CH.Ring    = Drawing.new("Circle"); CH.Ring.Filled = false; CH.Ring.Visible = false; CH.Ring.NumSides = 64
CH.RingOut = Drawing.new("Circle"); CH.RingOut.Filled = false; CH.RingOut.Visible = false; CH.RingOut.NumSides = 64
CH.Label    = Drawing.new("Text");  CH.Label.Visible = false; CH.Label.Center = true
CH.Label.Size = 14; CH.Label.Outline = true; CH.Label.Text = "Xeioa"
CH.LabelOut = Drawing.new("Text"); CH.LabelOut.Visible = false; CH.LabelOut.Center = true
CH.LabelOut.Size = 14; CH.LabelOut.Outline = false; CH.LabelOut.Text = "Xeioa"

local function RenderCrosshair(dt)
    local show = Toggles.CrosshairEnabled and Toggles.CrosshairEnabled.Value
    for i = 1, 4 do CH.Lines[i].Visible = false; CH.Outlines[i].Visible = false end
    CH.Dot.Visible = false; CH.DotOut.Visible = false
    CH.Ring.Visible = false; CH.RingOut.Visible = false
    CH.Label.Visible = false; CH.LabelOut.Visible = false
    if not show then return end

    local cx = Camera.ViewportSize.X / 2
    local cy = Camera.ViewportSize.Y / 2
    local center = Vector2.new(cx, cy)

    local style   = Options.CrosshairStyle     and Options.CrosshairStyle.Value     or "Cross"
    local size    = Options.CrosshairSize      and Options.CrosshairSize.Value      or 10
    local gap     = Options.CrosshairGap       and Options.CrosshairGap.Value       or 3
    local thick   = Options.CrosshairThickness and Options.CrosshairThickness.Value or 1
    local col     = Options.CrosshairColor     and Options.CrosshairColor.Value     or Color3.fromRGB(255, 255, 255)
    local outline = Toggles.CrosshairOutline   and Toggles.CrosshairOutline.Value
    local outCol  = Options.CrosshairOutlineColor and Options.CrosshairOutlineColor.Value or Color3.fromRGB(0, 0, 0)
    local spin    = Toggles.CrosshairSpin      and Toggles.CrosshairSpin.Value

    local ang
    if spin then
        local spinSpeed = Options.CrosshairSpinSpeed and Options.CrosshairSpinSpeed.Value or 90
        CH.SpinAngle = (CH.SpinAngle + math.rad(spinSpeed) * dt) % (math.pi * 2)
        ang = CH.SpinAngle
    else
        ang = math.rad(Options.CrosshairRotation and Options.CrosshairRotation.Value or 0)
    end

    local cosA, sinA = math.cos(ang), math.sin(ang)
    local function rv(dx, dy) return Vector2.new(dx * cosA - dy * sinA, dx * sinA + dy * cosA) end

    if style == "Dot" then
        local r = math.max(size / 2, 1)
        if outline then
            CH.DotOut.Visible = true; CH.DotOut.Position = center
            CH.DotOut.Radius = r + 2; CH.DotOut.Color = outCol; CH.DotOut.Thickness = 1
        end
        CH.Dot.Visible = true; CH.Dot.Position = center
        CH.Dot.Radius = r; CH.Dot.Color = col; CH.Dot.Thickness = 1

    elseif style == "Circle" then
        local r = math.max(size, 2)
        if outline then
            CH.RingOut.Visible = true; CH.RingOut.Position = center
            CH.RingOut.Radius = r + 1; CH.RingOut.Color = outCol; CH.RingOut.Thickness = thick + 2
        end
        CH.Ring.Visible = true; CH.Ring.Position = center
        CH.Ring.Radius = r; CH.Ring.Color = col; CH.Ring.Thickness = thick

    else
        local dirs = { rv(1, 0), rv(-1, 0), rv(0, -1), rv(0, 1) }
        local count = (style == "T-Cross") and 3 or 4
        for i = 1, count do
            local d = dirs[i]
            local from = center + d * gap
            local to   = center + d * (gap + size)
            if outline then
                CH.Outlines[i].Visible = true
                CH.Outlines[i].From = from; CH.Outlines[i].To = to
                CH.Outlines[i].Color = outCol; CH.Outlines[i].Thickness = thick + 2
            end
            CH.Lines[i].Visible = true
            CH.Lines[i].From = from; CH.Lines[i].To = to
            CH.Lines[i].Color = col; CH.Lines[i].Thickness = thick
        end
    end

    if Toggles.CrosshairLabel and Toggles.CrosshairLabel.Value then
        local labelY = cy + (size + gap) + 10
        CH.Label.Visible = true
        CH.Label.Position = Vector2.new(cx, labelY)
        CH.Label.Color = col
        CH.Label.Font = 2
    end
end

RunService.RenderStepped:Connect(function(dt) RenderCrosshair(dt) end)

local MovLeft = Tabs.Movement:AddLeftGroupbox("Character", "zap")
local MovRight = Tabs.Movement:AddRightGroupbox("CFrame Speed (Fly)", "wind")

MovLeft:AddToggle("WalkSpeedEnabled", {
    Text = "Custom WalkSpeed",
    Default = false,
})

MovLeft:AddSlider("WalkSpeed", {
    Text = "Walk Speed",
    Default = 16,
    Min = 1,
    Max = 500,
    Rounding = 0,
    Suffix = " u/s",
})

MovLeft:AddToggle("JumpPowerEnabled", {
    Text = "Custom Jump Power",
    Default = false,
})

MovLeft:AddSlider("JumpPower", {
    Text = "Jump Power",
    Default = 50,
    Min = 1,
    Max = 300,
    Rounding = 0,
})

MovLeft:AddDivider()

MovLeft:AddToggle("NoClip", {
    Text = "No Clip",
    Default = false,
    Risky = true,
})

MovLeft:AddToggle("InfiniteJump", {
    Text = "Infinite Jump",
    Default = false,
})

MovLeft:AddToggle("BhopEnabled", {
    Text = "Bunny Hop",
    Default = false,
})

MovLeft:AddSlider("BhopSpeed", {
    Text = "Bhop Speed",
    Default = 30,
    Min = 5,
    Max = 200,
    Rounding = 0,
    Suffix = " u/s",
})

MovRight:AddToggle("CFSpeedEnabled", {
    Text = "CFrame Speed (Fly)",
    Default = false,
    Risky = true,
})

MovRight:AddSlider("CFSpeed", {
    Text = "Fly Speed",
    Default = 50,
    Min = 5,
    Max = 500,
    Rounding = 0,
    Suffix = " u/s",
})

MovRight:AddDivider()
MovRight:AddLabel("WASD + Space / Ctrl to fly.\nWorks on Mobile (virtual joystick)", true)

local MiscLeft = Tabs.Misc:AddLeftGroupbox("General", "tool")
local MiscRight = Tabs.Misc:AddRightGroupbox("Notifications", "bell")

MiscLeft:AddToggle("AntiAFK", {
    Text = "Anti-AFK",
    Default = true,
})

Toggles.AntiAFK:OnChanged(function()
    if Toggles.AntiAFK.Value then
        local vPlayer = Players.LocalPlayer
        vPlayer.Idled:Connect(function()
            if Toggles.AntiAFK and Toggles.AntiAFK.Value then
                game:GetService("VirtualUser"):CaptureController()
                game:GetService("VirtualUser"):ClickButton2(Vector2.new())
            end
        end)
    end
end)

MiscLeft:AddToggle("HideUI", {
    Text = "Hide UI (Panic)",
    Default = false,
    Risky = true,
})

Toggles.HideUI:OnChanged(function()
    if Toggles.HideUI.Value then
        Library:SetVisible(false)
    end
end)

MiscLeft:AddDivider()
MiscLeft:AddLabel("Menu Keybind"):AddKeyPicker("MenuKeybind", {
    Default = "RightShift",
    NoUI = true,
    Text = "Menu keybind",
})
Library.ToggleKeybind = Options.MenuKeybind

MiscLeft:AddButton({
    Text = "Unload Script",
    Func = function() Library:Unload() end,
    DoubleClick = true,
})

MiscRight:AddDropdown("NotificationSide", {
    Values = { "Left", "Right" },
    Default = "Right",
    Text = "Notification Side",
    Callback = function(v)
        Library:SetNotifySide(v)
    end,
})

MiscRight:AddButton({
    Text = "Test Notification",
    Func = function()
        Library:Notify({
            Title = "Script",
            Description = "Notification test!",
            Time = 3,
        })
    end,
})

local UIGroup = Tabs.UISettings:AddLeftGroupbox("Menu", "settings")

UIGroup:AddToggle("KeybindMenuOpen", {
    Default = false,
    Text = "Open Keybind Menu",
    Callback = function(v)
        Library.KeybindFrame.Visible = v
    end,
})

UIGroup:AddToggle("ShowCustomCursor", {
    Text = "Custom Cursor",
    Default = true,
    Callback = function(v)
        Library.ShowCustomCursor = v
    end,
})

UIGroup:AddDropdown("DPIDropdown", {
    Values = { "50%", "75%", "100%", "125%", "150%", "175%", "200%" },
    Default = "100%",
    Text = "DPI Scale",
    Callback = function(v)
        v = v:gsub("%%", "")
        Library:SetDPIScale(tonumber(v))
    end,
})

UIGroup:AddSlider("UICornerSlider", {
    Text = "Corner Radius",
    Default = Library.CornerRadius or 6,
    Min = 0,
    Max = 20,
    Rounding = 0,
    Callback = function(v)
        Window:SetCornerRadius(v)
    end,
})

UIGroup:AddDivider()

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ "MenuKeybind" })
ThemeManager:SetFolder("ObsidianScript")
SaveManager:SetFolder("ObsidianScript/configs")

SaveManager:BuildConfigSection(Tabs.UISettings)
ThemeManager:ApplyToTab(Tabs.UISettings)

SaveManager:LoadAutoloadConfig()

Library:Notify({
    Title = "Script Loaded",
    Description = "Use RightShift to toggle the menu.",
    Time = 4,
})
