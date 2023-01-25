--[[
Production Revamp
Setting File

Copyright (C) Achimobil, braeven, 2022

Date: 04.09.2022
Version: 1.0.0.1

Contact/Help/Tutorials:
discord.gg/gHmnFZAypk

Changelog:
1.0.0.0 @ 22.08.2022 - Initial Release
1.0.0.1 @ 04.09.2022 - ÜbersetzungsVariablen angepasst

Important:.
No changes are allowed to this script without permission from Achimobil AND Braeven.
If you want to make a production with this script, look in the discord channels for tutorials/help or download the FS22_Revamp_Productions Pack for reference
Don't copy the script into a production, load the mod as a dependency!

Es dürfen an diesem Script keine Veränderungen ohne Erlaubnis von Achimobil UND Braeven gemacht werden.
Wenn du eine Produktion mit diesem Script bauen möchtest, lese dir die angepinnten Tutorials im Discord durch oder guck dir die FS22_Revamp_Productions an.
Nicht das Script in Produktionen kopieren, ladet den Mod über eine Dependency!

]]


function Revamp.registerOverwrittenFunctions(placeableType)
  SpecializationUtil.registerOverwrittenFunction(placeableType, "canBeSold", Revamp.canBeSold)
end

PlaceableProductionPoint.registerOverwrittenFunctions = Utils.prependedFunction(PlaceableProductionPoint.registerOverwrittenFunctions, Revamp.registerOverwrittenFunctions)



function Revamp.registerEventListeners(placeableType)
	SpecializationUtil.registerEventListener(placeableType, "onSell", PlaceableSilo)
end

PlaceableProductionPoint.registerEventListeners = Utils.prependedFunction(PlaceableProductionPoint.registerEventListeners, Revamp.registerEventListeners)



function Revamp:canBeSold(superFunc)
	local spec = self.spec_productionPoint

	--local warning = spec.sellWarningText .. "\n"
  --revamp text
	local totalFillLevel = 0
	spec.totalFillTypeSellPrice = 0

	for fillTypeIndex, fillLevel in pairs(spec.storages[1].fillLevels) do
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

			local price = fillLevel * lowestSellPrice * PlaceableSilo.PRICE_SELL_FACTOR
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


function PlaceableSilo:onSell()
	local spec = self.spec_productionPoint

	if self.isServer and spec.totalFillTypeSellPrice > 0 then
		g_currentMission:addMoney(spec.totalFillTypeSellPrice, self:getOwnerFarmId(), MoneyType.HARVEST_INCOME, true, true)
	end
end