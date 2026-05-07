local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

local Options = Library.Options
local Toggles = Library.Toggles

Library.ShowToggleFrameInKeybinds = true

local Window = Library:CreateWindow({
	Title = "BloxStrike",
	Footer = "Xeioa",
	NotifySide = "Right",
	ShowCustomCursor = true,
	AutoShow = true,
})

local Tabs = {
	Combat = Window:AddTab("Combat", "sword"),
	Visual = Window:AddTab("Visual", "eye"),
	Skins = Window:AddTab("Skins", "shirt"),
	["UI Settings"] = Window:AddTab("UI Settings", "settings"),
}

local AimbotBox  = Tabs.Combat:AddLeftGroupbox("Aimbot", "crosshair")
local MiscBox    = Tabs.Combat:AddRightGroupbox("Misc", "zap")

local ESPBox     = Tabs.Visual:AddLeftGroupbox("ESP", "scan-eye")
local EffectsBox = Tabs.Visual:AddRightGroupbox("Effects", "sparkles")

local WeaponBox  = Tabs.Skins:AddLeftGroupbox("Weapon Skins", "layers")
local KnifeBox   = Tabs.Skins:AddRightGroupbox("Knife & Gloves", "package")

local replicatedstorage = game:GetService("ReplicatedStorage")
local runservice        = game:GetService("RunService")
local tweenservice      = game:GetService("TweenService")
local cas               = game:GetService("ContextActionService")
local players           = game:GetService("Players")
local workspace_svc     = game:GetService("Workspace")
local inputservice      = game:GetService("UserInputService")
local plr               = players.LocalPlayer
local cam               = workspace_svc.CurrentCamera
local charfolder        = workspace_svc:WaitForChild("Characters", 10)

local function get_t()   return charfolder:FindFirstChild("Terrorists") end
local function get_ct()  return charfolder:FindFirstChild("Counter-Terrorists") end
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

-- ─── AIMBOT ────────────────────────────────────────────────────────────────

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
	inputservice.InputEnded:Connect(function(i) if i.UserInputType == aim_key then is_aiming = false end end)
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
			local vp    = cam.ViewportSize
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

AimbotBox:AddToggle("aim",   { Text = "Aimbot",     Default = false }):OnChanged(function() aim_enabled = Toggles.aim.Value  end)
AimbotBox:AddToggle("fov",   { Text = "FOV Circle", Default = false }):OnChanged(function() fov_enabled = Toggles.fov.Value  end)
AimbotBox:AddSlider("fov_r", { Text = "FOV Radius", Default = 100, Min = 10,  Max = 500, Rounding = 0 }):OnChanged(function() fov_radius = Options.fov_r.Value end)
AimbotBox:AddSlider("smth",  { Text = "Smoothing",  Default = 3,   Min = 1,   Max = 10,  Rounding = 0 }):OnChanged(function() smoothing  = Options.smth.Value  end)
AimbotBox:AddDivider()

local trigger_enabled, trigger_delay = false, 0
AimbotBox:AddToggle("trig",  { Text = "Triggerbot",    Default = false }):OnChanged(function() trigger_enabled = Toggles.trig.Value end)
AimbotBox:AddSlider("trig_d",{ Text = "Trigger Delay", Default = 0, Min = 0, Max = 500, Rounding = 0, Suffix = "ms" }):OnChanged(function() trigger_delay = Options.trig_d.Value end)

task.spawn(function()
	while task.wait(0.01) do
		if trigger_enabled and is_alive() then
			local r      = cam:ViewportPointToRay(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
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

-- ─── MISC COMBAT ───────────────────────────────────────────────────────────

local hitbox_enabled, hitbox_size, hb_originals = false, 3, {}
MiscBox:AddToggle("hb",   { Text = "Hitbox Expander", Default = false }):OnChanged(function() hitbox_enabled = Toggles.hb.Value  end)
MiscBox:AddSlider("hb_s", { Text = "Hitbox Size",     Default = 3, Min = 1, Max = 3, Rounding = 1 }):OnChanged(function() hitbox_size = Options.hb_s.Value end)

task.spawn(function()
	while task.wait(0.5) do
		local e = get_enemy()
		if e then
			for _, v in ipairs(e:GetChildren()) do
				local hd, h = v:FindFirstChild("Head"), v:FindFirstChildOfClass("Humanoid")
				if hd and h and h.Health > 0 then
					if not hb_originals[hd] then hb_originals[hd] = hd.Size end
					if hitbox_enabled then
						hd.Size        = Vector3.new(hitbox_size, hitbox_size, hitbox_size)
						hd.CanCollide  = false
						hd.Transparency = 0.5
					else
						if hb_originals[hd] then hd.Size = hb_originals[hd]; hd.Transparency = 0 end
					end
				end
			end
		end
	end
end)

local bhop_enabled = false
MiscBox:AddToggle("bhop", { Text = "Bunny Hop", Default = false }):OnChanged(function() bhop_enabled = Toggles.bhop.Value end)
runservice.RenderStepped:Connect(function()
	if bhop_enabled and inputservice:IsKeyDown(Enum.KeyCode.Space) and is_alive() and plr.Character then
		local h = plr.Character:FindFirstChildOfClass("Humanoid")
		if h and h:GetState() ~= Enum.HumanoidStateType.Jumping and h:GetState() ~= Enum.HumanoidStateType.Freefall then
			h.Jump = true
		end
	end
end)

local norecoil_enabled = false
MiscBox:AddToggle("nr", { Text = "No Recoil", Default = false }):OnChanged(function() norecoil_enabled = Toggles.nr.Value end)
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

MiscBox:AddDivider()

local wallbang_enabled = false
local wallbang_keywords = {
	"cube","wall","box","crate","fence","container","concrete",
	"cube.001","ship","invisible","plane.002","plane.003",
	"ceiling.006","acprop","cylinder.008","doorarchway.001","door3_low","cylinder.006"
}
MiscBox:AddToggle("wb", { Text = "Wallbang", Default = false }):OnChanged(function()
	wallbang_enabled = Toggles.wb.Value
	for _, v in ipairs(workspace_svc:GetDescendants()) do
		if v:IsA("BasePart") then
			local name = string.lower(v.Name)
			for _, kw in ipairs(wallbang_keywords) do
				if string.find(name, kw, 1, true) then
					v.CanCollide  = not wallbang_enabled
					if wallbang_enabled then v.CastShadow = false end
					break
				end
			end
		end
	end
end)
MiscBox:AddButton({
	Text = "Destroy Walls",
	Func = function()
		for _, v in ipairs(workspace_svc:GetDescendants()) do
			local name = string.lower(v.Name)
			for _, kw in ipairs(wallbang_keywords) do
				if string.find(name, kw, 1, true) then v:Destroy(); break end
			end
		end
	end,
	DoubleClick = true,
	Tooltip = "Double-click to destroy all wall parts",
})

-- ─── ESP (completely redesigned) ───────────────────────────────────────────

local esp_enabled   = false
local show_box      = true
local show_name     = true
local show_hp       = true
local show_dist     = true
local show_tracer   = false
local esp_color     = Color3.fromRGB(255, 60, 60)
local esp_cache     = {}

local function make_line(thick, color, transp)
	local l = Drawing.new("Line")
	l.Thickness   = thick or 1
	l.Color       = color or Color3.new(1, 1, 1)
	l.Transparency = transp or 1
	l.Visible     = false
	return l
end

local function make_text(size, color, center, outline)
	local t = Drawing.new("Text")
	t.Size    = size or 14
	t.Color   = color or Color3.new(1, 1, 1)
	t.Center  = center ~= nil and center or true
	t.Outline = outline ~= nil and outline or true
	t.Visible = false
	return t
end

local function create_esp_set()
	return {
		tl_h   = make_line(2, esp_color),
		tl_v   = make_line(2, esp_color),
		tr_h   = make_line(2, esp_color),
		tr_v   = make_line(2, esp_color),
		bl_h   = make_line(2, esp_color),
		bl_v   = make_line(2, esp_color),
		br_h   = make_line(2, esp_color),
		br_v   = make_line(2, esp_color),
		tl_h_o = make_line(4, Color3.new(0,0,0)),
		tl_v_o = make_line(4, Color3.new(0,0,0)),
		tr_h_o = make_line(4, Color3.new(0,0,0)),
		tr_v_o = make_line(4, Color3.new(0,0,0)),
		bl_h_o = make_line(4, Color3.new(0,0,0)),
		bl_v_o = make_line(4, Color3.new(0,0,0)),
		br_h_o = make_line(4, Color3.new(0,0,0)),
		br_v_o = make_line(4, Color3.new(0,0,0)),
		hp_bg  = make_line(5, Color3.new(0,0,0)),
		hp_bar = make_line(3, Color3.new(0,1,0)),
		name   = make_text(14, Color3.new(1,1,1), true, true),
		dist   = make_text(12, Color3.fromRGB(200,200,200), true, true),
		tracer = make_line(1, esp_color),
		tracer_o = make_line(3, Color3.new(0,0,0)),
	}
end

local function set_corner(e, bx, by, bw, bh)
	local cl = math.max(6, math.floor(bw * 0.22))
	local ch = math.max(6, math.floor(bh * 0.18))
	local x1, y1 = bx,        by
	local x2, y2 = bx + bw,   by
	local x3, y3 = bx,        by + bh
	local x4, y4 = bx + bw,   by + bh

	e.tl_h.From = Vector2.new(x1, y1);        e.tl_h.To = Vector2.new(x1 + cl, y1)
	e.tl_v.From = Vector2.new(x1, y1);        e.tl_v.To = Vector2.new(x1, y1 + ch)
	e.tr_h.From = Vector2.new(x2, y2);        e.tr_h.To = Vector2.new(x2 - cl, y2)
	e.tr_v.From = Vector2.new(x2, y2);        e.tr_v.To = Vector2.new(x2, y2 + ch)
	e.bl_h.From = Vector2.new(x3, y3);        e.bl_h.To = Vector2.new(x3 + cl, y3)
	e.bl_v.From = Vector2.new(x3, y3);        e.bl_v.To = Vector2.new(x3, y3 - ch)
	e.br_h.From = Vector2.new(x4, y4);        e.br_h.To = Vector2.new(x4 - cl, y4)
	e.br_v.From = Vector2.new(x4, y4);        e.br_v.To = Vector2.new(x4, y4 - ch)

	e.tl_h_o.From = e.tl_h.From; e.tl_h_o.To = e.tl_h.To
	e.tl_v_o.From = e.tl_v.From; e.tl_v_o.To = e.tl_v.To
	e.tr_h_o.From = e.tr_h.From; e.tr_h_o.To = e.tr_h.To
	e.tr_v_o.From = e.tr_v.From; e.tr_v_o.To = e.tr_v.To
	e.bl_h_o.From = e.bl_h.From; e.bl_h_o.To = e.bl_h.To
	e.bl_v_o.From = e.bl_v.From; e.bl_v_o.To = e.bl_v.To
	e.br_h_o.From = e.br_h.From; e.br_h_o.To = e.br_h.To
	e.br_v_o.From = e.br_v.From; e.br_v_o.To = e.br_v.To
end

local function show_corners(e, vis)
	local keys = {"tl_h","tl_v","tr_h","tr_v","bl_h","bl_v","br_h","br_v",
	              "tl_h_o","tl_v_o","tr_h_o","tr_v_o","bl_h_o","bl_v_o","br_h_o","br_v_o"}
	for _, k in ipairs(keys) do e[k].Visible = vis end
end

local function hide_esp(e)
	for _, v in pairs(e) do v.Visible = false end
end

runservice.RenderStepped:Connect(function()
	if not esp_enabled or not is_alive() then
		for _, e in pairs(esp_cache) do hide_esp(e) end
		return
	end
	local target_folder = get_enemy()
	if not target_folder then return end
	local alive_now = {}

	for _, v in ipairs(target_folder:GetChildren()) do
		local hum  = v:FindFirstChildOfClass("Humanoid")
		local root = v:FindFirstChild("HumanoidRootPart")
		local hd   = v:FindFirstChild("Head")
		if hum and hum.Health > 0 and root and hd then
			alive_now[v] = true
			if not esp_cache[v] then esp_cache[v] = create_esp_set() end
			local e = esp_cache[v]

			local rp,  vis  = cam:WorldToViewportPoint(root.Position)
			local top, _    = cam:WorldToViewportPoint(hd.Position + Vector3.new(0, 0.6, 0))
			local bot, _    = cam:WorldToViewportPoint(root.Position - Vector3.new(0, 3.1, 0))

			if vis then
				local bh  = math.abs(top.Y - bot.Y)
				local bw  = bh * 0.55
				local bx  = rp.X - bw / 2
				local by  = top.Y

				if show_box then
					for _, d in ipairs({"tl_h","tl_v","tr_h","tr_v","bl_h","bl_v","br_h","br_v"}) do
						e[d].Color = esp_color
					end
					set_corner(e, bx, by, bw, bh)
					show_corners(e, true)
				else
					show_corners(e, false)
				end

				if show_hp then
					local hpp   = hum.Health / hum.MaxHealth
					local hpx   = bx - 7
					local hpc   = Color3.new(1 - hpp, hpp * 0.85, 0)
					e.hp_bg.From  = Vector2.new(hpx, by - 1)
					e.hp_bg.To    = Vector2.new(hpx, by + bh + 1)
					e.hp_bg.Visible = true
					e.hp_bar.From = Vector2.new(hpx, by + bh)
					e.hp_bar.To   = Vector2.new(hpx, by + bh - (bh * hpp))
					e.hp_bar.Color   = hpc
					e.hp_bar.Visible = true
				else
					e.hp_bg.Visible, e.hp_bar.Visible = false, false
				end

				if show_name then
					e.name.Text     = v.Name
					e.name.Position = Vector2.new(rp.X, by - 18)
					e.name.Color    = esp_color
					e.name.Visible  = true
				else
					e.name.Visible = false
				end

				if show_dist then
					local dst       = math.floor((cam.CFrame.Position - root.Position).Magnitude)
					e.dist.Text     = dst .. "m"
					e.dist.Position = Vector2.new(rp.X, by + bh + 3)
					e.dist.Visible  = true
				else
					e.dist.Visible = false
				end

				if show_tracer then
					local vp         = cam.ViewportSize
					e.tracer_o.From  = Vector2.new(vp.X / 2, vp.Y)
					e.tracer_o.To    = Vector2.new(rp.X, by + bh)
					e.tracer_o.Visible = true
					e.tracer.From    = Vector2.new(vp.X / 2, vp.Y)
					e.tracer.To      = Vector2.new(rp.X, by + bh)
					e.tracer.Color   = esp_color
					e.tracer.Visible = true
				else
					e.tracer.Visible, e.tracer_o.Visible = false, false
				end
			else
				hide_esp(e)
			end
		end
	end

	for k, v in pairs(esp_cache) do
		if not alive_now[k] then
			for _, d in pairs(v) do d:Remove() end
			esp_cache[k] = nil
		end
	end
end)

ESPBox:AddToggle("esp",       { Text = "ESP",      Default = false }):OnChanged(function() esp_enabled = Toggles.esp.Value     end)
ESPBox:AddToggle("esp_b",     { Text = "Corners",  Default = true  }):OnChanged(function() show_box    = Toggles.esp_b.Value   end)
ESPBox:AddToggle("esp_h",     { Text = "HP Bar",   Default = true  }):OnChanged(function() show_hp     = Toggles.esp_h.Value   end)
ESPBox:AddToggle("esp_n",     { Text = "Name",     Default = true  }):OnChanged(function() show_name   = Toggles.esp_n.Value   end)
ESPBox:AddToggle("esp_d",     { Text = "Distance", Default = true  }):OnChanged(function() show_dist   = Toggles.esp_d.Value   end)
ESPBox:AddToggle("esp_t",     { Text = "Tracer",   Default = false }):OnChanged(function() show_tracer = Toggles.esp_t.Value   end)
ESPBox:AddDivider()
ESPBox:AddLabel("ESP Color"):AddColorPicker("esp_clr", {
	Default = Color3.fromRGB(255, 60, 60),
	Title   = "ESP Color",
	Callback = function(v) esp_color = v end,
})

-- ─── EFFECTS ───────────────────────────────────────────────────────────────

local antiflash, antismoke = false, false
EffectsBox:AddToggle("af", { Text = "No Flash", Default = false }):OnChanged(function() antiflash = Toggles.af.Value end)
EffectsBox:AddToggle("as", { Text = "No Smoke", Default = false }):OnChanged(function() antismoke = Toggles.as.Value end)
task.spawn(function()
	while task.wait(0.2) do
		if antiflash then
			local gui    = plr.PlayerGui:FindFirstChild("FlashbangEffect")
			local effect = game:GetService("Lighting"):FindFirstChild("FlashbangColorCorrection")
			if gui    then gui:Destroy()    end
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

EffectsBox:AddDivider()

local antiaim_enabled    = false
local antiaim_mode       = "Spin"
local antiaim_angle      = 0
local antiaim_spin_speed = 10

EffectsBox:AddToggle("aa",     { Text = "Anti Aim",   Default = false }):OnChanged(function() antiaim_enabled    = Toggles.aa.Value     end)
EffectsBox:AddDropdown("aa_mode", { Text = "AA Mode", Values = {"Spin","Jitter","Down","Up"}, Default = "Spin" }):OnChanged(function() antiaim_mode = Options.aa_mode.Value end)
EffectsBox:AddSlider("aa_spd", { Text = "Spin Speed", Default = 10, Min = 1, Max = 30, Rounding = 0 }):OnChanged(function() antiaim_spin_speed = Options.aa_spd.Value end)

local aa_conn = nil
local function get_neck_joint()
	local char = plr.Character
	if not char then return end
	local upper = char:FindFirstChild("UpperTorso")
	if upper then local n = upper:FindFirstChild("Neck"); if n then return n end end
	local head  = char:FindFirstChild("Head")
	if head  then local n = head:FindFirstChild("Neck");  if n then return n end end
end
local function start_antiaim()
	if aa_conn then aa_conn:Disconnect(); aa_conn = nil end
	aa_conn = runservice.Heartbeat:Connect(function()
		if not antiaim_enabled or not is_alive() or not plr.Character then return end
		local hrp        = plr.Character:FindFirstChild("HumanoidRootPart")
		local root_joint = hrp and hrp:FindFirstChild("RootJoint")
		if not root_joint then
			local lower  = plr.Character:FindFirstChild("LowerTorso")
			root_joint   = lower and lower:FindFirstChild("Root")
		end
		if antiaim_mode == "Spin" then
			if not root_joint then return end
			antiaim_angle  = (antiaim_angle + antiaim_spin_speed) % 360
			root_joint.C0  = CFrame.new(0, -1, 0) * CFrame.Angles(0, math.rad(antiaim_angle), 0)
		elseif antiaim_mode == "Jitter" then
			if not root_joint then return end
			root_joint.C0  = CFrame.new(0, -1, 0) * CFrame.Angles(0, math.rad(180), 0)
		elseif antiaim_mode == "Down" then
			local neck = get_neck_joint()
			if neck then neck.C0 = CFrame.new(0, 1, 0) * CFrame.Angles(math.rad(-89), 0, 0) end
		elseif antiaim_mode == "Up" then
			local neck = get_neck_joint()
			if neck then neck.C0 = CFrame.new(0, 1, 0) * CFrame.Angles(math.rad(89), 0, 0)  end
		end
	end)
end
start_antiaim()

EffectsBox:AddDivider()

local thirdperson_enabled = false
local tp_distance         = 10
local current_fov         = 70

local function set_char_visible(visible)
	local char = plr.Character
	if not char then return end
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
	local char = plr.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if state then
		if hum then hum.CameraOffset = Vector3.new(0, 2.5, tp_distance) end
		set_char_visible(true)
		cam.FieldOfView = 70
	else
		if hum then hum.CameraOffset = Vector3.new(0, 0, 0) end
		set_char_visible(false)
		cam.FieldOfView = current_fov
	end
end
runservice.RenderStepped:Connect(function()
	if thirdperson_enabled and plr.Character then
		set_char_visible(true)
		hide_viewmodel()
	end
end)

EffectsBox:AddToggle("tp", { Text = "Third Person", Default = false }):OnChanged(function()
	thirdperson_enabled = Toggles.tp.Value
	set_thirdperson(thirdperson_enabled)
end)
EffectsBox:AddSlider("tp_dist", { Text = "TP Distance", Default = 10, Min = 3, Max = 30, Rounding = 0 }):OnChanged(function()
	tp_distance = Options.tp_dist.Value
	if thirdperson_enabled and plr.Character then
		local hum = plr.Character:FindFirstChildOfClass("Humanoid")
		if hum then hum.CameraOffset = Vector3.new(0, 0, tp_distance) end
	end
end)
plr.CharacterAdded:Connect(function()
	task.wait(0.5)
	if thirdperson_enabled then set_thirdperson(true) end
end)

EffectsBox:AddDivider()

local stretch_enabled = false
local stretch_res     = 0.80
EffectsBox:AddToggle("stretch", { Text = "Stretched Res", Default = false }):OnChanged(function()
	stretch_enabled = Toggles.stretch.Value
	if not stretch_enabled then cam.CFrame = cam.CFrame * CFrame.new(0,0,0,1,0,0,0,1,0,0,0,1) end
end)
EffectsBox:AddSlider("stretch_r", { Text = "Stretch Amount", Default = 80, Min = 50, Max = 99, Rounding = 0 }):OnChanged(function()
	stretch_res = Options.stretch_r.Value / 100
end)
runservice.RenderStepped:Connect(function()
	if stretch_enabled then cam.CFrame = cam.CFrame * CFrame.new(0,0,0,1,0,0,0,stretch_res,0,0,0,1) end
end)

local motionblur_enabled = false
local blur_amount        = 15
local blur_amplifier     = 5
local motion_blur_fx     = nil
local last_look          = cam.CFrame.LookVector

EffectsBox:AddToggle("mb",     { Text = "Motion Blur",    Default = false }):OnChanged(function()
	motionblur_enabled = Toggles.mb.Value
	if not motionblur_enabled and motion_blur_fx then motion_blur_fx.Size = 0 end
end)
EffectsBox:AddSlider("mb_amt", { Text = "Blur Amount",    Default = 15, Min = 1, Max = 45, Rounding = 0 }):OnChanged(function() blur_amount    = Options.mb_amt.Value end)
EffectsBox:AddSlider("mb_amp", { Text = "Blur Amplifier", Default = 5,  Min = 1, Max = 15, Rounding = 0 }):OnChanged(function() blur_amplifier = Options.mb_amp.Value end)

motion_blur_fx        = Instance.new("BlurEffect")
motion_blur_fx.Size   = 0
motion_blur_fx.Parent = cam

workspace_svc.Changed:Connect(function(prop)
	if prop == "CurrentCamera" then
		local nc = workspace_svc.CurrentCamera
		if motion_blur_fx and motion_blur_fx.Parent then
			motion_blur_fx.Parent = nc
		else
			motion_blur_fx        = Instance.new("BlurEffect")
			motion_blur_fx.Size   = 0
			motion_blur_fx.Parent = nc
		end
	end
end)
runservice.Heartbeat:Connect(function()
	if not motion_blur_fx or not motion_blur_fx.Parent then
		motion_blur_fx        = Instance.new("BlurEffect")
		motion_blur_fx.Size   = 0
		motion_blur_fx.Parent = cam
	end
	if motionblur_enabled then
		local mag             = (cam.CFrame.LookVector - last_look).Magnitude
		motion_blur_fx.Size   = math.abs(mag) * blur_amount * blur_amplifier / 2
	else
		motion_blur_fx.Size = 0
	end
	last_look = cam.CFrame.LookVector
end)

-- ─── KNIFE ─────────────────────────────────────────────────────────────────

local knife_enabled, knife_selected, spawned, inspecting, swinging, last_atk = false, "Butterfly Knife", false, false, false, 0
local knife_data = {
	["Karambit"]      = {Offset = CFrame.new(0, -1.5, 1.5)},
	["Butterfly Knife"]= {Offset = CFrame.new(0, -1.5, 1.5)},
	["M9 Bayonet"]    = {Offset = CFrame.new(0, -1.5, 1)},
	["Flip Knife"]    = {Offset = CFrame.new(0, -1.5, 1.25)},
	["Gut Knife"]     = {Offset = CFrame.new(0, -1.5, 0.5)},
}
local knife_vm, animator, equip_anim, idle_anim, inspect_anim, heavy_anim, s1_anim, s2_anim

local function get_knife() return cam:FindFirstChild("T Knife") or cam:FindFirstChild("CT Knife") end
local function clean_part(part)
	if not part:IsA("BasePart") then return end
	part.CanCollide, part.Anchored, part.CastShadow, part.CanTouch, part.CanQuery = false, false, false, false, false
end
local function play_sound(f, n)
	local sf = replicatedstorage.Sounds:FindFirstChild(knife_selected)
	if not sf then return end
	local sound        = sf:WaitForChild(f):WaitForChild(n):Clone()
	sound.Parent       = cam
	sound:Play()
	sound.Ended:Once(function() sound:Destroy() end)
	return sound
end
local function attach_asset(f, arm, model, n, o)
	local target_arm = knife_vm:FindFirstChild(arm)
	if not target_arm then return end
	local asset       = f:WaitForChild(model):Clone()
	clean_part(asset)
	asset.Name, asset.Parent = n, target_arm
	local motor       = Instance.new("Motor6D")
	motor.Part0, motor.Part1, motor.C0, motor.Parent = target_arm, asset, o, target_arm
end
local function handle_action(name, state)
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
		local anims  = {heavy_anim, s1_anim, s2_anim}
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
	knife_vm             = knife_template:WaitForChild("Camera"):Clone()
	knife_vm.Name, knife_vm.Parent = knife_selected, cam
	for _, part in knife_vm:GetDescendants() do clean_part(part) end
	for _, part in k:GetDescendants() do
		if part:IsA("BasePart") or part:IsA("Texture") then part.Transparency = 1 end
	end
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
	animator         = controller:FindFirstChildWhichIsA("Animator") or controller
	local anim_folder = replicatedstorage.Assets.WeaponAnimations:WaitForChild(knife_selected):WaitForChild("CameraAnimations")
	equip_anim   = animator:LoadAnimation(anim_folder:WaitForChild("Equip"))
	idle_anim    = animator:LoadAnimation(anim_folder:WaitForChild("Idle"))
	inspect_anim = animator:LoadAnimation(anim_folder:WaitForChild("Inspect"))
	heavy_anim   = animator:LoadAnimation(anim_folder:WaitForChild("Heavy Swing"))
	s1_anim      = animator:LoadAnimation(anim_folder:WaitForChild("Swing1"))
	s2_anim      = animator:LoadAnimation(anim_folder:WaitForChild("Swing2"))
	knife_vm:SetPrimaryPartCFrame(cam.CFrame * CFrame.new(0, -1.5, 5))
	tweenservice:Create(knife_vm.PrimaryPart, TweenInfo.new(0.2), {CFrame = cam.CFrame * knife_offset}):Play()
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
		if knife_enabled and alive_state and current_knife and not spawned then spawn_vm(current_knife)
		elseif (not knife_enabled or not current_knife or not alive_state) and spawned then remove_vm() end
	end
end)

-- ─── SKINS ─────────────────────────────────────────────────────────────────

local skins_enabled, selected_skins, skin_drops, skin_options = false, {}, {}, {}
local ct_weapon_list    = {["USP-S"]=1,["Five-SeveN"]=1,["MP9"]=1,["FAMAS"]=1,["M4A1-S"]=1,["M4A4"]=1,["AUG"]=1}
local shared_weapon_list= {["P250"]=1,["Desert Eagle"]=1,["Dual Berettas"]=1,["Negev"]=1,["P90"]=1,["Nova"]=1,["XM1014"]=1,["AWP"]=1,["SSG 08"]=1}
local knife_list        = {["Karambit"]=1,["Butterfly Knife"]=1,["M9 Bayonet"]=1,["Flip Knife"]=1,["Gut Knife"]=1,["T Knife"]=1,["CT Knife"]=1}
local glove_list        = {["Sports Gloves"]=1}
local skins_folder      = replicatedstorage:WaitForChild("Assets"):WaitForChild("Skins")
local ignore_items      = {["HE Grenade"]=1,["Incendiary Grenade"]=1,["Molotov"]=1,["Smoke Grenade"]=1,["Flashbang"]=1,["Decoy Grenade"]=1,["C4"]=1,["CT Glove"]=1,["T Glove"]=1}

local function apply_skin_to_model(m)
	if not m or not skins_enabled or not is_alive() then return end
	local skin_name = selected_skins[m.Name]
	if not skin_name then return end
	pcall(function()
		local s_fd  = skins_folder:FindFirstChild(m.Name)
		if not s_fd then return end
		local st    = s_fd:FindFirstChild(skin_name)
		local source= st and st:FindFirstChild("Camera") and st.Camera:FindFirstChild("Factory New")
		if not source then return end
		for _, o in cam:GetChildren() do
			local l, r = o:FindFirstChild("Left Arm"), o:FindFirstChild("Right Arm")
			if l or r then
				local gf   = skins_folder:FindFirstChild("Sports Gloves")
				local gs   = gf and gf:FindFirstChild(selected_skins["Sports Gloves"])
				local gsrc = gs and gs:FindFirstChild("Camera") and gs.Camera:FindFirstChild("Factory New")
				if gsrc then
					for _, side in {"Left Arm", "Right Arm"} do
						local arm, s = o:FindFirstChild(side), gsrc:FindFirstChild(side)
						if arm and s then
							local g = arm:FindFirstChild("Glove")
							if g then
								local ex = g:FindFirstChildOfClass("SurfaceAppearance")
								if ex then ex:Destroy() end
								s:Clone().Parent = g
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

WeaponBox:AddToggle("skin_on", { Text = "Skins", Default = false }):OnChanged(function()
	skins_enabled = Toggles.skin_on.Value
	if not skins_enabled then for _, o in cam:GetChildren() do o:SetAttribute("SkinApplied", nil) end end
end)
WeaponBox:AddButton({
	Text = "Random Skin",
	Func = function()
		for w_n, o_l in pairs(skin_options) do
			if #o_l > 0 then
				local r_s = o_l[math.random(1, #o_l)]
				if skin_drops[w_n] then selected_skins[w_n] = r_s; Options["Skin_"..w_n]:SetValue(r_s) end
			end
		end
	end,
	DoubleClick = false,
})

local function build_weapon_dropdown(w_n, box)
	local f = skins_folder:FindFirstChild(w_n)
	if not f then return end
	local o = {}
	for _, s in f:GetChildren() do table.insert(o, s.Name) end
	skin_options[w_n] = o
	if not selected_skins[w_n] then selected_skins[w_n] = o[1] end
	local d = box:AddDropdown("Skin_"..w_n, { Text = w_n, Values = o, Default = o[1], Searchable = true })
	d:OnChanged(function()
		selected_skins[w_n] = d.Value
		for _, obj in cam:GetChildren() do obj:SetAttribute("SkinApplied", nil); apply_skin_to_model(obj) end
	end)
	skin_drops[w_n] = d
end

KnifeBox:AddToggle("knf_on",  { Text = "Knife",      Default = false }):OnChanged(function() knife_enabled = Toggles.knf_on.Value; if not knife_enabled then remove_vm() end end)
KnifeBox:AddDropdown("knf_sel",{ Text = "Knife Type", Values = {"Butterfly Knife","Karambit","M9 Bayonet","Flip Knife","Gut Knife"}, Default = "Butterfly Knife" }):OnChanged(function()
	knife_selected = Options.knf_sel.Value
	if spawned then remove_vm() end
end)
KnifeBox:AddDivider()

for n in pairs(knife_list)         do build_weapon_dropdown(n, KnifeBox)  end
for n in pairs(glove_list)         do build_weapon_dropdown(n, KnifeBox)  end
for n in pairs(ct_weapon_list)     do build_weapon_dropdown(n, WeaponBox) end
for n in pairs(shared_weapon_list) do build_weapon_dropdown(n, WeaponBox) end
for _, f in skins_folder:GetChildren() do
	if not ignore_items[f.Name] and not knife_list[f.Name] and not glove_list[f.Name]
		and not ct_weapon_list[f.Name] and not shared_weapon_list[f.Name] then
		build_weapon_dropdown(f.Name, WeaponBox)
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

-- ─── UI SETTINGS ───────────────────────────────────────────────────────────

local MenuGroup = Tabs["UI Settings"]:AddLeftGroupbox("Menu", "wrench")

MenuGroup:AddToggle("KeybindMenuOpen", {
	Default  = Library.KeybindFrame.Visible,
	Text     = "Open Keybind Menu",
	Callback = function(value) Library.KeybindFrame.Visible = value end,
})
MenuGroup:AddToggle("ShowCustomCursor", {
	Text     = "Custom Cursor",
	Default  = true,
	Callback = function(Value) Library.ShowCustomCursor = Value end,
})
MenuGroup:AddDropdown("NotificationSide", {
	Values   = {"Left", "Right"},
	Default  = "Right",
	Text     = "Notification Side",
	Callback = function(Value) Library:SetNotifySide(Value) end,
})
MenuGroup:AddDropdown("DPIDropdown", {
	Values   = {"50%","75%","100%","125%","150%","175%","200%"},
	Default  = "100%",
	Text     = "DPI Scale",
	Callback = function(Value)
		Value = Value:gsub("%%", "")
		Library:SetDPIScale(tonumber(Value))
	end,
})
MenuGroup:AddSlider("UICornerSlider", {
	Text     = "Corner Radius",
	Default  = Library.CornerRadius,
	Min      = 0,
	Max      = 20,
	Rounding = 0,
	Callback = function(value) Window:SetCornerRadius(value) end,
})
MenuGroup:AddDivider()
MenuGroup:AddLabel("Menu Keybind"):AddKeyPicker("MenuKeybind", {
	Default = "RightShift",
	NoUI    = true,
	Text    = "Menu Keybind",
})
MenuGroup:AddButton({
	Text = "Unload",
	Func = function() Library:Unload() end,
	DoubleClick = false,
})

Library.ToggleKeybind = Options.MenuKeybind

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({"MenuKeybind"})
ThemeManager:SetFolder("BloxStrike")
SaveManager:SetFolder("BloxStrike/configs")
SaveManager:BuildConfigSection(Tabs["UI Settings"])
ThemeManager:ApplyToTab(Tabs["UI Settings"])
SaveManager:LoadAutoloadConfig()
