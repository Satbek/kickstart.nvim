local uv = vim.uv or vim.loop

local M = {}

-- Shared project-detection helpers for local modules.
--
-- Root resolution intentionally stops at HOME by default:
--   - if a marker such as `.git` or `.hobby` is found, that wins
--   - otherwise the top-most directory directly under HOME becomes the root
--
-- This keeps per-project state stable even for ad-hoc personal folders that
-- are not repositories yet.

-- Default markers that define an explicit project root.
M.root_markers = { '.hobby', '.git', '.svn', '.hg' }

-- Markers that classify a project as "hobby".
M.hobby_markers = { '.hobby' }

local function normalize(path) return vim.fs.normalize(path) end

-- If we reached `stop_dir` without seeing an explicit marker, treat the
-- highest directory below `stop_dir` as the project root.
local function fallback_root_for_path(path, stop_dir)
  path = normalize(path)
  stop_dir = normalize(stop_dir)

  if path == stop_dir then return stop_dir end

  local root = path
  for parent in vim.fs.parents(path) do
    if parent == stop_dir then return root end
    root = parent
  end

  return path
end

---@class CustomProjectContext
---@field path string Normalized starting directory used for resolution.
---@field project_root string Stable resolved project root for the path.
---@field is_hobby boolean Whether a hobby marker exists above the path.

-- Return the most useful directory for a buffer:
--   - file buffer      -> parent directory of the file
--   - directory buffer -> that directory itself
--   - unnamed buffer   -> current working directory
---@param bufnr? integer
---@return string
function M.current_buffer_dir(bufnr)
  bufnr = bufnr or 0

  local bufname = vim.api.nvim_buf_get_name(bufnr)
  if bufname == '' then return normalize(vim.fn.getcwd()) end

  local stat = uv.fs_stat(bufname)
  if stat and stat.type == 'directory' then return normalize(bufname) end

  return normalize(vim.fs.dirname(bufname))
end

-- Walk upward from `path` until `stop_dir` and return the first matching path.
-- By default the search stops at HOME so personal directories do not collapse
-- into `/` when no explicit root marker exists yet.
---@param targets string|string[]
---@param path? string
---@param opts? { stop_dir?: string }
---@return string|nil
function M.find_upward(targets, path, opts)
  opts = opts or {}
  path = normalize(path or M.current_buffer_dir())

  local stop_dir = normalize(opts.stop_dir or uv.os_homedir())
  local found = vim.fs.find(targets, {
    upward = true,
    path = path,
    stop = stop_dir,
  })

  return found[1]
end

-- Resolve a stable project root for `path`.
--
-- Rules:
--   1. Search upward for a root marker such as `.git` or `.hobby`.
--   2. If a marker is found, use the directory that contains it.
--   3. If no marker is found before `stop_dir` (HOME by default), use the
--      top-most directory directly under `stop_dir`.
--
-- Example:
--   /home/user/some_dir/nested/file.lua -> /home/user/some_dir
--
-- This fallback is useful for personal folders that are not repositories yet
-- but still need stable per-project state like prompts, caches or settings.
---@param path? string
---@param opts? { markers?: string[], stop_dir?: string }
---@return string
function M.root(path, opts)
  opts = opts or {}
  path = normalize(path or M.current_buffer_dir())

  local markers = opts.markers or M.root_markers
  local stop_dir = normalize(opts.stop_dir or uv.os_homedir())
  local root_marker = M.find_upward(markers, path, { stop_dir = stop_dir })

  if root_marker then return normalize(vim.fs.dirname(root_marker)) end

  return fallback_root_for_path(path, stop_dir)
end

-- Return whether `path` belongs to a hobby project.
---@param path? string
---@param opts? { markers?: string[], stop_dir?: string }
---@return boolean
function M.is_hobby(path, opts)
  opts = opts or {}
  path = normalize(path or M.current_buffer_dir())

  local hobby_markers = opts.markers or M.hobby_markers
  local stop_dir = normalize(opts.stop_dir or uv.os_homedir())

  return M.find_upward(hobby_markers, path, { stop_dir = stop_dir }) ~= nil
end

-- Build a reusable project context for the current buffer or an explicit path.
-- The returned table is intentionally small so other modules can depend on it
-- without pulling in plugin-specific state.
---@param path? string
---@param opts? { markers?: string[], stop_dir?: string }
---@return CustomProjectContext
function M.context(path, opts)
  path = normalize(path or M.current_buffer_dir())

  return {
    path = path,
    project_root = M.root(path, opts),
    is_hobby = M.is_hobby(path, opts),
  }
end

return M
