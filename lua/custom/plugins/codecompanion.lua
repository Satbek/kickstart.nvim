-- Do not use foreighn providers on work projects.
-- Every project counts as working, unless it has .hobby file.
local function is_hobby_project()
  -- 1. Get the absolute path to the directory of the current file
  local current_dir = vim.fn.expand '%:p:h'

  -- 2. Traverse upwards to the root directory
  -- vim.fs.find with upward = true is the most stable way to do this in Neovim
  local found = vim.fs.find('.hobby', {
    upward = true,
    path = current_dir,
    stop = vim.loop.os_homedir(), -- Optional: stop at home dir to avoid scanning root
  })

  -- 3. Return result.
  if #found > 0 then return found[1] end
end

return {
  'olimorris/codecompanion.nvim',
  -- test comment
  dependencies = {
    'nvim-lua/plenary.nvim',
    'nvim-treesitter/nvim-treesitter',
  },
  keys = {
    { '<leader>ca', '<cmd>CodeCompanionActions<cr>', mode = { 'n', 'v' }, desc = 'CodeCompanion: Actions' },
    { '<LocalLeader>a', '<cmd>CodeCompanionChat Toggle<cr>', mode = { 'n', 'v' }, desc = 'CodeCompanion: Toggle chat' },
    { 'ga', '<cmd>CodeCompanionChat Add<cr>', mode = 'v', desc = 'CodeCompanion: Add selection to chat' },
  },
  config = function()
    local config = {
      interactions = {
        -- todo: if there are .hobby file use codex, othervise primate ai
        chat = {
          adapter = 'private_ai',
          roles = {
            llm = function(adapter)
              if adapter.model ~= nil and adapter.model.name ~= nil then
                -- we can return model.name
                return 'CodeCompanion (' .. adapter.formatted_name .. ':' .. adapter.model.name .. ')'
              end
              return 'CodeCompanion (' .. adapter.formatted_name .. ')'
            end,
            user = 'Me',
          },
        },
        -- Inline interaction supports HTTP adapters only (ACP like `codex` won't work here)
        inline = { adapter = 'private_ai' },
        background = {
          -- Background interactions currently support HTTP adapters only.
          -- `codex` is an ACP adapter, so use an HTTP adapter for title generation.
          -- todo: extra small local model for this
          adapter = 'private_ai',
          chat = {
            callbacks = {
              ['on_ready'] = {
                actions = {
                  'interactions.background.builtin.chat_make_title',
                },
                -- Enable "on_ready" callback which contains the title generation action
                enabled = true,
              },
            },
            opts = {
              -- Enable background interactions generally
              enabled = true,
            },
          },
        },
      },
      opts = {
        language = 'Russian',
      },
      display = {
        diff = {
          enabled = true,
          -- inline: show edits inline in the current buffer (or float, depending on provider_opts.inline.layout)
          -- split: open side-by-side/stacked diff windows for review before applying
          -- mini_diff: use mini.diff UI/signs (requires mini.diff to be set up and available)
          provider = 'inline',
        },
      },

      adapters = {
        http = {
          private_ai = function()
            return require('codecompanion.adapters').extend('openai_compatible', {
              name = 'private_ai',
              env = {
                -- url = 'PRIVATE_AI_URL',
                url = 'PRIVATE_AI_LLM_PROXY_URL',
                api_key = 'PRIVATE_AI_API_KEY',
                chat_url = '/v1/chat/completions',
                models_endpoint = '/v1/models',
              },
              schema = {
                model = {
                  choices = {
                    'glm-5',
                    'glm-4.7',
                    'qwen-3-32b',
                    'kimi-k2.5',
                  },
                  default = 'glm-5',
                },
              },
            })
          end,
          grok_xai = function()
            return require('codecompanion.adapters').extend('openai_responses', {
              name = 'grok_xai',
              url = 'https://api.x.ai/v1/responses',
              env = {
                api_key = 'XAI_API_KEY',
              },
              schema = {
                model = {
                  choices = {
                    'grok-code-fast-1',
                    'grok-4-1-fast-reasoning',
                    'grok-4-1-fast-non-reasoning',
                    'grok-4',
                  },
                  default = 'grok-code-fast-1',
                },
              },
            })
          end,
          grok_xai_compatible = function()
            return require('codecompanion.adapters').extend('openai_compatible', {
              name = 'grok_xai_compatible',
              env = {
                url = 'https://api.x.ai',
                api_key = 'XAI_API_KEY',
                chat_url = '/v1/chat/completions',
                models_endpoint = '/v1/models',
              },
            })
          end,

          opts = {
            show_presets = false,
          },
        },
        acp = {
          opts = {
            show_presets = false,
          },
          -- you should install https://github.com/zed-industries/codex-acp/releases for codex
          codex = function()
            return require('codecompanion.adapters').extend('codex', {
              defaults = {
                auth_method = 'chatgpt', -- "openai-api-key"|"codex-api-key"|"chatgpt"
              },
            })
          end,
        },
      },
    }
    if not is_hobby_project() then
      -- support only private_ai
      config.adapters.acp = { opts = { show_presets = false } }
      for k, _ in pairs(config.adapters.http) do
        if k ~= 'private_ai' then config.adapters.http[k] = nil end
      end
      config.adapters.http.opts = { show_presets = false }
    else
      -- work with codex
      config.interactions.chat.adapter = 'codex'
      config.interactions.inline.adapter = 'codex'
      config.interactions.background.chat.opts.enabled = false
    end

    require('codecompanion').setup(config)
  end,
}
