local function find_linter_config(cfg_file)
  -- 1. Get the absolute path to the directory of the current file
  local current_dir = vim.fn.expand '%:p:h'

  -- 2. Traverse upwards to the root directory
  -- vim.fs.find with upward = true is the most stable way to do this in Neovim
  local found = vim.fs.find(cfg_file, {
    upward = true,
    path = current_dir,
    stop = vim.loop.os_homedir(), -- Optional: stop at home dir to avoid scanning root
  })

  -- 3. If found, return the first match (it will be the closest one)
  if #found > 0 then return found[1] end

  -- 4. Fallback to your global config
  -- stdpath('config') points to your ~/.config/nvim/
  return vim.fs.joinpath(vim.fn.stdpath 'config', cfg_file)
end

return {
  { -- Linting
    'mfussenegger/nvim-lint',
    event = { 'BufReadPre', 'BufNewFile' },
    config = function()
      local lint = require 'lint'
      lint.linters_by_ft = {
        markdown = { 'markdownlint' },
        lua = { 'luacheck' },
        go = { 'golangcilint' },
      }

      -- lua
      local luacheck = lint.linters.luacheck

      luacheck.cmd = vim.fs.joinpath(vim.fn.stdpath 'data', 'mason', 'bin', 'luacheck')
      luacheck.args = {
        '--config',
        find_linter_config '.luacheckrc',
        unpack(luacheck.args),
      }

      -- go
      lint.linters.golangcilint.cmd = vim.fs.joinpath(vim.fn.stdpath 'data', 'mason', 'bin', 'golangci-lint')

      table.insert(lint.linters.golangcilint.args, 1, find_linter_config '.golangci-lint.yml')
      table.insert(lint.linters.golangcilint.args, 1, '--config')

      -- To allow other plugins to add linters to require('lint').linters_by_ft,
      -- instead set linters_by_ft like this:
      -- lint.linters_by_ft = lint.linters_by_ft or {}
      -- lint.linters_by_ft['markdown'] = { 'markdownlint' }
      --
      -- However, note that this will enable a set of default linters,
      -- which will cause errors unless these tools are available:
      -- {
      --   clojure = { "clj-kondo" },
      --   dockerfile = { "hadolint" },
      --   inko = { "inko" },
      --   janet = { "janet" },
      --   json = { "jsonlint" },
      --   markdown = { "vale" },
      --   rst = { "vale" },
      --   ruby = { "ruby" },
      --   terraform = { "tflint" },
      --   text = { "vale" }
      -- }
      --
      -- You can disable the default linters by setting their filetypes to nil:
      -- lint.linters_by_ft['clojure'] = nil
      -- lint.linters_by_ft['dockerfile'] = nil
      -- lint.linters_by_ft['inko'] = nil
      -- lint.linters_by_ft['janet'] = nil
      -- lint.linters_by_ft['json'] = nil
      -- lint.linters_by_ft['markdown'] = nil
      -- lint.linters_by_ft['rst'] = nil
      -- lint.linters_by_ft['ruby'] = nil
      -- lint.linters_by_ft['terraform'] = nil
      -- lint.linters_by_ft['text'] = nil

      -- Create autocommand which carries out the actual linting
      -- on the specified events.
      local lint_augroup = vim.api.nvim_create_augroup('lint', { clear = true })
      vim.api.nvim_create_autocmd({ 'BufEnter', 'BufWritePost', 'InsertLeave' }, {
        group = lint_augroup,
        callback = function()
          -- Only run the linter in buffers that you can modify in order to
          -- avoid superfluous noise, notably within the handy LSP pop-ups that
          -- describe the hovered symbol using Markdown.
          if vim.bo.modifiable then lint.try_lint() end
        end,
      })
    end,
  },
}
