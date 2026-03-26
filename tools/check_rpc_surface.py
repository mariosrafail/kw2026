import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
CANONICAL_PATH = ROOT / "scripts" / "app" / "runtime_shared.gd"
RUNTIME_PATH = ROOT / "scripts" / "app" / "runtime_rpc_logic.gd"
RUNTIME_CONTROLLER_PATH = ROOT / "scripts" / "app" / "runtime_controller.gd"
BRIDGE_PATH = ROOT / "scripts" / "ui" / "main_menu" / "lobby_rpc_bridge.gd"
MAIN_PATH = ROOT / "scripts" / "main.gd"


FUNC_RE = re.compile(r"^\s*func\s+(_rpc_[A-Za-z0-9_]+)\s*\((.*)\)\s*->\s*([A-Za-z0-9_]+)\s*:\s*$")
RPC_RE = re.compile(r'^\s*@rpc\((.*)\)\s*$')


def _normalize_signature(args: str, ret: str) -> str:
    normalized_args = re.sub(r"\s+", " ", args.strip())
    return f"({normalized_args}) -> {ret.strip()}"


def parse_rpc_methods(path: Path) -> dict[str, dict[str, str]]:
    methods: dict[str, dict[str, str]] = {}
    pending_rpc = ""
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        rpc_match = RPC_RE.match(raw_line)
        if rpc_match:
            pending_rpc = rpc_match.group(1).strip()
            continue
        func_match = FUNC_RE.match(raw_line)
        if func_match:
            methods[func_match.group(1)] = {
                "signature": _normalize_signature(func_match.group(2), func_match.group(3)),
                "rpc": pending_rpc,
            }
            pending_rpc = ""
            continue
        if raw_line.strip() and not raw_line.lstrip().startswith("#"):
            pending_rpc = ""
    return methods


def compare_signature_sets(label: str, canonical: dict[str, dict[str, str]], other: dict[str, dict[str, str]]) -> list[str]:
    errors: list[str] = []
    missing = sorted(set(canonical.keys()) - set(other.keys()))
    extra = sorted(set(other.keys()) - set(canonical.keys()))
    if missing:
        errors.append(f"{label}: missing methods: {', '.join(missing)}")
    if extra:
        errors.append(f"{label}: unexpected methods: {', '.join(extra)}")
    for method_name in sorted(set(canonical.keys()) & set(other.keys())):
        canonical_sig = canonical[method_name]["signature"]
        other_sig = other[method_name]["signature"]
        if canonical_sig != other_sig:
            errors.append(
                f"{label}: signature mismatch for {method_name}: canonical {canonical_sig} != {other_sig}"
            )
    return errors


def compare_rpc_annotations(label: str, canonical: dict[str, dict[str, str]], other: dict[str, dict[str, str]]) -> list[str]:
    errors: list[str] = []
    for method_name in sorted(set(canonical.keys()) & set(other.keys())):
        canonical_rpc = canonical[method_name]["rpc"]
        other_rpc = other[method_name]["rpc"]
        if canonical_rpc != other_rpc:
            errors.append(
                f'{label}: @rpc mismatch for {method_name}: canonical "{canonical_rpc}" != "{other_rpc}"'
            )
    return errors


def parse_rpc_method_order(paths: list[Path]) -> list[str]:
    ordered: list[str] = []
    for path in paths:
        for raw_line in path.read_text(encoding="utf-8").splitlines():
            func_match = FUNC_RE.match(raw_line)
            if func_match:
                ordered.append(func_match.group(1))
    return ordered


def compare_rpc_order(label: str, canonical_paths: list[Path], other_paths: list[Path]) -> list[str]:
    canonical_order = parse_rpc_method_order(canonical_paths)
    other_order = parse_rpc_method_order(other_paths)
    if canonical_order == other_order:
        return []
    min_len = min(len(canonical_order), len(other_order))
    for index in range(min_len):
        if canonical_order[index] != other_order[index]:
            return [
                f"{label}: rpc method order mismatch at index {index}: "
                f"canonical {canonical_order[index]} != {other_order[index]}"
            ]
    if len(canonical_order) != len(other_order):
        return [
            f"{label}: rpc method count mismatch in ordered comparison: "
            f"canonical {len(canonical_order)} != {len(other_order)}"
        ]
    return [f"{label}: rpc method order mismatch"]


def check_main_is_thin(path: Path) -> list[str]:
    errors: list[str] = []
    rpc_methods = parse_rpc_methods(path)
    if rpc_methods:
        errors.append(f"{path.relative_to(ROOT)} should not declare _rpc_ methods anymore.")
    return errors


def main() -> int:
    canonical = parse_rpc_methods(CANONICAL_PATH)
    runtime = parse_rpc_methods(RUNTIME_PATH)
    runtime_controller = parse_rpc_methods(RUNTIME_CONTROLLER_PATH)
    bridge = parse_rpc_methods(BRIDGE_PATH)
    gameplay_root = dict(canonical)
    gameplay_root.update(runtime_controller)

    errors: list[str] = []
    errors.extend(compare_signature_sets("runtime_rpc_logic.gd", canonical, runtime))
    errors.extend(compare_signature_sets("lobby_rpc_bridge.gd", gameplay_root, bridge))
    errors.extend(compare_rpc_annotations("lobby_rpc_bridge.gd", gameplay_root, bridge))
    errors.extend(compare_rpc_order(
        "lobby_rpc_bridge.gd",
        [CANONICAL_PATH, RUNTIME_CONTROLLER_PATH],
        [BRIDGE_PATH],
    ))
    errors.extend(check_main_is_thin(MAIN_PATH))

    if errors:
        print("RPC surface validation failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    print("RPC surface validation OK.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
