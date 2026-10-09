# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A personal collection of plugins for [Noctalia](https://noctalia.dev) v5, a Wayland desktop shell. Plugins are
Luau scripts the shell loads and calls; there is no build step and no compiled artifact. These are not published
to the plugin store, so the store's submission rules (see "Publishing" below) are optional here.

- `ticktick-integration/` (`agokule/ticktick-integration`) — the plugin under active development.
- `example/` — **not one of these plugins.** A copy of `noctalia/example` from the official-plugins repo, kept as
  read-only API documentation. Don't edit it, "fix" it, or copy its id or settings into a real plugin. It differs
  from upstream only cosmetically; upstream may have moved on, so check there for anything new.
- `noctalia.d.luau` — luau-lsp definitions for the whole host API, gitignored, refetched with
  `just fetch-plugin-api`. **It is the authoritative API reference**: read it before using any `noctalia.*`, `ui.*`,
  `barWidget.*`, `shortcut.*`, `launcher.*`, `desktopWidget.*` or `panel.*` member. Its header names the API level
  it describes, and members carry the level they arrived in ("API 26"). UI prop tables in it are exhaustive.
- `.nvim.lua` + `.nvim/lsp/luau_lsp.lua` — Neovim luau-lsp setup that loads `noctalia.d.luau` as `@noctalia`.
  `.luaurc` (the same as upstream's) sets nonstrict mode and turns off `FunctionUnused`, which would otherwise
  flag every host callback.

The running shell (`noctalia --version`) is v5.2.1, which supports plugin API levels up to 32.

## Where to look things up

Read in this order. Each layer covers what the one before it doesn't.

1. **`noctalia.d.luau`** — signatures, prop names, value shapes, API levels, the entry-callback list (at the
   bottom, as a comment: callbacks are deliberately not declared there).
2. **The docs, as source** — <https://github.com/noctalia-dev/noctalia-docs>, under
   `src/content/docs/noctalia/plugins/development/`: `manifest.mdx`, `entries.mdx`, `declarative-ui.mdx`,
   `runtime-api.mdx`, `plugin-api.mdx`, `workflow.mdx`. Fetch them raw from
   `https://raw.githubusercontent.com/noctalia-dev/noctalia-docs/main/<path>`; that's more complete than scraping
   docs.noctalia.dev. The per-level API ledger is `src/data/plugin-api.json`. **Ignore `noctalia-shell-legacy/`**:
   it documents v4's QML plugin system, which is unrelated.
3. **Official plugins** — <https://github.com/noctalia-dev/official-plugins>. Pick by what you're building:
   - `timer` — **the multi-entry reference**: one service owns state; bar widget, panel and desktop widget are
     thin clients over `noctalia.state`. Also the desktop-widget reference.
   - `example` — every entry type in miniature (also copied here); `panel.luau` exercises every interactive control,
     `dnd.luau` drag and drop.
   - `notes` — full-height panel, launcher, files on disk. `world_clock` — plugin- vs panel-level settings,
     `pluginDataDir` persistence. `bitwarden` — login/unlock panels (`keyboard_focus`, `dismiss_on_outside_click`),
     a network-backed launcher with `debounce_ms`. `wallhaven` — HTTP, downloads, image grid.
     `umbriel-companion` — a request channel from UI entries to a service.
   - `.github/workflows/validate-plugins.py` — the store's validator; it encodes every manifest rule CI enforces.
4. **Community plugins** — ~240 of them. The shell already keeps a clone at
   `~/.local/state/noctalia/plugins/sources/community/repo` (and `…/official/repo`). **Those clones belong to the
   shell: read only, never modify.** They have no working tree and are partial (`blob:none`) clones, so every file
   read may hit the network. Read them through git with single bulk commands, not per-file loops:
   ```sh
   C=~/.local/state/noctalia/plugins/sources/community/repo
   git -C $C show HEAD:catalog.toml                          # ids, descriptions, plugin_api, tags
   git -C $C grep -l '^\[\[desktop_widget\]\]' HEAD -- '*/plugin.toml'
   git -C $C show HEAD:vikunja/service.luau
   ```
   The ones worth knowing for TickTick work:
   - `omertahaoztop/vikunja` (dir `vikunja/`) — **the closest analog**: a token-authed REST task manager with today's
     and overdue tasks, quick add, complete and postpone. Its service is a model for an API client.
   - `fel/quill` — a desktop widget listing todos that opens a panel to edit them.
   - `nightwatch75/todo` and `redxtech/super-productivity` — task UIs.

## Development loop

This repo is registered with the running shell as the `path` source `my-local-plugins`, so it runs straight from
this checkout. There's no install step.

```sh
just fetch-plugin-api                          # refetch noctalia.d.luau from official-plugins
noctalia plugins lint ticktick-integration     # offline: declared settings vs. what the code reads
luau-lsp analyze --platform=standard --definitions:@noctalia=noctalia.d.luau <files>   # offline type check
noctalia msg plugins list                      # installed plugins, source, enabled state
noctalia msg config-reload                     # pick up plugin.toml changes
noctalia msg plugins disable agokule/ticktick-integration   # disable + enable: full restart of every entry
noctalia msg plugins enable  agokule/ticktick-integration
noctalia msg plugin agokule/ticktick-integration:<entry> all <event> [payload]   # -> onIpc(event, payload)
noctalia msg panel-toggle agokule/ticktick-integration:<panel-id> [context]     # -> onOpen(context)
noctalia msg settings-open-plugin agokule/ticktick-integration
grep '\[luau\]' ~/.cache/noctalia/noctalia.log | grep ticktick | tail -20      # script errors
```

- **`.luau` edits hot-reload by themselves.** The log confirms each one (`hot reload: reloaded service '…'`).
  That includes required modules that have already loaded. A module that *failed* to load isn't watched, so after
  fixing one, touch the entry script. Manifest changes need `config-reload`.
- **IPC targets:** bar widgets take `focused`, a connector (`DP-1`), `<connector>:<bar>`, or `all`. Services,
  panels, launcher providers and other non-bar entries have no output and only match **`all`**.
- **The log is `~/.cache/noctalia/noctalia.log`** (rotated to `.1`). Script failures look like
  `[ERR] [luau] plugin <id>:<entry>: call to '<fn>' failed: <file>:<line>: <message>`. `chunk` means the top
  level failed at load, and `async http callback` means an error inside an HTTP callback. `luau_load failed` is a
  syntax error, often a bad type annotation. `noctalia.log(msg)` writes here too. Unknown UI props and undeclared
  `getConfig` keys appear as warnings and are skipped, not raised as errors. When something just doesn't show
  up, check the log first.
- **`luau-lsp analyze` reports false `Unknown require` errors inside `smart_recognition/init.luau`.** luau-lsp
  applies standard Luau `init` semantics and resolves that file's `./x.luau` from the *parent* directory. Noctalia
  resolves from the file's own directory, and Noctalia is what counts. Errors anywhere else are real.
- Anything that touches the host API can only be verified by letting it reload in the shell. Pure logic can be
  tested offline (see "Testing").

## How the plugin runtime works

**Entries.** `plugin.toml` declares one table per entry, each naming a `.luau` file:

| Table | What it is | Rendering |
| --- | --- | --- |
| `[[widget]]` | bar widget, one instance per placement | imperative `barWidget.setText/setGlyph/…` *or* `barWidget.render(ui tree)` |
| `[[desktop_widget]]` | tile on the desktop; the user places and sizes it | `desktopWidget.render(ui tree)` |
| `[[panel]]` | pop-up surface opened by id, takes keyboard focus | `panel.render(ui tree)` |
| `[[launcher_provider]]` | results behind a `/prefix` | `launcher.setResults` |
| `[[shortcut]]` | control-center toggle tile | `shortcut.setLabel/setIcon/setActive` |
| `[[service]]` | headless singleton, runs while the plugin is enabled | none |

An entry is addressed `author/plugin:entry-id`, which is what `togglePanel`, IPC and bar config use.

**Isolation.** Each entry runs in its own Luau VM, off the UI thread, with a per-call time budget. Entries of one
plugin share **no Lua memory**. They talk through `noctalia.state` (in-memory, `get`/`set`/`watch`) or IPC
(`onIpc`). Durable data goes in files under `noctalia.pluginDataDir()`.

**Callbacks are globals.** The host calls global functions: `update`, `onClick`, `onRightClick`,
`onMiddleClick`, `onScroll`, `onHover`, `onQuery`, `onActivate`, `onOpen`, `onClose`, `onKey`, `onFrameTick`,
`onIpc`, `onConfigChanged`, `onEnable`, `onOutputsChanged`, `onExit`. They can't be `local`, and they must be
defined **in the entry file itself** (see Modules). The full list, with which entry gets which, is at the bottom
of `noctalia.d.luau`. The top level of an entry runs once at load; set up state and register
`noctalia.state.watch` handlers there.

**Modules** (`require`, API 22). The path must start with `./` or `../` and end in `.luau`. It resolves
**relative to the file containing the `require` call**: inside `api/`, `require("./types.luau")` means
`api/types.luau`, and `"./api/types.luau"` would look for `api/api/types.luau`. `init.luau` has no special meaning
and there are no search paths. A module must return one non-nil value. Each module gets **its own global
environment**: globals it assigns are private to it, so the host never sees a callback defined in a module.
Each entry keeps its own module cache, so the same module required from two entries is two separate instances.
Circular requires fail.

**Shared state.** `noctalia.state` values are copied between VMs, so they must be plain data (strings, numbers,
booleans, nested tables of those, never functions). Treat a `get` result as a snapshot: change it, then `set` it
again. `get` returns `nil` until some entry has set the key, and a launcher or widget can load before the service's
first publish, so always default (`noctalia.state.get("data") or {...}`). A `watch` also fires in the entry that
did the `set` (`timer/service.luau` relies on this). State is in-memory only: it survives a service restart, but
is cleared when the plugin stops or the shell exits.

**Settings.** `noctalia.getConfig(key)` reads only keys declared in the manifest. An undeclared key logs a warning
and returns `nil`. Scopes:
- Root `[[setting]]` is plugin-level, seeded into **every** entry, and edited in Settings → Plugins (the gear).
  Anything a service needs goes here.
- `[[widget.setting]]` belongs to one bar-widget instance and isn't visible to other entries.
  `[[panel.setting]]` / `[[desktop_widget.setting]]` are the panel and desktop-widget equivalents.
- A setting with no `default` is `nil` until the user sets it, so guard before concatenating it
  (`"Bearer " .. nil` throws).
- Types are `string`, `string_list`, `string_map` (API 6), `bool`, `int`, `double`, `select` (`options` =
  `{ value, label_key }`), `file` (`extensions`), `folder`, `glyph`, `color`. Fields are `min`/`max`/`step`,
  `visible_when = { key, values = ["…"] }` and `advanced = true`.
- Labels are always `label_key`/`description_key` lookups into `translations/en.json`. Literal labels are
  rejected. Nest the JSON as objects (`{"settings": {"api_key": {"label": …}}}`), with lowercase single-segment
  keys and no dots inside a key. Script strings use `noctalia.tr(key, subst)` / `noctalia.trp(key, n)`.
- **When settings change:** widgets, desktop widgets and panels are rebuilt. A service that defines
  `onConfigChanged()` keeps running and sees the new values. One that doesn't is **restarted** (its top level runs
  again). Either way state survives, so key any cache by the settings it was fetched with.

**`plugin_api`** is the *minimum* host API level the plugin needs. Raise it when you use something newer, and not
before. `noctalia.d.luau` annotates most members. Manifest options and behaviours it doesn't annotate: 5
`dragSource`/`dropZone`; 6 `string_map`; 8 `dismiss_on_outside_click`; 9 **function closures as UI callbacks**
(before 9, only global-name strings); 10 `keyboard_focus`; 11 `persistent` panels; 13 `capture_keys` + `onKey`;
14 `[widget.actions]`; 17 `onEnable`, the `onExit` reason, and services starting on enable; 18 panel frame ticks;
21 `ui.markdown`, `submitOnEnter`, scroll follow props; 22 `require`; 24 argv form of `runAsync`; 30 panel `layer`;
32 `tooltip` on box/row/column/image. The full ledger is `plugin-api.json` in the docs repo.

**Luau, not Lua 5.4.** You get `+=`/`-=`/`..=`, backtick interpolation (`` `{n} tasks` ``), `if c then a else b`
expressions, `continue`, `//`, generalized iteration (`for k, v in t`), type annotations and
`export type`/`--!nonstrict`. There is no `goto` and no integer subtype. `os.time()`, `os.date()` and
`noctalia.formatTime()` are whole-second; `noctalia.nowMs()` is the only sub-second clock.

## Declarative UI, by surface

`ui.*` trees are retained: the host diffs each render and updates native controls in place, so re-rendering an
unchanged tree is cheap. Give list children a stable `key`.

| | bar widget (`render`) | desktop widget | panel |
| --- | --- | --- | --- |
| `button`, clickable `row`/`column`/`box`/`image` | yes | yes | yes |
| `toggle`, `slider` | yes | not documented either way | yes |
| Keyboard controls (`input`, `select`, `scroll`) | **no** | **no**: can't take focus | yes |
| Tooltips | yes | **no** | yes |
| Drag and drop, `openContextMenu`, `onKey` | no | no | yes |
| Ticks | `setUpdateInterval` only | `setWantsSecondTicks`, `setNeedsFrameTick` | same as desktop, while open |
| Size | bar thickness on the cross axis; one control tall | user-owned | manifest `width`/`height` (px or `"fill"`) |

- **Callbacks** take a function (API 9+, render-scoped: replaced on every render) or the *name* of a global.
  Arguments always arrive as strings: toggles get `"true"`/`"false"`, selects get the index, sliders the number as
  text. A closure captures its row, which is the easy way to give each list row its own handler. Named handlers
  are needed where a callback must outlive the render (a graph's teardown `onPointerLeave`).
- **Controlled vs. uncontrolled:** `toggle`/`slider`/`select` are value-driven, so pass the current value on every
  render. `input` is uncontrolled: `value` seeds it once, the host owns the text afterwards, and edits come back
  through `onChange`/`onSubmit`. Keep its `key` stable. `focus = true` only applies when the input is created.
- **Layout:** column/row/scroll stretch children across the cross axis by default, so pass `align = "center"` for a
  row of centered items. `opacity` fades the whole group; for a translucent background with opaque text use a
  translucent `fill` (`"surface_variant/0.6"`). Colors are palette roles (`primary`, `on_surface`, `error`,
  `outline`, …), a role with alpha (`primary/0.6`), or hex.
- **Bar widgets:** branch on `barWidget.isVertical()` (row vs. column). Once `render()` has run,
  `setText`/`setGlyph`/… do nothing. Inline controls take their own clicks; the widget-level `onClick` gets the
  rest of the capsule. **Middle click opens the widget's settings by default**, so `onMiddleClick` never fires
  unless the manifest declares `[widget.actions] middle = "none"`, and a user's gesture bindings override any
  callback. The timer plugin notes that `clearTooltip()` with no tooltip set crashed the entry, so track whether
  one is set.
- **Panels:** render in `onOpen` and again after every state change. Size is fixed by the manifest, and there's
  no runtime `setSize`. Manifest keys: `placement` (`attached`/`floating`), `position` (`auto`, `center`,
  `top_left` … `bottom_right`), `open_near_click`, `keyboard_focus` (`on_demand`/`exclusive`/`none`),
  `dismiss_on_outside_click` (set it `false` for credential prompts), `persistent`, `capture_keys`, `layer`.
  Open one from code with `noctalia.togglePanel("author/plugin:panel")`, which **takes no context**, so pass "what
  to open" through a state key first (quill uses a `pending_action` key). `panel-open <id> <context>` over IPC does
  carry context into `onOpen`.
- **Desktop widgets** can't type, so anything that needs a text field opens a panel (`timer` and `quill` both do
  this). `ui.image` loads local files only, so `noctalia.download` remote images first.

## Launcher providers

- Manifest: `prefix` is a bare word: the user types `/` + prefix, so don't include the slash. `glyph` is the
  default row glyph (a Tabler name). Also `include_in_global_search`, `debounce_ms` (set it for network-backed
  providers), and `[[launcher_provider.category]]` (`label`, `glyph`) for grouping rows by their `category`.
  There is **no `icon` field** on `[[launcher_provider]]`.
- `onQuery(text)` gets the text after the prefix. **`launcher.setResults(query, results)` must echo that exact
  `text`**: late answers are matched to their query, and the newest wins. Publish a placeholder synchronously,
  then call `setResults` again from the async callback.
- Result rows: `{ id, title, subtitle?, glyph?, icon?, badge?, query?, score? }`. **`glyph` is a Tabler/Nerd-Font
  name; `icon` is an XDG themed-icon name**, so `"circle-plus"` belongs in `glyph`. `badge` replaces both.
- `onActivate(id)` closes the launcher unless it calls `launcher.setQuery(text)` (or the row set `query`), which
  rewrites the input and keeps the launcher open for drill-down. Rank local lists with
  `noctalia.fuzzyScore(pattern, text)`.

## Patterns worth copying

**A service owns the remote data; UI entries are thin clients.** This is how `timer`, `vikunja`, `quill` and
`umbriel-companion` are all built:
- The service fetches on `setUpdateInterval`, normalises the data, and publishes one snapshot key (vikunja's
  carries a `revision` counter that only bumps when the data actually changed).
- Clients `watch` the snapshot and render it. They never call the API themselves.
- Clients send commands by setting a command key to a table with a **unique `requestId`**, e.g.
  `{ action = "complete", taskId = …, projectId = …, requestId = "panel-7" }`. The service `watch`es that key,
  runs the request, then publishes a result key carrying the same `requestId` and refreshes the snapshot.
  Whether re-setting an identical value fires a watch isn't documented; the unique id sidesteps the question.
- The service also exposes the same actions over `onIpc`, which makes them scriptable and testable from the shell.

**HTTP.** Wrap `noctalia.http` once, the way `vikunja/service.luau`'s `apiRequestBase` does:
- **`HttpResponse.ok` is transport success only.** A 401 or 500 arrives with `ok = true`, so success is
  `res.ok and res.status >= 200 and res.status < 300`.
- `noctalia.http` returns `false` when the request wasn't accepted. Treat that as a failure; vikunja synthesizes a
  failed response for it ("http queue full"). Requests honour `[shell] offline_mode`.
- Errors thrown inside a callback only reach the log (`call to 'async http callback' failed`), so `pcall` the
  callback if a failure has to be shown to the user.
- Set `Content-Type: application/json` whenever there's a JSON body. `noctalia.json.encode` returns
  `(nil, err)` on failure, not an error.
- Headers are full `"Name: value"` lines. Use `noctalia.string.urlEncode` for query parameters.

**Persistence.** `noctalia.pluginDataDir()` is `~/.local/state/noctalia/plugins/data/<author>/<plugin>/`. Write
JSON there with `writeFile` + `json.encode`. **Never write under `noctalia.pluginDir()`**: for this repo that's
the git checkout itself, and for git-installed plugins it's a copy that gets overwritten on update.

**Subprocesses.** Use the argv form `noctalia.runAsync({ "cmd", arg, … }, cb)` (API 24) whenever any argument is
dynamic. The string form goes through `sh -c` and needs quoting. Without a callback, `runAsync` is a detached
fire-and-forget.

## Gotchas this repo has already hit

Each of these appears in `~/.cache/noctalia/noctalia.log`:
- `invalid argument #2 to 'notify' (string expected, got table)`: `notify`/`notifyError` take strings only.
  `tostring` or `json.encode` anything else.
- `require: cannot open '…/api/api/types.luau'`: a require path written relative to the entry instead of to the
  module containing it.
- `require path must be relative and end in .luau`: missing `./` or extension.
- `luau_load failed … Expected type, got ')'` and other parse errors in a module: a malformed annotation. Any
  parse error kills the whole entry at load, and luau-lsp flags these before the shell does.
- `invalid argument #1 to 'insert' (table expected, got nil)`: reading a state key or decoded field before anything
  set it.

## Publishing (only if a plugin is ever submitted)

The store is `noctalia-dev/community-plugins` (official-plugins takes no third-party plugins). Its CI runs
`validate-plugins.py` from official-plugins, which is plain file inspection and safe to run here:
`python3 -I <official-plugins>/.github/workflows/validate-plugins.py --root .`. The rules beyond the manifest
basics:
- The plugin directory name must equal the part of the id after `/` (`ticktick-integration` already does).
- Required files are `README.md`, `thumbnail.webp` (960×540 WebP, ≤ 512 KiB) and `translations/en.json`.
- The README needs `# Title`, an intro, and `## Plugin` naming the id, every entry id and `/<prefix>` in
  backticks. It also needs `## Usage`, plus `## Settings` and `## Requirements` when applicable. Every panel needs
  its `noctalia msg panel-toggle …` command. No raw HTML.
- Launcher prefixes must match `^[a-z]+$`. **`tt-new` would fail this**, though the host accepts it.
- Every setting needs a `default`. `description` is ≤ 120 chars. `tags` come from a fixed list (`productivity`
  is on it). `version` is plain `MAJOR.MINOR.PATCH`, bumped on every change. Ship no symlinks and no
  obfuscated, minified or downloaded code. List external commands in `dependencies` and the README.

## The TickTick plugin

TickTick is a todo app with a developer API. Intended features:

1. **Add tasks from the launcher** (`/tt-new`, entry `ticktick-new`, `new_task.luau`). The typed text is parsed with
   TickTick's Smart Recognition rules, previewed in `onQuery`, and created on `onActivate`. *Working.*
2. **Desktop widget**: today's tasks, or the tasks of a chosen list. Users mark tasks done and ideally edit them
   from the widget. Since desktop widgets can't take keyboard focus, editing means opening a panel. *Not started.*
3. **Bar widget**: up to 2 tasks; clicking one marks it done. Editing is deliberately out of scope there.
   *Not started.*

Layout:
- `ticktick-service.luau` (`ticktick-update`) — service; every 5 minutes it fetches `GET /open/v1/project` and
  publishes state key `data`, shaped `{ projects, project_names }` (`utils/types.luau`'s `TicktickPluginData`).
- `api/requests.luau` — HTTP calls (`get_projects`, `create_task`) and `is_success(res)`, the 2xx check every
  caller should use instead of `res.ok`. Every request carries `Authorization: Bearer <api_key>`.
- `api/types.luau` — `TicktickProject`, `TicktickTask` (the Open API's Task schema; only `title` and `projectId`
  are required on create).
- `api/convert.luau` — `toTicktickTask(parsed, projects)`: `ParsedTask` → Task body. It resolves `~list` names to
  project ids and falls back to `"inbox"`. The docs only document the `inbox` alias on the filter/undone endpoints,
  so if no-list tasks ever go missing, look here.
- `smart_recognition/` — the parser (below). `plugin_api` is 22, for `require`.

The `api_key` plugin-level setting holds the user's TickTick API token and has no default. The widgets will need
the service to grow into the "service owns the data" pattern above: today's tasks plus a command key for
complete/edit, with each cached task keeping both `id` and `projectId`.

### TickTick Open API

Docs live at <https://developer.ticktick.com/docs#/openapi>, but that page is a docsify SPA: the server 404s every
path under `/docs`, so fetch the raw markdown at <https://developer.ticktick.com/docs/openapi.md>.

Base host `https://api.ticktick.com`, with every request carrying `Authorization: Bearer <token>`. The token is
either an OAuth2 access token (register an app at developer.ticktick.com/manage, then
`https://ticktick.com/oauth/authorize` → `/oauth/token`) or, for personal use, a token created in the TickTick
web app under avatar → Settings → Account → API Token. The `api_key` setting holds the latter.

| Purpose | Call |
| --- | --- |
| Create a task | `POST /open/v1/task` — `title` and `projectId` both required; returns the Task |
| List projects | `GET /open/v1/project` — `id`, `name`, `color`, `sortOrder`, … |
| One project + its undone tasks | `GET /open/v1/project/{projectId}/data` → `{project, tasks, columns}` |
| Tasks in a date range | `POST /open/v1/task/undone` — `startDate`/`endDate` required, range ≤ 14 days, `projectIds` optional (`inbox` for the inbox) |
| Richer queries | `POST /open/v1/task/filter` — project/date/priority/tag/kind/status filters, max 200 tasks |
| Complete | `POST /open/v1/project/{projectId}/task/{taskId}/complete`, no body; batch `POST /open/v1/task/completeTasks` (≤ 50, one project, defaults to the inbox) |
| Edit | `POST /open/v1/task/{taskId}`; delete `DELETE /open/v1/project/{projectId}/task/{taskId}` |
| User's time zone | `POST /open/v1/preference` → `{ timeZone }` (IANA), for the Task's `timeZone` field |

Also available: `/task/move`, `/task/batch`, `/task/completed`, `/task/search`, comments, and
project/group/column CRUD.

`ParsedTask` was built against the Task schema and maps onto it field for field: `priority` (None `0`, Low `1`,
Medium `3`, High `5`), `reminders` as a `TRIGGER:` array, `repeatFlag` as an RRULE, `tags`, `isAllDay`, and
`dueDate`/`startDate` in `yyyy-MM-dd'T'HH:mm:ssZ`, which is exactly what `momentToIso` emits. Task `status` is `-1`
abandoned, `0` normal, `2` completed. `repeatFrom` (`0` original date, `1` completion date, `2` calendar; the
server defaults to `2`) only matters alongside `repeatFlag`.

Two consequences: creating a task **requires a project id**, so `~list` resolves through the cached name → id map;
and completing a task needs its `projectId` as well as its id, so whatever the widgets cache must keep both.

### The Smart Recognition parser

`ticktick-integration/smart_recognition/` parses quick-add text the way TickTick's Smart Recognition does: dates,
times, ranges, repeat rules as RRULEs, early and postponed reminders. It also handles three markers TickTick's help
page doesn't document: `!priority`, `#tag`, and `~list` / `^list`. `init.luau` is the only module entries require
(by its full path; the name is not special to the host). Its header comment is the syntax reference, because the
help page's own tables are images.

- `calendar.luau` — the `Moment` type and all date math. It deliberately avoids `os.time(table)`, whose local-vs-UTC
  reading is host-dependent; everything goes through days-from-civil instead. Moments are local wall time.
- `scanner.luau` — the working text. Recognising a token blanks its span out of both the original-case and
  lowercased copies **with spaces of the same width**, so every extractor's indices stay valid and whatever
  survives becomes the task title. Don't change this to deletion.
- `vocabulary.luau` — word tables. `markers.luau`, `dates.luau`, `times.luau`, `repeats.luau`, `reminders.luau` —
  one module per family of rules.
- `init.luau` — the `ParsedTask` type, the shared `plan` contract (documented above `resolve`), `resolve`, and
  `parseTask`.

Two invariants to know before editing rules:
- **Extractor order is load-bearing** and lives in `parseTask`: markers → repeats → reminders → dates → times →
  resolve. Early reminders must run before delays ("remind 3 mins earlier" would otherwise read as "3 mins later"),
  and repeats before dates ("every 6 march" before "6 march").
- **Rule tables are ordered specific → general.** A rule's `fn` returns `true` only when it consumed something;
  returning `false` lets the scan continue with the next match or rule. That's how a pattern like
  `every%s+(%d+)%s*(%a+)` rejects "every 6 march" and lets the yearly rule have it. Adding a rule usually means
  inserting it in the right place, not appending.

Resolution is "next effective", matching TickTick: a time already past today rolls to tomorrow, a weekday rolls a
week, a day-and-month rolls a year, and a date the user spelled out in full stays put. `plan.dateKind` carries
that distinction.

## Testing

There is no test runner and no `luau` binary on this machine; `lua5.4` and `luac5.4` are installed. Pure logic
(the parser, `api/convert.luau`) can still be exercised:
1. Strip the Luau-only syntax: `export type` blocks, `: T` annotations (including function types like
   `(HttpResponse) -> ()` and annotated loop variables `for i, p: T in`), and `+=` / `-=` / `..=`.
2. Run the result under `lua5.4` with a `require` shim that resolves `./x.luau` **relative to the requiring
   file's directory** (as the host does) to the stripped `.lua`, plus empty `launcher` and `noctalia` globals.
3. Backtick strings and `if … then … else` expressions have no Lua 5.4 equivalent. A module that uses them needs
   those spots rewritten in the stripped copy.

`luac5.4 -p` on a stripped file is a cheap syntax check. Anything that touches the host API has to be verified by
reloading in the shell.

## Conventions

**Prefer several small commits over one large one.** Split work along its natural seams — a formatting or data fix,
a new feature, and a docs change are three commits, not one — and commit them in an order where each stands on its
own. History here is linear on `main`; a topic branch just gets rebased and fast-forwarded back, so that is where
commits end up.

Luau files start with `--!nonstrict`, indent with 2 spaces, and separate sections with `-- ── name ───` banners.
Requires are explicitly relative **and include the extension** (`require("./calendar.luau")`), resolved from the
requiring file's directory.
