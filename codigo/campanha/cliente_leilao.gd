extends "res://codigo/mercado/cliente_mercado.gd"
## Ouro e correio separados do mercado em Brasas; operações do servidor têm namespace próprio.
var jogador_campanha: Node
func preparar(jogador: Node) -> void:
	jogador_campanha=jogador
	super.preparar(jogador)
func arquivo_do_jogador(jogador: Node) -> String:
	return "user://percurso_primeira_raiz/leilao_p2.json" if jogador!=null and bool(jogador.get("eh_p2")) else "user://percurso_primeira_raiz/leilao.json"
func nome_moeda() -> String:return "OURO"
func saldo() -> int:
	return jogador_campanha.inventario.ouro_campanha if is_instance_valid(jogador_campanha) else DadosJogo.moedas
func valor_entrega(entrega: Dictionary) -> int:return int(entrega.get("ouro",0))
func chamar(funcao: String, corpo: Dictionary) -> Dictionary:
	if "--script" in OS.get_cmdline_args() and not Ranking.url_servico.begins_with("http://127.0.0.1:"):
		return {"ok":false,"erro":SEM_CONEXAO,"rede":true}
	return await super.chamar("campanha_"+funcao,corpo)
func _mudar_brasas(quantia: int) -> void:
	if is_instance_valid(jogador_campanha):jogador_campanha.adicionar_moedas(quantia)
