# MCP Tool Guidelines

Choose tools by the information or action needed. Prefer the relevant MCP when
it is available and supports the task; use native tools for small, direct operations.

## Availability and routing

- Check the tools exposed by the current client and their schemas before using
  an unfamiliar capability. Names below may have a client-specific MCP prefix.
- Use mcpls for semantic code navigation, context-mode for processing large
  outputs, and Context7 for dependency documentation.
- If a server, language, or operation is unavailable, or results are incomplete,
  use targeted native reads, `rg`, or the project's compiler, linter, and tests.
  Briefly report the limitation. Retry only when new information can resolve it.
  A permission denial still requires the client's normal approval workflow.
- Reuse current evidence. Repeat a lookup when the relevant code or question
  changes, not merely because another edit is about to happen.

## mcpls: semantic navigation and edits

- Locate symbols with `workspace_symbol_search` and declarations with
  `get_definition`. Use `get_hover` to resolve unknown types or signatures before
  changing call sites; use `go_to_implementation` when concrete implementations matter.
- Before deleting a symbol or changing a contract or behavior that affects callers,
  inspect `get_references`; use `get_incoming_calls` for call relationships.
  LSP results may omit dynamic usages and unsupported files. Supplement them with
  targeted text searches when needed. Use `rg` directly for text, config keys, and paths.
- For symbol renames, prefer `rename_symbol`. Inspect the returned edits and apply
  them with native editing tools if the server only returns a workspace edit.
  Verify the resulting diff; a successful tool response does not prove files changed.
- After a coherent set of edits, request current `get_diagnostics` for affected
  files. `get_cached_diagnostics` reads notifications without triggering analysis;
  an empty cache is not proof that the latest changes are valid. If freshness cannot
  be established, use the project's validator. Distinguish new errors from existing
  ones and run the relevant compiler, linter, or tests before reporting completion.

## context-mode: process data before returning it

- Use `ctx_execute_file` to analyze large files through `FILE_CONTENT`, and
  `ctx_execute` to process logs, test output, JSON, or other potentially large results.
  Print focused findings with useful evidence: paths, line numbers, exact excerpts,
  errors, and exit codes. Preserve command failures when summarizing output.
- Use native reading tools for small files needed in full, specific snippets, and
  exact text needed for an edit. Use native editing tools for persistent changes
  (for example, `apply_patch` in Codex or `replace_file_content` in agy).
  Do not rely on analysis sandboxes to persist repository edits.
- Group independent exploration commands with `ctx_batch_execute` and include
  related questions in `queries`. Keep dependent commands and mutations sequential.
- Index large documents or bounded directory selections with `ctx_index` when
  repeated searches will be useful. Prefer `path` for existing files and descriptive
  source labels. Query with `ctx_search`, batching related questions in `queries`
  and using `source` to scope results. Check source freshness after edits.
- For large web pages or API responses needed for research, use
  `ctx_fetch_and_index` followed by `ctx_search` when the tool supports the request.
  For other tools, prefer a supported file-output option, then process or index
  that file. Do not paste large responses already in context into `ctx_index` again.
- Use `ctx_doctor` when diagnosing context-mode problems and `ctx_stats` when
  savings or usage statistics are requested; neither is a routine prerequisite.

## Context7: dependency documentation

- When external API behavior, signatures, or configuration are uncertain, use
  `resolve-library-id` then `query-docs`, targeting the dependency version in use.
  Reuse a library ID or documentation already established for that version.
- If the library or version is unavailable, consult its official documentation
  or installed declarations and state any remaining uncertainty.
