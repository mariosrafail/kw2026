"""Real UDP delay/jitter/loss on localhost only. No packet payloads or credentials logged."""
from __future__ import annotations
import argparse, heapq, json, random, select, socket, time
from pathlib import Path

def main() -> None:
    parser=argparse.ArgumentParser()
    parser.add_argument('--ports',default='18891,18892');parser.add_argument('--target-port',type=int,default=18886)
    parser.add_argument('--delay-ms',type=float,default=50);parser.add_argument('--jitter-ms',type=float,default=10)
    parser.add_argument('--loss',type=float,default=0.02);parser.add_argument('--duration',type=float,default=36)
    parser.add_argument('--report',required=True);args=parser.parse_args()
    assert 0<=args.loss<=0.1 and 0<=args.delay_ms<=500 and 0<=args.jitter_ms<=100
    rng=random.Random(913731);sockets=[];fronts={};backs={};channels={};queue=[];serial=0
    metrics={'packets_in':0,'packets_out':0,'dropped':0,'bytes':0,'peak_queue':0,'configured_one_way_ms':args.delay_ms,'configured_jitter_ms':args.jitter_ms,'configured_loss':args.loss}
    for port in map(int,args.ports.split(',')):
        s=socket.socket(socket.AF_INET,socket.SOCK_DGRAM);s.bind(('127.0.0.1',port));s.setblocking(False);sockets.append(s);fronts[s]=port
    print('UDP_FAULT_PROXY_READY',args.ports,flush=True)
    started=time.monotonic();next_notice=started+8
    try:
        while time.monotonic()-started<args.duration:
            now=time.monotonic()
            if now>=next_notice:
                print('PROXY_PROGRESS',metrics['packets_in'],metrics['packets_out'],metrics['dropped'],flush=True);next_notice=now+8
            for _ in range(512):
                if not queue or queue[0][0]>time.monotonic():break
                _,_,sender,destination,payload=heapq.heappop(queue)
                try:sender.sendto(payload,destination);metrics['packets_out']+=1
                except OSError:metrics['dropped']+=1
            readable,_,_=select.select(sockets,[],[],0.002)
            for current in readable:
                try:data,addr=current.recvfrom(65536)
                except (BlockingIOError,ConnectionResetError):continue
                metrics['packets_in']+=1;metrics['bytes']+=len(data)
                if len(data)>4096 or rng.random()<args.loss or len(queue)>=4096:
                    metrics['dropped']+=1;continue
                if current in fronts:
                    key=(fronts[current],addr)
                    if key not in channels:
                        if len(channels)>=16:metrics['dropped']+=1;continue
                        up=socket.socket(socket.AF_INET,socket.SOCK_DGRAM);up.bind(('127.0.0.1',0));up.setblocking(False)
                        channels[key]=up;backs[up]=(current,addr);sockets.append(up)
                    sender=channels[key];destination=('127.0.0.1',args.target_port)
                else:
                    if addr!=('127.0.0.1',args.target_port):metrics['dropped']+=1;continue
                    sender,destination=backs[current]
                serial+=1
                due=time.monotonic()+max(0,args.delay_ms+rng.uniform(-args.jitter_ms,args.jitter_ms))/1000
                heapq.heappush(queue,(due,serial,sender,destination,data))
                metrics['peak_queue']=max(metrics['peak_queue'],len(queue))
    finally:
        for s in sockets:s.close()
        Path(args.report).write_text(json.dumps(metrics,indent=2),encoding='utf-8')
        print('UDP_FAULT_PROXY_DONE',json.dumps(metrics),flush=True)
if __name__=='__main__':main()
