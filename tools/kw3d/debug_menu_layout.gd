extends SceneTree
func _initialize() -> void: run.call_deferred()
func pr(n: Control, name: String) -> void:
	print(name, " rect=",n.get_global_rect()," min=",n.get_combined_minimum_size()," custom=",n.custom_minimum_size," vis=",n.visible)
func run() -> void:
	var stage=load("res://scenes/prototypes/kw_3d_lan_duel.tscn").instantiate()
	root.add_child(stage)
	for i in range(12): await process_frame
	var m=stage.client.menu
	pr(m,"menu");pr(m.panel,"panel")
	var b=m.create_button
	var n:Node=b
	var depth=0
	while n!=null and depth<10:
		if n is Control: pr(n as Control,"ancestor"+str(depth)+":"+n.name)
		n=n.get_parent();depth+=1
	quit()
