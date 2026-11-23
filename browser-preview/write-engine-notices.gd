extends SceneTree

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1 or not args[0].is_absolute_path():
		printerr("Pass one absolute notice output path after --.")
		quit(1)
		return
	var out := FileAccess.open(args[0], FileAccess.WRITE)
	if out == null:
		printerr("Could not write engine notices.")
		quit(1)
		return
	out.store_string("Godot Engine " + str(Engine.get_version_info()["string"]) + "\n")
	out.store_string("https://godotengine.org/\n\n" + Engine.get_license_text() + "\n")
	out.store_string("\nTHIRD-PARTY COPYRIGHTS\n\n")
	for component in Engine.get_copyright_info():
		out.store_string(component["name"] + "\n")
		for part in component["parts"]:
			out.store_string("  Files: " + ", ".join(part["files"]) + "\n")
			out.store_string("  Copyright: " + "; ".join(part["copyright"]) + "\n")
			out.store_string("  License: " + part["license"] + "\n")
		out.store_string("\n")
	out.store_string("\nTHIRD-PARTY LICENSE TEXTS\n")
	var licenses := Engine.get_license_info()
	var identifiers := licenses.keys()
	identifiers.sort()
	for identifier in identifiers:
		out.store_string("\n" + identifier + "\n" + licenses[identifier] + "\n")
	out.close()
	quit()