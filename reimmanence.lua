addon.name    = 'reimmanence'
addon.author  = 'you'
addon.version = '2.3.2'
addon.desc    = 'Scholar helper: Immanence skillchain combos that run themselves, with game-state timing, safety stops and a Genbu II (Vana\'diel day) window.'
addon.link    = ''

require('common')
local chat  = require('chat')
local imgui = require('imgui')
local theme = require('theme')
require('aurora')(theme)
theme.persist_scale('reimmanence')

----------------------------------------------------------------------
-- Timing (seconds) - edit these to taste
----------------------------------------------------------------------
-- fixed mode (/sch timing fixed): the old blind timer
local IMMANENCE_WAIT = 2   -- after using Immanence, wait this long before casting
local SPELL_WAIT     = 4   -- after casting a normal spell, wait this long before the next Immanence
local HELIX_WAIT     = 6   -- same, but after a helix spell (Luminohelix/Noctohelix cast slower)
local ANNOUNCE_DELAY = 0   -- extra wait after the last spell before "GO MAGIC BURST"
-- smart mode (default): every step waits for what the game actually does
local IMM_BUFF      = 470  -- status effect id of Immanence (/sch buff <id> changes it if it is wrong)
local IMM_MIN       = 1.0  -- seconds the Immanence buff must have been up before the spell is sent
local IMM_TIMEOUT   = 7    -- Immanence did not show up after this long: no charge / on recast / Amnesia
local IMM_RETRY     = 2.0  -- the /ja is sent again every this many seconds while the buff has not appeared (max IMM_TRIES sends)
local IMM_TRIES     = 3
local SETTLE        = 1.2  -- pause after a spell lands before the next Immanence
local CAST_MARGIN   = 6    -- seconds on top of the spell's cast time before "the spell did not go off"
local RECAST_MAX    = 20   -- refuse to wait for a spell recast longer than this
local MAX_STEPS     = 5

----------------------------------------------------------------------
-- Skillchain data (from Ivaar's Skillchains addon)
-- chain[first][second] = { level, result }
----------------------------------------------------------------------
local chain = {
    Light         = { Light = {4,'Light'} },
    Darkness      = { Darkness = {4,'Darkness'} },
    Gravitation   = { Distortion = {3,'Darkness'}, Fragmentation = {2,'Fragmentation'} },
    Fragmentation = { Fusion = {3,'Light'}, Distortion = {2,'Distortion'} },
    Distortion    = { Gravitation = {3,'Darkness'}, Fusion = {2,'Fusion'} },
    Fusion        = { Fragmentation = {3,'Light'}, Gravitation = {2,'Gravitation'} },
    Compression   = { Transfixion = {1,'Transfixion'}, Detonation = {1,'Detonation'} },
    Liquefaction  = { Impaction = {2,'Fusion'}, Scission = {1,'Scission'} },
    Induration    = { Reverberation = {2,'Fragmentation'}, Compression = {1,'Compression'}, Impaction = {1,'Impaction'} },
    Reverberation = { Induration = {1,'Induration'}, Impaction = {1,'Impaction'} },
    Transfixion   = { Scission = {2,'Distortion'}, Reverberation = {1,'Reverberation'}, Compression = {1,'Compression'} },
    Scission      = { Liquefaction = {1,'Liquefaction'}, Reverberation = {1,'Reverberation'}, Detonation = {1,'Detonation'} },
    Detonation    = { Compression = {2,'Gravitation'}, Scission = {1,'Scission'} },
    Impaction     = { Liquefaction = {1,'Liquefaction'}, Detonation = {1,'Detonation'} },
}

-- Elements each skillchain can be magic-burst with
local elements = {
    Light         = { 'Fire', 'Wind', 'Lightning', 'Light' },
    Darkness      = { 'Earth', 'Ice', 'Water', 'Dark' },
    Gravitation   = { 'Earth', 'Dark' },
    Fragmentation = { 'Wind', 'Lightning' },
    Distortion    = { 'Ice', 'Water' },
    Fusion        = { 'Fire', 'Light' },
    Compression   = { 'Dark' },
    Liquefaction  = { 'Fire' },
    Induration    = { 'Ice' },
    Reverberation = { 'Water' },
    Transfixion   = { 'Light' },
    Scission      = { 'Earth' },
    Detonation    = { 'Wind' },
    Impaction     = { 'Lightning' },
}

local colors = {
    Light         = { 1.00, 1.00, 0.70, 1 },
    Darkness      = { 0.75, 0.55, 1.00, 1 },
    Gravitation   = { 0.70, 0.50, 0.30, 1 },
    Fragmentation = { 0.98, 0.61, 0.97, 1 },
    Distortion    = { 0.20, 0.60, 1.00, 1 },
    Fusion        = { 1.00, 0.40, 0.40, 1 },
    Compression   = { 0.60, 0.45, 0.85, 1 },
    Liquefaction  = { 1.00, 0.30, 0.20, 1 },
    Induration    = { 0.40, 1.00, 1.00, 1 },
    Reverberation = { 0.35, 0.45, 1.00, 1 },
    Transfixion   = { 0.95, 0.95, 0.95, 1 },
    Scission      = { 0.85, 0.55, 0.20, 1 },
    Detonation    = { 0.40, 1.00, 0.40, 1 },
    Impaction     = { 1.00, 0.40, 1.00, 1 },
}

local COL_HEAD = theme.C.gold
local COL_DIM  = theme.C.muted
local COL_GO   = theme.C.green

local function check(old, new)
    for k = 1, #old do
        local combo = chain[old[k]]
        if combo then
            for i = 1, #new do
                local r = combo[new[i]]
                if r then return r[1], r[2] end
            end
        end
    end
    return nil
end

----------------------------------------------------------------------
-- Immanence spells and the property each one gives
----------------------------------------------------------------------
local spells = {
    { name = 'Fire',        el = 'Fire',      prop = 'Liquefaction'  },
    { name = 'Blizzard',    el = 'Ice',       prop = 'Induration'    },
    { name = 'Aero',        el = 'Wind',      prop = 'Detonation'    },
    { name = 'Stone',       el = 'Earth',     prop = 'Scission'      },
    { name = 'Thunder',     el = 'Lightning', prop = 'Impaction'     },
    { name = 'Water',       el = 'Water',     prop = 'Reverberation' },
    { name = 'Luminohelix', el = 'Light',     prop = 'Transfixion',  helix = true },
    { name = 'Noctohelix',  el = 'Dark',      prop = 'Compression',  helix = true },
}

local alias = {
    fire = 'Fire', ice = 'Ice', blizzard = 'Ice', wind = 'Wind', aero = 'Wind',
    earth = 'Earth', stone = 'Earth', lightning = 'Lightning', thunder = 'Lightning',
    water = 'Water', light = 'Light', luminohelix = 'Light',
    dark = 'Dark', darkness = 'Dark', noctohelix = 'Dark',
}

local numerals = { '', ' II', ' III', ' IV', ' V', ' VI' }
local tier = 1   -- which tier of each spell to actually cast (/sch tier <1-6>); helixes cap at II
local timing = 'smart'   -- 'smart' (watch the game) or 'fixed' (old timers)

local function spell_cast_name(sp)
    local t = tier
    if sp.helix then t = math.min(t, 2) end
    return sp.name .. numerals[t]
end

local function has_element(result, elem)
    for _, e in ipairs(elements[result] or {}) do
        if e == elem then return true end
    end
    return false
end

local function search(elem, steps)
    local results, seq = {}, {}
    local function dfs(step, active)
        for _, sp in ipairs(spells) do
            local lv, res = check(active, { sp.prop })
            if res then
                seq[step] = sp
                if step == steps then
                    if has_element(res, elem) then
                        local list, names = {}, {}
                        for i = 1, steps do list[i] = seq[i] names[i] = seq[i].name end
                        results[#results + 1] = {
                            spells = list, res = res, lv = lv,
                            key = table.concat(names, '>') .. '=' .. res,
                        }
                    end
                elseif lv ~= 4 then
                    dfs(step + 1, { res })
                end
            end
        end
    end
    for _, sp in ipairs(spells) do
        seq[1] = sp
        dfs(2, { sp.prop })
    end
    table.sort(results, function(a, b)
        if a.lv ~= b.lv then return a.lv < b.lv end
        return a.key < b.key
    end)
    return results
end

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------
local function say(msg)
    print(chat.header(addon.name):append(chat.message(msg)))
end

local function queue(cmd)
    AshitaCore:GetChatManager():QueueCommand(1, cmd)
end

local detect = nil   -- /sch detect: watching for the status effect Immanence adds
local state = nil    -- { element=, steps=, results={} }
local run   = nil    -- the running sequence (see start_combo)
local stopped = nil  -- { text=, t= }  why the last sequence was stopped, shown in the windows

----------------------------------------------------------------------
-- Reading the game: buffs, spells, MP, recast
----------------------------------------------------------------------
local function mm() return AshitaCore:GetMemoryManager() end

-- set of status effect ids on you, or nil when they cannot be read
local function player_buffs()
    local ok, set = pcall(function()
        local b = mm():GetPlayer():GetBuffs()
        local s = {}
        for _, id in pairs(b) do
            if type(id) == 'number' and id > 0 and id < 0xFFFF then s[id] = true end
        end
        return s
    end)
    if ok then return set end
    return nil
end

local spell_cache = {}
local function spell_res(name)                 -- { id, mp, cast (1/4 s) } or nil
    local c = spell_cache[name]
    if c ~= nil then return c or nil end
    local ok, r = pcall(function()
        local s = AshitaCore:GetResourceManager():GetSpellByName(name, 0)
        if s then return { id = s.Index, mp = s.ManaCost, cast = s.CastTime } end
        return nil
    end)
    spell_cache[name] = (ok and r) or false
    return (ok and r) or nil
end

local function has_spell(id)
    local ok, r = pcall(function() return mm():GetPlayer():HasSpell(id) end)
    return ok and r == true
end

local function spell_recast(id)                -- seconds left
    local ok, t = pcall(function() return mm():GetRecast():GetSpellTimer(id) end)
    if ok and type(t) == 'number' then return t / 60 end
    return 0
end

local function own_mp()
    local ok, v = pcall(function() return mm():GetParty():GetMemberMP(0) end)
    return ok and v or nil
end

-- readable list of the status effect ids you have right now
local function buff_text()
    local b = player_buffs()
    if not b then return '(cannot read status effects)' end
    local t = {}
    for id in pairs(b) do if id ~= 255 then t[#t + 1] = id end end
    table.sort(t)
    return #t > 0 and table.concat(t, ', ') or '(none)'
end

-- Immanence's status effect id is remembered between sessions (it is the one thing that can differ per server)
local function settings_dir() return ('%sconfig\\addons\\reimmanence\\'):format(AshitaCore:GetInstallPath()) end
local function save_settings()
    pcall(function()
        ashita.fs.create_dir(settings_dir())
        local f = io.open(settings_dir() .. 'settings.cfg', 'w')
        if f then f:write(('return { imm_buff = %d }\n'):format(IMM_BUFF)) f:close() end
    end)
end
local settings_loaded = false
local function load_settings()
    if settings_loaded then return end
    settings_loaded = true
    pcall(function()
        local chunk = loadfile(settings_dir() .. 'settings.cfg')
        local t = chunk and chunk()
        if type(t) == 'table' and type(t.imm_buff) == 'number' and t.imm_buff >= 1 and t.imm_buff < 1024 then
            IMM_BUFF = math.floor(t.imm_buff)
        end
    end)
end

local function own_zone()
    local ok, v = pcall(function() return mm():GetParty():GetMemberZone(0) end)
    return ok and v or nil
end

local function target_index()
    local ok, v = pcall(function() return mm():GetTarget():GetTargetIndex(0) end)
    return ok and v or 0
end

----------------------------------------------------------------------
-- Vana'diel day (used by the Genbu II window and the safety stop)
----------------------------------------------------------------------
local DAYS = {
    { name = 'Firesday',     el = 'Fire' },      { name = 'Earthsday', el = 'Earth' },
    { name = 'Watersday',    el = 'Water' },     { name = 'Windsday',  el = 'Wind' },
    { name = 'Iceday',       el = 'Ice' },       { name = 'Lightningday', el = 'Lightning' },
    { name = 'Lightsday',    el = 'Light' },     { name = 'Darksday',  el = 'Dark' },
}

-- Vana'diel time runs 25x real time from 2002-01-01 00:00 JST (unix 1009810800); the week has 8 days.
local function vana_day_index()
    local vt = (os.time() - 1009810800) * 25
    return math.floor(vt / 86400) % 8 + 1
end

local function vana_day_seconds_left()          -- real seconds until the next Vana'diel day
    local vt = (os.time() - 1009810800) * 25
    return (86400 - (vt % 86400)) / 25
end

----------------------------------------------------------------------
-- Sequence builder / runner
--   /p <element> skillchain starting
--   smart : Immanence -> wait until the buff is up -> spell -> wait until the buff is used up (spell landed)
--           -> next Immanence ... -> /p GO MAGIC BURST
--   fixed : the same commands on blind timers
----------------------------------------------------------------------
local function build_events(elem, combo, burst)
    local ev, plain = {}, {}
    for i, sp in ipairs(combo.spells) do plain[i] = sp.name end

    ev[#ev + 1] = { t = 0, cmd = ('/p %s skillchain starting (%s)'):format(elem, table.concat(plain, ' > ')),
                    desc = 'Announce' }

    local last = 0
    local base = 0
    for i, sp in ipairs(combo.spells) do
        ev[#ev + 1] = { t = base, cmd = '/ja "Immanence" <me>', desc = 'Immanence' }
        last = base + IMMANENCE_WAIT
        ev[#ev + 1] = { t = last, cmd = ('/ma "%s" <t>'):format(spell_cast_name(sp)),
                        desc = 'Cast ' .. spell_cast_name(sp) }
        base = last + (sp.helix and HELIX_WAIT or SPELL_WAIT)
    end

    ev[#ev + 1] = { t = last + ANNOUNCE_DELAY, cmd = ('/p GO MAGIC BURST (%s)'):format(burst or elem),
                    desc = 'Announce burst' }
    return ev
end

local function abort(reason)
    stopped = { text = reason, t = os.clock() }
    run = nil
    say('Stopped: ' .. reason)
end

-- status effects that make the rest of the sequence pointless
local BAD_STATUS = { [2] = 'asleep', [19] = 'asleep', [6] = 'silenced', [7] = 'petrified', [10] = 'stunned',
                     [16] = 'under Amnesia', [28] = 'terrorized' }

-- Checked every frame while a sequence runs. Returns the reason to stop, or nil.
local function safety()
    local ok, why = pcall(function()
        local m = mm()
        local party = m:GetParty()
        if party:GetMemberIsActive(0) ~= 1 then return 'you are not logged in' end
        if run.zone and party:GetMemberZone(0) ~= run.zone then return 'you zoned' end
        if party:GetMemberHP(0) <= 0 then return 'you are down' end
        if run.day and vana_day_index() ~= run.day then return "the Vana'diel day changed" end
        if run.target then
            if m:GetTarget():GetTargetIndex(0) ~= run.target then return 'the target changed or was lost' end
            local ent = m:GetEntity()
            local st = ent:GetStatus(run.target)
            if ent:GetHPPercent(run.target) <= 0 or st == 2 or st == 3 then return 'the target died' end
        end
        local b = player_buffs()
        if b then
            for id, what in pairs(BAD_STATUS) do
                if b[id] then return 'you are ' .. what end
            end
        end
        return nil
    end)
    if ok then return why end
    return nil
end

-- Before anything is sent: right job, a target, you know every spell, enough MP for all of them
----------------------------------------------------------------------
-- Stratagem charges (Immanence costs one). Same estimate the Windower/Gearswap Scholar scripts use:
--   max charges = floor((SCH level + 10) / 20),  charges = floor(max - max * recast / 240 s)
-- The stratagem recast is ability recast id 231. Returns charges, max (or nil when it cannot be read).
----------------------------------------------------------------------
local function strat_charges()
    local ok, cur, max = pcall(function()
        local p = mm():GetPlayer()
        local lv
        if p:GetMainJob() == 20 then lv = p:GetMainJobLevel()
        elseif p:GetSubJob() == 20 then lv = p:GetSubJobLevel() end
        if not lv or lv < 10 then return nil end
        local mx = math.floor((lv + 10) / 20)
        local rc = mm():GetRecast()
        local timer = 0
        for i = 0, 31 do
            if rc:GetAbilityTimerId(i) == 231 then timer = rc:GetAbilityTimer(i) / 60 break end
        end
        local cur = math.floor(mx - mx * timer / 240 + 0.0001)
        return math.max(0, math.min(mx, cur)), mx
    end)
    if ok and cur then return cur, max end
    return nil
end

-- big, easy-to-see readout under the window title
local function draw_charges(needed)
    local cur, max = strat_charges()
    imgui.SetWindowFontScale(0.8 * theme.ui_scale)
    imgui.TextColored(COL_DIM, 'IMMANENCE CHARGES')
    imgui.SetWindowFontScale(1.7 * theme.ui_scale)
    if not cur then
        imgui.TextColored(COL_DIM, '?')
    else
        local col = (cur == 0 and theme.C.red) or ((needed and cur < needed) and theme.C.amber) or theme.C.green
        imgui.TextColored(col, ('%d / %d'):format(cur, max))
        imgui.SameLine(0, 14)
        -- magic orbs: a glowing, highlighted sphere per charge, a faint empty ring per spent one
        local th = imgui.GetTextLineHeight()
        local r = math.max(5, th * 0.36)
        local gap = r * 0.9
        local total_w = max * (2 * r) + (max - 1) * gap
        local ok = pcall(function()
            local dl = imgui.GetWindowDrawList()
            local a1, a2 = imgui.GetCursorScreenPos()
            local x0, y0
            if type(a1) == 'table' then x0, y0 = a1.x or a1[1], a1.y or a1[2] else x0, y0 = a1, a2 end
            local cy = y0 + th * 0.5
            for i = 1, max do
                local cx = x0 + r + (i - 1) * (2 * r + gap)
                if i <= cur then
                    dl:AddCircleFilled({ cx, cy }, r * 1.45, imgui.GetColorU32({ col[1], col[2], col[3], 0.10 }), 24)   -- glow
                    dl:AddCircleFilled({ cx, cy }, r * 1.18, imgui.GetColorU32({ col[1], col[2], col[3], 0.18 }), 24)
                    dl:AddCircleFilled({ cx, cy }, r, imgui.GetColorU32({ col[1] * 0.55, col[2] * 0.55, col[3] * 0.55, 1 }), 24) -- body (darker rim)
                    dl:AddCircleFilled({ cx, cy }, r * 0.78, imgui.GetColorU32({ col[1], col[2], col[3], 1 }), 24)
                    dl:AddCircleFilled({ cx - r * 0.30, cy - r * 0.32 }, r * 0.30, imgui.GetColorU32({ 1, 1, 1, 0.75 }), 12)   -- shine
                else
                    dl:AddCircleFilled({ cx, cy }, r, imgui.GetColorU32({ 1, 1, 1, 0.04 }), 24)
                    dl:AddCircle({ cx, cy }, r, imgui.GetColorU32({ col[1], col[2], col[3], 0.30 }), 24, 1.5)
                end
            end
        end)
        if ok then
            imgui.Dummy({ total_w, th })
        else
            for i = 1, max do
                if i > 1 then imgui.SameLine(0, 3) end
                imgui.TextColored(i <= cur and col or COL_DIM, i <= cur and '(O)' or '( )')
            end
        end
    end
    imgui.SetWindowFontScale(theme.ui_scale)
end

local function preflight(combo)
    local ok, main, sub = pcall(function()
        local p = mm():GetPlayer()
        return p:GetMainJob(), p:GetSubJob()
    end)
    if ok and main ~= 20 and sub ~= 20 then
        say('You are not on Scholar (main or sub) - Immanence is unavailable.')
        return false
    end
    if target_index() == 0 then
        say('Target the enemy first.')
        return false
    end
    local ch = strat_charges()
    if ch and ch < #combo.spells then
        say(('Careful: about %d Immanence charge(s) available, this chain needs %d.'):format(ch, #combo.spells))
    end
    local total = 0
    for _, sp in ipairs(combo.spells) do
        local name = spell_cast_name(sp)
        local info = spell_res(name)
        if info then
            if not has_spell(info.id) then
                say(('You have not learned %s.'):format(name))
                return false
            end
            total = total + (info.mp or 0)
        end
    end
    local mp = own_mp()
    if mp and total > 0 and mp < total then
        say(('Not enough MP for the whole chain: need %d, have %d.'):format(total, mp))
        return false
    end
    return true
end

local function start_combo(combo, announce, burst, day)
    if run then say('A sequence is already running (/sch stop to cancel).') return end
    if not preflight(combo) then return end
    stopped = nil
    local mode = timing
    if mode == 'smart' and not player_buffs() then
        say("Can't read your status effects - using fixed timing for this run.")
        mode = 'fixed'
    end
    run = { mode = mode, combo = combo, announce = announce, burst = burst, day = day,
            target = target_index(), zone = own_zone(), t0 = os.clock(), desc = '', phase = 'announce', i = 1 }
    if mode == 'fixed' then
        run.events = build_events(announce, combo, burst)
        run.idx = 1
    end
end

local function start_run(i)
    if not state or not state.results[i] then say('No such combination.') return end
    start_combo(state.results[i], state.element, nil, nil)
end

local function step_fixed(now)
    local elapsed = now - run.t0
    while run and run.idx <= #run.events and elapsed >= run.events[run.idx].t do
        queue(run.events[run.idx].cmd)
        run.idx = run.idx + 1
    end
    if run and run.idx > #run.events then run = nil end
    if run then
        local ev = run.events[run.idx]
        run.desc = ev and ('Next: %s in %.1fs'):format(ev.desc, math.max(0, ev.t - elapsed)) or ''
    end
end

local function step_smart(now)
    local combo = run.combo
    local n = #combo.spells
    local sp = combo.spells[run.i]
    local name = spell_cast_name(sp)

    if run.phase == 'announce' then
        local plain = {}
        for i, s in ipairs(combo.spells) do plain[i] = s.name end
        queue(('/p %s skillchain starting (%s)'):format(run.announce, table.concat(plain, ' > ')))
        run.phase, run.not_before = 'imm_send', now

    elseif run.phase == 'imm_send' then
        if now < run.not_before then return end
        local info = spell_res(name)
        if info then
            local mp = own_mp()
            if mp and info.mp and mp < info.mp then abort(('not enough MP for %s (need %d, have %d)'):format(name, info.mp, mp)) return end
            local rc = spell_recast(info.id)
            if rc > 0.2 then
                if rc > RECAST_MAX then abort(('%s is on recast (%.0fs)'):format(name, rc)) return end
                run.desc = ('Waiting for %s recast (%.0fs)'):format(name, rc)
                return
            end
        end
        local b = player_buffs() or {}
        run.sent, run.t_sent = 0, now
        if not b[IMM_BUFF] then
            queue('/ja "Immanence" <me>')                              -- already up from before: just use it
            run.sent = 1
        end
        run.phase, run.t0, run.seen = 'imm_wait', now, nil
        run.desc = ('Immanence (%d/%d)'):format(run.i, n)

    elseif run.phase == 'imm_wait' then
        local b = player_buffs() or {}
        if b[IMM_BUFF] then
            run.seen = run.seen or now
            if now - run.seen >= IMM_MIN then
                queue(('/ma "%s" <t>'):format(name))
                local info = spell_res(name)
                run.cast_to = ((info and info.cast or 8) / 4) + CAST_MARGIN
                run.phase, run.t0 = 'cast_wait', now
                run.desc = ('Casting %s (%d/%d)'):format(name, run.i, n)
            end
        else
            -- the command can be swallowed (game busy right after a cast / chat line): send it again
            if (run.sent or 0) < IMM_TRIES and now - (run.t_sent or now) >= IMM_RETRY then
                queue('/ja "Immanence" <me>')
                run.sent, run.t_sent = (run.sent or 0) + 1, now
            end
            if now - run.t0 > IMM_TIMEOUT then
                local bb = player_buffs() or {}
                local arts = bb[358] or bb[359] or bb[401] or bb[402]
                abort(('Immanence did not activate (sent %d times). %sStatus effects now: %s. If you can use Immanence by hand, run /sch detect.')
                    :format(run.sent or 0, arts and '' or 'No Light/Dark Arts is active - stratagems need one. ', buff_text()))
            end
        end

    elseif run.phase == 'cast_wait' then
        local b = player_buffs() or {}
        if not b[IMM_BUFF] then                                  -- the buff is used up: the spell went off
            if run.i >= n then
                queue(('/p GO MAGIC BURST (%s)'):format(run.burst or run.announce))
                run = nil
            else
                run.i = run.i + 1
                run.phase, run.not_before = 'imm_send', now + SETTLE
                run.desc = 'Next spell...'
            end
        elseif now - run.t0 > run.cast_to then
            abort(('%s did not go off (interrupted, out of range, or silenced?)'):format(name))
        end
    end
end

local function step_run(now)
    local why = safety()
    if why then abort(why) return end
    if run.mode == 'fixed' then step_fixed(now) else step_smart(now) end
end

----------------------------------------------------------------------
-- Shared window pieces
----------------------------------------------------------------------
local win_open = { true }

local function draw_run_status(now)
    if not run then return end
    imgui.TextColored(COL_GO, 'Running...  ' .. (run.desc or ''))
    if theme.danger('Stop') then run = nil end
end

local function draw_stopped(now)
    if stopped and os.clock() - stopped.t < 20 then
        imgui.TextColored(theme.C.warn, 'Stopped: ' .. stopped.text)
    end
end

local function draw_row(i, r)
    if run then
        imgui.TextColored(COL_DIM, ('%d.'):format(i))
    else
        if theme.accent('Go##' .. i, { 40, 0 }, true) then start_run(i) end
    end
    imgui.SameLine()
    for k, sp in ipairs(r.spells) do
        if k > 1 then
            imgui.Text(' > ')
            imgui.SameLine(0, 0)
        end
        imgui.Text(spell_cast_name(sp))
        imgui.SameLine(0, 0)
    end
    imgui.Text(' = ')
    imgui.SameLine(0, 0)
    imgui.TextColored(colors[r.res] or { 1, 1, 1, 1 }, r.res)
    imgui.SameLine(0, 0)
    imgui.TextColored(COL_DIM, ('  Lv%d (%s)'):format(r.lv, table.concat(elements[r.res], '/')))
end

----------------------------------------------------------------------
-- GENBU II  (/sch genbu): chains for the current Vana'diel day that never use a spell, or trigger a
-- skillchain, of that day's element (2 spells per chain).
----------------------------------------------------------------------
local EL_COL = {
    Fire = { 1.00, 0.45, 0.35, 1 }, Ice = { 0.60, 0.88, 1.00, 1 }, Wind = { 0.50, 0.95, 0.60, 1 },
    Earth = { 0.85, 0.70, 0.40, 1 }, Lightning = { 0.85, 0.60, 1.00, 1 }, Water = { 0.40, 0.65, 1.00, 1 },
    Light = { 1.00, 0.97, 0.75, 1 }, Dark = { 0.70, 0.55, 0.90, 1 },
}
local EL_ORDER = { 'Fire', 'Earth', 'Water', 'Wind', 'Ice', 'Lightning', 'Light', 'Dark' }
local GENBU_MAX = 600

-- every chain of 2 Immanence spells that avoids day_el
local function genbu_search(day_el, maxsteps)
    local results, seq, capped = {}, {}, false
    local pool = {}
    for _, sp in ipairs(spells) do
        if sp.el ~= day_el then pool[#pool + 1] = sp end
    end
    local function dfs(step, active)
        for _, sp in ipairs(pool) do
            if capped then return end
            local lv, res = check(active, { sp.prop })
            if res and not has_element(res, day_el) then
                seq[step] = sp
                local list, names = {}, {}
                for i = 1, step do list[i] = seq[i] names[i] = seq[i].name end
                results[#results + 1] = { spells = list, res = res, lv = lv, n = step, key = table.concat(names, '>') }
                if #results >= GENBU_MAX then capped = true return end
                if step < maxsteps and lv ~= 4 then dfs(step + 1, { res }) end
            end
        end
    end
    for _, sp in ipairs(pool) do
        if capped then break end
        seq[1] = sp
        dfs(2, { sp.prop })
    end
    table.sort(results, function(a, b)
        if a.res ~= b.res then return a.res < b.res end
        if a.n ~= b.n then return a.n < b.n end
        return a.key < b.key
    end)
    return results, capped
end

-- the best burst spell you actually know for each element (highest tier), refreshed every few seconds
local NUKE_BASE = { Fire = 'Fire', Ice = 'Blizzard', Wind = 'Aero', Earth = 'Stone', Lightning = 'Thunder',
                    Water = 'Water', Light = 'Luminohelix', Dark = 'Noctohelix' }
local best_cache = { t = -10, by_el = {} }
local function best_burst(now)
    if now - best_cache.t < 3 then return best_cache.by_el end
    best_cache.t = now
    local out = {}
    for el, base in pairs(NUKE_BASE) do
        local top = (el == 'Light' or el == 'Dark') and 2 or 6
        for t = top, 1, -1 do
            local name = base .. numerals[t]
            local info = spell_res(name)
            if info and has_spell(info.id) then out[el] = name break end
        end
    end
    best_cache.by_el = out
    return out
end

local genbu = nil          -- { day = nil (today) | 1..8, filter = nil | element, sig, results, seen, changed }
local genbu_open = { true }

local function draw_genbu(now)
    if not genbu then return end
    local today = vana_day_index()

    -- day change: announce it, and keep following "today" unless a day was picked by hand
    if genbu.seen and genbu.seen ~= today then
        genbu.changed = { from = genbu.seen, to = today, t = now }
        say(("Vana'diel day changed: %s -> %s"):format(DAYS[genbu.seen].name, DAYS[today].name))
    end
    genbu.seen = today

    local di = genbu.day or today
    local day = DAYS[di]
    local sig = tostring(di)
    if genbu.sig ~= sig then
        genbu.sig = sig
        genbu.results, genbu.capped = genbu_search(day.el, 2)
    end

    imgui.SetNextWindowPos({ 340, 260 }, ImGuiCond_FirstUseEver)
    imgui.SetNextWindowSize({ 580, 460 }, ImGuiCond_FirstUseEver)
    genbu_open[1] = true
    local nc, nv = theme.push()
    if theme.begin('Reimmanence - Genbu II', genbu_open) then
        theme.header(genbu_open, 'GENBU', 'II', ('%s  -  never use %s spells or %s skillchains'):format(
            day.name, day.el:upper(), day.el:upper()))
        draw_charges(2)

        -- day banner: what day it is, when it ends, and whether the list matches it
        if genbu.changed and now - genbu.changed.t < 20 then
            imgui.TextColored(theme.C.gold, ("DAY CHANGED: %s -> %s  (the list below has been updated)"):format(
                DAYS[genbu.changed.from].name, DAYS[genbu.changed.to].name))
        end
        local left = vana_day_seconds_left()
        imgui.TextColored(left < 90 and theme.C.warn or COL_DIM,
            ("Today: %s  -  next day in %d:%02d"):format(DAYS[today].name, math.floor(left / 60), math.floor(left % 60)))
        if di ~= today then
            imgui.TextColored(theme.C.warn, ('This list is for %s, but today is %s - Go is disabled. Pick Today.'):format(
                day.name, DAYS[today].name))
        end

        if theme.toggle('Today', 'gToday', genbu.day == nil) then genbu.day = nil end
        for i, d in ipairs(DAYS) do
            imgui.SameLine()
            if theme.toggle(d.el .. (i == today and '*' or ''), 'gDay' .. i, di == i) then
                genbu.day = (i == today) and nil or i
            end
        end

        imgui.TextColored(COL_DIM, 'Burst:')
        imgui.SameLine()
        if theme.toggle('Any', 'gFAny', genbu.filter == nil) then genbu.filter = nil end
        for _, el in ipairs(EL_ORDER) do
            if el ~= day.el then
                imgui.SameLine()
                if theme.toggle(el, 'gF' .. el, genbu.filter == el) then genbu.filter = el end
            end
        end
        if genbu.filter == day.el then genbu.filter = nil end

        local bad = {}
        for prop in pairs(elements) do
            if has_element(prop, day.el) then bad[#bad + 1] = prop end
        end
        table.sort(bad)
        imgui.TextColored(COL_DIM, 'Skipped skillchains: ' .. table.concat(bad, ', '))

        draw_run_status(now)
        draw_stopped(now)
        imgui.Separator()

        local best = best_burst(now)
        local shown, last = 0, nil
        for i, r in ipairs(genbu.results) do
            if not genbu.filter or has_element(r.res, genbu.filter) then
                shown = shown + 1
                if r.res ~= last then
                    last = r.res
                    imgui.TextColored(colors[r.res] or { 1, 1, 1, 1 }, r.res:upper())
                    imgui.SameLine()
                    imgui.TextColored(COL_DIM, '  burst with:')
                    for _, el in ipairs(elements[r.res]) do
                        imgui.SameLine()
                        if best[el] then
                            imgui.TextColored(EL_COL[el] or COL_DIM, best[el])
                        else
                            imgui.TextColored(COL_DIM, el .. ': none known')
                        end
                    end
                end
                if run then
                    imgui.TextColored(COL_DIM, '  -')
                else
                    if theme.accent('Go##g' .. i, { 40, 0 }, di == today) then
                        if di ~= today then
                            say(("This list is for %s but today is %s - pick Today first."):format(day.name, DAYS[today].name))
                        else
                            start_combo(r, r.res, table.concat(elements[r.res], '/'), di)
                        end
                    end
                end
                imgui.SameLine()
                for k, sp in ipairs(r.spells) do
                    if k > 1 then
                        imgui.Text(' > ')
                        imgui.SameLine(0, 0)
                    end
                    imgui.TextColored(EL_COL[sp.el] or { 1, 1, 1, 1 }, spell_cast_name(sp))
                    imgui.SameLine(0, 0)
                end
                imgui.Text(' = ')
                imgui.SameLine(0, 0)
                imgui.TextColored(colors[r.res] or { 1, 1, 1, 1 }, r.res)
                imgui.SameLine(0, 0)
                imgui.TextColored(COL_DIM, ('  Lv%d'):format(r.lv))
            end
        end
        if shown == 0 then
            imgui.TextColored(COL_DIM, '(no combination found)')
        elseif genbu.capped then
            imgui.TextColored(COL_DIM, ('showing first %d chains (more exist)'):format(GENBU_MAX))
        end
    end
    theme.finish()
    theme.pop(nc, nv)
    if not genbu_open[1] then
        genbu = nil
        run = nil
    end
end

----------------------------------------------------------------------
-- Main window
----------------------------------------------------------------------
ashita.events.register('d3d_present', 'reimmanence_present', function()
    local now = os.clock()
    load_settings()
    if detect then
        local b = player_buffs() or {}
        local found = {}
        for id in pairs(b) do
            if id ~= 255 and not detect.before[id] then found[#found + 1] = id end
        end
        if #found == 1 then
            IMM_BUFF = found[1]
            save_settings()
            say(('detect: Immanence is status effect %d - saved.'):format(IMM_BUFF))
            detect = nil
        elseif #found > 1 then
            table.sort(found)
            say('detect: several new effects appeared (' .. table.concat(found, ', ') .. '). Wait until only Immanence is new and try again.')
            detect = nil
        elseif now > detect.t_end then
            say('detect: nothing new appeared - Immanence was not used.')
            detect = nil
        end
    end
    if run then step_run(now) end
    draw_genbu(now)
    if not state then return end

    imgui.SetNextWindowPos({ 300, 300 }, ImGuiCond_FirstUseEver)
    imgui.SetNextWindowSize({ 480, 280 }, ImGuiCond_FirstUseEver)
    win_open[1] = true
    local nc, nv = theme.push()
    if theme.begin('Reimmanence', win_open) then
        theme.header(win_open, 'REIMMANENCE', '', ('%s skillchain  -  %d spells  -  %s timing'):format(
            state.element, state.steps, timing))
        draw_charges(state.steps)
        imgui.TextColored(COL_DIM, 'Press Go to announce, run Immanence + the spells, and call the burst.')

        draw_run_status(now)
        draw_stopped(now)

        imgui.Separator()
        if #state.results == 0 then
            imgui.TextColored(COL_DIM, '(no combination found)')
        end
        for i, r in ipairs(state.results) do draw_row(i, r) end
    end
    theme.finish()
    theme.pop(nc, nv)
    if not win_open[1] then
        state = nil
        run = nil
    end
end)

----------------------------------------------------------------------
-- Commands
----------------------------------------------------------------------
local function help()
    say('/sch <element> [steps]  - list Immanence combos for that skillchain element, with a Go button.')
    say('   elements: fire ice wind earth lightning water light dark (aero, stone, etc. also work)')
    say("/sch genbu [element]  - GENBU II window: chains for today's Vana'diel day that avoid the day's element")
    say('/sch go <n>        run combination number n from the list')
    say('/sch stop          cancel a running sequence')
    say('/sch tier <1-6>    which spell tier to cast (default 1; helixes max out at II)')
    say('/sch timing smart|fixed   smart = wait for the game (default), fixed = old blind timers')
    say('/sch buff <id>     Immanence status effect id used by smart timing (default 470, remembered)')
    say('/sch detect        finds that id for you: run it, then use Immanence by hand   /sch buffs  lists your status effect ids')
    say('/sch off           close the windows')
    say('A run stops by itself if you zone, the target dies or changes, you are put out of action, MP runs short, or Immanence/a spell does not go off.')
end

ashita.events.register('command', 'reimmanence_command', function(e)
    local args = e.command:args()
    if #args == 0 then return end
    local c = args[1]:lower()
    if c ~= '/sch' and c ~= '/reim' then return end
    e.blocked = true

    local arg = args[2] and args[2]:lower() or ''

    if arg == '' or arg == 'help' then
        help()

    elseif arg == 'off' or arg == 'hide' or arg == 'close' then
        state = nil
        genbu = nil
        run = nil

    elseif arg == 'stop' or arg == 'cancel' then
        if run then run = nil say('Sequence cancelled.') else say('Nothing is running.') end

    elseif arg == 'tier' then
        local t = tonumber(args[3])
        if not t or t < 1 or t > 6 or t ~= math.floor(t) then
            say('Usage: /sch tier <1-6>')
            return
        end
        tier = t
        say(('Casting tier %d spells (helixes cap at II).'):format(tier))

    elseif arg == 'timing' then
        local v = args[3] and args[3]:lower() or ''
        if v ~= 'smart' and v ~= 'fixed' then say('Usage: /sch timing smart | fixed') return end
        timing = v
        say('Timing: ' .. v)

    elseif arg == 'buff' then
        local n = tonumber(args[3])
        if not n or n < 1 or n > 1023 then say('Usage: /sch buff <status effect id>  (Immanence is 470)') return end
        IMM_BUFF = math.floor(n)
        save_settings()
        say('Immanence status effect id: ' .. IMM_BUFF .. ' (saved)')

    elseif arg == 'buffs' then
        say(('Your status effect ids: %s'):format(buff_text()))
        say(('Immanence id in use: %d - %s'):format(IMM_BUFF, (player_buffs() or {})[IMM_BUFF] and 'you have it now' or 'not on you right now'))

    elseif arg == 'detect' then
        detect = { t_end = os.clock() + 20, before = player_buffs() or {} }
        say('detect: use Immanence by hand now (within 20 seconds).')

    elseif arg == 'go' then
        start_run(tonumber(args[3]) or 0)

    elseif arg == 'genbu' then
        local day = nil
        if args[3] then
            local el = alias[args[3]:lower()]
            if not el then say('Unknown element: ' .. args[3]) return end
            for i, d in ipairs(DAYS) do
                if d.el == el then day = i end
            end
        end
        genbu = { day = day, filter = nil, results = {} }

    else
        local elem = alias[arg]
        if not elem then say('Unknown element: ' .. args[2]) return end

        local steps = 2
        if args[3] then
            steps = tonumber(args[3])
            if not steps or steps < 2 or steps > MAX_STEPS then
                say(('Steps must be between 2 and %d.'):format(MAX_STEPS))
                return
            end
        end
        run = nil
        state = { element = elem, steps = steps, results = search(elem, steps) }
    end
end)
