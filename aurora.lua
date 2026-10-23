-- aurora.lua  -  "Aurora" skin + font-scale control for my Ashita v4 addons (ChainFinder, Reimmanence, Dual Chains, RoE Helper)
--
-- Deep ink panels, glass-edged buttons, an aurora (teal -> violet) accent, gradient titles and a glowing rule under the
-- header. It re-colours and re-shapes theme.lua for the addon that loads it (every addon has its own copy of both files).
--
-- Usage:   local theme = require('theme')
--          require('aurora')(theme)
--          theme.persist_scale('myaddon')      -- optional: remembers the font scale in config\addons\myaddon\ui.cfg
--          ... inside a window, as the LAST thing before theme.finish():   theme.scale_footer()
--          ... right after every imgui.BeginCombo / BeginChild:            theme.child_scale()
-- Delete the require line to go back to the classic gold theme.

local imgui = require('imgui')

local function lerp(a, b, t) return a + (b - a) * t end
local function mix(c1, c2, t, a)
    return { lerp(c1[1], c2[1], t), lerp(c1[2], c2[2], t), lerp(c1[3], c2[3], t), a or 1 }
end

return function(M)
    local C = M.C

    -- palette ----------------------------------------------------------------
    local TEAL   = { 0.27, 0.92, 0.80, 1.00 }
    local VIOLET = { 0.66, 0.50, 1.00, 1.00 }
    C.bg       = { 0.030, 0.038, 0.070, 0.965 }
    C.card     = { 0.058, 0.070, 0.118, 1.00 }
    C.frame    = { 0.078, 0.092, 0.150, 1.00 }
    C.frame_hi = { 0.115, 0.135, 0.215, 1.00 }
    C.border   = { 0.30, 0.85, 0.80, 0.20 }
    C.line     = { 0.45, 0.70, 1.00, 0.10 }
    C.gold     = TEAL                                   -- "accent" everywhere the base theme used gold
    C.gold_dim = { TEAL[1], TEAL[2], TEAL[3], 0.62 }
    C.gold_bg  = { TEAL[1], TEAL[2], TEAL[3], 0.95 }
    C.amber    = { 1.00, 0.78, 0.36, 1.00 }            -- the skill under the cursor / equipped spells
    C.violet   = VIOLET
    C.text     = { 0.89, 0.93, 0.99, 1.00 }
    C.muted    = { 0.47, 0.53, 0.68, 1.00 }
    C.green    = { 0.55, 0.95, 0.50, 1.00 }
    C.dark     = { 0.020, 0.030, 0.050, 1.00 }

    -- font scale persistence ---------------------------------------------------
    local scale_name, scale_loaded = nil, true
    local function scale_path()
        return ('%sconfig\\addons\\%s\\ui.cfg'):format(AshitaCore:GetInstallPath(), scale_name)
    end
    function M.persist_scale(name) scale_name, scale_loaded = name, false end
    local function save_scale()
        if not scale_name then return end
        pcall(function()
            ashita.fs.create_dir(('%sconfig\\addons\\%s\\'):format(AshitaCore:GetInstallPath(), scale_name))
            local f = io.open(scale_path(), 'w')
            if f then
                f:write(('return { scale = %d }\n'):format(math.floor(M.ui_scale * 100 + 0.5)))
                f:close()
            end
        end)
    end

    -- Font scale 25-150%, bottom right of the window. Drawn at 100% always so it never moves while you drag;
    -- the text rescales live and the setting is written once, when you let go.
    local dragging = false
    function M.scale_footer()
        imgui.SetWindowFontScale(1.0)
        local fh = 28
        local y = imgui.GetWindowHeight() - fh - 8
        if imgui.GetCursorPosY() < y then imgui.SetCursorPosY(y) end
        local sw = 130
        local total = M.text_w('Scale') + sw + M.btn_w('100%') + 24
        local x = imgui.GetWindowWidth() - total - 20
        if x > imgui.GetCursorPosX() then imgui.SetCursorPosX(x) end
        imgui.TextColored(C.muted, 'Scale')
        imgui.SameLine()
        imgui.SetNextItemWidth(sw)
        local v = { math.floor(M.ui_scale * 100 + 0.5) }
        if imgui.SliderInt('##aur_scale', v, 25, 150, '%d%%') then
            M.set_scale(v[1] / 100)
            dragging = true
        end
        if dragging and not imgui.IsItemActive() then
            dragging = false
            save_scale()
        end
        imgui.SameLine()
        if M.ghost('100%##aur_s100') then
            M.set_scale(1.0)
            save_scale()
        end
        imgui.SetWindowFontScale(M.ui_scale)
    end

    -- global style -----------------------------------------------------------
    local base_push_loaded = false
    function M.push()
        if not scale_loaded then
            scale_loaded = true
            pcall(function()
                local chunk = loadfile(scale_path())
                local t = chunk and chunk()
                if type(t) == 'table' and type(t.scale) == 'number' then
                    M.ui_scale = math.max(25, math.min(150, t.scale)) / 100
                end
            end)
        end
        local cols = {
            { ImGuiCol_WindowBg, C.bg }, { ImGuiCol_ChildBg, { 0, 0, 0, 0 } },
            { ImGuiCol_PopupBg, { 0.050, 0.060, 0.105, 0.99 } },
            { ImGuiCol_Border, C.border }, { ImGuiCol_Text, C.text }, { ImGuiCol_TextDisabled, C.muted },
            { ImGuiCol_FrameBg, C.frame }, { ImGuiCol_FrameBgHovered, C.frame_hi }, { ImGuiCol_FrameBgActive, C.frame_hi },
            { ImGuiCol_Button, C.frame }, { ImGuiCol_ButtonHovered, C.frame_hi }, { ImGuiCol_ButtonActive, C.frame_hi },
            { ImGuiCol_Header, { TEAL[1], TEAL[2], TEAL[3], 0.14 } }, { ImGuiCol_HeaderHovered, { TEAL[1], TEAL[2], TEAL[3], 0.10 } },
            { ImGuiCol_HeaderActive, { TEAL[1], TEAL[2], TEAL[3], 0.20 } },
            { ImGuiCol_SliderGrab, TEAL }, { ImGuiCol_SliderGrabActive, VIOLET }, { ImGuiCol_CheckMark, TEAL },
            { ImGuiCol_PlotHistogram, TEAL }, { ImGuiCol_Separator, C.line },
            { ImGuiCol_ScrollbarBg, { 0, 0, 0, 0 } }, { ImGuiCol_ScrollbarGrab, { TEAL[1], TEAL[2], TEAL[3], 0.22 } },
            { ImGuiCol_ScrollbarGrabHovered, { TEAL[1], TEAL[2], TEAL[3], 0.40 } },
            { ImGuiCol_ScrollbarGrabActive, { VIOLET[1], VIOLET[2], VIOLET[3], 0.60 } },
            { ImGuiCol_TableRowBg, { 0, 0, 0, 0 } },
        }
        for _, c in ipairs(cols) do imgui.PushStyleColor(c[1], c[2]) end
        local vars = {
            { ImGuiStyleVar_WindowRounding, 16 }, { ImGuiStyleVar_ChildRounding, 10 }, { ImGuiStyleVar_FrameRounding, 10 },
            { ImGuiStyleVar_GrabRounding, 10 }, { ImGuiStyleVar_PopupRounding, 10 }, { ImGuiStyleVar_ScrollbarRounding, 10 },
            { ImGuiStyleVar_WindowPadding, { 18, 16 } }, { ImGuiStyleVar_FramePadding, { 11, 6 } },
            { ImGuiStyleVar_ItemSpacing, { 8, 8 } }, { ImGuiStyleVar_WindowBorderSize, 1 }, { ImGuiStyleVar_ScrollbarSize, 7 },
        }
        for _, v in ipairs(vars) do imgui.PushStyleVar(v[1], v[2]) end
        return #cols, #vars
    end

    -- toggles: solid aurora pill when on, glass pill with a faint teal edge when off ----------
    function M.toggle(label, id, selected, size)
        local text = label .. '##' .. id
        if selected then
            imgui.PushStyleColor(ImGuiCol_Button, C.gold_bg)
            imgui.PushStyleColor(ImGuiCol_ButtonHovered, { 0.45, 1.00, 0.90, 1 })
            imgui.PushStyleColor(ImGuiCol_ButtonActive, VIOLET)
            imgui.PushStyleColor(ImGuiCol_Text, C.dark)
            local hit = M._button(text, size)
            imgui.PopStyleColor(4)
            return hit
        end
        imgui.PushStyleColor(ImGuiCol_Button, { 1, 1, 1, 0.03 })
        imgui.PushStyleColor(ImGuiCol_ButtonHovered, { TEAL[1], TEAL[2], TEAL[3], 0.14 })
        imgui.PushStyleColor(ImGuiCol_ButtonActive, { VIOLET[1], VIOLET[2], VIOLET[3], 0.30 })
        imgui.PushStyleColor(ImGuiCol_Text, { C.text[1], C.text[2], C.text[3], 0.80 })
        imgui.PushStyleColor(ImGuiCol_Border, { TEAL[1], TEAL[2], TEAL[3], 0.22 })
        imgui.PushStyleVar(ImGuiStyleVar_FrameBorderSize, 1)
        local hit = M._button(text, size)
        imgui.PopStyleVar(1)
        imgui.PopStyleColor(5)
        return hit
    end

    -- header -------------------------------------------------------------------
    -- gradient text: every letter is a step on the teal -> violet ramp
    local function grad_text(text, scale)
        imgui.SetWindowFontScale(scale * M.ui_scale)
        local n = #text
        for i = 1, n do
            local ch = text:sub(i, i)
            local col = mix(TEAL, VIOLET, (n > 1) and ((i - 1) / (n - 1)) or 0)
            if i > 1 then imgui.SameLine(0, 1) end
            imgui.TextColored(col, ch)
        end
        imgui.SetWindowFontScale(M.ui_scale)
    end

    -- a glowing rule: teal fading through violet to nothing. Falls back to a plain separator if the draw list
    -- binding is not what I expect.
    local function glow_rule()
        local ok = pcall(function()
            local dl = imgui.GetWindowDrawList()
            local a, b = imgui.GetCursorScreenPos()
            local x, y
            if type(a) == 'table' then x, y = a.x or a[1], a.y or a[2] else x, y = a, b end
            local w = imgui.GetWindowWidth() - imgui.GetCursorPosX() * 2
            local segs = 36
            local sw = w / segs
            for i = 0, segs - 1 do
                local t = i / (segs - 1)
                local col = mix(TEAL, VIOLET, t, 0.85 * (1 - t * t) + 0.06)
                dl:AddRectFilled({ x + i * sw, y }, { x + (i + 1) * sw + 1, y + 2 }, imgui.GetColorU32(col))
            end
        end)
        if ok then
            imgui.Dummy({ 1, 5 })
        else
            imgui.Separator()
        end
    end

    function M.header(open, a, b, sub, mini)
        local mini_hit = false
        local pad_x = imgui.GetCursorPosX()
        local y0 = imgui.GetCursorPosY()
        if open then
            local bs = 24
            local th = imgui.GetTextLineHeight() * 1.35
            imgui.SetCursorPos({ imgui.GetWindowWidth() - pad_x - bs, y0 + (th - bs) / 2 })
            imgui.PushStyleVar(ImGuiStyleVar_FramePadding, { 0, 0 })
            imgui.PushStyleColor(ImGuiCol_ButtonHovered, { 1.0, 0.42, 0.50, 0.28 })
            local hit = M.ghost('X##hdr_close', { bs, bs })
            imgui.PopStyleColor(1)
            imgui.PopStyleVar(1)
            if hit then open[1] = false end
            if mini ~= nil then
                imgui.SetCursorPos({ imgui.GetWindowWidth() - pad_x - bs * 2 - 6, y0 + (th - bs) / 2 })
                imgui.PushStyleVar(ImGuiStyleVar_FramePadding, { 0, 0 })
                imgui.PushStyleColor(ImGuiCol_ButtonHovered, { TEAL[1], TEAL[2], TEAL[3], 0.25 })
                local mh = M.ghost((mini and '+' or '-') .. '##hdr_mini', { bs, bs })
                imgui.PopStyleColor(1)
                imgui.PopStyleVar(1)
                if imgui.IsItemHovered() then imgui.SetTooltip(mini and 'Show controls' or 'Hide controls (compact)') end
                if mh then mini_hit = true end
            end
        end
        imgui.SetCursorPos({ pad_x, y0 })
        grad_text(((a or '') .. ((b and b ~= '') and (' ' .. b) or '')), 1.35)
        if sub and sub ~= '' then
            imgui.SetWindowFontScale(0.9 * M.ui_scale)
            imgui.TextColored(C.muted, sub)
            imgui.SetWindowFontScale(M.ui_scale)
        end
        glow_rule()
        imgui.BeginChild('##theme_body', { 0, 0 }, false)
        imgui.SetWindowFontScale(M.ui_scale)
        M._body = true
        return mini_hit
    end
end
