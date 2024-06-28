-- Constants.lua
Constants = Constants or {}
Constants.CRED = "Sa0iBLPNyJQrwpTTG-tWLQU-1QeUAJA73DdxGGiKoJc"
Constants.WAR = "xU9zFkq3X2ZQ6olwNVvr1vUWIjc3kXTWr7xKQD6dh10"
Constants.TestToken = "1PIaQp_wij0H8Ykx-LuQEUqXQndryycWRjCRvV3R8lI"
Constants.JOOSE = "YMs4s_KkK7JHG1y8QplgZz0RYuKL_46FLq5ZG4wWrn8"
Constants.OldRandomSeed = Constants.OldRandomSeed or 69420

-- Initialize Tokens and HouseBalance
Constants.Tokens = {
    { name = "JOOSE", process = Constants.JOOSE, minBet = 1000000000000, maxBet = 100000000000000},
    { name = "TestToken", process = Constants.TestToken, minBet = 100, maxBet = 1000 }
}

HouseBalance = HouseBalance or {
    [Constants.CRED] = 0,
    [Constants.WAR] = 0,
    [Constants.TestToken] = 0,
    [Constants.JOOSE]= 0
}

LockedBalance = LockedBalance or {
    [Constants.CRED] = 0,
    [Constants.WAR] = 0,
    [Constants.TestToken] = 0,
    [Constants.JOOSE] = 0
}

return Constants
