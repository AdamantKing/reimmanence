-- theme.lua  -  shared look for my Ashita v4 addons (ChainFinder, Immanence, RoE Helper)
--
-- Style taken from YunaGearOpt: near-black flat panels, white hairlines, soft rounded corners, quiet
-- uppercase captions, and gold only where it matters (title, selection, primary action).
--
-- Put a copy of this file next to each addon's .lua file and  local theme = require('theme').
--
-- Usage in d3d_present:
--     local nc, nv = theme.push()
--     ... draw windows ...
--     theme.pop(nc, nv)
--
-- Inside a window (opened with theme.begin so it has no native title bar):
--     if theme.begin('My Window##id', open_flag) then
--         theme.header(open_flag, 'CHAIN', 'FINDER', 'subtitle text')
--         ...
--     end
--     imgui.End()

require('common')
local imgui = require('imgui')

local M = {}

M.C = {
    bg       = { 0.052, 0.055, 0.064, 0.97 },
    card     = { 0.082, 0.087, 0.101, 1.00 },
    frame    = { 0.110, 0.116, 0.134, 1.00 },
    frame_hi = { 0.150, 0.157, 0.180, 1.00 },
    border   = { 1.000, 1.000, 1.000, 0.06 },
    line     = { 1.000, 1.000, 1.000, 0.07 },
    gold     = { 0.940, 0.770, 0.420, 1.00 },
    gold_dim = { 0.940, 0.770, 0.420, 0.62 },
    gold_bg  = { 0.940, 0.770, 0.420, 0.92 },
    text     = { 0.910, 0.918, 0.935, 1.00 },
    muted    = { 0.500, 0.528, 0.590, 1.00 },
    green    = { 0.450, 0.900, 0.600, 1.00 },
    red      = { 1.000, 0.450, 0.450, 1.00 },
    warn     = { 1.000, 0.600, 0.200, 1.00 },
    blue     = { 0.450, 0.700, 1.000, 1.00 },
    dark     = { 0.060, 0.060, 0.070, 1.00 },
}
local C = M.C

-- Window scale (1.0 = 100%). Addons that offer a scale control set it with M.set_scale(); everyone else stays at 1.0.
M.ui_scale = 1.0

function M.set_scale(s)
    s = math.max(0.25, math.min(1.5, s))
    if math.abs(s - M.ui_scale) < 0.0001 then return end
    M.ui_scale = s
end

----------------------------------------------------------------------
-- ImGui reads plain text as a printf format, so a '%' (e.g. "Haste%") turns into garbage.
-- Escape it once for every Text call. Pass pre-formatted strings only.
----------------------------------------------------------------------
if not imgui.__theme_escaped then
    imgui.__theme_escaped = true
    local raw_text, raw_colored, raw_disabled = imgui.Text, imgui.TextColored, imgui.TextDisabled
    local function esc(t) return (tostring(t):gsub('%%', '%%%%')) end
    imgui.Text = function(t, ...) return raw_text(esc(t), ...) end
    imgui.TextColored = function(c, t, ...) return raw_colored(c, esc(t), ...) end
    if raw_disabled then imgui.TextDisabled = function(t, ...) return raw_disabled(esc(t), ...) end end
end

----------------------------------------------------------------------
-- Global style: push once per frame around all of an addon's windows
----------------------------------------------------------------------
function M.push()
    local cols = {
        { ImGuiCol_WindowBg, C.bg }, { ImGuiCol_ChildBg, { 0, 0, 0, 0 } },
        { ImGuiCol_PopupBg, { 0.075, 0.079, 0.092, 0.99 } },
        { ImGuiCol_Border, C.border }, { ImGuiCol_Text, C.text }, { ImGuiCol_TextDisabled, C.muted },
        { ImGuiCol_FrameBg, C.frame }, { ImGuiCol_FrameBgHovered, C.frame_hi }, { ImGuiCol_FrameBgActive, C.frame_hi },
        { ImGuiCol_Button, C.frame }, { ImGuiCol_ButtonHovered, C.frame_hi }, { ImGuiCol_ButtonActive, C.frame_hi },
        { ImGuiCol_Header, { 1, 1, 1, 0.06 } }, { ImGuiCol_HeaderHovered, { 1, 1, 1, 0.045 } },
        { ImGuiCol_HeaderActive, { 1, 1, 1, 0.09 } },
        { ImGuiCol_SliderGrab, C.gold }, { ImGuiCol_SliderGrabActive, C.gold }, { ImGuiCol_CheckMark, C.gold },
        { ImGuiCol_PlotHistogram, C.gold }, { ImGuiCol_Separator, C.line },
        { ImGuiCol_ScrollbarBg, { 0, 0, 0, 0 } }, { ImGuiCol_ScrollbarGrab, { 1, 1, 1, 0.08 } },
        { ImGuiCol_ScrollbarGrabHovered, { 1, 1, 1, 0.16 } }, { ImGuiCol_ScrollbarGrabActive, { 1, 1, 1, 0.22 } },
        { ImGuiCol_TableRowBg, { 0, 0, 0, 0 } },
    }
    for _, c in ipairs(cols) do imgui.PushStyleColor(c[1], c[2]) end
    local u = M.ui_scale
    local function sc(v) return v end         -- only the FONT is scaled, never paddings or window sizes
    local vars = {
        { ImGuiStyleVar_WindowRounding, sc(12) }, { ImGuiStyleVar_ChildRounding, sc(8) }, { ImGuiStyleVar_FrameRounding, sc(6) },
        { ImGuiStyleVar_GrabRounding, sc(6) }, { ImGuiStyleVar_PopupRounding, sc(8) }, { ImGuiStyleVar_ScrollbarRounding, sc(8) },
        { ImGuiStyleVar_WindowPadding, { sc(16), sc(14) } }, { ImGuiStyleVar_FramePadding, { sc(10), sc(6) } },
        { ImGuiStyleVar_ItemSpacing, { sc(8), sc(8) } }, { ImGuiStyleVar_WindowBorderSize, 1 }, { ImGuiStyleVar_ScrollbarSize, sc(8) },
    }
    for _, v in ipairs(vars) do imgui.PushStyleVar(v[1], v[2]) end
    return #cols, #vars
end

function M.pop(nc, nv)
    imgui.PopStyleVar(nv)
    imgui.PopStyleColor(nc)
end

----------------------------------------------------------------------
-- Windows
----------------------------------------------------------------------
-- No native title bar (the header below replaces it); extra = additional ImGuiWindowFlags
-- The window itself never scrolls: the header (with the X) stays pinned at the top, and everything below it
-- lives in a scrolling body child that header() opens. Always finish with theme.finish() instead of imgui.End().
function M.begin(name, open, extra)
    local flags = bit.bor(ImGuiWindowFlags_NoTitleBar, ImGuiWindowFlags_NoCollapse,
        ImGuiWindowFlags_NoScrollbar, ImGuiWindowFlags_NoScrollWithMouse)
    if extra then flags = bit.bor(flags, extra) end
    M._body = false
    local vis = imgui.Begin(name, open, flags)
    if vis then
        imgui.SetWindowFontScale(M.ui_scale)
    end
    return vis
end

-- Closes the scrolling body (if the header opened one) and the window
function M.finish()
    if M._body then
        imgui.EndChild()
        M._body = false
    end
    imgui.End()
end

----------------------------------------------------------------------
-- Text helpers
----------------------------------------------------------------------
function M.title_text(text, scale, color)
    imgui.SetWindowFontScale(scale * M.ui_scale)
    imgui.TextColored(color or C.text, text)
    imgui.SetWindowFontScale(M.ui_scale)
end

-- small quiet uppercase-style section caption
function M.caption(text)
    imgui.SetWindowFontScale(0.82 * M.ui_scale)
    imgui.TextColored(C.muted, text)
    imgui.SetWindowFontScale(M.ui_scale)
end

function M.muted(text) imgui.TextColored(C.muted, text) end

function M.text_w(text)
    local ok, a = pcall(imgui.CalcTextSize, text)
    if ok then
        if type(a) == 'number' then return a end
        if type(a) == 'table' then return a.x or a[1] or (#text * 7) end
    end
    return #text * 7
end
function M.btn_w(text) return math.floor(M.text_w(text) + 26) end

----------------------------------------------------------------------
-- Buttons
----------------------------------------------------------------------
-- size is optional; never hand nil to the binding
function M._button(label, size)
    if size then return imgui.Button(label, size) end
    return imgui.Button(label)
end

-- Solid gold when active, normal dark button otherwise
function M.accent(label, size, active)
    if active then
        imgui.PushStyleColor(ImGuiCol_Button, C.gold_bg)
        imgui.PushStyleColor(ImGuiCol_ButtonHovered, C.gold)
        imgui.PushStyleColor(ImGuiCol_ButtonActive, C.gold)
        imgui.PushStyleColor(ImGuiCol_Text, C.dark)
    end
    local clicked = M._button(label, size)
    if active then imgui.PopStyleColor(4) end
    return clicked
end

-- No fill, muted text
function M.ghost(label, size)
    imgui.PushStyleColor(ImGuiCol_Button, { 0, 0, 0, 0 })
    imgui.PushStyleColor(ImGuiCol_Text, C.muted)
    local clicked = M._button(label, size)
    imgui.PopStyleColor(2)
    return clicked
end

-- Toggle / option button: gold when selected, softly outlined-by-fill when not
function M.toggle(label, id, selected, size)
    local text = label .. '##' .. id
    if selected then return M.accent(text, size, true) end
    imgui.PushStyleColor(ImGuiCol_Button, { 1, 1, 1, 0.03 })
    imgui.PushStyleColor(ImGuiCol_ButtonHovered, { 1, 1, 1, 0.08 })
    imgui.PushStyleColor(ImGuiCol_ButtonActive, { 1, 1, 1, 0.12 })
    imgui.PushStyleColor(ImGuiCol_Text, { C.text[1], C.text[2], C.text[3], 0.78 })
    local clicked = M._button(text, size)
    imgui.PopStyleColor(4)
    return clicked
end

-- Tinted button: a colour at low alpha with coloured text (gold / green / red)
function M.tinted(label, color, size)
    imgui.PushStyleColor(ImGuiCol_Button, { color[1], color[2], color[3], 0.12 })
    imgui.PushStyleColor(ImGuiCol_ButtonHovered, { color[1], color[2], color[3], 0.22 })
    imgui.PushStyleColor(ImGuiCol_ButtonActive, { color[1], color[2], color[3], 0.32 })
    imgui.PushStyleColor(ImGuiCol_Text, color)
    local clicked = M._button(label, size)
    imgui.PopStyleColor(4)
    return clicked
end

-- Destructive action: red tint
function M.danger(label, size) return M.tinted(label, C.red, size) end

----------------------------------------------------------------------
-- Header: "CHAIN FINDER" (white + gold), a quiet info line, an X at the right, one hairline under it.
-- open = the table passed to Begin (open[1] = false when X is clicked)
----------------------------------------------------------------------
-- mini = nil (no button) | false (controls shown: button "-") | true (controls hidden: button "+").
-- Returns true when the mini button was clicked.
function M.header(open, a, b, sub, mini)
    local mini_hit = false
    local pad_x = imgui.GetCursorPosX()
    local y0 = imgui.GetCursorPosY()
    if open then
        -- square button, vertically centred on the (scaled) title line, right edge on the content margin
        local bs = 24
        local th = imgui.GetTextLineHeight() * 1.35
        imgui.SetCursorPos({ imgui.GetWindowWidth() - pad_x - bs, y0 + (th - bs) / 2 })
        -- the global FramePadding (10,6) is wider than a 24px button's room for the glyph, which pushes the X to the
        -- bottom-right of the button; zero padding lets ImGui centre it
        imgui.PushStyleVar(ImGuiStyleVar_FramePadding, { 0, 0 })
        local hit = M.ghost('X##hdr_close', { bs, bs })
        imgui.PopStyleVar(1)
        if hit then open[1] = false end
        if mini ~= nil then
            imgui.SetCursorPos({ imgui.GetWindowWidth() - pad_x - bs * 2 - 6, y0 + (th - bs) / 2 })
            imgui.PushStyleVar(ImGuiStyleVar_FramePadding, { 0, 0 })
            local mh = M.ghost((mini and '+' or '-') .. '##hdr_mini', { bs, bs })
            imgui.PopStyleVar(1)
            if imgui.IsItemHovered() then imgui.SetTooltip(mini and 'Show controls' or 'Hide controls (compact)') end
            if mh then mini_hit = true end
        end
    end
    imgui.SetCursorPos({ pad_x, y0 })
    M.title_text(a, 1.35, C.text)
    if b and b ~= '' then
        imgui.SameLine(0, 5)
        M.title_text(b, 1.35, C.gold)
    end
    if sub and sub ~= '' then
        imgui.SetWindowFontScale(0.9 * M.ui_scale)
        imgui.TextColored(C.muted, sub)
        imgui.SetWindowFontScale(M.ui_scale)
    end
    imgui.Separator()
    -- everything after the header scrolls inside this child; the header above stays put
    imgui.BeginChild('##theme_body', { 0, 0 }, false)
    imgui.SetWindowFontScale(M.ui_scale)       -- a child window has its own font scale
    M._body = true
    return mini_hit
end

-- Mini mode (no header): a lone "+" button at the top-right that restores the window. Returns true when clicked.
function M.mini_corner(tip)
    local bs = 24
    local pad_x = imgui.GetCursorPosX()
    imgui.SetCursorPosX(imgui.GetWindowWidth() - pad_x - bs)
    imgui.PushStyleVar(ImGuiStyleVar_FramePadding, { 0, 0 })
    local hit = M.ghost('+##mini_corner', { bs, bs })
    imgui.PopStyleVar(1)
    if imgui.IsItemHovered() then imgui.SetTooltip(tip or 'Show controls') end
    imgui.SetCursorPosX(pad_x)
    return hit
end

-- call right after every imgui.BeginChild / BeginCombo / BeginPopup so it matches the window scale
function M.child_scale() imgui.SetWindowFontScale(M.ui_scale) end

return M
