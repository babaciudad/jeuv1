## Invariant 3 : la commande est l'unité d'échange du gameplay. Si sa
## sérialisation n'est pas exacte, tout le reste est bâti sur du sable.
extends GdUnitTestSuite

func test_serialisation_aller_retour() -> void:
	var original: Command = Command.new(1234, 7, Command.Type.NONE, {"dir": Vector2(0.5, -0.25), "n": 3})
	var restored: Command = Command.from_bytes(original.to_bytes())

	assert_object(restored).is_not_null()
	assert_int(restored.tick).is_equal(1234)
	assert_int(restored.actor_id).is_equal(7)
	assert_int(int(restored.type)).is_equal(int(Command.Type.NONE))
	assert_dict(restored.payload).is_equal({"dir": Vector2(0.5, -0.25), "n": 3})

func test_charge_utile_vide() -> void:
	var restored: Command = Command.from_bytes(Command.new(0, 1).to_bytes())
	assert_object(restored).is_not_null()
	assert_dict(restored.payload).is_empty()

func test_octets_tronques_refuses() -> void:
	var bytes: PackedByteArray = Command.new(10, 2).to_bytes()
	assert_object(Command.from_bytes(bytes.slice(0, bytes.size() - 1))).is_null()
	assert_object(Command.from_bytes(PackedByteArray())).is_null()

func test_taille_de_charge_utile_mensongere_refusee() -> void:
	var bytes: PackedByteArray = Command.new(10, 2).to_bytes()
	bytes.encode_u32(Command.OFFSET_PAYLOAD_SIZE, 9999)
	assert_object(Command.from_bytes(bytes)).is_null()

func test_type_inconnu_refuse() -> void:
	var bytes: PackedByteArray = Command.new(10, 2).to_bytes()
	bytes.encode_u8(Command.OFFSET_TYPE, 200)
	assert_object(Command.from_bytes(bytes)).is_null()

func test_tick_negatif_non_serialisable() -> void:
	assert_array(Command.new(-1, 0).to_bytes()).is_empty()
