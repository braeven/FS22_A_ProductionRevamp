--[[
Production Revamp
Animal Input System

Copyright (C) braeven, Achimobil, 2022

Author: braeven, Achimobil

Date: 29.05.2023
Version: 1.0.2.1

Contact/Help/Tutorials:
discord.gg/gHmnFZAypk


Changelog:
1.0.0.0 @ 24.11.2022 - Initial commit
1.0.1.0 @ 21.12.2022 - Verschiedene Gesundheitseinstellungen ermöglicht
1.0.2.0 @ 27.12.2022 - Anpassung für die Tier-Übersicht
1.0.2.0 @ 29.05.2023 - Button Übersetzbar gemacht
1.4.3.2 @ 26.12.2023 - Bugfix für unterscheidung Tiere bei mehreren Triggern

Important:.
No changes are allowed to this script without permission from Braeven.
If you want to make a production with this script, look in the documentation, discord channels for tutorials/help or download the FS22_Revamp_Productions Pack for reference
Don't copy the script into a production, load the mod as a dependency!

Es dürfen an diesem Script keine Veränderungen ohne Erlaubnis von Braeven gemacht werden.
Wenn du eine Produktion mit diesem Script bauen möchtest, lese dir die Dokumentation, die angepinnten Tutorials im Discord durch oder guck dir die FS22_Revamp_Productions an.
Nicht das Script in Produktionen kopieren, ladet den Mod über eine Dependency!

]]

RevampAnimals = {}

--Production Revamp: MenüButton um sich mögliche Tiere/FillTypes anzeigen zu lassen
function RevampAnimals:updateMenuButtons(superFunc)
	local isProductionListActive = self.productionList == FocusManager:getFocusedElement()
	local production, productionPoint = self:getSelectedProduction()

	if isProductionListActive and productionPoint.animalTypes ~= nil then
		table.insert(self.menuButtonInfo, {
			profile = "buttonOk",
			inputAction = InputAction.MENU_EXTRA_1,
			text = self.i18n:getText("Revamp_ShowAnimalsOverview"),
			callback = function()
				ProductionAnimalOverview:show(productionPoint)
			end
		})
		self:setMenuButtonInfoDirty()
	end
end

InGameMenuProductionFrame.updateMenuButtons = Utils.appendedFunction(InGameMenuProductionFrame.updateMenuButtons, RevampAnimals.updateMenuButtons)

-- Wird der subType von diesem Trigger angenommen?
function ProductionPoint:getIsSubTypeAllowedForTrigger(trigger, subTypeName)
	if self.animalTriggers[trigger] == nil then 
		Logging.warning("getIsSubTypeAllowedForTrigger for unknown trigger");
		return false;
	end
	if self.animalTriggers[trigger].subTypes == nil then 
		Logging.warning("getIsSubTypeAllowedForTrigger for trigger without subTypes definitions");
		return false;
	end
	
	local animalAllowed = self.animalTriggers[trigger].subTypes[subTypeName];

	if animalAllowed == nil then 
		return false ;
	end

	return animalAllowed;
end



function ProductionPoint:calculateAnimals(subType, health, age, fatteningBonus)
	local animal = self.animalTypes[subType]
	if animal == nil then
		return 0, nil, 0, "WrongAnimal";
	end
	if animal.weight[age] == nil then
		return 0, nil, 0, "WrongAge";
	end
	if health < animal.minHealthList[age] or health > animal.maxHealthList[age] then
		return 0, nil, 0, "WrongHealth";
	end
	local weight = animal.weight[age]
	local factor = (0.1 + (0.9 * health) / animal.maxHealthList[age]) * fatteningBonus
	local value = weight * factor
	local fillLevel = self.storage:getFillLevel(animal.inputFillTypes[age])
	local capacity = self.storage:getCapacity(animal.inputFillTypes[age])
	local maxAnimals = math.floor((capacity - fillLevel) / value)

	return maxAnimals, animal.inputFillTypes[age], value, nil
	--Basierend auf den erlaubten und gleichen Tieren die zugehörige Werte bestimmen für die maximale Anzahl Tiere die in den Trigger kann. Wird aufgerufen, nachdem die erlaubten Tieren übermittelt und Abgeglichen wurden. Wird für jeden Cluster einzelnd übermittelt.
end



function ProductionPoint:transportAnimals(subType, health, age, amount, fatteningBonus)
	local animal = self.animalTypes[subType]
	if animal == nil then
		return false
	end
	local weight = animal.weight[age]
	if animal.weight[age] == nil then
		return false
	end
	if health < animal.minHealthList[age] or health > animal.maxHealthList[age] then
		return false
	end
	local factor = (0.1 + (0.9 * health / animal.maxHealthList[age])) * fatteningBonus
	local value = weight * factor * amount
	local fillLevel = self.storage:getFillLevel(animal.inputFillTypes[age])
	local capacity = self.storage:getCapacity(animal.inputFillTypes[age])
	if capacity < value then
		return false
	else
		self.storage:setFillLevel(fillLevel + value, animal.inputFillTypes[age])
		return true
	end
end



function ProductionPoint:loadAnimals(xmlFile, key, animalStorage, components, i3dMappings)
	self.animalTypes = {}
	local mainTrigger = xmlFile:getValue(key..".animalTrigger#triggerNode", nil, components, i3dMappings)

	xmlFile:iterate(key .. ".animalTrigger.inputs.input", function (index, animalKey)
		local animal = {}

		--Grunddaten auslesen
		local animalType = xmlFile:getValue(animalKey .. "#animalType", nil)
		local animalSubType = xmlFile:getValue(animalKey .. "#animalSubType", nil)
		local inputFillType = xmlFile:getValue(animalKey .. "#inputFillType")
		local inputFillTypeIndex = g_fillTypeManager:getFillTypeIndexByName(inputFillType)

		--Überprüfen ob AnimalSubType, AnimalType und InputFillType gültig sind
		local skip = false
		if animalType == nil and animalSubType == nil then
			Logging.xmlError(xmlFile, "Production Revamp: No animalType or animalSubType given for Production '%s'", self.owningPlaceable:getName())
			skip = true
		elseif animalSubType == nil and g_currentMission.animalSystem:getTypeByName(animalType) == nil then
			Logging.xmlError(xmlFile, "Production Revamp: No animalSubType given and animalType '%s' is invalid for Production '%s'", animalType, self.owningPlaceable:getName())
			skip = true
		elseif animalType == nil and g_currentMission.animalSystem:getSubTypeByName(animalSubType) == nil then
			Logging.xmlError(xmlFile, "Production Revamp: No animalType given and animalSubType '%s' is invalid for Production '%s'", animalSubType, self.owningPlaceable:getName())
			skip = true
		end
		if skip == false then
			--ErrorAnimalType bestimmen
			local errorAnimalType = animalType
			if animalType == nil then
				errorAnimalType = animalSubType
			end

			if inputFillTypeIndex == nil then
				Logging.xmlError(xmlFile, "Production Revamp: Unable to load inputFillType '%s' for Production '%s' - Animal: '%s'.", inputFillType, self.owningPlaceable:getName(), errorAnimalType)
			elseif not animalStorage[inputFillTypeIndex] then
				Logging.xmlError(xmlFile, "Production Revamp: No storage supplied for inputFillType '%s' for Production '%s' - Animal: '%s'.", inputFillType, self.owningPlaceable:getName(), errorAnimalType)
			else
				self.animalInputFillTypeIndexes[inputFillTypeIndex] = true;

				--Alter und Gesundheit auslesen und überprüfen
				local minHealthFactor = xmlFile:getInt(animalKey .. "#minHealthFactor", 50)
				local maxHealthFactor = xmlFile:getInt(animalKey .. "#maxHealthFactor", 100)
				local minAgeMonth = xmlFile:getInt(animalKey .. "#minAgeMonth", 6)
				local maxAgeMonth = xmlFile:getInt(animalKey .. "#maxAgeMonth", 200)
				if maxHealthFactor > 100 or maxHealthFactor < 1 then
					maxHealthFactor = 100
					Logging.xmlError(xmlFile, "Production Revamp: Invalid value maxHealth '%s%' set for Production '%s' - Animal: '%s'. Allowed range: 1 - 100. Value set to 100.", maxHealth, self.owningPlaceable:getName(), errorAnimalType)
				end
				if minHealthFactor > 100 or minHealthFactor < 0 then
					minHealthFactor = 50
					Logging.xmlError(xmlFile, "Production Revamp: Invalid value minHealth '%s%' set for Production '%s' - Animal: '%s'. Allowed range: 0 - 100.	Value set to 50.", minHealth, self.owningPlaceable:getName(), errorAnimalType)
				end
				if minHealthFactor > maxHealthFactor then
					maxHealthFactor = 100
					minHealthFactor = 50
					Logging.xmlError(xmlFile, "Production Revamp: Value minHealth '%s%' is bigger than value maxHealth '%s%' for Production '%s' - Animal: '%s'. maxHealth must be bigger or equal to minHealth. Values set to 50 and 100.", minHealthFactor, maxHealthFactor, self.owningPlaceable:getName(), errorAnimalType)
				end
				if minAgeMonth < 0 then
					minAgeMonth = 6
					Logging.xmlError(xmlFile, "Production Revamp: Invalid value '%s%' minAgeMonth set for Production '%s' - Animal: '%s'. Only positive numbers are allowed. Value set to 6.", minAgeMonth, self.owningPlaceable:getName(), errorAnimalType)
				end
				if maxAgeMonth < 0 then
					maxAgeMonth = 200
					Logging.xmlError(xmlFile, "Production Revamp: Invalid value '%s%' maxAgeMonth set for Production '%s' - Animal: '%s'. Only positive numbers are allowed. Value set to 200.", maxAgeMonth, self.owningPlaceable:getName(), errorAnimalType)
				end
				if minAgeMonth > maxAgeMonth then
					minAgeMonth = 6
					maxAgeMonth = 200
					Logging.xmlError(xmlFile, "Production Revamp: Value '%s%' minAgeMonth is bigger than value maxAgeMonth %s%' for Production '%s' - Animal: '%s'. maxAgeMonth must be bigger or equal to minAgeMonth. Values set to 6 and 200.", minAgeMonth, maxAgeMonth, self.owningPlaceable:getName(), errorAnimalType)
				end
				local trigger = xmlFile:getValue(animalKey.."#triggerNode", mainTrigger, components, i3dMappings)

				--Fake animalTypes sollte nur ein subType da sein für die nachfolgende Schleife
				local animalTypes = {}
				if animalSubType ~= nil then
					animalSubType = g_currentMission.animalSystem:getSubTypeIndexByName(animalSubType)
					animalTypes.subTypes = {}
					table.insert(animalTypes.subTypes, animalSubType)
				else
					animalTypes = g_currentMission.animalSystem:getTypeByName(animalType)
				end

				for _, subTypeIndex in pairs(animalTypes.subTypes) do
					local currentType = g_currentMission.animalSystem:getSubTypeByIndex(subTypeIndex).name
					animal.weight = {}
					animal.inputFillTypes = {}
					animal.recipe = {}
					animal.maxHealthList = {}
					animal.minHealthList = {}
					local oldestAge = 0
					local oldestValue = math.huge
					local youngestAge = math.huge
					local youngestValue = math.huge

					--Sollte der AnimalSubtype schon eingetragen sein, Daten laden und ergänzen
					if self.animalTypes[currentType] ~= nil then
						animal.weight = self.animalTypes[currentType].weight
						animal.inputFillTypes = self.animalTypes[currentType].inputFillTypes
						animal.recipe = self.animalTypes[currentType].recipe
						animal.maxHealthList = self.animalTypes[currentType].maxHealthList
						animal.minHealthList = self.animalTypes[currentType].minHealthList
						animal.minHealthFactor = self.animalTypes[currentType].minHealthFactor
						animal.maxHealthFactor = self.animalTypes[currentType].maxHealthFactor
						animal.minAgeMonth = self.animalTypes[currentType].minAgeMonth
						animal.maxAgeMonth = self.animalTypes[currentType].maxAgeMonth
					end

					--Daten für die Fehlermeldung hinterlegen
					if animal.minHealthFactor == nil or animal.minHealthFactor > minHealthFactor then
						animal.minHealthFactor = minHealthFactor
					end
					if animal.maxHealthFactor == nil or animal.maxHealthFactor < maxHealthFactor then
						animal.maxHealthFactor = maxHealthFactor
					end
					if animal.minAgeMonth == nil or animal.minAgeMonth > minAgeMonth then
						animal.minAgeMonth = minAgeMonth
					end
					if animal.maxAgeMonth == nil or animal.maxAgeMonth < maxAgeMonth then
						animal.maxAgeMonth = maxAgeMonth
					end

					--Umwandlungs-Übersicht anlegen
					local recipe = {}
					recipe.biggestAmount = 0
					recipe.smallestAmount = math.huge

					--Durch alle weight Einträge durchgehen und Daten in Tabelle hinterlegen, dabei min/max Werte bestimmen
					xmlFile:iterate(animalKey .. ".weight", function (weightIndex, weightKey)
						local value = xmlFile:getInt(weightKey .. "#value", 1000)
						local ageMonth = xmlFile:getInt(weightKey .. "#ageMonth", 6)
						if ageMonth > maxAgeMonth then
							Logging.xmlError(xmlFile, "Production Revamp: Value ageMonth '%s' is bigger than value maxAgeMonth '%s' for Production '%s' - Animal: '%s'. ageMonth must be equal or smaller to value maxAgeMonth. Entry was skipped.", ageMonth, maxAgeMonth, self.owningPlaceable:getName(), errorAnimalType)
						elseif ageMonth < minAgeMonth then
							Logging.xmlError(xmlFile, "Production Revamp: Value ageMonth '%s' is smaller than value minAgeMonth '%s' for Production '%s' - Animal: '%s'. ageMonth must be equal or bigger to value minAgeMonth. Entry was skipped.", ageMonth, minAgeMonth, self.owningPlaceable:getName(), errorAnimalType)
						elseif value < 0 then
							Logging.xmlError(xmlFile, "Production Revamp: Value value(weight) '%s' is a negative number for Production '%s' - Animal: '%s'. value must be equal or bigger to 0. Entry was skipped.", value, self.owningPlaceable:getName(), errorAnimalType)
						else
							if ageMonth >= oldestAge then
								oldestValue = value
								oldestAge = ageMonth
							end
							if ageMonth <= youngestAge then
								youngestValue = value
								youngestAge = ageMonth
							end
							animal.weight[ageMonth] = value
							animal.maxHealthList[ageMonth] = maxHealthFactor
							animal.minHealthList[ageMonth] = minHealthFactor
							animal.inputFillTypes[ageMonth] = inputFillTypeIndex
							if recipe.biggestAmount < value then
								recipe.biggestAmount = value
							end
							if recipe.smallestAmount > value then
								recipe.smallestAmount = value
							end
						end
					end)

					--SubType für Rezept-Anzeige hinterlegen

					recipe.minAge = minAgeMonth
					recipe.maxAge = maxAgeMonth
					recipe.minHealth = minHealthFactor
					recipe.maxHealth = maxHealthFactor
					recipe.fillTypeIndex = inputFillTypeIndex
					table.insert(animal.recipe, recipe)

					--Sollte kein Wert für weight[maxAgeMonth] vorhanden sein, wird dieser hier hinterlegt, damit die folgende Schleife nicht fehlerhaft sein kann.
					if animal.weight[maxAgeMonth] == nil then
						animal.weight[maxAgeMonth] = oldestValue
						animal.maxHealthList[maxAgeMonth] = maxHealthFactor
						animal.minHealthList[maxAgeMonth] = minHealthFactor
						animal.inputFillTypes[maxAgeMonth] = inputFillTypeIndex
					end

					--Sollte kein Wert für weight[minAgeMonth] vorhanden sein, wird dieser hier hinterlegt, damit die folgende Schleife nicht fehlerhaft sein kann.
					if animal.weight[minAgeMonth] == nil then
						animal.weight[minAgeMonth] = youngestValue
						animal.maxHealthList[minAgeMonth] = maxHealthFactor
						animal.minHealthList[minAgeMonth] = minHealthFactor
						animal.inputFillTypes[minAgeMonth] = inputFillTypeIndex
					end

					--Kontrollieren ob für alle Altersstufen Einträge vorhanden sind, ansonsten Ergänzen
					local lastAge = youngestAge
					local lastValue = youngestValue
					local calculateWeight = xmlFile:getBool(animalKey .. "#calculateWeight", true)

					for x = minAgeMonth, maxAgeMonth do
						if calculateWeight then
							if animal.weight[x] ~= nil then
								--nichts tun
							elseif lastAge ~= x then
								-- next age suchen
								local nextAge = maxAgeMonth;
								for y = lastAge + 1, maxAgeMonth do
									if animal.weight[y] ~= nil and y < nextAge then
										nextAge = y;
									end
								end

								-- stufen berechnen
								local weightDifference = animal.weight[nextAge] - lastValue;
								local steps = nextAge - lastAge;
								local stepWeight = MathUtil.round(weightDifference / steps, 3)

								-- zwischenschritte einfügen
								for y = lastAge + 1, nextAge - 1 do
									animal.weight[y] = lastValue + (stepWeight * (y - lastAge))
									animal.maxHealthList[y] = maxHealthFactor
									animal.minHealthList[y] = minHealthFactor
									animal.inputFillTypes[y] = inputFillTypeIndex
								end

								-- Werte für nächste Berechnung setzen
								lastValue = animal.weight[nextAge]
								lastAge = nextAge
							end
						else
							if animal.weight[x] == nil then
								animal.weight[x] = lastValue
								animal.maxHealthList[x] = maxHealthFactor
								animal.minHealthList[x] = minHealthFactor
								animal.inputFillTypes[x] = inputFillTypeIndex
							else
								lastValue = animal.weight[x]
							end
						end
					end

					--Eintragen in Tabelle für den Trigger
					if self.animalTriggers[trigger] == nil then
						self.animalTriggers[trigger] = {};
						self.animalTriggers[trigger].subTypes = {};
						self.animalTriggers[trigger].subTypes[currentType] = true;
						table.insert(self.animalIndexToTrigger, trigger);
						self.animalTriggerToIndex[trigger] = #self.animalIndexToTrigger;
					else
						self.animalTriggers[trigger].subTypes[currentType] = true;
					end
					self.animalTypes[currentType] = animal
				end
			end
		end
	end)
end