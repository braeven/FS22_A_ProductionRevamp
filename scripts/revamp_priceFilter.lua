--[[
Production Revamp
Revamp Price Menu Filter Functions

Copyright (C) braeven, 2022

Author: braeven / Achimobil
Date: 21.05.2022
Version: 1.0.0.0

Contact/Help/Tutorials:
discord.gg/gHmnFZAypk

Changelog:
1.0.0.0 @ 21.05.2022 - Release Initial Version

Important:
Kopiere diese Datei in deine Produktionen um einen Revamp-Versionscheck ausführen zu können. Diese Datei ist außerdem nötig um Filltypes bei bestehenden Sellingstations anmelden zu können und StoreItems An-/Abzumelden.

Copy this File into your Productions to add a Revamp-Versionscheck. This File is also needed to add Filltypes into existing Sellingstations and registering/unregistering StoreItems.Important:.
No changes are allowed to this script without permission from Braeven AND Achimobil.
If you want to make a production with this script, look in the documentation, discord channels for tutorials/help or download the FS22_Revamp_Productions Pack for reference
Don't copy the script into a production, load the mod as a dependency!

Es dürfen an diesem Script keine Veränderungen ohne Erlaubnis von Braeven UND Achimobil gemacht werden.
Wenn du eine Produktion mit diesem Script bauen möchtest, lese dir die Dokumentation, die angepinnten Tutorials im Discord durch oder guck dir die FS22_Revamp_Productions an.
Nicht das Script in Produktionen kopieren, ladet den Mod über eine Dependency!
]]

RevampPriceMenu = {}

function RevampPriceMenu:rebuildTable()
	local filter = {}
	if InGameMenuPricesFrame.filter ~= nil then
		local catfillTypes = g_fillTypeManager:getFillTypesByCategoryNames(InGameMenuPricesFrame.filter, "JAJAJAJAJA Warning: UnloadTrigger has invalid fillTypeCategory '%s'.")
		for _, fillType in pairs(catfillTypes) do
			filter[fillType] = true
		end
	end
		
	self.fillTypes = {}

	for _, fillTypesDesc in pairs(self.fillTypeManager:getFillTypes()) do
		if fillTypesDesc.showOnPriceTable then
			if filter[fillTypesDesc.index] ~= nil then
				table.insert(self.fillTypes, fillTypesDesc)
			elseif InGameMenuPricesFrame.filter == nil then
				table.insert(self.fillTypes, fillTypesDesc)
			end
		end
	end
	self.productList:reloadData()
end

InGameMenuPricesFrame.rebuildTable = Utils.appendedFunction(InGameMenuPricesFrame.rebuildTable, RevampPriceMenu.rebuildTable)



function RevampPriceMenu:updateMenuButtons()
	local buttonText = g_i18n:getText("REVAMP_FILTER")
	if InGameMenuPricesFrame.filter ~= nil then
		buttonText = g_i18n:getText(InGameMenuPricesFrame.filter)
	end
	table.insert(self.menuButtonInfo, {
		profile = "buttonOk",
		inputAction = InputAction.MENU_EXTRA_2,
		text = buttonText,
		callback = function()
			self:togglePricesList()
		end
	})
	self:setMenuButtonInfoDirty()
end

InGameMenuPricesFrame.updateMenuButtons = Utils.appendedFunction(InGameMenuPricesFrame.updateMenuButtons, RevampPriceMenu.updateMenuButtons)



function InGameMenuPricesFrame:togglePricesList(clearView)
	if clearView == true then
		InGameMenuPricesFrame.filter = nil
		InGameMenuPricesFrame.filterId = 0
	else
		if InGameMenuPricesFrame.filterId == nil then
			InGameMenuPricesFrame.filterId = 0
		end
		if InGameMenuPricesFrame.filters == nil then
			InGameMenuPricesFrame.filters = {}
			InGameMenuPricesFrame.filters[0] = nil
			InGameMenuPricesFrame.filters[1] = "REVAMP_FILTER_FRUITS"
			InGameMenuPricesFrame.filters[2] = "REVAMP_FILTER_GRASSES"
			InGameMenuPricesFrame.filters[3] = "REVAMP_FILTER_SILAGES"
			InGameMenuPricesFrame.filters[4] = "REVAMP_FILTER_FEED"
			InGameMenuPricesFrame.filters[5] = "REVAMP_FILTER_FEEDINGREDIENTS"
			InGameMenuPricesFrame.filters[6] = "REVAMP_FILTER_SEEDS"
			InGameMenuPricesFrame.filters[7] = "REVAMP_FILTER_PRODUCTS"
			InGameMenuPricesFrame.filters[8] = "REVAMP_FILTER_ANIMALPRODUCTS"
			InGameMenuPricesFrame.filters[9] = "REVAMP_FILTER_CONSUMABLES"
			InGameMenuPricesFrame.filterFA = {}
			InGameMenuPricesFrame.filterFA[2] = true
			InGameMenuPricesFrame.filterFA[3] = true
			InGameMenuPricesFrame.filterFA[4] = true
			InGameMenuPricesFrame.filterFA[6] = true
		end

		local FA = RevampHelper:testFarmingAgency()

		local function getNextFilter(filterId)
			filterId = filterId + 1
			if filterId == 9 then
				filterId = 0
			elseif InGameMenuPricesFrame.filterFA[filterId] ~= nil and FA == false then
					filterId = getNextFilter(filterId)
			end

			return filterId
		end

		InGameMenuPricesFrame.filterId = getNextFilter(InGameMenuPricesFrame.filterId)

		InGameMenuPricesFrame.filter = InGameMenuPricesFrame.filters[InGameMenuPricesFrame.filterId]
		self:rebuildTable()
	end
end


function RevampPriceMenu:onFrameOpen(superFunc)
	InGameMenuPricesFrame.filter = nil
	InGameMenuPricesFrame.filterId = 0
end

InGameMenuPricesFrame.onFrameOpen = Utils.prependedFunction(InGameMenuPricesFrame.onFrameOpen, RevampPriceMenu.onFrameOpen)

function RevampPriceMenu:addDLCFillTypes()
	local pdlc = "pdlc_forestryPack"
	if g_modIsLoaded[pdlc] then
		local fillTypeCategoryIndex = g_fillTypeManager:addFillTypeCategory("REVAMP_FILTER_PRODUCTS", false)
		local fillTypeNames = string.split("ARMOIRE BARREL BATHTUB BIRDHOUSE BOWL BUCKET CARTONROLL CATTREE CHAIR DOGHOUSE EASEL FLOORTILES METAL PAPERROLL PEPPERGRINDER PICTUREFRAME PLANKS PREFABWALL SHINGLE STAIRCASERAILING TABLE WOODBEAM", " ")

		for _, fillTypeName in ipairs(fillTypeNames) do
			local fillType = g_fillTypeManager:getFillTypeIndexByName(fillTypeName)
			if fillType ~= nil then
				g_fillTypeManager:addFillTypeToCategory(fillType, fillTypeCategoryIndex)
			end
		end
	end
	
	local pdlc = "pdlc_pumpsAndHosesPack"
	if g_modIsLoaded[pdlc] then
		local fillTypeCategoryIndex = g_fillTypeManager:addFillTypeCategory("REVAMP_FILTER_ANIMALPRODUCTS", false)
		local fillTypeNames = string.split("SEPARATED_MANURE", " ")

		for _, fillTypeName in ipairs(fillTypeNames) do
			local fillType = g_fillTypeManager:getFillTypeIndexByName(fillTypeName)
			if fillType ~= nil then
				g_fillTypeManager:addFillTypeToCategory(fillType, fillTypeCategoryIndex)
			end
		end
	end

	local pdlc = "pdlc_agiPack"
	if g_modIsLoaded[pdlc] then
		local fillTypeCategoryIndex = g_fillTypeManager:addFillTypeCategory("REVAMP_FILTER_CONSUMABLES", false)
		local fillTypeNames = string.split("LIQUIDSEEDTREATMENT", " ")

		for _, fillTypeName in ipairs(fillTypeNames) do
			local fillType = g_fillTypeManager:getFillTypeIndexByName(fillTypeName)
			if fillType ~= nil then
				g_fillTypeManager:addFillTypeToCategory(fillType, fillTypeCategoryIndex)
			end
		end
	end

	local pdlc = "pdlc_premiumExpansion"
	if g_modIsLoaded[pdlc] then
		local fillTypeCategoryIndex = g_fillTypeManager:addFillTypeCategory("REVAMP_FILTER_PRODUCTS", false)
		local fillTypeNames = string.split("POTATOCHIPS PRESERVEDCARROTS PRESERVEDPARSNIP PRESERVEDBEETROOT SOUPCANSMIXED SOUPCANSCARROTS SOUPCANSPARSNIP SOUPCANSBEETROOT SOUPCANSPOTATO", " ")

		for _, fillTypeName in ipairs(fillTypeNames) do
			local fillType = g_fillTypeManager:getFillTypeIndexByName(fillTypeName)
			if fillType ~= nil then
				g_fillTypeManager:addFillTypeToCategory(fillType, fillTypeCategoryIndex)
			end
		end

		local fillTypeCategoryIndex = g_fillTypeManager:addFillTypeCategory("REVAMP_FILTER_FRUITS", false)
		local fillTypeNames = string.split("BEETROOT CARROT PARSNIP", " ")

		for _, fillTypeName in ipairs(fillTypeNames) do
			local fillType = g_fillTypeManager:getFillTypeIndexByName(fillTypeName)
			if fillType ~= nil then
				g_fillTypeManager:addFillTypeToCategory(fillType, fillTypeCategoryIndex)
			end
		end
	end

	local pdlc = "pdlc_farmProductionPack"
	if g_modIsLoaded[pdlc] then
		local fillTypeCategoryIndex = g_fillTypeManager:addFillTypeCategory("REVAMP_FILTER_PRODUCTS", false)
		local fillTypeNames = string.split("WASHEDPOTATO WASHEDSUGARBEET WASHEDCARROT WASHEDBEETROOT WASHEDPARSNIP", " ")

		for _, fillTypeName in ipairs(fillTypeNames) do
			local fillType = g_fillTypeManager:getFillTypeIndexByName(fillTypeName)
			if fillType ~= nil then
				g_fillTypeManager:addFillTypeToCategory(fillType, fillTypeCategoryIndex)
			end
		end

		local fillTypeCategoryIndex = g_fillTypeManager:addFillTypeCategory("REVAMP_FILTER_CONSUMABLES", false)
		local fillTypeNames = string.split("SULPHURICACID", " ")

		for _, fillTypeName in ipairs(fillTypeNames) do
			local fillType = g_fillTypeManager:getFillTypeIndexByName(fillTypeName)
			if fillType ~= nil then
				g_fillTypeManager:addFillTypeToCategory(fillType, fillTypeCategoryIndex)
			end
		end
	end
end

Mission00.onStartMission = Utils.appendedFunction(Mission00.onStartMission, RevampPriceMenu.addDLCFillTypes)