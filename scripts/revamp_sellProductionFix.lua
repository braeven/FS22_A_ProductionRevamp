--[[
Production Revamp
Production Sell Fix - Sells Goods that are still in a Production, when selling the production

Copyright (C) Achimobil, braeven, 2022

Date: 22.12.2022
Version: 1.0.0.0

Contact/Help/Tutorials:
discord.gg/gHmnFZAypk

Changelog:
1.0.0.0 @ 22.12.2022 - Initial Release

Important:.
No changes are allowed to this script without permission from Achimobil AND Braeven.
If you want to make a production with this script, look in the discord channels for tutorials/help or download the FS22_Revamp_Productions Pack for reference
Don't copy the script into a production, load the mod as a dependency!

Es dürfen an diesem Script keine Veränderungen ohne Erlaubnis von Achimobil UND Braeven gemacht werden.
Wenn du eine Produktion mit diesem Script bauen möchtest, lese dir die angepinnten Tutorials im Discord durch oder guck dir die FS22_Revamp_Productions an.
Nicht das Script in Produktionen kopieren, ladet den Mod über eine Dependency!

]]
RevampSellFix ={}

function RevampSellFix.registerOverwrittenFunctions(placeableType)
	SpecializationUtil.registerOverwrittenFunction(placeableType, "canBeSold", RevampSellFix.canBeSold)
end

PlaceableProductionPoint.registerOverwrittenFunctions = Utils.prependedFunction(PlaceableProductionPoint.registerOverwrittenFunctions, RevampSellFix.registerOverwrittenFunctions)



function RevampSellFix.registerEventListeners(placeableType)
	SpecializationUtil.registerEventListener(placeableType, "onSell", RevampSellFix)
end

PlaceableProductionPoint.registerEventListeners = Utils.prependedFunction(PlaceableProductionPoint.registerEventListeners, RevampSellFix.registerEventListeners)



function RevampSellFix:canBeSold(superFunc)
	local spec = self.spec_productionPoint
	
	spec.sellWarningText = g_i18n:getText("Revamp_ProductionNotEmpty")
	local warning = spec.sellWarningText .. "\n"

	local totalFillLevel = 0
	spec.totalFillTypeSellPrice = 0
	
	--DebugUtil.printTableRecursively(spec.productionPoint, test, 2, 3)
	for fillTypeIndex, fillLevel in pairs(spec.productionPoint.storage.fillLevels) do
		totalFillLevel = totalFillLevel + fillLevel

		if fillLevel > 0 then
			local lowestSellPrice = math.huge

			for _, unloadingStation in pairs(g_currentMission.storageSystem:getUnloadingStations()) do
				if unloadingStation.owningPlaceable ~= nil and unloadingStation.isSellingPoint and unloadingStation.acceptedFillTypes[fillTypeIndex] then
					local price = unloadingStation:getEffectiveFillTypePrice(fillTypeIndex)

					if price > 0 then
						lowestSellPrice = math.min(lowestSellPrice, price)
					end
				end
			end

			if lowestSellPrice == math.huge then
				lowestSellPrice = 0.5
			end

			local price = fillLevel * lowestSellPrice * 0.7
			local fillType = g_fillTypeManager:getFillTypeByIndex(fillTypeIndex)
			warning = string.format("%s%s (%s) - %s: %s\n", warning, fillType.title, g_i18n:formatVolume(fillLevel), g_i18n:getText("ui_sellValue"), g_i18n:formatMoney(price, 0, true, true))
			spec.totalFillTypeSellPrice = spec.totalFillTypeSellPrice + price
		end
	end

	if totalFillLevel > 0 then
		return true, warning
	end

	return true, nil
end



function RevampSellFix:onSell()
	local spec = self.spec_productionPoint
	
	--Bei wiederkaufbaren Produktionen das Lager nullen
	for fillTypeIndex, fillLevel in pairs(spec.productionPoint.storage.fillLevels) do
		if fillLevel > 0 then
			spec.productionPoint.storage.fillLevels[fillTypeIndex] = 0
		end
	end
	
	if self.isServer and spec.totalFillTypeSellPrice > 0 then
		g_currentMission:addMoney(spec.totalFillTypeSellPrice, self:getOwnerFarmId(), MoneyType.SOLD_PRODUCTS, true, true)
	end
end