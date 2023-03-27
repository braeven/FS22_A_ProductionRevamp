--[[
Production Revamp
Production Animal Delivery

Copyright (C) braeven, Achimobil, 2022

Author: braeven, Achimobil

Date: 02.01.2023
Version: 1.0.1.0

Contact/Help/Tutorials:
discord.gg/gHmnFZAypk


Changelog:
1.0.0.0 @ 24.11.2022 - Initial commit
1.0.1.0 @ 02.01.2023 - TierIcons werden durchgestrichen, wenn sie nicht angenommen werden

Important:.
No changes are allowed to this script without permission from Braeven.
If you want to make a production with this script, look in the documentation, discord channels for tutorials/help or download the FS22_Revamp_Productions Pack for reference
Don't copy the script into a production, load the mod as a dependency!

Es dürfen an diesem Script keine Veränderungen ohne Erlaubnis von Braeven gemacht werden.
Wenn du eine Produktion mit diesem Script bauen möchtest, lese dir die Dokumentation, die angepinnten Tutorials im Discord durch oder guck dir die FS22_Revamp_Productions an.
Nicht das Script in Produktionen kopieren, ladet den Mod über eine Dependency!

]]
ProductionAnimalDelivery = {
	MOD_DIRECTORY = g_currentModDirectory,
	CONTROLS = {
		"textElement",
		"palletIconElement",
		"acceptedElement",
		"itemsElement",
		"quantityElement",
		"basePriceText",
		"totalPriceText",
		"yesButton"
	}
}
local ProductionAnimalDelivery_mt = Class(ProductionAnimalDelivery, YesNoDialog)

function ProductionAnimalDelivery.register()
	local productionAnimalDelivery = ProductionAnimalDelivery.new()

	if g_gui ~= nil then
		local filename = Utils.getFilename("gui/ProductionAnimalDelivery.xml", ProductionAnimalDelivery.MOD_DIRECTORY)

		g_gui:loadGui(filename, "ProductionAnimalDelivery", productionAnimalDelivery)
	end

	ProductionAnimalDelivery.INSTANCE = productionAnimalDelivery
end

function ProductionAnimalDelivery.show(callback, target, itemsInTrailer, triggerId)
	if ProductionAnimalDelivery.INSTANCE ~= nil then
		local dialog = ProductionAnimalDelivery.INSTANCE

		dialog:setCallback(callback, target)
		dialog:setText(nil)
		dialog:setItems(itemsInTrailer, triggerId)
		g_gui:showDialog("ProductionAnimalDelivery")
	end
end

function ProductionAnimalDelivery.new(target, custom_mt)
	local self = YesNoDialog.new(target, custom_mt or ProductionAnimalDelivery_mt)
	self.selectedFillType = nil
	self.areButtonsDisabled = false
	self.lastSelectedFillType = nil
	self:registerControls(ProductionAnimalDelivery.CONTROLS)

	return self
end

function ProductionAnimalDelivery.createFromExistingGui(gui, guiName)
	ProductionAnimalDelivery.register()

	local callback = gui.callbackFunc
	local target = gui.target
	local items = gui.items
	local maxQuantity = gui.maxQuantity

	ProductionAnimalDelivery.show(callback, target, items, maxQuantity)
end

function ProductionAnimalDelivery:onOpen()
	ProductionAnimalDelivery:superClass().onOpen(self)
	FocusManager:setFocus(self.itemsElement)
end

function ProductionAnimalDelivery:onClickOk()
	if self.areButtonsDisabled then
		return true
	else
		self:sendCallback(self.lastSelectedIndex, self.quantityElement:getState())

		return false
	end
end

function ProductionAnimalDelivery:onClickBack(forceBack, usedMenuButton)
	self:close()

	return false
end

function ProductionAnimalDelivery:sendCallback(index, quantity)
	if self.inputDelay < self.time then
		self:close()

		if self.callbackFunc ~= nil then
			if self.target ~= nil then
				self.callbackFunc(self.target, self.triggerId, index, quantity, self.callbackArgs)
			else
				self.callbackFunc(index, self.triggerId, quantity, self.callbackArgs)
			end
		end

		local items = {}
		for k, item in ipairs(self.items) do
			if k ~= index then
				table.insert(items, item)
			else
				if quantity < item.maxAnimals then
					item.maxAnimals = item.maxAnimals - quantity
					table.insert(items, item)	
				end
			end
		end
		if #items > 0 then
			self.show(self.callbackFunc, self.target, items, self.triggerId)
		end
	end
end

function ProductionAnimalDelivery:onClickItems(state)
	self:setButtonDisabled(false)

	local item = self.items[state]
	self.lastSelectedIndex = state

	self.palletIconElement:setImageFilename(item.imageFilename)
	self.acceptedElement:setImageFilename(item.accepted)
	self:updateQuantities();
	-- self:updateProductionInfo()
end

function ProductionAnimalDelivery:onClickQuantity()
	self:updateProductionInfo()
end

function ProductionAnimalDelivery:updateQuantities()
	local item = self.items[self.lastSelectedIndex]

	local quantities = {}

	for i = 1, item.maxAnimals do
		table.insert(quantities, tostring(i) .. " " .. g_i18n:getText("ui_numAnimals"))
	end
	
	-- nicht abgebbar, ok button deaktivieren
	self.yesButton:setDisabled(#quantities == 0)
	self.quantityElement:setDisabled(#quantities == 0)
	
	if #quantities == 0 then
		-- Message einfügen
		if item.calculationMessageTranslated ~= nil then
			table.insert(quantities, item.calculationMessageTranslated)
		else
			table.insert(quantities, g_i18n:getText("Revamp_productFullError"))
		end
	end

	self.quantityElement:setTexts(quantities)
	
	-- max vorauswählen beim wechseln, da dies meist das ist, was man ausladen will.
	self.quantityElement:setState(item.maxAnimals, true)
end

function ProductionAnimalDelivery:updateProductionInfo()
	local item = self.items[self.lastSelectedIndex];
	local quantity = self.quantityElement:getState();
	
	local fillType = g_fillTypeManager:getFillTypeByIndex(item.inputFillTypeForProduction);
	
	if fillType ~= nil then
		local singleAmount = RevampHelper:formatVolume(item.weightPerAnimal, 0, fillType.unitShort);
		local totalAmount = RevampHelper:formatVolume(item.weightPerAnimal * quantity, 0, fillType.unitShort);
		
		self.basePriceText:setText(singleAmount .. " " .. fillType.title)
		self.totalPriceText:setText(totalAmount .. " " .. fillType.title)
	else
		self.basePriceText:setText("")
		self.totalPriceText:setText("")
	end
end

function ProductionAnimalDelivery:setItems(itemsInTrailer, triggerId)
	self.items = itemsInTrailer
	self.triggerId = triggerId
	self.itemsMapping = {}
	local selectedId = 1
	local itemTitles = {}

	for k, item in ipairs(itemsInTrailer) do
		table.insert(itemTitles, item.title)

		if k == self.lastSelectedIndex then
			selectedId = k
		end
	end

	self.itemsElement:setTexts(itemTitles)
	self.itemsElement:setState(selectedId, true)
end

function ProductionAnimalDelivery:setButtonDisabled(disabled)
	self.areButtonsDisabled = disabled

	self.yesButton:setDisabled(disabled)
end

ProductionAnimalDelivery.register()
