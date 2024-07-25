--[[
Part of Production Revamp

Copyright (C) braeven & Achimobil 2022

Author: braeven

Version: 1.1.0.0
Date: 22.08.2022
]]

ProductionPointPriorityEvent = {}
local ProductionPointPriorityEvent_mt = Class(ProductionPointPriorityEvent, Event)

InitEventClass(ProductionPointPriorityEvent, "ProductionPointPriorityEvent")

function ProductionPointPriorityEvent.emptyNew()
	local self = Event.new(ProductionPointPriorityEvent_mt)

	return self
end

function ProductionPointPriorityEvent.new(productionPoint, inputFillTypeId, priority)
	local self = ProductionPointPriorityEvent.emptyNew()
	self.productionPoint = productionPoint
	self.inputFillTypeId = inputFillTypeId
	self.priority = priority

	return self
end

function ProductionPointPriorityEvent:readStream(streamId, connection)
	self.productionPoint = NetworkUtil.readNodeObject(streamId)
	self.inputFillTypeId = streamReadUIntN(streamId, FillTypeManager.SEND_NUM_BITS)
	self.priority = streamReadUIntN(streamId, 6)

	self:run(connection)
end

function ProductionPointPriorityEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.productionPoint)
	streamWriteUIntN(streamId, self.inputFillTypeId, FillTypeManager.SEND_NUM_BITS)
	streamWriteUIntN(streamId, self.priority, 6)
end

function ProductionPointPriorityEvent:run(connection)
	if not connection:getIsServer() then
		g_server:broadcastEvent(self, false, connection)
	end

	if self.productionPoint ~= nil then
		self.productionPoint:setInputPriority(self.inputFillTypeId, self.priority, true)
	end
end

function ProductionPointPriorityEvent.sendEvent(productionPoint, inputFillTypeId, priority, noEventSend)
	if noEventSend == nil or noEventSend == false then
		if g_server ~= nil then
			g_server:broadcastEvent(ProductionPointPriorityEvent.new(productionPoint, inputFillTypeId, priority))
		else
			g_client:getServerConnection():sendEvent(ProductionPointPriorityEvent.new(productionPoint, inputFillTypeId, priority))
		end
	end
end
