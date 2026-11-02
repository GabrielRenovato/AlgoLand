extends Node

## Primeira defesa da vila: três levas de rebentos pela entrada sul, sem saque da arena e sem cronômetro durante menus.
## Usa o mesmo contrato do encontro da chegada (`ativa`, `chefe`, `iniciar`), que a cena e o guia já conhecem.
var cena: Node2D
var ativa := false
var chefe: Node2D
var onda := 0
var criaturas: Array[Node2D] = []
const ONDAS := 3
const PAUSA_ENTRE_ONDAS := 1.5
const LIMITE_ONDA := 12.0 ## a próxima leva vem mesmo com rebentos vivos
const QUANTIDADES := [3, 4, 5]
const ENTRADA := Vector2(0, 392)
var _desde_onda := 0.0
var _ajuste := {"menos_primeira_onda": 0, "menos_vida": 0}

func iniciar() -> Error:
	if ativa: return ERR_BUSY
	var pronto: bool = cena.controlador.objetivos_disponiveis().any(func(o):return o.alvo=="barricada_vila" and o.tipo=="vencer")
	if cena.regiao!="vila" or not pronto: return ERR_UNAVAILABLE
	if cena.sessao!=null and cena.sessao.ativo and not cena.sessao.sou_host(): return ERR_UNAVAILABLE
	_ajuste = preload("res://codigo/campanha/preparos_ivo.gd").ajuste_defesa(cena.controlador.progresso.preparo)
	ativa = true
	onda = 0
	_desde_onda = 0.0
	cena.hud.anunciar("Rebentos na entrada!","Segure a rua. Eles vêm pelo sul.",3.5)
	return OK

func _process(delta: float) -> void:
	if not ativa or not cena.interface._telas_abertas.is_empty() or cena.jogador.estaMorto: return
	criaturas = criaturas.filter(func(n):return is_instance_valid(n) and not n.esta_morto)
	_desde_onda += delta
	if onda < ONDAS and (onda==0 or (criaturas.is_empty() and _desde_onda>=PAUSA_ENTRE_ONDAS) or _desde_onda>=LIMITE_ONDA):
		_desde_onda = 0.0
		_onda()
	elif onda == ONDAS and criaturas.is_empty() and _desde_onda >= PAUSA_ENTRE_ONDAS:
		_vencer()

func _onda() -> void:
	onda += 1
	cena.hud.anunciar("Onda %d/%d" % [onda,ONDAS],"",2.0)
	var quantidade: int = int(QUANTIDADES[onda-1])
	if onda == 1: quantidade = maxi(1, quantidade - int(_ajuste.menos_primeira_onda))
	if cena.sessao!=null and cena.sessao.ativo: quantidade += cena.sessao.jogadores_na_partida()-1
	for i in quantidade:
		var criatura := preload("res://cenas/inimigos/rebento_raizes.tscn").instantiate()
		var lado: float = (float(i) - (quantidade-1) / 2.0) * 38.0
		criatura.position = cena._livre(ENTRADA + Vector2(lado, 0))
		criatura.vida = maxi(6, 16 + onda * 2 - int(_ajuste.menos_vida))
		criatura.dano = 2
		cena.add_child(criatura)
		criaturas.append(criatura)

func _vencer() -> void:
	ativa = false
	if cena.controlador.interagir("vencer","barricada_vila")==OK:
		cena.salvar_retorno()
		cena._avisar("A vila resistiu. Fale com Osvaldo sobre os reparos.")

func _exit_tree() -> void:
	for criatura in criaturas:
		if is_instance_valid(criatura): criatura.queue_free()
