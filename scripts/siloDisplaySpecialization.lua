--[[
Copyright (C) Achimobil & braeven, 2022

Author: Achimobil, Braeven
Date: 06.01.2023
Version: 1.0.0.0

Contact:
https://forum.giants-software.com
https://discord.gg/Va7JNnEkcW (Achimobil) 
https://discord.gg/gHmnFZAypk (Revamp)

History:
0.1.0.0 @ 24.04.2022 - First Version.
0.1.1.0 @ 16.05.2022 - Add Version and Name for main.lua
0.1.2.0 @ 01.06.2022 - Change Name and output on init
0.1.2.1 @ 06.06.2022 - Changed display clipdistance from 300 to 500(Braeven)
0.2.0.0 @ 18.10.2022 - Wechselnde Schriftfarbe abhängig vom Füllstand ermöglicht(Braeven)
0.2.0.1 @ 20.12.2022 - Code Cleanup
1.0.0.0 @ 06.01.2023 - Fehlenquellen abgefangen und Meldungen hinzugefügt
1.0.0.0 @ 06.01.2023 - ReverseMode added
1.0.0.0 @ 06.01.2023 - Prozentuale Angaben werden beim colorChange unterstützt


Important:
It is not allowed to copy in own Mods. Only usage as reference with Production Revamp.
No changes are to be made to this script without permission from Achimobil or braeven.

Darf nicht in eigene Mods kopiert werden. Darf nur über den Production Revamp Mod benutzt werden.
An diesem Skript dürfen ohne Genehmigung von Achimobil oder braeven keine Änderungen vorgenommen werden.
]]

SiloDisplaySpecialization = {
	Version = "1.0.0.0",
	Name = "SiloDisplaySpecialization"
}
print(g_currentModName .. " - init " .. SiloDisplaySpecialization.Name .. "(Version: " .. SiloDisplaySpecialization.Version .. ")")

function SiloDisplaySpecialization.prerequisitesPresent(specializations)
	return SpecializationUtil.hasSpecialization(PlaceableSilo, specializations)
end

function SiloDisplaySpecialization.registerEventListeners(placeableType)
	SpecializationUtil.registerEventListener(placeableType, "onLoad", SiloDisplaySpecialization)
	SpecializationUtil.registerEventListener(placeableType, "onFinalizePlacement", SiloDisplaySpecialization)
	SpecializationUtil.registerEventListener(placeableType, "onPostFinalizePlacement", SiloDisplaySpecialization)
end

function SiloDisplaySpecialization.registerFunctions(placeableType)
	SpecializationUtil.registerFunction(placeableType, "updateDisplays", SiloDisplaySpecialization.updateDisplays)
end

function SiloDisplaySpecialization.registerXMLPaths(schema, basePath)
	schema:setXMLSpecializationType("SiloDisplay")

	schema:register(XMLValueType.NODE_INDEX, basePath .. ".silo.siloDisplays.siloDisplay(?)#node", "Display start node")
	schema:register(XMLValueType.STRING, basePath .. ".silo.siloDisplays.siloDisplay(?)#font", "Display font name")
	schema:register(XMLValueType.STRING, basePath .. ".silo.siloDisplays.siloDisplay(?)#alignment", "Display text alignment")
	schema:register(XMLValueType.FLOAT, basePath .. ".silo.siloDisplays.siloDisplay(?)#size", "Display text size")
	schema:register(XMLValueType.FLOAT, basePath .. ".silo.siloDisplays.siloDisplay(?)#scaleX", "Display text x scale")
	schema:register(XMLValueType.FLOAT, basePath .. ".silo.siloDisplays.siloDisplay(?)#scaleY", "Display text y scale")
	schema:register(XMLValueType.STRING, basePath .. ".silo.siloDisplays.siloDisplay(?)#mask", "Display text mask")
	schema:register(XMLValueType.FLOAT, basePath .. ".silo.siloDisplays.siloDisplay(?)#emissiveScale", "Display emissive scale")
	schema:register(XMLValueType.COLOR, basePath .. ".silo.siloDisplays.siloDisplay(?)#color", "Display text color")
	schema:register(XMLValueType.COLOR, basePath .. ".silo.siloDisplays.siloDisplay(?)#hiddenColor", "Display text hidden color")
	schema:register(XMLValueType.BOOL, basePath .. ".silo.siloDisplays.siloDisplay(?)#reverse", "Sets Display in Reverse-mode")
	schema:register(XMLValueType.INT, basePath .. ".silo.siloDisplays.siloDisplay(?)#reverseAmount", "Sets amount for ReverseMode")
	schema:register(XMLValueType.STRING, basePath .. ".silo.siloDisplays.siloDisplay(?)#fillType", "Filltype name for the Display to show amount")
	schema:register(XMLValueType.COLOR, basePath .. ".silo.siloDisplays.siloDisplay(?).colorChange(?)#color", "Display text color")
	schema:register(XMLValueType.FLOAT, basePath .. ".silo.siloDisplays.siloDisplay(?).colorChange(?)#amount", "Amount when a color-change should happen")
end

function SiloDisplaySpecialization:onLoad(savegame)
	self.spec_siloDisplay = {}
	local spec = self.spec_siloDisplay
	local xmlFile = self.xmlFile
	
	spec.siloDisplays = {}

	local displayKey = "placeable.silo.siloDisplays"
	if xmlFile:hasProperty(displayKey) then

		xmlFile:iterate(displayKey.. ".siloDisplay", function (_, siloDisplayKey)
			local display = {}
			display.displayNode = xmlFile:getValue(siloDisplayKey .. "#node", nil, self.components, self.i3dMappings)
			if display.displayNode == nil then
				Logging.xmlError(xmlFile, "Production Revamp: siloDisplay: Node '%s' does not exist, Display will be skipped for silo '%s'.", display.displayNode, self:getName())
			else
				local fontName = xmlFile:getValue(siloDisplayKey .. "#font", "DIGIT"):upper()
				display.fontMaterial = g_materialManager:getFontMaterial(fontName, self.customEnvironment)

				if display.fontMaterial == nil then
					Logging.xmlError(xmlFile, "Production Revamp: siloDisplay: Font '%s' does not exist, Font set to 'DIGIT' for display at '%s', node '%s'.", fontName, self:getName(), display.displayNode)
					display.fontMaterial = g_materialManager:getFontMaterial("DIGIT", self.customEnvironment)
				end

				local fillTypeName = xmlFile:getValue(siloDisplayKey .. "#fillType")
				display.fillTypeId = g_fillTypeManager:getFillTypeIndexByName(fillTypeName)
				if display.fillTypeId == nil then
					Logging.xmlError(xmlFile, "Production Revamp: siloDisplay: FillType '%s' does not exist for display at '%s', Node '%s'. Display was skipped.", fillTypeName, self:getName(), display.displayNode)
				else

					local alignmentStr = xmlFile:getValue(siloDisplayKey .. "#alignment", "RIGHT")
					local alignment = RenderText["ALIGN_" .. alignmentStr:upper()] or RenderText.ALIGN_RIGHT
					local size = xmlFile:getFloat(siloDisplayKey .. "#size", 0.13)
					local scaleX = xmlFile:getFloat(siloDisplayKey .. "#scaleX", 1)
					local scaleY = xmlFile:getFloat(siloDisplayKey .. "#scaleY", 1)
					local mask = xmlFile:getValue(siloDisplayKey .. "#mask", "000000")
					local emissiveScale = xmlFile:getFloat(siloDisplayKey .. "#emissiveScale", 0.2)
					local color = xmlFile:getValue(siloDisplayKey .. "#color", {0.9, 0.9, 0.9, 1}, true)
					local hiddenColor = xmlFile:getValue(siloDisplayKey .. "#hiddenColor", nil, true)

					display.formatStr, display.formatPrecision = string.maskToFormat(mask)
					display.characterLine = display.fontMaterial:createCharacterLine(display.displayNode, mask:len(), size, color, hiddenColor, emissiveScale, scaleX, scaleY, alignment)

					display.reverse = xmlFile:getBool(siloDisplayKey .. "#reverse", false)
					if display.reverse == true then
						display.reverseAmount = xmlFile:getInt(siloDisplayKey .. "#reverseAmount", 0)
						if display.reverseAmount <= 0 then
							Logging.xmlError(xmlFile, "Production Revamp: siloDisplay: No valid reverseMaxAmount was given for FillType '%s' at '%s', Node '%s'. ReverseMode deactivated.", fillTypeName, self:getName(), display.displayNode)
							display.reverse = false
						end
					end

					--Farben auslesen
					display.changer = false
					if xmlFile:hasProperty(siloDisplayKey .. ".colorChange") then
						--Grundfarbe hinterlegen
						display.colorChange = {}
						local base = {}
						base.amount = 0
						base.color = color
						table.insert(display.colorChange, base)
						
						local capacity = 0
						--Für Prozentuale Angaben, Capacity auslesen
						for storageId, storage in ipairs(self.spec_silo.storages) do
							 capacity = storage.capacities[display.fillTypeId] or storage.capacity
						end

						xmlFile:iterate(siloDisplayKey .. ".colorChange", function (index, colorKey)
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

					table.insert(spec.siloDisplays, display)
				end
			end
		end)

		function spec.fillLevelChangedCallback(fillType, delta)
			self:updateDisplays()
		end
	end
end

function SiloDisplaySpecialization:onFinalizePlacement(savegame)
	local spec = self.spec_siloDisplay
	for _, sourceStorage in pairs(self.spec_silo.loadingStation:getSourceStorages()) do
		sourceStorage:addFillLevelChangedListeners(spec.fillLevelChangedCallback)
	end
end

function SiloDisplaySpecialization:onPostFinalizePlacement(savegame)
	self:updateDisplays()
end

function SiloDisplaySpecialization:updateDisplays()
	local spec = self.spec_siloDisplay
	local farmId = self:getOwnerFarmId()

	for _, display in pairs(spec.siloDisplays) do
		local fillLevel = self.spec_silo.loadingStation:getFillLevel(display.fillTypeId, farmId)
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