# Sesiones.vim

Sesiones.vim is a simple and efficient session manager for **Vim** and **Neovim**.  
It allows you to save, load, and manage editing sessions per project with clean, predictable behavior.

Originally created by **José Manuel Picaza**, this 2025 version modernizes the original plugin with:
- safer session handling (`sessionoptions` tuned to avoid corruption),
- XDG-compliant directory defaults,
- clear user commands (`:SessionSave`, `:SessionLoad`, etc.),
- and a minimal codebase that remains 100% compatible with Vim 8 and Neovim 0.5+.

---

## Table of contents

1. [Features](#features)
2. [Installation](#installation)
3. [Usage](#usage)
4. [Configuration](#configuration)
5. [How sessions are stored](#how-sessions-are-stored)
6. [Implementation details](#implementation-details)
7. [Compatibility](#compatibility)
8. [Troubleshooting](#troubleshooting)
9. [Integration examples](#integration-examples)
10. [FAQ](#faq)
11. [License](#license)
12. [Credits](#credits)

---

## Features

- **Save and restore sessions easily** with simple, mnemonic commands.
- **Automatic project naming**: each session is tied to your working directory.
- **XDG-compliant storage**: sessions are stored under `~/.vim/sessions` or Neovim’s state path.
- **Safe session management**: does not persist `options` or `help` buffers to prevent broken sessions.
- **Optional autosave**: automatically stores your session when exiting Vim.
- **Cross-platform**: works equally well on Linux, macOS, and Windows.
- **Lightweight**: no dependencies, pure Vimscript, loads only when needed.

---

## Installation

### Using vim-plug
Add this line to your `.vimrc` or `init.vim` and run `:PlugInstall`.

```vim
Plug 'jmpicaza/Sesiones.vim'
````

### Using Vim’s native package system

```bash
mkdir -p ~/.vim/pack/plugins/start
cd ~/.vim/pack/plugins/start
git clone https://github.com/jmpicaza/Sesiones.vim.git
```

### Using Neovim’s package system

```bash
mkdir -p ~/.local/share/nvim/site/pack/plugins/start
cd ~/.local/share/nvim/site/pack/plugins/start
git clone https://github.com/jmpicaza/Sesiones.vim.git
```

No dependencies are required. The plugin is written in pure Vimscript and works out of the box.

---

## Usage

Sesiones.vim defines a set of intuitive commands that mirror a typical workflow for managing projects.

| Command                 | Description                                                              |
| ----------------------- | ------------------------------------------------------------------------ |
| `:SessionSave [name]`   | Saves a session under the current working directory or an optional name. |
| `:SessionSave! [name]`  | Forces overwrite of an existing session file.                            |
| `:SessionLoad [name]`   | Loads the session for the current directory or a specific name.          |
| `:SessionDelete [name]` | Removes a saved session file.                                            |
| `:SessionList`          | Displays all available session files in the configured directory.        |

### Typical workflow

```vim
" Start working on a project
cd ~/projects/myapp
vim main.py

" Save your current session
:SessionSave

" Later, reopen Vim in the same directory
:SessionLoad

" See all sessions
:SessionList

" Delete an obsolete session
:SessionDelete my_old_project
```

If you omit `[name]`, the plugin automatically uses a short identifier derived from your current directory.

---

## Configuration

All configuration variables are optional. Add them to your `.vimrc` or `init.vim`.

```vim
" Directory where session files will be stored
let g:sesiones_dir = "~/.vim/sessions"

" Automatically save on exit
let g:sesiones_autosave = 1

" Include tabpages in the saved session (1 = yes, 0 = no)
let g:sesiones_include_tabpages = 1

" Include all open buffers (1 = yes, 0 = no)
let g:sesiones_include_buffers = 0
```

### Default directories

* **Neovim**: `stdpath('state') . '/sessions'`
* **Vim**: `~/.vim/sessions` or `$XDG_STATE_HOME/vim/sessions`

### Session naming

Session files are automatically named using the last part of the working directory and a short hash, for example:

```
myproject-4a91f7a.vim
```

This ensures uniqueness across projects with similar names.

---

## How sessions are stored

Sesiones.vim uses Vim’s built-in `:mksession` and `:source` commands but applies modern best practices:

* Removes `options` and `help` from `sessionoptions` to avoid global setting pollution.
* Allows inclusion/exclusion of tabs and buffers based on configuration.
* Saves only relevant state (buffers, layout, tabs) for quick restoration.
* Stores sessions under a dedicated folder rather than inside your project to keep your repo clean.

Example sessionoptions as used internally:

```vim
set sessionoptions-=options
set sessionoptions-=help
set sessionoptions+=tabpages,buffers,curdir
```

---

## Implementation details

The plugin follows a clean runtimepath structure:

```
plugin/sesiones.vim       → user commands and defaults
autoload/sesiones.vim     → core logic (loaded lazily)
doc/sesiones.txt          → help file (:h sesiones)
```

### Autoload structure

The autoloaded functions are namespaced under `sesiones#` and include:

* `sesiones#save(name, bang)`
* `sesiones#load(name)`
* `sesiones#delete(name)`
* `sesiones#list()`
* helper functions for path resolution and hash generation.

This modular approach keeps startup fast and avoids unnecessary global state.

---

## Compatibility

| Environment | Supported | Notes                                        |
| ----------- | --------- | -------------------------------------------- |
| Vim 8.0+    | Yes       | Fully tested with standard builds.           |
| Neovim 0.5+ | Yes       | Uses `stdpath('state')` for session storage. |
| macOS       | Yes       | Works via native terminal or GUI.            |
| Linux       | Yes       | Fully supported.                             |
| Windows     | Yes       | Compatible with gVim and terminal Vim.       |

---

## Troubleshooting

| Problem                   | Likely cause             | Suggested fix                                                           |
| ------------------------- | ------------------------ | ----------------------------------------------------------------------- |
| Session not saved on exit | Autosave disabled        | `let g:sesiones_autosave = 1`                                           |
| Session not found         | Wrong directory          | Check `:echo g:sesiones_dir`                                            |
| Tabs not restored         | Tabpages disabled        | `let g:sesiones_include_tabpages = 1`                                   |
| Buffers missing           | Buffers excluded         | `let g:sesiones_include_buffers = 1`                                    |
| Session file corrupted    | Sessionoptions too broad | Plugin already prevents `options` persistence; update plugin if needed. |

If problems persist, run:

```vim
:verb set sessionoptions?
:SessionList
```

to inspect what sessions are available and what options are active.

---

## Integration examples

### FZF integration

You can combine Sesiones.vim with FZF for quick session loading:

```vim
command! SessionFzf call fzf#run(fzf#wrap({
  \ 'source': 'ls ' . shellescape(g:sesiones_dir),
  \ 'sink':   'SessionLoad',
  \ 'options': '--prompt "Sessions> "'
  \ }))
```

### Mapping example

Add a few helper mappings for faster access:

```vim
nnoremap <leader>ss :SessionSave<CR>
nnoremap <leader>sl :SessionLoad<CR>
nnoremap <leader>sd :SessionDelete<CR>
nnoremap <leader>si :SessionList<CR>
```

---

## FAQ

**Q:** Does Sesiones.vim overwrite my existing `.vim/sessions` directory?
**A:** No. If the directory exists, it reuses it. Otherwise, it creates one.

**Q:** Can I use different session directories per machine?
**A:** Yes. You can override `g:sesiones_dir` in a local `.vimrc` or machine-specific config.

**Q:** Does it conflict with Startify, Obsession, or vim-session?
**A:** No. It is fully independent and does not redefine any of their functions. It simply provides a minimal and predictable interface using Vim’s native session management.

**Q:** Is there a way to autosave every N minutes?
**A:** Not built-in, but you can use an `autocmd CursorHold` with `call sesiones#save('', 1)` if you need periodic autosaves.

---

## License

This project is licensed under the **MIT License**.
See the [LICENSE](LICENSE) file for full text.

---

## Credits

**Author:** José Manuel Picaza
**Modernization:** 2025 refactor and documentation cleanup.
**Inspiration:** original *Sesiones.vim* script published on vim.org.
**Acknowledgments:** Vim and Neovim communities for maintaining consistent session behavior across editors.

---

Keep your editing workspace organized and restore any project instantly — one `:SessionSave` away.

