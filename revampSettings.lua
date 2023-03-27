--[[
Production Revamp
Setting File

Copyright (C) Achimobil, braeven, 2022

Date: 19.12.2022
Version: 1.0.0.2

Contact/Help/Tutorials:
discord.gg/gHmnFZAypk

Changelog:
1.0.0.0 @ 22.08.2022 - Initial Release
1.0.0.1 @ 04.09.2022 - ÜbersetzungsVariablen angepasst
1.0.0.2 @ 19.12.2022 - Code Cleanup

Important:.
No changes are allowed to this script without permission from Achimobil AND Braeven.
If you want to make a production with this script, look in the discord channels for tutorials/help or download the FS22_Revamp_Productions Pack for reference
Don't copy the script into a production, load the mod as a dependency!

Es dürfen an diesem Script keine Veränderungen ohne Erlaubnis von Achimobil UND Braeven gemacht werden.
Wenn du eine Produktion mit diesem Script bauen möchtest, lese dir die angepinnten Tutorials im Discord durch oder guck dir die FS22_Revamp_Productions an.
Nicht das Script in Produktionen kopieren, ladet den Mod über eine Dependency!

]]

RevampSettings = {}
RevampSettings.name = g_currentModName
RevampSettings.modDir = g_currentModDirectory
RevampSettings.BuyRestriction = { "Everyone", "FarmManager", "ProductionAgent", "None" }
RevampSettings.debug = false

source(g_currentModDirectory .. "events/changeRevampSettingsEvent.lua")
source(g_currentModDirectory .. "events/changeRevampCheckSettingsEvent.lua")
source(g_currentModDirectory .. "events/changeRevampDecimalSettingsEvent.lua")
source(g_currentModDirectory .. "events/loadRevampSettingsEvent.lua")

function RevampSettings.init()
	-- init default settings
	RevampSettings.current = {}
	RevampSettings.current.BuyRestriction = 3 -- ProductionAgent
	RevampSettings.current.PrioSystemActive = true
	RevampSettings.current.MissionFixActive = true
	RevampSettings.current.PriceCorrectionActive = true
	RevampSettings.current.DistributionCostFactor = 1
	RevampSettings.current.DirectSellingPriceFactor = 0.9

	-- listen zum speichern der elemente für das wieder füllen bei änderungen von anderen
	RevampSettings.multiElements = {}
	RevampSettings.checkElements = {}
	RevampSettings.textElements = {}

	-- Einstellungen speichern und laden
	Mission00.loadMission00Finished = Utils.appendedFunction(Mission00.loadMission00Finished, RevampSettings.loadSettingsXML)
	FSCareerMissionInfo.saveToXMLFile = Utils.appendedFunction(FSCareerMissionInfo.saveToXMLFile, RevampSettings.saveSettingsXML)

	-- game settings dialog extension
	InGameMenuGameSettingsFrame.onFrameOpen = Utils.appendedFunction(InGameMenuGameSettingsFrame.onFrameOpen, RevampSettings.GameSettingsFrame_onFrameOpen)
	InGameMenuGameSettingsFrame.updateGameSettings = Utils.appendedFunction(InGameMenuGameSettingsFrame.updateGameSettings, RevampSettings.GameSettingsFrame_updateGameSettings)

	-- damit beim joinen im MP die einstellungen geholt werden senden wir ein event dass die einstellungen dann an alle schickt
	FSBaseMission.onConnectionFinishedLoading = Utils.appendedFunction(FSBaseMission.onConnectionFinishedLoading, RevampSettings.loadSettingsFromServer)
end

function RevampSettings.GameSettingsFrame_onFrameOpen(self)
	---Darf nur ein mal aufgerufen werden, beim nächsten mal sind die elemente ja schon da
	if self.revampGameSettings_initialized == nil then
		local target = RevampSettings.current

		RevampSettings:AddTitle(self, "Revamp_Settings_Title")

		RevampSettings:AddGameSettingMultiElement(self, target, "BuyRestriction", RevampSettings.BuyRestriction, RevampSettings.current.BuyRestriction)
		RevampSettings:AddGameSettingCheckElement(self, target, "PrioSystemActive", RevampSettings.current.PrioSystemActive)
		RevampSettings:AddGameSettingCheckElement(self, target, "MissionFixActive", RevampSettings.current.MissionFixActive)
		RevampSettings:AddGameSettingCheckElement(self, target, "PriceCorrectionActive", RevampSettings.current.PriceCorrectionActive)
		RevampSettings:AddGameSettingDecimalNonNegativeElement(self, target, "DistributionCostFactor", RevampSettings.current.DistributionCostFactor)
		RevampSettings:AddGameSettingDecimalNonNegativeElement(self, target, "DirectSellingPriceFactor", RevampSettings.current.DirectSellingPriceFactor)

		self.revampGameSettings_initialized = true

		self.boxLayout:invalidateLayout()
	end
end

function RevampSettings:GameSettingsFrame_updateGameSettings()
	-- Settings neu in den dialog laden, könnten von anderem Admin ja geändert sein
	for settingId, element in pairs(RevampSettings.multiElements) do
		element:setState(RevampSettings.current[settingId])
		element:setDisabled(not self.hasMasterRights)
	end
	for settingId, element in pairs(RevampSettings.checkElements) do
		element:setIsChecked(RevampSettings.current[settingId])
		element:setDisabled(not self.hasMasterRights)
	end
	for settingId, element in pairs(RevampSettings.textElements) do
		element:setText(tostring(RevampSettings.current[settingId]))
		element:setDisabled(not self.hasMasterRights)
	end
end

function RevampSettings:AddGameSettingDecimalNonNegativeElement(self, target, settingId, state)

	-- wir kopieren aus dem dialog das 2. GuiElement, das ist die eingabestelle für den savegame namen
	local wrappingElement = self.boxLayout.elements[2]:clone()

	-- hier nutzen wir das input das schon kopiert ist
	local newTextElement = wrappingElement.elements[1]

	newTextElement.target = self
	newTextElement.onEnterPressedCallback = RevampSettings.onTextChangedGameSettingDecimalNonNegativeCallback
	newTextElement.id = settingId
	newTextElement.maxCharacters = 5
	newTextElement:setText(tostring(state))

	local settingTitle = wrappingElement.elements[2]
	settingTitle:setText(RevampSettings:getText("Revamp_" .. settingId .. "_Title"))

	local toolTip = wrappingElement.elements[3]
	toolTip:setText(RevampSettings:getText("Revamp_" .. settingId .. "_Tooltip"))

	self.boxLayout:addElement(wrappingElement)

	RevampSettings.textElements[settingId] = newTextElement
end

function RevampSettings:AddGameSettingCheckElement(self, target, settingId, state)
	-- hier kopieren wir ein checkbox feld element
	local newMultiElement = self.checkTraffic:clone()
	newMultiElement.target = target
	newMultiElement.onClickCallback = RevampSettings.onClickGameSettingCheckbox
	newMultiElement.buttonLRChange = RevampSettings.onClickGameSettingCheckbox
	newMultiElement.id = settingId

	local settingTitle = newMultiElement.elements[4]
	settingTitle:setText(RevampSettings:getText("Revamp_" .. settingId .. "_Title"))

	local toolTip = newMultiElement.elements[6]
	toolTip:setText(RevampSettings:getText("Revamp_" .. settingId .. "_Tooltip"))

	newMultiElement:setIsChecked(state)

	self.boxLayout:addElement(newMultiElement)

	RevampSettings.checkElements[settingId] = newMultiElement
end

function RevampSettings:AddGameSettingMultiElement(self, target, settingId, valueList, state)

	local elementTexts = {}
	for id, name in pairs(valueList) do
		table.insert(elementTexts, RevampSettings:getText("Revamp_" .. settingId .. "_" .. name))
	end

	-- hier kopieren wir ein multi feld element
	local newMultiElement = self.economicDifficulty:clone()
	newMultiElement.target = target
	newMultiElement.onClickCallback = RevampSettings.onClickGameSettingMultiOption
	newMultiElement.buttonLRChange = RevampSettings.onClickGameSettingMultiOption
	newMultiElement.id = settingId
	newMultiElement:setTexts(elementTexts)

	local settingTitle = newMultiElement.elements[4]
	settingTitle:setText(RevampSettings:getText("Revamp_" .. settingId .. "_Title"))

	local toolTip = newMultiElement.elements[6]
	toolTip:setText(RevampSettings:getText("Revamp_" .. settingId .. "_Tooltip"))

	newMultiElement:setState(state)

	self.boxLayout:addElement(newMultiElement)

	RevampSettings.multiElements[settingId] = newMultiElement
end

function RevampSettings:AddTitle(self, text)
	local title = TextElement.new()
	title:applyProfile("settingsMenuSubtitle", true)
	title:setText(RevampSettings:getText(text))

	self.boxLayout:addElement(title)
end

function RevampSettings:getText(key)
	local result = g_i18n.modEnvironments[RevampSettings.name].texts[key]
	if result == nil then
		return g_i18n:getText(key)
	end
	return result
end

function RevampSettings:onClickGameSettingMultiOption(state, optionElement)
	RevampSettings:print("Change ".. tostring(optionElement.id) .. " to " .. tostring(state))
	g_client:getServerConnection():sendEvent(ChangeRevampSettingsEvent.new(optionElement.id, state))
end

function RevampSettings:onClickGameSettingCheckbox(state, checkboxElement)
	RevampSettings:print("Change ".. tostring(checkboxElement.id) .. " to " .. tostring(checkboxElement:getIsChecked()))
	g_client:getServerConnection():sendEvent(ChangeRevampCheckSettingsEvent.new(checkboxElement.id, checkboxElement:getIsChecked()))
end

function RevampSettings:onTextChangedGameSettingDecimalNonNegativeCallback(textElement, text)
	local newValue = tonumber(textElement:getText())
	if newValue == nil then
		newValue = 1
	end
	if newValue < 0 then
		newValue = 0
	end
	RevampSettings:print("Change ".. tostring(textElement.id) .. " to " .. tostring(newValue))
	g_client:getServerConnection():sendEvent(ChangeRevampDecimalSettingsEvent.new(textElement.id, newValue))

	-- noch mal explizit setzen sonst setzt er er bei erneutem editieren zurück auf den vorherigen wert und die korrektur auf 1 im fehlerfall ist nicht sichtbar
	textElement:setText(tostring(newValue))
end

function RevampSettings.saveSettingsXML(missionInfo)
	if(RevampSettings.current == nil) then
		return
	end

	local xmlFile = XMLFile.create("RevampXML", missionInfo.savegameDirectory .. "/revamp.xml", "revamp")
	if xmlFile ~= nil then
		xmlFile:setInt("revamp.BuyRestriction", RevampSettings.current.BuyRestriction)
		xmlFile:setBool("revamp.PrioSystemActive", RevampSettings.current.PrioSystemActive)
		xmlFile:setBool("revamp.MissionFixActive", RevampSettings.current.MissionFixActive)
		xmlFile:setBool("revamp.PriceCorrectionActive", RevampSettings.current.PriceCorrectionActive)
		xmlFile:setFloat("revamp.DistributionCostFactor", RevampSettings.current.DistributionCostFactor)
		xmlFile:setFloat("revamp.DirectSellingPriceFactor", RevampSettings.current.DirectSellingPriceFactor)
		xmlFile:save()
	end
end

function RevampSettings.loadSettingsXML(mission, node)
	if mission:getIsServer() then
		if mission.missionInfo.savegameDirectory ~= nil and fileExists(mission.missionInfo.savegameDirectory .. "/revamp.xml") then
			local xmlFile = XMLFile.load("RevampXML", mission.missionInfo.savegameDirectory .. "/revamp.xml")
			if xmlFile ~= nil then
				RevampSettings.current.BuyRestriction = xmlFile:getInt("revamp.BuyRestriction")
				RevampSettings:print("Production Revamp: Loaded 'BuyRestriction': " .. tostring(RevampSettings.current.BuyRestriction))

				RevampSettings.loadSettingsBool(xmlFile, "PrioSystemActive")
				RevampSettings.loadSettingsBool(xmlFile, "MissionFixActive")
				RevampSettings.loadSettingsBool(xmlFile, "PriceCorrectionActive")
				RevampSettings.loadSettingsFloat(xmlFile, "DistributionCostFactor")
				RevampSettings.loadSettingsFloat(xmlFile, "DirectSellingPriceFactor")
				xmlFile:delete()
			end
		end
	end
end

function RevampSettings.loadSettingsBool(xmlFile, settingsId)
	RevampSettings.current[settingsId] = xmlFile:getBool("revamp." .. settingsId, true)
	RevampSettings:print("Production Revamp: Loaded '" .. settingsId .. "': " .. tostring(RevampSettings.current[settingsId]))
end

function RevampSettings.loadSettingsFloat(xmlFile, settingsId)
	local value = xmlFile:getFloat("revamp." .. settingsId)
	if value == nil then
		return
	end
	RevampSettings.current[settingsId] = value
	RevampSettings:print("Production Revamp: Loaded '" .. settingsId .. "': " .. tostring(RevampSettings.current[settingsId]))
end

function RevampSettings.loadSettingsFromServer()
	RevampSettings:print("Production Revamp: Request settings from server")
	g_client:getServerConnection():sendEvent(LoadRevampSettingsEvent.new())
end

function RevampSettings:print(text)
	if RevampSettings.debug then
		print(text)
	end
end

function RevampSettings:IsBuyAllowedForUser(productionPoint)
	if RevampSettings.current.BuyRestriction == 1 then -- "Everyone"
		return true
	elseif RevampSettings.current.BuyRestriction == 2 then -- "FarmManager"
		local owningFarm = g_farmManager:getFarmById(productionPoint:getOwnerFarmId())
		if not owningFarm:isUserFarmManager(g_currentMission.playerUserId) then
			return false
		end
	elseif RevampSettings.current.BuyRestriction == 3 then -- "ProductionAgent"
		if not g_currentMission:getHasPlayerPermission("manageProductions") then
			return false
		end
	else -- "None"
		return false
	end

	return true
end

RevampSettings.init()