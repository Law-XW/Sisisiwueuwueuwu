local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local window = library:CreateWindow({
    Title = "Xeioa",
    Footer = "Xeioa",
    Icon = 95816097006870,
    NotifySide = "Right",
    ShowCustomCursor = true,
})

local toggles = library.Toggles
local options = library.Options

local tabs = {
    combat   = window:AddTab("Combat",   "crosshair"),
    visuals  = window:AddTab("Visuals",  "eye"),
    skins    = window:AddTab("Skins",    "swords"),
    settings = window:AddTab("Settings", "settings"),
}

-- Groupboxen
local combatbox = tabs.combat:AddLeftGroupbox("combat",   "crosshair")
local espbox    = tabs.visuals:AddLeftGroupbox("esp",     "eye")
local miscbox   = tabs.visuals:AddRightGroupbox("misc",   "sparkles")
local skinbox   = tabs.skins:AddLeftGroupbox("skins",     "swords")
local uibox     = tabs.settings:AddLeftGroupbox("ui",     "settings")
local chbox     = tabs.settings:AddRightGroupbox("crosshair", "crosshair")
local fpsbox    = tabs.settings:AddLeftGroupbox("fps",    "activity")

local replicatedstorage = game:GetService("ReplicatedStorage")
local runservice        = game:GetService("RunService")
local tweenservice      = game:GetService("TweenService")
local cas               = game:GetService("ContextActionService")
local players           = game:GetService("Players")
local workspace_svc     = game:GetService("Workspace")
local inputservice      = game:GetService("UserInputService")
local plr  = players.LocalPlayer
local cam  = workspace_svc.CurrentCamera
local charfolder = workspace_svc:WaitForChild("Characters", 10)

local function get_t()  return charfolder:FindFirstChild("Terrorists") end
local function get_ct() return charfolder:FindFirstChild("Counter-Terrorists") end
local function is_alive()
    local t, ct = get_t(), get_ct()
    return (t and t:FindFirstChild(plr.Name)) or (ct and ct:FindFirstChild(plr.Name))
end
local function get_enemy()
    if not is_alive() then return end
    local t, ct = get_t(), get_ct()
    if t and t:FindFirstChild(plr.Name) then return ct end
    if ct and ct:FindFirstChild(plr.Name) then return t end
end

-- ─── AIMBOT ──────────────────────────────────────────────────────────────────
local aim_enabled = false
local fov_enabled = false
local fov_radius  = 100
local smoothing   = 3
local aim_key     = Enum.UserInputType.MouseButton2
local is_aiming   = false
local is_mobile   = inputservice.TouchEnabled and not inputservice.KeyboardEnabled

local fov_circle = Drawing.new("Circle")
fov_circle.Thickness = 1
fov_circle.Filled    = false
fov_circle.Visible   = false
fov_circle.Color     = Color3.new(1, 1, 1)

local function get_screen_center()
    return Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
end

local function get_target()
    local res, dist = nil, fov_radius
    local e = get_enemy()
    if not e or not aim_enabled then return end
    local aim_pos = is_mobile and get_screen_center() or inputservice:GetMouseLocation()
    for _, v in ipairs(e:GetChildren()) do
        local h, hd = v:FindFirstChildOfClass("Humanoid"), v:FindFirstChild("Head")
        if h and h.Health > 0 and hd then
            local p, vis = cam:WorldToViewportPoint(hd.Position)
            if vis then
                local d = (Vector2.new(p.X, p.Y) - aim_pos).Magnitude
                if d < dist then dist = d; res = hd end
            end
        end
    end
    return res
end

if not is_mobile then
    inputservice.InputBegan:Connect(function(i) if i.UserInputType == aim_key then is_aiming = true  end end)
    inputservice.InputEnded:Connect(function(i)  if i.UserInputType == aim_key then is_aiming = false end end)
else
    local aim_touch_id = nil
    inputservice.TouchStarted:Connect(function(touch, gp)
        if gp then return end
        if aim_touch_id == nil then aim_touch_id = touch.Position; is_aiming = true end
    end)
    inputservice.TouchEnded:Connect(function(touch, gp)
        if gp then return end
        is_aiming = false; aim_touch_id = nil
    end)
end

runservice.RenderStepped:Connect(function()
    local center = get_screen_center()
    if fov_enabled then
        fov_circle.Position = center
        fov_circle.Radius   = fov_radius
        fov_circle.Visible  = true
    else
        fov_circle.Visible = false
    end
    if not is_aiming or not is_alive() or not aim_enabled then return end
    local target = get_target()
    if target then
        local p_pos = cam:WorldToViewportPoint(target.Position)
        if is_mobile then
            local vp  = cam.ViewportSize
            local new_x = math.clamp(p_pos.X, 0, vp.X)
            local new_y = math.clamp(p_pos.Y, 0, vp.Y)
            local ray   = cam:ViewportPointToRay(new_x, new_y)
            cam.CFrame  = CFrame.lookAt(cam.CFrame.Position, cam.CFrame.Position + ray.Direction)
        else
            local m_pos = inputservice:GetMouseLocation()
            if mousemoverel then
                mousemoverel((p_pos.X - m_pos.X) / smoothing, (p_pos.Y - m_pos.Y) / smoothing)
            end
        end
    end
end)

combatbox:AddToggle('aim',   { Text = 'aim',    Default = false }):OnChanged(function() aim_enabled = toggles.aim.Value   end)
combatbox:AddToggle('fov',   { Text = 'fov',    Default = false }):OnChanged(function() fov_enabled = toggles.fov.Value   end)
combatbox:AddSlider('fov_r', { Text = 'fov r',  Default = 100, Min = 10, Max = 500, Rounding = 0 }):OnChanged(function() fov_radius = options.fov_r.Value end)
combatbox:AddSlider('smth',  { Text = 'smooth', Default = 3,   Min = 1,  Max = 10,  Rounding = 0 }):OnChanged(function() smoothing  = options.smth.Value  end)

-- ─── TRIGGERBOT ──────────────────────────────────────────────────────────────
local trigger_enabled, trigger_delay = false, 0
combatbox:AddToggle('trig',  { Text = 'triggerbot', Default = false }):OnChanged(function() trigger_enabled = toggles.trig.Value  end)
combatbox:AddSlider('trig_d',{ Text = 'delay (ms)', Default = 0, Min = 0, Max = 500, Rounding = 0 }):OnChanged(function() trigger_delay = options.trig_d.Value end)

task.spawn(function()
    while task.wait(0.01) do
        if trigger_enabled and is_alive() then
            local r = cam:ViewportPointToRay(cam.ViewportSize.X/2, cam.ViewportSize.Y/2)
            local params = RaycastParams.new()
            params.FilterType = Enum.RaycastFilterType.Exclude
            local ign = {cam}
            if plr.Character then table.insert(ign, plr.Character) end
            params.FilterDescendantsInstances = ign
            local res = workspace_svc:Raycast(r.Origin, r.Direction * 1000, params)
            if res and res.Instance then
                local m = res.Instance:FindFirstAncestorOfClass("Model")
                if m and m:FindFirstChildOfClass("Humanoid") then
                    local e = get_enemy()
                    if e and m.Parent == e and m:FindFirstChildOfClass("Humanoid").Health > 0 then
                        if trigger_delay > 0 then task.wait(trigger_delay / 1000) end
                        if mouse1click then mouse1click() end
                        task.wait(0.05)
                    end
                end
            end
        end
    end
end)

-- ─── HITBOX ──────────────────────────────────────────────────────────────────
local hitbox_enabled, hitbox_size, hb_originals = false, 3, {}
combatbox:AddToggle('hb',  { Text = 'hitbox',   Default = false }):OnChanged(function() hitbox_enabled = toggles.hb.Value  end)
combatbox:AddSlider('hb_s',{ Text = 'hitbox sz',Default = 3, Min = 1, Max = 3, Rounding = 1 }):OnChanged(function() hitbox_size = options.hb_s.Value end)

task.spawn(function()
    while task.wait(0.5) do
        local e = get_enemy()
        if e then
            for _, v in ipairs(e:GetChildren()) do
                local hd, h = v:FindFirstChild("Head"), v:FindFirstChildOfClass("Humanoid")
                if hd and h and h.Health > 0 then
                    if not hb_originals[hd] then hb_originals[hd] = hd.Size end
                    if hitbox_enabled then
                        hd.Size = Vector3.new(hitbox_size, hitbox_size, hitbox_size)
                        hd.CanCollide = false
                        hd.Transparency = 0.5
                    else
                        if hb_originals[hd] then hd.Size = hb_originals[hd]; hd.Transparency = 0 end
                    end
                end
            end
        end
    end
end)

-- ─── BHOP ────────────────────────────────────────────────────────────────────
local bhop_enabled = false
combatbox:AddToggle('bhop', { Text = 'bhop', Default = false }):OnChanged(function() bhop_enabled = toggles.bhop.Value end)
runservice.RenderStepped:Connect(function()
    if bhop_enabled and inputservice:IsKeyDown(Enum.KeyCode.Space) and is_alive() and plr.Character then
        local h = plr.Character:FindFirstChildOfClass("Humanoid")
        if h and h:GetState() ~= Enum.HumanoidStateType.Jumping and h:GetState() ~= Enum.HumanoidStateType.Freefall then
            h.Jump = true
        end
    end
end)

-- ─── NO RECOIL ───────────────────────────────────────────────────────────────
local norecoil_enabled = false
combatbox:AddToggle('nr', { Text = 'no recoil', Default = false }):OnChanged(function() norecoil_enabled = toggles.nr.Value end)

task.spawn(function()
    while task.wait(0.5) do
        if norecoil_enabled then
            pcall(function()
                local char = plr.Character
                if char then
                    for _, tool in pairs(char:GetChildren()) do
                        if tool:IsA("Tool") then
                            local recoil = tool:FindFirstChild("Recoil") or tool:FindFirstChild("RecoilControl")
                            if recoil and recoil:IsA("NumberValue") then recoil.Value = 0 end
                        end
                    end
                end
            end)
        end
    end
end)

-- ─── WALLBANG ────────────────────────────────────────────────────────────────
local wallbang_enabled = false
local wallbang_keywords = {
    "cube","wall","box","crate","fence","container","concrete",
    "cube.001","ship","invisible","plane.002","plane.003",
    "ceiling.006","acprop","cylinder.008","doorarchway.001",
    "door3_low","cylinder.006"
}

combatbox:AddToggle('wb', { Text = 'wallbang', Default = false }):OnChanged(function()
    wallbang_enabled = toggles.wb.Value
    for _, v in ipairs(workspace_svc:GetDescendants()) do
        if v:IsA("BasePart") then
            local name = string.lower(v.Name)
            for _, kw in ipairs(wallbang_keywords) do
                if string.find(name, kw, 1, true) then
                    v.CanCollide = not wallbang_enabled
                    if wallbang_enabled then v.CastShadow = false end
                    break
                end
            end
        end
    end
end)

combatbox:AddButton('wallbang_destroy', function()
    for _, v in ipairs(workspace_svc:GetDescendants()) do
        local name = string.lower(v.Name)
        for _, kw in ipairs(wallbang_keywords) do
            if string.find(name, kw, 1, true) then v:Destroy(); break end
        end
    end
end)

-- ─── KNIFE VM ────────────────────────────────────────────────────────────────
local knife_enabled, knife_selected, spawned, inspecting, swinging, last_atk = false, "Butterfly Knife", false, false, false, 0
local knife_data = {
    ["Karambit"]      = { Offset = CFrame.new(0, -1.5, 1.5)  },
    ["Butterfly Knife"]={ Offset = CFrame.new(0, -1.5, 1.5)  },
    ["M9 Bayonet"]    = { Offset = CFrame.new(0, -1.5, 1)    },
    ["Flip Knife"]    = { Offset = CFrame.new(0, -1.5, 1.25) },
    ["Gut Knife"]     = { Offset = CFrame.new(0, -1.5, 0.5)  },
}
local knife_vm, animator, equip_anim, idle_anim, inspect_anim, heavy_anim, s1_anim, s2_anim

local function get_knife() return cam:FindFirstChild("T Knife") or cam:FindFirstChild("CT Knife") end
local function clean_part(part)
    if not part:IsA("BasePart") then return end
    part.CanCollide, part.Anchored, part.CastShadow, part.CanTouch, part.CanQuery = false, false, false, false, false
end
local function play_sound(f, n)
    local sound_folder = replicatedstorage.Sounds:FindFirstChild(knife_selected)
    if not sound_folder then return end
    local sound = sound_folder:WaitForChild(f):WaitForChild(n):Clone()
    sound.Parent = cam; sound:Play()
    sound.Ended:Once(function() sound:Destroy() end)
    return sound
end
local function attach_asset(f, arm, model, n, o)
    local target_arm = knife_vm:FindFirstChild(arm)
    if not target_arm then return end
    local asset = f:WaitForChild(model):Clone()
    clean_part(asset)
    asset.Name, asset.Parent = n, target_arm
    local motor = Instance.new("Motor6D")
    motor.Part0, motor.Part1, motor.C0, motor.Parent = target_arm, asset, o, target_arm
end
local function handle_action(name, state, _object)
    if state ~= Enum.UserInputState.Begin or not spawned or not animator or not is_alive() then return Enum.ContextActionResult.Pass end
    if name == "ins" then
        if (equip_anim and equip_anim.IsPlaying) or inspecting or swinging then return Enum.ContextActionResult.Pass end
        inspecting = true
        if idle_anim then idle_anim:Stop() end
        inspect_anim:Play()
        inspect_anim.Stopped:Once(function() inspecting = false end)
    elseif name == "atk" then
        local now = os.clock()
        if (equip_anim and equip_anim.IsPlaying) or (now - last_atk < 1) then return Enum.ContextActionResult.Pass end
        last_atk = now
        if inspecting then inspecting = false; if inspect_anim then inspect_anim:Stop() end end
        swinging = true
        if idle_anim then idle_anim:Stop() end
        local anims  = { heavy_anim, s1_anim, s2_anim }
        local chosen = anims[math.random(1, #anims)]
        local folder = (chosen == heavy_anim and "HitOne") or (chosen == s1_anim and "HitTwo") or "HitThree"
        chosen:Play()
        local s = play_sound(folder, "1")
        if s then s.Volume = 5 end
        chosen.Stopped:Once(function() swinging = false end)
    end
    return Enum.ContextActionResult.Pass
end
local function remove_vm()
    spawned = false
    cas:UnbindAction("ins"); cas:UnbindAction("atk")
    if knife_vm then knife_vm:Destroy(); knife_vm = nil end
    animator, inspecting, swinging = nil, false, false
end
local function spawn_vm(k)
    if spawned or not knife_enabled or not is_alive() then return end
    spawned = true
    local knife_template = replicatedstorage.Assets.Weapons:WaitForChild(knife_selected)
    local knife_offset   = knife_data[knife_selected].Offset
    knife_vm = knife_template:WaitForChild("Camera"):Clone()
    knife_vm.Name, knife_vm.Parent = knife_selected, cam
    for _, part in knife_vm:GetDescendants() do clean_part(part) end
    for _, part in k:GetDescendants() do if part:IsA("BasePart") or part:IsA("Texture") then part.Transparency = 1 end end
    if plr.Character.Parent.Name == "Terrorists" then
        local gloves = replicatedstorage.Assets.Weapons:WaitForChild("T Glove")
        attach_asset(gloves, "Left Arm",  "Left Arm",  "Glove", CFrame.new(0, 0, -1.5))
        attach_asset(gloves, "Right Arm", "Right Arm", "Glove", CFrame.new(0, 0, -1.5))
    else
        local sleeves = replicatedstorage.Assets.Sleeves:WaitForChild("IDF")
        local gloves  = replicatedstorage.Assets.Weapons:WaitForChild("CT Glove")
        attach_asset(sleeves, "Left Arm",  "Left Arm",  "Sleeve", CFrame.new(0, 0, 0.5))
        attach_asset(gloves,  "Left Arm",  "Left Arm",  "Glove",  CFrame.new(0, 0, -1.5))
        attach_asset(sleeves, "Right Arm", "Right Arm", "Sleeve", CFrame.new(0, 0, 0.5))
        attach_asset(gloves,  "Right Arm", "Right Arm", "Glove",  CFrame.new(0, 0, -1.5))
    end
    local controller = knife_vm:FindFirstChildOfClass("AnimationController") or knife_vm:FindFirstChildOfClass("Animator")
    animator = controller:FindFirstChildWhichIsA("Animator") or controller
    local anim_folder = replicatedstorage.Assets.WeaponAnimations:WaitForChild(knife_selected):WaitForChild("CameraAnimations")
    equip_anim   = animator:LoadAnimation(anim_folder:WaitForChild("Equip"))
    idle_anim    = animator:LoadAnimation(anim_folder:WaitForChild("Idle"))
    inspect_anim = animator:LoadAnimation(anim_folder:WaitForChild("Inspect"))
    heavy_anim   = animator:LoadAnimation(anim_folder:WaitForChild("Heavy Swing"))
    s1_anim      = animator:LoadAnimation(anim_folder:WaitForChild("Swing1"))
    s2_anim      = animator:LoadAnimation(anim_folder:WaitForChild("Swing2"))
    knife_vm:SetPrimaryPartCFrame(cam.CFrame * CFrame.new(0, -1.5, 5))
    tweenservice:Create(knife_vm.PrimaryPart, TweenInfo.new(0.2), { CFrame = cam.CFrame * knife_offset }):Play()
    equip_anim:Play()
    play_sound("Equip", "1")
    cas:BindAction("ins", handle_action, false, Enum.KeyCode.F)
    cas:BindAction("atk", handle_action, false, Enum.UserInputType.MouseButton1)
end

runservice.RenderStepped:Connect(function()
    if not knife_enabled or not knife_vm or not knife_vm.PrimaryPart then return end
    knife_vm.PrimaryPart.CFrame = cam.CFrame * knife_data[knife_selected].Offset
    if not (equip_anim and equip_anim.IsPlaying) and not inspecting and not swinging then
        if idle_anim and not idle_anim.IsPlaying then idle_anim:Play() end
    end
end)

task.spawn(function()
    while task.wait(0.1) do
        local alive_state   = is_alive()
        local current_knife = get_knife()
        if knife_enabled and alive_state and current_knife and not spawned then
            spawn_vm(current_knife)
        elseif (not knife_enabled or not current_knife or not alive_state) and spawned then
            remove_vm()
        end
    end
end)

-- ─── SKINS ───────────────────────────────────────────────────────────────────
local skins_enabled, selected_skins, skin_drops, skin_options = false, {}, {}, {}
local ct_weapon_list     = { ["USP-S"]=1,["Five-SeveN"]=1,["MP9"]=1,["FAMAS"]=1,["M4A1-S"]=1,["M4A4"]=1,["AUG"]=1 }
local shared_weapon_list = { ["P250"]=1,["Desert Eagle"]=1,["Dual Berettas"]=1,["Negev"]=1,["P90"]=1,["Nova"]=1,["XM1014"]=1,["AWP"]=1,["SSG 08"]=1 }
local knife_list         = { ["Karambit"]=1,["Butterfly Knife"]=1,["M9 Bayonet"]=1,["Flip Knife"]=1,["Gut Knife"]=1,["T Knife"]=1,["CT Knife"]=1 }
local glove_list         = { ["Sports Gloves"]=1 }
local skins_folder       = replicatedstorage:WaitForChild("Assets"):WaitForChild("Skins")
local ignore_items       = { ["HE Grenade"]=1,["Incendiary Grenade"]=1,["Molotov"]=1,["Smoke Grenade"]=1,["Flashbang"]=1,["Decoy Grenade"]=1,["C4"]=1,["CT Glove"]=1,["T Glove"]=1 }

local function apply_skin_to_model(m)
    if not m or not skins_enabled or not is_alive() then return end
    local skin_name = selected_skins[m.Name]
    if not skin_name then return end
    pcall(function()
        local s_fd = skins_folder:FindFirstChild(m.Name)
        if not s_fd then return end
        local st     = s_fd:FindFirstChild(skin_name)
        local source = st and st:FindFirstChild("Camera") and st.Camera:FindFirstChild("Factory New")
        if not source then return end
        for _, o in cam:GetChildren() do
            local l, r = o:FindFirstChild("Left Arm"), o:FindFirstChild("Right Arm")
            if l or r then
                local gf   = skins_folder:FindFirstChild("Sports Gloves")
                local gs   = gf and gf:FindFirstChild(selected_skins["Sports Gloves"])
                local gsrc = gs and gs:FindFirstChild("Camera") and gs.Camera:FindFirstChild("Factory New")
                if gsrc then
                    for _, side in { "Left Arm", "Right Arm" } do
                        local arm, s2 = o:FindFirstChild(side), gsrc:FindFirstChild(side)
                        if arm and s2 then
                            local g = arm:FindFirstChild("Glove")
                            if g then
                                local ex = g:FindFirstChildOfClass("SurfaceAppearance")
                                if ex then ex:Destroy() end
                                s2:Clone().Parent = g
                                g:FindFirstChildOfClass("SurfaceAppearance").Name = "SurfaceAppearance"
                            end
                        end
                    end
                end
            end
        end
        if not glove_list[m.Name] then
            local weapon = m:FindFirstChild("Weapon")
            if weapon then
                for _, part in weapon:GetDescendants() do
                    if part:IsA("BasePart") then
                        local ns = source:FindFirstChild(part.Name)
                        if ns then
                            local ex = part:FindFirstChildOfClass("SurfaceAppearance")
                            if ex then ex:Destroy() end
                            ns:Clone().Parent = part
                            part:FindFirstChildOfClass("SurfaceAppearance").Name = "SurfaceAppearance"
                        end
                    end
                end
            end
        end
        m:SetAttribute("SkinApplied", skin_name)
    end)
end

skinbox:AddToggle('skin_on', { Text = 'skins', Default = false }):OnChanged(function()
    skins_enabled = toggles.skin_on.Value
    if not skins_enabled then for _, o in cam:GetChildren() do o:SetAttribute("SkinApplied", nil) end end
end)

skinbox:AddButton('rnd_skin', function()
    for w_n, o_l in pairs(skin_options) do
        if #o_l > 0 then
            local r_s = o_l[math.random(1, #o_l)]
            if skin_drops[w_n] then selected_skins[w_n] = r_s; options["Skin_"..w_n]:SetValue(r_s) end
        end
    end
end)

local function build_skin_dropdown(w_n)
    local f = skins_folder:FindFirstChild(w_n)
    if not f then return end
    local o = {}
    for _, s in f:GetChildren() do table.insert(o, s.Name) end
    skin_options[w_n] = o
    if not selected_skins[w_n] then selected_skins[w_n] = o[1] end
    local d = skinbox:AddDropdown("Skin_"..w_n, { Text = w_n, Values = o, Default = o[1] })
    d:OnChanged(function()
        selected_skins[w_n] = d.Value
        for _, obj in cam:GetChildren() do obj:SetAttribute("SkinApplied", nil); apply_skin_to_model(obj) end
    end)
    skin_drops[w_n] = d
end

skinbox:AddToggle('knf_on',  { Text = 'knife',  Default = false }):OnChanged(function()
    knife_enabled = toggles.knf_on.Value
    if not knife_enabled then remove_vm() end
end)
skinbox:AddDropdown('knf_sel', { Text = 'knives', Values = {"Butterfly Knife","Karambit","M9 Bayonet","Flip Knife","Gut Knife"}, Default = "Butterfly Knife" }):OnChanged(function()
    knife_selected = options.knf_sel.Value
    if spawned then remove_vm() end
end)

for n in pairs(knife_list)         do build_skin_dropdown(n) end
for n in pairs(glove_list)         do build_skin_dropdown(n) end
for n in pairs(ct_weapon_list)     do build_skin_dropdown(n) end
for n in pairs(shared_weapon_list) do build_skin_dropdown(n) end
for _, f in skins_folder:GetChildren() do
    if not ignore_items[f.Name] and not knife_list[f.Name] and not glove_list[f.Name]
       and not ct_weapon_list[f.Name] and not shared_weapon_list[f.Name] then
        build_skin_dropdown(f.Name)
    end
end

cam.ChildAdded:Connect(function(o)
    if not skins_enabled or not is_alive() then return end
    task.wait(0.1); apply_skin_to_model(o)
end)
task.spawn(function()
    while task.wait(0.5) do
        if skins_enabled and is_alive() then
            for _, o in cam:GetChildren() do
                if selected_skins[o.Name] and o:GetAttribute("SkinApplied") ~= selected_skins[o.Name] then
                    apply_skin_to_model(o)
                end
            end
        end
    end
end)

-- ─── ESP ─────────────────────────────────────────────────────────────────────
local ESP_ACCENT    = Color3.fromRGB(0, 200, 255)
local esp_enabled   = false
local show_box      = true
local show_name     = true
local show_hp       = true
local show_hptext   = true
local show_dist     = true
local show_snap     = false
local show_skeleton = false
local esp_cache     = {}

local function nl(thick, col)
    local l = Drawing.new("Line")
    l.Thickness = thick or 1; l.Color = col or Color3.new(1,1,1)
    l.Transparency = 1; l.Visible = false; return l
end
local function nt(sz, col, center)
    local t = Drawing.new("Text")
    t.Size = sz or 14; t.Color = col or Color3.new(1,1,1)
    t.Outline = true; t.Center = center ~= false; t.Visible = false; return t
end

local function ns(col, transp)
    local s = Drawing.new("Square")
    s.Filled = true; s.Color = col or Color3.new(0,0,0)
    s.Transparency = transp or 0.5; s.Visible = false; return s
end

local function create_esp_set()
    local blk = Color3.new(0,0,0)
    local e = {
        -- corner bracket box (shadow + color, 4 corners × 2 lines each)
        tl_h_s=nl(2,blk), tl_v_s=nl(2,blk), tr_h_s=nl(2,blk), tr_v_s=nl(2,blk),
        bl_h_s=nl(2,blk), bl_v_s=nl(2,blk), br_h_s=nl(2,blk), br_v_s=nl(2,blk),
        tl_h=nl(1.5), tl_v=nl(1.5), tr_h=nl(1.5), tr_v=nl(1.5),
        bl_h=nl(1.5), bl_v=nl(1.5), br_h=nl(1.5), br_v=nl(1.5),
        -- health bar (bg track + 3 gradient segments + text)
        hp_bg   = nl(4, Color3.fromRGB(10,10,10)),
        hp_bar1 = nl(2.5, Color3.fromRGB(0,230,80)),
        hp_bar2 = nl(2.5, Color3.fromRGB(255,220,50)),
        hp_bar3 = nl(2.5, Color3.fromRGB(255,55,55)),
        hp_txt  = nt(11, Color3.new(1,1,1), false),
        -- name tag (background pill + text)
        name_bg = ns(Color3.fromRGB(5,5,8), 0.35),
        name    = nt(13, Color3.new(1,1,1), true),
        -- distance label (background + text)
        dist_bg = ns(Color3.fromRGB(5,5,8), 0.45),
        dist    = nt(11, Color3.fromRGB(160,160,160), true),
        -- tracer / snapline
        snap_s = nl(2, blk),
        snap   = nl(1, ESP_ACCENT),
        -- skeleton (7 bones)
        sk = {}
    }
    for i = 1, 7 do
        e.sk[i] = nl(1, Color3.fromRGB(200,200,200))
        e.sk[i].Transparency = 0.55
    end
    return e
end

local function hp_gradient(p)
    p = math.clamp(p, 0, 1)
    if p > 0.5 then return Color3.new((1-p)*2, 1, 0)
    else return Color3.new(1, p*2, 0) end
end

local CK = {
    "tl_h","tl_v","tr_h","tr_v","bl_h","bl_v","br_h","br_v",
    "tl_h_s","tl_v_s","tr_h_s","tr_v_s","bl_h_s","bl_v_s","br_h_s","br_v_s",
}
local function draw_corners(e, bx, by, bw, bh, col)
    local cx, cy, o = bw*0.28, bh*0.22, 1
    e.tl_h_s.From=Vector2.new(bx-o,by-o);       e.tl_h_s.To=Vector2.new(bx+cx,by-o)
    e.tl_v_s.From=Vector2.new(bx-o,by-o);       e.tl_v_s.To=Vector2.new(bx-o,by+cy)
    e.tr_h_s.From=Vector2.new(bx+bw+o,by-o);    e.tr_h_s.To=Vector2.new(bx+bw-cx,by-o)
    e.tr_v_s.From=Vector2.new(bx+bw+o,by-o);    e.tr_v_s.To=Vector2.new(bx+bw+o,by+cy)
    e.bl_h_s.From=Vector2.new(bx-o,by+bh+o);    e.bl_h_s.To=Vector2.new(bx+cx,by+bh+o)
    e.bl_v_s.From=Vector2.new(bx-o,by+bh+o);    e.bl_v_s.To=Vector2.new(bx-o,by+bh-cy)
    e.br_h_s.From=Vector2.new(bx+bw+o,by+bh+o); e.br_h_s.To=Vector2.new(bx+bw-cx,by+bh+o)
    e.br_v_s.From=Vector2.new(bx+bw+o,by+bh+o); e.br_v_s.To=Vector2.new(bx+bw+o,by+bh-cy)
    e.tl_h.From=Vector2.new(bx,by);     e.tl_h.To=Vector2.new(bx+cx,by);     e.tl_h.Color=col
    e.tl_v.From=Vector2.new(bx,by);     e.tl_v.To=Vector2.new(bx,by+cy);     e.tl_v.Color=col
    e.tr_h.From=Vector2.new(bx+bw,by);  e.tr_h.To=Vector2.new(bx+bw-cx,by);  e.tr_h.Color=col
    e.tr_v.From=Vector2.new(bx+bw,by);  e.tr_v.To=Vector2.new(bx+bw,by+cy);  e.tr_v.Color=col
    e.bl_h.From=Vector2.new(bx,by+bh);  e.bl_h.To=Vector2.new(bx+cx,by+bh);  e.bl_h.Color=col
    e.bl_v.From=Vector2.new(bx,by+bh);  e.bl_v.To=Vector2.new(bx,by+bh-cy);  e.bl_v.Color=col
    e.br_h.From=Vector2.new(bx+bw,by+bh); e.br_h.To=Vector2.new(bx+bw-cx,by+bh); e.br_h.Color=col
    e.br_v.From=Vector2.new(bx+bw,by+bh); e.br_v.To=Vector2.new(bx+bw,by+bh-cy); e.br_v.Color=col
    for _,k in ipairs(CK) do e[k].Visible = true end
end
local function hide_corners(e) for _,k in ipairs(CK) do e[k].Visible = false end end

local function hide_all(e)
    for k,v in pairs(e) do
        if k=="sk" then for _,l in ipairs(v) do l.Visible=false end
        elseif type(v)=="userdata" then v.Visible=false end
    end
end
local function remove_esp(e)
    for k,v in pairs(e) do
        if k=="sk" then for _,l in ipairs(v) do l:Remove() end
        elseif type(v)=="userdata" then pcall(function() v:Remove() end) end
    end
end

runservice.RenderStepped:Connect(function()
    if not esp_enabled or not is_alive() then
        for _,e in pairs(esp_cache) do hide_all(e) end; return
    end
    local ef = get_enemy()
    if not ef then for _,e in pairs(esp_cache) do hide_all(e) end; return end
    local vp   = cam.ViewportSize
    local sbot = Vector2.new(vp.X/2, vp.Y)
    local alive_now = {}

    for _, v in ipairs(ef:GetChildren()) do
        local hum  = v:FindFirstChildOfClass("Humanoid")
        local root = v:FindFirstChild("HumanoidRootPart")
        local hd   = v:FindFirstChild("Head")
        if hum and hum.Health > 0 and root and hd then
            alive_now[v] = true
            if not esp_cache[v] then esp_cache[v] = create_esp_set() end
            local e = esp_cache[v]

            local rp,  vis = cam:WorldToViewportPoint(root.Position)
            local top_p    = cam:WorldToViewportPoint(hd.Position   + Vector3.new(0, 0.7, 0))
            local bot_p    = cam:WorldToViewportPoint(root.Position  - Vector3.new(0, 3.1, 0))

            if vis then
                local bh   = math.abs(top_p.Y - bot_p.Y)
                local bw   = bh * 0.55
                local bx   = rp.X - bw * 0.5
                local by   = top_p.Y
                local hpp  = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
                local hcol = hp_gradient(hpp)
                local dst  = math.floor((cam.CFrame.Position - root.Position).Magnitude)
                local bcol = (hpp < 0.3) and Color3.fromRGB(255,55,55) or ESP_ACCENT

                -- Box
                if show_box then draw_corners(e, bx, by, bw, bh, bcol) else hide_corners(e) end

                -- Health bar (3-segment gradient: green → yellow → red)
                if show_hp then
                    local hbx  = bx - 6
                    local hbot = by + bh
                    local hmid = hbot - bh * hpp
                    -- background track
                    e.hp_bg.From = Vector2.new(hbx, by-1); e.hp_bg.To = Vector2.new(hbx, hbot+1); e.hp_bg.Visible = true
                    -- green segment (top third of bar = high hp)
                    local seg_top    = math.max(hmid, hbot - bh * 1.0)
                    local seg_yellow = hbot - bh * 0.5
                    local seg_red    = hbot - bh * 0.25
                    if hpp > 0.5 then
                        e.hp_bar1.From = Vector2.new(hbx, seg_yellow); e.hp_bar1.To = Vector2.new(hbx, hmid);    e.hp_bar1.Visible = true
                        e.hp_bar2.From = Vector2.new(hbx, hbot);       e.hp_bar2.To = Vector2.new(hbx, seg_yellow); e.hp_bar2.Visible = true
                        e.hp_bar3.Visible = false
                    elseif hpp > 0.25 then
                        e.hp_bar1.Visible = false
                        e.hp_bar2.From = Vector2.new(hbx, seg_red); e.hp_bar2.To = Vector2.new(hbx, hmid);  e.hp_bar2.Visible = true
                        e.hp_bar3.From = Vector2.new(hbx, hbot);    e.hp_bar3.To = Vector2.new(hbx, seg_red); e.hp_bar3.Visible = true
                    else
                        e.hp_bar1.Visible = false; e.hp_bar2.Visible = false
                        e.hp_bar3.From = Vector2.new(hbx, hbot); e.hp_bar3.To = Vector2.new(hbx, hmid); e.hp_bar3.Visible = true
                    end
                    if show_hptext then
                        e.hp_txt.Text     = tostring(math.floor(hum.Health))
                        e.hp_txt.Position = Vector2.new(hbx - 4, hmid - 6)
                        e.hp_txt.Color    = hcol
                        e.hp_txt.Visible  = true
                    else
                        e.hp_txt.Visible = false
                    end
                else
                    e.hp_bg.Visible=false; e.hp_bar1.Visible=false; e.hp_bar2.Visible=false; e.hp_bar3.Visible=false; e.hp_txt.Visible=false
                end

                -- Name (with dark pill background)
                if show_name then
                    local npad = 4
                    local ntw  = #v.Name * 7
                    e.name_bg.Size     = Vector2.new(ntw + npad*2, 16)
                    e.name_bg.Position = Vector2.new(rp.X - ntw/2 - npad, by - 20)
                    e.name_bg.Visible  = true
                    e.name.Text = v.Name; e.name.Position = Vector2.new(rp.X, by - 20); e.name.Visible = true
                else
                    e.name_bg.Visible = false; e.name.Visible = false
                end

                -- Distance (with dark pill background)
                if show_dist then
                    local dtxt = dst .. "m"
                    local dtw  = #dtxt * 6
                    local dpad = 3
                    local dc   = dst<40 and Color3.fromRGB(255,220,60)
                             or dst<100 and Color3.fromRGB(200,200,200)
                             or Color3.fromRGB(130,130,130)
                    e.dist_bg.Size     = Vector2.new(dtw + dpad*2, 14)
                    e.dist_bg.Position = Vector2.new(rp.X - dtw/2 - dpad, by + bh + 3)
                    e.dist_bg.Visible  = true
                    e.dist.Text = dtxt; e.dist.Color = dc
                    e.dist.Position = Vector2.new(rp.X, by + bh + 4); e.dist.Visible = true
                else
                    e.dist_bg.Visible = false; e.dist.Visible = false
                end

                -- Tracer
                if show_snap then
                    local f2d = Vector2.new(bot_p.X, bot_p.Y)
                    e.snap_s.From = sbot+Vector2.new(1,1); e.snap_s.To = f2d+Vector2.new(1,1); e.snap_s.Visible=true
                    e.snap.From   = sbot;                  e.snap.To   = f2d
                    e.snap.Color  = bcol;                  e.snap.Visible = true
                else e.snap.Visible=false; e.snap_s.Visible=false end

                -- Skeleton
                if show_skeleton then
                    local function g2d(pn)
                        local p = v:FindFirstChild(pn); if not p then return nil end
                        local s2, sv = cam:WorldToViewportPoint(p.Position)
                        return sv and Vector2.new(s2.X, s2.Y) or nil
                    end
                    local tor = g2d("UpperTorso") or g2d("Torso")
                    local low = g2d("LowerTorso") or tor
                    local lsh = g2d("Left Upper Arm")  or g2d("Left Arm")
                    local rsh = g2d("Right Upper Arm") or g2d("Right Arm")
                    local lel = g2d("Left Lower Arm")  or lsh
                    local rel = g2d("Right Lower Arm") or rsh
                    local bones = {
                        {g2d("Head"), tor}, {tor, low},
                        {tor, lsh}, {tor, rsh},
                        {lsh, lel}, {rsh, rel},
                        {low, g2d("HumanoidRootPart")},
                    }
                    for i, bone in ipairs(bones) do
                        if bone[1] and bone[2] then
                            e.sk[i].From=bone[1]; e.sk[i].To=bone[2]; e.sk[i].Visible=true
                        elseif e.sk[i] then e.sk[i].Visible=false end
                    end
                else
                    for _,l in ipairs(e.sk) do l.Visible=false end
                end
            else
                hide_all(e)
            end
        end
    end

    for k, e in pairs(esp_cache) do
        if not alive_now[k] then remove_esp(e); esp_cache[k]=nil end
    end
end)

-- ESP Groupbox (Visuals tab, links)
espbox:AddToggle('esp',    { Text = 'esp',      Default = false }):OnChanged(function() esp_enabled   = toggles.esp.Value    end)
espbox:AddToggle('esp_b',  { Text = 'box',      Default = true  }):OnChanged(function() show_box      = toggles.esp_b.Value  end)
espbox:AddToggle('esp_h',  { Text = 'hp bar',   Default = true  }):OnChanged(function() show_hp       = toggles.esp_h.Value  end)
espbox:AddToggle('esp_ht', { Text = 'hp number',Default = true  }):OnChanged(function() show_hptext   = toggles.esp_ht.Value end)
espbox:AddToggle('esp_n',  { Text = 'name',     Default = true  }):OnChanged(function() show_name     = toggles.esp_n.Value  end)
espbox:AddToggle('esp_d',  { Text = 'distance', Default = true  }):OnChanged(function() show_dist     = toggles.esp_d.Value  end)
espbox:AddToggle('esp_sn', { Text = 'tracer',   Default = false }):OnChanged(function() show_snap     = toggles.esp_sn.Value end)
espbox:AddToggle('esp_sk', { Text = 'skeleton', Default = false }):OnChanged(function() show_skeleton = toggles.esp_sk.Value end)

-- ─── MISC VISUALS (rechte Groupbox im Visuals Tab) ───────────────────────────
local antiflash, antismoke = false, false
miscbox:AddToggle('af', { Text = 'no flash', Default = false }):OnChanged(function() antiflash = toggles.af.Value end)
miscbox:AddToggle('as', { Text = 'no smoke', Default = false }):OnChanged(function() antismoke = toggles.as.Value end)

task.spawn(function()
    while task.wait(0.2) do
        if antiflash then
            local gui    = plr.PlayerGui:FindFirstChild("FlashbangEffect")
            local effect = game:GetService("Lighting"):FindFirstChild("FlashbangColorCorrection")
            if gui then gui:Destroy() end
            if effect then effect:Destroy() end
        end
    end
end)

task.spawn(function()
    while task.wait(0.5) do
        if antismoke then
            local debris = workspace_svc:FindFirstChild("Debris")
            if debris then
                for _, folder in ipairs(debris:GetChildren()) do
                    if string.match(folder.Name, "Voxel") then folder:ClearAllChildren(); folder:Destroy() end
                end
            end
        end
    end
end)

-- Anti-Aim
local antiaim_enabled = false
local antiaim_mode = "Spin"
local antiaim_angle = 0
local antiaim_spin_speed = 10

miscbox:AddToggle('aa',     { Text = 'anti aim', Default = false }):OnChanged(function() antiaim_enabled = toggles.aa.Value end)
miscbox:AddDropdown('aa_mode', { Text = 'aa mode', Values = {"Spin","Jitter","Down","Up"}, Default = "Spin" }):OnChanged(function() antiaim_mode = options.aa_mode.Value end)
miscbox:AddSlider('aa_spd', { Text = 'spin speed', Default = 10, Min = 1, Max = 30, Rounding = 0 }):OnChanged(function() antiaim_spin_speed = options.aa_spd.Value end)

local aa_conn = nil
local function get_neck_joint()
    local char = plr.Character; if not char then return end
    local upper = char:FindFirstChild("UpperTorso")
    if upper then local n = upper:FindFirstChild("Neck"); if n then return n end end
    local head = char:FindFirstChild("Head")
    if head then local n = head:FindFirstChild("Neck"); if n then return n end end
end
local function start_antiaim()
    if aa_conn then aa_conn:Disconnect(); aa_conn = nil end
    aa_conn = runservice.Heartbeat:Connect(function()
        if not antiaim_enabled or not is_alive() or not plr.Character then return end
        local hrp        = plr.Character:FindFirstChild("HumanoidRootPart")
        local root_joint = hrp and hrp:FindFirstChild("RootJoint")
        if not root_joint then
            local lower = plr.Character:FindFirstChild("LowerTorso")
            root_joint  = lower and lower:FindFirstChild("Root")
        end
        if antiaim_mode == "Spin" then
            if not root_joint then return end
            antiaim_angle = (antiaim_angle + antiaim_spin_speed) % 360
            root_joint.C0 = CFrame.new(0, -1, 0) * CFrame.Angles(0, math.rad(antiaim_angle), 0)
        elseif antiaim_mode == "Jitter" then
            if not root_joint then return end
            root_joint.C0 = CFrame.new(0, -1, 0) * CFrame.Angles(0, math.rad(180), 0)
        elseif antiaim_mode == "Down" then
            local neck = get_neck_joint()
            if neck then neck.C0 = CFrame.new(0, 1, 0) * CFrame.Angles(math.rad(-89), 0, 0) end
        elseif antiaim_mode == "Up" then
            local neck = get_neck_joint()
            if neck then neck.C0 = CFrame.new(0, 1, 0) * CFrame.Angles(math.rad(89), 0, 0) end
        end
    end)
end
start_antiaim()

-- Third Person
local thirdperson_enabled = false
local tp_distance = 10
local current_fov = 70

local function set_char_visible(visible)
    local char = plr.Character; if not char then return end
    for _, part in pairs(char:GetDescendants()) do
        if part:IsA("BasePart") or part:IsA("Decal") then
            part.LocalTransparencyModifier = visible and 0 or 1
        end
    end
end
local function hide_viewmodel()
    for _, obj in pairs(cam:GetChildren()) do
        if obj:IsA("Model") then
            for _, part in pairs(obj:GetDescendants()) do
                if part:IsA("BasePart") or part:IsA("MeshPart") or part:IsA("SpecialMesh") then
                    part.LocalTransparencyModifier = 1
                end
            end
        end
    end
end
local function set_thirdperson(state)
    local char = plr.Character; if not char then return end
    local hum  = char:FindFirstChildOfClass("Humanoid")
    if state then
        if hum then hum.CameraOffset = Vector3.new(0, 2.5, tp_distance) end
        set_char_visible(true); cam.FieldOfView = 70
    else
        if hum then hum.CameraOffset = Vector3.new(0, 0, 0) end
        set_char_visible(false); cam.FieldOfView = current_fov
    end
end

runservice.RenderStepped:Connect(function()
    if thirdperson_enabled and plr.Character then set_char_visible(true); hide_viewmodel() end
end)

miscbox:AddToggle('tp', { Text = '3rd person', Default = false }):OnChanged(function()
    thirdperson_enabled = toggles.tp.Value
    set_thirdperson(thirdperson_enabled)
end)
miscbox:AddSlider('tp_dist', { Text = 'tp distance', Default = 10, Min = 3, Max = 30, Rounding = 0 }):OnChanged(function()
    tp_distance = options.tp_dist.Value
    if thirdperson_enabled and plr.Character then
        local hum = plr.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.CameraOffset = Vector3.new(0, 0, tp_distance) end
    end
end)

plr.CharacterAdded:Connect(function()
    task.wait(0.5)
    if thirdperson_enabled then set_thirdperson(true) end
end)

-- Stretched res
local stretch_enabled = false
local stretch_res = 0.80

miscbox:AddToggle('stretch', { Text = 'stretched', Default = false }):OnChanged(function()
    stretch_enabled = toggles.stretch.Value
    if not stretch_enabled then
        cam.CFrame = cam.CFrame * CFrame.new(0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1)
    end
end)
miscbox:AddSlider('stretch_r', { Text = 'stretch res', Default = 80, Min = 50, Max = 99, Rounding = 0 }):OnChanged(function()
    stretch_res = options.stretch_r.Value / 100
end)

runservice.RenderStepped:Connect(function()
    if stretch_enabled then
        cam.CFrame = cam.CFrame * CFrame.new(0, 0, 0, 1, 0, 0, 0, stretch_res, 0, 0, 0, 1)
    end
end)

-- Motion Blur
local motionblur_enabled = false
local blur_amount    = 15
local blur_amplifier = 5
local motion_blur_fx = nil
local last_look      = cam.CFrame.LookVector

miscbox:AddToggle('mb', { Text = 'motion blur', Default = false }):OnChanged(function()
    motionblur_enabled = toggles.mb.Value
    if not motionblur_enabled and motion_blur_fx then motion_blur_fx.Size = 0 end
end)
miscbox:AddSlider('mb_amt', { Text = 'blur amount', Default = 15, Min = 1, Max = 45, Rounding = 0 }):OnChanged(function()
    blur_amount = options.mb_amt.Value
end)
miscbox:AddSlider('mb_amp', { Text = 'blur amp',    Default = 5,  Min = 1, Max = 15, Rounding = 0 }):OnChanged(function()
    blur_amplifier = options.mb_amp.Value
end)

motion_blur_fx = Instance.new("BlurEffect")
motion_blur_fx.Size   = 0
motion_blur_fx.Parent = cam

workspace_svc.Changed:Connect(function(prop)
    if prop == "CurrentCamera" then
        local new_cam = workspace_svc.CurrentCamera
        if motion_blur_fx and motion_blur_fx.Parent then
            motion_blur_fx.Parent = new_cam
        else
            motion_blur_fx = Instance.new("BlurEffect")
            motion_blur_fx.Size   = 0
            motion_blur_fx.Parent = new_cam
        end
    end
end)

runservice.Heartbeat:Connect(function()
    if not motion_blur_fx or not motion_blur_fx.Parent then
        motion_blur_fx = Instance.new("BlurEffect")
        motion_blur_fx.Size   = 0
        motion_blur_fx.Parent = cam
    end
    if motionblur_enabled then
        local mag = (cam.CFrame.LookVector - last_look).Magnitude
        motion_blur_fx.Size = math.abs(mag) * blur_amount * blur_amplifier / 2
    else
        motion_blur_fx.Size = 0
    end
    last_look = cam.CFrame.LookVector
end)

-- ─── FPS COUNTER ─────────────────────────────────────────────────────────────
local fps_enabled  = true
local fps_position = "Top Left"
local fps_val      = 0
local fps_frames   = 0
local fps_timer    = 0

local fps_draw = Drawing.new("Text")
fps_draw.Size         = 15
fps_draw.Color        = Color3.fromRGB(0, 200, 255)
fps_draw.Outline      = true
fps_draw.OutlineColor = Color3.new(0, 0, 0)
fps_draw.Font         = Drawing.Fonts.Monospace
fps_draw.Visible      = false

local FPS_PADDING = 8
local function fps_anchor()
    local vp = cam.ViewportSize
    if fps_position == "Top Left"     then return Vector2.new(FPS_PADDING, FPS_PADDING) end
    if fps_position == "Top Right"    then fps_draw.Center = false; return Vector2.new(vp.X - 80, FPS_PADDING) end
    if fps_position == "Bottom Left"  then return Vector2.new(FPS_PADDING, vp.Y - 24) end
    if fps_position == "Bottom Right" then return Vector2.new(vp.X - 80, vp.Y - 24) end
    return Vector2.new(FPS_PADDING, FPS_PADDING)
end

runservice.RenderStepped:Connect(function(dt)
    fps_frames = fps_frames + 1
    fps_timer  = fps_timer  + dt
    if fps_timer >= 0.5 then
        fps_val    = math.floor(fps_frames / fps_timer)
        fps_frames = 0; fps_timer = 0
    end
    if fps_enabled then
        local col
        if fps_val >= 100 then col = Color3.fromRGB(0, 230, 80)
        elseif fps_val >= 60 then col = Color3.fromRGB(255, 220, 50)
        else col = Color3.fromRGB(255, 60, 60) end
        fps_draw.Text     = "FPS  " .. tostring(fps_val)
        fps_draw.Color    = col
        fps_draw.Position = fps_anchor()
        fps_draw.Visible  = true
    else
        fps_draw.Visible = false
    end
end)

fpsbox:AddToggle('fps_on', { Text = 'fps counter', Default = true }):OnChanged(function()
    fps_enabled = toggles.fps_on.Value
end)
fpsbox:AddDropdown('fps_pos', {
    Text    = 'position',
    Values  = {"Top Left", "Top Right", "Bottom Left", "Bottom Right"},
    Default = "Top Left",
}):OnChanged(function()
    fps_position = options.fps_pos.Value
end)

-- ─── WATERMARK (UIGradient, oben rechts) ─────────────────────────────────────
local wm_enabled = true

local wm_gui = Instance.new("ScreenGui")
wm_gui.Name           = "XeioaWatermark"
wm_gui.ResetOnSpawn   = false
wm_gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
wm_gui.Enabled        = true
wm_gui.Parent         = plr:WaitForChild("PlayerGui")

-- Outer frame (top-right, 10px margin)
local wm_frame = Instance.new("Frame")
wm_frame.Size                  = UDim2.new(0, 148, 0, 40)
wm_frame.Position              = UDim2.new(1, -158, 0, 10)
wm_frame.BackgroundColor3      = Color3.fromRGB(8, 8, 12)
wm_frame.BackgroundTransparency = 0
wm_frame.BorderSizePixel       = 0
wm_frame.Parent                = wm_gui

local wm_corner = Instance.new("UICorner")
wm_corner.CornerRadius = UDim.new(0, 7)
wm_corner.Parent       = wm_frame

-- Background gradient (dark → slightly lighter at top)
local wm_bg_grad = Instance.new("UIGradient")
wm_bg_grad.Color    = ColorSequence.new({
    ColorSequenceKeypoint.new(0,   Color3.fromRGB(20, 20, 30)),
    ColorSequenceKeypoint.new(1,   Color3.fromRGB(6,  6,  10)),
})
wm_bg_grad.Rotation = 90
wm_bg_grad.Parent   = wm_frame

-- Thin border glow using a stroke
local wm_stroke = Instance.new("UIStroke")
wm_stroke.Color       = Color3.fromRGB(0, 200, 255)
wm_stroke.Thickness   = 1
wm_stroke.Transparency = 0.72
wm_stroke.Parent      = wm_frame

-- Bottom accent bar (gradient cyan → purple → cyan)
local wm_bar = Instance.new("Frame")
wm_bar.Size                   = UDim2.new(1, -14, 0, 2)
wm_bar.Position               = UDim2.new(0, 7, 1, -3)
wm_bar.BackgroundColor3       = Color3.fromRGB(0, 200, 255)
wm_bar.BorderSizePixel        = 0
wm_bar.Parent                 = wm_frame

local wm_bar_corner = Instance.new("UICorner")
wm_bar_corner.CornerRadius = UDim.new(1, 0)
wm_bar_corner.Parent       = wm_bar

local wm_bar_grad = Instance.new("UIGradient")
wm_bar_grad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0,    Color3.fromRGB(0,   200, 255)),
    ColorSequenceKeypoint.new(0.5,  Color3.fromRGB(160,  60, 255)),
    ColorSequenceKeypoint.new(1,    Color3.fromRGB(0,   200, 255)),
})
wm_bar_grad.Parent = wm_bar

-- Title label "Xeioa"
local wm_title = Instance.new("TextLabel")
wm_title.Size                 = UDim2.new(1, -10, 0, 20)
wm_title.Position             = UDim2.new(0, 10, 0, 2)
wm_title.BackgroundTransparency = 1
wm_title.Text                 = "Xeioa"
wm_title.TextColor3           = Color3.new(1, 1, 1)
wm_title.Font                 = Enum.Font.GothamBold
wm_title.TextSize             = 14
wm_title.TextXAlignment       = Enum.TextXAlignment.Left
wm_title.Parent               = wm_frame

-- Gradient on title text (cyan glow)
local wm_title_grad = Instance.new("UIGradient")
wm_title_grad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0,   Color3.new(1, 1, 1)),
    ColorSequenceKeypoint.new(0.6, Color3.new(1, 1, 1)),
    ColorSequenceKeypoint.new(1,   Color3.fromRGB(0, 200, 255)),
})
wm_title_grad.Parent = wm_title

-- Sub label "fps | ping"
local wm_sub_label = Instance.new("TextLabel")
wm_sub_label.Size                 = UDim2.new(1, -10, 0, 16)
wm_sub_label.Position             = UDim2.new(0, 10, 0, 19)
wm_sub_label.BackgroundTransparency = 1
wm_sub_label.TextColor3           = Color3.fromRGB(100, 180, 220)
wm_sub_label.Font                 = Enum.Font.Code
wm_sub_label.TextSize             = 11
wm_sub_label.TextXAlignment       = Enum.TextXAlignment.Left
wm_sub_label.Parent               = wm_frame

-- Update sub label every frame
runservice.RenderStepped:Connect(function()
    if not wm_enabled then return end
    local ping = math.floor(players.LocalPlayer:GetNetworkPing() * 1000)
    wm_sub_label.Text = tostring(fps_val) .. " fps   " .. tostring(ping) .. " ms"
end)

uibox:AddToggle('wm_on', { Text = 'watermark', Default = true }):OnChanged(function()
    wm_enabled        = toggles.wm_on.Value
    wm_gui.Enabled    = wm_enabled
end)

-- ESP Farbe
uibox:AddDropdown('esp_col', {
    Text    = 'esp color',
    Values  = {"Cyan", "Green", "Purple", "Orange", "White", "Red"},
    Default = "Cyan",
}):OnChanged(function()
    local map = {
        Cyan   = Color3.fromRGB(0,200,255),
        Green  = Color3.fromRGB(0,230,80),
        Purple = Color3.fromRGB(180,80,255),
        Orange = Color3.fromRGB(255,150,30),
        White  = Color3.new(1,1,1),
        Red    = Color3.fromRGB(255,55,55),
    }
    ESP_ACCENT = map[options.esp_col.Value] or Color3.fromRGB(0,200,255)
end)

-- ─── CROSSHAIR ───────────────────────────────────────────────────────────────
local ch_enabled = false
local ch_size    = 8
local ch_gap     = 4
local ch_thick   = 1.5
local ch_color   = Color3.fromRGB(0, 200, 255)
local ch_dot     = false

local CH_LINES = {}
for i = 1, 4 do
    local l = Drawing.new("Line")
    l.Thickness = ch_thick; l.Color = ch_color; l.Visible = false
    CH_LINES[i] = l
end
local ch_dot_draw = Drawing.new("Circle")
ch_dot_draw.Radius = 2; ch_dot_draw.Color = ch_color; ch_dot_draw.Filled = true; ch_dot_draw.Visible = false

local CH_SHADOW = {}
for i = 1, 4 do
    local l = Drawing.new("Line")
    l.Thickness = ch_thick + 1.5; l.Color = Color3.new(0,0,0); l.Visible = false
    CH_SHADOW[i] = l
end
local ch_dot_shadow = Drawing.new("Circle")
ch_dot_shadow.Radius = 3; ch_dot_shadow.Color = Color3.new(0,0,0); ch_dot_shadow.Filled = true; ch_dot_shadow.Visible = false

runservice.RenderStepped:Connect(function()
    if not ch_enabled then
        for i = 1, 4 do CH_LINES[i].Visible = false; CH_SHADOW[i].Visible = false end
        ch_dot_draw.Visible = false; ch_dot_shadow.Visible = false; return
    end
    local c = get_screen_center()
    local s, g = ch_size, ch_gap
    local dirs = {
        { Vector2.new(-s-g, 0), Vector2.new(-g, 0) },
        { Vector2.new( s+g, 0), Vector2.new( g, 0) },
        { Vector2.new(0, -s-g), Vector2.new(0, -g) },
        { Vector2.new(0,  s+g), Vector2.new(0,  g) },
    }
    for i, d in ipairs(dirs) do
        CH_SHADOW[i].From = c+d[1]; CH_SHADOW[i].To = c+d[2]; CH_SHADOW[i].Color = Color3.new(0,0,0); CH_SHADOW[i].Visible = true
        CH_LINES[i].From  = c+d[1]; CH_LINES[i].To  = c+d[2]; CH_LINES[i].Color  = ch_color;           CH_LINES[i].Visible  = true
    end
    if ch_dot then
        ch_dot_shadow.Position = c; ch_dot_shadow.Visible = true
        ch_dot_draw.Position   = c; ch_dot_draw.Color = ch_color; ch_dot_draw.Visible = true
    else
        ch_dot_shadow.Visible = false; ch_dot_draw.Visible = false
    end
end)

chbox:AddToggle('ch_on',  { Text = 'crosshair',  Default = false }):OnChanged(function() ch_enabled = toggles.ch_on.Value  end)
chbox:AddToggle('ch_dot', { Text = 'center dot', Default = false }):OnChanged(function() ch_dot     = toggles.ch_dot.Value end)
chbox:AddSlider('ch_sz',  { Text = 'size',       Default = 8,  Min = 2,  Max = 20, Rounding = 0 }):OnChanged(function() ch_size  = options.ch_sz.Value end)
chbox:AddSlider('ch_gp',  { Text = 'gap',        Default = 4,  Min = 0,  Max = 12, Rounding = 0 }):OnChanged(function() ch_gap   = options.ch_gp.Value end)
chbox:AddSlider('ch_th',  { Text = 'thickness',  Default = 2,  Min = 1,  Max = 5,  Rounding = 0 }):OnChanged(function()
    ch_thick = options.ch_th.Value
    for i = 1, 4 do CH_LINES[i].Thickness = ch_thick end
end)
chbox:AddDropdown('ch_col', {
    Text    = 'color',
    Values  = {"Cyan", "White", "Green", "Red", "Yellow", "Purple"},
    Default = "Cyan",
}):OnChanged(function()
    local map = {
        Cyan   = Color3.fromRGB(0,200,255),
        White  = Color3.new(1,1,1),
        Green  = Color3.fromRGB(0,230,80),
        Red    = Color3.fromRGB(255,55,55),
        Yellow = Color3.fromRGB(255,220,50),
        Purple = Color3.fromRGB(180,80,255),
    }
    ch_color = map[options.ch_col.Value] or Color3.fromRGB(0,200,255)
end)
