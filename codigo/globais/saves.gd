extends Node

## Mundos salvos (autoload Saves): o jogo solo fica direto em user:// (como sempre foi) e o mundo cooperativo em
## user://coop/, com fazenda, cidade, calendário, progresso, baú, inventários e personagens próprios, como o Stardew.
## A tela inicial escolhe o mundo (trocar) antes de começar ou continuar; trocar repõe o caminho de cada save e
## recarrega tudo. As opções (user://opcoes.cfg) são do jogo, não do mundo.

signal mundo_trocado(mundo: String)

const SOLO := "solo"
const COOP := "coop"
const PASTAS := {SOLO: "user://", COOP: "user://coop/"}

var mundo := SOLO

func pasta() -> String:
	return PASTAS[mundo]

func caminho(arquivo: String) -> String:
	return pasta() + arquivo

func eh_coop() -> bool:
	return mundo == COOP

## Personagem de cada jogador (aparência e apelido): o 2 só existe no mundo cooperativo
func caminho_personagem(jogador_2 := false) -> String:
	return caminho("configuracao_jogador_p2.json" if jogador_2 else "configuracao_jogador.json")

func existe_mundo(qual: String) -> bool:
	return FileAccess.file_exists(PASTAS[qual] + "configuracao_jogador.json")

## Passa a usar o mundo `qual`: aponta cada save para a pasta dele e recarrega (ou zera, se o arquivo não existe)
func trocar(qual: String) -> void:
	mundo = qual
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(pasta()))
	Progresso.caminho_save = caminho("progresso.json")
	Calendario.caminho_save = caminho("calendario.json")
	Cidade.caminho_save = caminho("cidade.json")
	Fazenda.caminho_save = caminho("fazenda.json")
	Introducao.caminho_save = caminho("introducao.json")
	BauCasa.caminho_save = caminho("bau.json")
	InventarioJogador.caminho_save = caminho("inventario.json")
	InventarioJogador2.caminho_save = caminho("inventario_p2.json")
	Progresso.carregar()
	Calendario.carregar()
	Cidade.carregar()
	Fazenda.carregar()
	Introducao.carregar()
	BauCasa.carregar()
	InventarioJogador.limpar()
	InventarioJogador.carregar()
	InventarioJogador2.limpar()
	InventarioJogador2.carregar()
	Transicao.limpar()
	mundo_trocado.emit(mundo)
