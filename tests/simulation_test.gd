## La correction d'horloge est le seul mécanisme autorisé à modifier le
## compteur de tick. Ces tests fixent son comportement sans réseau.
extends GdUnitTestSuite

var _created: Array[Simulation] = []

func after_test() -> void:
	for sim: Simulation in _created:
		sim.free()
	_created.clear()

func _make() -> Simulation:
	var sim: Simulation = Simulation.new()
	_created.append(sim)
	return sim

func test_avance_d_un_tick_sans_cible() -> void:
	var sim: Simulation = _make()
	sim.advance()
	sim.advance()
	assert_int(sim.current_tick).is_equal(2)

func test_zone_morte_pas_de_correction() -> void:
	var sim: Simulation = _make()
	sim.advance()
	# Cible à un tick d'avance : dans la zone morte, on avance normalement.
	sim.set_target_tick(sim.current_tick + 1)
	sim.advance()
	assert_int(sim.current_tick).is_equal(2)

func test_rattrape_un_tick_quand_en_retard() -> void:
	var sim: Simulation = _make()
	sim.set_target_tick(5)
	sim.advance()
	assert_int(sim.current_tick).is_equal(2)

func test_cale_un_tick_quand_en_avance() -> void:
	var sim: Simulation = _make()
	sim.advance()
	sim.advance()
	sim.advance()
	sim.set_target_tick(0)
	sim.advance()
	assert_int(sim.current_tick).is_equal(3)

func test_resynchronisation_au_dela_du_seuil() -> void:
	var sim: Simulation = _make()
	var snapped_to: Array[int] = []
	sim.tick_snapped.connect(func(_from: int, to: int) -> void: snapped_to.append(to))
	sim.set_target_tick(Simulation.SNAP_THRESHOLD_TICKS + 50)
	sim.advance()
	assert_int(sim.current_tick).is_equal(Simulation.SNAP_THRESHOLD_TICKS + 50)
	assert_int(snapped_to.size()).is_equal(1)

func test_les_commandes_sont_appliquees_a_leur_tick() -> void:
	var sim: Simulation = _make()
	var applied: Array[int] = []
	sim.command_applied.connect(func(command: Command) -> void: applied.append(command.tick))
	sim.buffer.push(Command.new(3, 1))
	for _i: int in 5:
		sim.advance()
	assert_array(applied).is_equal([3])

## Le socle temporel du jeu, verrouille en test.
##
## Toute la simulation est datee en ticks de 1/60 s (invariant 1). Ce reglage
## ne vit pas dans le code mais dans project.godot : personne ne le relit
## jamais, et s'il derivait, le jeu entier tournerait plus vite ou plus
## lentement sans qu'aucun autre test ne s'en apercoive -- les ticks resteraient
## parfaitement coherents entre eux, simplement ils ne vaudraient plus 1/60 s.
func test_le_pas_physique_vaut_bien_un_soixantieme() -> void:
	# Affectation typee directe : le cast explicite d'un Variant est refuse par
	# le typage strict du projet, l'affectation est verifiee a l'execution.
	var rate: int = ProjectSettings.get_setting(
		"physics/common/physics_ticks_per_second", 0)
	assert_int(rate) \
		.override_failure_message(
			"Le pas physique est a %d Hz : la simulation ne tourne plus a la "
			% rate + "vitesse pour laquelle toutes les attaques sont reglees.") \
		.is_equal(SimConfig.TICK_RATE)

## Plafond de rattrapage. Au defaut de Godot (8), un a-coup fait jouer huit
## ticks dans une seule image : le personnage franchit un demi-metre d'un bond,
## ce qui se lit a l'ecran comme une teleportation ou un passage a travers le
## decor.
func test_le_rattrapage_est_plafonne() -> void:
	var cap: int = ProjectSettings.get_setting(
		"physics/common/max_physics_steps_per_frame", 8)
	assert_int(cap) \
		.override_failure_message(
			"Rattrapage plafonne a %d pas : un a-coup fera bondir les acteurs." % cap) \
		.is_less_equal(4)
	assert_int(cap).is_greater(0)
