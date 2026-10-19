extends Node2D
## Anima uma encomenda persistente durante o expediente; o prazo pertence ao calendário.
const Dados := preload("res://codigo/cidade/dados_cidade.gd")
const Profundidade := preload("res://codigo/globais/profundidade.gd")
const PONTO_FORNALHA := Vector2(385,74)
const PONTO_BIGORNA := Vector2(476,70)
const TEMPOS_MARTELO := [0.10,0.10,0.14,0.12,0.06,0.14]
const CICLO_MARTELO := 0.66
var etapa := ""
var tipo := ""
var inventario: Node
var resultado := ""
var _ivo: Node2D
var _tempo := 0.0
var _textura: Texture2D
var _posicao_sprite := Vector2.ZERO
var _impacto_anterior := -1
var _centelhas: Array[Dictionary] = []
var _aviso: Label
var _espera_trabalho := 0.5

func _ready() -> void:
	add_to_group("trabalhos_forja")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_as_relative = false
	z_index = Profundidade.z_de(92)+2

func ocupado() -> bool:
	return etapa != ""

func pedido_atual() -> Node:
	for oficina in get_tree().get_nodes_in_group("trabalhos_forja"):
		if oficina.ocupado():
			return oficina
	return null

func situacao(mochila: Node, receita: String) -> String:
	if not Progresso.encomenda_forja.is_empty():
		return Progresso.texto_encomenda_forja()
	return resultado if mochila == inventario and receita == tipo else ""

func iniciar(receita: String, mochila: Node) -> String:
	if pedido_atual() != null or not Progresso.encomenda_forja.is_empty():
		return "IVO JA ESTA TRABALHANDO EM UM PEDIDO"
	var cena := get_parent().get_parent()
	var fechado := Dados.atendimento_forja(cena, Calendario.dia_da_semana())
	if fechado != "":
		return fechado
	var motivo := Progresso.encomendar_arma(receita, mochila)
	if motivo != "":
		return motivo
	_iniciar_animacao(receita,mochila)
	return ""

func _iniciar_animacao(receita: String, mochila: Node) -> void:
	var cena := get_parent().get_parent()
	_ivo = cena.moradores["ferreiro"]
	_textura = _ivo.sprite.texture
	_posicao_sprite = _ivo.sprite.position
	_ivo.ocupado_na_forja = true
	_ivo.calar()
	_ivo.parceiro_papo = null
	_ivo.passeio.reiniciar()
	_aviso = Label.new()
	_aviso.name = "PedidoForja"
	_aviso.position = Vector2(-40,-36)
	_aviso.size = Vector2(80,12)
	_aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_aviso.add_theme_font_override("font",preload("res://assets/ui/Planes_ValMore.ttf"))
	_aviso.add_theme_font_size_override("font_size",8)
	_aviso.add_theme_color_override("font_color",Color("eed09c"))
	_aviso.add_theme_color_override("font_outline_color",Color("493432"))
	_aviso.add_theme_constant_override("outline_size",2)
	_ivo.add_child(_aviso)
	inventario = mochila
	tipo = receita
	resultado = ""
	_impacto_anterior = -1
	_ir_para("indo_fornalha",PONTO_FORNALHA)

func _ir_para(nova: String, ponto: Vector2) -> void:
	_voltar_folha()
	etapa = nova
	_tempo = 0
	_ivo._ir_ate(ponto)
	# Contorna a frente da fornalha; não atravessa o desenho do forno para trocar de posto.
	if nova == "indo_bigorna":
		var cena: Node = _ivo.vila
		_ivo.caminho = cena.caminho_entre(_ivo.position,Vector2(380,112))
		_ivo.caminho.append_array(cena.caminho_entre(Vector2(380,112),Vector2(484,112)))
		_ivo.caminho.append_array(cena.caminho_entre(Vector2(484,112),ponto))

func _physics_process(delta: float) -> void:
	for i in range(_centelhas.size()-1,-1,-1):
		_centelhas[i]["tempo"] += delta
		if _centelhas[i]["tempo"] > 0.22:
			_centelhas.remove_at(i)
	if not ocupado():
		_espera_trabalho -= delta
		if _espera_trabalho <= 0:
			_espera_trabalho = 1.0
			var cena := get_parent().get_parent()
			if not Progresso.encomenda_forja.is_empty() and not Progresso.encomenda_forja_pronta() and pedido_atual() == null and Dados.atendimento_forja(cena,Calendario.dia_da_semana()).is_empty():
				var dono := InventarioJogador2 if int(Progresso.encomenda_forja["jogador"]) == 2 else InventarioJogador
				_iniciar_animacao(str(Progresso.encomenda_forja["tipo"]),dono)
		queue_redraw()
		return
	if not is_instance_valid(_ivo) or not is_instance_valid(inventario):
		_concluir("")
		return
	if Progresso.encomenda_forja.is_empty() or Progresso.encomenda_forja_pronta() or Dados.servico_fechado("ferreiro",_ivo.vila.hora_atual(),Calendario.dia_da_semana()) != "":
		_concluir("")
		return
	_tempo += delta
	_aviso.text = {"indo_fornalha":"Preparando", "aquecendo":"Aquecendo", "indo_bigorna":"Preparando", "martelando":"Forjando"}.get(etapa, "")
	_ivo._soltar_atravessados()
	if etapa.begins_with("indo_"):
		_caminhar(delta)
	elif etapa == "aquecendo":
		_ivo.sprite.frame = int(_tempo/0.18)%4
		if _tempo >= 1.44:
			_ir_para("indo_bigorna",PONTO_BIGORNA)
	elif etapa == "martelando":
		var dentro := fmod(_tempo,CICLO_MARTELO)
		var quadro := 0
		while quadro < TEMPOS_MARTELO.size()-1 and dentro >= TEMPOS_MARTELO[quadro]:
			dentro -= TEMPOS_MARTELO[quadro]
			quadro += 1
		_ivo.sprite.frame = quadro
		var ciclo := int(_tempo/CICLO_MARTELO)
		if quadro == 4 and ciclo != _impacto_anterior:
			_impacto_anterior = ciclo
			_centelhas.append({"tempo":0.0,"ponto":Vector2(462,63)})
			Sons.tocar("bloqueio",0.04,-8.0)
		if _tempo >= CICLO_MARTELO*4:
			_concluir("")
	# Na lateral da bigorna, o martelo passa sobre a mesa de aço.
	_ivo.z_index = Profundidade.z_de(92)+1 if etapa == "martelando" else Profundidade.z_de(_ivo.position.y+9)
	queue_redraw()

func _caminhar(delta: float) -> void:
	if _tempo > 20:
		_concluir("CAMINHO BLOQUEADO. LIBERE A PASSAGEM E TENTE NOVAMENTE.")
		return
	if not _ivo.caminho.is_empty():
		var diferenca: Vector2 = _ivo.caminho[0]-_ivo.position
		if diferenca.length() <= 1:
			_ivo.caminho.remove_at(0)
		else:
			var colisao: KinematicCollision2D = _ivo.move_and_collide(diferenca.normalized()*minf(30*delta,diferenca.length()))
			if colisao != null and colisao.get_collider() is Node and colisao.get_collider().is_in_group("jogadores"):
				_ivo._jogador_no_caminho(colisao.get_collider(),delta)
			_ivo.sprite.frame = _ivo._direcao(diferenca)*7+1+int(_tempo*8)%6
		return
	var destino := PONTO_FORNALHA if etapa == "indo_fornalha" else PONTO_BIGORNA
	if _ivo.position.distance_to(destino) > 3:
		_concluir("NAO CONSEGUI CHEGAR A BANCADA. TENTE NOVAMENTE.")
		return
	etapa = "aquecendo" if etapa == "indo_fornalha" else "martelando"
	_tempo = 0
	_ivo.sprite.texture = load("res://assets/npcs/cidade/trabalho/ivo_%s.png" % ("aquecer" if etapa == "aquecendo" else "martelar"))
	_ivo.sprite.frame = 0
	_ivo.sprite.hframes = 4 if etapa == "aquecendo" else 6
	_ivo.sprite.vframes = 1

func _voltar_folha() -> void:
	if not is_instance_valid(_ivo):
		return
	_ivo.sprite.frame = 0
	_ivo.sprite.hframes = 7
	_ivo.sprite.vframes = 4
	_ivo.sprite.texture = _textura
	_ivo.sprite.position = _posicao_sprite

func _concluir(mensagem: String) -> void:
	resultado = mensagem
	etapa = ""
	_espera_trabalho = 10.0
	_voltar_folha()
	if is_instance_valid(_aviso):
		_aviso.queue_free()
	if is_instance_valid(_ivo):
		_ivo.caminho.clear()
		_ivo.ocupado_na_forja = false
		_ivo.atualizar_rotina()
		if _ivo.agenda.get("local", "") == _ivo.vila.local and not _ivo._saindo:
			_ivo._ir_ate(_ivo.agenda["ponto"])

func _exit_tree() -> void:
	# A encomenda já está salva e continua contando dias mesmo com o mapa descarregado.
	if ocupado():
		_concluir("")

func _draw() -> void:
	if etapa == "martelando":
		draw_rect(Rect2(to_local(Vector2(455,62)),Vector2(10,1)),Color("eaa55d"))
	for centelha in _centelhas:
		var t: float = centelha["tempo"]
		var ponto: Vector2 = to_local(centelha["ponto"])
		for vetor in [Vector2(-18,-28),Vector2(8,-36),Vector2(25,-20)]:
			var pos: Vector2 = (ponto+vetor*t+Vector2(0,60*t*t)).round()
			draw_rect(Rect2(pos,Vector2.ONE),Color("f5d188") if t < 0.1 else Color("d48a53"))
