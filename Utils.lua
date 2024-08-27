local json = require("json")
Utils = Utils or {}

function Utils.updateRandomness(blockHeight)
    assert(tonumber(blockHeight), "Improper arguments")

    local blockHeightNumber = tonumber(blockHeight)
    local randomFactor1 = math.random()
    local randomFactor2 = math.random()
    local randomFactor3 = math.random()
    local randomFactor4 = math.random()

    local mathing = ((blockHeightNumber * randomFactor1) / (Constants.OldRandomSeed + randomFactor2) * randomFactor3) + randomFactor4

    local seed = math.floor(mathing * 2 ^ 32) % 2 ^ 32
    math.randomseed(seed)

    Constants.OldRandomSeed = seed
end

function Utils.stringifyCards(cards)
    local cardStrings = {}
    for _, card in ipairs(cards) do
        table.insert(cardStrings, card.value .. " of " .. card.suit)
    end
    return table.concat(cardStrings, ", ")
end

function Utils.calculateHandValue(hand)
    local total = 0
    local aces = 0

    for _, card in ipairs(hand) do
        local value = card.value
        if value == "J" or value == "Q" or value == "K" then
            total = total + 10
        elseif value == "A" then
            aces = aces + 1
            total = total + 11
        else
            total = total + tonumber(value)
        end
    end

    while total > 21 and aces > 0 do
        total = total - 10
        aces = aces - 1
    end

    return total
end

function Utils.calculateCardValue(value)
    if value == "J" or value == "Q" or value == "K" then
        return 10
    elseif value == "A" then
        return 11
    else
        return tonumber(value)
    end
end

function Utils.hasSoft17(hand)
    local hasAce = false
    for _, card in ipairs(hand) do
        if card.value == "A" then
            hasAce = true
        end
    end
    return hasAce and Utils.calculateHandValue(hand) == 17
end

function Utils.checkTokenValidity(tokenProcess)
    -- print("Checking token validity")
    for _, token in ipairs(Constants.Tokens) do
        if tokenProcess == token.process then
            return true, token
        end
    end
    return false, nil
end

function Utils.returnBet(token, playerName, quantity, message)
    LockedBalance[token] = LockedBalance[token] - quantity
    Send({
        Target = token,
        Action = "Transfer",
        Recipient = playerName,
        Quantity = tostring(quantity),
        ["X-Note"] = message
    })
    Send({
        Target = playerName,
        Action = "BlackJackMessage",
        Data = message
    })
end

function Utils.handleNewGame(playerName, quantity, tokenDetails, llama)
    if quantity >= tokenDetails.minBet and quantity <= tokenDetails.maxBet then
        -- print("first if passed")
        -- print(quantity)
        local potentialPayout = tonumber(quantity) * 2
        if not LockedBalance[tokenDetails.process] then
            LockedBalance[tokenDetails.process] = 0
        end
        if HouseBalance[tokenDetails.process] - LockedBalance[tokenDetails.process] >= potentialPayout then
            -- print("Second if passed")
            local success, err = pcall(State.addPlayerGameState, playerName, quantity, tokenDetails.process)
            if not success then
                print("Error in addPlayerGameState: " .. err)
            else
                pcall(State.sendGameStateMessage, playerName, llama)
            end
        else
            Utils.returnBet(tokenDetails.process, playerName, quantity, "Insufficient house funds to cover potential payout")
        end
    else
        Utils.returnBet(tokenDetails.process, playerName, quantity, "Bet amount out of range")
    end
end

function Utils.handleDoubleDown(playerName, quantity, gameState)
    local token = gameState.token
    if quantity == gameState.hands[gameState.activeHandIndex].bet then
        if #gameState.hands[gameState.activeHandIndex].cards == 2 and not gameState.hands[gameState.activeHandIndex].doubledDown then
            local doubleDownBet = gameState.hands[gameState.activeHandIndex].bet
            local potentialPayout = doubleDownBet * 2
            if HouseBalance[token] - LockedBalance[token] >= potentialPayout then
                gameState.hands[gameState.activeHandIndex].doubledDown = true
                gameState.hands[gameState.activeHandIndex].bet = gameState.hands[gameState.activeHandIndex].bet + doubleDownBet
                LockedBalance[token] = LockedBalance[token] + doubleDownBet
                local newCard = table.remove(gameState.deck)
                table.insert(gameState.hands[gameState.activeHandIndex].cards, newCard)
                pcall(State.sendGameStateMessage, playerName)
                pcall(State.moveToNextHandOrDealer, playerName)
            else
                Utils.returnBet(token, playerName, quantity, "Insufficient funds to cover potential payout for double down")
            end
        else
            Utils.returnBet(token, playerName, quantity, "You cannot double down at this stage.")
        end
    else
        Utils.returnBet(token, playerName, quantity, "Double down bet amount must match the original bet.")
    end
end

function Utils.handleSplitBet(playerName, quantity, gameState)
    local token = gameState.token
    if quantity == gameState.hands[gameState.activeHandIndex].bet then
        local activeHand = gameState.hands[gameState.activeHandIndex]
        if #activeHand.cards == 2 and Utils.calculateCardValue(activeHand.cards[1].value) == Utils.calculateCardValue(activeHand.cards[2].value) then
            local splitBet = activeHand.bet
            local potentialPayout = splitBet * 2
            if HouseBalance[token] - LockedBalance[token] >= potentialPayout then
                LockedBalance[token] = LockedBalance[token] + splitBet
                local newCard1 = table.remove(gameState.deck)
                local newCard2 = table.remove(gameState.deck)
                local newHand1 = { cards = { activeHand.cards[1], newCard1 }, bet = splitBet }
                local newHand2 = { cards = { activeHand.cards[2], newCard2 }, bet = splitBet }
                gameState.hands[gameState.activeHandIndex] = newHand1
                table.insert(gameState.hands, gameState.activeHandIndex + 1, newHand2)
                pcall(State.sendGameStateMessage, playerName)
            else
                Utils.returnBet(token, playerName, quantity, "Insufficient funds to cover potential payout for split.")
            end
        else
            Utils.returnBet(token, playerName, quantity, "You cannot split at this stage.")
        end
    else
        Utils.returnBet(token, playerName, quantity, "Split bet amount must match the original bet.")
    end
end

function Utils.handleInsuranceBet(playerName, quantity, gameState)
    local token = gameState.token
    if gameState.dealerCards[2].value == "A" then
        local insuranceBet = gameState.hands[gameState.activeHandIndex].bet / 2
        local potentialPayout = insuranceBet * 2

        if HouseBalance[token] - LockedBalance[token] >= potentialPayout then
            LockedBalance[token] = LockedBalance[token] + insuranceBet
            gameState.insuranceBet = insuranceBet
            Send({ Target = playerName, Action = "BlackJackMessage", Data = "Insurance taken" })

            if Utils.calculateHandValue(gameState.dealerCards) == 21 then
                local message = "Dealer has blackjack! Insurance pays 2:1"
                Send({
                    Target = token,
                    Action = "Transfer",
                    Recipient = playerName,
                    Quantity = tostring(insuranceBet * 2),
                    ["X-Note"] = "Insurance payout"
                })
                Send({ Target = playerName, Action = "BlackJackMessage", State = json.encode(gameState), Data = message })
                while Utils.calculateHandValue(gameState.hands[gameState.activeHandIndex].cards) < 21 do
                    local newCard = table.remove(gameState.deck)
                    table.insert(gameState.hands[gameState.activeHandIndex].cards, newCard)
                end
                pcall(State.resolveGame, playerName)
            else
                local message = "Dealer does not have blackjack. Insurance bet lost."
                LockedBalance[token] = LockedBalance[token] - insuranceBet -- decrement if lost
                Send({ Target = playerName, Action = "BlackJackMessage", State = json.encode(gameState), Data = message })
            end
        else
            Utils.returnBet(token, playerName, quantity, "Insurance not available due to insufficient funds")
        end
    else
        Utils.returnBet(token, playerName, quantity, "Insurance not available")
    end
end

return Utils
