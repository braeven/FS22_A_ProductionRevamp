QuickAmountDialog = {
    CONTROLS = {
        "consoleAmountText",
        "headerText",
        "dialogTextElement",
        "dialogTitleElement"
    }
}
local QuickAmountDialog_mt = Class(QuickAmountDialog, DialogElement)

function QuickAmountDialog.new(target, custom_mt)
    local self = DialogElement.new(target, custom_mt or QuickAmountDialog_mt)
    self.isBackAllowed = false
    self.inputDelay = 250
    self.current = 1
    self.optionElements = {}
    self.options = {}
    self.leftDelayTime = 0
    self.scrollDelayDuration = FocusManager.FIRST_LOCK

    self:registerControls(QuickAmountDialog.CONTROLS)

    return self
end

function QuickAmountDialog:onOpen()
    QuickAmountDialog:superClass().onOpen(self)

    self.inputDelay = self.time + 250

    for element, amount in pairs(self.optionElements) do
        element.elements[3]:setText(tostring(amount))
    end

    self.farm = g_farmManager:getFarmById(g_currentMission:getFarmId())

    self:updateAmount(0)
end

function QuickAmountDialog:setCallback(callbackFunc, target, args)
    self.callbackFunc = callbackFunc
    self.target = target
    self.callbackArgs = args
end

function QuickAmountDialog:setTargetFarm(farm)
    self.headerText:setText(string.format(g_i18n:getText("button_mp_transferMoney_dialogTitle"), farm.name))
end

function QuickAmountDialog:onClickOk()
    if self.areButtonsDisabled then
        return true
    else
        self:sendCallback(self.current)

        return false
    end
end

function QuickAmountDialog:onClickBack(forceBack, usedMenuButton)
    self:sendCallback(0)

    return false
end

function QuickAmountDialog:sendCallback(value)
    if self.inputDelay < self.time then
        self:close()

        if self.callbackFunc ~= nil then
            if self.target ~= nil then
                self.callbackFunc(self.target, value, self.callbackArgs)
            else
                self.callbackFunc(value, self.callbackArgs)
            end
        end
    end
end

function QuickAmountDialog:onClickLeft(element)
    local amount = self.optionElements[element.parent]

    self:updateAmount(amount, false)
end

function QuickAmountDialog:onClickRight(element)
    local amount = self.optionElements[element.parent]

    self:updateAmount(amount, true)
end

function QuickAmountDialog:updateAmount(diff, forwards)
-- print("diff: " .. tostring(diff));
-- print("self.options")
-- DebugUtil.printTableRecursively(self.options,"_",0,2)

    if diff == 0 then
        self.current = 1
        self.consoleAmountText:setText(self.options[self.current]);
        return;
    end
    
    if self.leftDelayTime > g_time  then
        return;
    end
    
    self.leftDelayTime = g_time + self.scrollDelayDuration;

    -- element direkt wählen
    local numOfOptions = #self.options;
    if forwards then
        local newCurrent = self.current + diff;
        if newCurrent > numOfOptions then
            local fullToMuch = math.floor(newCurrent / numOfOptions);
            newCurrent = newCurrent - (fullToMuch * numOfOptions);
        end
        self.current = newCurrent;
    else
        -- minus Weg noch schreiben
        local newCurrent = self.current - diff;
        if newCurrent < 1 then
            newCurrent = numOfOptions;
        end
        self.current = newCurrent;
    end
    
    self.consoleAmountText:setText(self.options[self.current]);
end

function QuickAmountDialog:onCreateScroller(element, amount)
    local amount = tonumber(amount)
    self.optionElements[element] = amount
end

-- neu aus anderen kopiert
function QuickAmountDialog:setText(text)
    if self.dialogTextElement ~= nil then
        self.dialogTextElement:setText(Utils.getNoNil(text, self.defaultText))
    end
end

function QuickAmountDialog:setTitle(text)
    if self.dialogTitleElement ~= nil then
        self.dialogTitleElement:setText(Utils.getNoNil(text, self.defaultTitle))
    end
end

function QuickAmountDialog:setOptions(options)
    self.options = options;
    self:updateAmount(0);
end

function QuickAmountDialog:inputEvent(action, value, eventUsed)
    eventUsed = QuickAmountDialog:superClass().inputEvent(self, action, value, eventUsed)

    local focusedElement = FocusManager:getFocusedElement();
    
    if not eventUsed then
        if action == InputAction.MENU_AXIS_LEFT_RIGHT then
            if value < -g_analogStickHTolerance then
                eventUsed = true

                self:onClickLeft(focusedElement)
            elseif g_analogStickHTolerance < value then
                eventUsed = true

                self:onClickRight(focusedElement)
            end
        elseif action == InputAction.MENU_PAGE_PREV then
            eventUsed = true

            self:onClickLeft(focusedElement)
        elseif action == InputAction.MENU_PAGE_NEXT then
            eventUsed = true

            self:onClickRight(focusedElement)
        end
    end

    return eventUsed
end