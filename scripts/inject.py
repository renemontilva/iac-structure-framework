#!/usr/bin/env python3
import json
import sys
from pathlib import Path
from typing import Dict, Any, List

ROOT = Path("infra/layers")
PUBLISHED = Path("interfaces/published")


def load_plan(plan_path: Path) -> dict:
	return json.loads(plan_path.read_text())


def read_outputs(stack_id: str, env: str, version: str) -> Dict[str, Any]:
	outputs_file = PUBLISHED / env / stack_id / f"v{version}" / "outputs.json"
	if not outputs_file.exists():
		raise FileNotFoundError(f"Missing outputs for {stack_id} env={env} v{version}: {outputs_file}")
	return json.loads(outputs_file.read_text())


def flatten(prefix: str, obj: Any) -> Dict[str, str]:
	flat: Dict[str, str] = {}
	if isinstance(obj, dict):
		for k, v in obj.items():
			flat.update(flatten(f"{prefix}{k}_", v))
	elif isinstance(obj, list):
		flat[prefix.rstrip("_")] = json.dumps(obj)
	else:
		flat[prefix.rstrip("_")] = str(obj)
	return flat


def build_env_vars(dependencies: List[str], env: str, versions: Dict[str, str]) -> Dict[str, str]:
	all_vars: Dict[str, str] = {}
	for dep in dependencies:
		ver = versions.get(dep, "1.0.0")
		dep_outputs = read_outputs(dep, env, ver)
		dep_flat = flatten(f"TF_INJECT_{dep.upper().replace('-', '_')}_", dep_outputs)
		all_vars.update(dep_flat)
	return all_vars


def main() -> int:
	if len(sys.argv) < 5:
		print("Usage: inject.py <plan.json> <consumer_stack_id> <env> <versions.json>", file=sys.stderr)
		print("Example: inject.py out/plan.json platform-eks dev '{\"foundation-network\": \"1.0.0\"}'", file=sys.stderr)
		return 2
	plan_path = Path(sys.argv[1])
	consumer = sys.argv[2]
	env = sys.argv[3]
	versions = json.loads(sys.argv[4])
	plan = load_plan(plan_path)
	nodes = {n["stack_id"]: n for n in plan["nodes"]}
	if consumer not in nodes:
		print(f"Unknown consumer stack_id: {consumer}", file=sys.stderr)
		return 2
	deps = nodes[consumer]["depends_on"]
	env_vars = build_env_vars(deps, env, versions)
	print(json.dumps(env_vars, indent=2))
	return 0


if __name__ == "__main__":
	sys.exit(main())