-- math.randomseed(os.time()) -- os is not available in this environment. os.time() will always return 10
CRED = "Sa0iBLPNyJQrwpTTG-tWLQU-1QeUAJA73DdxGGiKoJc"
WAR = "xU9zFkq3X2ZQ6olwNVvr1vUWIjc3kXTWr7xKQD6dh10"
TestToken = "1PIaQp_wij0H8Ykx-LuQEUqXQndryycWRjCRvV3R8lI"
OldRandomSeed = OldRandomSeed or 69420

gameStates = gameStates or {}
houseBalance = houseBalance or 0
lockedBalance = lockedBalance or 0


function updateRandomness(blockHeight)
    assert(tonumber(blockHeight), "Improper arguments")

    local blockHeightNumber = tonumber(blockHeight)

    -- Generate a series of pseudo-random numbers
    local randomFactor1 = math.random()
    local randomFactor2 = math.random()
    local randomFactor3 = math.random()
    local randomFactor4 = math.random()

    -- Combine the block height with random factors to create a more complex seed
    local mathing = ((blockHeightNumber * randomFactor1) / (OldRandomSeed + randomFactor2) * randomFactor3) +
    randomFactor4

    -- Ensure the seed is within the 32-bit integer range
    local seed = math.floor(mathing * 2 ^ 32) % 2 ^ 32

    math.randomseed(seed)

    OldRandomSeed = seed
end

-- Function to create a new deck of cards
function createDeck()
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

-- Function to shuffle the deck
function shuffleDeck(deck)
    for i = #deck, 2, -1 do
        local j = math.random(i)
        deck[i], deck[j] = deck[j], deck[i]
    end
end

-- Function to deal cards from the deck
function dealCards(deck, numCards)
    local cards = {}
    for i = 1, numCards do
        table.insert(cards, table.remove(deck))
    end
    return cards
end

-- Initialize a game state for a player
function addPlayerGameState(playerName, betAmount)
    local deck = createDeck()
    shuffleDeck(deck)
    local playerCards = dealCards(deck, 2)
    local dealerCards = dealCards(deck, 2)

    gameStates[playerName] = {
        hands = { { cards = playerCards, bet = betAmount } },
        activeHandIndex = 1,
        dealerCards = dealerCards,
        dealerCardShown = false,
        deck = deck,
        originalBet = betAmount,
        insuranceBet = 0
    }
    lockedBalance = lockedBalance + (betAmount * 2)
end

function endGame(playerName)
    Send({ Target = TestToken, Action = "Balance", Tags = { Target = ao.id } })
    -- Check if the game state for the player exists
    if gameStates[playerName] then
        -- Unlock the locked balance
        for _, hand in ipairs(gameStates[playerName].hands) do
            lockedBalance = lockedBalance - (hand.bet * 2)
        end
        -- Remove the player's game state by setting it to nil
        gameStates[playerName] = nil
        print(playerName .. "'s game has ended and their state has been removed.")
    else
        print("No game state found for " .. playerName .. ".")
    end
end

-- Function to evaluate if a message should trigger the handler
local function isCredBalanceMessage(msg)
    if msg.From == TestToken and msg.Tags.Balance then
        print("This is a cred balance message")
        return true
    else
        return false
    end
end

local function isCreditNoticeMessage(msg)
    if msg.From == TestToken and msg.Action == "Credit-Notice" then
        print("This is a credit notice message")
        return true
    else
        print("Not a credit message")
        return false
    end
end

function getGameState(playerName)
    local gameState = gameStates[playerName]
    if not gameState then
        print("Game state for player " .. playerName .. " does not exist.")
        return nil
    else
        -- Copy the gameState to avoid modifying the original
        local gameStateCopy = {
            hands = gameState.hands,
            activeHandIndex = gameState.activeHandIndex,
            dealerCards = {},
            dealerCardShown = gameState.dealerCardShown,
            originalBet = gameState.originalBet,
            deck = gameState.deck
        }

        if gameState.dealerCardShown then
            gameStateCopy.dealerCards = gameState.dealerCards
        else
            gameStateCopy.dealerCards[1] = gameState.dealerCards[2]
        end

        return gameStateCopy
    end
end

function sendGameStateMessage(playerName)
    local success, state = pcall(getGameState, playerName)
    if success and state then
        print(state)
        -- Stringify all player's hands
        local allPlayerHandsString = ""
        for i, hand in ipairs(state.hands) do
            local playerCardsString = stringifyCards(hand.cards)
            allPlayerHandsString = allPlayerHandsString .. "Hand " .. i .. ": " .. playerCardsString .. ". "
        end
        local dealerCardsString = stringifyCards(state.dealerCards)

        -- Prepare and send the game state message to the player
        local message = "Your cards are: " ..
        allPlayerHandsString ..
        "And the dealer is showing: " ..
        dealerCardsString .. ". Your active hand is: " .. tostring(state.activeHandIndex)
        Send({ Target = playerName, Action = "BlackJackMessage", Wager = tostring(state.originalBet), Data = message })
        print("Sent message to " .. playerName .. ": " .. message)
    else
        -- Handle the case where there is no active game for the player
        local message = "You have no active game, start one by sending a bet"
        Send({ Target = playerName, Action = "BlackJackMessage", Data = message })
        print("Sent message to " .. playerName .. ": " .. message)
        if not success then print("Error in sendGameStateMessage: " .. state) end
    end
end

function sendFinalGameStateMessage(playerName, resultMessage)
    local success, gameState = pcall(function() return gameStates[playerName] end)
    if success and gameState then
        -- Adjusted to use activeHandIndex-1 correctly
        local hand = gameState.hands[gameState.activeHandIndex - 1]
        local playerCardsString, dealerCardsString = "", ""

        if hand and hand.cards then
            playerCardsString = stringifyCards(hand.cards)
        else
            if hand then
                print("Hand is present")
            else
                print("No Hand")
            end
            if hand and hand.cards then
                print("Cards found")
            else
                print("No Cards")
            end
            print("Error: Player hand or cards are nil.")
        end

        if gameState.dealerCards then
            dealerCardsString = stringifyCards(gameState.dealerCards)
        else
            print("Error: Dealer cards are nil.")
        end

        local message = resultMessage ..
            " Your final cards were: " .. playerCardsString .. ". Dealer's final cards were: " .. dealerCardsString
        Send({ Target = playerName, Action = "BlackJackMessage", Data = message })
        print("Sent final game state to " .. playerName .. ": " .. message)
    else
        if not success then
            print("Error in sendFinalGameStateMessage: " .. gameState)
        else
            print("Error: gameState is nil.")
        end
    end
end

function stringifyCards(cards)
    local cardStrings = {}
    for _, card in ipairs(cards) do
        table.insert(cardStrings, card.value .. " of " .. card.suit)
    end
    return table.concat(cardStrings, ", ")
end

Handlers.add(
    "CredBalance",
    isCredBalanceMessage,
    function(msg)
        print("Updating house balance, new balance is " .. msg.Tags.Balance)
        houseBalance = msg.Tags.Balance
    end
)

Handlers.add(
    "Credit-Notice",
    isCreditNoticeMessage,
    function(msg)
        updateRandomness(msg["Block-Height"])
        print("credit notice received")
        local playerName = msg.Tags.Sender
        local quantity = tonumber(msg.Tags.Quantity)
        local xNote = msg.Tags["X-Note"]

        if xNote == "Bankroll" then
            Send({ Target = TestToken, Action = "Balance" })
            return
        end

        if not gameStates[playerName] then
            -- No active game, treat it as a new bet if the amount is within limits
            if quantity >= 10 and quantity <= 1000 then
                local potentialPayout = quantity * 2
                if houseBalance - lockedBalance >= potentialPayout then
                    local success, err = pcall(addPlayerGameState, playerName, quantity)
                    if not success then
                        print("Error in addPlayerGameState: " .. err)
                    else
                        print(playerName .. " has started a game with a bet of " .. quantity .. " CRED units.")
                        -- Send the game state to the player
                        pcall(sendGameStateMessage, playerName)
                    end
                else
                    print("Insufficient funds to cover potential payout.")
                    -- Return the bet if the house cannot cover the potential payout
                    local message = "Insufficient funds to cover potential payout"
                    Send({
                        Target = TestToken,
                        Action = "Transfer",
                        Recipient = playerName,
                        Quantity = tostring(quantity),
                        ["X-Note"] = message
                    })
                    print("Sent message to " .. playerName .. ": " .. message)
                    Send({
                        Target = playerName,
                        Action = "BlackJackMessage",
                        Data =
                        "The house cannot cover your potential winnings at this time, your bet has been returned to you"
                    })
                    print("Sent message to " ..
                        playerName ..
                        ": The house cannot cover your potential winnings at this time, your bet has been returned to you")
                end
            else
                print("Bet amount out of range.")
                -- Return the bet if it's not within the allowed range
                local message = "Bet amount out of range"
                Send({
                    Target = TestToken,
                    Action = "Transfer",
                    Recipient = playerName,
                    Quantity = tostring(quantity),
                    ["X-Note"] = message
                })
                print("Sent message to " .. playerName .. ": " .. message)
                Send({
                    Target = playerName,
                    Action = "BlackJackMessage",
                    Data =
                    "Bets must be between 10 and 1000 CRED units, your bet has been returned to you"
                })
                print("Sent message to " ..
                    playerName .. ": Bets must be between 10 and 1000 CRED units, your bet has been returned to you")
            end
        else
            -- Active game exists, check if this is a double down, split, or insurance attempt
            local gameState = gameStates[playerName]
            if xNote == "Double down bet" then
                print("double down received, quantity: " .. quantity)
                if quantity == gameState.hands[gameState.activeHandIndex].bet then
                    if #gameState.hands[gameState.activeHandIndex].cards == 2 and not gameState.hands[gameState.activeHandIndex].doubledDown then
                        print("double down valid")
                        local doubleDownBet = gameState.hands[gameState.activeHandIndex].bet
                        local potentialPayout = doubleDownBet * 2
                        if houseBalance - lockedBalance >= potentialPayout then
                            -- Player can double down
                            gameState.hands[gameState.activeHandIndex].doubledDown = true
                            gameState.hands[gameState.activeHandIndex].bet = gameState.hands[gameState.activeHandIndex]
                                .bet + doubleDownBet
                            lockedBalance = lockedBalance + doubleDownBet
                            -- Draw one additional card
                            local success, newCard = pcall(function() return table.remove(gameState.deck) end)
                            if not success then print("Error in drawing card: " .. newCard) end
                            table.insert(gameState.hands[gameState.activeHandIndex].cards, newCard)

                            -- Send updated game state
                            pcall(sendGameStateMessage, playerName)

                            -- Automatically stay after doubling down
                            pcall(moveToNextHandOrDealer, playerName)
                        else
                            print("Insufficient funds to cover potential payout for double down.")
                            -- Return the bet if the house cannot cover the potential payout
                            local message = "Insufficient funds to cover potential payout for double down"
                            Send({
                                Target = TestToken,
                                Action = "Transfer",
                                Recipient = playerName,
                                Quantity = tostring(
                                    quantity),
                                ["X-Note"] = message
                            })
                            print("Sent message to " .. playerName .. ": " .. message)
                            Send({
                                Target = playerName,
                                Action = "BlackJackMessage",
                                Data =
                                "The house cannot cover your potential double down winnings at this time, your double down bet has been returned to you"
                            })
                            print("Sent message to " ..
                                playerName ..
                                ": The house cannot cover your potential double down winnings at this time, your double down bet has been returned to you")
                        end
                    else
                        local message = "You cannot double down at this stage."
                        Send({
                            Target = TestToken,
                            Action = "Transfer",
                            Recipient = playerName,
                            Quantity = tostring(
                                quantity),
                            ["X-Note"] = message
                        })
                        print("Sent refund message to " .. playerName .. " due to: " .. message)
                        Send({ Target = playerName, Action = "BlackJackMessage", Data = message })
                        print("Sent message to " .. playerName .. ": " .. message)
                    end
                else
                    local message = "Double down bet amount must match the original bet."
                    Send({
                        Target = TestToken,
                        Action = "Transfer",
                        Recipient = playerName,
                        Quantity = tostring(quantity),
                        ["X-Note"] = message
                    })
                    print("Sent refund message to " .. playerName .. " due to: " .. message)
                    Send({ Target = playerName, Action = "BlackJackMessage", Data = message })
                    print("Sent message to " .. playerName .. ": " .. message)
                end
            elseif xNote == "Split bet" then
                if quantity == gameState.hands[gameState.activeHandIndex].bet then
                    local activeHand = gameState.hands[gameState.activeHandIndex]
                    if #activeHand.cards == 2 and calculateCardValue(activeHand.cards[1].value) == calculateCardValue(activeHand.cards[2].value) then
                        local splitBet = activeHand.bet
                        local potentialPayout = splitBet * 2
                        if houseBalance - lockedBalance >= potentialPayout then
                            -- Player can split
                            lockedBalance = lockedBalance + splitBet
                            local success1, newCard1 = pcall(function() return table.remove(gameState.deck) end)
                            local success2, newCard2 = pcall(function() return table.remove(gameState.deck) end)
                            if not success1 then print("Error in drawing card for split: " .. newCard1) end
                            if not success2 then print("Error in drawing card for split: " .. newCard2) end
                            local newHand1 = { cards = { activeHand.cards[1], newCard1 }, bet = splitBet }
                            local newHand2 = { cards = { activeHand.cards[2], newCard2 }, bet = splitBet }
                            gameState.hands[gameState.activeHandIndex] = newHand1
                            table.insert(gameState.hands, gameState.activeHandIndex + 1, newHand2)

                            -- Send updated game state
                            pcall(sendGameStateMessage, playerName)
                        else
                            print("Insufficient funds to cover potential payout for split.")
                            -- Return the bet if the house cannot cover the potential payout
                            local message = "Insufficient funds to cover potential payout for split"
                            Send({
                                Target = TestToken,
                                Action = "Transfer",
                                Recipient = playerName,
                                Quantity = tostring(
                                    quantity),
                                ["X-Note"] = message
                            })
                            print("Sent message to " .. playerName .. ": " .. message)
                            Send({
                                Target = playerName,
                                Action = "BlackJackMessage",
                                Data =
                                "The house cannot cover your potential split winnings at this time, your split bet has been returned to you"
                            })
                            print("Sent message to " ..
                                playerName ..
                                ": The house cannot cover your potential split winnings at this time, your split bet has been returned to you")
                        end
                    else
                        local message = "You cannot split at this stage."
                        Send({
                            Target = TestToken,
                            Action = "Transfer",
                            Recipient = playerName,
                            Quantity = tostring(
                                quantity),
                            ["X-Note"] = message
                        })
                        print("Sent refund message to " .. playerName .. " due to: " .. message)
                        Send({ Target = playerName, Action = "BlackJackMessage", Data = message })
                        print("Sent message to " .. playerName .. ": " .. message)
                    end
                else
                    local message = "Split bet amount must match the original bet."
                    Send({
                        Target = TestToken,
                        Action = "Transfer",
                        Recipient = playerName,
                        Quantity = tostring(quantity),
                        ["X-Note"] = message
                    })
                    print("Sent refund message to " .. playerName .. " due to: " .. message)
                    Send({ Target = playerName, Action = "BlackJackMessage", Data = message })
                    print("Sent message to " .. playerName .. ": " .. message)
                end
            elseif xNote == "Insurance bet" then
                if gameState.dealerCards[2].value == "A" then
                    local insuranceBet = gameState.hands[gameState.activeHandIndex].bet / 2
                    local potentialPayout = insuranceBet * 2

                    if houseBalance - lockedBalance >= potentialPayout then
                        lockedBalance = lockedBalance + insuranceBet
                        gameState.insuranceBet = insuranceBet
                        Send({ Target = playerName, Action = "BlackJackMessage", Data = "Insurance taken" })
                        print("Sent message to " .. playerName .. ": Insurance taken")

                        -- Resolve insurance bet if dealer has blackjack
                        if calculateHandValue(gameState.dealerCards) == 21 then
                            local message = "Dealer has blackjack! Insurance pays 2:1"
                            Send({
                                Target = TestToken,
                                Action = "Transfer",
                                Recipient = playerName,
                                Quantity = tostring(
                                    insuranceBet * 2),
                                ["X-Note"] = "Insurance payout"
                            })
                            print("Sent message to " .. playerName .. ": " .. message)
                            Send({ Target = playerName, Action = "BlackJackMessage", Data = message })
                            print("Sent message to " .. playerName .. ": " .. message)
                            -- Auto resolve player hand since dealer has blackjack
                            while calculateHandValue(gameState.hands[gameState.activeHandIndex].cards) < 21 do
                                local newCard = table.remove(gameState.deck)
                                table.insert(gameState.hands[gameState.activeHandIndex].cards, newCard)
                            end
                            pcall(resolveGame, playerName)
                        else
                            local message = "Dealer does not have blackjack. Insurance bet lost."
                            Send({ Target = playerName, Action = "BlackJackMessage", Data = message })
                            print("Sent message to " .. playerName .. ": " .. message)
                        end
                    else
                        local message = "Insurance not available due to insufficient funds"
                        Send({
                            Target = TestToken,
                            Action = "Transfer",
                            Recipient = playerName,
                            Quantity = tostring(
                                quantity),
                            ["X-Note"] = message
                        })
                        print("Sent refund message to " .. playerName .. " due to: " .. message)
                        Send({ Target = playerName, Action = "BlackJackMessage", Data = message })
                        print("Sent message to " .. playerName .. ": " .. message)
                    end
                else
                    local message = "Insurance not available"
                    Send({
                        Target = TestToken,
                        Action = "Transfer",
                        Recipient = playerName,
                        Quantity = tostring(quantity),
                        ["X-Note"] = message
                    })
                    print("Sent refund message to " .. playerName .. " due to: " .. message)
                    Send({ Target = playerName, Action = "BlackJackMessage", Data = message })
                    print("Sent message to " .. playerName .. ": " .. message)
                end
            else
                -- If not a double down, split, or insurance, check if it's a regular game update
                local message = "You already have an active game. Finish it before starting a new one."
                Send({
                    Target = TestToken,
                    Action = "Transfer",
                    Recipient = playerName,
                    Quantity = tostring(quantity),
                    ["X-Note"] = message
                })
                print("Sent refund message to " .. playerName .. " due to: " .. message)
                Send({ Target = playerName, Action = "BlackJackMessage", Data = message })
                print("Sent message to " .. playerName .. ": " .. message)
            end
        end
    end
)

Handlers.add(
    "showState",
    Handlers.utils.hasMatchingTag("Action", "showState"),
    function(msg)
        updateRandomness(msg["Block-Height"])
        local caller = msg.Caller or msg.From
        print("Sending game state for " .. caller)
        local success, err = pcall(sendGameStateMessage, caller)
        if not success then print("Error in showState handler: " .. err) end
    end
)

-- A helper function to calculate the total value of a hand, considering Aces as 1 or 11
function calculateHandValue(hand)
    local total = 0
    local aces = 0

    for _, card in ipairs(hand) do
        local value = card.value
        if value == "J" or value == "Q" or value == "K" then
            total = total + 10
        elseif value == "A" then
            aces = aces + 1
            total = total + 11 -- Consider Ace as 11 initially
        else
            total = total + tonumber(value)
        end
    end

    -- Adjust for Aces if total is over 21
    while total > 21 and aces > 0 do
        total = total - 10 -- Change one Ace from 11 to 1
        aces = aces - 1
    end

    return total
end

function calculateCardValue(value)
    if value == "J" or value == "Q" or value == "K" then
        return 10
    elseif value == "A" then
        return 11
    else
        return tonumber(value)
    end
end

function hasSoft17(hand)
    local hasAce = false
    for _, card in ipairs(hand) do
        if card.value == "A" then
            hasAce = true
        end
    end
    return hasAce and calculateHandValue(hand) == 17
end

function dealerDraw(playerName)
    local success, err = pcall(function()
        local gameState = gameStates[playerName]
        if not gameState then
            print("Game state for player " .. playerName .. " does not exist.")
            return
        end

        -- Ensure the dealer's second card is shown
        gameState.dealerCardShown = true

        local dealerHandValue = calculateHandValue(gameState.dealerCards)

        while dealerHandValue < 17 or hasSoft17(gameState.dealerCards) do
            local card = table.remove(gameState.deck)
            table.insert(gameState.dealerCards, card)
            dealerHandValue = calculateHandValue(gameState.dealerCards)
        end

        resolveGame(playerName)
    end)
    if not success then print("Error in dealerDraw: " .. err) end
end

function resolveGame(playerName)
    local success, err = pcall(function()
        local gameState = gameStates[playerName]
        for _, hand in ipairs(gameState.hands) do
            local playerHandValue = calculateHandValue(hand.cards)
            local dealerHandValue = calculateHandValue(gameState.dealerCards)

            -- Determine the game's outcome
            local resultMessage
            if playerHandValue > 21 then
                resultMessage = "Busted! Your hand value exceeded 21. You lose."
            elseif dealerHandValue > 21 or playerHandValue > dealerHandValue then
                resultMessage = "Winner Winner Chicken Dinner!!!! (as long as you spend that CRED on a chicken dinner)"
                Send({
                    Target = TestToken,
                    Action = "Transfer",
                    Recipient = playerName,
                    Quantity = tostring(hand.bet * 2),
                    ["X-Note"] = "You won!"
                })
            elseif dealerHandValue > playerHandValue then
                resultMessage = "Dealer wins. Better luck next time."
            else -- dealerHandValue == playerHandValue
                resultMessage = "It's a Push!"
                Send({
                    Target = TestToken,
                    Action = "Transfer",
                    Recipient = playerName,
                    Quantity = tostring(hand.bet),
                    ["X-Note"] = "It's a push!"
                })
            end

            -- Send the result to the player
            local success, err = pcall(sendFinalGameStateMessage, playerName, resultMessage)
            if not success then print("Error in sendFinalGameStateMessage: " .. err) end
        end

        pcall(endGame, playerName)
    end)
    if not success then print("Error in resolveGame: " .. err) end
end

function moveToNextHandOrDealer(playerName)
    local success, err = pcall(function()
        local gameState = gameStates[playerName]
        gameState.activeHandIndex = gameState.activeHandIndex + 1
        if gameState.activeHandIndex > #gameState.hands then
            pcall(dealerDraw, playerName)
        else
            pcall(sendGameStateMessage, playerName)
        end
    end)
    if not success then print("Error in moveToNextHandOrDealer: " .. err) end
end

Handlers.add(
    "Hit",
    Handlers.utils.hasMatchingTag("Action", "Hit"),
    function(msg)
        updateRandomness(msg["Block-Height"])
        local success, err = pcall(function()
            if not gameStates[msg.From] then
                -- No active game for this user
                Send({
                    Target = msg.From,
                    Action = "BlackJackMessage",
                    Data =
                    "You have no active game. Start one by placing a bet."
                })
                print("Sent message to " .. msg.From .. ": You have no active game. Start one by placing a bet.")
            else
                -- Active game exists, proceed with drawing a card
                local gameState = gameStates[msg.From]
                local newCard = table.remove(gameState.deck)                            -- Draw the top card from the deck
                table.insert(gameState.hands[gameState.activeHandIndex].cards, newCard) -- Add the new card to the player's hand

                local playerHandValue = calculateHandValue(gameState.hands[gameState.activeHandIndex].cards)

                if playerHandValue == 21 then
                    Send({ Target = msg.From, Action = "BlackJackMessage", Data = "21! Dealer's draw" })
                    print("Sent message to " .. msg.From .. ": 21! Dealer's draw")
                    moveToNextHandOrDealer(msg.From)
                elseif playerHandValue > 21 then
                    -- Player has busted
                    Send({
                        Target = msg.From,
                        Action = "BlackJackMessage",
                        Data =
                        "Busted! Your hand value exceeded 21. Game over for this hand."
                    })
                    gameState.hands[gameState.activeHandIndex].dealerCardShown = true

                    sendGameStateMessage(msg.From)

                    print("Sent message to " ..
                        msg.From .. ": Busted! Your hand value exceeded 21. Game over for this hand.")
                    moveToNextHandOrDealer(msg.From)
                else
                    -- Player has not busted, send the updated game state
                    sendGameStateMessage(msg.From)
                end
            end
        end)
        if not success then print("Error in Hit handler: " .. err) end
    end
)

Handlers.add(
    "Stay",
    Handlers.utils.hasMatchingTag("Action", "Stay"),
    function(msg)
        updateRandomness(msg["Block-Height"])
        local success, err = pcall(function()
            if not gameStates[msg.From] then
                -- No active game
                Send({
                    Target = msg.From,
                    Action = "BlackJackMessage",
                    Data =
                    "You have no active game. Start one by placing a bet."
                })
                print("Sent message to " .. msg.From .. ": You have no active game. Start one by placing a bet.")
            else
                moveToNextHandOrDealer(msg.From)
            end
        end)
        if not success then print("Error in Stay handler: " .. err) end
    end
)
