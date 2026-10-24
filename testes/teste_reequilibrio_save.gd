extends SceneTree

const Migracao := preload("res://codigo/dados/reequilibrio_save.gd")
var falhas := 0
var verificacoes := 0

func _initialize() -> void: rodar.call_deferred()
func conferir(ok: bool, texto: String) -> void:
	verificacoes += 1
	if not ok: falhas += 1; push_error(texto)
func escrever(caminho: String, valor: Variant) -> void:
	var f := FileAccess.open(caminho,FileAccess.WRITE)
	f.store_string(JSON.stringify(valor)); f.close()
func ler(caminho: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(caminho))

func rodar() -> void:
	assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
	await process_frame
	if "--verificar-inicio" in OS.get_cmdline_user_args() or "--verificar-reabertura" in OS.get_cmdline_user_args():
		var primeira := "--verificar-inicio" in OS.get_cmdline_user_args()
		for mundo in ["solo","coop"]:
			root.get_node("Saves").trocar(mundo)
			var p = root.get_node("Progresso")
			conferir(p.brasas==(0 if primeira else 23),"Inicialização real respeita marcador e saldo: "+mundo)
			conferir(not p.receita_liberada("elmo_carrasco"),"Receita zerada antes do autoload carregar")
			var inv = root.get_node("InventarioJogador")
			conferir(inv.buscar_por_tipo("elmo_carrasco")==null and inv.quantidade_tipo("receita:elmo_carrasco")==0,"Inventário real não recupera itens removidos")
			p.brasas=23;p.salvar()
		quit(1 if falhas else 0)
		return
	for mundo in ["solo","coop"]:
		var pasta: String = "user://teste_reequilibrio/"+mundo+"/"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(pasta))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(pasta+Migracao.MARCADOR))
		var lendaria := {"tipo":"elmo_carrasco","categoria":"cabeca","raridade":"lendario","nivel":5.0}
		var epica := {"tipo":"peitoral_carrasco","categoria":"corpo","raridade":"epico","nivel":5.0}
		var receita := {"tipo":"receita:elmo_carrasco","categoria":"receita","quantidade":10.0}
		var arma := {"tipo":"espada_basica","categoria":"arma","raridade":"lendario"}
		var vara := {"tipo":"vara_pesca","categoria":"vara","raridade":"lendario"}
		var dados := {"mochila":[lendaria,receita,epica,arma,vara],"equipados":{"cabeca":lendaria,"corpo":epica},"moedas_forja":99.0,"mao":{"arma":0.0}}
		for nome in ["inventario.json","inventario_p2.json","inventario_introducao_checkpoint.json"]: escrever(pasta+nome,dados)
		escrever(pasta+"bau.json",{"capacidade":40,"itens":[receita,lendaria,epica,vara]})
		escrever(pasta+"introducao.json",{"versao":2,"etapa":3,"inventario":dados})
		escrever(pasta+"progresso.json",{"brasas":9999,"armas_liberadas":{"elmo_carrasco":true},"armas_fabricadas":{"arco_curto":true},"melhorias":{"vigor":4},"maior_onda_vencida":25,"mochila_pendente":{"dados":dados,"caminho":pasta+"inventario_p2.json"},"encomenda_forja":{"tipo":"botas_basicas"}})
		escrever(pasta+"fazenda.json",{"galinheiro":{"nivel":3}})
		conferir(Migracao.preparar(pasta)==OK,"Migração termina: "+mundo)
		var p: Dictionary = ler(pasta+"progresso.json")
		conferir(p.brasas==0 and p.armas_liberadas.is_empty(),"Zera saldo e receitas aprendidas")
		conferir(p.melhorias.vigor==4 and p.maior_onda_vencida==25 and p.armas_fabricadas.arco_curto and p.encomenda_forja.tipo=="botas_basicas","Preserva melhorias, andares, modelos fabricados e pedidos pagos")
		conferir(p.mochila_pendente.dados.mochila[0]==null and p.mochila_pendente.dados.mochila[1]==null,"Transação pendente não ressuscita itens removidos")
		for nome in ["inventario.json","inventario_p2.json","inventario_introducao_checkpoint.json"]:
			var inv: Dictionary = ler(pasta+nome)
			conferir(inv.mochila.size()==5 and inv.mochila[0]==null and inv.mochila[1]==null and inv.equipados.cabeca==null,"Remove pergaminhos e armadura lendária sem deslocar casas: "+nome)
			conferir(inv.mochila[2]==epica and inv.mochila[3]==arma and inv.mochila[4]==vara and inv.moedas_forja==99,"Preserva outras raridades, armas, vara e materiais: "+nome)
		var bau: Dictionary = ler(pasta+"bau.json")
		conferir(bau.capacidade==40 and bau.itens==[null,null,epica,vara],"Limpa o baú sem perder capacidade e outros itens")
		conferir(ler(pasta+"introducao.json").inventario.equipados.cabeca==null,"Checkpoint do prólogo também é limpo")
		conferir(ler(pasta+"fazenda.json").galinheiro.nivel==3,"Fazenda preservada")
		p.brasas=17;p.armas_liberadas={"elmo_carrasco":true};escrever(pasta+"progresso.json",p);escrever(pasta+"inventario.json",dados)
		conferir(Migracao.preparar(pasta)==OK and ler(pasta+"progresso.json").brasas==17 and ler(pasta+"inventario.json")==dados,"Reabrir preserva conquistas novas")
		DirAccess.remove_absolute(ProjectSettings.globalize_path(pasta+Migracao.MARCADOR))
		var f := FileAccess.open(pasta+"bau.json",FileAccess.WRITE);f.store_string("{");f.close()
		conferir(Migracao.preparar(pasta)==ERR_PARSE_ERROR and ler(pasta+"progresso.json").brasas==17 and not FileAccess.file_exists(pasta+Migracao.MARCADOR),"Arquivo inválido impede escrita e confirmação")
	# Prova a ordem dos autoloads e o marcador em duas inicializações do motor.
	for pasta in ["user://","user://coop/"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(pasta+Migracao.MARCADOR))
		escrever(pasta+"progresso.json",{"brasas":999,"armas_liberadas":{"elmo_carrasco":true}})
		escrever(pasta+"inventario.json",{"mochila":[{"tipo":"receita:elmo_carrasco","categoria":"receita"}],"equipados":{"cabeca":{"tipo":"elmo_carrasco","categoria":"cabeca","raridade":"lendario"}}})
		escrever(pasta+"introducao.json",{"versao":2,"etapa":999})
	for argumento in ["--verificar-inicio","--verificar-reabertura"]:
		var saida: Array = []
		var resultado := OS.execute(OS.get_executable_path(),["--headless","--path",ProjectSettings.globalize_path("res://"),"--script","res://testes/teste_reequilibrio_save.gd","--",argumento],saida,true)
		conferir(resultado==0,"Inicialização completa do motor: "+argumento)
		if resultado!=0:
			for trecho in saida: print(trecho)
	print("REEQUILIBRIO SAVE: %d verificações; %d falhas"%[verificacoes,falhas])
	quit(1 if falhas else 0)
