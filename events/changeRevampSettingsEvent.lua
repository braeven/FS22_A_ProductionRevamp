--[[
Part of Production Revamp

Copyright (C) braeven & Achimobil 2022

Author: Achimobil

Version: 1.1.0.0
Date: 22.08.2022
]]

ChangeRevampSettingsEvent = {}
ChangeRevampSettingsEvent_mt = Class(ChangeRevampSettingsEvent, Event);
InitEventClass(ChangeRevampSettingsEvent, "ChangeRevampSettingsEvent");

---Create instance of Event class
function ChangeRevampSettingsEvent.emptyNew()
    local self = Event.new(ChangeRevampSettingsEvent_mt);
    return self;
end

---Create new instance of event
function ChangeRevampSettingsEvent.new(settingsId, state)
    if RevampSettings.debug then print("ChangeRevampSettingsEvent.new") end
    local self = ChangeRevampSettingsEvent.emptyNew();
    self.settingsId = settingsId;
    self.state = state;
    return self;
end

---Called on client side on join
-- @param integer streamId streamId
-- @param integer connection connection
function ChangeRevampSettingsEvent:readStream(streamId, connection)
    if RevampSettings.debug then print("ChangeRevampSettingsEvent.readStream") end
    self.settingsId = streamReadString(streamId);
    self.state = streamReadInt32(streamId)
    
    self:run(connection)
end

---Called on server side on join
-- @param integer streamId streamId
-- @param integer connection connection
function ChangeRevampSettingsEvent:writeStream(streamId, connection)
    if RevampSettings.debug then print("ChangeRevampSettingsEvent.writeStream") end
    streamWriteString(streamId, self.settingsId)
    streamWriteInt32(streamId, self.state)
end

---Run action on receiving side
-- @param integer connection connection
function ChangeRevampSettingsEvent:run(connection)
    if RevampSettings.debug then print("ChangeRevampSettingsEvent.run") end
    RevampSettings.current[self.settingsId] = self.state;
    
    if g_server ~= nil then
        g_server:broadcastEvent(self, false)
    end
end

