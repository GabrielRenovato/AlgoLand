extends "res://codigo/ui/catalogo_inventario.gd"

const Desafios := preload("res://codigo/dados/desafios_armas.gd")
const Icones := preload("res://codigo/ui/icones_itens.gd")

func _ready() -> void:
	super._ready()
	name = "Desafios"
	Progresso.armas_liberadas_alteradas.connect(_agendar)
	Progresso.onda_vencida_alterada.connect(_agendar)
	EventosJogo.inventario_de(self).mochila_alterada.connect(_agendar)

func _atualizar() -> void:
	_limpar_catalogo()
	_rotulo(_lista,"ARMAS PERMANENTES",Color("f6d879"))
	_nova_grade()
	var inventario := EventosJogo.inventario_de(self)
	for tipo in Desafios.DESAFIOS:
		var dados: Dictionary = Desafios.DESAFIOS[tipo]
		var liberada := Progresso.arma_liberada(tipo)
		var atual := mini(int(Progresso.get(dados["campo"])),int(dados["meta"]))
		var detalhes := "%s\n%s\n%s\n%s\nNovas partidas: comum, nivel 1." % [DadosItem.NOMES[tipo],dados["titulo"],dados["texto"],"LIBERADA PARA SEMPRE" if liberada else "PROGRESSO: %d / %d" % [atual,dados["meta"]]]
		if liberada and not tipo in inventario.armas_permanentes_entregues:
			detalhes += "\n" + ("TOQUE NOVAMENTE PARA RETIRAR" if _usa_toque() else (Controle.rotulo_acao("ui_accept",self)+": RETIRAR" if Controle.usando_controle_de(self) else "CLIQUE PARA RETIRAR"))
		elif liberada:
			detalhes += "\nJA RECEBIDA NESTA PARTIDA"
		_adicionar_item(tipo,Icones.obter_arma(tipo,get_tree()),liberada,detalhes,_retirar.bind(tipo))

func _retirar(tipo: String) -> void:
	var inventario := EventosJogo.inventario_de(self)
	if Progresso.arma_liberada(tipo) and not tipo in inventario.armas_permanentes_entregues:
		inventario.entregar_armas_liberadas()

func primeiro_cartao() -> Control:
	return _grade_catalogo.get_child(0) if is_instance_valid(_grade_catalogo) and _grade_catalogo.get_child_count()>0 else null
