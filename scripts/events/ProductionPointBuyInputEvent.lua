--[[
Part of Production Revamp

Copyright (C) braeven & Achimobil 2022

Author: braeven

Version: 1.1.0.0
Date: 22.08.2022
]]

ProductionPointBuyInputEvent = {}
local ProductionPointBuyInputEvent_mt = Class(ProductionPointBuyInputEvent, Event)

InitEventClass(ProductionPointBuyInputEvent, "ProductionPointBuyInputEvent")

function ProductionPointBuyInputEvent.emptyNew()
	local self = Event.new(ProductionPointBuyInputEvent_mt)

	return self
end

function ProductionPointBuyInputEvent.new(productionPoint, fillType, buyVolume, price)
	local self = ProductionPointBuyInputEvent.emptyNew()
	self.productionPoint = productionPoint
	self.fillType = fillType
	self.buyVolume = buyVolume
	self.price = price

	return self
end

function ProductionPointBuyInputEvent:readStream(streamId, connection)
	self.productionPoint = NetworkUtil.readNodeObject(streamId)
	self.fillType = streamReadInt32(streamId)
	self.buyVolume = streamReadInt32(streamId)
	self.price = streamReadInt32(streamId)

	self:run(connection)
end

function ProductionPointBuyInputEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.productionPoint)
	streamWriteInt32(streamId, self.fillType)
	streamWriteInt32(streamId, self.buyVolume)
	streamWriteInt32(streamId, self.price)
end

function ProductionPointBuyInputEvent:run(connection)
	if not connection:getIsServer() then
		g_server:broadcastEvent(self, false, connection)
	end

	if self.productionPoint ~= nil then
		self.productionPoint:buyInput(self.fillType, self.buyVolume, self.price, true)
	end
end

function ProductionPointBuyInputEvent.sendEvent(productionPoint, fillType, buyVolume, price, noEventSend)
	if noEventSend == nil or noEventSend == false then
		if g_server ~= nil then
			g_server:broadcastEvent(ProductionPointBuyInputEvent.new(productionPoint, fillType, buyVolume, price))
		else
			g_client:getServerConnection():sendEvent(ProductionPointBuyInputEvent.new(productionPoint, fillType, buyVolume, price))
		end
	end
end
