--[[
Production Revamp
Production Animal Overview

Copyright (C) braeven, Achimobil, 2022

Author: braeven, Achimobil

Date: 19.01.2023
Version: 1.0.0.1

Contact/Help/Tutorials:
discord.gg/gHmnFZAypk


Changelog:
1.0.0.0 @ 24.11.2022 - Initial commit
1.0.0.1 @ 19.01.2023 - Vergessenen Text Übersetzbar gemacht

Important:.
No changes are allowed to this script without permission from Braeven.
If you want to make a production with this script, look in the documentation, discord channels for tutorials/help or download the FS22_Revamp_Productions Pack for reference
Don't copy the script into a production, load the mod as a dependency!

Es dürfen an diesem Script keine Veränderungen ohne Erlaubnis von Braeven gemacht werden.
Wenn du eine Produktion mit diesem Script bauen möchtest, lese dir die Dokumentation, die angepinnten Tutorials im Discord durch oder guck dir die FS22_Revamp_Productions an.
Nicht das Script in Produktionen kopieren, ladet den Mod über eine Dependency!

]]
ProductionAnimalOverview = {
	MOD_DIRECTORY = g_currentModDirectory,
	CONTROLS = {
		"subTypeElementText",
		"animalIconElement",
		"subTypeElement",
		"overviewHealthText",
		"overviewAgeText",
		"overviewInputFillTypeText",
		"recipeFillIcon",
		"yesButton"
	}
}
local ProductionAnimalOverview_mt = Class(ProductionAnimalOverview, YesNoDialog)



function ProductionAnimalOverview.register()
	local ProductionAnimalOverview = ProductionAnimalOverview.new()

	if g_gui ~= nil then
		local filename = Utils.getFilename("gui/ProductionAnimalOverview.xml", ProductionAnimalOverview.MOD_DIRECTORY)

		g_gui:loadGui(filename, "ProductionAnimalOverview", ProductionAnimalOverview)
	end
end



function ProductionAnimalOverview:show(productionPoint)
	local dialog = g_gui:showDialog("ProductionAnimalOverview")

	local items = {}
	--Daten aufbereiten
	for animalName, animal in pairs(productionPoint.animalTypes) do
		local subType = g_currentMission.animalSystem:getSubTypeByName(animalName)
		for recipeIndex, recipe in ipairs(animal.recipe) do
			local item = {}

			--Name der Rasse, Bild der Rasse auslesen
			local visual = g_currentMission.animalSystem:getVisualByAge(subType.subTypeIndex, recipe.minAge)
			item.imageFilename = visual.store.imageFilename
			item.title = visual.store.name

			--Umwandlungsdaten auslesen und eintragen
			item.minAge = recipe.minAge
			item.maxAge = recipe.maxAge
			item.minHealth = recipe.minHealth
			item.maxHealth = recipe.maxHealth
			local fillType = g_fillTypeManager:getFillTypeByIndex(recipe.fillTypeIndex)
			item.fillTypeName = fillType.title
			item.unitShort = fillType.unitShort
			if item.unitShort == "" then
				item.unitShort = nil
			end
			item.hudOverlayFilename = fillType.hudOverlayFilename
			item.biggestAmount = recipe.biggestAmount
			item.smallestAmount = recipe.smallestAmount

			table.insert(items, item)
		end
	end
	dialog.target:setItems(items)
end



function ProductionAnimalOverview.new(target, custom_mt)
	local self = YesNoDialog.new(target, custom_mt or ProductionAnimalOverview_mt)
	self.areButtonsDisabled = false

	self:registerControls(ProductionAnimalOverview.CONTROLS)

	return self
end



function ProductionAnimalOverview:onOpen()
	ProductionAnimalOverview:superClass().onOpen(self)
	FocusManager:setFocus(self.subTypeElement)
end



function ProductionAnimalOverview:onClickOk()
	self:close()
end



function ProductionAnimalOverview:onClickBack(forceBack, usedMenuButton)
	self:close()
end



function ProductionAnimalOverview:onClickItems(state)
	local item = self.items[state]
	self.lastSelectedIndex = state

	self.animalIconElement:setImageFilename(item.imageFilename)
	self.recipeFillIcon:setImageFilename(item.hudOverlayFilename)
	self.overviewHealthText:setText(item.minHealth.. " - " ..item.maxHealth.. " %")
	self.overviewAgeText:setText(item.minAge.. " - " ..item.maxAge.. " " ..g_i18n:getText("ui_months"))
	self.overviewInputFillTypeText:setText(item.fillTypeName.. ": " ..item.smallestAmount.. " - " ..g_i18n:formatVolume(item.biggestAmount, 0, item.unitShort))

end



function ProductionAnimalOverview:setItems(items)
	self.items = items
	self.itemsMapping = {}
	local selectedId = 1
	local itemTitles = {}

	for k, item in ipairs(items) do
		table.insert(itemTitles, item.title)

		if k == self.lastSelectedIndex then
			selectedId = k
		end
	end

	self.subTypeElement:setTexts(itemTitles)
	self.subTypeElement:setState(selectedId, true)
end



ProductionAnimalOverview.register()