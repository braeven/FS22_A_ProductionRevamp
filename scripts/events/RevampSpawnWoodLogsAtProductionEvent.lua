--[[
Part of Production Revamp

Copyright (C) braeven & Achimobil 2022

Author: Achimobil

Version: 1.2.0.0
Date: 30.12.2022
]]

RevampSpawnWoodLogsAtProductionEvent = {}
local RevampSpawnWoodLogsAtProductionEvent_mt = Class(RevampSpawnWoodLogsAtProductionEvent, Event)
InitEventClass(RevampSpawnWoodLogsAtProductionEvent, "RevampSpawnWoodLogsAtProductionEvent")

function RevampSpawnWoodLogsAtProductionEvent.emptyNew()
	local self = Event.new(RevampSpawnWoodLogsAtProductionEvent_mt)
	return self
end

function RevampSpawnWoodLogsAtProductionEvent.new(productionPoint, pendingWoodLogs, amountPerWoodLog, fillTypeIndex, selectedWoodLogLength)
	local self = RevampSpawnWoodLogsAtProductionEvent.emptyNew()

	self.productionPoint = productionPoint
	self.pendingWoodLogs = pendingWoodLogs
	self.amountPerWoodLog = amountPerWoodLog
	self.fillTypeIndex = fillTypeIndex
	self.selectedWoodLogLength = selectedWoodLogLength

	return self
end

function RevampSpawnWoodLogsAtProductionEvent:readStream(streamId, connection)
	self.productionPoint = NetworkUtil.readNodeObject(streamId)
	self.pendingWoodLogs = streamReadInt32(streamId)
	self.amountPerWoodLog = streamReadFloat32(streamId)
	self.fillTypeIndex = streamReadInt32(streamId)
	self.selectedWoodLogLength = streamReadInt32(streamId)

	self:run(connection)
end

function RevampSpawnWoodLogsAtProductionEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.productionPoint) 
	streamWriteInt32(streamId, self.pendingWoodLogs)
	streamWriteFloat32(streamId, self.amountPerWoodLog)
	streamWriteInt32(streamId, self.fillTypeIndex)
	streamWriteInt32(streamId, self.selectedWoodLogLength)
end

function RevampSpawnWoodLogsAtProductionEvent:run(connection)
	assert(not connection:getIsServer(), "RevampSpawnWoodLogsAtProductionEvent is client to server only")

	-- eintragen was vom client gebraucht wird in die spec
	local productionPoint = self.productionPoint

	productionPoint.pendingWoodLogs = self.pendingWoodLogs;
	productionPoint.amountPerWoodLog = self.amountPerWoodLog;
	productionPoint.fillTypeIndex = self.fillTypeIndex;
	productionPoint.selectedWoodLogLength = self.selectedWoodLogLength;
	
	productionPoint.activatable:spawnWoodLogs();
end

function RevampSpawnWoodLogsAtProductionEvent.sendEvent(productionPoint, pendingWoodLogs, amountPerWoodLog, fillTypeIndex, selectedWoodLogLength)
	g_client:getServerConnection():sendEvent(RevampSpawnWoodLogsAtProductionEvent.new(productionPoint, pendingWoodLogs, amountPerWoodLog, fillTypeIndex, selectedWoodLogLength))
end