extends SceneTree
var falhas := 0
var cena: Node2D
var capturas := "res://capturas-maestria"
var jogador: CharacterBody2D
class Alvo extends CharacterBody2D:
	var vida := 300
	var vida_maxima := 300
	var esta_morto := false
	var golpes := 0
	func _ready() -> void:
		add_to_group("enemy")
		collision_layer=4;collision_mask=0
		var colisao:=CollisionShape2D.new()
		var forma:=CircleShape2D.new();forma.radius=12
		colisao.shape=forma;add_child(colisao)
		var sprite:=Sprite2D.new()
		sprite.texture=load("res://assets/inimigos/rebento_raizes/atlas.png")
		sprite.hframes=8;sprite.vframes=6;sprite.centered=false
		sprite.offset=Vector2(-512,-800);sprite.scale=Vector2.ONE*0.1
		add_child(sprite)

	func receber_dano(valor: int, _forca := Vector2.ZERO) -> void:
		golpes += 1
		vida = maxi(0,vida-valor)
		esta_morto = vida == 0
	func atordoar(_duracao: float) -> void: pass
func _initialize() -> void: rodar.call_deferred()
func verificar(nome: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ",nome)
	if not ok: falhas += 1
func quadros(n:=8) -> void:
	for i in n: await process_frame; await physics_frame
func area(no: Control) -> Rect2:
	return no.get_global_transform_with_canvas()*Rect2(Vector2.ZERO,no.size)
func foto(nome: String) -> void:
	await RenderingServer.frame_post_draw
	verificar("captura "+nome,root.get_texture().get_image().save_png(capturas.path_join(nome+".png"))==OK)
func rodar() -> void:
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes") or DisplayServer.get_name()=="headless": quit(1);return
	for argumento in OS.get_cmdline_user_args():
		if argumento.begins_with("--capturas="):capturas=argumento.trim_prefix("--capturas=")
	DirAccess.make_dir_recursive_absolute(capturas)
	var catalogo=load("res://codigo/dados/catalogo_maestria.gd")
	var progresso=load("res://codigo/campanha/progresso_campanha.gd").new()
	verificar("prepara campanha isolada",progresso.iniciar("user://percurso_primeira_raiz","prototipo")==OK)
	for missao in ["sobreviver_queda","estrada_interrompida"]:
		for objetivo in load("res://codigo/campanha/catalogo_campanha.gd").dados().missoes[missao].objetivos:progresso.registrar_objetivo(missao,objetivo.id)
	for id in ["dara","retorno"]:progresso.registrar_objetivo("acolhimento",id)
	progresso.salvar_retorno("vila",Vector2(0,180))
	root.mode=Window.MODE_WINDOWED
	root.content_scale_size=Vector2i(576,324);root.size=Vector2i(1152,648)
	set_meta("campanha_nova_instancia",false) # Restaura a vila preparada para exercitar o combate.
	change_scene_to_file("res://cenas/campanha/percurso_prototipo.tscn")
	await quadros(90)
	cena=current_scene
	if cena==null or cena.get("jogador")==null:verificar("campanha inicia",false);quit(1);return
	jogador=cena.jogador
	if jogador.get("maestria")==null:verificar("componente inicia",false);quit(1);return
	var maestria:Node=jogador.maestria
	var modelo:RefCounted=maestria.modelo
	verificar("save da campanha separado do mundo",modelo.pronto and modelo.caminho=="user://percurso_primeira_raiz/maestria.json" and not FileAccess.file_exists("user://maestria.json"))
	verificar("novo personagem tem dois golpes",maestria.limite_combo("espada")==2)
	var alvo:=Alvo.new()
	cena.add_child(alvo)
	alvo.position=jogador.position+Vector2(22,0)
	maestria.novo_golpe()
	var xp_antes:int=modelo.experiencia.espada
	jogador.aplicar_golpe(alvo,Vector2.RIGHT)
	verificar("acerto real concede dominio",modelo.experiencia.espada>xp_antes)
	var xp:int=modelo.experiencia.espada
	maestria.registrar_acerto(alvo,10,alvo.vida,"espada_basica",maestria.golpe_id)
	verificar("mesmo contato nao duplica xp",modelo.experiencia.espada==xp)
	for i in 100:
		alvo.vida=300;alvo.esta_morto=false
		maestria.novo_golpe()
		jogador.aplicar_golpe(alvo,Vector2.RIGHT)
	xp=modelo.experiencia.espada
	alvo.vida=300;alvo.esta_morto=false
	maestria.novo_golpe();jogador.aplicar_golpe(alvo,Vector2.RIGHT)
	verificar("regeneracao nao renova orcamento do inimigo",modelo.experiencia.espada==xp)
	alvo.queue_free()
	for f in catalogo.FAMILIAS:
		while modelo.nivel(f)<100:modelo.adicionar_xp(f,mini(10000,catalogo.xp_para_nivel(100)-int(modelo.experiencia[f])))
		for ramo in 3:
			for degrau in 2:modelo.aprender("%s_%d_%d" % [f,ramo,degrau])
		modelo.aprender(f+"_0_2");modelo.aprender(f+"_0_3")
		verificar("duas tecnicas equipam "+f,modelo.equipar(f+"_0_1")==OK and modelo.equipar(f+"_1_1")==OK)
		verificar("terceira tecnica exige retirar anterior "+f,modelo.equipar(f+"_2_1")==ERR_OUT_OF_MEMORY)
		modelo.equipar(f+"_0_3")
	verificar("fundamento libera terceiro golpe",maestria.limite_combo("espada")==3)
	jogador.position=Vector2(0,180)
	jogador.parar_para_conversa(jogador.position+Vector2.RIGHT)
	var arma_original=jogador.inventario.equipados.arma
	var escudo_original=jogador.inventario.equipados.escudo
	for par in [["espada","espada_basica"],["montante","espada_gemea"],["lanca","lanca_basica"],["machado","machado"],["maca","maca"],["arco","arco_curto"],["escudo","espada_basica"]]:
		var f:String=par[0]
		var item=load("res://codigo/modelos/dados_item.gd").de_dict({"tipo":par[1],"categoria":"arma","duas_maos":f in ["montante","lanca","machado","arco"]})
		jogador.inventario.equipados.arma=item
		jogador.inventario.equipados.escudo=escudo_original
		jogador._aplicar_modelo()
		await quadros(12)
		var original:Vector2=jogador.position
		var alvo_tecnica:=Alvo.new()
		cena.add_child(alvo_tecnica)
		alvo_tecnica.position=original+Vector2(28,0)
		jogador.stamina=jogador.stamina_maxima
		jogador.parar_para_conversa(original+Vector2.RIGHT)
		maestria._recarga_ate=0
		verificar("tecnica inicia "+f,maestria.executar(0,f).is_empty())
		await quadros(5)
		if f=="espada":
			for botao in maestria._botoes:
				verificar("tecnica nao cobre barra nem aviso",not area(botao).intersects(area(cena.hud.barra_armas._coluna)) and not area(botao).intersects(area(cena.hud.faixa_banner)))
		await foto("tecnica-"+f+"-preparo")
		await quadros(16)
		await foto("tecnica-"+f+"-contato")
		await quadros(45)
		verificar("tecnica causa um contato "+f,alvo_tecnica.golpes==1)
		verificar("tecnica termina e devolve controle "+f,not maestria.executando and not jogador.has_meta("tecnica_maestria"))
		alvo_tecnica.queue_free()
		for ramo in [1,2]:
			jogador.position=original
			jogador.stamina=jogador.stamina_maxima
			jogador.parar_para_conversa(original+Vector2.RIGHT)
			maestria._recarga_ate=0
			if ramo==2:
				modelo.equipar(f+"_1_1");modelo.equipar(f+"_2_1")
				verificar("resposta exige defesa "+f,maestria.executar(1,f)=="BLOQUEIE OU APARE ANTES DE RESPONDER")
				maestria._guarda_ate=Time.get_ticks_msec()+2000
			var outro:=Alvo.new();cena.add_child(outro);outro.position=original+Vector2(28,0)
			verificar("tecnica caminho %d %s" % [ramo,f],maestria.executar(1,f).is_empty())
			await quadros(90)
			verificar("contato unico caminho %d %s" % [ramo,f],outro.golpes==1 and not maestria.executando)
			outro.queue_free()
			if ramo==2:modelo.equipar(f+"_2_1");modelo.equipar(f+"_1_1")
		jogador.position=original;jogador.stamina=jogador.stamina_maxima
		var alvo_fim:=Alvo.new();cena.add_child(alvo_fim);alvo_fim.position=original+Vector2(28,0)
		if f=="escudo":
			jogador.defesa._iniciar_escudada()
			verificar("aparar aciona finalizador de escudo",maestria.executando and maestria.tecnica.familia=="escudo")
		else:verificar("finalizador inicia "+f,maestria.iniciar_finalizador(f))
		await quadros(90)
		verificar("finalizador tem contato unico "+f,alvo_fim.golpes==1 and not maestria.executando)
		alvo_fim.queue_free()
		jogador.position=original
	jogador.inventario.equipados.arma=arma_original;jogador.inventario.equipados.escudo=escudo_original;jogador._aplicar_modelo()
	await quadros(10)
	jogador.stamina=0
	maestria._recarga_ate=0
	verificar("tecnica exige folego",maestria.executar(0)=="FOLEGO INSUFICIENTE" and not maestria.executando)
	jogador.stamina=jogador.stamina_maxima
	verificar("tecnica pode iniciar apos recuperar",maestria.executar(0).is_empty())
	jogador.desabilitar_todas_acoes(true)
	verificar("abrir tela cancela tecnica",not maestria.executando)
	jogador.desabilitar_todas_acoes(false)
	cena.interface._abrir_tela("maestria")
	await quadros(15)
	var tela:Control=cena.interface._telas.maestria
	verificar("tela integrada e bloqueia acoes",tela.visible and not jogador.movimento_habilitado and tela.modelo==modelo)
	for medida in [Vector2i(576,324),Vector2i(288,512),Vector2i(320,324),Vector2i(960,540)]:
		root.content_scale_size=medida;root.size=medida*2
		await quadros(12)
		for f in catalogo.FAMILIAS:
			tela.familia=f;tela._selecionado="";tela._detalhe.hide();tela._centrar=true;tela.atualizar()
			await quadros(8)
			verificar("painel cabe %s %s" % [f,medida],Rect2(Vector2.ZERO,Vector2(medida)).encloses(area(tela.painel)))
			verificar("conteudo respeita moldura %s %s" % [f,medida],area(tela.painel).grow(-9).encloses(area(tela._coluna)))
			verificar("vinte nos com icones %s %s" % [f,medida],tela._nos.size()==20)
			for id in tela._nos:
				var no:Button=tela._nos[id]
				var quadrado:PanelContainer=no.get_node("Quadrado")
				verificar("no pequeno e alvo acessivel %s %s" % [id,medida],quadrado.size.x<=40 and no.size.x>=32 and area(no).encloses(area(quadrado)))
			for id in [f+"_0_0",f+"_0_1",f+"_1_3"]:
				tela._abrir_detalhe(id)
				await quadros(6)
				verificar("tooltip dentro da tela %s %s" % [id,medida],Rect2(Vector2.ZERO,Vector2(medida)).grow(-8).encloses(area(tela._detalhe)))
				for no in tela._detalhe_coluna.get_children():
					verificar("margens do tooltip %s %s" % [id,medida],area(tela._detalhe).grow(-8).encloses(area(no)))
				tela._fechar_detalhe()
			if f in ["espada","escudo"]:
				await foto("arvore-%s-%dx%d" % [f,medida.x,medida.y])
				tela._abrir_detalhe(f+"_0_1")
				await quadros(6)
				await foto("tooltip-%s-%dx%d" % [f,medida.x,medida.y])
				tela._fechar_detalhe()

	tela._resetar();tela._resetar()
	verificar("redistribuicao na cidade preserva nivel",modelo.nivel(tela.familia)==100 and modelo.disponiveis(tela.familia)==12)
	cena.interface._fechar_tela("maestria")
	await quadros(8)
	verificar("fechar tela restaura controles",jogador.movimento_habilitado)
	print("FALHAS: ",falhas)
	quit(1 if falhas else 0)
