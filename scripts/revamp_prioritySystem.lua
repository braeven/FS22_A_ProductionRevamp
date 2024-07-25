--[[
Production Revamp
Revamp Priority System

Copyright (C) braeven, Achimobil, 2022

Author: braeven, Achimobil

Date: 29.03.2023
Version: 1.2.4.1

Contact/Help/Tutorials:
discord.gg/gHmnFZAypk


Changelog:
1.0.0.0 @ 09.07.2022 - Moved Priority System out of the main-file into new file
1.1.0.0 @ 05.08.2022 - Produktion mit Zeitbrenzungen Verteilen und bekommen nur Güter währen dieser Zeit
1.2.0.0 @ 27.09.2022 - Kompabilität mit PnH
1.2.1.0 @ 01.10.2022 - Bugfix mit PnH mit dem Prioritäten System
1.2.2.0 @ 20.12.2022 - Code Cleanup
1.2.3.0 @ 10.01.2023 - Lieferzeiten korrigiert
1.2.4.0 @ 14.02.2023 - Bugfix Zyklen-Anzeige
1.2.4.1 @ 17.03.2023 - Bugfix mit PnH
1.2.4.2 @ 29.03.2023 - Bugfix again


Important:.
No changes are allowed to this script without permission from Braeven AND Achimobil.
If you want to make a production with this script, look in the documentation, discord channels for tutorials/help or download the FS22_Revamp_Productions Pack for reference
Don't copy the script into a production, load the mod as a dependency!

Es dürfen an diesem Script keine Veränderungen ohne Erlaubnis von Braeven UND Achimobil gemacht werden.
Wenn du eine Produktion mit diesem Script bauen möchtest, lese dir die Dokumentation, die angepinnten Tutorials im Discord durch oder guck dir die FS22_Revamp_Productions an.
Nicht das Script in Produktionen kopieren, ladet den Mod über eine Dependency!

]]

source(g_currentModDirectory .. "scripts/events/ProductionPointPriorityEvent.lua")

RevampPriority = {}

--Production Revamp: Überschrieben um den Output-Mode auf "Einlagern" setzen zu können
function RevampPriority:setOutputDistributionMode(superFunc, outputFillTypeId, mode, noEventSend)

	-- Pump'n'Hoses Produktionen ignorieren
	if self:isa(SandboxProductionPoint) or (self.owningPlaceable.isSandboxPlaceable ~= nil and self.owningPlaceable:isSandboxPlaceable()) then
		if mode == ProductionPoint.OUTPUT_MODE.STORE then
			mode = ProductionPoint.OUTPUT_MODE.DIRECT_SELL
		end
		return superFunc(self, outputFillTypeId, mode, noEventSend)
	end

	if self.outputFillTypeIds[outputFillTypeId] == nil then
		printf("Production Revamp: Error: setOutputDistribution(): fillType '%s' is not an output fillType", g_fillTypeManager:getFillTypeNameByIndex(outputFillTypeId))

		return
	end

	mode = tonumber(mode)
	self.outputFillTypeIdsDirectSell[outputFillTypeId] = nil
	self.outputFillTypeIdsAutoDeliver[outputFillTypeId] = nil
	--Production Revamp: Alle Filltypes generell auf nil setzen für die Storage-Liste
	self.outputFillTypeIdsStorage[outputFillTypeId] = nil
	--Production Revamp: CoolDown für den Palettenspawner, damit nicht versehentlich Paletten gespawnt werden beim Umschalten
	self.palletSpawnCooldown = g_time + 4000

	if mode == ProductionPoint.OUTPUT_MODE.DIRECT_SELL then
		if self.disableDirectSell[outputFillTypeId] == false then
			self.outputFillTypeIdsDirectSell[outputFillTypeId] = true
		elseif self.disableDistribution[outputFillTypeId] == false then
			self.outputFillTypeIdsAutoDeliver[outputFillTypeId] = true
		else
			self.outputFillTypeIdsStorage[outputFillTypeId] = true
		end
	elseif mode == ProductionPoint.OUTPUT_MODE.AUTO_DELIVER then
		if self.disableDistribution[outputFillTypeId] == false then
			self.outputFillTypeIdsAutoDeliver[outputFillTypeId] = true	
		else
			self.outputFillTypeIdsStorage[outputFillTypeId] = true
		end
	--Production Revamp: Sollte ein Output auf "Einlagern" stehen, Filltype in der Liste hinterlegen
	elseif mode == ProductionPoint.OUTPUT_MODE.STORE then
		self.outputFillTypeIdsStorage[outputFillTypeId] = true
	elseif mode ~= ProductionPoint.OUTPUT_MODE.KEEP then
		printf("Production Revamp: Error: revamp setOutputDistribution(): Undefined mode '%s'", mode)

		return
	end

	ProductionPointOutputModeEvent.sendEvent(self, outputFillTypeId, mode, noEventSend)
end

ProductionPoint.setOutputDistributionMode = Utils.overwrittenFunction(ProductionPoint.setOutputDistributionMode, RevampPriority.setOutputDistributionMode)



--Production Revamp: Überschrieben um den Output-Mode auf "Einlagern" auslesen zu können
function RevampPriority:getOutputDistributionMode(superFunc, outputFillTypeId)
	if self.outputFillTypeIdsStorage ~= nil and self.outputFillTypeIdsStorage[outputFillTypeId] ~= nil then
		return ProductionPoint.OUTPUT_MODE.STORE
	end

	return superFunc(self, outputFillTypeId)
end

ProductionPoint.getOutputDistributionMode = Utils.overwrittenFunction(ProductionPoint.getOutputDistributionMode, RevampPriority.getOutputDistributionMode)



function RevampPriority:getNextOutputDistributionMode(superFunc, curMode)
	if curMode == ProductionPoint.OUTPUT_MODE.KEEP then 
		return ProductionPoint.OUTPUT_MODE.DIRECT_SELL
	elseif curMode == ProductionPoint.OUTPUT_MODE.DIRECT_SELL then 
		return ProductionPoint.OUTPUT_MODE.AUTO_DELIVER
	elseif curMode == ProductionPoint.OUTPUT_MODE.AUTO_DELIVER then 
		return ProductionPoint.OUTPUT_MODE.STORE
	end

	return ProductionPoint.OUTPUT_MODE.KEEP
end



function RevampPriority:toggleOutputDistributionMode(superFunc, outputFillTypeId)
	if self.outputFillTypeIds[outputFillTypeId] ~= nil then
		local curMode = self:getOutputDistributionMode(outputFillTypeId)

		if self.getNextOutputDistributionMode ~= nil then
			self:setOutputDistributionMode(outputFillTypeId, self:getNextOutputDistributionMode(curMode))
			return
		end

		if table.hasElement(ProductionPoint.OUTPUT_MODE, curMode + 1) then
			self:setOutputDistributionMode(outputFillTypeId, curMode + 1)
		else
			self:setOutputDistributionMode(outputFillTypeId, 0)
		end
	end
end

ProductionPoint.toggleOutputDistributionMode = Utils.overwrittenFunction(ProductionPoint.toggleOutputDistributionMode, RevampPriority.toggleOutputDistributionMode)



--Production Revamp: Einbau Intelligentes Verteilen nach Prioritäten & Eingeschalteten Produktionen + Bugfix Verteil-Kosten
function RevampPriority:distributeGoods()
	if not self.isServer then
		return
	end

	local currentHour = g_currentMission.environment.currentHour

	for _, farmTable in pairs(self.farmIds) do
		for i = 1, #farmTable.productionPoints do
			local distributingProdPoint = farmTable.productionPoints[i]
			local skip = true

			--Production Revamp: Produktionen können nur innerhalb der Arbeitszeit Waren versenden. Außerhalb der Arbeitszeit wird die Schleife der jeweiligen Produktion übersprungen.
			--Production Revamp: PNH-Produktionen mit Zeiten versehen um Fehler zu vermeiden
			if distributingProdPoint.hoursTable == nil then
				distributingProdPoint.hoursTable = {}
				for i = 0, 24 do
					distributingProdPoint.hoursTable[i] = true
				end
			end
			if distributingProdPoint.hoursTable[currentHour] then
				skip = false
			end

			if not skip then
				for fillTypeIdToDistribute in pairs(distributingProdPoint.outputFillTypeIdsAutoDeliver) do
					local amountToDistribute = distributingProdPoint.storage:getFillLevel(fillTypeIdToDistribute)

					if amountToDistribute > 0 then
						local prodPointsInDemand = farmTable.inputTypeToProductionPoints[fillTypeIdToDistribute] or {}

						--Production Revamp: Verteilen als eigene Funktion abhängig von der eingestellten Priorität der Belieferung
						local function distributePriority(priority, amountToDistribute, prodPointsInDemand, fillTypeIdToDistribute, distributingProdPoint)
							local ignorePriority = not RevampSettings.current.PrioSystemActive
							local remainingAmount = amountToDistribute
							local totalFreeCapacity = 0
							for n = 1, #prodPointsInDemand do
								--Production Revamp: Nur aktive Produktionen sollen beliefert werden, dafür werden die einzelnen Produktionslinien kontrolliert, ob sie nicht Inaktiv sind, Berechnung der Freien Kapazität
								local rproductions = prodPointsInDemand[n].productions
								local skip = true


								--Production Revamp: Weil PnH keine Prioritäten hat, Kontrollieren ob eine Prio vorhanden ist, sonst diese auf 10 setzen
								--Production Revamp: Weil PnH keine Zeiten hat, Kontrollieren ob Zeiten vorhanden sind, sonst diese setzen
								if prodPointsInDemand[n].inputFillTypeIdsPriority == nil then
									prodPointsInDemand[n].inputFillTypeIdsPriority = {}
								end
								if prodPointsInDemand[n].inputFillTypeIdsPriority[fillTypeIdToDistribute] == nil then
									prodPointsInDemand[n].inputFillTypeIdsPriority[fillTypeIdToDistribute] = 10
								end

								if prodPointsInDemand[n].hoursTable == nil then
									prodPointsInDemand[n].hoursTable = {}
									for i = 0, 24 do
										prodPointsInDemand[n].hoursTable[i] = true
									end
								end
								
								--Production Revamp: Belieferung ist nur Möglich, wenn die Produktion arbeitet.
								if prodPointsInDemand[n].hoursTable[currentHour] then
									skip = false
								end

								--Production Revamp: Jede Produktionslinie in jeder Produktion durchsuchen ob diese nicht INACTIVE ist
								if not skip then
									local running = false
									for g = 1, #rproductions do
										local lproductions = rproductions[g]
										--Production Revamp: Nur dann Verteilen wenn auch die Produktionslinie selber aktiv ist und nicht nur Lagerplatz vorhanden
										if rproductions[g].status ~= ProductionPoint.PROD_STATUS.INACTIVE and distributingProdPoint.id~= lproductions.id then
											for u = 1, #lproductions.inputs do
												local input = lproductions.inputs[u]
												if input.type == fillTypeIdToDistribute then
													running = true
												end
											end
										end
									end

									if (prodPointsInDemand[n].inputFillTypeIdsPriority[fillTypeIdToDistribute] == priority or ignorePriority) and running then
										totalFreeCapacity = totalFreeCapacity + prodPointsInDemand[n].storage:getFreeCapacity(fillTypeIdToDistribute, true)
									end
								end
							end

							if totalFreeCapacity > 0 then
								for n = 1, #prodPointsInDemand do
									local prodPointInDemand = prodPointsInDemand[n]
									local maxAmountToReceive = prodPointInDemand.storage:getFreeCapacity(fillTypeIdToDistribute, true)
									local skip = true

									--Production Revamp: Produktionen können nur innerhalb der Arbeitszeit Waren versenden. Außerhalb der Arbeitszeit wird die Schleife der jeweiligen Produktion beendet.
									if prodPointsInDemand[n].hoursTable[currentHour] then
										skip = false
									end

									if not skip and maxAmountToReceive > 0 then
										--Production Revamp: Nur aktive Produktionen sollen beliefert werden, dafür werden die einzelnen Produktionslinien kontrolliert, ob sie nicht Inaktiv sind, Verteilen auf die Lager
										local rproductions = prodPointsInDemand[n].productions
										local running = false
										for g = 1, #rproductions do
											local lproductions = rproductions[g]
											if rproductions[g].status ~= ProductionPoint.PROD_STATUS.INACTIVE and distributingProdPoint.id~= lproductions.id then
												for u = 1, #lproductions.inputs do
													local input = lproductions.inputs[u]
													if input.type == fillTypeIdToDistribute then
														running = true
													end
												end
											end
										end

										if (prodPointsInDemand[n].inputFillTypeIdsPriority[fillTypeIdToDistribute] == priority or ignorePriority) and running then
											local amountToTransfer = math.min(maxAmountToReceive, amountToDistribute * maxAmountToReceive / totalFreeCapacity)
											remainingAmount = remainingAmount - amountToTransfer
											local distanceSourceToTarget = calcDistanceFrom(distributingProdPoint.owningPlaceable.rootNode, prodPointInDemand.owningPlaceable.rootNode)

											local RevampFactor = 0
											if RevampSettings.current.DistributionCostFactor > 0.1 then
												RevampFactor = ProductionPoint.DIRECT_DELIVERY_PRICE * RevampSettings.current.DistributionCostFactor
											end
											local transferCosts = amountToTransfer * distanceSourceToTarget * RevampFactor

											--Production Revamp: Verteilen kostet Geld, es bringt keins...
											g_currentMission:addMoney(-transferCosts, prodPointInDemand.ownerFarmId, MoneyType.PRODUCTION_DELIVER_COSTS, true)
											prodPointInDemand.storage:setFillLevel(prodPointInDemand.storage:getFillLevel(fillTypeIdToDistribute) + amountToTransfer, fillTypeIdToDistribute)
											distributingProdPoint.storage:setFillLevel(distributingProdPoint.storage:getFillLevel(fillTypeIdToDistribute) - amountToTransfer, fillTypeIdToDistribute)
										end
									end
								end
							end

							if remainingAmount > 0 then
								priority = priority + 1
								if priority < 11 and not ignorePriority then
									distributePriority(priority, remainingAmount, prodPointsInDemand, fillTypeIdToDistribute, distributingProdPoint)
								end
							end
						end

						--Production Revamp: Aufruf Verteilern für Priority 1
						distributePriority(1, amountToDistribute, prodPointsInDemand, fillTypeIdToDistribute, distributingProdPoint)
					end
				end
			end
		end
	end
end

ProductionChainManager.distributeGoods = Utils.overwrittenFunction(ProductionChainManager.distributeGoods, RevampPriority.distributeGoods)



--Production Revamp: Hinzugefügt um Input-Priorität auslesen zu können
function ProductionPoint:getInputPriority(inputFillTypeId)
	--Production Revamp: weil PnH keine Prioritäten hat, Kontrollieren ob eine Prio vorhanden ist, sonst diese auf 10 setzen:
	if self.inputFillTypeIdsPriority == nil then
		self.inputFillTypeIdsPriority = {}
	end
	if self.inputFillTypeIdsPriority[inputFillTypeId] == nil then
		self.inputFillTypeIdsPriority[inputFillTypeId] = 10
	end
	return self.inputFillTypeIdsPriority[inputFillTypeId]
end



--Production Revamp: Toggle-Function um Input-Priority zu ändern
function ProductionPoint:toggleInputPriority(fillType)
	if self.inputFillTypeIds[fillType] ~= nil then
		local curPriority = self:getInputPriority(fillType)
		if curPriority == 10 then
			curPriority = 0
		else
			curPriority = curPriority + 1
		end

		self:setInputPriority(fillType, curPriority)
	end
end



--Production Revamp: Callback für die Input-Priorität zu ändern
function InGameMenuProductionFrame:priorityCallback()
	local production, productionPoint = self:getSelectedProduction()
	local fillType = self:getSelectedStorageFillType()

	if fillType ~= FillType.UNKNOWN then
		productionPoint:toggleInputPriority(fillType)
		self.storageList:reloadData()
	end
end



--Production Revamp: MenüButten für Input-Priorität hinzugefügt
function RevampPriority:updateMenuButtons(superFunc)
	local isProductionListActive = self.productionList == FocusManager:getFocusedElement()
	local fillType, isInput = self:getSelectedStorageFillType()

	-- Pump'n'Hoses Produktionen ignorieren
	local _, productionPoint = self:getSelectedProduction()
	if productionPoint:isa(SandboxProductionPoint) or (productionPoint.owningPlaceable.isSandboxPlaceable ~= nil and productionPoint.owningPlaceable:isSandboxPlaceable()) then
		return
	end
 
	if not isProductionListActive and fillType ~= FillType.UNKNOWN and isInput and RevampSettings.current.PrioSystemActive then
		table.insert(self.menuButtonInfo, {
			profile = "buttonOk",
			inputAction = InputAction.MENU_ACCEPT,
			text = self.i18n:getText("Revamp_ChangePriority"),
			callback = function()
				self:priorityCallback()
			end
		})
		self:setMenuButtonInfoDirty()
	end
end

InGameMenuProductionFrame.updateMenuButtons = Utils.appendedFunction(InGameMenuProductionFrame.updateMenuButtons, RevampPriority.updateMenuButtons)



--Production Revamp: Hinzugefügt um Input-Prioritäten zu ändern
function ProductionPoint:setInputPriority(inputFillTypeId, priority, noEventSend)
	if self.inputFillTypeIds[inputFillTypeId] == nil then
		printf("Production Revamp: Error: setInputPriority(): fillType '%s' is not an input fillType", g_fillTypeManager:getFillTypeNameByIndex(inputFillTypeId))

		return
	end

	priority = tonumber(priority)

	if priority > 10 then
		printf("Production Revamp: Error: setInputPriority(): Priority '%s' is not supported", priority)

		return
	else
		self.inputFillTypeIdsPriority[inputFillTypeId] = priority
	end

	ProductionPointPriorityEvent.sendEvent(self, inputFillTypeId, priority, noEventSend)
end