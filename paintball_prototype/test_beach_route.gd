extends SceneTree
func _initialize() -> void:
	call_deferred("_run")
func check(ok: bool, detail: String) -> bool:
	if not ok:
		push_error(detail)
		quit(1)
	return ok
func _run() -> void:
	var save_path := "user://route-test-%s.cfg" % Time.get_ticks_usec()
	set_meta("fishing_save_override",save_path)
	change_scene_to_file("res://paintball_prototype/town.tscn")
	await scene_changed
	var town := current_scene
	if not check(town.camera.projection==Camera3D.PROJECTION_PERSPECTIVE and town.has_node("TownLayout"),"Town didn't get art and shared camera"):
		return
	var town_layout := town.get_node("TownLayout")
	town.player.position = town_layout.BEACH_DOOR + Vector3(0,0.04,-1.4)
	if not check(town._interaction_text()=="Ferry to the island", "Town ferry not reachable from the pond side"):
		return
	town._interact()
	await scene_changed
	var beach := current_scene
	if not check(beach.name=="WillowbrookBeach" and beach.fishing_ui != null and beach.camera.projection==Camera3D.PROJECTION_PERSPECTIVE,"Beach scene or camera didn't load"):
		return
	var ui: Node3D = beach.fishing_ui
	var loop_stream := ui.wave_audio.stream as AudioStreamWAV
	if not check(ui.wave_audio.playing and loop_stream.stereo and loop_stream.loop_mode==AudioStreamWAV.LOOP_FORWARD and loop_stream.loop_end>loop_stream.loop_begin,"Beach waves should start as a looping stereo bed"):
		return
	beach.player.position.z = 31.0
	ui.tick(3.0,true)
	var inland_volume: float = ui.wave_audio.volume_db
	beach.player.position.z = -12.0
	ui.tick(0.12,true)
	if not check(inland_volume < -35.0 and ui.wave_audio.volume_db > inland_volume and ui.wave_audio.volume_db < -22.0,"Approaching the water should smoothly raise wave volume"):
		return
	ui.tick(2.0,true)
	if not check(ui.wave_audio.volume_db > -21.0,"Pier volume should settle at the shore level"):
		return
	beach.player.position = beach.beach_scenery.POLE
	beach._interact()
	if not check(ui.game.equipped,"Pole interaction didn't equip"):
		return
	beach.player.position = Vector3(-7,0.03,2)
	beach._update_camera()
	ui.game.population.clear()
	ui.click(beach.camera)
	if not check(not ui.game.line.is_empty() and ui.game.line.fish_id==-1 and ui.game.phase()=="casting","Click didn't start an animated cast into empty water"):
		return
	ui.click(beach.camera)
	if not check(ui.game.phase()=="casting","A second click interrupted the cast in flight"):
		return
	if not check(ui.cast_audio.playing and ui.cast_audio.stream.get_length() < ui.game.line.flight_time and not ui.plop_audio.playing,"Accepted cast should play the short whoosh, but no splash before touchdown"):
		return
	var flight: float = ui.game.line.flight_time
	ui.tick(flight * 0.5, true)
	if not check(ui.bobber.position.y > ui.WATER_Y and not ui.ripples[0].visible, "Cast should arc through the air before the splash"):
		return
	ui.tick(flight * 0.5 + 0.08, true)
	if not check(ui.ripples[0].visible and ui.droplets[0].visible, "Landing should create ripples and droplets"):
		return
	if not check(ui.plop_audio.playing and not ui.splash_pending,"Touchdown should play a plop and disarm it"):
		return
	ui.plop_audio.stop()
	ui.tick(0.05,true)
	if not check(not ui.plop_audio.playing,"Splash should not replay on later frames"):
		return
	ui.click(beach.camera)
	if not check(ui.game.line.is_empty() and ui.plop_audio.playing,"Reeling in an empty line should replay the splash"):
		return
	ui.plop_audio.stop()
	ui.click(beach.camera)
	ui.tick(ui.game.line.flight_time + 0.02,true)
	ui.plop_audio.stop()
	ui.tick(ui.game.line.remaining + 0.1,true)
	if not check(ui.game.line.is_empty() and not ui.plop_audio.playing and not ui.nibble_audio.playing and not ui.bite_audio.playing and not ui.catch_audio.playing,"Empty-line timeout should not play a reel splash"):
		return
	var spot: Array[Vector3] = [Vector3(-7,0,-6.5)]
	ui.game.start_population(spot)
	ui.click(beach.camera)
	ui.tick(ui.game.line.flight_time + 0.05,true)
	ui.plop_audio.stop()
	ui.click(beach.camera)
	if not check(ui.game.line.is_empty() and ui.plop_audio.playing and ui.game.inventory.is_empty() and not ui.catch_audio.playing and not ui.bite_audio.playing,"Reeling too early should play the no-fish retrieval splash"):
		return
	ui.plop_audio.stop()
	ui.game.start_population(spot)
	ui.click(beach.camera)
	if not check(not ui.game.line.is_empty() and ui.game.line.fish_id!=-1,"Click didn't attract an existing fish"):
		return
	ui.tick(ui.game.line.flight_time + 0.02,true)
	ui.plop_audio.stop()
	if not check(not ui.nibble_audio.playing,"Waiting before the first nibble should not play a cue"):
		return
	for nibble: float in ui.game.line.nibbles:
		ui.tick(nibble - ui.game.line.age + 0.02,true)
		if not check(ui.game.phase()=="nibble" and ui.nibble_audio.playing and not ui.bite_audio.playing and not ui.catch_audio.playing,"A small nibble should play only its soft drop cue"):
			return
		ui.nibble_audio.stop()
		ui.tick(0.02,true)
		if not check(not ui.nibble_audio.playing,"The drop should not replay during the same nibble"):
			return
	ui.tick(ui.game.line.bite_at - ui.game.line.age + 0.1,true)
	if not check(ui.game.phase()=="bite" and ui.bite_audio.playing and not ui.plop_audio.playing and not ui.catch_audio.playing,"A true bite should play the short reel cue, not a splash"):
		return
	ui.bite_audio.stop()
	ui.tick(0.02,true)
	if not check(not ui.bite_audio.playing,"The bite cue must not replay on later bite frames"):
		return
	ui.click(beach.camera)
	if not check(ui.game.inventory.size()==1 and ui.game.stars==0,"Reel didn't add a fish without awarding stars"):
		return
	if not check(ui.is_modal_open() and ui.primary.text=="Keep Fishing" and beach.player.movement_locked,"Catch popup didn't open immediately"):
		return
	if not check(ui.catch_audio.playing and not ui.plop_audio.playing and not ui.bite_audio.playing,"A successful catch should play its own splash, not a plop or bite cue"):
		return
	var caught_card: Control = ui.sale_cards.get_node("FishCard")
	var caught_name := caught_card.find_child("FishName",true,false) as Label
	var caught_value := caught_card.find_child("FishValue",true,false) as Label
	var caught_pictures := caught_card.find_children("*","SubViewport",true,false)
	if not check(caught_name != null and not caught_name.text.is_empty() and caught_value.text.contains("star") and caught_pictures.size()==1,"Catch popup didn't show name, star value, and model"):
		return
	ui.primary.pressed.emit()
	if not check(not ui.is_modal_open() and not beach.player.movement_locked and beach.player.is_physics_processing() and ui.game.inventory.size()==1 and ui.game.stars==0,"Keep Fishing lost catch, awarded stars, or failed to restore controls"):
		return
	ui.click(beach.camera)
	if not check(ui.game.phase()=="casting","Expected a new cast before keyboard put-away"):
		return
	var put_away_key := InputEventKey.new()
	put_away_key.physical_keycode = KEY_R
	put_away_key.pressed = true
	root.push_input(put_away_key)
	if not check(not ui.game.equipped and ui.game.line.is_empty() and not ui.held_rod.visible and not ui.bobber.visible
		and not ui.put_away_button.visible and not ui.cast_audio.playing and ui.game.inventory.size()==1 and ui.game.stars==0,
		"R didn't put away the rod and cancel the cast harmlessly"):
		return
	beach.player.position = beach.beach_scenery.POLE
	beach._interact()
	ui.tick(0.02,true)
	await process_frame
	if not check(ui.game.equipped and ui.held_rod.visible and ui.put_away_button.visible,"Pole pickup must remain available after putting it away"):
		return
	var tap := InputEventScreenTouch.new()
	tap.index = 0
	tap.position = ui.put_away_button.get_global_rect().get_center()
	tap.pressed = true
	root.push_input(tap,true)
	tap = tap.duplicate() as InputEventScreenTouch
	tap.pressed = false
	root.push_input(tap,true)
	await process_frame
	if not check(not ui.game.equipped and not ui.held_rod.visible and not ui.put_away_button.visible
		and ui.game.inventory.size()==1 and ui.game.stars==0,"Tapping Put Away didn't stow the pole without changing the bag"):
		return
	var caught_id: String = ui.game.inventory[0]
	ui.game.inventory.append(caught_id)
	for kind in ["goldfish","tetra","bluegoldfish","betta","flatfish","lionfish"]:
		ui.game.inventory.append(kind)
	var expected_count: int = ui.game.inventory.size()
	beach.player.position = beach.beach_scenery.SHOP_NPC
	beach._interact()
	if not check(ui.is_modal_open() and ui.primary.text=="Confirm Sale" and ui.sale_cards.get_child_count()==1,"Shop sale preview didn't show"):
		return
	var sale_list := ui.sale_cards.get_node("FishList") as ScrollContainer
	await process_frame
	var sale_rows := sale_list.get_node("Items")
	var expected_total: int = ui.game.sale_preview().total
	if not check(sale_list.get_v_scroll_bar().max_value > sale_list.get_v_scroll_bar().page and sale_rows.get_child_count() < expected_count and ui.sale_total.text.contains(str(expected_total)),"Sale list didn't scroll, group duplicates, or show total"):
		return
	if not check(sale_rows.find_child("FishValue",true,false).text.contains("each"),"Grouped sale item didn't show its per-fish value"):
		return
	ui.close_modal()
	if not check(ui.game.inventory.size()==expected_count and ui.game.stars==0,"Cancel sale changed inventory or stars"):
		return
	beach._interact()
	ui.primary.pressed.emit()
	if not check(ui.game.inventory.is_empty() and ui.game.stars==expected_total and ui.heading.text=="Sale Complete","Confirm sale didn't grant stars"):
		return
	ui.primary.pressed.emit()
	beach.player.position = beach.beach_scenery.SLIDE_ENTRY
	beach._interact()
	if not check(beach.slide_time==0.0 and not beach.player.is_physics_processing(),"Slide did not start"):
		return
	for i in range(430):
		await physics_frame
	if not check(beach.slide_time<0.0 and beach.player.is_physics_processing() and absf(beach.player.position.z-14.35)<.3,"Slide did not return control"):
		return
	beach.player.position = beach.beach_scenery.TOWN_DOOR
	var beach_ambience: WeakRef = weakref(ui.wave_audio)
	beach._interact()
	await scene_changed
	if not check(beach_ambience.get_ref() == null,"Leaving the beach should free its wave audio"):
		return
	if not check(current_scene.name=="WillowbrookTown" and current_scene.player.position.distance_to(preload("res://paintball_prototype/town_layout.gd").BEACH_RETURN)<0.2,"Beach exit didn't return beside Town ferry landing"):
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	print("PASS: town-to-beach, shared camera, click casts and reels, keyboard/touch put-away, timed beach audio, catch popup, scrollable sale cancel/confirm, slide, and ferry return")
	quit()
