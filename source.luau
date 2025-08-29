--!strict

_G.globals = {
	fov = 90,
	targetPart = "Head", -- Head, Torso, Left Arm, Right Arm, Left Leg, Right Leg
	visibleCheck = false,
	teamCheck = false,
}

type _globals = {
	fov: number,
	targetPart: string,
	visibleCheck: boolean,
	teamCheck: boolean,
}

local globals = (_G.globals or {}) :: _globals

type R6Character = Model & {
	Head: BasePart & {
		face: Decal,
	},
	HumanoidRootPart: BasePart & {
		RootJoint: Motor6D,
	},
	Torso: BasePart & {
		Neck: Motor6D,
		Left_Shoulder: Motor6D,
		Right_Shoulder: Motor6D,
		Left_Hip: Motor6D,
		Right_Hip: Motor6D,
	},
	["Left Arm"]: BasePart,
	["Right Arm"]: BasePart,
	["Left Leg"]: BasePart,
	["Right Leg"]: BasePart,

	Humanoid: Humanoid & {
		Animator: Animator?,
		HumanoidDescription: HumanoidDescription?,
	},

	[string]: Accessory | BasePart | Humanoid | Motor6D | Model | Folder | Instance,
}

type PlayerInstance = {
	instance: Player & {
		PlayerGui: PlayerGui,
		PlayerScripts: PlayerScripts,
		Backpack: Backpack,
	},
	character: R6Character?,
	OnCharacterAdded: (bind: (character: Model) -> nil) -> RBXScriptConnection,
}
local PlayersService = game:GetService("Players")
local Player = {} :: PlayerInstance
do
	local playerInstance = PlayersService.LocalPlayer
	playerInstance.CharacterAdded:Connect(function(newCharacter: Model)
		Player.character = newCharacter :: R6Character
		(newCharacter:WaitForChild("Humanoid") :: Humanoid).Died:Connect(function()
			Player.character = nil
		end)
	end)

	function Player.OnCharacterAdded(bind)
		return playerInstance.CharacterAdded:Connect(bind)
	end
end

local Players: { Player } = {}
do
	-- local playersIndex: { [Player]: number } = {}
	local function InsertPlayer(player: Player)
		table.insert(Players, player)
		-- playersIndex[player] = #Players
	end

	PlayersService.PlayerRemoving:Connect(function(player: Player)
		local i = table.find(Players, player)
		if not i then
			return
		end
		table.remove(Players, i)
	end)

	PlayersService.PlayerAdded:Connect(InsertPlayer)
	for _, v: Player in PlayersService:GetPlayers() do
		if v == (Player.instance :: Player) then
			continue
		end

		task.spawn(InsertPlayer, v)
	end
end

local camera = workspace.CurrentCamera
local cameraViewportSize = camera.ViewportSize
local function WorldToScreen(position: Vector3): (Vector2, boolean) -- camera.WorldToScreenPoint no no no
	local cameraPosition = camera.CFrame.Position
	local dir = (position - cameraPosition).Unit
	local distance = (position - cameraPosition).Magnitude

	local scaleFactor = math.tan(math.rad(camera.FieldOfView) / 2) * distance
	local zFactor = dir.Z + 0.0001

	local viewportSizeX = cameraViewportSize.X
	local viewportSizeY = cameraViewportSize.Y
	local screenX = dir.X * scaleFactor / zFactor * (viewportSizeX / 2) + (viewportSizeX / 2)
	local screenY = -dir.Y * scaleFactor / zFactor * (viewportSizeY / 2) + (viewportSizeY / 2)
	return Vector2.new(screenX, screenY),
		screenX >= 0 and screenX <= viewportSizeX and screenY >= 0 and screenY <= viewportSizeY
end

local UserInputService = game:GetService("UserInputService")
local function GetAimingPlayer(): BasePart?
	local bestDist: number, bestTargetPart: BasePart
	local playerInstance = Player.instance
	for i, player in Players do
		if globals.teamCheck and player.Team == playerInstance.Team then
			continue
		end

		local playerCharacter = player.Character :: R6Character?
		if not playerCharacter then
			continue
		end

		local playerHumanoid = playerCharacter:FindFirstChild("Humanoid") :: Humanoid?
		if not playerHumanoid or playerHumanoid.Health <= 0 then
			continue
		end

		local targetPart = (
			globals.targetPart and playerCharacter:FindFirstChild(globals.targetPart)
			or playerCharacter:FindFirstChild("HumanoidRootPart")
		) :: BasePart?
		if not targetPart then
			continue
		end

		local screenPosition, onScreen = WorldToScreen(targetPart.Position)
		if globals.visibleCheck and not onScreen then
			continue
		end

		local distance = (UserInputService:GetMouseLocation() - screenPosition).Magnitude
		if distance <= (bestDist or globals.fov or 0) then
			bestDist = distance
			bestTargetPart = targetPart
		end
	end
	return bestTargetPart
end

local old
local function hkFireInstantHit(self: Workspace?, ray: Ray, ignoreList: { Instance }, raycastParams: RaycastParams)
	if self ~= workspace then
		return old(self, ray, ignoreList, raycastParams)
	end

	local targetPart = GetAimingPlayer()
	if targetPart then
		local origin = ray.Origin
		local direction = (targetPart.Position - origin).Unit * 1000
		local newRay = Ray.new(origin, direction)

		return old(self, newRay, ignoreList, raycastParams)
	end
	return old(self, ray, ignoreList, raycastParams)
end

old = hookmetamethod(game, "__namecall", newcclosure(hkFireInstantHit))
