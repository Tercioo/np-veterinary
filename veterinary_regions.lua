


--where's the veterinary location
--vet npc is spawned when the player enters the area

veterinaryObject.veterinaryRegion = {
	name = "VeterinaryRegion1",
	worldHeight = 114.33435821533,
	regionHeight = 30,
	regionEnterCallback = veterinaryObject.OnEnterRegion,
	regionLeaveCallback = veterinaryObject.OnLeaveRegion,
	isNetwork = true,
	isPermanent = true,

	squareSize = 84,
	regionCoords = {
		[16] = {13},
	}
}