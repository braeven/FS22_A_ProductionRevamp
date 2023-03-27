--[[
Production Revamp
Animal Station

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
RevampAnimalStation = {
	MOD_DIRECTORY = g_currentModDirectory}
RevampAnimalStation.debug = false;
local RevampAnimalStation_mt = Class(RevampAnimalStation)

InitObjectClass(RevampAnimalStation, "RevampAnimalStation")

function RevampAnimalStation.print(text, ...)
	if RevampAnimalStation.debug then
		local text = string.format("RevampAnimalStation DEBUG: %s", string.format(text, ...));
		if text ~= RevampAnimalStation.lastDebugText then
			RevampAnimalStation.lastDebugText = text;
			print(text);
		end
	end
end

function RevampAnimalStation.new(isServer, isClient)
	RevampAnimalStation.print("new")
	local self = Object.new(isServer, isClient, RevampAnimalStation_mt)
	self.customEnvironment = g_currentMission.loadingMapModName
	self.innerNodes = {}
	self.isEnabled = false
	self.activatedTarget = nil

	return self
end

function RevampAnimalStation:load(productionPoint)
	RevampAnimalStation.print("load")
	self.productionPoint = productionPoint

	for triggerId, triggerIndex in pairs(self.productionPoint.animalTriggerToIndex) do
		local animalDefinition = self.productionPoint.animalTriggers[triggerId];
		local innerNode = {}
		innerNode.triggerIndex = triggerIndex;
		innerNode.triggerId = triggerId;
		innerNode.activatable = RevampAnimalLoadingTriggerActivatable.new(self, triggerId);
		innerNode.animalDefinition = animalDefinition;
		innerNode.loadingVehicle = nil;

		table.insert(self.innerNodes, innerNode);

		addTrigger(innerNode.triggerId, "triggerCallback", self)
	end

	if #self.innerNodes == 0 then
		return false
	end

	self.isEnabled = true

	return true
end

function RevampAnimalStation:delete()
	RevampAnimalStation.print("delete")

	if self.innerNodes ~= nil then
		for _, innerNode in pairs(self.innerNodes) do
			removeTrigger(innerNode.triggerId)
			g_currentMission.activatableObjectsSystem:removeActivatable(innerNode.activatable)
		end

		self.innerNodes = nil
	end
end

function RevampAnimalStation:getInnerNode(triggerIndex)
	RevampAnimalStation.print("getInnerNode - %s", triggerIndex)
	for _, innerNode in pairs(self.innerNodes) do
		if innerNode.triggerIndex == triggerIndex then
			return innerNode
		end
	end

	return nil
end

function RevampAnimalStation:triggerCallback(triggerId, otherId, onEnter, onLeave, onStay)
	RevampAnimalStation.print("triggerCallback - %s,%s,%s,%s,%s", triggerId, otherId, onEnter, onLeave, onStay)
	if self.isEnabled and (onEnter or onLeave) then
		local vehicle = g_currentMission.nodeToObject[otherId]
		
		if vehicle ~= nil and vehicle.getSupportsAnimalType ~= nil then
			local triggerIndex = self.productionPoint.animalTriggerToIndex[triggerId];
			local innerNode = self:getInnerNode(triggerIndex)
			if innerNode ~= nil then
				if onEnter then
					self:setLoadingTrailer(innerNode, vehicle)
				elseif onLeave then
					if vehicle == innerNode.loadingVehicle then
						self:setLoadingTrailer(innerNode, nil)
					end
				end
			end
		end
	end
end

function RevampAnimalStation:setLoadingTrailer(innerNode, loadingVehicle)
	RevampAnimalStation.print("setLoadingTrailer - %s,%s", innerNode, loadingVehicle)

	if innerNode ~= nil then
		if innerNode.loadingVehicle ~= nil and innerNode.loadingVehicle.setLoadingTrigger ~= nil then
			innerNode.loadingVehicle:setLoadingTrigger(nil)
			g_currentMission.activatableObjectsSystem:removeActivatable(innerNode.activatable)
		end

		innerNode.loadingVehicle = loadingVehicle

		if innerNode.loadingVehicle ~= nil and innerNode.loadingVehicle.setLoadingTrigger ~= nil then
			innerNode.loadingVehicle:setLoadingTrigger(self)
			g_currentMission.activatableObjectsSystem:addActivatable(innerNode.activatable)
		end
	end
end

function RevampAnimalStation:openAnimalMenu(triggerId)
	self:showAnimalScreen(triggerId)

	self.activatedTarget = self.loadingVehicle
end

function RevampAnimalStation:showAnimalScreen(triggerId)

	local triggerIndex = self.productionPoint.animalTriggerToIndex[triggerId];
	local innerNode = self:getInnerNode(triggerIndex)

	-- Liste erstellen was im Trailer ist zum anzeigen
	local itemsInTrailer = {}
	local clusters = innerNode.loadingVehicle:getClusters()

	if clusters ~= nil then
		for _, cluster in ipairs(clusters) do
			local item = {}
			item.cluster = cluster
			item.subType = g_currentMission.animalSystem:getSubTypeByIndex(cluster.subTypeIndex)
			local visual = g_currentMission.animalSystem:getVisualByAge(cluster.subTypeIndex, cluster.age)
			item.imageFilename = visual.store.imageFilename
			item.title = string.format("%s %s - %s - %s", item.cluster.numAnimals, visual.store.name, g_i18n:formatNumMonth(cluster.age), string.format("%d %%", cluster.health))
			item.maxAnimals, item.inputFillTypeForProduction, item.weightPerAnimal, item.calculationMessage = self.productionPoint:calculateAnimals(item.subType.name, cluster.health, cluster.age)
			item.maxAnimals = math.min(item.maxAnimals, item.cluster.numAnimals)
			item.accepted = RevampAnimalStation.MOD_DIRECTORY .."images/accepted.png"
			if item.calculationMessage ~= nil then
				if item.calculationMessage == "WrongAge" then
					local animal = self.productionPoint.animalTypes[item.subType.name]
					item.calculationMessageTranslated = string.format(g_i18n:getText("Revamp_animalAgeError"), animal.minAgeMonth, animal.maxAgeMonth)
					item.accepted = RevampAnimalStation.MOD_DIRECTORY .."images/notAccepted.png"
				elseif item.calculationMessage == "WrongHealth" then
					local animal = self.productionPoint.animalTypes[item.subType.name]
					item.calculationMessageTranslated = string.format(g_i18n:getText("Revamp_animalHealthError"), animal.minHealthFactor, animal.maxHealthFactor)
					item.accepted = RevampAnimalStation.MOD_DIRECTORY .."images/notAccepted.png"
				elseif item.calculationMessage == "WrongAnimal" then
					item.calculationMessageTranslated = g_i18n:getText("Revamp_animalNotValid")
				end
			end

			table.insert(itemsInTrailer, item)
		end
	end

	if #itemsInTrailer ~= 0 then
		ProductionAnimalDelivery.show(self.animalDeliveryCallback, self, itemsInTrailer, triggerId)
	end
end



function RevampAnimalStation:animalDeliveryCallback(triggerId, selectedIndex, quantity)
	RevampAnimalStation.print("animalDeliveryCallback - %s,%s,%s", triggerId, selectedIndex, quantity);
	local triggerIndex = self.productionPoint.animalTriggerToIndex[triggerId];
	RevampMoveAnimalsEvent.sendEvent(self.productionPoint, triggerIndex, selectedIndex, quantity);
end



function RevampAnimalStation:receiveAnimalDeliveryCallback(triggerIndex, selectedIndex, quantity)
	RevampAnimalStation.print("receiveAnimalDeliveryCallback - %s,%s,%s", triggerIndex, selectedIndex, quantity)
-- print("self")
-- DebugUtil.printTableRecursively(self, " ", 0, 2)

	if selectedIndex == nil then
		return
	end
	local innerNode = self:getInnerNode(triggerIndex)
	local clusters = innerNode.loadingVehicle:getClusters()
	local cluster = clusters[selectedIndex]
	local subType = g_currentMission.animalSystem:getSubTypeByIndex(cluster.subTypeIndex)

	local success = self.productionPoint:transportAnimals(subType.name, cluster.health, cluster.age, quantity)

	if success then 
		cluster:changeNumAnimals(-quantity)
		local clusterSystem = innerNode.loadingVehicle:getClusterSystem()
		clusterSystem:updateNow()
	end
end



RevampAnimalLoadingTriggerActivatable = {}
local RevampAnimalLoadingTriggerActivatable_mt = Class(RevampAnimalLoadingTriggerActivatable)

function RevampAnimalLoadingTriggerActivatable.new(revampAnimalStation, triggerId)
	local self = setmetatable({}, RevampAnimalLoadingTriggerActivatable_mt)
	self.owner = revampAnimalStation
	self.triggerId = triggerId
	self.activateText = g_i18n:getText("Revamp_transferAnimals", revampAnimalStation.customEnvironment)

	return self
end

function RevampAnimalLoadingTriggerActivatable:run()
	self.owner:openAnimalMenu(self.triggerId)
end

function RevampAnimalLoadingTriggerActivatable:getIsActivatable()
	local owner = self.owner

	if not owner.isEnabled then
		return false
	end

	if not g_currentMission:getHasPlayerPermission("tradeAnimals") then
		return false
	end

	local canAccess = owner.productionPoint == nil or owner.productionPoint:getOwnerFarmId() == g_currentMission:getFarmId()

	if not canAccess then
		return false
	end

	local rootAttacherVehicle = nil

	local triggerIndex = owner.productionPoint.animalTriggerToIndex[self.triggerId];
	local innerNode = owner:getInnerNode(triggerIndex)
	if innerNode.loadingVehicle ~= nil then
		rootAttacherVehicle = innerNode.loadingVehicle.rootVehicle
	end
	
	return rootAttacherVehicle == g_currentMission.controlledVehicle
end