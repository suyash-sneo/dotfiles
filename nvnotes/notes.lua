-- ============================================================================
-- Notes Vault Config
-- Target: Neovim 0.12.1+
-- Usage:  nvim -u /Users/sneo/dev/Sparda/notes.lua
--
-- This is a dedicated notes-only Neovim profile. It is intentionally separate
-- from a coding config and is optimized for:
--   - folder-first note organization
--   - fast note and folder creation
--   - markdown as the file model
--   - tree context plus fzf retrieval
--   - a clean UI with minimal IDE baggage
-- ============================================================================

local uv = vim.uv or vim.loop

-- Normalize all paths so the rest of the file can assume absolute, clean paths.
local function normalize_path(path)
  if not path or path == "" then
    return path
  end
  if path:sub(1, 1) == "~" then
    path = vim.fn.expand(path)
  end
  return vim.fs.normalize(path)
end

-- Soft version guard. The config may still work on nearby versions, but it is
-- written specifically for Neovim 0.12.1.
do
  local version = vim.version()
  if version.major == 0 and version.minor < 12 then
    vim.notify("This notes config targets Neovim 0.12.1+", vim.log.levels.WARN, { title = "Notes Vault" })
  end
end

-- Leader keys are set early because plugin setup and mappings depend on them.
vim.g.mapleader = "\\"
vim.g.maplocalleader = "\\"

-- Disable old markdown ftplugin recommendations; they tend to be too opinionated
-- for a raw-markdown editing workflow.
vim.g.markdown_recommended_style = 0

-- Help Vim's markdown highlighter understand fenced languages even before
-- Treesitter fully takes over.
vim.g.markdown_fenced_languages = {
  "bash=sh",
  "sh=sh",
  "zsh=sh",
  "json=json",
  "lua=lua",
  "vim=vim",
  "yaml=yaml",
  "toml=toml",
  "diff=diff",
}

-- ============================================================================
-- Core paths
-- ============================================================================

local vault_root = normalize_path("~/dev/Sparda")
local state_root = normalize_path(vim.fn.stdpath("state") .. "/notes-vault")

local Config = {
  vault = {
    root = vault_root,
    assets = normalize_path(vault_root .. "/assets"),
    images = normalize_path(vault_root .. "/assets/images"),
    daily = normalize_path(vault_root .. "/Daily Log"),
    quick = normalize_path(vault_root .. "/Temporal/Inbox"),
  },
  state = {
    root = state_root,
    undo_dir = normalize_path(state_root .. "/undo"),
    session = normalize_path(state_root .. "/session.vim"),
  },
  ui = {
    border = "rounded",
  },
}

-- ============================================================================
-- Utility helpers
-- ============================================================================

local Util = {}

function Util.notify(message, level)
  vim.notify(message, level or vim.log.levels.INFO, { title = "Notes Vault" })
end

function Util.normalize(path)
  return normalize_path(path)
end

function Util.path_join(...)
  local parts = { ... }
  return Util.normalize(table.concat(parts, "/"))
end

function Util.dirname(path)
  local dir = vim.fs.dirname(Util.normalize(path))
  return dir and Util.normalize(dir) or nil
end

function Util.file_exists(path)
  return vim.fn.filereadable(Util.normalize(path)) == 1
end

function Util.dir_exists(path)
  return vim.fn.isdirectory(Util.normalize(path)) == 1
end

-- Create a directory tree if it does not exist.
function Util.ensure_dir(path)
  path = Util.normalize(path)
  if not path or path == "" then
    return
  end
  if not Util.dir_exists(path) then
    vim.fn.mkdir(path, "p")
  end
end

function Util.ensure_paths(paths)
  for _, path in ipairs(paths) do
    Util.ensure_dir(path)
  end
end

-- Check whether a path lives inside the configured vault root. This is used to
-- keep search, creation, and relative-link logic anchored to the vault.
function Util.inside_vault(path)
  path = Util.normalize(path)
  local root = Config.vault.root
  return path == root or path:sub(1, #root + 1) == root .. "/"
end

function Util.split_path(path)
  local parts = {}
  for part in Util.normalize(path):gmatch("[^/]+") do
    table.insert(parts, part)
  end
  return parts
end

-- Compute a relative path manually. This is used for image links so the link is
-- portable if the note moves with its folder structure preserved.
function Util.relative_path(from_dir, to_path)
  from_dir = Util.normalize(from_dir)
  to_path = Util.normalize(to_path)

  local from_parts = Util.split_path(from_dir)
  local to_parts = Util.split_path(to_path)

  local index = 1
  while from_parts[index] and to_parts[index] and from_parts[index] == to_parts[index] do
    index = index + 1
  end

  local rel = {}
  for _ = index, #from_parts do
    table.insert(rel, "..")
  end
  for i = index, #to_parts do
    table.insert(rel, to_parts[i])
  end

  if #rel == 0 then
    return "."
  end

  return table.concat(rel, "/")
end

-- Show vault-local paths in messages when possible; it is less noisy than a
-- full absolute path.
function Util.display_path(path)
  path = Util.normalize(path)
  if not path then
    return ""
  end
  if Util.inside_vault(path) then
    local rel = Util.relative_path(Config.vault.root, path)
    return rel == "." and "/" or rel
  end
  return path
end

-- Return the current buffer's real file path, ignoring unnamed, terminal, and
-- special buffers.
function Util.current_buffer_path()
  local name = vim.api.nvim_buf_get_name(0)
  if name == "" or name:match("^%w+://") or vim.bo.buftype ~= "" then
    return nil
  end
  return Util.normalize(name)
end

-- Prefer the directory of the current note; otherwise fall back to the current
-- working directory if it is inside the vault; otherwise use vault root.
function Util.current_buffer_dir()
  local path = Util.current_buffer_path()
  if path then
    return Util.dirname(path)
  end
  local cwd = Util.normalize(vim.fn.getcwd())
  if Util.inside_vault(cwd) then
    return cwd
  end
  return Config.vault.root
end

-- Insert a string at the exact cursor position without switching modes.
function Util.insert_text_at_cursor(text)
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  vim.api.nvim_buf_set_text(0, row - 1, col, row - 1, col, { text })
  vim.api.nvim_win_set_cursor(0, { row, col + #text })
end

function Util.replace_line_range(bufnr, start_line, end_line, lines)
  vim.api.nvim_buf_set_lines(bufnr, start_line - 1, end_line, false, lines)
end

-- Common missing-tool checker for shell-backed helpers such as jq and pngpaste.
function Util.require_executable(binary, hint)
  if vim.fn.executable(binary) == 1 then
    return true
  end
  local message = ("%s is required"):format(binary)
  if hint and hint ~= "" then
    message = message .. ". " .. hint
  end
  Util.notify(message, vim.log.levels.ERROR)
  return false
end

-- Preserve indentation when formatting JSON ranges taken from markdown or list
-- contexts.
function Util.common_indent(lines)
  local indent
  for _, line in ipairs(lines) do
    if line:match("%S") then
      local current = line:match("^(%s*)") or ""
      if indent == nil then
        indent = current
      else
        local max = math.min(#indent, #current)
        local i = 1
        while i <= max and indent:sub(i, i) == current:sub(i, i) do
          i = i + 1
        end
        indent = indent:sub(1, i - 1)
      end
    end
  end
  return indent or ""
end

function Util.strip_indent(lines, indent)
  if indent == "" then
    return vim.deepcopy(lines)
  end
  local stripped = {}
  for _, line in ipairs(lines) do
    if line:sub(1, #indent) == indent then
      table.insert(stripped, line:sub(#indent + 1))
    else
      table.insert(stripped, line)
    end
  end
  return stripped
end

function Util.add_indent(lines, indent)
  if indent == "" then
    return lines
  end
  local prefixed = {}
  for _, line in ipairs(lines) do
    if line == "" then
      table.insert(prefixed, "")
    else
      table.insert(prefixed, indent .. line)
    end
  end
  return prefixed
end

-- Read the active visual selection in a way that works for JSON helpers and
-- text wrapping helpers.
function Util.get_visual_selection()
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")
  local mode = vim.fn.visualmode()

  local srow, scol = start_pos[2], start_pos[3]
  local erow, ecol = end_pos[2], end_pos[3]

  if srow == 0 or erow == 0 then
    return nil
  end

  if srow > erow or (srow == erow and scol > ecol) then
    srow, erow = erow, srow
    scol, ecol = ecol, scol
  end

  local last_line = vim.api.nvim_buf_get_lines(0, erow - 1, erow, false)[1] or ""
  if mode == "V" then
    scol = 1
    ecol = #last_line
  else
    ecol = math.min(ecol, #last_line)
  end

  return {
    start_row = srow,
    start_col = math.max(scol, 1),
    end_row = erow,
    end_col = math.max(ecol, 0),
    mode = mode,
  }
end

-- Make sure the expected vault/state directories exist before plugin setup and
-- before any feature tries to write to them.
Util.ensure_paths({
  Config.vault.root,
  Config.vault.assets,
  Config.vault.images,
  Config.vault.daily,
  Config.state.root,
  Config.state.undo_dir,
})

-- ============================================================================
-- General editor options
-- ============================================================================

vim.opt.expandtab = true
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.softtabstop = 2

vim.opt.hidden = true
vim.opt.number = true
vim.opt.relativenumber = false
vim.opt.termguicolors = true
vim.opt.undofile = true
vim.opt.undodir = Config.state.undo_dir
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.wildmode = "longest:full,full"
vim.opt.wrap = false
vim.opt.linebreak = false
vim.opt.breakindent = true
vim.opt.mouse = "a"
vim.opt.scrolloff = 8
vim.opt.sidescrolloff = 8
vim.opt.joinspaces = false
vim.opt.splitright = true
vim.opt.splitbelow = true
vim.opt.clipboard = "unnamedplus"
vim.opt.confirm = true
vim.opt.cursorline = true
vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.writebackup = false
vim.opt.showmode = false
vim.opt.laststatus = 3
vim.opt.signcolumn = "yes:1"
vim.opt.fillchars = { eob = " " }
vim.opt.conceallevel = 0
vim.opt.autoread = true
vim.opt.foldenable = false
vim.opt.updatetime = 200
vim.opt.timeoutlen = 300
vim.opt.completeopt = { "menu", "menuone", "noselect" }
vim.opt.shortmess:append("Ic")
vim.opt.wildignorecase = true

-- Session is scoped to this profile because the session file lives under a
-- notes-only state directory.
vim.opt.sessionoptions = {
  "buffers",
  "curdir",
  "folds",
  "help",
  "localoptions",
  "tabpages",
  "winsize",
}

-- Newer Neovim supports a global default border for UI windows.
pcall(function()
  vim.opt.winborder = Config.ui.border
end)

-- ============================================================================
-- Feature modules
-- Each feature is kept in a local table so the file stays modular even though
-- everything lives in one init-like script.
-- ============================================================================

local Tree = {}
local Search = {}
local Notes = {}
local Markdown = {}
local Json = {}
local Screenshot = {}
local Wrap = {}
local Terminal = { buf = nil, win = nil }
local Session = { restored = false }

-- ============================================================================
-- Neo-tree helpers
-- ============================================================================

-- Detect whether any Neo-tree window is currently open.
function Tree.has_window()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].filetype == "neo-tree" then
      return true
    end
  end
  return false
end

-- Try to derive the "current folder context" from Neo-tree selection. If the
-- selected node is a file, return its parent directory. If the API lookup fails,
-- return nil and let higher-level fallbacks take over.
function Tree.selected_dir()
  if vim.bo.filetype ~= "neo-tree" and not Tree.has_window() then
    return nil
  end

  local ok, manager = pcall(require, "neo-tree.sources.manager")
  if not ok then
    return nil
  end

  local state
  if vim.bo.filetype == "neo-tree" then
    local ok_state, result = pcall(manager.get_state_for_window)
    if ok_state then
      state = result
    end
  else
    local ok_state, result = pcall(manager.get_state, "filesystem")
    if ok_state then
      state = result
    end
  end

  if not state then
    return nil
  end

  if state.tree then
    local ok_node, node = pcall(state.tree.get_node, state.tree)
    if ok_node and node then
      local path = node.get_id and node:get_id() or node.path
      if not path then
        return nil
      end
      path = Util.normalize(path)
      if node.type == "directory" then
        return path
      end
      if node.get_parent_id then
        local parent = node:get_parent_id()
        if parent then
          return Util.normalize(parent)
        end
      end
      return Util.dirname(path)
    end
  end

  if state.path then
    return Util.normalize(state.path)
  end

  return nil
end

-- Best-effort path resolution for note creation:
--   1. selected Neo-tree folder
--   2. current note's directory
--   3. cwd if it is inside the vault
--   4. vault root
function Tree.best_target_dir()
  local selected = Tree.selected_dir()
  if selected and Util.inside_vault(selected) then
    return selected
  end

  local current_dir = Util.current_buffer_dir()
  if current_dir and Util.inside_vault(current_dir) then
    return current_dir
  end

  local cwd = Util.normalize(vim.fn.getcwd())
  if Util.inside_vault(cwd) then
    return cwd
  end

  return Config.vault.root
end

function Tree.refresh()
  local ok, manager = pcall(require, "neo-tree.sources.manager")
  if ok then
    pcall(manager.refresh, "filesystem")
  end
end

function Tree.open_float()
  local current = Util.current_buffer_path()
  if current and Util.inside_vault(current) then
    vim.cmd("Neotree toggle source=filesystem reveal position=float")
    return
  end
  vim.cmd("Neotree toggle source=filesystem position=float dir=" .. vim.fn.fnameescape(Tree.best_target_dir()))
end

function Tree.open_sidebar()
  local current = Util.current_buffer_path()
  if current and Util.inside_vault(current) then
    vim.cmd("Neotree toggle source=filesystem reveal position=left")
    return
  end
  vim.cmd("Neotree toggle source=filesystem position=left dir=" .. vim.fn.fnameescape(Tree.best_target_dir()))
end

function Tree.reveal_current()
  local current = Util.current_buffer_path()
  if current and Util.inside_vault(current) then
    vim.cmd("Neotree source=filesystem reveal position=float")
    return
  end
  vim.cmd("Neotree source=filesystem position=float dir=" .. vim.fn.fnameescape(Tree.best_target_dir()))
end

function Tree.jump_root()
  pcall(vim.cmd, "cd " .. vim.fn.fnameescape(Config.vault.root))
  vim.cmd("Neotree source=filesystem position=float dir=" .. vim.fn.fnameescape(Config.vault.root))
end

-- ============================================================================
-- fzf-lua helpers
-- ============================================================================

-- Guard search workflows with clear missing-tool messages.
function Search.require_fzf(needs_rg)
  if vim.fn.executable("fzf") == 0 and vim.fn.executable("fzf-tmux") == 0 and vim.fn.executable("sk") == 0 then
    Util.notify("fzf-lua needs fzf (or skim) on your PATH. Install it with: brew install fzf", vim.log.levels.ERROR)
    return nil
  end
  if needs_rg and vim.fn.executable("rg") == 0 then
    Util.notify("ripgrep is required for content search. Install it with: brew install ripgrep", vim.log.levels.ERROR)
    return nil
  end
  local ok, fzf = pcall(require, "fzf-lua")
  if not ok then
    Util.notify("fzf-lua is unavailable", vim.log.levels.ERROR)
    return nil
  end
  return fzf
end

function Search.files(cwd, prompt)
  local fzf = Search.require_fzf(false)
  if not fzf then
    return
  end
  cwd = Util.normalize(cwd or Config.vault.root)
  if vim.fn.isdirectory(cwd) == 0 then
    cwd = Config.vault.root
  end
  fzf.files({
    cwd = cwd,
    prompt = prompt or "Files> ",
  })
end

function Search.grep(cwd, prompt)
  local fzf = Search.require_fzf(true)
  if not fzf then
    return
  end
  cwd = Util.normalize(cwd or Config.vault.root)
  if vim.fn.isdirectory(cwd) == 0 then
    cwd = Config.vault.root
  end
  fzf.live_grep({
    cwd = cwd,
    prompt = prompt or "Grep> ",
  })
end

function Search.buffers()
  local fzf = Search.require_fzf(false)
  if not fzf then
    return
  end
  fzf.buffers()
end

function Search.resume()
  local fzf = Search.require_fzf(false)
  if not fzf then
    return
  end
  fzf.resume()
end

-- ============================================================================
-- Note and folder creation helpers
-- ============================================================================

-- Resolve relative user input against a base directory. Files default to
-- markdown if the user omits an extension.
function Notes.resolve_input_path(base_dir, input, force_markdown)
  local value = vim.trim(input)
  local path
  if value:match("^/") or value:match("^~") then
    path = Util.normalize(value)
  else
    path = Util.path_join(base_dir, value)
  end
  if force_markdown and not path:match("%.[^/]+$") then
    path = path .. ".md"
  end
  return Util.normalize(path)
end

-- Create a note if needed, then open it. New notes can be initialized with
-- starter content such as a daily heading.
function Notes.create_or_open(path, initial_lines)
  path = Util.normalize(path)

  if Util.dir_exists(path) then
    Util.notify("Cannot open note because this path is a directory: " .. Util.display_path(path), vim.log.levels.ERROR)
    return
  end

  Util.ensure_dir(Util.dirname(path))

  local is_new = not Util.file_exists(path)
  if is_new then
    vim.fn.writefile(initial_lines or { "" }, path)
  end

  vim.cmd("edit " .. vim.fn.fnameescape(path))

  if is_new then
    local last = vim.api.nvim_buf_line_count(0)
    vim.api.nvim_win_set_cursor(0, { last, 0 })
    vim.schedule(function()
      if vim.bo.buftype == "" then
        pcall(vim.cmd, "startinsert")
      end
    end)
  end

  Tree.refresh()
end

function Notes.new_note(base_dir, default_name)
  local target_dir = Util.normalize(base_dir or Tree.best_target_dir())
  vim.ui.input({
    prompt = ("New note in %s: "):format(Util.display_path(target_dir)),
    default = default_name or "",
  }, function(input)
    if not input or vim.trim(input) == "" then
      return
    end
    local path = Notes.resolve_input_path(target_dir, input, true)
    Notes.create_or_open(path, { "" })
  end)
end

function Notes.new_note_here()
  Notes.new_note(Util.current_buffer_dir())
end

function Notes.new_folder(base_dir)
  local target_dir = Util.normalize(base_dir or Tree.best_target_dir())
  vim.ui.input({
    prompt = ("New folder in %s: "):format(Util.display_path(target_dir)),
    default = "",
  }, function(input)
    if not input or vim.trim(input) == "" then
      return
    end

    local path = Notes.resolve_input_path(target_dir, input, false)
    if Util.file_exists(path) then
      Util.notify("A file already exists at " .. Util.display_path(path), vim.log.levels.ERROR)
      return
    end

    Util.ensure_dir(path)
    Tree.refresh()
    Util.notify("Created folder: " .. Util.display_path(path))
  end)
end

function Notes.quick_note()
  Util.ensure_dir(Config.vault.quick)
  Notes.new_note(Config.vault.quick, "note-" .. os.date("%Y-%m-%d_%H-%M-%S"))
end

-- Daily logs live in: Daily Log/YYYY/MM/YYYY-MM-DD.md
function Notes.today_daily()
  local day = os.date("%Y-%m-%d")
  local year = os.date("%Y")
  local month = os.date("%m")
  local dir = Util.path_join(Config.vault.daily, year, month)
  local path = Util.path_join(dir, day .. ".md")

  Util.ensure_dir(dir)
  Notes.create_or_open(path, {
    "# " .. day,
    "",
  })
end

function Notes.insert_timestamp_heading()
  local heading = "## " .. os.date("%H:%M")
  local row = vim.api.nvim_win_get_cursor(0)[1]
  local line = vim.api.nvim_get_current_line()

  if line == "" then
    vim.api.nvim_buf_set_lines(0, row - 1, row, false, {
      heading,
      "",
    })
    vim.api.nvim_win_set_cursor(0, { row + 1, 0 })
  else
    vim.api.nvim_buf_set_lines(0, row, row, false, {
      "",
      heading,
      "",
    })
    vim.api.nvim_win_set_cursor(0, { row + 3, 0 })
  end

  vim.cmd.startinsert()
end

-- ============================================================================
-- Markdown and code-fence helpers
-- ============================================================================

-- Support both ``` and ~~~ fences. Language is optional.
local function parse_fence(line)
  local fence, lang = line:match("^%s*(```+)%s*([%w_+-]*)%s*$")
  if fence then
    return fence, lang or ""
  end
  fence, lang = line:match("^%s*(~~~+)%s*([%w_+-]*)%s*$")
  if fence then
    return fence, lang or ""
  end
  return nil, nil
end

-- Find the fence block containing the cursor. This powers "copy current code
-- block" and "format current JSON block".
function Markdown.current_fence()
  local total = vim.api.nvim_buf_line_count(0)
  local cursor_row = vim.api.nvim_win_get_cursor(0)[1]
  local lines = vim.api.nvim_buf_get_lines(0, 0, total, false)
  local active

  for i, line in ipairs(lines) do
    local fence, lang = parse_fence(line)
    if fence then
      if not active then
        active = {
          fence = fence,
          lang = (lang or ""):lower(),
          start_line = i,
        }
      elseif fence == active.fence then
        local block = {
          start_line = active.start_line,
          end_line = i,
          lang = active.lang,
          content_start = active.start_line + 1,
          content_end = i - 1,
        }
        if cursor_row >= block.start_line and cursor_row <= block.end_line then
          return block
        end
        active = nil
      end
    end
  end

  return nil
end

-- Insert a fenced block and place the cursor on the blank line inside it.
function Markdown.insert_fence(lang)
  local row = vim.api.nvim_win_get_cursor(0)[1]
  local line = vim.api.nvim_get_current_line()
  local opener = "```" .. (lang or "")
  local block = {
    opener,
    "",
    "```",
  }

  if line == "" then
    vim.api.nvim_buf_set_lines(0, row - 1, row, false, block)
    vim.api.nvim_win_set_cursor(0, { row + 1, 0 })
  else
    vim.api.nvim_buf_set_lines(0, row, row, false, block)
    vim.api.nvim_win_set_cursor(0, { row + 2, 0 })
  end

  vim.cmd.startinsert()
end

function Markdown.copy_current_fence()
  local fence = Markdown.current_fence()
  if not fence then
    Util.notify("Cursor is not inside a fenced code block", vim.log.levels.WARN)
    return
  end

  local lines = vim.api.nvim_buf_get_lines(0, fence.start_line - 1, fence.end_line, false)
  local text = table.concat(lines, "\n")
  vim.fn.setreg("+", text)
  vim.fn.setreg('"', text)
  Util.notify("Copied fenced code block")
end

-- Render-markdown is installed but deliberately off by default; this function
-- gives a raw-markdown-first workflow with an optional pretty view.
function Markdown.toggle_render()
  if vim.bo.filetype ~= "markdown" then
    Util.notify("Markdown rendering only applies to markdown buffers", vim.log.levels.INFO)
    return
  end

  local ok, render = pcall(require, "render-markdown")
  if not ok then
    Util.notify("render-markdown.nvim is unavailable", vim.log.levels.ERROR)
    return
  end

  render.buf_toggle()
end

-- ============================================================================
-- JSON helpers
-- ============================================================================

-- Run jq in format or compact mode.
function Json.run_jq(input, compact)
  if not Util.require_executable("jq", "Install it with: brew install jq") then
    return nil
  end

  local command = compact and { "jq", "-c", "." } or { "jq", "." }
  local result = vim.system(command, {
    text = true,
    stdin = input,
  }):wait()

  if result.code ~= 0 then
    local message = vim.trim(result.stderr or "")
    if message == "" then
      message = "jq failed"
    end
    Util.notify(message, vim.log.levels.ERROR)
    return nil
  end

  return result.stdout or ""
end

function Json.transform_lines(lines, compact)
  local indent = Util.common_indent(lines)
  local raw_lines = Util.strip_indent(lines, indent)
  local output = Json.run_jq(table.concat(raw_lines, "\n"), compact)
  if not output then
    return nil
  end

  output = output:gsub("\n$", "")
  local out_lines = vim.split(output, "\n", { plain = true, trimempty = false })
  return Util.add_indent(out_lines, indent)
end

function Json.transform_range(start_line, end_line, compact)
  local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
  local transformed = Json.transform_lines(lines, compact)
  if not transformed then
    return
  end
  Util.replace_line_range(0, start_line, end_line, transformed)
end

function Json.transform_visual(compact)
  local selection = Util.get_visual_selection()
  if not selection then
    return
  end

  local lines = vim.api.nvim_buf_get_text(
    0,
    selection.start_row - 1,
    selection.start_col - 1,
    selection.end_row - 1,
    selection.end_col,
    {}
  )

  local transformed = Json.transform_lines(lines, compact)
  if not transformed then
    return
  end

  vim.api.nvim_buf_set_text(
    0,
    selection.start_row - 1,
    selection.start_col - 1,
    selection.end_row - 1,
    selection.end_col,
    transformed
  )
end

function Json.transform_current_fence(compact)
  local fence = Markdown.current_fence()
  if not fence then
    Util.notify("Cursor is not inside a fenced code block", vim.log.levels.WARN)
    return
  end

  if not fence.lang:match("^json") then
    Util.notify("Current fenced code block is not JSON", vim.log.levels.WARN)
    return
  end

  if fence.content_start > fence.content_end then
    Util.notify("Current JSON block is empty", vim.log.levels.WARN)
    return
  end

  local lines = vim.api.nvim_buf_get_lines(0, fence.content_start - 1, fence.content_end, false)
  local transformed = Json.transform_lines(lines, compact)
  if not transformed then
    return
  end

  Util.replace_line_range(0, fence.content_start, fence.content_end, transformed)
end

-- ============================================================================
-- Screenshot / image helpers
-- ============================================================================

-- Try to resolve the markdown image link target under the cursor.
function Screenshot.link_target_under_cursor()
  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2] + 1
  local start = 1

  while true do
    local s, e, target = line:find("!%b[]%((.-)%)", start)
    if not s then
      break
    end

    local open_paren = line:find("%(", s)
    local close_paren = line:find("%)", open_paren + 1)
    if open_paren and close_paren and col >= open_paren + 1 and col <= close_paren - 1 then
      target = target:gsub("^<", ""):gsub(">$", "")
      return target
    end

    start = e + 1
  end

  local cfile = vim.fn.expand("<cfile>")
  if cfile ~= "" then
    return cfile
  end

  return nil
end

-- macOS clipboard image import using pngpaste.
-- The saved file lands in assets/images with a timestamp name, and a relative
-- markdown link is either inserted at the cursor or copied to the clipboard.
function Screenshot.save_from_clipboard(copy_only)
  if vim.fn.has("macunix") ~= 1 then
    Util.notify("Clipboard image import is macOS-only", vim.log.levels.WARN)
    return
  end

  if not Util.require_executable("pngpaste", "Install it with: brew install pngpaste") then
    return
  end

  Util.ensure_dir(Config.vault.images)

  local filename = os.date("%Y-%m-%d_%H-%M-%S") .. ".png"
  local image_path = Util.path_join(Config.vault.images, filename)

  local result = vim.system({ "pngpaste", image_path }, { text = true }):wait()
  if result.code ~= 0 then
    local message = vim.trim(result.stderr or "")
    if message == "" then
      message = "Clipboard does not contain an image"
    end
    Util.notify(message, vim.log.levels.ERROR)
    return
  end

  local base_dir = Util.current_buffer_dir()
  if not Util.inside_vault(base_dir) then
    base_dir = Config.vault.root
  end

  local rel = Util.relative_path(base_dir, image_path)
  local link = "![](" .. rel .. ")"

  if copy_only then
    vim.fn.setreg("+", link)
    vim.fn.setreg('"', link)
    Util.notify("Screenshot saved and link copied: " .. rel)
    return
  end

  Util.insert_text_at_cursor(link)
  Util.notify("Screenshot saved: " .. rel)
end

function Screenshot.open_under_cursor()
  if vim.fn.has("macunix") ~= 1 then
    Util.notify("Opening images is macOS-only", vim.log.levels.WARN)
    return
  end

  local target = Screenshot.link_target_under_cursor()
  if not target then
    Util.notify("No image path found under cursor", vim.log.levels.WARN)
    return
  end

  local full_path = target
  if target:sub(1, 1) ~= "/" then
    full_path = Util.path_join(Util.current_buffer_dir(), target)
  end

  full_path = Util.normalize(full_path)
  if not Util.file_exists(full_path) then
    Util.notify("Image not found: " .. full_path, vim.log.levels.ERROR)
    return
  end

  vim.fn.jobstart({ "open", full_path }, { detach = true })
end

-- ============================================================================
-- Simple surround/wrapping helpers
-- ============================================================================

function Wrap.visual(left, right)
  local selection = Util.get_visual_selection()
  if not selection then
    return
  end

  vim.api.nvim_buf_set_text(
    0,
    selection.end_row - 1,
    selection.end_col,
    selection.end_row - 1,
    selection.end_col,
    { right }
  )
  vim.api.nvim_buf_set_text(
    0,
    selection.start_row - 1,
    selection.start_col - 1,
    selection.start_row - 1,
    selection.start_col - 1,
    { left }
  )
end

function Wrap.word(left, right)
  vim.cmd("normal! viw")
  vim.schedule(function()
    Wrap.visual(left, right)
  end)
end

-- ============================================================================
-- Built-in floating terminal
-- ============================================================================

function Terminal.layout()
  local max_width = math.max(20, vim.o.columns - 4)
  local max_height = math.max(8, vim.o.lines - 4)
  local width = math.min(max_width, math.max(60, math.floor(vim.o.columns * 0.88)))
  local height = math.min(max_height, math.max(12, math.floor(vim.o.lines * 0.30)))

  return {
    relative = "editor",
    style = "minimal",
    border = Config.ui.border,
    width = width,
    height = height,
    row = math.max(1, math.floor((vim.o.lines - height) / 2) - 1),
    col = math.floor((vim.o.columns - width) / 2),
  }
end

function Terminal.open()
  if Terminal.win and vim.api.nvim_win_is_valid(Terminal.win) then
    vim.api.nvim_set_current_win(Terminal.win)
    vim.cmd.startinsert()
    return
  end

  if not (Terminal.buf and vim.api.nvim_buf_is_valid(Terminal.buf)) then
    Terminal.buf = vim.api.nvim_create_buf(false, false)
    vim.bo[Terminal.buf].bufhidden = "hide"
  end

  Terminal.win = vim.api.nvim_open_win(Terminal.buf, true, Terminal.layout())
  vim.wo[Terminal.win].number = false
  vim.wo[Terminal.win].relativenumber = false
  vim.wo[Terminal.win].signcolumn = "no"
  vim.wo[Terminal.win].cursorline = false
  vim.wo[Terminal.win].wrap = false

  if vim.bo[Terminal.buf].buftype ~= "terminal" then
    vim.fn.termopen(vim.o.shell)
  end

  vim.cmd.startinsert()
end

function Terminal.close()
  if Terminal.win and vim.api.nvim_win_is_valid(Terminal.win) then
    pcall(vim.api.nvim_win_close, Terminal.win, true)
  end
  Terminal.win = nil
end

function Terminal.toggle()
  if Terminal.win and vim.api.nvim_win_is_valid(Terminal.win) then
    Terminal.close()
  else
    Terminal.open()
  end
end

function Terminal.toggle_from_terminal()
  local keys = vim.api.nvim_replace_termcodes("<C-\\><C-n>", true, false, true)
  vim.api.nvim_feedkeys(keys, "n", false)
  vim.schedule(function()
    Terminal.toggle()
  end)
end

-- ============================================================================
-- Session save/restore
-- ============================================================================

-- Before writing a session, close or hide transient UI that should not be
-- captured as the main editing state.
function Session.prepare_save()
  Terminal.close()

  local wins = vim.api.nvim_list_wins()
  if #wins == 1 then
    local buf = vim.api.nvim_win_get_buf(wins[1])
    if vim.bo[buf].filetype == "neo-tree" then
      vim.cmd.enew()
    end
  end

  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].filetype == "neo-tree" then
      pcall(vim.api.nvim_win_close, win, true)
    end
  end
end

function Session.save()
  Session.prepare_save()
  local ok, err = pcall(function()
    vim.cmd("silent! mksession! " .. vim.fn.fnameescape(Config.state.session))
  end)
  if not ok then
    Util.notify("Failed to save session: " .. tostring(err), vim.log.levels.WARN)
  end
end

function Session.restore()
  if vim.fn.argc() > 0 then
    return false
  end

  if vim.fn.filereadable(Config.state.session) == 0 then
    return false
  end

  local ok, err = pcall(function()
    vim.cmd("silent! source " .. vim.fn.fnameescape(Config.state.session))
  end)
  if not ok then
    Util.notify("Failed to restore session: " .. tostring(err), vim.log.levels.WARN)
    return false
  end

  Session.restored = true
  return true
end

function Session.open_default()
  pcall(vim.cmd, "cd " .. vim.fn.fnameescape(Config.vault.root))
  if vim.api.nvim_buf_get_name(0) ~= "" then
    vim.cmd.enew()
  end
end

-- ============================================================================
-- lazy.nvim bootstrap
-- ============================================================================

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not uv.fs_stat(lazypath) then
  local out = vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
  if vim.v.shell_error ~= 0 then
    error("Failed to clone lazy.nvim:\n" .. out)
  end
end
vim.opt.rtp:prepend(lazypath)

-- ============================================================================
-- Plugin setup
-- ============================================================================

require("lazy").setup({
  {
    -- Theme: readable, calm, and good for both markdown and fenced code.
    "rebelot/kanagawa.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      require("kanagawa").setup({
        commentStyle = { italic = false },
        keywordStyle = { italic = false },
        statementStyle = { bold = false },
        transparent = false,
        dimInactive = false,
        terminalColors = true,
        theme = "wave",
      })
      vim.cmd.colorscheme("kanagawa-wave")
    end,
  },
  {
    -- Shared Lua utility library used by several plugins.
    "nvim-lua/plenary.nvim",
    lazy = true,
  },
  {
    -- File icons for tree and picker UI.
    "nvim-tree/nvim-web-devicons",
    lazy = true,
  },
  {
    -- UI primitives used by Neo-tree.
    "MunifTanjim/nui.nvim",
    lazy = true,
  },
  {
    -- Tree-based filesystem navigation and creation workflow.
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    cmd = "Neotree",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
      "nvim-tree/nvim-web-devicons",
    },
    config = function()
      require("neo-tree").setup({
        close_if_last_window = false,
        popup_border_style = Config.ui.border,
        enable_git_status = false,
        enable_diagnostics = false,
        sort_case_insensitive = true,
        default_component_configs = {
          indent = {
            with_markers = false,
            indent_size = 2,
            padding = 1,
          },
          modified = {
            symbol = "*",
          },
        },
        filesystem = {
          bind_to_cwd = false,
          follow_current_file = {
            enabled = false,
          },
          group_empty_dirs = false,
          use_libuv_file_watcher = true,
          hijack_netrw_behavior = "open_default",
          filtered_items = {
            hide_dotfiles = false,
            hide_gitignored = true,
            hide_hidden = false,
            hide_by_name = { ".DS_Store" },
          },
          window = {
            position = "float",
            width = 42,
            mappings = {
              ["<cr>"] = "open",
              ["l"] = "open",
              ["h"] = "close_node",
              ["<bs>"] = "navigate_up",
              ["a"] = "add",
              ["A"] = "add_directory",
              ["d"] = "delete",
              ["r"] = "rename",
              ["m"] = "move",
              ["y"] = "copy_to_clipboard",
              ["p"] = "paste_from_clipboard",
              ["/"] = "fuzzy_finder",
              ["H"] = "toggle_hidden",
              ["."] = "set_root",
              ["<leader>nn"] = "add",
              ["<leader>nN"] = "add_directory",
            },
          },
        },
      })
    end,
  },
  {
    -- Fast file and content retrieval with path-aware display.
    "ibhagwan/fzf-lua",
    cmd = "FzfLua",
    dependencies = {
      "nvim-tree/nvim-web-devicons",
    },
    config = function()
      require("fzf-lua").setup({
        "default-title",
        winopts = {
          height = 0.90,
          width = 0.92,
          preview = {
            layout = "vertical",
          },
        },
        files = {
          prompt = "Files> ",
          cwd_prompt = true,
          hidden = true,
          formatter = "path.filename_first",
        },
        grep = {
          prompt = "Grep> ",
          cwd_prompt = true,
          hidden = true,
          formatter = "path.filename_first",
        },
        buffers = {
          prompt = "Buffers> ",
          sort_lastused = true,
          show_unloaded = true,
        },
      })
    end,
  },
  {
    -- Treesitter provides the main syntax quality for markdown and code fences.
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    lazy = false,
    build = function()
      if vim.fn.executable("tree-sitter") == 1 then
        vim.cmd("TSUpdate")
      else
        vim.notify(
          "Skipping Treesitter parser install because the tree-sitter CLI is missing. Install it with: brew install tree-sitter-cli",
          vim.log.levels.WARN,
          { title = "Notes Vault" }
        )
      end
    end,
    config = function()
      local ok, ts = pcall(require, "nvim-treesitter")
      if not ok then
        return
      end

      ts.setup({
        install_dir = vim.fn.stdpath("data") .. "/site",
      })

      if vim.fn.executable("tree-sitter") == 1 then
        pcall(ts.install, {
          "markdown",
          "markdown_inline",
          "bash",
          "json",
          "lua",
          "vim",
          "yaml",
          "toml",
          "diff",
        })
      else
        vim.schedule(function()
          Util.notify(
            "Treesitter parsers were not installed because the tree-sitter CLI is missing. Install it with: brew install tree-sitter-cli",
            vim.log.levels.WARN
          )
        end)
      end

      pcall(vim.treesitter.language.register, "bash", "sh")
      pcall(vim.treesitter.language.register, "bash", "zsh")
    end,
  },
  {
    -- Optional pretty markdown rendering. Installed but disabled by default so
    -- raw markdown remains the editing mode.
    "MeanderingProgrammer/render-markdown.nvim",
    ft = { "markdown" },
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "nvim-tree/nvim-web-devicons",
    },
    config = function()
      require("render-markdown").setup({
        enabled = false,
        render_modes = { "n", "c", "t" },
      })
    end,
  },
  {
    -- Simple auto-pairing for brackets, quotes, braces, and backticks.
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    config = function()
      require("nvim-autopairs").setup({
        disable_filetype = { "neo-tree", "TelescopePrompt", "prompt" },
      })
    end,
  },
}, {
  install = {
    colorscheme = { "kanagawa" },
  },
  checker = {
    enabled = false,
  },
  change_detection = {
    notify = false,
  },
})

-- ============================================================================
-- Autocommands
-- ============================================================================

-- Prose-friendly defaults only in markdown/text buffers.
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "markdown", "text" },
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.linebreak = true
    vim.opt_local.breakindent = true
    vim.opt_local.spell = true
    vim.opt_local.spelllang = "en_us"
    vim.opt_local.textwidth = 0
    vim.opt_local.conceallevel = 0
    vim.opt_local.colorcolumn = ""
    vim.opt_local.showbreak = "  "
    vim.opt_local.formatoptions:remove({ "c", "r", "o", "t" })
    vim.opt_local.formatoptions:append("n")
    vim.opt_local.formatoptions:append("j")
  end,
})

-- Start Treesitter explicitly for the note-related languages we care about.
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "markdown", "bash", "sh", "zsh", "json", "lua", "vim", "yaml", "toml", "diff" },
  callback = function(args)
    pcall(vim.treesitter.start, args.buf)
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = "neo-tree",
  callback = function()
    vim.opt_local.wrap = false
    vim.opt_local.spell = false
    vim.opt_local.number = false
    vim.opt_local.relativenumber = false
  end,
})

vim.api.nvim_create_autocmd("TermOpen", {
  callback = function(args)
    vim.opt_local.number = false
    vim.opt_local.relativenumber = false
    vim.opt_local.spell = false
    vim.opt_local.wrap = false
    vim.opt_local.signcolumn = "no"
    vim.keymap.set("t", "<Esc><Esc>", [[<C-\><C-n>]], {
      buffer = args.buf,
      silent = true,
      desc = "Leave terminal mode",
    })
  end,
})

-- Keep the floating terminal sized sensibly when the editor is resized.
vim.api.nvim_create_autocmd("VimResized", {
  callback = function()
    if Terminal.win and vim.api.nvim_win_is_valid(Terminal.win) then
      vim.api.nvim_win_set_config(Terminal.win, Terminal.layout())
    end
  end,
})

-- Restore the last notes session if present. Otherwise start at the vault root.
vim.api.nvim_create_autocmd("VimEnter", {
  once = true,
  callback = function()
    if not Session.restore() then
      Session.open_default()
    end
  end,
})

-- Save the notes-only session on clean exit.
vim.api.nvim_create_autocmd("VimLeavePre", {
  callback = function()
    if vim.v.dying == 0 then
      Session.save()
    end
  end,
})

-- ============================================================================
-- User commands
-- ============================================================================

vim.api.nvim_create_user_command("NotesTreeFloat", Tree.open_float, {
  desc = "Toggle Neo-tree in a float",
})

vim.api.nvim_create_user_command("NotesTreeSidebar", Tree.open_sidebar, {
  desc = "Toggle Neo-tree sidebar",
})

vim.api.nvim_create_user_command("NotesReveal", Tree.reveal_current, {
  desc = "Reveal current file in Neo-tree",
})

vim.api.nvim_create_user_command("NotesRoot", Tree.jump_root, {
  desc = "Jump to vault root",
})

vim.api.nvim_create_user_command("NotesNew", function()
  Notes.new_note(Tree.best_target_dir())
end, {
  desc = "Create a note in the selected or current folder",
})

vim.api.nvim_create_user_command("NotesNewHere", Notes.new_note_here, {
  desc = "Create a note beside the current buffer",
})

vim.api.nvim_create_user_command("NotesNewFolder", function()
  Notes.new_folder(Tree.best_target_dir())
end, {
  desc = "Create a folder in the selected or current folder",
})

vim.api.nvim_create_user_command("NotesQuick", Notes.quick_note, {
  desc = "Create a quick note in Temporal/Inbox",
})

vim.api.nvim_create_user_command("DailyToday", Notes.today_daily, {
  desc = "Open today's daily log",
})

vim.api.nvim_create_user_command("InsertTimestampHeading", Notes.insert_timestamp_heading, {
  desc = "Insert a timestamp heading",
})

vim.api.nvim_create_user_command("PasteScreenshot", function()
  Screenshot.save_from_clipboard(false)
end, {
  desc = "Paste clipboard image into assets/images and insert link",
})

vim.api.nvim_create_user_command("PasteScreenshotCopyLink", function()
  Screenshot.save_from_clipboard(true)
end, {
  desc = "Paste clipboard image into assets/images and copy link",
})

vim.api.nvim_create_user_command("OpenImageUnderCursor", Screenshot.open_under_cursor, {
  desc = "Open linked image under cursor with macOS open",
})

vim.api.nvim_create_user_command("ToggleMarkdownRender", Markdown.toggle_render, {
  desc = "Toggle render-markdown for the current buffer",
})

vim.api.nvim_create_user_command("InsertBashFence", function()
  Markdown.insert_fence("bash")
end, {
  desc = "Insert a bash fenced code block",
})

vim.api.nvim_create_user_command("InsertJsonFence", function()
  Markdown.insert_fence("json")
end, {
  desc = "Insert a JSON fenced code block",
})

vim.api.nvim_create_user_command("InsertCodeFence", function()
  Markdown.insert_fence("")
end, {
  desc = "Insert a generic fenced code block",
})

vim.api.nvim_create_user_command("CopyFence", Markdown.copy_current_fence, {
  desc = "Copy the current fenced code block",
})

vim.api.nvim_create_user_command("JsonFormat", function(cmd)
  Json.transform_range(cmd.line1, cmd.line2, false)
end, {
  range = true,
  desc = "Format JSON in the given line range using jq",
})

vim.api.nvim_create_user_command("JsonMinify", function(cmd)
  Json.transform_range(cmd.line1, cmd.line2, true)
end, {
  range = true,
  desc = "Minify JSON in the given line range using jq",
})

vim.api.nvim_create_user_command("JsonFenceFormat", function()
  Json.transform_current_fence(false)
end, {
  desc = "Format the current fenced JSON block using jq",
})

vim.api.nvim_create_user_command("JsonFenceMinify", function()
  Json.transform_current_fence(true)
end, {
  desc = "Minify the current fenced JSON block using jq",
})

vim.api.nvim_create_user_command("ToggleNotesTerminal", Terminal.toggle, {
  desc = "Toggle the floating notes terminal",
})

-- ============================================================================
-- Keymaps
-- ============================================================================

-- Old habit preserved: clear search highlight with Ctrl-h.
vim.keymap.set("n", "<C-h>", "<Cmd>nohlsearch<CR>", {
  silent = true,
  desc = "Clear search highlight",
})

-- Old habits preserved: jk / kj exit insert mode quickly.
vim.keymap.set("i", "jk", "<Esc>", {
  silent = true,
  desc = "Exit insert mode",
})

vim.keymap.set("i", "kj", "<Esc>", {
  silent = true,
  desc = "Exit insert mode",
})

-- Wrapped-line movement makes prose navigation feel natural.
vim.keymap.set("n", "j", function()
  return vim.v.count == 0 and "gj" or "j"
end, {
  expr = true,
  silent = true,
  desc = "Wrapped-line down",
})

vim.keymap.set("n", "k", function()
  return vim.v.count == 0 and "gk" or "k"
end, {
  expr = true,
  silent = true,
  desc = "Wrapped-line up",
})

vim.keymap.set("x", "j", function()
  return vim.v.count == 0 and "gj" or "j"
end, {
  expr = true,
  silent = true,
  desc = "Wrapped-line down",
})

vim.keymap.set("x", "k", function()
  return vim.v.count == 0 and "gk" or "k"
end, {
  expr = true,
  silent = true,
  desc = "Wrapped-line up",
})

-- Search: vault-wide defaults, plus scoped folder-context variants.
vim.keymap.set("n", "<leader>f", function()
  Search.files(Config.vault.root, "Vault Files> ")
end, {
  silent = true,
  desc = "Find files in the vault",
})

vim.keymap.set("n", "<leader>r", function()
  Search.grep(Config.vault.root, "Vault Grep> ")
end, {
  silent = true,
  desc = "Grep the vault",
})

vim.keymap.set("n", "<leader>b", Search.buffers, {
  silent = true,
  desc = "Search open buffers",
})

vim.keymap.set("n", "<leader>nf", function()
  Search.files(Tree.best_target_dir(), "Folder Files> ")
end, {
  silent = true,
  desc = "Find files in the current folder context",
})

vim.keymap.set("n", "<leader>nr", function()
  Search.grep(Tree.best_target_dir(), "Folder Grep> ")
end, {
  silent = true,
  desc = "Grep in the current folder context",
})

vim.keymap.set("n", "<leader>nR", Search.resume, {
  silent = true,
  desc = "Resume the previous picker",
})

-- Tree / folder-first workflow.
vim.keymap.set("n", "<leader>no", Tree.open_float, {
  silent = true,
  desc = "Toggle floating tree",
})

vim.keymap.set("n", "<leader>nO", Tree.open_sidebar, {
  silent = true,
  desc = "Toggle sidebar tree",
})

vim.keymap.set("n", "<leader>ne", Tree.reveal_current, {
  silent = true,
  desc = "Reveal current file in tree",
})

vim.keymap.set("n", "<leader>nv", Tree.jump_root, {
  silent = true,
  desc = "Jump to vault root",
})

vim.keymap.set("n", "<leader>nn", function()
  Notes.new_note(Tree.best_target_dir())
end, {
  silent = true,
  desc = "Create a new note in the selected/current folder",
})

vim.keymap.set("n", "<leader>nc", Notes.new_note_here, {
  silent = true,
  desc = "Create a new note beside the current buffer",
})

vim.keymap.set("n", "<leader>nN", function()
  Notes.new_folder(Tree.best_target_dir())
end, {
  silent = true,
  desc = "Create a new folder in the selected/current folder",
})

vim.keymap.set("n", "<leader>ni", Notes.quick_note, {
  silent = true,
  desc = "Create a quick inbox note",
})

vim.keymap.set("n", "<leader>nd", Notes.today_daily, {
  silent = true,
  desc = "Open today's daily log",
})

vim.keymap.set("n", "<leader>nt", Notes.insert_timestamp_heading, {
  silent = true,
  desc = "Insert a timestamp heading",
})

-- Screenshot and image workflow.
vim.keymap.set("n", "<leader>ns", function()
  Screenshot.save_from_clipboard(false)
end, {
  silent = true,
  desc = "Paste screenshot and insert markdown link",
})

vim.keymap.set("n", "<leader>nS", function()
  Screenshot.save_from_clipboard(true)
end, {
  silent = true,
  desc = "Paste screenshot and copy markdown link",
})

vim.keymap.set("n", "<leader>nI", Screenshot.open_under_cursor, {
  silent = true,
  desc = "Open image under cursor",
})

-- Raw markdown by default, rendered markdown on demand.
vim.keymap.set("n", "<leader>nm", Markdown.toggle_render, {
  silent = true,
  desc = "Toggle markdown rendering",
})

-- Code fence insertion / extraction helpers.
vim.keymap.set("n", "<leader>nba", function()
  Markdown.insert_fence("bash")
end, {
  silent = true,
  desc = "Insert a bash fenced block",
})

vim.keymap.set("n", "<leader>nbj", function()
  Markdown.insert_fence("json")
end, {
  silent = true,
  desc = "Insert a JSON fenced block",
})

vim.keymap.set("n", "<leader>nbc", function()
  Markdown.insert_fence("")
end, {
  silent = true,
  desc = "Insert a generic fenced block",
})

vim.keymap.set("n", "<leader>nby", Markdown.copy_current_fence, {
  silent = true,
  desc = "Copy the current fenced block",
})

-- JSON helpers: normal mode targets current fenced JSON; visual mode targets the
-- current visual selection.
vim.keymap.set("n", "<leader>njf", function()
  Json.transform_current_fence(false)
end, {
  silent = true,
  desc = "Format the current fenced JSON block",
})

vim.keymap.set("n", "<leader>njm", function()
  Json.transform_current_fence(true)
end, {
  silent = true,
  desc = "Minify the current fenced JSON block",
})

vim.keymap.set("x", "<leader>njf", function()
  Json.transform_visual(false)
end, {
  silent = true,
  desc = "Format selected JSON",
})

vim.keymap.set("x", "<leader>njm", function()
  Json.transform_visual(true)
end, {
  silent = true,
  desc = "Minify selected JSON",
})

-- Small built-in surround helper for square brackets.
vim.keymap.set("n", "<leader>nw", function()
  Wrap.word("[", "]")
end, {
  silent = true,
  desc = "Wrap current word in brackets",
})

vim.keymap.set("x", "<leader>nw", function()
  Wrap.visual("[", "]")
end, {
  silent = true,
  desc = "Wrap selection in brackets",
})

-- Floating terminal.
vim.keymap.set("n", "<F12>", Terminal.toggle, {
  silent = true,
  desc = "Toggle floating terminal",
})

vim.keymap.set("i", "<F12>", function()
  vim.cmd.stopinsert()
  Terminal.toggle()
end, {
  silent = true,
  desc = "Toggle floating terminal",
})

vim.keymap.set("t", "<F12>", Terminal.toggle_from_terminal, {
  silent = true,
  desc = "Toggle floating terminal",
})

vim.keymap.set("n", "<leader>nT", Terminal.toggle, {
  silent = true,
  desc = "Toggle floating terminal",
})

vim.keymap.set("i", "<leader>nT", function()
  vim.cmd.stopinsert()
  Terminal.toggle()
end, {
  silent = true,
  desc = "Toggle floating terminal",
})

vim.keymap.set("t", "<leader>nT", Terminal.toggle_from_terminal, {
  silent = true,
  desc = "Toggle floating terminal",
})

-- ============================================================================
-- Mapping summary
-- ============================================================================
-- <leader>f    Vault files
-- <leader>r    Vault grep
-- <leader>b    Buffers
-- <leader>nf   Current-folder files
-- <leader>nr   Current-folder grep
-- <leader>nR   Resume picker
-- <leader>no   Floating tree
-- <leader>nO   Sidebar tree
-- <leader>ne   Reveal current file in tree
-- <leader>nv   Jump to vault root
-- <leader>nn   New note in selected/current folder
-- <leader>nc   New note beside current buffer
-- <leader>nN   New folder in selected/current folder
-- <leader>ni   Quick inbox note
-- <leader>nd   Today's daily log
-- <leader>nt   Insert timestamp heading
-- <leader>ns   Paste screenshot and insert link
-- <leader>nS   Paste screenshot and copy link
-- <leader>nI   Open image under cursor
-- <leader>nm   Toggle rendered markdown
-- <leader>nba  Insert bash fenced block
-- <leader>nbj  Insert JSON fenced block
-- <leader>nbc  Insert generic fenced block
-- <leader>nby  Copy current fenced block
-- <leader>njf  Format current fenced JSON / selected JSON
-- <leader>njm  Minify current fenced JSON / selected JSON
-- <leader>nw   Wrap word or selection in brackets
-- <leader>nT   Toggle floating terminal
-- <F12>        Toggle floating terminal
-- <C-h>        Clear search highlight
-- jk / kj      Escape insert mode
