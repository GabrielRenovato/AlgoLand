extends Node

## Identidade e rotina únicas, compartilhadas pelos mapas no cooperativo.
var aves: Array[Dictionary] = []
const VELOCIDADE := 19.0
const PASTAGEM := Rect2(-112,48,800,440)
var _quintal: WeakRef
var _origem := Vector2.ZERO

func configurar_quintal(exterior: Node2D) -> void:
	_quintal = weakref(exterior)
	_origem = exterior.portinha.global_position

func _rota(ave: Dictionary, alvo: Vector2) -> PackedVector2Array:
	var exterior: Node = _quintal.get_ref() if _quintal != null else null
	var pontos := PackedVector2Array()
	if is_instance_valid(exterior):
		var ambiente := exterior.get_parent().get_node_or_null("ObraCarpinteiro")
		if ambiente != null:
			for ponto in ambiente.caminho_morador(ambiente.to_local(_origem+ave.ponto),ambiente.to_local(_origem+alvo),"galinha"):
				pontos.append(ambiente.to_global(ponto)-_origem)
			return pontos
	pontos.append(alvo)
	return pontos

func _destinar(ave: Dictionary, alvo: Vector2) -> bool:
	var rota := _rota(ave,alvo)
	if rota.is_empty(): return false
	ave.destino = rota[-1]
	ave.rota = rota
	return true

func _caminhar_fora(ave: Dictionary, delta: float) -> void:
	var restante := VELOCIDADE*delta
	var rota: PackedVector2Array = ave.get("rota",PackedVector2Array())
	while restante > 0 and not rota.is_empty():
		var distancia: float = ave.ponto.distance_to(rota[0])
		ave.ponto = ave.ponto.move_toward(rota[0],restante)
		if distancia <= restante:
			rota.remove_at(0)
		else:
			restante = 0
			break
		restante -= distancia
	ave.rota = rota

func _porta_interna() -> Vector2:
	var largura: float = [192,256,320][clampi(Fazenda.galinheiro.nivel-1,0,2)]
	return Vector2((largura/2+16)/(largura-48),0)


func reiniciar() -> void: aves.clear()

func pode_sair(hora: float, clima: int) -> bool:
	return Fazenda.galinheiro.get("portinha_aberta",true) and hora >= 7 and hora < 18 and clima not in [2,3,4,6]

func portinha_aberta() -> bool:
	if Fazenda.galinheiro.get("portinha_aberta",true): return true
	return aves.any(func(a): return a.estado != "dentro")

func _process(delta: float) -> void:
	# Ao trocar mapas não há relógio por alguns quadros. Isso não é amanhecer.
	if Transicao.ocupada: return
	var luz := get_tree().get_first_node_in_group("iluminacao")
	if luz == null: return
	avancar(delta,luz.hora_do_mundo(),Fazenda.clima_hoje)

func avancar(delta: float, hora: float, clima: int) -> void:
	while aves.size() > Fazenda.galinheiro.aves.size(): aves.pop_back()
	while aves.size() < Fazenda.galinheiro.aves.size():
		var i := aves.size()
		aves.append({"estado":"dentro","passagem":0.0,"ponto":Vector2(0.2+0.15*(i%4),0.3+0.15*(i/4)),"destino":Vector2(0.2+0.15*(i%4),0.3+0.15*(i/4)),"espera":0.5+float(i)*0.35,"atividade":"bicar"})
	var sair := pode_sair(hora,clima)
	var ocupado := aves.any(func(a): return a.estado in ["saindo","entrando"])
	var proxima := -1
	for i in aves.size():
		if aves[i].estado == "dentro": proxima = i; break
	for i in aves.size():
		var ave: Dictionary = aves[i]
		match ave.estado:
			"dentro":
				if sair and i == proxima:
					ave.atividade = "caminhar"
					ave.ponto = ave.ponto.move_toward(_porta_interna(),delta*0.38)
					if ave.ponto.distance_to(_porta_interna()) < 0.01 and not ocupado:
						ave.estado = "saindo"
						ocupado = true
				else:
					_passear(ave,delta,Rect2(0.08,0.12,0.8,0.74),0.13,i)
			"saindo":
				if not sair: ave.estado = "entrando"
				else:
					ave.passagem = minf(1,ave.passagem+delta/1.6)
					if ave.passagem == 1:
						ave.estado = "fora"
						ave.ponto = Vector2(0,18)
						ave.destino = ave.ponto
						ave.rota = PackedVector2Array()
						ave.espera = 0
			"fora":
				if not sair:
					ave.estado = "voltando"
					_destinar(ave,Vector2(0,18))
				else: _passear(ave,delta,PASTAGEM,VELOCIDADE,i)
			"voltando":
				if sair:
					ave.estado = "fora"
					ave.destino = ave.ponto
					ave.rota = PackedVector2Array()
					ave.espera = 0
					continue
				ave.atividade = "caminhar"
				_caminhar_fora(ave,delta)
				# A grade reserva margem aos corpos grandes; a ave alcança a soleira
				# pelos últimos pixels livres, antes de iniciar o recorte da passagem.
				if ave.get("rota",PackedVector2Array()).is_empty() and ave.ponto.distance_to(Vector2(0,18)) < 20:
					ave.ponto = ave.ponto.move_toward(Vector2(0,18),delta*VELOCIDADE)
				if ave.ponto.distance_to(Vector2(0,18)) < 0.01 and not ocupado:
					ave.estado = "entrando"
					ocupado = true
			"entrando":
				ave.passagem = maxf(0,ave.passagem-delta/1.6)
				if ave.passagem == 0:
					ave.estado = "dentro"
					ave.ponto = _porta_interna()
					ave.destino = Vector2(0.2+float(i%4)*0.13,0.5)
					ave.espera = 0

func _passear(ave: Dictionary, delta: float, area: Rect2, velocidade: float, indice: int) -> void:
	if ave.get("pausa_ate",0.0) > 0:
		ave.pausa_ate -= delta
		return
	if ave.ponto.distance_to(ave.destino) > velocidade*delta:
		ave.atividade = "caminhar"
		if ave.estado == "fora": _caminhar_fora(ave,delta)
		else: ave.ponto = ave.ponto.move_toward(ave.destino,delta*velocidade)
		return
	ave.ponto = ave.destino
	ave.espera -= delta
	if ave.espera > 0: return
	ave.atividade = "bicar" if randf() < 0.7 else "descansar"
	# Escolhe um destino livre em vez de amontoar todas as aves no mesmo ponto.
	for tentativa in 16:
		var candidato := Vector2(randf_range(area.position.x,area.end.x),randf_range(area.position.y,area.end.y))
		if ave.estado == "fora":
			# Destinos distribuídos pelo pasto, sem manter o bando junto da porta.
			var setor := posmod(indice+floori(float(ave.get("passeios",0))/3.0),4)
			candidato.x = area.position.x + area.size.x*(setor+randf_range(0.15,0.85))/4.0
		var perto := false
		for j in aves.size():
			if j != indice and aves[j].estado == ave.estado and aves[j].destino.distance_to(candidato) < (42.0 if ave.estado == "fora" else 0.16): perto = true
		if not perto:
			if ave.estado == "fora":
				if not _destinar(ave,candidato): continue
				ave.passeios = int(ave.get("passeios",0))+1
			else: ave.destino = candidato
			break
	ave.espera = randf_range(1.4,4.0)
	# Mantém a bicada/repouso antes da próxima caminhada.
	ave["pausa_ate"] = ave.espera
