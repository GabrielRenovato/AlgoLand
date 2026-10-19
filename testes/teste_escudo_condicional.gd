extends SceneTree

## Combate real, lotação, persistência e aparência com save isolado.
var Modelo: GDScript
const Forja := preload("res://codigo/dados/forja_armas.gd")
var _falhas := 0

func _initialize() -> void:
	_rodar()

func _verificar(nome: String, passou: bool) -> void:
	print("OK " if passou else "FALHA ", nome)
	if not passou: _falhas += 1

func _quadros() -> void:
	for i in 4: await process_frame

func _capturar(nome: String) -> void:
	if not "--capturar" in OS.get_cmdline_user_args(): return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/algoland-equipamento-%s.png" % nome)

func _rodar() -> void:
	await process_frame
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"):
		push_error("Use save isolado AlgoLand testes.")
		quit(1)
		return
	root.mode = Window.MODE_WINDOWED
	root.content_scale_size = Vector2i(576, 324)
	root.size = Vector2i(1152, 648)
	Modelo = load("res://codigo/modelos/modelo_inventario.gd")
	var inv = root.get_node("InventarioJogador")
	inv.limpar()
	inv.criar_itens_iniciais()
	inv.equipados.escudo.afixos = {"vitalidade": 2.0, "velocidade": 4.0}
	for tipo in ["lanca_basica", "arco_curto", "aljava_basica"]:
		inv.adicionar_arma_nova(tipo)
	var aljava = inv.buscar_por_tipo("aljava_basica")
	var casa_aljava: int = inv.indice_de(aljava)
	inv.equipar(aljava)
	_verificar("aljava equipada libera casa e não reserva espaço", inv.item_na_celula(casa_aljava) == null and inv.indice_de(aljava) == -1 and not inv.casa_reservada(casa_aljava))
	var cena = load("res://cenas/cenario.tscn").instantiate()
	root.add_child(cena)
	current_scene = cena
	await _quadros()
	cena.get_node("enemySpawner/GerenciadorOndas").parar_ondas()
	var jogador = cena.get_node("Jogador")
	jogador.troca_sem_pose = true
	var espada = inv.equipados.arma
	var escudo = inv.equipados.escudo
	var lanca = inv.buscar_por_tipo("lanca_basica")
	var arco = inv.buscar_por_tipo("arco_curto")
	var pacote: Dictionary = jogador._pacote_do_item(escudo)
	var defesa: int = jogador.bonus_defesa
	var vitalidade: int = jogador.bonus_vitalidade
	var textura_escudo = jogador.sprite_escudo.texture
	_verificar("espada ativa bônus e animação de escudo", jogador.usando_escudo and jogador._escudo_aplicado == escudo and int(pacote.defesa) > 0)
	jogador._tocar_pose("aparar")
	_verificar("pose de espada inclui escudo", jogador.no_reacao._escudo.visible)
	await _capturar("espada")
	jogador.no_reacao.encerrar()
	# Toda a mochila pode encher sem impedir troca para duas mãos.
	while inv.tem_espaco(): inv.adicionar(Forja.criar_item("botas_basicas"))
	for i in 3:
		_verificar("troca para lança com mochila cheia %d" % i, inv.equipar(lanca))
		await _quadros()
		_verificar("lança suspende todos os bônus sem tirar escudo do slot %d" % i, inv.equipados.escudo == escudo and not jogador.usando_escudo and jogador.bonus_defesa == defesa - int(pacote.defesa) and jogador.bonus_vitalidade == vitalidade - int(pacote.vitalidade) and not jogador.sprite_escudo.visible and jogador._pacote_aplicado.escudo == jogador._pacote_do_item(null))
		_verificar("volta para espada com mochila cheia %d" % i, inv.equipar(espada))
		await _quadros()
		_verificar("espada restaura bônus uma única vez %d" % i, jogador.usando_escudo and jogador.bonus_defesa == defesa and jogador.bonus_vitalidade == vitalidade and jogador.sprite_escudo.texture == textura_escudo)
	inv.equipar(lanca)
	await _quadros()
	jogador._tocar_pose("aparar")
	_verificar("pose de lança omite escudo", not jogador.no_reacao._escudo.visible)
	await _capturar("lanca")
	jogador.no_reacao.encerrar()
	inv.equipar(arco)
	await _quadros()
	_verificar("arco mantém aljava e escudo equipado inativo", jogador.usando_arco and not jogador.usando_escudo and inv.equipados.escudo == escudo and inv.equipados.secundaria == aljava and jogador.sprite_escudo.texture == preload("res://codigo/dados/objetos_refinados.gd").textura(jogador.TEXTURA_ALJAVA))
	jogador.atualizar_texturas_escudo()
	_verificar("atualização de escudo inativo preserva sprite da aljava", jogador.sprite_escudo.texture == preload("res://codigo/dados/objetos_refinados.gd").textura(jogador.TEXTURA_ALJAVA))
	jogador._tocar_pose("aparar")
	_verificar("pose de arco omite escudo", not jogador.no_reacao._escudo.visible)
	await _capturar("arco")
	jogador.no_reacao.encerrar()
	inv.salvar("user://escudo_condicional.json")
	var copia = Modelo.new()
	copia.carregar("user://escudo_condicional.json")
	_verificar("save conserva escudo fora da mochila e inativo com arco", copia.equipados.escudo != null and copia.equipados.secundaria != null and not copia.escudo_ativo() and copia.celulas_da_mao.escudo == -1)
	copia.free()
	# Saves legados reservavam casa para o escudo; a migração libera só essa casa.
	var legado: Dictionary = inv.dados_save()
	legado.mao = {"arma": inv.celulas_da_mao.arma, "escudo": 23}
	legado.mochila[23] = null
	Modelo.gravar_dados("user://escudo_legado.json", legado)
	copia = Modelo.new()
	copia.carregar("user://escudo_legado.json")
	_verificar("migração libera reserva antiga e preserva itens equipados", copia.equipados.escudo.tipo == escudo.tipo and copia.equipados.arma.tipo == arco.tipo and copia.item_na_celula(23) == null and not copia.casa_reservada(23))
	copia.free()
	inv.equipar(espada)
	await _quadros()
	var tela = cena.get_node("Interface/TelaInventario")
	cena.get_node("Interface")._abrir_tela("inventario")
	await create_timer(0.5).timeout
	tela._atualizar()
	await _quadros()
	_verificar("interface oferece escudo e aljava sem slot de arma", tela._slots_equipamento.has("escudo") and tela._slots_equipamento.has("secundaria") and not tela._slots_equipamento.has("arma"))
	await _capturar("mochila")
	root.get_node("Controle").usando_toque = true
	root.content_scale_size = Vector2i(288, 216)
	root.size = Vector2i(864, 648)
	await _quadros()
	tela.ajustar_largura(216.0)
	await create_timer(0.5).timeout
	await _capturar("mochila-mobile")
	print("FALHAS: ", _falhas)
	quit(1 if _falhas else 0)
