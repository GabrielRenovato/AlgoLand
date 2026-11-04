extends SceneTree
## Missões secundárias da vila, recompensas só em ouro/materiais, descanso, reações e HUD sem Brasas.
## Precisa de janela (como teste_percurso_campanha.gd) e apaga o save isolado do percurso ao começar.
const PASTA := "user://percurso_primeira_raiz"
var falhas := 0
var cena: Node2D
var ultimo_texto := ""

func _initialize() -> void: rodar.call_deferred()

func verificar(nome: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ", nome)
	if not ok: falhas += 1

func quadros(n := 8) -> void:
	for i in n:
		await process_frame
		await physics_frame

func apagar(caminho: String) -> void:
	var dir := DirAccess.open(caminho)
	if dir == null: return
	for arquivo in dir.get_files(): DirAccess.remove_absolute(caminho.path_join(arquivo))
	for sub in dir.get_directories(): apagar(caminho.path_join(sub))
	DirAccess.remove_absolute(caminho)

## Fecha a fala aberta; diante de opções escolhe a última ("Agora não").
func fechar_fala() -> void:
	var d = cena.interface._telas.introducao
	for i in 8:
		if not d.visible: break
		if not d._opcoes.is_empty():
			d._fechar_fala()
			await quadros(30)
			d._caixa_opcoes.get_child(d._opcoes.size() - 1).pressed.emit()
		else:
			d._fechar_fala()
		await quadros(15)

func falar(id: String) -> Error:
	var erro: Error = cena._conversar_morador(id)
	await quadros(25)
	ultimo_texto = cena.interface._telas.introducao._texto.text
	await fechar_fala()
	await quadros(10)
	return erro

func interagir_estrada(id: String) -> Error:
	cena.jogador.position = cena.alvos[id].no.position
	cena.jogador.velocity = Vector2.ZERO
	await quadros(3)
	var erro: Error = cena.interagir_proximo()
	await quadros(25)
	await fechar_fala()
	await quadros(10)
	return erro

func objetivos(missao: String) -> Array:
	return cena.controlador.progresso.objetivos_cumpridos(missao)

func rodar() -> void:
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes") or DisplayServer.get_name() == "headless":
		quit(1); return
	root.mode = Window.MODE_WINDOWED
	root.content_scale_size = Vector2i(576, 324)
	root.size = Vector2i(1152, 648)
	apagar(PASTA)
	# Save pronto até o fim do acolhimento, como depois da recepção completa.
	var c = load("res://codigo/campanha/controlador_campanha.gd").new()
	verificar("save de teste inicia", c.iniciar(PASTA, "prototipo") == OK)
	var catalogo: Dictionary = load("res://codigo/campanha/catalogo_campanha.gd").dados()
	for missao in ["sobreviver_queda", "estrada_interrompida", "acolhimento"]:
		for o in catalogo.missoes[missao].objetivos:
			var erro: Error = c.progresso.registrar_preparo("ligacao_raiz") if o.id == "oficio" else c.progresso.registrar_objetivo(missao, o.id)
			if erro != OK: verificar("preparar %s:%s" % [missao, o.id], false)
	c = null
	set_meta("campanha_nova_instancia", false)
	change_scene_to_file("res://cenas/campanha/percurso_prototipo.tscn")
	await quadros(50)
	cena = current_scene
	verificar("vila abre depois do acolhimento", cena.abrir_regiao("vila", false) == OK)
	await quadros(40)
	cena.registro_run.apresentada = true ## o relatório da região não deve abrir por cima das falas
	var progresso = cena.controlador.progresso
	var ouro_antes: int = root.get_node("DadosJogo").moedas
	var brasas_antes: int = int(root.get_node("Progresso").brasas)
	var forja_antes: int = cena.jogador.inventario.quantidade_tipo("material:moeda_forja")
	var inv = cena.jogador.inventario

	verificar("HUD da campanha esconde as Brasas", not cena.hud.rotulo_brasas.visible)
	verificar("HUD da campanha esconde a moeda de forja", not cena.hud.rotulo_moeda_forja.visible)
	verificar("HUD da campanha mantém o ouro", cena.hud.rotulo_moedas.is_visible_in_tree())

	# Banco de descanso perto de Lia
	cena.jogador.hp_atual = 1
	cena.jogador.position = cena.alvos["descanso"].no.position
	await quadros(3)
	verificar("banco de descanso é interagível", cena.interagir_proximo() == OK)
	verificar("descanso recupera a vida", int(cena.jogador.hp_atual) == int(cena.jogador.estatisticas.hp_maximo))

	# Pedidos e etapas
	verificar("pedido de Ivo ainda não existe", not "pedido" in objetivos("ferro_que_ainda_serve"))
	await falar("ivo")
	verificar("Ivo abre o pedido das ferragens", "pedido" in objetivos("ferro_que_ainda_serve") and ultimo_texto.to_lower().contains("ferro"))
	await falar("rosa")
	verificar("Rosa abre o pedido dos suprimentos", "pedido" in objetivos("quem_ficou_para_tras"))
	await falar("dara")
	verificar("Dara abre o pedido do treino", "pedido" in objetivos("antes_de_sair_outra_vez"))
	verificar("conversar com Dara não conclui o treino", not "treino" in objetivos("antes_de_sair_outra_vez"))

	# Estrada: ferragens e suprimentos
	verificar("estrada abre", cena.abrir_regiao("estrada", false) == OK)
	await quadros(40)
	await interagir_estrada("carreto")
	verificar("carreto entrega as ferragens", "ferragens" in objetivos("ferro_que_ainda_serve"))
	await interagir_estrada("trabalhador")
	verificar("trabalhador recebe os suprimentos", "suprimentos" in objetivos("quem_ficou_para_tras"))

	# Volta à vila e fecha as missões
	verificar("vila reabre", cena.abrir_regiao("vila", false) == OK)
	await quadros(40)
	await falar("ivo")
	verificar("Ivo conclui o ferro", progresso.missao_concluida("ferro_que_ainda_serve"))
	await falar("rosa")
	verificar("Rosa conclui o relato", progresso.missao_concluida("quem_ficou_para_tras"))
	cena._iniciar_treino()
	await quadros(4)
	cena._treino.encerrar(true)
	await quadros(30)
	await fechar_fala()
	verificar("treino concluído fecha a missão de Dara", progresso.missao_concluida("antes_de_sair_outra_vez"))
	await quadros(20)

	# Recompensas só em ouro, materiais, poções e receita
	verificar("recibos gravados para as três missões", progresso.recompensas.size() == 3)
	verificar("ouro das três missões chegou", root.get_node("DadosJogo").moedas == ouro_antes + 125)
	verificar("minério e madeira de Ivo chegaram", inv.quantidade_tipo("material:ferro") >= 3 and inv.quantidade_tipo("material:madeira") >= 2)
	verificar("curativos de Rosa chegaram", inv.quantidade_tipo("pocao:cura") >= 2)
	verificar("receita de Ivo chegou", inv.quantidade_tipo("receita:luvas_basicas") >= 1)
	verificar("nenhuma Brasa nem moeda de forja foi paga", int(root.get_node("Progresso").brasas) == brasas_antes and inv.quantidade_tipo("material:moeda_forja") == forja_antes)

	# Persistência e entrega única
	var novo = load("res://codigo/campanha/controlador_campanha.gd").new()
	verificar("save reabre com os recibos", novo.iniciar(PASTA, "prototipo") == OK and novo.progresso.recompensas.size() == 3)
	var ouro_depois: int = root.get_node("DadosJogo").moedas
	cena._conferir_missoes()
	await quadros(10)
	verificar("recompensa não é entregue duas vezes", root.get_node("DadosJogo").moedas == ouro_depois)

	# Reação da vila na segunda conversa
	await falar("lia")
	await falar("lia")
	verificar("Lia comenta o banco de descanso na segunda conversa", ultimo_texto.to_lower().contains("banco"))

	print("FALHAS: ", falhas)
	apagar(PASTA)
	quit(1 if falhas > 0 else 0)
