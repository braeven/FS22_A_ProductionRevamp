--[[
Part of Production Revamp

Copyright (C) braeven & Achimobil 2022

Author: Achimobil

Version: 1.1.0.0
Date: 22.08.2022
]]

ChangeRevampCheckSettingsEvent = {}
ChangeRevampCheckSettingsEvent_mt = Class(ChangeRevampCheckSettingsEvent, Event);
InitEventClass(ChangeRevampCheckSettingsEvent, "ChangeRevampCheckSettingsEvent");

---Create instance of Event class
function ChangeRevampCheckSettingsEvent.emptyNew()
    local self = Event.new(ChangeRevampCheckSettingsEvent_mt);
    return self;
end

---Create new instance of event
function ChangeRevampCheckSettingsEvent.new(settingsId, state)
    RevampSettings:print("ChangeRevampCheckSettingsEvent.new");
    local self = ChangeRevampCheckSettingsEvent.emptyNew();
    self.settingsId = settingsId;
    self.state = state;
    return self;
end

---Called on client side on join
-- @param integer streamId streamId
-- @param integer connection connection
function ChangeRevampCheckSettingsEvent:readStream(streamId, connection)
    RevampSettings:print("ChangeRevampCheckSettingsEvent.readStream");
    self.settingsId = streamReadString(streamId);
    self.state = streamReadBool(streamId)
    
    self:run(connection)
end

---Called on server side on join
-- @param integer streamId streamId
-- @param integer connection connection
function ChangeRevampCheckSettingsEvent:writeStream(streamId, connection)
    RevampSettings:print("ChangeRevampCheckSettingsEvent.writeStream");
    streamWriteString(streamId, self.settingsId)
    streamWriteBool(streamId, self.state)
end

---Run action on receiving side
-- @param integer connection connection
function ChangeRevampCheckSettingsEvent:run(connection)
    RevampSettings:print("ChangeRevampCheckSettingsEvent.run");
    RevampSettings.current[self.settingsId] = self.state;
    
    if g_server ~= nil then
        g_server:broadcastEvent(self, false)
    end
end

