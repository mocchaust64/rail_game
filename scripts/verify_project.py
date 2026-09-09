#!/usr/bin/env python3
"""Fast source-level verification for Flow Factory planning-router build."""
from __future__ import annotations
import itertools
import json
import pathlib
import re
from collections import defaultdict

ROOT = pathlib.Path(__file__).resolve().parents[1]
ERRORS: list[str] = []
KINDS = {"red", "blue", "yellow"}


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
        "gameplay/track_visuals.gd", "ui/hud.gd", "ui/planning_hud.gd",
        "ui/cargo_icon.gd", "services/save_service.gd", "services/audio_service.gd",
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


def routed_receiver(nodes: dict[str, dict], source: str, kind: str, rules: dict[str, str]) -> str | None:
    nid = source
    seen: set[str] = set()
    while nid in nodes and nid not in seen:
        seen.add(nid)
        node = nodes[nid]
        node_type = node["type"]
        if node_type == "receiver":
            return node.get("kind")
        if node_type == "junction":
            selected = rules[nid]
            nid = node["out_a"] if kind == selected else node["out_b"]
        else:
            nid = node["next"]
    return None


def planning_solution(level: dict, nodes: dict[str, dict]) -> dict[str, str] | None:
    junction_ids = [nid for nid, node in nodes.items() if node["type"] == "junction"]
    options: list[list[str]] = []
    for nid in junction_ids:
        raw = nodes[nid].get("filter_options", ["red", "blue", "yellow"])
        allowed = [str(value) for value in raw if str(value) in KINDS]
        if not allowed:
            return None
        options.append(allowed)

    for values in itertools.product(*options):
        rules = dict(zip(junction_ids, values))
        solved = True
        for spawn in level.get("spawns", []):
            kind = str(spawn.get("kind", ""))
            source = str(spawn.get("source", ""))
            if routed_receiver(nodes, source, kind, rules) != kind:
                solved = False
                break
        if solved:
            return rules
    return None


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
            fail(f"{path.name}: buffer capacity too small")

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
            if node.get("type") == "junction":
                filter_options = node.get("filter_options", ["red", "blue", "yellow"])
                if not filter_options or any(str(value) not in KINDS for value in filter_options):
                    fail(f"{path.name}: {nid} has invalid filter_options")

        if graph_has_cycle(nodes):
            fail(f"{path.name}: graph contains a cycle")

        cache: dict[str, set[str]] = {}
        for spawn in level.get("spawns", []):
            source = spawn.get("source")
            kind = spawn.get("kind")
            if source not in nodes or nodes[source].get("type") != "source":
                fail(f"{path.name}: invalid spawn source {source}")
                continue
            if kind not in KINDS:
                fail(f"{path.name}: unsupported spawn kind {kind}")
                continue
            cache.setdefault(source, reachable_kinds(nodes, source))
            if kind not in cache[source]:
                fail(f"{path.name}: {kind} from {source} cannot reach matching receiver")

        solution = planning_solution(level, nodes)
        if solution is None:
            fail(f"{path.name}: no planning-router solution exists")
        else:
            summary = ", ".join(f"{nid}={kind}" for nid, kind in solution.items())
            print(f" - {path.name} solution: {summary}")


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
    print(" - resource paths resolve")
    print(" - 10 terminating level graphs")
    print(" - every level has a valid pre-run routing solution")
    print(" - gameplay visuals use custom generated geometry")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
