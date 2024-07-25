--[[
Production Revamp
Revamp Speciality Productions

Copyright (C) braeven, Achimobil, 2022

Author: braeven, Achimobil

Date: 05.06.2024
Version: 1.0.0.0

Contact/Help/Tutorials:
discord.gg/gHmnFZAypk


Changelog:
1.0.0.0 @ 05.06.2024 - Aus revamp.lua in eigene Datei ausgelagert.


Important:.
No changes are allowed to this script without permission from Braeven AND Achimobil.
If you want to make a production with this script, look in the documentation, discord channels for tutorials/help or download the FS22_Revamp_Productions Pack for reference
Don't copy the script into a production, load the mod as a dependency!

Es dürfen an diesem Script keine Veränderungen ohne Erlaubnis von Braeven UND Achimobil gemacht werden.
Wenn du eine Produktion mit diesem Script bauen möchtest, lese dir die Dokumentation, die angepinnten Tutorials im Discord durch oder guck dir die FS22_Revamp_Productions an.
Nicht das Script in Produktionen kopieren, ladet den Mod über eine Dependency!

]]

function ProductionPoint:loadProductionModes(production, index, productionKey, xmlFile, pModes)
	--Production Revamp: Wenn kein Modus für die Produktionslinie vorhanden ist, übergeordneten Produktionsmodus übernehmen
	production.mode = xmlFile:getValue(productionKey .. "#mode", pModes.mode)
	production.mixMode = xmlFile:getValue(productionKey .. "#mixMode", pModes.mixMode)
	production.mixMode = production.mixMode:upper()
	production.boostMode = xmlFile:getValue(productionKey .. "#boostMode", pModes.boostMode)
	production.boostMode = production.boostMode:upper()

	production.seasonsList = {}
	production.seasons = xmlFile:getValue(productionKey .. "#seasons", pModes.seasons)
	if production.seasons ~= nil then
		production.seasonText = ""
		local seasons = string.split(production.seasons, " ")
		for s = 1, #seasons do
			local season = tonumber(seasons[s])
			production.seasonsList[season] = true
			-- 0 Spring, 1 Summer, 2 Autumn, 3 Winter
			local text = ""
			if season == 0 then
				text = g_i18n:getText("Revamp_seasonSpring")
			elseif season == 1 then
				text = g_i18n:getText("Revamp_seasonSummer")
			elseif season == 2 then
				text = g_i18n:getText("Revamp_seasonAutumn")
			elseif season == 3 then
				text = g_i18n:getText("Revamp_seasonWinter")
			else
				Logging.xmlError(xmlFile, "Production Revamp: Invalid Season Entry for Production '%s'. Allowed: 0 - 3", production.name or index)
			end

			if production.seasonText == "" then
				production.seasonText = text
			elseif text ~= "" then
				production.seasonText = production.seasonText .. ", " .. text
			end
		end
	end

	production.monthsList = {}
	production.months = xmlFile:getValue(productionKey .. "#months", pModes.months)
	if production.months ~= nil then
		production.monthsText = ""
		local months = string.split(production.months, " ")
		local lastMonth = 0
		local lastMonthText = ""
		for s = 1, #months do
			local month = tonumber(months[s])
			production.monthsList[month] = true
			-- 1 März, 2 April, ..
			month = month + 2
			if month == 13 then
				month = 1
			elseif month == 14 then
				month = 2
			end
			if month > 15 then
				Logging.xmlError(xmlFile, "Production Revamp: Invalid Months Entry for Production '%s'. Allowed: 1 - 12", production.name or index)
			else
				local text = g_i18n:getText("ui_month"..month.."_short")
				if production.monthsText == "" then
					production.monthsText = text
					lastMonth = month
				else
					if month == lastMonth + 1 then
						lastMonth = month
						lastMonthText = text
					else
						production.monthsText = production.monthsText .. " - " .. lastMonthText .. ", " .. text
						lastMonthText = ""
						lastMonth = month
					end
				end
			end
		end
		if lastMonthText ~= nil then
			production.monthsText = production.monthsText .. " - " .. lastMonthText
		end
	end
	production.weatherFactor = xmlFile:getValue(productionKey .. "#weatherFactor", pModes.weatherFactor)

	local pStartHour = string.split(xmlFile:getString(productionKey .. "#startHour", pModes.startHour), " ")
	local pEndHour = string.split(xmlFile:getString(productionKey .. "#endHour", pModes.endHour), " ")
	production.hoursTable = {}
	production.hoursText = ""
	if #pStartHour ~= #pEndHour then
		Logging.xmlError(xmlFile, "Production Revamp: startHour or endHour is invalid, Opening-Hours are set to 0-24 for '%s'.", production.name or index)
		pStartHour[1] = 0
		pEndHour[1] = 24
	end

	for i = 1, #pStartHour do
		local startTime = tonumber(pStartHour[i])
		local endTime = tonumber(pEndHour[i])
		if startTime < endTime and startTime >=0 and endTime <25 then
			local hoursTableCount = 0
			for j = startTime, (endTime - 1) do
				production.hoursTable[j] = true
				hoursTableCount = hoursTableCount + 1;
				self.hoursTable[j] = true
			end
			if hoursTableCount < 24 then
				production.hoursText = production.hoursText .." ".. startTime .. " - " .. endTime .. " "
			end
		else
			Logging.xmlError(xmlFile, "Production Revamp: Entry '%s' from startHour or endHour is invalid for Production '%s'.", i, production.name or index)
		end
	end

	production.minPower = xmlFile:getValue(productionKey .. "#minPower", pModes.minPower)

	production.hideFromMenu = xmlFile:getValue(productionKey .. "#hideFromMenu", pModes.hideFromMenu)
	production.hideComplete = hideFromMenu --Nötig um die Ingame-Liste komplett zu verstecken
	if production.hideFromMenu == true then
		self.hiddenProductions = self.hiddenProductions + 1
	end
	production.autoStart = xmlFile:getValue(productionKey .. "#autoStart", pModes.autoStart)

	return production
end



function ProductionPoint:processWeather(weatherAffected, weatherFactor, amount, fillType, cyclesPerMinuteMinuteFactor)
	local fillLevel = self:getFillLevel(fillType)
	if weatherAffected=="sun" then
		if g_currentMission.environment.isSunOn then
			local dayMinutes = g_currentMission.environment.dayTime / 60000
			local currentClouds = g_currentMission.environment.weather.cloudUpdater:getCurrentValues()
			local lightDamping = currentClouds.lightDamping
			local sunBrightnessScale = 1
			if g_currentMission.environment.baseLighting.sunBrightnessScaleCurve ~= nil then
				sunBrightnessScale = g_currentMission.environment.baseLighting.sunBrightnessScaleCurve:get(dayMinutes)
			end
			local sunInput = amount * (1 - lightDamping) * (sunBrightnessScale / 7) * cyclesPerMinuteMinuteFactor * weatherFactor
			self.storage:setFillLevel(fillLevel + sunInput, fillType)
		end
	elseif weatherAffected=="night" then
		if not g_currentMission.environment.isSunOn then
			local dayMinutes = g_currentMission.environment.dayTime / 60000
			local currentClouds = g_currentMission.environment.weather.cloudUpdater:getCurrentValues()
			local lightDamping = currentClouds.lightDamping
			local nightBrightnessScale = 1
			if g_currentMission.environment.baseLighting.sunBrightnessScaleCurve ~= nil then
				nightBrightnessScale = g_currentMission.environment.baseLighting.moonBrightnessScaleCurveData:get(dayMinutes)
			end
			local nightInput = amount * (1 - lightDamping) * (nightBrightnessScale / 7) * cyclesPerMinuteMinuteFactor * weatherFactor
			self.storage:setFillLevel(fillLevel + nightInput, fillType)
		end
	elseif weatherAffected=="rain" then
		if g_currentMission.environment.weather:getIsRaining() then
			local rainfallScale = g_currentMission.environment.weather:getRainFallScale()
			local rainInput = amount * rainfallScale * cyclesPerMinuteMinuteFactor * weatherFactor
			self.storage:setFillLevel(fillLevel + rainInput, fillType)
		end
	elseif weatherAffected=="wind" then
		local windVelocity = g_currentMission.environment.weather.windUpdater.currentVelocity
		local windInput = amount * (windVelocity / 15) * cyclesPerMinuteMinuteFactor * weatherFactor
		self.storage:setFillLevel(fillLevel + windInput, fillType)
	elseif weatherAffected=="temp" then
		local currentTemp = g_currentMission.environment.weather:getCurrentTemperature()
		local tempInput = amount * (currentTemp / 25) * cyclesPerMinuteMinuteFactor * weatherFactor
		self.storage:setFillLevel(fillLevel + tempInput, fillType)
	end
end



function ProductionPoint:processInput(self, input, factor, fillLevel, enoughInput, mixMode, useFillType, boostFillType, production)
	if enoughInput[input.mix] or input.mix == 0 or input.mix == production.boostNumber or input.mix == production.masterNumber then
		if fillLevel > input.amount * factor then
			local process = true
			if mixMode ~= "ASC" then
				if input.mix == 0 or input.mix == production.boostNumber or input.mix == production.masterNumber then
					--nichts tun
				else
					if useFillType[input.mix] ~= nil then
						if useFillType[input.mix] ~= input.type then
							process = false
						end
					end
				end
			elseif production.feedMixer ~= nil then
				process = false
				--useFillType wird zu filltype = menge bei feedMixer
				if useFillType[input.type] > 0 then
					self.storage:setFillLevel(fillLevel - useFillType[input.type] * factor, input.type)
				end
			end
			if boostFillType[production.boostNumber] ~= 0 and input.mix == production.boostNumber then
				if boostFillType[production.boostNumber] == input.type then
					--nichts tun
				else
					process = false
				end
			end
			if boostFillType[production.masterNumber] ~= 0 and input.mix == production.masterNumber then
				if boostFillType[production.masterNumber] == input.type then
					--nichts tun
				else
					process = false
				end
			end
			if process then
				enoughInput[input.mix] = false
				if self.loadingStation ~= nil then
					if not input.outputConditional==false then
						local ouputFillLevel = self:getFillLevel(input.outputConditional)
						self.storage:setFillLevel(ouputFillLevel + input.outputAmount * factor, input.outputConditional)
					end
					if self.onlySellDirectly == true then
						self.storage:setFillLevel(fillLevel - (input.amount * factor), input.type)
					else
						self.loadingStation:removeFillLevel(input.type, input.amount * factor, self.ownerFarmId)
					end
				else
					if not input.outputConditional==false then
						local ouputFillLevel = self:getFillLevel(input.outputConditional)
						self.storage:setFillLevel(ouputFillLevel + input.outputAmount * factor, input.outputConditional)
					end
					self.storage:setFillLevel(fillLevel - input.amount * factor, input.type)
				end
			end
		end
	end
end



function ProductionPoint:processMix(mix, maxnum, needamount, fillLevel, enoughInput, useFillType, useFillTypeLevel, fillTypeId, mixMode)
	local color = 0
	if mix >= maxnum then
		maxnum = mix
	end
	if fillLevel >= needamount then
		if mixMode ~= "ASC" then
			if useFillType[mix] == nil then
				useFillType[mix] = fillTypeId
				useFillTypeLevel[mix] = fillLevel
			elseif useFillTypeLevel[mix] < fillLevel and mixMode == "MOST" then
				useFillType[mix] = fillTypeId
				useFillTypeLevel[mix] = fillLevel
			elseif useFillTypeLevel[mix] > fillLevel and mixMode == "LEAST" then
				useFillType[mix] = fillTypeId
				useFillTypeLevel[mix] = fillLevel
			elseif mixMode == "DESC" then
				useFillType[mix] = fillTypeId
				useFillTypeLevel[mix] = fillLevel
			end
		end
		enoughInput[mix] = true
	elseif not enoughInput[mix] then
		enoughInput[mix] = false
		color = 2
	else 
		color = 2
	end
	return maxnum, enoughInput, color, useFillType, useFillTypeLevel
end



function ProductionPoint:processProductionMode(production, mode, cyclesPerMinuteMinuteFactor, skip)
	--Production Revamp: Sollte die Produktion Öffnungszeiten haben, außerhalb der "Zeit" keine Produktion. Die Inputmengen werden trotzdem durchlaufen, um die Rezeptanzeige zu aktualisieren
	if mode=="hourly" then
		local currentHour = g_currentMission.environment.currentHour
		if not production.hoursTable[currentHour] then
			skip = ProductionPoint.PROD_STATUS.OUTSIDE_OF_HOURS
		end
	elseif mode=="sun" then
		if g_currentMission.environment.isSunOn or production.minPower > 0 then
			local dayMinutes = g_currentMission.environment.dayTime / 60000
			local currentClouds = g_currentMission.environment.weather.cloudUpdater:getCurrentValues()
			local lightDamping = currentClouds.lightDamping
			local sunBrightnessScale = 1
			if g_currentMission.environment.baseLighting.sunBrightnessScaleCurve ~= nil then
				sunBrightnessScale = g_currentMission.environment.baseLighting.sunBrightnessScaleCurve:get(dayMinutes)
			end
			local sunFactor = (1 - lightDamping) * (sunBrightnessScale / 7)
			if sunFactor < production.minPower then
				sunFactor = production.minPower
			end
			cyclesPerMinuteMinuteFactor = cyclesPerMinuteMinuteFactor * sunFactor * production.weatherFactor
		else
			skip = true
		end
	elseif mode=="rain" then
		if g_currentMission.environment.weather:getIsRaining() or production.minPower > 0 then
			local rainfallScale = g_currentMission.environment.weather:getRainFallScale()
			if rainfallScale < production.minPower then
				rainfallScale = production.minPower
			end
			cyclesPerMinuteMinuteFactor = cyclesPerMinuteMinuteFactor * rainfallScale	* production.weatherFactor
		else
			skip = true
		end
	elseif mode=="wind" then
		local windVelocity = g_currentMission.environment.weather.windUpdater.currentVelocity
		local windFactor = (windVelocity / 15)
		if windFactor < production.minPower then
			windFactor = production.minPower
		end
		cyclesPerMinuteMinuteFactor = cyclesPerMinuteMinuteFactor * windFactor * production.weatherFactor
	elseif mode=="temp" then
		local currentTemp = g_currentMission.environment.weather:getCurrentTemperature()
		--Production Revamp: Die Temperatur darf nicht negativ sein
		if currentTemp < 0 then
			currentTemp = 0
		end
		local tempFactor = (currentTemp / 25)
		if tempFactor < production.minPower then
			tempFactor = production.minPower
		end
		cyclesPerMinuteMinuteFactor = cyclesPerMinuteMinuteFactor * tempFactor * production.weatherFactor
	elseif mode=="tempNegative" then
		local currentTemp = g_currentMission.environment.weather:getCurrentTemperature()
		--Production Revamp: Die Temperatur darf nicht 0 oder negativ sein
		if currentTemp <= 0 then
			currentTemp = 1
		end
		local tempFactor = (20 / currentTemp) * 0.05
		if tempFactor < production.minPower then
			tempFactor = production.minPower
		end
		cyclesPerMinuteMinuteFactor = cyclesPerMinuteMinuteFactor * tempFactor * production.weatherFactor
	elseif mode=="seasonal" then
		if production.seasonsList[g_currentMission.environment.currentSeason] == nil then
			skip = ProductionPoint.PROD_STATUS.OUTSIDE_OF_SEASONS
		end
	elseif mode=="monthly" then
		if production.monthsList[g_currentMission.environment.currentPeriod] == nil then
			skip = ProductionPoint.PROD_STATUS.OUTSIDE_OF_MONTHS
		end
	end
	return cyclesPerMinuteMinuteFactor, skip
end


RevampProductionSettings = {}
--Production Revamp: MenüButton um das Rezept ändern zu können
function RevampProductionSettings:updateMenuButtons(superFunc)
	local isProductionListActive = self.productionList == FocusManager:getFocusedElement()
	local production, productionPoint = self:getSelectedProduction()

	if isProductionListActive then
		if production.mix == true or production.boost == true then
			table.insert(self.menuButtonInfo, {
				profile = "buttonOk",
				inputAction = InputAction.MENU_EXTRA_1,
				text = self.i18n:getText("Revamp_PS_MenueButton"),
				callback = function()
					self:RevampProductionSettingsShowMenue()
				end
			})
			self:setMenuButtonInfoDirty()
		end
	end
end

InGameMenuProductionFrame.updateMenuButtons = Utils.appendedFunction(InGameMenuProductionFrame.updateMenuButtons, RevampProductionSettings.updateMenuButtons)


--Production Revamp: Callback um Rezept zu ändern
function InGameMenuProductionFrame:RevampProductionSettingsShowMenue(mode)
	local isProductionListActive = self.productionList == FocusManager:getFocusedElement()
	local production, productionPoint = self:getSelectedProduction()

	if isProductionListActive or mode ~= nil then
		local selectableOptions = {}
		local options = {}
		local text = ""
		
		if production.mix == true and production.boost == true and mode == nil then
			text = g_i18n:getText("Revamp_PS_Choose_Title")
			table.insert(selectableOptions, {mode="MIX", self=self, production=production})
			table.insert(options, g_i18n:getText("Revamp_PS_Choose_Mix"))
			table.insert(selectableOptions, {mode="BOOST", self=self, production=production})
			table.insert(options, g_i18n:getText("Revamp_PS_Choose_Boost"))
		elseif production.mix == true or mode == "MIX" then
			--mix-Dialog anzeigen
			text = g_i18n:getText("Revamp_PS_Mix_Title").."\n"..g_i18n:getText("Revamp_PS_Mix_Text")
			table.insert(selectableOptions, {setting="MIX", value="ASC", self=self, production=production})
			table.insert(options, g_i18n:getText("Revamp_PS_Mix_Asc"))
			table.insert(selectableOptions, {setting="MIX", value="DESC", self=self, production=production})
			table.insert(options, g_i18n:getText("Revamp_PS_Mix_Desc"))
			table.insert(selectableOptions, {setting="MIX", value="LEAST", self=self, production=production})
			table.insert(options, g_i18n:getText("Revamp_PS_Mix_Least"))
			table.insert(selectableOptions, {setting="MIX", value="MOST", self=self, production=production})
			table.insert(options, g_i18n:getText("Revamp_PS_Mix_Most"))
		elseif production.boost == true or mode == "BOOST" then
			--boost-Dialog anzeigen
			text = g_i18n:getText("Revamp_PS_Boost_Title").."\n"..g_i18n:getText("Revamp_PS_Boost_Text")
			table.insert(selectableOptions, {setting="BOOST", value="ASC", self=self, production=production})
			table.insert(options, g_i18n:getText("Revamp_PS_Boost_Asc"))
			table.insert(selectableOptions, {setting="BOOST", value="DESC", self=self, production=production})
			table.insert(options, g_i18n:getText("Revamp_PS_Boost_Desc"))
			table.insert(selectableOptions, {setting="BOOST", value="LEAST", self=self, production=production})
			table.insert(options, g_i18n:getText("Revamp_PS_Boost_Least"))
			table.insert(selectableOptions, {setting="BOOST", value="MOST", self=self, production=production})
			table.insert(options, g_i18n:getText("Revamp_PS_Boost_Most"))
		end

		local dialogArguments = {
			text = text,
			title = productionPoint:getName(),
			options = options,
			target = self,
			args = selectableOptions,
			callback = self.RevampProductionSettingsChange
		}

		--Alten Dialog falls vorhanden resetten
		local dialog = g_gui.guis["OptionDialog"]
		if dialog ~= nil then
			dialog.target:setOptions({""}) -- Add fake option to force a "reset"
		end
		g_gui:showOptionDialog(dialogArguments)
	end
end


function InGameMenuProductionFrame:RevampProductionSettingsChange(selectedOption, args)
	local production, productionPoint = self:getSelectedProduction()
	local selectedArg = args[selectedOption]
	if selectedArg == nil then return end

	if selectedArg.mode ~= nil then
		if selectedArg.mode == "MIX" then
			self:RevampProductionSettingsShowMenue("mix")
		elseif selectedArg.mode == "BOOST" then
			self:RevampProductionSettingsShowMenue("boost")
		end
	elseif selectedArg.setting == "BOOST" then
		productionPoint:setRevampSettings(selectedArg.production.id, nil, selectedArg.value, nil)
	elseif selectedArg.setting == "MIX" then
		productionPoint:setRevampSettings(selectedArg.production.id, selectedArg.value, nil, nil)
	end
end