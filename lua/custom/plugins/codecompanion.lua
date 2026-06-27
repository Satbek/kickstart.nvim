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

local private_ai_reasoning_effort = 'off'
local private_ai_reasoning_choices = {
  'off',
  'minimal',
  'low',
  'medium',
  'high',
  'xhigh',
}

local function is_private_ai_reasoning_effort(value) return vim.tbl_contains(private_ai_reasoning_choices, value) end

local function private_ai_map_schema_to_params(adapter, settings)
  settings = vim.deepcopy(settings or adapter:make_from_schema())

  if settings.reasoning_effort == nil or settings.reasoning_effort == 'off' then
    if adapter.parameters ~= nil then adapter.parameters.reasoning_effort = nil end
    settings.reasoning_effort = nil
  end

  return require('codecompanion.adapters.http').map_schema_to_params(adapter, settings)
end

local function private_ai_parse_meta(_, data)
  local extra = data.extra
  if extra == nil then return data end

  local reasoning_content = extra.reasoning_content or extra.reasoning_text
  if reasoning_content then
    data.output = data.output or {}
    data.output.reasoning = { content = reasoning_content }
    if data.output.content == '' then data.output.content = nil end
  end

  return data
end

local function codecompanion_llm_role(adapter)
  local model = adapter.model and adapter.model.name
  local role = 'CodeCompanion (' .. adapter.formatted_name
  if model ~= nil then role = role .. ':' .. model end

  if adapter.name == 'private_ai' then role = role .. '; reasoning=' .. private_ai_reasoning_effort end

  return role .. ')'
end

local function set_private_ai_reasoning_effort(value)
  if not is_private_ai_reasoning_effort(value) then
    vim.notify('PrivateAIReasoning: unknown value `' .. value .. '`', vim.log.levels.ERROR)
    return
  end

  private_ai_reasoning_effort = value

  local chat = require('codecompanion').last_chat()
  if chat ~= nil and chat.adapter ~= nil and chat.adapter.name == 'private_ai' and chat.settings ~= nil then
    chat.settings.reasoning_effort = value
    chat:apply_settings(chat.settings)
  end

  vim.notify('private_ai reasoning_effort = ' .. value)
end

local function select_private_ai_reasoning_effort()
  vim.ui.select(private_ai_reasoning_choices, {
    prompt = 'private_ai reasoning_effort',
    format_item = function(value)
      local current = value == private_ai_reasoning_effort and ' *' or ''
      return value .. current
    end,
  }, function(value)
    if value ~= nil then set_private_ai_reasoning_effort(value) end
  end)
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
    {
      '<LocalLeader>cl',
      function() require('codecompanion').cli { agent = 'claude_code' } end,
      mode = 'n',
      desc = 'CodeCompanion: Claude Code CLI',
    },
    { 'ga', '<cmd>CodeCompanionChat Add<cr>', mode = 'v', desc = 'CodeCompanion: Add selection to chat' },
    { 'gA', '<cmd>PrivateAIReasoning<cr>', mode = 'n', desc = 'CodeCompanion: Select private_ai reasoning' },
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
            llm = codecompanion_llm_role,
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
            claude_code = {
              cmd = 'claude',
              args = {},
              description = 'Claude Code CLI',
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
              map_schema_to_params = private_ai_map_schema_to_params,
              handlers = {
                parse_message_meta = private_ai_parse_meta,
              },
              schema = {
                model = {
                  order = 1,
                  mapping = 'parameters',
                  type = 'enum',
                  desc = 'ID модели private_ai.',
                  choices = {
                    'glm-5',
                    'glm-5.1',
                    'glm-5.2',
                    'qwen3-32b',
                    'kimi-k2.5',
                    'claude-opus-4-8',
                    'claude-sonnet-4-6',
                    'deepseek-v4-pro',
                    'claude-haiku-4-5',
                    'MiniMax-M3',
                  },
                  default = 'glm-5.2',
                },
                reasoning_effort = {
                  order = 2,
                  mapping = 'parameters',
                  type = 'enum',
                  optional = true,
                  default = function() return private_ai_reasoning_effort end,
                  choices = private_ai_reasoning_choices,
                  desc = 'Reasoning effort для private_ai. off = не отправлять параметр; остальные значения уходят как reasoning_effort.',
                },
              },
            })
          end,
          -- Native Anthropic adapter pointed at the private_ai proxy's
          -- `/v1/messages` endpoint. Unlike the OpenAI-compatible `private_ai`
          -- adapter (`/v1/chat/completions`), this one emits Anthropic
          -- `cache_control` breakpoints, so Claude prompt caching actually
          -- works and cache token usage is reported. Use it for Claude models;
          -- keep `private_ai` for glm/qwen/kimi/deepseek/minimax.
          private_ai_anthropic = function()
            return require('codecompanion.adapters').extend('anthropic', {
              name = 'private_ai_anthropic',
              formatted_name = 'Private AI (Anthropic)',
              env = {
                url = 'PRIVATE_AI_LLM_PROXY_URL',
                api_key = 'PRIVATE_AI_API_KEY',
              },
              url = '${url}/v1/messages',
              schema = {
                model = {
                  default = 'claude-opus-4-8',
                  choices = {
                    ['claude-opus-4-8'] = {
                      formatted_name = 'Claude Opus 4.8',
                      meta = { context_window = 1000000, max_tokens = 128000 },
                      opts = { can_reason = true, has_vision = true },
                    },
                    ['claude-sonnet-4-6'] = {
                      formatted_name = 'Claude Sonnet 4.6',
                      meta = { context_window = 1000000, max_tokens = 128000 },
                      opts = { can_reason = true, has_vision = true },
                    },
                    ['claude-haiku-4-5'] = {
                      formatted_name = 'Claude Haiku 4.5',
                      meta = { context_window = 200000, max_tokens = 64000 },
                      opts = { can_reason = false, has_vision = true },
                    },
                  },
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
                    'grok-4.3',
                  },
                  default = 'grok-4.3',
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
          claude_code = function()
            return require('codecompanion.adapters').extend('claude_code', {
              env = {
                CLAUDE_CODE_OAUTH_TOKEN = 'CLAUDE_CODE_OAUTH_TOKEN',
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

    vim.api.nvim_create_user_command('PrivateAIReasoning', function(opts)
      if opts.args == '' then
        select_private_ai_reasoning_effort()
      else
        set_private_ai_reasoning_effort(opts.args)
      end
    end, {
      nargs = '?',
      complete = function() return private_ai_reasoning_choices end,
    })

    vim.api.nvim_create_autocmd({ 'BufEnter', 'DirChanged' }, {
      group = vim.api.nvim_create_augroup('codecompanion-project-context', { clear = true }),
      callback = sync_runtime_config,
    })
  end,
}
