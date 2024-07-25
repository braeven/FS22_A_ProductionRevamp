--[[
Production Revamp
Function for Debugging certain parts

Copyright (C) Acimobil, 2023
]]

RevampDebugHelper = {};
RevampDebugHelper.settingsDirectory = g_currentModSettingsDirectory;
RevampDebugHelper.settingsFile = g_currentModSettingsDirectory .. "RevampDebug.xml";
RevampDebugHelper.configFileNames = {};
RevampDebugHelper.moduleNames = {};


-- function RevampDebugHelper:onStartMission()
	-- RevampDebugHelper:loadDebugSettings();
-- end

-- Mission00.onStartMission = Utils.appendedFunction(Mission00.onStartMission, RevampDebugHelper.onStartMission)

function RevampDebugHelper:loadDebugSettings()
	createFolder(RevampDebugHelper.settingsDirectory)
	if not fileExists(RevampDebugHelper.settingsFile) then
		RevampDebugHelper:createDefaultFile();
	else
		RevampDebugHelper:loadSettings();
	end
end

function RevampDebugHelper:createDefaultFile()

	local xmlFile = XMLFile.create("revampDebug", RevampDebugHelper.settingsFile, "revampDebug")

	xmlFile:setString("revampDebug.configFiles.configFile#name", "")
	xmlFile:setString("revampDebug.modules.module#name", "")

	xmlFile:save()
	xmlFile:delete()
end

function RevampDebugHelper:loadSettings()
	local xmlFile = XMLFile.load("revampDebug", RevampDebugHelper.settingsFile)

	if xmlFile == nil then
		return false
	end
	
	local debugConfigFilesString = nil
	
	xmlFile:iterate("revampDebug.configFiles.configFile", function (_, key)
			local name = xmlFile:getString(key .. "#name");
			
			if name ~= nil and name ~= '' then
				RevampDebugHelper.configFileNames[name] = true;
				if debugConfigFilesString == nil then
					debugConfigFilesString = name;
				else
					debugConfigFilesString = debugConfigFilesString .. ", " .. name;
				end
				
			end
		end)
	if debugConfigFilesString ~= nil then
		Logging.info("Revamp Debug activated for config files: (%s)", debugConfigFilesString)
	end
	
	debugConfigFilesString = nil
	xmlFile:iterate("revampDebug.modules.module", function (_, key)
			local name = xmlFile:getString(key .. "#name");
			
			if name ~= nil and name ~= '' then
				RevampDebugHelper.moduleNames[name] = true;
				if debugConfigFilesString == nil then
					debugConfigFilesString = name;
				else
					debugConfigFilesString = debugConfigFilesString .. ", " .. name;
				end
				
			end
		end)
	if debugConfigFilesString ~= nil then
		Logging.info("Revamp Debug activated for config files: (%s)", debugConfigFilesString)
	end
		
	xmlFile:delete()
end



function RevampDebugHelper:Debug(configFileName, revampModule, message, ...)

	if configFileName ~= nil then
		configFileName = Utils.removeModDirectory(configFileName);
	end
	
	if RevampDebugHelper.configFileNames[configFileName] ~= nil then
		--should be shown
	elseif RevampDebugHelper.moduleNames[revampModule] ~= nil then
		--should be shown
	else
		return;
	end
		
	-- print the output
	local frontLine = string.format("%s - %s: " ,configFileName, revampModule);
	
	print(string.format("  RevampDebug - " .. frontLine .. message, ...))
	
	-- DebugUtil.printTableRecursively(self, " - ",0,2)
end

RevampDebugHelper:loadDebugSettings();