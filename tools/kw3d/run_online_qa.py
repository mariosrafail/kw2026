"""Launch one real headless Godot authority plus two real clients. No external hosting."""
from __future__ import annotations
import argparse, json, pathlib, subprocess, sys, time
ROOT=pathlib.Path(__file__).absolute().parents[2]
SCENE='res://scenes/prototypes/kw_3d_multiplayer.tscn'
DEFAULT_GODOT=r'C:\Program Files (x86)\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe'

def run_case(godot: str, output: pathlib.Path, delay: float, jitter: float, loss: float) -> dict:
    output.mkdir(parents=True,exist_ok=True); processes=[]; handles=[]; failures=[]
    def start(name: str, command: list[str]) -> subprocess.Popen:
        log=(output/(name+'.log')).open('w',encoding='utf-8');handles.append(log)
        p=subprocess.Popen(command,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT);processes.append(p);return p
    engine=[godot,'--path',str(ROOT)]
    try:
        proxy=None
        if delay or loss:
            proxy=start('udp_proxy',[sys.executable,'-I','-S','-u',str(ROOT/'tools/kw3d/udp_fault_proxy.py'),'--delay-ms',str(delay),'--jitter-ms',str(jitter),'--loss',str(loss),'--duration','42','--report',str(output/'proxy.json')])
        if proxy:
            deadline=time.monotonic()+120
            while 'UDP_FAULT_PROXY_READY' not in (output/'udp_proxy.log').read_text(encoding='utf-8',errors='replace'):
                if proxy.poll() is not None:raise RuntimeError('Proxy failed before READY')
                if time.monotonic()>deadline:raise TimeoutError('Proxy startup')
                time.sleep(0.1)
        server=start('server',engine+['--headless',SCENE,'--','--kw-server','--kw-port=18886','--kw-duration=30','--kw-qa-fixture','--kw-report='+str(output/'server.json'),'--kw-qa'])
        time.sleep(0.7)
        if proxy and proxy.poll() is not None:raise RuntimeError("UDP fault proxy exited before clients started")
        clients=[]
        for role in [1,2]:
            port=(18890+role) if proxy else 18886
            clients.append(start('client_'+str(role),engine+['--rendering-method','gl_compatibility','--resolution','800x450','--position',('10,100' if role==1 else '820,100'),SCENE,'--','--kw-connect','--kw-host=127.0.0.1','--kw-port='+str(port),'--kw-qa-client='+str(role),'--kw-profile=qa'+str(role),'--kw-output='+str(output),'--kw-test-seconds=20','--kw-qa']))
        for i,p in enumerate(clients,1):
            if p.wait(timeout=65)!=0:failures.append('client_exit_'+str(i))
        if server.wait(timeout=30)!=0:failures.append('server_exit')
        if proxy and proxy.wait(timeout=35)!=0:failures.append('proxy_exit')
    except Exception as exc: failures.append(type(exc).__name__+': '+str(exc))
    finally:
        for p in processes:
            if p.poll() is None:p.terminate()
        for p in processes:
            try:p.wait(timeout=3)
            except subprocess.TimeoutExpired:p.kill();p.wait()
        for h in handles:h.close()
    for path in output.glob('*.log'):
        text=path.read_text(encoding='utf-8',errors='replace')
        if any(marker in text for marker in ['SCRIPT ERROR:','ERROR:','WARNING: Sending','Parse Error:']):failures.append('log_errors_'+path.name)
    results=[]
    try:
        server=json.loads((output/'server.json').read_text(encoding='utf-8'))
        results=[json.loads((output/('client_'+str(i)+'.json')).read_text(encoding='utf-8')) for i in [1,2]]
        players={str(a['id']):a for a in server['actors'] if not a['bot']}
        if len(players)!=2:failures.append('duplicated_or_missing_player')
        for i,result in enumerate(results,1):
            failures+=['client_'+str(i)+'_'+x for x in result['failures']]
            for pid,actor in players.items():
                remote=result['actors'].get(pid,{})
                for key in ['hp','kills','gcd']:
                    if remote.get(key)!=actor[key]:failures.append('state_mismatch_'+str(i)+'_'+pid+'_'+key)
            if result['steady_max_correction']>0.55:failures.append('large_prediction_correction_'+str(i))
        if server['grenade_events']!=2:failures.append('grenade_duplicate_or_lost')
        if server['kill_events']<1 or server['kill_events']!=sum(p['kills'] for p in players.values()):failures.append('kill_inconsistency')
        if server['rejected_inputs']<6:failures.append('malformed_inputs_not_rejected')
        if server['has_camera']:failures.append('server_has_camera')
        if delay and any(r['rtt_ms']<delay for r in results):failures.append('fault_proxy_not_in_path')
    except Exception as exc:failures.append('result_read: '+str(exc));server={}
    report={'failures':failures,'configured_rtt_ms':delay*2,'jitter_per_leg_ms':jitter,'loss':loss,'clients':results,'server_metrics':server.get('metrics',{}),'server_damage_events':server.get('damage_events'),'server_kills':server.get('kill_events'),'server_grenades':server.get('grenade_events'),'server_rejected':server.get('rejected_inputs')}
    (output/'integration_results.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    print('NETWORK_CASE',output.name,'PASS' if not failures else 'FAIL',json.dumps(failures),flush=True)
    return report

def main() -> None:
    parser=argparse.ArgumentParser();parser.add_argument('--godot',default=DEFAULT_GODOT);parser.add_argument('--output',required=True)
    parser.add_argument('--delay-ms',type=float,default=0);parser.add_argument('--jitter-ms',type=float,default=0);parser.add_argument('--loss',type=float,default=0)
    args=parser.parse_args();report=run_case(args.godot,pathlib.Path(args.output),args.delay_ms,args.jitter_ms,args.loss)
    sys.exit(1 if report['failures'] else 0)
if __name__=='__main__':main()
