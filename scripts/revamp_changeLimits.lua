--[[
Production Revamp
Change Production/Pallet Limits
Changes the Production and the Pallets Limits to 180 / infinite. Be warned, the game can slow down from to many objects.

Copyright (C) braeven, 2022

Author: braeven

Version: 1.1.1.1
Date: 19.12.2022
]]

SlotSystem.NUM_OBJECT_LIMITS = {
	[SlotSystem.LIMITED_OBJECT_BALE] = {
		[PlatformId.WIN] = math.huge,
		[PlatformId.MAC] = math.huge,
		[PlatformId.PS4] = 200,
		[PlatformId.PS5] = 200,
		[PlatformId.XBOX_ONE] = 200,
		[PlatformId.XBOX_SERIES] = 200,
		[PlatformId.IOS] = 100,
		[PlatformId.ANDROID] = 100,
		[PlatformId.SWITCH] = 100,
		[PlatformId.GGP] = 200
	},
	[SlotSystem.LIMITED_OBJECT_PALLET] = {
		[PlatformId.WIN] = math.huge,
		[PlatformId.MAC] = math.huge,
		[PlatformId.PS4] = 50,
		[PlatformId.PS5] = 50,
		[PlatformId.XBOX_ONE] = 50,
		[PlatformId.XBOX_SERIES] = 50,
		[PlatformId.IOS] = 50,
		[PlatformId.ANDROID] = 50,
		[PlatformId.SWITCH] = 50,
		[PlatformId.GGP] = 50
	}
}
ProductionChainManager.NUM_MAX_PRODUCTION_POINTS = 180
FillTypeManager.SEND_NUM_BITS = 9
print("Production Revamp: Changed Production(180), Pallet(unlimited) and FillType(512) Limit")
