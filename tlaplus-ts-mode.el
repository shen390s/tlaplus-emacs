;;; tlaplus-ts-mode.el --- Major mode for TLA+ using tree-sitter -*- lexical-binding: t; -*-

;; Copyright (C) 2026

;; Author: tlaplus-emacs contributors
;; Version: 0.2.0
;; Package-Requires: ((emacs "29.1"))
;; Keywords: languages tla+
;; URL: https://github.com/tlaplus-community/tree-sitter-tlaplus
;; SPDX-License-Identifier: MIT

;;; Commentary:

;; Tree-sitter based major mode for editing TLA+ specification files.
;; Provides features comparable to the VS Code TLA+ extension:
;; - Syntax highlighting via tree-sitter
;; - Indentation
;; - Imenu and navigation
;; - Code snippets/templates (skeleton)
;; - Unicode symbol input
;; - SANY parser integration
;; - PlusCal translator integration
;; - TLC model checker integration
;; - Expression evaluation (REPL)
;; - LaTeX/PDF export
;; - TLAPS proof system integration
;; - Error parsing (compilation-mode)
;; - .cfg file support

;;; Code:

(require 'treesit)
(require 'compile)
(require 'skeleton)
(require 'comint)

;;; Customization

(defgroup tlaplus nil
  "Major mode for TLA+ specifications."
  :group 'languages
  :prefix "tlaplus-")

(defcustom tlaplus-ts-mode-indent-offset 2
  "Number of spaces for each indentation step in `tlaplus-ts-mode'."
  :type 'integer
  :group 'tlaplus)

(defcustom tlaplus-java-home ""
  "Path to Java home directory for running TLA+ tools."
  :type 'string
  :group 'tlaplus)

(defcustom tlaplus-java-options ""
  "Additional JVM options for TLA+ tools."
  :type 'string
  :group 'tlaplus)

(defcustom tlaplus-tlatools-path ""
  "Path to tla2tools.jar.  If empty, uses `tlaplus-java-home' to find it."
  :type 'string
  :group 'tlaplus)

(defcustom tlaplus-pluscal-options ""
  "Additional options for the PlusCal translator."
  :type 'string
  :group 'tlaplus)

(defcustom tlaplus-tlc-options ""
  "Additional options for TLC model checker."
  :type 'string
  :group 'tlaplus)

(defcustom tlaplus-module-search-paths nil
  "Additional paths to search for TLA+ modules."
  :type '(repeat string)
  :group 'tlaplus)

(defcustom tlaplus-pdf-command "pdflatex"
  "Command to produce PDFs from .tex files."
  :type 'string
  :group 'tlaplus)

(defcustom tlaplus-tlaps-enabled nil
  "Enable TLAPS proof system integration."
  :type 'boolean
  :group 'tlaplus)

(defcustom tlaplus-tlaps-command '("tlapm")
  "Command and arguments to run TLAPS."
  :type '(repeat string)
  :group 'tlaplus)

;;; Font-lock

(defvar tlaplus-ts-mode--font-lock-rules
  '(:language tlaplus
    :override t
    :feature comment
    ((block_comment "(*" @font-lock-comment-delimiter-face)
     (block_comment "*)" @font-lock-comment-delimiter-face)
     (block_comment_text) @font-lock-comment-face
     (comment) @font-lock-comment-face
     (single_line) @font-lock-comment-face)

    :language tlaplus
    :override t
    :feature keyword
    (["ACTION" "ASSUME" "ASSUMPTION" "AXIOM" "BY" "CASE" "CHOOSE"
      "CONSTANT" "CONSTANTS" "COROLLARY" "DEF" "DEFINE" "DEFS"
      "ELSE" "EXCEPT" "EXTENDS" "HAVE" "HIDE" "IF" "IN"
      "INSTANCE" "LAMBDA" "LEMMA" "LET" "LOCAL" "MODULE" "NEW"
      "OBVIOUS" "OMITTED" "ONLY" "OTHER" "PICK" "PROOF"
      "PROPOSITION" "PROVE" "QED" "RECURSIVE" "SF_" "STATE"
      "SUFFICES" "TAKE" "TEMPORAL" "THEN" "THEOREM" "USE"
      "VARIABLE" "VARIABLES" "WF_" "WITH" "WITNESS"
      (address) (all_map_to) (assign) (case_arrow) (case_box)
      (def_eq) (exists) (forall) (gets) (label_as)
      (maps_to) (set_in) (temporal_exists) (temporal_forall)]
     @font-lock-keyword-face)

    :language tlaplus
    :override t
    :feature keyword
    (["algorithm" "assert" "await" "begin" "call" "define"
      "either" "else" "elsif" "end" "fair" "goto" "if" "macro"
      "or" "print" "procedure" "process" "variable" "variables"
      "when" "with" "then"
      (pcal_algorithm_start) (pcal_end_either) (pcal_end_if)
      (pcal_return) (pcal_skip)]
     @font-lock-keyword-face)

    :language tlaplus
    :override t
    :feature string
    ((string) @font-lock-string-face
     (escape_char) @font-lock-escape-face)

    :language tlaplus
    :override t
    :feature number
    ((nat_number) @font-lock-number-face
     (real_number) @font-lock-number-face
     (binary_number (value) @font-lock-number-face)
     (octal_number (value) @font-lock-number-face)
     (hex_number (value) @font-lock-number-face)
     (boolean) @font-lock-constant-face)

    :language tlaplus
    :override t
    :feature type
    ((boolean_set) @font-lock-type-face
     (string_set) @font-lock-type-face
     (nat_number_set) @font-lock-type-face
     (int_number_set) @font-lock-type-face
     (real_number_set) @font-lock-type-face)

    :language tlaplus
    :override t
    :feature module
    ((extends (identifier_ref) @font-lock-type-face)
     (instance (identifier_ref) @font-lock-type-face)
     (module name: (_) @font-lock-type-face)
     (module_definition name: (_) @font-lock-type-face))

    :language tlaplus
    :override t
    :feature definition
    ((operator_definition name: (_) @font-lock-function-name-face)
     (function_definition name: (identifier) @font-lock-function-name-face)
     (recursive_declaration (identifier) @font-lock-function-name-face)
     (recursive_declaration (operator_declaration name: (_) @font-lock-function-name-face))
     (pcal_macro_decl name: (identifier) @font-lock-function-name-face)
     (pcal_macro_call name: (identifier) @font-lock-function-call-face)
     (pcal_proc_decl name: (identifier) @font-lock-function-name-face)
     (pcal_process name: (identifier) @font-lock-function-name-face))

    :language tlaplus
    :override t
    :feature constant
    ((constant_declaration (identifier) @font-lock-constant-face)
     (constant_declaration (operator_declaration name: (_) @font-lock-constant-face))
     (assumption name: (identifier) @font-lock-constant-face)
     (theorem name: (identifier) @font-lock-constant-face))

    :language tlaplus
    :override t
    :feature variable
    ((variable_declaration (identifier) @font-lock-variable-name-face)
     (pcal_var_decl (identifier) @font-lock-variable-name-face))

    :language tlaplus
    :override t
    :feature parameter
    ((choose (identifier) @font-lock-variable-use-face)
     (choose (tuple_of_identifiers (identifier) @font-lock-variable-use-face))
     (lambda (identifier) @font-lock-variable-use-face)
     (operator_definition parameter: (identifier) @font-lock-variable-use-face)
     (operator_definition (operator_declaration name: (_) @font-lock-variable-use-face))
     (quantifier_bound (identifier) @font-lock-variable-use-face)
     (quantifier_bound (tuple_of_identifiers (identifier) @font-lock-variable-use-face))
     (unbounded_quantification (identifier) @font-lock-variable-use-face))

    :language tlaplus
    :override t
    :feature property
    ((record_literal (identifier) @font-lock-property-name-face)
     (set_of_records (identifier) @font-lock-property-name-face))

    :language tlaplus
    :override t
    :feature label
    ((_ label: (identifier) @font-lock-preprocessor-face)
     (label name: (_) @font-lock-preprocessor-face)
     (proof_step_id (level) @font-lock-preprocessor-face)
     (proof_step_id (name) @font-lock-preprocessor-face)
     (proof_step_ref (level) @font-lock-preprocessor-face)
     (proof_step_ref (name) @font-lock-preprocessor-face))

    :language tlaplus
    :override t
    :feature delimiter
    ([(langle_bracket) (rangle_bracket) (rangle_bracket_sub)
      "{" "}" "[" "]" "]_" "(" ")"]
     @font-lock-bracket-face
     ["," ":" "." "!" ";"
      (bullet_conj) (bullet_disj) (prev_func_val) (placeholder)]
     @font-lock-delimiter-face)

    :language tlaplus
    :override nil
    :feature operator
    ((bound_infix_op symbol: (_) @font-lock-operator-face)
     (bound_prefix_op symbol: (_) @font-lock-operator-face)
     (bound_postfix_op symbol: (_) @font-lock-operator-face)
     (bound_nonfix_op symbol: (_) @font-lock-operator-face)
     (prefix_op_symbol) @font-lock-operator-face
     (infix_op_symbol) @font-lock-operator-face
     (postfix_op_symbol) @font-lock-operator-face))
  "Font-lock rules for `tlaplus-ts-mode'.")

;;; Indentation

(defvar tlaplus-ts-mode--indent-rules
  `((tlaplus
     ((parent-is "source_file") column-0 0)
     ((node-is "double_line") column-0 0)
     ((node-is "extramodular_text") column-0 0)
     ((parent-is "extramodular_text") column-0 0)
     ((parent-is "module") column-0 0)
     ((parent-is "let_in") parent-bol tlaplus-ts-mode-indent-offset)
     ((parent-is "conj_list") parent-bol tlaplus-ts-mode-indent-offset)
     ((parent-is "disj_list") parent-bol tlaplus-ts-mode-indent-offset)
     ((parent-is "if_then_else") parent-bol tlaplus-ts-mode-indent-offset)
     ((parent-is "case") parent-bol tlaplus-ts-mode-indent-offset)
     ((parent-is "except") parent-bol tlaplus-ts-mode-indent-offset)
     ((parent-is "parentheses") parent-bol tlaplus-ts-mode-indent-offset)
     ((parent-is "finite_set_literal") parent-bol tlaplus-ts-mode-indent-offset)
     ((parent-is "set_filter") parent-bol tlaplus-ts-mode-indent-offset)
     ((parent-is "set_map") parent-bol tlaplus-ts-mode-indent-offset)
     ((parent-is "function_literal") parent-bol tlaplus-ts-mode-indent-offset)
     ((parent-is "record_literal") parent-bol tlaplus-ts-mode-indent-offset)
     ((parent-is "tuple_literal") parent-bol tlaplus-ts-mode-indent-offset)
     ((parent-is "non_terminal_proof") parent-bol tlaplus-ts-mode-indent-offset)
     (no-node column-0 0)))
  "Indentation rules for `tlaplus-ts-mode'.")

;;; Imenu

(defvar tlaplus-ts-mode--imenu-settings
  `(("Operator" "\\`operator_definition\\'" nil nil)
    ("Function" "\\`function_definition\\'" nil nil)
    ("Module" "\\`module\\'" nil nil)
    ("Theorem" "\\`theorem\\'" nil nil)
    ("Variable" "\\`variable_declaration\\'" nil nil)
    ("Constant" "\\`constant_declaration\\'" nil nil)
    ("Assumption" "\\`assumption\\'" nil nil))
  "Imenu settings for `tlaplus-ts-mode'.")

;;; Navigation

(defvar tlaplus-ts-mode--defun-type-regexp
  (regexp-opt '("operator_definition"
                "function_definition"
                "module"
                "theorem"
                "assumption"
                "pcal_proc_decl"
                "pcal_process"
                "pcal_macro_decl"))
  "Regexp matching defun-like node types for navigation.")

;;; Skeletons / Templates

(define-skeleton tlaplus-skeleton-module
  "Insert a new TLA+ module skeleton."
  "Module name: "
  "---- MODULE " str " ----" \n
  "EXTENDS TLC" \n
  \n
  _ \n
  "====" \n)

(define-skeleton tlaplus-skeleton-pluscal
  "Insert a PlusCal algorithm block."
  "Algorithm name: "
  "(*--algorithm " str \n
  _ \n
  "begin" \n
  > "skip;" \n
  "end algorithm; *)" \n)

(define-skeleton tlaplus-skeleton-process
  "Insert a PlusCal process."
  "Process name: "
  "process " str " = " (skeleton-read "Value: ") \n
  "begin" \n
  > _ \n
  "end process;" \n)

(define-skeleton tlaplus-skeleton-procedure
  "Insert a PlusCal procedure."
  "Procedure name: "
  "procedure " str "(" (skeleton-read "Params: ") ") begin" \n
  > _ \n
  "end procedure;" \n)

(define-skeleton tlaplus-skeleton-macro
  "Insert a PlusCal macro."
  "Macro name: "
  "macro " str "(" (skeleton-read "Params: ") ") begin" \n
  > _ \n
  "end macro;" \n)

(define-skeleton tlaplus-skeleton-if
  "Insert PlusCal if block."
  "Condition: "
  "if " str " then" \n
  > _ \n
  "end if;" \n)

(define-skeleton tlaplus-skeleton-if-else
  "Insert PlusCal if-else block."
  "Condition: "
  "if " str " then" \n
  > _ \n
  "else" \n
  > \n
  "end if;" \n)

(define-skeleton tlaplus-skeleton-while
  "Insert PlusCal while loop."
  "Condition: "
  "while " str " do" \n
  > _ \n
  "end while;" \n)

(define-skeleton tlaplus-skeleton-with
  "Insert PlusCal with block."
  "Variable: "
  "with " str " do" \n
  > _ \n
  "end with;" \n)

(define-skeleton tlaplus-skeleton-either
  "Insert PlusCal either block."
  nil
  "either" \n
  > _ \n
  "or" \n
  > \n
  "end either;" \n)

(define-skeleton tlaplus-skeleton-define
  "Insert PlusCal define block."
  nil
  "define" \n
  > _ \n
  "end define;" \n)

;;; Unicode Symbol Input

(defvar tlaplus-unicode-translations
  '(;; Logic
    ("\\land" . "∧") ("\\lor" . "∨") ("\\lnot" . "¬") ("\\neg" . "¬")
    ("\\implies" . "⟹") ("\\equiv" . "≡") ("\\TRUE" . "⊤") ("\\FALSE" . "⊥")
    ;; Quantifiers
    ("\\forall" . "∀") ("\\A" . "∀") ("\\exists" . "∃") ("\\E" . "∃")
    ("\\AA" . "𝔸") ("\\EE" . "𝔼")
    ;; Sets
    ("\\in" . "∈") ("\\notin" . "∉") ("\\cup" . "∪") ("\\cap" . "∩")
    ("\\subseteq" . "⊆") ("\\subset" . "⊂") ("\\supset" . "⊃")
    ("\\union" . "∪") ("\\inter" . "∩")
    ;; Arrows
    ("\\to" . "→") ("\\gets" . "←") ("\\mapsto" . "↦")
    ("\\rightarrow" . "→") ("\\leftarrow" . "←")
    ("\\Rightarrow" . "⇒") ("\\Leftarrow" . "⇐")
    ("\\leftrightarrow" . "↔")
    ;; Relations
    ("\\leq" . "≤") ("\\geq" . "≥") ("\\neq" . "≠")
    ("\\prec" . "≺") ("\\succ" . "≻")
    ("\\preceq" . "⪯") ("\\succeq" . "⪰")
    ("\\sim" . "∼") ("\\simeq" . "≃") ("\\approx" . "≈")
    ;; Misc
    ("\\times" . "×") ("\\div" . "÷") ("\\cdot" . "⋅")
    ("\\circ" . "∘") ("\\bullet" . "●") ("\\star" . "⋆")
    ("\\infinity" . "∞") ("\\nat" . "ℕ") ("\\int" . "ℤ") ("\\real" . "ℝ")
    ;; TLA+ specific
    ("\\prime" . "′") ("\\enabled" . "ENABLED") ("\\unchanged" . "UNCHANGED")
    ("\\diamond" . "◇") ("\\box" . "□") ("\\leadsto" . "⇝")
    ("\\sqsubseteq" . "⊑") ("\\sqsupseteq" . "⊒")
    ("\\oplus" . "⊕") ("\\ominus" . "⊖") ("\\otimes" . "⊗")
    ("\\oslash" . "⊘") ("\\odot" . "⊙")
    ("\\langle" . "⟨") ("\\rangle" . "⟩")
    ("\\ll" . "≪") ("\\gg" . "≫")
    ;; Subscript/superscript
    ("\\o" . "∘") ("\\X" . "×") ("\\#" . "≠")
    ("|->" . "↦") ("<-" . "←") ("->" . "→")
    ("=>" . "⇒") ("~>" . "⇝") ("[]" . "□") ("<>" . "◇"))
  "Mapping from ASCII TLA+ symbols to Unicode equivalents.")

(defun tlaplus-insert-unicode ()
  "Insert a Unicode symbol by selecting from TLA+ symbol names."
  (interactive)
  (let* ((candidates (mapcar (lambda (pair)
                               (format "%s  %s" (car pair) (cdr pair)))
                             tlaplus-unicode-translations))
         (choice (completing-read "Symbol: " candidates nil t))
         (sym (cdr (assoc (car (split-string choice)) tlaplus-unicode-translations))))
    (when sym (insert sym))))

(defun tlaplus-unicode-replace-region (beg end)
  "Replace ASCII TLA+ symbols with Unicode in region BEG to END."
  (interactive "r")
  (save-excursion
    (dolist (pair tlaplus-unicode-translations)
      (goto-char beg)
      (while (search-forward (car pair) end t)
        (replace-match (cdr pair) t t)))))

;;; Utility: Java/tlatools command building

(defun tlaplus--java-command ()
  "Return the java executable path.
Checks: `tlaplus-java-home', JAVA_HOME env, toolbox-bundled JRE, then PATH."
  (or
   (unless (string-empty-p tlaplus-java-home)
     (expand-file-name "bin/java" tlaplus-java-home))
   (when-let ((jh (getenv "JAVA_HOME")))
     (let ((j (expand-file-name "bin/java" jh)))
       (when (file-executable-p j) j)))
   (tlaplus--detect-toolbox-java)
   (executable-find "java")
   (error "Java not found. Set `tlaplus-java-home' or JAVA_HOME")))

(defun tlaplus--find-toolbox-ini ()
  "Locate toolbox.ini relative to tla-toolbox executable."
  (when-let ((toolbox (executable-find "tla-toolbox")))
    (let ((dir (file-name-directory (file-truename toolbox))))
      (cl-some (lambda (rel)
                 (let ((f (expand-file-name rel dir)))
                   (when (file-exists-p f) f)))
               '("toolbox.ini"
                 "../lib/tla-toolbox/toolbox.ini"
                 "../libexec/toolbox/toolbox.ini")))))

(defun tlaplus--parse-ini-vm (ini-file)
  "Parse the -vm value from INI-FILE.
Returns the Java executable path specified after the -vm line.
Resolves relative paths against the directory containing INI-FILE."
  (with-temp-buffer
    (insert-file-contents ini-file)
    (when (re-search-forward "^-vm$" nil t)
      (forward-line 1)
      (let* ((raw (string-trim (buffer-substring-no-properties
                                (line-beginning-position) (line-end-position))))
             (path (if (file-name-absolute-p raw)
                       raw
                     (expand-file-name raw (file-name-directory ini-file)))))
        (when (file-executable-p path) path)))))

(defun tlaplus--detect-toolbox-java ()
  "Find bundled Java from tla-toolbox installation via toolbox.ini."
  (when-let ((ini (tlaplus--find-toolbox-ini)))
    (tlaplus--parse-ini-vm ini)))

(defun tlaplus--tlatools-jar ()
  "Return path to tla2tools.jar.
Auto-detects from `tla-toolbox' if available and `tlaplus-tlatools-path' is empty."
  (if (not (string-empty-p tlaplus-tlatools-path))
      tlaplus-tlatools-path
    (or (tlaplus--detect-tlatools-jar)
        (error "Set `tlaplus-tlatools-path' to the path of tla2tools.jar"))))

(defun tlaplus--detect-tlatools-jar ()
  "Try to find tla2tools.jar from tla-toolbox installation.
Searches: nix store, common install directories, and PATH-adjacent locations."
  (or
   ;; Nix: follow tla-toolbox symlink into store
   (when-let ((toolbox (executable-find "tla-toolbox")))
     (let ((real (file-truename toolbox)))
       (when (string-match "\\(/nix/store/[^/]+\\)" real)
         (let ((jar (expand-file-name "libexec/toolbox/tla2tools.jar"
                                      (match-string 1 real))))
           (when (file-exists-p jar) jar)))))
   ;; Generic: look relative to tla-toolbox or tla2tools on PATH
   (when-let ((toolbox (or (executable-find "tla-toolbox")
                           (executable-find "tla2tools"))))
     (let ((dir (file-name-directory (file-truename toolbox))))
       (cl-some (lambda (name)
                  (let ((f (expand-file-name name dir)))
                    (when (file-exists-p f) f)))
                '("tla2tools.jar" "../lib/tla2tools.jar"
                  "../share/java/tla2tools.jar"))))
   ;; Well-known locations
   (cl-some (lambda (path)
              (let ((f (expand-file-name path)))
                (when (file-exists-p f) f)))
            '("/opt/TLA+Toolbox/tla2tools.jar"
              "/usr/local/lib/tla2tools.jar"
              "/usr/share/java/tla2tools.jar"
              "~/tla2tools.jar"))))

(defun tlaplus--base-args ()
  "Return base java args list for TLA+ tools."
  (let ((args (list (tlaplus--java-command))))
    (unless (string-empty-p tlaplus-java-options)
      (setq args (append args (split-string-and-unquote tlaplus-java-options))))
    (append args (list "-cp" (tlaplus--tlatools-jar)))))

(defun tlaplus--module-path-args ()
  "Return -DTLA-Library args for module search paths."
  (when tlaplus-module-search-paths
    (list (concat "-DTLA-Library=" (string-join tlaplus-module-search-paths ":")))))

;;; SANY Parser Integration

(defvar tlaplus-sany-error-regexp
  '(tlaplus-sany "^\\(?:Semantic\\|Lexical\\|Parsing\\) error[^\n]*\n.*line \\([0-9]+\\), col \\([0-9]+\\).*of module \\([^ \n]+\\)"
                 3 1 2 2)
  "Compilation error regexp for SANY output.")

(defun tlaplus-parse-module ()
  "Parse the current TLA+ module with SANY."
  (interactive)
  (let* ((file (buffer-file-name))
         (cmd (string-join
               (append (tlaplus--base-args)
                       (tlaplus--module-path-args)
                       (list "tla2sany.SANY" file))
               " ")))
    (save-buffer)
    (compile cmd)))

;;; PlusCal Translator

(defun tlaplus-translate-pluscal ()
  "Translate PlusCal to TLA+ in the current module."
  (interactive)
  (let* ((file (buffer-file-name))
         (cmd (string-join
               (append (tlaplus--base-args)
                       (tlaplus--module-path-args)
                       (list "pcal.trans")
                       (unless (string-empty-p tlaplus-pluscal-options)
                         (split-string-and-unquote tlaplus-pluscal-options))
                       (list file))
               " ")))
    (save-buffer)
    (compile cmd)
    (add-hook 'compilation-finish-functions #'tlaplus--revert-after-translate nil t)))

(defun tlaplus--revert-after-translate (_buf _msg)
  "Revert buffer after PlusCal translation."
  (remove-hook 'compilation-finish-functions #'tlaplus--revert-after-translate t)
  (revert-buffer t t t))

;;; TLC Model Checker

(defvar tlaplus-tlc-error-regexp
  '(tlaplus-tlc "^Error: .* line \\([0-9]+\\), col \\([0-9]+\\).*module \\([^ \n]+\\)"
                3 1 2 2)
  "Compilation error regexp for TLC output.")

(defun tlaplus-run-tlc (&optional cfg-file)
  "Run TLC model checker on the current module.
With prefix arg or CFG-FILE, prompt for a .cfg file."
  (interactive
   (list (when current-prefix-arg
           (read-file-name "Config file: " nil nil t nil
                           (lambda (f) (string-suffix-p ".cfg" f))))))
  (let* ((file (buffer-file-name))
         (cfg (or cfg-file
                  (let ((default-cfg (concat (file-name-sans-extension file) ".cfg")))
                    (when (file-exists-p default-cfg) default-cfg))))
         (cmd (string-join
               (append (tlaplus--base-args)
                       (tlaplus--module-path-args)
                       (list "tlc2.TLC")
                       (unless (string-empty-p tlaplus-tlc-options)
                         (split-string-and-unquote tlaplus-tlc-options))
                       (when cfg (list "-config" cfg))
                       (list file))
               " ")))
    (save-buffer)
    (compile cmd)))

(defun tlaplus-stop-tlc ()
  "Stop the running TLC process."
  (interactive)
  (when-let ((buf (get-buffer "*compilation*")))
    (kill-compilation)))

;;; REPL / Expression Evaluation

(defvar tlaplus-repl-buffer-name "*TLA+ REPL*")

(defun tlaplus-repl ()
  "Start a TLA+ REPL using TLC in REPL mode.
Requires tla2tools.jar with tlc2.REPL (available in standalone
tla2tools.jar from TLA+ GitHub releases, not always in toolbox)."
  (interactive)
  (unless (comint-check-proc tlaplus-repl-buffer-name)
    (let* ((java (tlaplus--java-command))
           (jar (tlaplus--tlatools-jar))
           (args (append
                  (unless (string-empty-p tlaplus-java-options)
                    (split-string-and-unquote tlaplus-java-options))
                  (list "-cp" jar "tlc2.REPL"))))
      (apply #'make-comint-in-buffer "TLA+ REPL" tlaplus-repl-buffer-name
             java nil args)))
  (pop-to-buffer tlaplus-repl-buffer-name))

(defun tlaplus-evaluate-expression (expr)
  "Evaluate EXPR in the TLA+ REPL."
  (interactive "sExpression: ")
  (tlaplus-repl)
  (with-current-buffer tlaplus-repl-buffer-name
    (goto-char (point-max))
    (insert expr)
    (comint-send-input)))

(defun tlaplus-evaluate-region (beg end)
  "Evaluate the region BEG..END in the TLA+ REPL."
  (interactive "r")
  (tlaplus-evaluate-expression (buffer-substring-no-properties beg end)))

;;; LaTeX/PDF Export

(defun tlaplus-export-to-latex ()
  "Export the current TLA+ module to LaTeX."
  (interactive)
  (let* ((file (buffer-file-name))
         (cmd (string-join
               (append (tlaplus--base-args)
                       (list "tla2tex.TLA" "-shade" "-latexCommand" tlaplus-pdf-command file))
               " ")))
    (save-buffer)
    (compile cmd)))

(defun tlaplus-export-to-pdf ()
  "Export the current TLA+ module to PDF via LaTeX."
  (interactive)
  (let* ((file (buffer-file-name))
         (cmd (string-join
               (append (tlaplus--base-args)
                       (list "tla2tex.TLA" "-shade" "-latexCommand" tlaplus-pdf-command
                             "-latexOutputExt" "pdf" file))
               " ")))
    (save-buffer)
    (compile cmd)))

;;; TLAPS Integration

(defun tlaplus-prove-step ()
  "Check the current proof step with TLAPS."
  (interactive)
  (unless tlaplus-tlaps-enabled
    (error "Set `tlaplus-tlaps-enabled' to t to use TLAPS"))
  (let* ((file (buffer-file-name))
         (cmd (string-join
               (append tlaplus-tlaps-command
                       (list "--stretch" "3" "--method" "blast"
                             file))
               " ")))
    (save-buffer)
    (compile cmd)))

;;; Error Parsing

(with-eval-after-load 'compile
  (add-to-list 'compilation-error-regexp-alist-alist tlaplus-sany-error-regexp)
  (add-to-list 'compilation-error-regexp-alist 'tlaplus-sany)
  (add-to-list 'compilation-error-regexp-alist-alist tlaplus-tlc-error-regexp)
  (add-to-list 'compilation-error-regexp-alist 'tlaplus-tlc))

;;; .cfg file mode

(define-derived-mode tlaplus-cfg-mode prog-mode "TLA+Cfg"
  "Major mode for TLA+ .cfg model files."
  (setq-local comment-start "\\* ")
  (setq-local comment-end "")
  (setq-local font-lock-defaults
              '(((("\\<\\(CONSTANTS?\\|INIT\\|NEXT\\|SPECIFICATION\\|INVARIANTS?\\|PROPERTIES\\|SYMMETRY\\|CONSTRAINT\\|ACTION_CONSTRAINT\\|VIEW\\|CHECK_DEADLOCK\\|POSTCONDITION\\|ALIAS\\)\\>"
                   . font-lock-keyword-face)
                  ("\\\\\\*.*$" . font-lock-comment-face))))))

(add-to-list 'auto-mode-alist '("\\.cfg\\'" . tlaplus-cfg-mode))

;;; Keymap

(defvar-keymap tlaplus-ts-mode-map
  :doc "Keymap for `tlaplus-ts-mode'."
  "C-c C-p" #'tlaplus-parse-module
  "C-c C-t" #'tlaplus-translate-pluscal
  "C-c C-c" #'tlaplus-run-tlc
  "C-c C-k" #'tlaplus-stop-tlc
  "C-c C-e" #'tlaplus-evaluate-expression
  "C-c C-r" #'tlaplus-evaluate-region
  "C-c C-l" #'tlaplus-export-to-latex
  "C-c C-d" #'tlaplus-export-to-pdf
  "C-c C-u" #'tlaplus-insert-unicode
  "C-c C-s" #'tlaplus-prove-step)

(easy-menu-define tlaplus-ts-mode-menu tlaplus-ts-mode-map
  "Menu for TLA+ mode."
  '("TLA+"
    ["Parse Module (SANY)" tlaplus-parse-module]
    ["Translate PlusCal" tlaplus-translate-pluscal]
    "---"
    ["Run TLC" tlaplus-run-tlc]
    ["Stop TLC" tlaplus-stop-tlc]
    "---"
    ["Evaluate Expression..." tlaplus-evaluate-expression]
    ["Evaluate Region" tlaplus-evaluate-region]
    ["Open REPL" tlaplus-repl]
    "---"
    ["Export to LaTeX" tlaplus-export-to-latex]
    ["Export to PDF" tlaplus-export-to-pdf]
    "---"
    ["Insert Unicode Symbol" tlaplus-insert-unicode]
    ["Check Proof Step (TLAPS)" tlaplus-prove-step]))

;;; Mode Definition

(defun tlaplus-ts-mode--indent-line ()
  "Indent the current line.
Falls back to column 0 when tree-sitter has no node at point
\(e.g. extramodular text after `====')."
  (if (treesit-node-at (save-excursion (back-to-indentation) (point)))
      (treesit-indent)
    (indent-line-to 0)))

(defun tlaplus-ts-mode--indent-region (beg end)
  "Indent region BEG..END, handling lines with no tree-sitter node."
  (save-excursion
    (goto-char beg)
    (while (and (< (point) end) (not (eobp)))
      (unless (looking-at-p "[ \t]*$")
        (tlaplus-ts-mode--indent-line))
      (forward-line 1))))

;;;###autoload
(define-derived-mode tlaplus-ts-mode prog-mode "TLA+"
  "Major mode for editing TLA+ files, powered by tree-sitter.

\\{tlaplus-ts-mode-map}"
  :group 'tlaplus
  (unless (treesit-ready-p 'tlaplus)
    (error "Tree-sitter grammar for TLA+ is not available"))

  (treesit-parser-create 'tlaplus)

  (setq-local treesit-font-lock-settings
              (apply #'treesit-font-lock-rules
                     tlaplus-ts-mode--font-lock-rules))

  (setq-local treesit-font-lock-feature-list
              '((comment)
                (keyword string)
                (number type module definition constant variable)
                (parameter property label delimiter operator)))

  (setq-local treesit-simple-indent-rules tlaplus-ts-mode--indent-rules)
  (setq-local treesit-simple-imenu-settings tlaplus-ts-mode--imenu-settings)
  (setq-local treesit-defun-type-regexp tlaplus-ts-mode--defun-type-regexp)

  (setq-local comment-start "\\* ")
  (setq-local comment-end "")
  (setq-local comment-start-skip "\\\\\\*[ \t]*\\|([*][ \t]*")

  (treesit-major-mode-setup)
  (setq-local indent-line-function #'tlaplus-ts-mode--indent-line)
  (setq-local indent-region-function #'tlaplus-ts-mode--indent-region))

(if (treesit-ready-p 'tlaplus t)
    (add-to-list 'auto-mode-alist '("\\.tla\\'" . tlaplus-ts-mode)))

(provide 'tlaplus-ts-mode)
;;; tlaplus-ts-mode.el ends here
