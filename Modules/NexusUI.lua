--[[
    NEXUS UI — полный интерфейс
    Управляет глобальной таблицей _G.Nexus
--]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local CONFIG = {
    Colors = {
        Background = Color3.fromRGB(15, 15, 18),
        Surface = Color3.fromRGB(25, 25, 30),
        SurfaceHover = Color3.fromRGB(35, 35, 42),
        SurfaceActive = Color3.fromRGB(40, 40, 48),
        Accent = Color3.fromRGB(0, 255, 136),
        TextPrimary = Color3.fromRGB(240, 240, 245),
        TextSecondary = Color3.fromRGB(150, 150, 160),
        Border = Color3.fromRGB(40, 40, 50),
        ToggleOff = Color3.fromRGB(60, 60, 70),
        ToggleOn = Color3.fromRGB(0, 255, 136),
        SliderTrack = Color3.fromRGB(40, 40, 50),
        SliderFill = Color3.fromRGB(0, 255, 136),
    },
    Sizes = {
        WindowWidth = 700,
        WindowHeight = 450,
        SidebarWidth = 160,
        HeaderHeight = 45,
        ElementHeight = 36,
        CornerRadius = 8,
        ElementPadding = 6,
    },
    Animations = {
        Fast = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        Medium = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        Slow = TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
        Bounce = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
    }
}

local function Create(className, props)
    local inst = Instance.new(className)
    for k, v in pairs(props or {}) do
        inst[k] = v
    end
    return inst
end

local function Tween(inst, info, props)
    local t = TweenService:Create(inst, info, props)
    t:Play()
    return t
end

local function HoverEffect(btn, normal, hover)
    btn.MouseEnter:Connect(function()
        Tween(btn, CONFIG.Animations.Fast, {BackgroundColor3 = hover})
    end)
    btn.MouseLeave:Connect(function()
        Tween(btn, CONFIG.Animations.Fast, {BackgroundColor3 = normal})
    end)
end

local function IsPress(input)
    return input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch
end

local function IsMove(input)
    return input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch
end

local NexusUI = {}
NexusUI.__index = NexusUI

function NexusUI.new()
    local self = setmetatable({}, NexusUI)
    self.IsOpen = false
    self.IsAnimating = false
    self.IsMinimized = false
    self.CurrentTab = nil
    self.Tabs = {}
    self.OpenDropdowns = {}
    self:Init()
    return self
end

function NexusUI:Init()
    self.Gui = Create("ScreenGui", {
        Name = "NexusUI",
        Parent = PlayerGui,
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 9999,
    })

    self.Container = Create("Frame", {
        Name = "Container",
        Parent = self.Gui,
        BackgroundTransparency = 1,
        Size = UDim2.new(0, CONFIG.Sizes.WindowWidth, 0, CONFIG.Sizes.WindowHeight),
        Position = UDim2.new(0.5, -CONFIG.Sizes.WindowWidth/2, 0.5, -CONFIG.Sizes.WindowHeight/2),
        Active = true,
        Visible = false,
        ClipsDescendants = true,
    })

    self.UIScale = Create("UIScale", {Parent = self.Container})
    local function UpdateScale()
        local vp = workspace.CurrentCamera.ViewportSize
        local s = math.min(1, math.min(vp.X / 900, vp.Y / 600))
        Tween(self.UIScale, CONFIG.Animations.Medium, {Scale = s})
    end
    UpdateScale()
    local viewportConn
    local function RebindCamera()
        if viewportConn then viewportConn:Disconnect() end
        viewportConn = workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(UpdateScale)
        UpdateScale()
    end
    RebindCamera()
    workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(RebindCamera)

    self.MainFrame = Create("CanvasGroup", {
        Name = "MainFrame",
        Parent = self.Container,
        BackgroundColor3 = CONFIG.Colors.Background,
        GroupTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 1, 0),
        ClipsDescendants = true,
    })
    Create("UICorner", {CornerRadius = UDim.new(0, CONFIG.Sizes.CornerRadius), Parent = self.MainFrame})
    Create("UIStroke", {Color = CONFIG.Colors.Border, Thickness = 1, Transparency = 0.5, Parent = self.MainFrame})

    self:BuildHeader()
    self:BuildSidebar()
    self:BuildContentArea()
    self:BuildTabs()
    self:EnableDrag()
    self:SetupToggleKey()
end

function NexusUI:BuildHeader()
    self.Header = Create("Frame", {
        Name = "Header",
        Parent = self.MainFrame,
        BackgroundColor3 = CONFIG.Colors.Surface,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, CONFIG.Sizes.HeaderHeight),
        ZIndex = 2,
        Active = true,
    })
    Create("UICorner", {CornerRadius = UDim.new(0, CONFIG.Sizes.CornerRadius), Parent = self.Header})

    Create("Frame", {
        Parent = self.Header,
        BackgroundColor3 = CONFIG.Colors.Surface,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0.5, 0),
        Position = UDim2.new(0, 0, 0.5, 0),
        ZIndex = 2,
    })

    Create("TextLabel", {
        Parent = self.Header, BackgroundTransparency = 1,
        Size = UDim2.new(0, 30, 1, 0), Position = UDim2.new(0, 15, 0, 0),
        Font = Enum.Font.GothamBold, Text = "◆", TextColor3 = CONFIG.Colors.Accent,
        TextSize = 18, ZIndex = 3,
    })
    Create("TextLabel", {
        Parent = self.Header, BackgroundTransparency = 1,
        Size = UDim2.new(0, 200, 1, 0), Position = UDim2.new(0, 42, 0, 0),
        Font = Enum.Font.GothamBold, Text = "NEXUS", TextColor3 = CONFIG.Colors.TextPrimary,
        TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3,
    })
    Create("TextLabel", {
        Parent = self.Header, BackgroundTransparency = 1,
        Size = UDim2.new(0, 200, 1, 0), Position = UDim2.new(0, 100, 0, 0),
        Font = Enum.Font.Gotham, Text = "UI", TextColor3 = CONFIG.Colors.Accent,
        TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3,
    })

    local minBtn = Create("TextButton", {
        Parent = self.Header, BackgroundColor3 = CONFIG.Colors.SurfaceHover,
        BorderSizePixel = 0, Size = UDim2.new(0, 30, 0, 30),
        Position = UDim2.new(1, -75, 0.5, -15), Text = "−",
        Font = Enum.Font.GothamBold, TextColor3 = CONFIG.Colors.TextPrimary,
        TextSize = 18, AutoButtonColor = false, ZIndex = 3,
    })
    Create("UICorner", {CornerRadius = UDim.new(0, 6), Parent = minBtn})
    HoverEffect(minBtn, CONFIG.Colors.SurfaceHover, CONFIG.Colors.SurfaceActive)
    minBtn.MouseButton1Click:Connect(function() self:ToggleMinimize() end)

    local closeBtn = Create("TextButton", {
        Parent = self.Header, BackgroundColor3 = CONFIG.Colors.SurfaceHover,
        BorderSizePixel = 0, Size = UDim2.new(0, 30, 0, 30),
        Position = UDim2.new(1, -40, 0.5, -15), Text = "×",
        Font = Enum.Font.GothamBold, TextColor3 = CONFIG.Colors.TextPrimary,
        TextSize = 18, AutoButtonColor = false, ZIndex = 3,
    })
    Create("UICorner", {CornerRadius = UDim.new(0, 6), Parent = closeBtn})
    HoverEffect(closeBtn, CONFIG.Colors.SurfaceHover, Color3.fromRGB(180, 50, 50))
    closeBtn.MouseButton1Click:Connect(function() self:Close() end)
end

function NexusUI:BuildSidebar()
    self.Sidebar = Create("Frame", {
        Name = "Sidebar", Parent = self.MainFrame,
        BackgroundColor3 = CONFIG.Colors.Background,
        BorderSizePixel = 0,
        Size = UDim2.new(0, CONFIG.Sizes.SidebarWidth, 1, -CONFIG.Sizes.HeaderHeight),
        Position = UDim2.new(0, 0, 0, CONFIG.Sizes.HeaderHeight),
        ZIndex = 2,
        ClipsDescendants = true,
    })
    Create("UIListLayout", {
        Parent = self.Sidebar, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder,
    })
    Create("UIPadding", {
        Parent = self.Sidebar,
        PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10),
        PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10),
    })
    Create("Frame", {
        Parent = self.MainFrame, BackgroundColor3 = CONFIG.Colors.Border,
        BorderSizePixel = 0,
        Size = UDim2.new(0, 1, 1, -CONFIG.Sizes.HeaderHeight - 20),
        Position = UDim2.new(0, CONFIG.Sizes.SidebarWidth, 0, CONFIG.Sizes.HeaderHeight + 10),
        ZIndex = 2,
    })
end

function NexusUI:BuildContentArea()
    self.ContentArea = Create("Frame", {
        Name = "ContentArea", Parent = self.MainFrame,
        BackgroundTransparency = 1, BorderSizePixel = 0,
        Size = UDim2.new(1, -CONFIG.Sizes.SidebarWidth - 20, 1, -CONFIG.Sizes.HeaderHeight - 20),
        Position = UDim2.new(0, CONFIG.Sizes.SidebarWidth + 10, 0, CONFIG.Sizes.HeaderHeight + 10),
        ZIndex = 2, ClipsDescendants = true,
    })
    Create("UIPadding", {
        Parent = self.ContentArea,
        PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 5),
        PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5),
    })
end

function NexusUI:CreateTab(name, icon)
    local btn = Create("TextButton", {
        Parent = self.Sidebar, BackgroundColor3 = CONFIG.Colors.Background,
        BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 38),
        Text = "", AutoButtonColor = false,
        LayoutOrder = #self.Tabs, ZIndex = 3,
    })
    Create("UICorner", {CornerRadius = UDim.new(0, 6), Parent = btn})

    local iconLbl = Create("TextLabel", {
        Parent = btn, BackgroundTransparency = 1,
        Size = UDim2.new(0, 28, 1, 0), Position = UDim2.new(0, 8, 0, 0),
        Font = Enum.Font.GothamBold, Text = icon or "•",
        TextColor3 = CONFIG.Colors.TextSecondary, TextSize = 14, ZIndex = 4,
    })
    local nameLbl = Create("TextLabel", {
        Parent = btn, BackgroundTransparency = 1,
        Size = UDim2.new(1, -40, 1, 0), Position = UDim2.new(0, 36, 0, 0),
        Font = Enum.Font.GothamSemibold, Text = name,
        TextColor3 = CONFIG.Colors.TextSecondary, TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4,
    })
    local indicator = Create("Frame", {
        Parent = btn, BackgroundColor3 = CONFIG.Colors.Accent,
        BorderSizePixel = 0, Size = UDim2.new(0, 3, 0, 0),
        Position = UDim2.new(0, -2, 0.15, 0), ZIndex = 4,
    })
    Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = indicator})

    local content = Create("ScrollingFrame", {
        Parent = self.ContentArea, BackgroundTransparency = 1,
        BorderSizePixel = 0, Size = UDim2.new(1, 0, 1, 0),
        CanvasSize = UDim2.new(0, 0, 0, 0),
        ScrollBarThickness = 3, ScrollBarImageColor3 = CONFIG.Colors.Accent,
        Visible = false, ZIndex = 3,
        ClipsDescendants = true,
    })
    local list = Create("UIListLayout", {
        Parent = content, Padding = UDim.new(0, CONFIG.Sizes.ElementPadding),
        SortOrder = Enum.SortOrder.LayoutOrder,
    })
    Create("UIPadding", {
        Parent = content,
        PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 5),
        PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5),
    })
    list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        content.CanvasSize = UDim2.new(0, 0, 0, list.AbsoluteContentSize.Y + 10)
    end)

    local tab = {Name = name, Button = btn, Content = content, Indicator = indicator, Elements = {}}

    btn.MouseButton1Click:Connect(function() self:SelectTab(tab) end)
    btn.MouseEnter:Connect(function()
        if self.CurrentTab ~= tab then
            Tween(btn, CONFIG.Animations.Fast, {BackgroundColor3 = CONFIG.Colors.Surface})
            Tween(iconLbl, CONFIG.Animations.Fast, {TextColor3 = CONFIG.Colors.TextPrimary})
            Tween(nameLbl, CONFIG.Animations.Fast, {TextColor3 = CONFIG.Colors.TextPrimary})
        end
    end)
    btn.MouseLeave:Connect(function()
        if self.CurrentTab ~= tab then
            Tween(btn, CONFIG.Animations.Fast, {BackgroundColor3 = CONFIG.Colors.Background})
            Tween(iconLbl, CONFIG.Animations.Fast, {TextColor3 = CONFIG.Colors.TextSecondary})
            Tween(nameLbl, CONFIG.Animations.Fast, {TextColor3 = CONFIG.Colors.TextSecondary})
        end
    end)

    table.insert(self.Tabs, tab)
    return tab
end

function NexusUI:SelectTab(tab)
    if self.CurrentTab == tab then return end
    self:CloseAllDropdowns()
    if self.CurrentTab then
        Tween(self.CurrentTab.Button, CONFIG.Animations.Fast, {BackgroundColor3 = CONFIG.Colors.Background})
        Tween(self.CurrentTab.Indicator, CONFIG.Animations.Fast, {Size = UDim2.new(0, 3, 0, 0)})
        self.CurrentTab.Content.Visible = false
        for _, c in ipairs(self.CurrentTab.Button:GetChildren()) do
            if c:IsA("TextLabel") then Tween(c, CONFIG.Animations.Fast, {TextColor3 = CONFIG.Colors.TextSecondary}) end
        end
    end
    self.CurrentTab = tab
    Tween(tab.Button, CONFIG.Animations.Fast, {BackgroundColor3 = CONFIG.Colors.Surface})
    Tween(tab.Indicator, CONFIG.Animations.Medium, {Size = UDim2.new(0, 3, 0.7, 0)})
    tab.Content.Visible = true
    for _, c in ipairs(tab.Button:GetChildren()) do
        if c:IsA("TextLabel") then Tween(c, CONFIG.Animations.Fast, {TextColor3 = CONFIG.Colors.Accent}) end
    end
end

function NexusUI:CloseAllDropdowns()
    for _, closeFn in pairs(self.OpenDropdowns) do
        closeFn(true)
    end
end

-- Элементы интерфейса

function NexusUI:CreateSection(tab, title)
    local f = Create("Frame", {
        Parent = tab.Content, BackgroundTransparency = 1,
        BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 30),
        LayoutOrder = #tab.Elements,
    })
    Create("TextLabel", {
        Parent = f, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0),
        Font = Enum.Font.GothamBold, Text = title:upper(),
        TextColor3 = CONFIG.Colors.Accent, TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    table.insert(tab.Elements, f)
    return f
end

function NexusUI:CreateToggle(tab, text, default, callback)
    default = default or false
    callback = callback or function() end

    local f = Create("Frame", {
        Parent = tab.Content, BackgroundColor3 = CONFIG.Colors.Surface,
        BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, CONFIG.Sizes.ElementHeight),
        LayoutOrder = #tab.Elements,
    })
    Create("UICorner", {CornerRadius = UDim.new(0, 6), Parent = f})

    Create("TextLabel", {
        Parent = f, BackgroundTransparency = 1,
        Size = UDim2.new(1, -70, 1, 0), Position = UDim2.new(0, 12, 0, 0),
        Font = Enum.Font.Gotham, Text = text,
        TextColor3 = CONFIG.Colors.TextPrimary, TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local bg = Create("Frame", {
        Parent = f, BackgroundColor3 = default and CONFIG.Colors.ToggleOn or CONFIG.Colors.ToggleOff,
        BorderSizePixel = 0, Size = UDim2.new(0, 44, 0, 22),
        Position = UDim2.new(1, -56, 0.5, -11),
    })
    Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = bg})

    local circle = Create("Frame", {
        Parent = bg, BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0, Size = UDim2.new(0, 18, 0, 18),
        Position = default and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9),
    })
    Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = circle})
    Create("UIGradient", {
        Color = ColorSequence.new(Color3.new(1,1,1), Color3.fromRGB(220,220,220)),
        Parent = circle,
    })

    local state = default
    local function toggle()
        state = not state
        Tween(bg, CONFIG.Animations.Medium, {BackgroundColor3 = state and CONFIG.Colors.ToggleOn or CONFIG.Colors.ToggleOff})
        Tween(circle, CONFIG.Animations.Medium, {
            Position = state and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)
        })
        callback(state)
    end

    local hit = Create("TextButton", {
        Parent = f, BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0), Text = "", AutoButtonColor = false,
    })
    hit.MouseButton1Click:Connect(toggle)
    HoverEffect(f, CONFIG.Colors.Surface, CONFIG.Colors.SurfaceHover)

    table.insert(tab.Elements, f)
    callback(default)
    return f
end

function NexusUI:CreateButton(tab, text, callback)
    callback = callback or function() end
    local f = Create("Frame", {
        Parent = tab.Content, BackgroundTransparency = 1,
        BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, CONFIG.Sizes.ElementHeight),
        LayoutOrder = #tab.Elements,
    })
    local btn = Create("TextButton", {
        Parent = f, BackgroundColor3 = CONFIG.Colors.Surface,
        BorderSizePixel = 0, Size = UDim2.new(1, 0, 1, 0),
        Font = Enum.Font.GothamSemibold, Text = text,
        TextColor3 = CONFIG.Colors.TextPrimary, TextSize = 13,
        AutoButtonColor = false,
    })
    Create("UICorner", {CornerRadius = UDim.new(0, 6), Parent = btn})

    btn.MouseButton1Click:Connect(function()
        Tween(btn, CONFIG.Animations.Fast, {BackgroundColor3 = CONFIG.Colors.Accent, TextColor3 = CONFIG.Colors.Background})
        task.delay(0.15, function()
            Tween(btn, CONFIG.Animations.Fast, {BackgroundColor3 = CONFIG.Colors.Surface, TextColor3 = CONFIG.Colors.TextPrimary})
        end)
        callback()
    end)
    HoverEffect(btn, CONFIG.Colors.Surface, CONFIG.Colors.SurfaceHover)

    table.insert(tab.Elements, f)
    return f
end

function NexusUI:CreateSlider(tab, text, min, max, default, callback)
    callback = callback or function() end
    default = math.clamp(default or min, min, max)

    local f = Create("Frame", {
        Parent = tab.Content, BackgroundColor3 = CONFIG.Colors.Surface,
        BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 50),
        LayoutOrder = #tab.Elements,
    })
    Create("UICorner", {CornerRadius = UDim.new(0, 6), Parent = f})

    Create("TextLabel", {
        Parent = f, BackgroundTransparency = 1,
        Size = UDim2.new(0.5, 0, 0, 24), Position = UDim2.new(0, 12, 0, 2),
        Font = Enum.Font.Gotham, Text = text,
        TextColor3 = CONFIG.Colors.TextPrimary, TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    local valLbl = Create("TextLabel", {
        Parent = f, BackgroundTransparency = 1,
        Size = UDim2.new(0.5, -20, 0, 24), Position = UDim2.new(0.5, 10, 0, 2),
        Font = Enum.Font.GothamBold, Text = tostring(default),
        TextColor3 = CONFIG.Colors.Accent, TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Right,
    })

    local track = Create("Frame", {
        Parent = f, BackgroundColor3 = CONFIG.Colors.SliderTrack,
        BorderSizePixel = 0, Size = UDim2.new(1, -24, 0, 6),
        Position = UDim2.new(0, 12, 0, 32),
    })
    Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = track})

    local fill = Create("Frame", {
        Parent = track, BackgroundColor3 = CONFIG.Colors.SliderFill,
        BorderSizePixel = 0, Size = UDim2.new((default - min) / (max - min), 0, 1, 0),
    })
    Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = fill})

    local knob = Create("Frame", {
        Parent = track, BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0, Size = UDim2.new(0, 14, 0, 14),
        Position = UDim2.new((default - min) / (max - min), -7, 0.5, -7),
        ZIndex = 2,
    })
    Create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = knob})
    Create("UIGradient", {
        Color = ColorSequence.new(Color3.new(1,1,1), Color3.fromRGB(230,230,230)),
        Parent = knob,
    })

    local hitbox = Create("TextButton", {
        Parent = f, BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0), Text = "", AutoButtonColor = false,
        ZIndex = 10,
    })

    local dragging = false

    local function update(input)
        local rel = math.clamp((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        local val = math.floor(min + (max - min) * rel)
        Tween(fill, CONFIG.Animations.Fast, {Size = UDim2.new(rel, 0, 1, 0)})
        Tween(knob, CONFIG.Animations.Fast, {Position = UDim2.new(rel, -7, 0.5, -7)})
        valLbl.Text = tostring(val)
        callback(val)
    end

    local function endDrag()
        if not dragging then return end
        dragging = false
        Tween(knob, CONFIG.Animations.Fast, {Size = UDim2.new(0, 14, 0, 14)})
    end

    hitbox.InputBegan:Connect(function(input)
        if not IsPress(input) then return end
        dragging = true
        Tween(knob, CONFIG.Animations.Fast, {Size = UDim2.new(0, 18, 0, 18)})
        update(input)
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and IsMove(input) then
            update(input)
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if dragging and IsPress(input) then
            endDrag()
        end
    end)

    hitbox.MouseEnter:Connect(function()
        Tween(f, CONFIG.Animations.Fast, {BackgroundColor3 = CONFIG.Colors.SurfaceHover})
    end)
    hitbox.MouseLeave:Connect(function()
        Tween(f, CONFIG.Animations.Fast, {BackgroundColor3 = CONFIG.Colors.Surface})
    end)

    table.insert(tab.Elements, f)
    callback(default)
    return f
end

function NexusUI:CreateDropdown(tab, text, options, defaultIdx, callback)
    callback = callback or function() end
    options = options or {}
    defaultIdx = defaultIdx or 1

    local f = Create("Frame", {
        Parent = tab.Content, BackgroundColor3 = CONFIG.Colors.Surface,
        BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, CONFIG.Sizes.ElementHeight),
        LayoutOrder = #tab.Elements, ClipsDescendants = false,
        ZIndex = 1,
    })
    Create("UICorner", {CornerRadius = UDim.new(0, 6), Parent = f})

    Create("TextLabel", {
        Parent = f, BackgroundTransparency = 1,
        Size = UDim2.new(0.5, 0, 1, 0), Position = UDim2.new(0, 12, 0, 0),
        Font = Enum.Font.Gotham, Text = text,
        TextColor3 = CONFIG.Colors.TextPrimary, TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local ddBtn = Create("TextButton", {
        Parent = f, BackgroundColor3 = CONFIG.Colors.SurfaceHover,
        BorderSizePixel = 0, Size = UDim2.new(0, 140, 0, 26),
        Position = UDim2.new(1, -152, 0.5, -13),
        Font = Enum.Font.Gotham, Text = options[defaultIdx] or "Select...",
        TextColor3 = CONFIG.Colors.TextPrimary, TextSize = 12,
        AutoButtonColor = false,
    })
    Create("UICorner", {CornerRadius = UDim.new(0, 4), Parent = ddBtn})

    local arrow = Create("TextLabel", {
        Parent = ddBtn, BackgroundTransparency = 1,
        Size = UDim2.new(0, 20, 1, 0), Position = UDim2.new(1, -20, 0, 0),
        Font = Enum.Font.GothamBold, Text = "▼",
        TextColor3 = CONFIG.Colors.TextSecondary, TextSize = 10,
    })

    local ddFrame = Create("Frame", {
        Parent = f, BackgroundColor3 = CONFIG.Colors.SurfaceHover,
        BorderSizePixel = 0, Size = UDim2.new(0, 140, 0, 0),
        Position = UDim2.new(1, -152, 0, 32),
        ClipsDescendants = true, ZIndex = 10, Visible = false,
    })
    Create("UICorner", {CornerRadius = UDim.new(0, 4), Parent = ddFrame})
    Create("UIStroke", {Color = CONFIG.Colors.Border, Thickness = 1, Parent = ddFrame})

    Create("UIListLayout", {
        Parent = ddFrame, Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder,
    })

    local open = false
    local activeSizeTween = nil

    local function toggle(forceClose)
        if forceClose and not open then return end
        open = (not forceClose) and (not open)

        f.ZIndex = open and 50 or 1

        if activeSizeTween then
            activeSizeTween:Cancel()
            activeSizeTween = nil
        end
        ddFrame.Visible = true
        local neededHeight = math.min(#options * 28, 140)

        if open then
            local fBottom = f.AbsolutePosition.Y + f.AbsoluteSize.Y
            local contentBottom = self.ContentArea.AbsolutePosition.Y + self.ContentArea.AbsoluteSize.Y
            local spaceBelow = contentBottom - fBottom
            local openUpward = spaceBelow < neededHeight + 10

            if openUpward then
                ddFrame.Position = UDim2.new(1, -152, 0, -neededHeight - 4)
                arrow.Rotation = 0
            else
                ddFrame.Position = UDim2.new(1, -152, 0, 32)
                arrow.Rotation = 180
            end
            activeSizeTween = Tween(ddFrame, CONFIG.Animations.Medium, {Size = UDim2.new(0, 140, 0, neededHeight)})
        else
            arrow.Rotation = 0
            local t = Tween(ddFrame, CONFIG.Animations.Medium, {Size = UDim2.new(0, 140, 0, 0)})
            activeSizeTween = t
            t.Completed:Connect(function()
                if not open then
                    ddFrame.Visible = false
                end
            end)
        end
    end

    table.insert(self.OpenDropdowns, function(force)
        if force and open then toggle(true) end
    end)

    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if not open then return end
        if not IsPress(input) then return end
        local pos = input.Position
        local inButton = ddBtn.AbsolutePosition.X <= pos.X and pos.X <= ddBtn.AbsolutePosition.X + ddBtn.AbsoluteSize.X
            and ddBtn.AbsolutePosition.Y <= pos.Y and pos.Y <= ddBtn.AbsolutePosition.Y + ddBtn.AbsoluteSize.Y
        local inList = ddFrame.AbsolutePosition.X <= pos.X and pos.X <= ddFrame.AbsolutePosition.X + ddFrame.AbsoluteSize.X
            and ddFrame.AbsolutePosition.Y <= pos.Y and pos.Y <= ddFrame.AbsolutePosition.Y + ddFrame.AbsoluteSize.Y
        if not inButton and not inList then
            toggle(true)
        end
    end)

    for i, opt in ipairs(options) do
        local b = Create("TextButton", {
            Parent = ddFrame, BackgroundColor3 = CONFIG.Colors.SurfaceHover,
            BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 26),
            Font = Enum.Font.Gotham, Text = opt,
            TextColor3 = CONFIG.Colors.TextPrimary, TextSize = 12,
            AutoButtonColor = false, LayoutOrder = i,
        })
        b.MouseButton1Click:Connect(function()
            ddBtn.Text = opt
            toggle(true)
            callback(opt, i)
        end)
        b.MouseEnter:Connect(function()
            Tween(b, CONFIG.Animations.Fast, {BackgroundColor3 = CONFIG.Colors.Accent, TextColor3 = CONFIG.Colors.Background})
        end)
        b.MouseLeave:Connect(function()
            Tween(b, CONFIG.Animations.Fast, {BackgroundColor3 = CONFIG.Colors.SurfaceHover, TextColor3 = CONFIG.Colors.TextPrimary})
        end)
    end

    ddBtn.MouseButton1Click:Connect(function() toggle() end)
    HoverEffect(f, CONFIG.Colors.Surface, CONFIG.Colors.SurfaceHover)

    table.insert(tab.Elements, f)
    callback(options[defaultIdx], defaultIdx)
    return f
end

function NexusUI:CreateLabel(tab, text)
    local lbl = Create("TextLabel", {
        Parent = tab.Content, BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 24),
        Font = Enum.Font.Gotham, Text = text,
        TextColor3 = CONFIG.Colors.TextSecondary, TextSize = 12,
        TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = #tab.Elements,
    })
    table.insert(tab.Elements, lbl)
    return lbl
end

-- Управление окном

function NexusUI:Open()
    if self.IsOpen or self.IsAnimating then return end
    self.IsAnimating = true
    self.IsOpen = true

    self.Container.Size = UDim2.new(0, CONFIG.Sizes.WindowWidth, 0, CONFIG.Sizes.WindowHeight)
    self.Container.Position = UDim2.new(0.5, -CONFIG.Sizes.WindowWidth/2, 0.5, -CONFIG.Sizes.WindowHeight/2)
    self.Container.Visible = true

    Tween(self.MainFrame, CONFIG.Animations.Medium, {GroupTransparency = 0}).Completed:Connect(function()
        self.IsAnimating = false
    end)
end

function NexusUI:Close()
    if not self.IsOpen or self.IsAnimating then return end
    self.IsAnimating = true
    self.IsOpen = false
    self:CloseAllDropdowns()

    Tween(self.MainFrame, CONFIG.Animations.Medium, {GroupTransparency = 1}).Completed:Connect(function()
        self.Container.Visible = false
        self.IsAnimating = false
    end)
end

function NexusUI:ToggleMinimize()
    self.IsMinimized = not self.IsMinimized
    self:CloseAllDropdowns()
    if self.IsMinimized then
        Tween(self.ContentArea, CONFIG.Animations.Medium, {Size = UDim2.new(1, -CONFIG.Sizes.SidebarWidth - 20, 0, 0)})
        Tween(self.Sidebar, CONFIG.Animations.Medium, {Size = UDim2.new(0, CONFIG.Sizes.SidebarWidth, 0, 0)})
        Tween(self.Container, CONFIG.Animations.Medium, {Size = UDim2.new(0, CONFIG.Sizes.WindowWidth, 0, CONFIG.Sizes.HeaderHeight)})
    else
        Tween(self.ContentArea, CONFIG.Animations.Medium, {Size = UDim2.new(1, -CONFIG.Sizes.SidebarWidth - 20, 1, -CONFIG.Sizes.HeaderHeight - 20)})
        Tween(self.Sidebar, CONFIG.Animations.Medium, {Size = UDim2.new(0, CONFIG.Sizes.SidebarWidth, 1, -CONFIG.Sizes.HeaderHeight)})
        Tween(self.Container, CONFIG.Animations.Medium, {Size = UDim2.new(0, CONFIG.Sizes.WindowWidth, 0, CONFIG.Sizes.WindowHeight)})
    end
end

function NexusUI:EnableDrag()
    local dragging = false
    local dragStart, startPos

    self.Header.InputBegan:Connect(function(input)
        if not IsPress(input) then return end
        dragging = true
        dragStart = input.Position
        startPos = self.Container.Position
    end)

    UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if not IsMove(input) then return end
        local delta = input.Position - dragStart
        self.Container.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end)

    UserInputService.InputEnded:Connect(function(input)
        if not dragging then return end
        if not IsPress(input) then return end
        dragging = false
    end)
end

function NexusUI:SetupToggleKey()
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == Enum.KeyCode.RightShift or input.KeyCode == Enum.KeyCode.Insert then
            if self.IsOpen then self:Close() else self:Open() end
        end
    end)
end

-- ПОСТРОЕНИЕ ВКЛАДОК (связь с _G.Nexus)

function NexusUI:BuildTabs()
    local Nexus = _G.Nexus
    if not Nexus then
        Nexus = {
            Settings = {
                Aimbot = false, SilentAim = false, AutoShoot = false, FOVSize = 200, TargetPart = "Head",
                GodMode = false, InfiniteJump = false, WalkSpeed = 70, JumpPower = 70,
                BoxESP = false, SkeletonESP = false, NameESP = false, Tracers = false, MaxDistance = 1000,
                AntiAFK = false, AutoFarm = false,
            },
            ResetCharacter = function() end,
            RejoinServer = function() end,
        }
        _G.Nexus = Nexus
    end

    local combat = self:CreateTab("Combat", "⚔")
    self:CreateSection(combat, "Combat Features")
    self:CreateToggle(combat, "Aimbot", Nexus.Settings.Aimbot, function(v) Nexus.Settings.Aimbot = v end)
    self:CreateToggle(combat, "Silent Aim", Nexus.Settings.SilentAim, function(v) Nexus.Settings.SilentAim = v end)
    self:CreateToggle(combat, "Auto Shoot", Nexus.Settings.AutoShoot, function(v) Nexus.Settings.AutoShoot = v end)
    self:CreateSlider(combat, "FOV Size", 30, 300, Nexus.Settings.FOVSize, function(v) Nexus.Settings.FOVSize = v end)
    self:CreateDropdown(combat, "Target Part", {"Head", "Torso", "HumanoidRootPart"}, 1, function(opt) Nexus.Settings.TargetPart = opt end)

    local player = self:CreateTab("Player", "👤")
    self:CreateSection(player, "Character")
    self:CreateToggle(player, "God Mode", Nexus.Settings.GodMode, function(v) Nexus.Settings.GodMode = v end)
    self:CreateToggle(player, "Infinite Jump", Nexus.Settings.InfiniteJump, function(v) Nexus.Settings.InfiniteJump = v end)
    self:CreateSlider(player, "WalkSpeed", 16, 200, Nexus.Settings.WalkSpeed, function(v) Nexus.Settings.WalkSpeed = v end)
    self:CreateSlider(player, "JumpPower", 50, 300, Nexus.Settings.JumpPower, function(v) Nexus.Settings.JumpPower = v end)
    self:CreateButton(player, "Reset Character", function() Nexus.ResetCharacter() end)

    local visuals = self:CreateTab("Visuals", "👁")
    self:CreateSection(visuals, "ESP")
    self:CreateToggle(visuals, "Box ESP", Nexus.Settings.BoxESP, function(v) Nexus.Settings.BoxESP = v end)
    self:CreateToggle(visuals, "Skeleton ESP", Nexus.Settings.SkeletonESP, function(v) Nexus.Settings.SkeletonESP = v end)
    self:CreateToggle(visuals, "Name ESP", Nexus.Settings.NameESP, function(v) Nexus.Settings.NameESP = v end)
    self:CreateToggle(visuals, "Tracers", Nexus.Settings.Tracers, function(v) Nexus.Settings.Tracers = v end)
    self:CreateSlider(visuals, "Max Distance", 100, 5000, Nexus.Settings.MaxDistance, function(v) Nexus.Settings.MaxDistance = v end)

    local misc = self:CreateTab("Misc", "⚙")
    self:CreateSection(misc, "Utilities")
    self:CreateToggle(misc, "Anti-AFK", Nexus.Settings.AntiAFK, function(v) Nexus.Settings.AntiAFK = v end)
    self:CreateToggle(misc, "Auto-Farm", Nexus.Settings.AutoFarm, function(v) Nexus.Settings.AutoFarm = v end)
    self:CreateButton(misc, "Rejoin Server", function() Nexus.RejoinServer() end)

    local settings = self:CreateTab("Settings", "🔧")
    self:CreateSection(settings, "Configuration")
    self:CreateToggle(settings, "Show Keybinds", true, function(v) end)
    self:CreateToggle(settings, "Notifications", true, function(v) end)
    self:CreateSlider(settings, "UI Scale", 50, 150, 100, function(v) if self.UIScale then self.UIScale.Scale = v/100 end end)
    self:CreateButton(settings, "Save Config", function() end)
    self:CreateButton(settings, "Load Config", function() end)
    self:CreateLabel(settings, "RightShift or Insert to toggle UI")

    self:SelectTab(combat)
end

-- Создание UI

local UI = NexusUI.new()
task.delay(0.5, function()
    UI:Open()
end)

print("NexusUI loaded! Press RightShift or Insert to toggle.")
