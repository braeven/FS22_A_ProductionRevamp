--[[
Part of Production Revamp

Copyright (C) braeven & Achimobil 2022

Author: braeven & Achimobil

Version: 1.3.0.0
Date: 30.12.2022
]]

SpawnPalletsAtSiloEvent = {}
local SpawnPalletsAtSiloEvent_mt = Class(SpawnPalletsAtSiloEvent, Event)
InitEventClass(SpawnPalletsAtSiloEvent, "SpawnPalletsAtSiloEvent")

function SpawnPalletsAtSiloEvent.emptyNew()
	local self = Event.new(SpawnPalletsAtSiloEvent_mt)
	return self
end

function SpawnPalletsAtSiloEvent.new(aPalletSilo, ownerFarmId, pendingLiters, fillTypeIndex, isBale, isRoundbale, width, height, length, diameter, capacity, wrapState, customEnvironment)
	local self = SpawnPalletsAtSiloEvent.emptyNew()

	self.aPalletSilo = aPalletSilo
	self.ownerFarmId = ownerFarmId
	self.pendingLiters = pendingLiters
	self.fillTypeIndex = fillTypeIndex
	self.isBale = isBale
	self.isRoundbale = isRoundbale
	self.width = width
	self.height = height
	self.length = length
	self.diameter = diameter
	self.capacity = capacity
	self.wrapState = wrapState
	self.customEnvironment = customEnvironment

	return self
end

function SpawnPalletsAtSiloEvent:readStream(streamId, connection)
	self.aPalletSilo = NetworkUtil.readNodeObject(streamId)
	self.ownerFarmId = streamReadInt32(streamId)
	self.pendingLiters = streamReadInt32(streamId)
	self.fillTypeIndex = streamReadInt32(streamId)
	self.isBale = streamReadBool(streamId)
	self.isRoundbale = streamReadBool(streamId)
	self.width = streamReadFloat32(streamId)
	self.height = streamReadFloat32(streamId)
	self.length = streamReadFloat32(streamId)
	self.diameter = streamReadFloat32(streamId)
	self.capacity = streamReadFloat32(streamId)
	self.wrapState = streamReadBool(streamId)
	if streamReadBool(streamId) then
		self.customEnvironment = streamReadString(streamId)
	end

	self:run(connection)
end

function SpawnPalletsAtSiloEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.aPalletSilo) 
	streamWriteInt32(streamId, self.ownerFarmId)
	streamWriteInt32(streamId, self.pendingLiters)
	streamWriteInt32(streamId, self.fillTypeIndex)
	streamWriteBool(streamId, self.isBale)
	streamWriteBool(streamId, self.isRoundbale)
	streamWriteFloat32(streamId, self.width)
	streamWriteFloat32(streamId, self.height)
	streamWriteFloat32(streamId, self.length)
	streamWriteFloat32(streamId, self.diameter)
	streamWriteFloat32(streamId, self.capacity)
	streamWriteBool(streamId, self.wrapState)
	if streamWriteBool(streamId, self.customEnvironment ~= nil) then
		streamWriteString(streamId, self.customEnvironment)
	end

end

function SpawnPalletsAtSiloEvent:run(connection)
	assert(not connection:getIsServer(), "SpawnPalletsAtSiloEvent is client to server only")

	-- eintragen was vom client gebraucht wird in die spec
	local spec = self.aPalletSilo.spec_SiloPalletSpawner
	spec.pendingLiters[self.fillTypeIndex] = self.pendingLiters;
	spec.fillTypeIndex = self.fillTypeIndex;
	spec.capacity = self.capacity;

	spec.palletSpawner:spawnPallet(self.ownerFarmId, self.fillTypeIndex, spec.activatable.getPalletCallback, spec.activatable, self.isBale, self.isRoundbale, self.width, self.height, self.length, self.diameter, self.capacity, self.wrapState, self.customEnvironment)
end

function SpawnPalletsAtSiloEvent.sendEvent(aPalletSilo, ownerFarmId, pendingLiters, fillTypeIndex, isBale, isRoundbale, width, height, length, diameter, capacity, wrapState, customEnvironment)
	g_client:getServerConnection():sendEvent(SpawnPalletsAtSiloEvent.new(aPalletSilo, ownerFarmId, pendingLiters, fillTypeIndex, isBale, isRoundbale, width, height, length, diameter, capacity, wrapState, customEnvironment))
end