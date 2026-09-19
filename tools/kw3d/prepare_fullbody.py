# Reproducible cuboid importer for the approved Blockbench source.
from pathlib import Path
import base64, hashlib, io, json, math
from PIL import Image
ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'art_source/blockbench/outrage/Outrage_FullBody_v11_slimmer_body_foot.bbmodel'
OUT = ROOT / 'assets/prototypes/outrage_fullbody'
SCALE = 0.07
CENTER = [0.0, 25.5, 0.0]
RIGS = {'Outrage_Head':'HeadRig','Torso':'TorsoRig','Foot_Left':'LeftLegRig','Foot_Right':'RightLegRig'}

def outline(boxes, pivot):
    axes = [sorted({float(b[k][a]) for b in boxes for k in ('from','to')}) for a in range(3)]
    occupied = set()
    for ix in range(len(axes[0])-1):
        for iy in range(len(axes[1])-1):
            for iz in range(len(axes[2])-1):
                cell = (ix,iy,iz)
                c = [(axes[a][cell[a]]+axes[a][cell[a]+1])*0.5 for a in range(3)]
                if any(all(b['from'][a]<c[a]<b['to'][a] for a in range(3)) for b in boxes):
                    occupied.add(cell)
    ids, vertices, normal_sets, indices = {}, [], [], []
    faces = [((0,0,-1),0),((0,0,1),1),((-1,0,0),2),((1,0,0),3),((0,1,0),4),((0,-1,0),5)]
    for cell in sorted(occupied):
        x0,y0,z0 = [axes[a][cell[a]] for a in range(3)]
        x1,y1,z1 = [axes[a][cell[a]+1] for a in range(3)]
        quads = [
            [(x1,y1,z0),(x0,y1,z0),(x0,y0,z0),(x1,y0,z0)],
            [(x0,y1,z1),(x1,y1,z1),(x1,y0,z1),(x0,y0,z1)],
            [(x0,y1,z0),(x0,y1,z1),(x0,y0,z1),(x0,y0,z0)],
            [(x1,y1,z1),(x1,y1,z0),(x1,y0,z0),(x1,y0,z1)],
            [(x0,y1,z0),(x1,y1,z0),(x1,y1,z1),(x0,y1,z1)],
            [(x0,y0,z1),(x1,y0,z1),(x1,y0,z0),(x0,y0,z0)]
        ]
        for normal, face_id in faces:
            if tuple(cell[a]+normal[a] for a in range(3)) in occupied:
                continue
            q = []
            for point in quads[face_id]:
                if point not in ids:
                    ids[point]=len(vertices)
                    vertices.append([(point[a]-pivot[a])*SCALE for a in range(3)])
                    normal_sets.append(set())
                index=ids[point]; normal_sets[index].add(normal); q.append(index)
            indices.extend([q[0],q[1],q[2],q[0],q[2],q[3]])
    normals=[]
    for ns in normal_sets:
        v=[sum(n[a] for n in ns) for a in range(3)]
        mag=math.sqrt(sum(k*k for k in v))
        normals.append([k/mag for k in v] if mag else list(next(iter(ns))))
    return {'vertices':vertices,'normals':normals,'indices':indices}

def main():
    data=json.loads(SOURCE.read_text(encoding='utf-8'))
    elements=data['elements']; by_id={e['uuid']:e for e in elements}
    groups={g['uuid']:g for g in data['groups']}
    assert len(elements)==len(by_id), 'Duplicate element UUIDs'
    assert all(e.get('type','cube')=='cube' for e in elements), 'Non-cuboid geometry needs exporter support'
    assert all(not any(e.get('rotation',[0,0,0])) for e in elements), 'Rotated cube: stop instead of flattening'
    assert all(not any(g.get('rotation',[0,0,0])) for g in groups.values()), 'Rotated group: stop instead of flattening'
    OUT.mkdir(parents=True,exist_ok=True)
    texture_data=[]
    for i,t in enumerate(data['textures']):
        assert t['source'].startswith('data:image/png;base64,'), 'Texture must be embedded'
        raw=base64.b64decode(t['source'].split(',',1)[1]); im=Image.open(io.BytesIO(raw)); im.load()
        name='palette_%02d.png'%i; (OUT/name).write_bytes(raw)
        texture_data.append({'path':name,'width':im.width,'height':im.height})
    result={name:{'name':name,'pivot':None,'parts':[]} for name in RIGS.values()}
    visited=[]
    def walk(items,rig=None):
        for item in items:
            if isinstance(item,str):
                e=by_id[item]; assert rig, 'Element outside an animation rig'
                assert e.get('export',True), 'Hidden/excluded parts need explicit review'
                assert all(e['to'][a]>e['from'][a] for a in range(3)), 'Non-positive cuboid'
                result[rig]['parts'].append(e); visited.append(item)
            else:
                g=groups[item['uuid']]; next_rig=RIGS.get(g['name'],rig)
                if g['name'] in RIGS: result[next_rig]['pivot']=g['origin']
                walk(item['children'],next_rig)
    walk(data['outliner'])
    assert sorted(visited)==sorted(by_id), 'Outliner does not cover every part exactly once'
    for rig in result.values():
        assert rig['pivot'] is not None and rig['parts']
        rig['rest']=[(rig['pivot'][a]-CENTER[a])*SCALE for a in range(3)]
        rig['outline']=outline(rig['parts'],rig['pivot'])
    sha=hashlib.sha256(SOURCE.read_bytes()).hexdigest()
    build={'source':SOURCE.relative_to(ROOT).as_posix(),'sha256':sha,
           'scale':SCALE,'center':CENTER,'capsule_height':3.43,
           'textures':texture_data,'rigs':list(result.values()),'part_count':len(elements)}
    (OUT/'build_data.json').write_text(json.dumps(build,separators=(',',':')),encoding='utf-8')
    print('PREPARE_PASS source='+sha+' parts='+str(len(elements)))
    print('RIGS',[(r['name'],len(r['parts']),r['rest']) for r in result.values()])
if __name__=='__main__': main()
