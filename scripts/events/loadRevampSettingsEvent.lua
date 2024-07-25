--[[
Part of Production Revamp

Copyright (C) braeven & Achimobil 2022

Author: Achimobil

Version: 1.1.0.0
Date: 22.08.2022
]]

LoadRevampSettingsEvent = {}
LoadRevampSettingsEvent_mt = Class(LoadRevampSettingsEvent, Event)
InitEventClass(LoadRevampSettingsEvent, "LoadRevampSettingsEvent")

function LoadRevampSettingsEvent.emptyNew()
	local self = Event.new(LoadRevampSettingsEvent_mt)
	return self
end

function LoadRevampSettingsEvent.new(settings)
	if RevampSettings.debug then print("LoadRevampSettingsEvent.new") end
	local self = LoadRevampSettingsEvent.emptyNew()
	self.settings = settings
	return self
end

function LoadRevampSettingsEvent:readStream(streamId, connection)
	if RevampSettings.debug then
		print("LoadRevampSettingsEvent:readStream")
	end
	if g_server == nil then
		self.settings = {}
		self.settings.BuyRestriction = streamReadUInt16(streamId)
		self.settings.PrioSystemActive = streamReadBool(streamId)
		self.settings.MissionFixActive = streamReadBool(streamId)
		self.settings.PriceCorrectionActive = streamReadBool(streamId)
		self.settings.DistributionCostFactor = streamReadFloat32(streamId)
		self.settings.DirectSellingPriceFactor = streamReadFloat32(streamId)
		
		self:run(connection)
	end
end

function LoadRevampSettingsEvent:writeStream(streamId, connection)

	if RevampSettings.debug then
		print("LoadRevampSettingsEvent:writeStream")
	end

	streamWriteUInt16(streamId, self.settings.BuyRestriction)
	streamWriteBool(streamId, self.settings.PrioSystemActive)
	streamWriteBool(streamId, self.settings.MissionFixActive)
	streamWriteBool(streamId, self.settings.PriceCorrectionActive)
	streamWriteFloat32(streamId, self.settings.DistributionCostFactor)
	streamWriteFloat32(streamId, self.settings.DirectSellingPriceFactor)

end

function LoadRevampSettingsEvent:run(connection)
	if g_server ~= nil then
		g_server:broadcastEvent(LoadRevampSettingsEvent.new(RevampSettings.current), false)
		return
	end

	if(self.settings ~= nil) then
		RevampSettings.current = self.settings
	end
end
