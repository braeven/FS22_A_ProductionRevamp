--[[
Copyright (C) Achimobil, 2023

Author: Achimobil
Date: 16.06.2023
Version: 0.2.0.0

Contact:
https://forum.giants-software.com
https://discord.gg/Va7JNnEkcW (Achimobil) 
https://discord.gg/gHmnFZAypk (Revamp)

History:
0.1.0.0 @ 14.05.2022 - First Version
0.1.1.0 @ 01.06.2022 - Change Name and output on init
0.1.1.1 @ 19.12.2022 - Code Cleanup
0.2.0.0 @ 16.06.2023 - Verzögerte Anzeige für performance verbesserung


Important:
It is not allowed to copy in own Mods. Only usage as reference with Production Revamp.
No changes are to be made to this script without permission from Achimobil or braeven.

Darf nicht in eigene Mods kopiert werden. Darf nur über den Production Revamp Mod benutzt werden.
An diesem Skript dürfen ohne Genehmigung von Achimobil oder braeven keine Änderungen vorgenommen werden.
]]

ProductionObjectFillLevelSpecialization = {
	Version = "0.2.0.0",
	Name = "ProductionObjectFillLevelSpecialization"
}

function ProductionObjectFillLevelSpecialization.prerequisitesPresent(specializations)
	return SpecializationUtil.hasSpecialization(PlaceableProductionPoint, specializations)
end

function ProductionObjectFillLevelSpecialization.registerEventListeners(placeableType)
	SpecializationUtil.registerEventListener(placeableType, "onLoad", ProductionObjectFillLevelSpecialization)
	SpecializationUtil.registerEventListener(placeableType, "onFinalizePlacement", ProductionObjectFillLevelSpecialization)
	SpecializationUtil.registerEventListener(placeableType, "onPostFinalizePlacement", ProductionObjectFillLevelSpecialization)
	SpecializationUtil.registerEventListener(placeableType, "onUpdate", ProductionObjectFillLevelSpecialization)
end

function ProductionObjectFillLevelSpecialization.registerFunctions(placeableType)
	SpecializationUtil.registerFunction(placeableType, "updateObjectFillLevels", ProductionObjectFillLevelSpecialization.updateObjectFillLevels)
	SpecializationUtil.registerFunction(placeableType, "setProductionObjectFillLevelDirty", ProductionObjectFillLevelSpecialization.setProductionObjectFillLevelDirty)
end

function ProductionObjectFillLevelSpecialization.registerXMLPaths(schema, basePath)
	schema:setXMLSpecializationType("ProductionObjectFillLevelSpecialization")

	schema:register(XMLValueType.NODE_INDEX, basePath .. ".productionPoint.productionObjectFillLevels.productionObjectFillLevel(?)#rootNode", "Root Node, all directChilds are taken from as filltype")
	schema:register(XMLValueType.STRING, basePath .. ".productionPoint.productionObjectFillLevels.productionObjectFillLevel(?)#fillType", "Defines the fill type name used for showing objects")
	schema:register(XMLValueType.STRING, basePath .. ".productionPoint.productionObjectFillLevels.productionObjectFillLevel(?)#fillTypes", "Defines the fill type names used for showing objects")
	schema:register(XMLValueType.STRING, basePath .. ".productionPoint.productionObjectFillLevels.productionObjectFillLevel(?)#fillTypeCategories", "Defines the fill type categories used for showing objects")
	schema:register(XMLValueType.STRING, basePath .. ".productionPoint.productionObjectFillLevels.productionObjectFillLevel(?)#maxAtFillLevel", "This fill level is showing all childs")
	schema:register(XMLValueType.STRING, basePath .. ".productionPoint.productionObjectFillLevels.productionObjectFillLevel(?)#firstAtFillLevel", "This fill level is needed to show the first child", 1)
	schema:register(XMLValueType.STRING, basePath .. ".productionPoint.productionObjectFillLevels.productionObjectFillLevel(?)#invert", "When true the objects hide/show will be inverted", false)
	schema:register(XMLValueType.STRING, basePath .. ".productionPoint.productionObjectFillLevels#useSubNodesInsteadOfMainNodes", "True for using the second level of subnodes instead of the first level", false)

	schema:setXMLSpecializationType()
end

function ProductionObjectFillLevelSpecialization:onLoad(savegame)
	self.spec_productionObjectFillLevel = {}
	local spec = self.spec_productionObjectFillLevel
	local xmlFile = self.xmlFile
	spec.UseSubNodesInsteadOfMainNodes = self.xmlFile:getBool("placeable.productionPoint.productionObjectFillLevels#useSubNodesInsteadOfMainNodes", false)

	spec.productionObjectFillLevels = {}
	spec.productionObjectFillLevelDirty = true;
	spec.lastUpdateTime = 0;
	local i = 0

	while true do
		local productionObjectFillLevelKey = string.format("placeable.productionPoint.productionObjectFillLevels.productionObjectFillLevel(%d)", i)

		if not xmlFile:hasProperty(productionObjectFillLevelKey) then
			break
		end

		local productionObjectFillLevel = {}
		productionObjectFillLevel.fillTypes = {}

		local rootNode = self.xmlFile:getValue(productionObjectFillLevelKey .. "#rootNode", nil, self.components, self.i3dMappings)
		productionObjectFillLevel.rootNode = rootNode

		-- get childs
		local numChildren = getNumOfChildren(rootNode)

		productionObjectFillLevel.ChildNodeIds = {}
		for i = 0, numChildren - 1 do
			if not spec.UseSubNodesInsteadOfMainNodes then
				table.insert(productionObjectFillLevel.ChildNodeIds, getChildAt(rootNode, i))
			else
				local childNodeId = getChildAt(rootNode, i)
				local numChildrenInner = getNumOfChildren(childNodeId)
				for j = 0, numChildrenInner - 1 do
					table.insert(productionObjectFillLevel.ChildNodeIds, getChildAt(childNodeId, j))
				end
			end
		end
		
		local fillTypeNameXml = xmlFile:getValue(productionObjectFillLevelKey .. "#fillType")
		local fillTypeNames = xmlFile:getValue(productionObjectFillLevelKey .. "#fillTypes")
		local fillTypeCategories = xmlFile:getValue(productionObjectFillLevelKey .. "#fillTypeCategories")
		
		if fillTypeNameXml ~= nil and fillTypeNames ~= nil then
			Logging.xmlWarning(xmlFile, "fillType and fillTypes are both set, only one of the two allowed")
		end
		
		if fillTypeNames == nil then
			fillTypeNames = fillTypeNameXml;
		end
		
		if fillTypeNames ~= nil then
			local fillTypeNameList = fillTypeNames:split(" ")
			for _, fillTypeName in ipairs(fillTypeNameList) do
				local fillTypeIndex = g_fillTypeManager:getFillTypeIndexByName(fillTypeName);
				if fillTypeIndex ~= nil then
					productionObjectFillLevel.fillTypes[fillTypeIndex] = true;
				end
			end
		end
		
		if fillTypeCategories ~= nil then
			local fillTypes = g_fillTypeManager:getFillTypesByCategoryNames(fillTypeCategories, "Warning: ProductionObjectFillLevel has invalid fillTypeCategory '%s'.")

			for _, fillType in pairs(fillTypes) do
				productionObjectFillLevel.fillTypes[fillType] = true
			end
		end
		
		productionObjectFillLevel.maxAtFillLevel = xmlFile:getInt(productionObjectFillLevelKey .. "#maxAtFillLevel")
		productionObjectFillLevel.firstAtFillLevel = xmlFile:getInt(productionObjectFillLevelKey .. "#firstAtFillLevel", -1)
		if productionObjectFillLevel.firstAtFillLevel == -1 then
			-- nicht angegeben vom Modder, also wie vorher maximalmenge geteilt durch nodes
			productionObjectFillLevel.firstAtFillLevel = productionObjectFillLevel.maxAtFillLevel / #productionObjectFillLevel.ChildNodeIds
		end
		productionObjectFillLevel.invert = xmlFile:getBool(productionObjectFillLevelKey .. "#invert", false)
		productionObjectFillLevel.fillLevelStep = (productionObjectFillLevel.maxAtFillLevel - productionObjectFillLevel.firstAtFillLevel) / math.max(#productionObjectFillLevel.ChildNodeIds - 1, 1)

		table.insert(spec.productionObjectFillLevels, productionObjectFillLevel)

		i = i + 1
	end

	function spec.fillLevelChangedCallback(fillType, delta)
		self:setProductionObjectFillLevelDirty()
	end
end

function ProductionObjectFillLevelSpecialization:onFinalizePlacement(savegame)
	local spec = self.spec_productionObjectFillLevel
	self.spec_productionPoint.productionPoint.storage:addFillLevelChangedListeners(spec.fillLevelChangedCallback)
end

function ProductionObjectFillLevelSpecialization:onPostFinalizePlacement(savegame)
	self:updateObjectFillLevels()
end

function ProductionObjectFillLevelSpecialization:setProductionObjectFillLevelDirty()
	local spec = self.spec_productionObjectFillLevel;
	if not spec.productionObjectFillLevelDirty then 
		spec.productionObjectFillLevelDirty = true 
	end
	self:raiseActive()
end

function ProductionObjectFillLevelSpecialization:onUpdate(dt)
	local spec = self.spec_productionObjectFillLevel;
	if not spec.productionObjectFillLevelDirty then
		return
	end;
	spec.lastUpdateTime = spec.lastUpdateTime + dt
	if spec.lastUpdateTime < 5000 then
		self:raiseActive()
		return
	end;
	
	self:updateObjectFillLevels()
	
	spec.lastUpdateTime = 0
	spec.productionObjectFillLevelDirty = false;
	
end

function ProductionObjectFillLevelSpecialization:updateObjectFillLevels()
	local spec = self.spec_productionObjectFillLevel
	local farmId = self:getOwnerFarmId()

	for _, productionObjectFillLevel in pairs(spec.productionObjectFillLevels) do
		local fillLevel = 0;
		
		for fillTypeIndex, _ in pairs(productionObjectFillLevel.fillTypes) do
			fillLevel = fillLevel + self.spec_productionPoint.productionPoint.storage:getFillLevel(fillTypeIndex);
		end

		-- hier bestimmen, was alles sichtbar oder unsichtbar sein soll
		local visibleMaxIndex = 0

		if fillLevel >= productionObjectFillLevel.firstAtFillLevel then
			visibleMaxIndex = 1
		end
		-- add one per fillLevelStep
		if fillLevel > productionObjectFillLevel.firstAtFillLevel then
			visibleMaxIndex = visibleMaxIndex + math.floor((fillLevel - productionObjectFillLevel.firstAtFillLevel) / productionObjectFillLevel.fillLevelStep)
		end

		local visibleValueShow = true
		local visibleValueNoShow = false
		local collisionValueShow = 1001002
		local collisionValueNoShow = 0

		if productionObjectFillLevel.invert then
			-- inverting is just the flip the used values
			visibleValueShow = false
			visibleValueNoShow = true
			collisionValueShow = 0
			collisionValueNoShow = 1001002
		end

		for childIndex, childNodeId in pairs(productionObjectFillLevel.ChildNodeIds) do
			if childIndex <= visibleMaxIndex then
				setVisibility(childNodeId, visibleValueShow)
				setCollisionMask(childNodeId, collisionValueShow)

				local numChildren = getNumOfChildren(childNodeId)
				for i = 0, numChildren - 1 do
					setCollisionMask(getChildAt(childNodeId, i), collisionValueShow)
				end
			else
				setVisibility(childNodeId, visibleValueNoShow)
				setCollisionMask(childNodeId, collisionValueNoShow)

				local numChildren = getNumOfChildren(childNodeId)
				for i = 0, numChildren - 1 do
					setCollisionMask(getChildAt(childNodeId, i), collisionValueNoShow)
				end
			end
		end
	end
end