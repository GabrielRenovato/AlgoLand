extends SceneTree
var falhas := 0
func _initialize() -> void: _rodar.call_deferred()
func verificar(nome: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ",nome)
	if not ok: falhas += 1
func quadros(n := 6) -> void:
	for i in n: await process_frame
func _rodar() -> void:
	if not String(ProjectSettings.get_setting("application/config/custom_user_dir_name","")).begins_with("AlgoLand testes"):
		quit(1)
		return
	root.get_node("Saves").trocar("coop")
	root.get_node("Introducao").pular_prologo()
	var fazenda: Node = root.get_node("Fazenda")
	fazenda._zerar()
	for nome in ["InventarioJogador","InventarioJogador2"]:
		root.get_node(nome).limpar()
		root.get_node(nome).criar_itens_iniciais()
	var coop: Node = root.get_node("Cooperativo")
	coop.dispositivo_p1 = coop.SEM_CONTROLE
	coop.dispositivo_p2 = 40
	coop._reconfigurar_entrada()
	change_scene_to_file("res://cenas/praia.tscn")
	await quadros(40)
	var p1: Node = coop._jogador1()
	var p2: Node = coop.jogador2()
	var inv1: Node = root.get_node("InventarioJogador")
	var inv2: Node = root.get_node("InventarioJogador2")
	verificar("captura cria item na mochila do dono",fazenda.pescar("sardinha",false,p1,0) and inv1.quantidade_peixes("sardinha")==1 and inv2.quantidade_peixes()==0)
	fazenda.pescar("sardinha",false,p1,0)
	fazenda.pescar("sardinha",true,p1,2)
	fazenda.pescar("sardinha",false,p2,1)
	var pilhas := []
	for item in inv1.mochila:
		if item != null and item.categoria=="peixe": pilhas.append(item)
	verificar("empilha mesma espécie e qualidade, separa qualidade diferente",pilhas.size()==2 and pilhas[0].quantidade==2 and pilhas[1].qualidade==2)
	verificar("P2 guarda peixes próprios",inv2.quantidade_peixes()==1 and fazenda.total_de_peixes(p1)==3 and fazenda.total_de_peixes(p2)==1)
	var valor: int = fazenda.valor_dos_peixes("sardinha",p1)
	verificar("qualidade melhora preço",valor==11)
	inv1.salvar()
	inv1.carregar()
	verificar("save mantém espécie, pilha e qualidade",inv1.quantidade_peixes()==3 and inv1.mochila.any(func(i): return i != null and i.categoria=="peixe" and i.qualidade==2))
	verificar("gasta qualidade normal primeiro",fazenda.gastar_peixes("sardinha",2,p1) and inv1.quantidade_peixes()==1 and inv1.mochila.any(func(i): return i != null and i.categoria=="peixe" and i.qualidade==2))
	var historico: Dictionary = fazenda.peixes_pescados.duplicate()
	verificar("venda do P2 não usa peixes do P1",fazenda.vender_peixes("sardinha",p2)==4 and inv2.quantidade_peixes()==0 and inv1.quantidade_peixes()==1 and fazenda.peixes_pescados==historico)
	fazenda.peixes = {"carpa":7}
	fazenda.migrar_peixes_antigos()
	verificar("migração do contador antigo preserva os peixes",fazenda.peixes.is_empty() and inv1.quantidade_peixes("carpa")==7)
	var tipo_item: GDScript = load("res://codigo/modelos/dados_item.gd")
	var arco = inv1._criar_item({"tipo":"arco_curto","categoria":"arma","duas_maos":true})
	arco.nivel = 5
	inv1.adicionar(arco)
	var escudo = inv1._criar_item({"tipo":"escudo_basico","categoria":"escudo","duas_maos":false})
	escudo.nivel = 5
	inv1.adicionar(escudo)
	inv1.adicionar_sementes("batata",9)
	inv1.moedas_forja = 4
	inv1.reiniciar_equipamento_da_partida()
	verificar("encerrar descarta saque temporário",inv1.indice_de(arco)==-1 and inv1.indice_de(escudo)==-1 and inv1.buscar_por_tipo("escudo_basico").nivel==1)
	verificar("encerrar preserva peixes, sementes e moedas permanentes",inv1.quantidade_peixes()==8 and inv1.quantidade_sementes("batata")==9 and inv1.moedas_forja==4)
	var sessao_script: GDScript = load("res://codigo/pesca/sessao_pesca.gd")
	var s1: Node = sessao_script.new()
	var s2: Node = sessao_script.new()
	s1.iniciar(p1,Vector2.RIGHT,"mar")
	s2.iniciar(p2,Vector2.LEFT,"mar")
	s1.peixe = "anchova"
	s2.peixe = "carpa"
	s1._pegar()
	s2._pegar()
	var total1: int = inv1.quantidade_peixes()
	root.get_node("Controle").vetor_toque = Vector2.RIGHT
	s1._process(0.2)
	root.get_node("Controle").vetor_toque = Vector2.ZERO
	verificar("toque de movimento cancela comemoração sem perder peixe",s1.is_queued_for_deletion() and p1.movimento_habilitado and inv1.quantidade_peixes()==total1)
	verificar("movimento do P1 mantém comemoração do P2",not s2.is_queued_for_deletion() and not p2.movimento_habilitado)
	Input.action_press("p2_move_right")
	s2._process(0.2)
	Input.action_release("p2_move_right")
	verificar("controle do P2 cancela apenas sua comemoração",s2.is_queued_for_deletion() and p2.movimento_habilitado)
	await quadros()
	verificar("compositor e animação voltam após comemoração",p1.get_node("CompositeSprites").visible and p1._arvore_animacao.active and not p1.has_node("SessaoPesca"))
	var ui: Node = root.get_node("EventosJogo").interface_p1()
	ui._abrir_tela("inventario")
	await create_timer(0.3).timeout
	var slot: Control
	for casa in ui._telas["inventario"]._slots_mochila:
		if casa.item_atual != null and casa.item_atual.categoria=="peixe" and casa.item_atual.qualidade==2: slot=casa
	var dica: Control = slot.item_ui().tooltip_do_item() if slot != null else null
	verificar("peixe com qualidade usa estrela nativa e tooltip do item",slot != null and slot.item_ui()._estrela_qualidade.visible and dica.find_children("*","Label",true,false).any(func(rotulo): return rotulo.text.contains("OURO")))
	if dica != null: dica.free()
	print("FALHAS: ",falhas)
	quit(1 if falhas else 0)
