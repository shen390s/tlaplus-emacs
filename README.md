# tlaplus-ts-mode

Tree-sitter based Emacs major mode for [TLA+](https://lamport.azurewebsites.net/tla/tla.html) specifications.

Provides feature parity with the [VS Code TLA+ extension](https://github.com/tlaplus/vscode-tlaplus).

Requires Emacs 29.1+ (built-in tree-sitter support) and the [tree-sitter-tlaplus](https://github.com/tlaplus-community/tree-sitter-tlaplus) grammar.

## Features

- **Syntax highlighting** via tree-sitter font-lock (comments, keywords, strings, numbers, types, operators, definitions, variables, constants, PlusCal)
- **Indentation** with tree-sitter awareness
- **Imenu** support (operators, functions, modules, theorems, variables, constants, assumptions)
- **Navigation** between definitions with `treesit-beginning-of-defun` / `treesit-end-of-defun`
- **Code snippets** (skeleton templates for modules, PlusCal algorithms, processes, macros, etc.)
- **Unicode symbol input** — insert mathematical symbols via `C-c C-u`
- **SANY parser** — parse module and jump to errors (`C-c C-p`)
- **PlusCal translator** — translate PlusCal to TLA+ (`C-c C-t`)
- **TLC model checker** — run model checking (`C-c C-c`), stop (`C-c C-k`)
- **Expression evaluation** — REPL (`M-x tlaplus-repl`), evaluate expression (`C-c C-e`), evaluate region (`C-c C-r`)
- **LaTeX/PDF export** — export to LaTeX (`C-c C-l`) or PDF (`C-c C-d`)
- **TLAPS integration** — check proof steps (`C-c C-s`)
- **Error parsing** — SANY and TLC errors are parsed by `compilation-mode` for navigation
- **.cfg file support** — `tlaplus-cfg-mode` with keyword highlighting

## Installation

### 1. Install the tree-sitter grammar

```elisp
(add-to-list 'treesit-language-source-alist
             '(tlaplus "https://github.com/tlaplus-community/tree-sitter-tlaplus"))
```

Then run `M-x treesit-install-language-grammar RET tlaplus RET`.

### 2. Install tlaplus-ts-mode

Clone this repository and add to your load path:

```elisp
(add-to-list 'load-path "/path/to/tlaplus-ts-mode")
(require 'tlaplus-ts-mode)
```

Or with `use-package`:

```elisp
(use-package tlaplus-ts-mode
  :load-path "/path/to/tlaplus-ts-mode"
  :custom
  (tlaplus-tlatools-path "/path/to/tla2tools.jar")
  (tlaplus-java-home ""))
```

### 3. TLA+ tools (required for tools integration)

If `tla-toolbox` is on your PATH (e.g. installed via Nix), the jar and Java are
auto-detected — no configuration needed.

Otherwise, download `tla2tools.jar` from the [TLA+ releases](https://github.com/tlaplus/tlaplus/releases) and set:

```elisp
(setq tlaplus-tlatools-path "/path/to/tla2tools.jar")
```

**Note:** The REPL (`M-x tlaplus-repl`) requires `tla2tools.jar` from v1.7.1 or
v1.8.0, which contains `tlc2.REPL`. The jar bundled with TLA+ Toolbox 1.7.4 does
*not* include this class. Download the standalone jar from the
[v1.8.0 release](https://github.com/tlaplus/tlaplus/releases/tag/v1.8.0).

### 4. TLAPS (optional, for proof checking)

Install `tlapm` separately (e.g. `nix-env -iA nixpkgs.tlaplusProofManager` or
from [TLAPS releases](https://github.com/tlaplus/tlapm/releases)), then enable:

```elisp
(setq tlaplus-tlaps-enabled t)
```

## Key Bindings

| Key       | Command                       | Description                  |
|-----------|-------------------------------|------------------------------|
| `C-c C-p` | `tlaplus-parse-module`        | Parse module with SANY       |
| `C-c C-t` | `tlaplus-translate-pluscal`   | Translate PlusCal            |
| `C-c C-c` | `tlaplus-run-tlc`             | Run TLC model checker        |
| `C-c C-k` | `tlaplus-stop-tlc`            | Stop TLC                     |
| `C-c C-e` | `tlaplus-evaluate-expression` | Evaluate expression in REPL  |
| `C-c C-r` | `tlaplus-evaluate-region`     | Evaluate region in REPL      |
| `C-c C-l` | `tlaplus-export-to-latex`     | Export to LaTeX              |
| `C-c C-d` | `tlaplus-export-to-pdf`       | Export to PDF                |
| `C-c C-u` | `tlaplus-insert-unicode`      | Insert Unicode symbol        |
| `C-c C-s` | `tlaplus-prove-step`          | Check proof step (TLAPS)     |

Use `C-u C-c C-c` to prompt for a non-default `.cfg` file.

## Customization

| Variable                      | Default      | Description                          |
|-------------------------------|--------------|--------------------------------------|
| `tlaplus-ts-mode-indent-offset` | `2`       | Indentation width                    |
| `tlaplus-tlatools-path`       | `""`         | Path to `tla2tools.jar`              |
| `tlaplus-java-home`           | `""`         | Java home directory                  |
| `tlaplus-java-options`        | `""`         | Extra JVM options                    |
| `tlaplus-pluscal-options`     | `""`         | PlusCal translator options           |
| `tlaplus-tlc-options`         | `""`         | TLC model checker options            |
| `tlaplus-module-search-paths` | `nil`        | Additional module search directories |
| `tlaplus-pdf-command`         | `"pdflatex"` | LaTeX-to-PDF command                 |
| `tlaplus-tlaps-enabled`       | `nil`        | Enable TLAPS integration             |
| `tlaplus-tlaps-command`       | `("tlapm")`  | TLAPS command                        |

## Skeleton Templates

Insert TLA+ / PlusCal boilerplate via `M-x tlaplus-skeleton-*`:

- `tlaplus-skeleton-module` — new module
- `tlaplus-skeleton-pluscal` — PlusCal algorithm block
- `tlaplus-skeleton-process` — process
- `tlaplus-skeleton-procedure` — procedure
- `tlaplus-skeleton-macro` — macro
- `tlaplus-skeleton-if`, `tlaplus-skeleton-if-else`, `tlaplus-skeleton-while`, `tlaplus-skeleton-with`, `tlaplus-skeleton-either`, `tlaplus-skeleton-define`

## License

MIT
