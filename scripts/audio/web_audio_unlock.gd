extends Node
class_name WebAudioUnlock

signal web_audio_unlocked()

var _initialized := false
var _unlocked := false
var _last_gesture_tick := 0

func _ready() -> void:
	if not OS.has_feature("web"):
		return
	_initialized = true
	set_process(true)
	set_process_input(true)
	_install_web_audio_hooks()
	print("[AUDIO] web audio unlock initialized")
	_log_bus_volumes()

func _process(_delta: float) -> void:
	if not _initialized or _unlocked:
		return
	var tick := int(JavaScriptBridge.eval("window.KW_WEB_AUDIO_GESTURE_TICK || 0"))
	if tick > _last_gesture_tick:
		_last_gesture_tick = tick
		print("[AUDIO] first user gesture received")
		_attempt_resume("js-gesture")

func _input(event: InputEvent) -> void:
	if not _initialized or _unlocked:
		return
	var is_gesture := false
	if event is InputEventMouseButton:
		is_gesture = (event as InputEventMouseButton).pressed
	elif event is InputEventScreenTouch:
		is_gesture = (event as InputEventScreenTouch).pressed
	elif event is InputEventKey:
		is_gesture = (event as InputEventKey).pressed
	if not is_gesture:
		return
	print("[AUDIO] first user gesture received")
	_attempt_resume("godot-input")

func ensure_web_audio_unlocked(reason: String = "manual") -> void:
	if not _initialized or _unlocked:
		return
	_attempt_resume(reason)

func is_web_audio_unlocked() -> bool:
	return _unlocked

func _install_web_audio_hooks() -> void:
	JavaScriptBridge.eval("(function(){try{window.KW_WEB_AUDIO_GESTURE_TICK=window.KW_WEB_AUDIO_GESTURE_TICK||0;window.KW_WEB_AUDIO_ENABLED=window.KW_WEB_AUDIO_ENABLED===true; if(window.KW_WEB_AUDIO_HOOKS_INSTALLED){return;} var onGesture=function(){window.KW_WEB_AUDIO_GESTURE_TICK=(window.KW_WEB_AUDIO_GESTURE_TICK||0)+1;}; ['pointerdown','touchstart','click','keydown'].forEach(function(evt){window.addEventListener(evt,onGesture,{passive:true});document.addEventListener(evt,onGesture,{passive:true});}); window.KW_WEB_AUDIO_HOOKS_INSTALLED=true;}catch(e){}})();")

func _attempt_resume(reason: String) -> void:
	if _unlocked:
		return
	print("[AUDIO] audio resume attempted reason=%s" % reason)
	var result := str(JavaScriptBridge.eval("(function(){try{window.KW_WEB_AUDIO_ENABLED=window.KW_WEB_AUDIO_ENABLED===true; var resumed=0; var done=false; var mark=function(){window.KW_WEB_AUDIO_ENABLED=true; done=true;}; var resumeCtx=function(ctx){if(!ctx){return;} try{if(typeof ctx.resume==='function'){ctx.resume(); resumed+=1; if(ctx.state==='running'){mark();}} else if(ctx.state==='running'){mark();}}catch(e){}}; if(window.godotAudioContext){resumeCtx(window.godotAudioContext);} if(window.AudioContext||window.webkitAudioContext){try{window.KW_AUDIO_CTX=window.KW_AUDIO_CTX||new (window.AudioContext||window.webkitAudioContext)();}catch(e){} resumeCtx(window.KW_AUDIO_CTX);} if(window.Module){resumeCtx(window.Module.audioContext);resumeCtx(window.Module.ctx); if(window.Module.resumeAudio){try{window.Module.resumeAudio(); window.KW_WEB_AUDIO_ENABLED=true; done=true;}catch(e){}}} if(!done){window.KW_WEB_AUDIO_ENABLED = (window.KW_WEB_AUDIO_ENABLED===true) || resumed>0;} return String(window.KW_WEB_AUDIO_ENABLED===true);}catch(e){return 'false';}})();")).strip_edges().to_lower()
	_unlocked = result == "true"
	print("[AUDIO] audio unlocked = %s" % str(_unlocked))
	_log_bus_volumes()
	if _unlocked:
		emit_signal("web_audio_unlocked")

func _log_bus_volumes() -> void:
	var master_db := _bus_volume_db_by_name("Master")
	var music_db := _bus_volume_db_by_name("Music")
	var sfx_db := _bus_volume_db_by_name("SFX")
	print("[AUDIO] master volume = %s" % str(master_db))
	print("[AUDIO] music volume = %s" % str(music_db))
	print("[AUDIO] sfx volume = %s" % str(sfx_db))

func _bus_volume_db_by_name(bus_name: String) -> String:
	for i in range(AudioServer.get_bus_count()):
		if AudioServer.get_bus_name(i).to_lower() == bus_name.to_lower():
			return str(AudioServer.get_bus_volume_db(i))
	return "missing"
