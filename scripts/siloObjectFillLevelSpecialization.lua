--[[
Copyright (C) Achimobil, 2022

Author: Achimobil
Date: 01.06.2022
Version: 0.3.3.0

Contact:
https://forum.giants-software.com
https://discord.gg/Va7JNnEkcW (Achimobil) 
https://discord.gg/gHmnFZAypk (Revamp)

History:
V 0.1.0.0 @ 24.04.2022 - First Version.
V 0.2.0.0 @ 02.05.2022 - Added simple CollisionMash Change on Visible Change
V 0.3.0.0 @ 03.05.2022 - Added useSubNodesInsteadOfMainNodes
V 0.3.1.0 @ 07.05.2022 - Fix Collision when subnodes are used
V 0.3.2.0 @ 10.05.2022 - Add Version and Name for main.lua
V 0.3.3.0 @ 01.06.2022 - Change Name and output on init

Important:
It is not allowed to copy in own Mods. Only usage as reference with Production Revamp.
No changes are to be made to this script without permission from Achimobil or braeven.

Darf nicht in eigene Mods kopiert werden. Darf nur über den Production Revamp Mod benutzt werden.
An diesem Skript dürfen ohne Genehmigung von Achimobil oder braeven keine Änderungen vorgenommen werden.
]]

SiloObjectFillLevelSpecialization = {
    Version = "0.3.2.0",
    Name = "SiloObjectFillLevelSpecialization"
}
print(g_currentModName .. " - init " .. SiloObjectFillLevelSpecialization.Name .. "(Version: " .. SiloObjectFillLevelSpecialization.Version .. ")");

function SiloObjectFillLevelSpecialization.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(PlaceableSilo, specializations);
end

function SiloObjectFillLevelSpecialization.registerEventListeners(placeableType)
	SpecializationUtil.registerEventListener(placeableType, "onLoad", SiloObjectFillLevelSpecialization);
	SpecializationUtil.registerEventListener(placeableType, "onFinalizePlacement", SiloObjectFillLevelSpecialization);
	SpecializationUtil.registerEventListener(placeableType, "onPostFinalizePlacement", SiloObjectFillLevelSpecialization);
end

function SiloObjectFillLevelSpecialization.registerFunctions(placeableType)
	SpecializationUtil.registerFunction(placeableType, "updateObjectFillLevels", SiloObjectFillLevelSpecialization.updateObjectFillLevels);
end

function SiloObjectFillLevelSpecialization.registerXMLPaths(schema, basePath)
	schema:setXMLSpecializationType("SiloDisplay");
    
	schema:register(XMLValueType.NODE_INDEX, basePath .. ".silo.siloObjectFillLevels.siloObjectFillLevel(?)#rootNode", "Root Node, all directChilds are taken from as filltype");
	schema:register(XMLValueType.STRING, basePath .. ".silo.siloObjectFillLevels.siloObjectFillLevel(?)#fillType", "Filltype name for the Display to show amount");
	schema:register(XMLValueType.STRING, basePath .. ".silo.siloObjectFillLevels.siloObjectFillLevel(?)#maxAtFillLevel", "this fill level is showing all childs");
	schema:register(XMLValueType.STRING, basePath .. ".silo.siloObjectFillLevels.siloObjectFillLevel(?)#firstAtFillLevel", "This fill level is needed to show the first child", 1);
	schema:register(XMLValueType.STRING, basePath .. ".silo.siloObjectFillLevels.siloObjectFillLevel(?)#invert", "When true the objects hide/show will be inverted", false);
	schema:register(XMLValueType.STRING, basePath .. ".silo.siloObjectFillLevels#useSubNodesInsteadOfMainNodes", "true for using the second level of subnodes instead of the first level", false);
    
	schema:setXMLSpecializationType();
end

function SiloObjectFillLevelSpecialization:onLoad(savegame)
    self.spec_siloObjectFillLevel = {};
	local spec = self.spec_siloObjectFillLevel;
	local xmlFile = self.xmlFile;
    spec.UseSubNodesInsteadOfMainNodes = self.xmlFile:getBool("placeable.silo.siloObjectFillLevels#useSubNodesInsteadOfMainNodes", false);

	spec.siloObjectFillLevels = {};
	local i = 0;

	while true do
		local siloObjectFillLevelKey = string.format("placeable.silo.siloObjectFillLevels.siloObjectFillLevel(%d)", i);

		if not xmlFile:hasProperty(siloObjectFillLevelKey) then
			break;
		end
        
        local siloObjectFillLevel = {};
        
		local rootNode = self.xmlFile:getValue(siloObjectFillLevelKey .. "#rootNode", nil, self.components, self.i3dMappings);
        siloObjectFillLevel.rootNode = rootNode;
        
        -- get childs
		local numChildren = getNumOfChildren(rootNode)

        siloObjectFillLevel.ChildNodeIds = {};
		for i = 0, numChildren - 1 do
            if not spec.UseSubNodesInsteadOfMainNodes then
                table.insert(siloObjectFillLevel.ChildNodeIds, getChildAt(rootNode, i))
            else
                local childNodeId = getChildAt(rootNode, i)
                local numChildrenInner = getNumOfChildren(childNodeId)
                for j = 0, numChildrenInner - 1 do
                    table.insert(siloObjectFillLevel.ChildNodeIds, getChildAt(childNodeId, j))
                end        
            end
		end        
        
        local fillTypeName = xmlFile:getValue(siloObjectFillLevelKey .. "#fillType");
        siloObjectFillLevel.fillTypeId = g_fillTypeManager:getFillTypeIndexByName(fillTypeName);
        siloObjectFillLevel.maxAtFillLevel = xmlFile:getInt(siloObjectFillLevelKey .. "#maxAtFillLevel");
        siloObjectFillLevel.firstAtFillLevel = xmlFile:getInt(siloObjectFillLevelKey .. "#firstAtFillLevel", -1);
        if siloObjectFillLevel.firstAtFillLevel == -1 then
            -- nicht angegeben vom Modder, also wie vorher maximalmenge geteilt durch nodes
            siloObjectFillLevel.firstAtFillLevel = siloObjectFillLevel.maxAtFillLevel / #siloObjectFillLevel.ChildNodeIds;
        end
        siloObjectFillLevel.invert = xmlFile:getBool(siloObjectFillLevelKey .. "#invert", false);
        siloObjectFillLevel.fillLevelStep = (siloObjectFillLevel.maxAtFillLevel - siloObjectFillLevel.firstAtFillLevel) / math.max(#siloObjectFillLevel.ChildNodeIds -1, 1);
        
        table.insert(spec.siloObjectFillLevels, siloObjectFillLevel);

		i = i + 1;
	end
    
	function spec.fillLevelChangedCallback(fillType, delta)
        self:updateObjectFillLevels();
	end    
end

function SiloObjectFillLevelSpecialization:onFinalizePlacement(savegame)
	local spec = self.spec_siloObjectFillLevel;
	for _, sourceStorage in pairs(self.spec_silo.loadingStation:getSourceStorages()) do
        sourceStorage:addFillLevelChangedListeners(spec.fillLevelChangedCallback);
    end
end

function SiloObjectFillLevelSpecialization:onPostFinalizePlacement(savegame)
    self:updateObjectFillLevels();
end


function SiloObjectFillLevelSpecialization:updateObjectFillLevels()
	local spec = self.spec_siloObjectFillLevel;
	local farmId = self:getOwnerFarmId();
    
	for _, siloObjectFillLevel in pairs(spec.siloObjectFillLevels) do
		local fillLevel = self.spec_silo.loadingStation:getFillLevel(siloObjectFillLevel.fillTypeId, farmId);
        
        --  hier bestimmen, was alles sichtbar oder unsichtbar sein soll
        local visibleMaxIndex = 0;
        
        if fillLevel >= siloObjectFillLevel.firstAtFillLevel then
            visibleMaxIndex = 1;
        end
        -- add one per fillLevelStep
        if fillLevel > siloObjectFillLevel.firstAtFillLevel then
            visibleMaxIndex = visibleMaxIndex + math.floor((fillLevel - siloObjectFillLevel.firstAtFillLevel) / siloObjectFillLevel.fillLevelStep)
        end
        
        local visibleValueShow = true;
        local visibleValueNoShow = false;
        local collisionValueShow = 1001002;
        local collisionValueNoShow = 0;
        
        if siloObjectFillLevel.invert then
            -- inverting is just the flip the used values
            visibleValueShow = false;
            visibleValueNoShow = true;
            collisionValueShow = 0;
            collisionValueNoShow = 1001002;
        end
        
        for childIndex, childNodeId in pairs(siloObjectFillLevel.ChildNodeIds) do
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