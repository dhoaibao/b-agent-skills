#!/usr/bin/env python3
"""Preserving Claude Code plugin/kernel lifecycle for b-agentic."""
from __future__ import annotations

import argparse
import json
import os
import shutil
from copy import deepcopy
import sys
from pathlib import Path

MARKER_START = "<!-- b-agentic:managed-kernel:start -->"
MARKER_END = "<!-- b-agentic:managed-kernel:end -->"

def safe_home(path: Path, home: Path) -> bool:
    try:
        path.expanduser().resolve().relative_to(home.resolve())
        return True
    except ValueError:
        return False

def copy_tree(source: Path, target: Path) -> None:
    target.parent.mkdir(parents=True, exist_ok=True)
    if target.is_symlink():
        raise SystemExit(f"refusing to replace symlinked Claude path: {target}")
    if target.exists():
        if target.is_dir():
            shutil.rmtree(target)
        else:
            target.unlink()
    shutil.copytree(source, target)

def tree_bytes(path: Path) -> dict[str, bytes]:
    if not path.exists():
        return {}
    return {str(item.relative_to(path)): item.read_bytes() for item in path.rglob("*") if item.is_file()}

def write_snapshot(source: Path, target: Path) -> None:
    if target.exists():
        shutil.rmtree(target)
    copy_tree(source, target)

def kernel_block(source: Path) -> str:
    text = source.read_text().rstrip()
    return f"{MARKER_START}\n{text}\n{MARKER_END}"

def merge_kernel(path: Path, source: Path, snapshot: Path, replace: bool) -> tuple[str, str]:
    if path.is_symlink():
        raise SystemExit(f"refusing to modify symlinked Claude instructions: {path}")
    block = kernel_block(source)
    existing = path.read_text() if path.exists() else ""
    if MARKER_START in existing and MARKER_END in existing:
        start = existing.index(MARKER_START)
        end = existing.index(MARKER_END, start) + len(MARKER_END)
        updated = existing[:start] + block + existing[end:]
        action = "replace"
    elif not existing:
        updated, action = block + "\n", "write"
    elif replace:
        updated, action = existing.rstrip() + "\n\n" + block + "\n", "append"
    else:
        updated, action = existing.rstrip() + "\n\n" + block + "\n", "append"
    snapshot.parent.mkdir(parents=True, exist_ok=True)
    snapshot.write_text(updated)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(updated)
    return action, updated

def load_object(path: Path, label: str) -> dict:
    try:
        value = json.loads(path.read_text())
    except Exception as exc:
        raise SystemExit(f"cannot safely read {label}: {exc}") from exc
    if not isinstance(value, dict):
        raise SystemExit(f"cannot safely read {label}: expected an object")
    return value


def load_managed_settings(source: Path) -> dict:
    managed = load_object(source / "plugin" / "settings.json", "b-agentic plugin settings")
    managed["enabledPlugins"] = {"b-agentic@local": True}
    return managed


def apply_managed_settings(data: dict, managed: dict) -> dict:
    conflicts = [key for key in ("crossSessionInbound", "statusLine") if key in data and data[key] != managed.get(key)]
    if conflicts:
        names = ", ".join(conflicts)
        raise SystemExit(f"refusing to overwrite user-owned Claude setting(s): {names}; remove the conflict or use an isolated Claude config")
    merged = deepcopy(data)
    for key, value in managed.items():
        if key == "enabledPlugins":
            enabled = merged.get(key)
            if enabled is None:
                enabled = {}
            if not isinstance(enabled, dict):
                raise SystemExit("cannot safely merge Claude settings: enabledPlugins is not an object")
            merged[key] = dict(enabled)
            for plugin, state in value.items():
                merged[key].setdefault(plugin, state)
        elif key == "permissions":
            permissions = merged.get(key)
            if permissions is None:
                permissions = {}
            if not isinstance(permissions, dict):
                raise SystemExit("cannot safely merge Claude settings: permissions is not an object")
            permissions = dict(permissions)
            managed_denies = value.get("deny", []) if isinstance(value, dict) else []
            existing_denies = permissions.get("deny", [])
            if not isinstance(existing_denies, list) or not isinstance(managed_denies, list):
                raise SystemExit("cannot safely merge Claude settings: permissions.deny is not a list")
            permissions["deny"] = list(existing_denies)
            for rule in managed_denies:
                if rule not in permissions["deny"]:
                    permissions["deny"].append(rule)
            merged[key] = permissions
        else:
            merged[key] = deepcopy(value)
    return merged


def merge_settings(path: Path, snapshot: Path, managed: dict, preserve_snapshot: bool = False) -> str:
    if path.is_symlink():
        raise SystemExit(f"refusing to modify symlinked Claude settings: {path}")
    original = path.read_text() if path.exists() else ""
    try:
        data = json.loads(original) if original else {}
        if not isinstance(data, dict):
            raise ValueError("settings must be an object")
    except Exception as exc:
        raise SystemExit(f"cannot safely merge Claude settings {path}: {exc}") from exc
    updated = json.dumps(apply_managed_settings(data, managed), indent=2, sort_keys=True) + "\n"
    snapshot.parent.mkdir(parents=True, exist_ok=True)
    if not preserve_snapshot or not snapshot.exists():
        snapshot.write_text(original)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(updated)
    return "write" if not original else "merge"

def install(args: argparse.Namespace) -> None:
    source = args.source.resolve()
    config = args.config.expanduser().resolve()
    home = Path.home().resolve()
    if not source.is_dir() or not (source / "plugin").is_dir() or not (source / "plugin" / ".claude-plugin" / "plugin.json").is_file() or not (source / "plugin" / "settings.json").is_file() or not (source / "references/kernel.template.md").is_file():
        raise SystemExit(f"invalid b-agentic source: {source}")
    if not safe_home(config, home):
        raise SystemExit(f"Claude config path must remain under home: {config}")
    plugin_source = source / "plugin"
    target = config / "plugins" / "b-agentic"
    metadata = config / "b-agentic"
    managed_settings = load_managed_settings(source)
    settings_path = config / "settings.json"
    kernel_path = config / "CLAUDE.md"
    if target.is_symlink():
        raise SystemExit(f"refusing to replace symlinked Claude plugin: {target}")
    if settings_path.is_symlink():
        raise SystemExit(f"refusing to modify symlinked Claude settings: {settings_path}")
    if kernel_path.is_symlink():
        raise SystemExit(f"refusing to modify symlinked Claude instructions: {kernel_path}")
    # Validate conflicts before copying any plugin or kernel files.
    existing_settings = settings_path.read_text() if settings_path.exists() else ""
    try:
        existing_data = json.loads(existing_settings) if existing_settings else {}
        if not isinstance(existing_data, dict):
            raise ValueError("settings must be an object")
        apply_managed_settings(existing_data, managed_settings)
    except SystemExit:
        raise
    except Exception as exc:
        raise SystemExit(f"cannot safely merge Claude settings {settings_path}: {exc}") from exc
    if args.dry_run:
        print(f"[dry-run] install plugin {plugin_source} -> {target}")
        print(f"[dry-run] merge kernel {source / 'references/kernel.template.md'} -> {kernel_path}")
        print(f"[dry-run] merge plugin activation -> {settings_path}")
        return
    metadata.mkdir(parents=True, exist_ok=True)
    target_snapshot = metadata / "plugin.snapshot"
    if target.exists():
        if target_snapshot.exists() and tree_bytes(target) != tree_bytes(target_snapshot):
            backup = metadata / "backups" / "plugin"
            write_snapshot(target, backup)
        elif not target_snapshot.exists():
            write_snapshot(target, metadata / "backups" / "preexisting-plugin")
    copy_tree(plugin_source, target)
    write_snapshot(plugin_source, target_snapshot)
    kernel_snapshot = metadata / "kernel.snapshot"
    kernel_action, _ = merge_kernel(kernel_path, source / "references/kernel.template.md", kernel_snapshot, args.replace_kernel)
    settings_snapshot = metadata / "settings.snapshot"
    existing_manifest = metadata / "install.json"
    settings_action = merge_settings(settings_path, settings_snapshot, managed_settings, preserve_snapshot=existing_manifest.is_file())
    manifest = {
        "suite": "b-agentic",
        "runtime": "claude-code",
        "installedAt": __import__("datetime").datetime.now().isoformat(timespec="seconds"),
        "paths": {"config": str(config), "plugin": str(target), "kernel": str(kernel_path), "settings": str(settings_path), "metadata": str(metadata)},
        "actions": {"kernel": kernel_action, "settings": settings_action},
        "managedSettings": managed_settings,
        "snapshots": {"plugin": str(target_snapshot), "kernel": str(kernel_snapshot), "settings": str(settings_snapshot)},
    }
    (metadata / "install.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
    print(f"b-agentic Claude Code install complete: {target}")

def remove_kernel(path: Path, snapshot: Path, created: bool) -> str:
    if not path.exists() or not snapshot.exists():
        return "missing"
    current = path.read_text()
    installed = snapshot.read_text()
    if current != installed:
        return "preserved"
    if created:
        path.unlink()
        return "removed"
    if MARKER_START not in current or MARKER_END not in current:
        return "preserved"
    start = current.index(MARKER_START)
    end = current.index(MARKER_END, start) + len(MARKER_END)
    cleaned = (current[:start].rstrip() + "\n" + current[end:].lstrip()).strip("\n") + "\n"
    path.write_text(cleaned)
    return "block-removed"

def restore_settings(path: Path, snapshot: Path, managed: dict) -> str:
    if path.is_symlink():
        print(f"warning: preserving symlinked settings: {path}", file=sys.stderr)
        return "preserved"
    if not path.exists() or not snapshot.exists():
        return "missing"
    original_text = snapshot.read_text()
    original = json.loads(original_text) if original_text else {}
    current = load_object(path, "installed Claude settings")
    expected = apply_managed_settings(original, managed)
    if current == expected:
        if original_text:
            path.write_text(original_text)
        else:
            path.unlink()
        return "restored"
    changed = deepcopy(current)
    for key, value in managed.items():
        if key == "enabledPlugins":
            enabled = changed.get(key)
            original_enabled = original.get(key, {})
            if isinstance(enabled, dict) and isinstance(original_enabled, dict):
                for plugin, state in value.items():
                    if plugin not in original_enabled and enabled.get(plugin) == state:
                        enabled.pop(plugin, None)
                if enabled:
                    changed[key] = enabled
                else:
                    changed.pop(key, None)
        elif key == "permissions":
            permissions = changed.get(key)
            original_permissions = original.get(key, {})
            managed_denies = value.get("deny", []) if isinstance(value, dict) else []
            original_denies = original_permissions.get("deny", []) if isinstance(original_permissions, dict) else []
            if isinstance(permissions, dict) and isinstance(permissions.get("deny"), list):
                permissions["deny"] = [rule for rule in permissions["deny"] if rule in original_denies or rule not in managed_denies]
                if isinstance(original_permissions, dict) and permissions == original_permissions:
                    changed[key] = deepcopy(original_permissions)
                elif permissions.get("deny"):
                    changed[key] = permissions
                else:
                    permissions.pop("deny", None)
                    if permissions:
                        changed[key] = permissions
                    else:
                        changed.pop(key, None)
        elif changed.get(key) == value:
            if key in original:
                changed[key] = deepcopy(original[key])
            else:
                changed.pop(key, None)
    path.write_text(json.dumps(changed, indent=2, sort_keys=True) + "\n")
    return "managed values removed; user changes preserved"


def uninstall(args: argparse.Namespace) -> None:
    manifest_path = args.manifest.expanduser().resolve()
    home = Path.home().resolve()
    if not safe_home(manifest_path, home) or not manifest_path.is_file():
        raise SystemExit(f"manifest not found under home: {manifest_path}")
    data = json.loads(manifest_path.read_text())
    if data.get("suite") != "b-agentic" or data.get("runtime") != "claude-code":
        raise SystemExit("unsupported b-agentic manifest")
    paths = data.get("paths", {})
    metadata = Path(paths.get("metadata", manifest_path.parent)).expanduser().resolve()
    if not safe_home(metadata, home):
        raise SystemExit("manifest metadata is outside home")
    plugin = Path(paths["plugin"]).expanduser()
    if not safe_home(plugin, home):
        raise SystemExit("manifest plugin path is outside home")
    plugin_snapshot = Path(data.get("snapshots", {}).get("plugin", metadata / "plugin.snapshot")).expanduser().resolve()
    if plugin.is_symlink():
        print(f"warning: preserving symlinked plugin: {plugin}", file=sys.stderr)
    elif plugin.exists() and plugin_snapshot.exists() and tree_bytes(plugin) == tree_bytes(plugin_snapshot):
        shutil.rmtree(plugin)
    elif plugin.exists():
        print(f"warning: preserving modified plugin: {plugin}", file=sys.stderr)
    kernel = Path(paths["kernel"]).expanduser()
    if not safe_home(kernel, home):
        raise SystemExit("manifest kernel path is outside home")
    if kernel.is_symlink():
        print(f"warning: preserving symlinked instructions: {kernel}", file=sys.stderr)
    kernel_snapshot = Path(data.get("snapshots", {}).get("kernel", metadata / "kernel.snapshot")).expanduser().resolve()
    print(f"kernel: {'preserved' if kernel.is_symlink() else remove_kernel(kernel, kernel_snapshot, data.get('actions', {}).get('kernel') == 'write')}")
    settings = Path(paths["settings"]).expanduser()
    if not safe_home(settings, home):
        raise SystemExit("manifest settings path is outside home")
    settings_snapshot = Path(data.get("snapshots", {}).get("settings", metadata / "settings.snapshot")).expanduser().resolve()
    managed_settings = data.get("managedSettings", {"enabledPlugins": {"b-agentic@local": True}})
    print(f"settings: {restore_settings(settings, settings_snapshot, managed_settings)}")
    manifest_path.unlink(missing_ok=True)
    # Keep no user files; metadata is b-agentic-owned and safe to remove.
    if metadata.exists() and safe_home(metadata, home):
        shutil.rmtree(metadata)
    print("Manifest-only uninstall complete for claude-code.")

def main() -> None:
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command", required=True)
    p_install = sub.add_parser("install")
    p_install.add_argument("--source", type=Path, required=True)
    p_install.add_argument("--config", type=Path, required=True)
    p_install.add_argument("--dry-run", action="store_true")
    p_install.add_argument("--replace-kernel", action="store_true")
    p_uninstall = sub.add_parser("uninstall")
    p_uninstall.add_argument("--manifest", type=Path, required=True)
    args = parser.parse_args()
    if args.command == "install":
        install(args)
    else:
        uninstall(args)

if __name__ == "__main__":
    main()
