# PodOS for Omarchy

Your [PodOS](https://podos.io) notifications and tasks in the
[Omarchy](https://omarchy.org) bar, with desktop pop-ups for new notifications.
PodOS is a web app, so this gives you notifications at a glance without keeping
a tab open.

- **Bar icon**: the PodOS rings, lit in your theme's active colour with an
  unread count when something needs you.
- **Notifications tab**: your user notifications (mentions, task comments,
  assignments; not project-wide alerts), unread and read in one list. They are
  grouped by thread the way the PodOS dashboard groups them, under day headings,
  with sender avatars. Unread threads are bold with an accent dot.
- **Tasks tab** (optional): your Doing and Need tasks in one project, with
  progress bars.
- **Desktop pop-ups** for each new notification, with **Open** and
  **Mark read** buttons.

Colours come from the current Omarchy theme.

## Install

You need Omarchy with its Quickshell shell, `python3`, and a PodOS MCP token.

1. Add the plugin and put it on the bar:

   ```bash
   omarchy plugin add https://github.com/cbowofrivia/omarchy-podos-notifications --enable
   ```

2. Save your token. Create one at <https://podos.io/integrations/mcp>, then put
   it in a file only you can read:

   ```bash
   install -d -m700 ~/.config/podos-notify
   ( umask 077; ${EDITOR:-nano} ~/.config/podos-notify/token )
   ```

   If the PodOS MCP server is already set up in Claude Code, you can reuse its
   token without it appearing on screen:

   ```bash
   jq -r .mcpServers.podos.env.PODOS_TOKEN ~/.claude.json | install -m600 /dev/stdin ~/.config/podos-notify/token
   ```

3. Optionally, turn on the Tasks tab by setting `tasksProject` to a PodOS
   project code (the `?project=…` part of a dashboard URL). Use the widget's
   settings, or add it to the widget's entry in `~/.config/omarchy/shell.json`:

   ```json
   { "id": "podos.notifications", "tasksProject": "your-project-code" }
   ```

4. Restart the shell, then check it:

   ```bash
   omarchy restart shell
   omarchy-shell podos.notifications status   # "ready <unread count>"
   ```

Update later with `omarchy plugin update podos.notifications`.

## Use

| Action | Mouse | Keyboard (panel open) |
| --- | --- | --- |
| Open the panel | Click the icon | |
| Refresh | Right-click the icon | `r` |
| Open the PodOS inbox (or task board) | Middle-click the icon | `i` |
| Switch tab | Click a tab | `←` `→`, `n`, `t` |
| Open a notification (marks it read) | Click the row | `↑` `↓`, `Enter` |
| Toggle read / unread | Right-click the row, or its button | `m` |
| Mark everything read | Header ✓ | `a` |

To open the panel on a tab from a script or a Hyprland key binding:

```bash
omarchy-shell podos.notifications showTab notifications   # or tasks
```

## Settings

| Key | Default | What it does |
| --- | --- | --- |
| `refreshIntervalSec` | `60` | How often to poll PodOS (30 to 3600 seconds). |
| `desktopNotifications` | `true` | Show a desktop pop-up for each new notification. |
| `tasksProject` | empty | Project code for the Tasks tab. Empty hides the tab. |
| `apiUrl` | `https://api.podos.io` | PodOS API base URL. |
| `dashboardUrl` | `https://podos.io` | PodOS dashboard base URL. |

## How it works

`podos-notify` is a small Python helper (standard library only) that calls the
PodOS public API, the same endpoints the PodOS MCP server uses. It swaps your
token for a short-lived login token, lists notifications, marks them read or
unread, and lists tasks. The QML widget runs it on a timer.

- **Files.** It writes the login token and the IDs of notifications it has
  already shown pop-ups for to `~/.local/state/podos-notify/` (mode 600).
  Avatars are cached in `~/.cache/podos-notify/avatars/`.
- **First run.** The first poll only records what is already there, so you don't
  get a pop-up for every old notification.
- **Links and avatars.** Links only open, and avatars are only downloaded (1 MB
  cap), on the dashboard host and its subdomains. Anything else opens your inbox
  instead.
- **Displayed text.** Text from the API is always shown as plain text.

The helper can be run by hand. Every command prints JSON:

```bash
./podos-notify list --tasks-project your-project-code
./podos-notify read <notification-id>...
./podos-notify --help
```

## Troubleshooting

- **Status says `unauthenticated`.** The token file is missing or PodOS rejected
  it. Create a new token and save it again.
- **Status says `offline`.** PodOS couldn't be reached. It retries on the next
  poll.
- **Changes to the plugin files don't show.** Run `omarchy restart shell`.

## Licence

MIT
