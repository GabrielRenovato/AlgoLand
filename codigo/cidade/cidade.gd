extends "res://codigo/logica/fazenda.gd"

const ClimaCidade := preload("res://codigo/cenario/clima.gd")
const DadosCidade := preload("res://codigo/cidade/dados_cidade.gd")
const MoradorCidade := preload("res://codigo/cidade/morador_cidade.gd")
const InteragivelCidade := preload("res://codigo/logica/interagivel.gd")
const PortalArena := preload("res://codigo/cidade/portal_arena.gd")
const InteriorCasa := preload("res://codigo/cidade/interior_casa.gd")
const Profundidade := preload("res://codigo/globais/profundidade.gd")
const CercasVila := preload("res://codigo/cidade/cercas_vila.gd")
const DecoracaoVila := preload("res://codigo/cidade/decoracao_vila.gd")
const SombraCidade := preload("res://codigo/cidade/sombra_cidade.gd")
const BordasGrama := preload("res://codigo/cidade/bordas_grama.gd")
const NUVENS_SUAVES := preload("res://codigo/cidade/nuvens_suaves.gdshader")
## Base do arco do portal da arena (a chegada do jogador, "Chegada_portal", fica logo abaixo)
const POSICAO_PORTAL := Vector2(488, 112)
@export var local := "cidade"
var moradores: Dictionary = {}
var apoio_helena: Node
var navegacao := AStarGrid2D.new()
var _navegacao_cadeira := AStarGrid2D.new()
var _tempo_rotina := 0.0
var _decoracao: Node2D
var _estacao_visual := -1
## Materiais do PixelLab por estação e máscaras de transição Wang (ids e colisões são preservados).
const ESTACOES_TERRENO := ["primavera", "verao", "outono", "inverno"]
const PARES_TERRENO := ["grama_terra", "grama_pedra", "terra_pedra"]
var _material_agua: ShaderMaterial
var _agua_viva = preload("res://codigo/cenario/agua_viva.gd").new()
var _camada_agua: TileMapLayer
var _terra_mascarada = preload("res://codigo/cenario/terra_mascarada.gd").new()
var _bordas_grama: Node2D
var _chao_detalhado: Node2D

func _ready() -> void:
	if local == "cidade":
		super._ready()
		var clima := get_tree().get_first_node_in_group("clima")
		if clima != null:
			var cobertura := clima.get_node_or_null("Mundo/Nuvens/Cobertura") as TextureRect
			if cobertura != null:
				var material_nuvens := ShaderMaterial.new()
				material_nuvens.shader = NUVENS_SUAVES
				cobertura.material = material_nuvens
	else:
		# Quando o interior inteiro cabe na tela (zoom 1, como o resto do jogo), a câmera fica fixa no centro da
		# casa. Casa maior que a tela, ou o celular com o zoom maior: ela acompanha o jogador sem sair da casa.
		var camera: Camera2D = $Jogador.camera
		camera.position_smoothing_enabled = false
		var tela := get_viewport().get_visible_rect().size / camera.zoom
		if Controle.usando_toque or limites.size.x > tela.x or limites.size.y > tela.y:
			# No eixo em que a casa cabe, os limites crescem até a tela, com a casa no meio
			var area := limites
			if not Controle.usando_toque:
				area = area.grow_individual(maxf(0, tela.x - area.size.x) / 2, maxf(0, tela.y - area.size.y) / 2,
					maxf(0, tela.x - area.size.x) / 2, maxf(0, tela.y - area.size.y) / 2)
			camera.limit_left = int(area.position.x)
			camera.limit_top = int(area.position.y)
			camera.limit_right = int(area.end.x)
			camera.limit_bottom = int(area.end.y)
		else:
			camera.set_as_top_level(true)
			camera.global_position = limites.get_center()
	if local == "cidade":
		_montar_portal()
		# A decoração entra antes da navegação, para os moradores contornarem barracas, bancos e árvores
		_montar_decoracao()
		add_child(preload("res://codigo/cidade/podio_ranking.gd").new())
		var quintal := preload("res://codigo/cidade/quintal_carpinteiro.gd").new()
		add_child(quintal)
		var selo := preload("res://codigo/cidade/selo_limiar.gd").new()
		selo.name = "SeloDoLimiar"
		selo.position = DadosCidade.ponto("poco") + Vector2(0,12)
		add_child(selo)
	_montar_navegacao()
	Cidade.visitar(local)
	if not Progresso.partida_ativa:
		Progresso.iniciar_partida()
		if DadosJogo.moedas == 0:
			DadosJogo.definir_ouro_inicial()
			DadosJogo.atualizar_ui_moedas()
	for id in DadosCidade.MORADORES:
		if id == "nilo":
			continue
		var npc := MoradorCidade.new()
		npc.name = id.capitalize()
		npc.id = id
		npc.vila = self
		add_child(npc)
		moradores[id] = npc
	apoio_helena = preload("res://codigo/cidade/apoio_helena.gd").new()
	add_child(apoio_helena)
	if local == "cidade":
		var nilo := preload("res://codigo/pesca/pescador.gd").new()
		nilo.name = "Nilo"
		add_child(nilo)
	if local == "pousada":
		add_child(preload("res://codigo/cidade/rotina_taverna.gd").new())
	var meteorologia := get_node_or_null("Terrains/Estacoes/Meteorologia")
	if meteorologia != null:
		meteorologia.clima_mudou.connect(_ao_clima_mudou)
	Fazenda.clima_do_dia_mudou.connect(_ao_clima_mudou)
	if local in ["cidade","praia"]:
		var lobby := preload("res://codigo/cidade/lobby_cidade.gd").new()
		lobby.mapa = 1 if local == "cidade" else 3
		add_child(lobby)
	_montar_mural()
	Calendario.estacao_mudou.connect(_ao_estacao)
	var estacoes_cidade := get_node_or_null("Terrains/Estacoes")
	if estacoes_cidade != null:
		estacoes_cidade.estacao_mudou.connect(_ao_estacao)
	_atualizar_ambiente()
	if local == "enfermaria" and Transicao.acordou_ferido:
		Transicao.acordou_ferido = false
		_rosa_cuida_do_ferido()

## Caiu na arena e acordou num leito: a Rosa conta que cuidou dele e pede cuidado (um jeito diferente a cada vez)
const FALAS_ENFERMARIA := [
	["Calma, nao levanta de uma vez! Te trouxeram da arena desacordado.", "Ja cuidei dos seus ferimentos. Voce esta novinho em folha.", "Mas toma mais cuidado la dentro, ouviu? Leve pocoes!"],
	["Ai, meu bem, de novo por aqui? Os curativos ja estao no lugar.", "Voce esta curado. Agora coma alguma coisa antes de voltar para aquela arena."],
	["Pronto, pronto. Febre baixou e os cortes fecharam.", "Voce esta curado, mas eu nao quero te ver neste leito tao cedo. Cuidado!"],
]

## Leito do paciente, separado do quarto da Rosa; recorte do travesseiro em pixels lógicos.
const LEITO_FERIDO := Vector2(372, 96)
const TRAVESSEIRO := 13

func _rosa_cuida_do_ferido() -> void:
	var jogador: Node2D = $Jogador
	# A Transicao põe o jogador no marcador e só depois clareia: deita entre uma coisa e outra, ainda no escuro
	while Transicao.retornando:
		await get_tree().process_frame
	var cobertor := _deitar_no_leito(jogador)
	jogador.set_physics_process(false)
	if Transicao.ocupada:
		await Transicao.troca_concluida
	await get_tree().create_timer(0.6).timeout
	_rosa_ao_lado_do_leito(jogador)
	var dialogo: Control = EventosJogo.interface_p1()._telas["introducao"]
	var falas: Array[String] = []
	falas.assign(FALAS_ENFERMARIA[randi() % FALAS_ENFERMARIA.size()])
	dialogo.iniciar(falas, "DONA ROSA", "curandeira")
	EventosJogo.abrir_tela.emit("introducao")
	await dialogo.concluido
	# Levanta sozinho, ao pé do leito
	await get_tree().create_timer(0.3).timeout
	if is_instance_valid(cobertor):
		cobertor.queue_free()
	if is_instance_valid(jogador):
		jogador.show()
		jogador.levantar(LEITO_FERIDO + Vector2(0, 26))
		jogador.set_physics_process(true)
	var rosa: Node2D = moradores.get("curandeira")
	if is_instance_valid(rosa):
		rosa.cuidando_de_paciente = false
		rosa._agenda_base.clear()
		rosa.atualizar_rotina()

## A Rosa fica de pé ao lado do leito, olhando para o jogador (acordada, mesmo que a rotina dela fosse outra; depois
## ela volta a andar pela própria agenda)
func _rosa_ao_lado_do_leito(jogador: Node2D) -> void:
	var rosa: Node2D = moradores.get("curandeira")
	if rosa == null:
		return
	rosa.cuidando_de_paciente = true
	if rosa.dormindo:
		rosa._acordar()
	rosa.visible = true
	rosa._saindo = false
	rosa.caminho.clear()
	rosa.position = LEITO_FERIDO + Vector2(26, 14)
	rosa._atualizar_colisao()
	rosa.olhar_para(jogador.position)

## Deita o jogador no leito: conserva o estado de repouso e mostra a cabeça Raven
## sob o cobertor recortado na escala da cama. Devolve a representação para remover ao levantar.
func _deitar_no_leito(jogador: Node2D) -> Node2D:
	var cama: Node2D = null
	for no in $Interior.get_children():
		if no is Node2D and no.position == LEITO_FERIDO and no.get_node_or_null("Imagem") != null:
			cama = no
	if cama == null:
		return null
	var imagem: Sprite2D = cama.get_node("Imagem")
	# A imagem da cama é uma folha com quadros (estações/variações): recorta só o quadro em uso
	var quadro := Vector2(imagem.texture.get_width() / imagem.hframes, imagem.texture.get_height() / imagem.vframes)
	var canto := Vector2(imagem.frame % imagem.hframes, imagem.frame / imagem.hframes) * quadro
	var altura := quadro.y * absf(imagem.scale.y)
	var corte := TRAVESSEIRO / absf(imagem.scale.y)
	jogador.sentar(LEITO_FERIDO + Vector2(0,12),1,cama.z_index+1,1)
	var paciente := Node2D.new()
	paciente.name = "PacienteNoLeito"
	cama.add_child(paciente)
	var cabeca := preload("res://codigo/cenario/cama.gd").criar_cabeca(jogador)
	jogador.hide()
	cabeca.name = "Cabeca"
	cabeca.position = Vector2(-12,-altura-6)
	cabeca.z_as_relative = false
	cabeca.z_index = cama.z_index + 1
	paciente.add_child(cabeca)
	var cobertor: Sprite2D = imagem.duplicate()
	cobertor.name = "Cobertor"
	cobertor.hframes = 1
	cobertor.vframes = 1
	cobertor.frame = 0
	cobertor.region_enabled = true
	cobertor.region_rect = Rect2(canto + Vector2(0,corte),Vector2(quadro.x,quadro.y-corte))
	cobertor.offset.y += corte
	cobertor.z_as_relative = false
	cobertor.z_index = cama.z_index + 1 + Profundidade.NIVEIS
	paciente.add_child(cobertor)
	return paciente

## Na rua usa o clima exibido (inclusive F3); dentro das casas usa o tempo compartilhado do mundo.
func clima_atual() -> int:
	var meteorologia := get_node_or_null("Terrains/Estacoes/Meteorologia")
	if meteorologia != null:
		return meteorologia.clima_atual
	return ClimaCidade.clima_do_mundo(Calendario.estacao())

func _ao_clima_mudou(_estado: int) -> void:
	for npc in moradores.values():
		npc.atualizar_rotina()

func hora_atual() -> float:
	return $Iluminacao.hora

func _process(delta: float) -> void:
	_atualizar_papo(delta)
	_tempo_rotina += delta
	if _tempo_rotina >= 0.5:
		_tempo_rotina = 0
		for npc in moradores.values():
			npc.atualizar_rotina()
		_atualizar_ambiente()
		_tentar_papo_entre_vizinhos()

# --- Papo entre moradores ---------------------------------------------------------------------------------------

const Papos := preload("res://codigo/cidade/papos_vizinhos.gd")
const DISTANCIA_PAPO := 58.0
const DISTANCIA_JOGADOR_PAPO := 220.0
const INTERVALO_PAPO := 24.0
var _proximo_papo := 8.0
var _participantes: Array[Node2D] = []
var _falas_papo: Array[Dictionary] = []
var _indice_papo := 0
var _tempo_fala := 0.0
var _clima_papo := -1
var fala_servico := false
var _historico_papos: Dictionary = {}
var _reencontro: Dictionary = {}

func _tentar_papo_entre_vizinhos() -> void:
	if Cidade.dialogo_aberto_no_ambiente(self): return
	var agora := Time.get_ticks_msec() / 1000.0
	if not _participantes.is_empty() or agora < _proximo_papo or randf() > 0.35:
		return
	var livres: Array = moradores.values().filter(func(npc):
		var jogador := Cooperativo.jogador_no_ambiente(npc)
		return npc.livre_para_papo() and jogador != null and npc.global_position.distance_to(jogador.global_position) < DISTANCIA_JOGADOR_PAPO
	)
	livres.shuffle()
	for a in livres:
		for b in livres:
			if a == b or a.position.distance_to(b.position) > DISTANCIA_PAPO:
				continue
			var chave := _chave_papo(a.id, b.id)
			if agora < float(_reencontro.get(chave, 0.0)):
				continue
			_papo(a, b)
			return

func _chave_papo(a: String, b: String) -> String:
	return a + "|" + b if a < b else b + "|" + a

func _papo(a: Node2D, b: Node2D) -> void:
	if not _participantes.is_empty() or a == b:
		return
	var chave := _chave_papo(a.id, b.id)
	var contexto := {"clima": clima_atual(), "estacao": Calendario.estacao(),
		"vencida": Progresso.maior_onda_vencida, "chefe": Progresso.checkpoint_max,
		"nome_chefe": Papos.Conversa.chefe_da_onda(Progresso.checkpoint_max)}
	_falas_papo = Papos.montar(a.id, b.id, contexto, int(_historico_papos.get(chave, 0)))
	if _falas_papo.is_empty():
		return
	_historico_papos[chave] = int(_historico_papos.get(chave, 0)) + 1
	_participantes.assign([a, b])
	_clima_papo = clima_atual()
	_indice_papo = 0
	_tempo_fala = 0.0
	a.parceiro_papo = b
	b.parceiro_papo = a
	a.olhar_para(b.position)
	b.olhar_para(a.position)
	for npc in moradores.values():
		npc.calar()
	_atualizar_papo(0.0)

func _atualizar_papo(delta: float) -> void:
	if _participantes.is_empty():
		return
	for npc in _participantes:
		if not is_instance_valid(npc) or not npc.pode_continuar_papo() or clima_atual() != _clima_papo:
			_encerrar_papo()
			return
	if _participantes[0].position.distance_to(_participantes[1].position) > DISTANCIA_PAPO + 8.0:
		_encerrar_papo()
		return
	if fala_servico:
		return
	_tempo_fala -= delta
	if _tempo_fala > 0:
		return
	if _indice_papo >= _falas_papo.size():
		_encerrar_papo()
		return
	for npc in _participantes:
		npc.calar()
	var fala: Dictionary = _falas_papo[_indice_papo]
	var quem: Node2D = _participantes[0] if _participantes[0].id == fala["dono"] else _participantes[1]
	_tempo_fala = Papos.duracao(fala["texto"]) + 0.35
	quem.dizer(DadosCidade.MORADORES[quem.id]["nome"] + ": " + fala["texto"], _tempo_fala - 0.35)
	_indice_papo += 1

func _encerrar_papo() -> void:
	if _participantes.size() == 2 and is_instance_valid(_participantes[0]) and is_instance_valid(_participantes[1]):
		_reencontro[_chave_papo(_participantes[0].id, _participantes[1].id)] = Time.get_ticks_msec() / 1000.0 + 180.0
	for npc in _participantes:
		if is_instance_valid(npc):
			npc.calar()
			npc.parceiro_papo = null
			npc._espera_balao = 15.0
	_participantes.clear()
	_falas_papo.clear()
	_proximo_papo = Time.get_ticks_msec() / 1000.0 + INTERVALO_PAPO

func _ao_estacao(_estacao: int) -> void:
	for npc in moradores.values():
		npc.atualizar_rotina()
	_atualizar_ambiente()

func porta_do_local(destino: String) -> Vector2:
	if local == "praia":
		return $Chegada_palafita.position if destino == "palafita" else $Chegada_cidade.position
	if local != "cidade":
		return $Chegada_entrada.position
	if destino == "fazenda":
		return $Chegada_fazenda.position
	if destino in ["praia","palafita"]:
		return $Chegada_praia.position
	if DadosCidade.PREDIOS.has(destino):
		return DadosCidade.PREDIOS[destino]["base"] + Vector2(DadosCidade.PREDIOS[destino]["porta_x"], 36)
	return DadosCidade.ponto("praca")

func ajustar_posicao_continuacao(ponto: Vector2) -> Vector2:
	if local != "carpintaria": return ponto
	# A planta anterior era uma sala única; uma posição antiga pode cair numa parede nova.
	var celula := Vector2i(to_local(ponto)/navegacao.cell_size)
	if navegacao.is_in_boundsv(celula) and not navegacao.is_point_solid(celula): return ponto
	return $Chegada_entrada.global_position

func _montar_navegacao() -> void:
	_montar_grade(navegacao,6)
	_montar_grade(_navegacao_cadeira,10)

func _montar_grade(grade: AStarGrid2D, folga: float) -> void:
	grade.cell_size = Vector2(8, 8) if local != "cidade" else Vector2(16, 16)
	grade.region = Rect2i(Vector2i.ZERO, Vector2i(limites.size / grade.cell_size))
	grade.offset = grade.cell_size * 0.5
	grade.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	grade.update()
	for cuerpo in find_children("*", "StaticBody2D", true, false):
		for forma in cuerpo.get_children():
			if forma is CollisionShape2D and forma.disabled:
				continue
			var area := Rect2()
			var poligono := PackedVector2Array()
			if forma is CollisionShape2D and forma.shape is RectangleShape2D:
				area = Rect2(forma.global_position - forma.shape.size * 0.5, forma.shape.size)
			elif forma is CollisionPolygon2D:
				for p in forma.polygon:
					poligono.append(forma.to_global(p))
					if area.size == Vector2.ZERO:
						area = Rect2(forma.to_global(p), Vector2(0.01, 0.01))
					else:
						area = area.expand(forma.to_global(p))
			else:
				continue
			# A rota representa a posição do corpo; os pés ficam nove pixels abaixo.
			area.position.y -= 9
			area = area.grow(folga)
			for y in grade.region.size.y:
				for x in grade.region.size.x:
					var celula := Vector2i(x, y)
					var ponto := grade.get_point_position(celula)
					if not area.has_point(ponto):
						continue
					if poligono.is_empty():
						grade.set_point_solid(celula)
					else:
						# Não bloquear terra seca dentro do retângulo que envolve o lago.
						for margem in [Vector2.ZERO, Vector2(-folga, 0), Vector2(folga, 0), Vector2(0, -folga), Vector2(0, folga)]:
							if Geometry2D.is_point_in_polygon(ponto + Vector2(0, 9) + margem, poligono):
								grade.set_point_solid(celula)
								break

func caminho_entre(inicio: Vector2, fim: Vector2, grade: AStarGrid2D = null) -> PackedVector2Array:
	if grade == null: grade = navegacao
	var de := _celula_livre(inicio,grade)
	var ate := _celula_livre(fim,grade)
	var pontos := grade.get_point_path(de, ate)
	if not pontos.is_empty():
		# Preservar o centro inicial evita cortar a quina do móvel ao sair da borda da célula.
		if not pontos[0].is_equal_approx(inicio):
			pontos.insert(0, inicio)
		# Um destino dentro de um móvel ou parede precisa terminar na célula livre,
		# sem acrescentar um último segmento que faça o morador colidir para sempre.
		var celula_fim := Vector2i(fim / grade.cell_size)
		if grade.is_in_boundsv(celula_fim) and not grade.is_point_solid(celula_fim):
			pontos.append(fim)
	return pontos

## Percursos próprios passam por um lugar familiar, quando o desvio é razoável.
## A navegação normal continua verificando os móveis e os corredores de cada trecho.
func caminho_morador(inicio: Vector2, fim: Vector2, id: String) -> PackedVector2Array:
	if id == "helena": return caminho_entre(inicio,fim,_navegacao_cadeira)
	var direto := caminho_entre(inicio,fim)
	var perfis: Dictionary = preload("res://codigo/cidade/perfis_rotina.gd").PERFIS
	if local not in ["cidade","praia"] or not perfis.has(id) or inicio.distance_to(fim) < 80 or direto.is_empty():
		return direto
	var perfil: Dictionary = perfis[id]
	var apoio: Vector2 = DadosCidade.ponto(perfil["via"]) if local == "cidade" else perfil["orla"]
	if inicio.distance_to(apoio) < 24 or fim.distance_to(apoio) < 24: return direto
	var primeira := caminho_entre(inicio,apoio)
	if primeira.is_empty(): return direto
	var segunda := caminho_entre(primeira[-1],fim)
	if segunda.is_empty(): return direto
	var distancia_direta := _comprimento_rota(direto)
	if _comprimento_rota(primeira)+_comprimento_rota(segunda) > distancia_direta*1.5+24:
		return direto
	primeira.append_array(segunda)
	return primeira

func _comprimento_rota(rota: PackedVector2Array) -> float:
	var comprimento := 0.0
	for i in range(1,rota.size()): comprimento += rota[i-1].distance_to(rota[i])
	return comprimento

func _celula_livre(ponto: Vector2, grade: AStarGrid2D = null) -> Vector2i:
	if grade == null: grade = navegacao
	var celula := Vector2i(ponto / grade.cell_size)
	celula.x = clampi(celula.x, 0, grade.region.size.x - 1)
	celula.y = clampi(celula.y, 0, grade.region.size.y - 1)
	if not grade.is_point_solid(celula):
		return celula
	for raio in range(1, 12):
		for dy in range(-raio, raio + 1):
			for dx in range(-raio, raio + 1):
				var candidata := celula + Vector2i(dx, dy)
				if grade.is_in_boundsv(candidata) and not grade.is_point_solid(candidata):
					return candidata
	return celula

func _montar_portal() -> void:
	var portal := PortalArena.new()
	portal.name = "PortalArena"
	portal.position = POSICAO_PORTAL
	add_child(portal)

func _montar_mural() -> void:
	if local not in ["cidade", "sede"]:
		return
	var mural := InteragivelCidade.new()
	mural.name = "MuralPedidos"
	mural.position = DadosCidade.ponto("mural") if local == "cidade" else InteriorCasa.mural()
	mural.nome_tela = "mural_cidade"
	mural.so_entre_ondas = false
	var forma := CollisionShape2D.new()
	var circulo := CircleShape2D.new()
	circulo.radius = 25
	forma.shape = circulo
	mural.add_child(forma)
	add_child(mural)

func _montar_decoracao() -> void:
	SombraCidade.contato($Jogador, 18.0, 3.0, Vector2(0, 11))
	var decoracao := DecoracaoVila.new()
	decoracao.name = "Decoracao"
	add_child(decoracao)
	add_child(CercasVila.new())
	add_child(preload("res://codigo/cidade/limites_vila.gd").new())

## Terrenos locais por estação; preserva os índices Wang e o acabamento do calçamento.
func _aplicar_terreno(estacao: int) -> void:
	var camada := get_node_or_null("Terrains/Terreno") as TileMapLayer
	if camada == null:
		return
	var raiz := "res://assets/cenario/algoland_original/"
	var pasta: String = raiz + ESTACOES_TERRENO[estacao] + "/"
	for i in PARES_TERRENO.size():
		(camada.tile_set.get_source(i) as TileSetAtlasSource).texture = load(pasta + PARES_TERRENO[i] + ".png")
	(camada.tile_set.get_source(3) as TileSetAtlasSource).texture = load(pasta + "grama_agua.png")
	(camada.tile_set.get_source(3) as TileSetAtlasSource).use_texture_padding = false
	if _camada_agua == null:
		# A água usa o próprio material; reflexos não alteram grama, terra ou calçamento.
		_camada_agua = TileMapLayer.new()
		_camada_agua.name = "SuperficieAgua"
		_camada_agua.tile_set = camada.tile_set
		_camada_agua.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_camada_agua.z_index = camada.z_index
		camada.get_parent().add_child(_camada_agua)
		for celula in camada.get_used_cells():
			if camada.get_cell_source_id(celula) == 3:
				_camada_agua.set_cell(celula, 3, camada.get_cell_atlas_coords(celula))
				camada.erase_cell(celula)
		_agua_viva.configurar(_camada_agua,load(raiz+"mascara_agua.png"),Vector2(8,3))
		_material_agua=_agua_viva.material
	_agua_viva.aplicar(estacao)
	if _bordas_grama == null:
		_bordas_grama = BordasGrama.new()
		_bordas_grama.name = "BordasGrama"
		camada.get_parent().add_child(_bordas_grama)
	_bordas_grama.configurar(camada, _camada_agua, estacao)
	if _terra_mascarada._fontes.is_empty():
		_terra_mascarada.configurar(camada,{0:"cidade/%s_grama_terra",2:"cidade/%s_terra_pedra"})
	_terra_mascarada.aplicar(estacao)
	if _chao_detalhado==null:
		_chao_detalhado=preload("res://codigo/cidade/chao_detalhado.gd").new()
		_chao_detalhado.name="ChaoDetalhado"
		camada.get_parent().add_child(_chao_detalhado)
		_chao_detalhado.configurar(camada,_camada_agua)
	_chao_detalhado.aplicar(estacao)


## Estação que está valendo na tela: a do nó Estacoes (que também obedece ao painel F3), senão a do calendário
func estacao_visual() -> int:
	var estacoes := get_node_or_null("Terrains/Estacoes")
	if estacoes != null and "estacao_atual" in estacoes and int(estacoes.estacao_atual) >= 0:
		return int(estacoes.estacao_atual)
	return Calendario.estacao()

func _atualizar_ambiente() -> void:
	var estacao := estacao_visual()
	if estacao != _estacao_visual:
		_estacao_visual = estacao
		_aplicar_terreno(estacao)
	var noite := hora_atual() >= 18 or hora_atual() < 6
	for filho in get_children():
		if filho.has_meta("lampiao"):
			filho.visible = noite
	var enfeites := get_node_or_null("Terrains/EnfeitesFesta")
	if enfeites != null:
		enfeites.visible = Calendario.dia_na_estacao() == Calendario.DIAS_POR_ESTACAO
