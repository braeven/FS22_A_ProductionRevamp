--[[
Production Revamp
Revamp Spawner Main File

Copyright (C) braeven, Achimobil, 2022

Author: braeven, Achimobil

Date: 12.04.2023
Version: 1.4.3.1

Contact/Help/Tutorials:
discord.gg/gHmnFZAypk


Changelog:
1.0.0.0 @ 01.05.2022 - Initial Release.
1.0.0.1 @ 06.06.2022 - Bugfix: Spawner-Menü zeigt keine FillTypes ohne Paletten/Ballen mehr an.
1.0.0.2 @ 11.06.2022 - Timer hinzugefügt, damit der Spawner nicht zu schnell spawnt.
1.0.1.0 @ 06.07.2022 - sort filltype selection and correct max display.
1.1.0.0 @ 05.08.2022 - Unterstützung von Produktionen mit Öffnungszeiten eingebaut.
1.1.1.0 @ 17.08.2022 - fix customEnvironment problem in siloPalletSpawnerSpecialization
1.1.2.0 @ 20.08.2022 - Farbwahl für Silageballen
1.1.2.1 @ 30.08.2022 - Holz wählbar auch wenn es keine Palette dafür gibt
1.1.2.2 @ 30.08.2022 - InAktive/Aktive Produktionen Filter zurücksetzen beim Menü-Aufruf
1.1.2.3 @ 31.08.2022 - Holzstämme spawnen jetzt in spawnplace direction
1.1.2.4 @ 31.08.2022 - Unnötigen Code entfernt
1.2.0.0 @ 27.09.2022 - Kompabilität mit PnH
1.3.0.0 @ 17.11.2022 - Spawnfehler mit mehreren FillTypes Gleichzeitig behoben
1.4.0.0 @ 08.12.2022 - Holzstamm länge kann jetzt gewählt werden
1.4.0.1 @ 20.12.2022 - Code Cleanup
1.4.1.0 @ 30.12.2022 - Bugfix Paletten, Ballen und Holz im MP
1.4.2.0 @ 05.01.2023 - Bugfix - auch kleine Mengen größer 1l können ausgelagert werden
1.4.3.0 @ 10.01.2023 - Bugfix mit Öffnungszeiten und Palettenspawn
1.4.3.1 @ 12.04.2023 - Bugfix mit Spawner und Öffnungszeiten

Important:.
No changes are allowed to this script without permission from Braeven AND Achimobil.
If you want to make a production with this script, look in the documentation, discord channels for tutorials/help or download the FS22_Revamp_Productions Pack for reference
Don't copy the script into a production, load the mod as a dependency!

Es dürfen an diesem Script keine Veränderungen ohne Erlaubnis von Braeven UND Achimobil gemacht werden.
Wenn du eine Produktion mit diesem Script bauen möchtest, lese dir die Dokumentation, die angepinnten Tutorials im Discord durch oder guck dir die FS22_Revamp_Productions an.
Nicht das Script in Produktionen kopieren, ladet den Mod über eine Dependency!

]]

RevampSpawner = {}

--Production Revamp: Integration aPalletSilo in Produktions-Trigger/ProduktionsMenü
--Production Revamp: Based on aPalletSilo V2.2.0 by Achimobil & Braeven, Modified for productions and Production Revamp


-- load event
local path = g_currentModDirectory .. "events/RevampSpawnWoodLogsAtProductionEvent.lua"
source(path)



--Production Revamp: Spawnscript Aufruf hinterlegen/überschreiben
function RevampSpawner:run()
	local ownerFarmId = self.productionPoint:getOwnerFarmId()

	if ownerFarmId == AccessHandler.EVERYONE then
		self.productionPoint:buyRequest()
	else if ownerFarmId == self.mission:getFarmId() then
		--Production Revamp: Sollte kein PalettenSpawner vorhanden sein, direkt Menü anzeigen
		if self.productionPoint.palletSpawner == nil then
			self.productionPoint:openMenu()
		else
			local selectableOptions = {}
			local options = {}

			--Production Revamp: Menü öffnen Option hinzufügen
			local openmenu = {}
			openmenu.openmenu = true
			table.insert(selectableOptions, openmenu)
			table.insert(options, g_i18n:getText("Revamp_OpenProduction"))
			
			--Production Revamp: Sollte die Produktion Öffnungszeiten haben, außerhalb der "Zeiten" keine Produktion, dann auch keine Paletten manuell spawnen.
			local skip = false
			local foundOne = false
			local closedTimes = ""
			for _, production in pairs (self.productionPoint.productions) do
				local modes = string.split(production.mode, " ")
				for _, mode in pairs(modes) do
					if mode =="hourly" then
						local currentHour = g_currentMission.environment.currentHour
						if production.hoursTable[currentHour] == true then
							skip = false
							foundOne = true
						elseif foundOne == false then
							closedTimes = production.hours
							skip = true
						end
					end
				end
			end

			if not skip then
				local availableItemsInStorages = {}
				--Production Revamp: Nur anzeigen was im Lager ist und auch OUTPUT ist
				for fillTypeIndex, fillLevel in pairs (self.productionPoint.storage.fillLevels) do
					for index, value in ipairs(self.productionPoint.outputFillTypeIdsArray) do
						if value == fillTypeIndex and fillLevel > 1 then
							--BallenTypen laden falls noch nicht geladen
							if self.baleTypes == nil then
								self.baleTypes = RevampHelper:GetBaleTypes()
							end
							local currentFillType = g_fillTypeManager:getFillTypeByIndex(fillTypeIndex)

							--Production Revamp: Filltypen ohne Palette und Ballen werden nicht angezeigt
							local output = false
							if self.baleTypes[currentFillType.name] ~= nil or currentFillType.palletFilename ~= nil or (currentFillType.name == "WOOD" and self.productionPoint.woodSpawnPlace ~= nil) then
								output = true
							end

							if output then
								if availableItemsInStorages[fillTypeIndex] == nil then
									availableItemsInStorages[fillTypeIndex] = {}
									availableItemsInStorages[fillTypeIndex].fillTypeIndex = fillTypeIndex
									availableItemsInStorages[fillTypeIndex].fillLevel = fillLevel

									availableItemsInStorages[fillTypeIndex].title = g_currentMission.fillTypeManager.fillTypes[fillTypeIndex].title
								end
							end
						end
					end
				end

				-- Sortieren der Filltypes
				local sortedAvailableItems = {}
				for _, availableItem in pairs (availableItemsInStorages) do
					table.insert(sortedAvailableItems, availableItem)
				end

				table.sort(sortedAvailableItems, compAvailableItems)

				local empty = true
				--FillType-Liste erstellen
				for _, availableItem in pairs (sortedAvailableItems) do
					table.insert(selectableOptions, availableItem)
					table.insert(options, availableItem.title .. " (" .. math.floor(availableItem.fillLevel) .. " l)")
					empty = false
				end

				if empty then
					local dummy = {}
					dummy.empty = true
					table.insert(selectableOptions, dummy)
					table.insert(options, g_i18n:getText("Revamp_StorageEmpty"))
				end
			else
				local dummy = {}
				dummy.empty = true
				local text = string.format(g_i18n:getText("Revamp_ProductionClosed"), self.productionPoint:getName(), closedTimes)
				table.insert(selectableOptions, dummy)
				table.insert(options, text)
			end

			--Dialog erstellen
			local dialogArguments = {
				text = g_i18n:getText("Revamp_ChooseWhatToPutOut"),
				title = self.productionPoint:getName(),
				options = options,
				target = self,
				args = selectableOptions,
				callback = self.fillTypeSelected
			}

			--TODO: hack to reset the "remembered" option (i.e. solve a bug in the game engine)
			local dialog = g_gui.guis["OptionDialog"]
			if dialog ~= nil then
				dialog.target:setOptions({""}) -- Add fake option to force a "reset"
			end

			g_gui:showOptionDialog(dialogArguments)
			end
		end
	end
end

ProductionPointActivatable.run = Utils.overwrittenFunction(ProductionPointActivatable.run, RevampSpawner.run)



function compAvailableItems(w1,w2)
	return w1.title .. w1.fillTypeIndex < w2.title .. w2.fillTypeIndex
end



--Production Revamp: Filltype ausgewählt, Mengen-Optionen anzeigen/BallenGrößen anzeigen
function ProductionPointActivatable:fillTypeSelected(selectedOption, args, rproductionPoint)
	local selectableOptions = {}
	local options = {}
	if rproductionPoint == nil then
		rproductionPoint = self.productionPoint
	end
	local selectedArg = args[selectedOption]
	if selectedArg == nil then return end

	if selectedArg.openmenu then
		rproductionPoint:openMenu()
	elseif selectedArg.closed then
		local dummy = {}
		dummy.empty = true
		local text = string.format(g_i18n:getText("Revamp_ProductionClosed"), rproductionPoint:getName(), selectedArg.closedTimes)
		table.insert(selectableOptions, dummy)
		table.insert(options, text)
		--Dialogbox erstellen
		local dialogArguments = {
			text = "",
			title = rproductionPoint:getName(),
			options = options,
			target = self,
			args = selectableOptions,
			callback = self.fillTypeSelected
		}

		--TODO: hack to reset the "remembered" option (i.e. solve a bug in the game engine)
		local dialog = g_gui.guis["OptionDialog"]
		if dialog ~= nil then
			dialog.target:setOptions({""}) -- Add fake option to force a "reset"
		end
		g_gui:showOptionDialog(dialogArguments)		
	elseif selectedArg.empty then
		--Production Revamp: Leer, damit nichts passiert
	else
		local fillTypeIndex = selectedArg.fillTypeIndex

		--Ballen Übersicht laden falls noch nicht geladen
		if self.baleTypes == nil then
			self.baleTypes = RevampHelper:GetBaleTypes()
		end	

		-- Liste Überprüfen ob ein Filltype in der Ballen-Liste auftaucht
		-- Sollte kein Ballen vorhanden sein, wie Palette behandeln, ansonsten Ballenliste weiter auswerten
		local currentFillType = g_fillTypeManager:getFillTypeByIndex(fillTypeIndex)

		-- wenn es mehrere möglichkeiten gibt zu auslagern, also Ballen, Paletten oder Holzstämme.
		-- hier die möglichkeiten bestimmen
		local possibilities = {}
		if self.baleTypes[currentFillType.name] ~= nil then
			table.insert(possibilities, "bale")
		end
		if rproductionPoint.palletSpawner.fillTypeIdToPallet[fillTypeIndex] ~= nil then
			table.insert(possibilities, "pallet")
		end
		if currentFillType.name == "WOOD" and rproductionPoint.woodSpawnPlace ~= nil then
			table.insert(possibilities, "woodLog")
		end

		-- Wenn es nur eine Möglichkeit gibt, diese direkt aufrufen ohne anderen dialog
		if #possibilities == 1 then
			if possibilities[1] == "bale" then
				self:chooseBaleAmount(self, rproductionPoint, selectedArg.fillLevel, currentFillType)
			return
			elseif possibilities[1] == "woodLog" then
				self:chooseWoodLogLength(self, rproductionPoint, selectedArg.fillLevel, currentFillType)
				return
			else
				self:choosePalletAmount(self, rproductionPoint, selectedArg.fillLevel, currentFillType)
				return
			end
		elseif #possibilities == 0 then
				return
		else
			-- multiple choice dialog 
			local selectableOptions = {}
			local options = {}

			-- Auswahl erstellen
			for i, possibilitie in pairs (possibilities) do
				table.insert(selectableOptions, {fillLevel=selectedArg.fillLevel, possibilitie=possibilitie, fillType=currentFillType, productionPoint=rproductionPoint})
				table.insert(options, g_i18n:getText("Revamp_SpawnType_"..possibilitie))
			end

			-- Dialogbox erstellen
			local dialogArguments = {
				text = g_i18n:getText("Revamp_ChooseSpawnToPutOut") .. " - " .. currentFillType.title .. " (" .. RevampHelper:formatVolume(selectedArg.fillLevel, 0, currentFillType.unitShort) .. ")",
				title = rproductionPoint:getName(),
				options = options,
				target = self,
				args = selectableOptions,
				callback = self.spawnTypeSelected
			}

			--TODO: hack to reset the "remembered" option (i.e. solve a bug in the game engine)
			local dialog = g_gui.guis["OptionDialog"]
			if dialog ~= nil then
				dialog.target:setOptions({""}) -- Add fake option to force a "reset"
			end

			g_gui:showOptionDialog(dialogArguments)
			return
		end
	end
end



function ProductionPointActivatable:spawnTypeSelected(selectedOption, args)
	local selectedArg = args[selectedOption]
	if selectedArg == nil then return end

	if selectedArg.possibilitie == "bale" then
		self:chooseBaleAmount(self, selectedArg.productionPoint, selectedArg.fillLevel, selectedArg.fillType)
		return
	elseif selectedArg.possibilitie == "woodLog" then
		self:chooseWoodLogLength(self, selectedArg.productionPoint, selectedArg.fillLevel, selectedArg.fillType)
		return
	else
		self:choosePalletAmount(self, selectedArg.productionPoint, selectedArg.fillLevel, selectedArg.fillType)
		return
	end
end



function ProductionPointActivatable:chooseWoodLogLength(self, rproductionPoint, availableFillLevel, fillType)
	-- Auswahl Länge anzeigen

	local minLength = rproductionPoint.minWoodLogLength
	local maxLength = rproductionPoint.maxWoodLogLength -- 34 max bei spruce

	local selectableOptions = {}
	local options = {}

	-- Auswahl für jede länge erstellen
	for i = minLength, maxLength do
		table.insert(selectableOptions, {length = i, amountPerWoodLog = RevampHelper.amountPerMeterSpruce[i], fillType = fillType, fillLevel = availableFillLevel, productionPoint=rproductionPoint})
		table.insert(options, i .. "m (" ..RevampHelper:formatVolume(RevampHelper.amountPerMeterSpruce[i], 0, fillType.unitShort) .. ")")
	end

	if #selectableOptions == 1 then

		rproductionPoint.selectedWoodLogLength = selectableOptions[1].length
		rproductionPoint.amountPerWoodLog = selectableOptions[1].amountPerWoodLog
		rproductionPoint.fillTypeIndex = selectableOptions[1].fillType.index

		self:chooseWoodLogAmount(self, rproductionPoint, selectableOptions[1].fillLevel, selectableOptions[1].fillType)

		return
	end

	-- Dialogbox erstellen
	local dialogArguments = {
		text = g_i18n:getText("Revamp_ChooseWoodLogLength") .. " - " .. fillType.title .. " (" .. RevampHelper:formatVolume(availableFillLevel, 0, fillType.unitShort) .. ")",
		title = rproductionPoint:getName(),
		options = options,
		target = self,
		args = selectableOptions,
		callback = self.woodLogsLengthSelected
	}

	--TODO: hack to reset the "remembered" option (i.e. solve a bug in the game engine)
	local dialog = g_gui.guis["OptionDialog"]
	if dialog ~= nil then
		dialog.target:setOptions({""}) -- Add fake option to force a "reset"
	end

	g_gui:showOptionDialog(dialogArguments)
end



function ProductionPointActivatable:woodLogsLengthSelected(selectedOption, args)
	local selectedArg = args[selectedOption]
	if selectedArg == nil then return end

	if self.productionPoint == nil then
		-- wenn das nicht über self aufgerufen wurde, das self korrigieren. Notwendig bei aufruf über das Menü
		self = selectedArg.productionPoint.activatable
	end

	self.productionPoint.selectedWoodLogLength = selectedArg.length
	self.productionPoint.amountPerWoodLog = selectedArg.amountPerWoodLog
	self.productionPoint.fillTypeIndex = selectedArg.fillType.index
		
	self:chooseWoodLogAmount(self, self.productionPoint, selectedArg.fillLevel, selectedArg.fillType)
	
end



function ProductionPointActivatable:chooseWoodLogAmount(self, rproductionPoint, availableFillLevel, fillType)
	-- wieviele stämme können erstellt werden?
	-- nur ganze stämme?
	local amountPerWoodLog = rproductionPoint.amountPerWoodLog -- für spruce mit 6m
	local maxWoodLogs = Utils.getNoNil(math.floor(availableFillLevel / amountPerWoodLog), 0)

	if maxWoodLogs == 0 then
			return
	end

	-- begrenzen auf maximal 15
	maxWoodLogs = math.min(maxWoodLogs, rproductionPoint.maxWoodLogs)

	local selectableOptions = {}
	local options = {}

	-- Auswahl für jede menge die geht erstellen
	for i=1, maxWoodLogs do
		table.insert(selectableOptions, {amount=i, amountPerWoodLog=amountPerWoodLog, fillTypeIndex=fillType.index, productionPoint=rproductionPoint})
		table.insert(options, i .. " " .. g_i18n:getText("Revamp_WoodLogItem") .. " " ..self.productionPoint.selectedWoodLogLength.. " m (" ..RevampHelper:formatVolume(amountPerWoodLog*i, 0, fillType.unitShort) .. ")")
	end

	-- Dialogbox erstellen
	local dialogArguments = {
		text = g_i18n:getText("Revamp_ChooseAmountToPutOut") .. " - " .. fillType.title .. " (" .. RevampHelper:formatVolume(availableFillLevel, 0, fillType.unitShort) .. ")",
		title = rproductionPoint:getName(),
		options = options,
		target = self,
		args = selectableOptions,
		callback = self.woodLogsAmountSelected
	}

	--TODO: hack to reset the "remembered" option (i.e. solve a bug in the game engine)
	local dialog = g_gui.guis["OptionDialog"]
	if dialog ~= nil then
		dialog.target:setOptions({""}) -- Add fake option to force a "reset"
	end

	g_gui:showOptionDialog(dialogArguments)
end



function ProductionPointActivatable:woodLogsAmountSelected(selectedOption, args)
	local selectedArg = args[selectedOption]
	if selectedArg == nil then return end

	if self.productionPoint == nil then
		-- wenn das nicht über self aufgerufen wurde, das self korrigieren. Notwendig bei aufruf über das Menü
		self = selectedArg.productionPoint.activatable
	end

	self.productionPoint.pendingWoodLogs = selectedArg.amount
	self.productionPoint.amountPerWoodLog = selectedArg.amountPerWoodLog
	self.productionPoint.fillTypeIndex = selectedArg.fillTypeIndex

	if self.productionPoint.isServer then
		self:spawnWoodLogs()
	else
		RevampSpawnWoodLogsAtProductionEvent.sendEvent(self.productionPoint, self.productionPoint.pendingWoodLogs, self.productionPoint.amountPerWoodLog, self.productionPoint.fillTypeIndex, self.productionPoint.selectedWoodLogLength)

		-- Im multiplayer die lokale sperre wieder raus nehmen, sonst kann jeder user nur ein mal spawnen. 
		-- Somit könnte nehrfach gespawned werden im MP. Ich denke aktuell nicht das es ein Problem ist
		self.productionPoint.pendingWoodLogs = nil
	end
end



function ProductionPointActivatable:spawnWoodLogs()
	local rproductionPoint = self.productionPoint
	if rproductionPoint.isServer then				
		-- hier könnte auf platz geprüft werden, das hat aber nicht funktioniert
		local useSpawnPlace = rproductionPoint.woodSpawnPlace

		if useSpawnPlace == nil then
			return
		end

		-- einen stamm auslagern, spruce hat max länge 6m und dabei 1862 holz
		local treeTypeName = "SPRUCE1"
		local treeTypeDesc = g_treePlantManager:getTreeTypeDescFromName(treeTypeName)
		local treeType = treeTypeDesc.index

		-- spawnpunkt aus der xml
		local x, y, z = getWorldTranslation(useSpawnPlace)
		local dirX, dirY, dirZ = localDirectionToWorld(useSpawnPlace, 0, 0, 1)

		local length = rproductionPoint.selectedWoodLogLength
		local growthState = #treeTypeDesc.treeFilenames

		local spawned = PalletSiloActivatable:spawnLog(rproductionPoint, treeTypeDesc.index, length, growthState, x, y, z, dirX, dirY, dirZ)
		if spawned then
			rproductionPoint.pendingWoodLogs = rproductionPoint.pendingWoodLogs - 1
			if rproductionPoint.pendingWoodLogs == 0 then
				rproductionPoint.pendingWoodLogs = nil
			end

			--Filllevel aus Storage abziehen
			local delta = rproductionPoint.amountPerWoodLog
			local available = rproductionPoint.storage.fillLevels[rproductionPoint.fillTypeIndex]
			if available ~= null and available > 0 then
				local moved = math.min(delta, available)
				rproductionPoint.storage:setFillLevel(available - moved, rproductionPoint.fillTypeIndex)
			end
		else
			-- wenn nichts ging, dann abbrechen
			rproductionPoint.pendingWoodLogs = nil
		end				

		-- mit timer so lange aufrufen bis alles weg ist
		if rproductionPoint.pendingWoodLogs ~= nil and rproductionPoint.pendingWoodLogs > 0 then

			self.woodLogTimer = Timer.new(400)
			self.woodLogTimer:setFinishCallback(
				function()
					self:spawnWoodLogs(rproductionPoint)
				end)
			self.woodLogTimer:start(true)
		end
	end
end



function ProductionPointActivatable:choosePalletAmount(self, rproductionPoint, availableFillLevel, fillType)
	--Werte für Spawner hinterlegen
	rproductionPoint.pendingLiters[fillType.index] = availableFillLevel

	--Berechnen der maximalen Palettenanzahl
	local pallet = rproductionPoint.palletSpawner.fillTypeIdToPallet[fillType.index]
	local amountPerPallet = pallet.capacity
	local maxPallets = math.floor(availableFillLevel / amountPerPallet)
	if ((availableFillLevel - (maxPallets*amountPerPallet)) >= 1) then
		maxPallets = maxPallets + 1
	end

	if(maxPallets == 0) then return end

	--Auswählbare Palettenanzahl in Liste eintragen
	local selectableOptions = {}
	local options = {}
	for i=1, maxPallets do
		table.insert(selectableOptions, {amount=i, amountPerPallet=amountPerPallet, fillTypeIndex=fillType.index, productionPoint=rproductionPoint})
		table.insert(options, i .. " " .. g_i18n:getText("Revamp_PalletSiloItem") .. " (" ..RevampHelper:formatVolume(math.min(amountPerPallet * i, rproductionPoint.pendingLiters[fillType.index]), 0, fillType.unitShort) .. ")")
	end

	--Dialog erstellen
	local dialogArguments = {
		text = g_i18n:getText("Revamp_ChooseAmountToPutOut") .. " - " .. fillType.title .. " (" .. RevampHelper:formatVolume(availableFillLevel, 0, fillType.unitShort) .. ")",
		title = rproductionPoint:getName(),
		options = options,
		target = self,
		args = selectableOptions,
		callback = self.amountSelected
	}

	--TODO: hack to reset the "remembered" option (i.e. solve a bug in the game engine)
	local dialog = g_gui.guis["OptionDialog"]
	if dialog ~= nil then
		dialog.target:setOptions({""}) -- Add fake option to force a "reset"
	end
	g_gui:showQuickAmountDialog(dialogArguments)
end



function ProductionPointActivatable:chooseBaleAmount(self, rproductionPoint, availableFillLevel, fillType)
	baleType = self.baleTypes[fillType.name]
	local selectableOptions = {}
	local options = {}

	--BallenVarianten in Optionsliste eintragen mit den entsprechenden Daten, Options = AnzeigeName, selectableObtion = Übermittelte Werte
	for index, baleSize in ipairs(baleType.sizes) do
		local title
		if baleSize.isRoundbale then
			title = g_i18n:getText("fillType_roundBale") .. " " .. tostring(baleSize.diameter) .. "m (" .. tostring(baleSize.capacity) .. "L)"
		else
			title = g_i18n:getText("fillType_squareBale") .. " " .. tostring(baleSize.length) .. "m (" .. tostring(baleSize.capacity) .. "L)"
		end
		table.insert(selectableOptions, {fillTypeIndex=fillType.index, baleSize=baleSize, fillLevel=availableFillLevel, productionPoint=rproductionPoint, customEnvironment = baleSize.customEnvironment})
		table.insert(options, title)
	end

	--Dialogbox erstellen welcher Ballen ausgelagert werden soll
	local dialogArguments = {
		text = g_i18n:getText("Revamp_ChooseBaleType") .. " - " .. fillType.title .. " (" .. RevampHelper:formatVolume(availableFillLevel, 0, fillType.unitShort) .. ")",
		title = rproductionPoint:getName(),
		options = options,
		target = self,
		args = selectableOptions,
		callback = self.baleSelected
	}

	--TODO: hack to reset the "remembered" option (i.e. solve a bug in the game engine)
	local dialog = g_gui.guis["OptionDialog"]
	if dialog ~= nil then
		dialog.target:setOptions({""}) -- Add fake option to force a "reset"
	end
	g_gui:showOptionDialog(dialogArguments)
end



--Production Revamp: Ausgewählte Anzahl Paletten spawnen
function ProductionPointActivatable:amountSelected(selectedOption, args)
	local selectedArg = args[selectedOption]
	if selectedArg == nil then return end
	local totalAmount = selectedArg.amount * selectedArg.amountPerPallet
	local productionPoint = selectedArg.productionPoint

	-- Wenn es setzlinge sind, dann Dialog zwischenschalten zum typ wählen
	local currentFillType = g_fillTypeManager:getFillTypeByIndex(selectedArg.fillTypeIndex)
	if currentFillType.name == "TREESAPLINGS" then
		local pallet = productionPoint.palletSpawner.fillTypeIdToPallet[selectedArg.fillTypeIndex]
		local storeItem = g_storeManager:getItemByXMLFilename(pallet.filename)

		local selectableOptions = {}
		local options = {}

		for index, treeSaplingType in ipairs(storeItem.configurations.treeSaplingType) do
			local title = treeSaplingType.name
			table.insert(selectableOptions, {treeSaplingTypeIndex=treeSaplingType.index, treeSaplingTypeName=treeSaplingType.name, amount=selectedArg.amount, amountPerPallet=selectedArg.amountPerPallet, productionPoint=selectedArg.productionPoint, fillTypeIndex=selectedArg.fillTypeIndex})
			table.insert(options, title)
		end

		--Dialogbox erstellen
		local dialogArguments = {
			text = g_i18n:getText("configuration_treeType"),
			title = productionPoint:getName(),
			options = options,
			target = self,
			args = selectableOptions,
			callback = self.treeSaplingTypeSelected
		}

		--TODO: hack to reset the "remembered" option (i.e. solve a bug in the game engine)
		local dialog = g_gui.guis["OptionDialog"]
		if dialog ~= nil then
			dialog.target:setOptions({""}) -- Add fake option to force a "reset"
		end
		g_gui:showOptionDialog(dialogArguments)	

		-- return damit nicht direkt ausgelagert wird
		return
	end

	--Auzulagernde Menge hinterlegen
	productionPoint.pendingLiters[selectedArg.fillTypeIndex] = math.min(productionPoint.pendingLiters[selectedArg.fillTypeIndex], totalAmount)
	--Event aufrufen für Multiplayer
	RevampSpawnPalletsEvent.sendEvent(productionPoint, productionPoint.ownerFarmId, selectedArg.fillTypeIndex, productionPoint.pendingLiters[selectedArg.fillTypeIndex])
end



--Production Revamp: Setzlingstyp wurde gewählt
function ProductionPointActivatable:treeSaplingTypeSelected(selectedOption, args)
	local selectedArg = args[selectedOption]
	if selectedArg == nil then return end
	local totalAmount = selectedArg.amount * selectedArg.amountPerPallet
	local productionPoint = selectedArg.productionPoint

	-- zuletzt gewählter Setzlingstyp in produktion hinterlegen so dass es benutzt werden kann
	productionPoint.treeSaplingTypeIndex = selectedArg.treeSaplingTypeIndex
	productionPoint.treeSaplingTypeName = selectedArg.treeSaplingTypeName

	--Auzulagernde Menge hinterlegen
	productionPoint.pendingLiters[selectedArg.fillTypeIndex] = math.min(productionPoint.pendingLiters[selectedArg.fillTypeIndex], totalAmount)
	--Event aufrufen für Multiplayer
	RevampSpawnPalletsEvent.sendEvent(productionPoint, productionPoint.ownerFarmId, selectedArg.fillTypeIndex, productionPoint.pendingLiters[selectedArg.fillTypeIndex])
end



--Production Revamp: Receive function from SendEvent
function ProductionPoint:ReceivePalletEvent(ownerFarmId, fillTypeIndex, pendingLiters)
	self.pendingLiters[fillTypeIndex] = pendingLiters
	self.palletSpawner:spawnPallet(ownerFarmId, fillTypeIndex, ProductionPoint.getPalletCallback, self)
end



--Production Revamp: Receive function from SendEvent
function ProductionPoint:ReceiveBaleEvent(ownerFarmId, fillTypeIndex, pendingLiters, isBale, isRoundbale, width, height, length, diameter, capacity, wrapState, customEnvironment)
	--Werte hinterlegen für den Spawner
	self.pendingLiters[fillTypeIndex] = pendingLiters

	self.palletSpawner:spawnBale(ownerFarmId, fillTypeIndex, ProductionPoint.getPalletCallback, self, isBale, isRoundbale, width, height, length, diameter, capacity, wrapState, customEnvironment, self.wrapColor)
end



--Production Revamp: CallBack fürs Paletten/Ballen Spawnen
function ProductionPoint:getPalletCallback(pallet, result, fillTypeIndex)
	--Production Revamp: Spawner abschalten, da Palette gespawnt wurde
	self.spawnPending = false
	if pallet ~= nil then
		pallet.fillTypeIndex = fillTypeIndex

		local delta = 0
		--Nur ausführen sollte es eine Palette sein
		if pallet.isBale == nil then
			if result == PalletSpawner.RESULT_SUCCESS then
				pallet:emptyAllFillUnits(true)
			end
			--Die noch leere Palette befüllen
			delta = pallet:addFillUnitFillLevel(self.ownerFarmId, 1, self.pendingLiters[fillTypeIndex], fillTypeIndex, ToolType.UNDEFINED)
		else
			--Da Ballen mit vorgegebenen Volumen spawnen, Capacity auslesen um sie aus dem Storage zu entfernen
			delta = pallet.capacity
		end

		self.pendingLiters[fillTypeIndex] = math.max(self.pendingLiters[fillTypeIndex] - delta, 0)
		
		-- setzlingstyp eintragen, wenn filltype
		local currentFillType = g_fillTypeManager:getFillTypeByIndex(fillTypeIndex)
		if currentFillType.name == "TREESAPLINGS" and self.treeSaplingTypeIndex ~= nil then
			pallet.boughtConfigurations.treeSaplingType[pallet.configurations.treeSaplingType] = nil
			pallet.configurations.treeSaplingType = self.treeSaplingTypeIndex
			pallet.boughtConfigurations.treeSaplingType[self.treeSaplingTypeIndex] = true

			-- seit patch 1.8 muss hier die infobox gefüllt werden mit dem Namen beim spawnen
			pallet.spec_treeSaplingPallet.infoBoxLineValue = self.treeSaplingTypeName
		end

		--Filllevel aus Storage abziehen
		local available = self.storage.fillLevels[fillTypeIndex]
		if available ~= null and available > 0 then
			local moved = math.min(delta, available)
			self.storage:setFillLevel(available - moved, fillTypeIndex)
		end
		if self.pendingLiters[fillTypeIndex] > 0 then
			--Damit das gesammt FillVolume ausgelager werden kann, überprüfen ob der Ballen größer ist als der restliche Inhalt und anpassen
			if pallet.isBale and self.pendingLiters[fillTypeIndex] < pallet.capacity then
				pallet.capacity = self.pendingLiters[fillTypeIndex]
			end
			self:updatePallets(pallet)
		else
			self.pendingLiters[fillTypeIndex] = nil
		end
	end
end



--Production Revamp: CallBack für den Timer
function ProductionPoint:TimerCallback(fillTypeIndex)
	if self.isbale == nil then
		self.palletSpawner:spawnPallet(self.ownerFarmId, fillTypeIndex, ProductionPoint.getPalletCallback, self)
	else
		local bale = self.bale
		self.palletSpawner:spawnBale(self.ownerFarmId, fillTypeIndex, ProductionPoint.getPalletCallback, self, bale.isBale, bale.isRoundbale, bale.width, bale.height, bale.length, bale.diameter, bale.capacity, bale.wrapState, bale.customEnvironment, self.wrapColor)
	end
end



--Production Revamp: UpdateFunktion für Palettenspawner, Timer von 200ms um zu schnelles Spawnen zu vermeiden
function ProductionPoint:updatePallets(bale)
	if self.isServer then
		if not self.spawnPending and self.pendingLiters[bale.fillTypeIndex] > 0 then
			self.spawnPending = true
			if bale.isBale == nil then
				self.isbale = nil
				self.palletTimer = Timer.new(200)
				self.palletTimer:setFinishCallback(
				function()
					self:TimerCallback(bale.fillTypeIndex)
				end)
				self.palletTimer:start(true)
			else
				self.isbale = true
				self.bale = bale
				self.palletTimer = Timer.new(200)
				self.palletTimer:setFinishCallback(
				function()
					self:TimerCallback(bale.fillTypeIndex)
				end)
				self.palletTimer:start(true)
			end
		end
	end
end



--Production Revamp: Ballen Variante augewählt, Mengen-Optionen anzeigen
function ProductionPointActivatable:baleSelected(selectedOption, args)
	--Parameter auslesen
	local selectedArg = args[selectedOption]
	if selectedArg == nil then return end
	local productionPoint = selectedArg.productionPoint
	local fillTypeIndex = selectedArg.fillTypeIndex
	local baleSize = selectedArg.baleSize
	local amountPerBale = baleSize.capacity

	--Werte für spawner hinterlegen
	productionPoint.pendingLiters[fillTypeIndex] = selectedArg.fillLevel

	--Berechnen der maximalen Ballenanzahl
	local maxBales = math.floor(selectedArg.fillLevel / amountPerBale)
	if ((selectedArg.fillLevel - (maxBales*amountPerBale)) >= 1) then
		maxBales = maxBales + 1
	end

	if(maxBales == 0) then return end

	--Auswählbare Ballenanzahl in Liste eintragen
	local currentFillType = g_fillTypeManager:getFillTypeByIndex(fillTypeIndex)

	local selectableOptions = {}
	local options = {}
	for i=1, maxBales do
		table.insert(selectableOptions, {amount=i, amountPerPallet=amountPerBale, fillTypeIndex=fillTypeIndex, baleSize=baleSize, productionPoint=productionPoint})
		table.insert(options, i .. " " .. g_i18n:getText("Revamp_BaleSiloItem") .. " (" ..RevampHelper:formatVolume(math.min(amountPerBale*i, productionPoint.pendingLiters[fillTypeIndex]), 0, currentFillType.unitShort) .. ")")
	end

	--Dialog Optionen Anlegen
	local dialogArguments = {
		text = g_i18n:getText("Revamp_ChooseAmountToPutOut") .. " - " .. currentFillType.title .. " (" .. RevampHelper:formatVolume(selectedArg.fillLevel, 0, currentFillType.unitShort) .. ")",
		title = productionPoint:getName(),
		options = options,
		target = self,
		args = selectableOptions,
		callback = self.spawnBales
	}

	--TODO: hack to reset the "remembered" option (i.e. solve a bug in the game engine)
	local dialog = g_gui.guis["OptionDialog"]
	if dialog ~= nil then
		dialog.target:setOptions({""}) -- Add fake option to force a "reset"
	end

	g_gui:showQuickAmountDialog(dialogArguments)
end



--Production Revamp: Ausgewähle Anzahl Ballen spawnen
function ProductionPointActivatable:spawnBales(selectedOption, args)
	-- Anzahl möglicher Ballen für eine neue Auswahl
	local selectedArg = args[selectedOption]
	if selectedArg == nil then return end
	local baleSize = selectedArg.baleSize
	local productionPoint = selectedArg.productionPoint

	--EntnahmeMenge berechnen
	local totalAmount = selectedArg.amount * selectedArg.baleSize.capacity

	productionPoint.pendingLiters[selectedArg.fillTypeIndex] = math.min(productionPoint.pendingLiters[selectedArg.fillTypeIndex], totalAmount)

	--Damit das gesammt FillVolume ausgelager werden kann, überprüfen ob der Ballen größer ist als der restliche Inhalt und anpassen
	if productionPoint.pendingLiters[selectedArg.fillTypeIndex] < selectedArg.baleSize.capacity then
		productionPoint.capacity = productionPoint.pendingLiters[selectedArg.fillTypeIndex]
	else
		productionPoint.capacity = selectedArg.baleSize.capacity
	end
	RevampSpawnBalesEvent.sendEvent(productionPoint, productionPoint.ownerFarmId, selectedArg.fillTypeIndex, productionPoint.pendingLiters[selectedArg.fillTypeIndex], true, baleSize.isRoundbale, baleSize.width, baleSize.height, baleSize.length, baleSize.diameter, productionPoint.capacity, baleSize.wrapState, baleSize.customEnvironment)

end



--Production Revamp: Auftrag Ballen zu generieren in der SpawnQueue hinterlegen
function PalletSpawner:spawnBale(farmId, fillTypeId, callback, callbackTarget, isBale, isRoundbale, width, height, length, diameter, capacity, wrapState, customEnvironment, wrapColor)
	local pallet = nil
	if isBale then
		--Ballen Daten laden
		local baleXMLFilename = g_baleManager:getBaleXMLFilename(fillTypeId, isRoundbale, width, height, length, diameter, customEnvironment)

		--Ballen Abmessung hinterlegen für Spawncheck
		local size = {}
		local fillType = g_fillTypeManager:getFillTypeByIndex(fillTypeId)
		size.height = height
		if isRoundbale then
			--Maße vom Rundballen hinterlegen
			size.width = diameter
			size.length = diameter
		elseif fillType.name == "COTTON" then
			--Maße vom Cotton Quaderballen drehen für den Spawnbereich, damit dieser Spawnen kann
			size.width = length
			size.length = width
		else
			--Maße von Quaderballen hinterlegen
			size.width = width
			size.length = length			
		end

		--Fake Palette anlegen, damit der Spawner weiterhin funktioniert
		pallet = {}
		pallet.filename = baleXMLFilename
		pallet.size = size
		pallet.capacity = capacity
		pallet.isBale = true
		pallet.isRoundbale = isRoundbale
		pallet.wrapState = wrapState
		pallet.width = width
		pallet.height = height
		pallet.length = length
		pallet.diameter = diameter
		pallet.customEnvironment = customEnvironment
		pallet.wrapColor = wrapColor
	end

	if pallet ~= nil then
		table.insert(self.spawnQueue, {
			pallet = pallet,
			fillType = fillTypeId,
			farmId = farmId,
			callback = callback,
			callbackTarget = callbackTarget
		})
		g_currentMission:addUpdateable(self)
	else
		Logging.devError("Production Revamp: no bale for fillTypeId", fillTypeId)
		callback(callbackTarget, nil, PalletSpawner.NO_PALLET_FOR_FILLTYPE, fillTypeId)
	end
end



--Production Revamp: Ballen generieren
function PalletSpawner:onSpawnSearchFinishedBale(location)
	local objectToSpawn = self.currentObjectToSpawn
	if location ~= nil then
		location.y = location.y + 0.25
		--Ballen generieren
		local baleObject = Bale.new(g_currentMission:getIsServer(), g_currentMission:getIsClient())
		if objectToSpawn.pallet.isRoundbale then
			--Rundballen auf die Seite drehen, damit diese nicht wegrollen
			location.xRot = location.xRot + (3.1415927 / 2)
		end
		local fillType = g_fillTypeManager:getFillTypeByIndex(objectToSpawn.fillType)
		if fillType.name == "COTTON" then
			--Cotton Quaderballen drehen, damit diese in den Spawnbereich passen
			location.yRot = location.yRot + (3.1415927 / 2)
			--Cotton Quaderballen zusätzliche 0,25m nach oben verschieben
			location.y = location.y + 1.30
		end
		if baleObject:loadFromConfigXML(objectToSpawn.pallet.filename, location.x, location.y, location.z, location.xRot, location.yRot, location.zRot) then
			baleObject:setFillType(objectToSpawn.fillType, true)
			baleObject:setOwnerFarmId(objectToSpawn.farmId, true)
			baleObject:setFillLevel(objectToSpawn.pallet.capacity, true)
			if objectToSpawn.pallet.wrapState then
				--SilageBallen eingewickelt Spawnen
				baleObject:setWrappingState(1)
				local colors = RevampHelper.UnpackWrapColor(objectToSpawn.pallet.wrapColor)
				baleObject:setColor(colors[1], colors[2], colors[3], colors[4])
			end
			baleObject:register()
			--Manueller Callback
			objectToSpawn.callback(objectToSpawn.callbackTarget, objectToSpawn.pallet, PalletSpawner.RESULT_SUCCESS, objectToSpawn.fillType)
			self.currentObjectToSpawn = nil
			table.remove(self.spawnQueue, 1)
		else
			print("PalletSpawner: Could not spawn bale object")
		end
	else
		objectToSpawn.callback(objectToSpawn.callbackTarget, nil, PalletSpawner.RESULT_NO_SPACE)

		self.currentObjectToSpawn = nil

		table.remove(self.spawnQueue, 1)
	end
end



--Production Revamp: Connector-Funktion zum Spawner-Script vom ProduktionsMenü(Namensräume)
function InGameMenuProductionFrame:menuconnector()
	local _, productionPoint = self:getSelectedProduction()
	local fillType, isInput = self:getSelectedStorageFillType()
	local fillLevel = self.selectedProductionPoint.storage:getFillLevel(fillType)

	local args = {}

	--Production Revamp: Sollte die Produktion Öffnungszeiten haben, außerhalb der "Zeiten" keine Produktion, dann auch keine Paletten manuell spawnen.
	local skip = false
	local foundOne = false

	for _, production in pairs (productionPoint.productions) do
		local modes = string.split(production.mode, " ")
		for _, mode in pairs(modes) do
			if mode =="hourly" then
				local currentHour = g_currentMission.environment.currentHour
				if production.hoursTable[currentMission] == true then
					skip = false
					foundOne = true
				elseif foundOne == false then
					closedTimes = production.hours
					skip = true
				end
			end
		end
	end
	
	if skip then
		--Production Revamp: Fake-Eintrag damit die Produktion geschlossen Meldung angezeigt wird.
		local closed	= {}
		closed.fillTypeIndex = fillType
		closed.fillLevel = fillLevel
		closed.title = g_currentMission.fillTypeManager.fillTypes[fillType].title
		closed.closed = true
		closed.closedTimes = closedTimes
		table.insert(args, closed)
	else
		--Production Revamp: Fake-Eintrag damit die Mengen-Auswahl aufgerufen werden kann.
		local insert = {}
		insert.fillTypeIndex = fillType
		insert.fillLevel = fillLevel
		insert.title = g_currentMission.fillTypeManager.fillTypes[fillType].title
		table.insert(args, insert)
	end

	ProductionPointActivatable:fillTypeSelected(1, args, productionPoint)
end



--Production Revamp: MenüButten hinzufügen zum Auslagern
function RevampSpawner:updateMenuButtons(superFunc)

	-- Pump'n'Hoses Produktionen ignorieren
	local _, productionPoint = self:getSelectedProduction()
	if productionPoint:isa(SandboxProductionPoint) or (productionPoint.owningPlaceable.isSandboxPlaceable ~= nil and productionPoint.owningPlaceable:isSandboxPlaceable()) then
		return
	end

	local isProductionListActive = self.productionList == FocusManager:getFocusedElement()
	local fillType, isInput = self:getSelectedStorageFillType()

	if not isProductionListActive and fillType ~= FillType.UNKNOWN then
		if not isInput then
			local _, productionPoint = self:getSelectedProduction()
			if productionPoint.palletSpawner == nil then
			else
				--BallenTypen laden falls noch nicht geladen
				if ProductionPointActivatable.baleTypes == nil then
					ProductionPointActivatable.baleTypes = RevampHelper:GetBaleTypes()
				end
				local currentFillType = g_fillTypeManager:getFillTypeByIndex(fillType)

					--Production Revamp: Filltypen ohne Palette und Ballen werden nicht angezeigt
					local output = false
					if ProductionPointActivatable.baleTypes[currentFillType.name] ~= nil or currentFillType.palletFilename ~= nil or (currentFillType.name == "WOOD" and productionPoint.woodSpawnPlace ~= nil) then
						output = true
					end

					if output then
					table.insert(self.menuButtonInfo, {
						profile = "buttonOk",
						inputAction = InputAction.MENU_ACTIVATE,
						text = self.i18n:getText("Revamp_SpawnItem"),
						callback = function()
							self:menuconnector()
						end
					})
					self:setMenuButtonInfoDirty()
				end
			end
		end
	end
end

InGameMenuProductionFrame.updateMenuButtons = Utils.appendedFunction(InGameMenuProductionFrame.updateMenuButtons, RevampSpawner.updateMenuButtons)



print("Production Revamp: Loading Pallet/Bale Spawner complete")