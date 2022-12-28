AutoDialogue = {
    ADDON_NAME = "AutoDialogue",
}

EVENT_MANAGER:RegisterForEvent(AutoDialogue.ADDON_NAME, EVENT_ADD_ON_LOADED, function (eventCode, name)
    if name ~= AutoDialogue.ADDON_NAME then return end
    AutoDialogue:Initialize()
    EVENT_MANAGER:UnregisterForEvent(AutoDialogue.ADDON_NAME, EVENT_ADD_ON_LOADED)
end)

local function eq(text)
    return function(value) return value == text end
end

local function rx(pattern)
    return function(value) return (string.match(value, pattern) and true) or false end
end

local function s(text)
    return rx(string.gsub(text, "([^%w])", "%%%1"))
end

local function compile(rules, keysMatched)
    keysMatched = keysMatched or {}

    local fn = nil

    if #rules == 0 then
        local newKeysMatched, keyCount = {}, 0
        local hasRules = false
        for key, _ in pairs(rules) do
            if key == "rules" then
                hasRules = true
            else
                newKeysMatched[key] = true
                keyCount = keyCount + 1
            end
        end
        for key, _ in pairs(keysMatched) do
            if not newKeysMatched[key] then
                newKeysMatched[key] = true
                keyCount = keyCount + 1
            end
        end

        if hasRules then
            fn = compile(rules["rules"], newKeysMatched)
        end

        if not hasRules and not (newKeysMatched["response"] and keyCount >= 2) then
            d("Not permitting a rule with only the following keys:")
            d(newKeysMatched)
            fn = function(...) return false end
        else
            for key, matcher in pairs(rules) do
                if key ~= "rules" then
                    if type(matcher) == "string" then
                        matcher = eq(matcher)
                    end
                    local ruleFn = function(dialogueInfo) return matcher(dialogueInfo[key]) end
                    if fn == nil then
                        fn = ruleFn
                    elseif ruleFn ~= nil then
                        local origFn = fn
                        fn = function(...) return origFn(...) and ruleFn(...) end
                    end
                end
            end

            fn = fn or (function(...) return true end)
        end
    else
        for _, rule in ipairs(rules) do
            local ruleFn = compile(rule, keysMatched)
            if fn == nil then
                fn = ruleFn
            elseif ruleFn ~= nil then
                local origFn = fn
                fn = function(...) return origFn(...) or ruleFn(...) end
            end
        end

        fn = fn or (function(...) return false end)
    end

    return fn
end

local rules = {
    {
        target = "Remains-Silent",
        rules = {
            { response = "Have any poisons or potions today?" },
        },
    },
    {
        target = "Marked for Death",
        rules = {
            { response = "<Page through the book.>" },
            {
                response = "Goodbye.",
                rules = {
                    { body = s("throw me to the swamp") },
                    { body = s("My kin") },
                    { body = s("My spouse") },
                    { body = s("My ex-lover") },
                    { body = s("my rival") },
                    { body = s("My enemy") },
                    { body = s("My prey") },
                    { body = s("my vengance") },
                    { body = s("a well-connected competitor") },
                    { body = s("a camp follower") },
                    { body = s("Foreign petitioners") },
                    { body = s("sycophant") },
                    { body = s("a spy") },
                    { body = s("an eavesdropper") },
                    { body = s("a criminal") },
                    { body = s("their ringleader") },
                    { body = s("the troublemaker") },
                    { body = s("An agitator") },
                    { body = s("a loudmouth") },
                    { body = s("an insipid fool") },
                    { body = s("the playful idiot") },
                    { body = s("a skald in training") },
                    { body = s("the real vermin") },
                    { body = s("one of these vermin") },
                    { body = s("One of the refugees") },
                    { body = s("some lowly cur") },
                    { body = s("a welcher") },
                    { body = s("A coward") },
                    { body = s("the pretender") },
                    { body = s("a deadbeat") },
                    { body = s("slaughterfish bait") },
                    { body = s("a former customer") },
                    { body = s("one of the staff") },
                    { body = s("an employee") },
                    { body = s("the worker") },
                    { body = s("someone at the") },
                    { body = s("An assassination") },
                    { body = s("one of her friends") },
                    { body = s("an innocent") },
                    { body = s("a worshiper") },
                    { body = s("A lone traveler") },
                    { body = s("a spark to ignite") },
                },
            },
            {
                response = "<Accept this contract.>",
                rules = {
                    { body = s("citizens in") },
                    { body = s("citizens of") },
                    { body = s("anyone fool enough") },
                    { body = s("those who claim it") },
                    { body = s("Trim the branches") },
                    { body = s("Strike terror into the populace") },
                    { body = s("Keep the shadow of death lingering") },
                    { body = s("make the March too frightening") },
                },
            },
        },
    },
    {
        target = "Speaker Terenus",
        rules = {
            { response = "Do you have anything for me today, Speaker?" },
            { response = "Who do I need to kill?" },
            {
                body = s("Two challenges."),
                response = "I'm listening."
            },
        },
    },
}

local compiledRules = compile(rules)

function AutoDialogue:Initialize()
  local namespace = AutoDialogue.ADDON_NAME
  ZO_PreHook(INTERACTION, "FinalizeChatterOptions", function()
    EVENT_MANAGER:RegisterForUpdate(namespace.."AutoSelect", 0, function()
        EVENT_MANAGER:UnregisterForUpdate(namespace.."AutoSelect")
        self:AutoSelect()
    end)
  end)
  ZO_PreHook(ZO_InteractionManager, "SelectChatterOptionByIndex", function()
    EVENT_MANAGER:UnregisterForUpdate(namespace.."AutoSelect")
  end)
end

function AutoDialogue:AutoSelect()
    local matches = self:SearchDialogue()
    if #matches == 1 then
        local option = INTERACTION.optionControls[matches[1]];
        d("Selection option "..option:GetText())
        INTERACTION:HandleChatterOptionClicked(option)
    end
end

function AutoDialogue:SearchDialogue()
    local matches = {}

    if SCENE_MANAGER.currentScene.name == INTERACTION.sceneName then
        local dialogueInfo = {
            target = GetUnitName("interact"),
            body = ZO_InteractWindowTargetAreaBodyText:GetText(),
        }

        local lastMatch, matchCount = nil, 0
        for i = 1, INTERACTION.optionCount do
            dialogueInfo.response = INTERACTION.optionControls[i]:GetText()
            if compiledRules(dialogueInfo) then
                table.insert(matches, i)
            end
        end
    end

    return matches
end
