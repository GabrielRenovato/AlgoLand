extends SceneTree
## Pescarias consecutivas no mesmo lugar, inclusive ao esgotar as casas da mochila.

var falhas := 0
var verificacoes := 0
var jogador: Node2D
var inventario: Node

class Avisos extends Node:
	var ultimo := ""
	func avisar_barra(texto: String): ultimo=texto

func _initialize(): rodar.call_deferred()
func quadros(n:=5):
	for i in n:
		await process_frame
		await physics_frame
func conferir(ok: bool, texto: String):
	verificacoes+=1
	if not ok:
		falhas+=1
		push_error(texto)
func rodar():
	var Ponto = load("res://codigo/pesca/ponto_pesca.gd")
	assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
	root.get_node("Ranking").conexao_habilitada=false
	root.get_node("Introducao").pular_prologo()
	root.get_node("Transicao").hora_salva=12.0
	inventario=root.get_node("InventarioJogador")
	inventario.limpar()
	inventario.criar_itens_iniciais()
	change_scene_to_file("res://cenas/praia.tscn")
	await quadros(40)
	jogador=current_scene.get_node("Jogador")
	var ponto=current_scene.get_node("PescaPierLeste")
	jogador.global_position=ponto.global_position
	jogador.set_physics_process(false)
	inventario.definir_vara_na_mao(true)
	var avisos:=Avisos.new()
	root.add_child(avisos)
	avisos.add_to_group(jogador.grupo_hud())
	# Deixa três casas livres: cada qualidade ocupa uma casa diferente.
	var livres: Array[int]=[]
	for i in inventario.capacidade():
		if inventario.item_na_celula(i)==null: livres.append(i)
	for i in range(livres.size()-3):
		inventario.mochila[livres[i]]=preload("res://codigo/dados/forja_armas.gd").criar_item("espada_basica")
	await quadros()
	var posicao: Vector2=jogador.global_position
	for qualidade in 3:
		conferir(Ponto.tentar_lancar(jogador),"Lança novamente no mesmo ponto: %d"%qualidade)
		var sessao=jogador.get_node_or_null("SessaoPesca")
		if sessao==null: quit(1); return
		sessao.peixe="sardinha"
		sessao.qualidade_peixe=qualidade
		sessao._pegar()
		sessao._terminar()
		await quadros()
		conferir(jogador.global_position==posicao and jogador.movimento_habilitado and not jogador.ataques_bloqueados,"Captura restaura jogador sem deslocar: %d"%qualidade)
	conferir(not inventario.tem_espaco(),"Capturas esgotaram as casas vazias")
	avisos.ultimo=""
	conferir(Ponto.tentar_lancar(jogador),"Mochila sem casas vazias ainda permite pescar para empilhar")
	var sessao=jogador.get_node_or_null("SessaoPesca")
	if sessao==null:
		push_error("REPRODUZIDO: "+avisos.ultimo)
		quit(1)
		return
	sessao.peixe="sardinha"
	sessao.qualidade_peixe=0
	var antes: int=inventario.quantidade_peixes("sardinha")
	sessao._pegar()
	conferir(inventario.quantidade_peixes("sardinha")==antes+1,"Peixe igual entra na pilha existente")
	sessao._terminar()
	await quadros()
	conferir(Ponto.tentar_lancar(jogador),"Nova tentativa continua disponível após empilhar")
	sessao=jogador.get_node("SessaoPesca")
	sessao.peixe="anchova"
	sessao._pegar()
	conferir(avisos.ultimo=="MOCHILA CHEIA", "Captura sem espaço explica o motivo verdadeiro")
	conferir(inventario.quantidade_peixes("anchova")==0,"Sem espaço não concede nem duplica peixe")
	await quadros()
	conferir(not jogador.has_node("SessaoPesca") and jogador.movimento_habilitado,"Falha de captura encerra sessão e devolve movimento")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/pesca-mochila-cheia.png")
	# Fora da zona continua sendo inválido, mesmo com a vara selecionada.
	jogador.global_position=Vector2(100,100)
	await quadros()
	avisos.ultimo=""
	conferir(not Ponto.tentar_lancar(jogador) and avisos.ultimo=="APROXIME-SE DA AGUA PARA LANCAR","Só a ausência de água usa o aviso de aproximação")
	print("PESCA REPETIDA: %d verificações, %d falhas"%[verificacoes,falhas])
	current_scene.queue_free()
	await quadros()
	quit(1 if falhas else 0)
