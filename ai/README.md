# movim AI — separate installer edition

An optional Neovim edition with an **AI Panel**, isolated Pi chat tabs, full unsaved-buffer context, and selection-only proposals. Source, tests, pinned runtime lockfile, and installer scripts live in this `ai/` folder. The regular movim installer remains available separately.

## Installers

Executable packages are published as GitHub Release assets (the Windows installer exceeds GitHub's 100 MB Git-file limit):

- [Windows: movim-AI-Setup.exe](https://github.com/moeinparvizi/movim/releases/latest/download/movim-AI-Setup.exe)
- [macOS: movim-AI-macOS.zip](https://github.com/moeinparvizi/movim/releases/latest/download/movim-AI-macOS.zip)
- [Checksums](https://github.com/moeinparvizi/movim/releases/latest/download/SHA256SUMS)
- [راهنمای کامل فارسی](../docs/AI-PANEL.md)

Windows installs to `%LOCALAPPDATA%/Programs/movim-ai`, with its own configuration and state. It bundles Node, Pi, Neovim and the regular editor runtime. It does not add competing `movim`/`nvim` commands to PATH. Use the **movim AI** Start menu entry or `movim-ai.cmd` inside its installation directory.

macOS installs to `~/.config/movim-ai`, uses `NVIM_APPNAME=movim-ai`, and creates `~/.local/bin/movim-ai`. Homebrew is a prerequisite; the installer installs editor dependencies and runs `npm ci --ignore-scripts` against the included lockfile. This requires internet access. Full interactive macOS installation must be tested on a Mac; native headless tests run in CI.

## Configure the model

Run `:AIConfigure` for an OpenAI-compatible endpoint. Enter the endpoint, exact model ID, verified context-window size, and an **environment variable name**, not an API key. The provider settings are stored in the AI edition's Neovim state directory. When the variable is missing, configuration opens a hidden API-key prompt. You can also use `:AIKey` at any time while no requests are running. The key is kept only in the current process environment, never in provider.json or command history; re-enter it after restarting, or export the configured variable before launching. No credentials ship in these installers.

For example, configure your provider's actual URL and model, then enter your key using `:AIKey` (or set `MOVIM_AI_API_KEY` in your terminal). There is no bundled account or guaranteed access to GapCode models. A model name such as Luna is usable only if your provider exposes it through a supported API with your own authorization.

Advanced trusted configuration, set before startup:

```lua
vim.g.movim_ai = {
  provider = 'my-provider', model = 'exact-model-id',
  base_url = 'https://your-provider.example/v1',
  api = 'openai-completions', api_key_env = 'MOVIM_AI_API_KEY',
  context_window = 32768, output_tokens = 4096,
  sensitive_policy = 'deny',
  keys = { toggle = '<leader>aa', selection = '<leader>ae', attach = '<leader>af' },
}
```

With `base_url=''`, Pi's built-in provider/model catalog and its standard provider environment variables can be used. The model context size is checked again through RPC before each request. No arbitrary extensions, extra command-line flags, auth shell commands, or project settings are loaded.

## Keyboard workflow

| Action | Command / default mapping |
|---|---|
| Toggle panel, preserve tabs | `:AIPanel` / `Space aa` |
| Select code and ask for a change in a new tab | Visual `Space ae` |
| Attach current unsaved buffer | `:AIAttach` / `Space af` |
| Attach current buffer to a new tab | `:AIAttach!` |
| Choose a file, using an existing unsaved buffer when open | `:AIFile path` / `:AIFile! path` |
| Send chat / make tab / choose tab / rename | `:AIChat` / `:AINew` / `:AISelect` / `:AIRename` |
| Close tab / cancel request | `:AICloseTab` / `:AICancel` |
| Refresh / remove attached snapshots | `:AIRefresh` / `:AIRemove` |
| Show selection diff / accept / reject | `:AIPreview` / `:AIApply` / `:AIReject` |
| Refine a pending proposal | `:AIRevise` |
| Return to source and select again after edits | `:AIRerun`, then Visual `Space ae` |
| Move / resize panel | `:AIMove left\|right\|top\|bottom` / `:AIResize 60` |

Inside the panel: `i` chat, `n` new tab, `t` choose tab, `r` rename, `x` close tab, `Ctrl-C` cancel, `d` diff, `a` apply, `R` reject, `q` hide. Override `panel_keys` or `keys` in trusted Lua configuration; set individual mappings to `false` to disable them. Panel tabs do not create editor tabpages. Closing a running tab asks whether to cancel it; hiding the panel leaves requests running.

## Safety and limitations

- Pi **0.73.1**, exact dependency and transitive lockfile; official JSONL RPC over stdio, LF framing across arbitrary chunks.
- Empty tool/extension allowlists: `--no-tools --no-extensions --no-skills --no-prompt-templates --no-themes --no-context-files`. Each tab has a separate process, empty working directory and private agent directory. No project test or command execution.
- The full current buffer and explicit attachments are sent as data. Nothing is silently truncated. The budget conservatively counts UTF-8 bytes, history, framing and output reserve; oversized context stops and offers removing attachments, a new tab, or a larger model.
- `.env`, private keys, SSH paths and common credentials/secrets paths are denied by default. Configure `sensitive_patterns`; only set `sensitive_policy='allow'` after reviewing what you intend to send. This is a path policy, not a general secret scanner.
- A proposal must be exactly `{requestId,snapshotId,replacementText,explanation}`. The editor owns the target range, buffer identity, changedtick and snapshot. Stale, mismatched, incomplete or cancelled output cannot apply.
- Apply changes only the captured selection, one Undo block, no auto-save. Any source edit (even edit then Undo) requires a new selection/request. Reject changes nothing. Character and line selections work; block selections are explicitly refused.
- Conversations persist while the editor runs, including panel hide/show. They are not restored after exit. Cancellation kills that tab's Pi process; transcript remains visible, but the next request uses a fresh Pi session. No silent history compaction.
- Multi-file edits, partial-diff acceptance, LSP context gathering and automatic test execution are not included.

## Build and validate

From the repository root:

```text
cd ai/runtime
npm ci --ignore-scripts --no-audit --no-fund
cd ../..
nvim --headless -u NONE -l ai/tests/acceptance.lua
node ai/tests/rpc.cjs /path/to/nvim
```

From the parent workspace on Windows:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File neovim/installer/build-installers.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File neovim/ai/build-installers.ps1
```

Outputs: `ai/dist/movim-AI-Setup.exe`, `ai/dist/movim-AI-macOS.zip`, `ai/dist/SHA256SUMS`. Both editions share the release version. CI runs acceptance and real Pi RPC integration against a **synthetic localhost HTTP provider**; this tests transport, tool isolation and proposal flow without a paid API. It does not establish the quality/availability of a live model. Luna additionally reviewed the implementation and reran the headless acceptance tests.

Pinned protocol references: [Pi RPC](https://github.com/earendil-works/pi/blob/v0.73.1/packages/coding-agent/docs/rpc.md), [CLI flags](https://github.com/earendil-works/pi/blob/v0.73.1/packages/coding-agent/src/cli/args.ts), [model configuration](https://github.com/earendil-works/pi/blob/v0.73.1/packages/coding-agent/docs/models.md).
