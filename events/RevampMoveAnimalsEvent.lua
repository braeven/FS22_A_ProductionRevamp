--[[
Part of Production Revamp

Copyright (C) braeven & Achimobil 2022

Author: braeven & Achimobil

Version: 1.0.0.0
Date: 27.12.2022
]]


RevampMoveAnimalsEvent = {}
local RevampMoveAnimalsEvent_mt = Class(RevampMoveAnimalsEvent, Event)
InitEventClass(RevampMoveAnimalsEvent, "RevampMoveAnimalsEvent")

function RevampMoveAnimalsEvent.emptyNew()
	local self = Event.new(RevampMoveAnimalsEvent_mt)
	return self
end

function RevampMoveAnimalsEvent.new(productionPoint, triggerIndex, selectedIndex, quantity)
	local self = RevampMoveAnimalsEvent.emptyNew()
	self.productionPoint = productionPoint
	self.triggerIndex = triggerIndex
	self.selectedIndex = selectedIndex
	self.quantity = quantity
	return self
end

function RevampMoveAnimalsEvent:readStream(streamId, connection)
	self.productionPoint = NetworkUtil.readNodeObject(streamId)
	self.triggerIndex = streamReadInt32(streamId)
	self.selectedIndex = streamReadInt32(streamId)
	self.quantity = streamReadInt32(streamId)

	RevampAnimalStation.print("RevampMoveAnimalsEvent.readStream - %s,%s,%s", self.triggerIndex, self.selectedIndex, self.quantity);

	self:run(connection)
end

function RevampMoveAnimalsEvent:writeStream(streamId, connection)
	RevampAnimalStation.print("RevampMoveAnimalsEvent.writeStream - %s,%s,%s", self.triggerIndex, self.selectedIndex, self.quantity);
	NetworkUtil.writeNodeObject(streamId, self.productionPoint)
	streamWriteInt32(streamId, self.triggerIndex)
	streamWriteInt32(streamId, self.selectedIndex)
	streamWriteInt32(streamId, self.quantity)
end

function RevampMoveAnimalsEvent:run(connection)
	RevampAnimalStation.print("RevampMoveAnimalsEvent.run - %s,%s,%s", self.triggerIndex, self.selectedIndex, self.quantity);
	self.productionPoint.animalStation:receiveAnimalDeliveryCallback(self.triggerIndex, self.selectedIndex, self.quantity);
end

function RevampMoveAnimalsEvent.sendEvent(productionPoint, triggerIndex, selectedIndex, quantity)
	RevampAnimalStation.print("RevampMoveAnimalsEvent.sendEvent - %s,%s,%s,%s", productionPoint, triggerIndex, selectedIndex, quantity);
	g_client:getServerConnection():sendEvent(RevampMoveAnimalsEvent.new(productionPoint, triggerIndex, selectedIndex, quantity))
end