#!/usr/bin/env python3
"""Fast source-level verification for Flow Factory.
Runs without Godot so broken data/resource paths are caught before engine import.
"""
from __future__ import annotations
import json
import pathlib
import re
import sys
from collections import defaultdict

ROOT = pathlib.Path(__file__).resolve().parents[1]
ERRORS: list[str] = []


def fail(msg: str) -> None:
    ERRORS.append(msg)


def check_required_files() -> None:
    required = [
        "project.godot", "app/main.tscn", "game/game_controller.gd",
        "gameplay/item_actor.gd", "gameplay/junction_actor.gd",
        "gameplay/receiver_actor.gd", "gameplay/source_actor.gd",
        "gameplay/visual_factory.gd", "gameplay/level_validator.gd",
        "gameplay/track_geometry.gd", "gameplay/track_visuals.gd",
        "ui/hud.gd", "ui/cargo_icon.gd",
        "services/save_service.gd", "services/audio_service.gd",
        "services/haptic_service.gd", "services/analytics_service.gd",
        "assets/branding/icon.svg", "assets/branding/splash.svg",
        "assets/vendor/kaykit_prototype_bits/gltf/Barrel_A.gltf",
        "assets/vendor/kaykit_prototype_bits/gltf/Coin_A.gltf",
        "assets/vendor/kaykit_prototype_bits/gltf/prototypebits_texture.png",
        "assets/vendor/kaykit_space_base_bits/gltf/containers_C.gltf",
        "assets/vendor/kaykit_space_base_bits/gltf/basemodule_A.gltf",
        "assets/vendor/kaykit_space_base_bits/gltf/spacebits_texture.png",
        "assets/vendor/kaykit_space_base_bits/LICENSE.txt",
        "localisation/strings.csv",
        "assets/palette/toy_factory.tres",
        "default_bus_layout.tres",
        "game/scene_rig.gd", "game/level_builder.gd",
        "gameplay/item_pool.gd", "gameplay/motion.gd", "gameplay/screen_shake.gd",
        "assets/branding/icon.png", "assets/branding/splash.png",
        "assets/vendor/kaykit_prototype_bits/Pallet_Large_CC0_Derived.obj",
        "assets/vendor/kaykit_prototype_bits/Barrel_A_CC0_Derived.obj",
        "assets/vendor/kaykit_prototype_bits/Pallet_Loaded_CC0_Derived.obj",
        "assets/vendor/kaykit_prototype_bits/LICENSE.txt",
        "assets/vendor/kaykit_prototype_bits/SOURCE.md",
        "tests/track_geometry_check.gd", "tests/track_geometry_check.tscn",
    ]
    for rel in required:
        if not (ROOT / rel).exists():
            fail(f"missing required file: {rel}")


def check_resource_paths() -> None:
    pattern = re.compile(r'(?:preload|load)\(\s*["\']res://([^"\']+)["\']\s*\)')
    for path in ROOT.rglob("*.gd"):
        text = path.read_text(encoding="utf-8")
        for rel in pattern.findall(text):
            if not (ROOT / rel).exists():
                fail(f"{path.relative_to(ROOT)} references missing res://{rel}")


def outputs(node: dict) -> list[str]:
    if node["type"] == "receiver":
        return []
    if node["type"] == "junction":
        return [node["out_a"], node["out_b"]]
    return [node["next"]]


def graph_has_cycle(nodes: dict[str, dict]) -> bool:
    color = defaultdict(int)
    def visit(nid: str) -> bool:
        color[nid] = 1
        for nxt in outputs(nodes[nid]):
            if color[nxt] == 1:
                return True
            if color[nxt] == 0 and visit(nxt):
                return True
        color[nid] = 2
        return False
    return any(color[n] == 0 and visit(n) for n in nodes)


def reachable_kinds(nodes: dict[str, dict], source: str) -> set[str]:
    stack = [source]
    seen = set()
    kinds = set()
    while stack:
        nid = stack.pop()
        if nid in seen:
            continue
        seen.add(nid)
        node = nodes[nid]
        if node["type"] == "receiver":
            kinds.add(node["kind"])
        else:
            stack.extend(outputs(node))
    return kinds


def check_levels() -> None:
    paths = sorted((ROOT / "levels").glob("level_*.json"))
    if len(paths) != 10:
        fail(f"expected 10 levels, found {len(paths)}")
    for i, path in enumerate(paths, 1):
        try:
            level = json.loads(path.read_text(encoding="utf-8"))
        except Exception as exc:
            fail(f"{path.name}: invalid JSON: {exc}")
            continue
        if level.get("id") != i:
            fail(f"{path.name}: id must be {i}")
        if level.get("item_speed", 0) <= 0 or level.get("spawn_interval", 0) <= 0:
            fail(f"{path.name}: invalid speed/interval")
        if level.get("buffer_capacity", 0) < 3:
            fail(f"{path.name}: buffer capacity too small for MVP")
        nodes_list = level.get("nodes", [])
        nodes = {n.get("id"): n for n in nodes_list}
        if len(nodes) != len(nodes_list) or None in nodes:
            fail(f"{path.name}: duplicate or missing node id")
            continue
        for nid, node in nodes.items():
            if node.get("type") not in {"source", "normal", "junction", "receiver"}:
                fail(f"{path.name}: unsupported node type at {nid}")
                continue
            for nxt in outputs(node):
                if nxt not in nodes:
                    fail(f"{path.name}: {nid} points to missing {nxt}")
        if graph_has_cycle(nodes):
            fail(f"{path.name}: graph contains a cycle")
        cache: dict[str, set[str]] = {}
        for spawn in level.get("spawns", []):
            source = spawn.get("source")
            kind = spawn.get("kind")
            if source not in nodes or nodes[source].get("type") != "source":
                fail(f"{path.name}: invalid spawn source {source}")
                continue
            cache.setdefault(source, reachable_kinds(nodes, source))
            if kind not in cache[source]:
                fail(f"{path.name}: {kind} from {source} cannot reach matching receiver")


def check_vendor_assets() -> None:
    vendor = ROOT / "assets" / "vendor" / "kaykit_prototype_bits"
    minimums = {
        "Pallet_Large_CC0_Derived.obj": (50, 80),
        "Barrel_A_CC0_Derived.obj": (100, 180),
        "Pallet_Loaded_CC0_Derived.obj": (80, 120),
    }
    for name, (min_vertices, min_faces) in minimums.items():
        path = vendor / name
        if not path.exists():
            fail(f"vendor asset missing: {path.relative_to(ROOT)}")
            continue
        vertices = 0
        faces = 0
        for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
            if line.startswith("v "):
                vertices += 1
            elif line.startswith("f "):
                faces += 1
        if vertices < min_vertices or faces < min_faces:
            fail(f"vendor asset too simple/corrupt: {name} ({vertices}v/{faces}f)")
    license_text = (vendor / "LICENSE.txt").read_text(encoding="utf-8", errors="replace") if (vendor / "LICENSE.txt").exists() else ""
    source_text = (vendor / "SOURCE.md").read_text(encoding="utf-8", errors="replace") if (vendor / "SOURCE.md").exists() else ""
    if "CC0" not in license_text or "Kay Lousberg" not in license_text:
        fail("vendor license manifest missing CC0/KayKit provenance")
    if "github.com/KayKit-Game-Assets/KayKit-Prototype-Bits-1.0" not in source_text:
        fail("vendor source manifest missing upstream repository")


def check_audio() -> None:
    names = ["tap", "ui", "spawn", "correct", "wrong", "buffer_return", "win", "fail", "ambient"]
    for name in names:
        p = ROOT / "assets" / "audio" / f"{name}.wav"
        if not p.exists() or p.stat().st_size < 1000:
            fail(f"audio missing/too small: {p.relative_to(ROOT)}")


def main() -> int:
    check_required_files()
    check_resource_paths()
    check_levels()
    check_vendor_assets()
    check_audio()
    if ERRORS:
        print("FLOW FACTORY VERIFY: FAIL")
        for e in ERRORS:
            print(" -", e)
        return 1
    print("FLOW FACTORY VERIFY: PASS")
    print(" - required files present")
    print(" - preload/load resource paths resolve")
    print(" - 10 level graphs valid and terminating")
    print(" - every spawn kind can reach a matching receiver")
    print(" - bundled audio present")
    print(" - CC0 vendor geometry + provenance present")
    print(" - curved track renderer/geometry contract files present")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
