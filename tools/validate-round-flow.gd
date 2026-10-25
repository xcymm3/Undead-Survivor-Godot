extends RefCounted
static func validate(game, check: Callable) -> void:
	var data = game.get_node("/root/Data")
	var previous_notice: bool = data.settings.coop_notice_seen
	game.return_home()
	data.settings.coop_notice_seen = false
	game.ui.show_multiplayer()
	await game.get_tree().process_frame
	await game.get_tree().process_frame
	var view = game.ui.multiplayer_view
	check.call(view.dialog != null and view.notice_confirm.disabled,"First multiplayer entry requires reading the notice")
	view.confirm_notice()
	check.call(not data.settings.coop_notice_seen and view.dialog != null,"Calling confirm before scrolling cannot bypass the notice")
	view.cancel_notice()
	check.call(game.ui.current == "home" and not data.settings.coop_notice_seen,"Cancelling the notice returns home without acknowledging it")
	game.ui.show_multiplayer()
	await game.get_tree().process_frame
	await game.get_tree().process_frame
	view = game.ui.multiplayer_view
	view.notice_scroll.scroll_vertical = 10000
	await game.get_tree().process_frame
	check.call(view.notice_read and not view.notice_confirm.disabled,"Only reaching the scroll bottom enables confirmation")
	view.confirm_notice()
	check.call(data.settings.coop_notice_seen and view.dialog == null,"Confirmed notice is remembered outside individual save slots")
	game.ui.show_multiplayer()
	check.call(game.ui.multiplayer_view.dialog == null,"Returning to multiplayer does not repeat an acknowledged notice")
	game.ui.multiplayer_view.open_notice()
	check.call(game.ui.multiplayer_view.notice_confirm.disabled,"Top-right notice button opens a fresh scroll-gated copy")
	game.return_home()
	data.settings.coop_notice_seen = previous_notice
	for victorious in [false,true]:
		game.start_solo("defense",711)
		game.sim.progression.data.intro_seen = true
		game.sim.won = victorious
		game.sim.failed = not victorious
		game.finish_run()
		var ending = game.ending_sequence
		check.call(ending.phase == "animation" and not ending.caption.visible,"Ending starts with the actual collapse animation: "+str(victorious))
		ending.step(ending.animation_seconds+.01)
		ending.step(.5)
		check.call(ending.black.color.a > .49 and ending.black.color.a < .51 and not ending.caption.visible,"Caption cannot appear before the opaque fade")
		ending.step(.51)
		check.call(ending.black.color.a == 1 and ending.caption.visible,"Ending caption appears on fully opaque black")
		check.call(ending.caption.text == ("太阳升起，你活下来了...\n感谢游玩本DEMO！" if victorious else "你失败了，但是死亡并非终点..."),"Ending uses the exact requested caption")
		ending.step(2.81)
		ending.step(.01)
		check.call(not game.finished and not game.sim.failed and not game.sim.won and ending.black.color.a == 1,"New attempt is constructed only while the screen remains black")
		ending.step(.5)
		check.call(ending.black.color.a > .49 and ending.black.color.a < .51,"New spawn fades back into view")
		ending.step(.6)
		check.call(game.ending_sequence == null and game.ui.menu == null,"Automatic respawn ends without opening a result dialog")
		await game.get_tree().process_frame
	game.sim.failed = true
	game.sim.cause = "crystal"
	game.finish_run()
	var point = game.get_node("/root/Data").Maps.Defense.CRYSTAL
	check.call(game.camera.is_position_in_frustum(Vector3(point.x,4.5,point.y)),"Crystal defeat always frames the real crystal destruction even from the spawn room")
	game.start_solo("defense",713)
	game.sim.coop_host = "solo"
	game.sim.add_pawn("qa_guest","客机",1)
	var guest: Dictionary = game.sim.pawns.qa_guest
	game.sim.equipment.initialize_pawn(guest)
	guest.hp = 0
	game.sim.defense.started = true
	game.sim.defense.crystal_hp = 3000
	game.sim.roster.clear()
	game.sim.zombies.clear()
	game.sim.defense_director.launched_waves = {2:true}
	game.sim.defense_director.rewarded_waves.clear()
	game.sim.defense_director.reward_finished_waves()
	check.call(guest.hp == guest.max_hp and guest.pos.distance_to(game.sim.map_definition.spawn) < 6,"Connected dead guest revives at spawn after the actual wave is cleared")
	game.sim.wave = 3
	guest.protection = 0.0
	guest.tutorial_guard_remaining = 0.0
	game.sim.damage_pawn(guest,{"id":991,"pos":guest.pos},10000)
	check.call(guest.hp == 0 and guest.death_wave == 3,"Authoritative damage records the wave in which a guest dies")
	game.sim.defense_director.revive_guests(2)
	check.call(guest.hp == 0,"Clearing an older overlapping wave cannot revive a guest from a later wave")
	game.sim.defense_director.revive_guests(3)
	check.call(guest.hp == guest.max_hp and not guest.has("death_wave"),"Guest revives only after the wave of death has actually cleared")
	for index in [2,3]:
		var id = "qa_guest"+str(index)
		game.sim.add_pawn(id,id,index)
		game.sim.equipment.initialize_pawn(game.sim.pawns[id])
		game.sim.pawns[id].hp = 0
	game.sim.defense_director.revive_guests()
	check.call(game.sim.pawns.qa_guest3.pos.is_equal_approx(game.sim.map_definition.spawn+Vector2(1.4,2.6)),"Fourth-player wave revival uses its original valid spawn slot instead of an extra row")
	guest.hp = 0
	guest.connected = false
	game.sim.defense_director.revive_guests()
	check.call(guest.hp == 0,"Disconnected guest is never revived by wave completion")
	game.return_home()
