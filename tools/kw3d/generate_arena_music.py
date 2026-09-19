# Original KW arena loop: 128 BPM, 32 bars, 60 seconds. No third-party samples.
from pathlib import Path
import json, wave, numpy as np
ROOT=Path(__file__).resolve().parents[2]
SR=32000; BPM=128; BEAT=60/BPM; SECONDS=32*4*BEAT; N=round(SECONDS*SR)
rng=np.random.default_rng(20260919)
mix=np.zeros((N,2),dtype=np.float64)
def add(sound,beat,level=1.0,pan=0.0):
    start=round(beat*BEAT*SR); ids=(start+np.arange(len(sound)))%N
    l=np.sqrt((1-pan)*.5); r=np.sqrt((1+pan)*.5)
    mix[ids,0]+=sound*level*l;mix[ids,1]+=sound*level*r

def tone(midi,duration,kind='pluck'):
    t=np.arange(round(duration*SR))/SR; f=440*2**((midi-69)/12)
    if kind=='bass':
        wave=np.sin(2*np.pi*f*t)+.22*np.sin(4*np.pi*f*t)+.08*np.sin(6*np.pi*f*t)
        env=np.minimum(1,t/.006)*np.exp(-t*6)*np.minimum(1,(duration-t)/.045)
    elif kind=='pad':
        wave=np.sin(2*np.pi*f*t)+.13*np.sin(2*np.pi*f*1.003*t)
        env=np.minimum(1,t/.10)*np.minimum(1,(duration-t)/.24)*.45
    else:
        wave=sum(np.sin(2*np.pi*f*k*t)/k**1.8 for k in [1,2,3,4,6])
        env=np.minimum(1,t/.003)*np.exp(-t*13)*np.minimum(1,(duration-t)/.025)
    return wave*env

def drum(kind):
    duration={'kick':.3,'snare':.20,'hat':.065}[kind]
    t=np.arange(round(duration*SR))/SR
    noise=rng.normal(0,1,len(t)); high=noise-np.convolve(noise,np.ones(9)/9,mode='same')
    if kind=='kick':
        phase=2*np.pi*(48*t+90*.022*(1-np.exp(-t/.022)))
        v=np.sin(phase)*np.exp(-t*16)+high*np.exp(-t*180)*.05
    elif kind=='snare':
        v=high*.23*np.exp(-t*25)+np.sin(2*np.pi*182*t)*.22*np.exp(-t*36)
    else: v=high*.10*np.exp(-t*70)
    return v*np.minimum(1,t/.001)*np.minimum(1,(duration-t)/.01)
chords=[(41,[53,56,60]),(37,[49,53,56]),(44,[56,60,63]),(39,[51,55,58])]
for bar in range(32):
    beat=bar*4; root,chord=chords[(bar//2)%4]; section=bar//8
    for hit in range(4): add(drum('kick'),beat+hit,.80 if section!=2 else .58)
    for hit in [1,3]: add(drum('snare'),beat+hit,.75)
    for hit in np.arange(.5,4,.5): add(drum('hat'),beat+hit,.75 if hit%1 else .42,(-1 if int(hit*2)%2 else 1)*.22)
    for j,hit in enumerate([0,.75,1.5,2,2.75,3.5]):
        add(tone(root+(12 if j==4 and bar%2 else 0),.30,'bass'),beat+hit,.38)
    for j,note in enumerate(chord): add(tone(note,BEAT*3.9,'pad'),beat,.065,(j-1)*.5)
    if section!=2 or bar%2:
        pattern=[0,2,1,2,0,1,2,1]
        for j,hit in enumerate([.25,.75,1.25,1.75,2.25,2.75,3.25,3.75]):
            note=chord[pattern[(j+bar%2)%8]]+12+(12 if j==6 and section==3 else 0)
            pluck=tone(note,.38)
            add(pluck,beat+hit,.13 if section==0 else .17,(-1 if j%2 else 1)*.35)
            add(pluck,beat+hit+.75,.028,(-1 if j%2 else 1)*-.6)
    if bar%8==7:
        for hit in [3.25,3.5,3.75]: add(drum('snare'),beat+hit,.20)
mix-=np.mean(mix,axis=0)
mix=np.tanh(mix*1.35)
mix*=.78/np.max(np.abs(mix))
pcm=(mix*32767).astype('<i2')
out=ROOT/'assets/prototypes/audio';out.mkdir(parents=True,exist_ok=True)
path=out/'kw_neon_riot_loop.wav'
with wave.open(str(path),'wb') as f:
    f.setnchannels(2);f.setsampwidth(2);f.setframerate(SR);f.writeframes(pcm.tobytes())
meta={'title':'KW Neon Riot','bpm':BPM,'bars':32,'seconds':SECONDS,'sample_rate':SR,'peak':float(np.max(np.abs(mix))),'rms':float(np.sqrt(np.mean(mix**2))),'loop_boundary_delta':float(np.max(np.abs(mix[0]-mix[-1]))),'source':'Original deterministic synthesis; no external samples.'}
(out/'kw_neon_riot_loop.json').write_text(json.dumps(meta,indent=2))
print('ORIGINAL_SOUNDTRACK_READY',meta)
