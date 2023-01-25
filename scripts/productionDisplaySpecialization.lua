--[[
Copyright (C) Achimobil, Braeven 2022

Author: Achimobil, Braeven
Date: 18.10.2022
Version: 0.2.0.0

Contact:
https://forum.giants-software.com
https://discord.gg/Va7JNnEkcW (Achimobil) 
https://discord.gg/gHmnFZAypk (Revamp)

History:
0.1.0.0 @ 01.06.2022 - First Version.
0.1.0.1 @ 06.06.2022 - Changed display clipdistance from 300 to 500(Braeven)
0.2.0.0 @ 18.10.2022 - Wechselnde Schriftfarbe abhängig vom Füllstand ermöglicht(Braeven)

Important:
It is not allowed to copy in own Mods. Only usage as reference with Production Revamp.
No changes are to be made to this script without permission from Achimobil or braeven.

Darf nicht in eigene Mods kopiert werden. Darf nur über den Production Revamp Mod benutzt werden.
An diesem Skript dürfen ohne Genehmigung von Achimobil oder braeven keine Änderungen vorgenommen werden.
]]

ProductionDisplaySpecialization = {
    Version = "0.2.0.0",
    Name = "ProductionDisplaySpecialization"
}
print(g_currentModName .. " - init " .. ProductionDisplaySpecialization.Name .. "(Version: " .. ProductionDisplaySpecialization.Version .. ")");

function ProductionDisplaySpecialization.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(PlaceableProductionPoint, specializations);
end

function ProductionDisplaySpecialization.registerEventListeners(placeableType)
	SpecializationUtil.registerEventListener(placeableType, "onLoad", ProductionDisplaySpecialization);
	SpecializationUtil.registerEventListener(placeableType, "onFinalizePlacement", ProductionDisplaySpecialization);
	SpecializationUtil.registerEventListener(placeableType, "onPostFinalizePlacement", ProductionDisplaySpecialization);
end

function ProductionDisplaySpecialization.registerFunctions(placeableType)
	SpecializationUtil.registerFunction(placeableType, "updateDisplays", ProductionDisplaySpecialization.updateDisplays);
end

function ProductionDisplaySpecialization.registerXMLPaths(schema, basePath)
	schema:setXMLSpecializationType("ProductionDisplay");

	schema:register(XMLValueType.NODE_INDEX, basePath .. ".productionPoint.productionDisplays.productionDisplay(?)#node", "Display start node");
	schema:register(XMLValueType.STRING, basePath .. ".productionPoint.productionDisplays.productionDisplay(?)#font", "Display font name");
	schema:register(XMLValueType.STRING, basePath .. ".productionPoint.productionDisplays.productionDisplay(?)#alignment", "Display text alignment");
	schema:register(XMLValueType.FLOAT, basePath .. ".productionPoint.productionDisplays.productionDisplay(?)#size", "Display text size");
	schema:register(XMLValueType.FLOAT, basePath .. ".productionPoint.productionDisplays.productionDisplay(?)#scaleX", "Display text x scale");
	schema:register(XMLValueType.FLOAT, basePath .. ".productionPoint.productionDisplays.productionDisplay(?)#scaleY", "Display text y scale");
	schema:register(XMLValueType.STRING, basePath .. ".productionPoint.productionDisplays.productionDisplay(?)#mask", "Display text mask");
	schema:register(XMLValueType.FLOAT, basePath .. ".productionPoint.productionDisplays.productionDisplay(?)#emissiveScale", "Display emissive scale");
	schema:register(XMLValueType.COLOR, basePath .. ".productionPoint.productionDisplays.productionDisplay(?)#color", "Display text color");
	schema:register(XMLValueType.COLOR, basePath .. ".productionPoint.productionDisplays.productionDisplay(?)#hiddenColor", "Display text hidden color");
	schema:register(XMLValueType.STRING, basePath .. ".productionPoint.productionDisplays.productionDisplay(?)#fillType", "Filltype name for the Display to show amount");
  schema:register(XMLValueType.COLOR, basePath .. ".productionPoint.productionDisplays.productionDisplay(?).colorChange(?)#color", "Display text color");
  schema:register(XMLValueType.FLOAT, basePath .. ".productionPoint.productionDisplays.productionDisplay(?).colorChange(?)#amount", "Amount when a color-change should happen");
	schema:setXMLSpecializationType();
end

function ProductionDisplaySpecialization:onLoad(savegame)
  self.spec_productionPointDisplay = {};
	local spec = self.spec_productionPointDisplay;
	local xmlFile = self.xmlFile;

	spec.productionDisplays = {};
	local i = 0;

	while true do
		local productionPointDisplayKey = string.format("placeable.productionPoint.productionDisplays.productionDisplay(%d)", i);

		if not xmlFile:hasProperty(productionPointDisplayKey) then
			break;
		end

		local displayNode = self.xmlFile:getValue(productionPointDisplayKey .. "#node", nil, self.components, self.i3dMappings);
    local fontName = self.xmlFile:getValue(productionPointDisplayKey .. "#font", "DIGIT"):upper();
    local fontMaterial = g_materialManager:getFontMaterial(fontName, self.customEnvironment);

    local display = {};

    local alignmentStr = self.xmlFile:getValue(productionPointDisplayKey .. "#alignment", "RIGHT");
    local alignment = RenderText["ALIGN_" .. alignmentStr:upper()] or RenderText.ALIGN_RIGHT;
    local size = self.xmlFile:getValue(productionPointDisplayKey .. "#size", 0.13);
    local scaleX = self.xmlFile:getValue(productionPointDisplayKey .. "#scaleX", 1);
    local scaleY = self.xmlFile:getValue(productionPointDisplayKey .. "#scaleY", 1);
    local mask = self.xmlFile:getValue(productionPointDisplayKey .. "#mask", "000000");
    local emissiveScale = self.xmlFile:getValue(productionPointDisplayKey .. "#emissiveScale", 0.2);
    local color = self.xmlFile:getValue(productionPointDisplayKey .. "#color", {0.9, 0.9, 0.9, 1}, true);
    local hiddenColor = self.xmlFile:getValue(productionPointDisplayKey .. "#hiddenColor", nil, true);
    display.displayNode = displayNode;
    display.formatStr, display.formatPrecision = string.maskToFormat(mask);
    display.fontMaterial = fontMaterial;
    display.characterLine = fontMaterial:createCharacterLine(display.displayNode, mask:len(), size, color, hiddenColor, emissiveScale, scaleX, scaleY, alignment);
    
    local fillTypeName = xmlFile:getValue(productionPointDisplayKey .. "#fillType");
    display.fillTypeId = g_fillTypeManager:getFillTypeIndexByName(fillTypeName);

    --Grundfarbe hinterlegen
    display.colorChange = {};
    display.changer = false
    local base = {}
    base.amount = 0
    base.color = color
    table.insert(display.colorChange, base)
    
    --Farben auslesen
    self.xmlFile:iterate(productionPointDisplayKey .. ".colorChange", function (index, colorKey)
      display.changer = true

      local change = {}
      change.color = self.xmlFile:getValue(colorKey .. "#color", {0.6662, 0.3839, 0.5481, 1}, true);
      change.amount = self.xmlFile:getValue(colorKey .. "#amount", 1);
      table.insert(display.colorChange, change);
    end)
    table.insert(spec.productionDisplays, display);

		i = i + 1;
	end
    
	function spec.fillLevelChangedCallback(fillType, delta)
        self:updateDisplays();
	end
end

function ProductionDisplaySpecialization:onFinalizePlacement(savegame)
	local spec = self.spec_productionPointDisplay;
    self.spec_productionPoint.productionPoint.storage:addFillLevelChangedListeners(spec.fillLevelChangedCallback);
end

function ProductionDisplaySpecialization:onPostFinalizePlacement(savegame)
    self:updateDisplays();
end

function ProductionDisplaySpecialization:updateDisplays()
	local spec = self.spec_productionPointDisplay;
	local farmId = self:getOwnerFarmId();

	for _, display in pairs(spec.productionDisplays) do
		local fillLevel = self.spec_productionPoint.productionPoint.storage:getFillLevel(display.fillTypeId);
		local int, floatPart = math.modf(fillLevel);
		local value = string.format(display.formatStr, int, math.abs(math.floor(floatPart * 10^display.formatPrecision)))

    if display.changer then
      local before = 0

      for i = 1, #display.colorChange do
        if display.colorChange[i].amount <= fillLevel and before <= display.colorChange[i].amount then
          display.characterLine.textColor = display.colorChange[i].color
          before = display.colorChange[i].amount
        end
      end
    end
    
		display.fontMaterial:updateCharacterLine(display.characterLine, value);

    for i = 1, #display.characterLine.characters do
      local charNode = display.characterLine.characters[i]
      setClipDistance(charNode, 500)
      
      if display.changer then
        local color1 = display.characterLine.textColor[1]
        local color2 = display.characterLine.textColor[2]
        local color3 = display.characterLine.textColor[3]
        
        display.fontMaterial:setFontCharacterColor(charNode, color1, color2, color3)
      end
    end
	end
end