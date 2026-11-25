--========================================================--
-- SERVICES
--========================================================--

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

--========================================================--
-- NIGHTFALL UI
--========================================================--

local UI
if typeof(readfile) == "function" then
    local ok, content = pcall(function() return readfile("nightfall_gui.lua") end)
    if ok and content and content ~= "" then
        local loaderOk, lib = pcall(function() return loadstring(content)() end)
        if loaderOk and lib then
            UI = lib
        end
    end
end
if not UI then
    UI = loadstring(game:HttpGet(
        "https://raw.githubusercontent.com/Entervalov/NightFall/main/nightfall_gui.lua"
    ))()
end

assert(type(UI) == "table" and type(UI.CreateWindow) == "function", "NightFall must return the UI library")

--========================================================--
-- SETTINGS
--========================================================--

local Settings = {

    AntiJump = true,
    InfJump = false,
    AutoSprint = false,

    Underground = false,
    UndergroundDepth = 8,
    UndergroundSpeed = 20,

    Noclip = false,

    QuickRespawn = false,
    ReturnOnDeath = false,
    AutoWeapon = false,

    ESP = false,
    TeamColors = true,

    Highlight = true,
    HighlightColor = Color3.fromRGB(255, 70, 70),
    HighlightTransparency = 0.5,
	FireRateMultiplier = 1.0,

    Fullbright = false,

    TargetTeam = false,
    RapidFire = false,
    FireRate = 0.05,

    Hitbox = false,
    HitboxSize = 6,

    TargetKillerWeapon = "Equipped / Any",

    Spinbot = false,
    SpinSpeed = 30,
    SpinMode = "Spin",

    Bhop = false,
    BhopAuto = false,
    BhopHopHeight = 50,
    BhopSpeedBoost = 14,
    BhopAccelerate = true,
    BhopPreserveMomentum = true,
}

_G.Settings = Settings

--========================================================--
-- STATE
--========================================================--

local UndergroundConnection = nil
local UndergroundSavedCFrame = nil

local CharacterConnection = nil
local DeathConnection = nil
local CharacterTrackConnection = nil

local LastAliveCFrame = nil
local LastDeathCFrame = nil

local ESPObjects = {}
local HitboxObjects = {}

local OriginalLighting = {
    Brightness = Lighting.Brightness,
    ClockTime = Lighting.ClockTime,
    FogEnd = Lighting.FogEnd,
    FogStart = Lighting.FogStart,
    Ambient = Lighting.Ambient,
    OutdoorAmbient = Lighting.OutdoorAmbient,
    GlobalShadows = Lighting.GlobalShadows,
    ExposureCompensation = Lighting.ExposureCompensation,
}

--========================================================--
-- CHARACTER
--========================================================--

local function getCharacter()
    local Character = LocalPlayer.Character

    if not Character then
        return nil, nil, nil
    end

    local Humanoid = Character:FindFirstChildOfClass("Humanoid")
    local Root = Character:FindFirstChild("HumanoidRootPart")

    return Character, Humanoid, Root
end

--========================================================--
-- ESP
--========================================================--

local function removeESP(Player)

    local Object = ESPObjects[Player]

    if Object then

        if Object.Highlight then
            Object.Highlight:Destroy()
        end

        if Object.Billboard then
            Object.Billboard:Destroy()
        end

        ESPObjects[Player] = nil
    end
end

local function getPlayerColor(Player)

    if Settings.TeamColors
        and Player.Team
        and Player.Team.TeamColor then

        return Player.Team.TeamColor.Color
    end

    return Settings.HighlightColor
end

local function createESP(Player)

    if not Settings.ESP then
        removeESP(Player)
        return
    end

    if Player == LocalPlayer then
        return
    end

    removeESP(Player)

    local Character = Player.Character

    if not Character then
        return
    end

    local Root = Character:FindFirstChild("HumanoidRootPart")

    if not Root then
        return
    end

    local HighlightObject = nil

    if Settings.Highlight then

        HighlightObject = Instance.new("Highlight")
        HighlightObject.Name = "NightfallHighlight"
        HighlightObject.Adornee = Character
        HighlightObject.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        HighlightObject.FillTransparency = Settings.HighlightTransparency
        HighlightObject.OutlineTransparency = 0
        HighlightObject.FillColor = getPlayerColor(Player)
        HighlightObject.OutlineColor = getPlayerColor(Player)
        HighlightObject.Parent = Character
    end

    local Billboard = Instance.new("BillboardGui")
    Billboard.Name = "NightfallESP"
    Billboard.Adornee = Root
    Billboard.Size = UDim2.fromOffset(220, 55)
    Billboard.StudsOffset = Vector3.new(0, 3.2, 0)
    Billboard.AlwaysOnTop = true
    Billboard.Active = true

    local Label = Instance.new("TextButton")
    Label.BackgroundTransparency = 1
    Label.Size = UDim2.fromScale(1, 1)
    Label.Font = Enum.Font.GothamSemibold
    Label.TextSize = 13
    Label.TextStrokeTransparency = 0.5
    Label.TextColor3 = getPlayerColor(Player)
    Label.Text = Player.DisplayName
    Label.AutoButtonColor = false
    Label.Active = true
    Label.Selectable = false
    Label.Parent = Billboard
    Label:SetAttribute("NF_Owner", Player.UserId)
    Billboard.Parent = Root

    ESPObjects[Player] = {
        Highlight = HighlightObject,
        Billboard = Billboard,
        Label = Label
    }
end

local lastESPUpdate = 0
local function updateESP()
    if not Settings.ESP then
        for player in pairs(ESPObjects) do
            removeESP(player)
        end
        return
    end
    local now = os.clock()
    if now - lastESPUpdate < 0.1 then
        return
    end
    lastESPUpdate = now

    local _, _, MyRoot = getCharacter()
    local myPos = MyRoot and MyRoot.Position

    for _, Player in ipairs(Players:GetPlayers()) do
        if Player ~= LocalPlayer then
            local Character = Player.Character
            local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
            local Root = Character and Character:FindFirstChild("HumanoidRootPart")

            if Character and Root and Humanoid and Humanoid.Health > 0 then
                local existing = ESPObjects[Player]
                if not existing or (Settings.Highlight and not existing.Highlight)
                    or (not Settings.Highlight and existing.Highlight) then
                    createESP(Player)
                end

                local Object = ESPObjects[Player]
                if Object and Object.Label then
                    local dist = myPos and math.floor((Root.Position - myPos).Magnitude) or 0
                    local hp = math.floor(Humanoid.Health)

                    if Object.LastDist ~= dist or Object.LastHP ~= hp then
                        Object.LastDist = dist
                        Object.LastHP = hp
                        Object.Label.Text = string.format("%s [%dm] | %d HP", Player.DisplayName, dist, hp)
                    end

                    local newColor = getPlayerColor(Player)
                    if Object.LastColor ~= newColor then
                        Object.LastColor = newColor
                        Object.Label.TextColor3 = newColor
                        if Object.Highlight then
                            Object.Highlight.FillColor = newColor
                            Object.Highlight.OutlineColor = newColor
                        end
                    end
                end
            else
                if ESPObjects[Player] then
                    removeESP(Player)
                end
            end
        end
    end
end

--========================================================--
-- CLICK HOTKEY TP
--========================================================--

local ESP_CLICK_RADIUS = 60
local ESP_CLICK_COOLDOWN = 0.3
local _lastTeleportTime = 0

local TP_MODIFIER_KEY = Enum.KeyCode.Q

local _tpKeyHeld = false

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if input.UserInputType == Enum.UserInputType.Keyboard
       and input.KeyCode == TP_MODIFIER_KEY then
        _tpKeyHeld = true
    end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
    if input.UserInputType == Enum.UserInputType.Keyboard
       and input.KeyCode == TP_MODIFIER_KEY then
        _tpKeyHeld = false
    end
end)

local function teleportToRoot(targetRoot)
    local myChar = LocalPlayer.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot or not targetRoot then
        return
    end

    local targetLook = targetRoot.CFrame.LookVector
    local newPos = targetRoot.Position - targetLook * 3

    myRoot.CFrame = CFrame.new(newPos, targetRoot.Position)
    myRoot.AssemblyLinearVelocity = Vector3.zero
    myRoot.AssemblyAngularVelocity = Vector3.zero
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)

    if gameProcessed then
        return
    end

    if not _tpKeyHeld then
        return
    end

    local isClick = input.UserInputType == Enum.UserInputType.MouseButton1
                 or input.UserInputType == Enum.UserInputType.Touch
    if not isClick then
        return
    end

    if os.clock() - _lastTeleportTime < ESP_CLICK_COOLDOWN then
        return
    end

    local clickPos
    if input.UserInputType == Enum.UserInputType.Touch then
        clickPos = Vector2.new(input.Position.X, input.Position.Y)
    else
        clickPos = Vector2.new(
            UserInputService:GetMouseLocation().X,
            UserInputService:GetMouseLocation().Y
        )
    end

    local cam = workspace.CurrentCamera
    if not cam then
        return
    end

    local bestPlayer = nil
    local bestDist = ESP_CLICK_RADIUS

    for player, object in pairs(ESPObjects) do
        local billboard = object.Billboard
        if billboard and billboard.Adornee and billboard.Parent then

            local worldPos = billboard.Adornee.Position + billboard.StudsOffset
            local screenPos, onScreen = cam:WorldToViewportPoint(worldPos)

            if onScreen then
                local d = (Vector2.new(screenPos.X, screenPos.Y) - clickPos).Magnitude

                if d < bestDist then
                    bestDist = d
                    bestPlayer = player
                end
            end
        end
    end

    if not bestPlayer then
        return
    end

    local targetChar = bestPlayer.Character
    local targetRoot = targetChar and targetChar:FindFirstChild("HumanoidRootPart")
    if not targetRoot then
        return
    end

    _lastTeleportTime = os.clock()
    teleportToRoot(targetRoot)
end)

--========================================================--
-- CUSTOM WEAPON VISUAL
--========================================================--

local CustomWeapon = (function()
    local state = {
        Enabled = false,
        Saved   = {},
        Applied = {},
    }

    local CUSTOM_MESHES = {
        ["AK-47"]         = "rbxassetid://96327891060480",
        ["M4A1"]          = "rbxassetid://96327891060480",
        ["M9"]            = "rbxassetid://96327891060480",
        ["MP5"]           = "rbxassetid://96327891060480",
        ["Taser"]         = "rbxassetid://96327891060480",
        ["Remington 870"] = "rbxassetid://96327891060480",
        ["Revolver"]      = "rbxassetid://96327891060480",
    }

    local CUSTOM_TEXTURES = {
        ["AK-47"]         = "rbxassetid://128702198330575",
        ["M4A1"]          = "rbxassetid://128702198330575",
        ["M9"]            = "rbxassetid://128702198330575",
        ["MP5"]           = "rbxassetid://128702198330575",
        ["Taser"]         = "rbxassetid://128702198330575",
        ["Remington 870"] = "rbxassetid://128702198330575",
        ["Revolver"]      = "rbxassetid://128702198330575",
    }

    local function findOriginalVisuals(tool)
        local list = {}
        for _, d in ipairs(tool:GetDescendants()) do
            if d:IsA("MeshPart") and d.Name ~= "NF_CustomWeapon" then
                table.insert(list, d)
            end
        end
        return list
    end

    local function createCustomMeshPart(original, meshId, textureId)
        local custom = Instance.new("MeshPart")
        custom.Name         = "NF_CustomWeapon"
        custom.MeshId       = meshId
        custom.TextureID    = textureId or original.TextureID or ""
        custom.Size         = original.Size
        custom.Anchored     = false
        custom.CanCollide   = false
        custom.CanQuery     = false
        custom.CanTouch     = false
        custom.Massless     = true
        custom.Transparency = 0
        custom.CFrame       = original.CFrame
        custom.Parent       = original.Parent

        local weld = Instance.new("WeldConstraint")
        weld.Part0 = custom
        weld.Part1 = original
        weld.Parent = custom

        return custom
    end

    local function apply(tool)
        if not tool or not tool:IsA("Tool") then
            return
        end
        local meshId = CUSTOM_MESHES[tool.Name]
        if not meshId then
            return
        end

        if state.Applied[tool] then
            return
        end

        local originals = findOriginalVisuals(tool)
        if #originals == 0 then
            return
        end

        local textureId = CUSTOM_TEXTURES[tool.Name]
        state.Saved[tool] = {}

        for _, orig in ipairs(originals) do
            state.Saved[tool][orig] = orig.Transparency
            orig.Transparency = 1

            pcall(function()
                createCustomMeshPart(orig, meshId, textureId)
            end)
        end

        state.Applied[tool] = true
    end

    local function remove(tool)
        if not state.Applied[tool] then
            return
        end

        for _, d in ipairs(tool:GetDescendants()) do
            if d.Name == "NF_CustomWeapon" then
                pcall(function()
                    d:Destroy()
                end)
            end
        end

        local saved = state.Saved[tool]
        if saved then
            for orig, val in pairs(saved) do
                if orig and orig.Parent then
                    pcall(function()
                        orig.Transparency = val
                    end)
                end
            end
        end

        state.Applied[tool] = nil
        state.Saved[tool]   = nil
    end

    local function hookTool(tool)
        if not tool:IsA("Tool") then
            return
        end

        tool.Equipped:Connect(function()
            if state.Enabled then
                apply(tool)
            end
        end)

        tool.Unequipped:Connect(function()
            remove(tool)
        end)

        if state.Enabled then
            apply(tool)
        end
    end

    local function hookCharacter(char)
        for _, child in ipairs(char:GetChildren()) do
            if child:IsA("Tool") then
                hookTool(child)
            end
        end

        char.ChildAdded:Connect(function(child)
            if child:IsA("Tool") then
                task.wait(0.2)
                hookTool(child)
            end
        end)

        char.ChildRemoved:Connect(function(child)
            if child:IsA("Tool") then
                remove(child)
            end
        end)
    end

    local function enable()
        if state.Enabled then
            return
        end
        state.Enabled = true

        local char = LocalPlayer.Character
        if char then
            hookCharacter(char)
        end

        LocalPlayer.CharacterAdded:Connect(function(c)
            if state.Enabled then
                hookCharacter(c)
            end
        end)
    end

    local function disable()
        if not state.Enabled then
            return
        end
        state.Enabled = false

        for tool in pairs(state.Applied) do
            remove(tool)
        end
        state.Applied = {}
        state.Saved   = {}
    end

    return {
        Set = function(v)
            if v then
                enable()
            else
                disable()
            end
            return state.Enabled
        end,

        Get = function()
            return state.Enabled
        end,

        SetMeshes = function(tbl)
            table.clear(CUSTOM_MESHES)
            for k, v in pairs(tbl) do
                CUSTOM_MESHES[k] = v
            end
        end,

        SetTextures = function(tbl)
            table.clear(CUSTOM_TEXTURES)
            for k, v in pairs(tbl) do
                CUSTOM_TEXTURES[k] = v
            end
        end,
    }
end)()

--========================================================--
-- HITBOX
--========================================================--

local HitboxObjects = HitboxObjects or {}

local function removeHitbox(Player)
    if _hbQueue then
        for i = #_hbQueue, 1, -1 do
            if _hbQueue[i] and _hbQueue[i].Player == Player then
                table.remove(_hbQueue, i)
            end
        end
    end

    local data = HitboxObjects[Player]
    if not data then
        return
    end

    local head = data.Head
    if head and head.Parent and data.OriginalSize then
        pcall(function()
            head.Size = data.OriginalSize
        end)
    end

    HitboxObjects[Player] = nil
end

local function isAlive(Player)
    local Character = Player.Character
    if not Character then
        return false
    end
    local Humanoid = Character:FindFirstChildOfClass("Humanoid")
    return Humanoid ~= nil and Humanoid.Health > 0
end

local function createHitbox(Player)
    removeHitbox(Player)

    if not Settings.Hitbox or not isAlive(Player) then
        return
    end

    local Character = Player.Character
    local Head = Character and Character:FindFirstChild("Head")
    if not Head then
        return
    end

    local s = Settings.HitboxSize or 6
    local original = Head.Size

    pcall(function()
        Head.Size = Vector3.new(s, s, s)
    end)

    HitboxObjects[Player] = {
        Head = Head,
        OriginalSize = original,
        Player = Player,
    }
end

local lastHitboxUpdate = 0
local function updateHitboxes()
    if not Settings.Hitbox then
        for player in pairs(HitboxObjects) do
            removeHitbox(player)
        end
        return
    end
    local now = os.clock()
    if now - lastHitboxUpdate < 0.5 then
        return
    end
    lastHitboxUpdate = now

    for _, Player in ipairs(Players:GetPlayers()) do
        if Player ~= LocalPlayer then
            if isAlive(Player) then
                local data = HitboxObjects[Player]
                local head = Player.Character and Player.Character:FindFirstChild("Head")
                if head and (not data or not data.Head or not data.Head.Parent or data.Head ~= head) then
                    createHitbox(Player)
                end
            else
                removeHitbox(Player)
            end
        end
    end
end

local HitboxVisualObjects = HitboxVisualObjects or {}

local function removeHitboxVisual(Player)
    local part = HitboxVisualObjects[Player]
    if not part then
        return
    end
    if part.Parent then
        pcall(function()
            part:Destroy()
        end)
    end
    HitboxVisualObjects[Player] = nil
end

local function createHitboxVisual(Player)
    removeHitboxVisual(Player)

    local Character = Player.Character
    if not Character then
        return
    end

    local Head = Character:FindFirstChild("Head")
    if not Head then
        return
    end

    local s = Settings.HitboxSize or 6

    local Part = Instance.new("Part")
    Part.Name         = "NightfallHitboxVisual"
    Part.Size         = Vector3.new(s, s, s)
    Part.Transparency = 0.7
    Part.Material     = Enum.Material.ForceField
    Part.Color        = Settings.HitboxVisualColor or Color3.fromRGB(255, 0, 0)
    Part.CastShadow   = false
    Part.CanCollide   = false
    Part.CanTouch     = false
    Part.CanQuery     = false
    Part.Massless     = true
    Part.Anchored     = false
    Part.CFrame       = Head.CFrame
    Part.Parent       = Head

    local Weld = Instance.new("WeldConstraint")
    Weld.Part0 = Part
    Weld.Part1 = Head
    Weld.Parent = Part

    HitboxVisualObjects[Player] = Part
end

local lastVisualUpdate = 0
local function updateHitboxVisuals()
    if not Settings.Hitbox or not Settings.HitboxVisual then
        return
    end
    local now = os.clock()
    if now - lastVisualUpdate < 0.25 then
        return
    end
    lastVisualUpdate = now

    for _, Player in ipairs(Players:GetPlayers()) do
        if Player ~= LocalPlayer then
            if isAlive(Player) then
                local part = HitboxVisualObjects[Player]
                local needRecreate = false

                if not part or not part.Parent then
                    needRecreate = true
                elseif part.Size.X ~= (Settings.HitboxSize or 6) then
                    needRecreate = true
                end

                if needRecreate then
                    createHitboxVisual(Player)
                end
            else
                removeHitboxVisual(Player)
            end
        end
    end
end

--========================================================--
-- DAMAGE VISUAL NUMBER's
--========================================================--

local DamageNumbers = (function()
    local state = {
        Enabled = false,
        Conn    = nil,
        LastHP  = {},
        Pool    = {},
        PlayerConns = {},
    }

    local function spawnNumber(worldPosition, amount)
        local bb = Instance.new("BillboardGui")
        bb.Name             = "NF_DamageNumber"
        bb.Size             = UDim2.fromOffset(120, 50)
        bb.StudsOffset      = Vector3.new(0, 0, 0)
        bb.AlwaysOnTop      = true
        bb.LightInfluence   = 0
        bb.MaxDistance      = 300
        bb.Adornee          = nil
        bb.Parent           = Workspace.CurrentCamera
        bb.Enabled          = true

        local anchor = Instance.new("Part")
        anchor.Name           = "NF_DamageAnchor"
        anchor.Size           = Vector3.new(0.1, 0.1, 0.1)
        anchor.Transparency   = 1
        anchor.CanCollide     = false
        anchor.CanQuery       = false
        anchor.CanTouch       = false
        anchor.Anchored       = true
        anchor.Massless       = true
        anchor.CFrame         = CFrame.new(worldPosition)
        anchor.Parent         = Workspace.CurrentCamera

        bb.Adornee = anchor

        local label = Instance.new("TextLabel")
        label.BackgroundTransparency = 1
        label.Size                   = UDim2.fromScale(1, 1)
        label.Font                   = Enum.Font.GothamBold
        label.TextScaled             = true
        label.TextColor3             = Color3.fromRGB(255, 60, 60)
        label.TextStrokeTransparency = 0
        label.TextStrokeColor3       = Color3.fromRGB(0, 0, 0)
        label.Text                   = "-" .. tostring(amount)
        label.Parent                 = bb

        task.spawn(function()
            local startTime = os.clock()
            local duration  = 1.0
            local startPos  = worldPosition
            local riseY     = 4

            while os.clock() - startTime < duration do
                local t = (os.clock() - startTime) / duration

                if anchor and anchor.Parent then
                    anchor.CFrame = CFrame.new(
                        startPos + Vector3.new(0, riseY * t, 0)
                    )
                end

                if label then
                    label.TextTransparency = t
                    label.TextStrokeTransparency = t
                end

                task.wait(0.03)
            end

            if bb and bb.Parent then
                bb:Destroy()
            end
            if anchor and anchor.Parent then
                anchor:Destroy()
            end
        end)
    end

    local function unhookPlayer(Player)
        if state.PlayerConns[Player] then
            for _, conn in ipairs(state.PlayerConns[Player]) do
                pcall(function() conn:Disconnect() end)
            end
            state.PlayerConns[Player] = nil
        end
        state.LastHP[Player] = nil
    end

    local function hookPlayer(Player)
        if Player == LocalPlayer then return end
        unhookPlayer(Player)
        if not state.Enabled then return end

        local char = Player.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then return end

        state.LastHP[Player] = hum.Health

        local conns = {}
        local c1 = hum.HealthChanged:Connect(function(newHealth)
            if not state.Enabled then
                return
            end

            local oldHealth = state.LastHP[Player] or newHealth
            state.LastHP[Player] = newHealth

            local delta = oldHealth - newHealth
            if delta > 0 then
                local head = char:FindFirstChild("Head")
                local root = char:FindFirstChild("HumanoidRootPart")
                local pos

                if head then
                    pos = head.Position + Vector3.new(0, 2, 0)
                elseif root then
                    pos = root.Position + Vector3.new(0, 2, 0)
                else
                    pos = Vector3.new(0, 0, 0)
                end

                spawnNumber(pos, math.floor(delta + 0.5))
            end
        end)
        table.insert(conns, c1)

        state.PlayerConns[Player] = conns
    end

    local function setupPlayer(Player)
        if Player == LocalPlayer then
            return
        end
        hookPlayer(Player)
    end

    local function enable()
        if state.Enabled then
            return
        end
        state.Enabled = true
        state.LastHP = {}

        for _, Player in ipairs(Players:GetPlayers()) do
            setupPlayer(Player)
        end
    end

    local function disable()
        if not state.Enabled then
            return
        end
        state.Enabled = false

        for Player in pairs(state.PlayerConns) do
            unhookPlayer(Player)
        end
        state.PlayerConns = {}
        state.LastHP = {}

        for _, obj in ipairs(Workspace.CurrentCamera:GetChildren()) do
            if obj.Name == "NF_DamageNumber" or obj.Name == "NF_DamageAnchor" then
                pcall(function() obj:Destroy() end)
            end
        end
    end

    return {
        Set = function(v)
            if v then
                enable()
            else
                disable()
            end
            return state.Enabled
        end,

        Get = function()
            return state.Enabled
        end,

        HookPlayer = hookPlayer,
        CleanupPlayer = unhookPlayer,
    }
end)()

--========================================================--
-- FULLBRIGHT
--========================================================--

local FullbrightConn = nil
local isLightingModifying = false

local function applyFullbright()
    if isLightingModifying then return end
    isLightingModifying = true
    pcall(function()
        Lighting.Brightness = 2
        Lighting.FogEnd = 100000
        Lighting.FogStart = 0
        Lighting.Ambient = Color3.fromRGB(180, 180, 180)
        Lighting.OutdoorAmbient = Color3.fromRGB(180, 180, 180)
        Lighting.GlobalShadows = false
        Lighting.ExposureCompensation = 0.2
    end)
    isLightingModifying = false
end

local function restoreLighting()
    if isLightingModifying then return end
    isLightingModifying = true
    pcall(function()
        Lighting.Brightness = OriginalLighting.Brightness
        Lighting.FogStart = OriginalLighting.FogStart
        Lighting.FogEnd = OriginalLighting.FogEnd
        Lighting.Ambient = OriginalLighting.Ambient
        Lighting.OutdoorAmbient = OriginalLighting.OutdoorAmbient
        Lighting.GlobalShadows = OriginalLighting.GlobalShadows
        Lighting.ExposureCompensation = OriginalLighting.ExposureCompensation
    end)
    isLightingModifying = false
end

local function enableFullbright()
    if FullbrightConn then
        return
    end

    applyFullbright()

    FullbrightConn = Lighting:GetPropertyChangedSignal("Ambient"):Connect(function()
        if Settings.Fullbright and not isLightingModifying then
            applyFullbright()
        end
    end)
end

local function disableFullbright()
    if FullbrightConn then
        FullbrightConn:Disconnect()
        FullbrightConn = nil
    end
    restoreLighting()
end

local function updateFullbright()
    if Settings.Fullbright then
        enableFullbright()
    else
        disableFullbright()
    end
end

--========================================================--
-- Teleport Giver
--========================================================--

local function teleportToGiver(giverPath)
    local char = LocalPlayer.Character
    if not char then
        return
    end

    local root = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not root or not hum then
        return
    end

    for _, d in ipairs(char:GetDescendants()) do
        if d:IsA("ForceField") then
            UI:Notify({ 
                Title = "World", 
                Content = "You can't teleport with a shield", 
                Duration = 3 
            })
            return
        end
    end

    local giver = nil
    pcall(function()
        giver = giverPath()
    end)
    if not giver or not giver:IsA("BasePart") then
        UI:Notify({ 
            Title = "World", 
            Content = "TouchGiver not found", 
            Duration = 3 
        })
        return
    end

    local savedCF = root.CFrame
    local giverCF = giver.CFrame

    local offset = Vector3.new(0, 3, 2)
    root.CFrame = giverCF + offset

    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(1e6, 1e6, 1e6)
    bv.Velocity = -offset.Unit * 50
    bv.Parent = root

    task.wait(0.2)

    bv:Destroy()

    root.CFrame = savedCF

    pcall(function()
        hum:ChangeState(Enum.HumanoidStateType.GettingUp)
    end)

end

local function resolveTouchGiver(candidateIndices, isNested)
    local children = workspace:GetChildren()
    for _, idx in ipairs(candidateIndices) do
        local obj = children[idx]
        if obj then
            if isNested then
                local tg1 = obj:FindFirstChild("TouchGiver")
                local tg2 = tg1 and tg1:FindFirstChild("TouchGiver")
                if tg2 and tg2:IsA("BasePart") then
                    return tg2
                end
            else
                local tg = obj:FindFirstChild("TouchGiver")
                if tg and tg:IsA("BasePart") then
                    return tg
                end
            end
        end
    end

    local center = candidateIndices[1] or 180
    local minIdx = math.max(1, center - 6)
    local maxIdx = math.min(#children, center + 6)
    for i = minIdx, maxIdx do
        local obj = children[i]
        if obj then
            if isNested then
                local tg1 = obj:FindFirstChild("TouchGiver")
                local tg2 = tg1 and tg1:FindFirstChild("TouchGiver")
                if tg2 and tg2:IsA("BasePart") then
                    return tg2
                end
            else
                local tg = obj:FindFirstChild("TouchGiver")
                if tg and tg:IsA("BasePart") then
                    return tg
                end
            end
        end
    end
    return nil
end

local function getFNFAL()
    return resolveTouchGiver({71, 72, 70, 73, 69}, false)
end

local function getAK47()
    return resolveTouchGiver({206, 207, 205, 208, 209}, true)
end

local function getShotgun()
    return resolveTouchGiver({183, 184, 182, 185, 181}, false)
end

local function getMP5()
    return resolveTouchGiver({187, 188, 186, 189, 185}, false)
end

local function getSniper()
    return resolveTouchGiver({236, 237, 235, 238, 234}, false)
end

local function getM4A1()
    local obj = workspace:FindFirstChild("TouchGiver")
    return obj and obj:FindFirstChild("TouchGiver")
end

--========================================================--
-- RAPID FIRE 
--========================================================--

local function patchTool(tool)
    if not tool or not tool:IsA("Tool") then
        return
    end
    if tool:GetAttribute("ToolType") ~= "Gun" then
        return
    end
    if not Settings.RapidFire then
        return
    end

    local newRate = tonumber(Settings.FireRate) or 0.05
    if newRate < 0.01 then
        newRate = 0.01
    end

    pcall(function()
        tool:SetAttribute("FireRate", nil)
    end)

    task.defer(function()
        pcall(function()
            tool:SetAttribute("FireRate", newRate)
        end)
    end)
end

local function hookTool(tool)
    if not tool:IsA("Tool") then
        return
    end

    if Settings.RapidFire then
        patchTool(tool)
    end

    tool.Equipped:Connect(function()
        if Settings.RapidFire then
            patchTool(tool)

            task.delay(0.1, function()
                if Settings.RapidFire then
                    patchTool(tool)
                end
            end)
        end
    end)
end

local function hookCharacter(char)
    for _, child in ipairs(char:GetChildren()) do
        if child:IsA("Tool") then
            hookTool(child)
        end
    end

    char.ChildAdded:Connect(function(child)
        if child:IsA("Tool") then
            task.wait(0.2)
            hookTool(child)
        end
    end)
end

LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(0.2)
    hookCharacter(char)
end)

if LocalPlayer.Character then
    hookCharacter(LocalPlayer.Character)
end

local function refreshAllTools()
    if not LocalPlayer.Character then
        return
    end
    for _, child in ipairs(LocalPlayer.Character:GetChildren()) do
        if child:IsA("Tool") then
            patchTool(child)
        end
    end
end

--========================================================--
-- AUTO CRIMINAL
--========================================================--

local AutoCriminal = (function()
    local state = {
        Enabled   = false,
        Conn      = nil,
        LastCF    = nil,
        Teleporting = false,
    }

    local CRIMINAL_COLOR = Color3.fromRGB(218, 133, 65)
    local POLICE_COLOR   = Color3.fromRGB(13, 105, 172)

    local CRIMINAL_SPAWN_CFRAME = CFrame.new(
        -948.203491, 99.2255402, 2094.7876,
        0, 0, -1,
        0, 1, 0,
        1, 0, 0
    )

    local function getIndicatorColor()
        local ti = workspace:FindFirstChild("TeamIndicators")
        if not ti then
            return nil
        end

        local lp = ti:FindFirstChild("LocalPlayer")
        if lp then
            local frame = lp:FindFirstChild("Frame")
            if frame and frame:IsA("GuiObject") then
                return frame.BackgroundColor3
            end
        end

        local byName = ti:FindFirstChild(LocalPlayer.Name)
        if byName then
            local frame = byName:FindFirstChild("Frame")
            if frame and frame:IsA("GuiObject") then
                return frame.BackgroundColor3
            end
        end

        for _, v in ipairs(ti:GetChildren()) do
            if v:IsA("Folder") or v:IsA("Model") then
                if v.Name == LocalPlayer.Name then
                    local frame = v:FindFirstChild("Frame")
                    if frame and frame:IsA("GuiObject") then
                        return frame.BackgroundColor3
                    end
                end
            end
        end

        return nil
    end

    local function colorMatches(c, target, tolerance)
        tolerance = tolerance or 0.02
        return math.abs(c.R - target.R) < tolerance
           and math.abs(c.G - target.G) < tolerance
           and math.abs(c.B - target.B) < tolerance
    end

    local function teleportToSpawn()
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then
            return
        end

        state.LastCF = root.CFrame

        root.CFrame = CRIMINAL_SPAWN_CFRAME
        root.AssemblyLinearVelocity  = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero

        task.delay(0.4, function()
            local char2 = LocalPlayer.Character
            local root2 = char2 and char2:FindFirstChild("HumanoidRootPart")
            if root2 and state.LastCF then
                root2.CFrame = state.LastCF
                root2.AssemblyLinearVelocity  = Vector3.zero
                root2.AssemblyAngularVelocity = Vector3.zero
            end
            state.Teleporting = false
        end)
    end

    local function tick()
        if not state.Enabled then
            return
        end
        if state.Teleporting then
            return
        end

        local color = getIndicatorColor()
        if not color then
            return
        end

        if colorMatches(color, POLICE_COLOR) then
            return
        end

        if colorMatches(color, CRIMINAL_COLOR) then
            local char = LocalPlayer.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if not root then
                return
            end

            local dist = (root.Position - CRIMINAL_SPAWN_CFRAME.Position).Magnitude
            if dist < 5 then
                return
            end

            state.Teleporting = true
            teleportToSpawn()
        end
    end

    local function enable()
        if state.Enabled then
            return
        end
        state.Enabled = true

        if state.Conn then
            state.Conn:Disconnect()
        end
        state.Conn = task.spawn(function()
            while state.Enabled do
                pcall(tick)
                task.wait(0.42)
            end
        end)
    end

    local function disable()
        state.Enabled = false
        if state.Conn then
            task.cancel(state.Conn)
            state.Conn = nil
        end
        state.Teleporting = false
    end

    return {
        Set = function(v)
            if v then
                enable()
            else
                disable()
            end
            return state.Enabled
        end,

        Get = function()
            return state.Enabled
        end,

        CleanupPlayer = function(Player)
            removeMarker(Player)
        end,
    }
end)()

--========================================================--
-- ANTI-FLING + BLOCK CAR SEATS
--========================================================--

local AntiFling = (function()
    local state = {
        Enabled   = false,
        MaxSpeed  = 50,
        Conn1     = nil,
        Conn2     = nil,
        Conn3     = nil,
        CarParts  = {},
        PlayerParts = {},
    }

    local function registerCar(model)
        if not model:IsA("Model") then
            return
        end
        for _, v in ipairs(model:GetDescendants()) do
            if v:IsA("BasePart") then
                v.CanCollide = false
                state.CarParts[v] = true
            end
        end
    end

    local function registerPlayer(player)
        if not player.Character then
            return
        end
        for _, v in ipairs(player.Character:GetDescendants()) do
            if v:IsA("BasePart") then
                v.CanCollide = false
                state.PlayerParts[v] = true
            end
        end
    end

    local function clampVelocity()
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then
            return
        end

        local v = root.AssemblyLinearVelocity
        if v.Magnitude > state.MaxSpeed then
            root.AssemblyLinearVelocity  = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end
    end

    local function enable()
        if state.Enabled then
            return
        end
        state.Enabled = true
        state.CarParts = {}
        state.PlayerParts = {}
        state.PlayerConns = {}

        local carContainer = workspace:FindFirstChild("CarContainer")
        if carContainer then
            for _, v in ipairs(carContainer:GetChildren()) do
                registerCar(v)
            end
            state.Conn3 = carContainer.DescendantAdded:Connect(function(obj)
                if not state.Enabled then
                    return
                end
                if obj:IsA("BasePart") then
                    obj.CanCollide = false
                    state.CarParts[obj] = true
                end
            end)
        end

        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                registerPlayer(player)
                state.PlayerConns[player] = player.CharacterAdded:Connect(function()
                    task.wait(0.5)
                    if state.Enabled then
                        registerPlayer(player)
                    end
                end)
            end
        end

        state.Conn1 = RunService.Heartbeat:Connect(clampVelocity)

        state.Conn2 = Players.PlayerAdded:Connect(function(player)
            if not state.Enabled or player == LocalPlayer then
                return
            end
            state.PlayerConns[player] = player.CharacterAdded:Connect(function()
                task.wait(0.5)
                if state.Enabled then
                    registerPlayer(player)
                end
            end)
        end)

        task.spawn(function()
            while state.Enabled do
                task.wait(2)
                for part in pairs(state.CarParts) do
                    if not part.Parent then
                        state.CarParts[part] = nil
                    end
                end
                for part in pairs(state.PlayerParts) do
                    if not part.Parent then
                        state.PlayerParts[part] = nil
                    end
                end
            end
        end)
    end

    local function disable()
        if not state.Enabled then
            return
        end
        state.Enabled = false

        if state.Conn1 then
            state.Conn1:Disconnect()
            state.Conn1 = nil
        end
        if state.Conn2 then
            state.Conn2:Disconnect()
            state.Conn2 = nil
        end
        if state.Conn3 then
            state.Conn3:Disconnect()
            state.Conn3 = nil
        end

        if state.PlayerConns then
            for player, conn in pairs(state.PlayerConns) do
                pcall(function() conn:Disconnect() end)
            end
            state.PlayerConns = {}
        end

        for part in pairs(state.CarParts) do
            if part and part.Parent then
                part.CanCollide = true
            end
        end
        for part in pairs(state.PlayerParts) do
            if part and part.Parent then
                part.CanCollide = true
            end
        end

        state.CarParts = {}
        state.PlayerParts = {}
    end

    return {
        Set = function(v)
            if v then
                enable()
            else
                disable()
            end
            return state.Enabled
        end,

        Get = function()
            return state.Enabled
        end,

        CleanupPlayer = function(player)
            if state.PlayerConns and state.PlayerConns[player] then
                pcall(function() state.PlayerConns[player]:Disconnect() end)
                state.PlayerConns[player] = nil
            end
        end,
    }
end)()

--========================================================--
-- UNDERGROUND
--========================================================--

local function startUnderground()
    if UndergroundConnection then
        UndergroundConnection:Disconnect()
        UndergroundConnection = nil
    end
    UndergroundSavedCFrame = nil

    local Character, Humanoid, Root = getCharacter()
    if not Root or not Humanoid then
        return
    end

    UndergroundSavedCFrame = Root.CFrame

    UndergroundConnection = RunService.RenderStepped:Connect(function()
        if not Settings.Underground then
            return
        end

        local Character2, Humanoid2, Root2 = getCharacter()
        if not Root2 or not Humanoid2 then
            return
        end
        if not UndergroundSavedCFrame then
            return
        end

        local Current = Root2.CFrame
        local Rotation = Current - Current.Position
        local NewY = UndergroundSavedCFrame.Position.Y - Settings.UndergroundDepth

        Root2.CFrame = CFrame.new(
            Current.Position.X,
            NewY,
            Current.Position.Z
        ) * Rotation

        Root2.AssemblyLinearVelocity = Vector3.new(
            Root2.AssemblyLinearVelocity.X,
            0,
            Root2.AssemblyLinearVelocity.Z
        )
        Root2.AssemblyAngularVelocity = Vector3.zero
    end)
end

local function stopUnderground()
    if UndergroundConnection then
        UndergroundConnection:Disconnect()
        UndergroundConnection = nil
    end

    local _, Humanoid, Root = getCharacter()

    if Root then
        local CurrentPos = Root.Position
        local NewY = CurrentPos.Y + Settings.UndergroundDepth + 4

        Root.CFrame = CFrame.new(
            CurrentPos.X,
            NewY,
            CurrentPos.Z
        ) * (Root.CFrame - Root.CFrame.Position)

        Root.AssemblyLinearVelocity = Vector3.zero
        Root.AssemblyAngularVelocity = Vector3.zero
    end

    if Humanoid then
        Humanoid.WalkSpeed = Settings.DefaultSpeed
    end

    UndergroundSavedCFrame = nil
end

local function setUnderground(State)
    Settings.Underground = State

    if State then
        startUnderground()
    else
        stopUnderground()
    end
end

LocalPlayer.CharacterAdded:Connect(function(Character)
    local Humanoid = Character:WaitForChild("Humanoid", 10)
    local Root = Character:WaitForChild("HumanoidRootPart", 10)
    if not Humanoid or not Root then
        return
    end

    task.wait(0.5)

    Humanoid.WalkSpeed = Settings.DefaultSpeed
    workspace.Gravity = Settings.Gravity

    if Settings.Underground then
        if UndergroundConnection then
            UndergroundConnection:Disconnect()
            UndergroundConnection = nil
        end
        UndergroundSavedCFrame = nil
        startUnderground()
    else
        if UndergroundConnection then
            UndergroundConnection:Disconnect()
            UndergroundConnection = nil
        end
        UndergroundSavedCFrame = nil
    end
end)

--========================================================--
-- NOCLIP
--========================================================--

local Noclip = (function()
    local state = {
        Enabled       = false,
        Conn          = nil,
        DisabledWalls = {},
    }

    local overlapParams = OverlapParams.new()
    overlapParams.FilterType = Enum.RaycastFilterType.Exclude

    local groundParams = RaycastParams.new()
    groundParams.FilterType = Enum.RaycastFilterType.Exclude

    local function getPartYBounds(part)
        local cf = part.CFrame
        local size = part.Size
        local hx, hy, hz = size.X * 0.5, size.Y * 0.5, size.Z * 0.5
        local up = cf.UpVector
        local right = cf.RightVector
        local look = cf.LookVector
        local yExtent = math.abs(up.Y) * hy + math.abs(right.Y) * hx + math.abs(look.Y) * hz
        return cf.Position.Y - yExtent, cf.Position.Y + yExtent
    end

    local function isLadder(part)
        if part:IsA("TrussPart") then
            return true
        end
        local name = part.Name:lower()
        if name:find("ladder") or name:find("truss") or name:find("climb") then
            return true
        end
        local parent = part.Parent
        if parent and parent:IsA("Model") then
            local pName = parent.Name:lower()
            if pName:find("ladder") or pName:find("truss") then
                return true
            end
        end
        return false
    end

    local function onStepped()
        if not state.Enabled then
            return
        end
        local char = LocalPlayer.Character
        if not char then
            return
        end
        local root = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not root or not hum then
            return
        end

        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then
                part.CanCollide = false
            end
        end

        groundParams.FilterDescendantsInstances = { char }
        overlapParams.FilterDescendantsInstances = { char }

        local protected = {}

        local groundRay = workspace:Raycast(root.Position, Vector3.new(0, -6, 0), groundParams)
        local groundY = root.Position.Y - 3
        if groundRay and groundRay.Instance then
            protected[groundRay.Instance] = true
            groundY = groundRay.Position.Y
        end

        if hum.MoveDirection.Magnitude > 0.05 then
            local moveDir = hum.MoveDirection.Unit
            local forwardRay = workspace:Raycast(root.Position + moveDir * 1.5, Vector3.new(0, -6, 0), groundParams)
            if forwardRay and forwardRay.Instance then
                protected[forwardRay.Instance] = true
            end
            local closeRay = workspace:Raycast(root.Position + moveDir * 0.8, Vector3.new(0, -6, 0), groundParams)
            if closeRay and closeRay.Instance then
                protected[closeRay.Instance] = true
            end
        end

        local boxCF = root.CFrame * CFrame.new(0, 0.5, 0)
        local boxSize = Vector3.new(5, 6, 5)
        local touchingParts = {}
        pcall(function()
            touchingParts = workspace:GetPartBoundsInBox(boxCF, boxSize, overlapParams)
        end)

        local currentWalls = {}
        local chestY = root.Position.Y + 0.2
        local minWallTop = groundY + 1.2

        for _, part in ipairs(touchingParts) do
            if part:IsA("BasePart") and not part:IsA("Terrain") then
                if not protected[part] and not isLadder(part) then
                    local _, maxY = getPartYBounds(part)
                    if maxY > minWallTop and maxY > chestY then
                        currentWalls[part] = true
                        if state.DisabledWalls[part] == nil then
                            state.DisabledWalls[part] = part.CanCollide
                        end
                        part.CanCollide = false
                    end
                end
            end
        end

        for part, origCanCollide in pairs(state.DisabledWalls) do
            if not currentWalls[part] then
                if part and part.Parent then
                    pcall(function()
                        part.CanCollide = origCanCollide
                    end)
                end
                state.DisabledWalls[part] = nil
            end
        end
    end

    local function enable()
        if state.Enabled then
            return
        end
        state.Enabled = true
        Settings.Noclip = true

        if state.Conn then
            state.Conn:Disconnect()
        end
        state.Conn = RunService.Stepped:Connect(onStepped)
    end

    local function disable()
        if not state.Enabled then
            return
        end
        state.Enabled = false
        Settings.Noclip = false

        if state.Conn then
            state.Conn:Disconnect()
            state.Conn = nil
        end

        for part, origCanCollide in pairs(state.DisabledWalls) do
            if part and part.Parent then
                pcall(function()
                    part.CanCollide = origCanCollide
                end)
            end
        end
        state.DisabledWalls = {}

        local char = LocalPlayer.Character
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                    part.CanCollide = true
                end
            end
        end
    end

    return {
        Set = function(v)
            if v then
                enable()
            else
                disable()
            end
            return state.Enabled
        end,

        Get = function()
            return state.Enabled
        end,
    }
end)()

--========================================================--
-- TASE BYPASS
--========================================================--

local TaseBypass = (function()
    local TASE_ANIMS = {
        ["rbxassetid://279227693"] = true,
        ["rbxassetid://279229192"] = true,
    }

    local DEFAULT_SPEED = 16
    local DEFAULT_JUMP  = 7.2

    local Enabled = false

    local humanoid  = nil
    local lastSpeed = DEFAULT_SPEED
    local lastJump  = DEFAULT_JUMP

    local eventConns    = {}
    local humanoidConns = {}
    local charAddedConn = nil

    local PlayerTased = nil
    do
        local GunRemotes = ReplicatedStorage:FindFirstChild("GunRemotes")
        if GunRemotes then
            PlayerTased = GunRemotes:FindFirstChild("PlayerTased")
        end
    end

    local function clearTable(t)
        for _, c in ipairs(t) do
            if c and type(c.Disconnect) == "function" then
                pcall(function()
                    c:Disconnect()
                end)
            end
        end
        table.clear(t)
    end

    local function enableBackpack()
        if LocalPlayer:GetAttribute("BackpackEnabled") ~= true then
            LocalPlayer:SetAttribute("BackpackEnabled", true)
        end
    end

    local function setupCharacter(character)
        if not character or not Enabled then
            return
        end

        local hum = character:FindFirstChildOfClass("Humanoid")
            or character:WaitForChild("Humanoid", 5)
        if not hum then
            return
        end
        if not Enabled then
            return
        end

        humanoid = hum

        if hum.WalkSpeed > 0 then
            lastSpeed = hum.WalkSpeed
        end
        if hum.JumpHeight > 0 then
            lastJump  = hum.JumpHeight
        end

        clearTable(humanoidConns)

        humanoidConns[#humanoidConns + 1] =
            hum:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
                if hum.WalkSpeed > 0 then
                    lastSpeed = hum.WalkSpeed
                end
            end)

        humanoidConns[#humanoidConns + 1] =
            hum:GetPropertyChangedSignal("JumpHeight"):Connect(function()
                if hum.JumpHeight > 0 then
                    lastJump = hum.JumpHeight
                end
            end)
    end

    local function fixTase()
        if not Enabled then
            return
        end
        local hum = humanoid
        if not hum or not hum.Parent or hum.Health <= 0 then
            return
        end

        if hum.WalkSpeed == 0 and hum.JumpHeight == 0 then
            hum.WalkSpeed  = lastSpeed
            hum.JumpHeight = lastJump
        end

        for _, track in ipairs(hum:GetPlayingAnimationTracks()) do
            local anim = track.Animation
            if anim and TASE_ANIMS[anim.AnimationId] then
                track:Stop(0)
            end
        end

        enableBackpack()
    end

    local function enable()
        if Enabled then
            return
        end
        Enabled = true

        humanoid  = nil
        lastSpeed = DEFAULT_SPEED
        lastJump  = DEFAULT_JUMP
        clearTable(humanoidConns)

        if PlayerTased then
            eventConns[#eventConns + 1] = PlayerTased.OnClientEvent:Connect(function()
                task.defer(fixTase)
            end)
        end

        eventConns[#eventConns + 1] =
            LocalPlayer:GetAttributeChangedSignal("BackpackEnabled"):Connect(function()
                if Enabled and LocalPlayer:GetAttribute("BackpackEnabled") ~= true then
                    enableBackpack()
                end
            end)

        charAddedConn = LocalPlayer.CharacterAdded:Connect(function(c)
            humanoid = nil
            task.spawn(function()
                setupCharacter(c)
                enableBackpack()
            end)
        end)

        if LocalPlayer.Character then
            task.spawn(function()
                setupCharacter(LocalPlayer.Character)
                enableBackpack()
            end)
        end
    end

    local function disable()
        if not Enabled then
            return
        end
        Enabled = false

        clearTable(eventConns)
        clearTable(humanoidConns)

        if charAddedConn then
            charAddedConn:Disconnect()
            charAddedConn = nil
        end

        humanoid = nil
    end

    return {
        Set = function(v)
            if v == true then
                enable()
            else
                disable()
            end
            return Enabled
        end,

        Get = function()
            return Enabled
        end,
    }
end)()

--========================================================--
-- FE INVISIBLE
--========================================================--

local TweenService = game:GetService("TweenService")

local FEInvisible = (function()
    local state = {
        Enabled       = false,
        AnimTrack     = nil,
        HeartbeatConn = nil,
        Highlight     = nil,
        Saved         = {},
        RenderKey     = "FEInvisibleRenderStep",
    }

    local function getCharacter()
        return LocalPlayer.Character
    end

    local function isAlive()
        local char = getCharacter()
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        return hum ~= nil and hum.Health > 0
    end

    local function getOffsets(char)
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not hum or not root then
            return nil
        end
        local isR15 = (hum.RigType == Enum.HumanoidRigType.R15)
        local offsetY = hum.HipHeight + root.Size.Y / 2 - 1
        return isR15, offsetY
    end

    local function tweenTransparency(inst, target)
        TweenService:Create(
            inst,
            TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            { Transparency = target }
        ):Play()
    end

    local function applyGhostTransparency()
        local char = getCharacter()
        if not char then
            return
        end
        for _, d in ipairs(char:GetDescendants()) do
            if d:IsA("BasePart") or d:IsA("Decal") or d:IsA("Texture") then
                state.Saved[d] = state.Saved[d] or d.Transparency
                tweenTransparency(d, 0.99)
            end
        end
    end

    local function restoreTransparency()
        for inst, val in pairs(state.Saved) do
            if inst and inst.Parent then
                tweenTransparency(inst, val)
            end
        end
        state.Saved = {}
    end

    local function createGhostHighlight()
        local char = getCharacter()
        if not char or state.Highlight then
            return
        end

        local h = Instance.new("Highlight")
        h.Name = "FEInvisibleGhostOutline"
        h.FillTransparency = 1
        h.OutlineColor = Color3.fromRGB(255, 255, 255)
        h.OutlineTransparency = 1
        h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        h.Adornee = char
        h.Parent = char

        TweenService:Create(
            h,
            TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            { OutlineTransparency = 0.1 }
        ):Play()

        state.Highlight = h
    end

    local function removeGhostHighlight()
        if not state.Highlight then
            return
        end
        local h = state.Highlight
        state.Highlight = nil

        TweenService:Create(
            h,
            TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            { OutlineTransparency = 1 }
        ):Play()

        task.delay(0.35, function()
            pcall(function()
                h:Destroy()
            end)
        end)
    end

    local function playInvisAnimation()
        if not isAlive() then
            return
        end

        local char = getCharacter()
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not hum then
            return
        end

        local isR15 = (hum.RigType == Enum.HumanoidRigType.R15)
        local animId = isR15 and "18665825805" or "215384594"

        local anim = Instance.new("Animation")
        anim.AnimationId = "rbxassetid://" .. animId

        local animator = hum:FindFirstChildOfClass("Animator")
        if not animator then
            animator = Instance.new("Animator")
            animator.Parent = hum
        end

        state.AnimTrack = animator:LoadAnimation(anim)
        state.AnimTrack.Priority = Enum.AnimationPriority.Action4
        state.AnimTrack:Play(0, 0.001, 0)
        anim:Destroy()

        task.delay(0, function()
            if state.AnimTrack then
                state.AnimTrack.TimePosition = isR15 and 1.95 or 0.4
            end
        end)
    end

    local function cleanup()
        if state.HeartbeatConn then
            state.HeartbeatConn:Disconnect()
            state.HeartbeatConn = nil
        end

        pcall(function()
            RunService:UnbindFromRenderStep(state.RenderKey)
        end)

        if state.AnimTrack then
            pcall(function()
                state.AnimTrack:Stop(0)
            end)
            pcall(function()
                state.AnimTrack:Destroy()
            end)
            state.AnimTrack = nil
        end

        state.Saved = {}
        removeGhostHighlight()
    end

    local function enable()
        if state.Enabled or not isAlive() then
            return
        end
        state.Enabled = true

        applyGhostTransparency()
        createGhostHighlight()
        playInvisAnimation()

        pcall(function()
            RunService:UnbindFromRenderStep(state.RenderKey)
        end)

        RunService:BindToRenderStep(
            state.RenderKey,
            Enum.RenderPriority.Camera.Value - 1,
            function()
                if not state.Enabled or not isAlive() then
                    return
                end

                local char = getCharacter()
                local isR15, offsetY = getOffsets(char)
                local root = char and char:FindFirstChild("HumanoidRootPart")
                if not root or not offsetY then
                    return
                end

                root.CFrame = root.CFrame
                    * CFrame.new(0, offsetY, 0)
                    * CFrame.Angles(math.rad(isR15 and -180 or -90), 0, 0)

                if state.AnimTrack then
                    state.AnimTrack:AdjustWeight(0.001)
                end
            end
        )

        state.HeartbeatConn = RunService.Heartbeat:Connect(function()
            if not state.Enabled or not isAlive() then
                return
            end

            local char = getCharacter()
            local isR15, offsetY = getOffsets(char)
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if not root or not offsetY then
                return
            end

            root.CFrame = root.CFrame
                * CFrame.new(0, -offsetY, 0)
                * CFrame.Angles(math.rad(isR15 and 180 or 90), 0, 0)

            if state.AnimTrack then
                state.AnimTrack:AdjustWeight(100)
            end
        end)
    end

    local function disable()
        if not state.Enabled then
            return
        end
        state.Enabled = false

        restoreTransparency()
        cleanup()
    end

    LocalPlayer.CharacterAdded:Connect(function()
        if not state.Enabled then
            return
        end
        state.Enabled = false
        cleanup()
        task.wait(0.2)
        enable()
    end)

    return {
        Set = function(v)
            if v then
                enable()
            else
                disable()
            end
            return state.Enabled
        end,

        Get = function()
            return state.Enabled
        end,
    }
end)()

--========================================================--
-- ANTI-INVIS
--========================================================--

local AntiInvis = (function()
    local state = {
        Enabled    = false,
        Conn       = nil,
        RenderConn = nil,
        Revealed   = {},
    }

    local FE_ANIM_IDS = {
        ["rbxassetid://18665825805"] = true,
        ["rbxassetid://215384594"]   = true,
        ["18665825805"] = true,
        ["215384594"]   = true,
    }

    local function removeReveal(Player)
        local data = state.Revealed[Player]
        if data then
            if data.Highlight and data.Highlight.Parent then
                pcall(function() data.Highlight:Destroy() end)
            end
            if data.Billboard and data.Billboard.Parent then
                pcall(function() data.Billboard:Destroy() end)
            end
            if data.Adornments then
                for _, b in pairs(data.Adornments) do
                    if b and b.Parent then
                        pcall(function() b:Destroy() end)
                    end
                end
            end
            if data.SavedTransparencies then
                for part, orig in pairs(data.SavedTransparencies) do
                    if part and part.Parent then
                        pcall(function()
                            part.Transparency = orig
                            part.LocalTransparencyModifier = 0
                        end)
                    end
                end
            end
            state.Revealed[Player] = nil
        end
    end

    local function createChams(char, data)
        if not data.Adornments then
            data.Adornments = {}
        end
        for _, part in ipairs(char:GetChildren()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                local existing = data.Adornments[part]
                if not existing or not existing.Parent then
                    local b = Instance.new("BoxHandleAdornment")
                    b.Name = "AntiInvisCham"
                    b.Adornee = part
                    b.AlwaysOnTop = true
                    b.ZIndex = 10
                    b.Size = part.Size + Vector3.new(0.06, 0.06, 0.06)
                    b.Color3 = Color3.fromRGB(255, 30, 200)
                    b.Transparency = 0.35
                    b.Parent = part
                    data.Adornments[part] = b
                end
            end
        end
    end

    local function fixInvisRig(char, root, hum)
        local torso = char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
        if not torso or not root then
            return
        end

        local animator = hum:FindFirstChildOfClass("Animator")
        if animator then
            for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                local anim = track.Animation
                local id = anim and tostring(anim.AnimationId) or ""
                if FE_ANIM_IDS[id] or id:find("18665825805") or id:find("215384594") or (root.Position.Y - torso.Position.Y) > 2.5 then
                    pcall(function()
                        track:Stop(0)
                        track:AdjustWeight(0, 0)
                    end)
                end
            end
        end

        local rj = root:FindFirstChild("RootJoint") or torso:FindFirstChild("RootJoint")
        if rj then
            rj.Transform = CFrame.identity
            rj.C0 = CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0)
            rj.C1 = CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0)
        end

        if root.Position.Y > -10 and (root.Position.Y - torso.Position.Y) > 2.5 then
            torso.CFrame = root.CFrame
        end
    end

    local function revealPlayer(Player)
        local char = Player.Character
        if not char then
            return
        end
        local root = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not root or not hum or hum.Health <= 0 then
            removeReveal(Player)
            return
        end

        local data = state.Revealed[Player]
        if not data then
            data = {
                SavedTransparencies = {},
                Adornments = {},
                Highlight = nil,
                Billboard = nil,
            }
            state.Revealed[Player] = data
        end

        fixInvisRig(char, root, hum)

        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                if data.SavedTransparencies[part] == nil then
                    data.SavedTransparencies[part] = part.Transparency
                end
                part.Transparency = 0
                part.LocalTransparencyModifier = 0
            elseif part:IsA("Decal") then
                if data.SavedTransparencies[part] == nil then
                    data.SavedTransparencies[part] = part.Transparency
                end
                part.Transparency = 0
                part.LocalTransparencyModifier = 0
            end
        end

        createChams(char, data)

        if not data.Highlight or not data.Highlight.Parent then
            pcall(function()
                local h = Instance.new("Highlight")
                h.Name = "AntiInvisHighlight"
                h.Adornee = char
                h.FillColor = Color3.fromRGB(255, 30, 200)
                h.FillTransparency = 0.25
                h.OutlineColor = Color3.fromRGB(255, 255, 255)
                h.OutlineTransparency = 0
                h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                h.Parent = char
                data.Highlight = h
            end)
        end

        if not data.Billboard or not data.Billboard.Parent then
            pcall(function()
                local bb = Instance.new("BillboardGui")
                bb.Name = "AntiInvisOverhead"
                bb.Size = UDim2.fromOffset(200, 42)
                bb.StudsOffset = Vector3.new(0, 3.8, 0)
                bb.AlwaysOnTop = true
                bb.Adornee = root
                bb.Parent = root

                local label = Instance.new("TextLabel")
                label.Size = UDim2.fromScale(1, 1)
                label.BackgroundTransparency = 1
                label.Text = string.format("[INVIS] %s", Player.DisplayName)
                label.TextColor3 = Color3.fromRGB(255, 40, 220)
                label.TextStrokeTransparency = 0.2
                label.Font = Enum.Font.GothamBold
                label.TextSize = 14
                label.Parent = bb

                data.Billboard = bb
            end)
        end
    end

    local function isInvisible(Player)
        local char = Player.Character
        if not char then
            return false
        end

        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then
            return false
        end

        local root = char:FindFirstChild("HumanoidRootPart")
        local torso = char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")

        local checkParts = { "Torso", "UpperTorso", "Head" }
        for _, partName in ipairs(checkParts) do
            local part = char:FindFirstChild(partName)
            if part and part.Transparency > 0.75 then
                return true
            end
        end

        local animator = hum:FindFirstChildOfClass("Animator")
        if animator then
            for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                local anim = track.Animation
                local id = anim and tostring(anim.AnimationId) or ""
                if FE_ANIM_IDS[id] or id:find("18665825805") or id:find("215384594") then
                    return true
                end
            end
        end

        if root and torso then
            if (root.Position.Y - torso.Position.Y) > 2.5 then
                return true
            end
        end

        if root and root.Position.Y < -5 then
            return true
        end

        return false
    end

    local lastInvisCheck = 0
    local function updateScan()
        local now = os.clock()
        if now - lastInvisCheck < 0.2 then
            return
        end
        lastInvisCheck = now

        for _, Player in ipairs(Players:GetPlayers()) do
            if Player ~= LocalPlayer then
                if isInvisible(Player) then
                    revealPlayer(Player)
                else
                    removeReveal(Player)
                end
            end
        end
    end

    local function renderStep()
        if not state.Enabled then
            return
        end

        for Player, data in pairs(state.Revealed) do
            local char = Player.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if not char or not root or not hum or hum.Health <= 0 then
                removeReveal(Player)
            else
                fixInvisRig(char, root, hum)

                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                        part.Transparency = 0
                        part.LocalTransparencyModifier = 0
                    elseif part:IsA("Decal") then
                        part.Transparency = 0
                        part.LocalTransparencyModifier = 0
                    end
                end

                if root.Position.Y < -5 and data.Billboard then
                    local depth = math.floor(math.abs(root.Position.Y))
                    local label = data.Billboard:FindFirstChildOfClass("TextLabel")
                    if label then
                        label.Text = string.format("[UNDERGROUND -%dm] %s", depth, Player.DisplayName)
                    end
                end
            end
        end
    end

    local function enable()
        if state.Enabled then
            return
        end
        state.Enabled = true

        if state.Conn then
            state.Conn:Disconnect()
        end
        state.Conn = RunService.Heartbeat:Connect(updateScan)

        if state.RenderConn then
            state.RenderConn:Disconnect()
        end
        state.RenderConn = RunService.RenderStepped:Connect(renderStep)
    end

    local function disable()
        if not state.Enabled then
            return
        end
        state.Enabled = false

        if state.Conn then
            state.Conn:Disconnect()
            state.Conn = nil
        end
        if state.RenderConn then
            state.RenderConn:Disconnect()
            state.RenderConn = nil
        end

        for Player in pairs(state.Revealed) do
            removeReveal(Player)
        end
        state.Revealed = {}
    end

    return {
        Set = function(v)
            if v then
                enable()
            else
                disable()
            end
            return state.Enabled
        end,

        Get = function()
            return state.Enabled
        end,

        CleanupPlayer = function(Player)
            removeReveal(Player)
        end,
    }
end)()

--========================================================--
-- AUTO SPRINT
--========================================================--

local SprintState = {
    ShiftHeld = false,
}

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if input.UserInputType == Enum.UserInputType.Keyboard
       and (input.KeyCode == Enum.KeyCode.LeftShift
         or input.KeyCode == Enum.KeyCode.RightShift) then
        SprintState.ShiftHeld = true
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Keyboard
       and (input.KeyCode == Enum.KeyCode.LeftShift
         or input.KeyCode == Enum.KeyCode.RightShift) then
        SprintState.ShiftHeld = false
    end
end)

local function updateSprint()
    local Character = LocalPlayer.Character
    if not Character then
        return
    end
    local Humanoid = Character:FindFirstChildOfClass("Humanoid")
    if not Humanoid then
        return
    end

    if Humanoid.Health <= 0 then
        return
    end

    if Settings.Underground then
        if Humanoid.WalkSpeed ~= Settings.UndergroundSpeed then
            Humanoid.WalkSpeed = Settings.UndergroundSpeed
        end
        return
    end

    local speed = Settings.DefaultSpeed or 16
    if Settings.AutoSprint or SprintState.ShiftHeld then
        speed = speed + 8
    end
    if Humanoid.WalkSpeed ~= speed then
        Humanoid.WalkSpeed = speed
    end
end

--========================================================--
-- BYPASS ANTIJUMP
--========================================================--

local function updateJump()
    local StarterPlayer = game:GetService("StarterPlayer")
    local StarterScripts = StarterPlayer:FindFirstChild("StarterCharacterScripts")
    if not StarterScripts then
        return
    end

    local shouldDisable = Settings.AntiJump

    local starterAntiJump = StarterScripts:FindFirstChild("AntiJump")
    if starterAntiJump then
        starterAntiJump.Disabled = shouldDisable
    end

    local char = LocalPlayer.Character
    if char then
        local activeAntiJump = char:FindFirstChild("AntiJump")
        if activeAntiJump then
            activeAntiJump.Disabled = shouldDisable
        end
    end
end

LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(0.1)
    local activeAntiJump = char:FindFirstChild("AntiJump")
    if activeAntiJump then
        activeAntiJump.Disabled = Settings.AntiJump
    end
end)

--========================================================--
-- INF JUMP
--========================================================--

local InfJumpState = {
    SpaceHeld = false,
    JumpConn = nil,
    HeartbeatConn = nil,
    InputBeganConn = nil,
    InputEndedConn = nil,
    FocusConn = nil,
}

local function applyInfJumpImpulse()
    if not Settings.InfJump or UserInputService:GetFocusedTextBox() then
        return
    end
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if root and hum and hum.Health > 0 then
        local jumpVel = math.max(Settings.JumpPower or 50, 50)
        pcall(function()
            root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, jumpVel, root.AssemblyLinearVelocity.Z)
        end)
        pcall(function()
            root.Velocity = Vector3.new(root.Velocity.X, jumpVel, root.Velocity.Z)
        end)
        pcall(function()
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end)
    end
end

InfJumpState.InputBeganConn = UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then
        return
    end
    if input.KeyCode == Enum.KeyCode.Space then
        InfJumpState.SpaceHeld = true
    end
end)

InfJumpState.InputEndedConn = UserInputService.InputEnded:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.Space then
        InfJumpState.SpaceHeld = false
    end
end)

InfJumpState.FocusConn = UserInputService.TextBoxFocused:Connect(function()
    InfJumpState.SpaceHeld = false
end)

InfJumpState.JumpConn = UserInputService.JumpRequest:Connect(function()
    if not Settings.InfJump then
        return
    end
    applyInfJumpImpulse()
end)

InfJumpState.HeartbeatConn = RunService.Heartbeat:Connect(function()
    if not Settings.InfJump then
        return
    end
    if UserInputService:GetFocusedTextBox() then
        return
    end
    local isDown = false
    pcall(function()
        isDown = UserInputService:IsKeyDown(Enum.KeyCode.Space)
    end)
    if InfJumpState.SpaceHeld or isDown then
        applyInfJumpImpulse()
    end
end)

--========================================================--
-- RETURN ON DEATH
--========================================================--

local IsRespawning = false
local IsGrabbingWeapon = false
local IsTeleportingToDeath = false

local function getGiverByWeaponName(weaponName)
    if not weaponName then
        return nil
    end
    local name = tostring(weaponName):lower()
    if name:find("ak") then return getAK47() 
	end
    if name:find("remington") then return getShotgun() 
	end
    if name:find("mp5") then return getMP5() 
	end
    if name:find("sniper") then return getSniper() 
	end
    if name:find("m4a1") then return getM4A1() 
	end
    if name:find("fnfal") then return getFNFAL() 
	end
    return nil
end

local function hasAnyGun()
    local char = LocalPlayer.Character
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if char then
        for _, c in ipairs(char:GetChildren()) do
            if c:IsA("Tool") and (c:GetAttribute("ToolType") == "Gun" or getGiverByWeaponName(c.Name) ~= nil) then
                return true, c
            end
        end
    end
    if backpack then
        for _, c in ipairs(backpack:GetChildren()) do
            if c:IsA("Tool") and (c:GetAttribute("ToolType") == "Gun" or getGiverByWeaponName(c.Name) ~= nil) then
                return true, c
            end
        end
    end
    return false, nil
end

local function obtainWeapon(primaryWeaponName, fallbackWeaponName)
    if IsGrabbingWeapon or IsRespawning or IsTeleportingToDeath then
        return false
    end
    IsGrabbingWeapon = true

    local char = LocalPlayer.Character
    if not char then
        IsGrabbingWeapon = false
        return false
    end
    local root = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not root or not hum or hum.Health <= 0 then
        IsGrabbingWeapon = false
        return false
    end

    local targetName = primaryWeaponName or "AK-47"
    local giver = getGiverByWeaponName(targetName)
    if not giver and fallbackWeaponName then
        targetName = fallbackWeaponName
        giver = getGiverByWeaponName(fallbackWeaponName)
    end
    if not giver then
        giver = getAK47() or getShotgun() or getMP5()
        targetName = "AK-47"
    end

    if not giver or not giver:IsA("BasePart") then
        IsGrabbingWeapon = false
        return false
    end

    local savedCF = root.CFrame
    local giverCF = giver.CFrame
    local offset = Vector3.new(0, 3, 2)
    root.CFrame = giverCF + offset

    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(1e6, 1e6, 1e6)
    bv.Velocity = -offset.Unit * 50
    bv.Parent = root

    pcall(function()
        if firetouchinterest then
            firetouchinterest(root, giver, 0)
            task.wait(0.05)
            firetouchinterest(root, giver, 1)
        end
    end)

    task.wait(0.35)
    if bv and bv.Parent then
        bv:Destroy()
    end

    root.CFrame = savedCF
    root.AssemblyLinearVelocity = Vector3.zero
    pcall(function()
        hum:ChangeState(Enum.HumanoidStateType.GettingUp)
    end)

    task.wait(0.2)

    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if backpack and hum then
        local foundTool = nil
        for _, item in ipairs(backpack:GetChildren()) do
            if item:IsA("Tool") and (item:GetAttribute("ToolType") == "Gun" or getGiverByWeaponName(item.Name) ~= nil) then
                foundTool = item
                if item.Name:lower():find(targetName:lower()) then
                    break
                end
            end
        end
        if foundTool then
            hum:EquipTool(foundTool)
        end
    end

    IsGrabbingWeapon = false
    return true
end

--========================================================--
-- QUICK RESPAWN 
--========================================================--

local RespawnState = {
    LastAliveCF = nil,
    LastTeamName = nil,
    Busy = false,
    HasDied = false,
    HeartbeatConn = nil,
    DiedConn = nil,
    CharAddedConn = nil,
}

local function fixUI()
    -- If player is in Neutral (selecting team) or has no team, NEVER hide team selection GUI or override camera!
    if not LocalPlayer.Team or LocalPlayer.Team.Name == "Neutral" then
        local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
        local home = playerGui and playerGui:FindFirstChild("Home")
        if home then
            home.Enabled = true
            local intro = home:FindFirstChild("IntroFrame") or home:FindFirstChild("intro") or home:FindFirstChild("TeamSelect")
            if intro then
                intro.Visible = true
            end
        end
        return
    end

    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then
        local cam = workspace.CurrentCamera
        if cam then
            cam.CameraType = Enum.CameraType.Custom
            cam.CameraSubject = hum
        end
    end

    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    local home = playerGui and playerGui:FindFirstChild("Home")
    if home then
        home.Enabled = true
        local intro = home:FindFirstChild("IntroFrame") or home:FindFirstChild("intro") or home:FindFirstChild("TeamSelect")
        if intro and (IsRespawning or Settings.QuickRespawn) then
            intro.Visible = false
        end
    end

    pcall(function()
        LocalPlayer:SetAttribute("BackpackEnabled", true)
    end)
end

local function isTeamFull(teamName)
    if not teamName then
        return false
    end
    local Teams = game:GetService("Teams")
    local team = Teams:FindFirstChild(teamName)
    if not team then
        return false
    end

    if teamName == "Inmates" then
        return false
    end

    if teamName == "Guards" then
        local currentGuards = #team:GetPlayers()
        local totalPlayers = #Players:GetPlayers()
        local maxGuards = math.clamp(math.floor(totalPlayers / 3), 3, 8)

        local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
        local home = playerGui and playerGui:FindFirstChild("Home")
        local tsFrame = home and (home:FindFirstChild("TeamSelectFrame") or home:FindFirstChild("TeamSelect") or home:FindFirstChild("Teams"))
        if tsFrame then
            local guardsButton = tsFrame:FindFirstChild("Guards") or tsFrame:FindFirstChild("Guard")
            local fullLabel = guardsButton and guardsButton:FindFirstChild("Full")
            if fullLabel and fullLabel:IsA("GuiObject") and fullLabel.Visible then
                return true
            end
        end

        local isSelfGuard = (LocalPlayer.Team == team)
        local otherGuards = isSelfGuard and (currentGuards - 1) or currentGuards
        if otherGuards >= maxGuards or otherGuards >= 8 then
            return true
        end
    end

    return false
end

local function changeTeam(teamName, silent)
    local targetColor = nil
    if teamName == "Inmates" then
        targetColor = "Bright orange"
    elseif teamName == "Guards" then
        targetColor = "Bright blue"
    elseif teamName == "Neutral" then
        targetColor = "Medium stone grey"
    end

    if not targetColor then
        return false
    end

    local currentTeam = LocalPlayer.Team and LocalPlayer.Team.Name or ""
    if currentTeam == teamName then
        if not silent and UI and UI.Notify then
            UI:Notify({ Title = "Team Switcher", Content = "Already on " .. tostring(teamName) .. " team!", Duration = 2 })
        end
        return true
    end

    local wsRemote = workspace:FindFirstChild("Remote")
    local teamEvent = wsRemote and wsRemote:FindFirstChild("TeamEvent")
    local loadChar = wsRemote and wsRemote:FindFirstChild("loadchar")

    if not teamEvent then
        return false
    end

    if teamName == "Guards" and isTeamFull("Guards") then
        if not silent and UI and UI.Notify then
            UI:Notify({ Title = "Team Switcher", Content = "Guards team is full!", Duration = 3, Type = "warn" })
        end
        return false
    end

    if teamName == "Neutral" then
        pcall(function()
            teamEvent:FireServer("Medium stone grey")
        end)
        task.defer(function()
            local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
            local home = playerGui and playerGui:FindFirstChild("Home")
            if home then
                home.Enabled = true
                local intro = home:FindFirstChild("IntroFrame") or home:FindFirstChild("intro") or home:FindFirstChild("TeamSelect")
                if intro then
                    intro.Visible = true
                end
            end
        end)
        return true
    end

    -- In Prison Life, the server rejects direct team change to Guards/Inmates if not Neutral.
    -- Transition through Neutral first so the server accepts the team change:
    if currentTeam ~= "Neutral" then
        pcall(function()
            teamEvent:FireServer("Medium stone grey")
        end)
        local waitNeutral = os.clock() + 0.5
        while os.clock() < waitNeutral do
            if LocalPlayer.Team and LocalPlayer.Team.Name == "Neutral" then
                break
            end
            task.wait(0.02)
        end
    end

    -- Fire target team color
    pcall(function()
        teamEvent:FireServer(targetColor)
    end)

    -- Force respawn character on the new team
    task.wait(0.04)
    pcall(function()
        if loadChar then
            loadChar:InvokeServer(LocalPlayer)
        end
    end)
    pcall(function()
        if loadChar then
            loadChar:InvokeServer(nil, targetColor)
        end
    end)

    -- Also check RequestTeamChange remote if available
    local repRemotes = ReplicatedStorage:FindFirstChild("Remotes")
    local req = repRemotes and repRemotes:FindFirstChild("RequestTeamChange")
    if req then
        pcall(function()
            local Teams = game:GetService("Teams")
            local tObj = Teams:FindFirstChild(teamName)
            if tObj then
                req:InvokeServer(tObj, 1)
            end
        end)
    end

    local waitTeam = os.clock() + 1.2
    while os.clock() < waitTeam do
        if LocalPlayer.Team and LocalPlayer.Team.Name == teamName then
            break
        end
        task.wait(0.03)
    end

    fixUI()

    if not silent and UI and UI.Notify then
        if LocalPlayer.Team and LocalPlayer.Team.Name == teamName then
            UI:Notify({
                Title = "Team Switcher",
                Content = "Switched to " .. tostring(teamName) .. " team!",
                Duration = 2.5,
                Type = "success"
            })
        else
            UI:Notify({
                Title = "Team Switcher",
                Content = "Requested switch to " .. tostring(teamName),
                Duration = 2
            })
        end
    end

    return true
end

local function becomeCriminal()
    task.spawn(function()
        if UI and UI.Notify then
            UI:Notify({ Title = "Team Switcher", Content = "Becoming Criminal...", Duration = 2 })
        end

        -- Step 1: Must be on Inmates team first
        if not LocalPlayer.Team or LocalPlayer.Team.Name ~= "Inmates" then
            changeTeam("Inmates", true)
            local waitInmate = os.clock() + 3
            while os.clock() < waitInmate do
                if LocalPlayer.Team and LocalPlayer.Team.Name == "Inmates" then
                    break
                end
                task.wait(0.04)
            end
        end

        -- Step 2: Wait for character to spawn as Inmate
        local waitChar = os.clock() + 4
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        while (not char or not root or not hum or hum.Health <= 0) and os.clock() < waitChar do
            task.wait(0.05)
            char = LocalPlayer.Character
            root = char and char:FindFirstChild("HumanoidRootPart")
            hum = char and char:FindFirstChildOfClass("Humanoid")
        end

        if not root then
            if UI and UI.Notify then
                UI:Notify({ Title = "Team Switcher", Content = "Character not spawned yet!", Duration = 2.5, Type = "warn" })
            end
            return
        end

        task.wait(0.12)

        -- Step 3: Teleport to Criminal Base
        local crimCF = CFrame.new(-943.46, 94.13, 2063.63)
        root.CFrame = crimCF
        pcall(function()
            char:PivotTo(crimCF)
        end)
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero

        -- Also touch Criminal spawn pads if present
        pcall(function()
            local crimFolder = workspace:FindFirstChild("Criminals Spawn") or workspace:FindFirstChild("CriminalSpawn") or workspace:FindFirstChild("Criminal_Spawn")
            if crimFolder then
                local pad = crimFolder:IsA("BasePart") and crimFolder or crimFolder:FindFirstChildWhichIsA("BasePart")
                if pad and firetouchinterest then
                    firetouchinterest(root, pad, 0)
                    task.wait(0.05)
                    firetouchinterest(root, pad, 1)
                end
            end
        end)

        -- Step 4: Verify Criminal status
        local waitCrim = os.clock() + 3
        local isCrim = false
        while os.clock() < waitCrim do
            if LocalPlayer.Team and LocalPlayer.Team.Name == "Criminals" then
                isCrim = true
                break
            end
            task.wait(0.1)
        end

        if isCrim then
            if UI and UI.Notify then
                UI:Notify({ Title = "Team Switcher", Content = "Successfully joined Criminals team!", Duration = 3, Type = "success" })
            end
        else
            if UI and UI.Notify then
                UI:Notify({ Title = "Team Switcher", Content = "Teleported to Criminal Base!", Duration = 2.5, Type = "success" })
            end
        end
    end)
end

local function waitForTeam(targetTeamName, timeout)
    local start = os.clock()
    local maxWait = timeout or 0.35
    while os.clock() - start < maxWait do
        if LocalPlayer.Team and LocalPlayer.Team.Name == targetTeamName then
            return true
        end
        task.wait(0.02)
    end
    return false
end

local function doFastRespawn()
    if RespawnState.Busy or IsRespawning then
        return
    end

    local oldTeam = RespawnState.LastTeamName or (LocalPlayer.Team and LocalPlayer.Team.Name) or "Inmates"
    if oldTeam == "Criminals" or oldTeam == "Neutral" then
        oldTeam = "Inmates"
    end

    if isTeamFull(oldTeam) then
        oldTeam = "Inmates"
    end

    RespawnState.Busy = true
    IsRespawning = true

    local resetSafety = task.delay(3.5, function()
        if RespawnState.Busy or IsRespawning then
            RespawnState.Busy = false
            IsRespawning = false
            fixUI()
        end
    end)

    task.spawn(function()
        local success = false
        local attempts = 0

        while attempts < 2 and not success do
            attempts = attempts + 1
            changeTeam("Neutral")
            waitForTeam("Neutral", 0.35)
            task.wait(0.04)

            changeTeam(oldTeam)
            waitForTeam(oldTeam, 0.4)

            if LocalPlayer.Team and LocalPlayer.Team.Name == oldTeam then
                success = true
            else
                task.wait(0.05)
            end
        end

        if not success and LocalPlayer.Team and LocalPlayer.Team.Name == "Neutral" then
            changeTeam("Inmates")
            waitForTeam("Inmates", 0.4)
        end

        local expire = os.clock() + 2.5
        while os.clock() < expire do
            local c = LocalPlayer.Character
            local r = c and c:FindFirstChild("HumanoidRootPart")
            local h = c and c:FindFirstChildOfClass("Humanoid")
            if r and h and h.Health > 0 and LocalPlayer.Team and LocalPlayer.Team.Name ~= "Neutral" then
                break
            end
            task.wait(0.02)
        end

        fixUI()

        if resetSafety then
            task.cancel(resetSafety)
        end
        RespawnState.Busy = false
        IsRespawning = false
    end)
end

local function handleReturnOnDeath(char)
    if not Settings.ReturnOnDeath then
        RespawnState.HasDied = false
        return
    end

    if not LocalPlayer.Team or LocalPlayer.Team.Name == "Neutral" then
        RespawnState.HasDied = false
        return
    end

    task.spawn(function()
        local waitLimit = os.clock() + 4
        while os.clock() < waitLimit and IsRespawning do
            task.wait(0.03)
        end

        local root = char:WaitForChild("HumanoidRootPart", 4)
        local hum = char:WaitForChild("Humanoid", 4)
        if not root or not hum or hum.Health <= 0 then
            RespawnState.HasDied = false
            return
        end

        local targetCF = RespawnState.LastAliveCF
        if targetCF then
            IsTeleportingToDeath = true
            root.CFrame = targetCF
            root.AssemblyLinearVelocity = Vector3.zero
            root.Anchored = true
            task.wait(0.06)
            if root and root.Parent then
                root.Anchored = false
                root.CFrame = targetCF
                root.AssemblyLinearVelocity = Vector3.zero
            end
            task.wait(0.04)
            IsTeleportingToDeath = false
        end

        RespawnState.HasDied = false
    end)
end

local function onPlayerDied()
    if not LocalPlayer.Team or LocalPlayer.Team.Name == "Neutral" then
        return
    end
    if RespawnState.HasDied or RespawnState.Busy or IsRespawning then
        return
    end
    RespawnState.HasDied = true

    if Settings.QuickRespawn then
        task.spawn(doFastRespawn)
    end
end

local function hookRespawnCharacter(char)
    if RespawnState.DiedConn then
        RespawnState.DiedConn:Disconnect()
        RespawnState.DiedConn = nil
    end
    if RespawnState.HeartbeatConn then
        RespawnState.HeartbeatConn:Disconnect()
        RespawnState.HeartbeatConn = nil
    end

    local hum = char:WaitForChild("Humanoid", 5)
    local root = char:WaitForChild("HumanoidRootPart", 5)
    if not hum or not root then
        return
    end

    RespawnState.HeartbeatConn = RunService.Heartbeat:Connect(function()
        if not Settings.QuickRespawn and not Settings.ReturnOnDeath then
            return
        end
        if RespawnState.Busy or IsRespawning or IsGrabbingWeapon or IsTeleportingToDeath then
            return
        end
        if hum.Health > 0 and root.Parent then
            if root.Position.Y > -50 then
                RespawnState.LastAliveCF = root.CFrame
            end
            if LocalPlayer.Team and LocalPlayer.Team.Name ~= "Neutral" then
                RespawnState.LastTeamName = LocalPlayer.Team.Name
            end
        elseif hum.Health <= 0 and not RespawnState.HasDied then
            onPlayerDied()
        end
    end)

    RespawnState.DiedConn = hum.Died:Connect(function()
        onPlayerDied()
    end)
end

local function setupRespawnTracking()
    if not RespawnState.CharAddedConn then
        RespawnState.CharAddedConn = LocalPlayer.CharacterAdded:Connect(function(newChar)
            task.wait(0.05)
            if not LocalPlayer.Team or LocalPlayer.Team.Name == "Neutral" then
                RespawnState.HasDied = false
                local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
                local home = playerGui and playerGui:FindFirstChild("Home")
                if home then
                    home.Enabled = true
                    local intro = home:FindFirstChild("IntroFrame") or home:FindFirstChild("intro") or home:FindFirstChild("TeamSelect")
                    if intro then
                        intro.Visible = true
                    end
                end
                return
            end

            if Settings.QuickRespawn or IsRespawning then
                fixUI()
            end
            handleReturnOnDeath(newChar)
            hookRespawnCharacter(newChar)
        end)
    end

    LocalPlayer:GetPropertyChangedSignal("Team"):Connect(function()
        local team = LocalPlayer.Team
        if not team or team.Name == "Neutral" then
            RespawnState.Busy = false
            IsRespawning = false
            RespawnState.HasDied = false
            IsTeleportingToDeath = false
            task.defer(function()
                local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
                local home = playerGui and playerGui:FindFirstChild("Home")
                if home then
                    home.Enabled = true
                    local intro = home:FindFirstChild("IntroFrame") or home:FindFirstChild("intro") or home:FindFirstChild("TeamSelect")
                    if intro then
                        intro.Visible = true
                    end
                end
            end)
        end
    end)

    local char = LocalPlayer.Character
    if char then
        hookRespawnCharacter(char)
    end
end

setupRespawnTracking()

local QuickRespawn = {
    Set = function(v)
        Settings.QuickRespawn = v
        if v and LocalPlayer.Team and LocalPlayer.Team.Name ~= "Neutral" then
            RespawnState.LastTeamName = LocalPlayer.Team.Name
        end
        return Settings.QuickRespawn
    end,

    Get = function()
        return Settings.QuickRespawn
    end,

    RespawnNow = doFastRespawn,
}

local ReturnOnDeath = {
    Set = function(v)
        Settings.ReturnOnDeath = v
        return Settings.ReturnOnDeath
    end,

    Get = function()
        return Settings.ReturnOnDeath
    end,
}

--========================================================--
-- AUTOWEAPON
--========================================================--

local AutoWeapon = (function()
    local state = {
        Enabled = false,
        LastWeaponName = "AK-47",
        HeartbeatConn = nil,
        CharAddedConn = nil,
        IsDead = false,
    }

    local function handleRespawnWeapon()
        task.spawn(function()
            local timeout = os.clock() + 12
            while os.clock() < timeout do
                if IsRespawning or IsTeleportingToDeath or IsGrabbingWeapon then
                    task.wait(0.05)
                    continue
                end

                local c = LocalPlayer.Character
                local h = c and c:FindFirstChildOfClass("Humanoid")
                local r = c and c:FindFirstChild("HumanoidRootPart")

                if c and h and r and h.Health > 0 then
                    if Settings.ReturnOnDeath and RespawnState.LastAliveCF and (IsTeleportingToDeath or RespawnState.HasDied) then
                        task.wait(0.05)
                        continue
                    end

                    task.wait(0.12)
                    local hasGun, _ = hasAnyGun()
                    if not hasGun then
                        obtainWeapon(state.LastWeaponName or "AK-47", "Remington 870")
                    end
                    state.IsDead = false
                    break
                end
                task.wait(0.05)
            end
            state.IsDead = false
        end)
    end

    local function enable()
        if state.Enabled then
            return
        end
        state.Enabled = true
        state.IsDead = false

        if state.HeartbeatConn then
            state.HeartbeatConn:Disconnect()
        end
        state.HeartbeatConn = RunService.Heartbeat:Connect(function()
            if not state.Enabled then
                return
            end
            
            local character = LocalPlayer.Character
            local hum = character and character:FindFirstChildOfClass("Humanoid")
            
            if hum and hum.Health > 0 then
                local curTool = character:FindFirstChildOfClass("Tool")
                if curTool and (curTool:GetAttribute("ToolType") == "Gun" or getGiverByWeaponName(curTool.Name) ~= nil) then
                    state.LastWeaponName = curTool.Name
                elseif not state.LastWeaponName then
                    local backpack = LocalPlayer:FindFirstChild("Backpack")
                    if backpack then
                        for _, item in ipairs(backpack:GetChildren()) do
                            if item:IsA("Tool") and (item:GetAttribute("ToolType") == "Gun" or getGiverByWeaponName(item.Name) ~= nil) then
                                state.LastWeaponName = item.Name
                                break
                            end
                        end
                    end
                end
            elseif hum and hum.Health <= 0 and not state.IsDead then
                state.IsDead = true
                handleRespawnWeapon()
            end
        end)

        if state.CharAddedConn then
            state.CharAddedConn:Disconnect()
        end
        state.CharAddedConn = LocalPlayer.CharacterAdded:Connect(function()
            if not state.Enabled then
                return
            end
            handleRespawnWeapon()
        end)
    end

    local function disable()
        if not state.Enabled then
            return
        end
        state.Enabled = false
        if state.HeartbeatConn then
            state.HeartbeatConn:Disconnect()
            state.HeartbeatConn = nil
        end
        if state.CharAddedConn then
            state.CharAddedConn:Disconnect()
            state.CharAddedConn = nil
        end
        state.IsDead = false
    end

    return {
        Set = function(v)
            Settings.AutoWeapon = v
            if v then
                enable()
            else
                disable()
            end
            return state.Enabled
        end,

        Get = function()
            return state.Enabled
        end,
    }
end)()

--========================================================--
-- TARGET KILLER
--========================================================--

local TargetKiller = (function()
    local state = {
        Enabled = false,
        TargetPlayer = nil,
        TargetChar = nil,
        TargetSpawnTime = 0,
        LastCFrame = nil,
        LoopConn = nil,
        Busy = false,
        LastAttack = 0,
        BaseCooldown = 0.35,
        LastTeamWarn = 0,
        LastShieldWarn = 0,
    }

    local WeaponPriority = {
        ["M4A1"] = 1, ["AK47"] = 2, ["AK-47"] = 2, ["MP5"] = 3, ["Shotgun"] = 4, ["Remington 870"] = 4, ["FNFAL"] = 5, ["Sniper"] = 6,
    }

    local function isProtectedByShield(tChar)
        if not tChar then
            return false
        end
        if tChar:FindFirstChildOfClass("ForceField") or tChar:FindFirstChild("ForceField") then
            return true
        end
        for _, d in ipairs(tChar:GetChildren()) do
            if d:IsA("ForceField") or d.Name:lower():find("forcefield") or d.Name:lower():find("shield") then
                return true
            end
        end
        return false
    end

    local RaycastParams_Client = RaycastParams.new()
    RaycastParams_Client.FilterType = Enum.RaycastFilterType.Exclude

    local function getExternalSettings()
        local extSettings = _G.Settings or (getgenv and getgenv().Settings)
        
        if extSettings and extSettings.RapidFire then
            return true, tonumber(extSettings.FireRate) or 0.05
        end
        return false, 0
    end

    local function getShootEvent()
        local GunRemotes = game:GetService("ReplicatedStorage"):FindFirstChild("GunRemotes")
        return GunRemotes and GunRemotes:FindFirstChild("ShootEvent")
    end

    local function getGunTracers()
        local ok, mod = pcall(function()
            return require(game:GetService("ReplicatedStorage").SharedModules.GunTracers)
        end)
        if ok then
            return mod
        end
        return nil
    end

    local function isSameTeam(p1, p2)
        if not p1 or not p2 then
            return false
        end
        local t1 = p1.Team and p1.Team.Name
        local t2 = p2.Team and p2.Team.Name
        if not t1 or not t2 then
            return false
        end
        return t1 == t2
    end

    local function isGunTool(tool)
        if not tool or not tool:IsA("Tool") then
            return false
        end
        return (tool:GetAttribute("ToolType") == "Gun")
            or (getGiverByWeaponName(tool.Name) ~= nil)
            or (tool:FindFirstChild("GunStates") ~= nil)
    end

    local function equipGun()
        local char = LocalPlayer.Character
        local backpack = LocalPlayer:FindFirstChild("Backpack")
        if not char or not backpack then
            return nil
        end
        local hum = char:FindFirstChildOfClass("Humanoid")
        local pref = Settings.TargetKillerWeapon or "Equipped / Any"

        local currentTool = char:FindFirstChildOfClass("Tool")
        local isCurrentGun = isGunTool(currentTool)

        if isCurrentGun then
            if pref == "Equipped / Any" or currentTool.Name:lower() == pref:lower() then
                return currentTool
            end
        end

        if pref ~= "Equipped / Any" then
            for _, item in ipairs(backpack:GetChildren()) do
                if isGunTool(item) and item.Name:lower() == pref:lower() then
                    if hum then
                        hum:EquipTool(item)
                    end
                    return item
                end
            end
        end

        if isCurrentGun then
            return currentTool
        end

        local bestGun, bestPriority = nil, math.huge
        local Prio = {
            ["Remington 870"] = 1, ["Shotgun"] = 1, ["AK-47"] = 2, ["AK47"] = 2, ["M4A1"] = 3, ["MP5"] = 4, ["M9"] = 5
        }
        for _, item in ipairs(backpack:GetChildren()) do
            if isGunTool(item) then
                local p = Prio[item.Name] or 50
                if p < bestPriority then
                    bestPriority = p
                    bestGun = item
                end
            end
        end

        if bestGun and hum then
            hum:EquipTool(bestGun)
            return bestGun
        end

        return nil
    end

    local function resetPosition()
        if state.LastCFrame and LocalPlayer.Character then
            local root = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if root then
                root.Anchored = true
                root.CFrame = state.LastCFrame
                root.AssemblyLinearVelocity = Vector3.zero
                task.wait(0.05)
                root.Anchored = false
            end
        end
        state.LastCFrame = nil
    end

    local function mainLoop()
        if not state.Enabled or not state.TargetPlayer then
            return
        end
        if not state.TargetPlayer.Parent then
            resetPosition()
            state.TargetPlayer = nil
            return
        end
        local char = LocalPlayer.Character
        local tChar = state.TargetPlayer.Character
        if not char or not tChar then
            return
        end

        local root = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        local tHum = tChar:FindFirstChildOfClass("Humanoid")
        local tHead = tChar:FindFirstChild("Head")
        local tRoot = tChar:FindFirstChild("HumanoidRootPart")
        
        if not root or not hum or hum.Health <= 0 or not tHum or tHum.Health <= 0 or not tHead then 
            resetPosition()
            return 
        end

        if isSameTeam(LocalPlayer, state.TargetPlayer) then
            resetPosition()
            if os.clock() - state.LastTeamWarn > 5 then
                state.LastTeamWarn = os.clock()
                UI:Notify({
                    Title = "Auto Kill Target",
                    Content = string.format("Target %s is on ur team (%s)! Attack cancelled.", state.TargetPlayer.DisplayName, LocalPlayer.Team.Name),
                    Duration = 3,
                })
            end
            return
        end

        if IsRespawning or IsGrabbingWeapon or IsTeleportingToDeath then
            resetPosition()
            return
        end

        if state.TargetChar ~= tChar then
            state.TargetChar = tChar
            state.TargetSpawnTime = os.clock()
        end

        local timeSinceSpawn = os.clock() - (state.TargetSpawnTime or 0)
        if timeSinceSpawn < 0.5 then
            resetPosition()
            return
        end

        if isProtectedByShield(tChar) then
            resetPosition()
            if os.clock() - state.LastShieldWarn > 3 then
                state.LastShieldWarn = os.clock()
                UI:Notify({
                    Title = "Auto Kill Target",
                    Content = string.format("Target %s has a shield! Waiting for shield to expire...", state.TargetPlayer.DisplayName),
                    Duration = 2,
                })
            end
            return
        end

        local gun = equipGun()
        if not gun then
            resetPosition()
            if not IsGrabbingWeapon and not IsRespawning and not IsTeleportingToDeath then
                task.spawn(function()
                    local pref = Settings.TargetKillerWeapon or "Remington 870"
                    if pref:lower():find("ak") then
                        obtainWeapon("AK-47", "Remington 870")
                    else
                        obtainWeapon("Remington 870", "AK-47")
                    end
                end)
            end
            return
        end

        if not state.LastCFrame then
            state.LastCFrame = root.CFrame
        end

        local tVel = (tRoot and tRoot.AssemblyLinearVelocity) or Vector3.zero
        local targetHeadPos = tHead.Position
        local desiredPos = targetHeadPos + Vector3.new(0, 2.5, 0)

        root.CFrame = CFrame.lookAt(desiredPos, targetHeadPos)
        root.AssemblyLinearVelocity = tVel
        root.AssemblyAngularVelocity = Vector3.zero

        local rfEnabled, rfRate = getExternalSettings()
        local currentCooldown = state.BaseCooldown
        if rfEnabled then
            currentCooldown = math.max(rfRate, 0.01)
        end

        if not state.Busy and (os.clock() - state.LastAttack >= currentCooldown) then
            state.Busy = true

            local canShoot = true
            local attrAmmo = gun:GetAttribute("CurrentAmmo")
            if attrAmmo ~= nil and tonumber(attrAmmo) and tonumber(attrAmmo) <= 0 then
                canShoot = false
            end

            if canShoot then
                local headPart = char:FindFirstChild("Head") or root
                local shootEvent = getShootEvent()
                if shootEvent and headPart then
                    local payload = { { headPart.Position, tHead.Position, tHead } }
                    pcall(function()
                        shootEvent:FireServer(payload)
                    end)
                end
                
                local GunTracers = getGunTracers()
                if GunTracers and GunTracers.createBullet then
                    local muzzle = gun:FindFirstChild("Muzzle")
                    local muzzlePos = muzzle and muzzle.Position or root.Position
                    pcall(function()
                        GunTracers.createBullet(muzzlePos, tHead.Position)
                    end)
                end
            end
            state.LastAttack = os.clock()
            state.Busy = false
        end
    end

    local function enable()
        if state.Enabled then
            return
        end
        state.Enabled = true
        state.LastCFrame = nil
        state.Busy = false
        state.LastAttack = 0

        if state.LoopConn then
            state.LoopConn:Disconnect()
        end
        state.LoopConn = RunService.RenderStepped:Connect(function()
            if not state.Enabled then
                return
            end
            pcall(mainLoop)
        end)
    end

    local function disable()
        if not state.Enabled then
            return
        end
        state.Enabled = false
        if state.LoopConn then
            state.LoopConn:Disconnect()
            state.LoopConn = nil
        end
        resetPosition()
        state.Busy = false
    end

    return {
        Set = function(v)
            if v then
                enable()
            else
                disable()
            end
            return state.Enabled
        end,

        Get = function()
            return state.Enabled
        end,

        SetTarget = function(player)
            if state.TargetPlayer ~= player then
                resetPosition()
                state.TargetPlayer = player
                state.TargetChar = nil
                state.TargetSpawnTime = 0
            end
        end,

        GetTarget = function()
            return state.TargetPlayer
        end,

        SetCooldown = function(s)
            state.BaseCooldown = s
        end,
    }
end)()

--========================================================--
-- MOVEMENT
--========================================================--

Settings.DefaultSpeed = 16
Settings.SprintSpeed = 24
Settings.JumpPower = 50
Settings.Gravity = 196.2

local function setWalkSpeed(speed)
    Settings.DefaultSpeed = tonumber(speed) or 16
    Settings.SprintSpeed = Settings.DefaultSpeed + 8
    updateSprint()
end

local function setJumpPower(power)
    Settings.JumpPower = tonumber(power) or 50
    local _, humanoid = getCharacter()
    if humanoid then
        humanoid.UseJumpPower = true
        humanoid.JumpPower = Settings.JumpPower
    end
end

local function setGravity(gravity)
    Settings.Gravity = tonumber(gravity) or 196.2
    workspace.Gravity = Settings.Gravity
end

RunService.RenderStepped:Connect(function()
    if math.abs(workspace.Gravity - Settings.Gravity) > 0.1 then
        workspace.Gravity = Settings.Gravity
    end

    local char = LocalPlayer.Character
    if not char then
        return
    end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then
        return
    end

    if Settings.JumpPower ~= 50 or math.abs(Settings.Gravity - 196.2) > 0.5 then
        hum.UseJumpPower = true
        if hum.JumpPower ~= Settings.JumpPower then
            hum.JumpPower = Settings.JumpPower
        end
    else
        if hum.UseJumpPower then
            if hum.JumpPower ~= 50 then
                hum.JumpPower = 50
            end
        else
            if hum.JumpHeight ~= 7.2 then
                hum.JumpHeight = 7.2
            end
        end
    end

    local currentSpeed = Settings.DefaultSpeed
    if Settings.Underground then
        currentSpeed = Settings.UndergroundSpeed
    elseif Settings.AutoSprint or (SprintState and SprintState.ShiftHeld) then
        currentSpeed = Settings.DefaultSpeed + 8
    end

    if hum.WalkSpeed ~= currentSpeed then
        hum.WalkSpeed = currentSpeed
    end
end)

--========================================================--
-- SPINBOT
--========================================================--

local currentSpinAngle = 0
local spinbotLastActive = false

RunService.RenderStepped:Connect(function(dt)
    if not Settings.Spinbot then
        if spinbotLastActive then
            spinbotLastActive = false
            local char = LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if hum then
                hum.AutoRotate = true
            end
            if root then
                root.AssemblyAngularVelocity = Vector3.zero
                local cam = workspace.CurrentCamera
                if cam then
                    local _, camYaw, _ = cam.CFrame:ToEulerAnglesYXZ()
                    root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, camYaw, 0)
                end
            end
        end
        return
    end

    spinbotLastActive = true
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not root or not hum or hum.Health <= 0 then
        return
    end

    hum.AutoRotate = false

    local mode = Settings.SpinMode or "Spin"
    local speed = tonumber(Settings.SpinSpeed) or 30

    if mode == "Jitter" then
        currentSpinAngle = (currentSpinAngle + 180 + math.random(-35, 35)) % 360
    elseif mode == "Random" then
        currentSpinAngle = (currentSpinAngle + math.random(15, 60)) % 360
    elseif mode == "Slow" then
        currentSpinAngle = (currentSpinAngle + (speed * 0.4) * dt * 60) % 360
    else
        currentSpinAngle = (currentSpinAngle + speed * dt * 60) % 360
    end

    root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, math.rad(currentSpinAngle), 0)
end)

--========================================================--
-- BHOP
--========================================================--

local bhopStreak = 0
local lastHopTime = 0

local function handleBhop()
    if not Settings.Bhop then
        bhopStreak = 0
        return
    end

    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not root or not hum or hum.Health <= 0 then
        bhopStreak = 0
        return
    end

    local isMoving = (hum.MoveDirection.Magnitude > 0.05)
    local shouldHop = false

    if Settings.BhopAuto then
        shouldHop = isMoving
    else
        local isSpaceDown = false
        pcall(function()
            isSpaceDown = UserInputService:IsKeyDown(Enum.KeyCode.Space)
        end)
        local isInfSpace = (InfJumpState and InfJumpState.SpaceHeld == true)
        shouldHop = (isSpaceDown or isInfSpace) and (not UserInputService:GetFocusedTextBox())
    end

    local now = os.clock()

    if not shouldHop then
        if now - lastHopTime > 0.8 then
            bhopStreak = 0
        end
        return
    end

    local jumpPow = (hum.UseJumpPower and hum.JumpPower) or Settings.JumpPower or 50
    if jumpPow < 35 then jumpPow = 50 end
    local hopHeight = math.max(tonumber(Settings.BhopHopHeight) or jumpPow, jumpPow)
    local baseBoost = tonumber(Settings.BhopSpeedBoost) or 12

    if now - lastHopTime < 0.15 then
        if Settings.BhopPreserveMomentum and isMoving then
            local streakExtra = (Settings.BhopAccelerate and (bhopStreak * 2)) or 0
            local totalBoost = baseBoost + streakExtra
            local targetSpeed = (Settings.DefaultSpeed or 16) + totalBoost

            local moveDir = hum.MoveDirection.Unit
            local currentVel = root.AssemblyLinearVelocity
            local hSpeed = Vector2.new(currentVel.X, currentVel.Z).Magnitude

            if hSpeed < targetSpeed then
                local newH = moveDir * targetSpeed
                root.AssemblyLinearVelocity = Vector3.new(newH.X, currentVel.Y, newH.Z)
            end
        end
        return
    end

    local state = hum:GetState()
    local isGrounded = (hum.FloorMaterial ~= Enum.Material.Air)
        or (state == Enum.HumanoidStateType.Running)
        or (state == Enum.HumanoidStateType.Landed)

    if isGrounded then
        if now - lastHopTime < 0.7 then
            bhopStreak = math.min(bhopStreak + 1, 8)
        else
            bhopStreak = 1
        end
        lastHopTime = now

        local streakExtra = (Settings.BhopAccelerate and (bhopStreak * 2)) or 0
        local totalBoost = baseBoost + streakExtra
        local targetSpeed = (Settings.DefaultSpeed or 16) + totalBoost

        local moveDir = isMoving and hum.MoveDirection.Unit or (root.CFrame.LookVector * Vector3.new(1, 0, 1)).Unit
        local newH = moveDir * targetSpeed

        pcall(function()
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end)

        root.AssemblyLinearVelocity = Vector3.new(newH.X, hopHeight, newH.Z)
        pcall(function()
            root.Velocity = Vector3.new(newH.X, hopHeight, newH.Z)
        end)
    elseif Settings.BhopPreserveMomentum and isMoving then
        local streakExtra = (Settings.BhopAccelerate and (bhopStreak * 2)) or 0
        local totalBoost = baseBoost + streakExtra
        local targetSpeed = (Settings.DefaultSpeed or 16) + totalBoost

        local moveDir = hum.MoveDirection.Unit
        local currentVel = root.AssemblyLinearVelocity
        local hSpeed = Vector2.new(currentVel.X, currentVel.Z).Magnitude

        if hSpeed < targetSpeed then
            local newH = moveDir * targetSpeed
            root.AssemblyLinearVelocity = Vector3.new(newH.X, currentVel.Y, newH.Z)
        end
    end
end

RunService.Heartbeat:Connect(function()
    handleBhop()
end)

--========================================================--
-- KILLFEED NOTIFICATIONS
--========================================================--

local KillfeedNotify = false
local _lastKillfeedTime = 0

local KillfeedFolder = ReplicatedStorage:WaitForChild("Killfeed", 10)

if KillfeedFolder and KillfeedFolder:IsA("Folder") then

    KillfeedFolder.ChildAdded:Connect(function(child)

        if not KillfeedNotify then
            return
        end

        local now = os.clock()
        if now - _lastKillfeedTime < 1.0 then
            return
        end
        _lastKillfeedTime = now

        local text = child.Name
        if not text or #text < 5 or text == "#" then
            return
        end

        local icon = "skull"
        local tcolor = child:FindFirstChild("TColor")
        if tcolor and tcolor:IsA("Color3Value") then
            local c = tcolor.Value
            if c.R > c.B then
                icon = "sword"      
            elseif c.B > c.R then
                icon = "shield"     
            end
        end

        UI:Notify({
            Title = "Killfeed",
            Content = text,
            Icon = "skull",
            Duration = 3,
        })
    end)
end

--========================================================--
-- PLAYER CONNECTIONS
--========================================================--

local PlayerConnections = {}

local function cleanupPlayer(Player)
    if PlayerConnections[Player] then
        for _, conn in ipairs(PlayerConnections[Player]) do
            pcall(function() conn:Disconnect() end)
        end
        PlayerConnections[Player] = nil
    end

    removeESP(Player)
    removeHitbox(Player)
    removeHitboxVisual(Player)

    if DamageNumbers and DamageNumbers.CleanupPlayer then
        pcall(function() DamageNumbers.CleanupPlayer(Player) end)
    end
    if AntiFling and AntiFling.CleanupPlayer then
        pcall(function() AntiFling.CleanupPlayer(Player) end)
    end
    if AntiInvis and AntiInvis.CleanupPlayer then
        pcall(function() AntiInvis.CleanupPlayer(Player) end)
    end
    if TargetKiller and TargetKiller.GetTarget and TargetKiller.GetTarget() == Player then
        pcall(function()
            TargetKiller.SetTarget(nil)
        end)
    end
end

local function setupPlayer(Player)
    if Player == LocalPlayer then
        return
    end

    cleanupPlayer(Player)

    local conns = {}

    local cAdd = Player.CharacterAdded:Connect(function()
        task.wait(0.2)
        if not Player.Parent then
            return
        end
        if Settings.ESP then
            createESP(Player)
        end
        if Settings.Hitbox then
            createHitbox(Player)
            if Settings.HitboxVisual then
                createHitboxVisual(Player)
            end
        end
        if DamageNumbers and DamageNumbers.Get and DamageNumbers.Get() and DamageNumbers.HookPlayer then
            pcall(function() DamageNumbers.HookPlayer(Player) end)
        end
    end)
    table.insert(conns, cAdd)

    local cRem = Player.CharacterRemoving:Connect(function()
        removeESP(Player)
        removeHitbox(Player)
        removeHitboxVisual(Player)
    end)
    table.insert(conns, cRem)

    PlayerConnections[Player] = conns

    if Player.Character then
        if Settings.ESP then
            task.spawn(createESP, Player)
        end
        if Settings.Hitbox then
            task.spawn(createHitbox, Player)
            if Settings.HitboxVisual then
                task.spawn(createHitboxVisual, Player)
            end
        end
        if DamageNumbers and DamageNumbers.Get and DamageNumbers.Get() and DamageNumbers.HookPlayer then
            pcall(function() DamageNumbers.HookPlayer(Player) end)
        end
    end
end

for _, Player in ipairs(Players:GetPlayers()) do
    setupPlayer(Player)
end

Players.PlayerAdded:Connect(setupPlayer)

Players.PlayerRemoving:Connect(function(Player)
    cleanupPlayer(Player)
end)

--========================================================--
-- MAIN LOOP
--========================================================--

RunService.RenderStepped:Connect(function()
    if Settings.ESP then
        updateESP()
    end

    if Settings.Hitbox then
        updateHitboxVisuals()
        updateHitboxes()
    end

    if Settings.Underground then
        updateSprint()
    end
end)

--========================================================--
-- NIGHTFALL UI WINDOW
--========================================================--

local Window =
    UI:CreateWindow({
        Title = "Nightfall",
        Icon = "moon",
        Author = "Entervalov",
        Folder = "Nightfall",
        Scale = 0.78,
        Transparent = true,
        Theme = "Dark",
        SideBarWidth = 170,
        HasOutline = true,
        Changelogs = table.concat({
            "Added Noclip",
            "Fix QuickRespawn",
            "Redesigned UI",
            "Fix Auto Kill Target",
            "Added Config Manager"
        }, "\n")
    })

local function teleportToLocation(targetCF, name)
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not char or not root or not hum then
        if UI and UI.Notify then
            UI:Notify({ Title = "Teleport", Content = "Character not spawned yet!", Duration = 2, Type = "warn" })
        end
        return
    end

    if hum.Sit then
        hum.Sit = false
        task.wait(0.05)
    end

    local destCF = targetCF + Vector3.new(0, 3, 0)
    root.CFrame = destCF
    pcall(function()
        char:PivotTo(destCF)
    end)
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
    pcall(function()
        hum:ChangeState(Enum.HumanoidStateType.GettingUp)
    end)
    if name and UI and UI.Notify then
        UI:Notify({ Title = "Teleport", Content = "Teleported to " .. tostring(name), Duration = 2, Type = "success" })
    end
end

local function updateSpinbot()
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")

    if not Settings.Spinbot then
        if hum then
            hum.AutoRotate = true
        end
        if root then
            root.AssemblyAngularVelocity = Vector3.zero
            local cam = workspace.CurrentCamera
            if cam then
                local _, camYaw, _ = cam.CFrame:ToEulerAnglesYXZ()
                root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, camYaw, 0)
            end
        end
    else
        if hum then
            hum.AutoRotate = false
        end
        if root then
            local _, curYaw, _ = root.CFrame:ToEulerAnglesYXZ()
            currentSpinAngle = math.deg(curYaw)
        end
    end
end

local antiFlingConn = nil
local function updateAntiFling()
    if antiFlingConn then
        antiFlingConn:Disconnect()
        antiFlingConn = nil
    end
    if Settings.AntiFling then
        local collisionParts = {"HumanoidRootPart", "Torso", "UpperTorso", "LowerTorso"}
        antiFlingConn = RunService.Stepped:Connect(function()
            if not Settings.AntiFling then return end
            local myChar = LocalPlayer.Character
            local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
            if myRoot then
                myRoot.AssemblyAngularVelocity = Vector3.zero
            end
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer then
                    local char = player.Character
                    if char then
                        for _, partName in ipairs(collisionParts) do
                            local part = char:FindFirstChild(partName)
                            if part and part:IsA("BasePart") and part.CanCollide then
                                part.CanCollide = false
                            end
                        end
                    end
                end
            end
        end)
    end
end

local function updateNoclip()
    if Noclip and Noclip.Set then
        Noclip.Set(Settings.Noclip == true)
    end
end

local function updateRapidFire()
    local char = LocalPlayer.Character
    if char then
        for _, item in ipairs(char:GetChildren()) do
            if item:IsA("Tool") and patchTool then
                patchTool(item)
            end
        end
    end
    local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
    if bp then
        for _, item in ipairs(bp:GetChildren()) do
            if item:IsA("Tool") and patchTool then
                patchTool(item)
            end
        end
    end
end

--========================================================--
-- TABS (LOGICALLY GROUPED)
--========================================================--

local DashboardTab =
    Window:Tab({
        Title = "Dashboard",
        Icon = "home"
    })

local PlayerTab =
    Window:Tab({
        Title = "Player",
        Icon = "user"
    })

local CombatTab =
    Window:Tab({
        Title = "Combat",
        Icon = "crosshair"
    })

local WeaponsTab =
    Window:Tab({
        Title = "Weapons",
        Icon = "sword"
    })

local VisualsTab =
    Window:Tab({
        Title = "Visual",
        Icon = "eye"
    })

local LocationsTab =
    Window:Tab({
        Title = "Locations",
        Icon = "map-pin"
    })

local ConfigsTab =
    Window:Tab({
        Title = "Configs",
        Icon = "package"
    })

local SettingsTab =
    Window:Tab({
        Title = "Settings",
        Icon = "settings"
    })

--========================================================--
-- 1. DASHBOARD (COMMAND CENTER & QUICK SHORTCUTS)
--========================================================--

DashboardTab:Section({
    Title = "Quick Features"
})

local espDashboard = DashboardTab:Toggle({
    Title = "ESP",
    Desc = "See all players and items through walls",
    Value = Settings.ESP,
    Callback = function(State)
        Settings.ESP = State
        updateESP()
    end,
})

local sprintDashboard = DashboardTab:Toggle({
    Title = "AutoSprint",
    Desc = "Automatically enables fast sprinting",
    Value = Settings.AutoSprint,
    Callback = function(State)
        Settings.AutoSprint = State
        updateSprint()
    end,
})

DashboardTab:Toggle({
    Title = "Tase Bypass",
    Desc = "Complete immunity against police taser stuns",
    Value = false,
    Callback = function(State)
        if TaseBypass and TaseBypass.Set then
            TaseBypass.Set(State)
        end
    end,
})

DashboardTab:Toggle({
    Title = "Anti-Fling",
    Desc = "Prevents other players from pushing or flinging you",
    Value = false,
    Callback = function(State)
        Settings.AntiFling = State
        updateAntiFling()
    end,
})

DashboardTab:Section({
    Title = "Player Speed & Jump"
})

DashboardTab:Slider({
    Title = "Walk Speed",
    Desc = "Adjust character movement speed",
    Value = {
        Min = 16,
        Max = 150,
        Default = 16
    },
    Callback = function(Value)
        setWalkSpeed(Value)
        local Character, Humanoid = getCharacter()
        if Humanoid then
            Humanoid.WalkSpeed = Settings.DefaultSpeed
        end
    end
})

DashboardTab:Slider({
    Title = "Jump Power",
    Desc = "Adjust character jump height/power",
    Value = {
        Min = 50,
        Max = 250,
        Default = 50
    },
    Callback = function(Value)
        setJumpPower(Value)
        local Character, Humanoid = getCharacter()
        if Humanoid then
            if Humanoid.UseJumpPower then
                Humanoid.JumpPower = Settings.JumpPower
            else
                Humanoid.JumpHeight = (Settings.JumpPower / 50) * 7.2
            end
        end
    end
})

DashboardTab:Section({
    Title = "Quick Teleports"
})

DashboardTab:Button({
    Title = "📍 Criminal Base",
    Desc = "Instant teleport to Criminal Base",
    Callback = function()
        teleportToLocation(CFrame.new(-943.46, 94.13, 2063.63), "Criminal Base")
    end
})

DashboardTab:Button({
    Title = "📍 Prison Yard",
    Desc = "Instant teleport to the outdoor yard",
    Callback = function()
        teleportToLocation(CFrame.new(821.4232177734375, 97.99993133544922, 2479.514892578125), "Prison Yard")
    end
})

DashboardTab:Button({
    Title = "📍 Guards Armory",
    Desc = "Instant teleport to Guard Spawn / Armory",
    Callback = function()
        teleportToLocation(CFrame.new(829.2570190429688, 99.9766616821289, 2242.1328125), "Guards Armory")
    end
})

DashboardTab:Section({
    Title = "Quick Armory Grab"
})

DashboardTab:Button({
    Title = "🔫 Grab Remington Shotgun",
    Desc = "Instant pickup Remington 870",
    Callback = function()
        teleportToGiver(getShotgun)
    end
})

DashboardTab:Button({
    Title = "🔫 Grab AK-47",
    Desc = "Instant pickup AK-47 from Criminal Base",
    Callback = function()
        teleportToGiver(getAK47)
    end
})

DashboardTab:Button({
    Title = "🔫 Grab M4A1",
    Desc = "Instant pickup M4A1 rifle",
    Callback = function()
        teleportToGiver(getM4A1)
    end
})

--========================================================--
-- 2. PLAYER (MOVEMENT, BHOP, NOCLIP, UNDERGROUND, AUTOMATICS)
--========================================================--

PlayerTab:Section({
    Title = "Movement & Physics"
})

PlayerTab:Toggle({
    Title = "Anti-Jump",
    Desc = "Disables the jump limit",
    Value = false,
    Callback = function(State)
        Settings.AntiJump = State
        updateJump()
    end,
})

PlayerTab:Toggle({
    Title = "Inf Jump",
    Desc = "Hold space to ascend / fly upwards",
    Value = false,
    Callback = function(State)
        Settings.InfJump = State
        if not State and InfJumpState then
            InfJumpState.SpaceHeld = false
        end
    end,
})

local sprintPlayer = PlayerTab:Toggle({
    Title = "AutoSprint",
    Desc = "Autosprint",
    Value = false,
    Callback = function(State)
        Settings.AutoSprint = State
        updateSprint()
    end,
})

PlayerTab:Slider({
    Title = "Walk Speed",
    Desc = "Running speed",
    Value = {
        Min = 16,
        Max = 150,
        Default = 16
    },
    Callback = function(Value)
        setWalkSpeed(Value)
        local Character, Humanoid = getCharacter()
        if Humanoid then
            Humanoid.WalkSpeed = Settings.DefaultSpeed
        end
    end
})

PlayerTab:Slider({
    Title = "Jump Power",
    Desc = "Jump height (JumpPower / JumpHeight)",
    Value = {
        Min = 50,
        Max = 250,
        Default = 50
    },
    Callback = function(Value)
        setJumpPower(Value)
        local Character, Humanoid = getCharacter()
        if Humanoid then
            if Humanoid.UseJumpPower then
                Humanoid.JumpPower = Settings.JumpPower
            else
                Humanoid.JumpHeight = (Settings.JumpPower / 50) * 7.2
            end
        end
    end
})

PlayerTab:Slider({
    Title = "Gravity",
    Desc = "Adjust world gravity (Default: 196.2)",
    Value = {
        Min = 0,
        Max = 300,
        Default = 196.2
    },
    Callback = function(Value)
        local val = tonumber(Value) or 196.2
        Settings.Gravity = val
        workspace.Gravity = val
    end
})

PlayerTab:Section({
    Title = "Bunny Hop (Bhop)"
})

PlayerTab:Toggle({
    Title = "Bhop",
    Desc = "Enables Bunny Hop jumping",
    Value = false,
    Callback = function(State)
        Settings.Bhop = State
    end,
})

PlayerTab:Toggle({
    Title = "Auto Hop",
    Desc = "Automatically hops without needing to hold Space",
    Value = false,
    Callback = function(State)
        Settings.BhopAuto = State
    end,
})

PlayerTab:Slider({
    Title = "Hop Height",
    Parent = "Bhop",
    Desc = "Height of each hop jump",
    Value = {
        Min = 30,
        Max = 100,
        Default = 50
    },
    Callback = function(Value)
        Settings.BhopHopHeight = tonumber(Value) or 50
    end
})

PlayerTab:Slider({
    Title = "Bhop Speed Boost",
    Parent = "Bhop",
    Desc = "Additional speed gained while bunny hopping",
    Value = {
        Min = 0,
        Max = 40,
        Default = 14
    },
    Callback = function(Value)
        Settings.BhopSpeedBoost = tonumber(Value) or 14
    end
})

PlayerTab:Toggle({
    Title = "Consecutive Boost",
    Desc = "Increases speed with each consecutive hop",
    Value = true,
    Callback = function(State)
        Settings.BhopAccelerate = State
    end,
})

PlayerTab:Toggle({
    Title = "Preserve Momentum",
    Desc = "Preserves forward speed in air",
    Value = true,
    Callback = function(State)
        Settings.BhopPreserveMomentum = State
    end,
})

PlayerTab:Section({
    Title = "Noclip & Stealth"
})

PlayerTab:Toggle({
    Title = "Noclip",
    Desc = "Walk through walls and obstacles",
    Value = false,
    Callback = function(State)
        Settings.Noclip = State
        updateNoclip()
    end,
})

PlayerTab:Keybind({
    Title = "Noclip Keybind",
    Parent = "Noclip",
    Desc = "Toggle noclip on/off with key",
    Value = Enum.KeyCode.E,
    Callback = function()
        local Character, Humanoid = getCharacter()
        if not Character or not Humanoid then
            return
        end
        local newState = not Settings.Noclip
        Settings.Noclip = newState
        updateNoclip()
    end,
})

PlayerTab:Toggle({
    Title = "Invisible",
    Desc = "FE Invisibility exploit",
    Value = false,
    Callback = function(State)
        FEInvisible.Set(State)
    end,
})

PlayerTab:Section({
    Title = "Underground Exploit"
})

PlayerTab:Toggle({
    Title = "Underground",
    Desc = "Saves startup point and returns to it when turned off",
    Value = false,
    Callback = function(State)
        setUnderground(State)
    end
})

PlayerTab:Keybind({
    Title = "Undergrounder (Set key)",
    Parent = "Underground",
    Desc = "Toggle underground mode key",
    Value = Enum.KeyCode.V,
    Callback = function()
        local Character, Humanoid = getCharacter()
        if not Character or not Humanoid then
            return
        end
        local newState = not Settings.Underground
        setUnderground(newState)
    end,
})

PlayerTab:Slider({
    Title = "Depth",
    Parent = "Underground",
    Desc = "Underground depth level",
    Value = {
        Min = 2,
        Max = 30,
        Default = 8
    },
    Callback = function(Value)
        Settings.UndergroundDepth = tonumber(Value) or 8
    end
})

PlayerTab:Slider({
    Title = "Speed",
    Desc = "Movement speed underground",
    Value = {
        Min = 16,
        Max = 150,
        Default = 20
    },
    Callback = function(Value)
        Settings.UndergroundSpeed = tonumber(Value) or 20
        if Settings.Underground then
            updateSprint()
        end
    end
})

PlayerTab:Section({
    Title = "Character Automatics"
})

PlayerTab:Toggle({
    Title = "Quick Respawn",
    Desc = "Fast respawn upon death",
    Value = Settings.QuickRespawn or false,
    Callback = function(State)
        QuickRespawn.Set(State)
    end,
})

PlayerTab:Toggle({
    Title = "Return on Death",
    Desc = "Teleports back to the death position upon respawning",
    Value = Settings.ReturnOnDeath or false,
    Callback = function(State)
        ReturnOnDeath.Set(State)
    end,
})

PlayerTab:Toggle({
    Title = "Auto Criminal",
    Desc = "Automatically joins criminal team",
    Value = false,
    Callback = function(State)
        AutoCriminal.Set(State)
    end,
})

PlayerTab:Button({
    Title = "Become Criminal",
    Desc = "Switches to Inmate and teleports to Criminal Base",
    ButtonText = "Join Crims",
    Icon = "target",
    Callback = function()
        becomeCriminal()
    end
})

--========================================================--
-- 3. COMBAT (TARGET KILLER, HITBOX, SPINBOT, DEFENSE)
--========================================================--

CombatTab:Section({
    Title = "Target Killer"
})

local tkPlayerList = {}
for _, p in ipairs(game.Players:GetPlayers()) do
    if p ~= LocalPlayer then
        table.insert(tkPlayerList, p.Name)
    end
end

local tkDropdown = CombatTab:Dropdown({
    Title = "Target Player",
    Desc = "Choose the player's name you want to kill",
    Values = tkPlayerList,
    Value = nil,
    Callback = function(Value)
        local target = game.Players:FindFirstChild(Value)
        if target then
            TargetKiller.SetTarget(target)
        end
    end,
})

CombatTab:Dropdown({
    Title = "Target Weapon",
    Desc = "Choose gun to use or keep currently equipped weapon in hand",
    Values = { "Equipped / Any", "Remington 870", "AK-47", "M4A1", "MP5", "M9" },
    Value = "Equipped / Any",
    Callback = function(Value)
        Settings.TargetKillerWeapon = Value or "Equipped / Any"
    end,
})

local tkToggle = CombatTab:Toggle({
    Title = "Auto Kill Target",
    Desc = "Teleport above and shoot at the selected player",
    Value = false,
    Callback = function(State)
        if State then
            if not TargetKiller.GetTarget() then
                UI:Notify({
                    Title = "Error", Content = "First, choose a player", Duration = 3
                })
                tkToggle:Set(false)
                return
            end
        end
        TargetKiller.Set(State)
    end,
})

local _refreshDropdownScheduled = false
local function scheduleDropdownRefresh()
    if _refreshDropdownScheduled then
        return
    end
    _refreshDropdownScheduled = true
    task.delay(0.3, function()
        _refreshDropdownScheduled = false
        local newList = {}
        for _, p in ipairs(game.Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Parent then
                table.insert(newList, p.Name)
            end
        end
        table.sort(newList)
        pcall(function()
            tkDropdown:Refresh(newList)
        end)
    end)
end

game.Players.PlayerAdded:Connect(function(p)
    if p ~= LocalPlayer then
        scheduleDropdownRefresh()
    end
end)

game.Players.PlayerRemoving:Connect(function(p)
    if p ~= LocalPlayer then
        scheduleDropdownRefresh()
    end
end)

CombatTab:Section({
    Title = "Hitbox Expander"
})

CombatTab:Toggle({
    Title = "Hitbox",
    Desc = "Expands opponent hitboxes for easy shooting",
    Value = false,
    Callback = function(State)
        Settings.Hitbox = State
        updateHitboxes()
    end,
})

CombatTab:Section({
    Title = "Spinbot"
})

CombatTab:Toggle({
    Title = "Spinbot",
    Desc = "Quickly spin your character to avoid enemy fire",
    Value = false,
    Callback = function(State)
        Settings.Spinbot = State
        updateSpinbot()
    end,
})

CombatTab:Slider({
    Title = "Spin Speed",
    Parent = "Spinbot",
    Desc = "Rotation speed",
    Value = {
        Min = 5,
        Max = 100,
        Default = 30
    },
    Callback = function(Value)
        Settings.SpinSpeed = tonumber(Value) or 30
    end,
})

CombatTab:Dropdown({
    Title = "Spin Mode",
    Parent = "Spinbot",
    Desc = "Spin style mode",
    Values = { "Spin", "Jitter", "Random" },
    Value = "Spin",
    Callback = function(Value)
        Settings.SpinMode = Value or "Spin"
    end,
})

CombatTab:Section({
    Title = "Defense & Protection"
})

CombatTab:Toggle({
    Title = "Anti-Fling",
    Desc = "Prevents players from flinging you with physics collisions",
    Value = false,
    Callback = function(State)
        Settings.AntiFling = State
        updateAntiFling()
    end,
})

CombatTab:Toggle({
    Title = "Anti-Invis",
    Desc = "Reveals invisible exploiters so you can see them",
    Value = false,
    Callback = function(State)
        AntiInvis.Set(State)
    end,
})

CombatTab:Toggle({
    Title = "Tase Bypass",
    Desc = "Immunity against guard tasers",
    Value = false,
    Callback = function(State)
        TaseBypass.Set(State)
    end,
})

--========================================================--
-- 4. WEAPONS (MODIFICATIONS, AUTOMATICS, INSTANT TELEPORTS)
--========================================================--

WeaponsTab:Section({
    Title = "Weapon Modifications"
})

WeaponsTab:Toggle({
    Title = "Rapid Fire",
    Desc = "Removes gun cooldown for ultra-fast firing",
    Value = false,
    Callback = function(State)
        Settings.RapidFire = State
        updateRapidFire()
    end,
})

WeaponsTab:Slider({
    Title = "Fire Rate",
    Parent = "Rapid Fire",
    Desc = "Delay between shots (Lower is faster)",
    Value = {
        Min = 0.01,
        Max = 0.5,
        Default = 0.05
    },
    Callback = function(Value)
        Settings.FireRate = tonumber(Value) or 0.05
    end,
})

WeaponsTab:Toggle({
    Title = "Custom Weapon Visual",
    Desc = "Customizes firearm visual models",
    Value = false,
    Callback = function(State)
        CustomWeapon.Set(State)
    end,
})

WeaponsTab:Section({
    Title = "Weapon Automatics"
})

WeaponsTab:Toggle({
    Title = "Auto Weapon",
    Desc = "Automatically acquires guns on spawn",
    Value = false,
    Callback = function(State)
        AutoWeapon.Set(State)
    end,
})

WeaponsTab:Section({
    Title = "Instant Weapon Grab (Teleports)"
})

WeaponsTab:Button({
    Title = "🔫 Shotgun (Remington 870)",
    Desc = "Teleport grab Remington 870 shotgun",
    Callback = function()
        teleportToGiver(getShotgun)
    end
})

WeaponsTab:Button({
    Title = "🔫 AK-47",
    Desc = "Teleport grab AK-47 assault rifle",
    Callback = function()
        teleportToGiver(getAK47)
    end
})

WeaponsTab:Button({
    Title = "🔫 M4A1",
    Desc = "Teleport grab M4A1 rifle",
    Callback = function()
        teleportToGiver(getM4A1)
    end
})

WeaponsTab:Button({
    Title = "🔫 FNFAL",
    Desc = "Teleport grab FNFAL rifle (if available)",
    Callback = function()
        teleportToGiver(getFNFAL)
    end
})

WeaponsTab:Button({
    Title = "🔫 MP5",
    Desc = "Teleport grab MP5 submachine gun (if available)",
    Callback = function()
        teleportToGiver(getMP5)
    end
})

WeaponsTab:Button({
    Title = "🔫 Sniper",
    Desc = "Teleport grab Sniper rifle (if available)",
    Callback = function()
        teleportToGiver(getSniper)
    end
})

--========================================================--
-- 5. VISUALS (ESP, HIGHLIGHTS, DAMAGE, FULLBRIGHT)
--========================================================--

VisualsTab:Section({
    Title = "ESP & Highlights"
})

local espVisual = VisualsTab:Toggle({
    Title = "ESP",
    Desc = "Shows player ESP boxes and names",
    Value = false,
    Callback = function(State)
        Settings.ESP = State
        updateESP()
    end,
})

VisualsTab:Toggle({
    Title = "Team Colors",
    Desc = "Colors ESP based on player team (Inmate, Guard, Criminal)",
    Value = true,
    Callback = function(State)
        Settings.TeamColors = State
        if Settings.ESP then
            updateESP()
        end
    end,
})

VisualsTab:Toggle({
    Title = "Highlight",
    Desc = "Applies glowing chams highlight to characters",
    Value = true,
    Callback = function(State)
        Settings.Highlight = State
        if Settings.ESP then
            updateESP()
        end
    end,
})

local lastControlSync = 0
local controlSyncConnection
controlSyncConnection = RunService.Heartbeat:Connect(function()
    if getgenv and getgenv().NightFallGUI and not getgenv().NightFallGUI.Parent then
        controlSyncConnection:Disconnect()
        return
    end
    if os.clock() - lastControlSync < 0.1 then return end
    lastControlSync = os.clock()
    espDashboard:Set(Settings.ESP, true)
    espVisual:Set(Settings.ESP, true)
    sprintDashboard:Set(Settings.AutoSprint, true)
    sprintPlayer:Set(Settings.AutoSprint, true)
end)

VisualsTab:Section({
    Title = "Combat Visuals"
})

VisualsTab:Toggle({
    Title = "Damage Visible",
    Desc = "Displays floating damage indicators when hitting enemies",
    Value = false,
    Callback = function(State)
        DamageNumbers.Set(State)
    end,
})

VisualsTab:Section({
    Title = "World Lighting"
})

VisualsTab:Toggle({
    Title = "Fullbright",
    Desc = "Removes darkness, fog, and shadows for full visibility",
    Value = false,
    Callback = function(State)
        Settings.Fullbright = State
        updateFullbright()
    end
})

--========================================================--
-- 6. LOCATIONS (MAP WAYPOINTS)
--========================================================--

LocationsTab:Section({
    Title = "Map Locations"
})

LocationsTab:Button({
    Title = "📍 Criminal Base",
    Desc = "Teleport to Criminal Base hideout",
    Callback = function()
        teleportToLocation(CFrame.new(-943.46, 94.13, 2063.63), "Criminal Base")
    end
})

LocationsTab:Button({
    Title = "📍 Prison Interior",
    Desc = "Teleport to Prison interior cells",
    Callback = function()
        teleportToLocation(CFrame.new(918.77, 100, 2379.07), "Prison Interior")
    end
})

LocationsTab:Button({
    Title = "📍 Prison Yard",
    Desc = "Teleport to Prison outdoor yard",
    Callback = function()
        teleportToLocation(CFrame.new(821.4232177734375, 97.99993133544922, 2479.514892578125), "Prison Yard")
    end
})

LocationsTab:Button({
    Title = "📍 Guards Armory",
    Desc = "Teleport to Guards spawn area",
    Callback = function()
        teleportToLocation(CFrame.new(829.2570190429688, 99.9766616821289, 2242.1328125), "Guards Armory")
    end
})

--========================================================--
-- 7. SETTINGS (NOTIFICATIONS & UNLOAD)
--========================================================--

SettingsTab:Section({
    Title = "Killfeed"
})

SettingsTab:Toggle({
    Title = "Killfeed Notifications",
    Desc = "Shows on-screen killfeed notifications",
    Value = false,
    Callback = function(State)
        KillfeedNotify = State
    end
})

SettingsTab:Section({
    Title = "Nightfall Control"
})

SettingsTab:Toggle({
    Title = "Atmospheric Smoke",
    Desc = "Subtle violet smoke around the window",
    Icon = "moon",
    Value = true,
    Callback = function(state)
        Window:SetSmoke(state)
    end
})

SettingsTab:Dropdown({
    Title = "Interface Size",
    Desc = "Apply a preset without continuous resizing",
    Values = { "Compact", "Comfort", "Large" },
    Value = "Comfort",
    Callback = function(value)
        local scales = { Compact = 0.67, Comfort = 0.78, Large = 1 }
        Window:SetScale(scales[value])
    end
})

SettingsTab:Button({
    Title = "Center Window",
    Icon = "move",
    Callback = function()
        Window:Center()
    end
})


--========================================================--
-- CONFIG MANAGER (PRESETS & SAVE/LOAD)
--========================================================--

local ConfigPresets = {
    Default = {
        DefaultSpeed = 16,
        JumpPower = 50,
        AutoSprint = false,
        AntiJump = true,
        InfJump = false,
        Bhop = false,
        BhopAuto = false,
        BhopHopHeight = 50,
        BhopSpeedBoost = 10,
        BhopAccelerate = false,
        BhopPreserveMomentum = true,
        Noclip = false,
        QuickRespawn = false,
        ReturnOnDeath = false,
        Gravity = 196.2,
        Hitbox = false,
        Spinbot = false,
        SpinSpeed = 30,
        SpinMode = "Spin",
        AntiFling = false,
        ESP = false,
        TeamColors = true,
        Highlight = false,
        Fullbright = false,
        RapidFire = false,
        FireRate = 0.05,
    },
    Legit = {
        DefaultSpeed = 22,
        JumpPower = 50,
        AutoSprint = true,
        AntiJump = true,
        InfJump = false,
        Bhop = true,
        BhopAuto = false,
        BhopHopHeight = 50,
        BhopSpeedBoost = 10,
        BhopAccelerate = false,
        BhopPreserveMomentum = true,
        Noclip = false,
        QuickRespawn = false,
        ReturnOnDeath = false,
        Gravity = 196.2,
        Hitbox = false,
        Spinbot = false,
        SpinSpeed = 30,
        SpinMode = "Spin",
        AntiFling = true,
        ESP = true,
        TeamColors = true,
        Highlight = true,
        Fullbright = false,
        RapidFire = false,
        FireRate = 0.05,
    },
    Rage = {
        DefaultSpeed = 65,
        JumpPower = 85,
        AutoSprint = true,
        AntiJump = true,
        InfJump = true,
        Bhop = true,
        BhopAuto = true,
        BhopHopHeight = 55,
        BhopSpeedBoost = 22,
        BhopAccelerate = true,
        BhopPreserveMomentum = true,
        Noclip = false,
        QuickRespawn = true,
        ReturnOnDeath = false,
        Gravity = 175,
        Hitbox = true,
        Spinbot = true,
        SpinSpeed = 65,
        SpinMode = "Jitter",
        AntiFling = true,
        ESP = true,
        TeamColors = true,
        Highlight = true,
        Fullbright = true,
        RapidFire = true,
        FireRate = 0.01,
    }
}

local function applyConfig(cfg, name)
    if not cfg then return end
    for k, v in pairs(cfg) do
        Settings[k] = v
    end

    local Character, Humanoid = getCharacter()
    if Humanoid then
        Humanoid.WalkSpeed = Settings.DefaultSpeed or 16
        if Humanoid.UseJumpPower then
            Humanoid.JumpPower = Settings.JumpPower or 50
        else
            Humanoid.JumpHeight = ((Settings.JumpPower or 50) / 50) * 7.2
        end
    end
    workspace.Gravity = Settings.Gravity or 196.2

    task.spawn(function()
        updateFullbright()
        updateJump()
        updateSprint()
        updateESP()
        updateHitboxes()
        updateSpinbot()
        updateAntiFling()
        updateNoclip()
        updateRapidFire()
    end)

    if UI and UI.Notify then
        UI:Notify({
            Title = "Config Manager",
            Content = "Applied '" .. tostring(name or "Selected") .. "' config preset!",
            Duration = 2.5,
            Type = "success"
        })
    end
end

local function saveCustomConfig()
    local HttpService = game:GetService("HttpService")
    local saveTable = {}
    for k, v in pairs(Settings) do
        if type(v) == "boolean" or type(v) == "number" or type(v) == "string" then
            saveTable[k] = v
        end
    end

    local jsonStr = HttpService:JSONEncode(saveTable)
    local savedToFile = false

    if typeof(writefile) == "function" then
        local ok = pcall(function()
            writefile("NightFall_Config.json", jsonStr)
        end)
        if ok then savedToFile = true end
    end

    if getgenv then
        getgenv().NightFall_CustomConfig = saveTable
    end

    if UI and UI.Notify then
        UI:Notify({
            Title = "Config Manager",
            Content = savedToFile and "Config saved to NightFall_Config.json!" or "Config saved to memory session!",
            Duration = 3,
            Type = "success"
        })
    end
end

local function loadCustomConfig()
    local HttpService = game:GetService("HttpService")
    local loadedTable = nil

    if typeof(readfile) == "function" and typeof(isfile) == "function" and isfile("NightFall_Config.json") then
        local ok, data = pcall(function()
            return readfile("NightFall_Config.json")
        end)
        if ok and data and data ~= "" then
            pcall(function()
                loadedTable = HttpService:JSONDecode(data)
            end)
        end
    end

    if not loadedTable and getgenv and getgenv().NightFall_CustomConfig then
        loadedTable = getgenv().NightFall_CustomConfig
    end

    if loadedTable then
        applyConfig(loadedTable, "Custom")
    else
        if UI and UI.Notify then
            UI:Notify({
                Title = "Config Manager",
                Content = "No saved custom config file found!",
                Duration = 2.5,
                Type = "warn"
            })
        end
    end
end

ConfigsTab:Section({
    Title = "Preset Configurations"
})

ConfigsTab:Button({
    Title = "Default Config",
    Desc = "Reset to clean default settings",
    ButtonText = "Load Default",
    Icon = "settings",
    Callback = function()
        applyConfig(ConfigPresets.Default, "Default")
    end
})

ConfigsTab:Button({
    Title = "Legit Config",
    Desc = "Subtle assists: ESP, AutoSprint, smooth Bhop, Anti-Fling",
    ButtonText = "Load Legit",
    Icon = "shield",
    Callback = function()
        applyConfig(ConfigPresets.Legit, "Legit")
    end
})

ConfigsTab:Button({
    Title = "Rage Config",
    Desc = "Aggressive HVH: Hitbox, Rapid Fire, Spinbot, Speed 65",
    ButtonText = "Load Rage",
    Icon = "target",
    Callback = function()
        applyConfig(ConfigPresets.Rage, "Rage")
    end
})

ConfigsTab:Section({
    Title = "Custom Configurations"
})

ConfigsTab:Button({
    Title = "Save Custom Config",
    Desc = "Save your current settings to NightFall_Config.json",
    ButtonText = "Save Config",
    Icon = "package",
    Callback = saveCustomConfig
})

ConfigsTab:Button({
    Title = "Load Custom Config",
    Desc = "Load your saved settings from file",
    ButtonText = "Load Config",
    Icon = "home",
    Callback = loadCustomConfig
})

SettingsTab:Section({
    Title = "Script Management"
})

SettingsTab:Button({
    Title = "Unload Nightfall",
    Desc = "Safely disables all features and unloads script",
    ButtonText = "Unload",
    Icon = "trash",
    Callback = function()
        Settings.ESP = false
        Settings.Hitbox = false
        Settings.RapidFire = false
        Settings.AntiJump = false
        Settings.InfJump = false
        if InfJumpState then
            InfJumpState.SpaceHeld = false
        end
        Settings.AutoSprint = false
        Settings.QuickRespawn = false
        Settings.ReturnOnDeath = false
        Settings.Noclip = false
        Settings.Gravity = 196.2
        workspace.Gravity = 196.2
        Settings.JumpPower = 50
        Settings.DefaultSpeed = 16
        local unloadChar = LocalPlayer.Character
        local unloadHum = unloadChar and unloadChar:FindFirstChildOfClass("Humanoid")
        if unloadHum then
            unloadHum.WalkSpeed = 16
            if unloadHum.UseJumpPower then
                unloadHum.JumpPower = 50
            else
                unloadHum.JumpHeight = 7.2
            end
        end

        pcall(function()
            if Noclip and Noclip.Set then
                Noclip.Set(false)
            end
        end)

        pcall(function()
            if QuickRespawn and QuickRespawn.Set then
                QuickRespawn.Set(false)
            end
        end)
        pcall(function()
            if ReturnOnDeath and ReturnOnDeath.Set then
                ReturnOnDeath.Set(false)
            end
        end)

        if Settings.Underground then
            setUnderground(false)
        end

        pcall(function()
            FEInvisible.Set(false)
        end)

        pcall(function()
            if TaseBypass then
                TaseBypass.Set(false)
            end
        end)

        pcall(function()
            AutoCriminal.Set(false)
        end)

        pcall(function()
            DamageNumbers.Set(false)
        end)

        pcall(function()
            CustomWeapon.Set(false)
        end)

        disableFullbright()

        pcall(function()
            local StarterScripts = game:GetService("StarterPlayer"):FindFirstChild("StarterCharacterScripts")
            if StarterScripts then
                local AntiJump = StarterScripts:FindFirstChild("AntiJump")
                if AntiJump then
                    AntiJump.Disabled = false
                end
            end
            local char = LocalPlayer.Character
            if char then
                local activeAJ = char:FindFirstChild("AntiJump")
                if activeAJ then
                    activeAJ.Disabled = false
                end
            end
        end)

        for Player in pairs(ESPObjects) do
            removeESP(Player)
        end

        for Player in pairs(HitboxObjects) do
            removeHitbox(Player)
        end

        if TrackerGui then
            TrackerGui:Destroy()
        end

        if CharacterTrackConnection then
            CharacterTrackConnection:Disconnect()
            CharacterTrackConnection = nil
        end

        if DeathConnection then
            DeathConnection:Disconnect()
            DeathConnection = nil
        end

        if UndergroundConnection then
            UndergroundConnection:Disconnect()
            UndergroundConnection = nil
        end

        UndergroundSavedCFrame = nil

        Settings.Spinbot = false
        pcall(function()
            local char = LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum then
                hum.AutoRotate = true
            end
        end)

        for _, Player in ipairs(Players:GetPlayers()) do
            cleanupPlayer(Player)
        end

        Settings.Bhop = false

        print("[Nightfall] All functions unloaded.")
    end
})

DashboardTab:Select()

--========================================================--
-- INITIALIZATION
--========================================================--

task.spawn(function()

    task.wait(1)

    updateFullbright()
    updateJump()
    updateSprint()

    if Settings.ESP then
        updateESP()
    end

    if Settings.Hitbox then
        updateHitboxes()
    end

end)

print("[Nightfall] Loaded.")