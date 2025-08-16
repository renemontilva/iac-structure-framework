#!/usr/bin/env python3
import json
import sys
import os
from pathlib import Path
from typing import Dict, List, Set, Tuple

try:
	import yaml  # type: ignore
	except_msg = None
except Exception as e:
	except_msg = str(e)
	yaml = None

SCHEMA_PATH = Path("schemas/layer.schema.json")
ROOT = Path("infra/layers")


def load_json(path: Path) -> dict:
	with open(path, "r", encoding="utf-8") as f:
		return json.load(f)


def validate_manifest(manifest: dict, schema: dict) -> None:
	# Minimal inline validator to avoid dependency; assert required fields and types
	required = schema.get("required", [])
	for key in required:
		if key not in manifest:
			raise ValueError(f"Missing required field: {key}")
	# Spot checks
	if not isinstance(manifest.get("depends_on", []), list):
		raise ValueError("depends_on must be a list")
	if not isinstance(manifest.get("layer_order"), int):
		raise ValueError("layer_order must be an integer")


def find_manifests(root: Path) -> List[Path]:
	return [p for p in root.rglob("layer.yaml")]


def load_manifests(paths: List[Path], schema: dict) -> Dict[str, dict]:
	manifests: Dict[str, dict] = {}
	for p in paths:
		with open(p, "r", encoding="utf-8") as f:
			data = yaml.safe_load(f)
		validate_manifest(data, schema)
		stack_id = data["stack_id"]
		if stack_id in manifests:
			raise ValueError(f"Duplicate stack_id: {stack_id}")
		data["__file__"] = str(p)
		manifests[stack_id] = data
	return manifests


def build_dag(manifests: Dict[str, dict]) -> Dict[str, Set[str]]:
	# edges: A -> B means A must run before B (B depends on A)
	edges: Dict[str, Set[str]] = {sid: set() for sid in manifests.keys()}
	for stack_id, m in manifests.items():
		for dep in m.get("depends_on", []):
			if dep not in manifests:
				raise ValueError(f"Stack {stack_id} depends on unknown stack {dep}")
			edges[dep].add(stack_id)
	return edges


def topo_sort(manifests: Dict[str, dict], edges: Dict[str, Set[str]]) -> List[str]:
	# Kahn's algorithm, preferring lower layer_order first
	in_degree: Dict[str, int] = {sid: 0 for sid in manifests.keys()}
	for src, dests in edges.items():
		for d in dests:
			in_degree[d] += 1
	ready = [sid for sid, deg in in_degree.items() if deg == 0]
	ready.sort(key=lambda sid: manifests[sid]["layer_order"]) 
	order: List[str] = []
	while ready:
		sid = ready.pop(0)
		order.append(sid)
		for d in sorted(edges[sid]):
			in_degree[d] -= 1
			if in_degree[d] == 0:
				ready.append(d)
				ready.sort(key=lambda x: manifests[x]["layer_order"])  
	if len(order) != len(manifests):
		raise ValueError("Cycle detected in DAG or missing nodes")
	return order


def build_injection_map(manifests: Dict[str, dict]) -> Dict[str, List[str]]:
	# For each consumer, list providers whose outputs are injected
	injections: Dict[str, List[str]] = {sid: [] for sid in manifests}
	for sid, m in manifests.items():
		for dep in m.get("depends_on", []):
			injections[sid].append(dep)
	return injections


def main() -> int:
	if yaml is None:
		print("ERROR: PyYAML not available:", except_msg, file=sys.stderr)
		return 2
	if not SCHEMA_PATH.exists():
		print(f"ERROR: Missing schema {SCHEMA_PATH}", file=sys.stderr)
		return 2
	schema = load_json(SCHEMA_PATH)
	paths = find_manifests(ROOT)
	if not paths:
		print("No stacks found", file=sys.stderr)
		return 1
	manifests = load_manifests(paths, schema)
	edges = build_dag(manifests)
	order = topo_sort(manifests, edges)
	injections = build_injection_map(manifests)

	plan = {
		"execution_order": order,
		"nodes": [
			{
				"stack_id": sid,
				"name": manifests[sid]["name"],
				"layer_order": manifests[sid]["layer_order"],
				"depends_on": manifests[sid]["depends_on"],
				"outputs_contract": manifests[sid]["outputs_contract"],
				"file": manifests[sid]["__file__"],
			}
			for sid in order
		],
		"dependency_injection": injections,
	}
	print(json.dumps(plan, indent=2))
	return 0


if __name__ == "__main__":
	sys.exit(main())