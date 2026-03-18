# Client Modding

Modifying the WoW 3.3.5a game client — file formats, binary patches, DBC editing.
Client lives at `game_client/WOTLK/`. Raw extracted MPQ data at `raw_patches/` and `raw_locale_patches/`.

← [Back to Wiki Home](../README.md)

---

> **Status:** Reference files present. Full structured docs planned.

## Current Files

| File | Description |
|------|-------------|
| [file_formats.md](file_formats.md) | MPQ archives, DBC, ADT terrain, BLP textures, M2 models — struct layouts and tools |
| [wow_internals.md](wow_internals.md) | Taint system, protected API, IDA Pro binary unlocking, secure frames, build 12340 offsets |

## Planned Files

| File | Will cover |
|------|------------|
| `mpq_archives.md` | MPQ structure, tools (MPQEditor, StormLib), patching workflow |
| `dbc_files.md` | Full DBC list for WotLK, struct layouts, WDBXEditor workflow |
| `adt_terrain.md` | ADT chunk layout, heightmap format, Noggit workflow |
| `blp_textures.md` | BLP format, conversion tools, texture replacement |
| `m2_models.md` | M2/Skin structure, animation IDs, model replacement workflow |
| `taint_security.md` | Complete protected function list, InCombatLockdown, SecureHandler templates |
| `api_unlocking.md` | IDA Pro step-by-step, byte patches, memory offset table for build 12340 |

## Data Files Location
- DBC files: `acore_data_files/dbc/` (494 files, server-extracted)
- Map geometry: `acore_data_files/maps/`, `vmaps/`, `mmaps/`
- Raw MPQ data: `raw_patches/` — common, expansion, patch MPQs unpacked
- Locale data: `raw_locale_patches/` — enUS locale files unpacked

## Server ↔ Client DBC Sync
When editing DBC files for custom content:
- Server reads DBC at startup from `acore_data_files/dbc/`
- Client reads DBC from its MPQ archives
- **Both must match** for ID-referenced data (spell IDs, item IDs, etc.)
- Server DB overrides exist for some tables — see [dbc_access.md](../acore_development/dbc_access.md)
