extends SceneTree
var falhas := 0
class Alvo extends Node2D:
	var esta_morto := false
	var ultimo_dano := 0
	var ultima_forca := 0.0
	var atordoado := 0.0
	func receber_dano(dano: int, forca: Vector2) -> void:
		ultimo_dano = dano
		ultima_forca = forca.length()
	func atordoar(tempo: float) -> void: atordoado = tempo
func _initialize() -> void: rodar.call_deferred()
func verificar(nome: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ",nome)
	if not ok: falhas += 1
func quadros() -> void:
	for i in 10: await process_frame
func rodar() -> void:
	await process_frame
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"): quit(1); return
	root.get_node("Introducao").pular_prologo()
	var inv = root.get_node("InventarioJogador")
	inv.limpar()
	inv.criar_itens_iniciais()
	inv.adicionar_arma_nova("maca")
	change_scene_to_file("res://cenas/cenario.tscn")
	await quadros()
	current_scene.get_node("enemySpawner/GerenciadorOndas").parar_ondas()
	var jogador = current_scene.get_node("Jogador")
	jogador.troca_sem_pose = true
	var alvo := Alvo.new()
	current_scene.add_child(alvo)
	alvo.global_position = jogador.global_position+Vector2(20,0)
	jogador.estatisticas.dano_ataque = 100
	jogador.estatisticas.chance_critico = 0.0
	jogador.contragolpe_ate_ms = Time.get_ticks_msec()+3000
	seed(8)
	jogador.aplicar_golpe(alvo,Vector2.RIGHT)
	var contra: int = alvo.ultimo_dano
	seed(8)
	jogador.aplicar_golpe(alvo,Vector2.RIGHT)
	verificar("contragolpe aumenta dano uma vez",contra > alvo.ultimo_dano and jogador.contragolpe_ate_ms == 0)
	inv.equipar(inv.buscar_por_tipo("maca"))
	jogador._fase_combo = 3
	jogador.aplicar_golpe(alvo,Vector2.RIGHT)
	verificar("maça atordoa no combate real",is_equal_approx(alvo.atordoado,0.35) and alvo.ultima_forca >= 225)
	var disparo := {"tipo":"arco_longo","distancia":200.0,"golpe":{"dano":100,"critico":false},"forca":0.0}
	jogador.aplicar_golpe(alvo,Vector2.RIGHT,1.0,1.0,disparo)
	verificar("flecha conserva especialidade e dano após troca de arma",alvo.ultimo_dano == 115)
	print("FALHAS: ",falhas)
	quit(falhas)
