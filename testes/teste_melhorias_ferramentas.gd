extends SceneTree
const Melhorias := preload("res://codigo/dados/melhorias_ferramentas.gd")
var falhas := 0
func _initialize() -> void: rodar.call_deferred()
func quadros(n := 8) -> void:
	for i in n:
		await physics_frame
		await process_frame
func verificar(nome: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ",nome)
	if not ok: falhas+=1
func rodar() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name","")).begins_with("AlgoLand testes"):
		quit(1)
		return
	await process_frame
	root.get_node("Introducao").pular_prologo()
	var inv: Node=root.get_node("InventarioJogador")
	inv.limpar()
	inv.criar_itens_iniciais()
	for tipo in Melhorias.TIPOS:
		var item=inv.buscar_por_tipo(tipo)
		verificar("ferramenta inicial sem receita "+tipo,item!=null and item.nivel==1)
		var antes: Array=inv.fotografar_mochila()
		verificar("sem materiais nao muda ferramenta "+tipo,Melhorias.melhorar(inv,tipo)=="MATERIAIS INSUFICIENTES" and inv.fotografar_mochila()==antes)
		for n in [2,3]:
			verificar("materiais fisicos cabem "+tipo,inv.receber_materiais(Melhorias.CUSTOS[n]))
			verificar("melhora sem receita "+tipo+str(n),Melhorias.melhorar(inv,tipo)=="" and inv.buscar_por_tipo(tipo).nivel==n)
		verificar("limite evita cobranca repetida "+tipo,Melhorias.melhorar(inv,tipo)=="NIVEL MAXIMO")
	inv.carregar()
	for tipo in Melhorias.TIPOS: verificar("nivel salvo por ferramenta "+tipo,inv.buscar_por_tipo(tipo).nivel==3)
	var faz: Node=root.get_node("Fazenda")
	faz._definir_energia(1,100)
	verificar("enxada de ferro reduz energia",faz.gastar_energia("enxada",1) and faz.energia_de(1)==99)
	verificar("picareta de ferro reduz energia",faz.gastar_energia("picareta",1) and faz.energia_de(1)==98)
	change_scene_to_file("res://cenas/fazenda.tscn")
	await quadros(16)
	var plantio: Node=current_scene.find_child("Plantio",true,false)
	var jogador: Node2D=current_scene.get_node("Jogador")
	jogador.set_physics_process(false)
	root.get_node("Calendario").dia=1
	faz.solo.clear()
	faz.entulho.clear()
	var centro:=Vector2i(12,26)
	var ponto: Vector2=plantio.to_global(Vector2(centro)*16+Vector2(8,8))
	plantio._ao_impacto("enxada",ponto)
	verificar("enxada de ferro trabalha nove solos",faz.solo.size()==9)
	faz.agua_regador=2
	plantio._ao_impacto("regar",ponto)
	var molhados := 0
	for c in faz.solo:
		if faz.solo[c].molhado: molhados+=1
	verificar("regador respeita agua e prioriza alvo",molhados==2 and faz.esta_molhado(centro) and faz.agua_regador==0)
	var ui: Node=get_first_node_in_group("interface")
	var tela: Control=ui._telas["forja"]
	tela._mudar_categoria(true)
	verificar("aba com quatro ferramentas e niveis reais",tela._tipos_catalogo()==Melhorias.TIPOS and tela._fabricar.text=="NIVEL MAXIMO")
	current_scene.queue_free()
	await quadros()
	quit(1 if falhas else 0)
