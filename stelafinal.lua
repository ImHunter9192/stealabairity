local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
local Players, RS, RepS = game:GetService("Players"), game:GetService("RunService"), game:GetService("ReplicatedStorage")
local lp = Players.LocalPlayer
local scriptStart = os.clock()

local CFG = {
    Bases = "Bases", Treadmill = "TreadmillLocation", Admin = "Admin Treadmill",
    BoxTool = "Box",   -- backpack tools whose name contains this get placed
    PlaceY = 0,        -- ground height used for PlaceBox
}
local on, hitSize, placeDelay, saved = {}, 10, 0.5, {}
local placeTarget -- defined below
local VirtualUser = game:GetService("VirtualUser")

local function root() local c = lp.Character return c and c:FindFirstChild("HumanoidRootPart") end
local function posOf(o) return o:IsA("Model") and o:GetPivot().Position or o.Position end
-- the game shows the owner's name on Base.Origin.OwnerNameplate.PlayerName
local function mine(base)
    local l = base:FindFirstChild("PlayerName", true)
    if not (l and l:IsA("TextLabel")) then return false end
    local t = (l.Text:gsub("^@", "")):lower()
    return t == lp.DisplayName:lower() or t == lp.Name:lower()
end

local function myBase()
    local bases = workspace:FindFirstChild(CFG.Bases)
    if not bases then return end
    for _, b in ipairs(bases:GetChildren()) do
        if mine(b) then return b end
    end
end

local function myTreadmill()
    local bases = workspace:FindFirstChild(CFG.Bases)
    if not bases then return end
    for _, b in ipairs(bases:GetChildren()) do
        if mine(b) then return b:FindFirstChild(CFG.Treadmill, true) end
    end
end

local function admin()
    local o = workspace:FindFirstChild(CFG.Admin)
    return (o and (o:IsA("BasePart") or o:IsA("Model"))) and o or nil
end

local function goTo(t, up)
    local r = root()
    if r and t then r.CFrame = CFrame.new(posOf(t) + Vector3.new(0, up, 0)) return true end
    Rayfield:Notify({Title = "Teleport", Content = "Target not found", Duration = 3})
end
local function adminUp(a) return (a:IsA("BasePart") and a.Size.Y / 2 or 0) + 4 end

workspace.ChildAdded:Connect(function(c)
    if c.Name == CFG.Admin then
        Rayfield:Notify({Title = "Admin Treadmill", Content = "Spawned!", Duration = 4})
        if on.admin then task.wait(0.2) goTo(c, adminUp(c)) end
    end
end)

task.spawn(function()
    while task.wait(0.5) do
        pcall(function()
            local r, a = root(), admin()
            if not r then return end
            if on.admin and a then
                if (posOf(a) - r.Position).Magnitude > 15 then goTo(a, adminUp(a)) end
            elseif on.tread then
                local t = myTreadmill()
                if t and (posOf(t) - r.Position).Magnitude > 15 then goTo(t, 4) end
            end
        end)
    end
end)

local function remote(name) return RepS:FindFirstChild(name, true) end

-- where boxes go: inside MY base, no matter where I'm standing.
-- "boxSpot" is a point saved relative to my base's Origin part (set it with the button in the Main tab).
local placeSpread = 6
local boxSpot
pcall(function()
    if readfile and isfile and isfile("stela_boxspot.txt") then
        local x, y, z = readfile("stela_boxspot.txt"):match("([%-%d%.]+),([%-%d%.]+),([%-%d%.]+)")
        if x then boxSpot = Vector3.new(tonumber(x), tonumber(y), tonumber(z)) end
    end
end)

local function baseRef()
    local b = myBase()
    return b and (b:FindFirstChild("Origin") or b:FindFirstChild("PetBounds")), b
end

function placeTarget()
    local ref = baseRef()
    if not ref then return end
    local p = boxSpot and ref.CFrame:PointToWorldSpace(boxSpot) or ref.Position
    local off = Vector3.new(math.random(-placeSpread, placeSpread), 0, math.random(-placeSpread, placeSpread))
    return Vector3.new(p.X, CFG.PlaceY, p.Z) + off
end

local function saveBoxSpot()
    local r, ref = root(), baseRef()
    if not (r and ref) then
        Rayfield:Notify({Title = "Box spot", Content = "Couldn't find your base", Duration = 4})
        return
    end
    boxSpot = ref.CFrame:PointToObjectSpace(r.Position)
    pcall(function()
        if writefile then writefile("stela_boxspot.txt", boxSpot.X .. "," .. boxSpot.Y .. "," .. boxSpot.Z) end
    end)
    Rayfield:Notify({Title = "Box spot saved", Content = "Boxes now go here, from anywhere", Duration = 4})
end

-- auto place boxes: EquipTool(tool) then PlaceBox(Vector3) near where you stand
task.spawn(function()
    while task.wait(placeDelay) do
        if on.boxes then pcall(function()
            local r, place, equip = root(), remote("PlaceBox"), remote("EquipTool")
            if not (r and place and equip) then return end
            local tool
            for _, c in ipairs({lp.Character, lp.Backpack}) do
                for _, t in ipairs(c:GetChildren()) do
                    if t:IsA("Tool") and t.Name:find(CFG.BoxTool, 1, true) then tool = t break end
                end
                if tool then break end
            end
            if not tool then return end
            if tool.Parent ~= lp.Character then equip:FireServer(tool) task.wait(0.15) end
            local target = placeTarget()
            if not target then return end
            local back
            if on.tpPlace and (r.Position - target).Magnitude > 30 then
                back = r.CFrame -- remember where I was
                r.CFrame = CFrame.new(target + Vector3.new(0, 4, 0))
                task.wait(0.25)
            end
            pcall(function() place:FireServer(target) end)
            if back then
                task.wait(0.25)
                local r2 = root()
                if r2 then
                    r2.CFrame = back
                    r2.AssemblyLinearVelocity = Vector3.zero
                end
            end
        end) end
    end
end)

local function resetHitboxes()
    for hrp, s in pairs(saved) do if hrp.Parent then hrp.Size, hrp.Transparency = s, 1 end end
    table.clear(saved)
end

RS.Heartbeat:Connect(function()
    if on.hitbox then
        for _, p in ipairs(Players:GetPlayers()) do
            local h = p ~= lp and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
            if h then
                saved[h] = saved[h] or h.Size
                h.Size, h.Transparency, h.CanCollide = Vector3.new(hitSize, hitSize, hitSize), 0.7, false
            end
        end
    end
    if on.ragdoll then
        local c = lp.Character
        local hum = c and c:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
        hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
        hum.PlatformStand = false
        local s = hum:GetState()
        if s == Enum.HumanoidStateType.Ragdoll or s == Enum.HumanoidStateType.FallingDown then
            hum:ChangeState(Enum.HumanoidStateType.GettingUp)
        end
        for _, d in ipairs(c:GetDescendants()) do
            if d:IsA("BallSocketConstraint") then d:Destroy()
            elseif d:IsA("Motor6D") then d.Enabled = true end
        end
        if c:GetAttribute("Ragdoll") then c:SetAttribute("Ragdoll", false) end
    end
end)

-- webhook notifier: reads the game's own night-reset announcements (PlayerGui.NightWarning)
-- e.g. "ALL BOXES RESET!" then "Winged Verity Box" + " spawned in " + "Glass House!"
local HttpService = game:GetService("HttpService")
local wh = {url = "", bosses = ""}
on.night = true
local sent = {}
local httpReq = (syn and syn.request) or (http and http.request) or http_request or request

local function validUrl(u)
    return u:find("^https://[%w%.]*discord%.com/api/webhooks/") or u:find("^https://[%w%.]*discordapp%.com/api/webhooks/")
end

local function sendWebhook(title, desc)
    if not (httpReq and validUrl(wh.url)) then return false end
    pcall(httpReq, {
        Url = wh.url, Method = "POST", Headers = {["Content-Type"] = "application/json"},
        Body = HttpService:JSONEncode({embeds = {{title = title, description = desc, color = 5814783, footer = {text = lp.DisplayName}}}}),
    })
    return true
end

local function trim(s) return s:match("^%s*(.-)%s*$") end

-- selectable lists for the notification filters (edit or add names here)
local LISTS = {
    areas = {"Forest", "Ruins", "Desert", "Backrooms", "Dungeon", "Ocean", "Abyss", "Elysium", "Fracture",
        "Inferno", "Genesis", "Eternity", "Candyland", "Moonfall", "Glass House", "Observatory",
        "Haunted Graveyard", "Heaven's Gate", "Event Horizon", "Frostfire", "Checkmate", "Dread Keep"},
    boxes = {"Happy", "Smiling", "Annoyed", "Moggity", "Creepy", "Enraged", "True", "Golem", "Lord",
        "King", "Divine", "Winged", "Prism"},
}
-- the game stores each area's name on Workspace.Areas.AreaN (attribute DisplayName): use it if present
pcall(function()
    local af = workspace:FindFirstChild("Areas")
    if not af then return end
    local list = {}
    for _, a in ipairs(af:GetChildren()) do
        local n = a:GetAttribute("DisplayName")
        if n then list[#list + 1] = {tonumber(a.Name:match("%d+")) or 0, n} end
    end
    table.sort(list, function(x, y) return x[1] < y[1] end)
    if #list > 0 then
        LISTS.areas = {}
        for _, e in ipairs(list) do table.insert(LISTS.areas, e[2]) end
    end
end)
local sel = {areas = {}, boxes = {}} -- selected names (lowercase)

local function copy(t) local c = {} for i, v in ipairs(t) do c[i] = v end return c end
local function setSel(key, list)
    sel[key] = {}
    for _, n in ipairs(list) do sel[key][n:lower()] = true end
end
for k in pairs(sel) do setSel(k, LISTS[k]) end -- everything selected by default

-- true if the text names something that is selected. Names that are not in the list at all
-- (new areas/boxes) are let through so you never silently miss one.
local function allowed(key, text)
    local t, known = text:lower(), false
    for _, opt in ipairs(LISTS[key]) do
        if t:find(opt:lower(), 1, true) then
            known = true
            if sel[key][opt:lower()] then return true end
        end
    end
    return not known
end

local function findOpt(key, word)
    for _, opt in ipairs(LISTS[key]) do
        if opt:lower() == word:lower() then return opt:lower() end
    end
end


-- comma separated filter; empty = match everything
local function passes(filter, text)
    local any = false
    for item in filter:lower():gmatch("[^,]+") do
        item = trim(item)
        if item ~= "" then
            any = true
            if text:lower():find(item, 1, true) then return true end
        end
    end
    return not any
end

local function readAnnouncements(gui)
    local list = {}
    for _, d in ipairs(gui:GetDescendants()) do
        if d:IsA("TextLabel") and d.Text:lower():find("spawned in", 1, true) then
            local sibs = {}
            for _, c in ipairs(d.Parent:GetChildren()) do
                if c:IsA("TextLabel") and c.Text:match("%S") then sibs[#sibs + 1] = c end
            end
            table.sort(sibs, function(a, b)
                if a.LayoutOrder ~= b.LayoutOrder then return a.LayoutOrder < b.LayoutOrder end
                return a.AbsolutePosition.X < b.AbsolutePosition.X
            end)
            for i, c in ipairs(sibs) do
                if c == d and sibs[i - 1] and sibs[i + 1] then
                    local area = trim(sibs[i + 1].Text):gsub("!+$", "")
                    list[#list + 1] = {box = trim(sibs[i - 1].Text), area = area}
                end
            end
        end
    end
    return list
end

local function processAnnouncements(force)
    local gui = lp.PlayerGui:FindFirstChild("NightWarning")
    if not gui then return false end
    local lines, now = {}, os.clock()
    for _, a in ipairs(readAnnouncements(gui)) do
        local sig = a.box .. "@" .. a.area
        if (force or not sent[sig] or now - sent[sig] > 200)
            and allowed("boxes", a.box) and allowed("areas", a.area) then
            sent[sig] = now
            lines[#lines + 1] = "• **" .. a.box .. "** in **" .. a.area .. "**"
        end
    end
    if #lines == 0 then return false end
    local desc = table.concat(lines, "\n")
    sendWebhook("Boxes reset: new spawns", desc)
    local plain = desc:gsub("%*", "")
    Rayfield:Notify({Title = "New boxes", Content = plain, Duration = 8})
    return true
end

-- wait until the announcements stop changing for 3s, then send them as one message
local token = 0
local function schedule()
    if not on.night then return end
    token = token + 1
    local my = token
    task.delay(3, function() if my == token then pcall(processAnnouncements) end end)
end

local function hookGui(gui)
    local function watch(d)
        if d:IsA("TextLabel") then d:GetPropertyChangedSignal("Text"):Connect(schedule) end
    end
    for _, d in ipairs(gui:GetDescendants()) do watch(d) end
    gui.DescendantAdded:Connect(function(d) watch(d) if d:IsA("TextLabel") then schedule() end end)
end

local pg = lp:WaitForChild("PlayerGui")
local nw = pg:FindFirstChild("NightWarning")
if nw then hookGui(nw) end
pg.ChildAdded:Connect(function(c) if c.Name == "NightWarning" then hookGui(c) end end)

-- boss timers + alerts (the three portal signs show the countdown and the speed needed)
local TIERS = {
    {key = "Normal", gui = "BossPortalSign"},
    {key = "High", gui = "BossPortalSignHigh"},
    {key = "Top", gui = "BossPortalSignTop"},
}
local bossLabels, lastSecs, lastText = {}, {}, {}
local bossTiers = {Normal = true, High = true, Top = true}
local bossWarn = 60
on.bossSoon, on.bossEvent = false, false

local function readTier(t)
    local g = lp.PlayerGui:FindFirstChild(t.gui)
    if not g then return end
    local clock = g:FindFirstChild("Clock", true)
    local sp = g:FindFirstChild("Speed", true)
    local req = sp and sp:FindFirstChild("Value", true)
    return clock and clock.Text or "?", req and req.Text or "?"
end

local function toSecs(txt)
    local a, b, c = txt:match("^(%d+):(%d+):(%d+)$")
    if a then return tonumber(a) * 3600 + tonumber(b) * 60 + tonumber(c) end
    a, b = txt:match("^(%d+):(%d+)$")
    if a then return tonumber(a) * 60 + tonumber(b) end
end

task.spawn(function()
    while task.wait(1) do
        pcall(function()
            local lines = {}
            for _, t in ipairs(TIERS) do
                local clock, req = readTier(t)
                if clock then
                    local txt = t.key .. " (needs " .. req .. " speed): " .. clock
                    local lbl = bossLabels[t.key]
                    if lbl and lastText[t.key] ~= txt then lbl:Set(txt) lastText[t.key] = txt end
                    local secs, prev = toSecs(clock), lastSecs[t.key]
                    if secs then
                        if on.bossSoon and bossTiers[t.key] and prev and prev > bossWarn and secs <= bossWarn then
                            lines[#lines + 1] = "• **" .. t.key .. "** portal (needs " .. req .. " speed) in " .. clock
                        end
                        lastSecs[t.key] = secs
                    end
                end
            end
            if #lines > 0 then
                local desc = table.concat(lines, "\n")
                sendWebhook("Boss fight soon", desc)
                local plain = desc:gsub("%*", "")
                Rayfield:Notify({Title = "Boss soon", Content = plain, Duration = 8})
            end
        end)
    end
end)

-- game-side boss announcements: we forward whatever the remote sends so you can see boss names
local function fmt(v, d)
    d = d or 0
    local t = typeof(v)
    if t == "table" and d < 2 then
        local parts = {}
        for k, x in pairs(v) do parts[#parts + 1] = tostring(k) .. "=" .. fmt(x, d + 1) end
        return "{" .. table.concat(parts, ", ") .. "}"
    elseif t == "Instance" then
        return v.Name
    end
    return tostring(v)
end

for _, name in ipairs({"BossAnnounce", "BossPortalOffer"}) do
    task.spawn(function()
        local folder = RepS:WaitForChild("Remotes", 15)
        local r = folder and folder:WaitForChild(name, 15)
        if not r then return end
        r.OnClientEvent:Connect(function(...)
            if not on.bossEvent then return end
            local args, parts = table.pack(...), {}
            for i = 1, args.n do parts[#parts + 1] = fmt(args[i]) end
            local text = table.concat(parts, " | ")
            if not passes(wh.bosses, text) then return end
            local msg = name .. ": " .. (text ~= "" and text or "(no data)")
            sendWebhook("Boss event", msg)
            Rayfield:Notify({Title = "Boss event", Content = msg:sub(1, 200), Duration = 8})
        end)
    end)
end

-- stats: money / speed change since you executed the script
local SUFFIX = {{"Dc", 1e33}, {"No", 1e30}, {"Oc", 1e27}, {"Sp", 1e24}, {"Sx", 1e21}, {"Qi", 1e18},
    {"Qa", 1e15}, {"T", 1e12}, {"B", 1e9}, {"M", 1e6}, {"K", 1e3}}

local function parseNum(txt)
    if txt == nil then return end
    local num, suf = tostring(txt):match("^%+?%$?%s*([%d%.,]+)%s*(%a*)")
    if not num then return end
    local n = tonumber((num:gsub(",", "")))
    if not n then return end
    if suf == "" then return n end
    for _, x in ipairs(SUFFIX) do
        if x[1]:lower() == suf:lower() then return n * x[2] end
    end
end

local function abbr(n)
    local sign = n < 0 and "-" or ""
    n = math.abs(n)
    for _, x in ipairs(SUFFIX) do
        if n >= x[2] then return sign .. string.format("%.2f", n / x[2]) .. x[1] end
    end
    return sign .. string.format("%.2f", n)
end

local function pct(now, start)
    if not (now and start) or start == 0 then return "n/a" end
    return string.format("%+.2f%%", (now - start) / start * 100)
end

local function hms(sec)
    sec = math.floor(sec)
    return string.format("%02d:%02d:%02d", math.floor(sec / 3600), math.floor(sec % 3600 / 60), sec % 60)
end

local function readSpeed()
    local ls = lp:FindFirstChild("leaderstats")
    local v = ls and ls:FindFirstChild("Speed")
    return v and parseNum(v.Value)
end

local function readMoneyRate()
    local a = lp:GetAttribute("AdvancedCashRate")
    if type(a) == "number" then return a end
    local ls = lp:FindFirstChild("leaderstats")
    local v = ls and ls:FindFirstChild("Money/s")
    return v and parseNum(v.Value)
end

-- current money isn't in leaderstats, so read the HUD text that looks like "$52.1B"
local moneyLabel
local function isMoneyText(t) return t:match("^%$[%d%.,]+%s*%a*$") and not t:find("/") end
local function readMoney()
    if moneyLabel and moneyLabel:IsDescendantOf(game) and isMoneyText(moneyLabel.Text) then
        return parseNum(moneyLabel.Text)
    end
    moneyLabel = nil
    local best, bestSize = nil, -1
    for _, root in ipairs({lp.PlayerGui:FindFirstChild("StealAVerityHUD"), lp.PlayerGui}) do
        if root then
            for _, d in ipairs(root:GetDescendants()) do
                if d:IsA("TextLabel") and d.Visible and isMoneyText(d.Text) and d.TextSize > bestSize then
                    best, bestSize = d, d.TextSize
                end
            end
        end
        if best then break end
    end
    moneyLabel = best
    return best and parseNum(best.Text)
end

local statLabels, statText = {}, {}
local function setStat(key, txt)
    local l = statLabels[key]
    if l and statText[key] ~= txt then l:Set(txt) statText[key] = txt end
end

task.spawn(function()
    local samples, speed0, money0 = {}, nil, nil
    while task.wait(1) do
        pcall(function()
            setStat("timer", "Script running: " .. hms(os.clock() - scriptStart))
            local speed, money, mrate = readSpeed(), readMoney(), readMoneyRate()
            speed0 = speed0 or speed
            money0 = money0 or money
            setStat("money", "Money: " .. (money and ("$" .. abbr(money)) or "not found") .. "  (" .. pct(money, money0) .. ")")
            setStat("speed", "Speed: " .. (speed and abbr(speed) or "?") .. "  (" .. pct(speed, speed0) .. ")")
            if speed then -- speed/s averaged over the last 30 seconds
                samples[#samples + 1] = {os.clock(), speed}
                while #samples > 1 and os.clock() - samples[1][1] > 30 do table.remove(samples, 1) end
            end
            local sps = "..."
            if #samples >= 2 then
                local f, l = samples[1], samples[#samples]
                sps = abbr((l[2] - f[2]) / math.max(l[1] - f[1], 1))
            end
            setStat("sps", "Speed/s: " .. sps)
            setStat("mps", "Money/s: " .. (mrate and ("$" .. abbr(mrate)) or "?"))
        end)
    end
end)

-- REAL boxes are the models in Workspace.BoxRuntime (Areas.X.Boxes.Box are only 1x1 spawn markers).
-- An area box = a BoxRuntime model that sits on one of the area floors.
on.esp, on.espLabel = false, false
local areaBounds, areaIdx = {}, {}
for i, n in ipairs(LISTS.areas) do areaIdx[n] = i end

local function refreshAreaBounds()
    table.clear(areaBounds)
    local af = workspace:FindFirstChild("Areas")
    if not af then return end
    for _, a in ipairs(af:GetChildren()) do
        local name = a:GetAttribute("DisplayName")
        if name then
            local f = a:FindFirstChild("Floor")
            if f and f:IsA("BasePart") then areaBounds[#areaBounds + 1] = {name = name, cf = f.CFrame, size = f.Size} end
            local split = a:FindFirstChild("FloorSplit")
            if split and split:IsA("Model") then
                local cf, size = split:GetBoundingBox()
                areaBounds[#areaBounds + 1] = {name = name, cf = cf, size = size}
            end
        end
    end
end

local function areaOf(pos)
    for _, b in ipairs(areaBounds) do
        local p = b.cf:PointToObjectSpace(pos)
        if math.abs(p.X) <= b.size.X / 2 + 2 and math.abs(p.Z) <= b.size.Z / 2 + 2 and math.abs(p.Y) <= 60 then
            return b.name
        end
    end
end

-- face image id -> box type, built from the game's own BoxConfig.ById (only ids that belong to one box type)
local boxTypeByImage = {}
local function prettyId(id)
    local x = id:gsub("_box$", "")
    return (x:gsub("^%l", string.upper))
end
pcall(function()
    local cfg = require(RepS.Shared.BoxConfig)
    local owners = {}
    local function walk(v, id, d)
        if type(v) == "string" then
            for digits in v:gmatch("%d%d%d%d%d+") do
                owners[digits] = owners[digits] or {}
                owners[digits][id] = true
            end
        elseif type(v) == "table" and d < 3 then
            for _, x in pairs(v) do walk(x, id, d + 1) end
        end
    end
    for id, entry in pairs(cfg.ById) do walk(entry, prettyId(id), 0) end
    for digits, ids in pairs(owners) do
        local only, n = nil, 0
        for id in pairs(ids) do only, n = id, n + 1 end
        if n == 1 then boxTypeByImage[digits] = only end
    end
end)

local function faceDigits(model)
    local face = model:FindFirstChild("Face", true)
    local img = face and face:IsA("ImageLabel") and face.Image or ""
    return img:match("%d+")
end

local function boxTypeOf(model)
    for _, o in ipairs({model, model:FindFirstChild("Core")}) do
        if o then
            for k, v in pairs(o:GetAttributes()) do
                if type(v) == "string" and v ~= "" and k ~= "BoxUid" then return v end
            end
        end
    end
    local d = faceDigits(model)
    if d and boxTypeByImage[d] then return boxTypeByImage[d] end
    return d and ("Face " .. d) or "Unknown"
end

local function areaBoxes()
    refreshAreaBounds()
    local res = {}
    local br = workspace:FindFirstChild("BoxRuntime")
    if not br then return res end
    for _, m in ipairs(br:GetChildren()) do
        if m:IsA("Model") then
            local core = m:FindFirstChild("Core") or m.PrimaryPart
            if core then
                local area = areaOf(core.Position)
                if area then res[#res + 1] = {model = m, core = core, area = area, type = boxTypeOf(m)} end
            end
        end
    end
    return res
end

local espSingle, espColor, espTransp, typeColors = false, Color3.fromRGB(255, 200, 0), 0.6, {}
local function colorFor(t)
    if espSingle then return espColor end
    if typeColors[t] then return typeColors[t] end
    local h = 0
    for i = 1, #t do h = (h * 31 + t:byte(i)) % 360 end
    return Color3.fromHSV(h / 360, 0.8, 1)
end

-- ESP
local espObjs = {}
local function espClear()
    for _, o in pairs(espObjs) do o.folder:Destroy() end
    table.clear(espObjs)
end

task.spawn(function()
    while task.wait(2) do
        if not on.esp then
            if next(espObjs) then espClear() end
        else
            pcall(function()
                local parent = (gethui and gethui()) or game:GetService("CoreGui")
                local live = {}
                for _, b in ipairs(areaBoxes()) do
                    if allowed("areas", b.area) and allowed("boxes", b.type) then
                        live[b.model] = true
                        local o = espObjs[b.model]
                        if not o then
                            local f = Instance.new("Folder")
                            local adorn = Instance.new("BoxHandleAdornment")
                            adorn.Adornee, adorn.AlwaysOnTop, adorn.ZIndex = b.core, true, 1
                            adorn.Size, adorn.Transparency = b.model:GetExtentsSize(), 0.6
                            adorn.Parent = f
                            local gui = Instance.new("BillboardGui")
                            gui.Adornee, gui.AlwaysOnTop = b.core, true
                            gui.Size, gui.StudsOffset = UDim2.fromOffset(160, 22), Vector3.new(0, 3, 0)
                            local tl = Instance.new("TextLabel", gui)
                            tl.Size, tl.BackgroundTransparency = UDim2.fromScale(1, 1), 1
                            tl.TextScaled, tl.Font, tl.TextStrokeTransparency = true, Enum.Font.GothamBold, 0.4
                            gui.Parent = f
                            f.Parent = parent
                            o = {folder = f, adorn = adorn, gui = gui, label = tl}
                            espObjs[b.model] = o
                        end
                        local c = colorFor(b.type)
                        o.adorn.Color3, o.label.TextColor3 = c, c
                        o.adorn.Transparency = espTransp
                        o.label.Text = b.type .. " - " .. b.area
                        o.gui.Enabled = on.espLabel
                    end
                end
                for m, o in pairs(espObjs) do
                    if not live[m] then o.folder:Destroy() espObjs[m] = nil end
                end
            end)
        end
    end
end)

-- summary of every box on the map, grouped by area (sent after each night reset)
local function boxSummary()
    local byArea, order = {}, {}
    for _, b in ipairs(areaBoxes()) do
        if allowed("areas", b.area) and allowed("boxes", b.type) then
            if not byArea[b.area] then byArea[b.area] = {} order[#order + 1] = b.area end
            byArea[b.area][b.type] = (byArea[b.area][b.type] or 0) + 1
        end
    end
    table.sort(order, function(x, y) return (areaIdx[x] or 99) < (areaIdx[y] or 99) end)
    local lines = {}
    for _, area in ipairs(order) do
        local parts = {}
        for ty, n in pairs(byArea[area]) do parts[#parts + 1] = ty .. (n > 1 and (" x" .. n) or "") end
        table.sort(parts)
        lines[#lines + 1] = "**" .. area .. "**: " .. table.concat(parts, ", ")
    end
    return table.concat(lines, "\n"), #order
end

local function sendBoxSummary()
    local desc, n = boxSummary()
    if n == 0 then return false end
    sendWebhook("Boxes on the map", desc:sub(1, 4000))
    Rayfield:Notify({Title = "Boxes on the map", Content = (desc:gsub("%*", "")):sub(1, 200), Duration = 8})
    return true
end

-- night reset = the NightReadout countdown jumps from ~0 back up to minutes
local lastNight
task.spawn(function()
    while task.wait(1) do
        pcall(function()
            local g = lp.PlayerGui:FindFirstChild("NightReadout")
            if not g then return end
            local txt
            for _, d in ipairs(g:GetDescendants()) do
                if d:IsA("TextLabel") and d.Text:find("%d+s") then txt = d.Text break end
            end
            if not txt then return end
            local m, sec = txt:match("(%d+)m%s*(%d+)s")
            local secs = m and (tonumber(m) * 60 + tonumber(sec)) or tonumber(txt:match("(%d+)s"))
            if not secs then return end
            if on.night and lastNight and lastNight <= 20 and secs > lastNight + 100 then
                task.delay(6, function() pcall(sendBoxSummary) end) -- give the new boxes time to spawn
            end
            lastNight = secs
        end)
    end
end)

-- debug: every box with its area, detected type and face image id
local function scanReport()
    local out = {}
    for _, b in ipairs(areaBoxes()) do
        out[#out + 1] = b.area .. " | " .. b.type .. " | face=" .. tostring(faceDigits(b.model))
    end
    table.sort(out)
    local text = table.concat(out, "\n")
    if setclipboard then setclipboard(text) end
    print(text)
    Rayfield:Notify({Title = "Box scan", Content = #out .. " boxes scanned (copied to clipboard)", Duration = 4})
end

-- anti-AFK
on.afk = false
lp.Idled:Connect(function()
    if on.afk then
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end
end)

-- re-run this script after server hops / rejoins
local loaderUrl = "https://raw.githubusercontent.com/ImHunter9192/StealAVerity/refs/heads/main/stela.lua"
local function loaderSrc() return 'loadstring(game:HttpGet("' .. loaderUrl .. '"))()' end
local queueFn = (syn and syn.queue_on_teleport) or queue_on_teleport or (fluxus and fluxus.queue_on_teleport)
on.reexec = false
lp.OnTeleport:Connect(function()
    if on.reexec and queueFn then pcall(queueFn, loaderSrc()) end
end)

local function rayfieldMain()
    local roots = {game:GetService("CoreGui"), lp.PlayerGui}
    if gethui then table.insert(roots, 1, gethui()) end
    for _, root in ipairs(roots) do
        for _, g in ipairs(root:GetChildren()) do
            if g:IsA("ScreenGui") and g.Name:find("Rayfield") and g:FindFirstChild("Main") then return g.Main end
        end
    end
end

local Window = Rayfield:CreateWindow({
    Name = "Stela A Verity", LoadingTitle = "Stela A Verity", LoadingSubtitle = "Loading...",
    ConfigurationSaving = {Enabled = true, FolderName = "StelaAVerity", FileName = "Config"},
    KeySystem = false,
})
local Main, Combat, Player = Window:CreateTab("Main"), Window:CreateTab("Combat"), Window:CreateTab("Player")

local function toggle(tab, name, key, cb)
    tab:CreateToggle({Name = name, CurrentValue = false, Flag = key,
        Callback = function(v) on[key] = v if cb then cb(v) end end})
end

Main:CreateButton({Name = "Go To My Treadmill", Callback = function() goTo(myTreadmill(), 4) end})
Main:CreateButton({Name = "Go To Admin Treadmill", Callback = function()
    local a = admin()
    if a then goTo(a, adminUp(a)) else Rayfield:Notify({Title = "Admin Treadmill", Content = "Not spawned", Duration = 3}) end
end})
toggle(Main, "Auto Go To Treadmill", "tread")
toggle(Main, "Auto Go To Admin Treadmill", "admin")
toggle(Main, "Auto Place Verity Boxes", "boxes")
on.tpPlace = true
Main:CreateToggle({Name = "Teleport to base while placing, then back", CurrentValue = true, Flag = "TpPlace",
    Callback = function(v) on.tpPlace = v end})
Main:CreateButton({Name = "Set Box Spot To Where I'm Standing", Callback = saveBoxSpot})
Main:CreateButton({Name = "Reset Box Spot (use base center)", Callback = function()
    boxSpot = nil
    pcall(function() if writefile then writefile("stela_boxspot.txt", "") end end)
    Rayfield:Notify({Title = "Box spot", Content = "Reset to base center", Duration = 3})
end})
Main:CreateSlider({Name = "Box Spread Around Spot", Range = {0, 20}, Increment = 1, Suffix = " studs",
    CurrentValue = 6, Flag = "PlaceSpread", Callback = function(v) placeSpread = v end})
Main:CreateSlider({Name = "Place Delay", Range = {0.1, 5}, Increment = 0.1, Suffix = "s",
    CurrentValue = 0.5, Flag = "PlaceDelay", Callback = function(v) placeDelay = v end})

toggle(Combat, "Bat Hitbox Expander", "hitbox", function(v) if not v then resetHitboxes() end end)
Combat:CreateSlider({Name = "Hitbox Size", Range = {2, 40}, Increment = 1, Suffix = " studs",
    CurrentValue = 10, Flag = "HitboxSize", Callback = function(v) hitSize = v end})

toggle(Player, "Anti Ragdoll", "ragdoll")

local Stats = Window:CreateTab("Stats")
Stats:CreateSection("Session")
statLabels.timer = Stats:CreateLabel("Script running: 00:00:00")
Stats:CreateSection("Change since you executed the script")
statLabels.money = Stats:CreateLabel("Money: loading...")
statLabels.speed = Stats:CreateLabel("Speed: loading...")
Stats:CreateSection("Rates")
statLabels.sps = Stats:CreateLabel("Speed/s: loading...")
statLabels.mps = Stats:CreateLabel("Money/s: loading...")


local Visuals = Window:CreateTab("Visuals")
toggle(Visuals, "Box ESP (color-coded highlight)", "esp", function(v) if not v then espClear() end end)
toggle(Visuals, "Show box type + area above boxes", "espLabel")
Visuals:CreateButton({Name = "Scan Boxes (copy report)", Callback = scanReport})
Visuals:CreateSection("ESP colors")
Visuals:CreateToggle({Name = "Use one color for all boxes", CurrentValue = false, Flag = "EspSingle",
    Callback = function(v) espSingle = v end})
Visuals:CreateColorPicker({Name = "One color", Color = espColor, Flag = "EspColor",
    Callback = function(c) espColor = c end})
Visuals:CreateSlider({Name = "ESP fill transparency", Range = {0, 0.95}, Increment = 0.05, CurrentValue = 0.6,
    Flag = "EspTransp", Callback = function(v) espTransp = v end})
local colorType, pickerReady = LISTS.boxes[1], false
task.delay(3, function() pickerReady = true end) -- ignore the color picker's startup callback
Visuals:CreateDropdown({Name = "Pick a box type to recolor", Options = copy(LISTS.boxes),
    CurrentOption = {LISTS.boxes[1]}, MultipleOptions = false,
    Callback = function(o) colorType = type(o) == "table" and o[1] or o end})
Visuals:CreateColorPicker({Name = "Color for that box type", Color = Color3.fromRGB(255, 255, 255),
    Callback = function(c) if pickerReady and colorType then typeColors[colorType] = c end end})
Visuals:CreateButton({Name = "Reset per-type colors", Callback = function() table.clear(typeColors) end})

local Misc = Window:CreateTab("Misc")
Misc:CreateSection("Utility")
toggle(Misc, "Anti-AFK", "afk")
Misc:CreateSection("Interface")
Misc:CreateDropdown({Name = "UI color theme",
    Options = {"Default", "AmberGlow", "Amethyst", "Bloom", "DarkBlue", "Green", "Light", "Ocean", "Serenity"},
    CurrentOption = {"Default"}, MultipleOptions = false, Flag = "UiTheme",
    Callback = function(o)
        local name = type(o) == "table" and o[1] or o
        if not pcall(function() Window.ModifyTheme(name) end) then
            Rayfield:Notify({Title = "Theme", Content = "This Rayfield version can't change themes", Duration = 4})
        end
    end})
Misc:CreateSlider({Name = "UI size", Range = {50, 150}, Increment = 5, Suffix = "%", CurrentValue = 100,
    Flag = "UiScale", Callback = function(v)
        pcall(function()
            local m = rayfieldMain()
            if not m then return end
            local sc = m:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", m)
            sc.Scale = v / 100
        end)
    end})
Misc:CreateSection("Auto execute")
Misc:CreateInput({Name = "Script link to auto execute", CurrentValue = loaderUrl, PlaceholderText = loaderUrl,
    RemoveTextAfterFocusLost = false, Flag = "LoaderUrl",
    Callback = function(t) t = trim(t or "") if t ~= "" then loaderUrl = t end end})
toggle(Misc, "Re-run script after server hop / rejoin", "reexec")
Misc:CreateButton({Name = "Save to executor autoexec folder", Callback = function()
    local ok = pcall(function()
        if makefolder and isfolder and not isfolder("autoexec") then makefolder("autoexec") end
        writefile("autoexec/StelaAVerity.lua", loaderSrc())
    end)
    Rayfield:Notify({Title = "Auto execute", Duration = 5,
        Content = ok and "Saved autoexec/StelaAVerity.lua (delete it to turn this off)" or "Your executor can't write files"})
end})


local Hook = Window:CreateTab("Webhook")
Hook:CreateInput({Name = "Webhook URL", PlaceholderText = "https://discord.com/api/webhooks/...",
    RemoveTextAfterFocusLost = false, Flag = "WebhookUrl", Callback = function(t) wh.url = t end})
Hook:CreateToggle({Name = "Notify after every night reset", CurrentValue = true, Flag = "WebhookNight",
    Callback = function(v) on.night = v end})
Hook:CreateButton({Name = "Send Test Message", Callback = function()
    local ok = sendWebhook("Test", "Webhook works!")
    Rayfield:Notify({Title = "Webhook", Duration = 3,
        Content = ok and "Test sent" or "Invalid URL or your executor has no request function"})
end})
Hook:CreateButton({Name = "Read Current Announcements Now", Callback = function()
    if not processAnnouncements(true) then
        Rayfield:Notify({Title = "Webhook", Content = "No matching announcements on screen right now", Duration = 4})
    end
end})

Hook:CreateButton({Name = "Send Box Summary Now", Callback = function()
    if not sendBoxSummary() then
        Rayfield:Notify({Title = "Webhook", Content = "No boxes matched your filters", Duration = 4})
    end
end})

local Filters = Window:CreateTab("Notif Filters")
local function picker(title, key, flag)
    Filters:CreateSection(title)
    local dd
    dd = Filters:CreateDropdown({Name = title .. " (scroll, tap to pick)", Options = copy(LISTS[key]),
        CurrentOption = copy(LISTS[key]), MultipleOptions = true, Flag = flag,
        Callback = function(o)
            if type(o) == "string" then o = {o} end
            setSel(key, o)
        end})
    Filters:CreateButton({Name = "Select all " .. title, Callback = function()
        setSel(key, LISTS[key]) dd:Set(copy(LISTS[key]))
    end})
    Filters:CreateButton({Name = "Clear all " .. title, Callback = function()
        setSel(key, {}) dd:Set({})
    end})
    Filters:CreateInput({Name = "Add a name to " .. title, PlaceholderText = "type it, then press enter",
        RemoveTextAfterFocusLost = true, Callback = function(t)
            t = trim(t or "")
            if t == "" or findOpt(key, t) then return end
            table.insert(LISTS[key], t)
            sel[key][t:lower()] = true
            local picked = {}
            for _, n in ipairs(LISTS[key]) do if sel[key][n:lower()] then picked[#picked + 1] = n end end
            dd:Refresh(copy(LISTS[key]))
            dd:Set(picked)
        end})
end
picker("Areas", "areas", "FilterAreas")
picker("Box types", "boxes", "FilterBoxes")

local Boss = Window:CreateTab("Boss")
Boss:CreateSection("Next boss timers")
for _, t in ipairs(TIERS) do bossLabels[t.key] = Boss:CreateLabel(t.key .. ": loading...") end
Boss:CreateSection("Discord alerts (uses the URL from the Webhook tab)")
Boss:CreateToggle({Name = "Alert shortly before the boss starts", CurrentValue = false, Flag = "BossSoon",
    Callback = function(v) on.bossSoon = v end})
Boss:CreateSlider({Name = "Alert when this many seconds away", Range = {10, 300}, Increment = 5, Suffix = "s",
    CurrentValue = 60, Flag = "BossWarn", Callback = function(v) bossWarn = v end})
Boss:CreateDropdown({Name = "Which portals to alert for", Options = {"Normal", "High", "Top"},
    CurrentOption = {"Normal", "High", "Top"}, MultipleOptions = true, Flag = "BossTiers",
    Callback = function(o)
        if type(o) == "string" then o = {o} end
        bossTiers = {}
        for _, k in ipairs(o) do bossTiers[k] = true end
    end})
Boss:CreateToggle({Name = "Alert when the game announces a boss", CurrentValue = false, Flag = "BossEvent",
    Callback = function(v) on.bossEvent = v end})
Boss:CreateInput({Name = "Boss names (comma separated, empty = all)", PlaceholderText = "name1, name2",
    RemoveTextAfterFocusLost = false, Flag = "BossNames", Callback = function(t) wh.bosses = t end})

Rayfield:LoadConfiguration()
