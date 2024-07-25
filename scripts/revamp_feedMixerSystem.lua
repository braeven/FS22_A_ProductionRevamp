--[[
Production Revamp
Revamp FeedMixer System

Copyright (C) braeven, Achimobil, 2022

Author: braeven, Achimobil

Date: 09.06.2024
Version: 1.0.0.0

Contact/Help/Tutorials:
discord.gg/gHmnFZAypk


Changelog:
1.0.0.0 @ 09.06.2024 - Initial Commit


Important:.
No changes are allowed to this script without permission from Braeven AND Achimobil.
If you want to make a production with this script, look in the documentation, discord channels for tutorials/help or download the FS22_Revamp_Productions Pack for reference
Don't copy the script into a production, load the mod as a dependency!

Es dürfen an diesem Script keine Veränderungen ohne Erlaubnis von Braeven UND Achimobil gemacht werden.
Wenn du eine Produktion mit diesem Script bauen möchtest, lese dir die Dokumentation, die angepinnten Tutorials im Discord durch oder guck dir die FS22_Revamp_Productions an.
Nicht das Script in Produktionen kopieren, ladet den Mod über eine Dependency!

]]

source(g_currentModDirectory .. "scripts/events/RevampSettingsEvent.lua")

RevampFeedMixerSystem = {}

function ProductionPoint:FMSload(xmlFile, key, production)
	--Alle Rezepte laden und Daten hinterlegen
	self.feedMixer = {}
	self.feedMixer.inputStorageSize = xmlFile:getValue(key .. ".productions#feedInputStorage", 10000)
	self.feedMixer.outputStorageSize = xmlFile:getValue(key .. ".productions#feedOutputStorage", 10000)

	production.feedMixer = {}
	production.feedMixer.recipes = {}
	production.feedMixer.minPercentages = {}
	for x = 1, #g_currentMission.animalFoodSystem.recipes do --alle rezepte laden
		local recipe = g_currentMission.animalFoodSystem.recipes[x]
		if recipe.disableSelection == nil then --Manche Rezepte sollen nicht ausgewählt werden können, diese werden nicht eingetragen
			local entry = {}
			entry.output = recipe.fillType
			--Input-FillTypeListe für Storage
			entry.fillTypes = {}
			--Ingredients gruppiert lassen
			entry.ingredients = {}
			--mindest % Menge berechnen und hinterlegen
			entry.min = 0

			--alle ingredients in FillTypeListe für Storage hinterlegen, min-Wert zusammenrechnen
			for i = 1, #recipe.ingredients do
				local ingredient = recipe.ingredients[i]
				entry.min = entry.min + ingredient.minPercentage
				for y = 1, #ingredient.fillTypes do --alle zulässigen Filltypes für das Rezept in Tabelle hinterlegen
					local fillType = ingredient.fillTypes[y]
					entry.fillTypes[fillType] = true
				end
			end
			entry.ingredients = recipe.ingredients
			table.insert(production.feedMixer.recipes, entry)
		end
	end
	--Hier Funktion aufrufen, die Rezept 1 läd, später wird bei der Synchro/laden vom Savegame umgestellt
	local forage = g_fillTypeManager:getFillTypeIndexByName("FORAGE")
	production = self:FMSchangeRecipe(production, forage)
	self.feedMixer.id = #self.productions + 1
	
	return production
end


--altes Rezept löschen, neues laden
function ProductionPoint:FMSchangeRecipe(production, recipeId, reload)
	local recipe = {}
	for x = 1, #production.feedMixer.recipes do
		local testrecipe = production.feedMixer.recipes[x]
		if testrecipe.output == recipeId then
			recipe = testrecipe
		end
	end
	production.outputs = {}
	production.inputs = {}
	production.feedMixer.minPercentages = {}
	production.feedMixer.maxPercentages = {}
	production.feedMixer.neededPercentage = 0
	production.boostNumber = 0
	production.masterNumber = 0
	production.name = g_fillTypeManager:getFillTypeByIndex(recipe.output).title
	local oldFillType = production.feedMixer.selected
	production.feedMixer.selected = recipeId

	--Output-Liste erstellen
	local output = {}
	output.type = recipe.output
	production.primaryProductFillType = recipe.output
	output.sellDirectly = false
	output.boost = false
	output.weatherAffected = false
	output.weatherFactor = 1
	output.amount = 1000
	table.insert(production.outputs, output)

	--Input-Liste erstellen
	for i = 1, #recipe.ingredients do
		local ingredient = recipe.ingredients[i]
		production.feedMixer.neededPercentage = production.feedMixer.neededPercentage + (ingredient.minPercentage * 100)
		production.feedMixer.minPercentages[i+1] = ingredient.minPercentage * 100
		production.feedMixer.maxPercentages[i+1] = ingredient.maxPercentage * 100

		for _, fillTypeIndex in ipairs(ingredient.fillTypes) do
			local input = {}
			input.type = fillTypeIndex
			input.amount = 1
			input.mix = i
			production.boostNumber = i+1
			production.masterNumber = i+2
			input.minPercentage = ingredient.minPercentage
			input.maxPercentage = ingredient.maxPercentage

			input.boostfactor = 0
			input.outputConditional = false
			input.outputAmount = 1
			input.boostfactor = 0
			input.buyFactor = 2
			input.weatherAffected = false
			input.weatherFactor = 1
			input.allowBuying = true
			input.color = 0
			table.insert(production.inputs, input)
		end
	end
	if reload ~= nil then
		self:FMSchangeFillTypes(production.inputs, production.outputs, oldFillType)
	end
	return production
end

--Was in der Produktion abgegeben werden kann
function ProductionPoint:FMSchangeFillTypes(inputFillTypes, outputFillTypes, oldFillType)
	--Backup der anderen Produktionen erstellen bzw. laden falls vorhanden
	if self.backup == nil then
		self.backup = {}
		self.backupOut = {}
		--Backup nur wenn es mehr als eine Linie gibt
		if #self.productions > 1 then
			for index in pairs(self.inputFillTypeIds) do
				self.backup[index] = true
			end
			for index in pairs(self.outputFillTypeIds) do
				self.backupOut[index] = true
			end
		end
	else
		self.inputFillTypeIds = {}
		self.inputFillTypeIdsArray = {}
		self.outputFillTypeIds = {}
		self.outputFillTypeIdsArray = {}
		self.outputFillTypeIdsStorage[oldFillType] = nil
		self.outputFillTypeIdsAutoDeliver[oldFillType] = nil
		self.outputFillTypeIdsDirectSell[oldFillType] = nil
		self.storage.fillTypes = {}
		self.storage.sortedFillTypes = {}

		--Backups wieder herstellen
		for index in pairs(self.backup) do
			self.inputFillTypeIds[index] = true
			table.addElement(self.inputFillTypeIdsArray, index)
			self.storage.fillTypes[index] = true
			table.addElement(self.storage.sortedFillTypes, index)
			if self.storage.fillLevels[index] == nil then
				self.storage.fillLevels[index] = 0
			end
		end

		for index in pairs(self.backupOut) do
			self.outputFillTypeIds[index] = true
			table.addElement(self.outputFillTypeIdsArray, index)
			self.storage.fillTypes[index] = true
			self.outputFillTypeIdsStorage[index] = true
			table.addElement(self.storage.sortedFillTypes, index)
			if self.storage.fillLevels[index] == nil then
				self.storage.fillLevels[index] = 0
			end
		end
	end
	
	--Inputs laden, Storage und UnloadingTrigger aktualisieren
	for x = 1, #inputFillTypes do
		local input = inputFillTypes[x]
		self.inputFillTypeIds[input.type] = true
		if self.inputFillTypeIdsPriority[input.type] == nil then
			self.inputFillTypeIdsPriority[input.type] = 10
		end
		table.addElement(self.inputFillTypeIdsArray, input.type)
		if self.storage.capacities[input.type] == nil then
			self.storage.capacities[input.type] = self.feedMixer.inputStorageSize
		end
		self.storage.fillTypes[input.type] = true
		self.storage.fillLevelsLastSynced[input.type] = 0
		self.storage.fillLevelsLastPublished[input.type] = 0
		table.addElement(self.storage.sortedFillTypes, input.type)
		if self.storage.fillLevels[input.type] == nil then
			self.storage.fillLevels[input.type] = 0
		end
		local fillType = g_fillTypeManager:getFillTypeByIndex(input.type)
		self.unloadingStation:addAcceptedFillType(input.type, fillType.pricePerLiter, false, false)
		for _, unload in pairs(self.unloadingStation.unloadTriggers) do
			unload.fillTypes[input.type] = true
		end
	end
	self.unloadingStation:updateSupportedFillTypes()
	self.unloadingStation:initPricingDynamics()

	--Outputs laden, Storage und LoadingTrigger aktualisieren
	for x = 1, #outputFillTypes do
		local output = outputFillTypes[x]
		table.addElement(self.outputFillTypeIdsArray, output.type)
		if self.storage.capacities[output.type] == nil then
			self.storage.capacities[output.type] = self.feedMixer.outputStorageSize
		end
		self.storage.fillTypes[output.type] = true
		self.storage.fillLevelsLastSynced[output.type] = 0
		self.storage.fillLevelsLastPublished[output.type] = 0
		table.addElement(self.storage.sortedFillTypes, output.type)
		if self.storage.fillLevels[output.type] == nil then
			self.storage.fillLevels[output.type] = 0
		end
		self.outputFillTypeIdsStorage[output.type] = true
		self.outputFillTypeIds[output.type] = true
		self.loadingStation.supportedFillTypes[output.type] = true
		self.loadingStation.aiSupportedFillTypes[output.type] = true
		for _, loading in pairs(self.loadingStation.loadTriggers) do
			loading.fillTypes[output.type] = true
		end
	end

	for storageFillType, _ in pairs(self.storage.fillLevels) do
		if self.storage.fillTypes[storageFillType] == nil then
			self.storage.fillLevels[storageFillType] = nil
		end
	end

	for fillType, _ in pairs(self.inputFillTypeIdsPriority) do
		if self.inputFillTypeIds[fillType] == nil then
			self.inputFillTypeIdsPriority[fillType] = nil
		end
	end
end

function ProductionPoint:FMScalculate(production, cyclesPerMinuteMinuteFactor)
	local groupMin = {}	--Anzahl der FillTypes hinterlegt für min pro mix
	local groupMax = {}	--Anzahl der FillTypes hinterlegt für max pro mix
	local groupMinMax = {} --Anzahl der FillTypes hinterlegt für minmax pro mix
	local addedMinMax = 0 -- addiert max-mengen für mindest-FillTypes
	local addedMin = 0 --addiert mindest-Mengen
	local addedMax = 0 --addiert maximal-Mengen
	local minMaxMode = false

	--für das verarbeiten später
	local enoughInputResources = true
	local enoughInput = {}
	local useFillType = {}

	--Auslesen was vorhanden ist, min/max hinterlegen
	for x = 1, #production.inputs do
		local input = production.inputs[x]
		local fillLevel = self:getFillLevel(input.type)
		local factor = cyclesPerMinuteMinuteFactor
		local mix = input.mix
		enoughInput[mix] = true

		if fillLevel > 0 then
			--Durchgehen was vorhanden ist. Min addieren, max addieren basierend auf dem Storage
			if input.minPercentage > 0 then
				if groupMin[mix] == nil then
					groupMin[mix] = 1
					groupMinMax[mix] = 1
					addedMin = addedMin + input.minPercentage * 100
					addedMinMax = addedMinMax + input.maxPercentage * 100
				else
					groupMin[mix] = groupMin[mix] + 1
					groupMinMax[mix] = groupMinMax[mix] + 1
				end
			elseif groupMax[mix] == nil then
				groupMax[mix] = 1
				groupMinMax[mix] = 1
				addedMax = addedMax + input.maxPercentage * 100
			else
				groupMax[mix] = groupMax[mix] + 1
				groupMinMax[mix] = groupMinMax[mix] + 1
			end
		end
	end

	if production.feedMixer.neededPercentage > addedMin then
		enoughInputResources = false
	elseif addedMax < 100 then	
		if addedMax + addedMinMax > 100 then
			minMaxMode = true
			addedMax = addedMax + addedMinMax
			groupMax = groupMinMax
		else
			enoughInputResources = false
		end
	end

	--Neues Rezept anlegen
	for x = 1, #production.inputs do
		local input = production.inputs[x]
		local fillLevel = self:getFillLevel(input.type)
		local color = 0
		local mix = input.mix

		if fillLevel > 0 then
			--Wenn min vorhanden ist
			if groupMin[mix] ~= nil and not minMaxMode then
				local amount = 100 * (input.minPercentage / groupMin[mix])
				if (amount * cyclesPerMinuteMinuteFactor) > fillLevel then
					enoughInputResources = false
					color = 1
				else
					enoughInput[mix] = true
					useFillType[input.type] = amount
				end
			else
				local amount = 1000 * (input.maxPercentage / addedMax / groupMax[mix])
				if (amount * cyclesPerMinuteMinuteFactor) > fillLevel then
					enoughInputResources = false
					color = 1
				else
					enoughInput[mix] = true
					useFillType[input.type] = amount
				end
			end

		else
			if input.minPercentage > 0 then
				color = 1
			else
				color = 2
			end
			--Production Revamp: Farben hinterlegen für die Rezept-Anzeige, 0=weiß(vorhanden) 1=fehlt(wird benötigt) 2=(optional, nicht vorhanden)
		end

		if color~=input.color then
			self:setProductionInputColor(production.id, x, color)
		end
	end

	return enoughInputResources, enoughInput, useFillType
end

--Production Revamp: MenüButton um das Rezept ändern zu können
function RevampFeedMixerSystem:updateMenuButtons(superFunc)
	local isProductionListActive = self.productionList == FocusManager:getFocusedElement()
	local production, productionPoint = self:getSelectedProduction()

	if isProductionListActive and production.feedMixer ~= nil then
		table.insert(self.menuButtonInfo, {
			profile = "buttonOk",
			inputAction = InputAction.MENU_EXTRA_1,
			text = self.i18n:getText("Revamp_ChangeRecipe"),
			callback = function()
				self:FMSshowMenue()
			end
		})
		self:setMenuButtonInfoDirty()
	end
end

InGameMenuProductionFrame.updateMenuButtons = Utils.appendedFunction(InGameMenuProductionFrame.updateMenuButtons, RevampFeedMixerSystem.updateMenuButtons)

--Production Revamp: Callback um Rezept zu ändern
function InGameMenuProductionFrame:FMSshowMenue()
	local isProductionListActive = self.productionList == FocusManager:getFocusedElement()
	local production, productionPoint = self:getSelectedProduction()

	if isProductionListActive and production.feedMixer ~= nil then
		local selectableOptions = {}
		local options = {}

		for i = 1, #production.feedMixer.recipes do
			local recipe = production.feedMixer.recipes[i]
			local output = g_fillTypeManager:getFillTypeByIndex(recipe.output)
			if production.feedMixer.selected == recipe.output then
				table.insert(selectableOptions, 1, {recipe=recipe.output, self=self})
				table.insert(options, 1, output.title)
			else
				table.insert(selectableOptions, {recipe=recipe.output, self=self})
				table.insert(options, output.title)
			end
		end

		local dialogArguments = {
			text = g_i18n:getText("Revamp_ChangeRecipe"),
			title = productionPoint:getName(),
			options = options,
			target = self,
			args = selectableOptions,
			callback = self.FMSChangeRecipe
		}

		--Alten Dialog falls vorhanden resetten
		local dialog = g_gui.guis["OptionDialog"]
		if dialog ~= nil then
			dialog.target:setOptions({""}) -- Add fake option to force a "reset"
		end
		g_gui:showOptionDialog(dialogArguments)
	end
end

function InGameMenuProductionFrame:FMSChangeRecipe(selectedOption, args)
	local production, productionPoint = self:getSelectedProduction()
	local selectedArg = args[selectedOption]
	if selectedArg == nil then return end

	productionPoint:setRevampSettings(production.id, nil, nil, selectedArg.recipe)
	self.storageList:reloadData()
end