--[[
Production Revamp
Change the buying prices accordingly to the economic dificulty

Copyright (C) Achimobil, 2022

Author: Achimobil
]]

RevampCorrectBuyingPrices = {}



function RevampCorrectBuyingPrices:getEffectiveFillTypePrice(superFunc, fillTypeIndex)
	if not RevampSettings.current.PriceCorrectionActive then
		return superFunc(self, fillTypeIndex)
	end

	local fillType = g_fillTypeManager:getFillTypeByIndex(fillTypeIndex)
	local pricePerLiter = self.fillTypePricesScale[fillTypeIndex] * fillType.pricePerLiter * EconomyManager.getPriceMultiplier()

	return pricePerLiter
end

BuyingStation.getEffectiveFillTypePrice = Utils.overwrittenFunction(BuyingStation.getEffectiveFillTypePrice, RevampCorrectBuyingPrices.getEffectiveFillTypePrice)



function RevampCorrectBuyingPrices:updateFillAmounts(superFunc)
	if not RevampSettings.current.PriceCorrectionActive then
		return superFunc(self, fillTypeIndex)
	end

	local fillAmountTexts = {}
	local fillAmounts = self.fillTypeAmountMapping[self.selectedFillType]
	self.amountMapping = {}
	self.priceMapping = {}
	local fillType = g_fillTypeManager:getFillTypeByIndex(self.selectedFillType)
	local litersText = g_i18n:getText("unit_liter")

	for _, fillAmount in ipairs(fillAmounts) do
		local pricePerLiter = fillType.pricePerLiter * self.priceFactor * EconomyManager.getPriceMultiplier()
		local price = pricePerLiter * fillAmount
		local priceStr = g_i18n:formatMoney(price)
		local text = string.format("%d %s (%s)", fillAmount, litersText, priceStr)

		table.insert(fillAmountTexts, text)
		table.insert(self.amountMapping, fillAmount)
		table.insert(self.priceMapping, price)
	end

	self.fillAmountsElement:setTexts(fillAmountTexts)
	self.fillAmountsElement:setState(#fillAmountTexts, true)
	self:setButtonDisabled(#fillAmounts == 0)
	self.fillAmountsElement:setDisabled(#fillAmounts == 0)

	if #fillAmounts == 0 then
		self.fillAmountText:setText("-")
	end

	if self.fillTypesElement.disabled and not self.fillAmountsElement.disabled then
		FocusManager:unsetFocus(self.fillAmountsElement)
		FocusManager:setFocus(self.fillAmountsElement)
	end
end

RefillDialog.updateFillAmounts = Utils.overwrittenFunction(RefillDialog.updateFillAmounts, RevampCorrectBuyingPrices.updateFillAmounts)