local project = require 'custom.utils.project'

local function project_prompt_dir(root)
  root = root or project.context().project_root
  return vim.fs.joinpath(root, '.codecompanion')
end

local warned_missing_codex = false

local function chat_adapter_for_project()
  local ctx = project.context()
  if not ctx.is_hobby then return 'private_ai' end

  if vim.fn.executable 'codex-acp' == 1 then return 'codex' end

  if not warned_missing_codex then
    warned_missing_codex = true
    vim.schedule(function() vim.notify('CodeCompanion: `codex-acp` not found, falling back to `private_ai`', vim.log.levels.WARN) end)
  end

  return 'private_ai'
end

return {
  'olimorris/codecompanion.nvim',
  dependencies = {
    'nvim-lua/plenary.nvim',
    'nvim-treesitter/nvim-treesitter',
  },
  keys = {
    { '<leader>ca', '<cmd>CodeCompanionActions<cr>', mode = { 'n', 'v' }, desc = 'CodeCompanion: Actions' },
    { '<LocalLeader>a', '<cmd>CodeCompanionChat Toggle<cr>', mode = { 'n', 'v' }, desc = 'CodeCompanion: Toggle chat' },
    {
      '<LocalLeader>cc',
      function() require('codecompanion').cli { agent = 'codex' } end,
      mode = 'n',
      desc = 'CodeCompanion: Codex CLI',
    },
    {
      '<LocalLeader>cp',
      function() require('codecompanion').cli { agent = 'codex', prompt = true } end,
      mode = { 'n', 'v' },
      desc = 'CodeCompanion: Prompt Codex CLI',
    },
    { 'ga', '<cmd>CodeCompanionChat Add<cr>', mode = 'v', desc = 'CodeCompanion: Add selection to chat' },
  },
  config = function()
    require('codecompanion').setup {
      prompt_library = {
        markdown = {
          dirs = {
            project_prompt_dir(),
          },
        },
      },
      interactions = {
        chat = {
          adapter = 'private_ai',
          roles = {
            llm = function(adapter)
              if adapter.model ~= nil and adapter.model.name ~= nil then
                return 'CodeCompanion (' .. adapter.formatted_name .. ':' .. adapter.model.name .. ')'
              end
              return 'CodeCompanion (' .. adapter.formatted_name .. ')'
            end,
            user = 'Me',
          },
        },
        -- Inline interaction only supports HTTP adapters, so keep it on the
        -- internal proxy even when chat uses Codex.
        inline = { adapter = 'private_ai' },
        background = {
          -- Background interactions also require an HTTP adapter. Use the
          -- internal proxy for generated chat titles.
          adapter = 'private_ai',
          chat = {
            callbacks = {
              ['on_ready'] = {
                actions = {
                  'interactions.background.builtin.chat_make_title',
                },
                enabled = true,
              },
            },
            opts = {
              enabled = true,
            },
          },
        },
        cli = {
          -- Keep the Codex CLI explicit. This makes the workflow available
          -- without turning Codex into the default CLI agent globally.
          agents = {
            codex = {
              cmd = 'codex',
              args = {},
              description = 'OpenAI Codex CLI',
              provider = 'terminal',
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
          provider = 'inline',
        },
        action_palette = {
          opts = {
            show_preset_prompts = true,
          },
        },
      },
      adapters = {
        http = {
          private_ai = function()
            return require('codecompanion.adapters').extend('openai_compatible', {
              name = 'private_ai',
              env = {
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
          -- Install https://github.com/zed-industries/codex-acp/releases for Codex chat.
          codex = function()
            return require('codecompanion.adapters').extend('codex', {
              defaults = {
                auth_method = 'chatgpt',
              },
            })
          end,
        },
      },
    }

    local function sync_runtime_config()
      local ctx = project.context()
      local runtime_config = require('codecompanion.config').config

      -- Resolve prompts from the active project instead of the cwd that
      -- happened to be active when the plugin first loaded.
      runtime_config.prompt_library.markdown.dirs = {
        project_prompt_dir(ctx.project_root),
      }

      -- ACP adapters only work in chat, so prefer Codex for hobby projects
      -- and keep work projects on the internal HTTP proxy.
      runtime_config.interactions.chat.adapter = chat_adapter_for_project()
      runtime_config.interactions.inline.adapter = 'private_ai'
      runtime_config.interactions.background.adapter = 'private_ai'
    end

    sync_runtime_config()

    vim.api.nvim_create_autocmd({ 'BufEnter', 'DirChanged' }, {
      group = vim.api.nvim_create_augroup('codecompanion-project-context', { clear = true }),
      callback = sync_runtime_config,
    })
  end,
}
