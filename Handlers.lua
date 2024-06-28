-- Handlers.lua
require("State")
require("Utils")
require("Constants")
local json = require("json")

Handlers = Handlers or {}


-- Updated Balance handler to check against all tokens in Constants
Handlers.add(
    "Balance",
    function(msg)
        for _, token in ipairs(Constants.Tokens) do
            if msg.From == token.process and msg.Tags.Balance then
                return true
            end
        end
        return false
    end,
    function(msg)
        Utils.updateRandomness(msg["Block-Height"])
        print("Attempting to update house balance for " .. msg.From)
        HouseBalance[msg.From] = tonumber(msg.Tags.Balance)
        print("balance updated")
    end
)

Handlers.add(
    "Credit-Notice",
    Handlers.utils.hasMatchingTag("Action", "Credit-Notice"),
    function(msg)
        Utils.updateRandomness(msg["Block-Height"])
        local playerName = msg.Tags.Sender
        local quantity = tonumber(msg.Tags.Quantity)
        local xNote = msg.Tags["X-Note"]
        print("credit notice received")
        local success, tokenValid, tokenDetails = pcall(Utils.checkTokenValidity, msg.From)
        if not success then
            print("Error in checkTokenValidity: " .. tostring(tokenValid)) -- tokenValid contains the error message in this case
            return
        end
        if not tokenValid then
            print("Invalid TOken")
            Utils.returnBet(msg.From, playerName, quantity, "Invalid token received.")
            return
        end

        if xNote == "Bankroll" then
            Send({ Target = msg.From, Action = "Balance" })
            return
        end

        if tokenDetails and not State.GameStates[playerName] then
            print(tokenDetails)
            local newGameSuccess, err = pcall(Utils.handleNewGame, playerName, quantity, tokenDetails)
            if not newGameSuccess then
                print("Error in handleNewGame: " .. err)
            end
        else
            local gameState = State.GameStates[playerName]
            if gameState and gameState.token ~= msg.From then
                Utils.returnBet(msg.From, playerName, quantity, "Token mismatch in active game.")
                return
            end

            if xNote == "Double down bet" then
                Utils.handleDoubleDown(playerName, quantity, gameState)
            elseif xNote == "Split bet" then
                Utils.handleSplitBet(playerName, quantity, gameState)
            elseif xNote == "Insurance bet" then
                Utils.handleInsuranceBet(playerName, quantity, gameState)
            else
                Utils.returnBet(msg.From, playerName, quantity,
                    "You already have an active game. Finish it before starting a new one.")
            end
        end
    end
)



Handlers.add(
    "Hit",
    function(msg) return msg.Tags.Action == "Hit" end,
    function(msg)
        Utils.updateRandomness(msg["Block-Height"])
        local playerName = msg.From
        if not State.GameStates[playerName] then
            Send({
                Target = playerName,
                Action = "BlackJackMessage",
                Data = "You have no active game. Start one by placing a bet."
            })
        else
            local gameState = State.GameStates[playerName]
            local newCard = table.remove(gameState.deck)
            table.insert(gameState.hands[gameState.activeHandIndex].cards, newCard)
            local playerHandValue = Utils.calculateHandValue(gameState.hands[gameState.activeHandIndex].cards)

            if playerHandValue == 21 then
                Send({ Target = playerName, Action = "BlackJackMessage", Data = "21! Dealer's draw" })
                State.moveToNextHandOrDealer(playerName)
            elseif playerHandValue > 21 then
                Send({
                    Target = playerName,
                    Action = "BlackJackMessage",
                    Data = "Busted! Your hand value exceeded 21. Game over for this hand."
                })
                gameState.hands[gameState.activeHandIndex].dealerCardShown = true
                State.moveToNextHandOrDealer(playerName)
            else
                State.sendGameStateMessage(playerName)
            end
        end
    end
)

Handlers.add(
    "Stay",
    function(msg) return msg.Tags.Action == "Stay" end,
    function(msg)
        Utils.updateRandomness(msg["Block-Height"])
        local playerName = msg.From
        if not State.GameStates[playerName] then
            Send({
                Target = playerName,
                Action = "BlackJackMessage",
                Data = "You have no active game. Start one by placing a bet."
            })
        else
            State.moveToNextHandOrDealer(playerName)
        end
    end
)

Handlers.add(
    "showState",
    function(msg) return msg.Tags.Action == "showState" end,
    function(msg)
        Utils.updateRandomness(msg["Block-Height"])
        local caller = msg.Caller or msg.From
        local success, err = pcall(State.sendGameStateMessage, caller)
        if not success then print("Error in showState handler: " .. err) end
    end
)

Handlers.add(
    "TokenInfo",
    function(msg) return msg.Tags.Action == "TokenInfo" end,
    function(msg)
        Utils.updateRandomness(msg["Block-Height"])
        Send({ Target = msg.From, Action = "TokenInfo", Data = json.encode(Constants.Tokens) })
    end
)

function Handlers.updateHouseBalance(token, balance)
    HouseBalance[token] = balance
end

function Handlers.getHouseBalance(token)
    Send({ Target = token, Action = "Balance" })
end

HandlersList = Handlers.list

return HandlersList
