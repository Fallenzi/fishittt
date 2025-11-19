-- // ServerScript: FishingSystem.lua (Diletakkan di ServerScriptService)
-- Script ini menangani seluruh logika RNG dan menyediakan alat Debug Statistik.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- === PERSIAPAN REMOTE EVENT & DATA ===
-- Pastikan Anda telah membuat RemoteEvent bernama "FishEvent" di ReplicatedStorage
local FishEvent = ReplicatedStorage:WaitForChild("FishEvent", 30) 

local rngData = {} -- State Random.new() object per pemain (untuk keamanan)
local Debounce = {} -- Untuk mencegah spam pancingan per pemain

-- === DEFINISI LOOT TABLE UNTUK SEMUA PULAU ===
-- Item harus diurutkan dari yang paling langka (peluang terkecil) hingga paling umum (peluang terbesar)
local ALL_LOOT_TABLES = {
    ["Starter Island"] = {
        {"Secret Mermaid's Tear", 0.001},
        {"Rare Shell", 0.05},
        {"Common Seaweed", 1.0}
    },
    ["Ruins"] = { -- Target Pulau Anda
        {"Secret Lost Artifact", 0.00005},  -- 0.005% chance
        {"Ancient Relic", 0.005},         
        {"Rare Coral", 0.10},              
        {"Common Junk", 1.0}
    },
    -- Tambahkan pulau lain di sini...
}

-- [1] FUNGSI UTAMA RNG (AMAN - Server Authority)
local function getPlayerRNG(player)
    if not rngData[player] then
        -- Seed unik per sesi/pemain untuk mempersulit prediksi
        rngData[player] = Random.new(tick() + player.UserId) 
    end
    return rngData[player]
end

local function determineLoot(player, lootTable)
    local rng = getPlayerRNG(player)
    local roll = rng:NextNumber(0, 1) -- Roll acak aman dari 0 hingga 1

    for _, itemData in ipairs(lootTable) do
        local itemName = itemData[1]
        local chance = itemData[2]

        if roll <= chance then
            return itemName
        end
    end
    return "Nothing Found" 
end

-- [2] LOGIKA MEMANCING (Terhubung ke Client)
-- Client harus mengirim nama pulau saat memancing
FishEvent.OnServerEvent:Connect(function(player, islandName)
    -- Cek Pulau Valid
    local selectedLootTable = ALL_LOOT_TABLES[islandName]
    if not selectedLootTable then
        warn(string.format("%s mencoba memancing di pulau tidak valid: %s", player.Name, islandName))
        return 
    end
    
    -- Debounce Check
    if Debounce[player.UserId] and Debounce[player.UserId] > tick() then
        return 
    end
    Debounce[player.UserId] = tick() + 4 -- Contoh cooldown 4 detik

    -- Simulasi waktu memancing
    task.wait(3) 

    -- Penentuan Loot yang Aman (Server Authority)
    local lootResult = determineLoot(player, selectedLootTable)

    -- TODO: Tambahkan logika pemberian item/update inventory di sini (misalnya, leaderstats)
    print(string.format("%s memancing di %s dan mendapat: %s", player.Name, islandName, lootResult))

    -- Kirim hasil kembali ke Client (Client hanya menerima hasilnya, bukan seed)
    FishEvent:FireClient(player, lootResult)
end)

Players.PlayerRemoving:Connect(function(player)
    rngData[player] = nil
    Debounce[player.UserId] = nil
end)


-- ==================================================
-- [3] DEBUG: ALAT SIMULASI STATISTIK (Fitur "OP" untuk Developer)
-- Bagian ini menghitung rata-rata pull untuk Secret di Ruins
-- ==================================================

local TARGET_PULAU = "Ruins"
local TARGET_LOOT = "Secret Lost Artifact"
local SIMULATED_LOOT_TABLE = ALL_LOOT_TABLES[TARGET_PULAU]

local SIMULATION_COUNT = 100 -- Jumlah percobaan simulasi (Semakin besar, semakin akurat)
local MAX_PULLS = 1000000 -- Batas percobaan per trial

local function runDebugSimulation()
    if not SIMULATED_LOOT_TABLE then return end

    local localRNG = Random.new(tick()) -- RNG terpisah untuk simulasi
    local sumPulls = 0
    local foundCount = 0

    local function simulateLoot()
        local roll = localRNG:NextNumber(0, 1)
        for _, itemData in ipairs(SIMULATED_LOOT_TABLE) do
            if roll <= itemData[2] then
                return itemData[1]
            end
        end
        return "Nothing Found" 
    end

    print("--- STARTING DEBUG SIMULATION ---")
    print(string.format("🎯 TARGET PULAU: %s | ITEM: %s", TARGET_PULAU, TARGET_LOOT))
    
    for i = 1, SIMULATION_COUNT do
        local pullCount = 0
        local found = false
        
        while pullCount < MAX_PULLS do
            pullCount = pullCount + 1
            if simulateLoot() == TARGET_LOOT then
                found = true
                break
            end
        end
        
        if found then
            sumPulls = sumPulls + pullCount
            foundCount = foundCount + 1
        end
    end

    -- OUTPUT HASIL AKHIR KE CONSOLE STUDIO
    print("\n------------------ SIMULATION RESULTS ------------------")
    if foundCount > 0 then
        local averagePulls = sumPulls / foundCount
        local theoreticalChance = SIMULATED_LOOT_TABLE[1][2]
        local theoreticalPulls = 1 / theoreticalChance
        
        print(string.format("✅ SUCCESS! Trials Succeeded: %d/%d", foundCount, SIMULATION_COUNT))
        print(string.format("💰 TOTAL PULLS: %d", sumPulls))
        print(string.format("📊 RATA-RATA PULLS UNTUK SECRET: %.2f", averagePulls))
        print(string.format("💡 PULLS TEORITIS (1/Peluang): %.0f", theoreticalPulls))
    else
        print("❌ SIMULASI GAGAL! Target tidak ditemukan dalam batas percobaan yang ditetapkan.")
    end
    print("------------------------------------------------------")
end

-- Jalankan Simulasi Debug saat server dimulai (Hanya di Studio)
runDebugSimulation()

print("Fish It Multi-Island System Loaded.")
