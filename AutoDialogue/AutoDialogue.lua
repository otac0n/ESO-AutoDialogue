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

        local byItemCount = ((newKeysMatched["response"] and 1) or 0) + ((newKeysMatched["index"] and 1) or 0)
        if not hasRules and not (byItemCount > 0 and keyCount > byItemCount) then
            d("Not permitting a rule with only the following keys:")
            d(newKeysMatched)
            fn = function(...) return false end
        else
            for key, matcher in pairs(rules) do
                if key ~= "rules" then
                    if type(matcher) ~= "function" then
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
    -- Daily Writs
    {
        {
            target = rx("^[%w%s]- Delivery Crate$"),
            rules = {
                { response = "<Place the goods within the crate.>" },
                { response = "Complete Quest." },
            },
        },
        {
            target = rx("^%w+ Crafting Writs$"),
            index = 1,
        },
    },
    -- Tales of Tribute
    {
        target = "Raenobi",
        rules = {
            { response = "You're the intermediate leader?" },
            { response = "So, you tried to sabotage our team by getting Sorinne hooked again?" },
            { response = "Yes we do. And we intend to win." },
            { body = s("Lentondil will face you"), response = "Goodbye." },
        }
    },
    -- Assassins Guild: Story
    {
        -- A Question of Faith
        {
            target = "Note from Kor",
            response = "I'll go find Kor.",
        },
        {
            target = "Grazda",
            rules = {
                { response = "Do you need something, Grazda?" },
                { response = "I'll go talk to Kor in the Sanctuary." },
            },
        },
        {
            target = "Kor",
            rules = {
                { response = "How long has Hildegard been missing?" },
                { response = "Where does Hildegard usually go to pray?" },
                { response = "I'll help you find Hildegard." },
                { body = s("I'll meet you at the Chapel in Anvil."), response = "Goodbye." },
                { response = "A woman saw Hildegard speaking with Chanter Nemus before she fled in tears." },
                { response = "You think the Chanter said something to upset her?" },
                { response = "Any idea where she'd go in such a state of mind?" },
                { response = "I'll talk to the caravan master." },
                { response = "What was that about the Silver Dawn?" },
                { response = "Not if we reach her first." },
                { response = "You need to make sure Hildegard gets to the Sanctuary safely." },
                { body = s("Anyway, we'll see you back home."), response = "Goodbye." },
            },
        },
        {
            target = "Garrebh",
            rules = {
                { response = "Have you seen a young Nord woman? Wears a flower in her hair?" },
                { body = s("I have seen may such women in this city."), response = "Goodbye." },
            },
        },
        {
            target = "Decalus Carius",
            rules = {
                { response = "Have you seen a young Nord woman? Wears a flower in her hair?" },
                { body = s("A Nord? Here?"), response = "Goodbye." },
            },
        },
        {
            target = "Bellucia Leraud",
            rules = {
                { response = "Have you seen a young Nord woman? Wears a flower in her hair?" },
                { body = s("Now that you mention it,"), response = "Goodbye." },
            },
        },
        {
            target = "Alcedonia Delitian",
            rules = {
                { response = "She's a friend who's gone missing. I'm trying to find her." },
                { response = "Could you hear what he was saying?" },
                { response = "I'm sure it wasn't that kind of discussion." },
                { response = "Thanks for your help." },
            },
        },
        {
            target = "Bilami the Caravaneer",
            rules = {
                { response = "I'm looking for a young Nord woman. Wears a flower in her hair." },
                { response = "I'm trying to help her. Her family is worried about her." },
                { response = "How can I convince you I'm trying to help her? Did your caravan taker her to Skyrim?" },
                { response = "We're ready to go now." },
                { response = "I'm always ready for a fight." },
                { response = "We're ready to go back to Anvil now." },
                { response = "Yes, take me back to Anvil, please." },
            },
        },
        {
            response = "Goodbye.",
            rules = {
                { target = "Silver Dawn Hunter", body = "<This Silver Dawn hunter died in a fierce battle.>" },
                { target = "Disturbed Flowers", body = "<Flowers were expertly and recently picked from this plant without damaging either the plant or the remaining blossoms.>" },
                { target = "Slaughtered Deer", body = "<This deer was killed while drinking from the pool. Whoever killed it was able to approach unnoticed and make its attack.>" },
            }
        },
        {
            target = "Hildegard",
            rules = {
                { response = "Why didn't you return to the Sanctuary, Hildegard?" },
                { response = "Chanter Nemus told you all this? He knows about you and the Brotherhood?" },
                { response = "Chanter Nemus deceived you. He sent the Silver Dawn to kill you." },
                { response = "We're a family, Hilde. We protect each other. We're stronger together." },
                { response = "Let's get back to the Gold Coast." },
                { response = "I'll handle the Chanter. Where can I find him?" },
                { response = "I'll take care of the Chanter. Gome home, Hildegard." },
            }
        },
        {
            target = "Astara Caerellius",
            response = "Chanter Nemus tricked Hildegard and I killed him for it. It won't happen again.",
        },
    },
    -- Assassins Guild: Repeatable
    {
        target = "Remains-Silent",
        rules = {
            { response = "Have any poisons or potions today?" },
        },
    },
    {
        {
            target = "Elam Drals",
            response = "I completed a contract.",
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
                        { body = s("Gossipers") },
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
                        { body = s("whomever you deem appropriate") },
                        { body = s("anyone fool enough") },
                        { body = s("those who claim it") },
                        { body = s("Trim the branches") },
                        { body = s("The Thanes of Eastmarch") },
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
        d("Selection option "..tostring(matches[1])..": "..option:GetText())
        INTERACTION:HandleChatterOptionClicked(option)
    end
end

function AutoDialogue:GetOptionCount()
    local optionCount = 0
    if SCENE_MANAGER.currentScene.name == INTERACTION.sceneName then
        for i = 1, MAX_CHATTER_OPTIONS do
            if INTERACTION.optionControls[i]:IsControlHidden() then
                break
            end
            optionCount = i
        end
    end
    return optionCount
end

function AutoDialogue:SearchDialogue()
    local matches = {}

    local optionCount = self:GetOptionCount()
    if optionCount > 0 then
        local dialogueInfo = {
            target = GetUnitName("interact"),
            body = ZO_InteractWindowTargetAreaBodyText:GetText(),
        }

        local lastMatch, matchCount = nil, 0
        for i = 1, optionCount do
            dialogueInfo.index = i
            dialogueInfo.response = INTERACTION.optionControls[i]:GetText()
            if compiledRules(dialogueInfo) then
                table.insert(matches, i)
                d("Matched option "..tostring(i))
            else
                d("No match option "..tostring(i))
            end
        end
    end

    return matches
end
