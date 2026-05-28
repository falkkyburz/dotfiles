local M = {}

function M.file_exists(path)
  local f = io.open(path, "r")
  if f ~= nil then
    f:close()
    return true
  end
  return false
end

function M.group_ws()
    local directions = { "u", "r", "d", "l" }
    local active = hl.get_active_window()
    if active == nil then
        return
    end
    local workspace = hl.get_active_monitor().active_workspace
    local windows = hl.get_windows({ workspace = workspace })
    if active.group == nil then
        hl.dispatch(hl.dsp.group.toggle())
    end
    for _, window in pairs(windows) do
        if window.address ~= active.address and window.group == nil then
            for _, direction in pairs(directions) do
                hl.dispatch(hl.dsp.window.move({ window = window, into_group = direction }))
            end
        end
    end
end

function M.ungroup_ws()
    hl.dispatch("moveoutofgroup")
end

return M
