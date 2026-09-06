# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Personal plugins for [Noctalia](https://noctalia.dev), a Wayland desktop shell. Plugins are Luau
scripts the shell loads and calls; there is no build step and no compiled artifact.

- `ticktick-integration/` — the only plugin under active development.
- `example/` — **not one of these plugins.** It is Noctalia's own example plugin
  (`noctalia/example`), kept here to read for API usage. Treat it as read-only documentation;
  don't edit it, don't "fix" it, and don't copy its id or settings into a real plugin.
- `noctalia.d.luau` — type definitions for the host API, gitignored and refetched with `just`.
  It is the authoritative API reference: read it before using any `noctalia.*`, `ui.*`,
  `launcher.*`, `barWidget.*`, `desktopWidget.*` or `panel.*` member.

## The TickTick plugin

TickTick is a todo app with a developer API. The plugin's intended feature set:

1. **Add tasks from the launcher** — the `/tt-new` slash command (`[[launcher_provider]]`,
   prefix `tt-new`). Typed text is parsed with TickTick's Smart Recognition rules. *Implemented,
   minus the API call: activating a result only shows a notification.*
2. **Desktop widget** — today's tasks, or the tasks of a chosen TickTick list. Users mark tasks
   done and ideally edit them from the widget. *Not started.*
3. **Bar widget** — up to 2 tasks, clicking one marks it done. Editing is deliberately out of
   scope there; it isn't feasible in a bar capsule. *Not started.*

Nothing talks to TickTick yet. The `api_key` setting is declared in `plugin.toml` but never read
(`noctalia plugins lint` reports this), and no HTTP layer exists. When adding one, use
`noctalia.http` — it is async and callback-based, and it honors the shell's offline mode.

## TickTick Open API

Docs live at <https://developer.ticktick.com/docs#/openapi>, but that page is a docsify SPA — the
server 404s every path under `/docs`, so fetching it needs the raw markdown at
<https://developer.ticktick.com/docs/openapi.md>.

Base host `https://api.ticktick.com`, every request carrying `Authorization: Bearer <token>`. The
token is either an OAuth2 access token (register an app at developer.ticktick.com/manage, then
`https://ticktick.com/oauth/authorize` → `/oauth/token`) or, for personal use, a token created in
the TickTick web app under avatar → Settings → Account → API Token. The `api_key` setting is
meant to hold the latter.

Endpoints the three features need:

| Purpose | Call |
| --- | --- |
| Create a task | `POST /open/v1/task` — `title` and `projectId` are both required; returns the Task |
| List projects | `GET /open/v1/project` — `id`, `name`, `color`, `sortOrder` |
| One project + its undone tasks | `GET /open/v1/project/{projectId}/data` → `{project, tasks, columns}` |
| Tasks in a date range | `POST /open/v1/task/undone` — `startDate`/`endDate` required, range capped at 14 days, `projectIds` optional (`inbox` for the inbox) |
| Richer queries | `POST /open/v1/task/filter` — project/date/priority/tag/kind/status filters, max 200 tasks |
| Complete | `POST /open/v1/project/{projectId}/task/{taskId}/complete`, no body; batch is `POST /open/v1/task/completeTasks` (≤50, one project, defaults to inbox) |
| Edit | `POST /open/v1/task/{taskId}`; delete is `DELETE /open/v1/project/{projectId}/task/{taskId}` |

The parser's `ParsedTask` was built against the Task schema and maps onto it field for field:
`priority` (None `0`, Low `1`, Medium `3`, High `5`), `reminders` as a `TRIGGER:` array, `repeatFlag`
as an RRULE, `tags`, `isAllDay`, and `dueDate`/`startDate` in `yyyy-MM-dd'T'HH:mm:ssZ` — which is
exactly what `momentToIso` emits. Task `status` is `-1` abandoned, `0` normal, `2` completed.

Two consequences for the plugin: creating a task **requires a project id**, so the `~list` marker
has to resolve against a cached name → id map from `GET /open/v1/project` (`matchList` takes names,
and the id has to be carried alongside); and completing a task needs its `projectId` as well as its
id, so whatever the widgets cache must keep both.

## Commands

```sh
just fetch-plugin-api                      # refetch noctalia.d.luau from the official repo
noctalia plugins lint ticktick-integration # offline: declared settings vs. what the code reads
noctalia msg plugins list                  # installed plugins and their source
noctalia msg plugins disable agokule/ticktick-integration
noctalia msg plugins enable  agokule/ticktick-integration   # disable+enable reloads after an edit
noctalia msg plugin agokule/ticktick-integration:<entry> <target> <event> [payload]  # -> onIpc
```

This repo is registered with the running shell as the local plugin source `my-local-plugins`
(`noctalia msg plugins source list`), so edits here are live — no install step.

### Testing

There is no test runner and no `luau` binary on this machine; `lua5.4` and `luac5.4` are
installed. Pure logic (the parser) can still be exercised: strip the Luau-only syntax — `export
type` blocks, `: T` annotations, `+=` / `-=` / `..=` — and run the result under `lua5.4` with a
`require` shim that maps `./x.luau` to the transpiled file, plus stubs for the `launcher` and
`noctalia` globals. `luac5.4 -p` on the stripped file is also a cheap syntax check. Anything that
touches the host API has to be verified by reloading the plugin in the shell.

## Plugin structure

`plugin.toml` is the manifest: identity, `plugin_api`, settings, and one table per entry —
`[[widget]]` (bar), `[[desktop_widget]]`, `[[panel]]`, `[[service]]`, `[[shortcut]]`,
`[[launcher_provider]]`. Each entry names a `.luau` file. `example/plugin.toml` documents every
entry type inline and is the fastest way to recall the shape of one.

Things that are easy to get wrong:

- **`plugin_api` is the minimum host API the plugin needs.** Members in `noctalia.d.luau` are
  annotated with the level they arrived in ("API 26"); using one means raising this number.
  It is currently 22, the level that added `require()` for relative `.luau` modules.
- **Each entry runs in its own Luau runtime.** Two entries of the same plugin share no Lua memory.
  Cross-entry communication goes through `noctalia.state` (in-memory, with `watch`) or IPC
  (`onIpc`); durable data goes in `noctalia.pluginDataDir()`.
- **The host calls global functions, not exports.** `onQuery`/`onActivate` for a launcher provider,
  `update` for widgets and services, `onOpen`/`onClose` for panels, `onIpc`, `onExit`. They must be
  globals, so they cannot be `local`. The list is at the bottom of `noctalia.d.luau`.
- **Settings reach code through `noctalia.getConfig(key)`**, and their labels are `label_key` /
  `description_key` lookups into `translations/<lang>.json` — a declared setting needs a matching
  entry there or the UI shows nothing.
- **Bar widgets can be imperative (`setText`/`setGlyph`) or declarative (`render` with a `ui.*`
  tree); desktop widgets and panels are always declarative.**

## The Smart Recognition parser

`ticktick-integration/new_task.luau` is a thin launcher entry. All the parsing lives in
`ticktick-integration/smart_recognition/`, whose `init.luau` is the only module the entry requires.

It parses quick-add text the way TickTick's Smart Recognition does — dates, times, ranges, repeat
rules as RRULEs, early and postponed reminders — plus three markers TickTick's help page doesn't
document: `!priority`, `#tag`, and `~list` / `^list`. The header comment in `init.luau` is the
syntax reference; the help page's own tables are images, so the code is the written-down version.

- `calendar.luau` — the `Moment` type and all date math. Deliberately avoids `os.time(table)`,
  whose local-vs-UTC reading is host-dependent; everything goes through days-from-civil instead.
  Moments are local wall time.
- `scanner.luau` — the working text. Recognising a token blanks its span out of both the
  original-case and lowercased copies **with spaces of the same width**, so every extractor's
  indices stay valid and whatever survives becomes the task title. Don't change this to deletion.
- `vocabulary.luau` — word tables. `markers.luau`, `dates.luau`, `times.luau`, `repeats.luau`,
  `reminders.luau` — one module per family of rules.
- `init.luau` — the `ParsedTask` type, the shared `plan` contract (documented above `resolve`),
  `resolve`, and `parseTask`.

Two invariants worth knowing before editing rules:

- **Extractor order is load-bearing** and lives in `parseTask`: markers → repeats → reminders →
  dates → times → resolve. Early reminders must run before delays ("remind 3 mins earlier" would
  otherwise read as "3 mins later"); repeats before dates ("every 6 march" before "6 march").
- **Rule tables are ordered specific → general.** A rule's `fn` returns `true` only when it
  consumed something; returning `false` lets the scan continue with the next match or rule, which
  is how a pattern like `every%s+(%d+)%s*(%a+)` rejects "every 6 march" and lets the yearly rule
  have it. Adding a rule usually means inserting it in the right place, not appending.

Resolution is "next effective", matching TickTick: a time already past today rolls to tomorrow, a
weekday rolls a week, a day-and-month rolls a year, and a date the user spelled out in full stays
put. `plan.dateKind` is what carries that distinction.

## Conventions

**Prefer several small commits over one large one.** Split work along its natural seams — a
formatting or data fix, a new feature, and a docs change are three commits, not one — and commit
them in an order where each stands on its own. History here is linear on `main`; a topic branch
just gets rebased and fast-forwarded back, so that is where commits end up.

Luau files start with `--!nonstrict`, indent with 2 spaces, and separate sections with
`-- ── name ───` banners. Requires are explicitly relative **and include the extension** —
`require("./calendar.luau")` — which is what this host wants; sibling modules inside
`smart_recognition/` resolve relative to the requiring file.
