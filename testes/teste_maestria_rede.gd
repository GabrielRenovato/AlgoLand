extends SceneTree
var falhas:=0
class Sessao extends Node:
	var host:=true
	var dono:="host"
	var enviados:Array=[]
	func sou_host() -> bool:return host
	func perfil_de(_id:String) -> Dictionary:return {"dano_maximo":50}
	func enviar_para(para:String,m:Dictionary,_estado:=false) -> bool:enviados.append({"para":para,"m":m});return true
class Jogador extends CharacterBody2D:
	var maestria:Node
	func grupo_hud() -> String:return "hud"
class Parceiro extends Node2D:
	var id_arma_atual:="espada_basica"
	var usando_arco:=false
	var usando_lanca:=false
	var usando_escudo:=false
	var estaMorto:=false
class Alvo extends Node2D:
	var vida:=200
	func receber_dano(n:int,_forca:Vector2) -> void:vida=maxi(0,vida-n)
func _initialize() -> void:rodar.call_deferred()
func verificar(nome:String,ok:bool) -> void:
	print("OK " if ok else "FALHA ",nome)
	if not ok:falhas+=1
func rodar() -> void:
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"):quit(1);return
	DirAccess.remove_absolute("user://rede/maestria.json")
	var controle=load("res://codigo/coop_online/andar_coop.gd").new()
	controle.set_process(false)
	root.add_child(controle)
	var sessao:=Sessao.new();root.add_child(sessao);controle.sessao=sessao
	var jogador:=Jogador.new();root.add_child(jogador);controle.jogador=jogador
	var componente=load("res://codigo/jogador/maestria_jogador.gd").new()
	componente.set_process(false);root.add_child(componente)
	componente.jogador=jogador;jogador.maestria=componente
	verificar("save individual da rede",componente.modelo.iniciar("user://rede/maestria.json")==OK)
	var parceiro:=Parceiro.new();root.add_child(parceiro);controle.parceiros={"convidado":parceiro}
	var alvo:=Alvo.new();root.add_child(alvo);alvo.position=Vector2(20,0)
	controle._inimigos={7:alvo};controle._vmax={7:200}
	var pedido:Dictionary={"t":"golpe","de":"convidado","id":7,"dano":10,"maestria":{"familia":"espada","evento":1}}
	controle._aplicar_golpe(pedido)
	verificar("host confirma dano e credito por participante",alvo.vida==190 and sessao.enviados.size()==1 and sessao.enviados[0].para=="convidado")
	controle._golpes.clear();controle._aplicar_golpe(pedido)
	verificar("replay nao repete dano nem experiencia",alvo.vida==190 and sessao.enviados.size()==1)
	var credito:Dictionary=sessao.enviados[0].m.duplicate()
	sessao.host=false
	credito.de="outro_convidado";controle._receber(credito)
	verificar("convidado nao pode conceder credito",componente.modelo.experiencia.espada==0)
	credito.de="host";controle._receber(credito)
	var xp:int=componente.modelo.experiencia.espada
	verificar("credito confirmado e salvo",xp>0)
	controle._receber(credito)
	verificar("recibo duplicado ignorado",componente.modelo.experiencia.espada==xp)
	var reaberto=load("res://codigo/modelos/modelo_maestria.gd").new()
	verificar("recibos persistem apos reconectar",reaberto.iniciar("user://rede/maestria.json")==OK and credito.ticket in reaberto.recebidos)
	componente.modelo=reaberto
	controle._receber(credito)
	verificar("reabertura nao permite replay",componente.modelo.experiencia.espada==xp)
	sessao.host=true
	controle._golpes.clear()
	pedido.maestria={"familia":"arco","evento":2};controle._aplicar_golpe(pedido)
	verificar("familia falsa nao recebe experiencia",sessao.enviados.size()==1)
	controle._armas_recentes.convidado=Time.get_ticks_msec()
	controle._golpes.clear()
	pedido.maestria.evento=3;controle._aplicar_golpe(pedido)
	verificar("flecha em voo preserva arco apos troca",sessao.enviados.size()==2 and sessao.enviados[-1].m.familia=="arco")
	parceiro.position=Vector2(1000,0);controle._golpes.clear();pedido.maestria={"familia":"espada","evento":4}
	var vida_antes:int=alvo.vida
	controle._aplicar_golpe(pedido)
	verificar("alcance invalido nao concede dano ou credito",alvo.vida==vida_antes and sessao.enviados.size()==2)
	controle.queue_free();sessao.queue_free();jogador.queue_free();componente.queue_free();parceiro.queue_free();alvo.queue_free()
	print("FALHAS: ",falhas)
	quit(1 if falhas else 0)
