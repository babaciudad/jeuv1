## Le tampon doit rendre chaque commande à son tick, une seule fois, et
## abandonner celles arrivées trop tard plutôt que de les appliquer au
## mauvais moment.
extends GdUnitTestSuite

func test_rend_les_commandes_du_tick_demande() -> void:
	var buffer: CommandBuffer = CommandBuffer.new()
	buffer.push(Command.new(10, 1))
	buffer.push(Command.new(11, 1))
	buffer.push(Command.new(10, 2))

	var due: Array[Command] = buffer.take(10)
	assert_int(due.size()).is_equal(2)
	assert_int(buffer.size()).is_equal(1)

func test_une_commande_n_est_rendue_qu_une_fois() -> void:
	var buffer: CommandBuffer = CommandBuffer.new()
	buffer.push(Command.new(5, 1))
	assert_int(buffer.take(5).size()).is_equal(1)
	assert_int(buffer.take(5).size()).is_equal(0)

func test_les_commandes_en_retard_sont_abandonnees_et_comptees() -> void:
	var buffer: CommandBuffer = CommandBuffer.new()
	buffer.push(Command.new(3, 1))
	buffer.push(Command.new(4, 1))

	assert_int(buffer.take(10).size()).is_equal(0)
	assert_int(buffer.dropped_late).is_equal(2)
	assert_int(buffer.size()).is_equal(0)
