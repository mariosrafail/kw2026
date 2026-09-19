extends SceneTree
func _initialize() -> void:
	var stream := AudioStreamWAV.load_from_file("res://assets/prototypes/audio/kw_neon_riot_loop.wav")
	assert(stream != null and absf(stream.get_length()-60.0)<0.01)
	stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin=0
	stream.loop_end=int(round(stream.get_length()*stream.mix_rate))
	assert(ResourceSaver.save(stream,"res://assets/prototypes/audio/kw_neon_riot_loop.res")==OK)
	print("AUDIO_BAKE_PASS seconds=",stream.get_length()," loop_samples=",stream.loop_end)
	quit(0)
