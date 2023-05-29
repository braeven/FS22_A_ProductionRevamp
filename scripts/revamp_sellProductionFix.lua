--[[
Production Revamp
Production Sell Fix - Sells Goods that are still in a Production, when selling the production

Copyright (C) Achimobil, braeven, 2022

Date: 29.05.2023
Version: 1.1.0.0

Contact/Help/Tutorials:
discord.gg/gHmnFZAypk

Changelog:
1.0.0.0 @ 22.12.2022 - Initial Release
1.1.0.0 @ 29.05.2023 - Added Support for Combination Silo + ProductionPoint

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

	if self.spec_silo ~= nil then
		local spec2 = self.spec_silo
		spec2.totalFillTypeSellPrice = 0

		for fillTypeIndex, fillLevel in pairs(spec2.storages[1].fillLevels) do
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
				spec2.totalFillTypeSellPrice = spec2.totalFillTypeSellPrice + price
			end
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

	if spec.totalFillTypeSellPrice ~= nil then
		if self.isServer and spec.totalFillTypeSellPrice > 0 then
			g_currentMission:addMoney(spec.totalFillTypeSellPrice, self:getOwnerFarmId(), MoneyType.SOLD_PRODUCTS, true, true)
			spec.totalFillTypeSellPrice = nil
		end
	end
	if self.spec_silo ~= nil then
		if self.spec_silo.totalFillTypeSellPrice ~= nil then
			if self.isServer and self.spec_silo.totalFillTypeSellPrice > 0 then
				g_currentMission:addMoney(self.spec_silo.totalFillTypeSellPrice, self:getOwnerFarmId(), MoneyType.HARVEST_INCOME, true, true)
				self.spec_silo.totalFillTypeSellPrice = nil
			end
		end
	end
end



function RevampSellFix:onSellSilo()
	local spec = self.spec_silo

	if spec.totalFillTypeSellPrice ~= nil then
		if self.isServer and spec.totalFillTypeSellPrice > 0 then
			g_currentMission:addMoney(spec.totalFillTypeSellPrice, self:getOwnerFarmId(), MoneyType.HARVEST_INCOME, true, true)
			spec.totalFillTypeSellPrice = nil
		end
	end
	if self.spec_productionPoint~=nil then
		if self.spec_productionPoint.totalFillTypeSellPrice~=nil then
			if self.isServer and self.spec_productionPoint.totalFillTypeSellPrice > 0 then
				g_currentMission:addMoney(self.spec_productionPoint.totalFillTypeSellPrice, self:getOwnerFarmId(), MoneyType.SOLD_PRODUCTS, true, true)
				self.spec_productionPoint.totalFillTypeSellPrice = nil
			end
		end
	end
end

PlaceableSilo.onSell = Utils.overwrittenFunction(PlaceableSilo.onSell, RevampSellFix.onSellSilo)



function RevampSellFix:canBeSoldSilo(superFunc)
	local spec = self.spec_silo

	if spec.storagePerFarm then
		return false, nil
	end

	local warning = spec.sellWarningText .. "\n"
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

	if self.spec_productionPoint ~= nil then
		local spec2 = self.spec_productionPoint
		spec2.totalFillTypeSellPrice = 0

		for fillTypeIndex, fillLevel in pairs(spec2.productionPoint.storage.fillLevels) do
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
				spec2.totalFillTypeSellPrice = spec2.totalFillTypeSellPrice + price
			end
		end
	end

	if totalFillLevel > 0 then
		return true, warning
	end

	return true, nil
end

PlaceableSilo.canBeSold = Utils.overwrittenFunction(PlaceableSilo.canBeSold, RevampSellFix.canBeSoldSilo)