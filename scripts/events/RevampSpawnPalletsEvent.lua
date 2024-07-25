--[[
Part of Production Revamp

Copyright (C) braeven & Achimobil 2022

Author: braeven & Achimobil

Version: 1.3.0.0
Date: 05.12.2023
]]

RevampSpawnPalletsEvent = {}
local RevampSpawnPalletsEvent_mt = Class(RevampSpawnPalletsEvent, Event)
InitEventClass(RevampSpawnPalletsEvent, "RevampSpawnPalletsEvent")

function RevampSpawnPalletsEvent.emptyNew()
	local self = Event.new(RevampSpawnPalletsEvent_mt)
	return self
end

function RevampSpawnPalletsEvent.new(ProductionPoint, ownerFarmId, fillTypeIndex, pendingLiters)
	local self = RevampSpawnPalletsEvent.emptyNew()
	self.ProductionPoint = ProductionPoint
	self.ownerFarmId = ownerFarmId
	self.fillTypeIndex = fillTypeIndex
	self.pendingLiters = pendingLiters
	self.treeSaplingTypeIndex = treeSaplingTypeIndex
	self.treeSaplingTypeName = treeSaplingTypeName
	return self
end

function RevampSpawnPalletsEvent:readStream(streamId, connection)
	self.ProductionPoint = NetworkUtil.readNodeObject(streamId)
	self.ownerFarmId = streamReadInt32(streamId)
	self.fillTypeIndex = streamReadInt32(streamId)
	self.pendingLiters = streamReadInt32(streamId)
	self.treeSaplingTypeIndex = streamReadInt32(streamId)
	self.treeSaplingTypeName = streamReadString(streamId)

	self:run(connection)
end

function RevampSpawnPalletsEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.ProductionPoint) 
	streamWriteInt32(streamId, self.ownerFarmId)
	streamWriteInt32(streamId, self.fillTypeIndex)
	streamWriteInt32(streamId, self.pendingLiters)
	streamWriteInt32(streamId, self.treeSaplingTypeIndex)
	streamWriteString(streamId, self.treeSaplingTypeName)
end

function RevampSpawnPalletsEvent:run(connection)
	self.ProductionPoint:ReceivePalletEvent(self.ownerFarmId, self.fillTypeIndex, self.pendingLiters, self.treeSaplingTypeIndex, self.treeSaplingTypeName)
end

function RevampSpawnPalletsEvent.sendEvent(ProductionPoint, ownerFarmId, fillTypeIndex, pendingLiters, treeSaplingTypeIndex, treeSaplingTypeName)
	g_client:getServerConnection():sendEvent(RevampSpawnPalletsEvent.new(ProductionPoint, ownerFarmId, fillTypeIndex, pendingLiters, treeSaplingTypeIndex, treeSaplingTypeName))
end