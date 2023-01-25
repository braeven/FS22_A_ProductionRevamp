--[[
Part of Production Revamp

Copyright (C) braeven & Achimobil 2022

Author: braeven & Achimobil

Version: 1.1.0.0
Date: 22.08.2022
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
  return self
end

function RevampSpawnPalletsEvent:readStream(streamId, connection)
  self.ProductionPoint = NetworkUtil.readNodeObject(streamId)
  self.ownerFarmId = streamReadInt32(streamId)
  self.fillTypeIndex = streamReadInt32(streamId)
  self.pendingLiters = streamReadFloat32(streamId)

  self:run(connection)
end

function RevampSpawnPalletsEvent:writeStream(streamId, connection)
  NetworkUtil.writeNodeObject(streamId, self.ProductionPoint) 
  streamWriteInt32(streamId, self.ownerFarmId)
  streamWriteInt32(streamId, self.fillTypeIndex)
  streamWriteFloat32(streamId, self.pendingLiters)
end

function RevampSpawnPalletsEvent:run(connection)
  self.ProductionPoint:ReceivePalletEvent(self.ownerFarmId, self.fillTypeIndex, self.pendingLiters)
end

function RevampSpawnPalletsEvent.sendEvent(ProductionPoint, ownerFarmId, fillTypeIndex, pendingLiters)
  g_client:getServerConnection():sendEvent(RevampSpawnPalletsEvent.new(ProductionPoint, ownerFarmId, fillTypeIndex, pendingLiters))
end