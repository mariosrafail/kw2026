# Bake the approved AK silhouette from its existing cuboids. No source mesh edits.
from pathlib import Path
import importlib.util, json, re
ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('bb',ROOT/'tools/kw3d/prepare_fullbody.py')
module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module);module.SCALE=1.0
source=(ROOT/'scripts/prototypes/ak47_voxel_builder.gd').read_text()
text=source.split('const VOXELS: Array = ',1)[1].split('static func build',1)[0].strip()
voxels=json.loads(re.sub(r',\s*]',']',text))
boxes=[]
for v in voxels:
    sizes=[v[3],v[3],v[4]]
    boxes.append({k:[round(v[a]+sign*sizes[a]*0.5,5) for a in range(3)] for k,sign in [('from',-1),('to',1)]})
out=ROOT/'assets/prototypes/ak47_outline';out.mkdir(parents=True,exist_ok=True)
(out/'hull.json').write_text(json.dumps(module.outline(boxes,[0,0,0]),separators=(',',':')))
print('AK_UNION_READY',len(voxels))
