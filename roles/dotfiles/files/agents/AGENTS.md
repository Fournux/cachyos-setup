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

- Locate symbols with `find_symbol` and inspect file or directory structure with
  `get_symbols_overview`. Use `find_symbol` with `include_body=True` or
  `find_declaration` to inspect declarations and bodies. Use `find_implementations`
  when concrete implementations matter.
- Before deleting a symbol or changing a contract or behavior that affects callers,
  audit callers and call relationships with `find_referencing_symbols`.
  LSP results may omit dynamic usages and unsupported files. Supplement them with
  `search_for_pattern` or targeted `rg` for text, config keys, and paths.
- For symbol renames and structured modifications, prefer `rename_symbol`,
  `replace_symbol_body`, `insert_after_symbol`, or `insert_before_symbol`.
  Verify the resulting diff; a successful tool response does not prove files changed.
- After a coherent set of edits, check for regressions using `get_diagnostics_for_file`.
  Distinguish new errors from existing ones and run the relevant compiler, linter,
  or tests before reporting completion.

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
- Preserve errors, exit codes, and enough surrounding context to diagnose failures.
  When truncating output, make that explicit; retain full logs in a temporary file
  when further investigation may be needed. Do not infer success from filtered output.
- Start broad change reviews with `git diff --stat` or `git diff --name-only`,
  then inspect targeted or file-specific diffs instead of dumping the entire diff.
- Reuse content already available in the current context unless it changed or
  verification is necessary. Batch independent lookups; keep dependent steps sequential.
- Expand retrieved context progressively when current evidence is insufficient.
  Read a larger coherent section when it avoids repeated fragmented reads or guesses.
- Use native editing tools for persistent changes, such as `apply_patch` in Codex
  or `replace_file_content` in agy.

## Context7: dependency documentation

- When external API behavior, signatures, or configuration are uncertain, use
  `resolve-library-id` then `query-docs`, targeting the dependency version in use.
  Reuse a library ID or documentation already established for that version.
- If the library or version is unavailable, consult its official documentation
  or installed declarations and state any remaining uncertainty.
