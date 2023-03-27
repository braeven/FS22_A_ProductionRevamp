--[[
Part of Production Revamp

Copyright (C) braeven & Achimobil 2022

Author: Achimobil

Version: 1.1.0.0
Date: 22.08.2022
]]

ChangeRevampDecimalSettingsEvent = {}
ChangeRevampDecimalSettingsEvent_mt = Class(ChangeRevampDecimalSettingsEvent, Event);
InitEventClass(ChangeRevampDecimalSettingsEvent, "ChangeRevampDecimalSettingsEvent");

---Create instance of Event class
function ChangeRevampDecimalSettingsEvent.emptyNew()
	local self = Event.new(ChangeRevampDecimalSettingsEvent_mt);
	return self;
end

---Create new instance of event
function ChangeRevampDecimalSettingsEvent.new(settingsId, newValue)
	RevampSettings:print("ChangeRevampDecimalSettingsEvent.new");
	local self = ChangeRevampDecimalSettingsEvent.emptyNew();
	self.settingsId = settingsId;
	self.newValue = newValue;
	return self;
end

---Called on client side on join
-- @param integer streamId streamId
-- @param integer connection connection
function ChangeRevampDecimalSettingsEvent:readStream(streamId, connection)
	RevampSettings:print("ChangeRevampDecimalSettingsEvent.readStream");
	self.settingsId = streamReadString(streamId);
	self.newValue = streamReadFloat32(streamId)
	
	self:run(connection)
end

---Called on server side on join
-- @param integer streamId streamId
-- @param integer connection connection
function ChangeRevampDecimalSettingsEvent:writeStream(streamId, connection)
	RevampSettings:print("ChangeRevampDecimalSettingsEvent.writeStream");
	streamWriteString(streamId, self.settingsId)
	streamWriteFloat32(streamId, self.newValue)
end

---Run action on receiving side
-- @param integer connection connection
function ChangeRevampDecimalSettingsEvent:run(connection)
	RevampSettings:print("ChangeRevampDecimalSettingsEvent.run");
	RevampSettings.current[self.settingsId] = self.newValue;
	
	if g_server ~= nil then
		g_server:broadcastEvent(self, false)
	end
end

