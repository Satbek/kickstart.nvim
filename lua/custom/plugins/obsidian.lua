local function obsidian_vault()
  local vault = vim.env.OBSIDIAN_VAULT
  if vault == nil or vault == '' then return nil end

  vault = vim.fn.expand(vault)
  if (vim.uv or vim.loop).fs_stat(vault) == nil then return nil end

  return vault
end

local vault = obsidian_vault()
if vault == nil then return {} end

return {
  {
    'obsidian-nvim/obsidian.nvim',
    version = '*',
    ft = 'markdown',
    dependencies = {
      'nvim-lua/plenary.nvim',
    },
    cmd = { 'Obsidian' },
    keys = {
      { '<leader>oo', '<cmd>Obsidian open<cr>', ft = 'markdown', desc = '[O]bsidian [O]pen app' },
      { '<leader>oq', '<cmd>Obsidian quick_switch<cr>', ft = 'markdown', desc = '[O]bsidian [Q]uick switch' },
      { '<leader>os', '<cmd>Obsidian search<cr>', ft = 'markdown', desc = '[O]bsidian [S]earch notes' },
      { '<leader>on', '<cmd>Obsidian new<cr>', ft = 'markdown', desc = '[O]bsidian [N]ew note' },
      { '<leader>ot', '<cmd>Obsidian today<cr>', ft = 'markdown', desc = '[O]bsidian [T]oday' },
      { '<leader>ob', '<cmd>Obsidian backlinks<cr>', ft = 'markdown', desc = '[O]bsidian [B]acklinks' },
      { '<leader>ol', '<cmd>Obsidian links<cr>', ft = 'markdown', desc = '[O]bsidian [L]inks in note' },
    },
    opts = {
      legacy_commands = false,
      workspaces = {
        {
          name = 'main',
          path = vault,
        },
      },
      picker = {
        name = 'telescope.nvim',
      },
      preferred_link_style = 'wiki',
      daily_notes = {
        folder = 'daily',
        date_format = '%Y-%m-%d',
        alias_format = '%B %-d, %Y',
        default_tags = { 'daily-notes' },
      },
      templates = {
        folder = 'templates',
        date_format = '%Y-%m-%d',
        time_format = '%H:%M',
        substitutions = {},
      },
      frontmatter = {
        enabled = true,
      },
      statusline = {
        enabled = true,
      },
      follow_url_func = function(url)
        vim.ui.open(url)
      end,
      follow_img_func = function(img)
        vim.ui.open(img)
      end,
    },
  },
}
