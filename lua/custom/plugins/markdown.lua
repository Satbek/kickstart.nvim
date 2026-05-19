return {
  {
    'MeanderingProgrammer/render-markdown.nvim',
    ft = { 'markdown' },
    dependencies = {
      'nvim-treesitter/nvim-treesitter',
      'nvim-mini/mini.nvim',
    },
    cmd = { 'RenderMarkdown' },
    keys = {
      { '<leader>mr', '<cmd>RenderMarkdown buf_toggle<cr>', ft = 'markdown', desc = '[M]arkdown [R]ender toggle' },
      { '<leader>mR', '<cmd>RenderMarkdown preview<cr>', ft = 'markdown', desc = '[M]arkdown [R]ender preview' },
    },
    opts = {
      file_types = { 'markdown' },
      anti_conceal = {
        enabled = true,
        ignore = {
          code_background = true,
          sign = true,
          virtual_lines = true,
        },
      },
    },
  },
  {
    'iamcco/markdown-preview.nvim',
    ft = { 'markdown' },
    cmd = { 'MarkdownPreview', 'MarkdownPreviewStop', 'MarkdownPreviewToggle' },
    build = 'cd app && yarn install --frozen-lockfile',
    keys = {
      { '<leader>mp', '<cmd>MarkdownPreviewToggle<cr>', ft = 'markdown', desc = '[M]arkdown [P]review browser' },
    },
    init = function()
      vim.g.mkdp_filetypes = { 'markdown' }
      vim.g.mkdp_auto_start = 0
      vim.g.mkdp_echo_preview_url = 1
    end,
  },
}
