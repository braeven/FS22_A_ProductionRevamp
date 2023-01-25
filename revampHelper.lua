--[[
Production Revamp
Helper File

Copyright (C) Achimobil, braeven, 2022

Date: 23.10.2022
Version: 1.1.2.0

Contact/Help/Tutorials:
discord.gg/gHmnFZAypk


Important:.
No changes are allowed to this script without permission from Achimobil AND Braeven.
If you want to make a production with this script, look in the discord channels for tutorials/help or download the FS22_Revamp_Productions Pack for reference
Don't copy the script into a production, load the mod as a dependency!

Es dürfen an diesem Script keine Veränderungen ohne Erlaubnis von Achimobil UND Braeven gemacht werden.
Wenn du eine Produktion mit diesem Script bauen möchtest, lese dir die angepinnten Tutorials im Discord durch oder guck dir die FS22_Revamp_Productions an.
Nicht das Script in Produktionen kopieren, ladet den Mod über eine Dependency!

]]


RevampHelper = {};
RevampHelper.name = g_currentModName;
RevampHelper.modDir = g_currentModDirectory;


function RevampHelper:formatVolume(liters, precision, unit)
    if unit == "" then
        unit = nil;
    end
    
    return g_i18n:formatVolume(liters, precision, unit)
end

function RevampHelper:formatCapacity(liters, capacity, precision, unit)
    if unit == "" then
        unit = nil;
    end

    return g_i18n:formatVolume(liters, precision, "") .. " / " .. g_i18n:formatVolume(capacity, precision, unit);
end

function RevampHelper:GetBaleTypes()
    local baleTypes = { }

    -- Ballenliste erstellen in Abhängig vom Filltype, mögliche Ballen werden in Size hinterlegt als weitere Liste
    for index, baleType in ipairs(g_baleManager.bales) do

        --Sollte ein Ballen den Flag isAvaible auf false haben ist er für eine Karte deaktiviert, wie z.B. der packedsquareBale120/Multibale
        if baleType.isAvailable then
            for index, baleFillType in ipairs(baleType.fillTypes) do
                local fillType = g_fillTypeManager:getFillTypeByIndex(baleFillType.fillTypeIndex)
                local fillTypeName = fillType.name

                --BallenTypen in Abhängigkeit vom Filltype
                baleTypes[fillTypeName] = baleTypes[fillTypeName] or {
                    fillTypeIndex = baleFillType.fillTypeIndex,
                    fillTypeTitle = fillType.title,
                    fillTypeName = fillTypeName,
                    sizes = {},
                }

                local baleSizes = baleTypes[fillTypeName].sizes
                
                --Mögliche Ballenformate
                baleSizes[#baleSizes + 1] = {
                    isRoundbale = baleType.isRoundbale,
                    diameter = baleType.diameter,
                    width = baleType.width,
                    height = baleType.height,
                    length = baleType.length,
                    capacity = baleFillType.capacity,
                    customEnvironment = baleType.customEnvironment,
                    wrapState = true and (fillTypeName:upper() == "SILAGE" or fillTypeName:upper() == "GRASS_FERMENTED" or fillTypeName:upper() == "CHOPPEDMAIZE_FERMENTED")
                }
            end
        end
    end
    
    -- noch nach größe sortieren
    for _, baleType in pairs(baleTypes) do
        table.sort(baleType.sizes, RevampHelper.compBaleSizes);
    end

    return baleTypes
end

function RevampHelper.compBaleSizes(baleSize1,baleSize2)
    if baleSize1.isRoundbale == baleSize2.isRoundbale then
        if baleSize1.isRoundbale then
            return baleSize1.diameter < baleSize2.diameter;
        else
            return baleSize1.length < baleSize2.length;
        end
        
    end
    return baleSize1.isRoundbale;
end

function RevampHelper.UnpackWrapColor(wrapColor)
  if wrapColor == "random" then
    local color = {}
    local color = RevampHelper.RandomColor()
    return color
  else
    local testColor = g_brandColorManager:getBrandColorByName(wrapColor)
    if testColor ~= nil then
      return testColor
    else
      local uColors = string.split(wrapColor, " ")
      local color = {}
      color[1] = tonumber(uColors[1])
      color[2] = tonumber(uColors[2])
      color[3] = tonumber(uColors[3])
      color[4] = tonumber(uColors[4])
      if color[1] > 1 then
        color[1] = 1
      end
      if color[2] > 1 then
        color[2] = 1
      end
      if color[3] > 1 then
        color[3] = 1
      end    
      return color
    end
  end
end

function RevampHelper.RandomColor()
  local colorOptions = {'AMAZONE_BLUE3', 'AMAZONE_GREEN1', 'AMAZONE_ORANGE1', 'AMAZONE_RED1', 'AMAZONE_YELLOW1', 'AGCO_GREY1', 'LIZARD_BLUE1', 'LIZARD_OLIVE1', 'LIZARD_PINK1', 'LIZARD_PURPLE1', 'LIZARD_RED1', 'SHARED_BLACK0', 'SHARED_BLACKJET', 'SHARED_BLACKONYX', 'SHARED_BLUE1', 'SHARED_BLUENAVY', 'SHARED_BROWN', 'SHARED_GREYDARK', 'SHARED_GREYLIGHT', 'SHARED_REDCRIMSON', 'SHARED_SILVER', 'SHARED_WRAP_BLACK', 'SHARED_WRAP_BLUE', 'SHARED_WRAP_GREEN', 'SHARED_WRAP_PINK', 'SHARED_WRAP_WHITE', 'SHARED_YELLOW1', 'CLAAS_DARKGREY2', 'CLAAS_GREEN1', 'CLAAS_RED1', 'FENDT_DARKGREEN1', 'FENDT_NEWGREEN1', 'GOLDHOFER_BLUE', 'LEMKEN_BLUE1', 'MASSEYFERGUSON_RED', 'JCB_YELLOW1', 'SCHOUTEN_ORANGE1', 'JOHNDEERE_GREEN1', 'JOHNDEERE_YELLOW1', 'MCCORMACK_RED1'}
  local number = math.random(1, #colorOptions)
  local randomColor = colorOptions[number]
  color = g_brandColorManager:getBrandColorByName(randomColor)
  return color
end