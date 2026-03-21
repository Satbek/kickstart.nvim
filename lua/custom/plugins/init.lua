-- You can add your own plugins here or in other files in this directory!
--  I promise not to create any merge conflicts in this directory :)
--
-- See the kickstart.nvim README for more information

local go_filetypes = {
  go = true,
  gomod = true,
  gowork = true,
  gotmpl = true,
}

local function is_nvim_config_dir(bufnr)
  bufnr = bufnr or 0
  local bufname = vim.api.nvim_buf_get_name(bufnr)
  if bufname == '' then return false end

  local config_dir = vim.fn.stdpath 'config'
  return vim.startswith(bufname, config_dir)
end

local function format_enabled(bufnr)
  bufnr = bufnr or 0
  return is_nvim_config_dir(bufnr) or go_filetypes[vim.bo[bufnr].filetype] == true
end

return {
  { -- Autoformat
    'stevearc/conform.nvim',
    event = { 'BufWritePre' },
    cmd = { 'ConformInfo' },
    keys = {
      {
        '<leader>f',
        function()
          if not format_enabled(0) then return end
          require('conform').format { async = true, lsp_format = 'fallback' }
        end,
        mode = '',
        desc = '[F]ormat buffer',
      },
    },
    opts = {
      notify_on_error = false,
      format_on_save = function(bufnr)
        if not format_enabled(bufnr) then return end
        -- Disable "format_on_save lsp_fallback" for languages that don't
        -- have a well standardized coding style. You can add additional
        -- languages here or re-enable it for the disabled ones.
        local disable_filetypes = { c = true, cpp = true }
        if disable_filetypes[vim.bo[bufnr].filetype] then
          return nil
        else
          return {
            timeout_ms = 500,
            lsp_format = 'fallback',
          }
        end
      end,
      formatters_by_ft = {
        lua = { 'stylua' },
        -- Run import organization before final formatting for Go buffers.
        go = { 'goimports', 'gofumpt' },
        -- Conform can also run multiple formatters sequentially
        -- python = { "isort", "black" },
        --
        -- You can use 'stop_after_first' to run the first available formatter from the list
        -- javascript = { "prettierd", "prettier", stop_after_first = true },
      },
    },
  },
  {
    'ray-x/go.nvim',
    dependencies = { -- optional packages
      'ray-x/guihua.lua',
      'neovim/nvim-lspconfig',
      'nvim-treesitter/nvim-treesitter',
    },
    ft = { 'go', 'gomod', 'gowork', 'gotmpl' },
    opts = {
      -- Keep diagnostics under the global `vim.diagnostic.config` owner.
      diagnostic = false,
      -- Let the main LSP setup own `gopls`; go.nvim stays as the Go UX layer.
      lsp_cfg = false,
      lsp_inlay_hints = {
        -- Avoid globally forcing hints on; your generic LSP toggle handles this.
        enable = false,
      },
    },
  },
}
