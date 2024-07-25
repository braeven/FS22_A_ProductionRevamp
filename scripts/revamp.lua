--[[
Production Revamp
Main Script File

Copyright (C) braeven, Achimobil 2022

Author: braeven
Thanks for Helping: Achimobil, TethysSaturn, DickerSauerlaender, inconspicuously007, AlfredProm
Date: 20.06.2024
Version: 1.5.0.0 Beta 1

Contact/Help/Tutorials:
discord.gg/gHmnFZAypk

Important:.
No changes are allowed to this script without permission from Braeven and Achimobil.
If you want to make a production with this script, look in the discord channels for tutorials/help or download the FS22_Revamp_Productions Pack for reference
Don't copy the script into a production, load the mod as a dependency!

Es dürfen an diesem Script keine Veränderungen ohne Erlaubnis von Braeven und Achimobil gemacht werden.
Wenn du eine Produktion mit diesem Script bauen möchtest, lese dir die angepinnten Tutorials im Discord durch oder guck dir die FS22_Revamp_Productions an.
Nicht das Script in Produktionen kopieren, ladet den Mod über eine Dependency!

]]

Revamp = {}

Revamp.SellFillTypes = {}
Revamp.RemoveByFillTypeStoreItems = {}
Revamp.AddByFillTypeStoreItems = {}
Revamp.FillTypeFilesToLoad = {}
ProductionPoint.Revamp = g_currentModDirectory

ProductionPoint.PROD_STATUS = {
	INACTIVE = 0,
	RUNNING = 1,
	MISSING_INPUTS = 2,
	NO_OUTPUT_SPACE = 3,
	OUTSIDE_OF_SEASONS = 4,
	OUTSIDE_OF_MONTHS = 5,
	OUTSIDE_OF_HOURS = 6,
	FEEDMIXER_MIN = 7,
	FEEDMIXER_MAX = 8
}

ProductionPoint.PROD_STATUS_TO_L10N = {
	[ProductionPoint.PROD_STATUS.INACTIVE] = "ui_production_status_inactive",
	[ProductionPoint.PROD_STATUS.RUNNING] = "ui_production_status_running",
	[ProductionPoint.PROD_STATUS.MISSING_INPUTS] = "ui_production_status_materialsMissing",
	[ProductionPoint.PROD_STATUS.NO_OUTPUT_SPACE] = "ui_production_status_outOfSpace",
	[ProductionPoint.PROD_STATUS.OUTSIDE_OF_SEASONS] = "revamp_production_status_outsideOfSeasons",
	[ProductionPoint.PROD_STATUS.OUTSIDE_OF_MONTHS] = "revamp_production_status_outsideOfMonths",
	[ProductionPoint.PROD_STATUS.OUTSIDE_OF_HOURS] = "revamp_production_status_outsideOfHours"
}

local function registerProductionPointOutputMode(name, value)
	name = name:upper()

	if ProductionPoint.OUTPUT_MODE[name] == nil then
		if value == nil then
			value = 0

			for _, mode in pairs(ProductionPoint.OUTPUT_MODE) do
				if value < mode then
					value = mode
				end
			end

			--Überprüfen ob PnH aktiv ist und falls ja, Output-Modus-Zahl erhöhen
			local mods = g_modManager:getActiveMods(pdlc_pumpsAndHosesPack)

			for index, activemod in pairs(mods) do
				if activemod.modName == "pdlc_pumpsAndHosesPack" then
					if ProductionPoint.OUTPUT_MODE[AUTO_DISTRIBUTION] == nil then
						value = value + 1
					end
				end
			end

			value = value + 1
		end

		ProductionPoint.OUTPUT_MODE[name] = value

		if value >= 2^ProductionPoint.OUTPUT_MODE_NUM_BITS - 1 then
			ProductionPoint.OUTPUT_MODE_NUM_BITS = ProductionPoint.OUTPUT_MODE_NUM_BITS + 1
		end
	end
end

registerProductionPointOutputMode("STORE")



--Production Revamp: Neue XML-Variablen anmelden die aus der Produktion ausgelesen werden können
function Revamp.registerXMLPaths(schema, basePath)
	schema:register(XMLValueType.STRING, basePath .. ".productions.production(?).inputs.input(?)#mix", "Mixing Group for Input", 0)
	schema:register(XMLValueType.FLOAT, basePath .. ".productions.production(?).inputs.input(?)#boostfactor", "Boost-Factor for Input", 0) --Schreibfehler in der Vergangenheit, muss bleiben wegen Kombat
	schema:register(XMLValueType.FLOAT, basePath .. ".productions.production(?).inputs.input(?)#boostFactor", "Boost-Factor for Input", 0)
	schema:register(XMLValueType.FLOAT, basePath .. ".productions.production(?).inputs.input(?)#buyFactor", "Buy Factor for goods", 2)
	schema:register(XMLValueType.STRING, basePath .. ".productions.production(?).inputs.input(?)#fillTypeCategory", "Input fillTypeCategory", nil, true)
	schema:register(XMLValueType.BOOL, basePath .. ".productions.production(?).inputs.input(?)#allowbuying", "Allows Filltype to be bought inside the production GUI", true)
	schema:register(XMLValueType.BOOL, basePath .. ".productions.production(?).inputs.input(?)#allowBuying", "Allows Filltype to be bought inside the production GUI", true) --Schreibfehler in der Vergangenheit, muss bleiben wegen Kombat
	schema:register(XMLValueType.STRING, basePath .. ".productions.production(?).inputs.input(?)#weatherAffected", "Is Input affected by Weather", false)
	schema:register(XMLValueType.FLOAT, basePath .. ".productions.production(?).inputs.input(?)#weatherFactor", "The factor an Input is affected by Weather", 1)
	schema:register(XMLValueType.STRING, basePath .. ".productions.production(?).inputs.input(?)#outputConditional", "The fillType of a conditional output", false)
	schema:register(XMLValueType.FLOAT, basePath .. ".productions.production(?).inputs.input(?)#outputAmount", "The amount of the conditional output", 1)
	schema:register(XMLValueType.STRING, basePath .. ".productions.production(?).outputs.output(?)#weatherAffected", "Is Output affected by Weather", false)
	schema:register(XMLValueType.BOOL, basePath .. ".productions.production(?).outputs.output(?)#primaryProductFillType", "Is the Output the Primary FillType", false)
	schema:register(XMLValueType.FLOAT, basePath .. ".productions.production(?).outputs.output(?)#weatherFactor", "The factor an Output is affected by Weather", 1)
	schema:register(XMLValueType.BOOL, basePath .. ".productions.production(?).outputs.output(?)#boost", "Activate Boost for Output", true)
	schema:register(XMLValueType.BOOL, basePath .. ".productions.production(?).outputs.output(?)#disableDirectSell", "Disable the ability to set an output to sell directly", false)
	schema:register(XMLValueType.BOOL, basePath .. ".productions.production(?).outputs.output(?)#disableDistribution", "Disable the ability to set an output to sell directly", false)

	--Production Revamp: Zusätzliche Produktions-Einstellungen
	schema:register(XMLValueType.FLOAT, basePath .. ".productions#priorityPreset", "Priority Preset for Production Inputs", 10)
	schema:register(XMLValueType.STRING, basePath .. ".productions#wrapColor", "Silage Bale Wraping Color", "0.6662 0.3839 0.5481 1")
	schema:register(XMLValueType.BOOL, basePath .. ".productions#autoDeliver", "Automatically deliver good from a production", false)
	schema:register(XMLValueType.BOOL, basePath .. ".productions#autoSpawn", "Sets a production to automatically spawn pallets again", false)
	schema:register(XMLValueType.NODE_INDEX, basePath .. "#woodSpawnPlace", "Place to spawn wood logs. No collision is checked, be carefull")
	schema:register(XMLValueType.INT, basePath .. "#maxWoodLogs", "max wood logs to spawn at one call. No collision is checked, be carefull", 15)
	schema:register(XMLValueType.INT, basePath .. "#minWoodLogLength", "min length for user select of wood log length. Choosable in 1m steps", 6)
	schema:register(XMLValueType.INT, basePath .. "#maxWoodLogLength", "max length for user select of wood log length. Choosable in 1m steps", 6)

	--Production Revamp: Produktions-Modi Gesammte Produktion
	schema:register(XMLValueType.STRING, basePath .. ".productions#mode", "Mode of the production", "none")
	schema:register(XMLValueType.STRING, basePath .. ".productions#seasons", "Number of the seasons a production is working", "0 1 2 3")
	schema:register(XMLValueType.STRING, basePath .. ".productions#months", "Number of months a production is working", "1 2 3 4 5 6 7 8 9 10 11 12")
	schema:register(XMLValueType.FLOAT, basePath .. ".productions#weatherFactor", "Factor if a production is affected by weather", 1)
	schema:register(XMLValueType.STRING, basePath .. ".productions#startHour", "Starting hour for modus hourly", "0")
	schema:register(XMLValueType.STRING, basePath .. ".productions#endHour", "End hour for modus hourly", "24")
	schema:register(XMLValueType.FLOAT, basePath .. ".productions#minPower", "Minimum performance of a weather reliant production", 0)
	schema:register(XMLValueType.STRING, basePath .. ".productions#mixMode", "Changes how mix-items will be used", "ASC")
	schema:register(XMLValueType.STRING, basePath .. ".productions#boostMode", "Changes how boost-items will be used", "ASC")
	schema:register(XMLValueType.BOOL, basePath .. ".productions#hideFromMenu", "Hides Production from the Ingame-Menu", false)
	schema:register(XMLValueType.BOOL, basePath .. ".productions#autoStart", "Automatically starts a production", false)
	schema:register(XMLValueType.FLOAT, basePath .. ".productions#feedInputStorage", "Storage Size for ingredients of a FeedMixer Recipe", 1000)
	schema:register(XMLValueType.FLOAT, basePath .. ".productions#feedOutputStorage", "Storage Size for Feed Mixtures", 10000)

	--Production Revamp: Produktions-Modi Einzelne Produktionslinien
	schema:register(XMLValueType.STRING, basePath .. ".productions.production(?)#mode", "Mode of the production-line", "none")
	schema:register(XMLValueType.STRING, basePath .. ".productions.production(?)#seasons", "Number of the seasons a production-line is working", "0 1 2 3")
	schema:register(XMLValueType.STRING, basePath .. ".productions.production(?)#months", "Number of months a production-line is working", "1 2 3 4 5 6 7 8 9 10 11 12")
	schema:register(XMLValueType.FLOAT, basePath .. ".productions.production(?)#weatherFactor", "Factor if a production-line is affected by weather", 1)
	schema:register(XMLValueType.STRING, basePath .. ".productions.production(?)#startHour", "Starting hour for modus hourly", "0")
	schema:register(XMLValueType.STRING, basePath .. ".productions.production(?)#endHour", "End hour for modus hourly", "24")
	schema:register(XMLValueType.FLOAT, basePath .. ".productions.production(?)#minPower", "Minimum performance of a weather reliant production-line", 0)
	schema:register(XMLValueType.STRING, basePath .. ".productions.production(?)#mixMode", "Changes how mix-items will be used", "ASC")
	schema:register(XMLValueType.STRING, basePath .. ".productions.production(?)#boostMode", "Changes how boost-items will be used", "ASC")
	schema:register(XMLValueType.BOOL, basePath .. ".productions.production(?)#hideFromMenu", "Hide Production Line from Menue", false)
	schema:register(XMLValueType.BOOL, basePath .. ".productions.production(?)#autoStart", "Automatically starts a productionline", false)
	schema:register(XMLValueType.BOOL, basePath .. ".productions.production(?)#sharedThroughputCapacity", "Excludes a production line from sharedThroughputCapacity", false)
	schema:register(XMLValueType.FLOAT, basePath .. ".productions.production(?)#boostNumber", "Which number is the boost-mix", 6)

	--Production Revamp: Animal Trigger relevantes
	schema:register(XMLValueType.NODE_INDEX, basePath .. ".animalTrigger#triggerNode", "Node for the UnloadTrigger", nil)
	schema:register(XMLValueType.NODE_INDEX, basePath .. ".animalTrigger.inputs.input(?)#triggerNode", "Individual Node for the UnloadTrigger", nil)
	schema:register(XMLValueType.STRING, basePath .. ".animalTrigger.inputs.input(?)#animalType", "AnimalType to be used", nil)
	schema:register(XMLValueType.STRING, basePath .. ".animalTrigger.inputs.input(?)#animalSubType", "Animal SubType to be used", nil)
	schema:register(XMLValueType.STRING, basePath .. ".animalTrigger.inputs.input(?)#inputFillType", "The FillType Animals will be transformed into", nil, true)
	schema:register(XMLValueType.FLOAT, basePath .. ".animalTrigger.inputs.input(?)#minHealthFactor", "Minimum health requirement.", 50)
	schema:register(XMLValueType.FLOAT, basePath .. ".animalTrigger.inputs.input(?)#maxHealthFactor", "Maximum health requirement.", 100)
	schema:register(XMLValueType.FLOAT, basePath .. ".animalTrigger.inputs.input(?)#minAgeMonth", "Minimum age requirement.", 6)
	schema:register(XMLValueType.FLOAT, basePath .. ".animalTrigger.inputs.input(?)#maxAgeMonth", "Maximum age requirement", nil)
	schema:register(XMLValueType.BOOL, basePath .. ".animalTrigger.inputs.input(?)#calculateWeight", "Calculate remaining weight values automatically", true)
	schema:register(XMLValueType.FLOAT, basePath .. ".animalTrigger.inputs.input(?).weight(?)#ageMonth", "Age in months needed to reach value", 12)
	schema:register(XMLValueType.FLOAT, basePath .. ".animalTrigger.inputs.input(?).weight(?)#value", "Value for age", 1000)

	schema:register(XMLValueType.BOOL, basePath .. ".storage.capacity(?)#hideFromMenu", "Hide Filltype from Production Menu", False)
end

ProductionPoint.registerXMLPaths = Utils.prependedFunction(ProductionPoint.registerXMLPaths, Revamp.registerXMLPaths)



--Production Revamp: Neuen Savegame-Variable anlegen, damit der Modus "Einlagern" gespeichert werden kann & die PrioritätsEinstellung gespeichert wird
function Revamp.registerSavegameXMLPaths(schema, basePath)
	schema:register(XMLValueType.STRING, basePath .. ".storageFillType(?)", "fillType currently configured to be stored")
	schema:register(XMLValueType.STRING, basePath .. ".priorityFillType(?)", "fillType currently configured to be stored")
	schema:register(XMLValueType.STRING, basePath .. ".revampSettings(?)#id", "Production ID")
	schema:register(XMLValueType.STRING, basePath .. ".revampSettings(?)#feedMixerRecipe", "Currently Active FeedMixer Recipe")
	schema:register(XMLValueType.STRING, basePath .. ".revampSettings(?)#mixMode", "Currently Active Mix Mode")
	schema:register(XMLValueType.STRING, basePath .. ".revampSettings(?)#boostMode", "Currently Active Boost Mode")
end

ProductionPoint.registerSavegameXMLPaths = Utils.prependedFunction(ProductionPoint.registerSavegameXMLPaths, Revamp.registerSavegameXMLPaths)

--Production Revamp: Load Funktion komplett überarbeitet, um diverse neue Funktionen zu ermöglichen
function Revamp:load(superFunc, components, xmlFile, key, customEnv, i3dMappings)
	-- Pump'n'Hoses Produktionen ignorieren
	if self:isa(SandboxProductionPoint) or (self.owningPlaceable.isSandboxPlaceable ~= nil and self.owningPlaceable:isSandboxPlaceable()) then
		return superFunc(self, components, xmlFile, key, customEnv, i3dMappings);
	end

	self.node = components[1].node
	local name = xmlFile:getValue(key .. "#name")
	self.name = name and g_i18n:convertText(name, customEnv)
	self.productions = {}
	self.productionsIdToObj = {}
	self.inputFillTypeIds = {}
	self.inputFillTypeIdsArray = {}

	self.outputFillTypeIds = {}
	self.outputFillTypeIdsArray = {}
	self.outputFillTypeIdsDirectSell = {}
	self.outputFillTypeIdsAutoDeliver = {}
	self.outputFillTypeIdsToPallets = {}
	--Production Revamp: Storage-Liste hinzugefügt für "Einlagern" Funktion bei Produktionen
	self.outputFillTypeIdsStorage = {}
	--Production Revamp: Prioritäten-Liste hinzugefügt für Inputs beim Verteilen.
	self.inputFillTypeIdsPriority = {}
	--Production Revamp: Add pendingLiters für RevampSpawner-Script
	self.pendingLiters = {}
	--Production Revamp: Liste mit Filltypes die nicht direkt Verkauft werden können
	self.disableDirectSell = {}
	self.disableDistribution = {}
	self.sharedThroughputCapacity = xmlFile:getValue(key .. ".productions#sharedThroughputCapacity", true)
	self.priorityPreset = xmlFile:getValue(key .. ".productions#priorityPreset", 10)
	self.wrapColor = xmlFile:getValue(key .. ".productions#wrapColor", "0.6662 0.3839 0.5481 1")
	self.autoDeliver = xmlFile:getValue(key .. ".productions#autoDeliver", false)
	self.autoSpawn = xmlFile:getValue(key .. ".productions#autoSpawn", false)
	self.animalInputFillTypeIndexes = {}
	self.onlySellDirectly = true
	self.hiddenProductions = 0
	
	--Production Revamp: Produktions-Modi für gesamte Produktion auslesen
	local pModes = {}
	pModes.hideFromMenu = xmlFile:getValue(key .. ".productions#hideFromMenu", false)
	pModes.autoStart = xmlFile:getValue(key .. ".productions#autoStart", false)
	pModes.mode = xmlFile:getValue(key .. ".productions#mode", "")
	pModes.mixMode = xmlFile:getValue(key .. ".productions#mixMode", "ASC")
	pModes.mixMode = pModes.mixMode:upper()
	pModes.boostMode = xmlFile:getValue(key .. ".productions#boostMode", "ASC")
	pModes.boostMode = pModes.boostMode:upper()
	pModes.seasons = xmlFile:getValue(key .. ".productions#seasons", "0 1 2 3")
	pModes.months = xmlFile:getValue(key .. ".productions#months", "1 2 3 4 5 6 7 8 9 10 11 12")
	pModes.weatherFactor = xmlFile:getValue(key .. ".productions#weatherFactor", 1)
	pModes.startHour = xmlFile:getString(key .. ".productions#startHour", "0")
	pModes.endHour = xmlFile:getString(key .. ".productions#endHour", "24")
	pModes.minPower = xmlFile:getValue(key .. ".productions#minPower", 0)
	self.hoursTable = {}

	local usedProdIds = {}

	local revampCatList = {}
	local additionalStorageInput = {}
	local FarmingAgency = RevampHelper:testFarmingAgency()

	--Production Revamp: Animal Stuff laden
	self.animalTriggers = {}
	self.animalTriggerToIndex = {}
	self.animalIndexToTrigger = {}
	local animalStorage = {}	
	local hiddenStorage = {}
	--Production Revamp: Durch die Storages gehen um AnimalStorage sicher zu stellen und ausgeblendete FillTypes zu ermöglichen
	xmlFile:iterate(key..".storage.capacity", function(storageIndex, storageKey)
		local FillType = xmlFile:getValue(storageKey .. "#fillType")
		local storageType = g_fillTypeManager:getFillTypeIndexByName(FillType)
		if storageType == nil then
			Logging.xmlError(xmlFile, "Production Revamp: FillType '%s' does not exist - Production '%s'", FillType, self.owningPlaceable:getName())
		else
			animalStorage[storageType] = true
			local hide = xmlFile:getValue(storageKey .. "#hideFromMenu", false)
			if hideFromMenu == true or hide == true then
				hiddenStorage[storageType] = true
			end
		end
	end)


	if xmlFile:hasProperty(key .. ".animalTrigger") then
		self:loadAnimals(xmlFile, key, animalStorage, components, i3dMappings)
	end

	xmlFile:iterate(key .. ".productions.production", function (index, productionKey)
		local production = {
			id = xmlFile:getValue(productionKey .. "#id"),
			name = xmlFile:getValue(productionKey .. "#name", nil, customEnv, false),
		}
		local params = xmlFile:getValue(productionKey .. "#params")

		if params ~= nil then
			params = params:split("|")

			for i = 1, #params do
				params[i] = g_i18n:convertText(params[i], customEnv)
			end

			production.name = string.format(production.name, unpack(params))
		end

		if not production.id then
			Logging.xmlError(xmlFile, "missing id for production '%s'", production.name or index)

			return false
		end

		for i = 1, #usedProdIds do
			if usedProdIds[i] == production.id then
				Logging.xmlError(xmlFile, "production id '%s' already in use", production.id)

				return false
			end
		end

		table.insert(usedProdIds, production.id)

		local cyclesPerMonth = xmlFile:getValue(productionKey .. "#cyclesPerMonth")
		local cyclesPerHour = xmlFile:getValue(productionKey .. "#cyclesPerHour")
		local cyclesPerMinute = xmlFile:getValue(productionKey .. "#cyclesPerMinute")
		production.cyclesPerMinute = cyclesPerMonth and cyclesPerMonth / 60 / 24 or cyclesPerHour and cyclesPerHour / 60 or cyclesPerMinute or 1
		production.cyclesPerHour = cyclesPerHour or production.cyclesPerMinute * 60
		production.cyclesPerMonth = cyclesPerMonth or production.cyclesPerHour * 24

		local costsPerActiveMinute = xmlFile:getValue(productionKey .. "#costsPerActiveMinute")
		local costsPerActiveHour = xmlFile:getValue(productionKey .. "#costsPerActiveHour")
		local costsPerActiveMonth = xmlFile:getValue(productionKey .. "#costsPerActiveMonth")
		production.costsPerActiveMinute = costsPerActiveMonth and costsPerActiveMonth / 60 / 24 or costsPerActiveHour and costsPerActiveHour / 60 or costsPerActiveMinute or 1
		production.costsPerActiveHour = costsPerActiveHour or production.costsPerActiveMinute * 60
		production.costsPerActiveMonth = costsPerActiveMonth or production.costsPerActiveHour * 24

		production.sharedThroughputCapacity = xmlFile:getValue(productionKey .. "#sharedThroughputCapacity", self.sharedThroughputCapacity)
		production.mix = false
		production.boost = false
		production.boostNumber = xmlFile:getValue(productionKey .. "#boostNumber", 6)
		production.masterNumber = production.boostNumber + 1
		
		--Spezialitäten Production Modes laden
		production = self:loadProductionModes(production, index, productionKey, xmlFile, pModes)

		production.inputs = {}
		production.outputs = {}
		production.primaryProductFillType = nil
		
		-- Für Rezept-Anzeige aktive Stunden zählen geht nicht mit #
		local activeHoursCount = 0;
		for hour, value in pairs(production.hoursTable) do
			activeHoursCount = activeHoursCount + 1;
		end
		production.activeHours = activeHoursCount -- Hinterlegen für die Rezept-Anzeige
		production.cyclesPerMonth = MathUtil.round(((production.cyclesPerMonth / 24) * production.activeHours), 2)

		--Production Revamp: Master-Booster deaktiviert hinterlegen
		production.master = false
		production.outputWeather = false

		--Production Revamp: Produktions-Status auf an setzen für versteckte Produktionen
		if production.autoStart or production.hideFromMenu then
			production.status = ProductionPoint.PROD_STATUS.MISSING_INPUTS
		else
			production.status = ProductionPoint.PROD_STATUS.INACTIVE
		end

		--Production Revamp: Kontrollieren ob der Modus FeedMixer vorhanden ist in der Produktionslinie
		production.modes = string.split(production.mode, " ")
		for _, mode in pairs(production.modes) do
			--wenn Feed erkannt wurde
			if string.upper(mode) == "FEEDMIXER" and FarmingAgency == true then
				production = self:FMSload(xmlFile, key, production)
			end
			if string.upper(mode) == "LIMITBOOSTER" then
				production.boost = true
			end
		end

		if production.feedMixer == nil then
			xmlFile:iterate(productionKey .. ".inputs.input", function (inputIndex, inputKey)
				local input = {}

				--Production Revamp: Input über FillTypeCategory ermöglichen, funktioniert nur mit gleichen Input-Mengen
				local fillTypeCategoriesString = xmlFile:getValue(inputKey .. "#fillTypeCategory")

				if fillTypeCategoriesString == nil then
					local fillTypeString = xmlFile:getValue(inputKey .. "#fillType")
					input.type = g_fillTypeManager:getFillTypeIndexByName(fillTypeString)

					if input.type == nil then
						Logging.xmlError(xmlFile, "Unable to load fillType '%s' for '%s'", fillTypeString, inputKey)
					else
						--Production Revamp: mix, boost und masterBoost aus der XML auslesen und in der Input-Liste hinterlegen
						input.mix = xmlFile:getValue(inputKey .. "#mix", "0")
						if type(input.mix) ~= "number" then
							if input.mix:upper() == "BOOST" then
								input.mix = production.boostNumber
							elseif input.mix:upper() == "MASTER" then
								input.mix = production.masterNumber
								production.master = true
							else
								input.mix = tonumber(input.mix)
								if input.mix > 0 then
									production.mix = true
								end
							end
						else
							input.mix = tonumber(input.mix)
							if input.mix > 0 then
								production.mix = true
							end
						end

						--Production Revamp: Conditionale Outputs bei bestimmten Filltypes
						input.outputConditional = xmlFile:getValue(inputKey .. "#outputConditional", false)
						input.outputAmount = xmlFile:getValue(inputKey .. "#outputAmount", 1)
						if not input.outputConditional == false then
							input.outputConditional = g_fillTypeManager:getFillTypeIndexByName(input.outputConditional)
							if input.outputConditional == nil then
								input.outputConditional = false
								Logging.xmlError(xmlFile, "Production Revamp: Unable to load conditional output fillType '%s' for '%s'", fillTypeString, inputKey)
							else
								self.outputFillTypeIds[input.outputConditional] = true
								self.outputFillTypeIdsStorage[input.outputConditional] = true
								self.disableDistribution[input.outputConditional] = false
								self.disableDirectSell[input.outputConditional] = false
								if hiddenStorage[input.outputConditional] == nil then
									table.addElement(self.outputFillTypeIdsArray, input.outputConditional)
								end
								if input.mix == 0 then
									Logging.xmlError(xmlFile, "Production Revamp: Conditional output is only supposed to be used for mix/boost-fillTypes: '%s' for '%s'", fillTypeString, inputKey)
								end
							end
						end

						--Production Revamp: boostFactor, weatherAffected und weatherFactor auslesen
						input.boostfactor = xmlFile:getValue(inputKey .. "#boostFactor", xmlFile:getValue(inputKey .. "#boostfactor", 0))
						input.buyFactor = xmlFile:getValue(inputKey .. "#buyFactor", 2)
						input.weatherAffected = xmlFile:getValue(inputKey .. "#weatherAffected", false)
						input.weatherFactor = xmlFile:getValue(inputKey .. "#weatherFactor", 1)

						--Production Revamp: Auslesen ob Kauffunktion nicht möglich sein soll
						if self.animalInputFillTypeIndexes[input.type] == nil then
							input.allowBuying = xmlFile:getValue(inputKey .. "#allowBuying", xmlFile:getValue(inputKey .. "#allowbuying", true))
						else
							input.allowBuying = xmlFile:getValue(inputKey .. "#allowBuying", xmlFile:getValue(inputKey .. "#allowbuying", false))
						end

						--Production Revamp: Farben hinterlegen für Rezept-Anzeige
						input.color = 0

						self.inputFillTypeIds[input.type] = true

						--Production Revamp: Verteil-Priorität hinterlegen für FillTypes, 1 = wichtig, 10 = unwichtig
						self.inputFillTypeIdsPriority[input.type] = self.priorityPreset
						
						if hiddenStorage[input.type] == nil then
							table.addElement(self.inputFillTypeIdsArray, input.type)
						end


						input.amount = xmlFile:getValue(inputKey .. "#amount", 1)
						table.insert(production.inputs, input)
					end
				else
					local fillTypes = g_fillTypeManager:getFillTypesByCategoryNames(fillTypeCategoriesString, "Warning: '" .. tostring(key) .. "' has invalid fillTypeCategory '%s'.")
					local categoriesamount = xmlFile:getValue(inputKey .. "#amount", 1)
					local categoriesmix = xmlFile:getValue(inputKey .. "#mix", 0)
					if categoriesmix == "boost" then
						categoriesmix = production.boostNumber
					else
						categoriesmix = tonumber(categoriesmix)
						production.mix = true
					end
					--Production Revamp: boostFactor auslesen für die Categorie
					local categoriesBoostFactor = xmlFile:getValue(inputKey .. "#boostFactor", xmlFile:getValue(inputKey .. "#boostfactor", 0))
					local categoriesBuyFactor = xmlFile:getValue(inputKey .. "#buyFactor", 2)
					--Production Revamp: Auslesen ob Kauffunktion nicht möglich sein soll für die Categorie
					local allowBuying = xmlFile:getValue(inputKey .. "#allowBuying", xmlFile:getValue(inputKey .. "#allowbuying", true))
					for _, fillType in pairs(fillTypes) do
						local input = {}
						input.type = fillType
						input.mix = categoriesmix
						input.boostfactor= categoriesBoostFactor
						input.buyFactor= categoriesBuyFactor
						input.allowBuying = allowBuying
						input.color = 0
						self.inputFillTypeIds[input.type] = true

						--Production Revamp: Verteil-Priorität hinterlegen für FillTypes, 1 = wichtig, 10 = unwichtig
						self.inputFillTypeIdsPriority[input.type] = 10

						if hiddenStorage[input.type] == nil then
							table.addElement(self.inputFillTypeIdsArray, input.type)
						end

						input.amount = categoriesamount

						--Production Revamp: Wetterabhängig für Categorien ist nicht möglich, leere Werte hinterlegen zur Fehlervermeidung
						input.weatherAffected = false
						input.weatherFactor = 1

						table.insert(production.inputs, input)
						table.insert(revampCatList, fillType)
					end
				end
			end)
		end

		if #production.inputs == 0 then
			Logging.xmlError(xmlFile, "No inputs for production '%s'", productionKey)

			return
		end

		local maxOutputAmount = 0
		local primaryFillType = false

		if production.feedMixer == nil then
			xmlFile:iterate(productionKey .. ".outputs.output", function (outputIndex, outputKey)
				local output = {}
				local fillTypeString = xmlFile:getValue(outputKey .. "#fillType")
				output.type = g_fillTypeManager:getFillTypeIndexByName(fillTypeString)

				if output.type == nil then
					Logging.xmlError(xmlFile, "Unable to load fillType '%s' for '%s'", fillTypeString, outputKey)
				else
					output.sellDirectly = xmlFile:getValue(outputKey .. "#sellDirectly", false)
					if output.sellDirectly == false then
						self.onlySellDirectly = false
					end
					local disableDirectSell = xmlFile:getValue(outputKey .. "#disableDirectSell", false)
					if self.disableDirectSell[output.type] == nil or self.disableDirectSell[output.type] == false then
						self.disableDirectSell[output.type] = disableDirectSell
					end
					local disableDistribution = xmlFile:getValue(outputKey .. "#disableDistribution", false)
					if self.disableDistribution[output.type] == nil or self.disableDistribution[output.type] == false then
						self.disableDistribution[output.type] = disableDistribution
					end
					--Production Revamp: boost und weatherAffected aus der XML auslesen und in der Output-Liste hinterlegen
					output.boost = xmlFile:getValue(outputKey .. "#boost", true)
					output.weatherAffected = xmlFile:getValue(outputKey .. "#weatherAffected")
					output.weatherFactor = xmlFile:getValue(outputKey .. "#weatherFactor", 1)

					if not output.weatherAffected==false then
						production.outputWeather = true
					end

					if not output.sellDirectly then
						self.outputFillTypeIds[output.type] = true
						--Production Revamp: Alle Produktionen Standardmäßig auf Einlagern, bei AutoDeliver das Verteilen aktivieren
						if self.autoDeliver == true then
							self.outputFillTypeIdsAutoDeliver[output.type] = true
						elseif self.autoSpawn == true then
							self.outputFillTypeIds[output.type] = true
						else
							self.outputFillTypeIdsStorage[output.type] = true
						end
						if hiddenStorage[output.type] == nil then
							table.addElement(self.outputFillTypeIdsArray, output.type)
						end
					else
						self.soldFillTypesToPayOut[output.type] = 0
					end

					output.amount = xmlFile:getValue(outputKey .. "#amount", 1)

					--Production Revamp primaryProductFillType Einstellbar machen
					local primaryProductFillType = xmlFile:getValue(outputKey .. "#primaryProductFillType", false)
					if primaryProductFillType then
						primaryFillType = true
						production.primaryProductFillType = output.type
						maxOutputAmount = output.amount
					end

					table.insert(production.outputs, output)

					if maxOutputAmount < output.amount and primaryFillType==false then
						production.primaryProductFillType = output.type
						maxOutputAmount = output.amount
					end
				end
			end)
		end

		if #production.outputs == 0 then
			Logging.xmlError(xmlFile, "No outputs for production '%s'", productionKey)
		end

		if self.isClient then
			production.samples = {
				active = g_soundManager:loadSampleFromXML(xmlFile, productionKey .. ".sounds", "active", self.baseDirectory, components, 1, AudioGroup.ENVIRONMENT, i3dMappings, nil)
			}
			production.animationNodes = g_animationManager:loadAnimations(xmlFile, productionKey .. ".animationNodes", components, self, i3dMappings)
			production.effects = g_effectManager:loadEffect(xmlFile, productionKey .. ".effectNodes", components, self, i3dMappings)

			g_effectManager:setFillType(production.effects, FillType.UNKNOWN)
		end

		if self.productionsIdToObj[production.id] ~= nil then
			Logging.xmlError(xmlFile, "Error: production id '%s' already used", production.id)

			return false
		end

		self.productionsIdToObj[production.id] = production

		table.insert(self.productions, production)

		--Production Revamp: Produktion in die Liste der Aktiven Produktionen eintragen, damit diese immer an sind
		if production.autoStart or production.hideFromMenu then
			table.insert(self.activeProductions, production)
		end

		return true
	end)

	if #self.productions == 0 then
		Logging.xmlError(xmlFile, "No valid productions defined")
	end

	if self.owningPlaceable == nil then
		print("Error: ProductionPoint.owningPlaceable was not set before load()")

		return false
	end

	self.interactionTriggerNode = xmlFile:getValue(key .. ".playerTrigger#node", nil, components, i3dMappings)

	if self.interactionTriggerNode ~= nil then
		addTrigger(self.interactionTriggerNode, "interactionTriggerCallback", self)
	end

	if self.isClient then
		self.samples = {
			idle = g_soundManager:loadSampleFromXML(xmlFile, key .. ".sounds", "idle", self.baseDirectory, components, 1, AudioGroup.ENVIRONMENT, i3dMappings, nil),
			active = g_soundManager:loadSampleFromXML(xmlFile, key .. ".sounds", "active", self.baseDirectory, components, 1, AudioGroup.ENVIRONMENT, i3dMappings, nil)
		}
		self.animationNodes = g_animationManager:loadAnimations(xmlFile, key .. ".animationNodes", components, self, i3dMappings)
		self.effects = g_effectManager:loadEffect(xmlFile, key .. ".effectNodes", components, self, i3dMappings)

		g_effectManager:setFillType(self.effects, FillType.UNKNOWN)
	end

	self.unloadingStation = SellingStation.new(self.isServer, self.isClient)

	self.unloadingStation:load(components, xmlFile, key .. ".sellingStation", self.customEnvironment, i3dMappings, components[1].node)

	self.unloadingStation.storeSoldGoods = true
	self.unloadingStation.skipSell = self.owningPlaceable:getOwnerFarmId() ~= AccessHandler.EVERYONE

	function self.unloadingStation.getIsFillAllowedFromFarm(_, farmId)
		--Production Revamp: Überschrieben um Missionen und Verkaufen zu ermöglichen
		--return g_currentMission.accessHandler:canFarmAccess(farmId, self.owningPlaceable)
		return true
	end

	self.unloadingStation:register(true)
	local loadingStationKey = key .. ".loadingStation"

	if xmlFile:hasProperty(loadingStationKey) then
		self.loadingStation = LoadingStation.new(self.isServer, self.isClient)

		if not self.loadingStation:load(components, xmlFile, loadingStationKey, self.customEnvironment, i3dMappings, components[1].node) then
			Logging.xmlError(xmlFile, "Unable to load loading station %s", loadingStationKey)

			return false
		end

		function self.loadingStation.hasFarmAccessToStorage(_, farmId)
			return farmId == self.owningPlaceable:getOwnerFarmId()
		end

		self.loadingStation.owningPlaceable = self.owningPlaceable

		self.loadingStation:register(true)		
	end

	self.woodSpawnPlace = xmlFile:getValue(key.."#woodSpawnPlace", nil, components, i3dMappings);
	self.maxWoodLogs = xmlFile:getValue(key .. "#maxWoodLogs") or 15;
	self.minWoodLogLength = xmlFile:getValue(key .. "#minWoodLogLength") or 6;
	self.maxWoodLogLength = xmlFile:getValue(key .. "#maxWoodLogLength") or 6;

	local palletSpawnerKey = key .. ".palletSpawner"

	if xmlFile:hasProperty(palletSpawnerKey) then
		self.palletSpawner = PalletSpawner.new(self.baseDirectory)

		if not self.palletSpawner:load(components, xmlFile, key .. ".palletSpawner", self.customEnvironment, i3dMappings) then
			Logging.xmlError(xmlFile, "Unable to load pallet spawner %s", palletSpawnerKey)

			return false
		end
	end

	if self.loadingStation == nil and self.palletSpawner == nil and self.onlySellDirectly == false then
		Logging.xmlError(xmlFile, "No loading station or pallet spawner for production point")

		return false
	end

	if self.palletSpawner ~= nil then
		for fillTypeId, pallet in pairs(self.palletSpawner:getSupportedFillTypes()) do
			if self.outputFillTypeIds[fillTypeId] then
				self.outputFillTypeIdsToPallets[fillTypeId] = pallet
			end
		end

		--Production Revamp: inline function to only override when it is a production point to have no effect on silos
		function self.palletSpawner:update(dt)
			if #self.spawnQueue > 0 then
				if self.currentObjectToSpawn == nil then
					self.currentObjectToSpawn = self.spawnQueue[1]
					local spawnPlaces = self.fillTypeToSpawnPlaces[self.currentObjectToSpawn.fillType] or self.spawnPlaces

					if self.currentObjectToSpawn.pallet.isBale==nil then
						g_currentMission.placementManager:getPlaceAsync(spawnPlaces, self.currentObjectToSpawn.pallet.size, self.onSpawnSearchFinished, self)
					else
						g_currentMission.placementManager:getPlaceAsync(spawnPlaces, self.currentObjectToSpawn.pallet.size, self.onSpawnSearchFinishedBale, self)
					end
				end
			else
				g_currentMission:removeUpdateable(self)
			end
		end
	end

	self.storage = Storage.new(self.isServer, self.isClient)

	self.storage:load(components, xmlFile, key .. ".storage", i3dMappings)
	self.storage:register(true)
	-- Production Revamp: Bei Verwendung von Kategorien für die inputs für jeden input der Kategorie die Gesamtkapazität als Einzelkapazität eintragen, da sonst die Berechnungen nicht korrekt sind
	for _, filltype in ipairs(revampCatList) do
		if(self.storage.capacities[filltype] == nil) then
			self.storage.capacities[filltype] = self.storage.capacity
		end
	end

	if self.loadingStation ~= nil then
		if not self.loadingStation:addSourceStorage(self.storage) then
			if self.onlySellDirectly == false then
				Logging.xmlWarning(xmlFile, "Unable to add source storage ")
			end
		end

		g_currentMission.storageSystem:addLoadingStation(self.loadingStation, self.owningPlaceable)
	end

	self.unloadingStation:addTargetStorage(self.storage)

	-- Production Revamp: Bei Verwendung eines Feedmixers, Input-FillTypes im Lager eintragen und UnloadTrigger erweitern.
	if self.feedMixer ~= nil then
		local production = self.productions[self.feedMixer.id]
		self:FMSchangeFillTypes(production.inputs, production.outputs)
	end

	for inputFillTypeIndex in pairs(self.inputFillTypeIds) do
		if not self.unloadingStation:getIsFillTypeSupported(inputFillTypeIndex) and self.animalInputFillTypeIndexes[inputFillTypeIndex] == nil then
			local fillTypeName = g_fillTypeManager:getFillTypeNameByIndex(inputFillTypeIndex)

			Logging.xmlWarning(xmlFile, "Input filltype '%s' is not supported by unloading station", fillTypeName)
		end
	end

	for outputFillTypeIndex in pairs(self.outputFillTypeIds) do
		if (self.loadingStation == nil or not self.loadingStation:getIsFillTypeSupported(outputFillTypeIndex)) and self.outputFillTypeIdsToPallets[outputFillTypeIndex] == nil then
			local fillTypeName = g_fillTypeManager:getFillTypeNameByIndex(outputFillTypeIndex)

			Logging.xmlWarning(xmlFile, "Output filltype '%s' is not supported by loading station or pallet spawner", fillTypeName)
		end
	end

	self.unloadingStation.owningPlaceable = self.owningPlaceable

	g_currentMission.storageSystem:addUnloadingStation(self.unloadingStation, self.owningPlaceable)
	g_currentMission.economyManager:addSellingStation(self.unloadingStation)

	for i = 1, #self.productions do
		local production = self.productions[i]

		for x = 1, #production.inputs do
			local input = production.inputs[x]

			if not self.storage:getIsFillTypeSupported(input.type) then
				Logging.xmlError(xmlFile, "production point storage does not support fillType '%s' used as in input in production '%s'", g_fillTypeManager:getFillTypeNameByIndex(input.type), production.name)

				return false
			end
		end

		for x = 1, #production.outputs do
			local output = production.outputs[x]

			if not output.sellDirectly and not self.storage:getIsFillTypeSupported(output.type) then
				Logging.xmlError(xmlFile, "production point storage does not support fillType '%s' used as an output in production '%s'", g_fillTypeManager:getFillTypeNameByIndex(output.type), production.name)

				return false
			end
		end
	end

	for supportedFillType, _ in pairs(self.storage:getSupportedFillTypes()) do
		if not self.inputFillTypeIds[supportedFillType] and not self.outputFillTypeIds[supportedFillType] then
			Logging.xmlWarning(xmlFile, "storage fillType '%s' not used as a production input or ouput", g_fillTypeManager:getFillTypeNameByIndex(supportedFillType))
		end
	end
	
	--Production Revamp: Bezeichnung des Trigger mit Holz einlagern statt Holz Verkaufen
	if self.unloadingStation ~= nil then
		if self.unloadingStation.unloadTriggers ~= nil then
			for _, unloadTrigger in pairs(self.unloadingStation.unloadTriggers) do
				if unloadTrigger.woodTrigger ~= nil and unloadTrigger.woodTrigger.activatable ~= nil then
					if self.owningPlaceable:getOwnerFarmId() ~= AccessHandler.EVERYONE then
						unloadTrigger.woodTrigger.activatable.activateText = g_i18n:getText("Revamp_storeWoodlogs")
					end
				end
			end
		end
	end

	--Production Revamp: Trigger zum abladen von Tieren zusammenstellen und laden
	self.animalStation = RevampAnimalStation.new(self.isServer, self.isClient)

	if not self.animalStation:load(self) then
		self.animalStation:delete()
	end

	-- hier unsere überschreibung, wenn nicht aus dem Savegame geladen ist
	self.getNextOutputDistributionMode = Utils.overwrittenFunction(self.getNextOutputDistributionMode, RevampPriority.getNextOutputDistributionMode)

	return true
end

ProductionPoint.load = Utils.overwrittenFunction(ProductionPoint.load, Revamp.load)



function Revamp:delete()
	if self.animalStation ~= nil then
		self.animalStation:delete()

		self.animalStation = nil
	end
end

ProductionPoint.delete = Utils.prependedFunction(ProductionPoint.delete, Revamp.delete)



--Production Revamp: Auslesen, ob ein FillType versteckt werden soll.
function ProductionPoint:getHiddenFillType(fillTypeId)
	if self.storage.hide[fillTypeId] ~= nil then
		return false
	end
	return true
end



--Production Revamp: Überschrieben um neues Produktionsscript einfügen zu können
function Revamp:updateProduction(superFunc)

	-- Pump'n'Hoses Produktionen ignorieren
	if self:isa(SandboxProductionPoint) or (self.owningPlaceable.isSandboxPlaceable ~= nil and self.owningPlaceable:isSandboxPlaceable()) then
		return superFunc(self)
	end

	if self.lastUpdatedTime == nil then
		self.lastUpdatedTime = g_time
		return
	end

	local dt = MathUtil.clamp(g_time - self.lastUpdatedTime, 0, 30000)
	local timeAdjust = g_currentMission.environment.timeAdjustment
	local numActiveProductions = #self.activeProductions

	if numActiveProductions > 0 then
		local minuteFactorTimescaledDt = dt * self.minuteFactorTimescaled * timeAdjust

		--Alle aktiven Produktionen einmal durchgehen um Ausnahmen von sharedThroughputCapacity festzustellen
		local numSharedThroughputCapacity = 0
		if self.sharedThroughputCapacity  == true then
			for n = 1, numActiveProductions do
				local production = self.activeProductions[n]
				if production.sharedThroughputCapacity == true then
					numSharedThroughputCapacity = numSharedThroughputCapacity + 1
				end
			end
		else
			numSharedThroughputCapacity = 1
		end

		for n = 1, numActiveProductions do
			local production = self.activeProductions[n]
			local cyclesPerMinuteMinuteFactor = production.cyclesPerMinute * minuteFactorTimescaledDt / (self.sharedThroughputCapacity and numSharedThroughputCapacity or 1)
			--Sollte ProduktionsLinie von sharedThroughputCapacity ausgenommen sein
			if production.sharedThroughputCapacity == false then
				cyclesPerMinuteMinuteFactor = production.cyclesPerMinute * minuteFactorTimescaledDt
			end

			local skip = false
			local FMS = false

			--Production Revamp: Produktionen die andere Produktions-Modi verwenden, hier werden die Zyklen neu berechnet
			for _, mode in pairs(production.modes) do
				if mode=="FEEDMIXER" then
					FMS = true
				end
				cyclesPerMinuteMinuteFactor, skip = self:processProductionMode(production, mode, cyclesPerMinuteMinuteFactor, skip)

				if skip ~= false then
					if skip ~= true then
						production.status = skip
						self.owningPlaceable:productionStatusChanged(production, skip)
						self:setProductionStatus(production.id, skip)
					end

					break
				end
			end

			--Production Revamp: mix-gruppen/boostgruppe hinzufügen und auf false stellen
			local enoughInputResources = true
			local enoughInput = {}
			local useFillType = {}
			local useFillTypeLevel = {}
			local enoughOutputSpace = true
			local maxnum = 0
			local booster = 1
			local masterFactor = 1
			local boostFillType = {}
			boostFillType[production.boostNumber] = 0
			boostFillType[production.masterNumber] = 0
			
			if FMS == false then
			--Production Revamp: Überprüfen ob ein Master-Booster vorhanden ist, falls vorhanden, dann masterFactor auslesen
				if production.master then
					for t = 1, #production.inputs do
						local input = production.inputs[t]
						local fillLevel = self:getFillLevel(input.type)
						local needamount = input.amount * cyclesPerMinuteMinuteFactor

						if input.mix == production.masterNumber and fillLevel > needamount then
							if production.boostMode == "MOST" then
								if input.boostfactor > masterFactor then
										masterFactor = input.boostfactor
										boostFillType[production.masterNumber] = input.type
								end
							elseif production.boostMode == "LEAST" then
								if input.boostfactor < masterFactor then
										masterFactor = input.boostfactor
										boostFillType[production.masterNumber] = input.type
								end
							else
								masterFactor = masterFactor + input.boostfactor
							end
						end
					end
				end

				--Production Revamp: Dieser Abschnitt kontrolliert, ob ein /alle notwendigen Inputs in den jeweiligen Gruppe vorhanden sind
				--Production Revamp: Farben hinterlegen für die Rezept-Anzeige, 0=weiß(vorhanden) 1=fehlt(wird benötigt) 2=(optional, nicht vorhanden)
				for x = 1, #production.inputs do
					local input = production.inputs[x]

					--Production Revamp: Wetterabhängige Zugewinne im Input
					if not input.weatherAffected==false then
						self:processWeather(input.weatherAffected, input.weatherFactor, input.amount, input.type, cyclesPerMinuteMinuteFactor)
					end

					local fillLevel = self:getFillLevel(input.type)
					local factor = cyclesPerMinuteMinuteFactor * masterFactor
					local needamount = input.amount * factor
					local color = 0

					if input.mix == production.masterNumber then
						local boostamount = cyclesPerMinuteMinuteFactor * input.amount
						if fillLevel < boostamount then
							color = 2
						end
					elseif input.mix == production.boostNumber then
						if fillLevel >= needamount then
							if production.boost == true then
								if production.boostMode == "MOST" and input.boostfactor > booster then
									booster = input.boostfactor + 1
									boostFillType[production.boostNumber] = input.type
								elseif production.boostMode == "LEAST" and input.boostfactor < booster then
									booster = input.boostfactor + 1
									boostFillType[production.boostNumber] = input.type
								elseif production.boostMode == "DESC" then
									booster = input.boostfactor + 1
									boostFillType[production.boostNumber] = input.type
								elseif production.boostMode == "ASC" and boostFillType[production.boostNumber] == 0 then
									booster = input.boostfactor + 1
									boostFillType[production.boostNumber] = input.type
								end
							else
								booster = booster + input.boostfactor
							end
						else
							color = 2
						end
					elseif input.mix == 0 then
						if fillLevel < needamount then
							enoughInputResources = false
							color = 1
						end
					else
						maxnum, enoughInput, color, useFillType, useFillTypeLevel = self:processMix(input.mix, maxnum, needamount, fillLevel, enoughInput, useFillType, useFillTypeLevel, input.type, production.mixMode)
					end

					if color~=input.color then
						self:setProductionInputColor(production.id, x, color)
					end
				end

				--Production Revamp: dieser Abschnitt wertet die Ergebnisse der einzelnen Input-Gruppen aus
				if enoughInputResources and maxnum == #enoughInput then
					for x = 1, #enoughInput do
						local input = enoughInput[x]
						if not input then
							enoughInputResources = false
						end
					end
				end

					--Production Revamp: Wetterabhängige Zugewinne im Output
				if production.outputWeather then
					for x = 1, #production.outputs do
						local output = production.outputs[x]
						if output.weatherAffected==true then
							self:processWeather(output.weatherAffected, output.weatherFactor, output.amount, output.type, cyclesPerMinuteMinuteFactor)
						end
					end
				end
			else
				--FMS
				enoughInputResources, enoughInput, useFillType = self:FMScalculate(production, cyclesPerMinuteMinuteFactor)
			end

			if enoughInputResources == false and self.isOwned then
				if production.status ~= ProductionPoint.PROD_STATUS.MISSING_INPUTS then
					production.status = ProductionPoint.PROD_STATUS.MISSING_INPUTS

					self.owningPlaceable:productionStatusChanged(production, ProductionPoint.PROD_STATUS.MISSING_INPUTS)
					self:setProductionStatus(production.id, production.status)

					break
				end
			end

			if not skip then
				if enoughInputResources and self.isOwned then
					for x = 1, #production.outputs do
						local output = production.outputs[x]

						if not output.sellDirectly then
							local freeCapacity = self.storage:getFreeCapacity(output.type)

							--Production Revamp: Erweitert um den booster, um zu Kontrollieren ob genug Platz vorhanden wäre
							if freeCapacity < output.amount * cyclesPerMinuteMinuteFactor * booster * masterFactor then
								enoughOutputSpace = false

								if production.status ~= ProductionPoint.PROD_STATUS.NO_OUTPUT_SPACE then
									production.status = ProductionPoint.PROD_STATUS.NO_OUTPUT_SPACE

									self:setProductionStatus(production.id, production.status)
								end

								break
							end
						end
					end
				end

				if self.isOwned then
					self.productionCostsToClaim = self.productionCostsToClaim + production.costsPerActiveMinute * minuteFactorTimescaledDt
				end

				if not self.isOwned or enoughInputResources and enoughOutputSpace then
					local factor = cyclesPerMinuteMinuteFactor
					local mfactor = factor
					factor = factor * masterFactor

					--Production Revamp: Dieser Abschnitt entfernt die Verarbeiteten Inputs aus dem Silo
					for y = 1, #production.inputs do
						local input = production.inputs[y]
						local fillLevel = self:getFillLevel(input.type)

						if input.mix == production.masterNumber then
							self:processInput(self, input, mfactor, fillLevel, enoughInput, production.mixMode, useFillType, boostFillType, production)
						else
							self:processInput(self, input, factor, fillLevel, enoughInput, production.mixMode, useFillType, boostFillType, production)
						end
					end

					--Production Revamp: Output-Güter dem Silo gutschreiben in Abhängigkeit vom booster, wenn boost nicht deaktiviert wurde für den jeweiligen Filltype
					if self.isOwned then
						--Production Revamp: Umkehrbooster hinterlegen
						local boosterreverse = 1 - (booster - 1)
						if boosterreverse < 0 then
							boosterreverse = 0
						end
						for y = 1, #production.outputs do
							local output = production.outputs[y]
							if output.sellDirectly then
								if self.isServer then
									if output.boost == true then
										self.soldFillTypesToPayOut[output.type] = self.soldFillTypesToPayOut[output.type] + output.amount * factor * booster
									elseif output.boost == "reverse" then
										self.soldFillTypesToPayOut[output.type] = self.soldFillTypesToPayOut[output.type] + output.amount * factor * boosterreverse
									else
										self.soldFillTypesToPayOut[output.type] = self.soldFillTypesToPayOut[output.type] + output.amount * factor
									end
								end
							else
								local fillLevel = self.storage:getFillLevel(output.type)
								if output.boost == true then
									self.storage:setFillLevel(fillLevel + output.amount * factor * booster, output.type)
								elseif output.boost == "reverse" then
									self.storage:setFillLevel(fillLevel + output.amount * factor * boosterreverse, output.type)
								else
									self.storage:setFillLevel(fillLevel + output.amount * factor, output.type)
								end
							end
						end
					end

					if production.status ~= ProductionPoint.PROD_STATUS.RUNNING then
						production.status = ProductionPoint.PROD_STATUS.RUNNING

						self.owningPlaceable:productionStatusChanged(production, production.status)
						ProductionPointProductionStatusEvent.sendEvent(self, production.id, production.status)
					end
				end
			end
		end
	end

	if self.isServer and self.isOwned and self.palletSpawnCooldown < g_time and not self.waitingForPalletToSpawn then
		local nextFillTypeId = nil
		
		--Production Revamp: Automatisches Auslagern nur während der Produktionszeiten, wie beim manuellen Spawnen
		local currentHour = g_currentMission.environment.currentHour
		if self.hoursTable[currentHour] then
			while true do
				local fillTypeId = self.lastPalletFillTypeId

				if fillTypeId ~= nil and self.outputFillTypeIdsDirectSell[fillTypeId] == nil and self.outputFillTypeIdsAutoDeliver[fillTypeId] == nil and self.outputFillTypeIdsStorage[fillTypeId] == nil then
					local fillLevel = self.storage:getFillLevel(fillTypeId)

					if fillLevel > 0 then
						local pallet = self.outputFillTypeIdsToPallets[fillTypeId]

						if pallet and pallet.capacity <= fillLevel then
							nextFillTypeId = fillTypeId

							break
						end
					end
				end

				self.lastPalletFillTypeId = next(self.outputFillTypeIdsToPallets, self.lastPalletFillTypeId)

				if self.lastPalletFillTypeId == nil then
					break
				end
			end

			if nextFillTypeId ~= nil then
				self.waitingForPalletToSpawn = true

				self.palletSpawner:spawnPallet(self:getOwnerFarmId(), nextFillTypeId, self.palletSpawnRequestCallback, self)
			end
		end
	end

	self.lastUpdatedTime = g_time
end

ProductionPoint.updateProduction = Utils.overwrittenFunction(ProductionPoint.updateProduction, Revamp.updateProduction)



--Production Revamp: LoadFromXML überschrieben um die "Einlagern" Option aus dem Savegame laden zu können, Erweitert um die Prioritäten für Inputs aus dem Savegame laden zu können
function Revamp:loadFromXMLFile(superFunc, xmlFile, key)

	-- Pump'n'Hoses Produktionen ignorieren
	if self:isa(SandboxProductionPoint) or (self.owningPlaceable.isSandboxPlaceable ~= nil and self.owningPlaceable:isSandboxPlaceable()) then
		RevampDebugHelper:Debug(self.owningPlaceable.configFileName, "Revamp", "skip loading because Pump'n'Hoses production");
		return superFunc(self, xmlFile, key);
	end
	
	RevampDebugHelper:Debug(self.owningPlaceable.configFileName, "Revamp", "loading");

	local palletSpawnCooldown = xmlFile:getValue(key .. "#palletSpawnCooldown")

	if palletSpawnCooldown then
		self.palletSpawnCooldown = g_time + palletSpawnCooldown
	end

	self.productionCostsToClaim = xmlFile:getValue(key .. "#productionCostsToClaim") or self.productionCostsToClaim

	if self.owningPlaceable.ownerFarmId == AccessHandler.EVERYONE then
		for n = 1, #self.productions do
			self:setProductionState(self.productions[n].id, true)
		end
	end

	xmlFile:iterate(key .. ".revampSettings", function (index, productionKey)
		local prodId = xmlFile:getValue(productionKey .. "#id")
		local mixMode = xmlFile:getValue(productionKey .. "#mixMode", "ASC")
		local boostMode = xmlFile:getValue(productionKey .. "#boostMode", "ASC")
		local feedMixerRecipe = xmlFile:getValue(productionKey .. "#feedMixerRecipe")
		if feedMixerRecipe ~= nil then
			local feedIndex = g_fillTypeManager:getFillTypeIndexByName(feedMixerRecipe)
			if feedIndex == nil then
				Logging.error("Production Revamp: Unable to load fillType '%s' for '%s'", feedMixerRecipe, prodId)
				feedMixerRecipe = nil
			else
				feedMixerRecipe = feedIndex
			end
		end
		if self.productionsIdToObj[prodId] == nil then
			Logging.xmlWarning(xmlFile, "Unknown production id '%s'", prodId)
		else
			self:setRevampSettings(prodId, mixMode, boostMode, feedMixerRecipe)
		end
	end)

	xmlFile:iterate(key .. ".production", function (index, productionKey)
		local prodId = xmlFile:getValue(productionKey .. "#id")
		local isEnabled = xmlFile:getValue(productionKey .. "#isEnabled")

		if self.productionsIdToObj[prodId] == nil then
			Logging.xmlWarning(xmlFile, "Unknown production id '%s'", prodId)
		else
			self:setProductionState(prodId, isEnabled)
		end
	end)

	--Production Revamp: Alle Filltype auf Auslagern stellen, damit diese anschließend aus dem Savegame richtig geladen werden
	for fillType in pairs(self.outputFillTypeIds) do
		if self.outputFillTypeIdsAutoDeliver[fillType] == nil then
			if not self.mission.missionInfo.isNewSPCareer then
				self:setOutputDistributionMode(fillType, ProductionPoint.OUTPUT_MODE.KEEP)
			end
		end
	end

	xmlFile:iterate(key .. ".directSellFillType", function (index, directSellKey)
		local fillType = g_fillTypeManager:getFillTypeIndexByName(xmlFile:getValue(directSellKey))

		if fillType then
			self:setOutputDistributionMode(fillType, ProductionPoint.OUTPUT_MODE.DIRECT_SELL)
		end
	end)

	xmlFile:iterate(key .. ".autoDeliverFillType", function (index, autoDeliverKey)
		local fillType = g_fillTypeManager:getFillTypeIndexByName(xmlFile:getValue(autoDeliverKey))

		if fillType then
			self:setOutputDistributionMode(fillType, ProductionPoint.OUTPUT_MODE.AUTO_DELIVER)
		end
	end)

	--Production Revamp: Hinzugefügt um die "Einlagern" Option aus dem Savegame laden zu können
	xmlFile:iterate(key .. ".storageFillType", function (index, storageKey)
		local fillType = g_fillTypeManager:getFillTypeIndexByName(xmlFile:getValue(storageKey))

		if fillType then
			self:setOutputDistributionMode(fillType, ProductionPoint.OUTPUT_MODE.STORE)
		end
	end)

	--Production Revamp: Hinzugefügt um die Prioritäten für Inputs aus dem Savegame laden zu können
	xmlFile:iterate(key .. ".priorityFillType", function (index, priorityKey)
		local priorityType = xmlFile:getValue(priorityKey)
		local split = string.split(priorityType, " ")	
		local fillType = g_fillTypeManager:getFillTypeIndexByName(split[1])
		local priority = tonumber(split[2])
		if fillType then
			self:setInputPriority(fillType, priority)
		end
	end)

	if not self.storage:loadFromXMLFile(xmlFile, key .. ".storage") then
		return false
	end

	return true
end

ProductionPoint.loadFromXMLFile = Utils.overwrittenFunction(ProductionPoint.loadFromXMLFile, Revamp.loadFromXMLFile)



--Production Revamp: SaveToXML überschrieben um die Einstellung "Einlagern" speichern zu können
function Revamp:saveToXMLFile(superFunc, xmlFile, key, usedModNames)

	-- Pump'n'Hoses Produktionen ignorieren
	if self:isa(SandboxProductionPoint) or (self.owningPlaceable.isSandboxPlaceable ~= nil and self.owningPlaceable:isSandboxPlaceable()) then
		return superFunc(self, xmlFile, key, usedModNames);
	end

	if g_time < self.palletSpawnCooldown then
		xmlFile:setValue(key .. "#palletSpawnCooldown", self.palletSpawnCooldown - g_time)
	end

	if self.productionCostsToClaim ~= 0 then
		xmlFile:setValue(key .. "#productionCostsToClaim", self.productionCostsToClaim)
	end

	local xmlIndex = 0
	for i = 1, #self.productions do
		local production = self.productions[i]
		local productionKey = string.format("%s.revampSettings(%i)", key, xmlIndex)

		if production.mixMode ~= "ASC" or production.boostMode ~= "ASC" or production.feedMixer ~= nil then
			xmlFile:setValue(productionKey .. "#id", production.id)
			if production.mixMode ~= "ASC" then
				xmlFile:setValue(productionKey .. "#mixMode", production.mixMode)
			end
			if production.boostMode ~= "ASC" then
				xmlFile:setValue(productionKey .. "#boostMode", production.boostMode)
			end
			if production.feedMixer ~= nil then
				xmlFile:setValue(productionKey .. "#feedMixerRecipe", g_fillTypeManager:getFillTypeNameByIndex(production.feedMixer.selected))
			end
		end

		xmlIndex = xmlIndex + 1
	end

	local xmlIndex = 0
	for i = 1, #self.activeProductions do
		local production = self.activeProductions[i]
		local productionKey = string.format("%s.production(%i)", key, xmlIndex)

		xmlFile:setValue(productionKey .. "#id", production.id)
		xmlFile:setValue(productionKey .. "#isEnabled", true)

		xmlIndex = xmlIndex + 1
	end

	xmlFile:setTable(key .. ".directSellFillType", self.outputFillTypeIdsDirectSell, function (fillTypeKey, _, fillTypeId)
		local fillType = g_fillTypeManager:getFillTypeNameByIndex(fillTypeId)

		xmlFile:setValue(fillTypeKey, fillType)
	end)
	xmlFile:setTable(key .. ".autoDeliverFillType", self.outputFillTypeIdsAutoDeliver, function (fillTypeKey, _, fillTypeId)
		local fillType = g_fillTypeManager:getFillTypeNameByIndex(fillTypeId)

		xmlFile:setValue(fillTypeKey, fillType)
	end)
	--Production Revamp: Hinzugefügt um die "Einlagern" Option Speichern zu können
	xmlFile:setTable(key .. ".storageFillType", self.outputFillTypeIdsStorage, function (fillTypeKey, _, fillTypeId)
		local fillType = g_fillTypeManager:getFillTypeNameByIndex(fillTypeId)

		xmlFile:setValue(fillTypeKey, fillType)
	end)

	--Production Revamp: Hinzugefügt um Prioritäten speichern zu können
	xmlFile:setTable(key .. ".priorityFillType", self.inputFillTypeIdsPriority, function (fillTypeKey, _, fillTypeId)
		local fillType = g_fillTypeManager:getFillTypeNameByIndex(fillTypeId)
		local priority = self.inputFillTypeIdsPriority[fillTypeId]
		fillType = fillType .. " " .. priority

		xmlFile:setValue(fillTypeKey, fillType)
	end)

	self.storage:saveToXMLFile(xmlFile, key .. ".storage", usedModNames)
end

ProductionPoint.saveToXMLFile = Utils.overwrittenFunction(ProductionPoint.saveToXMLFile, Revamp.saveToXMLFile)



--Production Revamp: readStream überschrieben um die Einlagern-Funktion, Prioritäten und Farb-Rezepte im Multiplayer synchronisieren zu können
function Revamp:readStream(superFunc, streamId, connection)
	-- Pump'n'Hoses Produktionen ignorieren
	if self:isa(SandboxProductionPoint) or (self.owningPlaceable.isSandboxPlaceable ~= nil and self.owningPlaceable:isSandboxPlaceable()) then
		return superFunc(self, streamId, connection);
	end

	ProductionPoint:superClass().readStream(self, streamId, connection)

	if connection:getIsServer() then
		-- connection is to server, so here is client and we receive from server
		-- receive data from the server
		
		-- set all lines to KEEP so the sync can correct the send items when set to something different
		-- needed because otherwise all on KEEP will stay on STORE on the connected client while the server use KEEP
		--Production Revamp: mixmode/boostmode/feedMixerRecipe synchronisieren

		for i = 1, streamReadUInt8(streamId) do
			for i = 1, streamReadUInt8(streamId) do
				local productionId = streamReadString(streamId)
				local feedFillType = streamReadUIntN(streamId, FillTypeManager.SEND_NUM_BITS)
				self:setRevampSettings(productionId, nil, nil, feedFillType, true)
			end

			for i = 1, streamReadUInt8(streamId) do
				local productionId = streamReadString(streamId)
				local mixMode = streamReadString(streamId)
				self:setRevampSettings(productionId, mixMode, nil, nil, true)
			end

			for i = 1, streamReadUInt8(streamId) do
				local productionId = streamReadString(streamId)
				local boostMode = streamReadString(streamId)
				self:setRevampSettings(productionId, nil, boostMode, nil, true)
			end
		end

		for fillType in pairs(self.outputFillTypeIds) do
			if self.outputFillTypeIdsAutoDeliver[fillType] == nil then
				self:setOutputDistributionMode(fillType, ProductionPoint.OUTPUT_MODE.KEEP)
			end
		end

		for i = 1, streamReadUInt8(streamId) do
			self:setOutputDistributionMode(streamReadUIntN(streamId, FillTypeManager.SEND_NUM_BITS), ProductionPoint.OUTPUT_MODE.DIRECT_SELL)
		end

		for i = 1, streamReadUInt8(streamId) do
			self:setOutputDistributionMode(streamReadUIntN(streamId, FillTypeManager.SEND_NUM_BITS), ProductionPoint.OUTPUT_MODE.AUTO_DELIVER)
		end

		--Production Revamp: Neue Option "Einlagern" hinzugefügt
		for i = 1, streamReadUInt8(streamId) do
			self:setOutputDistributionMode(streamReadUIntN(streamId, FillTypeManager.SEND_NUM_BITS), ProductionPoint.OUTPUT_MODE.STORE)
		end

		--Production Revamp: Input-Prioritäten hinzugefügt
		for i = 1, streamReadUInt8(streamId) do
			local fillType = streamReadUIntN(streamId, FillTypeManager.SEND_NUM_BITS)
			local priority = streamReadUIntN(streamId, 6)
			self:setInputPriority(fillType, priority)
		end

		local unloadingStationId = NetworkUtil.readNodeObjectId(streamId)

		self.unloadingStation:readStream(streamId, connection)
		g_client:finishRegisterObject(self.unloadingStation, unloadingStationId)

		if self.loadingStation ~= nil then
			local loadingStationId = NetworkUtil.readNodeObjectId(streamId)

			self.loadingStation:readStream(streamId, connection)
			g_client:finishRegisterObject(self.loadingStation, loadingStationId)
		end

		local storageId = NetworkUtil.readNodeObjectId(streamId)

		self.storage:readStream(streamId, connection)
		g_client:finishRegisterObject(self.storage, storageId)

		for i = 1, streamReadUInt8(streamId) do
			local productionId = streamReadString(streamId)

			self:setProductionState(productionId, true)
			self:setProductionStatus(productionId, streamReadUIntN(streamId, ProductionPoint.PROD_STATUS_NUM_BITS))

			for x = 1, streamReadUInt8(streamId) do
				local productionId = streamReadString(streamId)
				local inputId = streamReadUIntN(streamId, FillTypeManager.SEND_NUM_BITS)
				local productionInputColor = streamReadUIntN(streamId, FillTypeManager.SEND_NUM_BITS)
				self:setProductionInputColor(productionId, inputId, productionInputColor)
			end
		end

		self.palletLimitReached = streamReadBool(streamId)
	end
end

ProductionPoint.readStream = Utils.overwrittenFunction(ProductionPoint.readStream, Revamp.readStream)



--Production Revamp: writeStream überschrieben um die Einlagern-Funktion, Prioritäten und Farb-Rezepte im Multiplayer synchronisieren zu können
function Revamp:writeStream(superFunc, streamId, connection)

	-- Pump'n'Hoses Produktionen ignorieren
	if self:isa(SandboxProductionPoint) or (self.owningPlaceable.isSandboxPlaceable ~= nil and self.owningPlaceable:isSandboxPlaceable()) then
		return superFunc(self, streamId, connection);
	end

	ProductionPoint:superClass().writeStream(self, streamId, connection)

	if not connection:getIsServer() then
		-- connection is not to server, so here is server and we write to client
		-- send data to the client
		streamWriteUInt8(streamId, table.size(self.productions))

		for i = 1, #self.productions do
			local production = self.productions[i]
			--Production Revamp: mixmode/boostmode/feedMixerRecipe synchronisieren
			if production.feedMixer ~= nil then
				streamWriteUInt8(streamId, 1)
				streamWriteString(streamId, production.id)
				streamWriteUIntN(streamId, production.feedMixer.selected, FillTypeManager.SEND_NUM_BITS)
			else
				streamWriteUInt8(streamId, 0)
			end

			if production.mixMode ~= "ASC" then
				streamWriteUInt8(streamId, 1)
				streamWriteString(streamId, production.id)
				streamWriteString(streamId, production.mixMode)
			else
				streamWriteUInt8(streamId, 0)
			end

			if production.boostMode ~= "ASC" then
				streamWriteUInt8(streamId, 1)
				streamWriteString(streamId, production.id)
				streamWriteString(streamId, production.boostMode)		
			else
				streamWriteUInt8(streamId, 0)
			end
		end

		streamWriteUInt8(streamId, table.size(self.outputFillTypeIdsDirectSell))

		for directSellFillTypeId in pairs(self.outputFillTypeIdsDirectSell) do
			streamWriteUIntN(streamId, directSellFillTypeId, FillTypeManager.SEND_NUM_BITS)
		end

		streamWriteUInt8(streamId, table.size(self.outputFillTypeIdsAutoDeliver))

		for autoDeliverFillTypeId in pairs(self.outputFillTypeIdsAutoDeliver) do
			streamWriteUIntN(streamId, autoDeliverFillTypeId, FillTypeManager.SEND_NUM_BITS)
		end

		--Production Revamp: Neue Option "Einlagern" hinzugefügt
		streamWriteUInt8(streamId, table.size(self.outputFillTypeIdsStorage))

		for autoStorageFillTypeId in pairs(self.outputFillTypeIdsStorage) do
			streamWriteUIntN(streamId, autoStorageFillTypeId, FillTypeManager.SEND_NUM_BITS)
		end

		--Production Revamp: Input-Prioritäten hinzugefügt
		streamWriteUInt8(streamId, table.size(self.inputFillTypeIdsPriority))

		for inputFillType in pairs(self.inputFillTypeIdsPriority) do
			local priority = self.inputFillTypeIdsPriority[inputFillType]
			streamWriteUIntN(streamId, inputFillType, FillTypeManager.SEND_NUM_BITS)
			streamWriteUIntN(streamId, priority, 6)
		end

		NetworkUtil.writeNodeObjectId(streamId, NetworkUtil.getObjectId(self.unloadingStation))
		self.unloadingStation:writeStream(streamId, connection)
		g_server:registerObjectInStream(connection, self.unloadingStation)

		if self.loadingStation ~= nil then
			NetworkUtil.writeNodeObjectId(streamId, NetworkUtil.getObjectId(self.loadingStation))
			self.loadingStation:writeStream(streamId, connection)
			g_server:registerObjectInStream(connection, self.loadingStation)
		end

		NetworkUtil.writeNodeObjectId(streamId, NetworkUtil.getObjectId(self.storage))
		self.storage:writeStream(streamId, connection)
		g_server:registerObjectInStream(connection, self.storage)
		streamWriteUInt8(streamId, #self.activeProductions)

		for i = 1, #self.activeProductions do
			local production = self.activeProductions[i]

			streamWriteString(streamId, production.id)
			streamWriteUIntN(streamId, production.status, ProductionPoint.PROD_STATUS_NUM_BITS)

			streamWriteUInt8(streamId, #production.inputs)
			for x = 1, #production.inputs do
				local productionInputColor = production.inputs[x].color
				local inputId = x
				streamWriteString(streamId, production.id)
				streamWriteUIntN(streamId, inputId, FillTypeManager.SEND_NUM_BITS)
				streamWriteUIntN(streamId, productionInputColor, FillTypeManager.SEND_NUM_BITS)
			end
		end

		streamWriteBool(streamId, self.palletLimitReached)
	end
end

ProductionPoint.writeStream = Utils.overwrittenFunction(ProductionPoint.writeStream, Revamp.writeStream)



--Production Revamp: addFillLevel neu geschrieben, um Produktionen als Verkaufspunkte zu erhalten/Missionsgüter nicht im Lager zu haben
function Revamp:addFillLevelFromTool(superFunc, farmId, deltaFillLevel, fillType, fillInfo, toolType, extraAttributes)
	if not RevampSettings.current.MissionFixActive or self.rootNodeName=="boatyard" or self.rootNodeName=="rollercoaster" then
		return superFunc(self, farmId, deltaFillLevel, fillType, fillInfo, toolType, extraAttributes);
	end

	local movedFillLevel = 0
	if deltaFillLevel > 0 then
		--Mission Abfragen
		local usedByMission = false
		for _, mission in pairs(self.missions) do
			if mission.fillSold ~= nil and mission.fillType == fillType and mission.farmId == farmId then
				mission:fillSold(deltaFillLevel)
				usedByMission = true

				break
			end
		end

		--Überprüfen ob Filltype im Lager angenommen wird
		if self:getIsFillTypeAllowed(fillType, extraAttributes) then
			--Sollte eine Mission für die Produktion aktiv sein
			if usedByMission then
				movedFillLevel = deltaFillLevel
			else
				--Überprüfen ob es sich um eine Produktion handelt
				if self.storeSoldGoods then
					--Besitzer-ID der Produktion ermitteln & Lohnerstatus auslesen
					local ownerFarmId = self.owningPlaceable:getOwnerFarmId()
					local testLohn = AccessHandler:canFarmAccessOtherId(farmId, ownerFarmId)

					--Sollte die Produktion dem Ablader gehören
					if ownerFarmId == farmId then
						movedFillLevel = SellingStation:superClass().addFillLevelFromTool(self, farmId, deltaFillLevel, fillType, fillInfo, toolType, extraAttributes)
					--Sollte die Produktionen jemand anderes gehören oder niemanden
					elseif ownerFarmId ~= farmId and ownerFarmId ~= 0 then
					 --sollte Lohnerstatus vorhanden sein
						if testLohn then
							movedFillLevel = SellingStation:superClass().addFillLevelFromTool(self, farmId, deltaFillLevel, fillType, fillInfo, toolType, extraAttributes)
						else
							movedFillLevel = deltaFillLevel
							self:sellFillType(farmId, movedFillLevel, fillType, toolType, extraAttributes)
						end
					else
						movedFillLevel = deltaFillLevel
						self:sellFillType(farmId, movedFillLevel, fillType, toolType, extraAttributes)
					end
				else
					movedFillLevel = deltaFillLevel
					self:sellFillType(farmId, movedFillLevel, fillType, toolType, extraAttributes)
					self:startFx(fillType)
				end
			end
		end
	end

	return movedFillLevel
end

SellingStation.addFillLevelFromTool = Utils.overwrittenFunction(SellingStation.addFillLevelFromTool, Revamp.addFillLevelFromTool)



--Production Revamp: Überschrieben, damit Anhänger, Fahrzeuge und co bei gekauften Produktionen abladen können für die Mission
function Revamp:getFreeCapacity(superFunc, fillTypeIndex, farmId)
	local usedByMission = false
	for _, mission in pairs(self.missions) do
		if mission.fillSold ~= nil and mission.fillType == fillTypeIndex and mission.farmId == farmId then
			usedByMission = true

			break
		end
	end

	if self.storeSoldGoods then
		if usedByMission then
			return 1000
		else
			return SellingStation:superClass().getFreeCapacity(self, fillTypeIndex, farmId)
		end
	else
		return math.huge
	end
end
SellingStation.getFreeCapacity = Utils.overwrittenFunction(SellingStation.getFreeCapacity, Revamp.getFreeCapacity)



--Production Revamp: Neuen Finanzbereich hinzufügen
function Revamp:AddFinances()
	MoneyType.PRODUCTION_DELIVER_COSTS = MoneyType.register("ProductionDeliveryCosts", "ProductionDeliveryCosts", g_currentModName)
	table.insert(FinanceStats.statNames, "ProductionDeliveryCosts")
	MoneyType.reset()
end



--Production Revamp: Revamp-Übersetzungen in Globale Übersetzungen verschieben, damit diese angezeigt werden können
function Revamp:mergeModTranslations(i18n)
	local modEnvMeta = getmetatable(_G)
	local env = modEnvMeta.__index

	local global = env.g_i18n.texts
	for key, text in pairs(i18n.texts) do
		global[key] = text
	end
end

Revamp:mergeModTranslations(g_i18n)



--Production Revamp: Möglichkeit hinzugefügt, Categories und Names gleichzeitig zu verwenden 
function Revamp:loadFillTypes(superFunc, xmlFile, xmlNode)
	local fillTypeCategories = xmlFile:getValue(xmlNode .. "#fillTypeCategories")
	local fillTypeNames = xmlFile:getValue(xmlNode .. "#fillTypes")
	local fillTypes = nil
	local bypass = false

	if fillTypeCategories ~= nil then
		bypass = true
		fillTypes = g_fillTypeManager:getFillTypesByCategoryNames(fillTypeCategories, "Warning: UnloadTrigger has invalid fillTypeCategory '%s'.")
		for _, fillType in pairs(fillTypes) do
			self.fillTypes[fillType] = true
		end
	end
	if fillTypeNames ~= nil then
		bypass = true
		fillTypes = g_fillTypeManager:getFillTypesByNames(fillTypeNames, "Warning: UnloadTrigger has invalid fillType '%s'.")
		for _, fillType in pairs(fillTypes) do
			self.fillTypes[fillType] = true
		end
	end

	if bypass == false then
		self.fillTypes = nil
	end
end

UnloadTrigger.loadFillTypes = Utils.overwrittenFunction(UnloadTrigger.loadFillTypes, Revamp.loadFillTypes)



--Production Revamp: Anzeige von Categorien im Baumenü ermöglichen.
function Revamp.loadSpecValueInputFillTypes(xmlFile, customEnvironment, baseDir)
	local fillTypeNames = nil
	xmlFile:iterate("placeable.productionPoint.productions.production", function (_, productionKey)
		xmlFile:iterate(productionKey .. ".inputs.input", function (_, inputKey)
			local fillTypeCategoriesString = xmlFile:getValue(inputKey .. "#fillTypeCategory")
			if fillTypeCategoriesString == nil then
				local fillTypeName = xmlFile:getValue(inputKey .. "#fillType")
				if fillTypeName~=nil then
					fillTypeNames = fillTypeNames or {}
					fillTypeNames[fillTypeName] = true
				end
			else
				local fillTypes = g_fillTypeManager:getFillTypesByCategoryNames(fillTypeCategoriesString, "Warning: '" .. tostring(key) .. "' has invalid fillTypeCategory '%s'.")
				for _, fillType in pairs(fillTypes) do
					local fillTypeName = g_fillTypeManager:getFillTypeNameByIndex(fillType)
					fillTypeNames = fillTypeNames or {}
					fillTypeNames[fillTypeName] = true
				end
			end
		end)
	end)

	return fillTypeNames
end

ProductionPoint.loadSpecValueInputFillTypes = Utils.overwrittenFunction(ProductionPoint.loadSpecValueInputFillTypes, Revamp.loadSpecValueInputFillTypes)



--Production Revamp: Überschrieben um den Verkaufsfaktor anpassbar zu machen.
function Revamp:directlySellOutputs(superfunc)
	for outputFillTypeId in pairs(self.outputFillTypeIdsDirectSell) do
		local amount = self.storage:getFillLevel(outputFillTypeId)

		if amount > 0 then
			local revenue = RevampSettings.current.DirectSellingPriceFactor * amount * g_currentMission.economyManager:getPricePerLiter(outputFillTypeId)

			self.mission:addMoney(revenue, self.ownerFarmId, MoneyType.SOLD_PRODUCTS, true)
			self.storage:setFillLevel(0, outputFillTypeId)
		end
	end
end

ProductionPoint.directlySellOutputs = Utils.overwrittenFunction(ProductionPoint.directlySellOutputs, Revamp.directlySellOutputs)



--Production Revamp: Überschrieben, damit auch kleine FillLevel-Änderungen erfasst werden können.
function Revamp:setFillLevel(superFunc, fillLevel, fillType, fillInfo)
	local capacity = self.capacities[fillType] or self.capacity
	fillLevel = MathUtil.clamp(fillLevel, 0, capacity)

	if self.fillLevels[fillType] ~= nil and fillLevel ~= self.fillLevels[fillType] then
		local oldLevel = self.fillLevels[fillType]
		self.fillLevels[fillType] = fillLevel
		local delta = self.fillLevels[fillType] - oldLevel

		-- this value and his usage is the only change of the original
		local oldLevelRounded = math.floor(oldLevel);
		local newLevelRounded = math.floor(fillLevel);
		local roundedLevelChanged = oldLevelRounded ~= newLevelRounded

		if math.abs(delta) > 0.1 or roundedLevelChanged then
			for _, func in ipairs(self.fillLevelChangedListeners) do
				func(fillType, delta)
			end
		end

		if self.isServer and (fillLevel < 0.1 or self.fillLevelSyncThreshold <= math.abs(self.fillLevelsLastSynced[fillType] - fillLevel) or capacity - fillLevel < 0.1) then
			self:raiseDirtyFlags(self.storageDirtyFlag)
		end

		self:updateFillPlanes()

		if self.dynamicFillPlane ~= nil then
			local refNode = self.dynamicFillPlane
			local width = 1
			local length = 1

			if fillInfo ~= nil then
				refNode = fillInfo.node
				length = fillInfo.length
				width = fillInfo.width
			end

			local x, y, z = localToWorld(refNode, 0, 0, 0)
			local d1x, d1y, d1z = localDirectionToWorld(refNode, width, 0, 0)
			local d2x, d2y, d2z = localDirectionToWorld(refNode, 0, 0, length)
			local steps = MathUtil.clamp(math.floor(delta / 400), 1, 25)

			for _ = 1, steps do
				fillPlaneAdd(self.dynamicFillPlane, delta / steps, x, y, z, d1x, d1y, d1z, d2x, d2y, d2z)
			end
		end
	end
end

Storage.setFillLevel = Utils.overwrittenFunction(Storage.setFillLevel, Revamp.setFillLevel)



--Production Revamp: Ingame Hilfe - Sprachabhängig XML Laden um Bilder austauschen zu können.
function Revamp:loadMapDataHelpLineManager(superFunc, ...)
	local ret = superFunc(self, ...)
	if ret then
		self:loadFromXML(Utils.getFilename("xml/HelpLine.xml", ProductionPoint.Revamp))
		return true
	end
	return false
end
HelpLineManager.loadMapData = Utils.overwrittenFunction(HelpLineManager.loadMapData, Revamp.loadMapDataHelpLineManager)



--Production Revamp: Neuer Auslagerungs-Dialog
source(Utils.getFilename("gui/QuickAmountDialog.lua", g_currentModDirectory))
function Revamp:LoadGui()
	local xmlGuiFileName = Utils.getFilename("gui/guiProfiles.xml", g_currentModDirectory)
	g_gui:loadProfiles(xmlGuiFileName)

	local quickAmountDialog = QuickAmountDialog.new()
	local xmlFileName = Utils.getFilename("gui/QuickAmountDialog.xml", g_currentModDirectory)
	g_gui:loadGui(xmlFileName, "QuickAmountDialog", quickAmountDialog)
end



--Production Revamp: Neuen Dialog als gui angelegt, damit das Einheitlich ist
function Gui:showQuickAmountDialog(args)
	local dialog = self:showDialog("QuickAmountDialog")

	if dialog ~= nil and args ~= nil then
		dialog.target:setText(args.text)
		dialog.target:setTitle(args.title)
		dialog.target:setOptions(args.options)
		dialog.target:setCallback(args.callback, args.target, args.args)
	end
end



--Production Revamp: WoodTrigger Text anpassen wenn eine Produktion gekauft wird
function Revamp:setOwnerFarmId(farmId, noEventSend)
	--Production Revamp: Bezeichnung des Trigger mit Holz einlagern statt Holz Verkaufen
	if self.unloadingStation ~= nil then
		if self.unloadingStation.unloadTriggers ~= nil then
			for _, unloadTrigger in pairs(self.unloadingStation.unloadTriggers) do
				if unloadTrigger.woodTrigger ~= nil and unloadTrigger.woodTrigger.activatable ~= nil then
					if self.owningPlaceable:getOwnerFarmId() ~= AccessHandler.EVERYONE then
						unloadTrigger.woodTrigger.activatable.activateText = g_i18n:getText("Revamp_storeWoodlogs")
					end
				end
			end
		end
	end
end
ProductionPoint.setOwnerFarmId = Utils.prependedFunction(ProductionPoint.setOwnerFarmId, Revamp.setOwnerFarmId)


function Revamp:updateFxState(superFunc)
	if self.isClient then
		if #self.activeProductions > 0 then
			if self.hiddenProductions < #self.activeProductions then
				g_soundManager:stopSample(self.samples.idle)

				if not g_soundManager:getIsSamplePlaying(self.samples.active) then
					g_soundManager:playSample(self.samples.active)
				end

				g_animationManager:startAnimations(self.animationNodes)
				g_effectManager:startEffects(self.effects)
			end
		else
			g_soundManager:stopSample(self.samples.active)

			if not g_soundManager:getIsSamplePlaying(self.samples.idle) then
				g_soundManager:playSample(self.samples.idle)
			end

			g_animationManager:stopAnimations(self.animationNodes)
			g_effectManager:stopEffects(self.effects)
		end
	end
end

ProductionPoint.updateFxState = Utils.overwrittenFunction(ProductionPoint.updateFxState, Revamp.updateFxState)


function Revamp:setProductionState(superFunc, productionId, state, noEventSend)
	local production = self.productionsIdToObj[productionId]

	if production ~= nil then
		if state then
			if not table.hasElement(self.activeProductions, production) then
				production.status = ProductionPoint.PROD_STATUS.RUNNING

				table.insert(self.activeProductions, production)
			end

			if self.isClient then
				--Versteckte Produktionen machen keinen Sound
				if production.hideFromMenu == false then
					g_soundManager:playSamples(production.samples)
					g_animationManager:startAnimations(production.animationNodes)
					g_effectManager:startEffects(production.effects)
				end
			end
		else
			table.removeElement(self.activeProductions, production)

			production.status = ProductionPoint.PROD_STATUS.INACTIVE

			if self.isClient then
				g_soundManager:stopSamples(production.samples)
				g_animationManager:stopAnimations(production.animationNodes)
				g_effectManager:stopEffects(production.effects)
			end
		end

		self.owningPlaceable:outputsChanged(production.outputs, state)
		ProductionPointProductionStateEvent.sendEvent(self, productionId, state, noEventSend)
	else
		log(string.format("Error: setProductionState(): unknown productionId '%s'", productionId))
	end

	if self.isClient then
		self:updateFxState()
	end
end

ProductionPoint.setProductionState = Utils.overwrittenFunction(ProductionPoint.setProductionState, Revamp.setProductionState)


--Production Revamp: Hinzugefügt um Input-Prioritäten zu ändern
function ProductionPoint:setRevampSettings(productionId, mixMode, boostMode, feedMixerRecipe, noEventSend)
	local production = self.productionsIdToObj[productionId]
	if feedMixerRecipe ~= nil and feedMixerRecipe ~= 0 then
		self:FMSchangeRecipe(production, feedMixerRecipe, true)
	end

	if mixMode ~= nil and mixMode ~= "none" then
		production.mixMode = mixMode
	end
	if boostMode ~= nil and boostMode ~= "none" then
		production.boostMode = boostMode
	end
	
	RevampSettingsEvent.sendEvent(self, productionId, mixMode, boostMode, feedMixerRecipe, noEventSend)
end

Revamp:AddFinances()
Revamp:LoadGui()