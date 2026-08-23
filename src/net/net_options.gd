## Options réseau d'une instance, lues sur la ligne de commande.
##
## Les arguments utilisateur sont ceux placés après « -- » lors du lancement,
## ce qui évite tout conflit avec les options du moteur.
##
##   --host                démarre en hôte (défaut)
##   --connect <adresse>   démarre en client et se connecte à cette adresse
##   --port <n>            port UDP
##   --latency <ms>        latence simulée à la réception, dans chaque sens
##   --loss <0..1>         probabilité de perte par paquet
##   --seed <n>            graine du tirage de perte, 0 = aléatoire
##   --label <texte>       étiquette affichée, pour distinguer les fenêtres
##   --log-ticks <n>       journalise l'état d'horloge tous les n ticks, 0 = off
class_name NetOptions
extends RefCounted

enum Role {
	HOST,
	CLIENT,
}

const DEFAULT_PORT: int = 45123

var role: Role = Role.HOST
var address: String = "127.0.0.1"
var port: int = DEFAULT_PORT
var latency_msec: int = 0
var loss: float = 0.0
var rng_seed: int = 0
var label: String = ""
## Intervalle de journalisation de l'horloge, en ticks. 0 désactive.
## Indispensable au banc réseau en mode headless, où il n'y a pas de fenêtre
## à regarder.
var log_ticks_interval: int = 0

static func from_command_line() -> NetOptions:
	return NetOptions.from_arguments(OS.get_cmdline_user_args())

static func from_arguments(args: PackedStringArray) -> NetOptions:
	var options: NetOptions = NetOptions.new()
	var index: int = 0
	while index < args.size():
		var arg: String = args[index]
		match arg:
			"--host":
				options.role = Role.HOST
			"--connect":
				options.role = Role.CLIENT
				index += 1
				if index < args.size():
					options.address = args[index]
			"--port":
				index += 1
				if index < args.size():
					options.port = args[index].to_int()
			"--latency":
				index += 1
				if index < args.size():
					options.latency_msec = maxi(0, args[index].to_int())
			"--loss":
				index += 1
				if index < args.size():
					options.loss = clampf(args[index].to_float(), 0.0, 1.0)
			"--seed":
				index += 1
				if index < args.size():
					options.rng_seed = args[index].to_int()
			"--label":
				index += 1
				if index < args.size():
					options.label = args[index]
			"--log-ticks":
				index += 1
				if index < args.size():
					options.log_ticks_interval = maxi(0, args[index].to_int())
		index += 1
	return options

func describe() -> String:
	var role_name: String = "hôte" if role == Role.HOST else "client"
	return "%s %s:%d latence=%dms perte=%.2f" % [role_name, address, port, latency_msec, loss]
