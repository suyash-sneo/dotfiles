# Notes Vault Neovim Config

This directory contains a dedicated Neovim config for a Markdown-first notes vault:

- config file: [notes.lua](/Users/sneo/dev/Sparda/notes.lua)
- vault root: `~/dev/Sparda`
- target Neovim: `0.12.1+`
- leader key: `\`
- design goal: a sharp editor pointed at a notes vault, not a PKM framework

The config is built around these priorities:

- folder-first note organization
- fast note and folder creation
- tree context via Neo-tree
- fast retrieval via fzf-lua
- raw Markdown editing by default
- optional rendered Markdown on demand
- lightweight helpers for JSON, screenshots, fenced code blocks, and terminal use

## Init / Launch

Launch a fresh notes-only Neovim session with:

```sh
NVIM_APPNAME=nvim-notes nvim -u /Users/sneo/dev/Sparda/notes.lua
```

Why this matters:

- `-u /Users/sneo/dev/Sparda/notes.lua` tells Neovim to use this file as the config entrypoint.
- `NVIM_APPNAME=nvim-notes` gives this notes profile its own isolated `stdpath()` directories for plugins, state, cache, sessions, and undo.
- without `NVIM_APPNAME`, the config still works, but it will use the default `nvim` app directories under `~/.local/share/nvim`, `~/.local/state/nvim`, and so on

Recommended shell alias:

```sh
alias nvnotes='NVIM_APPNAME=nvim-notes nvim -u /Users/sneo/dev/Sparda/notes.lua'
```

Reload shell config, then launch with:

```sh
nvnotes
```

## Bootstrap / Install

### System dependencies

Install the external tools the config expects:

```sh
brew install neovim git ripgrep fzf jq pngpaste tree-sitter-cli
xcode-select --install
```

What each one is used for:

- `git`: bootstraps `lazy.nvim`
- `ripgrep`: powers content grep in `fzf-lua`
- `fzf`: picker backend used by `fzf-lua`
- `jq`: JSON format and minify helpers
- `pngpaste`: macOS clipboard image import
- `tree-sitter-cli`: required by `nvim-treesitter` to build parsers

### First startup

On the first launch:

1. `lazy.nvim` will clone itself automatically if it is missing.
2. plugins declared in `notes.lua` will install automatically.
3. Treesitter parsers will be installed or updated by the config.

After the editor opens the first time, run:

```vim
:Lazy sync
:TSUpdate
```

Then quit and reopen.

## What Startup Does

When you start Neovim with no file arguments:

- the config attempts to restore the last notes session
- if no saved session exists, it starts in the vault root
- it does not auto-open a daily note

On exit:

- the current notes session is saved automatically
- floating terminal and Neo-tree windows are cleaned up before saving so the session stays usable

Session path:

- with `NVIM_APPNAME=nvim-notes`: `~/.local/state/nvim-notes/notes-vault/session.vim`
- without `NVIM_APPNAME`: `~/.local/state/nvim/notes-vault/session.vim`

To force a fresh session next launch, remove the session file:

```sh
rm ~/.local/state/nvim-notes/notes-vault/session.vim
```

## Files and State Layout

The config creates and uses these paths automatically:

- vault root: `~/dev/Sparda`
- assets: `~/dev/Sparda/assets`
- images: `~/dev/Sparda/assets/images`
- daily logs root: `~/dev/Sparda/Daily Log`
- quick notes: `~/dev/Sparda/Temporal/Inbox`
- notes state root: `stdpath("state") .. "/notes-vault"`
- persistent undo: `stdpath("state") .. "/notes-vault/undo"`
- session file: `stdpath("state") .. "/notes-vault/session.vim"`

If you want to move the vault, edit the `Core paths` section near the top of [notes.lua](/Users/sneo/dev/Sparda/notes.lua).

## Plugin Stack

This config intentionally keeps the plugin set small:

- `folke/lazy.nvim`
- `rebelot/kanagawa.nvim`
- `nvim-lua/plenary.nvim`
- `nvim-tree/nvim-web-devicons`
- `MunifTanjim/nui.nvim`
- `nvim-neo-tree/neo-tree.nvim`
- `ibhagwan/fzf-lua`
- `nvim-treesitter/nvim-treesitter`
- `MeanderingProgrammer/render-markdown.nvim`
- `windwp/nvim-autopairs`

Not included by design:

- LSP setup
- completion engines
- Vimwiki
- backlinking / graph / PKM systems
- Git-heavy IDE tooling

## Architecture

`notes.lua` is a single-file config, but it is structured as local modules implemented with Lua tables and helper functions.

High-level structure:

- `normalize_path`: early path normalization helper
- `Config`: vault paths, state paths, and UI constants
- `Util`: shared filesystem, path, selection, indentation, and notification helpers
- `Tree`: Neo-tree integration and target-directory resolution
- `Search`: `fzf-lua` wrappers for vault and folder-scoped search
- `Notes`: note creation, folder creation, quick notes, and daily logs
- `Markdown`: fenced block detection, fenced block insertion, render toggle
- `Json`: `jq`-backed formatting and minification for selections and fenced JSON blocks
- `Screenshot`: clipboard image import, markdown link insertion, image open helper
- `Wrap`: lightweight wrapping helpers for bracket surround
- `Terminal`: built-in floating terminal management
- `Session`: save/restore logic scoped to this notes profile

Execution order:

1. set leaders and markdown globals
2. define vault/state paths
3. define utility and feature modules
4. ensure required directories exist
5. apply general editor options
6. bootstrap `lazy.nvim`
7. install and configure plugins
8. register autocommands
9. register user commands
10. register keymaps

Why it is organized this way:

- the file stays portable because there is only one entrypoint
- the code stays maintainable because each feature lives in its own local table
- helpers are available before plugin setup and command registration

## UI and Editing Defaults

Important defaults:

- 2-space indentation
- `expandtab = true`
- line numbers on
- relative numbers off
- persistent undo on
- case-insensitive search with smartcase
- mouse enabled
- system clipboard enabled with `unnamedplus`
- split right / split below
- no swapfile
- cursorline on
- prose wrapping and spell check only in `markdown` and `text` buffers
- wrapped-line movement on plain `j` and `k` when no count is given

Theme:

- colorscheme: `kanagawa-wave`

Markdown behavior:

- raw Markdown editing is the default
- `render-markdown.nvim` is installed but not enabled by default
- fenced code blocks are highlighted with Treesitter-backed language parsers

## Search Workflow

Search is built on `fzf-lua`.

Vault-wide:

- `<leader>f`: file search in the vault
- `<leader>r`: ripgrep search in the vault
- `<leader>b`: buffer search

Folder-context variants:

- `<leader>nf`: file search rooted at the selected tree folder or current note directory
- `<leader>nr`: grep rooted at the selected tree folder or current note directory
- `<leader>nR`: resume the last picker

Notes on behavior:

- searches show path context clearly using filename-first formatting
- grep depends on `ripgrep`
- picker backend depends on `fzf` or `sk`

## Tree and Note Creation Workflow

Tree UI is built on Neo-tree and is meant to provide context, not permanent clutter.

Core tree actions:

- `<leader>no`: toggle floating tree
- `<leader>nO`: toggle sidebar tree
- `<leader>ne`: reveal current file in tree
- `<leader>nv`: jump to vault root and open tree there

Note and folder creation:

- `<leader>nn`: new note in the selected tree folder or best current folder context
- `<leader>nc`: new note beside the current buffer
- `<leader>nN`: new folder in the selected tree folder or best current folder context
- `<leader>ni`: quick note in `Temporal/Inbox`

How target folder resolution works:

1. selected Neo-tree directory
2. current note's directory
3. current working directory if it is inside the vault
4. vault root

Inside Neo-tree itself:

- `a`: add file
- `A`: add directory
- `r`: rename
- `d`: delete
- `m`: move
- `.`: set root
- `H`: toggle hidden files

## Daily Log Workflow

Daily logs are created on demand, not on startup.

Daily log path format:

```text
~/dev/Sparda/Daily Log/YYYY/MM/YYYY-MM-DD.md
```

Commands and keymaps:

- `:DailyToday`
- `<leader>nd`: open or create today's daily log
- `:InsertTimestampHeading`
- `<leader>nt`: insert `## HH:MM`

New daily files are initialized with:

```md
# YYYY-MM-DD
```

## Markdown and Code Fence Workflow

Raw markdown remains the normal editing mode.

Rendered markdown:

- `:ToggleMarkdownRender`
- `<leader>nm`

Fence insertion:

- `:InsertBashFence`
- `<leader>nba`
- `:InsertJsonFence`
- `<leader>nbj`
- `:InsertCodeFence`
- `<leader>nbc`

Fence utilities:

- `:CopyFence`
- `<leader>nby`: copy the current fenced code block to the clipboard

Treesitter parsers requested by the config:

- `markdown`
- `markdown_inline`
- `bash`
- `json`
- `lua`
- `vim`
- `yaml`
- `toml`
- `diff`

## JSON Helpers

JSON helpers use `jq`. If `jq` is missing, the config shows a clear error instead of failing silently.

Visual selection:

- `<leader>njf`: format selected JSON
- `<leader>njm`: minify selected JSON
- `:'<,'>JsonFormat`
- `:'<,'>JsonMinify`

Current fenced JSON block:

- `<leader>njf` in normal mode
- `<leader>njm` in normal mode
- `:JsonFenceFormat`
- `:JsonFenceMinify`

Behavior notes:

- indentation is preserved when possible
- fenced block helpers only operate when the cursor is inside a `json` fenced block

## Screenshot / Image Workflow

This is macOS-specific and uses `pngpaste`.

Main workflow:

- `<leader>ns`
- `:PasteScreenshot`

What it does:

1. reads an image from the macOS clipboard
2. saves it to `~/dev/Sparda/assets/images`
3. names it with a timestamp like `2026-04-19_15-43-11.png`
4. computes a relative path from the current note to the image
5. inserts `![](relative/path.png)` at the cursor

Copy-link-only variant:

- `<leader>nS`
- `:PasteScreenshotCopyLink`

Open image under cursor:

- `<leader>nI`
- `:OpenImageUnderCursor`

## Terminal Workflow

This config uses Neovim's built-in terminal, wrapped in a floating window.

Toggle:

- `<F12>`
- `<leader>nT`
- `:ToggleNotesTerminal`

Terminal notes:

- it reuses the same terminal buffer
- `<Esc><Esc>` exits terminal mode
- the floating window resizes with the editor

## Other Editing Helpers

Old habits preserved:

- `<C-h>`: clear search highlight
- `jk` and `kj` in insert mode: escape to normal mode
- plain `j` and `k`: move by display line in wrapped prose when no count is used

Autopairs:

- brackets, quotes, braces, parens, and backticks are auto-paired via `nvim-autopairs`

Simple wrapping:

- `<leader>nw` in normal mode: wrap current word in `[]`
- `<leader>nw` in visual mode: wrap selection in `[]`

## User Commands

Defined commands:

- `:NotesTreeFloat`
- `:NotesTreeSidebar`
- `:NotesReveal`
- `:NotesRoot`
- `:NotesNew`
- `:NotesNewHere`
- `:NotesNewFolder`
- `:NotesQuick`
- `:DailyToday`
- `:InsertTimestampHeading`
- `:PasteScreenshot`
- `:PasteScreenshotCopyLink`
- `:OpenImageUnderCursor`
- `:ToggleMarkdownRender`
- `:InsertBashFence`
- `:InsertJsonFence`
- `:InsertCodeFence`
- `:CopyFence`
- `:JsonFormat`
- `:JsonMinify`
- `:JsonFenceFormat`
- `:JsonFenceMinify`
- `:ToggleNotesTerminal`

## Keymap Summary

Core:

- `<leader>f`: vault files
- `<leader>r`: vault grep
- `<leader>b`: buffers

Notes namespace:

- `<leader>nf`: current-folder files
- `<leader>nr`: current-folder grep
- `<leader>nR`: resume picker
- `<leader>no`: floating tree
- `<leader>nO`: sidebar tree
- `<leader>ne`: reveal current file in tree
- `<leader>nv`: jump to vault root
- `<leader>nn`: new note in selected/current folder
- `<leader>nc`: new note beside current buffer
- `<leader>nN`: new folder in selected/current folder
- `<leader>ni`: quick inbox note
- `<leader>nd`: today's daily log
- `<leader>nt`: insert timestamp heading
- `<leader>ns`: paste screenshot and insert link
- `<leader>nS`: paste screenshot and copy link
- `<leader>nI`: open image under cursor
- `<leader>nm`: toggle rendered markdown
- `<leader>nba`: insert bash fenced block
- `<leader>nbj`: insert JSON fenced block
- `<leader>nbc`: insert generic fenced block
- `<leader>nby`: copy current fenced block
- `<leader>njf`: format current fenced JSON or visual selection
- `<leader>njm`: minify current fenced JSON or visual selection
- `<leader>nw`: wrap word or selection in brackets
- `<leader>nT`: toggle floating terminal

Other:

- `<F12>`: toggle floating terminal
- `<C-h>`: clear search highlight
- `jk` / `kj`: escape insert mode

## Updating the Config

This config is intentionally easy to evolve because everything is in one file.

Best places to edit:

- change vault paths in the `Core paths` section
- change editor behavior in `General editor options`
- change plugin choices in `Plugin setup`
- change workflows in the local feature modules such as `Notes`, `Search`, `Json`, and `Screenshot`
- change mappings near the bottom in the `Keymaps` section

## Troubleshooting

If `lazy.nvim` fails to bootstrap:

- confirm `git` is installed
- confirm Neovim has network access on first launch

If search opens but grep fails:

- install `ripgrep` with `brew install ripgrep`

If picker UI fails:

- install `fzf` with `brew install fzf`

If JSON helpers fail:

- install `jq` with `brew install jq`

If screenshot paste fails:

- install `pngpaste` with `brew install pngpaste`
- confirm the clipboard currently contains an image

If you want a fully clean re-bootstrap:

1. remove the `NVIM_APPNAME`-specific data/state directories
2. relaunch with `NVIM_APPNAME=nvim-notes`
3. run `:Lazy sync`
4. run `:TSUpdate`

## Cheatsheet

Leader key:

- `\`

Launch:

- `NVIM_APPNAME=nvim-notes nvim -u /Users/sneo/dev/Sparda/notes.lua`
- `nvnotes` if you created the alias

Search:

- `\f`: vault files
- `\r`: vault grep
- `\b`: buffers
- `\nf`: current-folder files
- `\nr`: current-folder grep
- `\nR`: resume picker

Tree and navigation:

- `\no`: floating tree
- `\nO`: sidebar tree
- `\ne`: reveal current file in tree
- `\nv`: jump to vault root

Note creation:

- `\nn`: new note in selected/current folder
- `\nc`: new note beside current buffer
- `\nN`: new folder in selected/current folder
- `\ni`: quick inbox note

Daily logs:

- `\nd`: open today's daily log
- `\nt`: insert timestamp heading

Images:

- `\ns`: save clipboard image and insert markdown link
- `\nS`: save clipboard image and copy markdown link
- `\nI`: open image link under cursor

Markdown and code blocks:

- `\nm`: toggle rendered markdown
- `\nba`: insert bash fenced block
- `\nbj`: insert JSON fenced block
- `\nbc`: insert generic fenced block
- `\nby`: copy current fenced block

JSON:

- `\njf`: format current fenced JSON or visual selection
- `\njm`: minify current fenced JSON or visual selection

Terminal:

- `<F12>`: toggle floating terminal
- `\nT`: toggle floating terminal

Other:

- `<C-h>`: clear search highlight
- `jk` / `kj`: escape insert mode
- `\nw`: wrap current word or selection in brackets
