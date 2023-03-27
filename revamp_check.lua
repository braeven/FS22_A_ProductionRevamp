--[[
Copyright (C) braeven, 2022

Author: braeven / Achimobil
Date: 14.02.2022
Version: 1.1.4.3

Contact/Help/Tutorials:
discord.gg/gHmnFZAypk

Changelog:
1.0.0.0 @ 16.04.2022 - Release Initial Version
1.1.0.0 @ 14.05.2022 - Added Option to add own FillTypes to Sellingstation
1.1.1.0 @ 19.05.2022 - Removed Discord-Link in Checker-Message.
1.1.2.0 @ 13.06.2022 - Added Option to force a registry of a FillType into Selllingstations
1.1.3.0 @ 14.08.2022 - Ausnahme für den Icon Generator hinzugefügt
1.1.4.0 @ 18.10.2022 - FillTypeFilesToLoad zum Laden von Filltypes ohne die bestehenden Daten zu überschreiben
1.1.4.1 @ 30.11.2022 - AddByFillTypeStoreItems erweitert um den mod Titel für die Bauanzeige
1.1.4.2 @ 19.12.2022 - Code Cleanup
1.1.4.3 @ 14.02.2022 - Schreibfehler in der Vergangenheit berücksichtig

Important:
Kopiere diese Datei in deine Produktionen um einen Revamp-Versionscheck ausführen zu können. Diese Datei ist außerdem nötig um Filltypes bei bestehenden Sellingstations anmelden zu können und StoreItems An-/Abzumelden.

Copy this File into your Productions to add a Revamp-Versionscheck. This File is also needed to add Filltypes into existing Sellingstations and registering/unregistering StoreItems.
]]

RevampChecker = {}


--Production Revamp: Function to compare the needed with the avaible version of Revamp
function RevampChecker.check(revampVersion, neededVersion)
	local base, major, minor, patch = string.match(revampVersion, "(%d+)%.(%d+)%.(%d+)%.(%d+)")
	RevampChecker.base = math.floor(base)
	RevampChecker.major = math.floor(major)
	RevampChecker.minor = math.floor(minor)
	RevampChecker.patch = math.floor(patch)

	local base, major, minor, patch = string.match(neededVersion, "(%d+)%.(%d+)%.(%d+)%.(%d+)")
	base = math.floor(base)
	major = math.floor(major)
	minor = math.floor(minor)
	patch = math.floor(patch)
	if RevampChecker.base > base then
		return true
	elseif RevampChecker.base == base then
		if RevampChecker.major > major then
			return true
		elseif RevampChecker.major == major then
			if RevampChecker.minor > minor then
				return true
			elseif RevampChecker.minor == minor then
				if RevampChecker.patch > patch then
					return true
				elseif RevampChecker.patch == patch then
					return true
				end
			end
		end
	end
	return false
end


--Production Revamp: Callback function for the warning message. Opens the modhub page if needed.
function RevampChecker.done(isYes)
	if isYes == true then
		local link = "mods.php?title=fs2022&searchMod=revamp"
		openWebFile(link, "")
	end
end


--Production Revamp: Warning function - Will generate the warning message for 2 languages
function RevampChecker.warning(revampVersion, neededVersion, modName)
	local title = "Wrong Version of Production Revamp"
	local text = "At least one mod needs a newer version.\n Mod " ..modName.. " needs at least version " ..neededVersion.. " of Production Revamp.\n The installed version is " ..revampVersion.. ", please update to the latest one."
	local textyes = "Open Modhub"
	local textno = "Ignore"
	local language = g_languageShort
	if language == "de" then
		title = "Veraltete Version von Production Revamp"
		text = "Mindestens ein Mod benötigt eine neuere Version.\n Der Mod " ..modName.. " benötigt Version " ..neededVersion.. " von Production Revamp.\n Die vorhandene Version ist " ..revampVersion.. ", bitte updaten."
		textyes = "Modhub öffnen"
		textno = "Ignorieren"
	end

	g_gui:showYesNoDialog({
		title = title,
		text = text,
		dialogType = DialogElement.TYPE_WARNING,
		callback = RevampChecker.done,
		target = self,
		yesText = textyes,
		noText = textno
	})
end


--Production Revamp: Checking the Version of Revamp, If the test succeeds, run the SellingStation Script.
function RevampChecker.test()
	local mods = g_modManager:getActiveMods(FS22_A_ProductionRevamp)
	local revampversion = ""

	for index, activemod in pairs(mods) do
		if activemod.title == "Production Revamp" then
			revampversion = activemod.version
		end
	end

	local modName = g_currentModName
	local mod = g_modManager:getModByName(modName)

	if mod == nil and g_iconGenerator then
		-- im Icon generator passiert so kein fehler
		return
	end

	local xmlFile = XMLFile.load("TempDesc", mod.modFile)

	if xmlFile ~= nil and xmlFile ~= 0 then
		local version = xmlFile:getString("modDesc.revamp#minVersion")
		local supressWarning = xmlFile:getBool("modDesc.revamp#supressWarning", false)

		if revampversion == "" and version ~= nil then
			if supressWarning then
				-- mach nix, weil es soll nichts gemacht werden
			else
				print("Production Revamp: Mod " ..modName.. " needs Revamp Version: " ..version.. ", Revamp not was found.")
			end
		elseif version ~= nil then
			print("Production Revamp: Testing Mod " ..modName.. " for Version: " ..version.. ", Revamp Version " ..revampversion.. " was found.")
			if RevampChecker.check(revampversion, version) then
				local g_revamp = getfenv(0)["FS22_A_ProductionRevamp"]
				local Revamp = g_revamp.Revamp
				--Production Revamp: XML Neu laden mit Revamp-Schema
				local xmlFile = XMLFile.load("TempDesc", mod.modFile, Revamp.XmlSchema)
				local hasSelling = xmlFile:hasProperty("modDesc.revamp.sellFillType(0)") 
				if hasSelling then
					xmlFile:iterate("modDesc.revamp.sellFillType", function (_, inputKey)
						local base = xmlFile:getValue(inputKey .. "#base")
						local fillType = xmlFile:getValue(inputKey .. "#fillType")
						local forceRegister = xmlFile:getValue(inputKey .. "#forceRegister", false)
						local Selltype = {}
						Selltype.base = base
						Selltype.fillType = fillType
						Selltype.forceRegister = forceRegister
						Selltype.modName = modName
						table.insert(Revamp.SellFillTypes, Selltype)
					end)
				end
				xmlFile:iterate("modDesc.storeItems.storeItem", function (_, inputKey)
					local storeItemXMLFilename = xmlFile:getString(inputKey .. "#xmlFilename")
					local removeWhenFillTypeNames = xmlFile:getValue(inputKey .. "#removeWhenFillTypes")
					if removeWhenFillTypeNames ~= nil then
						local storeItem = {}
						storeItem.xmlFilename = storeItemXMLFilename
						storeItem.removeWhenFillTypeNames = removeWhenFillTypeNames
						storeItem.customEnvironment = modName
						table.insert(Revamp.RemoveByFillTypeStoreItems, storeItem)
					end
				end)
				xmlFile:iterate("modDesc.revamp.storeItems.storeItem", function (_, inputKey)
					local storeItemXMLFilename = xmlFile:getString(inputKey .. "#xmlFilename")
					local removeWhenFillTypeNames = xmlFile:getValue(inputKey .. "#removeWhenFillTypes")
					local addWhenFillTypeNames = xmlFile:getValue(inputKey .. "#addWhenfillTypes")
					if addWhenFillTypeNames == nil then
						local addWhenFillTypeNames = xmlFile:getValue(inputKey .. "#addWhenFillTypes") -- SchreibFehler in der Vergangenheit
					end
					if removeWhenFillTypeNames ~= nil or addWhenFillTypeNames ~= nil then
						local storeItem = {}
						storeItem.xmlFilename = storeItemXMLFilename
						if removeWhenFillTypeNames ~= nil then
							storeItem.removeWhenFillTypeNames = removeWhenFillTypeNames
						end
						if addWhenFillTypeNames ~= nil then
							storeItem.addWhenFillTypeNames = addWhenFillTypeNames
						end
						storeItem.customEnvironment = modName
						storeItem.baseDirectory = g_currentModDirectory
						storeItem.title = mod.title
						table.insert(Revamp.AddByFillTypeStoreItems, storeItem)
					end
				end)
				-- for late loading non overriting fillTypes
				local fillTypesFilename = xmlFile:getString("modDesc.revamp.fillTypes#filename")

				if fillTypesFilename ~= nil then
					table.insert(Revamp.FillTypeFilesToLoad, {
						Utils.getFilename(fillTypesFilename, g_currentModDirectory),
						g_currentModDirectory,
						modName
					})
				end
			else
				RevampChecker.warning(revampversion, version, modName)
			end
		end
	end

	xmlFile:delete()
end


RevampChecker:test()