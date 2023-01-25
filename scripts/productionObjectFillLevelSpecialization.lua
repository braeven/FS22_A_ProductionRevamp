--[[
Copyright (C) Achimobil, 2022

Author: Achimobil
Date: 01.06.2022
Version: 0.1.1.0

Contact:
https://forum.giants-software.com
https://discord.gg/Va7JNnEkcW (Achimobil) 
https://discord.gg/gHmnFZAypk (Revamp)

History:
0.1.0.0 @ 14.05.2022 - First Version
0.1.1.0 @ 01.06.2022 - Change Name and output on init


Important:
It is not allowed to copy in own Mods. Only usage as reference with Production Revamp.
No changes are to be made to this script without permission from Achimobil or braeven.

Darf nicht in eigene Mods kopiert werden. Darf nur über den Production Revamp Mod benutzt werden.
An diesem Skript dürfen ohne Genehmigung von Achimobil oder braeven keine Änderungen vorgenommen werden.
]]

ProductionObjectFillLevelSpecialization = {
    Version = "0.1.1.0",
    Name = "ProductionObjectFillLevelSpecialization"
}

print(g_currentModName .. " - init " .. ProductionObjectFillLevelSpecialization.Name .. "(Version: " .. ProductionObjectFillLevelSpecialization.Version .. ")");

function ProductionObjectFillLevelSpecialization.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(PlaceableProductionPoint, specializations);
end

function ProductionObjectFillLevelSpecialization.registerEventListeners(placeableType)
	SpecializationUtil.registerEventListener(placeableType, "onLoad", ProductionObjectFillLevelSpecialization);
	SpecializationUtil.registerEventListener(placeableType, "onFinalizePlacement", ProductionObjectFillLevelSpecialization);
	SpecializationUtil.registerEventListener(placeableType, "onPostFinalizePlacement", ProductionObjectFillLevelSpecialization);
end

function ProductionObjectFillLevelSpecialization.registerFunctions(placeableType)
	SpecializationUtil.registerFunction(placeableType, "updateObjectFillLevels", ProductionObjectFillLevelSpecialization.updateObjectFillLevels);
end

function ProductionObjectFillLevelSpecialization.registerXMLPaths(schema, basePath)
	schema:setXMLSpecializationType("ProductionObjectFillLevelSpecialization");
    
	schema:register(XMLValueType.NODE_INDEX, basePath .. ".productionPoint.productionObjectFillLevels.productionObjectFillLevel(?)#rootNode", "Root Node, all directChilds are taken from as filltype");
	schema:register(XMLValueType.STRING, basePath .. ".productionPoint.productionObjectFillLevels.productionObjectFillLevel(?)#fillType", "Filltype name for the Display to show amount");
	schema:register(XMLValueType.STRING, basePath .. ".productionPoint.productionObjectFillLevels.productionObjectFillLevel(?)#maxAtFillLevel", "This fill level is showing all childs");
	schema:register(XMLValueType.STRING, basePath .. ".productionPoint.productionObjectFillLevels.productionObjectFillLevel(?)#firstAtFillLevel", "This fill level is needed to show the first child", 1);
	schema:register(XMLValueType.STRING, basePath .. ".productionPoint.productionObjectFillLevels.productionObjectFillLevel(?)#invert", "When true the objects hide/show will be inverted", false);
	schema:register(XMLValueType.STRING, basePath .. ".productionPoint.productionObjectFillLevels#useSubNodesInsteadOfMainNodes", "True for using the second level of subnodes instead of the first level", false);
    
	schema:setXMLSpecializationType();
end

function ProductionObjectFillLevelSpecialization:onLoad(savegame)
    self.spec_productionObjectFillLevel = {};
	local spec = self.spec_productionObjectFillLevel;
	local xmlFile = self.xmlFile;
    spec.UseSubNodesInsteadOfMainNodes = self.xmlFile:getBool("placeable.productionPoint.productionObjectFillLevels#useSubNodesInsteadOfMainNodes", false);

	spec.productionObjectFillLevels = {};
	local i = 0;

	while true do
		local productionObjectFillLevelKey = string.format("placeable.productionPoint.productionObjectFillLevels.productionObjectFillLevel(%d)", i);

		if not xmlFile:hasProperty(productionObjectFillLevelKey) then
			break;
		end
        
        local productionObjectFillLevel = {};
        
		local rootNode = self.xmlFile:getValue(productionObjectFillLevelKey .. "#rootNode", nil, self.components, self.i3dMappings);
        productionObjectFillLevel.rootNode = rootNode;
        
        -- get childs
		local numChildren = getNumOfChildren(rootNode)

        productionObjectFillLevel.ChildNodeIds = {};
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
        
        local fillTypeName = xmlFile:getValue(productionObjectFillLevelKey .. "#fillType");
        productionObjectFillLevel.fillTypeId = g_fillTypeManager:getFillTypeIndexByName(fillTypeName);
        productionObjectFillLevel.maxAtFillLevel = xmlFile:getInt(productionObjectFillLevelKey .. "#maxAtFillLevel");
        productionObjectFillLevel.firstAtFillLevel = xmlFile:getInt(productionObjectFillLevelKey .. "#firstAtFillLevel", -1);
        if productionObjectFillLevel.firstAtFillLevel == -1 then
            -- nicht angegeben vom Modder, also wie vorher maximalmenge geteilt durch nodes
            productionObjectFillLevel.firstAtFillLevel = productionObjectFillLevel.maxAtFillLevel / #productionObjectFillLevel.ChildNodeIds;
        end
        productionObjectFillLevel.invert = xmlFile:getBool(productionObjectFillLevelKey .. "#invert", false);
        productionObjectFillLevel.fillLevelStep = (productionObjectFillLevel.maxAtFillLevel - productionObjectFillLevel.firstAtFillLevel) / math.max(#productionObjectFillLevel.ChildNodeIds - 1, 1);
        
        table.insert(spec.productionObjectFillLevels, productionObjectFillLevel);

		i = i + 1;
	end
    
	function spec.fillLevelChangedCallback(fillType, delta)
        self:updateObjectFillLevels();
	end    
end

function ProductionObjectFillLevelSpecialization:onFinalizePlacement(savegame)
	local spec = self.spec_productionObjectFillLevel;
    self.spec_productionPoint.productionPoint.storage:addFillLevelChangedListeners(spec.fillLevelChangedCallback);
end

function ProductionObjectFillLevelSpecialization:onPostFinalizePlacement(savegame)
    self:updateObjectFillLevels();
end

function ProductionObjectFillLevelSpecialization:updateObjectFillLevels()
	local spec = self.spec_productionObjectFillLevel;
	local farmId = self:getOwnerFarmId();
    
	for _, productionObjectFillLevel in pairs(spec.productionObjectFillLevels) do
		local fillLevel = self.spec_productionPoint.productionPoint.storage:getFillLevel(productionObjectFillLevel.fillTypeId);
        
        --  hier bestimmen, was alles sichtbar oder unsichtbar sein soll
        local visibleMaxIndex = 0;
        
        if fillLevel >= productionObjectFillLevel.firstAtFillLevel then
            visibleMaxIndex = 1;
        end
        -- add one per fillLevelStep
        if fillLevel > productionObjectFillLevel.firstAtFillLevel then
            visibleMaxIndex = visibleMaxIndex + math.floor((fillLevel - productionObjectFillLevel.firstAtFillLevel) / productionObjectFillLevel.fillLevelStep)
        end
        
        local visibleValueShow = true;
        local visibleValueNoShow = false;
        local collisionValueShow = 1001002;
        local collisionValueNoShow = 0;
        
        if productionObjectFillLevel.invert then
            -- inverting is just the flip the used values
            visibleValueShow = false;
            visibleValueNoShow = true;
            collisionValueShow = 0;
            collisionValueNoShow = 1001002;
        end
        
        for childIndex, childNodeId in pairs(productionObjectFillLevel.ChildNodeIds) do
            if childIndex <= visibleMaxIndex then
                setVisibility(childNodeId, visibleValueShow);
                setCollisionMask(childNodeId, collisionValueShow)
                
                local numChildren = getNumOfChildren(childNodeId)
                for i = 0, numChildren - 1 do
                    setCollisionMask(getChildAt(childNodeId, i), collisionValueShow)
                end
            else
                setVisibility(childNodeId, visibleValueNoShow);
                setCollisionMask(childNodeId, collisionValueNoShow)
                
                local numChildren = getNumOfChildren(childNodeId)
                for i = 0, numChildren - 1 do
                    setCollisionMask(getChildAt(childNodeId, i), collisionValueNoShow)
                end
            end
        end
        
	end
end