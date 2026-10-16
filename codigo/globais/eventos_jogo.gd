extends Node

@warning_ignore("unused_signal")
signal abrir_tela(nome: String)
@warning_ignore("unused_signal")
signal fechar_tela(nome: String)
@warning_ignore("unused_signal")
signal tela_aberta(nome: String)
@warning_ignore("unused_signal")
signal tela_fechada(nome: String)
@warning_ignore("unused_signal")
signal forja_solicitada(item)

# --- Dono da interface (cooperativo) ----------------------------------------------------------------------------
# Cada tela, HUD e slot pertence a um jogador: o jogador 1 por padrão, ou o jogador 2 quando a interface está na metade
# dele (um ancestral com a meta "dono", posta pelo Cooperativo). Assim o mesmo código mostra e mexe na mochila, no ouro
# e no personagem de quem abriu a tela

## O jogador dono do nó (o jogador 1 se ninguém na linha de ancestrais tem a meta "dono")
func dono(no: Node) -> Node2D:
	if no is CharacterBody2D and no.is_in_group("jogadores"):
		return no
	var atual := no
	while atual != null:
		if atual.has_meta("dono"):
			var marcado = atual.get_meta("dono")
			if is_instance_valid(marcado):
				return marcado
		atual = atual.get_parent()
	if Cooperativo.ativo:
		return Cooperativo._jogador1()
	var coop := get_node_or_null("/root/Cooperativo")
	var cena: Node = coop.cena_de(no) if coop != null else get_tree().current_scene
	return cena.get_node_or_null("Jogador") as Node2D if cena != null else null

func eh_do_p2(no: Node) -> bool:
	var jogador := dono(no)
	return jogador != null and bool(jogador.get("eh_p2"))

## Mochila e equipamento do dono
func inventario_de(no: Node) -> Node:
	var jogador := dono(no)
	if jogador != null and jogador.get("inventario") != null:
		return jogador.inventario
	return InventarioJogador2 if eh_do_p2(no) else InventarioJogador

func moedas_de(no: Node) -> int:
	return DadosJogo.moedas_de(dono(no))

## A Interface que mostra as telas deste nó (a do jogador 2 fica na metade dele); null = a da cena
func interface_de(no: Node) -> Node:
	var atual := no
	while atual != null:
		if atual.is_in_group("interface"):
			return atual
		atual = atual.get_parent()
	if eh_do_p2(no) and Cooperativo.interface_p2() != null:
		return Cooperativo.interface_p2()
	return interface_p1()

## A Interface do jogador 1 (na cena, ou na metade esquerda da tela dividida)
func interface_p1() -> Node:
	for interface in get_tree().get_nodes_in_group("interface"):
		if not eh_do_p2(interface):
			return interface
	var cena := get_tree().current_scene
	return cena.get_node_or_null("Interface") if cena != null else null

## Abre/fecha a tela na interface do dono (a mochila do jogador 2 não fecha a do jogador 1)
func abrir_tela_de(no: Node, nome: String) -> void:
	var interface := interface_de(no)
	if interface != null and interface.has_method("_abrir_tela"):
		interface._abrir_tela(nome)
	else:
		abrir_tela.emit(nome)

func fechar_tela_de(no: Node, nome: String) -> void:
	var interface := interface_de(no)
	if interface != null and interface.has_method("_fechar_tela"):
		interface._fechar_tela(nome)
	else:
		fechar_tela.emit(nome)

## Uma coisa do mundo (porta, fogueira, morador) pediu uma tela para `jogador`: a dele (jogador 2) ou a da cena
func abrir_tela_para(jogador: Node, nome: String) -> void:
	if jogador != null and bool(jogador.get("eh_p2")) and Cooperativo.interface_p2() != null:
		Cooperativo.interface_p2()._abrir_tela(nome)
	else:
		abrir_tela.emit(nome)

## Painéis da mesma interface: a loja de um jogador nunca recebe o item do parceiro.
func painel_do_grupo(no: Node, grupo: String) -> Node:
	var interface := interface_de(no)
	for painel in get_tree().get_nodes_in_group(grupo):
		if interface == null or interface.is_ancestor_of(painel):
			return painel
	return null
