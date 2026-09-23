--!strict
-- ProfileStore owns persistence. We only wrap session lifecycle so services never talk to DataStore directly.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local ProfileStore = require(script.Parent.Packages.ProfileStore)

local CURRENT_SCHEMA = GameConfig.Data.SchemaVersion

export type Profile = {
	Data: Types.PlayerSave,
	Reconcile: (self: Profile) -> (),
	EndSession: (self: Profile) -> (),
	Save: (self: Profile) -> (),
	IsActive: (self: Profile) -> boolean,
	AddUserId: (self: Profile, userId: number) -> (),
	OnSessionEnd: { Connect: (self: any, listener: () -> ()) -> () },
}

local PlayerData = {}
local started = false
local store: any = nil
local cache: { [Player]: Profile } = {}
local loadedListeners: { (Player, Types.PlayerSave) -> () } = {}

local function defaultSave(): Types.PlayerSave
	return {
		schemaVersion = CURRENT_SCHEMA,
		coins = 0,
		aircraftTier = 1,
		pets = {},
		upgrades = { perchSlots = 0, incubator = 0, launchPad = 0, vault = 0 },
		passes = { x2Coins = false, fastHatch = false, bigVault = false, skyCrew = false },
		stats = { runs = 0, eggsDelivered = 0, eggsLost = 0, eggsStolen = 0, eggsStolenFromMe = 0 },
		meta = {
			firstJoinUnix = 0,
			lastSeenUnix = 0,
			streakDays = 0,
			ascensions = 0,
			lastPurchaseId = nil,
			luckyFeatherUntilUnix = 0,
		},
	}
end

local MIGRATIONS: { [number]: (Types.PlayerSave) -> () } = {}

local function migrate(data: any, player: Player): boolean
	local version = data.schemaVersion
	if typeof(version) ~= "number" then
		version = 0
	end
	if version > CURRENT_SCHEMA then
		player:Kick("Your data is from a newer version. Rejoin after an update.")
		return false
	end
	while version < CURRENT_SCHEMA do
		local step = MIGRATIONS[version]
		if step then
			step(data)
		end
		version += 1
		data.schemaVersion = version
	end
	data.schemaVersion = CURRENT_SCHEMA
	return true
end

function PlayerData.get(player: Player): Types.PlayerSave?
	local profile = cache[player]
	if profile == nil then
		return nil
	end
	return profile.Data
end

function PlayerData.saveNow(player: Player)
	local profile = cache[player]
	if profile and profile:IsActive() then
		profile:Save()
	end
end

function PlayerData.onLoaded(listener: (Player, Types.PlayerSave) -> ())
	table.insert(loadedListeners, listener)
	for player, profile in cache do
		listener(player, profile.Data)
	end
end

local function loadPlayer(player: Player)
	if store == nil then
		return
	end
	local profile = store:StartSessionAsync("Player_" .. player.UserId, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})
	if profile == nil then
		player:Kick("Your data is busy on another server. Rejoin in a moment.")
		return
	end
	profile:AddUserId(player.UserId)
	if not migrate(profile.Data, player) then
		profile:EndSession()
		return
	end
	profile:Reconcile()
	if profile.Data.meta.firstJoinUnix == 0 then
		profile.Data.meta.firstJoinUnix = os.time()
	end
	profile.OnSessionEnd:Connect(function()
		cache[player] = nil
		if player.Parent == Players then
			player:Kick("Your data session ended. Rejoin.")
		end
	end)
	cache[player] = profile
	for _, listener in loadedListeners do
		listener(player, profile.Data)
	end
end

function PlayerData.start()
	if started then
		return
	end
	started = true
	store = ProfileStore.New(GameConfig.Data.StoreName, defaultSave())
	if ProfileStore.SetConstant then
		ProfileStore.SetConstant("AUTO_SAVE_PERIOD", GameConfig.Data.AutosaveSeconds)
	end
	Players.PlayerAdded:Connect(loadPlayer)
	for _, player in Players:GetPlayers() do
		task.spawn(loadPlayer, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local profile = cache[player]
		if profile then
			profile.Data.meta.lastSeenUnix = os.time()
			profile:EndSession()
			cache[player] = nil
		end
	end)
end

return PlayerData
