--[[
Part of Production Revamp

Copyright (C) braeven & Achimobil 2022

Author: braeven & Achimobil

Version: 1.1.0.0
Date: 22.08.2022
]]


RevampSpawnBalesEvent = {}
local RevampSpawnBalesEvent_mt = Class(RevampSpawnBalesEvent, Event)
InitEventClass(RevampSpawnBalesEvent, "RevampSpawnBalesEvent")

function RevampSpawnBalesEvent.emptyNew()
  local self = Event.new(RevampSpawnBalesEvent_mt)
  return self
end

function RevampSpawnBalesEvent.new(ProductionPoint, ownerFarmId, fillTypeIndex, pendingLiters, isBale, isRoundbale, width, height, length, diameter, capacity, wrapState, customEnvironment)
    local self = RevampSpawnBalesEvent.emptyNew()
    self.ProductionPoint = ProductionPoint
    self.ownerFarmId = ownerFarmId
    self.fillTypeIndex = fillTypeIndex
    self.pendingLiters = pendingLiters
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

function RevampSpawnBalesEvent:readStream(streamId, connection)
    self.ProductionPoint = NetworkUtil.readNodeObject(streamId)
    self.ownerFarmId = streamReadInt32(streamId)
    self.fillTypeIndex = streamReadInt32(streamId)
    self.pendingLiters = streamReadFloat32(streamId)
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

function RevampSpawnBalesEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.ProductionPoint) 
    streamWriteInt32(streamId, self.ownerFarmId)
    streamWriteInt32(streamId, self.fillTypeIndex)
    streamWriteFloat32(streamId, self.pendingLiters)
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

function RevampSpawnBalesEvent:run(connection)
    self.ProductionPoint:ReceiveBaleEvent(self.ownerFarmId, self.fillTypeIndex, self.pendingLiters, self.isBale, self.isRoundbale, self.width, self.height, self.length, self.diameter, self.capacity, self.wrapState, self.customEnvironment)
end

function RevampSpawnBalesEvent.sendEvent(ProductionPoint, ownerFarmId, fillTypeIndex, pendingLiters, isBale, isRoundbale, width, height, length, diameter, capacity, wrapState, customEnvironment)
    g_client:getServerConnection():sendEvent(RevampSpawnBalesEvent.new(ProductionPoint, ownerFarmId, fillTypeIndex, pendingLiters, isBale, isRoundbale, width, height, length, diameter, capacity, wrapState, customEnvironment))
end