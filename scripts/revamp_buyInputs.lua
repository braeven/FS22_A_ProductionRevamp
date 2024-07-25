--[[
Production Revamp
Revamp Buy Inputs 

Copyright (C) braeven, Achimobil, 2022

Author: braeven, Achimobil

Date: 19.12.2022
Version: 1.2.1.1

Contact/Help/Tutorials:
discord.gg/gHmnFZAypk


Changelog:
1.0.0.0 @ 09.07.2022 - Moved buy Inputs Stuff out of the main-file into new file
1.1.0.0 @ 27.09.2022 - Kompabilität mit PnH
1.2.0.0 @ 17.10.2022 - Einstellbarer Kauffaktor
1.2.1.0 @ 08.11.2022 - Schreibfehler behoben
1.2.1.1 @ 19.12.2022 - Code Cleanup

Important:.
No changes are allowed to this script without permission from Braeven.
If you want to make a production with this script, look in the documentation, discord channels for tutorials/help or download the FS22_Revamp_Productions Pack for reference
Don't copy the script into a production, load the mod as a dependency!

Es dürfen an diesem Script keine Veränderungen ohne Erlaubnis von Braeven gemacht werden.
Wenn du eine Produktion mit diesem Script bauen möchtest, lese dir die Dokumentation, die angepinnten Tutorials im Discord durch oder guck dir die FS22_Revamp_Productions an.
Nicht das Script in Produktionen kopieren, ladet den Mod über eine Dependency!

]]

source(g_currentModDirectory .. "scripts/events/ProductionPointBuyInputEvent.lua")

RevampBuyInput = {}
--Production Revamp: MenüButton für Buy-Input hinzugefügt
function RevampBuyInput:updateMenuButtons(superFunc)
	local isProductionListActive = self.productionList == FocusManager:getFocusedElement()
	local fillType, isInput = self:getSelectedStorageFillType()
	local production, productionPoint = self:getSelectedProduction()
	local buyAllowedForUser = RevampSettings:IsBuyAllowedForUser(productionPoint)

	-- Pump'n'Hoses Produktionen ignorieren
	if productionPoint:isa(SandboxProductionPoint) or (productionPoint.owningPlaceable.isSandboxPlaceable ~= nil and productionPoint.owningPlaceable:isSandboxPlaceable()) then
		return
	end

	if not isProductionListActive and fillType ~= FillType.UNKNOWN and isInput and buyAllowedForUser then
		table.insert(self.menuButtonInfo, {
			profile = "buttonOk",
			inputAction = InputAction.MENU_CANCEL,
			text = self.i18n:getText("Revamp_BuyInputButton"),
			callback = function()
				self:buyInputMenu()
			end
		})
		self:setMenuButtonInfoDirty()
	end
end

InGameMenuProductionFrame.updateMenuButtons = Utils.appendedFunction(InGameMenuProductionFrame.updateMenuButtons, RevampBuyInput.updateMenuButtons)


--Production Revamp: Callback um Inputs zu kaufen
function InGameMenuProductionFrame:buyInputMenu()
	local production, productionPoint = self:getSelectedProduction()
	local fillType = self:getSelectedStorageFillType()
	local fillTypeName = g_fillTypeManager:getFillTypeByIndex(fillType).title
	local allowBuying = true
	local buyFactor = 2
	--Production Revamp: Added option to disable buying inputs
	for x, rProductionPoint in ipairs(productionPoint.productions) do
		for index, item in ipairs(rProductionPoint.inputs) do
			if item.type == fillType then
				if item.allowBuying then
					if item.buyFactor ~= buyFactor then
						buyFactor = item.buyFactor
					end
				else
					allowBuying = false
				end
			end
		end
	end
	if allowBuying then
		local missingFillLevel = self.selectedProductionPoint.storage:getFreeCapacity(fillType)
		local difficultyMultiplier = EconomyManager.getPriceMultiplier()
		local pricePerLiter = g_fillTypeManager:getFillTypeByIndex(fillType).pricePerLiter	* buyFactor * difficultyMultiplier
		local fillTypeDesc = g_fillTypeManager:getFillTypeByIndex(fillType)

		--Production Revamp: BuyVolume definieren
		local buyVolume1 = 1000
		local buyVolume2 = 10000
		local buyVolume3 = 50000
		local buyVolume4 = math.floor(missingFillLevel, 1)

		local selectableOptions = {}
		local options = {}

		local farmMoney = g_currentMission:getMoney(self.ownerFarmId)

		if missingFillLevel > buyVolume1 then
			local price = math.floor(pricePerLiter * buyVolume1, 1)
			local fillTypeText = RevampHelper:formatVolume(buyVolume1, 0, fillTypeDesc.unitShort).. " " ..fillTypeName
			local text = string.format(g_i18n:getText("Revamp_BuyInputText"), fillTypeText, g_i18n:formatMoney(price, 0, true))
			if price < farmMoney then
				table.insert(selectableOptions, {fillType=fillType, buyVolume=buyVolume1, price=price})
				table.insert(options, text)
			end
		end
		if missingFillLevel > buyVolume2 then
			local price = math.floor(pricePerLiter * buyVolume2, 1)
			local fillTypeText = RevampHelper:formatVolume(buyVolume2, 0, fillTypeDesc.unitShort).. " " ..fillTypeName
			local text = string.format(g_i18n:getText("Revamp_BuyInputText"), fillTypeText, g_i18n:formatMoney(price, 0, true))
			if price < farmMoney then
				table.insert(selectableOptions, {fillType=fillType, buyVolume=buyVolume2, price=price})
				table.insert(options, text)
			end
		end
		if missingFillLevel > buyVolume3 then
			local price = math.floor(pricePerLiter * buyVolume3, 1)
			local fillTypeText = RevampHelper:formatVolume(buyVolume3, 0, fillTypeDesc.unitShort).. " " ..fillTypeName
			local text = string.format(g_i18n:getText("Revamp_BuyInputText"), fillTypeText, g_i18n:formatMoney(price, 0, true))
			if price < farmMoney then
				table.insert(selectableOptions, {fillType=fillType, buyVolume=buyVolume3, price=price})
				table.insert(options, text)
			end
		end

		local price = math.floor(pricePerLiter * buyVolume4, 1)
		local fillTypeText = RevampHelper:formatVolume(buyVolume4, 0, fillTypeDesc.unitShort).. " " ..fillTypeName
		local text = string.format(g_i18n:getText("Revamp_BuyInputText"), fillTypeText, g_i18n:formatMoney(price, 0, true))
		if price < farmMoney then
			table.insert(selectableOptions, {fillType=fillType, buyVolume=buyVolume4, price=price, self=self})
			table.insert(options, text)
		else
			local buyVolumeMax = math.floor(farmMoney / pricePerLiter, 1)
			local price = math.floor(pricePerLiter * buyVolumeMax, 1)
			local fillTypeText = RevampHelper:formatVolume(buyVolumeMax, 0, fillTypeDesc.unitShort).. " " ..fillTypeName
			local text = string.format(g_i18n:getText("Revamp_BuyInputText"), fillTypeText, g_i18n:formatMoney(price, 0, true))
			table.insert(selectableOptions, {fillType=fillType, buyVolume=buyVolumeMax, price=price, self=self})
			table.insert(options, text)
		end
		if fillType ~= FillType.UNKNOWN then
			local dialogArguments = {
				text = g_i18n:getText("Revamp_BuyInput"),
				title = productionPoint:getName(),
				options = options,
				target = self,
				args = selectableOptions,
				callback = self.buyInput
			}
			g_gui:showOptionDialog(dialogArguments)
		end
	else
		local text = string.format(g_i18n:getText("Revamp_CantBuy"), fillTypeName)
		g_gui:showInfoDialog({
			text = text
		})
	end

	self.storageList:reloadData()
end



--Production Revamp: Inputs kaufbar machen
function InGameMenuProductionFrame:buyInput(selectedOption, args)
	local production, productionPoint = self:getSelectedProduction()
	local selectedArg = args[selectedOption]
	if selectedArg == nil then return end
	local fillType = selectedArg.fillType
	local buyVolume = selectedArg.buyVolume
	local price = selectedArg.price

	productionPoint:buyInput(fillType, buyVolume, price)
	self.storageList:reloadData()
end



--Production Revamp: BuyInput für Server
function ProductionPoint:buyInput(fillType, buyVolume, price, noEventSend)
	local currentFillLevel = self.storage:getFillLevel(fillType)
	local newFillLevel = currentFillLevel + buyVolume
	local farm = g_farmManager:getFarmById(self.ownerFarmId)

	if self.isServer then
		self.storage:setFillLevel(newFillLevel, fillType)
		g_currentMission:addMoney(-price, self.ownerFarmId, MoneyType.PRODUCTION_COSTS, true)
	end

	ProductionPointBuyInputEvent.sendEvent(self, fillType, buyVolume, price, noEventSend)
end