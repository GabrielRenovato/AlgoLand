extends SceneTree
var falhas := 0
var cena: Node2D
var esperado := 0
func _initialize():rodar.call_deferred()
func verificar(nome: String, ok: bool):
	print("OK " if ok else "FALHA ",nome)
	if not ok:falhas+=1
func quadros(n := 8):
	for i in n:await process_frame;await physics_frame
func foto(nome: String):
	await RenderingServer.frame_post_draw
	verificar("captura "+nome,root.get_texture().get_image().save_png("res://capturas-interface-campanha/"+nome+".png")==OK)
func abater(no: Node):
	no.set_physics_process(false)
	var vida: int=no.vida
	esperado+=vida
	cena.jogador.aplicar_golpe(no,Vector2.ZERO,1,1,{"tipo":"espada_basica","golpe":{"dano":99999,"critico":false},"evento_maestria":cena.jogador.maestria.novo_evento(),"especial":true})
	no._physics_process(3.1)
func pular():
	for no in cena.get_children():
		if no.has_method("pular") and no.get("ativa"):no.pular()
	await quadros(5)
func rodar():
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes") or DisplayServer.get_name()=="headless":quit(1);return
	DirAccess.make_dir_recursive_absolute("res://capturas-interface-campanha")
	var p=load("res://codigo/campanha/progresso_campanha.gd").new()
	p.iniciar("user://percurso_primeira_raiz","prototipo")
	var catalogo=load("res://codigo/campanha/catalogo_campanha.gd").dados()
	for m in ["sobreviver_queda","estrada_interrompida","acolhimento","pomar_sulcos"]:
		for o in catalogo.missoes[m].objetivos:p.registrar_objetivo(m,o.id)
	root.mode=Window.MODE_WINDOWED;root.content_scale_size=Vector2i(576,324);root.size=Vector2i(1152,648)
	set_meta("campanha_mapa_regional",true)
	change_scene_to_file("res://cenas/campanha/seletor_campanha.tscn");await quadros(30)
	current_scene.selecionar("chegada")
	for medida in [Vector2i(576,324),Vector2i(288,512),Vector2i(320,324)]:
		root.content_scale_size=medida;root.size=medida*2;await quadros(6)
		await foto("mapa-%d" % medida.x)
	root.content_scale_size=Vector2i(576,324);root.size=Vector2i(1152,648)
	current_scene.jogar_solo();await quadros(80);cena=current_scene
	await pular()
	var r: Node=cena.registro_run;r.set_process(false)
	var j: Node=cena.jogador;j.invulneravel=true
	# As demais telas da campanha usam o mesmo acabamento, com layouts próprios.
	for nome in ["inventario","maestria","pausa","forja","mercante"]:
		cena.interface._abrir_tela(nome);await quadros(18)
		verificar("abre tela "+nome,nome in cena.interface._telas_abertas)
		for medida in [Vector2i(576,324),Vector2i(288,512),Vector2i(320,324)]:
			root.content_scale_size=medida;root.size=medida*2;await quadros(20)
			var painel: Control=cena.interface._paineis[nome]
			verificar("painel cabe "+nome+str(medida),Rect2(Vector2.ZERO,Vector2(medida)).grow(1).encloses(painel.get_global_transform_with_canvas()*Rect2(Vector2.ZERO,painel.size)))
			for b in cena.interface._telas[nome].find_children("*","Button",true,false):
				if b.is_visible_in_tree() and b.text=="X":
					verificar("fechar dentro da moldura "+nome,painel.get_global_rect().grow(-4).encloses(b.get_global_rect()))
			if nome=="forja":
				for b in cena.interface._telas[nome]._botoes.values():
					if not b.is_visible_in_tree():continue
					for rotulo in b.find_children("*","Label",true,false):
						if rotulo.is_visible_in_tree():verificar("texto da receita dentro do slot "+str(medida),b.get_global_rect().grow(-3).encloses(rotulo.get_global_rect()))
			await foto(nome+"-%d" % medida.x)
			if nome=="pausa":
				cena.interface._telas[nome]._botao_opcoes.pressed.emit();await quadros(12)
				await foto("opcoes-%d" % medida.x)
				cena.interface._telas[nome]._botao_voltar.pressed.emit();await quadros(6)
			if nome=="inventario":
				cena.interface._telas[nome]._rolagem.scroll_vertical=10000;await quadros(4)
				await foto("inventario-atributos-%d" % medida.x)
				cena.interface._telas[nome]._rolagem.scroll_vertical=0
		cena.interface._fechar_tela(nome);await quadros(4)
	root.content_scale_size=Vector2i(576,324);root.size=Vector2i(1152,648)
	var dialogo: Control=cena.interface._telas.introducao
	cena.interface._abrir_tela("introducao")
	var falas: Array[String]=["Você tem abrigo na Vila das Flores. Prepare seus equipamentos e siga a seta até o próximo objetivo."]
	dialogo.iniciar(falas,"Dara","")
	await quadros(90);await foto("dialogo-576")
	cena.interface._fechar_tela("introducao");await quadros(5)
	for regiao in ["chegada","estrada","vila","pomar"]:
		var carregamento=load("res://codigo/campanha/carregamento_campanha.gd").new();root.add_child(carregamento);carregamento.mostrar(regiao)
		carregamento._revelar.kill();carregamento._historia.visible_ratio=1.0
		for medida in [Vector2i(576,324),Vector2i(288,512),Vector2i(320,324)]:
			root.content_scale_size=medida;root.size=medida*2;await quadros(8)
			verificar("carregamento cabe "+regiao+str(medida),Rect2(Vector2.ZERO,Vector2(medida)).encloses(carregamento._caixa.get_global_rect()))
			verificar("historia sem corte "+regiao+str(medida),carregamento._historia.size.y>=carregamento._historia.get_line_count()*carregamento._historia.get_line_height())
			await foto("carregamento-"+regiao+"-%d" % medida.x)
		carregamento.queue_free();await quadros(2)
	root.content_scale_size=Vector2i(576,324);root.size=Vector2i(1152,648)

	for id in ["espada","escudo","resgate"]:verificar("objetivo inicial "+id,cena.controlador.progresso.registrar_objetivo("sobreviver_queda",id)==OK)
	cena._preparar_criatura();await quadros(4)
	var lista: Array=cena.rebentos_espalhados.duplicate();lista.append(cena.inimigo)
	for no in lista:abater(no)
	await quadros(4)
	verificar("registro inclui dano real e limita excesso",r.dados().grupo[0].dano==esperado)
	verificar("nao conclui entre ondas",not r.concluida and not cena.interface._telas.resultado.visible)
	cena.controlador.progresso.registrar_objetivo("sobreviver_queda","vestigios")
	verificar("inicia ondas reais",cena.encontro.iniciar()==OK)
	for onda in 3:
		cena.encontro._process(2.1)
		for no in cena.encontro.criaturas.duplicate():
			if is_instance_valid(no) and not no.esta_morto:abater(no)
		await quadros(2)
	cena.encontro._process(2.1)
	var boss: Node=cena.encontro.chefe
	verificar("boss real registrado",is_instance_valid(boss))
	boss.set_physics_process(false);boss._physics_process(2.3);boss._physics_process(4.3)
	abater(boss);await quadros(4)
	verificar("dano de todos os inimigos e boss exato",r.dados().grupo[0].dano==esperado)
	verificar("dezenove abates reais",r.dados().abates==19 and r.dados().grupo[0].abates==19)
	j.invulneravel=false
	var hp: int=j.hp_atual;j.receber_dano(8)
	verificar("vida perdida real registrada",r.dados().pessoal.recebido==hp-j.hp_atual)
	j.invulneravel=true
	for no in cena.saque_inicial._visiveis.values().duplicate():
		if is_instance_valid(no):no._tentar_pegar()
	await quadros(3)
	var dados: Dictionary=r.dados()
	verificar("saque do boss aparece com atributos reais",dados.drops.any(func(d):return d.item.raridade=="raro" and d.recolhido))
	verificar("maestria conquistada aparece",not dados.maestria.is_empty() and dados.maestria[0].xp>0)
	var xp: Dictionary=j.maestria.modelo.experiencia.duplicate()
	r._process(2.1);await quadros(6)
	verificar("resultado abre automaticamente ao limpar",cena.interface._telas_abertas==["resultado"] and not j.movimento_habilitado)
	var resultado: Control=cena.interface._telas.resultado
	for medida in [Vector2i(960,900),Vector2i(576,324),Vector2i(288,512),Vector2i(320,324)]:
		root.content_scale_size=medida;root.size=medida*2;await quadros(40)
		verificar("moldura cabe "+str(medida),Rect2(Vector2.ZERO,Vector2(medida)).encloses(resultado.painel.get_global_transform_with_canvas()*Rect2(Vector2.ZERO,resultado.painel.size)))
		for b in resultado.find_children("*","Button",true,false):
			verificar("botao dentro da moldura "+b.text,resultado.painel.get_global_rect().grow(-8).encloses(b.get_global_rect()))
		verificar("slots do saque mostram drops reais",resultado.slots.size()==dados.drops.size())
		if not resultado.slots.is_empty():
			resultado.slots[0].pressed.emit();await quadros(2)
			verificar("selecionar mostra nome real",resultado.detalhe_item.text==load("res://codigo/modelos/dados_item.gd").de_dict(dados.drops[0].item).nome().capitalize())
		await foto("resultado-%d" % medida.x)
		if resultado.abas!=null:
			for aba in [1,0]:
				resultado.abas.current_tab=aba;await quadros(4);await foto("resultado-aba-%d-%d" % [aba,medida.x])
		if medida.x<700:
			resultado.rolagem.scroll_vertical=10000;await quadros(4);await foto("resultado-fim-%d" % medida.x)
	# Capacidade do placar e estados vazios usam apenas dados de apresentação neste save isolado.
	var exemplo: Dictionary=dados.duplicate(true)
	exemplo.grupo=[]
	for i in 4:exemplo.grupo.append({"id":"fixture%d" % i,"nome":"Aventureiro de nome muito comprido %d" % i,"dano":400-i*90})
	for medida in [Vector2i(576,324),Vector2i(288,512),Vector2i(320,324)]:
		root.content_scale_size=medida;root.size=medida*2;await quadros(4)
		resultado.apresentar(exemplo,"chegada");await quadros(20)
		if resultado.abas!=null:resultado.abas.current_tab=1;await quadros(4)
		verificar("quatro retratos no placar "+str(medida),resultado.find_children("RetratoCombatente","Control",true,false).size()==4)
		verificar("placar cabe "+str(medida),Rect2(Vector2.ZERO,Vector2(medida)).encloses(resultado.painel.get_global_transform_with_canvas()*Rect2(Vector2.ZERO,resultado.painel.size)))
		await foto("placar-quatro-%d" % medida.x)
	exemplo.drops=[];exemplo.maestria=[];exemplo.grupo=[]
	resultado.apresentar(exemplo,"estrada");await quadros(8)
	verificar("estado sem saque sem slots ficticios",resultado.slots.is_empty())
	await foto("sem-saque")
	resultado.apresentar(dados,"chegada","Clareira pacificada");await quadros(4)
	verificar("abrir resultado nao concede XP",j.maestria.modelo.experiencia==xp)
	resultado.explorar.emit();await quadros(3)
	verificar("explorar devolve controle",cena.interface._telas_abertas.is_empty() and j.movimento_habilitado)
	var remoto: Dictionary=r.resumo_rede()
	remoto.seq=999;remoto.grupo[0].dano=-1
	verificar("resumo invalido rejeitado",not r.receber_resumo(remoto))
	cena.interface.mostrar_resultado();await quadros(2)
	cena.interface._telas.resultado.rejogar.emit();await quadros(80);cena=current_scene
	await pular()
	verificar("repetir reinicia saque do registro",cena.registro_run.dados().drops.is_empty())
	verificar("repetir reinicia abates",cena.registro_run.dados().abates==0)
	verificar("repetir preserva maestria",xp.keys().all(func(f):return int(cena.jogador.maestria.modelo.experiencia.get(f,-1))==int(xp[f])))
	print("FALHAS: ",falhas);quit(1 if falhas else 0)
