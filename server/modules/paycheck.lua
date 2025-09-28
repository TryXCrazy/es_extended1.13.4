function StartPayCheck()
    CreateThread(function()
        while true do
            Wait(Config.PaycheckInterval)
            for player, xPlayer in pairs(ESX.Players) do
                local jobLabel = xPlayer.job.label
                local job = xPlayer.job.grade_name
                local salary = xPlayer.job.grade_salary

                if xPlayer.paycheckEnabled and salary > 0 then
                    if job == "unemployed" then
                        if Config.VMSCityhall then
                            if Config.AllowanceForUnemployedFromCityHallAccount then
                                local amount = exports['vms_cityhall']:getCompanyMoney()
                                if amount >= salary then
                                    exports['vms_cityhall']:updatePaychecks(xPlayer.source, salary)
                                    exports['vms_cityhall']:removeCompanyMoney(salary)
                                end
                            else
                                exports['vms_cityhall']:updatePaychecks(xPlayer.source, salary)
                            end
                        else
                            xPlayer.addAccountMoney("bank", salary, "Welfare Check")
                            TriggerClientEvent("esx:showAdvancedNotification", player, TranslateCap("bank"), TranslateCap("received_paycheck"), TranslateCap("received_help", salary), "CHAR_BANK_MAZE", 9)
                        end
                    elseif Config.EnableSocietyPayouts then
                        if Config.VMSBossMenu then
                            local society = exports['vms_bossmenu']:getSociety(xPlayer.job.name)
                            if society then
                                if society.balance >= salary then
                                    if Config.VMSCityhall then
                                        exports['vms_cityhall']:updatePaychecks(xPlayer.source, salary)
                                    else
                                        xPlayer.addAccountMoney("bank", salary, "Paycheck")
                                    end
                                end
                            else
                                if Config.VMSCityhall then
                                    exports['vms_cityhall']:updatePaychecks(xPlayer.source, salary)
                                else
                                    xPlayer.addAccountMoney("bank", salary, "Paycheck")
                                end
                            end
                        elseif Config.VMSCityhall then
                            TriggerEvent("esx_society:getSociety", xPlayer.job.name, function(society)
                                if society ~= nil then
                                    TriggerEvent("esx_addonaccount:getSharedAccount", society.account, function(account)
                                        if account.money >= salary then
                                            exports['vms_cityhall']:updatePaychecks(xPlayer.source, salary)
                                            account.removeMoney(salary)
                                            TriggerClientEvent("esx:showAdvancedNotification", player, TranslateCap("bank"), TranslateCap("received_paycheck"), TranslateCap("received_salary", salary), "CHAR_BANK_MAZE", 9)
                                        else
                                            TriggerClientEvent("esx:showAdvancedNotification", player, TranslateCap("bank"), "", TranslateCap("company_nomoney"), "CHAR_BANK_MAZE", 1)
                                        end
                                    end)
                                else
                                    exports['vms_cityhall']:updatePaychecks(xPlayer.source, salary)
                                    TriggerClientEvent("esx:showAdvancedNotification", player, TranslateCap("bank"), TranslateCap("received_paycheck"), TranslateCap("received_salary", salary), "CHAR_BANK_MAZE", 9)
                                end
                            end)
                        else
                            TriggerEvent("esx_society:getSociety", xPlayer.job.name, function(society)
                                if society ~= nil then
                                    TriggerEvent("esx_addonaccount:getSharedAccount", society.account, function(account)
                                        if account.money >= salary then
                                            xPlayer.addAccountMoney("bank", salary, "Paycheck")
                                            account.removeMoney(salary)
                                            TriggerClientEvent("esx:showAdvancedNotification", player, TranslateCap("bank"), TranslateCap("received_paycheck"), TranslateCap("received_salary", salary), "CHAR_BANK_MAZE", 9)
                                        else
                                            TriggerClientEvent("esx:showAdvancedNotification", player, TranslateCap("bank"), "", TranslateCap("company_nomoney"), "CHAR_BANK_MAZE", 1)
                                        end
                                    end)
                                else
                                    xPlayer.addAccountMoney("bank", salary, "Paycheck")
                                    TriggerClientEvent("esx:showAdvancedNotification", player, TranslateCap("bank"), TranslateCap("received_paycheck"), TranslateCap("received_salary", salary), "CHAR_BANK_MAZE", 9)
                                end
                            end)
                        end
                    else
                        if Config.VMSCityhall then
                            exports['vms_cityhall']:updatePaychecks(xPlayer.source, salary)
                        else
                            xPlayer.addAccountMoney("bank", salary, "Paycheck")
                            TriggerClientEvent("esx:showAdvancedNotification", player, TranslateCap("bank"), TranslateCap("received_paycheck"), TranslateCap("received_salary", salary), "CHAR_BANK_MAZE", 9)
                        end
                    end
                end
            end
        end
    end)
end
