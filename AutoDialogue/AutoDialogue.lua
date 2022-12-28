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
