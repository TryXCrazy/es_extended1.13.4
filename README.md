# Customized ESX Framework to VMS resources
| Compatible Resources  |
| ------------- |
| ✅ vms_cityhall| 
| ✅ vms_bossmenu| 
| ✅ vms_garagesV2| 

# VMS City Hall
#### Make these modifications if you use any multicharacter system:

#### es_extended/shared/config/main.lua
###### Lines 38-58
```diff
Config.LogPaycheck = false -- Logs paychecks to a nominated Discord channel via webhook (default is false)
Config.MaxWeight = 24 -- the max inventory weight without a backpack
Config.SaveDeathStatus = true -- Save the death status of a player
Config.EnableDebug = false -- Use Debug options?

Config.DefaultJobDuty = true -- A players default duty status when changing jobs

Config.EnablePaycheck = true -- enable paycheck
Config.PaycheckInterval = 7 * 60000 -- how often to receive paychecks in milliseconds
Config.EnableSocietyPayouts = false -- pay from the society account that the player is employed at? Requirement: esx_society
+ Config.AllowanceForUnemployedFromCityHallAccount = false -- Do you want unemployed players to receive paychecks from your city hall account?

+ Config.VMSCityhall = GetResourceState("vms_cityhall") ~= "missing"
+ Config.VMSBossMenu = GetResourceState("vms_bossmenu") ~= "missing"
+ Config.VMSGaragesV2 = GetResourceState("vms_garagesv2") ~= "missing"

Config.Multichar = GetResourceState("esx_multicharacter") ~= "missing"
Config.Identity = true -- Select a character identity data before they have loaded in (this happens by default with multichar)
Config.DistanceGive = 4.0 -- Max distance when giving items, weapons etc.

Config.AdminLogging = false -- Logs the usage of certain commands by those with group.admin ace permissions (default is false)
```

---
#### es_extended/server/main.lua
###### Lines 1-28
```diff
SetMapName("San Andreas")
SetGameType("ESX Legacy")

local oneSyncState = GetConvar("onesync", "off")
local newPlayer = "INSERT INTO `users` SET `accounts` = ?, `identifier` = ?, `group` = ?"
local loadPlayer = "SELECT `accounts`, `job`, `job_grade`, `group`, `position`, `inventory`, `skin`, `loadout`, `metadata`"

if Config.Multichar then
    newPlayer = newPlayer .. ", `firstname` = ?, `lastname` = ?, `dateofbirth` = ?, `sex` = ?, `height` = ?"
end

+ if Config.VMSCityhall then
+    newPlayer = newPlayer .. ', `ssn` = ?'
+ end

if Config.StartingInventoryItems then
    newPlayer = newPlayer .. ", `inventory` = ?"
end

+ if Config.Multichar or Config.Identity then
+    loadPlayer = loadPlayer .. ", `firstname`, `lastname`, `dateofbirth`, `sex`, `height`"
+ end

+ if Config.VMSCityhall then
+    loadPlayer = loadPlayer .. ', `ssn`'
+ end
```

###### Lines 30-65
```diff
local function createESXPlayer(identifier, playerId, data)
    local accounts = {}

    for account, money in pairs(Config.StartingAccountMoney) do
        accounts[account] = money
    end

    local defaultGroup = "user"
    if Core.IsPlayerAdmin(playerId) then
        print(("[^2INFO^0] Player ^5%s^0 Has been granted admin permissions via ^5Ace Perms^7."):format(playerId))
        defaultGroup = "admin"
    end

    local parameters = Config.Multichar and {
        json.encode(accounts),
        identifier,
        defaultGroup,
        data.firstname,
        data.lastname,
        data.dateofbirth,
        data.sex,
        data.height,
    } or {json.encode(accounts), identifier, defaultGroup}

+   if Config.Multichar and Config.VMSCityhall then
+       table.insert(parameters, exports['vms_cityhall']:GenerateSSN(data.dateofbirth, data.sex))
+   end

    if Config.StartingInventoryItems then
        table.insert(parameters, json.encode(Config.StartingInventoryItems))
    end

    MySQL.prepare(newPlayer, parameters, function()
        loadESXPlayer(identifier, playerId, true)
    end)
end
```

###### Lines 269-324
```diff
 -- Position
userData.coords = json.decode(result.position) or Config.DefaultSpawns[ESX.Math.Random(1,#Config.DefaultSpawns)]

 -- Skin
userData.skin = (result.skin and result.skin ~= "") and json.decode(result.skin) or { sex = userData.sex == "f" and 1 or 0 }

 -- Metadata
userData.metadata = (result.metadata and result.metadata ~= "") and json.decode(result.metadata) or {}

+ -- SSN
+ if Config.VMSCityhall then
+    if result.ssn then
+        userData.ssn = result.ssn
+    else
+        if result.dateofbirth ~= nil and result.sex ~= nil then
+            userData.ssn = exports['vms_cityhall']:GenerateSSN(result.dateofbirth, result.sex)
+            MySQL.prepare("UPDATE `users` SET `ssn` = ? WHERE `identifier` = ?", {userData.ssn, identifier})
+        end
+    end
+ end

 -- xPlayer Creation
+ local xPlayer = CreateExtendedPlayer(playerId, identifier, userData.group, userData.accounts, userData.inventory, userData.weight, userData.job, userData.loadout, GetPlayerName(playerId), userData.coords, userData.metadata, userData.ssn)

GlobalState["playerCount"] = GlobalState["playerCount"] + 1
ESX.Players[playerId] = xPlayer
Core.playersByIdentifier[identifier] = xPlayer

 -- Identity
if result.firstname and result.firstname ~= "" then
    userData.firstName = result.firstname
    userData.lastName = result.lastname
    local name = ("%s %s"):format(result.firstname, result.lastname)
    userData.name = name
    xPlayer.set("firstName", result.firstname)
    xPlayer.set("lastName", result.lastname)
    xPlayer.setName(name)
    if result.dateofbirth then
        userData.dateofbirth = result.dateofbirth
        xPlayer.set("dateofbirth", result.dateofbirth)
    end
    if result.sex then
        userData.sex = result.sex
        xPlayer.set("sex", result.sex)
    end
    if result.height then
        userData.height = result.height
        xPlayer.set("height", result.height)
    end
+   if userData.ssn then
+       xPlayer.set("ssn", userData.ssn)
+   end
end
```

---
#### es_extended/server/classes/player.lua
###### Lines 32-76
```diff
+ function CreateExtendedPlayer(playerId, identifier, group, accounts, inventory, weight, job, loadout, name, coords, metadata, ssn)
    ---@class xPlayer
    local self = {}

    self.accounts = accounts
    self.coords = coords
    self.group = group
    self.identifier = identifier
    self.inventory = inventory
    self.job = job
    self.loadout = loadout
    self.name = name
    self.playerId = playerId
    self.source = playerId
    self.variables = {}
    self.weight = weight
    self.maxWeight = Config.MaxWeight
    self.metadata = metadata
+   self.ssn = ssn
    self.lastPlaytime = self.metadata.lastPlaytime or 0
    self.paycheckEnabled = true
    self.admin = Core.IsPlayerAdmin(playerId)
    if Config.Multichar then
        local startIndex = identifier:find(":", 1)
        if startIndex then
            self.license = ("license%s"):format(identifier:sub(startIndex, identifier:len()))
        end
    else
        self.license = ("license:%s"):format(identifier)
    end

    if type(self.metadata.jobDuty) ~= "boolean" then
        self.metadata.jobDuty = self.job.name ~= "unemployed" and Config.DefaultJobDuty or false
    end
    job.onDuty = self.metadata.jobDuty

    ExecuteCommand(("add_principal identifier.%s group.%s"):format(self.license, self.group))

    local stateBag = Player(self.source).state
    stateBag:set("identifier", self.identifier, false)
    stateBag:set("license", self.license, false)
    stateBag:set("job", self.job, true)
    stateBag:set("group", self.group, true)
    stateBag:set("name", self.name, true)
+   stateBag:set("ssn", self.ssn, true)
```

---
#### es_extended/server/modules/paychecks.lua
###### Whole file
```diff
function StartPayCheck()
    CreateThread(function()
        while true do
            Wait(Config.PaycheckInterval)
            for player, xPlayer in pairs(ESX.Players) do
                local jobLabel = xPlayer.job.label
                local job = xPlayer.job.grade_name
                local salary = xPlayer.job.grade_salary

                if xPlayer.paycheckEnabled then
                    if salary > 0 then
                        if job == "unemployed" then -- unemployed
+                            if Config.VMSCityhall then
+                                if Config.AllowanceForUnemployedFromCityHallAccount then
+                                    local amount = exports['vms_cityhall']:getCompanyMoney()
+                                    if amount >= salary then
+                                        exports['vms_cityhall']:updatePaychecks(xPlayer.source, salary)
+                                        exports['vms_cityhall']:removeCompanyMoney(salary)
+                                    end
+                                else
+                                    exports['vms_cityhall']:updatePaychecks(xPlayer.source, salary)
+                                end
+                            else
                                xPlayer.addAccountMoney("bank", salary, "Welfare Check")
                                TriggerClientEvent("esx:showAdvancedNotification", player, TranslateCap("bank"), TranslateCap("received_paycheck"), TranslateCap("received_help", salary), "CHAR_BANK_MAZE", 9)
+                            end
                        elseif Config.EnableSocietyPayouts then
+                            if Config.VMSBossMenu then
+                                local society = exports['vms_bossmenu']:getSociety(xPlayer.job.name)
+                                if society then
+                                    if society.balance >= salary then
+                                        if Config.VMSCityhall then
+                                            exports['vms_cityhall']:updatePaychecks(xPlayer.source, salary)
+                                        else
+                                            xPlayer.addAccountMoney("bank", salary, "Paycheck")
+                                        end
+                                    end
+                                else
+                                    if Config.VMSCityhall then
+                                        exports['vms_cityhall']:updatePaychecks(xPlayer.source, salary)
+                                    else
+                                        xPlayer.addAccountMoney("bank", salary, "Paycheck")
+                                    end
+                                end                                
+
+                            elseif Config.VMSCityhall then
+                                TriggerEvent("esx_society:getSociety", xPlayer.job.name, function(society)
+                                    if society ~= nil then
+                                        TriggerEvent("esx_addonaccount:getSharedAccount", society.account, function(account)
+                                            if account.money >= salary then
+                                                exports['vms_cityhall']:updatePaychecks(xPlayer.source, salary)
+                                                account.removeMoney(salary)
+                                                TriggerClientEvent("esx:showAdvancedNotification", player, TranslateCap("bank"), TranslateCap("received_paycheck"), TranslateCap("received_salary", salary), "CHAR_BANK_MAZE", 9)
+                                            else
+                                                TriggerClientEvent("esx:showAdvancedNotification", player, TranslateCap("bank"), "", TranslateCap("company_nomoney"), "CHAR_BANK_MAZE", 1)
+                                            end
+                                        end)
+                                    else -- not a society
+                                        exports['vms_cityhall']:updatePaychecks(xPlayer.source, salary)
+                                        TriggerClientEvent("esx:showAdvancedNotification", player, TranslateCap("bank"), TranslateCap("received_paycheck"), TranslateCap("received_salary", salary), "CHAR_BANK_MAZE", 9)
+                                    end
+                                end)
+                                
+                            else
                                TriggerEvent("esx_society:getSociety", xPlayer.job.name, function(society)
                                    if society ~= nil then -- verified society
                                        TriggerEvent("esx_addonaccount:getSharedAccount", society.account, function(account)
                                            if account.money >= salary then -- does the society money to pay its employees?
                                                xPlayer.addAccountMoney("bank", salary, "Paycheck")
                                                account.removeMoney(salary)
                                                TriggerClientEvent("esx:showAdvancedNotification", player, TranslateCap("bank"), TranslateCap("received_paycheck"), TranslateCap("received_salary", salary), "CHAR_BANK_MAZE", 9)
                                            else
                                                TriggerClientEvent("esx:showAdvancedNotification", player, TranslateCap("bank"), "", TranslateCap("company_nomoney"), "CHAR_BANK_MAZE", 1)
                                            end
                                        end)
                                    else -- not a society
                                        xPlayer.addAccountMoney("bank", salary, "Paycheck")
                                        TriggerClientEvent("esx:showAdvancedNotification", player, TranslateCap("bank"), TranslateCap("received_paycheck"), TranslateCap("received_salary", salary), "CHAR_BANK_MAZE", 9)
                                    end
                                end)
                                
+                            end
                        else -- generic job
+                            if Config.VMSCityhall then
+                                exports['vms_cityhall']:updatePaychecks(xPlayer.source, salary)
+                            else
                                xPlayer.addAccountMoney("bank", salary, "Paycheck")
                                TriggerClientEvent("esx:showAdvancedNotification", player, TranslateCap("bank"), TranslateCap("received_paycheck"), TranslateCap("received_salary", salary), "CHAR_BANK_MAZE", 9)
+                            end
                        end
                    end
                end
            end
        end
    end)
end
```
