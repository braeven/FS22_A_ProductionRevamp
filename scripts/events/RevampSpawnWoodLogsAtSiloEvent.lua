--[[
Part of Production Revamp

Copyright (C) braeven & Achimobil 2022

Author: Achimobil

Version: 1.2.0.0
Date: 30.12.2022
]]

RevampSpawnWoodLogsAtSiloEvent = {}
local RevampSpawnWoodLogsAtSiloEvent_mt = Class(RevampSpawnWoodLogsAtSiloEvent, Event)
InitEventClass(RevampSpawnWoodLogsAtSiloEvent, "RevampSpawnWoodLogsAtSiloEvent")

function RevampSpawnWoodLogsAtSiloEvent.emptyNew()
	local self = Event.new(RevampSpawnWoodLogsAtSiloEvent_mt)
	return self
end

function RevampSpawnWoodLogsAtSiloEvent.new(aPalletSilo, pendingWoodLogs, amountPerWoodLog, fillTypeIndex, selectedWoodLogLength)
	local self = RevampSpawnWoodLogsAtSiloEvent.emptyNew()

	self.aPalletSilo = aPalletSilo
	self.pendingWoodLogs = pendingWoodLogs
	self.amountPerWoodLog = amountPerWoodLog
	self.pendingLiters = pendingLiters
	self.fillTypeIndex = fillTypeIndex
	self.selectedWoodLogLength = selectedWoodLogLength

	return self
end

function RevampSpawnWoodLogsAtSiloEvent:readStream(streamId, connection)
	self.aPalletSilo = NetworkUtil.readNodeObject(streamId)
	self.pendingWoodLogs = streamReadInt32(streamId)
	self.amountPerWoodLog = streamReadFloat32(streamId)
	self.fillTypeIndex = streamReadInt32(streamId)
	self.selectedWoodLogLength = streamReadInt32(streamId)

	self:run(connection)
end

function RevampSpawnWoodLogsAtSiloEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.aPalletSilo) 
	streamWriteInt32(streamId, self.pendingWoodLogs)
	streamWriteFloat32(streamId, self.amountPerWoodLog)
	streamWriteInt32(streamId, self.fillTypeIndex)
	streamWriteInt32(streamId, self.selectedWoodLogLength)
end

function RevampSpawnWoodLogsAtSiloEvent:run(connection)
	assert(not connection:getIsServer(), "RevampSpawnWoodLogsAtSiloEvent is client to server only")

	-- eintragen was vom client gebraucht wird in die spec
	local spec = self.aPalletSilo.spec_SiloPalletSpawner

	spec.pendingWoodLogs = self.pendingWoodLogs;
	spec.amountPerWoodLog = self.amountPerWoodLog;
	spec.fillTypeIndex = self.fillTypeIndex;
	spec.selectedWoodLogLength = self.selectedWoodLogLength
	
	spec.activatable:spawnWoodLogs(self);
end

function RevampSpawnWoodLogsAtSiloEvent.sendEvent(aPalletSilo, pendingWoodLogs, amountPerWoodLog, fillTypeIndex, selectedWoodLogLength)
	g_client:getServerConnection():sendEvent(RevampSpawnWoodLogsAtSiloEvent.new(aPalletSilo, pendingWoodLogs, amountPerWoodLog, fillTypeIndex, selectedWoodLogLength))
end