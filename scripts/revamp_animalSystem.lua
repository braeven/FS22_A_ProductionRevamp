--[[
Production Revamp
Animal Input System

Copyright (C) braeven, Achimobil, 2022

Author: braeven, Achimobil

Date: 27.12.2022
Version: 1.0.2.0

Contact/Help/Tutorials:
discord.gg/gHmnFZAypk


Changelog:
1.0.0.0 @ 24.11.2022 - Initial commit
1.0.1.0 @ 21.12.2022 - Verschiedene Gesundheitseinstellungen ermöglicht
1.0.2.0 @ 27.12.2022 - Anpassung für die Tier-Übersicht

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
	local buttonText = "Tiere Anzeigen"
	local isProductionListActive = self.productionList == FocusManager:getFocusedElement()
	local production, productionPoint = self:getSelectedProduction()

	if isProductionListActive and productionPoint.animalTypes ~= nil then
		table.insert(self.menuButtonInfo, {
			profile = "buttonOk",
			inputAction = InputAction.MENU_EXTRA_1,
			text = buttonText,
			callback = function()
				ProductionAnimalOverview:show(productionPoint)
			end
		})
		self:setMenuButtonInfoDirty()
	end
end

InGameMenuProductionFrame.updateMenuButtons = Utils.appendedFunction(InGameMenuProductionFrame.updateMenuButtons, RevampAnimals.updateMenuButtons)


function ProductionPoint:getAllowedAnimalSubTypes(trigger)
	allowedAnimals = self.animalTriggers[trigger]

	return allowedAnimals
	--Alle AnimalSubType übermitteln für Tierverladung. Anhand des Subtypes soll bestimmt werden, was überhaupt rein kann. Wird aufgerufen wenn der Trigger aktiviert wird.
end



function ProductionPoint:calculateAnimals(subType, health, age)
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
	local factor = 0.1 + (0.9 * health) / animal.maxHealthList[age]
	local value = weight * factor
	local fillLevel = self.storage:getFillLevel(animal.inputFillTypes[age])
	local capacity = self.storage:getCapacity(animal.inputFillTypes[age])
	local maxAnimals = math.floor((capacity - fillLevel) / value)

	return maxAnimals, animal.inputFillTypes[age], value, nil
	--Basierend auf den erlaubten und gleichen Tieren die zugehörige Werte bestimmen für die maximale Anzahl Tiere die in den Trigger kann. Wird aufgerufen, nachdem die erlaubten Tieren übermittelt und Abgeglichen wurden. Wird für jeden Cluster einzelnd übermittelt.
end



function ProductionPoint:transportAnimals(subType, health, age, amount)
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
	local factor = 0.1 + (0.9 * health / animal.maxHealthList[age])
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