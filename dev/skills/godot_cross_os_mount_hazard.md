# Godot Cross-OS Mount Hazard

Use this card when Godot import, `.import` generation, UID resolution, `.godot/uid_cache.bin`, or resource loading fails only inside Docker/WSL/Linux sandbox while the same project works from native Windows.

## Rule

Do not run Godot editor/import/headless against a cross-OS bind mount. For this project, Godot may only run against an OS-native project directory or the `/tmp` snapshot from `dev/agent_rules/godot_headless_check.md`, and that `/tmp` must itself be container-native Linux storage.

## Known bad setup

```yaml
services:
  agent-lot-haul:
    image: node:22-bookworm
    working_dir: /workspace
    volumes:
      - 'E:/GodotProjects/lot-and-haul:/workspace'
      - 'E:/tmp:/tmp'
```

This looks harmless but breaks the headless safety model. The project mount is already cross-OS, and mounting `E:/tmp` onto `/tmp` makes the supposedly safe `/tmp/lh.*` snapshot cross-OS too. Godot import then performs high-frequency file scans, creates `.import` files, updates UID cache data, and reloads resources through a filesystem bridge that can return stale, truncated, or desynced views.

## Symptom pattern

- Editor or headless logs mention invalid UID, missing `.import`, stale resource paths, or resource-cache problems.
- The same files look correct from native Windows or after disabling the cross-OS `/tmp` mount.
- Re-importing, deleting `.godot`, or touching files may appear to help briefly but does not make the mount trustworthy.

## Fix

Remove or comment out the host `/tmp` bind mount before running any Godot import/headless/test flow:

```yaml
volumes:
  - 'E:/GodotProjects/lot-and-haul:/workspace'
  # Do not mount E:/tmp to /tmp for Godot checks.
```

Then run Godot only from a native Windows checkout or from a fresh container-native `/tmp/lh.*` snapshot. If a Godot failure appears only inside the cross-OS sandbox, treat the filesystem layer as the prime suspect before diagnosing project resources.

## Incident note

Verified on 2026-06-14: `- 'E:/tmp:/tmp'` caused Godot import/cache behavior to fail in the sandbox; commenting out that single mount made the import flow normal again.
