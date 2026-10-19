extends SceneTree

const Receitas := preload("res://codigo/dados/forja_armas.gd")
const Conjuntos := preload("res://codigo/dados/conjuntos_armadura.gd")
const Dados := preload("res://codigo/modelos/dados_item.gd")
var falhas := 0
func _initialize() -> void: rodar.call_deferred()
func verificar(texto: String, ok: bool) -> void:
	print("OK " if ok else "FALHA ",texto)
	if not ok: falhas+=1
func rodar() -> void:
	if not str(ProjectSettings.get_setting("application/config/custom_user_dir_name","")).begins_with("AlgoLand testes"):
		quit(1)
		return
	await process_frame
	root.get_node("Saves").trocar("coop")
	root.get_node("Introducao").pular_prologo()
	var prog := root.get_node("Progresso")
	var inv := root.get_node("InventarioJogador")
	var inv2 := root.get_node("InventarioJogador2")
	var cal := root.get_node("Calendario")
	var drop = load("res://codigo/logica/equipamento_drop.gd")
	var drops = load("res://codigo/logica/drops_forja.gd")
	var palco := Node2D.new()
	root.add_child(palco)
	var inimigo := Node2D.new()
	inimigo.set_script(load("res://testes/apoio/inimigo_receita.gd"))
	palco.add_child(inimigo)
	var rng := RandomNumberGenerator.new()
	rng.seed=27102026
	var todos: Array = preload("res://codigo/dados/equipamentos.gd").TIPOS_DROP.duplicate()
	todos.append_array(Dados.FERRAMENTAS)
	todos.append_array(["aljava_basica","cabeca_basica","armadura_basica","luvas_basicas","botas_basicas",Dados.TIPO_VARA])
	for conjunto in Conjuntos.CONJUNTOS: todos.append_array(conjunto.TIPOS.keys())
	verificar("equipamentos de combate exigem receita; kit e ferramentas são livres",todos.all(func(t): return Receitas.RECEITAS.has(t) or t in Receitas.INICIAIS_LIVRES))
	for tipo in Receitas.RECEITAS:
		prog.apagar()
		for mochila in [inv,inv2]:
			mochila.limpar()
			mochila.criar_itens_iniciais()
			mochila._migrar_ferramentas()
			mochila._migrar_aljava()
			mochila.sincronizar_vara()
		verificar("kit e migrações preservam ferramentas sem liberar equipamentos: "+tipo, inv.buscar_por_tipo(tipo)==null and Dados.FERRAMENTAS.all(func(t): return inv.buscar_por_tipo(t)!=null) and inv.buscar_por_tipo(Dados.TIPO_VARA)!=null and inv.equipados.secundaria==null)
		# Isola a receita a testar sem fabricar os outros modelos.
		for outra in Receitas.RECEITAS:
			if outra!=tipo: prog.armas_liberadas[outra]=true
		verificar("receita respeita andar mínimo: "+tipo,drops.receita_pendente(Receitas.onda_receita(tipo)-1,self)=="")
		# Este teste cobre o conteúdo de um sorteio vencedor; a frequência é testada à parte.
		while true:
			var estado: int = rng.state
			if rng.randf() < drop.chance(false,true):
				rng.state = estado
				break
		var objeto: Node2D=drop.soltar_de(inimigo,palco,rng,999,true)
		verificar("chefe solta pergaminho, nunca equipamento pronto: "+tipo,objeto!=null and objeto.item.categoria=="receita" and objeto.item.conteudo()==tipo)
		if objeto==null: continue
		inv.adicionar(objeto.item)
		objeto._pego=true
		objeto.queue_free()
		verificar("coletar não aprende: "+tipo,not prog.receita_liberada(tipo) and inv.quantidade_tipo("receita:"+tipo)==1)
		verificar("uso consome a receita: "+tipo,prog.aprender_receita(tipo,inv)=="" and inv.quantidade_tipo("receita:"+tipo)==0)
		prog.adicionar_materiais_forja(Receitas.RECEITAS[tipo],inv)
		inv2.receber_materiais({"madeira":11,"ferro":13,"fibra":19,"fragmento":17})
		var antes2 := {}
		for id in Receitas.MATERIAIS: antes2[id]=inv2.quantidade_tipo("material:"+id)
		verificar("encomenda é aceita: "+tipo,prog.encomendar_arma(tipo,inv)=="")
		verificar("retirada exige dias de trabalho: "+tipo,not prog.encomenda_forja_pronta() and not prog.arma_liberada(tipo))
		cal.dia=int(prog.encomenda_forja.get("dia_pronto",cal.dia))
		verificar("retirada na forja: "+tipo,prog.retirar_encomenda_forja(inv)=="")
		var item=inv.buscar_por_tipo(tipo)
		verificar("categoria e nível corretos: "+tipo,item!=null and item.categoria==Receitas.criar_item(tipo).categoria and item.nivel==1)
		verificar("segundo jogador não é cobrado: "+tipo,antes2.keys().all(func(id): return antes2[id]==inv2.quantidade_tipo("material:"+id)))
		prog.carregar()
		verificar("receita e fabricação persistem: "+tipo,prog.receita_liberada(tipo) and prog.arma_liberada(tipo))
	palco.queue_free()
	quit(0 if falhas==0 else 1)
