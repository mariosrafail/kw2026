extends Node
## Trusted-LAN proof. Resume credentials are memory-only; not production identity/authentication.
signal welcomed(data: Dictionary)
signal state_received(data: Dictionary)
signal combat_event(data: Dictionary)
signal connection_message(text: String)
const LEVEL=preload("res://scripts/kw3d/online_level.gd")
const CODEC=preload("res://scripts/kw3d/input_codec.gd")
const PROTOCOL=1
const BUILD="kw3d-proof-20260919-v1"
const MAX_PLAYERS=4
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
	# WebSocketMultiplayerPeer has no ENetPacketPeer/channel state API. Presence in get_peers()
	# means Godot has completed the WebSocket multiplayer handshake.
	return multiplayer.multiplayer_peer is WebSocketMultiplayerPeer

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

func join(host: String,port: int,display_name: String="Player") -> Error:
	if server:return ERR_INVALID_PARAMETER
	close_connection(false)
	server_host=host.strip_edges();server_port=port;nickname=display_name.left(24)
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

func reconnect() -> Error:return join(server_host,server_port,nickname)
func _connected() -> void:_hello.rpc_id(1,PROTOCOL,BUILD,LEVEL.fingerprint(),token,nickname)
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
func _hello(protocol: int,build: String,manifest: String,resume: String,display_name: String) -> void:
	if not server:return
	var peer=multiplayer.get_remote_sender_id()
	if peer_slots.has(peer):return
	if protocol!=PROTOCOL or build!=BUILD or manifest!=LEVEL.fingerprint():
		_reject.rpc_id(peer,"Build/map mismatch. Both clients need the same KW proof.");return
	if resume.length()>128 or display_name.length()>32:_reject.rpc_id(peer,"Invalid handshake.");return
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
		if occupied>=MAX_PLAYERS:_reject.rpc_id(peer,"Room full. Reconnect slots are reserved briefly.");return
		slot=next_slot;next_slot+=1
	var key=Crypto.new().generate_random_bytes(24).hex_encode()
	sessions[key]={"slot":slot,"peer":peer,"expiry":0.0}
	peer_slots[peer]=slot;pending_peers.erase(peer)
	counters[peer]={"window":elapsed,"packets":0,"commands":0}
	world.add_player(slot)
	var a: Node3D=world.actors[slot]
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
	if f.size()!=11:return false
	for key in ["seq","ct","js","gs"]:
		if typeof(f.get(key))!=TYPE_INT or f[key]<0 or f[key]>2000000000:return false
	if typeof(f.get("move"))!=TYPE_VECTOR2 or not (f.move as Vector2).is_finite() or f.move.length()>1.001:return false
	for key in ["yaw","pitch","side"]:
		if typeof(f.get(key)) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(f[key])):return false
	if absf(f.yaw)>PI+0.001 or f.pitch < -0.84 or f.pitch>0.53 or f.side not in [-1.0,1.0]:return false
	for key in ["fire","aim","sprint"]:
		if typeof(f.get(key))!=TYPE_BOOL:return false
	return f.seq>0

func send_frames(frames: Array) -> void:
	if connected and not server and _can_send(1):_inputs.rpc_id(1,CODEC.encode(frames))

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
		if world.tick_id%3==0:_send_snapshot(world.snapshot())
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

func _send_snapshot(state: Dictionary) -> void:
	var raw: PackedByteArray=var_to_bytes(state)
	var compressed: PackedByteArray=raw.compress(FileAccess.COMPRESSION_ZSTD)
	max_snapshot_bytes=maxi(max_snapshot_bytes,compressed.size())
	var count: int=int(ceil(float(compressed.size())/900.0))
	for peer in peer_slots:
		if not _can_send(peer):continue
		for index in range(count):
			_snapshot_chunk.rpc_id(peer,int(state.tick),index,count,raw.size(),compressed.slice(index*900,mini(compressed.size(),(index+1)*900)))

@rpc("authority","call_remote","unreliable",1)
func _snapshot_chunk(tick: int,index: int,count: int,decoded_size: int,bytes: PackedByteArray) -> void:
	if server or not connected or tick<=last_snapshot_tick:return
	if count<1 or count>24 or index<0 or index>=count or bytes.size()>900 or decoded_size>262144 or decoded_size<1:return
	if not assembling.has(tick):assembling[tick]={"count":count,"size":decoded_size,"chunks":{}}
	var a: Dictionary=assembling[tick]
	if a.count!=count or a.size!=decoded_size:return
	a.chunks[index]=bytes
	for old_tick in assembling.keys():
		if old_tick<tick-12:assembling.erase(old_tick)
	if a.chunks.size()!=count:return
	var compressed=PackedByteArray()
	for i in range(count):compressed.append_array(a.chunks[i])
	var raw: PackedByteArray=compressed.decompress(decoded_size,FileAccess.COMPRESSION_ZSTD)
	var state: Variant=bytes_to_var(raw)
	assembling.erase(tick)
	if state is Dictionary:_on_snapshot(state)
