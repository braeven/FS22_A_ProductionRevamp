--[[
Copyright (C) Achimobil & braeven, 2022

Author: Achimobil (Base and pallets) / braeven (bales)
Date: 20.08.2022
Version: 2.2.5.0

Contact:
https://forum.giants-software.com
https://discord.gg/Va7JNnEkcW (Achimobil) 
https://discord.gg/gHmnFZAypk (Revamp)

History:
V 1.0.0.0 @ 15.01.2022 - Release Version.
V 1.1.0.0 @ 17.01.2022 - Make pallet string translatable in mod
V 2.0.0.0 @ 07.02.2022 - Add possibility to export Bales.
V 2.1.0.0 @ 09.05.2022 - Add total amount of selected quantity in dialog
V 2.1.1.0 @ 10.05.2022 - Add Version and Name for main.lua
V 2.2.0.0 @ 10.05.2022 - Add name and filllevel to next dialogs
V 2.2.1.0 @ 02.06.2022 - rename to integrate in Revamp
V 2.2.1.1 @ 06.06.2022 - fix to not not load when not defined in XML
V 2.2.1.2 @ 06.06.2022 - added message if storage is empty
V 2.2.2.0 @ 06.07.2022 - sort filltype selection and correct max display
V 2.2.3.0 @ 09.07.2022 - delay timer used like in the productions
V 2.2.4.0 @ 17.08.2022 - fix customEnvironment problem in siloPalletSpawnerSpecialization
V 2.2.5.0 @ 20.08.2022 - Farbwahl für Silageballen
V 2.2.5.1 @ 31.08.2022 - Holzstämme spawnen jetzt in spawnplace direction

Important:
It is not allowed to copy in own Mods. Only usage as reference with Production Revamp.
No changes are to be made to this script without permission from Achimobil or braeven.

Darf nicht in eigene Mods kopiert werden. Darf nur über den Production Revamp Mod benutzt werden.
An diesem Skript dürfen ohne Genehmigung von Achimobil oder braeven keine Änderungen vorgenommen werden.
]]



SiloPalletSpawnerSpecialization = {
    Version = "2.2.4.0",
    Name = "SiloPalletSpawnerSpecialization"
}

print(g_currentModName .. " - init " .. SiloPalletSpawnerSpecialization.Name .. "(Version: " .. SiloPalletSpawnerSpecialization.Version .. ")");

-- load event
local path = g_currentModDirectory .. "events/SpawnPalletsAtSiloEvent.lua";
source(path)

PalletSiloActivatable = {}

local PalletSiloActivatable_mt = Class(PalletSiloActivatable, Object)

---Creates a new instance of the class
-- @param bool isServer true if we are server
-- @param bool isClient true if we are client
-- @param table customMt meta table
-- @return table self returns the instance
function PalletSiloActivatable.new(placable, isServer, customMt)
    local self = Object.new(isServer, isClient, customMt or PalletSiloActivatable_mt)

    self.placable = placable
    self.activateText = g_i18n:getText("Revamp_Spawn");

    return self
end

---Called when press activate. In the test cases there were no parameters
function PalletSiloActivatable:run()    
    local spec = self.placable.spec_SiloPalletSpawner
    
    local availableItemsInStorages = {};
    
    -- wenn holz auslagern läuft, dann nicht aufrufen können
    if spec.pendingWoodLogs ~= nil then
        return;
    end

    -- was liegt im Lager?
    for _, storage in pairs (self.placable.spec_silo.storages) do
        for fillTypeIndex, fillLevel in pairs (storage.fillLevels) do
            if (fillLevel > 1) then
                if availableItemsInStorages[fillTypeIndex] == nil then
                    availableItemsInStorages[fillTypeIndex] = {};
                    availableItemsInStorages[fillTypeIndex].fillTypeIndex = fillTypeIndex;
                    availableItemsInStorages[fillTypeIndex].fillLevel = 0;
                    
                    -- name in meiner Sprache holen
                    availableItemsInStorages[fillTypeIndex].title = g_currentMission.fillTypeManager.fillTypes[fillTypeIndex].title
                end
                
                local currentAvailableItem = availableItemsInStorages[fillTypeIndex];
                currentAvailableItem.fillLevel = currentAvailableItem.fillLevel + fillLevel;
            end
        end
    end
    
    -- Sortieren der Filltypes
    local sortedAvailableItems = {}
    for _, availableItem in pairs (availableItemsInStorages) do
        table.insert(sortedAvailableItems, availableItem);
    end
    
    table.sort(sortedAvailableItems, compAvailableItems);
    
    -- umsortieren, damit die beiden listen den gleichen index haben
    local selectableOptions = {}
    local options = {};
    local empty = true

    for _, availableItem in pairs (sortedAvailableItems) do
        table.insert(selectableOptions, availableItem);
        table.insert(options, availableItem.title .. " (" .. math.floor(availableItem.fillLevel) .. " l)");
        empty = false
    end
    
    if empty then
      local dummy = {}
      dummy.empty = true
      table.insert(selectableOptions, dummy)
      table.insert(options, g_i18n:getText("Revamp_StorageEmpty"))
    end
      
    -- Wählen was ausgelagert werden soll aus dem was da ist
    local dialogArguments = {
        text = g_i18n:getText("Revamp_ChooseWhatToPutOut"),
        title = self.placable:getName(),
        options = options,
        target = self,
        args = selectableOptions,
        callback = self.fillTypeSelected
    }
    
    --TODO: hack to reset the "remembered" option (i.e. solve a bug in the game engine)
    local dialog = g_gui.guis["OptionDialog"]
    if dialog ~= nil then
        dialog.target:setOptions({""}) -- Add fake option to force a "reset"
    end

    g_gui:showOptionDialog(dialogArguments)
end

function compAvailableItems(w1,w2)
    return w1.title .. w1.fillTypeIndex < w2.title .. w2.fillTypeIndex;
end

function PalletSiloActivatable:fillTypeSelected(selectedOption, args)
    local spec = self.placable.spec_SiloPalletSpawner

    -- parameter auswerten
    local selectedArg = args[selectedOption];
    if selectedArg == nil then return end
    local fillTypeIndex = selectedArg.fillTypeIndex;
    if selectedArg.empty then return end

    -- Ballen Übersicht laden falls noch nicht geladen
    if self.baleTypes == nil then
        self.baleTypes = RevampHelper:GetBaleTypes()
        -- print("loaded Bales")
    end	

    -- Liste Überprüfen ob ein Filltype in der Ballen-Liste auftaucht
    -- Sollte kein Ballen vorhanden sein, wie Palette behandeln, ansonsten Ballenliste weiter auswerten
    local currentFillType = g_fillTypeManager:getFillTypeByIndex(fillTypeIndex)
    
    -- wenn es mehrere möglichkeiten gibt zu auslagern, also Ballen, Paletten oder Holzstämme. 
    -- hier die möglichkeiten bestimmen
    local possibilities = {};
    if self.baleTypes[currentFillType.name] ~= nil then
        table.insert(possibilities, "bale")
    end
    if spec.palletSpawner.fillTypeIdToPallet[fillTypeIndex] ~= nil then
        table.insert(possibilities, "pallet")
    end
    if currentFillType.name == "WOOD" and spec.woodSpawnPlace ~= nil then
        table.insert(possibilities, "woodLog")
    end
    
    -- Wenn es nur eine Möglichkeit gibt, diese direkt aufrufen ohne anderen dialog
    if #possibilities == 1 then
        if possibilities[1] == "bale" then
            self:chooseBaleAmount(self, selectedArg.fillLevel, currentFillType);
            return;
        elseif possibilities[1] == "woodLog" then
            self:chooseWoodLogAmount(self, selectedArg.fillLevel, currentFillType);
            return;
        else
            self:choosePalletAmount(self, selectedArg.fillLevel, currentFillType);
            return;
        end
    elseif #possibilities == 0 then
        return;
    else
        -- multiple choice dialog 
        local selectableOptions = {}
        local options = {};
                
        -- Auswahl erstellen
        for i, possibilitie in pairs (possibilities) do
            table.insert(selectableOptions, {fillLevel=selectedArg.fillLevel, possibilitie=possibilitie, fillType=currentFillType});
            table.insert(options, g_i18n:getText("Revamp_SpawnType_"..possibilitie));
        end

        -- Dialogbox erstellen
        local dialogArguments = {
            text = g_i18n:getText("Revamp_ChooseSpawnToPutOut") .. " - " .. currentFillType.title .. " (" .. RevampHelper:formatVolume(selectedArg.fillLevel, 0, currentFillType.unitShort) .. ")",
            title = self.placable:getName(),
            options = options,
            target = self,
            args = selectableOptions,
            callback = self.spawnTypeSelected
        }

        --TODO: hack to reset the "remembered" option (i.e. solve a bug in the game engine)
        local dialog = g_gui.guis["OptionDialog"]
        if dialog ~= nil then
            dialog.target:setOptions({""}) -- Add fake option to force a "reset"
        end

        g_gui:showOptionDialog(dialogArguments)
        return;
    end	  
end

function PalletSiloActivatable:spawnTypeSelected(selectedOption, args)
    local selectedArg = args[selectedOption];
    if selectedArg == nil then return end
    
    if selectedArg.possibilitie == "bale" then
        self:chooseBaleAmount(self, selectedArg.fillLevel, selectedArg.fillType);
        return;
    elseif selectedArg.possibilitie == "woodLog" then
        self:chooseWoodLogAmount(self, selectedArg.fillLevel, selectedArg.fillType);
        return;
    else
        self:choosePalletAmount(self, selectedArg.fillLevel, selectedArg.fillType);
        return;
    end
end

function PalletSiloActivatable:chooseWoodLogAmount(self, availableFillLevel, fillType)
    -- wiviele stämme können erstellt werden?
    -- nur ganze stämme?
    local spec = self.placable.spec_SiloPalletSpawner
    local amountPerWoodLog = 1862; -- für spruce mit 6m
    local maxWoodLogs = Utils.getNoNil(math.floor(availableFillLevel / amountPerWoodLog), 0)
    
    if maxWoodLogs == 0 then
        return;
    end
    
    -- begrenzen auf maximal 15
    maxWoodLogs = math.min(maxWoodLogs, spec.maxWoodLogs);
    
    local selectableOptions = {}
    local options = {};
    
    -- Auswahl für jede menge die geht erstellen
    for i=1, maxWoodLogs do
        table.insert(selectableOptions, {amount=i, amountPerWoodLog=amountPerWoodLog, fillTypeIndex=fillType.index});
        table.insert(options, i .. " " .. g_i18n:getText("Revamp_WoodLogItem") .. " (" ..RevampHelper:formatVolume(amountPerWoodLog*i, 0, fillType.unitShort) .. ")");
    end

    -- Dialogbox erstellen
    local dialogArguments = {
        text = g_i18n:getText("Revamp_ChooseAmountToPutOut") .. " - " .. fillType.title .. " (" .. RevampHelper:formatVolume(availableFillLevel, 0, fillType.unitShort) .. ")",
        title = self.placable:getName(),
        options = options,
        target = self,
        args = selectableOptions,
        callback = self.woodLogsAmountSelected
    }

    --TODO: hack to reset the "remembered" option (i.e. solve a bug in the game engine)
    local dialog = g_gui.guis["OptionDialog"]
    if dialog ~= nil then
        dialog.target:setOptions({""}) -- Add fake option to force a "reset"
    end

    g_gui:showOptionDialog(dialogArguments)
end

function PalletSiloActivatable:woodLogsAmountSelected(selectedOption, args)
    local spec = self.placable.spec_SiloPalletSpawner

    local selectedArg = args[selectedOption];
    if selectedArg == nil then return end

    spec.pendingWoodLogs = selectedArg.amount;
    spec.amountPerWoodLog = selectedArg.amountPerWoodLog;
    spec.fillTypeIndex = selectedArg.fillTypeIndex;
    
    
-- print("spec.palletSpawner")
-- DebugUtil.printTableRecursively(spec.palletSpawner,"_",0,2)
    
    if self.isServer then
        self:spawnWoodLogs(self);
    else
        RevampSpawnWoodLogsAtSiloEvent.sendEvent(self.placable, spec.pendingWoodLogs, spec.amountPerWoodLog, spec.fillTypeIndex)
        
        -- Im multiplayer die lokale sperre wieder raus nehmen, sonst kann jeder user nur ein mal spawnen. 
        -- Somit könnte nehrfach gespawned werden im MP. Ich denke aktuell nicht das es ein Problem ist
        spec.pendingWoodLogs = nil;
    end
end

function PalletSiloActivatable:spawnWoodLogs()
    if self.isServer then
        local spec = self.placable.spec_SiloPalletSpawner
        
        -- hier könnte auf platz geprüft werden, das hat aber nicht funktioniert
        local useSpawnPlace = spec.woodSpawnPlace;
        
        if useSpawnPlace == nil then
            return;
        end
        
        -- einen stamm auslagern, spruce hat max länge 6m und dabei 1862 holz
        local treeTypeName = "SPRUCE1"
        local treeTypeDesc = g_treePlantManager:getTreeTypeDescFromName(treeTypeName)
        local treeType = treeTypeDesc.index;
        
        -- spawnpunkt aus der xml
        local x, y, z = getWorldTranslation(useSpawnPlace)
        local dirX, dirY, dirZ = localDirectionToWorld(useSpawnPlace, 0, 0, 1)
        
        local length = 6
        local growthState = #treeTypeDesc.treeFilenames
        
        local spawned = PalletSiloActivatable:spawnLog(self, treeTypeDesc.index, length, growthState, x, y, z, dirX, dirY, dirZ)
        if spawned then
            spec.pendingWoodLogs = spec.pendingWoodLogs - 1;
            if spec.pendingWoodLogs == 0 then
                spec.pendingWoodLogs = nil;
            end
            
            -- Filllevel aus Silo abziehen
            local delta = spec.amountPerWoodLog;
            for _, storage in ipairs(self.placable.spec_silo.storages) do
                local available = storage.fillLevels[spec.fillTypeIndex];
                if available ~= nil and available > 0 then
                    local moved = math.min(delta, available);
                    storage:setFillLevel(available - moved, spec.fillTypeIndex);

                    delta = delta - moved;
                end

                if delta <= 0.001 then
                    break;
                end
            end
        else
            -- wenn nichts ging, dann abbrechen
            spec.pendingWoodLogs = nil;
        end        
        
        -- mit timer so lange aufrufen bis alles weg ist
        if spec.pendingWoodLogs ~= nil and spec.pendingWoodLogs > 0 then
            
            self.woodLogTimer = Timer.new(400)
            self.woodLogTimer:setFinishCallback(
                function()
                    self:spawnWoodLogs()
                end)
            self.woodLogTimer:start(true)
        end
    end
end

-- Add Log from EasyDevControls and then reworked to make them stay on save
function PalletSiloActivatable:spawnLog(self, treeType, length, growthState, x, y, z, dirX, dirY, dirZ)
    if treeType == nil or x == nil or y == nil or z == nil then
        return false;
    end

    local treeTypeDesc = g_treePlantManager:getTreeTypeDescFromIndex(treeType)

    if treeTypeDesc == nil or #treeTypeDesc.treeFilenames <= 1 then
        return false;
    end

    length = math.min(math.max((length or 1), 1), 8);
    growthState = math.min(math.max((growthState or 1), 0), 1);

    if self.isServer then
        
    
        local title = g_i18n:getText(treeTypeDesc.nameI18N, g_currentMission.baseDirectory);

        local growthStateI = math.floor(growthState * (#treeTypeDesc.treeFilenames - 1)) + 1
        local treeId, splitShapeFileId = g_treePlantManager:loadTreeNode(treeTypeDesc, x, y, z, 0, 0, 0, growthStateI)

        if getFileIdHasSplitShapes(splitShapeFileId) then
            table.insert(g_treePlantManager.treesData.splitTrees, {
                x = x,
                y = y,
                z = z,
                rx = 0,
                ry = 0,
                rz = 0,
                node = treeId,
                treeType = treeType,
                growthState = growthState,
                splitShapeFileId = splitShapeFileId,
                hasSplitShapes = true
            })

            g_server:broadcastEvent(TreePlantEvent.new(treeType, x, y, z, 0, 0, 0, growthState, splitShapeFileId, false))

            g_treePlantManager.loadTreeTrunkData = {
                x = x,
                y = y,
                z = z,
                dirX = dirX,
                dirY = dirY,
                dirZ = dirZ,
                offset = 0.5,
                framesLeft = 2,
                length = length,
                dataAdded = false,
                shape = treeId + 2
            }

        else
            delete(treeId)

            return false;
        end

        return true;
    end
end

function PalletSiloActivatable:chooseBaleAmount(self, availableFillLevel, fillType)
    local baleType = self.baleTypes[fillType.name]
    local selectableOptions = {}
    local options = {};

    -- BallenVarianten in Optionsliste eintragen mit den entsprechenden Daten, Options = AnzeigeName, selectableObtion = Übermittelte Werte
    for index, baleSize in ipairs(baleType.sizes) do
        local title
        if baleSize.isRoundbale then
            title = g_i18n:getText("fillType_roundBale") .. " " .. tostring(baleSize.diameter) .. "m (" .. tostring(baleSize.capacity) .. "L)"
        else
            title = g_i18n:getText("fillType_squareBale") .. " " .. tostring(baleSize.length) .. "m (" .. tostring(baleSize.capacity) .. "L)"
        end
        table.insert(selectableOptions, {fillTypeIndex=fillType.index, baleSize=baleSize, fillLevel=availableFillLevel});
        table.insert(options, title);
    end

    -- Dialogbox erstellen welcher Ballen ausgelagert werden soll
    local dialogArguments = {
        text = g_i18n:getText("Revamp_ChooseBaleType") .. " - " .. fillType.title .. " (" .. RevampHelper:formatVolume(availableFillLevel, 0, fillType.unitShort) .. ")",
        title = self.placable:getName(),
        options = options,
        target = self,
        args = selectableOptions,
        callback = self.baleSelected
    }

    --TODO: hack to reset the "remembered" option (i.e. solve a bug in the game engine)
    local dialog = g_gui.guis["OptionDialog"]
    if dialog ~= nil then
        dialog.target:setOptions({""}) -- Add fake option to force a "reset"
    end

    g_gui:showOptionDialog(dialogArguments)
end

function PalletSiloActivatable:baleSelected(selectedOption, args)
    local spec = self.placable.spec_SiloPalletSpawner

    --Parameter auslesen
    local selectedArg = args[selectedOption];
    if selectedArg == nil then return end
    local fillTypeIndex = selectedArg.fillTypeIndex;
    local baleSize = selectedArg.baleSize;
    local size = selectedArg.baleSize;
    local amountPerBale = size.capacity


    -- Werte für spawner definieren
    spec.fillTypeIndex = fillTypeIndex;
    spec.fillUnitIndex = 1;
    spec.pendingLiters = selectedArg.fillLevel;
    
    -- Berechnen der maximalen Ballenanzahl
    local maxBales = math.floor(selectedArg.fillLevel / amountPerBale)
    if ((selectedArg.fillLevel - (maxBales*amountPerBale)) >= 1) then
        maxBales = maxBales + 1;
    end
    
    if(maxBales == 0) then return end
    
    local currentFillType = g_fillTypeManager:getFillTypeByIndex(fillTypeIndex)
    
    -- Auswählbare Ballenanzahl in Liste eintragen
    local selectableOptions = {}
    local options = {};
    for i=1, maxBales do
        table.insert(selectableOptions, {amount=i, amountPerPallet=amountPerBale, fillTypeIndex=fillTypeIndex, baleSize=baleSize});
        table.insert(options, i .. " " .. g_i18n:getText("Revamp_BaleSiloItem") .. " (" ..RevampHelper:formatVolume(math.min(amountPerBale*i, spec.pendingLiters), 0, currentFillType.unitShort) .. ")");
    end
    
    -- Dialog Optionen Anlegen
    local dialogArguments = {
        text = g_i18n:getText("Revamp_ChooseAmountToPutOut") .. " - " .. currentFillType.title .. " (" .. RevampHelper:formatVolume(selectedArg.fillLevel, 0, currentFillType.unitShort) .. ")",
        title = self.placable:getName(),
        options = options,
        target = self,
        args = selectableOptions,
        callback = self.spawnBales
    }
    
    --TODO: hack to reset the "remembered" option (i.e. solve a bug in the game engine)
    local dialog = g_gui.guis["OptionDialog"]
    if dialog ~= nil then
        dialog.target:setOptions({""}) -- Add fake option to force a "reset"
    end

    g_gui:showQuickAmountDialog(dialogArguments)
end

function PalletSiloActivatable:choosePalletAmount(self, availableFillLevel, fillType)
    local spec = self.placable.spec_SiloPalletSpawner
    
    -- Werte für Spawner definieren
    spec.fillTypeIndex = fillType.index;
    spec.fillUnitIndex = 1;
    spec.pendingLiters = availableFillLevel;

    -- Berechnen der maximalen Palettenanzahl
    local amountPerPallet = spec.palletSpawner.fillTypeIdToPallet[spec.fillTypeIndex].capacity;
    local maxPallets = math.floor(availableFillLevel / amountPerPallet)
    if ((availableFillLevel - (maxPallets*amountPerPallet)) >= 1) then
        maxPallets = maxPallets + 1;
    end

    if(maxPallets == 0) then return end

    --Auswählbare Palettenanzahl in Liste eintragen
    local selectableOptions = {}
    local options = {};
    for i=1, maxPallets do
        table.insert(selectableOptions, {amount=i, amountPerPallet=amountPerPallet});
        table.insert(options, i .. " " .. g_i18n:getText("Revamp_PalletSiloItem") .. " (" ..RevampHelper:formatVolume(math.min(amountPerPallet * i, spec.pendingLiters), 0, fillType.unitShort) .. ")");
    end

    -- Wählen wieviel ausgelagert werden soll.
    local dialogArguments = {
        text = g_i18n:getText("Revamp_ChooseAmountToPutOut") .. " - " .. fillType.title .. " (" .. RevampHelper:formatVolume(availableFillLevel, 0, fillType.unitShort) .. ")",
        title = self.placable:getName(),
        options = options,
        target = self,
        args = selectableOptions,
        callback = self.amountSelected
    }

    --TODO: hack to reset the "remembered" option (i.e. solve a bug in the game engine)
    local dialog = g_gui.guis["OptionDialog"]
    if dialog ~= nil then
        dialog.target:setOptions({""}) -- Add fake option to force a "reset"
    end

    g_gui:showQuickAmountDialog(dialogArguments)
end

function PalletSiloActivatable:amountSelected(selectedOption, args)
    local spec = self.placable.spec_SiloPalletSpawner

    -- anzahl möglicher palleten für eine neue Auswahl
    local selectedArg = args[selectedOption];
    if selectedArg == nil then return end
    local totalAmount = selectedArg.amount * selectedArg.amountPerPallet;
    
    -- todo: Anzahl paletten wählen
    spec.pendingLiters = math.min(spec.pendingLiters, totalAmount);
    
    SpawnPalletsAtSiloEvent.sendEvent(self.placable, self.placable.ownerFarmId, spec.fillUnitIndex, spec.pendingLiters, spec.fillTypeIndex, false, false, 0, 0, 0, 0, 0, false)
    
end

function PalletSiloActivatable:spawnBales(selectedOption, args)
    local spec = self.placable.spec_SiloPalletSpawner

    -- Anzahl möglicher Ballen für eine neue Auswahl
    local selectedArg = args[selectedOption];
    if selectedArg == nil then return end

    --EntnahmeMenge berechnen
    local baleSize = selectedArg.baleSize;
    local totalAmount = selectedArg.amount * baleSize.capacity;
    
    spec.pendingLiters = math.min(spec.pendingLiters, totalAmount);
    
    --Damit das gesammt FillVolume ausgelager werden kann, überprüfen ob der Ballen größer ist als der restliche Inhalt und anpassen
    if spec.pendingLiters < selectedArg.baleSize.capacity then
        spec.capacity = spec.pendingLiters
    else
        spec.capacity = selectedArg.baleSize.capacity
    end

    SpawnPalletsAtSiloEvent.sendEvent(self.placable, self.placable.ownerFarmId, spec.fillUnitIndex, spec.pendingLiters, spec.fillTypeIndex, true, baleSize.isRoundbale, baleSize.width, baleSize.height, baleSize.length, baleSize.diameter, spec.capacity, baleSize.wrapState, baleSize.customEnvironment)
    
end

function PalletSiloActivatable:getPalletCallback(pallet, result, fillTypeIndex)
    local spec = self.placable.spec_SiloPalletSpawner
    spec.spawnPending = false
    if pallet ~= nil then
		local delta = 0
		--Nur ausführen sollte es eine Palette sein
		if pallet.isBale == nil then
          if result == PalletSpawner.RESULT_SUCCESS then
              pallet:emptyAllFillUnits(true)
          end

          delta = pallet:addFillUnitFillLevel(self.placable.ownerFarmId, spec.fillUnitIndex, spec.pendingLiters, fillTypeIndex, ToolType.UNDEFINED)
          spec.pendingLiters = math.max(spec.pendingLiters - delta, 0)
		else
		  --Ausführen um FillVolume aus Silo entfernen zu können
		  delta = pallet.capacity
		  spec.pendingLiters = math.max(spec.pendingLiters - delta, 0)
		end
        
        -- Filllevel aus Silo abziehen
        for _, storage in ipairs(self.placable.spec_silo.storages) do
            local available = storage.fillLevels[fillTypeIndex];
            if available ~= nil and available > 0 then
                local moved = math.min(delta, available)
                storage:setFillLevel(available - moved, fillTypeIndex)

                delta = delta - moved
            end

            if delta <= 0.001 then
                break
            end
        end
        
        if spec.pendingLiters > 5 then
		    --Damit das gesammt FillVolume ausgelager werden kann, überprüfen ob der Ballen größer ist als der restliche Inhalt und anpassen
			if pallet.isBale and spec.pendingLiters < pallet.capacity then
			  pallet.capacity = spec.pendingLiters
			end
            self:updatePallets(pallet)
        end
    end
end

--Production Revamp: CallBack für den Timer
function PalletSiloActivatable:TimerCallback()
    local spec = self.placable.spec_SiloPalletSpawner
    if self.isbale == nil then
        spec.palletSpawner:spawnPallet(self.placable.ownerFarmId, spec.fillTypeIndex, self.getPalletCallback, self)
    else
        local bale = self.bale
        spec.palletSpawner:spawnPallet(self.placable.ownerFarmId, spec.fillTypeIndex, self.getPalletCallback, self, bale.isBale, bale.isRoundbale, bale.width, bale.height, bale.length, bale.diameter, bale.capacity, bale.wrapState, bale.customEnvironment, spec.wrapColor)
    end
end

function PalletSiloActivatable:updatePallets(bale)
    if self.isServer then
        local spec = self.placable.spec_SiloPalletSpawner
        if not spec.spawnPending and spec.pendingLiters > 5 then
            spec.spawnPending = true
            if bale.isBale == nil then
                self.isbale = nil
                self.palletTimer = Timer.new(200)
                self.palletTimer:setFinishCallback(
                    function()
                        self:TimerCallback()
                    end)
                self.palletTimer:start(true)
            else
                self.isbale = true
                self.bale = bale
                self.palletTimer = Timer.new(200)
                self.palletTimer:setFinishCallback(
                    function()
                        self:TimerCallback()
                    end)
                self.palletTimer:start(true)
            end
        end
    end
end

function SiloPalletSpawnerSpecialization.prerequisitesPresent(specializations)
    return true
end

---
function SiloPalletSpawnerSpecialization.initSpecialization()    
    local schema = Placeable.xmlSchema
    schema:setXMLSpecializationType("SiloPalletSpawnerSpecialization")
    
    local baseXmlPath = "placeable.aPalletSilo"
    
    schema:register(XMLValueType.STRING, baseXmlPath .. "#wrapColor", "Silage Bale Wraping Color", "0.6662 0.3839 0.5481 1")
    schema:register(XMLValueType.NODE_INDEX, baseXmlPath .. "#triggerNode", "Trigger node for access menu")
    schema:register(XMLValueType.NODE_INDEX, baseXmlPath .. "#woodSpawnPlace", "Place to spawn wood logs. No collision is checked, be carefull")
    schema:register(XMLValueType.INT, baseXmlPath .. "#maxWoodLogs", "max wood logs to spawn at one call. No collision is checked, be carefull", 15)
    PalletSpawner.registerXMLPaths(schema, baseXmlPath .. ".palletSpawner")

    schema:setXMLSpecializationType()
    
    PlaceableSilo.INFO_TRIGGER_NUM_DISPLAYED_FILLTYPES = 25;
end

---
function SiloPalletSpawnerSpecialization.registerFunctions(placeableType)
    SpecializationUtil.registerFunction(placeableType, "onTriggerNodeCallback", SiloPalletSpawnerSpecialization.onTriggerNodeCallback)
end

---
function SiloPalletSpawnerSpecialization.registerOverwrittenFunctions(placeableType)
end

---
function SiloPalletSpawnerSpecialization.registerEventListeners(placeableType)
    SpecializationUtil.registerEventListener(placeableType, "onLoad", SiloPalletSpawnerSpecialization)
    SpecializationUtil.registerEventListener(placeableType, "onDelete", SiloPalletSpawnerSpecialization)
    SpecializationUtil.registerEventListener(placeableType, "onFinalizePlacement", SiloPalletSpawnerSpecialization)
    SpecializationUtil.registerEventListener(placeableType, "onRegisterActionEvents", SiloPalletSpawnerSpecialization)
end

---
function SiloPalletSpawnerSpecialization:onRegisterActionEvents(isActiveForInput, isActiveForInputIgnoreSelection)
end

---Called on loading
-- @param table savegame savegame
function SiloPalletSpawnerSpecialization:onLoad(savegame)

    -- hier für server und client
    self.spec_SiloPalletSpawner = {}
    local spec = self.spec_SiloPalletSpawner
    spec.available = false;
    
    local baseXmlPath = "placeable.aPalletSilo"
    
	if not self.xmlFile:hasProperty(baseXmlPath) then
		return;
	end
    
    spec.triggerNode = self.xmlFile:getValue(baseXmlPath.."#triggerNode", nil, self.components, self.i3dMappings);
    if spec.triggerNode ~= nil then
        if not CollisionFlag.getHasFlagSet(spec.triggerNode, CollisionFlag.TRIGGER_PLAYER) then
            Logging.xmlWarning(self.xmlFile, "Info trigger collison mask is missing bit 'TRIGGER_PLAYER' (%d)", CollisionFlag.getBit(CollisionFlag.TRIGGER_PLAYER))
        end
    end
    
    spec.woodSpawnPlace = self.xmlFile:getValue(baseXmlPath.."#woodSpawnPlace", nil, self.components, self.i3dMappings);
    spec.maxWoodLogs = self.xmlFile:getValue(baseXmlPath .. "#maxWoodLogs") or 15;
    spec.wrapColor = self.xmlFile:getValue(baseXmlPath.."#wrapColor", "0.6662 0.3839 0.5481 1")
    spec.activatable = PalletSiloActivatable.new(self, self.isServer)
        
    spec.palletSpawner = PalletSpawner.new()
    spec.palletSpawner:load(self.components, self.xmlFile, baseXmlPath .. ".palletSpawner", self.customEnvironment, self.i3dMappings)
        
    function spec.palletSpawner:spawnPallet(farmId, fillTypeId, callback, callbackTarget, isBale, isRoundbale, width, height, length, diameter, capacity, wrapState, customEnvironment, wrapColor)
        local pallet = nil
        if isBale then
          --Ballen Daten laden
          local baleXMLFilename = g_baleManager:getBaleXMLFilename(fillTypeId, isRoundbale, width, height, length, diameter, customEnvironment)

          --Ballen Abmessung hinterlegen für Spawncheck
          local size = {}
          local fillType = g_fillTypeManager:getFillTypeByIndex(fillTypeId)
          size.height = height
          if isRoundbale then
            --Maße vom Rundballen hinterlegen
            size.width = diameter
            size.length = diameter
          elseif fillType.name == "COTTON" then
            --Maße vom Cotton Quaderballen drehen für den Spawnbereich, damit dieser Spawnen kann
            size.width = length
            size.length = width
          else
            --Maße von Quaderballen hinterlegen
            size.width = width
            size.length = length	    
          end
          
          --Fake Palette anlegen, damit der Spawner weiterhin funktioniert
          pallet = {}
          pallet.filename = baleXMLFilename
          pallet.size = size
          pallet.capacity = capacity
          pallet.isBale = true
          pallet.isRoundbale = isRoundbale
          pallet.wrapState = wrapState
          pallet.width = width
          pallet.height = height
          pallet.length = length
          pallet.diameter = diameter
          pallet.customEnvironment = customEnvironment
          pallet.wrapColor = spec.wrapColor
          
        else
          pallet = spec.palletSpawner.fillTypeIdToPallet[fillTypeId]
        end

        if pallet ~= nil then
            table.insert(spec.palletSpawner.spawnQueue, {
                pallet = pallet,
                fillType = fillTypeId,
                farmId = farmId,
                callback = callback,
                callbackTarget = callbackTarget
            })
            g_currentMission:addUpdateable(spec.palletSpawner)

        else
            Logging.devError("PalletSpawner: no pallet for fillTypeId", fillTypeId)
            callback(callbackTarget, nil, PalletSpawner.NO_PALLET_FOR_FILLTYPE, fillTypeId)
        end
    end
    
    function spec.palletSpawner:onSpawnSearchFinished(location)
        local objectToSpawn = spec.palletSpawner.currentObjectToSpawn
        if location ~= nil then
            location.y = location.y + 0.25
            if objectToSpawn.pallet.isBale == nil then
              --Normaler PalettenSpawner
              VehicleLoadingUtil.loadVehicle(objectToSpawn.pallet.filename, location, true, 0, Vehicle.PROPERTY_STATE_OWNED, objectToSpawn.farmId, nil, nil, spec.palletSpawner.onFinishLoadingPallet, spec.palletSpawner)
            else
              --Ballen Spawner
              local baleObject = Bale.new(g_currentMission:getIsServer(), g_currentMission:getIsClient())
              if objectToSpawn.pallet.isRoundbale then
                --Rundballen auf die Seite drehen, damit diese nicht wegrollen
                location.xRot = location.xRot + (3.1415927 / 2)
              end
              local fillType = g_fillTypeManager:getFillTypeByIndex(objectToSpawn.fillType)
              if fillType.name == "COTTON" then
                --Cotton Quaderballen drehen, damit diese in den Spawnbereich passen
                location.yRot = location.yRot + (3.1415927 / 2)
                --Cotton Quaderballen zusätzliche 0,25m nach oben verschieben
                location.y = location.y + 1.30
              end
                if baleObject:loadFromConfigXML(objectToSpawn.pallet.filename, location.x, location.y, location.z, location.xRot, location.yRot, location.zRot) then
                    baleObject:setFillType(objectToSpawn.fillType, true)
                    baleObject:setOwnerFarmId(objectToSpawn.farmId, true)
                    baleObject:setFillLevel(objectToSpawn.pallet.capacity, true)
                    if objectToSpawn.pallet.wrapState then
                      --SilageBallen eingewickelt Spawnen
                      baleObject:setWrappingState(1)
                      local colors = RevampHelper.UnpackWrapColor(spec.wrapColor)
                      baleObject:setColor(colors[1], colors[2], colors[3], colors[4])
                    end
                    baleObject:register()
                    --Manueller Callback
                    objectToSpawn.callback(objectToSpawn.callbackTarget, objectToSpawn.pallet, PalletSpawner.RESULT_SUCCESS, objectToSpawn.fillType)
                    spec.palletSpawner.currentObjectToSpawn = nil
                    table.remove(spec.palletSpawner.spawnQueue, 1)
                else
                    print("SiloPalletSpawnerSpecialization: Could not spawn bale object")
                end
            end
        else
            objectToSpawn.callback(objectToSpawn.callbackTarget, nil, PalletSpawner.RESULT_NO_SPACE)

            spec.palletSpawner.currentObjectToSpawn = nil

            table.remove(spec.palletSpawner.spawnQueue, 1)
        end
    end
        
    if self.spec_silo ~= nil then
        if self.spec_silo.unloadingStation ~= nil then
            if self.spec_silo.unloadingStation.unloadTriggers ~= nil then
                for _, unloadTrigger in pairs(self.spec_silo.unloadingStation.unloadTriggers) do
                    if unloadTrigger.woodTrigger ~= nil then
                        unloadTrigger.woodTrigger.activatable.activateText = g_i18n:getText("Revamp_storeWoodlogs")
                    end
                end
            end
        end
    end
    
    spec.initialized = true;
end

---
function SiloPalletSpawnerSpecialization:onDelete()
    local spec = self.spec_SiloPalletSpawner

    if spec.triggerNode ~= nil then
        removeTrigger(spec.triggerNode)
        spec.triggerNode = nil
    end
end
---
function SiloPalletSpawnerSpecialization:onFinalizePlacement()
    local spec = self.spec_SiloPalletSpawner
    if spec.triggerNode ~= nil then
        addTrigger(spec.triggerNode, "onTriggerNodeCallback", self)
    end
end

---
function SiloPalletSpawnerSpecialization:onTriggerNodeCallback(triggerId, otherId, onEnter, onLeave, onStay)
    local spec = self.spec_SiloPalletSpawner
    if g_currentMission.player ~= nil and otherId == g_currentMission.player.rootNode then

        if onEnter then
            g_currentMission.activatableObjectsSystem:addActivatable(spec.activatable)
        else
            g_currentMission.activatableObjectsSystem:removeActivatable(spec.activatable)
        end
    end
end