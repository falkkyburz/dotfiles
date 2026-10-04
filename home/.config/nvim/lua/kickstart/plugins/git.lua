-- Repository status and a three-way merge editor, sharing the search project root.
return function(project_root)
  local function open_diff()
    require('diffview').open({ '-C=' .. project_root() })
  end

  return {
    {
      'NeogitOrg/neogit',
      dependencies = {
        'nvim-lua/plenary.nvim',
        'nvim-telescope/telescope.nvim',
        'sindrets/diffview.nvim',
      },
      cmd = 'Neogit',
      keys = {
        {
          '<leader>gg',
          function() require('neogit').open({ cwd = project_root() }) end,
          desc = 'Git status (Neogit)',
        },
      },
      opts = {
        kind = 'tab',
        integrations = { telescope = true, diffview = true },
      },
    },
    {
      'sindrets/diffview.nvim',
      dependencies = { 'nvim-tree/nvim-web-devicons' },
      cmd = { 'DiffviewOpen', 'DiffviewClose', 'DiffviewFileHistory' },
      keys = {
        { '<leader>gd', open_diff, desc = 'Git review changes' },
        { '<leader>gm', open_diff, desc = 'Git merge conflict editor' },
        { '<leader>gq', '<cmd>DiffviewClose<CR>', desc = 'Git close diff/merge editor' },
      },
      opts = function()
        local actions = require('diffview.actions')
        -- Keep the existing C/C++ and buffer key groups available in diff views.
        local view_maps = { ['<leader>b'] = false }
        local panel_maps = { ['<leader>b'] = false }
        for _, key in ipairs({ 'co', 'ct', 'cb', 'ca', 'cO', 'cT', 'cB', 'cA' }) do
          view_maps['<leader>' .. key] = false
          panel_maps['<leader>' .. key] = false
        end
        vim.list_extend(view_maps, {
          { 'n', '<leader>go', actions.conflict_choose('ours'), { desc = 'Conflict: choose ours' } },
          { 'n', '<leader>gt', actions.conflict_choose('theirs'), { desc = 'Conflict: choose theirs' } },
          { 'n', '<leader>gb', actions.conflict_choose('base'), { desc = 'Conflict: choose base' } },
          { 'n', '<leader>ga', actions.conflict_choose('all'), { desc = 'Conflict: include all versions' } },
        })
        return {
          view = {
            merge_tool = {
              layout = 'diff3_mixed',
              winbar_info = true,
              disable_diagnostics = true,
            },
          },
          keymaps = { view = view_maps, file_panel = panel_maps },
        }
      end,
    },
  }
end
