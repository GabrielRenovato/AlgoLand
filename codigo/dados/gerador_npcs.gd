extends RefCounted
## Fichas reproduzíveis e portáteis. Só aceita IDs do catálogo local, nunca caminhos.
const Roupas=preload("res://codigo/dados/roupas_base_3d.gd")
const Variacao=preload("res://codigo/dados/variacao_npcs.gd")
const PERFIS := {
	"aventureiro":{"nome":"Aventureiro","camisa":"tunica_aventureiro","calca":"calca_sarja","calcado":"botas_couro"},
	"guarda":{"nome":"Guarda","camisa":"tabardo_guarda","calca":"calca_cargo","calcado":"botas_couro"},
	"ferreiro":{"nome":"Ferreiro","camisa":"avental_ferreiro","calca":"calca_cargo","calcado":"botinas_trabalho"},
	"agricultor":{"nome":"Agricultor","camisa":"colete_agricultor","calca":"calca_sarja","calcado":"botinas_trabalho"},
	"herbalista":{"nome":"Herbalista","camisa":"tunica_herbalista","calca":"saia_campo","calcado":"sapatilhas_vinho"},
	"mercador":{"nome":"Mercador","camisa":"colete_mercador","calca":"calca_pescador","calcado":"sapatos_viagem"},
	"camponesa":{"nome":"Camponesa","camisa":"corpete_camponesa","calca":"saia_vinho_longa","calcado":"sapatilhas_vinho"}}
const TONS_PELE := ["f4c6a4","deb08c","c89270","a46f4d","825238","563729"]
const TONS_CABELO := ["51372b","8a5835","ad713c","b94527","d6b36b","cec7bb","342a32"]
const NOMES := ["Ari","Cora","Davi","Elia","Gael","Iara","Luan","Mara","Nara","Noel","Ravi","Yuna"]

static func gerar(semente: int,perfil: String="",numero: int=0) -> Dictionary:
	var rng:=RandomNumberGenerator.new()
	rng.seed=semente
	var perfis:Array=PERFIS.keys()
	if not PERFIS.has(perfil):perfil=perfis[rng.randi_range(0,perfis.size()-1)]
	var molde:Dictionary=PERFIS[perfil]
	var roupas:=Roupas.padrao()
	for categoria in ["camisa","calca","calcado"]:roupas[categoria]=molde[categoria]
	var cabelos:Array=Roupas.MODELOS.cabelo
	roupas.cabelo=cabelos[rng.randi_range(0,cabelos.size()-1)].id
	var pele:=Color(TONS_PELE[rng.randi_range(0,TONS_PELE.size()-1)])
	var cabelo:=Color(TONS_CABELO[rng.randi_range(0,TONS_CABELO.size()-1)])
	var ficha:Dictionary={"versao":1,"id":"npc_%s_%d_%d" % [perfil,semente,numero],"nome":NOMES[rng.randi_range(0,NOMES.size()-1)],"perfil":perfil,"semente":semente,"numero":numero,"movimento":"neutro",
		"aparencia":{"versao":1,"cor_pele":[pele.r,pele.g,pele.b],"cor":[cabelo.r,cabelo.g,cabelo.b,1.0],"cor_cabelo_personalizada":true,"olhos":rng.randi_range(0,5),"roupas_3d":roupas,"equipamentos":{},"pecas_visuais":15}}
	return Variacao.aplicar(ficha)

static func normalizar(ficha: Dictionary) -> Dictionary:
	if ficha.get("versao")!=1:return {}
	var perfil:String=str(ficha.get("perfil","aventureiro"))
	var semente:int=int(ficha.get("semente",0))
	var resultado:=gerar(semente,perfil,int(ficha.get("numero",0)))
	var nome:String=str(ficha.get("nome",resultado.nome)).strip_edges().left(32)
	if not nome.is_empty():resultado.nome=nome
	if ficha.get("movimento")=="feminino":resultado.movimento="feminino"
	if ficha.get("armadura_npc","")=="guarda_novato":resultado.armadura_npc="guarda_novato"
	if ficha.get("faixa_etaria")=="crianca":
		resultado.faixa_etaria="crianca"
		resultado.traje_infantil=ficha.get("traje_infantil","campestre") if ficha.get("traje_infantil","") in ["campestre","jardineira","vestido"] else "campestre"
		resultado.cabelo_infantil=ficha.get("cabelo_infantil","franjinha") if ficha.get("cabelo_infantil","") in ["franjinha","chiquinhas","cacheado"] else "franjinha"
		resultado.movimento="neutro"
	var entrada:Variant=ficha.get("aparencia")
	if entrada is Dictionary:
		var visual:Dictionary=load("res://codigo/dados/visual_ranking.gd").normalizar(entrada)
		if not visual.is_empty():resultado.aparencia=visual
	if resultado.has("variacao"):
		if resultado.get("faixa_etaria","")=="crianca":resultado.erase("variacao")
		else:resultado.variacao=Variacao.normalizar(ficha.get("variacao"),resultado)
	if ficha.get("sobrenome") is String and Variacao.ATIVA:resultado.sobrenome=str(ficha.sobrenome).strip_edges().left(24)
	return resultado

static func salvar(ficha: Dictionary,caminho: String) -> Error:
	var valida:=normalizar(ficha)
	if valida.is_empty():return ERR_INVALID_DATA
	var arquivo:=FileAccess.open(caminho,FileAccess.WRITE)
	if arquivo==null:return FileAccess.get_open_error()
	arquivo.store_string(JSON.stringify(valida,"\t")+"\n")
	return OK

static func carregar(caminho: String) -> Dictionary:
	if not FileAccess.file_exists(caminho):return {}
	var dados:Variant=JSON.parse_string(FileAccess.get_file_as_string(caminho))
	return normalizar(dados) if dados is Dictionary else {}
