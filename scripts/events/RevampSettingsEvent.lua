--[[
Part of Production Revamp

Copyright (C) braeven & Achimobil 2022

Author: braeven

Version: 1.0.0.0
Date: 18.06.2024
]]

RevampSettingsEvent = {}
local RevampSettingsEvent_mt = Class(RevampSettingsEvent, Event)

InitEventClass(RevampSettingsEvent, "RevampSettingsEvent")

function RevampSettingsEvent.emptyNew()
	local self = Event.new(RevampSettingsEvent_mt)

	return self
end

function RevampSettingsEvent.new(productionPoint, productionId, mixMode, boostMode, feedMixerRecipe)
	local self = RevampSettingsEvent.emptyNew()
	self.productionPoint = productionPoint
	self.productionId = productionId
	self.mixMode = mixMode
	self.boostMode = boostMode
	self.feedMixerRecipe = feedMixerRecipe

	return self
end

function RevampSettingsEvent:readStream(streamId, connection)
	self.productionPoint = NetworkUtil.readNodeObject(streamId)
	self.productionId = streamReadString(streamId)
	self.mixMode = streamReadString(streamId)
	self.boostMode = streamReadString(streamId)
	self.feedMixerRecipe = streamReadUIntN(streamId, FillTypeManager.SEND_NUM_BITS)

	self:run(connection)
end

function RevampSettingsEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.productionPoint)
	streamWriteString(streamId, self.productionId)
	streamWriteString(streamId, self.mixMode)
	streamWriteString(streamId, self.boostMode)
	streamWriteUIntN(streamId, self.feedMixerRecipe, FillTypeManager.SEND_NUM_BITS)
end

function RevampSettingsEvent:run(connection)
	if not connection:getIsServer() then
		g_server:broadcastEvent(self, false, connection)
	end

	if self.productionPoint ~= nil then
		self.productionPoint:setRevampSettings(self.productionId, self.mixMode, self.boostMode, self.feedMixerRecipe, true)
	end
end

function RevampSettingsEvent.sendEvent(productionPoint, productionId, mixMode, boostMode, feedMixerRecipe, noEventSend)
	if noEventSend == nil or noEventSend == false then
		if mixMode == nil then
			mixMode = "none"
		end
		if boostMode == nil then
			boostMode = "none"
		end
		if feedMixerRecipe == nil then
			feedMixerRecipe = 0
		end
		if g_server ~= nil then
			g_server:broadcastEvent(RevampSettingsEvent.new(productionPoint, productionId, mixMode, boostMode, feedMixerRecipe))
		else
			g_client:getServerConnection():sendEvent(RevampSettingsEvent.new(productionPoint, productionId, mixMode, boostMode, feedMixerRecipe))
		end
	end
end
