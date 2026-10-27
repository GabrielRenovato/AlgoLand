extends SceneTree
## Materiais ativos no jogo; revisão gráfica com save isolado, sem gravar personagem.
const Catalogo=preload("res://codigo/dados/roupas_base_3d.gd")
const SAIDA="res://arte/previas/personagens/base_3d/roupas_pixel/"
const RECORTE=Rect2i(215,155,210,330)
const RECORTE_MOV=Rect2i(165,150,310,320)
var falhas:=0
var verificacoes:=0
var h: Node
var tempos: Dictionary={}
func _initialize():rodar.call_deferred()
func conferir(ok: bool,msg: String):
	verificacoes+=1
	if not ok:
		falhas+=1
		push_error(msg)
func esperar(n: int):
	for i in n:await process_frame
func foto(nome: String) -> Image:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img: Image=h._vp.get_texture().get_image()
	img.save_png(SAIDA+nome+".png")
	return img
func pose(acao: String,d: int,progresso:=0.0):
	h._modelo.rotation.y=d*TAU/8.0
	var nome: String=h._nome_animacao(acao)
	h._player.play(nome,0)
	h._player.pause()
	var tempo: float=h._player.get_animation(nome).length
	h._player.seek(tempo*progresso,true)
	tempos[acao]=tempo
func folha(cols: int,linhas: int,recorte:=RECORTE) -> Image:
	var img:=Image.create(recorte.size.x*cols,recorte.size.y*linhas,false,Image.FORMAT_RGBA8)
	img.fill(Color("52624f"))
	return img
func colar(destino: Image,origem: Image,x: int,y: int,recorte:=RECORTE):
	destino.blend_rect(origem,recorte,Vector2i(x*recorte.size.x,y*recorte.size.y))
func rodar():
	assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
	assert(DisplayServer.get_name()!="headless")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAIDA))
	root.get_node("Ranking").conexao_habilitada=false
	root.get_node("Introducao").pular_prologo()
	root.get_node("Transicao").hora_salva=12.0
	change_scene_to_file("res://cenas/fazenda.tscn")
	await esperar(45)
	root.get_node("Transicao").limpar()
	var j=current_scene.get_node("Jogador")
	var mochila: Array=j.inventario.fotografar_mochila()
	h=j.get_node("HeroiBase3D")
	conferir(h.roupas_pixel_art,"Texturas de roupa ativas por padrão")
	# Inspeção das fontes em alta resolução; a grade final tem revisão própria.
	h.acabamento_pixel_art=false
	j.set_physics_process(false)
	j.no_fazenda.set_process(false)
	j.aparencia_raven={"pele":0,"cor":[1.0,1.0,1.0,1.0],"olhos":0}
	h._aplicar_cores()
	h.definir_roupas_3d(Catalogo.padrao())
	h.set_process(false)
	h._empunhadura_lanca.amostragem_automatica=false
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(SAIDA+"no_mapa.png")
	# Peças de combate não tapam as costuras vistas por trás.
	h._costas.visible=false
	h._mao.visible=false
	h._mao_esquerda.visible=false
	var originais: Array=[]
	for i in 3:originais.append(h._pecas[i].mesh)
	var comparacao:=folha(4,4)
	var pares:=folha(4,2)
	for modo in 2:
		h.roupas_pixel_art=modo==1
		for d in 8:
			pose("parado",d)
			var img: Image=await foto("%s_%d"%["depois" if modo else "antes",d])
			colar(comparacao,img,d%4,modo*2+d/4)
			if d<4:colar(pares,img,d,modo)
		for i in 3:
			conferir(h._pecas[i].mesh==originais[i],"Textura não troca malha nem rig")
	comparacao.save_png(SAIDA+"oito_direcoes.png")
	pares.save_png(SAIDA+"antes_depois.png")
	# Restauração exata dos materiais antigos.
	h.roupas_pixel_art=false
	pose("parado",0)
	var restaurado: Image=await foto("restaurado")
	var original:=Image.load_from_file(SAIDA+"antes_0.png")
	conferir(restaurado.get_data()==original.get_data(),"Desligar restaura o render original")
	h.roupas_pixel_art=true
	if "--somente-amostra" in OS.get_cmdline_user_args():
		print("ROUPAS AMOSTRA: ",verificacoes," verificações, ",falhas," falhas")
		quit(1 if falhas else 0)
		return
	# Todos os modelos existentes, nas quatro direções cardinais.
	var quantidade:=0
	for categoria in ["camisa","calca","calcado"]:
		var catalogo:=folha(4,Catalogo.MODELOS[categoria].size())
		for linha in Catalogo.MODELOS[categoria].size():
			var item: Dictionary=Catalogo.MODELOS[categoria][linha]
			var dados:=Catalogo.padrao()
			dados[categoria]=item.id
			h.definir_roupas_3d(dados)
			for d in 4:
				pose("parado",d*2)
				var img: Image=await foto("%s_%d"%[item.id,d])
				colar(catalogo,img,d,linha)
			for i in 3:
				var mat: ShaderMaterial=h._pecas[i].material_override
				conferir(mat.get_shader_parameter("desenho_pixel_roupas"),"Arte ativa após trocar peça")
				conferir(mat.get_shader_parameter("desenho_roupa") is Texture2D,"Atlas importado para exportação")
			quantidade+=1
		catalogo.save_png(SAIDA+"catalogo_"+categoria+".png")
	# Roupa, saia, sapatos e botas em movimento nas durações reais.
	for conjunto in 3:
		h.definir_roupas_3d([
			Catalogo.padrao(),
			{"camisa":"blusa_bufante","calca":"saia_pregas","calcado":"sapatilhas_vinho"},
			{"camisa":"jaqueta_viajante","calca":"calca_cargo","calcado":"botinas_trabalho"}][conjunto])
		for acao in ["correr","espada"]:
			var contato:=folha(6,2,RECORTE_MOV)
			for d in [0,2,4,6]:
				for q in 12:
					pose(acao,d,q/12.0)
					var img: Image=await foto("%s_%d_%d_%02d"%[acao,conjunto,d,q])
					if d==2:colar(contato,img,q%6,q/6,RECORTE_MOV)
			contato.save_png(SAIDA+"quadros_%s_%d.png"%[acao,conjunto])
	conferir(j.inventario.fotografar_mochila()==mochila,"Inventário preservado")
	FileAccess.open(SAIDA+"tempos.json",FileAccess.WRITE).store_string(JSON.stringify(tempos,"  "))
	print("ROUPAS PIXEL: ",quantidade," modelos; oito direções; três conjuntos em corrida/ataque; ",verificacoes," verificações, ",falhas," falhas; tempos=",tempos)
	quit(1 if falhas else 0)
