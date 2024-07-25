--[[
Copyright (C) Achimobil, Braeven 2023

Author: Achimobil, Braeven
Date: 16.06.2023
Version: 1.1.0.0

Contact:
https://forum.giants-software.com
https://discord.gg/Va7JNnEkcW (Achimobil) 
https://discord.gg/gHmnFZAypk (Revamp)

History:
0.1.0.0 @ 01.06.2022 - First Version.
0.1.0.1 @ 06.06.2022 - Changed display clipdistance from 300 to 500(Braeven)
0.2.0.0 @ 18.10.2022 - Wechselnde Schriftfarbe abhängig vom Füllstand ermöglicht(Braeven)
0.2.0.1 @ 19.12.2022 - Code Cleanup
1.0.0.0 @ 06.01.2023 - Fehlenquellen abgefangen und Meldungen hinzugefügt
1.0.0.0 @ 06.01.2023 - ReverseMode added
1.0.0.0 @ 06.01.2023 - Prozentuale Angaben werden beim colorChange unterstützt
1.1.0.0 @ 16.06.2023 - Verzögerte Anzeige für performance verbesserung

Important:
It is not allowed to copy in own Mods. Only usage as reference with Production Revamp.
No changes are to be made to this script without permission from Achimobil or braeven.

Darf nicht in eigene Mods kopiert werden. Darf nur über den Production Revamp Mod benutzt werden.
An diesem Skript dürfen ohne Genehmigung von Achimobil oder braeven keine Änderungen vorgenommen werden.
]]

ProductionDisplaySpecialization = {
	Version = "1.1.0.0",
	Name = "ProductionDisplaySpecialization"
}

function ProductionDisplaySpecialization.prerequisitesPresent(specializations)
	return SpecializationUtil.hasSpecialization(PlaceableProductionPoint, specializations)
end

function ProductionDisplaySpecialization.registerEventListeners(placeableType)
	SpecializationUtil.registerEventListener(placeableType, "onLoad", ProductionDisplaySpecialization)
	SpecializationUtil.registerEventListener(placeableType, "onFinalizePlacement", ProductionDisplaySpecialization)
	SpecializationUtil.registerEventListener(placeableType, "onPostFinalizePlacement", ProductionDisplaySpecialization)
	SpecializationUtil.registerEventListener(placeableType, "onUpdate", ProductionDisplaySpecialization)
end

function ProductionDisplaySpecialization.registerFunctions(placeableType)
	SpecializationUtil.registerFunction(placeableType, "updateDisplays", ProductionDisplaySpecialization.updateDisplays)
	SpecializationUtil.registerFunction(placeableType, "setProductionDisplayFillLevelDirty", ProductionDisplaySpecialization.setProductionDisplayFillLevelDirty)
end

function ProductionDisplaySpecialization.registerXMLPaths(schema, basePath)
	schema:setXMLSpecializationType("ProductionDisplay")

	schema:register(XMLValueType.NODE_INDEX, basePath .. ".productionPoint.productionDisplays.productionDisplay(?)#node", "Display start node")
	schema:register(XMLValueType.STRING, basePath .. ".productionPoint.productionDisplays.productionDisplay(?)#font", "Display font name")
	schema:register(XMLValueType.STRING, basePath .. ".productionPoint.productionDisplays.productionDisplay(?)#alignment", "Display text alignment")
	schema:register(XMLValueType.FLOAT, basePath .. ".productionPoint.productionDisplays.productionDisplay(?)#size", "Display text size")
	schema:register(XMLValueType.FLOAT, basePath .. ".productionPoint.productionDisplays.productionDisplay(?)#scaleX", "Display text x scale")
	schema:register(XMLValueType.FLOAT, basePath .. ".productionPoint.productionDisplays.productionDisplay(?)#scaleY", "Display text y scale")
	schema:register(XMLValueType.STRING, basePath .. ".productionPoint.productionDisplays.productionDisplay(?)#mask", "Display text mask")
	schema:register(XMLValueType.FLOAT, basePath .. ".productionPoint.productionDisplays.productionDisplay(?)#emissiveScale", "Display emissive scale")
	schema:register(XMLValueType.COLOR, basePath .. ".productionPoint.productionDisplays.productionDisplay(?)#color", "Display text color")
	schema:register(XMLValueType.COLOR, basePath .. ".productionPoint.productionDisplays.productionDisplay(?)#hiddenColor", "Display text hidden color")
	schema:register(XMLValueType.BOOL, basePath .. ".productionPoint.productionDisplays.productionDisplay(?)#reverse", "Sets Display in Reverse-mode")
	schema:register(XMLValueType.INT, basePath .. ".productionPoint.productionDisplays.productionDisplay(?)#reverseAmount", "Sets amount for ReverseMode")
	schema:register(XMLValueType.STRING, basePath .. ".productionPoint.productionDisplays.productionDisplay(?)#fillType", "Filltype name for the Display to show amount")
	schema:register(XMLValueType.COLOR, basePath .. ".productionPoint.productionDisplays.productionDisplay(?).colorChange(?)#color", "Display text color")
	schema:register(XMLValueType.FLOAT, basePath .. ".productionPoint.productionDisplays.productionDisplay(?).colorChange(?)#amount", "Amount when a color-change should happen")
	schema:setXMLSpecializationType()
end

function ProductionDisplaySpecialization:onLoad(savegame)
	self.spec_productionPointDisplay = {}
	local spec = self.spec_productionPointDisplay
	local xmlFile = self.xmlFile
	
	spec.productionDisplays = {}
	spec.productionDisplayFillLevelDirty = true;
	spec.lastUpdateTime = 0;

	local displayKey = "placeable.productionPoint.productionDisplays"
	if xmlFile:hasProperty(displayKey) then

		xmlFile:iterate(displayKey.. ".productionDisplay", function (_, productionPointDisplayKey)
			local display = {}
			display.displayNode = xmlFile:getValue(productionPointDisplayKey .. "#node", nil, self.components, self.i3dMappings)
			if display.displayNode == nil then
				Logging.xmlError(xmlFile, "Production Revamp: productionDisplay: Node '%s' does not exist, Display will be skipped for production '%s'.", display.displayNode, self:getName())
			else
				local fontName = xmlFile:getValue(productionPointDisplayKey .. "#font", "DIGIT"):upper()
				display.fontMaterial = g_materialManager:getFontMaterial(fontName, self.customEnvironment)

				if display.fontMaterial == nil then
					Logging.xmlError(xmlFile, "Production Revamp: productionDisplay: Font '%s' does not exist, Font set to 'DIGIT' for display at '%s', node '%s'.", fontName, self:getName(), display.displayNode)
					display.fontMaterial = g_materialManager:getFontMaterial("DIGIT", self.customEnvironment)
				end

				local fillTypeName = xmlFile:getValue(productionPointDisplayKey .. "#fillType")
				display.fillTypeId = g_fillTypeManager:getFillTypeIndexByName(fillTypeName)
				if display.fillTypeId == nil then
					Logging.xmlError(xmlFile, "Production Revamp: productionDisplay: FillType '%s' does not exist for display at '%s', Node '%s'. Display was skipped.", fillTypeName, self:getName(), display.displayNode)
				else

					local alignmentStr = xmlFile:getValue(productionPointDisplayKey .. "#alignment", "RIGHT")
					local alignment = RenderText["ALIGN_" .. alignmentStr:upper()] or RenderText.ALIGN_RIGHT
					local size = xmlFile:getFloat(productionPointDisplayKey .. "#size", 0.13)
					local scaleX = xmlFile:getFloat(productionPointDisplayKey .. "#scaleX", 1)
					local scaleY = xmlFile:getFloat(productionPointDisplayKey .. "#scaleY", 1)
					local mask = xmlFile:getValue(productionPointDisplayKey .. "#mask", "000000")
					local emissiveScale = xmlFile:getFloat(productionPointDisplayKey .. "#emissiveScale", 0.2)
					local color = xmlFile:getValue(productionPointDisplayKey .. "#color", {0.9, 0.9, 0.9, 1}, true)
					local hiddenColor = xmlFile:getValue(productionPointDisplayKey .. "#hiddenColor", nil, true)

					display.formatStr, display.formatPrecision = string.maskToFormat(mask)
					display.characterLine = display.fontMaterial:createCharacterLine(display.displayNode, mask:len(), size, color, hiddenColor, emissiveScale, scaleX, scaleY, alignment)

					display.reverse = xmlFile:getBool(productionPointDisplayKey .. "#reverse", false)
					if display.reverse == true then
						display.reverseAmount = xmlFile:getInt(productionPointDisplayKey .. "#reverseAmount", 0)
						if display.reverseAmount <= 0 then
							Logging.xmlError(xmlFile, "Production Revamp: productionDisplay: No valid reverseMaxAmount was given for FillType '%s' at '%s', Node '%s'. ReverseMode deactivated.", fillTypeName, self:getName(), display.displayNode)
							display.reverse = false
						end
					end

					--Farben auslesen
					display.changer = false
					if xmlFile:hasProperty(productionPointDisplayKey .. ".colorChange") then
						--Grundfarbe hinterlegen
						display.colorChange = {}
						local base = {}
						base.amount = 0
						base.color = color
						table.insert(display.colorChange, base)

						--Für Prozentuale Angaben, Capacity auslesen
						local capacity = self.spec_productionPoint.productionPoint.storage.capacities[display.fillTypeId]
						
						xmlFile:iterate(productionPointDisplayKey .. ".colorChange", function (index, colorKey)
							local change = {}
							change.color = xmlFile:getValue(colorKey .. "#color", {0.6662, 0.3839, 0.5481, 1}, true)
							change.amount = xmlFile:getValue(colorKey .. "#amount", 1)

							--für Prozentuale Angaben, Umrechnen mit Capacity
							if change.amount < 1.1 then
								change.amount = math.floor(capacity * change.amount)
							end
							
							display.changer = true
							table.insert(display.colorChange, change)
						end)
					end

					table.insert(spec.productionDisplays, display)
				end
			end
		end)

		function spec.fillLevelChangedCallback(fillType, delta)
			self:setProductionDisplayFillLevelDirty()
		end
	end
end

function ProductionDisplaySpecialization:onFinalizePlacement(savegame)
	local spec = self.spec_productionPointDisplay
	self.spec_productionPoint.productionPoint.storage:addFillLevelChangedListeners(spec.fillLevelChangedCallback)
end

function ProductionDisplaySpecialization:onPostFinalizePlacement(savegame)
	self:updateDisplays()
end

function ProductionDisplaySpecialization:setProductionDisplayFillLevelDirty()
	local spec = self.spec_productionPointDisplay;
	if not spec.productionDisplayFillLevelDirty then 
		spec.productionDisplayFillLevelDirty = true 
	end
	self:raiseActive()
end

function ProductionDisplaySpecialization:onUpdate(dt)
	local spec = self.spec_productionPointDisplay;
	if not spec.productionDisplayFillLevelDirty then
		return
	end;
	spec.lastUpdateTime = spec.lastUpdateTime + dt
	if spec.lastUpdateTime < 1000 then
		self:raiseActive()
		return
	end;
	
	self:updateDisplays()
	
	spec.lastUpdateTime = 0
	spec.productionDisplayFillLevelDirty = false;
	
end

function ProductionDisplaySpecialization:updateDisplays()
	local spec = self.spec_productionPointDisplay
	local farmId = self:getOwnerFarmId()

	for _, display in pairs(spec.productionDisplays) do
		local fillLevel = self.spec_productionPoint.productionPoint.storage:getFillLevel(display.fillTypeId)
		if display.reverse then
			fillLevel = display.reverseAmount - fillLevel
			if fillLevel < 0 then
				fillLevel = 0
			end
		end
		local int, floatPart = math.modf(fillLevel)
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

		display.fontMaterial:updateCharacterLine(display.characterLine, value)

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