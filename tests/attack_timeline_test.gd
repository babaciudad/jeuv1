## Invariant 8 : la hitbox s'ouvre et se ferme par les pistes d'appel de
## méthode de l'AnimationPlayer, pas par un compteur. Ce test vérifie que le
## calendrier chargé depuis res://data/ déclenche aux ticks attendus, et donc
## que régler une attaque dans l'éditeur d'animation suffit à changer le jeu.
extends GdUnitTestSuite

const ATTACK_PATH: String = "res://data/attacks/player_light.tres"
## 0,1667 s et 0,2833 s à 60 Hz.
const EXPECTED_OPEN_TICK: int = 10
const EXPECTED_CLOSE_TICK: int = 17

var _runner: AttackRunner

func before_test() -> void:
	_runner = AttackRunner.new()
	add_child(_runner)

func after_test() -> void:
	if is_instance_valid(_runner):
		_runner.queue_free()

func test_le_calendrier_ouvre_et_ferme_aux_ticks_attendus() -> void:
	var attack: AttackData = load(ATTACK_PATH)
	assert_object(attack).is_not_null()
	assert_object(attack.timeline).is_not_null()
	assert_bool(_runner.start(attack)).is_true()

	var open_tick: int = -1
	var close_tick: int = -1
	var finish_tick: int = -1
	for tick: int in 120:
		var was_open: bool = _runner.hitbox_open
		_runner.advance_tick()
		if not was_open and _runner.hitbox_open and open_tick < 0:
			open_tick = _runner.elapsed_ticks
		if was_open and not _runner.hitbox_open and close_tick < 0:
			close_tick = _runner.elapsed_ticks
		if _runner.finished and finish_tick < 0:
			finish_tick = _runner.elapsed_ticks
			break

	assert_int(open_tick).is_equal(EXPECTED_OPEN_TICK)
	assert_int(close_tick).is_equal(EXPECTED_CLOSE_TICK)
	assert_int(finish_tick).is_equal(36)

func test_une_cible_n_est_touchee_qu_une_fois_par_activation() -> void:
	var attack: AttackData = load(ATTACK_PATH)
	assert_bool(_runner.start(attack)).is_true()
	assert_bool(_runner.try_register_hit(42)).is_true()
	assert_bool(_runner.try_register_hit(42)).is_false()
	assert_bool(_runner.try_register_hit(43)).is_true()

func test_l_interruption_ferme_la_hitbox() -> void:
	var attack: AttackData = load(ATTACK_PATH)
	assert_bool(_runner.start(attack)).is_true()
	for _i: int in EXPECTED_OPEN_TICK + 1:
		_runner.advance_tick()
	assert_bool(_runner.hitbox_open).is_true()
	_runner.interrupt()
	assert_bool(_runner.hitbox_open).is_false()
	assert_bool(_runner.finished).is_true()
