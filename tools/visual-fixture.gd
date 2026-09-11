extends Node
var game
var previous = ""
var settle = 0
func _process(_dt: float) -> void:
 var raw = JavaScriptBridge.eval("JSON.stringify(window.__visualPose || {weapon:0,phase:0,view:'side',action:'idle',model:0})")
 if previous == raw and settle >= 4: return
 if previous != raw: settle = 0
 previous = raw
 settle += 1
 game.set_process(false)
 var spec: Dictionary = JSON.parse_string(raw)
 if spec.view == "lineup":
  game.weapon.visible = false
  game.ui.root.visible = false
  for actor in game.partners.values(): actor.visible = false
  if not has_node("Lineup"):
   var lineup = Node3D.new()
   lineup.name = "Lineup"
   add_child(lineup)
   for index in 4:
    var model = load("res://scripts/survivor_model.gd").new()
    lineup.add_child(model)
    model.build(index)
    model.position = Vector3((index-1.5)*1.05,0,5)
  game.camera.position = Vector3(0,1.5,.3)
  game.camera.look_at(Vector3(0,.95,5))
  game.camera.fov = 54
  RenderingServer.force_draw(true)
  if settle >= 4: JavaScriptBridge.eval("window.__visualReady = "+JSON.stringify(raw))
  return
 if has_node("Lineup"): get_node("Lineup").visible = false
 var p: Dictionary = game.sim.pawns.visual
 p.weapon = int(spec.weapon)
 p.requested = p.weapon
 p.reloading = spec.action == "reload"
 p.reload = Data.weapons[p.weapon].reloadDuration*(1-float(spec.phase))
 p.fire_anim = Data.weapons[p.weapon].fireDuration*(1-float(spec.phase)) if spec.action == "fire" else 0
 p.aim = spec.action == "aim"
 if int(p.appearance[0]) != int(spec.model):
  p.appearance[0] = int(spec.model)
  if game.partners.has("visual"):
   game.partners.visual.free()
   game.partners.erase("visual")
 if not game.partners.has("visual"):
  var actor = load("res://scripts/partner_view.gd").new()
  game.add_child(actor)
  actor.setup(p)
  game.partners.visual = actor
 var local: Dictionary = game.local_pawn()
 for key in ["weapon","requested","reloading","reload","fire_anim","aim"]: local[key] = p[key]
 game.weapon.ads = 1 if p.aim else 0
 game.weapon.sync(local,0,0)
 game.weapon.visible = spec.view == "first"
 if game.partners.has("visual"):
  game.partners.visual.sync(p,0.1)
  game.partners.visual.visible = spec.view != "first"
 game.camera.position = Vector3(3,1.65,5.15) if spec.view == "side" else Vector3(1.4,1.65,2.8) if spec.view == "front" else Vector3(0,1.7,9)
 if spec.view != "first": game.camera.look_at(Vector3(0,1.3,4.7))
 else: game.camera.rotation = Vector3.ZERO
 game.camera.fov = rad_to_deg(2*atan(tan(deg_to_rad(61)/2)/(6.0 if p.weapon == 5 else 1.25))) if spec.view == "first" and p.aim else 61
 game.ui.root.visible = spec.view == "first"
 game.ui.tick(0)
 game.effects.particles.clear()
 game.effects.step(0)
 if spec.action == "fire" and p.weapon != 6:
  var event = {"kind":"shot","player":local.id if spec.view == "first" else "visual","weapon":p.weapon,"from":Vector3(.24,1.52,4.5 if spec.view != "first" else 8.5),"to":Vector3(0,1.5,-25)}
  game.handle_effects([event])
  game.effects.step(0)
 RenderingServer.force_draw(true)
 if settle >= 4: JavaScriptBridge.eval("window.__visualReady = "+JSON.stringify(raw))
