local _, Addon = ...
-- /cgp perf: where the addon's time goes, and whether a long frame was its doing.
--
-- The game's addon profiler only gives one number for the whole addon. This times the calls the addon makes every 0.1 s
-- (the refresh and its steps) and the two handlers that run on every frame, and watches the frame time itself: a long
-- frame in which the addon spent almost nothing is somebody else's stutter.
--
--   /cgp perf            print what has been collected (starts collecting if it was off)
--   /cgp perf on | off   start (from zero) or stop collecting
--   /cgp perf reset      start again from zero
--   /cgp perf slow       the slowest single calls, with the time and whether you were in combat
--
-- Nothing is installed until the first use; after that the timed calls cost one clock read each while collecting and one
-- boolean test while not. Times are in milliseconds of the game's own clock (debugprofilestop).
local Perf = {}
Addon.Perf = Perf

local clock = debugprofilestop
local active, installed = false, false
local startedAt, combatTime = 0, 0
local stats, order = {}, {}
local slow, SLOW_KEEP, SLOW_MS = {}, 12, 3
local frames
local oursInFrame, depth = 0, 0

local function Reset()
    stats, order, slow = {}, {}, {}
    startedAt, combatTime = clock(), 0
    oursInFrame, depth = 0, 0
    frames = { count = 0, total = 0, worst = 0, worstOurs = 0, over33 = 0, over50 = 0, over100 = 0,
        ours50 = 0, memoryStart = collectgarbage("count"), long = {} }
end

local function Record(label, started, ...)
    local took = clock() - started
    local row = stats[label]
    if not row then
        row = { calls = 0, total = 0, max = 0, over1 = 0, over5 = 0, combat = 0 }
        stats[label] = row
        order[#order + 1] = label
    end
    row.calls = row.calls + 1
    row.total = row.total + took
    if took > row.max then row.max = took end
    if took > 1 then row.over1 = row.over1 + 1 end
    if took > 5 then row.over5 = row.over5 + 1 end
    if InCombatLockdown() then row.combat = row.combat + took end
    -- Only the outermost timed call counts toward the frame's total: the inner ones are already inside it.
    depth = depth - 1
    if depth <= 0 then depth = 0; oursInFrame = oursInFrame + took end
    if took >= SLOW_MS then
        slow[#slow + 1] = { label = label, took = took, at = (clock() - startedAt) / 1000, combat = InCombatLockdown() and true or false }
        table.sort(slow, function(a, b) return a.took > b.took end)
        while #slow > SLOW_KEEP do slow[#slow] = nil end
    end
    return ...
end

-- A function that is timed while collecting. Cheap when it is not.
function Perf.Wrap(label, fn)
    return function(...)
        if not active then return fn(...) end
        depth = depth + 1
        return Record(label, clock(), fn(...))
    end
end

-- Replaces obj[method] by a timed version, once.
local function Hook(obj, method, label)
    if type(obj) ~= "table" or type(obj[method]) ~= "function" or Perf.hooked and Perf.hooked[obj] and Perf.hooked[obj][method] then return end
    Perf.hooked = Perf.hooked or {}
    Perf.hooked[obj] = Perf.hooked[obj] or {}
    Perf.hooked[obj][method] = true
    obj[method] = Perf.Wrap(label, obj[method])
end

local function Install()
    if installed then return end
    installed = true
    -- The refresh and its steps. A step that is called inside another counts in both (the numbers are inclusive).
    Hook(Addon, "Refresh", "Addon:Refresh (every 0.1 s)")
    Hook(Addon, "CheckNativeTaint", "  CheckNativeTaint")
    Hook(Addon.HUD, "Refresh", "  HUD:Refresh")
    Hook(Addon.HUD, "RefreshChat", "  HUD:RefreshChat")
    Hook(Addon.HUD, "RefreshLegend", "  HUD:RefreshLegend")
    Hook(Addon.HUD, "ApplyLegendStyle", "  HUD:ApplyLegendStyle")
    Hook(Addon.Layout, "Prepare", "  Layout:Prepare")
    Hook(Addon.Layout, "Restore", "  Layout:Restore")
    Hook(Addon.Display, "Refresh", "  Display:Refresh")
    Hook(Addon.Display, "GetBars", "    Display:GetBars")
    Hook(Addon.Display, "RefreshGeometry", "    Display:RefreshGeometry")
    Hook(Addon.Display, "Update", "    Display:Update (slots)")
    Hook(Addon.Display, "SuppressNative", "    Display:SuppressNative")
    Hook(Addon.Display, "SetLayer", "    Display:SetLayer")
    Hook(Addon.Input, "Refresh", "    Input:Refresh")
    Hook(Addon.Mover, "Refresh", "  Mover:Refresh")
    Hook(Addon.ItemDelete, "Refresh", "  ItemDelete:Refresh")
    Hook(Addon.Wheels, "Refresh", "  Wheels:Refresh")
    Hook(Addon.MenuHints, "Refresh", "  MenuHints:Refresh")
    -- The handler that runs on every frame (the game's own events cause the refreshes, Poll only counts time).
    local HUD = Addon.HUD
    if HUD and HUD.legendWatcher and HUD.legendWatchHandler then
        HUD.legendWatcher:SetScript("OnUpdate", Perf.Wrap("HUD legend watcher (every frame)", HUD.legendWatchHandler))
    end
    -- The frame time, and how much of each frame was this addon's.
    local watch = CreateFrame("Frame")
    watch:SetScript("OnUpdate", function(_, elapsed)
        if not active then return end
        local ms = elapsed * 1000
        local ours = oursInFrame
        oursInFrame = 0
        frames.count = frames.count + 1
        frames.total = frames.total + ms
        depth = 0
        if InCombatLockdown() then combatTime = combatTime + elapsed end
        if ms > 33 then frames.over33 = frames.over33 + 1 end
        if ms > 50 then
            frames.over50 = frames.over50 + 1
            if ours >= 5 then frames.ours50 = frames.ours50 + 1 end
            frames.long[#frames.long + 1] = { ms = ms, ours = ours, at = (clock() - startedAt) / 1000 }
            if #frames.long > 8 then table.remove(frames.long, 1) end
        end
        if ms > 100 then frames.over100 = frames.over100 + 1 end
        if ms > frames.worst then frames.worst, frames.worstOurs = ms, ours end
    end)
end

function Perf.Start()
    Install()
    Reset()
    active = true
end

function Perf.Stop()
    active = false
end

function Perf.IsActive()
    return active
end

local function Say(text) Addon:Print(text) end

function Perf.Report()
    if not frames then Say("nothing collected yet: /cgp perf on, play for a minute, /cgp perf") return end
    local seconds = math.max(0.001, (clock() - startedAt) / 1000)
    Say(string.format("perf: %s, %.0f s collected, %.0f s of it in combat, Lua memory %.0f KB (%+.0f KB since the start)",
        active and "collecting" or "stopped", seconds, combatTime, collectgarbage("count"),
        collectgarbage("count") - frames.memoryStart))
    if frames.count > 0 then
        Say(string.format("frames: %d, average %.1f ms (%.0f fps), over 33 ms: %d, over 50 ms: %d, over 100 ms: %d, worst %.0f ms (this addon %.1f ms of it)",
            frames.count, frames.total / frames.count, 1000 * frames.count / math.max(1, frames.total), frames.over33,
            frames.over50, frames.over100, frames.worst, frames.worstOurs))
        if frames.over50 > 0 then
            Say(string.format("of the %d frames over 50 ms, this addon spent 5 ms or more in %d: a long frame without that is not its doing",
                frames.over50, frames.ours50))
        end
    end
    local names = {}
    for _, label in ipairs(order) do names[#names + 1] = label end
    table.sort(names, function(a, b) return stats[a].total > stats[b].total end)
    Say(string.format("%-36s %7s %8s %8s %9s %6s %5s %9s", "call", "calls", "avg ms", "max ms", "total ms", ">1 ms", ">5 ms", "in combat"))
    for _, label in ipairs(names) do
        local row = stats[label]
        Say(string.format("%-36s %7d %8.3f %8.2f %9.1f %6d %5d %8.1f", label, row.calls, row.total / row.calls, row.max,
            row.total, row.over1, row.over5, row.combat))
    end
    local refresh = stats["Addon:Refresh (every 0.1 s)"]
    if refresh then
        Say(string.format("the refresh alone: %.1f ms per second collected (%.2f%% of the time)", refresh.total / seconds,
            refresh.total / seconds / 10))
    end
    Say("totals are inclusive (a step inside the refresh counts in both rows); /cgp perf slow lists the slowest single calls")
end

function Perf.ReportSlow()
    if not frames then Say("nothing collected yet") return end
    if #slow == 0 then Say("no single call took " .. SLOW_MS .. " ms or more") return end
    Say("slowest single calls (" .. SLOW_MS .. " ms or more):")
    for _, entry in ipairs(slow) do
        Say(string.format("  %6.2f ms  %s  at %.0f s%s", entry.took, entry.label, entry.at, entry.combat and "  (in combat)" or ""))
    end
    if frames and #frames.long > 0 then
        Say("frames over 50 ms (the time, this addon's part of it, when):")
        for _, f in ipairs(frames.long) do
            Say(string.format("  %6.0f ms  addon %5.1f ms  at %.0f s", f.ms, f.ours, f.at))
        end
    end
end

-- The command word after /cgp perf.
function Perf.Command(arg)
    arg = (arg or ""):lower()
    if arg == "on" or arg == "start" then
        Perf.Start()
        Say("collecting. Play for a minute (a fight too), then /cgp perf")
    elseif arg == "off" or arg == "stop" then
        Perf.Stop()
        Say("stopped; /cgp perf prints what was collected")
    elseif arg == "reset" then
        Perf.Start()
        Say("started again from zero")
    elseif arg == "slow" then
        Perf.ReportSlow()
    else
        if not frames then
            Perf.Start()
            Say("it was not collecting: started now; /cgp perf again in a minute")
            return
        end
        Perf.Report()
    end
end
