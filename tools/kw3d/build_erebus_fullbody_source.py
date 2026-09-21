"""Build the editable Erebus fullbody Blockbench source from approved assets.

The approved Erebus head stays byte-for-byte equivalent at the cuboid/texture
level.  Outrage supplies only the torso/feet structure.  This script keeps the
source generation deterministic so later user corrections can be made either
in Blockbench or here without touching the Outrage source of truth.
"""
from __future__ import annotations

from copy import deepcopy
from io import BytesIO
from pathlib import Path
import base64
import json
import uuid

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
OUTRAGE = ROOT / "art_source/blockbench/outrage/Outrage_FullBody_v11_slimmer_body_foot.bbmodel"
EREBUS_HEAD = ROOT / "art_source/blockbench/erebus/Erebus_Head_v01.bbmodel"
OUTPUT = ROOT / "art_source/blockbench/erebus/Erebus_FullBody_v01.bbmodel"

ORANGE = (0xDF, 0x71, 0x26)
DARK_ORANGE = (0xB0, 0x5A, 0x1E)
BODY_REMAP = {
    (0x8F, 0x1D, 0x27): ORANGE,
    (0x70, 0x17, 0x1F): DARK_ORANGE,
}

BELLY_GEOMETRY = {
    "Torso_Step": ([-4.5, 20.0, -6.5], [4.5, 22.0, 3.0]),
    "Torso_Lower": ([-4.5, 16.0, -7.5], [4.5, 20.0, 3.0]),
    "Torso_Tip": ([-2.5, 12.0, -3.5], [2.5, 16.0, 1.5]),
}


def _load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def _collect_tree_ids(node: dict) -> tuple[set[str], set[str]]:
    groups = {str(node["uuid"])}
    elements: set[str] = set()
    for child in node.get("children", []):
        if isinstance(child, str):
            elements.add(child)
        else:
            child_groups, child_elements = _collect_tree_ids(child)
            groups.update(child_groups)
            elements.update(child_elements)
    return groups, elements


def _find_group(items: list, group_uuid: str) -> dict:
    for item in items:
        if not isinstance(item, dict):
            continue
        if item.get("uuid") == group_uuid:
            return item
        try:
            return _find_group(item.get("children", []), group_uuid)
        except LookupError:
            pass
    raise LookupError(group_uuid)


def _replace_group(items: list, group_uuid: str, replacement: dict) -> bool:
    for index, item in enumerate(items):
        if not isinstance(item, dict):
            continue
        if item.get("uuid") == group_uuid:
            items[index] = deepcopy(replacement)
            return True
        if _replace_group(item.get("children", []), group_uuid, replacement):
            return True
    return False


def _recolor_body_texture(texture: dict) -> dict:
    result = deepcopy(texture)
    source = str(result["source"])
    assert source.startswith("data:image/png;base64,")
    raw = base64.b64decode(source.split(",", 1)[1])
    image = Image.open(BytesIO(raw)).convert("RGBA")

    seen = {key: 0 for key in BODY_REMAP}
    pixels = image.load()
    for y in range(image.height):
        for x in range(image.width):
            r, g, b, a = pixels[x, y]
            replacement = BODY_REMAP.get((r, g, b))
            if replacement is not None:
                seen[(r, g, b)] += 1
                pixels[x, y] = (*replacement, a)
    assert all(count > 0 for count in seen.values()), f"Missing expected body palette colors: {seen}"

    encoded = BytesIO()
    image.save(encoded, format="PNG")
    result["source"] = "data:image/png;base64," + base64.b64encode(encoded.getvalue()).decode("ascii")
    result["name"] = "Erebus_BodyFeet_Orange.png"
    result["id"] = "1"
    result["uuid"] = str(uuid.uuid5(uuid.NAMESPACE_URL, "kw://erebus/bodyfeet/v01"))
    return result


def main() -> None:
    outrage = _load(OUTRAGE)
    head = _load(EREBUS_HEAD)

    outrage_head_uuid = next(
        group["uuid"] for group in outrage["groups"]
        if group["name"] == "Outrage_Head"
    )
    outrage_head = _find_group(outrage["outliner"], outrage_head_uuid)
    old_group_ids, old_element_ids = _collect_tree_ids(outrage_head)

    body_elements = [
        deepcopy(element)
        for element in outrage["elements"]
        if element["uuid"] not in old_element_ids
    ]
    body_groups = [
        deepcopy(group)
        for group in outrage["groups"]
        if group["uuid"] not in old_group_ids
    ]

    by_name = {element["name"]: element for element in body_elements}
    assert "Torso_Upper" in by_name
    for name, (lo, hi) in BELLY_GEOMETRY.items():
        assert name in by_name
        by_name[name]["from"] = lo
        by_name[name]["to"] = hi

    head_elements = deepcopy(head["elements"])
    head_groups = deepcopy(head["groups"])
    head_tree = deepcopy(head["outliner"][0])
    assert head_tree["name"] == "Erebus_Head"

    remaining_ids = {element["uuid"] for element in body_elements}
    new_ids = {element["uuid"] for element in head_elements}
    assert remaining_ids.isdisjoint(new_ids), "Head UUID collides with Outrage body UUID"

    outliner = deepcopy(outrage["outliner"])
    assert _replace_group(outliner, outrage_head_uuid, head_tree)

    assert len(outrage["textures"]) >= 2
    head_texture = deepcopy(head["textures"][0])
    head_texture["id"] = "0"
    body_texture = _recolor_body_texture(outrage["textures"][1])

    result = deepcopy(outrage)
    result["name"] = "Erebus_FullBody_v01"
    result["model_identifier"] = "kw.erebus.fullbody.v01"
    result["elements"] = head_elements + body_elements
    result["groups"] = head_groups + body_groups
    result["outliner"] = outliner
    result["textures"] = [head_texture, body_texture]

    # Every element must still be referenced exactly once by the outliner.
    visited: list[str] = []
    def walk(items: list) -> None:
        for item in items:
            if isinstance(item, str):
                visited.append(item)
            else:
                walk(item.get("children", []))
    walk(result["outliner"])
    expected = [element["uuid"] for element in result["elements"]]
    assert sorted(visited) == sorted(expected)
    assert len(visited) == len(set(visited))

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(
        json.dumps(result, separators=(",", ":"), ensure_ascii=False),
        encoding="utf-8",
    )
    print(
        "EREBUS_SOURCE_PASS",
        f"parts={len(result['elements'])}",
        f"head={len(head_elements)}",
        f"body={len(body_elements)}",
        f"output={OUTPUT.relative_to(ROOT).as_posix()}",
    )


if __name__ == "__main__":
    main()
