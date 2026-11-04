extends SceneTree
## Uniforme no mesmo ator da cidade; revisão de partes, restauração e movimento real.
const Elenco=preload("res://codigo/dados/moradores_primeira_raiz.gd")
const Gerador=preload("res://codigo/dados/gerador_npcs.gd")
var falhas:=0
var saida:="res://capturas-guarda-novato/"

func _initialize() -> void:rodar.call_deferred()
func verificar(nome: String,ok: bool) -> void:
	print("OK " if ok else "FALHA ",nome)
	if not ok:falhas+=1
func esperar(n:=3) -> void:
	for i in n:await process_frame
func foto(h: Node,nome: String) -> void:
	await RenderingServer.frame_post_draw
	var imagem:Image=h._vp.get_texture().get_image()
	var usado:=imagem.get_used_rect()
	verificar("sem cortes "+nome,usado.has_area() and usado.position.x>0 and usado.position.y>0 and usado.end.x<imagem.get_width() and usado.end.y<imagem.get_height())
	verificar("captura "+nome,imagem.save_png(saida+nome+".png")==OK)
	if nome in ["parado_0","parado_2"]:
		# Regressão da abertura: detectar pele na cabeça real, sem contar mãos ou cinto.
		var pele:=0
		for y in range(usado.position.y,usado.position.y+usado.size.y/2):
			for x in range(usado.position.x,usado.end.x):
				var cor:=imagem.get_pixel(x,y)
				if cor.a>.5 and cor.r>.4 and cor.r>cor.g*1.08 and cor.g>cor.b*1.12:pele+=1
		verificar("rosto aparece na abertura frontal" if nome=="parado_0" else "nuca permanece protegida",pele>25 if nome=="parado_0" else pele<5)

func rodar() -> void:
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes") or DisplayServer.get_name()=="headless":quit(1);return
	root.get_node("Ranking").conexao_habilitada=false
	DirAccess.make_dir_recursive_absolute(saida)
	var ficha:=Elenco.ficha("noel")
	verificar("Noel recebe uniforme próprio",ficha.get("armadura_npc")=="guarda_novato")
	var salva:=Gerador.salvar(ficha,"user://noel.json")
	var lida:=Gerador.carregar("user://noel.json")
	verificar("exportação preserva uniforme sem conceder equipamento",salva==OK and lida.get("armadura_npc")=="guarda_novato" and lida.nome==ficha.nome and lida.aparencia.roupas_3d==ficha.aparencia.roupas_3d and lida.aparencia.equipamentos.is_empty())
	for canal in 3:verificar("exportação preserva tom de pele %d" % canal,is_equal_approx(lida.aparencia.cor_pele[canal],ficha.aparencia.cor_pele[canal]))
	var arbitraria:=ficha.duplicate(true)
	arbitraria.armadura_npc="res://qualquer_arquivo.res"
	verificar("ficha recusa caminhos de uniforme",not Gerador.normalizar(arbitraria).has("armadura_npc"))
	var npc=load("res://cenas/npcs/npc_gerado.tscn").instantiate()
	npc.ficha=ficha
	npc.position=Vector2(150,200)
	root.add_child(npc)
	npc.set_physics_process(false)
	await esperar(8)
	var visual=npc.visual
	var h=visual.heroi
	var corpo:MeshInstance3D=h._modelo.find_child("CorpoBase",true,false)
	var original:=corpo.mesh.get_rid()
	for bits in 16:
		visual.pecas_armadura_npc=bits
		h._armaduras.atualizar()
		verificar("máscara independente %d" % bits,h._armaduras.mascara==bits)
		for i in 4:
			var p:MeshInstance3D=h._armaduras.malhas[i]
			verificar("slot %d/%d" % [bits,i],p.visible==bool(bits & (1<<i)))
			if p.visible:verificar("mesmo rig %d/%d" % [bits,i],p.skin==corpo.skin and p.skeleton==corpo.skeleton and p.mesh!=corpo.mesh and p.material_override.shader.resource_path.ends_with("guarda_novato_base_3d.gdshader"))
		verificar("peitoral recolhe roupa coberta %d" % bits,h._pecas[0].visible==not bool(bits & 2) and h._pecas[1].visible==not bool(bits & 2))
		verificar("elmo aberto preserva rosto e recolhe cabelo %d" % bits,h._cabeca_referencia.visible and not corpo.material_override.get_shader_parameter("elmo_fechado") and (not bool(bits & 1) or h._cabeca_referencia.material.get_shader_parameter("sem_cabelo")))
		visual.pose(false,0,0)
		await esperar(2)
		await foto(h,"pecas_%02d" % bits)
	var roupas:Dictionary=h.roupas_3d.duplicate()
	roupas.cabelo="cabelo_liso_longo"
	h.definir_roupas_3d(roupas)
	verificar("elmo recolhe cabelo volumétrico",not h._pecas[3].visible)
	visual.pecas_armadura_npc=0
	h._armaduras.atualizar()
	verificar("retirar elmo restaura cabelo e rosto",h._pecas[3].visible and h._cabeca_referencia.visible)
	h.definir_roupas_3d(ficha.aparencia.roupas_3d)
	visual.pecas_armadura_npc=15
	h._armaduras.atualizar()
	for d in 4:
		visual.pose(false,d,0)
		await esperar()
		await foto(h,"parado_%d" % d)
		var duracao:float=h._player.get_animation("Walk_Loop").length
		for q in 8:
			visual.pose_caminhada(true,d,duracao*q/8.0)
			await esperar(2)
			verificar("caminha sem usar corrida",h._player.current_animation=="Walk_Loop")
			await foto(h,"andar_%d_%02d" % [d,q])
		for acao in ["espada","lanca","arco","avanco","pesada","sentado"]:
			for fase in [0.0,.35,.7]:
				visual.pose_acao(acao,0,d,fase)
				await esperar(2)
				await foto(h,"%s_%d_%02d" % [acao,d,int(fase*100)])
	verificar("vestir preserva geometria do corpo",corpo.mesh.get_rid()==original)
	var nome:Label=npc.get_node("NomeNPC")
	verificar("nome centralizado acima da crista",absf(nome.position.x+nome.size.x/2)<.1 and nome.position.y+nome.size.y<visual.topo_aparente())
	npc.queue_free()
	await esperar(3)
	print("FALHAS: ",falhas)
	quit(falhas)
