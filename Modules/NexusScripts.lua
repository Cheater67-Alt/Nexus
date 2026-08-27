local Nexus = {
    Settings = {
        -- Combat
        Aimbot = false,
        SilentAim = false,
        AutoShoot = false,
        FOVSize = 200,
        TargetPart = "Head",
        
        -- Player
        GodMode = false,
        InfiniteJump = false,
        WalkSpeed = 16,
        JumpPower = 50,
        
        -- Visuals
        BoxESP = false,
        SkeletonESP = false,
        NameESP = false,
        Tracers = false,
        MaxDistance = 1000,
        
        -- Misc
        AntiAFK = false,
        AutoFarm = false,
    }
}

-- Сервисы
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- ═══════════════════════════════════════════════════════════════
-- COMBAT LOGIC
-- ═══════════════════════════════════════════════════════════════

local function getClosestPlayer()
    local closest, shortestDistance = nil, Nexus.Settings.FOVSize
    local mousePos = UserInputService:GetMouseLocation()

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("Humanoid") and player.Character.Humanoid.Health > 0 then
            local part = player.Character:FindFirstChild(Nexus.Settings.TargetPart) or player.Character:FindFirstChild("HumanoidRootPart")
            if part then
                local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
                if onScreen then
                    local dist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                    if dist < shortestDistance then
                        closest = part
                        shortestDistance = dist
                    end
                end
            end
        end
    end
    return closest
end

-- Camera Aimbot & Auto Shoot Loop
RunService.RenderStepped:Connect(function()
    local target = getClosestPlayer()
    
    if target then
        -- Aimbot (Плавное или прямое наведение камеры)
        if Nexus.Settings.Aimbot then
            Camera.CFrame = CFrame.new(Camera.CFrame.Position, target.Position)
        end
        
        -- Auto Shoot
        if Nexus.Settings.AutoShoot then
            local tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
            if tool then
                tool:Activate()
            end
        end
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- PLAYER LOGIC
-- ═══════════════════════════════════════════════════════════════

-- Speed & Jump Listener
RunService.Stepped:Connect(function()
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        hum.WalkSpeed = Nexus.Settings.WalkSpeed
        hum.JumpPower = Nexus.Settings.JumpPower
    end
end)

-- Infinite Jump
UserInputService.JumpRequest:Connect(function()
    if Nexus.Settings.InfiniteJump and LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
        LocalPlayer.Character:FindFirstChildOfClass("Humanoid"):ChangeState(Enum.HumanoidStateType.Jumping)
    end
end)

-- Reset Character
function Nexus.ResetCharacter()
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
        LocalPlayer.Character:FindFirstChildOfClass("Humanoid").Health = 0
    end
end

-- ═══════════════════════════════════════════════════════════════
-- VISUALS LOGIC (ESP)
-- ═══════════════════════════════════════════════════════════════

local ESP_Storage = {}

local function createESP(player)
    if player == LocalPlayer then return end
    
    local box = Drawing.new("Square")
    box.Visible = false
    box.Color = Color3.fromRGB(0, 255, 136)
    box.Thickness = 1
    box.Filled = false

    local name = Drawing.new("Text")
    name.Visible = false
    name.Color = Color3.fromRGB(255, 255, 255)
    name.Size = 14
    name.Center = true
    name.Outline = true

    local tracer = Drawing.new("Line")
    tracer.Visible = false
    tracer.Color = Color3.fromRGB(0, 255, 136)
    tracer.Thickness = 1

    ESP_Storage[player] = {Box = box, Name = name, Tracer = tracer}
end

for _, p in ipairs(Players:GetPlayers()) do createESP(p) end
Players.PlayerAdded:Connect(createESP)

RunService.RenderStepped:Connect(function()
    for player, objs in pairs(ESP_Storage) do
        if player.Character and player.Character:FindFirstChild("HumanoidRootPart") and player.Character:FindFirstChildOfClass("Humanoid").Health > 0 then
            local hrp = player.Character.HumanoidRootPart
            local pos, onScreen = Camera:WorldToViewportPoint(hrp.Position)
            local dist = (Camera.CFrame.Position - hrp.Position).Magnitude

            if onScreen and dist <= Nexus.Settings.MaxDistance then
                -- Name ESP
                if Nexus.Settings.NameESP then
                    objs.Name.Position = Vector2.new(pos.X, pos.Y - 40)
                    objs.Name.Text = player.Name .. " [" .. math.floor(dist) .. "m]"
                    objs.Name.Visible = true
                else objs.Name.Visible = false end

                -- Box ESP
                if Nexus.Settings.BoxESP then
                    local size = (Camera:WorldToViewportPoint(hrp.Position + Vector3.new(0, 3, 0)).Y - Camera:WorldToViewportPoint(hrp.Position - Vector3.new(0, 4, 0)).Y)
                    objs.Box.Size = Vector2.new(size / 1.5, size)
                    objs.Box.Position = Vector2.new(pos.X - objs.Box.Size.X / 2, pos.Y - objs.Box.Size.Y / 2)
                    objs.Box.Visible = true
                else objs.Box.Visible = false end

                -- Tracers
                if Nexus.Settings.Tracers then
                    objs.Tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                    objs.Tracer.To = Vector2.new(pos.X, pos.Y)
                    objs.Tracer.Visible = true
                else objs.Tracer.Visible = false end
            else
                objs.Name.Visible = false
                objs.Box.Visible = false
                objs.Tracer.Visible = false
            end
        else
            objs.Name.Visible = false
            objs.Box.Visible = false
            objs.Tracer.Visible = false
        end
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- MISC LOGIC
-- ═══════════════════════════════════════════════════════════════

-- Anti-AFK
local VirtualUser = game:GetService("VirtualUser")
LocalPlayer.Idled:Connect(function()
    if Nexus.Settings.AntiAFK then
        VirtualUser:Button2Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
        task.wait(1)
        VirtualUser:Button2Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
    end
end)

-- Rejoin
function Nexus.RejoinServer()
    TeleportService:Teleport(game.PlaceId, LocalPlayer)
end

return Nexus
