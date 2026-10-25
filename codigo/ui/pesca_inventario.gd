extends "res://codigo/ui/catalogo_inventario.gd"

const Peixes := preload("res://codigo/pesca/peixes.gd")
const Progressao := preload("res://codigo/pesca/progressao_pesca.gd")
const Varas := preload("res://codigo/pesca/varas.gd")
const Metas := preload("res://codigo/pesca/desafios_pesca.gd")
const Ficha := preload("res://codigo/ui/ficha_peixe.gd")
var _desafios_pesca := false
var _grade_peixes: GridContainer
func _ready() -> void:
	super._ready()
	name = "Pesca"

func _atualizar() -> void:
	_limpar_catalogo()
	var jogador := EventosJogo.dono(self)
	_lista.add_child(Progressao.painel(jogador))
	_rotulo(_lista,"VARA NV %d / 5" % Varas.nivel(jogador),Varas.CORES[Varas.nivel(jogador)-1])
	_rotulo(_lista,"PEDRAS: %d | ESPECIES: %d / %d" % [Varas.pedras(jogador),Fazenda.peixes_pescados.size(),Peixes.DADOS.size()])
	var trocar := Button.new()
	trocar.text = "VER CATALOGO" if _desafios_pesca else "VER DESAFIOS"
	preload("res://codigo/ui/estilo_inicio_detalhado.gd").botao(trocar,false,16.0)
	trocar.custom_minimum_size.y = 32
	# O botão está na lista que _limpar_catalogo libera: refazer a lista dentro do próprio sinal travava o jogo
	trocar.pressed.connect(func():
		_desafios_pesca = not _desafios_pesca
		_atualizar.call_deferred()
		_depois_de_trocar.call_deferred()
	)
	_lista.add_child(trocar)
	if _desafios_pesca:
		_mostrar_desafios()
		return
	_grade_peixes = _nova_grade()
	for id in Peixes.DADOS:
		var estacoes: Array = Peixes.DADOS[id]["estacoes"]
		var epoca := "ANO TODO" if estacoes.is_empty() else "/".join(estacoes.map(func(e): return Calendario.NOMES[int(e)]))
		var detalhes := "%s\n%s | %s\n%s\nVARA RECOMENDADA: NV %d\nPESCADOS: %d | BOLSA: %d\nVENDA: %d BRASAS" % [Peixes.nome(id),"MAR" if Peixes.catalogo()[id]["ambiente"] == "mar" else "AGUA DOCE",Peixes.raridade(id).to_upper(),epoca,Peixes.nivel_recomendado(id),int(Fazenda.peixes_pescados.get(id,0)),Fazenda.quantidade_peixes(id,EventosJogo.dono(self)),Peixes.brasas(id)]
		detalhes += "\nPESCA: NV %d | %s\nXP BASE: %d" % [Peixes.nivel_pesca(id), "LIBERADO" if Progressao.nivel(jogador) >= Peixes.nivel_pesca(id) else "BLOQUEADO", Progressao.experiencia_peixe(id)]
		_adicionar_item(id,Peixes.icone(id),int(Fazenda.peixes_pescados.get(id,0))>0,detalhes)

func _mostrar_desafios() -> void:
	var metas := Metas.DESAFIOS.merged(Metas.COLECAO)
	for id in metas:
		var dados: Dictionary = metas[id]
		var progresso := Fazenda.progresso_desafio_pesca(id)
		var concluido := Fazenda.pesca_recompensas.has(id)
		var cartao := VBoxContainer.new()
		_lista.add_child(cartao)
		_rotulo(cartao,"%s\n%d / %d | %d BRASAS" % [dados["nome"],mini(progresso,int(dados["meta"])),dados["meta"],dados["brasas"]])
		var resgatar := Button.new()
		resgatar.text = "CONCLUIDO" if concluido else "RESGATAR"
		preload("res://codigo/ui/estilo_inicio_detalhado.gd").botao(resgatar,false,16.0)
		resgatar.custom_minimum_size.y = 32
		resgatar.disabled = concluido or progresso < int(dados["meta"])
		resgatar.pressed.connect(func():
			Fazenda.resgatar_desafio_pesca(id)
			_agendar()
		)
		cartao.add_child(resgatar)

func _depois_de_trocar() -> void:
	scroll_vertical = 0
	var cartao := primeiro_cartao()
	if cartao != null:
		cartao.grab_focus()

func primeiro_cartao() -> Control:
	for filho in _lista.get_children():
		if filho is Button: return filho
	return null

func _estilizar_dica() -> void:
	preload("res://codigo/ui/estilo_inicio_detalhado.gd").painel(_dica, false, 10, true)
	_dica.mouse_filter = Control.MOUSE_FILTER_STOP

func _mostrar_dica(id: String, slot: Control) -> void:
	if not is_instance_valid(_dica) or not is_visible_in_tree() or not Peixes.existe(id): return
	_id_dica = id
	for filho in _linhas_dica.get_children(): filho.free()
	Ficha.preencher(_linhas_dica, id, EventosJogo.dono(self), _fechar_dica)
	var largura := minf(212, _area_dica.size.x - 20)
	_rolagem_dica.custom_minimum_size = Vector2(largura - 20, 0)
	_rolagem_dica.scroll_vertical = 0
	_dica.custom_minimum_size = Vector2(largura, 0)
	_dica.size = Vector2(largura, 0)
	_dica.show()
	_posicionar_dica.call_deferred(slot)
