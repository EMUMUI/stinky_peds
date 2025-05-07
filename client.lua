-- 将NPC对玩家脏臭的反应设置为true
local useNpcReactions = true
-- 将玩家对脏臭的反应设置为true
local usePlayerReactions = true
local debugPrints = true

-- 反应设置
local playerReactionDistance = 5.0  -- 玩家反应距离
local playerReactionCooldown = 30000  -- 反应之间的冷却时间（毫秒）
local npcReactionDistance = 6.0  -- NPC反应距离
local npcReactionCooldown = 10000  -- NPC反应冷却时间（毫秒）

-- 新增配置 
local showerProps = {
    GetHashKey("prop_shower_01"), 
    GetHashKey("prop_shower_02"), 
    GetHashKey("prop_shower_towel"), 
    GetHashKey("prop_bath_01"), 
    GetHashKey("prop_bath_02"), 
    GetHashKey("v_res_mbtaps"), 
    GetHashKey("apa_mp_h_bathtub_01"),
    GetHashKey("v_res_mbath"), 
    GetHashKey("v_res_mbsink"), 
    GetHashKey("prop_sink_02"), 
    GetHashKey("prop_sink_04"), 
    GetHashKey("prop_sink_05"),
    GetHashKey("prop_sink_06"), 
    GetHashKey("prop_ld_toilet_01"), 
    GetHashKey("prop_toilet_01"), 
    GetHashKey("prop_toilet_02")
}

local showerAnimations = {
    -- 淋浴器类道具 
    [GetHashKey("prop_shower_01")] = {dict = "mp_safehouseshower@male@", anim = "male_shower_idle_b"},
    [GetHashKey("prop_shower_02")] = {dict = "mp_safehouseshower@male@", anim = "male_shower_idle_b"},
    [GetHashKey("prop_shower_towel")] = {dict = "mp_safehouseshower@male@", anim = "male_shower_idle_b"},
    
    -- 浴缸类道具
    [GetHashKey("prop_bath_01")] = {dict = "anim@mp_yacht@shower@male@", anim = "male_shower_idle_a"},
    [GetHashKey("prop_bath_02")] = {dict = "anim@mp_yacht@shower@male@", anim = "male_shower_idle_a"},
    [GetHashKey("v_res_mbath")] = {dict = "anim@mp_yacht@shower@male@", anim = "male_shower_idle_a"},
    [GetHashKey("apa_mp_h_bathtub_01")] = {dict = "anim@mp_yacht@shower@male@", anim = "male_shower_idle_a"},
    
    -- 洗手台类道具 
    [GetHashKey("v_res_mbtaps")] = {dict = "missheist_agency3aig_23", anim = "urinal_sink_loop"},
    [GetHashKey("v_res_mbsink")] = {dict = "missheist_agency3aig_23", anim = "urinal_sink_loop"},
    [GetHashKey("prop_sink_02")] = {dict = "missheist_agency3aig_23", anim = "urinal_sink_loop"},
    
    -- 默认动画（用于未特别指定的道具）
    ["default"] = {dict = "mp_safehouseshower@male@", anim = "male_shower_idle_b"}
}

-- 不要修改以下变量，否则会搞砸事情
local flyEffects = {}
local playerDirt = 0
local lastReactionTime = {}
local lastPlayerReactionTime = {}

-- 新增变量
local isNearShowerProp = false 
local currentShowerProp = nil 

function spawnFlySwarm(ped)
    if not DoesEntityExist(ped) then return end

    local particleDict = "core"
    local particleName = "ent_amb_fly_swarm" -- 蚊子粒子，你可以将其更改为任何你想要的

    RequestNamedPtfxAsset(particleDict)
    while not HasNamedPtfxAssetLoaded(particleDict) do
        Wait(10)
    end

    UseParticleFxAssetNextCall(particleDict)

    local fx = StartParticleFxLoopedOnEntity(
        particleName,
        ped,
        0.0, 0.0, 0.3,
        0.0, 0.0, 0.0,
        1.0,
        false, false, false 
    )

    table.insert(flyEffects,  fx)
end

function removeAllFlies()
    for _, fx in ipairs(flyEffects) do 
        if DoesParticleFxLoopedExist(fx) then 
            StopParticleFxLooped(fx, 0)
        end 
    end 
    flyEffects = {}
end 

function GetMyDirt(callback)
    RegisterNetEvent("sync_flies:returnDirt", function(dirt)
        callback(dirt)
    end)

    TriggerServerEvent("sync_flies:requestDirt")
end

-- 事件
RegisterNetEvent("flies:clientSpawn", function(netId)
    local ped = NetToPed(netId)
    if DoesEntityExist(ped) then 
        spawnFlySwarm(ped)
    end
end)

RegisterNetEvent("flies:clientRemove", function(netId)
    local ped = NetToPed(netId)
    if DoesEntityExist(ped) then 
        if ped == PlayerPedId() then 
            removeAllFlies()
        end
    end 
end)

RegisterNetEvent("flies:setDirt", function(value)
    playerDirt = value 
    notify("你的脏污值是: " .. value .. "/200")

    if value >= 100 then 
        local netId = PedToNet(PlayerPedId())
        TriggerServerEvent("flies:syncEffect", netId)
    else 
        local netId = PedToNet(PlayerPedId())
        TriggerServerEvent("flies:syncRemove", netId)
    end
end)

RegisterNetEvent("stinky:showReactionText", function(text)
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    AddTextEntry('PLAYER_REACTION', text)
    BeginTextCommandDisplayHelp('PLAYER_REACTION')
    EndTextCommandDisplayHelp(2, false, true, -1)
    SetFloatingHelpTextWorldPosition(1, coords.x, coords.y, coords.z + 1.0)
    SetFloatingHelpTextStyle(1, 1, 2, -1, 3, 0)
    Wait(3000)
    ClearAllHelpMessages()
end)

RegisterNetEvent('playerTeleported', function()
    -- 重新同步脏污值和粒子效果 
    TriggerServerEvent('flies:playerSpawned')
end)

-- 触发在玩家出生时
AddEventHandler("playerSpawned", function()
    TriggerServerEvent("flies:playerSpawned")
    -- 这个线程每30分钟给客户端增加+10脏污
    CreateThread(function()
        while true do 
            Wait(10 * 60 * 1000) -- 10分钟
            TriggerServerEvent("sync_flies:clientRequestUpdateDirt", 10)
            notify("你在变得脏兮兮又黏糊糊的")
        end 
    end)
end)

local wasRecentlyCleaned = false

CreateThread(function()
    local wait = 5000
    while true do 
        Wait(wait)
 
        local ped = PlayerPedId()
        local isInWater = GetEntitySubmergedLevel(ped) > 0.15
        
        -- 检查附近的洗澡道具
        local foundShowerProp = false 
        local propCoords 
        local propEntity 
        local propModel 
        
        for _, propHash in ipairs(showerProps) do 
            local prop = GetClosestObjectOfType(GetEntityCoords(ped), 2.0, propHash, false, false, false)
            if prop ~= 0 then 
                foundShowerProp = true 
                propCoords = GetEntityCoords(prop)
                propEntity = prop 
                propModel = GetEntityModel(prop)
                break 
            end 
        end 
 
        isNearShowerProp = foundShowerProp
        currentShowerProp = propEntity 
 
        if isInWater or isNearShowerProp then 
            wait = 0 
            
            if isNearShowerProp then 
                helpNotify("按 ~INPUT_CONTEXT~ 使用")
            else 
                helpNotify("按 ~INPUT_CONTEXT~ 清洗")
            end 
 
            if IsControlJustReleased(0, 38) and not wasRecentlyCleaned then 
                wasRecentlyCleaned = true 
                
                -- 根据道具类型选择动画
                local animData = showerAnimations[propModel] or showerAnimations["default"]
                
                busySpinner("你正在清洁自己")
                
                -- 面向道具
                if isNearShowerProp then 
                    TaskTurnPedToFaceEntity(ped, currentShowerProp, 1000)
                    Wait(1000)
                end 
                
                -- 加载动画字典 
                RequestAnimDict(animData.dict) 
                while not HasAnimDictLoaded(animData.dict)  do 
                    Wait(10)
                end 
 
                FreezeEntityPosition(ped, true)
                TaskPlayAnim(ped, animData.dict,  animData.anim,  8.0, -8.0, 7000, 1, 0, false, false, false)
                
                -- 添加水花效果
                if isNearShowerProp then 
                    local showerFx = StartParticleFxLoopedOnEntity(
                        "water_splash_veh_out",
                        ped,
                        0.0, 0.0, 1.8,
                        0.0, 0.0, 0.0,
                        1.0,
                        false, false, false 
                    )
                    
                    -- 添加淋浴声音 
                    PlaySoundFrontend(-1, "Shower", "RESIDENTAL_SOUNDS", true)
                end
                
                Wait(7000)
                
                -- 清理效果
                if isNearShowerProp then 
                    StopSound(GetSoundId())
                    StopParticleFxLooped(showerFx, 0)
                end
                
                ClearPedTasks(ped)
                FreezeEntityPosition(ped, false)
                
                -- 设置湿润效果
                SetPedWetnessHeight(ped, 2.0)
                
                -- 根据清洁方式减少不同脏污值
                local dirtReduction = isNearShowerProp and -100 or -50
                TriggerServerEvent("sync_flies:clientRequestUpdateDirt", dirtReduction)
                
                notify("你洗干净了你自己。")
                BusyspinnerOff()
                
                Wait(5000)
                wasRecentlyCleaned = false 
            end 
        else 
            wait = 5000 
        end 
    end 
end)

RegisterCommand("checkdirt", function()
    GetMyDirt(function(dirt)
        if dirt then
            if dirt > 100 then
                notify("你真脏。你的脏污等级: " .. dirt .. "/200")
            else 
                notify("你还好。你的脏污等级: " .. dirt .. "/200")
            end
        else 
            notify("无法获取数据兄弟。")
        end
    end)
end)

-- 添加命令来查看支持的洗澡道具列表 
RegisterCommand("listshowers", function()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local foundAny = false 
    
    for _, propHash in ipairs(showerProps) do 
        local prop = GetClosestObjectOfType(coords, 50.0, propHash, false, false, false)
        if prop ~= 0 then 
            foundAny = true 
            local propCoords = GetEntityCoords(prop)
            local dist = #(coords - propCoords)
            
            -- 获取道具模型名称 
            local model = GetEntityModel(prop)
            local modelName = ""
            
            -- 尝试获取模型名称 
            for k, v in pairs(showerProps) do 
                if v == model then 
                    -- 这里我们无法直接反向查找哈希到名称，所以需要修改方法 
                    -- 改为直接显示哈希值 
                    modelName = string.format("0x%x",  model)
                    break 
                end 
            end 
            
            notify("找到洗澡道具 (模型哈希: " .. modelName .. ") (距离: " .. math.floor(dist)   .. " 米)")
        end 
    end 
    
    if not foundAny then 
        notify("附近没有找到支持的洗澡道具")
    end 
end, false)

-- 通知函数
function notify(msg)
    SetNotificationTextEntry('STRING')
    AddTextComponentString(msg)
    DrawNotification(0, 1)
end

function helpNotify(msg)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(msg)
    EndTextCommandDisplayHelp(0, false, true, -1)
end

function busySpinner(message)
    BeginTextCommandBusyspinnerOn('STRING')
    AddTextComponentSubstringPlayerName(message)
    EndTextCommandBusyspinnerOn(3)
end

function dbgPrint(msg)
    if debugPrints then
        print("^3[DEBUG]^0 " .. tostring(msg))
    end 
end

function getRandomDisgustAnim()
    local anims = {
        {dict = "re@construction", anim = "out_of_breath"},
        {dict = "gestures@m@standing@casual", anim = "gesture_no_way"},
        {dict = "anim@mp_player_intcelebrationfemale@stinker", anim = "stinker"}
    }
    local choice = anims[math.random(#anims)]
    dbgPrint("随机动画: " .. choice.dict  .. " - " .. choice.anim) 
    return choice.dict,  choice.anim  
end

function getPlayerReactionAnim()
    local anims = {
        {dict = "gestures@m@standing@casual", anim = "gesture_easy_now"},
        {dict = "gestures@m@standing@casual", anim = "gesture_no_way"},
        {dict = "mp_player_int_upperwank", anim = "mp_player_int_wank_01"},
        {dict = "anim@mp_player_intcelebrationfemale@face_palm", anim = "face_palm"}
    }
    local choice = anims[math.random(#anims)]
    return choice.dict,  choice.anim  
end

function EnumeratePeds()
    return coroutine.wrap(function() 
        local handle, ped = FindFirstPed()
        local success 
        repeat
            if not IsEntityDead(ped) then 
                coroutine.yield(ped) 
            end
            success, ped = FindNextPed(handle)
        until not success
        EndFindPed(handle)
    end)
end

-- 主要反应线程
CreateThread(function()
    if useNpcReactions or usePlayerReactions then 
        while true do
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)
            local currentTime = GetGameTimer()

            -- 只在玩家足够脏时检查
            if playerDirt >= 100 then 
                -- NPC反应
                if useNpcReactions then 
                    local rndm = math.random(1,  2)
                    for ped in EnumeratePeds() do
                        if DoesEntityExist(ped) and not IsPedAPlayer(ped) and not IsPedDeadOrDying(ped, true) then
                            local pedCoords = GetEntityCoords(ped)
                            local dist = #(playerCoords - pedCoords)

                            if dist < npcReactionDistance then
                                local pedId = tostring(ped)

                                if not lastReactionTime[pedId] or (currentTime - lastReactionTime[pedId]) > npcReactionCooldown then
                                    if not IsPedInAnyVehicle(ped) then 
                                        if rndm == 1 then 
                                            dbgPrint("NPC " .. ped .. " 足够近，播放动画。")
                                            if not NetworkHasControlOfEntity(ped) then
                                                NetworkRequestControlOfEntity(ped)
                                                Wait(50)
                                            end 
                                            ClearPedTasks(ped)
                                            local dict, anim = getRandomDisgustAnim()
                                            RequestAnimDict(dict)
                                            while not HasAnimDictLoaded(dict) do 
                                                Wait(10)
                                            end 
                                            TaskPlayAnim(ped, dict, anim, 8.0, -8.0, 3000, 49, 0, false, false, false)
                                            dbgPrint("在NPC " .. ped .. " 上播放了动画: " .. dict .. " - " .. anim)
                                            lastReactionTime[pedId] = currentTime 
                                        else
                                            dbgPrint("随机检查跳过了NPC " .. ped .. " 的动画")
                                        end
                                    end 
                                else
                                    dbgPrint("NPC " .. ped .. " 正在冷却。")
                                end
                            end 
                        end
                    end 
                end

                -- 玩家反应
                if usePlayerReactions then
                    for _, player in ipairs(GetActivePlayers()) do
                        local targetPed = GetPlayerPed(player)
                        if player ~= PlayerId() and DoesEntityExist(targetPed) and not IsPedDeadOrDying(targetPed, true) then
                            local targetCoords = GetEntityCoords(targetPed)
                            local dist = #(playerCoords - targetCoords)
                            
                            if dist < playerReactionDistance then 
                                local playerId = GetPlayerServerId(player)
                                
                                if not lastPlayerReactionTime[playerId] or (currentTime - lastPlayerReactionTime[playerId]) > playerReactionCooldown then 
                                    if math.random(1,  3) == 1 then  -- 1/3 的几率反应
                                        local dict, anim = getPlayerReactionAnim()
                                        RequestAnimDict(dict)
                                        while not HasAnimDictLoaded(dict) do 
                                            Wait(10)
                                        end 
                                        
                                        TaskPlayAnim(targetPed, dict, anim, 8.0, -8.0, 3000, 49, 0, false, false, false)
                                        
                                        local reactions = {
                                            "呸！你真臭！",
                                            "去洗个澡！",
                                            "这是什么味道？",
                                            "真恶心！",
                                            "呼！真难闻！"
                                        }
                                        local reactionText = reactions[math.random(#reactions)]
                                        TriggerServerEvent("stinky:showReactionText", playerId, reactionText)
                                        
                                        lastPlayerReactionTime[playerId] = currentTime
                                        dbgPrint("玩家对你的臭味做出了反应: " .. playerId)
                                    end
                                end 
                            end
                        end 
                    end
                end 
            end
            
            Wait(5000)
        end 
    end
end)

--玩家位置变化检测 
CreateThread(function()
    local lastCoords = GetEntityCoords(PlayerPedId())
    while true do 
        Wait(1000) -- 每秒检查一次 
        local currentCoords = GetEntityCoords(PlayerPedId())
        if #(lastCoords - currentCoords) > 10.0 then -- 如果移动距离超过10米 
            if playerDirt >= 100 then 
                local netId = PedToNet(PlayerPedId())
                TriggerServerEvent("flies:syncEffect", netId) -- 重新同步效果 
            end 
            lastCoords = currentCoords 
        end 
    end 
end)
