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
```
SetMapName("San Andreas")
SetGameType("ESX Legacy")

local oneSyncState = GetConvar("onesync", "off")
local newPlayer = "INSERT INTO `users` SET `accounts` = ?, `identifier` = ?, `group` = ?"
local loadPlayer = "SELECT `accounts`, `job`, `job_grade`, `group`, `position`, `inventory`, `skin`, `loadout`, `metadata`"

if Config.Multichar then
    newPlayer = newPlayer .. ", `firstname` = ?, `lastname` = ?, `dateofbirth` = ?, `sex` = ?, `height` = ?"
end

+ if Config.VMSCityhall then
+     newPlayer = newPlayer .. ', `ssn` = ?'
+ end

if Config.StartingInventoryItems then
    newPlayer = newPlayer .. ", `inventory` = ?"
end

+ if Config.Multichar or Config.Identity then
+     loadPlayer = loadPlayer .. ", `firstname`, `lastname`, `dateofbirth`, `sex`, `height`"
+ end

+ if Config.VMSCityhall then
+     loadPlayer = loadPlayer .. ', `ssn`'
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

+    if Config.Multichar and Config.VMSCityhall then
+        table.insert(parameters, exports['vms_cityhall']:GenerateSSN(data.dateofbirth, data.sex))
+    end

    if Config.StartingInventoryItems then
        table.insert(parameters, json.encode(Config.StartingInventoryItems))
    end

    MySQL.prepare(newPlayer, parameters, function()
        loadESXPlayer(identifier, playerId, true)
    end)
end
```

###### Lines 30-65
```diff
 -- Position
userData.coords = json.decode(result.position) or Config.DefaultSpawns[ESX.Math.Random(1,#Config.DefaultSpawns)]

 -- Skin
userData.skin = (result.skin and result.skin ~= "") and json.decode(result.skin) or { sex = userData.sex == "f" and 1 or 0 }

 -- Metadata
userData.metadata = (result.metadata and result.metadata ~= "") and json.decode(result.metadata) or {}

+ -- SSN
+ if Config.VMSCityhall then
+     if result.ssn then
+         userData.ssn = result.ssn
+     else
+         if result.dateofbirth ~= nil and result.sex ~= nil then
+             userData.ssn = exports['vms_cityhall']:GenerateSSN(result.dateofbirth, result.sex)
+             MySQL.prepare("UPDATE `users` SET `ssn` = ? WHERE `identifier` = ?", {userData.ssn, identifier})
+         end
+     end
+ end

 -- xPlayer Creation
+ local xPlayer = CreateExtendedPlayer(playerId, identifier, userData.group, userData.accounts, userData.inventory, userData.weight, userData.job, userData.loadout, GetPlayerName(playerId), userData.coords, userData.metadata, userData.ssn)

GlobalState["playerCount"] = GlobalState["playerCount"] + 1
ESX.Players[playerId] = xPlayer
Core.playersByIdentifier[identifier] = xPlayer
```













































