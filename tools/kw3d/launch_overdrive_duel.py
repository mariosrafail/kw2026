"""Start a local KW Overdrive Duel server plus two visible clients."""
from __future__ import annotations
import datetime, json, pathlib, subprocess, time

ROOT=pathlib.Path(__file__).absolute().parents[2]
SCENE='res://scenes/prototypes/kw_3d_lan_duel.tscn'
DEFAULT_GODOT=r'C:\Program Files (x86)\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe'
PORT=18896

def main() -> None:
    godot=DEFAULT_GODOT
    if not pathlib.Path(godot).is_file():
        raise SystemExit('Godot executable not found: '+godot)
    stamp=datetime.datetime.now().strftime('%Y%m%d_%H%M%S')
    out=ROOT/'tmp/kw3d'/('overdrive_duel_'+stamp)
    out.mkdir(parents=True)
    common=[godot,'--path',str(ROOT)]
    server=subprocess.Popen(
        common+['--headless','--log-file',str(out/'server.log'),SCENE,'--',
                '--kw-server','--kw-port='+str(PORT),'--kw-bind=127.0.0.1','--kw-idle-exit=120'],
        cwd=ROOT,stdin=subprocess.DEVNULL,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    deadline=time.monotonic()+15
    while True:
        if server.poll() is not None:
            raise SystemExit('Overdrive server stopped; check '+str(out/'server.log'))
        if (out/'server.log').exists() and 'KW_ONLINE_SERVER_READY' in (out/'server.log').read_text(encoding='utf-8',errors='replace'):
            break
        if time.monotonic()>deadline:
            server.terminate()
            raise SystemExit('Overdrive server did not become ready; see '+str(out/'server.log'))
        time.sleep(0.1)
    pids=[server.pid]
    for role,position in ((1,'20,80'),(2,'520,180')):
        client=subprocess.Popen(
            common+['--rendering-method','gl_compatibility','--resolution','960x540',
                    '--position',position,'--log-file',str(out/f'client_{role}.log'),SCENE,'--',
                    '--kw-connect','--kw-host=127.0.0.1','--kw-port='+str(PORT),
                    '--kw-profile=overdrive'+str(role),'--kw-name='+('Outrage' if role==1 else 'Erebus')],
            cwd=ROOT,stdin=subprocess.DEVNULL,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
        pids.append(client.pid)
        time.sleep(0.5)
    manifest={'created':stamp,'pids':pids,'server_pid':server.pid,'port':PORT,
              'scene':SCENE,'mode':'Overdrive Duel','logs':str(out)}
    (out/'processes.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
    (ROOT/'tmp/kw3d/latest_overdrive_duel.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
    print('KW OVERDRIVE DUEL started. Logs:',out)
    print('Ready both players; the host then presses START MATCH.')
if __name__=='__main__':
    main()
