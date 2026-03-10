import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
CANONICAL_PATH = ROOT / "scripts" / "app" / "runtime_shared.gd"
RUNTIME_PATH = ROOT / "scripts" / "app" / "runtime_rpc_logic.gd"
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


def check_main_is_thin(path: Path) -> list[str]:
    errors: list[str] = []
    rpc_methods = parse_rpc_methods(path)
    if rpc_methods:
        errors.append(f"{path.relative_to(ROOT)} should not declare _rpc_ methods anymore.")
    return errors


def main() -> int:
    canonical = parse_rpc_methods(CANONICAL_PATH)
    runtime = parse_rpc_methods(RUNTIME_PATH)
    bridge = parse_rpc_methods(BRIDGE_PATH)

    errors: list[str] = []
    errors.extend(compare_signature_sets("runtime_rpc_logic.gd", canonical, runtime))
    errors.extend(compare_signature_sets("lobby_rpc_bridge.gd", canonical, bridge))
    errors.extend(compare_rpc_annotations("lobby_rpc_bridge.gd", canonical, bridge))
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
