# Sesiones.vim

**Professional session manager for Vim and Neovim with intelligent nickname support**

**Author**: jmpicaza - Original creator and maintainer of both the classic and modern versions.

Sesiones.vim makes session management effortless by automatically associating sessions with your current files and providing an intuitive nickname system for easy access.

---

## ✨ Features

- **🎯 File-Based Sessions**: Sessions automatically associate with the current file or directory
- **🏷️ Smart Nicknames**: Auto-generated nicknames from filenames, with custom nickname support  
- **🎛️ Interactive Management**: Built-in session browser (`:SessionsEdit`) for visual session management
- **⚡ Tab Completion**: Smart completion for all commands using nicknames or encoded filenames
- **🛡️ Safe Encoding**: Robust filename encoding that prevents shell quoting issues
- **📂 XDG Compliant**: Follows XDG Base Directory standards (with legacy support)
- **🔄 Backward Compatible**: Works with existing `g:sesiones_path` configurations
- **🌍 Cross-Platform**: Seamless operation on Linux, macOS, and Windows
- **⚙️ Professional Quality**: Clean, maintainable code following Vim plugin best practices

## 📦 Installation

### Using [vim-plug](https://github.com/junegunn/vim-plug):
```vim
Plug 'jmpicaza/Sesiones.vim'
```

### Using [Vundle](https://github.com/VundleVim/Vundle.vim):
```vim
Plugin 'jmpicaza/Sesiones.vim'
```

### Using [Pathogen](https://github.com/tpope/vim-pathogen):
```bash
cd ~/.vim/bundle
git clone https://github.com/jmpicaza/Sesiones.vim.git
```

### Manual Installation:
```bash
git clone https://github.com/jmpicaza/Sesiones.vim.git
cp -r Sesiones.vim/* ~/.vim/
```

## 🚀 Quick Start

```vim
" Save session for current file
:SessionSave

" Save session with custom nickname  
:SessionSave MyProject

" Load session by nickname
:SessionLoad MyProject

" Interactive session browser
:SessionsEdit

" List all sessions
:SessionList

" Delete session by nickname
:SessionDelete MyProject
```

## 📖 Usage

### Basic Session Management

**Save Sessions:**
```vim
:SessionSave              " Auto-nickname from current filename
:SessionSave WebApp       " Custom nickname 'WebApp'
:SessionSave!             " Force overwrite (if needed)
```

**Load Sessions:**
```vim
:SessionLoad              " Load session for current directory/file
:SessionLoad WebApp       " Load by nickname
:SessionLoad<Tab>         " Use tab completion to see available sessions
```

**Manage Sessions:**
```vim
:SessionList              " View all sessions with details
:SessionsEdit             " Interactive session browser
:SessionDelete WebApp     " Delete session by nickname
```

### Interactive Session Browser

`:SessionsEdit` opens a dedicated buffer with:

- **Enter**: Load session under cursor
- **dd**: Delete session under cursor (with confirmation)  
- **r**: Rename session nickname
- **q**: Quit browser

```
" Sesiones.vim - Interactive Session Editor
"
" Instructions:
"   <Enter>  - Load session under cursor
"   dd       - Delete session under cursor
"   r        - Edit nickname for session under cursor  
"   q        - Quit without saving
"
" Format: Nickname | Filename | Size | Date
" Sessions:
" ---------
myproject.py              | home_user_code_myproject.py.vim    | 5.2KB | 2025-11-03 14:30
WebApp                    | home_user_sites_webapp_index.html  | 3.1KB | 2025-11-02 16:45
```

### Smart Nickname System

Sessions get automatic nicknames based on your current file:

- Editing `myproject.py` → nickname: `myproject.py`
- Custom nickname: `:SessionSave WebApp` → nickname: `WebApp`  
- Tab completion works with both nicknames and encoded filenames
- Use `:SessionLoad myproject.py` or `:SessionLoad WebApp`

## ⚙️ Configuration

### Directory Configuration

```vim
" XDG-compliant (default - automatic detection)
" ~/.local/share/nvim/sessions (Neovim)
" ~/.vim/sessions (Vim)

" Custom directory
let g:sesiones_dir = "~/my-sessions"

" Legacy support (still works)
let g:sesiones_path = "~/.vim/sessions"
```

### Session Options

```vim
" Include tabpages in sessions (default: 1)
let g:sesiones_include_tabpages = 1

" Include buffers in sessions (default: 1)  
let g:sesiones_include_buffers = 1

" Auto-save on exit (default: 0)
let g:sesiones_autosave = 0
```

### Key Mappings

```vim
" Example custom mappings
nnoremap <leader>ss :SessionSave<CR>
nnoremap <leader>sl :SessionLoad<CR>  
nnoremap <leader>se :SessionsEdit<CR>
nnoremap <leader>sx :SessionDelete<CR>
```

## 🗂️ How Sessions Work

### File Association
Sessions are tied to **specific files** rather than just directories:

- `~/code/myapp/main.py` → session: `home_user_code_myapp_main.py.vim`
- `~/docs/readme.md` → session: `home_user_docs_readme.md.vim`

### Nickname Mapping  
Nicknames are stored separately in `.sessions_nicknames`:
```
MyProject:home_user_code_myproject_main.py
WebApp:home_user_sites_webapp_index.html
```

### Session Files
- **Location**: `~/.local/share/nvim/sessions/` (or configured directory)
- **Format**: Standard Vim session files with `.vim` extension
- **Encoding**: Safe filename encoding (no shell quoting issues)

## 🔧 Advanced Usage

### Workflow Integration

```vim
" Project-specific session workflow
cd ~/code/myproject
vim main.py
" ... work on project ...
:SessionSave MyProject

" Later, quick project restore  
:SessionLoad MyProject
" Automatically restores: files, windows, cursor positions, folds
```

### Multiple File Sessions

```vim
" Work with multiple files
vim *.py
" Open various files, arrange windows, set up workspace
:SessionSave PythonProject
" Saves entire workspace state
```

### FZF Integration Example

```vim
" Example FZF integration for session selection
function! s:session_list()
  let sessions = []
  for file in glob(g:sesiones_dir . '/*.vim', 0, 1)
    call add(sessions, fnamemodify(file, ':t:r'))
  endfor
  return sessions
endfunction

command! -bang Sessions call fzf#run(fzf#wrap({
  \ 'source': s:session_list(),
  \ 'sink': 'SessionLoad',
  \ 'options': '--prompt="Sessions> "'
\ }, <bang>0))
```

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes with tests
4. Submit a pull request

## 📄 License

MIT License - see [LICENSE](LICENSE.md) file for details.

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/jmpicaza/Sesiones.vim/issues)
- **Author**: José Manuel Picaza <jmpicaza@gmail.com>
- **Repository**: [https://github.com/jmpicaza/Sesiones.vim](https://github.com/jmpicaza/Sesiones.vim)

---

**Sesiones.vim** - Making Vim session management effortless. 🚀
