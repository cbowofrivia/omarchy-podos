# Agent guide: PodOS for Omarchy

An Omarchy shell plugin (bar widget). It has a QML front end (`Panel.qml`,
`Service.qml`, `Avatar.qml`, `PodosIcon.qml`) and a Python helper
(`podos-notify`) that calls the PodOS API. The user-facing docs are in
`README.md`.

## Installing for a user

Do these in order. Stop and ask the user wherever a step says so.

1. Check that it's an Omarchy machine: `command -v omarchy omarchy-shell python3`.
2. Install it and put it on the bar:
   `omarchy plugin add https://github.com/cbowofrivia/omarchy-podos-notifications --enable --yes`.
   If the plugin is already installed, run `omarchy plugin update podos.notifications --yes`
   instead.
3. **Token. Never read, print, echo or copy the token value yourself**, and
   never put it in a command line you show. It belongs in
   `~/.config/podos-notify/token` with mode 600.
   - If `~/.config/podos-notify/token` already exists, leave it alone.
   - Otherwise ask the user to create a token at
     <https://podos.io/integrations/mcp> and save it themselves. Claude Code
     users can type `!` before a command to run it in the session:
     `! install -d -m700 ~/.config/podos-notify && ( umask 077; ${EDITOR:-nano} ~/.config/podos-notify/token )`
   - If the user already has the PodOS MCP server in Claude Code, offer them
     this command, which moves the token without showing it:
     `! jq -r .mcpServers.podos.env.PODOS_TOKEN ~/.claude.json | install -m600 /dev/stdin ~/.config/podos-notify/token`
     The user must run it themselves. Copying a credential is their call.
4. Ask the user whether they want the Tasks tab, and for which PodOS project
   code. Never guess a project code. If they want it, set `tasksProject` on the
   `podos.notifications` entry in `~/.config/omarchy/shell.json` (under
   `bar.layout.<section>`). Back the file up first, and edit it as JSON, keeping
   the rest of the file as it is.
5. `omarchy restart shell`, then `omarchy-shell podos.notifications status`:
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
- **Network.** Only `podos-notify` talks to the network. Keep its checks:
  https-only base URLs; links and avatars only on the dashboard host and its
  subdomains; size caps; timeouts. Never pass API data into a shell command.
  Pop-up buttons take untrusted values only after `--with`.
- **Strings.** User-facing strings live in `i18n/en.json` and are read with
  `strings.t()` / `strings.tn()`.
- **Spacing and motion.** Use `Style.space()`, `Style.spacing.*` and
  `Style.duration()`.
- **Testing.**
  - Saving a file doesn't always reload the plugin. Run `omarchy restart shell`,
    then check `journalctl --user --since -1min -o cat | grep -i podos` for QML
    errors.
  - `omarchy-shell podos.notifications showTab <notifications|tasks>` opens the
    panel on a tab, ready for a screenshot (`grim`).
  - `omarchy plugin validate .` checks the manifest.
  - Test helper changes directly, e.g. `./podos-notify list | python3 -m json.tool`.
- **Privacy.** Never commit screenshots or fixtures containing real
  notifications, names, avatars or project codes.
