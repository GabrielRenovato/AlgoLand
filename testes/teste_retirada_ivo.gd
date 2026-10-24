# Rodar com save isolado (AlgoLand testes...): retirada da encomenda com o Ivo, marcador sobre ele e horário de atendimento.
extends SceneTree
var falhas := 0
func v(nome: String, ok: bool, det := "") -> void:
	print("OK " if ok else "FALHA ", nome, " ", det)
	if not ok: falhas += 1
func q(n := 6) -> void:
	for i in n: await process_frame
func _initialize() -> void: _rodar.call_deferred()
func _rodar() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")).begins_with("AlgoLand testes"):
		push_error("Use um save isolado AlgoLand testes.")
		quit(1)
		return
	await process_frame
	var cidade: Node = root.get_node("Cidade"); cidade.caminho_save = "user://teste_ivo_cidade.json"; cidade.apagar()
	var prog: Node = root.get_node("Progresso"); prog.caminho_save = "user://teste_ivo_progresso.json"; prog.apagar()
	root.get_node("Introducao").pular_prologo()
	var inv: Node = root.get_node("InventarioJogador"); inv.limpar(); inv.criar_itens_iniciais()
	var vila: Node = load("res://cenas/cidade.tscn").instantiate(); root.add_child(vila); current_scene = vila
	await q(10)
	vila.get_node("Iluminacao").definir_hora(12.0); vila.get_node("Iluminacao").set_process(false)
	var dados: GDScript = load("res://codigo/cidade/dados_cidade.gd")
	var calendario: Node = root.get_node("Calendario")
	var folga: int = int(dados.FOLGAS["ferreiro"])
	while calendario.dia_da_semana() == folga: calendario.dia += 1
	var interface: Node = vila.get_node("Interface")
	var tela: Control = interface._telas["conversa_cidade"]
	var tipo := "arco_curto"
	# 1) em fabricação
	prog.encomenda_forja = {"tipo":tipo,"dia_inicio":calendario.dia,"dia_pronto":calendario.dia+2,"jogador":1,"materiais":{}}
	cidade.conversar("ferreiro"); await q()
	v("em fabricação: abre direto no andamento", tela._submenu == "encomenda_forja" and "Fica pronto em 2 dias" in tela._fala.text, tela._fala.text)
	v("em fabricação: não oferece retirar", not tela._botoes.any(func(b): return b.text.begins_with("RETIRAR")))
	interface._fechar_tela("conversa_cidade"); await q(3)
	# 2) pronta, aberto
	prog.encomenda_forja.dia_pronto = calendario.dia
	cidade.conversar("ferreiro"); await q()
	var botao = tela._botoes.filter(func(b): return b.text.begins_with("RETIRAR"))
	v("pronta: oferece RETIRAR com o nome da arma", botao.size() == 1 and "Quer retirar" in tela._fala.text, str(tela._botoes.map(func(b): return b.text)))
	# marcador sobre o Ivo
	var ivo: Node = null
	for m in get_nodes_in_group("moradores_cidade"):
		if m.id == "ferreiro": ivo = m
	var ind = ivo.get_node_or_null("IndicadorPedido") if ivo != null else null
	if ind != null: ind._atualizar()
	v("pronta: marcador com ícone da arma sobre o Ivo", ind != null and ind.visible and ind._icone_encomenda.visible and ind._icone_encomenda.texture != null and not ind._rotulo.visible)
	interface._fechar_tela("conversa_cidade"); await q(3)
	cidade.conversar("ferreiro"); await q()
	botao = tela._botoes.filter(func(b): return b.text.begins_with("RETIRAR"))
	botao[0].pressed.emit(); await q()
	v("retirada conclui a encomenda e libera o modelo", prog.encomenda_forja.is_empty() and prog.arma_liberada(tipo))
	v("entrega a arma na mochila", tela._fala.text.begins_with("Aqui esta") or "mochila" in tela._fala.text, tela._fala.text)
	if ind != null: ind._atualizar(); v("marcador some depois de retirar", not ind._icone_encomenda.visible)
	interface._fechar_tela("conversa_cidade"); await q(3)
	# 3) pronta, mas fechado
	prog.armas_liberadas.erase(tipo); prog.armas_fabricadas.erase(tipo)
	prog.encomenda_forja = {"tipo":tipo,"dia_inicio":calendario.dia-2,"dia_pronto":calendario.dia,"jogador":1,"materiais":{}}
	vila.get_node("Iluminacao").definir_hora(21.0)
	cidade.conversar("ferreiro"); await q()
	v("fechado: avisa o horário e não oferece retirar", "Volte no meu horario" in tela._fala.text and not tela._botoes.any(func(b): return b.text.begins_with("RETIRAR")), tela._fala.text)
	interface._fechar_tela("conversa_cidade"); await q(3)
	# 4) sem encomenda: conversa normal
	prog.encomenda_forja = {}
	cidade.conversar("ferreiro"); await q()
	v("sem encomenda: conversa normal", tela._submenu == "")
	print("FALHAS: ", falhas); quit(falhas)
