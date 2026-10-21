# Homelable Canvas — Stack Group Layout Convention

Applies to any docker-compose stack represented as a container-mode
group node in Homelable, holding one visible `docker_container` child
per logical service.

## Group node (the stack box)

- `type: generic`, `container_mode: true`
- `custom_icon: container` (generic "Docker Host / Container" icon —
  NOT `brand:docker`, that's the Docker logo brand icon and reads as
  heavier/wrong context for a stack group box)
- `custom_colors: { show_border: true }`
- `width: 150` (fits children width 134 + 8px padding each side —
  symmetric left/right; see gotcha below about why this matters)
- `height` = top_offset(48) + n × (child_height 36 + gap 16) − gap + bottom_padding(20)
- Left/right padding: 8px (must match child `x` exactly both sides —
  see width-symmetry gotcha)
- Top offset: 48px (room for the group's own label)
- Bottom padding: 20px
- `check_method: ping` **with no `check_target` set** — do NOT use
  `check_method: none`. Confirmed by testing: `none` triggers a
  periodic backend normalization that silently forces `status` back
  to `"online"` (solid green) within ~30-60s, even after explicitly
  setting `status: "unknown"`. Switching to `check_method: "ping"`
  with `check_target` left empty avoids this — the check never
  resolves (nothing to ping), so `status` stays at whatever you set
  (`"unknown"`) and does not get silently overwritten. Verified stable
  after 75s wait. Apply the same fix to any child node that
  legitimately has no route to check (e.g. an internal broker like
  `mosquitto`): `check_method: "ping"`, no `check_target`,
  `status: "unknown"`.

## Child nodes (one per logical service)

- `type: docker_container` (required — do not leave as `generic`)
- `width: 134`, `height: 36` — **always 36, no exceptions.** Do not
  manually resize a child to 50px or any other value "just this once"
  — it breaks the uniform formula for that whole stack and forces
  hand-tuned gap/padding math instead of the standard formula (this
  happened to `admin` and `adsb`, took several rounds to trace back
  and fix). If a child needs to look different, that's a signal to
  reconsider the design, not to special-case one node's height.
- Single vertical column, `x = 8` (relative to the group — MUST equal
  the group's left/right padding for symmetric margins, see gotcha)
- First child `y = 48` (top offset)
- Each subsequent child `y += 52` (36 height + 16 gap)
- `custom_icon: brand:<service-icon>` if known, else omit
- Note: `docker_container` type nodes render with extra visual chrome
  (border/status indicator) beyond their declared `height`. A 12px gap
  visually overlaps; 16px reads well and is the current standard.
- **API limitation:** neither `type: docker_container` nor
  `type: group` can be set through `create_node`/`update_node` — the
  tool's enum only accepts
  `isp|router|switch|server|proxmox|vm|lxc|nas|iot|ap|generic`.
  Create the node as `generic` via the API, then have the user flip
  its type to "Docker Container" manually in the UI afterward. Same
  restriction applies to the stack group box if you ever want a true
  `group` type instead of `generic`+`container_mode: true`.

## One visible node per logical service

If a compose service is backed by multiple containers that make up a
single logical app or role, show only **one** visible node and merge
the rest into its notes. This covers two shapes seen so far:

1. **Split app tiers** (frontend + backend + internal sidecar), e.g.
   `homelable` = `homelable` + `homelable-backend` + `homelable-mcp`.
2. **Server + companion agent**, e.g. `admin` stack's
   `beszel` (dashboard, has a public route) + `beszel-agent`
   (host-network metrics exporter, no route) — same pattern applies
   to `arcane` + `socket-proxy` (arcane is public, socket-proxy is an
   internal-only Docker API proxy it depends on).

Rule of thumb: keep the container that has the public route / hostname
users actually visit; merge everything else that has no route of its
own into that node's notes.

- Show only **one** node for the whole service — the user-facing
  container (the one with the public route / hostname users care
  about).
- Delete the extra container nodes from the canvas.
- Fold their hostname/port/notes info into the visible node's `notes`
  field so nothing is lost, e.g.:

  ```
  Homelable frontend UI. Stack: corsair/misc
  ---
  Includes 2 additional containers (not shown separately):
  - homelable-backend (homelable_backend): internal only, port 8000, homelable docker network
  - homelable-mcp (mcp.homelable.corsair.tf): MCP server, port 8001, traefik+homelable networks
  ```

  or, for a server+agent pair:

  ```
  System monitoring dashboard. Stack: corsair/admin
  ---
  Includes 1 additional container (not shown separately):
  - beszel-agent: host-network metrics agent (disks, GPU, sensors), reports to beszel via unix socket
  ```

- No `depends_on` edges between hidden sibling containers — since only
  one node is visible, there's nothing to connect. (Earlier revisions
  of this stack used `virtual` "depends_on" edges between all
  containers; this convention has been dropped in favor of the single
  merged-notes node.)

**Exception — user override:** the merge rule is a default, not a
hard requirement. If the user explicitly wants a tightly-coupled
container kept visible on its own (e.g. `corsair/7seas`'s
`transmission` — normally mergeable into `wireguard` since it runs via
`network_mode: service:wireguard` — and `flaresolverr`, normally
mergeable into `prowlarr` as its CAPTCHA-bypass helper), keep it as its
own child node instead of folding it into notes. Give it the same
`check_method: ping` / no target / `status: unknown` pattern as any
other no-route internal container.

## Stack ordering (multiple stacks under one host)

When a host (e.g. Corsair, Matey) has several stack-group boxes placed
in a row, order them **alphabetically left-to-right** by stack label
(not by creation order or arbitrary placement). Re-sort whenever a
stack is added, renamed, or the row is otherwise touched. Use a
consistent horizontal gap between boxes (4px has been the working
value) and keep them on the same `y` per host.

## Known bugs / gotchas (as of 2026-07-25)

- Do **not** pass `parent_id` as the literal string `"null"` to detach
  a node — the backend stores it as text and creates a
  broken/dangling reference. Use an empty string `""` instead
  (functionally treated as no-parent by the renderer).
- Toggling a node's own `container_mode` in the same update call that
  also touches its children can silently detach those children. Safe
  order: (1) set `container_mode`+size on the parent alone, (2)
  reattach children's `parent_id` in separate calls afterward.
- Only nest children under nodes that have `container_mode: true`.
  Reparenting into a plain (non-container) node — like a normal
  server card — causes visual overlap.
- Connection point handles (`top/bottom/left/right_handles`) are
  read-only in the API — not settable via `create_node`/`update_node`.
- Dragging nodes in the UI concurrently with API edits can cause
  position/parent drift — avoid mixing the two mid-edit.
- **Width-symmetry bug (found auditing 13 stacks at once):** if the
  group's left padding (child `x`) doesn't equal `group_width − x −
  child_width`, the box looks lopsided — heavier margin on one side.
  Always keep `x` and the right-side remainder equal: with
  `child_width=180` and `x=8`, group width must be `8+180+8=196`, not
  192. Check this explicitly any time width or `x` changes.
- **Gap-alternation bug (found in the same audit):** for stacks with
  3+ children, easy to accidentally leave one row's gap at an old
  value (e.g. 12px) while the rest use the current standard (16px),
  producing uneven spacing that reads as "inconsistent padding." When
  auditing a stack, compute every consecutive gap
  (`child[i+1].y − (child[i].y + child[i].height)`) and confirm they're
  ALL equal — don't just spot-check the first pair.
- Manually resizing a child's `height` in the UI (e.g. 36→50) does
  NOT auto-adjust the next child's `y` or the group's height — you
  must recompute and fix both by hand afterward, or the next row
  overlaps and/or bottom padding is wrong.

## Cross-stack "hosts" edge

If the stack group needs to show which physical host runs it, add a
`virtual` edge from the host server node to the stack group node
instead of nesting the group inside the server's card (nesting inside
a non-container server card breaks the layout — see gotchas above).
