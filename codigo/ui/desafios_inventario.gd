extends "res://codigo/ui/catalogo_inventario.gd"

const Receitas := preload("res://codigo/dados/forja_armas.gd")
const Icones := preload("res://codigo/ui/icones_itens.gd")

func _ready() -> void:
	colunas_maximas = 3
	super._ready()
	name = "Desafios"
	Progresso.armas_liberadas_alteradas.connect(_agendar)
	Progresso.onda_vencida_alterada.connect(_agendar)
	EventosJogo.inventario_de(self).mochila_alterada.connect(_agendar)

func _atualizar() -> void:
	_limpar_catalogo()
	_rotulo(_lista,"RECEITAS E EQUIPAMENTOS",Color("f6d879"))
	_nova_grade()
	var inventario := EventosJogo.inventario_de(self)
	for tipo in Receitas.RECEITAS:
		var liberada := Progresso.arma_liberada(tipo)
		var aprendida := Progresso.receita_liberada(tipo)
		var detalhes: String = Receitas.nome(tipo)
		if liberada:
			detalhes += "\nMODELO PERMANENTE\nUm equipamento comum, nivel 1, por partida."
			detalhes += "\nJA RECEBIDA NESTA PARTIDA" if tipo in inventario.armas_permanentes_entregues else "\nCONFIRME PARA RETIRAR"
		elif aprendida:
			detalhes += "\nRECEITA APRENDIDA\nFabrique na bigorna do Ivo usando os materiais da mochila."
		else:
			detalhes += "\nRECEITA NA ARENA\nA PARTIR DA ONDA %d\nColete e use a receita na mochila para aprender." % Receitas.onda_receita(tipo)
		_adicionar_item(tipo,Icones.obter(Receitas.criar_item(tipo),get_tree()),liberada or Progresso.receita_liberada(tipo),detalhes,_retirar.bind(tipo))

func _retirar(tipo: String) -> void:
	var inventario := EventosJogo.inventario_de(self)
	if Progresso.arma_liberada(tipo) and not tipo in inventario.armas_permanentes_entregues:
		inventario.entregar_armas_liberadas()

func primeiro_cartao() -> Control:
	return _grade_catalogo.get_child(0) if is_instance_valid(_grade_catalogo) and _grade_catalogo.get_child_count()>0 else null
