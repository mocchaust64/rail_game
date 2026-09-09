#!/usr/bin/env python3
"""Fast source-level verification for Flow Factory.
Runs without Godot so broken data/resource paths and accidental vendor-model
regressions are caught before engine import.
"""
from __future__ import annotations
import json
import pathlib
import re
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
        "gameplay/visual_factory.gd", "gameplay/machine_visuals.gd",
        "gameplay/processor_visual.gd", "gameplay/track_motion.gd",
        "gameplay/level_validator.gd", "gameplay/track_geometry.gd",
        "gameplay/track_visuals.gd", "ui/hud.gd", "ui/cargo_icon.gd",
        "services/save_service.gd", "services/audio_service.gd",
        "services/haptic_service.gd", "services/analytics_service.gd",
        "assets/branding/icon.svg", "assets/branding/splash.svg",
        "localisation/strings.csv", "assets/palette/toy_factory.tres",
        "default_bus_layout.tres", "game/scene_rig.gd", "game/level_builder.gd",
        "gameplay/item_pool.gd", "gameplay/motion.gd", "gameplay/screen_shake.gd",
        "assets/branding/icon.png", "assets/branding/splash.png",
        "tests/track_geometry_check.gd", "tests/track_geometry_check.tscn",
        "tests/track_visuals_check.gd", "tests/track_visuals_check.tscn",
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


def check_custom_gameplay_visuals() -> None:
    core = [
        ROOT / "gameplay" / "track_visuals.gd",
        ROOT / "gameplay" / "track_motion.gd",
        ROOT / "gameplay" / "junction_actor.gd",
        ROOT / "gameplay" / "machine_visuals.gd",
        ROOT / "gameplay" / "processor_visual.gd",
        ROOT / "gameplay" / "visual_factory.gd",
        ROOT / "gameplay" / "source_actor.gd",
    ]
    forbidden = ("kenney", "kaykit", "assets/vendor")
    for path in core:
        if not path.exists():
            continue
        text = path.read_text(encoding="utf-8").lower()
        for token in forbidden:
            if token in text:
                fail(f"{path.relative_to(ROOT)} still depends on external gameplay assets: {token}")


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


def check_audio() -> None:
    names = ["tap", "ui", "spawn", "correct", "wrong", "buffer_return", "win", "fail", "ambient"]
    for name in names:
        p = ROOT / "assets" / "audio" / f"{name}.wav"
        if not p.exists() or p.stat().st_size < 1000:
            fail(f"audio missing/too small: {p.relative_to(ROOT)}")


def main() -> int:
    check_required_files()
    check_resource_paths()
    check_custom_gameplay_visuals()
    check_levels()
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
    print(" - gameplay visuals use only custom generated geometry")
    print(" - moving rail and custom processor files present")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
