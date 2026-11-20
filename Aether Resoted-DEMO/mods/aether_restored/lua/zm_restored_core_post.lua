local function run(name, fn)
    pcall(fn)
end

run("ClassicUtils", function()
    local H = rawget(_G, "xhash")

    if type(H) ~= "function" then return end

    local legacy = rawget(_G, "JuggAugmentRename")
    if legacy then legacy.enabled = false end

    local old = rawget(_G, "ClassicUtils")
    if old and old.version == 2 then return end
    if old then old.enabled = false end

    local S = { version = 2, enabled = true, ticks = 0, polls = 0, hooks = {}, logged = {} }
    rawset(_G, "ClassicUtils", S)

    local PATTERNS = {
        { "Salvage x%d+", "Shield Parts x1" },
    }

    local PERKS = {
        {
            ref = "specialty_juggernog",
            label = "Juggernog",
            renames = {
                { lootId = 57716, key = "juggernog_probiotic", old = "Probiotic",
                  name = "Iron Maiden",
                  desc = "Drastically increase health, but decrease regeneration speed." },
                { lootId = 82060, key = "juggernog_turtleshell", old = "Turtle Shell",
                  name = "Apollo's Will",
                  desc = "Shields now regenerate over time." },
                { lootId = 100424, key = "juggernog_ironcore", old = "Iron Core",
                  name = "Dying Wish",
                  desc = "On lethal damage, become immune to all damage briefly. Each charge has a longer cooldown." },
                { lootId = 57721, key = "juggernog_retaliation", old = "Retaliation",
                  name = "Reinforced Shield",
                  desc = "Shields now have more health." },
                { lootId = 82040, key = "juggernog_hardenedplates", old = "Hardened Plates",
                  name = "Medpack",
                  desc = "Restoring armor heals you." },
                { lootId = 57715, key = "juggernog_durableplates", old = "Durable Plates",
                  name = "Barbed",
                  desc = "Zombies now take damage after damaging you." },
            },
        },
        {
            ref = "specialty_quickrevive",
            label = "Quick Revive",
            renames = {
                { lootId = 57727, key = "quickrevive_emt", old = "EMT",
                  desc = "Revived players keep 5 perks. Dead players respawn with their weapons." },
                { lootId = 57725, key = "quickrevive_equivalentexchange", old = "Equivalent Exchange",
                  name = "Germaphobe",
                  desc = "Avoiding damage grants overhealth." },
                { lootId = 81224, key = "quickrevive_dyingwish", old = "Dying Wish",
                  name = "Regeneration Elixir",
                  desc = "Health regeneration can occasionally persist after taking damage." },
                { lootId = 102242, key = "quickrevive_adrenalinerush", old = "Adrenaline Rush",
                  name = "Life's Reach",
                  desc = "Increases regeneration speed. Revive players from a further distance." },
                { lootId = 57724, key = "quickrevive_swiftrecovery", old = "Swift Recovery",
                  desc = "Slightly increase movement speed during regeneration." },
                { lootId = 102243, key = "quickrevive_emergencymedicalkit", old = "Emergency Medical Kit",
                  name = "Emergency Medkit" },
                { lootId = 57723, key = "quickrevive_slowdeath", old = "Slow Death",
                  name = "Coagulant" },
                { lootId = 57722, key = "quickrevive_karmicreturn", old = "Karmic Return",
                  name = "Up and At'em",
                  desc = "Slightly improves health regeneration and revive speeds." },
            },
        },
        {
            ref = "specialty_z_mod",
            label = "Mule Kick",
            renames = {
                { lootId = 122208, key = "mulekick_multipack", old = "Multi Pack",
                  name = "Multi Pack",
                  desc = "Pack-a-Punching a weapon might cause another weapon to upgrade." },
                { lootId = 97829, key = "mulekick_platehunter", old = "Plate Hunter",
                  name = "Bandolier Bandit",
                  desc = "Carry more stock ammo." },
                { lootId = 97815, key = "mulekick_bogo", old = "Bogo",
                  name = "Mule Munchies",
                  desc = "Mule Kick does not take up a perk slot." },
            },
        },
    }

    for _, perk in ipairs(PERKS) do
        perk.byLoot = {}
        for _, r in ipairs(perk.renames) do
            if r.lootId then perk.byLoot[r.lootId] = r end
        end
    end

    local ANY = { ref = "any", label = "augment", renames = {}, byLoot = {}, lootOnly = true }
    for _, perk in ipairs(PERKS) do
        for _, r in ipairs(perk.renames) do
            ANY.renames[#ANY.renames + 1] = r
            if r.lootId then ANY.byLoot[r.lootId] = r end
        end
    end

    local hkCache = {}

    local function hk(name)
        local v = hkCache[name]
        if v == nil then
            local ok, r = pcall(H, name)
            v = (ok and r) or false
            hkCache[name] = v
        end
        if v == false then return nil end
        return v
    end

    local function idx(t, k) return t[k] end
    local function callGetValue(field, controller) return field:GetValue(controller) end

    local function g(t, k)
        local tt = type(t)
        if tt ~= "table" and tt ~= "userdata" then return nil end
        local hv = hk(k)
        local v
        if hv ~= nil then
            local ok, r = pcall(idx, t, hv)
            if ok then v = r end
        end
        if v == nil then
            local ok, r = pcall(idx, t, k)
            if ok then v = r end
        end
        return v
    end

    local function s(t, k, v)
        local hv = hk(k)
        if hv ~= nil then t[hv] = v end
        t[k] = v
    end

    local function allFnKeys(tbl, name)
        local keys, seen = {}, {}
        if type(tbl) ~= "table" then return keys end
        for _, key in ipairs({ name, hk(name), hk(name:lower()) }) do
            if key ~= nil and not seen[key] then
                seen[key] = true
                local ok, f = pcall(idx, tbl, key)
                if ok and type(f) == "function" then keys[#keys + 1] = { key = key, fn = f } end
            end
        end
        return keys
    end

    local function findFn(tbl, name)
        for _, key in ipairs({ name, hk(name), hk(name:lower()) }) do
            local ok, f = pcall(idx, tbl, key)
            if ok and type(f) == "function" then return key, f end
        end
        return nil
    end

    local function refMatches(ref, wanted)
        if ref == nil then return false end
        if ref == wanted then return true end
        local hashed = hk(wanted)
        return hashed ~= nil and (ref == hashed or tostring(ref) == tostring(hashed))
    end

    local function perkForRef(ref)
        for _, perk in ipairs(PERKS) do
            if refMatches(ref, perk.ref) then return perk end
        end
        return nil
    end

    local function plainName(v)
        return (string.gsub(string.lower(tostring(v)), "[^%w]", ""))
    end

    local function matchEntry(perk, lootId, text)
        lootId = tonumber(lootId)
        if lootId and perk.byLoot[lootId] then return perk.byLoot[lootId] end
        if perk.lootOnly then return nil end
        if type(text) == "string" and text ~= "" then
            local lowered = text:lower()
            local plain = plainName(text)
            for _, r in ipairs(perk.renames) do
                if lowered == r.old:lower() or lowered:find(r.key, 1, true) then return r end
                if plain == plainName(r.old) then return r end
                if r.alts then
                    for _, alt in ipairs(r.alts) do
                        if plain == plainName(alt) then return r end
                    end
                end
                if r.has then
                    for _, part in ipairs(r.has) do
                        if plain:find(part, 1, true) then return r end
                    end
                end
                if r.name and plain == plainName(r.name) then return r end
            end
        end
        return nil
    end

    local function renameRow(perk, row)
        if type(row) ~= "table" then return false end
        local current = g(row, "displayname")
        local entry = matchEntry(perk, g(row, "lootid"), type(current) == "string" and current or nil)
        if not entry then return false end
        if entry.name and current ~= entry.name then s(row, "displayname", entry.name) end
        if entry.desc and g(row, "description") ~= entry.desc then s(row, "description", entry.desc) end
        return true
    end

    local function renameRowList(perk, list)
        local count = 0
        if type(list) ~= "table" then return 0 end
        for _, row in ipairs(list) do
            if renameRow(perk, row) then count = count + 1 end
        end
        return count
    end

    local function renamePerkRows(perk)
        local augment = rawget(_G, "ZMAUGMENT")
        if type(augment) ~= "table" then return 0 end
        local total = 0
        for _, listName in ipairs({ "augmentlist_full", "augmentlist_major", "augmentlist_minor" }) do
            total = total + renameRowList(perk, g(g(augment, listName), perk.ref))
        end
        return total
    end

    local function renameAnyRows()
        local augment = rawget(_G, "ZMAUGMENT")
        if type(augment) ~= "table" then return 0 end
        local total = 0
        for _, listName in ipairs({ "augmentlist_full", "augmentlist_major", "augmentlist_minor" }) do
            local tbl = g(augment, listName)
            if type(tbl) == "table" then
                for _, list in pairs(tbl) do
                    if type(list) == "table" then total = total + renameRowList(ANY, list) end
                end
            end
        end
        return total
    end

    local function renameAllRows()
        local total = 0
        for _, perk in ipairs(PERKS) do total = total + renamePerkRows(perk) end
        total = total + renameAnyRows()
        return total > 0
    end

    local function readField(field, controller)
        if field == nil then return nil end
        local ok, value = pcall(callGetValue, field, controller)
        if ok then return value end
        return nil
    end

    local function writeField(field, controller, value)
        if field == nil then return false end
        local setter = g(field, "SetValue")
        if type(setter) ~= "function" then return false end
        local ok = pcall(setter, field, controller, value)
        return ok
    end

    local function listEntryCount(list, controller)
        local count = tonumber(readField(g(list, "count"), controller))
        if count and count >= 0 and count <= 64 then return math.floor(count) end
        return nil
    end

    local function listEntry(list, index, count)
        if count then
            if index > count then return nil end
            local ok, v = pcall(idx, list, index)
            if ok then return v end
            return nil
        end
        local ok, v = pcall(rawget, list, index)
        if ok then return v end
        return nil
    end

    local function trimListSlots(list, count)
        if not count then return end
        for index = count + 1, count + 24 do
            if rawget(list, index) ~= nil then pcall(rawset, list, index, nil) end
        end
    end

    local function patchAugmentSelectUi(controller, perk)
        local dataSources = rawget(_G, "_DataSources") or rawget(_G, "DataSources")
        local select = g(g(g(dataSources, "zm"), "frontend"), "augment_select")
        if select == nil then return 0 end

        local patched = 0
        for _, listName in ipairs({ "major_augment_list", "minor_augment_list" }) do
            local list = g(select, listName)
            if list ~= nil then
                local count = listEntryCount(list, controller)
                for index = 1, (count or 24) do
                    local entry = listEntry(list, index, count)
                    if entry ~= nil then
                        local item = g(entry, "item")
                        if item ~= nil then
                            local nameField = g(item, "name")
                            local currentName = readField(nameField, controller)
                            local data = matchEntry(perk, readField(g(item, "loot_id"), controller),
                                type(currentName) == "string" and currentName or nil)
                            if data then
                                if data.name and currentName ~= data.name then
                                    writeField(nameField, controller, data.name)
                                end
                                if data.desc then
                                    local descField = g(item, "description")
                                    if readField(descField, controller) ~= data.desc then
                                        writeField(descField, controller, data.desc)
                                    end
                                end
                                patched = patched + 1
                            end
                        end
                    end
                end
                trimListSlots(list, count)
            end
        end
        return patched
    end

    local function hookFunction(object, name, tag, handler)
        if type(object) ~= "table" then return false end
        local keys = allFnKeys(object, name)
        if #keys == 0 then return false end
        local state = S.hooks[tag]
        if not state then
            state = { original = keys[1].fn, key = keys[1].key }
            state.wrapper = function(...)
                if not S.enabled then return state.original(...) end
                return handler(state.original, ...)
            end
            S.hooks[tag] = state
        else
            local allInstalled = true
            for _, entry in ipairs(keys) do
                if entry.fn ~= state.wrapper then allInstalled = false end
            end
            if allInstalled then return true end
            if keys[1].fn ~= state.wrapper then state.original = keys[1].fn end
        end
        for _, entry in ipairs(keys) do object[entry.key] = state.wrapper end
        return true
    end

    local function installHooks()
        local augment = rawget(_G, "ZMAUGMENT")
        if type(augment) ~= "table" then return false end

        hookFunction(augment, "initfullaugmentlist", "renameFullList", function(original, ...)
            local result = original(...)
            pcall(renameAllRows)
            return result
        end)

        hookFunction(augment, "inittypeaugmentlist", "renameTypeList", function(original, controller, equipmentType, ...)
            local result = original(controller, equipmentType, ...)
            pcall(renameAllRows)
            return result
        end)

        hookFunction(augment, "refreshaugmentlistdata", "renameRefresh", function(original, controller, ref, ...)
            local result = original(controller, ref, ...)
            local perk = perkForRef(ref)
            local target = perk or ANY
            pcall(function()
                renameAllRows()
                patchAugmentSelectUi(controller, target)
            end)
            return result
        end)

        for _, tag in ipairs({ "renameFullList", "renameTypeList", "renameRefresh" }) do
            if not S.hooks[tag] then return false end
        end
        S.hookedTable = augment
        return true
    end

    local function poll()
        S.polls = S.polls + 1
        local okHooks, hooked = pcall(installHooks)
        if not okHooks then return end

        if hooked then
            pcall(renameAllRows)
            S.ready = true
        end
    end

    local MAX_POLLS = 120

    poll()

    if not S.ready then
        local frame = rawget(_G, "Frame")
        local dw = frame and (g(frame, "DoWork") or frame.DoWork)
        local qkey, qfn
        if dw then qkey, qfn = findFn(dw, "Queue") end
        if qfn then
            qfn(dw, function()
                if not S.enabled or S.ready then return false end
                S.ticks = S.ticks + 1
                if S.ticks >= 5 then
                    S.ticks = 0
                    poll()
                    if S.ready or S.polls >= MAX_POLLS then return false end
                end
                return true
            end)
        end
    end
end)

run("TextTweaks", function()
    local SWAPS = {
      { "MAX ARMOR", "CARPENTER" },
      { "Max Armor", "Carpenter" },
      { "max armor", "carpenter" },
      { "Mannequin Turret", "Mannequin Turbine" },
      { "MANNEQUIN TURRET", "MANNEQUIN TURBINE" },
      { "mannequin turret", "mannequin turbine" },
      { "No starting Armor. Only armor available is gold armor from the wall buy.", "The Wunderfizz is disabled." }
    }

    local PATTERNS = {
      { "Salvage x ?(%d+)", "Shield Parts x%1" },
      { "Upgrade Rarity%??", "Buy a perk slot?" },
    }

    local GUMS = {
      { gum = "Dead Drop", name = nil, description = "ZOMBIES: Kills grant more points \n\nDEAD OPS ARCADE: Weapon drops are greatly increased."},
      { gum = "Armor Gettin'", name = "Shield Gettin'", description = "ZOMBIES: Give yourself a shield. \n\nDEAD OPS ARCADE: Receive a 1-Plate Armor Vest if you don't have one and get full plates." },
    }

    local K, E = rawget(_G, "KRONOS"), rawget(_G, "Engine")
    if type(K) ~= "table" or type(K.H) ~= "function" or type(E) ~= "table" or rawget(E, "__textTweaks") then return end

    local function plain(s, from, to)
      local out, i = {}, 1
      while true do
        local a, b = string.find(s, from, i, true)
        if not a then break end
        out[#out + 1] = string.sub(s, i, a - 1)
        out[#out + 1] = to
        i = b + 1
      end
      if #out == 0 then return s end
      out[#out + 1] = string.sub(s, i)
      return table.concat(out)
    end

    local function replace(s, list)
      if type(s) ~= "string" or s == "" then return s end
      for n, p in ipairs(list) do
        local from, to = p[1], p[2]
        if type(from) == "string" and from ~= "" and type(to) == "string" and from ~= to then
          if string.find(to, from, 1, true) then
            local mark = "\1" .. n .. "\1"
            s = plain(plain(plain(s, to, mark), from, to), mark, to)
          else
            s = plain(s, from, to)
          end
        end
      end
      return s
    end

    local function anyCase(p)
      local out, i, set = {}, 1, false
      while i <= #p do
        local c = string.sub(p, i, i)
        if c == "%" then
          out[#out + 1] = string.sub(p, i, i + 1)
          i = i + 2
        else
          if c == "[" then set = true elseif c == "]" then set = false end
          if not set and string.match(c, "%a") then
            out[#out + 1] = "[" .. string.lower(c) .. string.upper(c) .. "]"
          else
            out[#out + 1] = c
          end
          i = i + 1
        end
      end
      return table.concat(out)
    end

    local patterns = {}
    for _, p in ipairs(PATTERNS) do
      if type(p) == "table" and type(p[1]) == "string" and p[1] ~= "" and type(p[2]) == "string" then
        patterns[#patterns + 1] = { anyCase(p[1]), p[2] }
      end
    end

    local learned = {}
    local function swap(s)
      s = replace(replace(s, learned), SWAPS)
      if type(s) ~= "string" or s == "" then return s end
      for _, p in ipairs(patterns) do
        local ok, r = pcall(string.gsub, s, p[1], p[2])
        if ok and type(r) == "string" then s = r end
      end
      local ok2, r2 = pcall(string.gsub, s, "%f[%a][Ss][Aa][Ll][Vv][Aa][Gg][Ee]%f[%A]", function(w)
        if w == string.upper(w) then return "SHIELD PARTS" end
        return "Shield Parts"
      end)
      if ok2 and type(r2) == "string" then s = r2 end
      return s
    end

    local function norm(s)
      return (string.gsub(string.lower(tostring(s)), "[^%w]", ""))
    end

    local byGum = {}
    for _, g in ipairs(GUMS) do
      if type(g) == "table" and type(g.gum) == "string" then byGum[norm(g.gum)] = g end
    end

    local H = K.H
    local K_LOC, K_GSB = H("aed84c33ec5f01ea"), H("f06093d047200548")
    local K_NAME, K_DESC = H("c4bcadba8e631b86"), H("0cc44970c8397929")
    local K_MACHINE, K_ACTIVATED = H("cdf64fb082e0d494"), H("e1f17e9697d77479")
    local K_GUMS, K_LIST, K_GUM = H("da540426d753409c"), H("d2bdbd2f1cea94f5"), H("ec31222ba382d687")
    local K_GET_NAME, K_GET_DESC = H("5f579e5b36906711"), H("1425e4027de6cc1b")
    local loc, gsb = E[K_LOC], E[K_GSB]
    if type(loc) ~= "function" then return end
    local fixed, seen = {}, {}

    local function text(k)
      if k == nil then return nil end
      local ok, s = pcall(loc, k)
      if ok and type(s) == "string" and s ~= "" then return s end
    end

    local function teach(from, to)
      if type(from) ~= "string" or from == "" or type(to) ~= "string" or from == to then return end
      for _, p in ipairs(learned) do if p[1] == from then return end end
      learned[#learned + 1] = { from, to }
      local up = string.upper(from)
      if up ~= from then learned[#learned + 1] = { up, string.upper(to) } end
    end

    local function learn(b)
      if type(b) ~= "table" then return end
      local nk = b[K_NAME]
      if nk == nil then return end
      local key = tostring(nk)
      if seen[key] then return end
      seen[key] = true
      local name = text(nk)
      if not name then return end
      local g = byGum[norm(name)]
      if g == nil then return end
      if type(g.name) == "string" then
        fixed[key] = g.name
        teach(name, g.name)
        local ak = b[K_ACTIVATED]
        local a = text(ak)
        if a and norm(a) == norm(name) then fixed[tostring(ak)] = g.name end
      end
      if type(g.description) == "string" then
        for _, dk in ipairs({ b[K_DESC], b[K_MACHINE] }) do
          local d = text(dk)
          if d then
            fixed[tostring(dk)] = g.description
            teach(d, g.description)
          end
        end
      end
    end

    local function shown(v)
      if v == nil then return v end
      local f = fixed[tostring(v)]
      if f ~= nil then return f end
      if type(v) == "string" then return swap(v) end
      local ok, s = pcall(loc, v)
      if ok and type(s) == "string" then
        local t = swap(s)
        if t ~= s then return t end
      end
      return v
    end

    local wrapped = {}
    local function wrapGetter(G, key)
      local orig = G[key]
      if type(orig) ~= "function" or wrapped[orig] then return end
      local w = function(...)
        local r = orig(...)
        local ok, v = pcall(shown, r)
        if ok then return v end
        return r
      end
      wrapped[w] = true
      G[key] = w
    end

    local function learnAll(G)
      local list = G[K_LIST]()
      local gums = type(list) == "table" and list[K_GUMS]
      if type(gums) ~= "table" or type(gsb) ~= "function" then return end
      for _, e in ipairs(gums) do
        local ref = type(e) == "table" and e[K_GUM]
        if ref then pcall(learn, gsb(ref)) end
      end
    end

    local function patchCache(G)
      local cache = G[K_GUMS]
      if type(cache) ~= "table" then return end
      for _, e in pairs(cache) do
        if type(e) == "table" and type(e[K_NAME]) == "string" then
          local g = byGum[norm(e[K_NAME])]
          if g and type(g.name) == "string" then
            if type(e[K_ACTIVATED]) == "string" and norm(e[K_ACTIVATED]) == norm(e[K_NAME]) then e[K_ACTIVATED] = g.name end
            e[K_NAME] = g.name
          end
          if g and type(g.description) == "string" then
            e[K_DESC] = g.description
            if type(e[K_MACHINE]) == "string" then e[K_MACHINE] = g.description end
          end
          for _, k in ipairs({ K_NAME, K_DESC, K_MACHINE, K_ACTIVATED }) do
            if type(e[k]) == "string" then e[k] = swap(e[k]) end
          end
        end
      end
    end

    local ready = false
    local function setup()
      local G = rawget(_G, "GOBBLEGUM")
      if type(G) ~= "table" then return end
      ready = true
      pcall(learnAll, G)
      pcall(patchCache, G)
      pcall(wrapGetter, G, K_GET_NAME)
      pcall(wrapGetter, G, K_GET_DESC)
    end

    E.__textTweaks = true
    E[K_LOC] = function(key, ...)
      if not ready then pcall(setup) end
      local f = fixed[tostring(key)]
      if f ~= nil then return f end
      return swap(loc(key, ...))
    end
    if type(gsb) == "function" then
      E[K_GSB] = function(...)
        local b = gsb(...)
        pcall(learn, b)
        return b
      end
    end
    pcall(setup)
end)

run("PostKeys", function()
    local P = {}
    local hashers = {}
    local x = rawget(_G, "xhash")
    if type(x) == "function" then hashers[#hashers + 1] = x end
    local K = rawget(_G, "KRONOS")
    if type(K) == "table" and type(K.H) == "function" then hashers[#hashers + 1] = K.H end

    local cache = {}
    function P.keys(name)
        local c = cache[name]
        if c then return c end
        c = { name }
        local seen = { [name] = true }
        for _, h in ipairs(hashers) do
            for _, n in ipairs({ name, string.lower(name) }) do
                local ok, v = pcall(h, n)
                if ok and v ~= nil and not seen[v] then
                    seen[v] = true
                    c[#c + 1] = v
                end
            end
        end
        cache[name] = c
        return c
    end

    function P.get(t, name)
        if type(t) ~= "table" and type(t) ~= "userdata" then return nil end
        for _, k in ipairs(P.keys(name)) do
            local ok, v = pcall(function() return t[k] end)
            if ok and v ~= nil then return v end
        end
        return nil
    end

    function P.set(t, name, v)
        for _, k in ipairs(P.keys(name)) do
            pcall(function() t[k] = v end)
        end
    end

    function P.fns(t, name)
        local out = {}
        if type(t) ~= "table" and type(t) ~= "userdata" then return out end
        for _, k in ipairs(P.keys(name)) do
            local ok, v = pcall(function() return t[k] end)
            if ok and type(v) == "function" then out[#out + 1] = { key = k, fn = v } end
        end
        return out
    end

    function P.later(fn, every, maxTries)
        local frame = rawget(_G, "Frame")
        local dw = P.get(frame, "DoWork")
        local queue = P.get(dw, "Queue")
        if type(queue) ~= "function" then return false end
        local ticks, tries = 0, 0
        queue(dw, function()
            ticks = ticks + 1
            if ticks < every then return true end
            ticks = 0
            tries = tries + 1
            local ok, stop = pcall(fn)
            if ok and stop == true then return false end
            return tries < maxTries
        end)
        return true
    end

    rawset(_G, "PostKeys", P)
end)

run("AmmoModEssence", function()
    local P = rawget(_G, "PostKeys")
    if not P then return end

    local COST = 5000
    local old = rawget(_G, "AmmoModEssence")
    if old then old.enabled = false end

    local S = { enabled = true, calls = 0, logged = {}, installed = {} }
    rawset(_G, "AmmoModEssence", S)

    local function hasAmmo(v)
        if type(v) ~= "string" then return false end
        local l = string.lower(v)
        return string.find(l, "ammomod", 1, true) ~= nil or string.find(l, "ammo_mod", 1, true) ~= nil
    end

    local function isAmmoMod(item, tab)
        for _, key in ipairs({ "widgetName", "name", "category", "ref" }) do
            if hasAmmo(P.get(tab, key)) then return true end
        end
        for _, key in ipairs({ "itemref", "asset" }) do
            if hasAmmo(P.get(item, key)) then return true end
        end
        return false
    end

    local STEP = 5000

    local function isTierTab(tab)
        for _, key in ipairs({ "widgetName", "name", "category" }) do
            local v = P.get(tab, key)
            if type(v) == "string" then
                local l = string.lower(v)
                if string.find(l, "tierupgrade", 1, true) or string.find(l, "weapontier", 1, true) then return true end
            end
        end
        return false
    end

    local function tierRank(item, tab)
        local tier = tonumber(P.get(item, "tier"))
        if not tier or tier < 1 then return nil end
        local rank = 0
        local items = P.get(tab, "items")
        if type(items) == "table" then
            for _, other in ipairs(items) do
                local t = tonumber(P.get(other, "tier"))
                if t and t > 0 and t <= tier then rank = rank + 1 end
            end
        end
        if rank < 1 then rank = tier end
        return rank
    end

    local essence

    local function essenceFor(base)
        local c = {}
        for _, k in ipairs({ "mainlabelcolor", "maincountcolor" }) do
            local v = P.get(base, k)
            if v ~= nil then P.set(c, k, v) end
        end
        P.set(c, "currencyname", "essence")
        P.set(c, "namestring", "CP_ZMB/ESSENCE")
        P.set(c, "iconstringref", "CP_ZMB/ESSENCE_COUNT")
        P.set(c, "iconstringcountref", "CP_ZMB/ESSENCE_COUNT")
        return c
    end

    local function convert(item, tab, price)
        local cur = P.get(item, "currencydata")
        if P.get(cur, "currencyname") == "essence" then
            if P.get(item, "cost") ~= price then P.set(item, "cost", price) end
            return
        end
        if not essence then essence = essenceFor(cur or P.get(tab, "currencydata")) end
        P.set(item, "currencydata", essence)
        P.set(item, "cost", price)
    end

    local function findUtils()
        local U = rawget(_G, "PurchaseMenuUtils")
        if type(U) == "table" then return U end
        return nil
    end

    local function install()
        local U = findUtils()
        if not U then return false end
        local list = P.fns(U, "updateitempricing")
        if #list == 0 then return false end
        local did = false
        for _, e in ipairs(list) do
            if not S.installed[e.fn] then
                local original = e.fn
                local wrapper = function(a, item, tab, ...)
                    S.calls = S.calls + 1
                    local tierSaved, tierValue
                    if S.enabled and type(item) == "table" then
                        pcall(function()
                            if isAmmoMod(item, tab) then
                                convert(item, tab, COST)
                            elseif isTierTab(tab) then
                                local rank = tierRank(item, tab)
                                if rank then
                                    convert(item, tab, STEP * rank)
                                    tierSaved = P.get(item, "CurrentTier")
                                    tierValue = P.get(item, "tier")
                                    P.set(item, "CurrentTier", tierValue)
                                end
                            end
                        end)
                    end
                    if tierValue ~= nil then
                        local r = table.pack(pcall(original, a, item, tab, ...))
                        pcall(P.set, item, "CurrentTier", tierSaved)
                        if not r[1] then error(r[2], 0) end
                        return table.unpack(r, 2, r.n)
                    end
                    return original(a, item, tab, ...)
                end
                S.installed[wrapper] = true
                S.installed[original] = true
                pcall(function() U[e.key] = wrapper end)
                did = true
            end
        end
        return true
    end

    pcall(install)
    P.later(function()
        if not S.enabled then return true end
        pcall(install)
        return false
    end, 10, 600)
end)

run("SalvageText", function()
    local P = rawget(_G, "PostKeys")
    if not P then return end

    local old = rawget(_G, "SalvageText")
    if old then old.enabled = false end

    local S = { enabled = true, hooked = {}, count = 0, logged = {} }
    rawset(_G, "SalvageText", S)

    local function fix(v)
        if type(v) ~= "string" then return v end
        local ok, r = pcall(string.gsub, v, "%f[%a][Ss][Aa][Ll][Vv][Aa][Gg][Ee]%f[%A]", function(w)
            if w == string.upper(w) then return "SHIELD PARTS" end
            return "Shield Parts"
        end)
        if ok and type(r) == "string" then
            return r
        end
        return v
    end

    local function wrapMethod(target, name)
        local did = false
        for _, e in ipairs(P.fns(target, name)) do
            if not S.hooked[e.fn] then
                local original = e.fn
                local wrapper = function(self, v, ...)
                    if S.enabled and type(v) == "string" then v = fix(v) end
                    return original(self, v, ...)
                end
                S.hooked[wrapper] = true
                S.hooked[original] = true
                if pcall(function() target[e.key] = wrapper end) then did = true end
            end
        end
        return did
    end

    local function wrapText(target)
        local a = wrapMethod(target, "setText")
        local b = wrapMethod(target, "SetText")
        return a or b
    end

    local function wrapNew(class)
        for _, e in ipairs(P.fns(class, "new")) do
            if not S.hooked[e.fn] then
                local original = e.fn
                local wrapper = function(...)
                    local el = original(...)
                    if S.enabled and (type(el) == "table" or type(el) == "userdata") then
                        pcall(wrapText, el)
                    end
                    return el
                end
                S.hooked[wrapper] = true
                S.hooked[original] = true
                pcall(function() class[e.key] = wrapper end)
            end
        end
    end

    S.inst = setmetatable({}, { __mode = "k" })

    local TEXT_METHODS = { "setText", "SetText", "SetLabel", "setLabel" }

    local function wrapInstance(child)
        if child == nil then return false end
        local t = type(child)
        if t ~= "table" and t ~= "userdata" then return false end
        local marks = S.inst[child]
        if not marks then marks = {}; S.inst[child] = marks end
        local did = false
        for _, name in ipairs(TEXT_METHODS) do
            for _, e in ipairs(P.fns(child, name)) do
                if not marks[e.key] then
                    marks[e.key] = true
                    local original = e.fn
                    local wrapper = function(self, v, ...)
                        if S.enabled and type(v) == "string" then v = fix(v) end
                        return original(self, v, ...)
                    end
                    if pcall(function() child[e.key] = wrapper end) then did = true end
                end
            end
        end
        return did
    end

    local function field(el, name)
        local ok, v = pcall(function() return el[name] end)
        if ok and v ~= nil then return v end
        return P.get(el, name)
    end

    local function wrapChildren(el)
        local n = 0
        local ok = pcall(function()
            for _, v in pairs(el) do
                local t = type(v)
                if (t == "table" or t == "userdata") and v ~= el and #P.fns(v, "setText") > 0 then
                    if wrapInstance(v) then n = n + 1 end
                end
            end
        end)
        return n
    end

    local CARD_TEXT = {
        "header", "itemtype", "quantity", "cashvalue", "containmentvalue",
        "firetype", "blueprintname", "HeaderBlueprint", "descriptiontext",
        "LockedHintText", "PrimaryRewardTitle", "SecondaryRewardTitle",
        "TierText", "MissionLocation", "warningbanner", "BackpackFullLabel",
    }
    local BUTTON_TEXT = { "icontext", "buttoncallout", "text", "description", "warningbanner", "title", "string", "aux_text", "auxtext" }
    local SUB_BUTTONS = { "InteractButton", "SecondaryInteractButton" }
    local SUB_TEXT = { "Text", "Label", "StyledTextElement" }

    local function patchCard(el)
        local n = 0
        for _, name in ipairs(CARD_TEXT) do
            if wrapInstance(field(el, name)) then n = n + 1 end
        end
        for _, bname in ipairs(SUB_BUTTONS) do
            local b = field(el, bname)
            if b then
                if wrapInstance(b) then n = n + 1 end
                for _, tname in ipairs(SUB_TEXT) do
                    if wrapInstance(field(b, tname)) then n = n + 1 end
                end
            end
        end
        return n
    end

    local function patchButton(el)
        local n = 0
        for _, name in ipairs(BUTTON_TEXT) do
            if wrapInstance(field(el, name)) then n = n + 1 end
        end
        return n
    end

    local function patchBuilt(el)
        if type(el) ~= "table" and type(el) ~= "userdata" then return end
        local n = 0
        if field(el, "header") and field(el, "itemtype") and field(el, "InteractButton") then
            n = patchCard(el)
        elseif field(el, "buttoncallout") and field(el, "icontext") and field(el, "warningbanner") then
            n = patchButton(el) + wrapChildren(el)
        elseif field(el, "StyledTextElement") and field(el, "PromptButton") then
            n = wrapInstance(field(el, "StyledTextElement")) and 1 or 0
        end
    end

    function S.hookBuilder()
        local MB = rawget(_G, "MenuBuilder")
        if type(MB) ~= "table" then return false end
        local did = false
        for _, e in ipairs(P.fns(MB, "BuildRegisteredType")) do
            if not S.hooked[e.fn] then
                local original = e.fn
                local wrapper = function(...)
                    local el = original(...)
                    if S.enabled and el ~= nil then pcall(patchBuilt, el) end
                    return el
                end
                S.hooked[wrapper] = true
                S.hooked[original] = true
                if pcall(function() MB[e.key] = wrapper end) then did = true end
            end
        end
        return did
    end

    local function install()
        local L = rawget(_G, "LUI")
        local any = false
        if type(L) == "table" then
            for _, cname in ipairs({ "UIStyledText", "UIText" }) do
                local class = P.get(L, cname)
                if class then
                    if wrapText(class) then any = true end
                    wrapNew(class)
                end
            end
        end

        local trim = rawget(_G, "RemoveLeadingAndTrailingWhitespace")
        if type(trim) == "function" and not S.hooked[trim] then
            local wrapper = function(...)
                local r = trim(...)
                if S.enabled then return fix(r) end
                return r
            end
            S.hooked[wrapper] = true
            S.hooked[trim] = true
            rawset(_G, "RemoveLeadingAndTrailingWhitespace", wrapper)
            any = true
        end

        local fn = rawget(_G, "LocalizeIntoString")
        if type(fn) == "function" and not S.hooked[fn] then
            local wrapper = function(...)
                local r = fn(...)
                if S.enabled then return fix(r) end
                return r
            end
            S.hooked[wrapper] = true
            S.hooked[fn] = true
            rawset(_G, "LocalizeIntoString", wrapper)
            any = true
        end

        local E = rawget(_G, "Engine")
        if type(E) == "table" then
            for _, e in ipairs(P.fns(E, "Localize")) do
                if not S.hooked[e.fn] then
                    local original = e.fn
                    local wrapper = function(...)
                        local r = original(...)
                        if S.enabled then return fix(r) end
                        return r
                    end
                    S.hooked[wrapper] = true
                    S.hooked[original] = true
                    if pcall(function() E[e.key] = wrapper end) then any = true end
                end
            end
        end

        if S.hookBuilder() then any = true end

        return any
    end

    pcall(install)
    P.later(function()
        if not S.enabled then return true end
        pcall(install)
        return false
    end, 10, 600)
end)

run("RelicText", function()
    -- Relic names/descriptions come straight from script-bundle data, not through Engine.Localize,
    -- so TextTweaks never sees them. Patch them where they are read.
    local DESC_FROM = "No starting Armor. Only armor available is gold armor from the wall buy."
    local DESC_TO = "The Wunderfizz is disabled."

    local function loose(text)
        local out = {}
        for i = 1, #text do
            local c = string.sub(text, i, i)
            if string.match(c, "%s") then
                out[#out + 1] = "%s+"
            elseif string.match(c, "%a") then
                out[#out + 1] = "[" .. string.lower(c) .. string.upper(c) .. "]"
            elseif string.match(c, "%p") then
                out[#out + 1] = "%" .. c
            else
                out[#out + 1] = c
            end
        end
        return table.concat(out)
    end

    local DESC_PAT = loose(DESC_FROM)
    local NAME_PAT = loose("Mannequin Turret")

    local function swap(s)
        if type(s) ~= "string" or s == "" then return s end
        local ok, r = pcall(string.gsub, s, DESC_PAT, DESC_TO)
        if ok and type(r) == "string" then s = r end
        ok, r = pcall(string.gsub, s, NAME_PAT, function(w)
            if w == string.upper(w) then return "MANNEQUIN TURBINE" end
            if w == string.lower(w) then return "mannequin turbine" end
            return "Mannequin Turbine"
        end)
        if ok and type(r) == "string" then s = r end
        return s
    end

    local old = rawget(_G, "RelicText")
    if old then old.enabled = false end
    local S = { enabled = true, hooked = {} }
    rawset(_G, "RelicText", S)

    local function patchBundle(b)
        if type(b) ~= "table" then return end
        local ok, d = pcall(function() return b.description end)
        if ok and type(d) == "string" then
            local n = swap(d)
            if n ~= d then pcall(function() b.description = n end) end
        end
    end

    -- Every call below uses plain identifiers so the game compiles them to its own keys.
    local function install()
        local did = false

        if type(Engine) == "table" then
            local ok, orig = pcall(function() return Engine.GetScriptBundle end)
            if ok and type(orig) == "function" and not S.hooked[orig] then
                local w = function(...)
                    local r = orig(...)
                    if S.enabled then patchBundle(r) end
                    return r
                end
                S.hooked[w] = true
                S.hooked[orig] = true
                if pcall(function() Engine.GetScriptBundle = w end) then did = true end
            end
        end

        if type(LOOT) == "table" then
            local ok1, o1 = pcall(function() return LOOT.getitemdescriptionforbundle end)
            if ok1 and type(o1) == "function" and not S.hooked[o1] then
                local w = function(...)
                    local r = o1(...)
                    if S.enabled then return swap(r) end
                    return r
                end
                S.hooked[w] = true
                S.hooked[o1] = true
                if pcall(function() LOOT.getitemdescriptionforbundle = w end) then did = true end
            end

            local ok2, o2 = pcall(function() return LOOT.getdisplaynameforbundle end)
            if ok2 and type(o2) == "function" and not S.hooked[o2] then
                local w = function(...)
                    local r = o2(...)
                    if S.enabled then return swap(r) end
                    return r
                end
                S.hooked[w] = true
                S.hooked[o2] = true
                if pcall(function() LOOT.getdisplaynameforbundle = w end) then did = true end
            end
        end

        return did
    end

    pcall(install)

    local P = rawget(_G, "PostKeys")
    if P and P.later then
        P.later(function()
            if not S.enabled then return true end
            pcall(install)
            return false
        end, 10, 600)
    end
end)
