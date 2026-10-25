--// PORTAL TECNOLÓGICO GIGANTE (LocalScript, funciona no mobile)
--// Coloque em StarterPlayer > StarterPlayerScripts, ou execute como LocalScript.
--// Aparece o Tool "Portal" na hotbar. Equipe, mire (no celular o centro da tela),
--// veja o holograma e TOQUE/CLIQUE para construir.
--// 1º portal = AZUL, 2º portal = LARANJA. Entrou em um, sai no outro.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

------------------------------------------------------------
-- CONFIG
------------------------------------------------------------
local R = 14                 -- raio do anel (portal gigante)
local SEGMENTS = 28          -- peças do anel
local BUILD_DELAY = 0.07     -- tempo entre cada peça
local MAX_DIST = 140         -- distância máxima para construir
local TP_COOLDOWN = 1.5
local COLORS = {
	Color3.fromRGB(0, 200, 255),
	Color3.fromRGB(255, 140, 30),
}
local DARK = Color3.fromRGB(35, 42, 60)

------------------------------------------------------------
-- LIMPEZA (caso execute de novo)
------------------------------------------------------------
if _G.PortalLocalCleanup then pcall(_G.PortalLocalCleanup) end

local conns = {}
local function connect(sig, fn)
	local c = sig:Connect(fn)
	table.insert(conns, c)
	return c
end

local root = Instance.new("Folder")
root.Name = "PortalSystemLocal"
root.Parent = Workspace

local gui = Instance.new("ScreenGui")
gui.Name = "PortalFlash"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local flash = Instance.new("Frame")
flash.Size = UDim2.fromScale(1, 1)
flash.BackgroundTransparency = 1
flash.BorderSizePixel = 0
flash.Parent = gui

local currentTool
local holo

------------------------------------------------------------
-- HELPERS
------------------------------------------------------------
local function tw(obj, t, props, style, dir)
	local tween = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tween:Play()
	return tween
end

local function mk(parent, size, color, mat, transp, cf, cyl)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.Color = color
	p.Material = mat
	p.Transparency = transp
	p.CFrame = cf or CFrame.new()
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if cyl then p.Shape = Enum.PartType.Cylinder end
	p.Parent = parent
	return p
end

local function burst(part, color, n)
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(color)
	e.LightEmission = 1
	e.Rate = 0
	e.Lifetime = NumberRange.new(0.4, 0.9)
	e.Speed = NumberRange.new(10, 25)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.3), NumberSequenceKeypoint.new(1, 0) })
	e.Parent = part
	e:Emit(n or 10)
	Debris:AddItem(e, 2)
end

local function shake(duration, mag)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	task.spawn(function()
		local t0 = tick()
		while tick() - t0 < duration do
			local f = 1 - (tick() - t0) / duration
			hum.CameraOffset = Vector3.new((math.random() - 0.5) * mag * f, (math.random() - 0.5) * mag * f, 0)
			RunService.RenderStepped:Wait()
		end
		hum.CameraOffset = Vector3.zero
	end)
end

local function doFlash(color)
	flash.BackgroundColor3 = color
	flash.BackgroundTransparency = 0.15
	tw(flash, 0.6, { BackgroundTransparency = 1 })
end

------------------------------------------------------------
-- HOLOGRAMA
------------------------------------------------------------
local holoParts, holoScan, holoLabel = {}, nil, nil
local arc = 2 * math.pi * R / SEGMENTS * 1.02

local function buildHolo()
	holo = Instance.new("Model")
	holo.Name = "PortalHologram"
	holoParts = {}

	for i = 0, SEGMENTS - 1 do
		local a = i / SEGMENTS * 2 * math.pi
		local p = mk(holo, Vector3.new(arc, 0.5, 0.5), COLORS[1], Enum.Material.Neon, 0.45,
			CFrame.new(math.cos(a) * R, R + 1 + math.sin(a) * R, 0) * CFrame.Angles(0, 0, a + math.pi / 2))
		table.insert(holoParts, { part = p, base = 0.45 })
	end

	local D = 2 * R - 3
	local disc = mk(holo, Vector3.new(0.2, D, D), COLORS[1], Enum.Material.Neon, 0.88,
		CFrame.new(0, R + 1, 0) * CFrame.Angles(0, math.pi / 2, 0), true)
	table.insert(holoParts, { part = disc, base = 0.88 })

	local base = mk(holo, Vector3.new(0.2, 34, 34), COLORS[1], Enum.Material.Neon, 0.7,
		CFrame.Angles(0, 0, math.pi / 2), true)
	table.insert(holoParts, { part = base, base = 0.7 })

	for _, side in ipairs({ -1, 1 }) do
		local py = mk(holo, Vector3.new(4, 10, 4), COLORS[1], Enum.Material.Neon, 0.7,
			CFrame.new(side * (R + 4), 5, 0))
		table.insert(holoParts, { part = py, base = 0.7 })
	end

	holoScan = mk(holo, Vector3.new(2 * (R - 2), 0.4, 0.4), COLORS[1], Enum.Material.Neon, 0.2, CFrame.new())

	local bb = Instance.new("BillboardGui")
	bb.Adornee = disc
	bb.Size = UDim2.fromOffset(140, 32)
	bb.StudsOffset = Vector3.new(0, R + 4, 0)
	bb.AlwaysOnTop = true
	bb.Parent = disc
	holoLabel = Instance.new("TextLabel")
	holoLabel.Size = UDim2.fromScale(1, 1)
	holoLabel.BackgroundTransparency = 1
	holoLabel.Font = Enum.Font.GothamBold
	holoLabel.TextScaled = true
	holoLabel.Text = "PORTAL A"
	holoLabel.TextStrokeTransparency = 0.4
	holoLabel.Parent = bb

	holo.WorldPivot = CFrame.new()
end

local function setHoloColor(idx)
	local c = COLORS[idx]
	for _, h in ipairs(holoParts) do h.part.Color = c end
	holoScan.Color = c
	holoLabel.TextColor3 = c
	holoLabel.Text = idx == 1 and "PORTAL A" or "PORTAL B"
end

------------------------------------------------------------
-- MIRA (mouse no PC, centro da tela no celular)
------------------------------------------------------------
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function getTargetCF()
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return nil end

	local ray
	if UIS.TouchEnabled and not UIS.MouseEnabled then
		local vs = camera.ViewportSize
		ray = camera:ViewportPointToRay(vs.X / 2, vs.Y / 2)
	else
		local loc = UIS:GetMouseLocation()
		ray = camera:ViewportPointToRay(loc.X, loc.Y)
	end

	rayParams.FilterDescendantsInstances = { char, holo, root }
	local res = Workspace:Raycast(ray.Origin, ray.Direction * 600, rayParams)
	if not res then return nil end
	if (res.Position - hrp.Position).Magnitude > MAX_DIST then return nil end

	local pos = res.Position + Vector3.new(0, 0.05, 0)
	local toPlayer = hrp.Position - pos
	local flat = Vector3.new(toPlayer.X, 0, toPlayer.Z)
	if flat.Magnitude < 0.1 then flat = Vector3.new(0, 0, 1) end
	return CFrame.lookAt(pos, pos + flat.Unit)
end

------------------------------------------------------------
-- PORTAIS
------------------------------------------------------------
local portals = {}   -- [1] e [2]
local nextSlot = 1
local building = false
local lastTp = 0

local function removePortal(p)
	if not p then return end
	p.dead = true
	p.ready = false
	for _, d in ipairs(p.model:GetDescendants()) do
		if d:IsA("BasePart") then
			tw(d, 0.6, { Transparency = 1 })
		end
	end
	Debris:AddItem(p.model, 0.8)
end

local function buildPortal(idx, cf)
	building = true
	local color = COLORS[idx]
	local m = Instance.new("Model")
	m.Name = "Portal" .. idx
	m.Parent = root

	local portal = { model = m, cf = cf, idx = idx, ready = false, dead = false, spokes = {}, angle = 0 }
	portals[idx] = portal

	task.spawn(function()
		local function alive() return m.Parent ~= nil and not portal.dead end
		local D = 2 * R - 3

		-- 1) Base + onda de choque
		local pad = mk(m, Vector3.new(0.3, 0.1, 0.1), color, Enum.Material.Neon, 0,
			cf * CFrame.new(0, 0.3, 0) * CFrame.Angles(0, 0, math.pi / 2), true)
		tw(pad, 0.9, { Size = Vector3.new(0.6, 34, 34) }, Enum.EasingStyle.Quint)
		local pad2 = mk(m, Vector3.new(0.3, 0.1, 0.1), DARK, Enum.Material.Metal, 0,
			cf * CFrame.new(0, 0.5, 0) * CFrame.Angles(0, 0, math.pi / 2), true)
		tw(pad2, 1.1, { Size = Vector3.new(0.4, 29, 29) }, Enum.EasingStyle.Quint)

		local wave = mk(m, Vector3.new(0.2, 2, 2), color, Enum.Material.Neon, 0.3,
			cf * CFrame.new(0, 0.4, 0) * CFrame.Angles(0, 0, math.pi / 2), true)
		tw(wave, 1.3, { Size = Vector3.new(0.2, 70, 70), Transparency = 1 })
		Debris:AddItem(wave, 1.4)
		shake(4, 0.6)
		task.wait(0.8)
		if not alive() then return end

		-- 2) Pilares sobem
		for _, side in ipairs({ -1, 1 }) do
			local x = side * (R + 4)
			local py = mk(m, Vector3.new(4, 0.2, 4), DARK, Enum.Material.Metal, 0, cf * CFrame.new(x, 0.1, 0))
			tw(py, 0.9, { Size = Vector3.new(4, 10, 4), CFrame = cf * CFrame.new(x, 5, 0) }, Enum.EasingStyle.Back)
			local cap = mk(m, Vector3.new(4.4, 0.5, 4.4), color, Enum.Material.Neon, 1, cf * CFrame.new(x, 10.25, 0))
			task.delay(0.8, function()
				if alive() then
					tw(cap, 0.3, { Transparency = 0.1 })
					burst(cap, color, 15)
				end
			end)
		end
		task.wait(1.1)

		-- 3) Anel monta peça por peça
		local segs = {}
		for i = 0, SEGMENTS - 1 do
			if not alive() then return end
			local a = i / SEGMENTS * 2 * math.pi
			local cx, cy = math.cos(a), math.sin(a)
			local neon = (i % 2 == 1)
			local target = cf * CFrame.new(cx * R, R + 1 + cy * R, 0) * CFrame.Angles(0, 0, a + math.pi / 2)
			local startCF = cf * CFrame.new(cx * R * 1.8 + math.random(-10, 10), R + 1 + cy * R * 1.8 + 25, math.random(-15, 15))
				* CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
			local size = neon and Vector3.new(arc, 1.4, 1.4) or Vector3.new(arc, 2.4, 2.4)
			local p = mk(m, size, neon and color or DARK, neon and Enum.Material.Neon or Enum.Material.Metal, 1, startCF)
			table.insert(segs, { part = p, neon = neon })
			local t = tw(p, 0.7, { CFrame = target, Transparency = 0 }, Enum.EasingStyle.Back)
			t.Completed:Once(function()
				if alive() then burst(p, color, 6) end
			end)
			task.wait(BUILD_DELAY)
		end
		task.wait(0.8)
		if not alive() then return end

		-- 4) Pulso de ativação do anel
		for _, s in ipairs(segs) do
			if s.neon then
				tw(s.part, 0.25, { Color = Color3.new(1, 1, 1) }).Completed:Once(function()
					if s.part.Parent then tw(s.part, 0.5, { Color = color }) end
				end)
			end
		end
		task.wait(0.3)

		-- 5) Disco de energia + raios giratórios
		local disc = mk(m, Vector3.new(0.1, 0.1, 0.1), color, Enum.Material.Neon, 0.35,
			cf * CFrame.new(0, R + 1, 0) * CFrame.Angles(0, math.pi / 2, 0), true)
		tw(disc, 1.1, { Size = Vector3.new(0.4, D, D) }, Enum.EasingStyle.Back)
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = 45
		light.Brightness = 3
		light.Parent = disc
		local em = Instance.new("ParticleEmitter")
		em.Color = ColorSequence.new(color)
		em.LightEmission = 1
		em.Rate = 40
		em.Lifetime = NumberRange.new(1.5, 2.5)
		em.Speed = NumberRange.new(2, 6)
		em.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0) })
		em.Parent = disc

		for k = 0, 1 do
			local sp = mk(m, Vector3.new(2 * (R - 2), 0.3, 0.3), color, Enum.Material.Neon, 1, cf)
			tw(sp, 1, { Transparency = 0.5 })
			table.insert(portal.spokes, { part = sp, off = k * math.pi / 2 })
		end

		portal.disc = disc
		portal.ready = true
		shake(0.8, 0.8)
		burst(disc, color, 40)
		building = false
	end)
end

local function placePortal()
	if building then return end
	local cf = getTargetCF()
	if not cf then return end
	local idx = nextSlot
	nextSlot = 3 - nextSlot
	if portals[idx] then removePortal(portals[idx]) end
	buildPortal(idx, cf)
end

------------------------------------------------------------
-- TELEPORTE + ROTAÇÃO DOS RAIOS
------------------------------------------------------------
connect(RunService.Heartbeat, function(dt)
	for _, p in pairs(portals) do
		if p.ready and not p.dead then
			p.angle += dt * 1.6
			for _, s in ipairs(p.spokes) do
				if s.part.Parent then
					s.part.CFrame = p.cf * CFrame.new(0, R + 1, 0.1) * CFrame.Angles(0, 0, p.angle + s.off)
				end
			end
		end
	end

	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp or tick() - lastTp < TP_COOLDOWN then return end

	for idx, p in pairs(portals) do
		local other = portals[3 - idx]
		if p.ready and not p.dead and other and other.ready and not other.dead then
			local rel = p.cf:PointToObjectSpace(hrp.Position)
			local dx, dy = rel.X, rel.Y - (R + 1)
			if math.abs(rel.Z) < 3 and math.sqrt(dx * dx + dy * dy) < R - 2 then
				lastTp = tick()
				local speed = math.max(hrp.AssemblyLinearVelocity.Magnitude, 20)
				local exitPos = other.cf * Vector3.new(0, 3.5, 8)
				hrp.CFrame = CFrame.lookAt(exitPos, exitPos + other.cf.LookVector)
				hrp.AssemblyLinearVelocity = other.cf.LookVector * speed
				doFlash(COLORS[3 - idx])
				burst(other.disc, COLORS[3 - idx], 40)
				shake(0.5, 0.7)
				break
			end
		end
	end
end)

------------------------------------------------------------
-- TOOL
------------------------------------------------------------
local holoConn

local function showHolo()
	if not holo then buildHolo() end
	if holoConn then holoConn:Disconnect() end
	holoConn = RunService.RenderStepped:Connect(function()
		local cf = getTargetCF()
		if not cf then
			holo.Parent = nil
			return
		end
		setHoloColor(nextSlot)
		holo.Parent = Workspace
		holo:PivotTo(cf)
		local t = tick()
		for i, h in ipairs(holoParts) do
			h.part.Transparency = math.clamp(h.base + 0.12 * math.sin(t * 5 + i), 0, 1)
		end
		local Rr = R - 1.5
		local dy = math.sin(t * 1.8) * Rr
		holoScan.Size = Vector3.new(math.max(0.5, 2 * math.sqrt(Rr * Rr - dy * dy)), 0.4, 0.4)
		holoScan.CFrame = cf * CFrame.new(0, R + 1 + dy, 0)
	end)
end

local function hideHolo()
	if holoConn then holoConn:Disconnect() holoConn = nil end
	if holo then holo.Parent = nil end
end

local function giveTool()
	local backpack = player:WaitForChild("Backpack")
	for _, t in ipairs(backpack:GetChildren()) do
		if t.Name == "Portal" then t:Destroy() end
	end
	local tool = Instance.new("Tool")
	tool.Name = "Portal"
	tool.ToolTip = "Portal tecnológico"
	tool.RequiresHandle = false
	tool.CanBeDropped = false
	tool.Parent = backpack
	currentTool = tool

	tool.Equipped:Connect(showHolo)
	tool.Unequipped:Connect(hideHolo)
	tool.Activated:Connect(placePortal)
end

giveTool()
connect(player.CharacterAdded, function()
	hideHolo()
	task.wait(0.5)
	giveTool()
end)

_G.PortalLocalCleanup = function()
	hideHolo()
	for _, c in ipairs(conns) do c:Disconnect() end
	if currentTool then currentTool:Destroy() end
	if holo then holo:Destroy() end
	root:Destroy()
	gui:Destroy()
end
