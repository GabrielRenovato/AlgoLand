extends SceneTree

class GerenteTeste extends Node:
	var onda_atual := 1
	var inimigos_vivos := 1
	var onda_bonus := false

var falhas := 0
func _initialize() -> void: rodar.call_deferred()
func verificar(nome: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ", nome)
	if not ok: falhas += 1
func rodar() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("AlgoLand testes"):
		quit(1)
		return
	await process_frame
	root.get_node("Introducao").pular_prologo()
	root.get_node("Progresso").apagar()
	root.get_node("InventarioJogador").limpar()
	root.get_node("InventarioJogador2").limpar()
	var drop = load("res://codigo/logica/equipamento_drop.gd")
	var palco := Node2D.new()
	root.add_child(palco)
	var inimigo = load("res://testes/apoio/inimigo_receita.gd").new()
	palco.add_child(inimigo)
	var rng := RandomNumberGenerator.new()
	rng.seed = 18102026
	var taxas := []
	for caso in [{"nome":"comum","mutante":false,"chefe":false,"n":10000,"min":0.001,"max":0.0035},
		{"nome":"mutante","mutante":true,"chefe":false,"n":10000,"min":0.007,"max":0.014},
		{"nome":"chefe","mutante":false,"chefe":true,"n":2000,"min":0.17,"max":0.23}]:
		inimigo.eh_mutante = caso.mutante
		var quantidade := 0
		var somente_receitas := true
		for i in caso.n:
			var objeto: Node2D = drop.soltar_de(inimigo,palco,rng,1,caso.chefe)
			if objeto == null: continue
			quantidade += 1
			somente_receitas = somente_receitas and objeto.item.categoria == "receita"
			objeto.free()
		var taxa: float = float(quantidade)/float(caso.n)
		taxas.append(taxa)
		print("Taxa real ",caso.nome,": ",quantidade,"/",caso.n)
		verificar("frequencia rara para " + caso.nome, taxa >= caso.min and taxa <= caso.max and somente_receitas)
	verificar("mutantes e chefes continuam mais valiosos",taxas[0]<taxas[1] and taxas[1]<taxas[2])
	# Exercita o callback real do último abate: só o fragmento permanece garantido.
	inimigo.eh_mutante = false
	var gerador = load("res://codigo/logica/slime_spawner.gd").new()
	var gerente := GerenteTeste.new()
	gerador.principal = palco
	gerador.gerenciador_ondas = gerente
	gerador._rng_equipamentos.seed = 18102026
	while true:
		var estado: int = gerador._rng_equipamentos.state
		if gerador._rng_equipamentos.randf() >= drop.chance(false,false):
			gerador._rng_equipamentos.state = estado
			break
	gerador._soltar_equipamento(inimigo)
	var objetos := get_nodes_in_group("equipamento_drop")
	verificar("ultimo abate nao cria receita garantida",objetos.size()==1 and objetos[0].item.tipo=="material:fragmento")
	gerador.free()
	gerente.free()
	palco.queue_free()
	await process_frame
	print("Frequencia receitas: %d falhas" % falhas)
	quit(1 if falhas else 0)
