extends SceneTree
class JogadorTeste extends Node:
	var eh_p2 := false
const Visual := preload("res://codigo/dados/visual_ranking.gd")
var falhas := 0
var ranking: Node
func _initialize() -> void: rodar.call_deferred()
func conferir(ok: bool, texto: String) -> void:
	print("OK " if ok else "FALHA ",texto)
	if not ok: falhas += 1
func esperar_envio() -> void:
	var limite := Time.get_ticks_msec()+5000
	while ranking.ocupado() and Time.get_ticks_msec()<limite: await create_timer(0.01).timeout
	conferir(not ranking.ocupado(),"envio termina sem travar")
func buscar() -> void:
	ranking.buscar()
	ranking.buscar()
	var limite := Time.get_ticks_msec()+5000
	while ranking._buscando and Time.get_ticks_msec()<limite: await create_timer(0.01).timeout
	conferir(not ranking._buscando,"consulta termina sem travar")
func rodar() -> void:
	assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
	ranking = root.get_node("Ranking")
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		print("Execute pelo teste_ranking_http.py (servidor HTTP local, sem acesso ao Supabase real).")
		quit()
		return
	var url := "http://127.0.0.1:"+args[0]
	ranking.url_servico = url
	ranking.chave_servico = "teste_local"
	ranking.apelido = "TesteLocal"
	ranking._codigo = "codigo_apenas_do_servidor_local_123456"
	ranking.pendente = 0
	ranking._enviado = 0
	ranking._apelido_enviado = ""
	ranking._visual_enviado = ""
	ranking.visual_pendente = Visual.normalizar({"versao":1,"pele":1,"cabelo":12,"roupa":8,"cor":[1,0.5,0.3,1]})
	ranking.enviar(3)
	await esperar_envio()
	conferir(ranking._visual_enviado==JSON.stringify(ranking.visual_pendente),"pontuação e aparência enviadas na sequência")
	await buscar()
	conferir(ranking.lista_cache.size()==1 and ranking.lista_cache[0].aparencia.cabelo==12,"consulta retorna a aparência enviada")
	var cache: Array = ranking.lista_cache.duplicate(true)
	ranking.url_servico = url+"/falhar"
	await buscar()
	conferir(ranking.lista_cache==cache and not ranking.erro_consulta.is_empty(),"falha de conexão preserva os colocados da última consulta")
	ranking.visual_pendente.cabelo = 28
	var enviado: String = ranking._visual_enviado
	ranking.sincronizar_visual()
	await esperar_envio()
	conferir(ranking._visual_enviado==enviado,"visual com falha continua pendente")
	ranking.url_servico = url
	ranking.sincronizar_visual()
	await esperar_envio()
	conferir(ranking._visual_enviado==JSON.stringify(ranking.visual_pendente),"visual repete envio sem exigir novo recorde")
	# O callback só confirma a fotografia enviada, mesmo se o jogador mudar durante a requisição.
	ranking.visual_pendente.cabelo = 4
	ranking.sincronizar_visual()
	ranking.visual_pendente.cabelo = 7
	await esperar_envio()
	conferir(ranking._visual_enviado!=JSON.stringify(ranking.visual_pendente),"mudança durante envio não é confirmada indevidamente")
	ranking.sincronizar_visual()
	await esperar_envio()
	await buscar()
	conferir(ranking.lista_cache[0].aparencia.cabelo==7,"segunda fotografia atualiza o servidor")
	var p1 := JogadorTeste.new()
	var p2 := JogadorTeste.new()
	p2.eh_p2 = true
	ranking.registrar_uso(p1,"espada_basica")
	ranking.registrar_uso(p1,"espada_basica")
	ranking.registrar_uso(p2,"arco_longo")
	ranking.registrar_uso(p2,"res://arma_invalida")
	var parceiro: Node = ranking.para_jogador(p2)
	conferir(parceiro._codigo!=ranking._codigo and parceiro.arquivo_save!=ranking.arquivo_save,"P2 tem identidade e arquivo separados")
	conferir(ranking.armas_usadas=={"espada_basica":2} and parceiro.armas_usadas=={"arco_longo":1},"contagens e ids válidos independentes por jogador")
	ranking.sincronizar_visual()
	# Golpe durante requisição não é perdido pela confirmação do lote anterior.
	ranking.registrar_uso(p1,"espada_basica")
	await esperar_envio()
	conferir(ranking.armas_usadas.espada_basica==3 and ranking._armas_enviadas!=JSON.stringify(ranking.armas_usadas),"lote confirmado preserva uso novo durante envio")
	ranking.sincronizar_visual()
	await esperar_envio()
	conferir(ranking._armas_enviadas==JSON.stringify(ranking.armas_usadas),"contagens sincronizam sem reenviar pontuação")
	ranking.gravar_perfis()
	parceiro.armas_usadas = {}
	parceiro._carregar()
	conferir(parceiro.armas_usadas=={"arco_longo":1},"usos de P2 persistem entre sessões")
	p1.free()
	p2.free()
	var codigo: String = ranking._codigo
	ranking._gravar()
	ranking._carregar()
	conferir(ranking._codigo==codigo and ranking.visual_pendente.cabelo==7,"persistência preserva identidade e retrato entre sessões")
	print("RANKING HTTP: ",falhas," falhas")
	quit(1 if falhas else 0)
