--[[
Production Revamp
Extented functuality ccripts

Copyright (C) Achimobil, braeven, 2022

Date: 24.10.2022
Version: 1.0.0.0

Contact/Help/Tutorials:
discord.gg/gHmnFZAypk

Changelog:
1.0.0.0 @ 24.10.2022 - Moved out from main script file

Important:.
No changes are allowed to this script without permission from Achimobil AND Braeven.
If you want to make a production with this script, look in the discord channels for tutorials/help or download the FS22_Revamp_Productions Pack for reference
Don't copy the script into a production, load the mod as a dependency!

Es dürfen an diesem Script keine Veränderungen ohne Erlaubnis von Achimobil UND Braeven gemacht werden.
Wenn du eine Produktion mit diesem Script bauen möchtest, lese dir die angepinnten Tutorials im Discord durch oder guck dir die FS22_Revamp_Productions an.
Nicht das Script in Produktionen kopieren, ladet den Mod über eine Dependency!

]]

--Production Revamp: Zusätzliche XML-Schema für zusätzliche Funktionen
function Revamp:AddXmlSchema()
  Revamp.XmlSchema = XMLSchema.new("revamp")
  local schema = Revamp.XmlSchema
  schema:register(XMLValueType.STRING, "modDesc.revamp.sellFillType(?)", "Revamp SellPointScript", nil, false)
  schema:register(XMLValueType.STRING, "modDesc.revamp.sellFillType(?)#fillType", "Revamp SellPointScript: Name of the newfillType", nil, false)
  schema:register(XMLValueType.STRING, "modDesc.revamp.sellFillType(?)#base", "Revamp SellPointScript: Name of the baseFillType for registering the new fillType", nil, false)
  schema:register(XMLValueType.STRING, "modDesc.revamp.sellFillType(?)#forceRegister", "Revamp SellPointScript: Force registering of the new Filltype", nil, false)
  schema:register(XMLValueType.STRING, "modDesc.revamp.storeItems.storeItem(?)#xmlFilename", "Revamp storeItemScript: XML File to load load store item", nil, false)
  schema:register(XMLValueType.STRING, "modDesc.revamp.storeItems.storeItem(?)#addWhenfillTypes", "Revamp storeItemScript: Store Item only available when all entered filltypes are available", nil, false)
  schema:register(XMLValueType.STRING, "modDesc.revamp.storeItems.storeItem(?)#removeWhenFillTypes", "Revamp storeItemScript: Store Item only available when none of these filltypes are available", nil, false)
  schema:register(XMLValueType.STRING, "modDesc.storeItems.storeItem(?)#removeWhenFillTypes", "Revamp storeItemScript: Store Item will not be available when one of the fillTypes is available. Use WHEAT to remove when Revamp is available", nil, false)
end



--Production Revamp: Filltypes zur Sellingstation & Unloadingstation hinzuzufügen, wenn BaseFillType bereits vorhanden ist, ausgenommen Produktionen. FillTypes werden in der Revamp.SellFillTypes von anderen Mods hinterlegt.
function Revamp:AddSellingStationFilltype()
  if #Revamp.SellFillTypes > 0 then
    for x = 1, #Revamp.SellFillTypes do
      local SellFillType = Revamp.SellFillTypes[x]
      if SellFillType.fillType~=nil then
        local fillTypeIndex = g_fillTypeManager:getFillTypeIndexByName(SellFillType.fillType)
        local baseFillTypeIndex = g_fillTypeManager:getFillTypeIndexByName(SellFillType.base)
        local fillType = g_fillTypeManager:getFillTypeByIndex(fillTypeIndex)
        local baseFillType = g_fillTypeManager:getFillTypeByIndex(baseFillTypeIndex)
        local price = fillType.pricePerLiter
        local insert = ""
        local foundone = false
        local allreadyadded = false
        if SellFillType.forceRegister == false or SellFillType.forceRegister==nil then
          for _, station in pairs(g_currentMission.storageSystem:getUnloadingStations()) do
            if station.isSellingPoint and not station.hideFromPricesMenu and not station.storeSoldGoods then
              if station.acceptedFillTypes[fillTypeIndex] == true then
                allreadyadded = true
              end
            end
          end
        end
        if allreadyadded==false then
          for _, station in pairs(g_currentMission.storageSystem:getUnloadingStations()) do
            if station.isSellingPoint and not station.hideFromPricesMenu and not station.storeSoldGoods then
              if station.acceptedFillTypes[baseFillTypeIndex] == true then
                station:addAcceptedFillType(fillTypeIndex, price, false, false)
                station:initPricingDynamics()

                foundone = true
                --Production Revamp: Bei mehreren UnloadTriggern nur in die richtigen Eintragen
                for _, unload in pairs(station.unloadTriggers) do
                  if unload.fillTypes[baseFillTypeIndex] then
                    unload.fillTypes[fillTypeIndex] = true
                  end
                end
                if insert == "" then
                  insert = station.uiName
                else
                  insert = insert ..", ".. station.uiName
                end
              end
            end
          end
          if foundone==true then
            if SellFillType.forceRegister == false then
              print("Production Revamp: Added Filltype " ..fillType.title.. " into Sellingstations " ..insert.. " for FillType " ..baseFillType.title.. ". (Mod: " ..SellFillType.modName.. ")")
            else
              print("Production Revamp: Added Filltype " ..fillType.title.. " into Sellingstations " ..insert.. " for FillType " ..baseFillType.title.. ". (forced by Mod: " ..SellFillType.modName.. ")")
            end
          else
            if SellFillType.forceRegister == false then
              print("Production Revamp: Could not add " ..fillType.title.. " into Sellingstations, no compatible Sellingstation was found (Mod: " ..SellFillType.modName.. ")")
            else
              print("Production Revamp: Could not add " ..fillType.title.. " into Sellingstations, no compatible Sellingstation was found (forced by Mod: " ..SellFillType.modName.. ")")
            end
          end
        else
          print("Production Revamp: Skipped Adding Filltype " ..fillType.title.. " into Sellingstations for FillType " ..baseFillType.title.. ". FillType allready has Sellingstations (Mod: " ..SellFillType.modName.. ")")
        end
      end
    end
  end
end



--Production Revamp: Entfernen der geladenen storeItems denen die benötigten filltype fehlen. Liste wird durch die revamp_check.lua der mods gefüllt
function Revamp:RemoveNotAvailableStoreItems()
	local removedStoreItems = {};
	local hasRemovedStoreItems = false;
	for _, fillTypeDependentStoreItem in pairs(Revamp.RemoveByFillTypeStoreItems) do
		-- Entfernen, was zum entfernen definiert ist
		if fillTypeDependentStoreItem.removeWhenFillTypeNames ~= nil then
			local fillTypes = g_fillTypeManager:getFillTypesByNames(fillTypeDependentStoreItem.removeWhenFillTypeNames)
			local fillTypeNumber = #string.split(names, " ") + 1;
			if #fillTypes ~= 0 then
				for i = #g_storeManager.items, 1, -1 do
					local storeItem = g_storeManager.items[i];
					if storeItem.customEnvironment == fillTypeDependentStoreItem.customEnvironment and storeItem.rawXMLFilename == fillTypeDependentStoreItem.xmlFilename then
						g_storeManager:removeItemByIndex(i);
						if removedStoreItems[fillTypeDependentStoreItem.customEnvironment] == nil then
							removedStoreItems[fillTypeDependentStoreItem.customEnvironment] = fillTypeDependentStoreItem.xmlFilename;
						else
							removedStoreItems[fillTypeDependentStoreItem.customEnvironment] = removedStoreItems[fillTypeDependentStoreItem.customEnvironment] .. ", " .. fillTypeDependentStoreItem.xmlFilename;
						end
						hasRemovedStoreItems = true;
					end
				end
			end
		end
	end
	
	if hasRemovedStoreItems == true then
		print("Production Revamp: Removed store items because of missing needed filltypes")
		for modName, text in pairs(removedStoreItems) do
			print(" - " .. modName .. " - " .. text);
		end
	end
end

Mission00.onStartMission = Utils.appendedFunction(Mission00.onStartMission, Revamp.AddSellingStationFilltype)
Mission00.onStartMission = Utils.appendedFunction(Mission00.onStartMission, Revamp.RemoveNotAvailableStoreItems)



--Production Revamp: hinzufügen von store items in der revamp liste anhand der dortigen Bedingungen. Liste wird durch die revamp_check.lua der mods gefüllt
function Revamp:AddAdditionalStoreItems(xmlFilename, defaultXMLFilename)
	local addedStoreItems = {};
	local hasAddedStoreItems = false;
	local notAddedStoreItems = {};
	local hasNotAddedStoreItems = false;
	
	for _, fillTypeDependentStoreItem in pairs(Revamp.AddByFillTypeStoreItems) do
		-- einfügen, was die bedingungen erfüllt
		local addItem = false;
		
		-- alle fillTypes da?
		if fillTypeDependentStoreItem.addWhenFillTypeNames ~= nil then
			local fillTypes = g_fillTypeManager:getFillTypesByNames(fillTypeDependentStoreItem.addWhenFillTypeNames)
			local fillTypeNumber = #string.split(names, " ") + 1;
			if #fillTypes == fillTypeNumber then
				addItem = true;
			end
		end
		
		-- keine verbotenen fillTypes da?
		if fillTypeDependentStoreItem.removeWhenFillTypeNames ~= nil then
			local fillTypes = g_fillTypeManager:getFillTypesByNames(fillTypeDependentStoreItem.removeWhenFillTypeNames)
			if #fillTypes ~= 0 then
				addItem = false;
			end
		end
		
		if addItem then
			-- StoreManager:loadItem(rawXMLFilename, baseDir, customEnvironment, isMod, isBundleItem, dlcTitle, extraContentId, ignoreAdd)
			g_storeManager:loadItem(fillTypeDependentStoreItem.xmlFilename, fillTypeDependentStoreItem.baseDirectory, fillTypeDependentStoreItem.customEnvironment, true, false, "")
			if addedStoreItems[fillTypeDependentStoreItem.customEnvironment] == nil then
				addedStoreItems[fillTypeDependentStoreItem.customEnvironment] = fillTypeDependentStoreItem.xmlFilename;
			else
				addedStoreItems[fillTypeDependentStoreItem.customEnvironment] = addedStoreItems[fillTypeDependentStoreItem.customEnvironment] .. ", " .. fillTypeDependentStoreItem.xmlFilename;
			end
			hasAddedStoreItems = true;
		else
			if notAddedStoreItems[fillTypeDependentStoreItem.customEnvironment] == nil then
				notAddedStoreItems[fillTypeDependentStoreItem.customEnvironment] = fillTypeDependentStoreItem.xmlFilename;
			else
				notAddedStoreItems[fillTypeDependentStoreItem.customEnvironment] = notAddedStoreItems[fillTypeDependentStoreItem.customEnvironment] .. ", " .. fillTypeDependentStoreItem.xmlFilename;
			end
			hasNotAddedStoreItems = true;
		end
	end
	
	if hasAddedStoreItems == true then
		print("Production Revamp: Added store items because of matching filltypes requirements")
		for modName, text in pairs(addedStoreItems) do
			print(" - " .. modName .. " - " .. text);
		end
	end
	
	if hasNotAddedStoreItems == true then
		print("Production Revamp: Not added store items because of not matching filltypes requirements")
		for modName, text in pairs(notAddedStoreItems) do
			print(" - " .. modName .. " - " .. text);
		end
	end
end

Mission00.loadPlaceables = Utils.prependedFunction(Mission00.loadPlaceables, Revamp.AddAdditionalStoreItems)



--Production Revamp: loadMapData überschrieben, damit Revamp FillTypes geladen werden zum richtigen Zeitpunkt
function Revamp:loadMapDataFillTypeManager(superFunc, xmlFile, missionInfo, baseDirectory)
	FillTypeManager:superClass().loadMapData(self)
	self:loadDefaultTypes()

	if XMLUtil.loadDataFromMapXML(xmlFile, "fillTypes", baseDirectory, self, self.loadFillTypes, baseDirectory, false, missionInfo.customEnvironment) then
		for _, data in ipairs(self.modsToLoad) do
			local fillTypesXmlFile = XMLFile.load("fillTypes", data[1], FillTypeManager.xmlSchema)

			g_fillTypeManager:loadFillTypes(fillTypesXmlFile, data[2], false, data[3])
			fillTypesXmlFile:delete()
		end
		
		for _, data in ipairs(Revamp.FillTypeFilesToLoad) do
			local fillTypesXmlFile = XMLFile.load("fillTypes", data[1], FillTypeManager.xmlSchema)

			g_fillTypeManager:loadRevampFillTypes(fillTypesXmlFile, data[2], data[3])
			fillTypesXmlFile:delete()
		end

		self:constructFillTypeTextureArrays()

		return true
	end

	return false
end
FillTypeManager.loadMapData = Utils.overwrittenFunction(FillTypeManager.loadMapData, Revamp.loadMapDataFillTypeManager)



--Production Revamp: FillTypes abhängig von Bedingungen laden
function FillTypeManager:loadRevampFillTypes(xmlFile, baseDirectory, customEnv)
	if type(xmlFile) ~= "table" then
		xmlFile = XMLFile.wrap(xmlFile, FillTypeManager.xmlSchema)
	end

	xmlFile:iterate("map.fillTypes.fillType", function (_, key)
		local name = xmlFile:getValue(key .. "#name")
		local title = xmlFile:getValue(key .. "#title")
		local achievementName = xmlFile:getValue(key .. "#achievementName")
		local showOnPriceTable = xmlFile:getValue(key .. "#showOnPriceTable")
		local fillPlaneColors = xmlFile:getValue(key .. "#fillPlaneColors", "1.0 1.0 1.0", true)
		local unitShort = xmlFile:getValue(key .. "#unitShort", "")
		local kgPerLiter = xmlFile:getValue(key .. ".physics#massPerLiter")
		local massPerLiter = kgPerLiter and kgPerLiter / 1000
		local maxPhysicalSurfaceAngle = xmlFile:getValue(key .. ".physics#maxPhysicalSurfaceAngle")
		local hudFilename = xmlFile:getValue(key .. ".image#hud")
		local palletFilename = xmlFile:getValue(key .. ".pallet#filename")
		local pricePerLiter = xmlFile:getValue(key .. ".economy#pricePerLiter")
		local economicCurve = {}

		xmlFile:iterate(key .. ".economy.factors.factor", function (_, factorKey)
			local period = xmlFile:getValue(factorKey .. "#period")
			local factor = xmlFile:getValue(factorKey .. "#value")

			if period ~= nil and factor ~= nil then
				economicCurve[period] = factor
			end
		end)

		local diffuseMapFilename = xmlFile:getValue(key .. ".textures#diffuse")
		local normalMapFilename = xmlFile:getValue(key .. ".textures#normal")
		local specularMapFilename = xmlFile:getValue(key .. ".textures#specular")
		local distanceFilename = xmlFile:getValue(key .. ".textures#distance")
		local prioritizedEffectType = xmlFile:getValue(key .. ".effects#prioritizedEffectType") or "ShaderPlaneEffect"
		local fillSmokeColor = xmlFile:getValue(key .. ".effects#fillSmokeColor", nil, true)
		local fruitSmokeColor = xmlFile:getValue(key .. ".effects#fruitSmokeColor", nil, true)
		
		-- revamp injection to not override already given values
		local fillType = self.nameToFillType[name];
		if fillType ~= nil then
			if fillType.achievementName ~= nil then
				achievementName = fillType.achievementName;
			end
			if fillType.showOnPriceTable ~= nil then
				showOnPriceTable = fillType.showOnPriceTable;
			end
			if fillType.pricePerLiter ~= nil then
				pricePerLiter = fillType.pricePerLiter;
			end
			if fillType.massPerLiter ~= nil then
				massPerLiter = fillType.massPerLiter;
			end
			if fillType.maxPhysicalSurfaceAngle ~= nil then
				maxPhysicalSurfaceAngle = fillType.maxPhysicalSurfaceAngle;
			end
			if fillType.hudOverlayFilename ~= nil then
				hudOverlayFilename = fillType.hudOverlayFilename;
			end
			if fillType.diffuseMapFilename ~= nil then
				diffuseMapFilename = nil;
			end
			if fillType.normalMapFilename ~= nil then
				normalMapFilename = nil;
			end
			if fillType.specularMapFilename ~= nil then
				specularMapFilename = nil;
			end
			if fillType.distanceFilename ~= nil then
				distanceFilename = nil;
			end
			if fillType.palletFilename ~= nil then
				palletFilename = nil;
			end
			if fillType.fillPlaneColors ~= nil then
				fillPlaneColors = nil;
			end
			if fillType.prioritizedEffectType ~= nil then
				prioritizedEffectType = nil;
			end
			if fillType.fillSmokeColor ~= nil then
				fillSmokeColor = nil;
			end
			if fillType.fruitSmokeColor ~= nil then
				fruitSmokeColor = nil;
			end
		end

		self:addFillType(name, title, showOnPriceTable, pricePerLiter, massPerLiter, maxPhysicalSurfaceAngle, hudFilename, baseDirectory, customEnv, fillPlaneColors, unitShort, palletFilename, economicCurve, diffuseMapFilename, normalMapFilename, specularMapFilename, distanceFilename, prioritizedEffectType, fillSmokeColor, fruitSmokeColor, achievementName, false)
	end)
	xmlFile:iterate("map.fillTypeCategories.fillTypeCategory", function (_, key)
		local name = xmlFile:getValue(key .. "#name")
		local fillTypesStr = xmlFile:getValue(key) or ""
		local fillTypeCategoryIndex = self:addFillTypeCategory(name, false)

		if fillTypeCategoryIndex ~= nil then
			local fillTypeNames = fillTypesStr:split(" ")

			for _, fillTypeName in ipairs(fillTypeNames) do
				local fillType = self:getFillTypeByName(fillTypeName)

				if fillType ~= nil then
					if not self:addFillTypeToCategory(fillType.index, fillTypeCategoryIndex) then
						Logging.warning("Could not add fillType '" .. tostring(fillTypeName) .. "' to fillTypeCategory '" .. tostring(name) .. "'!")
					end
				else
					Logging.warning("Unknown FillType '" .. tostring(fillTypeName) .. "' in fillTypeCategory '" .. tostring(name) .. "'!")
				end
			end
		end
	end)
	xmlFile:iterate("map.fillTypeConverters.fillTypeConverter", function (_, key)
		local name = xmlFile:getValue(key .. "#name")
		local converter = self:addFillTypeConverter(name, false)

		if converter ~= nil then
			xmlFile:iterate(key .. ".converter", function (_, converterKey)
				local from = xmlFile:getValue(converterKey .. "#from")
				local to = xmlFile:getValue(converterKey .. "#to")
				local factor = xmlFile:getValue(converterKey .. "#factor")
				local sourceFillType = g_fillTypeManager:getFillTypeByName(from)
				local targetFillType = g_fillTypeManager:getFillTypeByName(to)

				if sourceFillType ~= nil and targetFillType ~= nil and factor ~= nil then
					self:addFillTypeConversion(converter, sourceFillType.index, targetFillType.index, factor)
				end
			end)
		end
	end)
	xmlFile:iterate("map.fillTypeSounds.fillTypeSound", function (_, key)
		local sample = g_soundManager:loadSampleFromXML(xmlFile, key, "sound", baseDirectory, getRootNode(), 0, AudioGroup.VEHICLE, nil, nil)

		if sample ~= nil then
			local entry = {
				sample = sample,
				fillTypes = {}
			}
			local fillTypesStr = xmlFile:getValue(key .. "#fillTypes") or ""

			if fillTypesStr ~= nil then
				local fillTypeNames = fillTypesStr:split(" ")

				for _, fillTypeName in ipairs(fillTypeNames) do
					local fillType = self:getFillTypeIndexByName(fillTypeName)

					if fillType ~= nil then
						table.insert(entry.fillTypes, fillType)

						self.fillTypeToSample[fillType] = sample
					else
						Logging.warning("Unable to load fill type '%s' for fillTypeSound '%s'", fillTypeName, key)
					end
				end
			end

			if xmlFile:getValue(key .. "#isDefault") then
				for fillType, _ in ipairs(self.fillTypes) do
					if self.fillTypeToSample[fillType] == nil then
						self.fillTypeToSample[fillType] = sample
					end
				end
			end

			table.insert(self.fillTypeSamples, entry)
		end
	end)

	return true
end


Revamp:AddXmlSchema()
print("Production Revamp: Added extendet functionalities")