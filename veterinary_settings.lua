
veterinaryObject = {}

--npc location
veterinaryObject.npcLocation = vector3 (1393.622, 1141.565, 114.4433) --where the veterinary is

--set in veterinary_regions.lua
veterinaryObject.vetRegionName = "VeterinaryRegion1" 

--animations
veterinaryObject.cowardAnimation1 = {"missheist_agency2ahands_up", "handsup_anxious"}
veterinaryObject.cellphoneAnimation1 = {"cellphone@", "cellphone_call_listen_base"}
veterinaryObject.medicresAnimation1 = {"amb@medic@standing@kneel@base", "base"}

--how many time in ms it takes to res the player
veterinaryObject.timeToRes = 60000

--after X seconds without the player aiming, it'll check if other players are aiming, if there's another it won't cancel the res
veterinaryObject.lossGunPointTime = false --vfalse makes this feature disabled (the vet will continue res even no one is pointing a gun to him)