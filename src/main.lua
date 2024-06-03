---@meta _
---@diagnostic disable

-- grabbing our dependencies,
-- these funky (---@) comments are just there
--	 to help VS Code find the definitions of things

---@diagnostic disable-next-line: undefined-global
local mods = rom.mods

---@module 'SGG_Modding-ENVY-auto'
mods['SGG_Modding-ENVY'].auto()
-- ^ this gives us `public` and `import`, among others
--	and makes all globals we define private to this plugin.
---@diagnostic disable: lowercase-global

---@diagnostic disable-next-line: undefined-global
rom = rom
---@diagnostic disable-next-line: undefined-global
_PLUGIN = PLUGIN

---@module 'SGG_Modding-Hades2GameDef-Globals'
game = rom.game

---@module 'SGG_Modding-ModUtil'
modutil = mods['SGG_Modding-ModUtil']

---@module 'SGG_Modding-Chalk'
chalk = mods["SGG_Modding-Chalk"]
---@module 'SGG_Modding-ReLoad'
reload = mods['SGG_Modding-ReLoad']

---@module 'config'
config = chalk.auto()
-- ^ this updates our config.toml in the config folder!
public.config = config -- so other mods can access our config

local function on_ready()
    -- what to do when we are ready, but not re-do on reload.
    if config.enabled == false then return end

    modutil.mod.Path.Wrap("ShowUseButton", function(base, objectId, useTarget)
        if useTarget ~= nil and game.CanReceiveGift(useTarget) == true then
            makeGiftDisplay(useTarget)
        end

        return base(objectId, useTarget)
    end)

    modutil.mod.Path.Wrap("HideUseButton", function(base, objectId, useTarget, fadeDuration)
        if game.ScreenAnchors["GiftDisplay"] ~= nil then
            game.SetAlpha({ Id = game.ScreenAnchors["GiftDisplay"].Id, Fraction = 0, Duration = 0.25 })
        end
        if game.ScreenAnchors["EmptyHeart"] ~= nil then
            game.SetAlpha({ Id = game.ScreenAnchors["EmptyHeart"].Id, Fraction = 0, Duration = 0.25 })
        end
        return base(objectId, useTarget, fadeDuration)
    end)
end

local function on_reload()
    function makeGiftDisplay(useTarget)
        local name = useTarget.Name or ""
        local giftEvents = modutil.mod.Path.Get("NarrativeData." .. name .. ".GiftTextLinePriorities")
        if giftEvents ~= nil then
            local iconFilled = 0
            local iconEmpty = 0
            local iconLocked = 0

            -- borowed from CodexLogic.CreateGiftTrack
            for i, eventName in ipairs(giftEvents) do
                local giftSource = game.EnemyData[name] or game.LootData[name] or
                    game.ConsumableData[name]
                if giftSource ~= nil then
                    local giftEventData = giftSource.GiftTextLineSets[eventName]
                    local onGiftTrack = giftEventData.OnGiftTrack
                    if giftEventData.AltGiftTrackEvent ~= nil and game.GameState.TextLinesRecord[giftEventData.AltGiftTrackEvent] then
                        giftEventData = giftSource.GiftTextLineSets[giftEventData.AltGiftTrackEvent]
                    end
                    if onGiftTrack then
                        -- this gets the linear gift order (although gifts can be given out of order)
                        -- local resourceData = nil
                        -- for resourceName, resourceAmount in pairs(giftEventData.Cost) do
                        --     resourceData = game.ResourceData[resourceName]
                        -- end

                        if game.GameState.TextLinesRecord[giftEventData.Name] then
                            iconFilled = iconFilled + 1
                        elseif giftEventData.GameStateRequirements ~= nil and not game.IsGameStateEligible(game.CurrentRun, giftEventData, giftEventData.GameStateRequirements) then
                            iconLocked = iconLocked + 1
                        else
                            iconEmpty = iconEmpty + 1
                        end
                    end
                end
            end
            
            --[[ notes for later...
            -- Codex_DefaultGiftHint
            -- Codex_KeepGoingHint
            -- Codex_LockedActivityHint
            -- Codex_FishingGiftHint
            -- Codex_HotSpringsGiftHint
            -- Codex_TavernaGiftHint
            -- Codex_FishNextHint
            -- Codex_UnavailableHint
            -- a few character-specific hints as well
            ]]--

            local scaleX = math.max(0.05, iconFilled * 0.05)
            local heart = "{!Icons.RelationshipHeartIcon}"
            local heartString = string.rep(heart, iconFilled)


            local giftDisplay = game.CreateScreenComponent({
                Name = "BlankObstacle",
                X = game.ScreenCenterX,
                Y = 50
            })
            local id = giftDisplay.Id
            game.ScreenAnchors["GiftDisplay"] = giftDisplay

            game.SetColor({ Id = id, Color = { 0, 0, 0, 0 } })
            game.SetAlpha({ Id = id, Fraction = 0.8, Duration = 0.1 })
            game.SetAnimation({ Name = "GUI\\TextBacking", DestinationId = id })
            game.SetScaleX({ Id = id, Fraction = scaleX })
            game.SetScaleY({ Id = id, Fraction = 0.5 })


            if iconFilled == 0 then
                local emptyHeart = game.CreateScreenComponent({ Name = "BlankObstacle" })
                game.ScreenAnchors["EmptyHeart"] = emptyHeart
                game.SetAlpha({ Id = emptyHeart.id, Fraction = 0.8, Duration = 0.1 })
                game.SetAnimation({ Name = "GUI\\Icons\\AphroditeInactive", DestinationId = emptyHeart.Id, Scale = 0.4 })
                game.Attach({ Id = emptyHeart.Id, DestinationId = id })
            else
                game.CreateTextBox({
                    Id = id,
                    Text = heartString,
                    Font = "LatoMedium",
                    FontSize = 14,
                    Justification = "Center",
                    Color = game.Color.White
                })
            end
        end
    end
end

-- this allows us to limit certain functions to not be reloaded.
local loader = reload.auto_single()

-- this runs only when modutil and the game's lua is ready
modutil.once_loaded.game(function()
    loader.load(on_ready, on_reload)
end)
