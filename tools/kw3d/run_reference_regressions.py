"""Re-run the preserved solo QA alongside the new server/input unit checks."""
from __future__ import annotations
import argparse,json,pathlib,subprocess,sys
ROOT=pathlib.Path(__file__).absolute().parents[2]
TESTS=['test_online_foundation','test_online_ui','test_sound_pressure','test_grenade_audio_ink','test_aim_polish','test_weapon_side','test_pixel_pass','test_waves','test_wave_live','test_combat_polish','test_fullbody','test_locomotion','test_locomotion_terrain','test_roaming_range']
def main() -> None:
    p=argparse.ArgumentParser();p.add_argument('--output',required=True);p.add_argument('--godot',required=True);a=p.parse_args()
    out=pathlib.Path(a.output);out.mkdir(parents=True,exist_ok=True);results=[]
    for test in TESTS:
        cmd=[a.godot,'--path',str(ROOT)]
        cmd+=['--headless'] if test=='test_online_foundation' else ['--rendering-method','gl_compatibility','--resolution','1280x720']
        cmd+=['--script','res://tools/kw3d/'+test+'.gd','--','--kw-qa','--qa-output='+str(out)]
        with (out/(test+'.log')).open('w',encoding='utf-8') as log:
            process=subprocess.Popen(cmd,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT)
            try:exit_code=process.wait(timeout=90)
            except subprocess.TimeoutExpired:process.terminate();process.wait();exit_code=-1
        text=(out/(test+'.log')).read_text(encoding='utf-8',errors='replace')
        errors=[line for line in text.splitlines() if 'ERROR:' in line or 'FAIL' in line]
        passed=exit_code==0 and not errors and 'PASS' in text
        results.append({'test':test,'passed':passed,'exit_code':exit_code,'errors':errors})
        print(test,'PASS' if passed else 'FAIL',flush=True)
    (out/'regression_results.json').write_text(json.dumps(results,indent=2),encoding='utf-8')
    sys.exit(0 if all(r['passed'] for r in results) else 1)
if __name__=='__main__':main()
