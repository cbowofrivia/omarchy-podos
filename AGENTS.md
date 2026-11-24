# Agent guide: PodOS for Omarchy

An Omarchy shell plugin (bar widget). It has a QML front end (`Panel.qml`,
`Service.qml`, `Avatar.qml`, `PodosIcon.qml`) and a Python helper
(`omarchy-podos-fetch`) that calls the PodOS API. The user-facing docs are in
`README.md`.

## Installing for a user

Do these in order. Stop and ask the user wherever a step says so.

1. Check that it's an Omarchy machine: `command -v omarchy omarchy-shell python3`.
2. Install it and put it on the bar:
   `omarchy plugin add https://github.com/cbowofrivia/omarchy-podos --enable --yes`.
   If the plugin is already installed, run `omarchy plugin update cbowofrivia.podos --yes`
   instead.
3. **Token. Never read, print, echo or copy the token value yourself**, and
   never put it in a command line you show. It belongs in
   `~/.config/omarchy-podos/token` with mode 600.
   - If `~/.config/omarchy-podos/token` already exists, leave it alone.
   - Otherwise ask the user to create a token at
     <https://podos.io/integrations/mcp> and save it themselves. Claude Code
     users can type `!` before a command to run it in the session:
     `! install -d -m700 ~/.config/omarchy-podos && ( umask 077; ${EDITOR:-nano} ~/.config/omarchy-podos/token )`
   - If the user already has the PodOS MCP server in Claude Code, offer them
     this command, which moves the token without showing it:
     `! jq -r .mcpServers.podos.env.PODOS_TOKEN ~/.claude.json | install -m600 /dev/stdin ~/.config/omarchy-podos/token`
     The user must run it themselves. Copying a credential is their call.
4. Ask the user whether they want the Tasks tab, and for which PodOS project
   code. Never guess a project code. If they want it, set `tasksProject` on the
   `cbowofrivia.podos` entry in `~/.config/omarchy/shell.json` (under
   `bar.layout.<section>`). Back the file up first, and edit it as JSON, keeping
   the rest of the file as it is.
5. `omarchy restart shell`, then `omarchy-shell cbowofrivia.podos status`:
   - `ready <n>` means it works.
   - `unauthenticated <n>` means the token is missing or was rejected; go back
     to step 3.
   - `offline <n>` means PodOS can't be reached right now.

Tell the user about the pop-ups. On the first poll it only records the
notifications already there, and after that each new one gets a desktop pop-up.

## Changing the plugin

- Read the Omarchy plugin guidance first. If the `omarchy` skill is available,
  read its `plugins.md`, especially *Plugin UI Safety*.
- **Themes.** Never hardcode colours. Use `root.foreground` / `root.dim` /
  `root.urgent` (from the bar), `Commons.Color.*` and `Style.*` tokens, as the
  rest of the plugin does.
- **Untrusted text.** Notification and task text comes from other people. Every
  `Text` must use `textFormat: Text.PlainText`. Use the `PlainLabel` component
  in `Panel.qml`.
- **Network.** Only `omarchy-podos-fetch` talks to the network. Keep its checks:
  https-only base URLs; links and avatars only on the dashboard host and its
  subdomains; size caps; timeouts. Never pass API data into a shell command.
  Pop-up buttons take untrusted values only after `--with`.
- **Strings.** User-facing strings live in `i18n/en.json` and are read with
  `strings.t()` / `strings.tn()`.
- **Spacing and motion.** Use `Style.space()`, `Style.spacing.*` and
  `Style.duration()`.
- **Performance.** The panel shares one process with the whole bar and the
  pop-ups, so a stall here freezes all of them.
  - No `MultiEffect`, `layer.enabled` or other effects in per-row items. A
    per-avatar `MultiEffect` once made every panel close freeze the shell for
    10-25 seconds. `Avatar.qml` rounds photos with `ShapePath.fillItem`.
  - Each row builds only what it shows (one `Loader` per entry).
  - Don't rebuild the rows unless the data changed. `Service.apply()` skips
    unchanged refreshes, clicks go through `overrides` that rows read in
    place, and day headings follow `today`, not the 30-second `now`.
  - To check for stalls, time
    `qs ipc -n -p /usr/share/omarchy/shell call cbowofrivia.podos status`
    in a loop while opening, refreshing and closing the panel. A healthy
    shell answers in tens of milliseconds.
- **Testing.**
  - Saving a file doesn't always reload the plugin. Run `omarchy restart shell`,
    then check `journalctl --user --since -1min -o cat | grep -i podos` for QML
    errors.
  - `omarchy-shell cbowofrivia.podos showTab <notifications|tasks>` opens the
    panel on a tab, ready for a screenshot (`grim`).
  - `omarchy plugin validate .` checks the manifest.
  - Test helper changes directly, e.g. `./omarchy-podos-fetch list | python3 -m json.tool`.
- **Privacy.** Never commit screenshots or fixtures containing real
  notifications, names, avatars or project codes.
