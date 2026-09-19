"""Start the local KW proof without changing the main project, firewall or remote hosting."""
from __future__ import annotations
import argparse, datetime, json, pathlib, subprocess, sys, time
ROOT=pathlib.Path(__file__).absolute().parents[2]
SCENE='res://scenes/prototypes/kw_3d_multiplayer.tscn'
DEFAULT_GODOT=r'C:\Program Files (x86)\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe'

def main() -> None:
    parser=argparse.ArgumentParser()
    parser.add_argument('--godot',default=DEFAULT_GODOT)
    parser.add_argument('--clients',type=int,choices=[0,1,2],default=1)
    parser.add_argument('--port',type=int,default=18886)
    parser.add_argument('--lan',action='store_true',help='Explicit trusted-LAN binding; does not alter firewall rules.')
    args=parser.parse_args()
    if not pathlib.Path(args.godot).is_file():raise SystemExit('Godot executable not found; specify --godot.')
    if not 1024<=args.port<=65535:raise SystemExit('Use a port between 1024 and 65535.')
    stamp=datetime.datetime.now().strftime('%Y%m%d_%H%M%S')
    out=ROOT/'tmp/kw3d'/('online_play_'+stamp);out.mkdir(parents=True)
    common=[args.godot,'--path',str(ROOT)]
    bind='0.0.0.0' if args.lan else '127.0.0.1'
    server=subprocess.Popen(common+['--headless','--log-file',str(out/'server.log'),SCENE,'--','--kw-server','--kw-port='+str(args.port),'--kw-bind='+bind,'--kw-idle-exit=120'],cwd=ROOT,stdin=subprocess.DEVNULL,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    deadline=time.monotonic()+12
    while True:
        if server.poll() is not None:raise SystemExit('Server stopped. Port may already be occupied. Check '+str(out/'server.log'))
        if (out/'server.log').exists() and 'KW_ONLINE_SERVER_READY' in (out/'server.log').read_text(encoding='utf-8',errors='replace'):break
        if time.monotonic()>deadline:server.terminate();raise SystemExit('Server did not become ready; see its log.')
        time.sleep(0.1)
    pids=[server.pid]
    for role in range(1,args.clients+1):
        resolution='960x540' if args.clients==2 else '1280x720'
        position='10,80' if role==1 else '500,240'
        client=subprocess.Popen(common+['--rendering-method','gl_compatibility','--resolution',resolution,'--position',position,'--log-file',str(out/('client_'+str(role)+'.log')),SCENE,'--','--kw-connect','--kw-host=127.0.0.1','--kw-port='+str(args.port),'--kw-profile=player'+str(role),'--kw-name=Player'+str(role)],cwd=ROOT,stdin=subprocess.DEVNULL,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
        pids.append(client.pid);time.sleep(0.4)
    manifest={'created':stamp,'pids':pids,'server_pid':server.pid,'bind':bind,'port':args.port,'scene':SCENE,'logs':str(out),'automatic_idle_shutdown_seconds':120}
    (out/'processes.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
    (ROOT/'tmp/kw3d/latest_online_play.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
    print('KW 3D online session started. Logs:',out)
    print('Close each game window to leave. The server stops after two minutes without clients.')
    if args.lan:print('LAN host enabled explicitly. Other devices need this PC LAN IP and port',args.port)
if __name__=='__main__':main()
