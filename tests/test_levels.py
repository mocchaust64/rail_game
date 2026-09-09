import json
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
LEVELS = ROOT / "levels"
KINDS = {"red", "blue", "yellow"}


def load_levels():
    return [json.loads(p.read_text()) for p in sorted(LEVELS.glob("level_*.json"))]


def reachable_receivers(level, source):
    nodes = {n["id"]: n for n in level["nodes"]}
    seen = set()
    stack = [source]
    result = set()
    while stack:
        cur = stack.pop()
        if cur in seen:
            continue
        seen.add(cur)
        n = nodes[cur]
        if n["type"] == "receiver":
            result.add(n["kind"])
            continue
        if n["type"] == "junction":
            stack.extend([n["out_a"], n["out_b"]])
        else:
            stack.append(n["next"])
    return result


class LevelContractTests(unittest.TestCase):
    def test_exactly_ten_levels(self):
        self.assertEqual(10, len(load_levels()))

    def test_ids_match_files_and_are_unique(self):
        ids = [x["id"] for x in load_levels()]
        self.assertEqual(list(range(1, 11)), ids)

    def test_node_graphs_are_well_formed(self):
        for level in load_levels():
            nodes = {n["id"]: n for n in level["nodes"]}
            self.assertEqual(len(nodes), len(level["nodes"]), level["id"])
            for n in nodes.values():
                self.assertEqual(2, len(n["pos"]))
                if n["type"] == "junction":
                    self.assertIn(n["out_a"], nodes)
                    self.assertIn(n["out_b"], nodes)
                    self.assertNotEqual(n["out_a"], n["out_b"])
                elif n["type"] != "receiver":
                    self.assertIn(n["next"], nodes)

    def test_every_spawn_can_reach_matching_receiver(self):
        for level in load_levels():
            cache = {}
            for spawn in level["spawns"]:
                source = spawn["source"]
                cache.setdefault(source, reachable_receivers(level, source))
                self.assertIn(spawn["kind"], cache[source], (level["id"], spawn))

    def test_gameplay_values_remain_puzzle_not_reflex(self):
        for level in load_levels():
            self.assertGreaterEqual(level["spawn_interval"], 1.10)
            self.assertLessEqual(level["item_speed"], 1.80)
            self.assertGreaterEqual(level["buffer_capacity"], 3)
            self.assertGreater(level["buffer_return_delay"], 2.0)

    def test_all_three_shapes_appear_by_level_three(self):
        kinds = {s["kind"] for l in load_levels()[:3] for s in l["spawns"]}
        self.assertEqual(KINDS, kinds)


if __name__ == "__main__":
    unittest.main(verbosity=2)
