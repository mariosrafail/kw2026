"""Reproducible cuboid importer for the authored Erebus fullbody source."""
from pathlib import Path
import base64
import hashlib
import io
import json

from PIL import Image

from prepare_fullbody import CENTER, ROOT, SCALE, outline


SOURCE = ROOT / "art_source/blockbench/erebus/Erebus_FullBody_v01.bbmodel"
OUT = ROOT / "assets/prototypes/erebus_fullbody"
RIGS = {
    "Erebus_Head": "HeadRig",
    "Torso": "TorsoRig",
    "Foot_Left": "LeftLegRig",
    "Foot_Right": "RightLegRig",
}


def main() -> None:
    data = json.loads(SOURCE.read_text(encoding="utf-8"))
    elements = data["elements"]
    by_id = {element["uuid"]: element for element in elements}
    groups = {group["uuid"]: group for group in data["groups"]}
    assert len(elements) == len(by_id), "Duplicate element UUIDs"
    assert all(element.get("type", "cube") == "cube" for element in elements)
    assert all(not any(element.get("rotation", [0, 0, 0])) for element in elements)
    assert all(not any(group.get("rotation", [0, 0, 0])) for group in groups.values())

    OUT.mkdir(parents=True, exist_ok=True)
    texture_data = []
    for index, texture in enumerate(data["textures"]):
        assert texture["source"].startswith("data:image/png;base64,")
        raw = base64.b64decode(texture["source"].split(",", 1)[1])
        image = Image.open(io.BytesIO(raw))
        image.load()
        name = "palette_%02d.png" % index
        (OUT / name).write_bytes(raw)
        texture_data.append({"path": name, "width": image.width, "height": image.height})

    result = {
        rig_name: {"name": rig_name, "pivot": None, "parts": []}
        for rig_name in RIGS.values()
    }
    visited = []

    def walk(items, rig=None):
        for item in items:
            if isinstance(item, str):
                element = by_id[item]
                assert rig, "Element outside an animation rig"
                assert element.get("export", True)
                assert all(element["to"][axis] > element["from"][axis] for axis in range(3))
                result[rig]["parts"].append(element)
                visited.append(item)
            else:
                group = groups[item["uuid"]]
                next_rig = RIGS.get(group["name"], rig)
                if group["name"] in RIGS:
                    result[next_rig]["pivot"] = group["origin"]
                walk(item["children"], next_rig)

    walk(data["outliner"])
    assert sorted(visited) == sorted(by_id)

    for rig in result.values():
        assert rig["pivot"] is not None and rig["parts"]
        rig["rest"] = [
            (rig["pivot"][axis] - CENTER[axis]) * SCALE
            for axis in range(3)
        ]
        rig["outline"] = outline(rig["parts"], rig["pivot"])

    sha = hashlib.sha256(SOURCE.read_bytes()).hexdigest()
    build = {
        "source": SOURCE.relative_to(ROOT).as_posix(),
        "sha256": sha,
        "scale": SCALE,
        "center": CENTER,
        "capsule_height": 3.43,
        "textures": texture_data,
        "rigs": list(result.values()),
        "part_count": len(elements),
    }
    (OUT / "build_data.json").write_text(
        json.dumps(build, separators=(",", ":")),
        encoding="utf-8",
    )
    manifest = {
        "source_sha256": sha,
        "source_file": SOURCE.relative_to(ROOT).as_posix(),
        "part_count": len(elements),
        "approved_head_source": "art_source/blockbench/erebus/Erebus_Head_v01.bbmodel",
        "base_body_source": "art_source/blockbench/outrage/Outrage_FullBody_v11_slimmer_body_foot.bbmodel",
        "generated_by": "tools/kw3d/build_erebus_fullbody_source.py",
    }
    (OUT / "source_manifest.json").write_text(
        json.dumps(manifest, indent=2) + "\n",
        encoding="utf-8",
    )
    print("EREBUS_PREPARE_PASS source=" + sha + " parts=" + str(len(elements)))
    print("RIGS", [(rig["name"], len(rig["parts"]), rig["rest"]) for rig in result.values()])


if __name__ == "__main__":
    main()
