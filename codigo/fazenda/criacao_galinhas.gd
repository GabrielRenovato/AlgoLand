extends RefCounted

const PRAZOS := [0,2,3,4]
const CAPACIDADES := [0,4,8,12]
const CUSTOS := [{},{"madeira":12,"pedra":8},{"madeira":24,"pedra":16,"ferro":4},{"madeira":40,"pedra":24,"ferro":8}]
const NOMES := ["Pipoca","Farofa","Canela","Pacoca","Pena","Nuvem","Aurora","Pintinha","Mel","Neve","Cacau","Luna"]
const PRECO_GALINHA := 25
const MAX_OVOS := 7

static func inicial() -> Dictionary:
	return {"nivel":0,"obra":0,"pronto_dia":-1,"inicio_obra":-1,"racao":0,"feno_colocado":false,"ultimo_dia":-1,"portinha_aberta":true,"incubacao":-1,"reserva_feno":0,"aves":[]}

static func ler(bruto: Variant) -> Dictionary:
	var estado := inicial()
	if not bruto is Dictionary: return estado
	for chave in ["nivel","obra"]: estado[chave] = clampi(int(bruto.get(chave,0)),0,3)
	estado.pronto_dia = maxi(-1,int(bruto.get("pronto_dia",-1)))
	estado.inicio_obra = maxi(-1,int(bruto.get("inicio_obra",estado.pronto_dia-maxi(1,estado.obra))))
	estado.ultimo_dia = maxi(-1,int(bruto.get("ultimo_dia",-1)))
	estado.feno_colocado = bool(bruto.get("feno_colocado",false))
	estado.portinha_aberta = bool(bruto.get("portinha_aberta",true))
	estado.incubacao = maxi(-1,int(bruto.get("incubacao",-1)))
	estado.reserva_feno = clampi(int(bruto.get("reserva_feno",0)),0,168)
	estado.racao = clampi(int(bruto.get("racao",0)),0,168)
	if bruto.get("aves",[]) is Array:
		for ave in bruto.get("aves",[]):
			if not ave is Dictionary or estado.aves.size() >= CAPACIDADES[estado.nivel]: continue
			estado.aves.append({"nome":str(ave.get("nome",NOMES[estado.aves.size()])).strip_edges().left(16),
				"vinculo":clampi(int(ave.get("vinculo",0)),0,100),"carinho_dia":maxi(-1,int(ave.get("carinho_dia",-1))),
				"ovos":clampi(int(ave.get("ovos",0)),0,MAX_OVOS),"cor":clampi(int(ave.get("cor",0)),0,2),
				"sexo":"galo" if ave.get("sexo","") == "galo" else "galinha", "nascimento":int(ave.get("nascimento",-10))})
	if not estado.feno_colocado:
		estado.reserva_feno += estado.racao
		estado.racao = 0
	return estado

## Fração visual avança no expediente; à noite mantém a última etapa alcançada.
static func progresso_obra(estado: Dictionary, dia: int, hora: float) -> float:
	if int(estado.obra) <= 0: return 0.0
	var inicio := int(estado.get("inicio_obra",int(estado.pronto_dia)-maxi(1,int(estado.obra))))
	var prazo := maxi(1,int(estado.pronto_dia)-inicio)
	var turno := 1.0 if hora < 6 or hora >= 17 else clampf((hora-8.0)/9.0,0.0,1.0)
	return clampf((float(dia-inicio)+turno)/prazo,0.0,1.0)

static func etapa_obra(estado: Dictionary, dia: int, hora: float) -> int:
	return mini(2,floori(progresso_obra(estado,dia,hora)*3.0))

static func capacidade(fazenda: Node) -> int:
	return CAPACIDADES[int(fazenda.galinheiro.nivel)]

static func total_ovos(fazenda: Node) -> int:
	var total := 0
	for ave in fazenda.galinheiro.aves: total += int(ave.ovos)
	return total

static func nova_ave(indice: int, sexo := "galinha", nascimento := -10) -> Dictionary:
	return {"nome":"Cocorico" if sexo == "galo" else NOMES[posmod(indice,NOMES.size())],"vinculo":0,"carinho_dia":-1,"ovos":0,"cor":indice%3,"sexo":sexo,"nascimento":nascimento}

static func adulta(ave: Dictionary, dia: int) -> bool:
	return dia-int(ave.get("nascimento",-10)) >= 5

static func tem_galo(estado: Dictionary, dia: int) -> bool:
	return estado.aves.any(func(a): return a.get("sexo","") == "galo" and adulta(a,dia))

static func avancar(fazenda: Node, dia: int) -> void:
	var estado: Dictionary = fazenda.galinheiro
	if dia <= int(estado.ultimo_dia): return
	if fazenda.get("bando") != null: fazenda.bando.reiniciar()
	estado.ultimo_dia = dia
	if estado.obra > 0 and dia >= int(estado.pronto_dia):
		estado.nivel = estado.obra
		estado.obra = 0
		if estado.aves.is_empty():
			estado.aves = [nova_ave(0),nova_ave(1),nova_ave(2,"galo")]
			estado.racao = 0
			# A primeira noite é a conclusão da obra, não uma produção retroativa.
			return
	if estado.incubacao >= 0 and dia >= estado.incubacao and estado.aves.size() < capacidade(fazenda):
		estado.aves.append(nova_ave(estado.aves.size(),"galinha",dia))
		estado.incubacao = -1
	if not estado.feno_colocado: return
	for ave in estado.aves:
		if estado.racao <= 0: continue
		estado.racao -= 1
		ave.vinculo = mini(100,int(ave.vinculo)+1)
		if ave.get("sexo","galinha") == "galinha" and adulta(ave,dia): ave.ovos = mini(MAX_OVOS,int(ave.ovos)+1)
	# Falta de ração apenas pausa a produção: sem morte, perda de vínculo ou ovos estragados.

static func _inventario(quem: Node) -> Node:
	return quem.inventario

static func _confirmar(fazenda: Node, quem: Node, antes: Dictionary, mochila: Array, brasas: int) -> String:
	var inv := _inventario(quem)
	var progresso: Node = fazenda.get_node("/root/Progresso")
	if not inv.salvar() or not fazenda.salvar() or not progresso.salvar():
		fazenda.galinheiro = antes
		inv.restaurar_mochila(mochila)
		progresso.brasas = brasas
		inv.salvar()
		fazenda.salvar()
		progresso.salvar()
		return "NAO FOI POSSIVEL SALVAR. TENTE NOVAMENTE."
	fazenda.galinheiro_alterado.emit()
	fazenda.bolsas_alteradas.emit()
	progresso.brasas_alteradas.emit(progresso.brasas)
	return ""

static func executar(fazenda: Node, quem: Node, acao: String, indice := -1, nome := "") -> String:
	if quem == null: return "JOGADOR INDISPONIVEL"
	var inv := _inventario(quem)
	var estado: Dictionary = fazenda.galinheiro
	var antes := estado.duplicate(true)
	var mochila: Array = inv.fotografar_mochila()
	var progresso: Node = fazenda.get_node("/root/Progresso")
	var brasas: int = progresso.brasas
	var calendario: Node = fazenda.get_node("/root/Calendario")
	match acao:
		"portinha":
			if estado.nivel == 0: return "CONSTRUA O GALINHEIRO PRIMEIRO"
			estado.portinha_aberta = not estado.portinha_aberta
		"construir":
			if estado.obra > 0: return "A OBRA JA ESTA EM ANDAMENTO"
			if estado.nivel >= 3: return "GALINHEIRO NO NIVEL MAXIMO"
			var proximo: int = estado.nivel+1
			for material in CUSTOS[proximo]:
				if inv.quantidade_tipo("material:"+material) < CUSTOS[proximo][material]: return "FALTAM MATERIAIS NA SUA MOCHILA"
			for material in CUSTOS[proximo]: inv.gastar_tipo("material:"+material,CUSTOS[proximo][material])
			estado.obra = proximo
			estado.inicio_obra = calendario.dia
			estado.pronto_dia = calendario.dia+PRAZOS[proximo]
		"comprar", "comprar_galo":
			if estado.nivel == 0: return "CONSTRUA O GALINHEIRO PRIMEIRO"
			if estado.aves.size()+int(estado.incubacao >= 0) >= capacidade(fazenda): return "GALINHEIRO CHEIO. AMPLIE PARA RECEBER MAIS AVES"
			if progresso.brasas < PRECO_GALINHA: return "FALTAM BRASAS"
			progresso.brasas -= PRECO_GALINHA
			estado.aves.append(nova_ave(estado.aves.size(),"galo" if acao == "comprar_galo" else "galinha"))
		"preparar_feno":
			if estado.nivel == 0: return "CONSTRUA O GALINHEIRO PRIMEIRO"
			if estado.reserva_feno > 0:
				var retirar := mini(14,int(estado.reserva_feno))
				if not inv.adicionar_coletavel("produto","feno",retirar): return "MOCHILA CHEIA"
				estado.reserva_feno -= retirar
			else:
				if inv.quantidade_tipo("material:fibra") < 2: return "TRAGA 2 FIBRAS PARA PREPARAR 14 FENOS"
				if not inv.adicionar_coletavel("produto","feno",14): return "MOCHILA CHEIA"
				inv.gastar_tipo("material:fibra",2)
		"lancar_feno":
			if estado.nivel == 0: return "CONSTRUA O GALINHEIRO PRIMEIRO"
			if estado.racao >= capacidade(fazenda)*7: return "COMEDOURO CHEIO"
			if inv.quantidade_tipo("produto:feno") < 1: return "RETIRE FENO NO DEPOSITO"
			inv.gastar_tipo("produto:feno",1)
			estado.racao += 1
			estado.feno_colocado = true
		"incubar":
			if estado.incubacao >= 0: return "JA HA UM OVO CHOCANDO"
			if estado.aves.size() >= capacidade(fazenda): return "AMPLIE O ABRIGO PARA RECEBER UM PINTINHO"
			if not tem_galo(estado,calendario.dia): return "PRECISA DE UM GALO ADULTO PARA UM OVO FERTIL"
			var mae := -1
			for i in estado.aves.size():
				if estado.aves[i].get("sexo","galinha") == "galinha" and estado.aves[i].ovos > 0: mae = i; break
			if mae < 0: return "ESPERE UMA GALINHA BOTAR UM OVO"
			estado.aves[mae].ovos -= 1
			estado.incubacao = calendario.dia+3
		"recolher":
			var ovos := total_ovos(fazenda)
			if ovos <= 0: return "AINDA NAO HA OVOS NOS NINHOS"
			if not inv.adicionar_coletavel("produto","ovo",ovos): return "MOCHILA CHEIA. OS OVOS CONTINUAM NOS NINHOS"
			for ave in estado.aves: ave.ovos = 0
		"carinho", "renomear":
			if indice < 0 or indice >= estado.aves.size(): return "GALINHA INDISPONIVEL"
			var ave: Dictionary = estado.aves[indice]
			if acao == "carinho":
				if ave.carinho_dia == calendario.dia: return "ESSA AVE JA RECEBEU CARINHO HOJE"
				ave.carinho_dia = calendario.dia
				ave.vinculo = mini(100,int(ave.vinculo)+3)
			else:
				nome = nome.strip_edges().left(16)
				if nome.is_empty(): return "ESCOLHA UM NOME PARA SUA GALINHA"
				ave.nome = nome
		_:
			return "ACAO INVALIDA"
	return _confirmar(fazenda,quem,antes,mochila,brasas)
