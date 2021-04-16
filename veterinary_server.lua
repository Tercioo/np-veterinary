
local veterinaryObject = veterinaryObject

--local pointers
local GetGameTimer = GetGameTimer

    --client ask to res a player
    local resCooldown = {}
    RegisterNetEvent ("np-veterinary:requestRessplayer")
    AddEventHandler ("np-veterinary:requestRessplayer", function (playerServerId, vetNetId)
        local cooldownTime = resCooldown [vetNetId] or 0
        cooldownTime = cooldownTime + veterinaryObject.timeToRes

        if (cooldownTime > GetGameTimer()) then
            TriggerClientEvent ("np-veterinary:doRessplayer", playerServerId, false)
            return
        end

        resCooldown [vetNetId] = GetGameTimer()
        TriggerClientEvent ("np-veterinary:doRessplayer", playerServerId, true)
    end)

    --client told the server he is aiming at the veterinary
    --only happens if there's a loss gun point time (loss gun point = time of no player aiming at the veterinary)
    local vets = {}
    local latestGunPointEvent = 0
    RegisterNetEvent ("np-veterinary:tellGunPoint")
    AddEventHandler ("np-veterinary:tellGunPoint", function (vetNetId)
        local timeNow = GetGameTimer()

        --if in 10 minutes no gun point event is triggered, clear the list of veterinaries at gun point
        if (latestGunPointEvent + 600 < timeNow) then
            for vetId, _ in pairs (vets) do
                vets [vetId] = nil
            end
        end

        latestGunPointEvent = timeNow

        --store vet info
        vets [vetNetId] = timeNow
    end)

    RegisterNetEvent ("np-veterinary:queryVetIsAtGunPoint")
    AddEventHandler ("np-veterinary:queryVetIsAtGunPoint", function (vetNetId, lossGunPointTime)
        latestGunPointEvent = GetGameTimer()
        local vetGunPointTime = vets [vetNetId] or 0
        if (vetGunPointTime + lossGunPointTime > GetGameTimer()) then
           return TriggerClientEvent ("np-veterinary:answerVetIsAtGunPoint", source, true)
        else
           return TriggerClientEvent ("np-veterinary:answerVetIsAtGunPoint", source, false)
        end
    end)



