-- Neo-tree is a Neovim plugin to browse the file system
-- https://github.com/nvim-neo-tree/neo-tree.nvim

---@module 'lazy'
---@type LazySpec
return {
  'nvim-neo-tree/neo-tree.nvim',
  version = '*',
  dependencies = {
    'nvim-lua/plenary.nvim',
    'nvim-tree/nvim-web-devicons', -- not strictly required, but recommended
    'MunifTanjim/nui.nvim',
  },
  lazy = false,
  keys = {
    { '<leader>e', '<cmd>Neotree toggle<CR>', desc = 'Toggle file sidebar', silent = true },
    { '\\', ':Neotree reveal<CR>', desc = 'NeoTree reveal', silent = true },
  },
  ---@module 'neo-tree'
  ---@type neotree.Config
  config = function(_, opts)
    require('neo-tree').setup(opts)
    vim.api.nvim_create_autocmd('VimEnter', {
      group = vim.api.nvim_create_augroup('kickstart-file-sidebar', { clear = true }),
      callback = function()
        -- Leave pipes, diff mode, and headless commands alone.
        if #vim.api.nvim_list_uis() == 0 or vim.o.diff or vim.fn.argc() > 1 then return end
        if vim.bo.buftype ~= '' then return end
        local name = vim.api.nvim_buf_get_name(0)
        local root = vim.fs.root(name ~= '' and name or vim.fn.getcwd(), '.git') or vim.fn.getcwd()
        require('neo-tree.command').execute({ action = 'show', source = 'filesystem', position = 'left', dir = root })
      end,
    })
  end,
  opts = {
    close_if_last_window = true,
    window = {
      position = 'left',
      width = 32,
      mappings = {
        ['<space>'] = 'none', -- Keep Space available as the leader key.
      },
    },
    filesystem = {
      follow_current_file = { enabled = true },
      bind_to_cwd = true,
      window = {
        mappings = {
          ['h'] = 'close_node',
          ['l'] = function(state)
            local node = state.tree:get_node()
            if node.type == 'directory' and node:is_expanded() then
              vim.cmd('normal! j')
            else
              state.commands.open(state)
            end
          end,
          ['\\'] = 'close_window',
        },
      },
    },
  },
}
