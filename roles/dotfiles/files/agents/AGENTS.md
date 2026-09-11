# MCP Tool Guidelines

Choose tools by the information or action needed. Prefer the relevant MCP when
it is available and supports the task; use native tools for small, direct operations.

## Availability and routing

- Check the tools exposed by the current client and their schemas before using
  an unfamiliar capability. Names below may have a client-specific MCP prefix.
- Use serena for semantic code navigation and Context7 for dependency documentation.
- If a server, language, or operation is unavailable, or results are incomplete,
  use targeted native reads, `rg`, or the project's compiler, linter, and tests.
  Briefly report the limitation. Retry only when new information can resolve it.
  A permission denial still requires the client's normal approval workflow.
- Reuse current evidence. Repeat a lookup when the relevant code or question
  changes, not merely because another edit is about to happen.

## serena: semantic navigation and edits

- **Mandatory on LSP-enabled codebases** (Python, Rust, Go, TS/JS, etc.): Always query Serena BEFORE falling back to broad file reading (`view_file`). Never dump whole source files when exploring or modifying symbols.
- **Symbol Exploration**:
  - Inspect file or module structure with `get_symbols_overview`.
  - Locate targets with `find_symbol` (use `include_body=False` to inspect structure/signatures, `include_body=True` only for the target body).
  - Use `find_declaration` and `find_implementations` to trace definitions and implementations.
- **Impact Analysis & Safe Refactoring**:
  - Before modifying contracts or deleting code, audit callers with `find_referencing_symbols`. Supplement with `search_for_pattern` or `rg` for dynamic usages and config references.
  - Prefer `rename_symbol` to rename symbols atomically across definitions and references.
  - Prefer `safe_delete_symbol` to delete unused symbols safely (verifies absence of references).
- **Symbolic Editing vs. File Editing**:
  - Prefer `replace_symbol_body` when replacing an entire function, method, or class.
  - Use `insert_before_symbol` or `insert_after_symbol` to inject new top-level declarations or methods.
  - For repeated edits across multiple files, prefer `replace_in_files` (always with `dry_run=True` first).
  - Use `replace_content` (Serena) or native line-replacement tools (`replace_file_content` in agy, `apply_patch` in Codex) for small, localized tweaks inside a body or in non-symbolic files.
- **Diagnostics & Quality**:
  - After code modifications, check for regressions using `get_diagnostics_for_file` before running project linters, compilers, or tests.
- **Project Memories**:
  - Consult `list_memories` and `read_memory` for project context and architecture decisions.
  - Store durable patterns, gotchas, or workspace conventions with `write_memory`.
- **Non-LSP Boundary**:
  - For plain text, config files (YAML, TOML, JSON), shell scripts, and templates lacking structured LSP symbols, use targeted native tools (`grep_search`, `rg`, native file editing).

## Context efficiency

Minimize unnecessary context usage while preserving enough evidence for correct work.

- Prefer LSP operations for definitions, references, implementations, symbols,
  and diagnostics when available. For text and file discovery, use targeted `rg`,
  `rg --files`, or equivalent searches before reading files.
- Read relevant line ranges around symbols or search matches. Read small files
  in full when useful; read entire large files only when the task requires it.
- Avoid large unfiltered command outputs. Filter build logs, test output, JSON,
  logs, diffs, and command results before returning them to the model. Use `rg`,
  `sed`, `jq`, `head`, `tail`, or equivalent tools to keep outputs focused.
- Programmatic filtering and inspection ("think in code"): When standard tools
  (`rg`, `jq`, `sed`) fall short for complex data structures, multi-step aggregation,
  or binary inspection, execute inline Python one-liners (`python3 -c "..."`) or
  temporary scratch scripts. Let local code process and filter evidence before
  returning only the minimal pertinent slice to context. Never use scripts to
  circumvent Serena on LSP-supported codebases.
- Preserve errors, exit codes, and enough surrounding context to diagnose failures.
  When truncating output, make that explicit; retain full logs in a temporary file
  when further investigation may be needed. Do not infer success from filtered output.
- Start broad change reviews with `git diff --stat` or `git diff --name-only`,
  then inspect targeted or file-specific diffs instead of dumping the entire diff.
- Reuse content already available in the current context unless it changed or
  verification is necessary. Batch independent lookups; keep dependent steps sequential.
- Expand retrieved context progressively when current evidence is insufficient.
  Read a larger coherent section when it avoids repeated fragmented reads or guesses.
- For small localized edits or in files without active LSP support, use native editing
  tools such as `apply_patch` in Codex or `replace_file_content` in agy.

## Context7: dependency documentation

- When external API behavior, signatures, or configuration are uncertain, use
  `resolve-library-id` then `query-docs`, targeting the dependency version in use.
  Reuse a library ID or documentation already established for that version.
- If the library or version is unavailable, consult its official documentation
  or installed declarations and state any remaining uncertainty.
