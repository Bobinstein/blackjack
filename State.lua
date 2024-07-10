-- require("Utils")
local json = require("json")

State = State or {}

State.GameStates = State.GameStates or {}
State.HistoricState = State.HistoricState or {}

function State.createDeck()
    local suits = { "Hearts", "Diamonds", "Clubs", "Spades" }
    local values = { "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A" }
    local deck = {}
    for _, suit in ipairs(suits) do
        for _, value in ipairs(values) do
            table.insert(deck, { value = value, suit = suit })
        end
    end
    return deck
end

function State.shuffleDeck(deck)
    for i = #deck, 2, -1 do
        local j = math.random(i)
        deck[i], deck[j] = deck[j], deck[i]
    end
end

function State.dealCards(deck, numCards)
    local cards = {}
    for i = 1, numCards do
        table.insert(cards, table.remove(deck))
    end
    return cards
end

function State.addPlayerGameState(playerName, betAmount, token)
    local deck = State.createDeck()
    State.shuffleDeck(deck)
    local playerCards = State.dealCards(deck, 2)
    local dealerCards = State.dealCards(deck, 2)

    State.GameStates[playerName] = {
        hands = { { cards = playerCards, bet = betAmount } },
        activeHandIndex = 1,
        dealerCards = dealerCards,
        dealerCardShown = false,
        deck = deck,
        originalBet = betAmount,
        insuranceBet = 0,
        token = token
    }
    LockedBalance[token] = LockedBalance[token] + (betAmount * 2)
end

function State.endGame(playerName)
    local gameState = State.GameStates[playerName]
    if gameState then
        for _, hand in ipairs(gameState.hands) do
            LockedBalance[gameState.token] = LockedBalance[gameState.token] - (hand.bet * 2)
            if gameState.insuranceBet > 0 then
                LockedBalance[gameState.token] = LockedBalance[gameState.token] - gameState.insuranceBet
            end
            if LockedBalance[gameState.token] < 0 then
                LockedBalance[gameState.token] = 0
            end
        end
        Send({Target = gameState.token, Action = "Balance"})
        State.GameStates[playerName] = nil
    end
end

function State.getGameState(playerName)
    local gameState = State.GameStates[playerName]
    if not gameState then
        gameState = State.HistoricState[playerName]
    end
    if not gameState then
        return nil
    else
        local gameStateCopy = {
            hands = gameState.hands,
            activeHandIndex = gameState.activeHandIndex,
            dealerCards = {},
            dealerCardShown = gameState.dealerCardShown,
            originalBet = gameState.originalBet,
            deck = gameState.deck,
            token = gameState.token
        }
        if gameState.isHistoric then 
            gameStateCopy.isHistoric = gameState.isHistoric
        end
        if gameState.dealerCardShown then
            gameStateCopy.dealerCards = gameState.dealerCards
        else
            gameStateCopy.dealerCards[1] = gameState.dealerCards[2]
        end

        return gameStateCopy
    end
end

function State.sendGameStateMessage(playerName)
    local success, state = pcall(State.getGameState, playerName)
    if success and state then
        local allPlayerHandsString = ""
        for i, hand in ipairs(state.hands) do
            local playerCardsString = Utils.stringifyCards(hand.cards)
            allPlayerHandsString = allPlayerHandsString .. "Hand " .. i .. ": " .. playerCardsString .. ". "
        end
        local dealerCardsString = Utils.stringifyCards(state.dealerCards)
        local message = "Your cards are: " ..
            allPlayerHandsString ..
            "And the dealer is showing: " ..
            dealerCardsString .. ". Your active hand is: " .. tostring(state.activeHandIndex)
        local stateCopy = {
            token = state.token,
            hands = state.hands,
            insuranceBet = state.insuranceBet,
            originalBet = state.originalBet,
            dealerCardShown = state.dealerCardShown,
            dealerCards = state.dealerCards,
            activeHandIndex = state.activeHandIndex
        }
        if state.isHistoric then
            stateCopy.isHistoric = state.isHistoric
            message = "This game has ended"
            print("sending historic state")
        end
        Send({ Target = playerName, Action = "BlackJackMessage", State = json.encode(stateCopy), Data = message })
    else
        local message = "You have no active game, start one by sending a bet"
        Send({ Target = playerName, Action = "BlackJackMessage", Data = message })
    end
end

function State.sendFinalGameStateMessage(playerName, resultMessage)
    local success, gameState = pcall(State.getGameState, playerName)
    if success and gameState then
        local hand = gameState.hands[gameState.activeHandIndex - 1]
        local playerCardsString = hand and hand.cards and Utils.stringifyCards(hand.cards) or ""
        local dealerCardsString = gameState.dealerCards and Utils.stringifyCards(gameState.dealerCards) or ""
        local message = resultMessage ..
            " Your final cards were: " .. playerCardsString .. ". Dealer's final cards were: " .. dealerCardsString
        
        local stateCopy = {
            isHistoric = true,
            token = gameState.token,
            hands = gameState.hands,
            insuranceBet = gameState.insuranceBet,
            originalBet = gameState.originalBet,
            dealerCardShown = gameState.dealerCardShown,
            dealerCards = gameState.dealerCards
        }
        State.HistoricState[playerName] = stateCopy
        Send({ Target = playerName, Action = "BlackJackMessage", State = json.encode(stateCopy), Data = message })
    end
end

function State.moveToNextHandOrDealer(playerName)
    local success, err = pcall(function()
        local gameState = State.GameStates[playerName]
        gameState.activeHandIndex = gameState.activeHandIndex + 1
        if gameState.activeHandIndex > #gameState.hands then
            local allBusted = true
            for _, hand in ipairs(gameState.hands) do
                if Utils.calculateHandValue(hand.cards) <= 21 then
                    allBusted = false
                    break
                end
            end
            if allBusted then
                gameState.dealerCardShown = true
                State.resolveGame(playerName)
            else
                pcall(State.dealerDraw, playerName)
            end
        else
            pcall(State.sendGameStateMessage, playerName)
        end
    end)
    if not success then print("Error in moveToNextHandOrDealer: " .. err) end
end

function State.dealerDraw(playerName)
    local success, err = pcall(function()
        local gameState = State.GameStates[playerName]
        if not gameState then
            return
        end

        gameState.dealerCardShown = true
        local dealerHandValue = Utils.calculateHandValue(gameState.dealerCards)

        while dealerHandValue < 17 or Utils.hasSoft17(gameState.dealerCards) do
            local card = table.remove(gameState.deck)
            table.insert(gameState.dealerCards, card)
            dealerHandValue = Utils.calculateHandValue(gameState.dealerCards)
        end

        State.resolveGame(playerName)
    end)
    if not success then print("Error in dealerDraw: " .. err) end
end

function State.resolveGame(playerName)
    local success, err = pcall(function()
        local gameState = State.GameStates[playerName]
        for _, hand in ipairs(gameState.hands) do
            local playerHandValue = Utils.calculateHandValue(hand.cards)
            local dealerHandValue = Utils.calculateHandValue(gameState.dealerCards)
            local resultMessage

            if playerHandValue > 21 then
                resultMessage = "Busted! Your hand value exceeded 21. You lose."
            elseif dealerHandValue > 21 or playerHandValue > dealerHandValue then
                resultMessage = "Winner Winner Chicken Dinner!!!! (as long as you spend that CRED on a chicken dinner)"
                Send({
                    Target = gameState.token,
                    Action = "Transfer",
                    Recipient = playerName,
                    Quantity = tostring(hand.bet * 2),
                    ["X-Note"] = "You won!"
                })
            elseif dealerHandValue > playerHandValue then
                resultMessage = "Dealer wins. Better luck next time."
            else
                resultMessage = "It's a Push!"
                Send({
                    Target = gameState.token,
                    Action = "Transfer",
                    Recipient = playerName,
                    Quantity = tostring(hand.bet),
                    ["X-Note"] = "It's a push!"
                })
            end

            local success, err = pcall(State.sendFinalGameStateMessage, playerName, resultMessage)
            if not success then print("Error in sendFinalGameStateMessage: " .. err) end
        end

        pcall(State.endGame, playerName)
    end)
    if not success then print("Error in resolveGame: " .. err) end
end

return State
