

local npt
local tooltipObject
local veterinaryObject = veterinaryObject

--local pointers
local unpack = table.unpack
local floor = math.floor
local GetPlayerPed = GetPlayerPed
local GetEntityCoords = GetEntityCoords
local random = math.random
local randomSeed = math.randomseed
local TriggerServerEvent = TriggerServerEvent
local DoesEntityExist = DoesEntityExist

local _DEBUG = false

--npc location
local npcLocation = veterinaryObject.npcLocation

--set in veterinary_regions.lua
local vetRegionName = veterinaryObject.vetRegionName

--animations
local cowardAnimation1 = veterinaryObject.cowardAnimation1
local cellphoneAnimation1 = veterinaryObject.cellphoneAnimation1
local medicresAnimation1 = veterinaryObject.medicresAnimation1

--how many time in ms it takes to res the player
local timeToRes = veterinaryObject.timeToRes

--after X seconds without the player aiming, it'll check if other players are aiming and reset the timer
local lossGunPointTime = veterinaryObject.lossGunPointTime or (timeToRes / 1000 + 2)

--helpers
local isAtGunPoint = false --store if the player is pointing a gun
local timeElapsed = 0 --amount of time elapsed within the gun point loop
local currentAnimation = ""
local lossGunPointTimeMs = lossGunPointTime * 1000

--veterinary ped settings
local veterinaryPedSettings = {
	type = 20, --paramedic
	hash = -1306051250, --regular doctor
	loc = npcLocation,
	heading = 90.0,
	network = false,
	thisScriptCheck = false,
}

--trigered aniamation by the playerAnimations function
local vetPlayAnim = function (anim, blendInSpeed, blendOutSpeed, duration, flag)
	if (anim == "callcops") then --call cops
		local cellphoneDict, cellphoneAnim = unpack (cellphoneAnimation1)
		currentAnimation = cellphoneAnimation1
		npt.PlayAnimationNetworked (veterinaryObject.netId, cellphoneDict, cellphoneAnim, blendInSpeed, blendOutSpeed, duration, flag)

	elseif (anim == "coward") then --coward
		local cowardDict, cowardAnim = unpack (cowardAnimation1)
		currentAnimation = cowardAnimation1
		npt.PlayAnimationNetworked (veterinaryObject.netId, cowardDict, cowardAnim, blendInSpeed, blendOutSpeed, duration, flag)

	elseif (anim == "medicres") then --medic res
		local medicresDict, medicresAnim = unpack (medicresAnimation1)
		currentAnimation = medicresAnimation1
		npt.PlayAnimationNetworked (veterinaryObject.netId, medicresDict, medicresAnim, blendInSpeed, blendOutSpeed, duration, flag)
	end
end

--@no-pixel
--when a gun is pointed to the ped, it calls the police immediately
local callPolice = function()
	--todo call the police
end

--@no-pixel
--server told to this player to ressurect
RegisterNetEvent("np-veterinary:doRessplayer")
AddEventHandler("np-veterinary:doRessplayer", function(canRes)
	local playerPed = GetPlayerPed(-1)
	local playerPedLocation = GetEntityCoords(playerPed)

	if (canRes) then
		NetworkResurrectLocalPlayer(playerPedLocation.x, playerPedLocation.y, playerPedLocation.z + 1, 90, true, false)
		SetPlayerInvincible(playerPed, false)
		ClearPedBloodDamage(playerPed)
		SetEntityHealth(playerPed, GetPedMaxHealth (playerPed) / 2)
		SetEntityCoords(playerPed, playerPedLocation.x, playerPedLocation.y, playerPedLocation.z + 1)
	else
		print ("^3np-veterinary (debug): 0x84")
	end
end)

--when the timer to res is finished, ask the server a res
local finishedResTime = function(taskHandleId, veterinaryPed, deadPlayer)
	if (not DoesEntityExist(veterinaryObject.pedId)) then
		print ("^3np-veterinary (debug): 0x5C")
		return
	end

	--get the nearest dead player
	local deadPlayer, distance = npt.GetNearestDeadPlayerFromCoords(npcLocation)
	if (deadPlayer and distance < 20) then
		local playerServerId = GetPlayerServerId(deadPlayer)
		if (playerServerId) then
			--ask the server to ressurect the player dead nearby
			TriggerServerEvent ("np-veterinary:requestRessplayer", playerServerId, veterinaryObject.netId)
		end
	end

	--finish the res
	veterinaryObject.cancelRes()
end

--check if the vet is already playing an animation, this means it is already in use
local isPlayingAnimations = function (veterinaryPed)
	local cowardDict, cowardAnim = unpack (cowardAnimation1)
	if (IsEntityPlayingAnim(veterinaryPed, cowardDict, cowardAnim, 3)) then
		return true
	end

	local cellphoneDict, cellphoneAnim = unpack (cellphoneAnimation1)
	if (IsEntityPlayingAnim(veterinaryPed, cellphoneDict, cellphoneAnim, 3)) then
		return true
	end

	local medicresDict, medicresAnim = unpack (medicresAnimation1)
	if (IsEntityPlayingAnim(veterinaryPed, medicresDict, medicresAnim, 3)) then
		return true
	end
end

--schedule animation at random
local playAnimations = function()
	--start with a coward animation
	npt.SetTimeout (random (250, 600), vetPlayAnim, "coward", 6.0, 2.0, -1, 1)

	--random call cops after the initial coward
	randomSeed (GetGameTimer())
	local randomTime = random (1500, 2500)
	npt.SetTimeout(randomTime, vetPlayAnim, "callcops", 6.0, 2.0, -1, 1) --calling cops

	--add another coward animation at random
	if (random (0, 1) == 0) then
		local newDelay = random (randomTime + 3000, randomTime + 4500)
		randomTime = randomTime + newDelay
		npt.SetTimeout(newDelay, vetPlayAnim, "coward", 6.0, 2.0, -1, 1) --coward
	end

	--finishes with the medic healing animation
	local newDelay = random (randomTime + 3000, randomTime + 4500) --medic
	randomTime = randomTime + newDelay
	npt.SetTimeout(newDelay, vetPlayAnim, "medicres", 3.0, 2.0, -1, 1)
end

local refreshAnimation = function (veterinaryPed)
	if (type (currentAnimation) == "table") then
		if (not isPlayingAnimations (veterinaryPed)) then
			local aDict, aAnim = unpack (currentAnimation)
			npt.PlayAnimationNetworked (veterinaryObject.netId, aDict, aAnim, 6.0, 2.0, -1, 1)
		end
	end
end

--called when the player has the vet at gun point
local playerGunPointToVetCallback = function (isGunPoint, isFinished, veterinaryPed)

	if (isGunPoint and not DoesEntityExist (veterinaryPed)) then
		print ("^3np-veterinary (debug): 0x1D") --is at gun point but the veterynatyPed doesn't exists?
		return
	end

	if (isGunPoint) then
		--reset the counter of time not aiming at the veterinary
		veterinaryObject.lossGunPointTime = 0
		--set the veterinary ped just to be safe
		veterinaryObject.pedId = veterinaryPed
		veterinaryObject.netId = PedToNet (veterinaryPed)

		--check if the player just pointed the gun on the vet
		if (not isAtGunPoint) then
			--check if the veterinary is busy
			if (isPlayingAnimations (veterinaryPed)) then
				return
			end

			isAtGunPoint = true

			--call the cops
			callPolice()

			--player animations
			playAnimations()

			--create a res task even if there's no dead player nearby
			veterinaryObject.ResTimerHandle = npt.CreateTask (finishedResTime, timeToRes, false, true, false, false, "Veterinary Res Timer", veterinaryPed, deadPlayer)

			--reset time elapsed
			timeElapsed = 0

			if (_DEBUG) then
				--make a progress bar using the tooltip system
				tooltipObject.ClearTooltip()
				tooltipObject.SetFollowEntityBone (veterinaryPed, 31086, 0.0, 0.0, 0.25)
				tooltipObject.AddLine ("debug - ressing time", "0", false, false, 14, {}, {"width: 200", "height: 14", "text-align: center"})
				tooltipObject.AddProgressBar (0, {126, 255, 212, 110}, true)
				tooltipObject.SetTableCSS ({
					"font-size: 16px;",
					"padding: 1px;",
					"background-color: rgba(29, 30, 40, 0.634);",
					"border: 1px outset;",
					"border-color: #000000;",
					"box-shadow: 0px 0px 4px #1000009D;",
					"border-radius: 0px;",
				})

				if (npt.IsPlayerInsideRegion (veterinaryObject.regionHandle)) then
					tooltipObject.ShowTooltip()
				end
			end
		end

		--refresh the server telling the player still has a gunpoint at the veterinary
		--only needed if there's a loss gun point time (loss gun point = time of no player aiming at the veterinary)
		if (lossGunPointTimeMs < timeToRes) then
			randomSeed (GetGameTimer())
			if (random (0, 2) == 0) then
				--don't tell so often
				TriggerServerEvent ("np-veterinary:tellGunPoint", veterinaryObject.netId)
			end
		end

		--update progress bar
		timeElapsed = timeElapsed + 1
		if (_DEBUG) then
			tooltipObject.SetProgressBarPercent (1, timeElapsed / (timeToRes/1000) * 100)
			tooltipObject.SetText(1, false, floor(timeElapsed) .. "s   (" .. floor(timeElapsed / (timeToRes/1000) * 100) .. "%)")
		end

		refreshAnimation (veterinaryObject.pedId)

	else
		--if the vet isn't at gun point, there's no reason to check gun point loss
		if (not isAtGunPoint) then
			return
		end

		--update progress bar
		timeElapsed = timeElapsed + 1
		if (_DEBUG) then
			tooltipObject.SetProgressBarPercent (1, timeElapsed / (timeToRes/1000) * 100)
			tooltipObject.SetText(1, false, floor(timeElapsed) .. "s   (" .. floor(timeElapsed / (timeToRes/1000) * 100) .. "%)")
		end

		refreshAnimation (veterinaryObject.pedId)

		--debug: won't lose gunpoint
		veterinaryObject.lossGunPointTime = 0

		--player isn't aiming at the vet
		--increase the time that this player isn't aiming at the veterinary
		veterinaryObject.lossGunPointTime = (veterinaryObject.lossGunPointTime and veterinaryObject.lossGunPointTime + 1) or 1

		--check if the time not aiming to vet elapsed $lossGunPointTime
		if (veterinaryObject.lossGunPointTime > lossGunPointTime) then
			--check if any other player nearby is aiming
			local allPlayersInVetRegion = npt.GetAllPlayersInRegion (veterinaryObject.regionHandle)
			for i = 1, #allPlayersInVetRegion do
				--check if this player has gun point to vet
				if (npt.PlayerGunPointAtPed (allPlayersInVetRegion [i], veterinaryObject.pedId)) then
					veterinaryObject.lossGunPointTime = 0
					return
				end
			end

			--no gun point detected from any player, ask the server
			TriggerServerEvent ("np-veterinary:queryVetIsAtGunPoint", veterinaryObject.netId, lossGunPointTime)
		end
	end
end

--receives the answer from server is there's a player pointing a gun
RegisterNetEvent ("np-veterinary:answerVetIsAtGunPoint")
AddEventHandler	("np-veterinary:answerVetIsAtGunPoint", function (isAtGunPoint)
	if (not isAtGunPoint) then
		veterinaryObject.cancelRes()
	else
		veterinaryObject.lossGunPointTime = 0
	end
end)

--no player is pointing the gun at the npc for more than $lossGunPointTime seconds
veterinaryObject.cancelRes = function()
	isAtGunPoint = false
	timeElapsed = 0

	if (veterinaryObject.ResTimerHandle) then
		npt.CancelTask (veterinaryObject.ResTimerHandle)
		veterinaryObject.ResTimerHandle = nil
	end

	vetPlayAnim("coward", 6.0, 2.0, -1, 1)
	npt.SetTimeout(random (4500, 7000), npt.SetPedStationary, veterinaryObject.pedId, veterinaryObject.netId)

	tooltipObject.HideTooltip()
end

veterinaryObject.vetReady = function (veterinaryPed, veterinaryNetId)
	--save vet ids
	veterinaryObject.pedId = veterinaryPed
	veterinaryObject.netId = veterinaryNetId

	--set the npc to not move
	npt.SetPedStationary (veterinaryPed, veterinaryNetId)

	--start an async task to know if veterinary is at gun point
	--when the npc is at gun point it'll call 'playerGunPointToVetCallback' function
	veterinaryObject.gunPointHandle = npt.PlayerGunPointAtPedAsync (playerGunPointToVetCallback, PlayerId(), veterinaryPed)

	--load animation async
	npt.LoadAnimationAsync (function()end, cowardAnimation1 [1])
	npt.LoadAnimationAsync (function()end, cellphoneAnimation1 [1])
	npt.LoadAnimationAsync (function()end, medicresAnimation1 [1])
end

veterinaryObject.OnEnterRegion = function (regionHandle)
	--check the location if the veterinary already exists in a 1 meter radius of its location
	local veterinaryPed = npt.CheckPedExistsAtLocation (npcLocation.x, npcLocation.y, npcLocation.z, 1.0)

	if (DoesEntityExist (veterinaryPed) and IsEntityDead (veterinaryPed)) then
		DeleteEntity (veterinaryPed)
		veterinaryPed = nil
	end

	if (not DoesEntityExist (veterinaryPed)) then
		npt.CreatePedAsyncWithNetwork (veterinaryObject.vetReady, veterinaryPedSettings)
	else
		--debug
		--npt.CreatePedAsyncWithNetwork (veterinaryObject.vetReady, veterinaryPedSettings)
		veterinaryObject.vetReady (veterinaryPed, NetworkGetNetworkIdFromEntity (veterinaryPed))
	end
end

veterinaryObject.OnLeaveRegion = function (regionHandle)

	--check if there's any other player inside the region
	if (#npt.GetAllPlayersInRegion (veterinaryObject.regionHandle) < 1) then

		--stop the check for gun point if any
		npt.CancelGunPointCheck (veterinaryObject.gunPointHandle)
		veterinaryObject.gunPointHandle = nil

		if (veterinaryObject.ResTimerHandle) then
			npt.CancelTask (veterinaryObject.ResTimerHandle)
			veterinaryObject.ResTimerHandle = nil
		end

		veterinaryObject.lossGunPointTime = nil
		timeElapsed = 0

		isAtGunPoint = false

		if (DoesEntityExist (veterinaryObject.pedId)) then
			DeleteEntity (veterinaryObject.pedId)
		end
	end

	tooltipObject.HideTooltip()
end


--load the toolbox
Citizen.CreateThread (function()
	Wait (50)
	npt = exports["np-toolbox"].GetNoPixelToolbox()
	tooltipObject = exports["np-tooltips"].GetTooltip()
	--create the veterinary region
	veterinaryObject.regionHandle = npt.CreateRegion (veterinaryObject.veterinaryRegion)
end)
