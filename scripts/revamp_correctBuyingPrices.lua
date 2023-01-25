--[[
Production Revamp
Change the buying prices accordingly to the economic dificulty

Copyright (C) Achimobil, 2022

Author: Achimobil
]]

RevampCorrectBuyingPrices = {}

--- Original from Source 1.3.0.0
function RevampCorrectBuyingPrices:getEffectiveFillTypePrice(superFunc, fillTypeIndex)
  if not RevampSettings.current.PriceCorrectionActive then
    return superFunc(self, fillTypeIndex);
  end

	local fillType = g_fillTypeManager:getFillTypeByIndex(fillTypeIndex)
	local pricePerLiter = self.fillTypePricesScale[fillTypeIndex] * fillType.pricePerLiter * EconomyManager.getPriceMultiplier()

	return pricePerLiter
end
BuyingStation.getEffectiveFillTypePrice = Utils.overwrittenFunction(BuyingStation.getEffectiveFillTypePrice, RevampCorrectBuyingPrices.getEffectiveFillTypePrice)