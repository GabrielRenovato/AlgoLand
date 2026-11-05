extends "res://codigo/ui/previa_heroi_3d.gd"
## Avatar visual isolado para mochila, lobby e pódio. Não executa combate nem grava saves.
const Visual := preload("res://codigo/dados/visual_ranking.gd")
signal renderizado
var aparencia: Dictionary = {}
var armadura_npc: String = ""
var pecas_armadura_npc: int = 15
var perfil_movimento: String = "neutro"
var inventario: RefCounted
var id_lanca_atual := "lanca_basica"

class ArcoVisual extends Node:
	const DURACAO_DISPARO := [0.18,0.1,0.1,0.1,0.4,0.05,0.05,0.1]
	const QUADRO_SOLTAR := 5
	var _tempo := 0.0
	var _indice := 0
	var _escala_tempo := 1.0
var no_arco: Node

func _ready() -> void:
	var dados := Visual.normalizar(aparencia)
	if dados.is_empty(): dados = Visual.normalizar({"versao":1})
	aparencia_raven = dados
	roupas_3d = dados.roupas_3d
	var modelo := Visual.criar_modelo(dados)
	inventario = modelo.inventario
	usando_espada = modelo.usando_espada
	usando_arco = modelo.usando_arco
	usando_lanca = modelo.usando_lanca
	usando_escudo = modelo.usando_escudo
	id_arma_atual = modelo.id_arma_atual
	id_lanca_atual = modelo.id_lanca_atual
	modelo.free()
	no_arco = ArcoVisual.new()
	add_child(no_arco)
	super._ready()
	heroi._player.add_animation_library("npcs",load("res://assets/personagens/base_3d/movimentos_npcs.res"))
	pose(false,0,0)
	_anunciar_render.call_deferred()

func _anunciar_render() -> void:
	# Aguarda o primeiro desenho do SubViewport antes de medir a silhueta.
	await RenderingServer.frame_post_draw
	if is_inside_tree(): renderizado.emit()

func _posar(acao: String, clipe: String, direcao: int, instante: float) -> void:
	heroi._acabamento_armas.atualizar()
	heroi._acao = acao
	heroi._modelo.rotation.y = DIRECOES[posmod(direcao,4)]
	heroi._guinada = heroi._modelo.rotation.y
	_direcao_ataque = [Vector2.DOWN,Vector2.RIGHT,Vector2.UP,Vector2.LEFT][posmod(direcao,4)]
	_direcao_golpe_3d = _direcao_ataque
	heroi._atualizar_iluminacao()
	heroi._player.play(clipe)
	heroi._player.speed_scale = 0.0
	heroi._player.seek(instante,true)
	heroi._encaixar_espada(acao in ["espada","lanca","guarda","guarda_livre"])
	heroi._encaixar_arma_pesada(acao in ["pesada","guarda_livre"])

func pose(correndo: bool, direcao: int, tempo: float) -> void:
	var acao := "correr" if correndo else "parado"
	var clipe: String = heroi._nome_animacao(acao)
	_posar(acao,clipe,direcao,fposmod(tempo,heroi._player.get_animation(clipe).length))

## Caminhada nativa do modelo, independente da corrida do jogador.
func duracao_caminhada() -> float:
	return heroi._player.get_animation("npcs/Caminhada_Feminina" if perfil_movimento=="feminino" else "Walk_Loop").length

func passada_caminhada() -> float:
	return float(heroi._player.get_animation_library("npcs").get_meta("passada_feminina_px")) if perfil_movimento=="feminino" else 5.0

func pose_caminhada(andando: bool,direcao: int,tempo: float) -> void:
	if not andando:
		if perfil_movimento=="feminino":
			var descanso:="npcs/Descanso_Feminino"
			_posar("parado",descanso,direcao,fposmod(tempo,heroi._player.get_animation(descanso).length))
			return
		pose(false,direcao,tempo)
		return
	var clipe:="Walk_Loop"
	if perfil_movimento=="feminino":clipe="npcs/Caminhada_Feminina"
	_posar("andar",clipe,direcao,fposmod(tempo,heroi._player.get_animation(clipe).length))

func pose_conversa(direcao: int,tempo: float) -> void:
	if perfil_movimento!="feminino":
		pose_caminhada(false,direcao,tempo)
		return
	var clipe:="npcs/Conversa_Feminina"
	_posar("parado",clipe,direcao,fposmod(tempo,heroi._player.get_animation(clipe).length))

func nome_do_golpe(combo: int) -> String:
	_fase_combo = maxi(1,combo)
	if usando_lanca: return "lanca"
	if id_arma_atual in ["machado","maca"]: return "pesada"
	return "espada"

func pose_acao(acao: String, coluna: int, direcao: int, progresso := -1.0) -> void:
	if acao=="esquiva": acao="avanco"
	var p := clampf(progresso if progresso>=0 else coluna/4.0,0.0,0.999)
	if acao=="arco":
		var total := 0.0
		for duracao in ArcoVisual.DURACAO_DISPARO: total += duracao
		var restante := p*total
		no_arco._indice = 0
		for i in ArcoVisual.DURACAO_DISPARO.size():
			no_arco._indice = i
			if restante<ArcoVisual.DURACAO_DISPARO[i]: break
			restante -= ArcoVisual.DURACAO_DISPARO[i]
		no_arco._tempo = restante
	var clipe: String = heroi._nome_animacao(acao)
	var duracao: float = heroi._player.get_animation(clipe).length
	if acao=="arco": p=minf(p/.40,0.999) if p<.40 else clampf((p-.40)/.60,0.0,0.999)
	if acao=="avanco": p=lerpf(heroi.JANELA_DASH.x,heroi.JANELA_DASH.y,p)
	if acao=="pesada": p=lerpf(heroi.JANELA_PESADA.x,heroi.JANELA_PESADA.y,p)
	if acao in ["espada","lanca"]: heroi._progresso_golpe=p
	_posar(acao,clipe,direcao,p*duracao)

func pose_pesca(quadro: int, direcao: int) -> void:
	var clipe := "mixamo/FishingIdle" if quadro==3 else "mixamo/FishingCast"
	_posar("pesca",clipe,direcao,0.0 if quadro==3 else [1.05,1.5,2.0][clampi(quadro,0,2)])

func retangulo_aparente() -> Rect2:
	var usado: Rect2i = heroi.imagem_quadro().get_used_rect()
	return heroi.transform*heroi._sprite.transform*Rect2(Vector2(usado.position)+heroi._sprite.offset,Vector2(usado.size))

func topo_aparente() -> float:
	var retangulo := retangulo_aparente()
	return retangulo.position.y if retangulo.has_area() else -40.0
