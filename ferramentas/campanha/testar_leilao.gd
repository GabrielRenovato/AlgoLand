extends SceneTree
class Aventureiro extends Node:
	var eh_p2 := false
	var inventario: Node
	func adicionar_moedas(valor: int) -> void:
		inventario.ouro_campanha+=valor
		inventario.salvar()
var falhas:=0
func _initialize():rodar.call_deferred()
func verificar(nome: String,ok: bool):
	print("OK " if ok else "FALHA ",nome)
	if not ok:falhas+=1
func rodar():
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"):quit(1);return
	var url:=""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--mercado-local=http://127.0.0.1:"):url=a.trim_prefix("--mercado-local=")
	if url.is_empty():quit(1);return
	var ranking: Node=root.get_node("Ranking")
	var progresso: Node=root.get_node("Progresso")
	ranking.url_servico=url;ranking.chave_servico="teste_local";ranking.conexao_habilitada=true
	DirAccess.make_dir_recursive_absolute("user://percurso_primeira_raiz")
	var moeda_antiga: int=progresso.brasas
	var jogadores: Array=[]
	var clientes: Array=[]
	for i in 2:
		var j:=Aventureiro.new();j.eh_p2=i==1
		j.inventario=load("res://codigo/modelos/modelo_inventario.gd").new()
		j.inventario.caminho_save="user://percurso_primeira_raiz/bolsa-%d.json"%i
		j.inventario.ouro_campanha=100
		root.add_child(j);j.add_child(j.inventario)
		var c=load("res://codigo/campanha/cliente_leilao.gd").new()
		j.add_child(c);c.preparar(j);await c.atualizar_regras()
		jogadores.append(j);clientes.append(c)
	var vendedor=jogadores[0];var comprador=jogadores[1]
	var a=clientes[0];var b=clientes[1]
	verificar("identidades e arquivos de correio separados",a.perfil.codigo_secreto()!=b.perfil.codigo_secreto() and a.arquivo!=b.arquivo)
	vendedor.inventario.adicionar_coletavel("material","ferro",3)
	var item=vendedor.inventario.buscar_por_tipo("material:ferro")
	var anuncio: Dictionary=await a.anunciar(item,vendedor.inventario,20,24,2)
	verificar("anuncia pilha usando ouro",anuncio.ok and a.saldo()==99 and item.quantidade==1)
	var busca: Dictionary=await b.buscar({"tipo":"material:ferro"},0)
	verificar("outro jogador encontra anúncio real",busca.ok and busca.dados.anuncios.size()==1)
	if not busca.ok or busca.dados.anuncios.is_empty():quit(1);return
	var r: Dictionary=await b.comprar(busca.dados.anuncios[0],comprador.inventario)
	verificar("compra desconta ouro do comprador",r.ok and b.saldo()==80)
	await b.retirar_correio(comprador.inventario)
	var comprado=comprador.inventario.buscar_por_tipo("material:ferro")
	verificar("compra entrega duas unidades na mochila",comprado!=null and comprado.quantidade==2)
	await a.retirar_correio(vendedor.inventario)
	verificar("vendedor recebe ouro líquido da taxa",a.saldo()==117)
	await b.retirar_correio(comprador.inventario)
	await a.retirar_correio(vendedor.inventario)
	verificar("repetir correio não duplica itens ou ouro",comprado.quantidade==2 and a.saldo()==117)
	var sem_saldo: Dictionary=await b.comprar({"id":9999,"preco":1000},comprador.inventario)
	verificar("saldo insuficiente não desconta ouro",not sem_saldo.ok and b.saldo()==80)
	var outro: Dictionary=await a.anunciar(item,vendedor.inventario,10,24)
	var meus: Dictionary=await a.meus()
	verificar("novo anúncio consta na lista do vendedor",outro.ok and meus.ok)
	var cancelado: Dictionary=await a.cancelar(int(outro.dados.id))
	await a.retirar_correio(vendedor.inventario)
	verificar("cancelar devolve o item",cancelado.ok and vendedor.inventario.buscar_por_tipo("material:ferro")!=null)
	var recarregado=load("res://codigo/modelos/modelo_inventario.gd").new()
	recarregado.caminho_save=vendedor.inventario.caminho_save
	verificar("ouro persiste junto da mochila",recarregado.carregar() and recarregado.ouro_campanha==a.saldo())
	recarregado.free()
	verificar("mercado da campanha não altera Brasas",progresso.brasas==moeda_antiga)
	print("FALHAS: ",falhas)
	quit(falhas)
