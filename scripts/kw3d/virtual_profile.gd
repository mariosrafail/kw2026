extends RefCounted
## Local-only identity bridge for the prototype client. This is deliberately not
## authentication: the updater writes kw_profile.json beside kw.exe and the game
## uses its virtual username for presentation/network display only.

const FALLBACK_USERNAME := "KW_ROOKIE"

static func sanitize_username(value: String) -> String:
	var source := value.strip_edges()
	var out := ""
	for i in range(source.length()):
		var c := source.substr(i,1)
		var code := c.unicode_at(0)
		var allowed := (code>=48 and code<=57) or (code>=65 and code<=90) or (code>=97 and code<=122) or c in ["_","-"]
		if allowed:out+=c
		elif c in [" ","."]:out+="_"
		if out.length()>=24:break
	out=out.strip_edges().trim_prefix("_").trim_suffix("_")
	return out if out.length()>=3 else FALLBACK_USERNAME

static func local_username() -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--kw-name="):
			return sanitize_username(argument.trim_prefix("--kw-name="))
	var candidates: Array[String]=[]
	if not OS.has_feature("editor"):
		candidates.append(OS.get_executable_path().get_base_dir().path_join("kw_profile.json"))
	candidates.append(ProjectSettings.globalize_path("user://kw_profile.json"))
	for path in candidates:
		if not FileAccess.file_exists(path):continue
		var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			var name:=sanitize_username(str((parsed as Dictionary).get("virtual_username","")))
			if not name.is_empty():return name
	return FALLBACK_USERNAME
