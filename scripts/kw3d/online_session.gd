extends Node
## Trusted-LAN proof. Resume credentials are memory-only; not production identity/authentication.
signal welcomed(data: Dictionary)
signal state_received(data: Dictionary)
signal combat_event(data: Dictionary)
signal connection_message(text: String)
const LEVEL=preload("res://scripts/kw3d/online_level.gd")
const CODEC=preload("res://scripts/kw3d/input_codec.gd")
const PROTOCOL=6
const BUILD="kw3d-proof-20260925-compact-snapshots-v6"
const MAX_PLAYERS=4
const SNAPSHOT_FORMAT=2
const SNAPSHOT_COMPRESSION=FileAccess.COMPRESSION_FASTLZ
var server=false
var world: Node3D
var actor_id=0
var token=""
var current_match=""
var connected=false
var connection_state="Disconnected"
var peer_slots: Dictionary={}
var sessions: Dictionary={}
var pending_peers: Dictionary={}
var counters: Dictionary={}
var next_slot=1
var rejected_inputs=0
var snapshot_count=0
var accepted_inputs=0
var last_snapshot_tick=-1
var last_event=0
var server_host="127.0.0.1"
var server_port=18886
var nickname="Player"
var appearance="outrage"
var elapsed=0.0
var connect_started=0.0
var ping_elapsed=0.0
var rtt_ms=0.0
var assembling: Dictionary={}
var max_snapshot_bytes=0
var transport_mode="enet"

func _ready() -> void:
	name="Session"
	multiplayer.allow_object_decoding=false
	multiplayer.server_relay=false
	multiplayer.peer_connected.connect(_peer_connected)
	multiplayer.peer_disconnected.connect(_peer_disconnected)
	multiplayer.connected_to_server.connect(_connected)
	multiplayer.connection_failed.connect(func():_lost("Connection failed. Check server address/port."))
	multiplayer.server_disconnected.connect(func():_lost("Server disconnected. Reconnect within 30 seconds to retain your actor."))

func _can_send(peer_id: int) -> bool:
	if multiplayer.multiplayer_peer == null:return false
	if not multiplayer.get_peers().has(peer_id):return false
	if multiplayer.multiplayer_peer is ENetMultiplayerPeer:
		var packet_peer: ENetPacketPeer=multiplayer.multiplayer_peer.get_peer(peer_id)
		return packet_peer!=null and packet_peer.get_state()==ENetPacketPeer.STATE_CONNECTED and packet_peer.get_channels()>3
	if multiplayer.multiplayer_peer is WebSocketMultiplayerPeer:
		var ws_transport := multiplayer.multiplayer_peer as WebSocketMultiplayerPeer
		var ws_peer: WebSocketPeer = ws_transport.get_peer(peer_id)
		return ws_peer != null and ws_peer.get_ready_state() == WebSocketPeer.STATE_OPEN
	return false

func start_server(authority: Node3D,port: int,bind: String="127.0.0.1",transport: String="enet") -> Error:
	server=true;world=authority;server_port=port
	transport_mode=transport.strip_edges().to_lower()
	var error: Error=OK
	if transport_mode in ["websocket","ws","wss"]:
		transport_mode="websocket"
		var peer:=WebSocketMultiplayerPeer.new()
		error=peer.create_server(port,"*")
		if error==OK:multiplayer.multiplayer_peer=peer
	else:
		transport_mode="enet"
		var peer:=ENetMultiplayerPeer.new();peer.set_bind_ip(bind)
		error=peer.create_server(port,MAX_PLAYERS+4,3)
		if error==OK:multiplayer.multiplayer_peer=peer
	if error!=OK:
		connection_message.emit("Server port unavailable: "+str(error))
		return error
	world.event_created.connect(_broadcast_event)
	connected=true;connection_state="Server listening"
	print("KW_ONLINE_SERVER_READY port=",port," bind=",bind," transport=",transport_mode," protocol=",PROTOCOL)
	return OK

func join(host: String,port: int,display_name: String="Player",selected_appearance: String="outrage") -> Error:
	if server:return ERR_INVALID_PARAMETER
	close_connection(false)
	server_host=host.strip_edges();server_port=port;nickname=display_name.left(24)
	var normalized_appearance := selected_appearance.strip_edges().to_lower()
	appearance = normalized_appearance if normalized_appearance in ["outrage","erebus","kosas","aevilok","loker"] else "outrage"
	if server_host.is_empty():return ERR_INVALID_PARAMETER
	var error: Error=OK
	if server_host.begins_with("ws://") or server_host.begins_with("wss://"):
		transport_mode="websocket"
		var peer:=WebSocketMultiplayerPeer.new()
		error=peer.create_client(server_host)
		if error==OK:multiplayer.multiplayer_peer=peer
	else:
		if port<1024 or port>65535:return ERR_INVALID_PARAMETER
		transport_mode="enet"
		var peer:=ENetMultiplayerPeer.new()
		error=peer.create_client(server_host,server_port,3)
		if error==OK:multiplayer.multiplayer_peer=peer
	if error!=OK:_lost("Cannot open network connection: "+str(error));return error
	connection_state="Connecting...";connect_started=elapsed;connection_message.emit(connection_state)
	return OK

func close_connection(clear_token: bool=false) -> void:
	assembling.clear();connected=false
	if multiplayer.multiplayer_peer!=null:multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer=OfflineMultiplayerPeer.new()
	if clear_token:token="";actor_id=0;current_match="";last_event=0

func reconnect() -> Error:return join(server_host,server_port,nickname,appearance)
func _connected() -> void:_hello.rpc_id(1,PROTOCOL,BUILD,LEVEL.fingerprint(),token,nickname,appearance)

func _sanitize_display_name(value: String) -> String:
	var source:=value.strip_edges()
	var result:=""
	for i in range(source.length()):
		var c:=source.substr(i,1)
		var code:=c.unicode_at(0)
		if (code>=48 and code<=57) or (code>=65 and code<=90) or (code>=97 and code<=122) or c in ["_","-"]:
			result+=c
		elif c in [" ","."]:
			result+="_"
		if result.length()>=24:break
	return result if result.length()>=3 else "KW_ROOKIE"
func _lost(text: String) -> void:
	if OS.get_cmdline_user_args().has("--kw-qa"):print("NETWORK_STATE ",text)
	connected=false;connection_state=text;connection_message.emit(text)
func _peer_connected(peer: int) -> void:
	if server:
		pending_peers[peer]=elapsed
		if OS.get_cmdline_user_args().has("--kw-qa"):
			if multiplayer.multiplayer_peer is ENetMultiplayerPeer:
				print("TRANSPORT_CONNECTED enet channels=",multiplayer.multiplayer_peer.get_peer(peer).get_channels())
			else:
				print("TRANSPORT_CONNECTED websocket peer=",peer)
func _peer_disconnected(peer: int) -> void:
	if not server:return
	pending_peers.erase(peer)
	if not peer_slots.has(peer):return
	var slot: int=peer_slots[peer];peer_slots.erase(peer);counters.erase(peer)
	world.detach_player(slot)
	for entry in sessions.values():
		if entry.slot==slot:entry.peer=0;entry.expiry=elapsed+30

@rpc("any_peer","call_remote","reliable",0)
func _hello(protocol: int,build: String,manifest: String,resume: String,display_name: String,requested_appearance: String="outrage") -> void:
	if not server:return
	var peer=multiplayer.get_remote_sender_id()
	if peer_slots.has(peer):return
	if protocol!=PROTOCOL or build!=BUILD or manifest!=LEVEL.fingerprint():
		_reject.rpc_id(peer,"Build/map mismatch. Both clients need the same KW proof.");return
	if resume.length()>128 or display_name.length()>32 or requested_appearance.length()>32:_reject.rpc_id(peer,"Invalid handshake.");return
	var normalized_appearance := requested_appearance.strip_edges().to_lower()
	var normalized_name := _sanitize_display_name(display_name)
	if normalized_appearance not in ["outrage","erebus","kosas","aevilok","loker"]:
		normalized_appearance = "outrage"
	var slot=0
	if not resume.is_empty() and sessions.has(resume):
		var entry: Dictionary=sessions[resume]
		if entry.peer!=0:
			# A valid resume secret can reclaim only an idle/stale transport.
			var existing: Node3D=world.actors.get(entry.slot)
			if existing!=null and world.tick_id-existing.last_input_tick<=45:
				_reject.rpc_id(peer,"Previous connection is active. Retry shortly.");return
			var old_peer: int=entry.peer
			peer_slots.erase(old_peer);counters.erase(old_peer)
			if multiplayer.get_peers().has(old_peer):multiplayer.multiplayer_peer.disconnect_peer(old_peer)
			entry.peer=0;entry.expiry=elapsed+30
		if elapsed<=float(entry.expiry) and world.actors.has(entry.slot):slot=entry.slot
		sessions.erase(resume)
	if slot==0:
		var occupied=0
		for a in world.actors.values():
			if not a.is_bot:occupied+=1
		var room_max := int(world.max_players()) if world != null and world.has_method("max_players") else MAX_PLAYERS
		if occupied>=room_max:_reject.rpc_id(peer,"Room full. Reconnect slots are reserved briefly.");return
		slot=next_slot;next_slot+=1
	var key=Crypto.new().generate_random_bytes(24).hex_encode()
	sessions[key]={"slot":slot,"peer":peer,"expiry":0.0}
	peer_slots[peer]=slot;pending_peers.erase(peer)
	counters[peer]={"window":elapsed,"packets":0,"commands":0}
	world.add_player(slot)
	var a: Node3D=world.actors[slot]
	a.display_name=normalized_name
	# Co-op actors share the standard gameplay hitbox profile but may render any
	# selected human warrior. Duel actors own their hero assignment separately.
	if not world.has_method("_hero_for_new_player"):
		a.skin = normalized_appearance
	a.connected=true;a.input_queue.clear();a.input_started=false;a.last_input_tick=world.tick_id
	_accept.rpc_id(peer,{"slot":slot,"token":key,"match":world.match_id,"ack":a.ack,"js":a.last_jump_serial,"gs":a.last_grenade_serial,"state":world.snapshot(),"room":world.room_packet() if world.has_method("room_packet") else {}})
	print("KW_ONLINE_JOIN slot=",slot," actors=",peer_slots.size())

@rpc("authority","call_remote","reliable",0)
func _accept(payload: Dictionary) -> void:
	if server:return
	if payload.match!=current_match:last_event=0
	current_match=payload.match;actor_id=payload.slot;token=payload.token;last_snapshot_tick=-1
	connected=true;connection_state="Connected - player %d"%actor_id
	welcomed.emit(payload);_on_snapshot(payload.state);connection_message.emit(connection_state)

@rpc("authority","call_remote","reliable",0)
func _reject(reason: String) -> void:
	if server:return
	_lost(reason);close_connection(false)

static func valid_frame(f: Dictionary) -> bool:
	if f.size()!=13:return false
	for key in ["seq","ct","js","gs"]:
		if typeof(f.get(key))!=TYPE_INT or f[key]<0 or f[key]>2000000000:return false
	if typeof(f.get("move"))!=TYPE_VECTOR2 or not (f.move as Vector2).is_finite() or f.move.length()>1.001:return false
	for key in ["yaw","pitch","side"]:
		if typeof(f.get(key)) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(f[key])):return false
	if absf(f.yaw)>PI+0.001 or f.pitch < -0.84 or f.pitch>0.53 or f.side not in [-1.0,1.0]:return false
	for key in ["fire","aim","sprint","reload"]:
		if typeof(f.get(key))!=TYPE_BOOL:return false
	if typeof(f.get("weapon"))!=TYPE_INT or int(f.weapon) not in [0,1,2,3]:return false
	return f.seq>0

func send_frames(frames: Array) -> void:
	if connected and not server and _can_send(1):_inputs.rpc_id(1,CODEC.encode_recent(frames,4))

@rpc("any_peer","call_remote","unreliable_ordered",1)
func _inputs(bytes: PackedByteArray) -> void:
	if not server:return
	var frames: Array=CODEC.decode(bytes)
	var peer=multiplayer.get_remote_sender_id()
	if not peer_slots.has(peer) or frames.is_empty() or frames.size()>4:rejected_inputs+=1;return
	var limiter: Dictionary=counters[peer]
	if elapsed-float(limiter.window)>=1:limiter.window=elapsed;limiter.packets=0;limiter.commands=0
	limiter.packets+=1
	if limiter.packets>100:rejected_inputs+=1;return
	var a: Node3D=world.actors[peer_slots[peer]]
	for frame in frames:
		if not frame is Dictionary or not valid_frame(frame):rejected_inputs+=1;continue
		var seq: int=frame.seq
		if seq<=a.ack or a.input_queue.has(seq):continue
		if seq>a.ack+180 or a.input_queue.size()>=120 or limiter.commands>=90:rejected_inputs+=1;continue
		if int(frame.js)>a.last_jump_serial+8 or int(frame.gs)>a.last_grenade_serial+8:rejected_inputs+=1;continue
		limiter.commands+=1;accepted_inputs+=1;a.input_queue[seq]=frame;a.last_input_tick=world.tick_id

@rpc("authority","call_remote","unreliable_ordered",1)
func _on_snapshot(payload: Dictionary) -> void:
	if server or not connected:return
	if payload.get("match","")!=current_match or int(payload.get("tick",-1))<=last_snapshot_tick:return
	last_snapshot_tick=payload.tick;snapshot_count+=1;state_received.emit(payload)

func _broadcast_event(payload: Dictionary) -> void:
	for peer in peer_slots:
		if _can_send(peer):_on_event.rpc_id(peer,payload)

@rpc("authority","call_remote","reliable",2)
func _on_event(payload: Dictionary) -> void:
	if server or not connected or payload.get("match","")!=current_match:return
	var id: int=payload.get("event",0)
	if id<=last_event:return
	last_event=id;combat_event.emit(payload)



func set_ready(value: bool) -> void:
	if connected and not server:
		_set_ready.rpc_id(1,value)

@rpc("any_peer","call_remote","reliable",0)
func _set_ready(value: bool) -> void:
	if not server or world==null or not world.has_method("set_ready"):return
	var peer:=multiplayer.get_remote_sender_id()
	if peer_slots.has(peer):world.set_ready(int(peer_slots[peer]),value)

func request_match_start() -> void:
	if connected and not server:
		_start_match.rpc_id(1)

@rpc("any_peer","call_remote","reliable",0)
func _start_match() -> void:
	if not server or world==null or not world.has_method("start_match"):return
	var peer:=multiplayer.get_remote_sender_id()
	if peer_slots.has(peer):world.start_match(int(peer_slots[peer]))

func request_duel_skill() -> void:
	if connected and not server and _can_send(1):_duel_skill.rpc_id(1)

@rpc("any_peer","call_remote","reliable",0)
func _duel_skill() -> void:
	if not server or world==null or not world.has_method("use_skill"):return
	var peer:=multiplayer.get_remote_sender_id()
	if peer_slots.has(peer):world.use_skill(int(peer_slots[peer]))

func choose_duel_augment(card_id: String) -> void:
	if connected and not server and card_id.length()<=48 and _can_send(1):_duel_augment.rpc_id(1,card_id)

@rpc("any_peer","call_remote","reliable",0)
func _duel_augment(card_id: String) -> void:
	if not server or world==null or not world.has_method("choose_augment") or card_id.length()>48:return
	var peer:=multiplayer.get_remote_sender_id()
	if peer_slots.has(peer):world.choose_augment(int(peer_slots[peer]),card_id)

func request_respawn() -> void:
	if connected and not server and _can_send(1):_respawn.rpc_id(1)

@rpc("any_peer","call_remote","reliable",0)
func _respawn() -> void:
	if not server:return
	var peer=multiplayer.get_remote_sender_id()
	if peer_slots.has(peer):world.respawn(peer_slots[peer])

@rpc("any_peer","call_remote","unreliable",0)
func _ping(value: int) -> void:
	var peer =multiplayer.get_remote_sender_id()
	if server and peer_slots.has(peer) and _can_send(peer):_pong.rpc_id(peer,value)

@rpc("authority","call_remote","unreliable",0)
func _pong(value: int) -> void:
	if not server:rtt_ms=clampf(float(Time.get_ticks_msec()-value),0,5000)

func _physics_process(delta: float) -> void:
	elapsed+=delta
	if server:
		world.step()
		if world.tick_id%3==0:_send_snapshot()
		for key in sessions.keys():
			var entry: Dictionary=sessions[key]
			if entry.peer==0 and elapsed>float(entry.expiry):world.remove_player(entry.slot);sessions.erase(key)
		for peer in pending_peers.keys():
			if elapsed-float(pending_peers[peer])>6:
				if multiplayer.get_peers().has(peer):multiplayer.multiplayer_peer.disconnect_peer(peer)
				pending_peers.erase(peer)
	else:
		if connection_state=="Connecting..." and elapsed-connect_started>8:close_connection();_lost("Connection timed out.")
		if connected:
			ping_elapsed+=delta
			if ping_elapsed>=1 and _can_send(1):ping_elapsed=0;_ping.rpc_id(1,Time.get_ticks_msec())

func _pack_snapshot(state: Dictionary,viewer_id: int) -> Array:
	var actors_packed: Array=[]
	for raw_actor in state.get("actors",[]):
		var actor: Dictionary=raw_actor as Dictionary
		var owner:=int(actor.get("id",0))==viewer_id
		var pose: PackedFloat32Array=PackedFloat32Array() if owner else actor.get("pose",PackedFloat32Array()) as PackedFloat32Array
		var owner_data: Array=[]
		if owner:
			owner_data=[
				int(actor.get("ack",0)),int(actor.get("js",0)),int(actor.get("gs",0)),float(actor.get("respawn_left",0.0)),float(actor.get("skill_cd",0.0)),
				PackedInt32Array([int(actor.get("ak_ammo",25)),int(actor.get("sg_ammo",2)),int(actor.get("kar_ammo",1)),int(actor.get("gl_ammo",1))]),
				PackedFloat32Array([float(actor.get("ak_reload",0.0)),float(actor.get("sg_reload",0.0)),float(actor.get("kar_reload",0.0)),float(actor.get("gl_reload",0.0))])
			]
		var duel_data: Array=[]
		if actor.has("hero"):
			duel_data=[str(actor.get("hero","")),float(actor.get("max_hp",100.0)),int(actor.get("skill_charges",0)),int(actor.get("skill_max",0)),float(actor.get("guard",0.0)),float(actor.get("haste",0.0)),actor.get("augments",[])]
		actors_packed.append([
			int(actor.get("id",0)),bool(actor.get("bot",false)),str(actor.get("skin","outrage")),actor.get("p",Vector3.ZERO),actor.get("v",Vector3.ZERO),
			float(actor.get("yaw",0.0)),float(actor.get("ay",0.0)),float(actor.get("ap",0.0)),float(actor.get("hp",100.0)),int(actor.get("kills",0)),
			float(actor.get("gcd",0.0)),float(actor.get("fcd",0.0)),int(actor.get("weapon",0)),int(actor.get("ammo",0)),float(actor.get("reload",0.0)),
			float(actor.get("skill_active",0.0)),bool(actor.get("connected",true)),pose,int(actor.get("steps",0)),bool(actor.get("ground",true)),float(actor.get("phase",0.0)),owner_data,duel_data,str(actor.get("name","KW_ROOKIE"))
		])
	return [SNAPSHOT_FORMAT,int(state.get("tick",0)),str(state.get("match","")),bool(state.get("round_live",false)),int(state.get("wave",0)),str(state.get("phase","")),int(state.get("remaining",0)),actors_packed,state.get("grenades",[]),state.get("bolts",[]),int(state.get("event",0)),state.get("room",{})]

func _unpack_snapshot(packed: Array) -> Dictionary:
	if packed.size()<12 or int(packed[0])!=SNAPSHOT_FORMAT:return {}
	var actors_unpacked: Array=[]
	for raw_actor in packed[7] as Array:
		var a: Array=raw_actor as Array
		if a.size()<23:continue
		var actor: Dictionary={
			"id":int(a[0]),"bot":bool(a[1]),"skin":str(a[2]),"p":a[3],"v":a[4],"yaw":float(a[5]),"ay":float(a[6]),"ap":float(a[7]),
			"hp":float(a[8]),"kills":int(a[9]),"gcd":float(a[10]),"fcd":float(a[11]),"weapon":int(a[12]),"ammo":int(a[13]),"reload":float(a[14]),
			"skill_active":float(a[15]),"connected":bool(a[16]),"steps":int(a[18]),"ground":bool(a[19]),"phase":float(a[20])
		}
		var pose:=a[17] as PackedFloat32Array
		if not pose.is_empty():actor["pose"]=pose
		var owner_data:=a[21] as Array
		if owner_data.size()>=7:
			actor["ack"]=int(owner_data[0]);actor["js"]=int(owner_data[1]);actor["gs"]=int(owner_data[2]);actor["respawn_left"]=float(owner_data[3]);actor["skill_cd"]=float(owner_data[4])
			var ammos:=owner_data[5] as PackedInt32Array
			var reloads:=owner_data[6] as PackedFloat32Array
			if ammos.size()>=4:
				actor["ak_ammo"]=ammos[0];actor["sg_ammo"]=ammos[1];actor["kar_ammo"]=ammos[2];actor["gl_ammo"]=ammos[3]
			if reloads.size()>=4:
				actor["ak_reload"]=reloads[0];actor["sg_reload"]=reloads[1];actor["kar_reload"]=reloads[2];actor["gl_reload"]=reloads[3]
		var duel_data:=a[22] as Array
		if duel_data.size()>=7:
			actor["hero"]=str(duel_data[0]);actor["max_hp"]=float(duel_data[1]);actor["skill_charges"]=int(duel_data[2]);actor["skill_max"]=int(duel_data[3]);actor["guard"]=float(duel_data[4]);actor["haste"]=float(duel_data[5]);actor["augments"]=duel_data[6]
		actor["name"]=str(a[23]) if a.size()>=24 else ("KW_%04d"%int(a[0]))
		actors_unpacked.append(actor)
	return {"tick":int(packed[1]),"match":str(packed[2]),"round_live":bool(packed[3]),"wave":int(packed[4]),"phase":str(packed[5]),"remaining":int(packed[6]),"actors":actors_unpacked,"grenades":packed[8],"bolts":packed[9],"event":int(packed[10]),"room":packed[11]}

func _send_snapshot() -> void:
	for peer in peer_slots:
		if not _can_send(peer):continue
		var viewer_id:=int(peer_slots[peer])
		var packed: Array=world.network_snapshot(viewer_id) if world.has_method("network_snapshot") else _pack_snapshot(world.snapshot(),viewer_id)
		var raw: PackedByteArray=var_to_bytes(packed)
		var compressed: PackedByteArray=raw.compress(SNAPSHOT_COMPRESSION)
		max_snapshot_bytes=maxi(max_snapshot_bytes,compressed.size())
		var count: int=int(ceil(float(compressed.size())/900.0))
		for index in range(count):
			_snapshot_chunk.rpc_id(peer,int(packed[1]),index,count,raw.size(),compressed.slice(index*900,mini(compressed.size(),(index+1)*900)))

@rpc("authority","call_remote","unreliable",1)
func _snapshot_chunk(tick: int,index: int,count: int,decoded_size: int,bytes: PackedByteArray) -> void:
	if server or not connected or tick<=last_snapshot_tick:return
	if count<1 or count>24 or index<0 or index>=count or bytes.size()>900 or decoded_size>262144 or decoded_size<1:return
	if count==1:
		var raw_single:=bytes.decompress(decoded_size,SNAPSHOT_COMPRESSION)
		var state_single: Variant=bytes_to_var(raw_single)
		if state_single is Array:
			var unpacked_single:=_unpack_snapshot(state_single as Array)
			if not unpacked_single.is_empty():_on_snapshot(unpacked_single)
		elif state_single is Dictionary:
			_on_snapshot(state_single)
		return
	if not assembling.has(tick):assembling[tick]={"count":count,"size":decoded_size,"chunks":{}}
	var a: Dictionary=assembling[tick]
	if a.count!=count or a.size!=decoded_size:return
	a.chunks[index]=bytes
	for old_tick in assembling.keys():
		if old_tick<tick-12:assembling.erase(old_tick)
	if a.chunks.size()!=count:return
	var compressed=PackedByteArray()
	for i in range(count):compressed.append_array(a.chunks[i])
	var raw: PackedByteArray=compressed.decompress(decoded_size,SNAPSHOT_COMPRESSION)
	var state: Variant=bytes_to_var(raw)
	assembling.erase(tick)
	if state is Array:
		var unpacked:=_unpack_snapshot(state as Array)
		if not unpacked.is_empty():_on_snapshot(unpacked)
	elif state is Dictionary:
		_on_snapshot(state)
