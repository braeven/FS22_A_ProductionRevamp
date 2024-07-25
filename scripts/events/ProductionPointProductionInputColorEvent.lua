--[[
Part of Production Revamp

Copyright (C) braeven & Achimobil 2022

Author: braeven

Version: 1.1.0.0
Date: 22.08.2022
]]


ProductionPointProductionInputColorEvent = {}
local ProductionPointProductionInputColorEvent_mt = Class(ProductionPointProductionInputColorEvent, Event)

InitEventClass(ProductionPointProductionInputColorEvent, "ProductionPointProductionInputColorEvent")

function ProductionPointProductionInputColorEvent.emptyNew()
	local self = Event.new(ProductionPointProductionInputColorEvent_mt)

	return self
end

function ProductionPointProductionInputColorEvent.new(productionPoint, productionId, inputId, color)
	local self = ProductionPointProductionInputColorEvent.emptyNew()
	self.productionPoint = productionPoint
	self.productionId = productionId
	self.inputId = inputId
	self.color = color

	return self
end

function ProductionPointProductionInputColorEvent:readStream(streamId, connection)
	self.productionPoint = NetworkUtil.readNodeObject(streamId)
	self.productionId = streamReadString(streamId)
	self.inputId = streamReadUIntN(streamId, FillTypeManager.SEND_NUM_BITS)
	self.color = streamReadUIntN(streamId, FillTypeManager.SEND_NUM_BITS)

	self:run(connection)
end

function ProductionPointProductionInputColorEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.productionPoint)
	streamWriteString(streamId, self.productionId)
	streamWriteUIntN(streamId, self.inputId, FillTypeManager.SEND_NUM_BITS)
	streamWriteUIntN(streamId, self.color, FillTypeManager.SEND_NUM_BITS)
end

function ProductionPointProductionInputColorEvent:run(connection)
	if not connection:getIsServer() then
		g_server:broadcastEvent(self, false, connection)
	end

	if self.productionPoint ~= nil then
		self.productionPoint:setProductionInputColor(self.productionId, self.inputId, self.color, true)
	end
end

function ProductionPointProductionInputColorEvent.sendEvent(productionPoint, productionId, inputId, color, noEventSend)
	if noEventSend == nil or noEventSend == false then
		if g_server ~= nil then
			g_server:broadcastEvent(ProductionPointProductionInputColorEvent.new(productionPoint, productionId, inputId, color))
		else
			g_client:getServerConnection():sendEvent(ProductionPointProductionInputColorEvent.new(productionPoint, productionId, inputId, color))
		end
	end
end
