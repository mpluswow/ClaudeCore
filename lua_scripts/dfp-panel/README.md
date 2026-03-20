# dfp-panel — DFP Panel Server Entry Point

This directory is the server-side root for the **DFP Panel** feature set. It acts as an index: the actual feature logic lives in sibling module directories and is loaded independently by mod-ale.

---

## Files

| File | Description |
|------|-------------|
| `dfp-panel-server.lua` | Stub entry point. Documents which modules belong to this panel. No runtime logic. |

---

## Module Architecture

DFP Panel follows a split-module pattern — each feature is a self-contained server+client pair:

```
lua_scripts/
├── dfp-panel/
│   └── dfp-panel-server.lua       ← index / documentation stub
│
├── dfp-ah/
│   └── dfp-ah-server.lua          ← AH feature (independent module)
│
├── dfp-daily/
│   └── dfp-daily-server.lua       ← Daily Tasks feature (independent module)
│
└── (future modules)
    └── dfp-xxx-server.lua
```

mod-ale loads all `.lua` files under `lua_scripts/` recursively, so each module self-registers its own event handlers. `dfp-panel-server.lua` does not need to `require` or `dofile` them — they load automatically.

---

## Client Counterpart

**`game_client/WOTLK/Interface/AddOns/DFP_Panel/DFP_Panel.lua`**

The panel addon provides:
- Minimap button (draggable, persists position via `SavedVariables`)
- Main panel window with feature buttons
- Each button calls the corresponding feature addon's slash command:
  - AH button → `SlashCmdList["DFPAH"]("")`
  - Daily Tasks button → `SlashCmdList["DFPDAILY"]("")`

This pattern means DFP Panel itself has no server dependency — it only coordinates client-side addon slash commands. All server interaction happens inside each feature's own addon.

---

## Adding a New Feature Module

1. Create `lua_scripts/dfp-<name>/<name>-server.lua` with its event handlers.
2. Create `game_client/.../DFP_<NAME>/` with `.toc` + `.lua` files.
3. Register a slash command in the client addon: `SLASH_DFP<NAME>1 = "/<cmd>"`.
4. Add a button to `DFP_Panel.lua` that calls `SlashCmdList["DFP<NAME>"]("")`.
5. Add a reference comment in `dfp-panel-server.lua` listing the new module.
6. Write a `README.md` in the new module folder.
