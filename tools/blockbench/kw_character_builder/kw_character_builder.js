(function() {
    'use strict';

    const PLUGIN_ID = 'kw_character_builder';
    const SIZE = 64;
    const FACES = ['front', 'back', 'right', 'left', 'top', 'bottom'];
    const FACE_LABELS = {
        front: 'FRONT', back: 'BACK', right: 'RIGHT', left: 'LEFT', top: 'TOP', bottom: 'BOTTOM'
    };
    const FACE_TO_CUBE = {
        front: 'north', back: 'south', right: 'east', left: 'west', top: 'up', bottom: 'down'
    };

    // Anchors match the current KW / Outrage authored proportions closely.
    const PARTS = [
        {id: 'head', label: 'HEAD', anchor: [0, 40, 0]},
        {id: 'torso', label: 'TORSO', anchor: [0, 22, 0]},
        {id: 'left_leg', label: 'LEFT LEG', anchor: [-4.5, 3, -1]},
        {id: 'right_leg', label: 'RIGHT LEG', anchor: [4.5, 3, -1]},
    ];

    const state = {
        part: 'head',
        face: 'front',
        tool: 'brush',
        color: '#8f1d27',
        brushSize: 1,
        voxelSize: 1,
        mode: 'forgiving',
        whiteToAlpha: true,
        newProject: true,
        anchors: {},
        stores: {},
        painting: false,
        lastCell: null,
    };

    let openAction = null;
    let editorDialog = null;
    let editorCanvas = null;
    let editorCtx = null;

    function makeCanvas() {
        const c = document.createElement('canvas');
        c.width = SIZE;
        c.height = SIZE;
        const ctx = c.getContext('2d', {willReadFrequently: true});
        ctx.clearRect(0, 0, SIZE, SIZE);
        ctx.imageSmoothingEnabled = false;
        return c;
    }

    function initState() {
        PARTS.forEach(part => {
            state.anchors[part.id] = part.anchor.slice();
            state.stores[part.id] = {};
            FACES.forEach(face => state.stores[part.id][face] = makeCanvas());
        });
    }

    function currentStore() {
        return state.stores[state.part][state.face];
    }

    function renderEditor() {
        if (!editorCtx || !editorCanvas) return;
        editorCtx.clearRect(0, 0, SIZE, SIZE);
        editorCtx.drawImage(currentStore(), 0, 0);
        refreshTabState();
        refreshAnchorInputs();
    }

    function refreshTabState() {
        const root = document.getElementById('kwcb_root');
        if (!root) return;
        root.querySelectorAll('[data-kw-part]').forEach(el => {
            el.classList.toggle('active', el.dataset.kwPart === state.part);
        });
        root.querySelectorAll('[data-kw-face]').forEach(el => {
            el.classList.toggle('active', el.dataset.kwFace === state.face);
        });
        root.querySelectorAll('[data-kw-tool]').forEach(el => {
            el.classList.toggle('active', el.dataset.kwTool === state.tool);
        });
    }

    function refreshAnchorInputs() {
        const root = document.getElementById('kwcb_root');
        if (!root) return;
        const a = state.anchors[state.part];
        ['x', 'y', 'z'].forEach((axis, i) => {
            const input = root.querySelector(`[data-anchor="${axis}"]`);
            if (input && document.activeElement !== input) input.value = a[i];
        });
    }

    function setStatus(text, kind = '') {
        const el = document.getElementById('kwcb_status');
        if (!el) return;
        el.textContent = text;
        el.dataset.kind = kind;
    }

    function eventCell(event) {
        const rect = editorCanvas.getBoundingClientRect();
        return {
            x: Math.max(0, Math.min(SIZE - 1, Math.floor((event.clientX - rect.left) / rect.width * SIZE))),
            y: Math.max(0, Math.min(SIZE - 1, Math.floor((event.clientY - rect.top) / rect.height * SIZE))),
        };
    }

    function parseHex(hex) {
        let value = (hex || '#000000').replace('#', '');
        if (value.length === 3) value = value.split('').map(c => c + c).join('');
        const n = parseInt(value, 16) || 0;
        return [(n >> 16) & 255, (n >> 8) & 255, n & 255, 255];
    }

    function rgbaHex(r, g, b) {
        return '#' + [r, g, b].map(v => v.toString(16).padStart(2, '0')).join('');
    }

    function paintAt(cell) {
        const store = currentStore();
        const ctx = store.getContext('2d', {willReadFrequently: true});
        const radius = Math.max(1, state.brushSize);
        if (state.tool === 'picker') {
            const px = ctx.getImageData(cell.x, cell.y, 1, 1).data;
            if (px[3]) {
                state.color = rgbaHex(px[0], px[1], px[2]);
                const input = document.getElementById('kwcb_color');
                if (input) input.value = state.color;
            }
            state.tool = 'brush';
            refreshTabState();
            return;
        }
        for (let oy = 0; oy < radius; oy++) {
            for (let ox = 0; ox < radius; ox++) {
                const x = cell.x + ox;
                const y = cell.y + oy;
                if (x < 0 || y < 0 || x >= SIZE || y >= SIZE) continue;
                if (state.tool === 'eraser') {
                    ctx.clearRect(x, y, 1, 1);
                } else {
                    ctx.fillStyle = state.color;
                    ctx.fillRect(x, y, 1, 1);
                }
            }
        }
        renderEditor();
    }

    function lineCells(a, b) {
        const out = [];
        let x0 = a.x, y0 = a.y, x1 = b.x, y1 = b.y;
        const dx = Math.abs(x1 - x0), sx = x0 < x1 ? 1 : -1;
        const dy = -Math.abs(y1 - y0), sy = y0 < y1 ? 1 : -1;
        let err = dx + dy;
        while (true) {
            out.push({x: x0, y: y0});
            if (x0 === x1 && y0 === y1) break;
            const e2 = 2 * err;
            if (e2 >= dy) { err += dy; x0 += sx; }
            if (e2 <= dx) { err += dx; y0 += sy; }
        }
        return out;
    }

    function pointerDown(event) {
        event.preventDefault();
        if (event.button === 2) state.tool = 'picker';
        state.painting = true;
        const cell = eventCell(event);
        state.lastCell = cell;
        paintAt(cell);
        try { editorCanvas.setPointerCapture(event.pointerId); } catch (_) {}
    }

    function pointerMove(event) {
        if (!state.painting) return;
        const cell = eventCell(event);
        if (state.lastCell && state.tool !== 'picker') {
            lineCells(state.lastCell, cell).forEach(paintAt);
        } else {
            paintAt(cell);
        }
        state.lastCell = cell;
    }

    function pointerUp(event) {
        state.painting = false;
        state.lastCell = null;
        try { editorCanvas.releasePointerCapture(event.pointerId); } catch (_) {}
    }

    function clearCurrentFace() {
        const c = currentStore();
        c.getContext('2d').clearRect(0, 0, SIZE, SIZE);
        renderEditor();
    }

    function flipCurrent(horizontal) {
        const src = currentStore();
        const tmp = makeCanvas();
        const ctx = tmp.getContext('2d');
        ctx.save();
        if (horizontal) {
            ctx.translate(SIZE, 0);
            ctx.scale(-1, 1);
        } else {
            ctx.translate(0, SIZE);
            ctx.scale(1, -1);
        }
        ctx.drawImage(src, 0, 0);
        ctx.restore();
        src.getContext('2d').clearRect(0, 0, SIZE, SIZE);
        src.getContext('2d').drawImage(tmp, 0, 0);
        renderEditor();
    }

    function downloadDataURL(filename, dataURL) {
        const a = document.createElement('a');
        a.href = dataURL;
        a.download = filename;
        document.body.appendChild(a);
        a.click();
        a.remove();
    }

    function exportCurrentFace() {
        downloadDataURL(`kw_${state.part}_${state.face}.png`, currentStore().toDataURL('image/png'));
    }

    function importCurrentFace(file) {
        if (!file) return;
        const reader = new FileReader();
        reader.onload = () => {
            const img = new Image();
            img.onload = () => {
                const target = currentStore();
                const ctx = target.getContext('2d', {willReadFrequently: true});
                ctx.clearRect(0, 0, SIZE, SIZE);
                ctx.imageSmoothingEnabled = false;
                ctx.drawImage(img, 0, 0, SIZE, SIZE);
                if (state.whiteToAlpha) {
                    const id = ctx.getImageData(0, 0, SIZE, SIZE);
                    for (let i = 0; i < id.data.length; i += 4) {
                        if (id.data[i] > 248 && id.data[i + 1] > 248 && id.data[i + 2] > 248) {
                            id.data[i + 3] = 0;
                        }
                    }
                    ctx.putImageData(id, 0, 0);
                }
                renderEditor();
                setStatus(`Imported ${file.name} into ${state.part}/${state.face}`, 'ok');
            };
            img.src = reader.result;
        };
        reader.readAsDataURL(file);
    }

    function setFaceDataURL(partId, face, dataURL) {
        return new Promise((resolve, reject) => {
            if (!state.stores[partId] || !state.stores[partId][face]) {
                reject(new Error(`Unknown KW face ${partId}/${face}`));
                return;
            }
            const img = new Image();
            img.onload = () => {
                const target = state.stores[partId][face];
                const ctx = target.getContext('2d', {willReadFrequently: true});
                ctx.clearRect(0, 0, SIZE, SIZE);
                ctx.imageSmoothingEnabled = false;
                ctx.drawImage(img, 0, 0, SIZE, SIZE);
                if (state.part === partId && state.face === face) renderEditor();
                resolve();
            };
            img.onerror = () => reject(new Error(`Could not decode ${partId}/${face}`));
            img.src = dataURL;
        });
    }

    function saveKWProject() {
        const payload = {
            version: 1,
            size: SIZE,
            voxelSize: state.voxelSize,
            mode: state.mode,
            anchors: state.anchors,
            parts: {},
        };
        PARTS.forEach(part => {
            payload.parts[part.id] = {};
            FACES.forEach(face => payload.parts[part.id][face] = state.stores[part.id][face].toDataURL('image/png'));
        });
        const blob = new Blob([JSON.stringify(payload)], {type: 'application/json'});
        const url = URL.createObjectURL(blob);
        downloadDataURL('kw_character.kwskin.json', url);
        setTimeout(() => URL.revokeObjectURL(url), 1000);
    }

    function loadKWProject(file) {
        if (!file) return;
        const reader = new FileReader();
        reader.onload = async () => {
            try {
                const payload = JSON.parse(reader.result);
                state.voxelSize = Number(payload.voxelSize || 1);
                state.mode = payload.mode === 'strict' ? 'strict' : 'forgiving';
                PARTS.forEach(part => {
                    if (payload.anchors && payload.anchors[part.id]) state.anchors[part.id] = payload.anchors[part.id].slice(0, 3).map(Number);
                });
                const loads = [];
                PARTS.forEach(part => FACES.forEach(face => {
                    const src = payload.parts && payload.parts[part.id] && payload.parts[part.id][face];
                    if (!src) return;
                    loads.push(new Promise(resolve => {
                        const img = new Image();
                        img.onload = () => {
                            const c = state.stores[part.id][face];
                            const ctx = c.getContext('2d');
                            ctx.clearRect(0, 0, SIZE, SIZE);
                            ctx.drawImage(img, 0, 0, SIZE, SIZE);
                            resolve();
                        };
                        img.src = src;
                    }));
                }));
                await Promise.all(loads);
                const root = document.getElementById('kwcb_root');
                if (root) {
                    root.querySelector('#kwcb_voxel_size').value = state.voxelSize;
                    root.querySelector('#kwcb_mode').value = state.mode;
                }
                renderEditor();
                setStatus(`Loaded ${file.name}`, 'ok');
            } catch (error) {
                console.error(error);
                setStatus('Could not load KW skin project', 'error');
            }
        };
        reader.readAsText(file);
    }

    function pixelData(canvas) {
        return canvas.getContext('2d', {willReadFrequently: true}).getImageData(0, 0, SIZE, SIZE).data;
    }

    function rgbaAt(data, u, v) {
        if (u < 0 || v < 0 || u >= SIZE || v >= SIZE) return [0, 0, 0, 0];
        const i = (v * SIZE + u) * 4;
        return [data[i], data[i + 1], data[i + 2], data[i + 3]];
    }

    function packRGBA(c) {
        return (((c[0] << 24) | (c[1] << 16) | (c[2] << 8) | c[3]) >>> 0).toString(16).padStart(8, '0');
    }

    function faceSample(face, data, x, y, z) {
        const sy = SIZE - 1 - y;
        switch (face) {
            case 'front': return rgbaAt(data, x, sy);
            case 'back': return rgbaAt(data, SIZE - 1 - x, sy);
            case 'right': return rgbaAt(data, z, sy);
            case 'left': return rgbaAt(data, SIZE - 1 - z, sy);
            case 'top': return rgbaAt(data, x, z);
            case 'bottom': return rgbaAt(data, x, SIZE - 1 - z);
        }
        return [0, 0, 0, 0];
    }

    function hasPaint(data) {
        for (let i = 3; i < data.length; i += 4) if (data[i] > 8) return true;
        return false;
    }

    function visualHull(partId) {
        const faceData = {};
        const active = {};
        FACES.forEach(face => {
            faceData[face] = pixelData(state.stores[partId][face]);
            active[face] = hasPaint(faceData[face]);
        });
        const anyPaint = FACES.some(face => active[face]);
        if (!anyPaint) return {voxels: new Map(), active, missing: [], empty: true};
        const pairs = [['front', 'back'], ['left', 'right'], ['top', 'bottom']];
        const missing = pairs.filter(pair => !active[pair[0]] && !active[pair[1]]);
        if (missing.length) return {voxels: new Map(), active, missing, empty: false};

        const voxels = new Map();
        let min = [SIZE, SIZE, SIZE], max = [-1, -1, -1];
        for (let y = 0; y < SIZE; y++) {
            for (let z = 0; z < SIZE; z++) {
                for (let x = 0; x < SIZE; x++) {
                    const s = {};
                    FACES.forEach(face => s[face] = faceSample(face, faceData[face], x, y, z));
                    const opaque = face => !active[face] || s[face][3] > 8;
                    let occupied;
                    if (state.mode === 'strict') {
                        occupied = FACES.every(face => opaque(face));
                    } else {
                        const pairOk = (a, b) => {
                            if (!active[a]) return s[b][3] > 8;
                            if (!active[b]) return s[a][3] > 8;
                            return s[a][3] > 8 || s[b][3] > 8;
                        };
                        occupied = pairOk('front', 'back') && pairOk('left', 'right') && pairOk('top', 'bottom');
                    }
                    if (!occupied) continue;

                    // Each direction falls back to its opposite view if that exact pixel is transparent.
                    const colors = {
                        front: s.front[3] > 8 ? s.front : s.back,
                        back: s.back[3] > 8 ? s.back : s.front,
                        left: s.left[3] > 8 ? s.left : s.right,
                        right: s.right[3] > 8 ? s.right : s.left,
                        top: s.top[3] > 8 ? s.top : s.bottom,
                        bottom: s.bottom[3] > 8 ? s.bottom : s.top,
                    };
                    const signature = FACES.map(face => packRGBA(colors[face])).join('|');
                    const key = `${x},${y},${z}`;
                    voxels.set(key, {x, y, z, colors, signature});
                    min[0] = Math.min(min[0], x); min[1] = Math.min(min[1], y); min[2] = Math.min(min[2], z);
                    max[0] = Math.max(max[0], x); max[1] = Math.max(max[1], y); max[2] = Math.max(max[2], z);
                }
            }
        }
        return {voxels, active, missing: [], min, max, empty: false};
    }

    function voxelKey(x, y, z) { return `${x},${y},${z}`; }

    // Greedy merge equal six-face color signatures into larger cuboids.
    function mergeVoxels(hull) {
        const voxels = hull.voxels;
        const visited = new Set();
        const boxes = [];
        const items = Array.from(voxels.values()).sort((a, b) => a.y - b.y || a.z - b.z || a.x - b.x);

        const same = (x, y, z, sig) => {
            const key = voxelKey(x, y, z);
            const v = voxels.get(key);
            return !!v && !visited.has(key) && v.signature === sig;
        };

        items.forEach(v => {
            const startKey = voxelKey(v.x, v.y, v.z);
            if (visited.has(startKey)) return;
            let x1 = v.x;
            while (same(x1 + 1, v.y, v.z, v.signature)) x1++;

            let z1 = v.z;
            outerZ: while (true) {
                const nz = z1 + 1;
                for (let x = v.x; x <= x1; x++) if (!same(x, v.y, nz, v.signature)) break outerZ;
                z1 = nz;
            }

            let y1 = v.y;
            outerY: while (true) {
                const ny = y1 + 1;
                for (let z = v.z; z <= z1; z++) {
                    for (let x = v.x; x <= x1; x++) if (!same(x, ny, z, v.signature)) break outerY;
                }
                y1 = ny;
            }

            for (let y = v.y; y <= y1; y++) for (let z = v.z; z <= z1; z++) for (let x = v.x; x <= x1; x++) {
                visited.add(voxelKey(x, y, z));
            }
            boxes.push({x0: v.x, y0: v.y, z0: v.z, x1, y1, z1, colors: v.colors});
        });
        return boxes;
    }

    function buildAtlas() {
        const atlas = document.createElement('canvas');
        atlas.width = SIZE * FACES.length;
        atlas.height = SIZE * PARTS.length;
        const ctx = atlas.getContext('2d');
        ctx.clearRect(0, 0, atlas.width, atlas.height);
        ctx.imageSmoothingEnabled = false;
        PARTS.forEach((part, row) => {
            FACES.forEach((face, col) => ctx.drawImage(state.stores[part.id][face], col * SIZE, row * SIZE));
        });
        return atlas;
    }

    function buildColorLookup(partId) {
        const partIndex = PARTS.findIndex(p => p.id === partId);
        const lookups = {};
        FACES.forEach((face, faceIndex) => {
            const map = new Map();
            const data = pixelData(state.stores[partId][face]);
            for (let y = 0; y < SIZE; y++) for (let x = 0; x < SIZE; x++) {
                const c = rgbaAt(data, x, y);
                if (c[3] <= 8) continue;
                const key = packRGBA(c);
                if (!map.has(key)) map.set(key, [faceIndex * SIZE + x, partIndex * SIZE + y]);
            }
            lookups[face] = map;
        });
        return lookups;
    }

    function fallbackUV(partId, face, colorKey) {
        const opposite = {front:'back', back:'front', left:'right', right:'left', top:'bottom', bottom:'top'}[face];
        const lookup = buildColorLookup(partId);
        return lookup[face].get(colorKey) || lookup[opposite].get(colorKey) || [FACES.indexOf(face) * SIZE, PARTS.findIndex(p => p.id === partId) * SIZE];
    }

    function removeOldGenerated() {
        const generatedGroups = Group.all.filter(g => g.name === 'KW_GENERATED');
        Cube.all.slice().forEach(cube => {
            if (cube.getAllAncestors().some(g => generatedGroups.includes(g))) cube.remove();
        });
        generatedGroups.slice().forEach(group => group.remove());
        Texture.all.slice().forEach(texture => {
            if (texture.name === 'KW_character_atlas.png') texture.remove();
        });
    }

    function ensureProject() {
        if (state.newProject || !Project) {
            if (typeof newProject === 'function') {
                const target = (typeof Formats !== 'undefined' && Formats.free) ? Formats.free : 'free';
                const ok = newProject(target);
                if (ok === false && !Project) throw new Error('Could not create Generic Model project');
            }
        }
        if (!Project) throw new Error('Open or create a Blockbench project first');
    }

    function createModel() {
        try {
            setStatus('Generating visual hulls...', 'working');
            ensureProject();
            removeOldGenerated();

            const atlas = buildAtlas();
            const atlasW = atlas.width, atlasH = atlas.height;
            Project.texture_width = atlasW;
            Project.texture_height = atlasH;
            const texture = new Texture({
                name: 'KW_character_atlas.png',
                width: atlasW,
                height: atlasH,
                uv_width: atlasW,
                uv_height: atlasH,
                source: atlas.toDataURL('image/png'),
            });
            texture.fromDataURL(atlas.toDataURL('image/png'));
            texture.add(false, true);

            const rootGroup = new Group({name: 'KW_GENERATED', origin: [0, 0, 0]}).init();
            rootGroup.addTo();
            let totalCubes = 0;
            let generatedParts = 0;
            const warnings = [];

            PARTS.forEach(part => {
                const hull = visualHull(part.id);
                if (hull.empty) return;
                if (hull.missing.length) {
                    warnings.push(`${part.label}: draw at least one view in each axis pair (front/back, left/right, top/bottom)`);
                    return;
                }
                if (!hull.voxels.size) return;

                const boxes = mergeVoxels(hull);
                if (boxes.length > 3000) {
                    warnings.push(`${part.label}: ${boxes.length} cuboids is too dense; simplify the drawing or use flatter colors`);
                    return;
                }
                const lookup = buildColorLookup(part.id);
                const group = new Group({name: `KW_${part.label.replace(/ /g, '_')}`, origin: state.anchors[part.id].slice()}).init();
                group.addTo(rootGroup);
                generatedParts++;

                const min = hull.min, max = hull.max;
                const center = [(min[0] + max[0] + 1) / 2, (min[1] + max[1] + 1) / 2, (min[2] + max[2] + 1) / 2];
                const s = state.voxelSize;
                boxes.forEach((box, index) => {
                    const from = [
                        state.anchors[part.id][0] + (box.x0 - center[0]) * s,
                        state.anchors[part.id][1] + (box.y0 - center[1]) * s,
                        state.anchors[part.id][2] + (box.z0 - center[2]) * s,
                    ];
                    const to = [
                        state.anchors[part.id][0] + (box.x1 + 1 - center[0]) * s,
                        state.anchors[part.id][1] + (box.y1 + 1 - center[1]) * s,
                        state.anchors[part.id][2] + (box.z1 + 1 - center[2]) * s,
                    ];
                    const cube = new Cube({
                        name: `${part.id}_${String(index + 1).padStart(3, '0')}`,
                        from,
                        to,
                        origin: state.anchors[part.id].slice(),
                        box_uv: false,
                    }).init();
                    cube.addTo(group);
                    cube.applyTexture(texture, true);
                    FACES.forEach(face => {
                        const colorKey = packRGBA(box.colors[face]);
                        const opposite = {front:'back', back:'front', left:'right', right:'left', top:'bottom', bottom:'top'}[face];
                        const uv = lookup[face].get(colorKey) || lookup[opposite].get(colorKey) || fallbackUV(part.id, face, colorKey);
                        const f = cube.faces[FACE_TO_CUBE[face]];
                        f.uv = [uv[0], uv[1], uv[0] + 1, uv[1] + 1];
                        f.texture = texture.uuid;
                    });
                    totalCubes++;
                });
            });

            texture.select();
            Canvas.updateAll();
            if (!generatedParts) {
                rootGroup.remove();
                throw new Error(warnings[0] || 'Nothing generated. Draw at least one complete part first.');
            }
            const msg = `Generated ${generatedParts} part(s), ${totalCubes} cuboids` + (warnings.length ? ` — ${warnings.join(' | ')}` : '');
            setStatus(msg, warnings.length ? 'warn' : 'ok');
            Blockbench.showQuickMessage(`KW model generated: ${totalCubes} cuboids`, 2500);
        } catch (error) {
            console.error(error);
            setStatus(error.message || String(error), 'error');
            Blockbench.showMessageBox({title: 'KW Character Builder', message: error.message || String(error)});
        }
    }

    function exportAtlas() {
        downloadDataURL('KW_character_atlas.png', buildAtlas().toDataURL('image/png'));
    }

    function dialogHTML() {
        const partTabs = PARTS.map(p => `<button class="kwcb-tab" data-kw-part="${p.id}">${p.label}</button>`).join('');
        const faceTabs = FACES.map(f => `<button class="kwcb-tab face" data-kw-face="${f}">${FACE_LABELS[f]}</button>`).join('');
        return `
<style>
#kwcb_root{font-family:Arial,sans-serif;color:var(--color-text);min-height:650px;display:flex;flex-direction:column;gap:8px;user-select:none}
#kwcb_root .row{display:flex;gap:6px;align-items:center;flex-wrap:wrap}
#kwcb_root .kwcb-tab,#kwcb_root .tool,#kwcb_root .action{border:1px solid #317997;background:#152c3b;color:#dff8ff;padding:6px 9px;border-radius:3px;cursor:pointer;font-weight:700;font-size:12px}
#kwcb_root .kwcb-tab.active,#kwcb_root .tool.active{background:#106d86;border-color:#5ef0ff;box-shadow:0 0 8px #18d5ff77;color:white}
#kwcb_root .face{font-size:11px;padding:5px 8px}
#kwcb_root .action.primary{background:#6b164a;border-color:#ff48bb;box-shadow:0 0 8px #ff2a9a66}
#kwcb_root .action.generate{background:#0b6c73;border-color:#54faff;box-shadow:0 0 10px #26dff777;font-size:14px;padding:8px 14px}
#kwcb_workspace{display:grid;grid-template-columns:minmax(430px,1fr) 240px;gap:12px;min-height:520px}
#kwcb_canvas_wrap{display:flex;align-items:center;justify-content:center;min-height:520px;border:1px solid #2b6179;border-radius:5px;background-color:#111820;background-image:linear-gradient(45deg,#23303a 25%,transparent 25%),linear-gradient(-45deg,#23303a 25%,transparent 25%),linear-gradient(45deg,transparent 75%,#23303a 75%),linear-gradient(-45deg,transparent 75%,#23303a 75%);background-size:20px 20px;background-position:0 0,0 10px,10px -10px,-10px 0;overflow:hidden}
#kwcb_canvas_stack{position:relative;width:512px;height:512px;max-width:100%;max-height:70vh;aspect-ratio:1/1}
#kwcb_canvas{position:absolute;inset:0;width:100%;height:100%;image-rendering:pixelated;cursor:crosshair;touch-action:none;border:1px solid #67dbea;box-shadow:0 0 18px #00cfff55;background:transparent}
#kwcb_grid{position:absolute;inset:0;pointer-events:none;border:1px solid #8befff55;background-image:linear-gradient(to right,rgba(122,228,255,.16) 1px,transparent 1px),linear-gradient(to bottom,rgba(122,228,255,.16) 1px,transparent 1px);background-size:calc(100% / 64) calc(100% / 64);mix-blend-mode:screen}
#kwcb_side{border:1px solid #2b6179;background:#102331;border-radius:5px;padding:10px;display:flex;flex-direction:column;gap:10px}
#kwcb_side label{font-size:11px;color:#9ed8e8;font-weight:700}
#kwcb_side input[type=number],#kwcb_side select{background:#0b1822;color:#e8faff;border:1px solid #356b80;padding:4px;max-width:85px}
#kwcb_side input[type=color]{width:48px;height:30px;border:0;background:transparent}
#kwcb_status{margin-top:auto;padding:8px;border-left:3px solid #44dcea;background:#0b1922;font-size:11px;white-space:normal}
#kwcb_status[data-kind=error]{border-color:#ff425c;color:#ff9daa}#kwcb_status[data-kind=warn]{border-color:#ffd45a;color:#ffe49b}#kwcb_status[data-kind=ok]{border-color:#54f5b7;color:#b9ffe1}
#kwcb_root .mini{font-size:10px;color:#86afbe;line-height:1.35}
#kwcb_root .sep{height:1px;background:#28546a;width:100%}
</style>
<div id="kwcb_root">
  <div class="row">${partTabs}</div>
  <div class="row">${faceTabs}</div>
  <div class="row">
    <button class="tool active" data-kw-tool="brush">BRUSH</button>
    <button class="tool" data-kw-tool="eraser">ERASER</button>
    <button class="tool" data-kw-tool="picker">PICKER</button>
    <label>COLOR <input id="kwcb_color" type="color" value="#8f1d27"></label>
    <label>SIZE <select id="kwcb_brush"><option>1</option><option>2</option><option>4</option></select></label>
    <button class="action" id="kwcb_flip_h">FLIP H</button>
    <button class="action" id="kwcb_flip_v">FLIP V</button>
    <button class="action" id="kwcb_clear">CLEAR FACE</button>
  </div>
  <div id="kwcb_workspace">
    <div id="kwcb_canvas_wrap"><div id="kwcb_canvas_stack"><canvas id="kwcb_canvas" width="64" height="64"></canvas><div id="kwcb_grid"></div></div></div>
    <div id="kwcb_side">
      <div><b>PNG / ALPHA</b><div class="mini">Transparent pixels define empty 3D space. RGB colors are preserved on generated surfaces.</div></div>
      <button class="action" id="kwcb_import">IMPORT PNG TO FACE</button><input id="kwcb_import_file" type="file" accept="image/png" hidden>
      <button class="action" id="kwcb_export_face">EXPORT FACE PNG</button>
      <label><input id="kwcb_white_alpha" type="checkbox" checked> Treat near-white as transparent on PNG import</label>
      <div class="sep"></div>
      <div><b>PART POSITION</b></div>
      <div class="row"><label>X <input data-anchor="x" type="number" step="0.5"></label><label>Y <input data-anchor="y" type="number" step="0.5"></label><label>Z <input data-anchor="z" type="number" step="0.5"></label></div>
      <label>VOXEL SIZE <input id="kwcb_voxel_size" type="number" min="0.1" max="4" step="0.1" value="1"></label>
      <label>RECONSTRUCTION <select id="kwcb_mode"><option value="forgiving">FORGIVING</option><option value="strict">STRICT</option></select></label>
      <div class="mini">Forgiving tolerates small differences between opposite hand-drawn views. Strict intersects every painted silhouette.</div>
      <label><input id="kwcb_new_project" type="checkbox" checked> Generate in a new Generic Model project</label>
      <div class="sep"></div>
      <button class="action" id="kwcb_save">SAVE .KWSKIN.JSON</button>
      <button class="action" id="kwcb_load">LOAD .KWSKIN.JSON</button><input id="kwcb_load_file" type="file" accept="application/json,.json" hidden>
      <button class="action" id="kwcb_atlas">EXPORT PNG ATLAS</button>
      <button class="action generate" id="kwcb_generate">GENERATE 3D</button>
      <div id="kwcb_status">Ready. Draw at least one view in each axis pair: front/back, left/right, top/bottom.</div>
    </div>
  </div>
</div>`;
    }

    function wireDialog() {
        const root = document.getElementById('kwcb_root');
        if (!root) return;
        editorCanvas = document.getElementById('kwcb_canvas');
        editorCtx = editorCanvas.getContext('2d', {willReadFrequently: true});
        editorCtx.imageSmoothingEnabled = false;

        root.querySelectorAll('[data-kw-part]').forEach(button => button.addEventListener('click', () => {
            state.part = button.dataset.kwPart;
            renderEditor();
        }));
        root.querySelectorAll('[data-kw-face]').forEach(button => button.addEventListener('click', () => {
            state.face = button.dataset.kwFace;
            renderEditor();
        }));
        root.querySelectorAll('[data-kw-tool]').forEach(button => button.addEventListener('click', () => {
            state.tool = button.dataset.kwTool;
            refreshTabState();
        }));

        editorCanvas.addEventListener('pointerdown', pointerDown);
        editorCanvas.addEventListener('pointermove', pointerMove);
        editorCanvas.addEventListener('pointerup', pointerUp);
        editorCanvas.addEventListener('pointercancel', pointerUp);
        editorCanvas.addEventListener('contextmenu', e => e.preventDefault());

        document.getElementById('kwcb_color').addEventListener('input', e => state.color = e.target.value);
        document.getElementById('kwcb_brush').addEventListener('change', e => state.brushSize = Number(e.target.value));
        document.getElementById('kwcb_clear').addEventListener('click', clearCurrentFace);
        document.getElementById('kwcb_flip_h').addEventListener('click', () => flipCurrent(true));
        document.getElementById('kwcb_flip_v').addEventListener('click', () => flipCurrent(false));
        document.getElementById('kwcb_export_face').addEventListener('click', exportCurrentFace);
        document.getElementById('kwcb_import').addEventListener('click', () => document.getElementById('kwcb_import_file').click());
        document.getElementById('kwcb_import_file').addEventListener('change', e => { importCurrentFace(e.target.files[0]); e.target.value = ''; });
        document.getElementById('kwcb_white_alpha').addEventListener('change', e => state.whiteToAlpha = e.target.checked);
        document.getElementById('kwcb_voxel_size').addEventListener('change', e => state.voxelSize = Math.max(0.1, Number(e.target.value) || 1));
        document.getElementById('kwcb_mode').addEventListener('change', e => state.mode = e.target.value);
        document.getElementById('kwcb_new_project').addEventListener('change', e => state.newProject = e.target.checked);
        root.querySelectorAll('[data-anchor]').forEach(input => input.addEventListener('change', e => {
            const axis = {x:0, y:1, z:2}[input.dataset.anchor];
            state.anchors[state.part][axis] = Number(e.target.value) || 0;
        }));
        document.getElementById('kwcb_save').addEventListener('click', saveKWProject);
        document.getElementById('kwcb_load').addEventListener('click', () => document.getElementById('kwcb_load_file').click());
        document.getElementById('kwcb_load_file').addEventListener('change', e => { loadKWProject(e.target.files[0]); e.target.value = ''; });
        document.getElementById('kwcb_atlas').addEventListener('click', exportAtlas);
        document.getElementById('kwcb_generate').addEventListener('click', createModel);

        renderEditor();
    }

    function openEditor() {
        if (editorDialog) editorDialog.hide();
        editorDialog = new Dialog({
            id: 'kw_character_builder_dialog',
            title: 'KW Character Builder — 6 View Pixel → 3D',
            width: 1000,
            lines: [dialogHTML()],
            buttons: ['Close'],
            singleButton: true,
        });
        editorDialog.show();
        setTimeout(wireDialog, 0);
    }

    initState();

    // Tiny public bridge for future local automation / Godot tooling and QA.
    window.KWCharacterBuilder = {
        open: openEditor,
        generate: createModel,
        setFaceDataURL,
        setPartAnchor(partId, anchor) {
            if (!state.anchors[partId] || !Array.isArray(anchor) || anchor.length < 3) return false;
            state.anchors[partId] = anchor.slice(0, 3).map(Number);
            if (state.part === partId) refreshAnchorInputs();
            return true;
        },
        setMode(mode) { state.mode = mode === 'strict' ? 'strict' : 'forgiving'; },
        getState() {
            return {
                part: state.part,
                face: state.face,
                voxelSize: state.voxelSize,
                mode: state.mode,
                anchors: JSON.parse(JSON.stringify(state.anchors)),
            };
        },
    };

    Plugin.register(PLUGIN_ID, {
        title: 'KW Character Builder',
        author: 'Marios Rafail / OpenAI',
        description: 'Paint six 64×64 orthographic pixel views per KW body part and generate a colored voxel/cuboid 3D model directly in Blockbench.',
        icon: 'view_in_ar',
        version: '0.1.0',
        variant: 'both',
        min_version: '4.8.0',
        tags: ['Utility'],
        onload() {
            openAction = new Action('open_kw_character_builder', {
                name: 'KW Character Builder',
                description: 'Paint 6-view pixel art and generate a KW 3D model',
                icon: 'view_in_ar',
                click: openEditor,
            });
            MenuBar.menus.tools.addAction(openAction);
        },
        onunload() {
            if (openAction) openAction.delete();
            if (editorDialog) editorDialog.delete();
            delete window.KWCharacterBuilder;
            openAction = null;
            editorDialog = null;
        },
    });
})();
