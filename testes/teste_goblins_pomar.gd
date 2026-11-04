extends SceneTree
var falhas := 0
var cena: Node2D
class AlvoTeste extends Node2D:
	var invulneravel := false
	var estaMorto := false
	var caido := false
	var acertos := 0
	func receber_dano(_dano: int,_forca := Vector2.ZERO) -> void:acertos+=1
func _initialize() -> void:rodar.call_deferred()
func verificar(nome: String,ok: bool) -> void:
	print("OK " if ok else "FALHA ",nome)
	if not ok:falhas+=1
func quadros(n := 4) -> void:
	for i in n:await process_frame;await physics_frame
func foto(nome: String) -> void:
	await RenderingServer.frame_post_draw
	verificar("captura "+nome,root.get_texture().get_image().save_png("res://capturas-goblins/"+nome+".png")==OK)
func rodar() -> void:
	if not OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"):quit(1);return
	DirAccess.make_dir_recursive_absolute("res://capturas-goblins")
	var catalogo=load("res://codigo/campanha/catalogo_campanha.gd").dados()
	var p=load("res://codigo/campanha/progresso_campanha.gd").new()
	verificar("save isolado",p.iniciar("user://percurso_primeira_raiz","prototipo")==OK)
	for missao in ["sobreviver_queda","estrada_interrompida","acolhimento"]:
		for o in catalogo.missoes[missao].objetivos:p.registrar_objetivo(missao,o.id)
	set_meta("campanha_destino","pomar");set_meta("campanha_nova_instancia",true)
	root.content_scale_size=Vector2i(576,324);root.size=Vector2i(1152,648)
	change_scene_to_file("res://cenas/campanha/percurso_prototipo.tscn")
	await quadros(70);cena=current_scene
	cena.jogador.invulneravel=true
	verificar("estagio 4 aberto",cena.regiao=="pomar")
	verificar("32 goblins",cena.goblins_espalhados.size()==32)
	print("GOBLINS_TOTAL ",cena.goblins_espalhados.size())
	var setores := {}
	var entrada:=Vector2(cena.terreno.dados.entrada[0],cena.terreno.dados.entrada[1])
	var seguros:=true
	var textura:Texture2D=cena.goblins_espalhados[0].sprite.texture
	for g in cena.goblins_espalhados:
		g.ia_habilitada=false;g.velocity=Vector2.ZERO
		seguros=seguros and g.position.distance_to(entrada)>140.0 and cena.terreno.ponto_seguro(g.position)
		setores[Vector2i(signi(int(g.position.x)),signi(int(g.position.y)))]=true
		seguros=seguros and g.sprite.texture==textura and g.find_children("*","SubViewport",true,false).is_empty()
	verificar("distribuicao nos quatro quadrantes",setores.size()>=4)
	verificar("entrada segura, terreno livre e atlas compartilhado",seguros)
	var guias:=cena.get_children().filter(func(n):return n.has_method("_alvo_atual"))
	verificar("seta usa o mesmo alvo da missao",not guias.is_empty() and not guias[0]._alvo_atual().is_empty())
	var camera:Camera2D=cena.jogador.get_node("Camera2D")
	camera.position_smoothing_enabled=false;camera.zoom=Vector2.ONE*.4
	cena.jogador.position=Vector2.ZERO;await quadros(8);await foto("mapa-pomar")
	camera.zoom=Vector2.ONE*1.8
	var g:Node2D=cena.goblins_espalhados[0]
	cena.jogador.position=g.position+Vector2(70,30);await quadros(8);await foto("grupo-goblins")
	# Combate em trecho livre; demais goblins ficam desativados durante o teste.
	g.position=cena._livre(Vector2(0,200));g.ia_habilitada=true;g.set_physics_process(false);g.chance_combo=0.0
	# Colisão física dos pés em ambos os sentidos, com o player real.
	var posicao_player:Vector2=cena.jogador.global_position
	var centro_colisao:Vector2=g.global_position
	cena.jogador.set_physics_process(false)
	cena.jogador.velocity=Vector2.ZERO
	for rumo in [Vector2.RIGHT,Vector2.DOWN,Vector2.UP,Vector2.LEFT]:
		cena.jogador.global_position=centro_colisao-Vector2(0,9)
		g.global_position=centro_colisao+rumo*40.0
		await quadros(2)
		var choque_goblin:KinematicCollision2D=g.move_and_collide(-rumo*80.0)
		verificar("goblin bloqueado pelo player: "+str(rumo),choque_goblin!=null and choque_goblin.get_collider()==cena.jogador and (g.global_position-centro_colisao).dot(rumo)>9.0)
		g.global_position=centro_colisao+rumo*40.0
		cena.jogador.global_position=centro_colisao-Vector2(0,9)
		await quadros(2)
		var choque_player:KinematicCollision2D=cena.jogador.move_and_collide(rumo*80.0)
		verificar("player bloqueado pelo goblin: "+str(rumo),choque_player!=null and choque_player.get_collider()==g)
	await foto("colisao-player-goblin")
	cena.jogador.global_position=posicao_player
	cena.jogador.set_physics_process(true)
	g.global_position=centro_colisao
	var alvo:=AlvoTeste.new();cena.add_child(alvo);alvo.add_to_group("jogadores")
	alvo.position=g.position+Vector2(80,0)
	cena.jogador.position=Vector2(-450,300)
	g._jogador_cache=alvo;g._proxima_escolha_alvo=Time.get_ticks_msec()+10000
	await physics_frame
	var posicao_antes:Vector2=g.position
	g._physics_process(.1)
	verificar("persegue e reproduz corrida",g.velocity.x>0 and g.animacao=="correr" and g.position.x>posicao_antes.x)
	for i in 24: g._physics_process(1.0/60.0)
	verificar("contorno mantem velocidade e passada de corrida",g.velocity.length()>80.0 and g.position.distance_to(posicao_antes)>25.0)
	g.position=posicao_antes;alvo.position=g.position+Vector2(20,0)
	g.iniciar_ataque(Vector2.RIGHT)
	g._physics_process(.30);verificar("antecipacao sem dano",alvo.acertos==0)
	g._physics_process(.20);verificar("impacto atinge uma vez",alvo.acertos==1)
	g._physics_process(.20);verificar("nao repete dano durante corte",alvo.acertos==1)
	g._cancelar_golpe();alvo.position=g.position+Vector2(120,0)
	g.iniciar_ataque(Vector2.RIGHT);g._physics_process(.75)
	verificar("esquiva sai do alcance",alvo.acertos==1)
	g._cancelar_golpe();alvo.position=g.position+Vector2(20,0)
	g.iniciar_ataque(Vector2.RIGHT);g.esta_recuando=true;g._postura_quebrada=true;g._physics_process(.2)
	verificar("recuo interrompe o golpe",not g.esta_atacando and alvo.acertos==1)
	g.esta_recuando=false
	var parede:=StaticBody2D.new();parede.collision_layer=64;parede.collision_mask=0
	var col:=CollisionShape2D.new();var forma:=RectangleShape2D.new();forma.size=Vector2(4,80);col.shape=forma
	parede.add_child(col);cena.add_child(parede);parede.position=g.position+Vector2(10,0);await quadros(3)
	g.iniciar_ataque(Vector2.RIGHT);g._physics_process(.75)
	verificar("parede bloqueia dano",alvo.acertos==1)
	parede.queue_free()
	await quadros(3)
	# Mesmos atlas revisados, sem espelhar nem aplicar deformação extra ao personagem.
	for rumo in [Vector2.DOWN,Vector2.RIGHT,Vector2.UP,Vector2.LEFT]:
		g._cancelar_golpe()
		g.definir_direcao_animacao(rumo)
		g.velocity=rumo*100.0
		g._tocar("correr",true)
		g._animar(.1)
		var nome_direcao:String=g.DIRECOES[g.direcao]
		verificar("corrida direcional 2D: "+nome_direcao,g._clip=="correr_"+nome_direcao and g.sprite.texture is AtlasTexture and not g.sprite.flip_h and g.sprite.scale.is_equal_approx(Vector2.ONE*.071))
		g.velocity=Vector2.ZERO;g._tocar("parado",true)
		verificar("guarda direcional sem perna de corrida: "+nome_direcao,g._clip=="parado_"+nome_direcao)
	# Combo completo: impactos seguem os quadros1/5/9, separados pelas recuperações de200ms.
	g.chance_combo=1.0;g._cancelar_golpe();g.esta_recuando=false
	alvo.position=g.position+Vector2(20,0)
	var antes_combo:int=alvo.acertos
	g.iniciar_ataque(Vector2.RIGHT)
	g._physics_process(.30);verificar("combo tem antecipacao",alvo.acertos==antes_combo)
	g._physics_process(.04);verificar("primeiro golpe no quadro de impacto",alvo.acertos==antes_combo+1)
	g._physics_process(.22);verificar("primeira pausa sem dano repetido",alvo.acertos==antes_combo+1)
	g._physics_process(.23);verificar("segundo golpe no quadro de impacto",alvo.acertos==antes_combo+2)
	g._physics_process(.22);verificar("segunda pausa sem dano repetido",alvo.acertos==antes_combo+2)
	g._physics_process(.25);verificar("terceiro golpe no quadro de impacto",alvo.acertos==antes_combo+3)
	g._physics_process(.30);verificar("combo encerra e volta para guarda",not g.esta_atacando and g._clip=="parado_direita")
	# As novas direções usam seus próprios clipes e janelas de impacto.
	for direcao_ataque in [Vector2.UP,Vector2.LEFT]:
		g._cancelar_golpe();g.esta_recuando=false
		alvo.position=g.position+direcao_ataque*20.0
		var acertos_antes:int=alvo.acertos
		g.iniciar_ataque(direcao_ataque)
		g._physics_process(.30);g._physics_process(.04)
		var sufixo:String="cima" if direcao_ataque==Vector2.UP else "esquerda"
		verificar("ataque integrado com rumo e impacto: "+sufixo,g.esta_atacando and g._clip=="combo_"+sufixo and alvo.acertos==acertos_antes+1)
		verificar("alvo real preservado em todas direcoes: "+sufixo,g._centro_do_alvo(alvo).is_equal_approx(alvo.global_position))
	g._cancelar_golpe()
	# Dano real troca o atlas, avança as poses e encerra sem virar para o recuo.
	g.ia_habilitada=false
	for rumo in [Vector2.DOWN,Vector2.RIGHT,Vector2.UP,Vector2.LEFT]:
		g.definir_direcao_animacao(rumo)
		var sufixo:String=g.DIRECOES[g.direcao]
		g.receber_dano(1, -rumo*20.0)
		var inicio_dano:Texture2D=g.sprite.texture
		verificar("receber dano inicia clipe direcional: "+sufixo,g.animacao=="ferido" and g._clip=="ferido_"+sufixo)
		g._physics_process(.08)
		verificar("reacao avanca mantendo raiz e rumo: "+sufixo,g.sprite.texture!=inicio_dano and g._clip=="ferido_"+sufixo and g.sprite.offset==Vector2(-320,-560))
		g.receber_dano(1,-rumo*20.0)
		verificar("novo impacto reinicia reacao: "+sufixo,g.tempo_animacao==0.0)
		g._physics_process(.4)
		verificar("reacao termina sem repetir: "+sufixo,g.animacao=="parado" and g._clip=="parado_"+sufixo)
	var replica=load("res://codigo/coop_online/inimigo_replica.gd").new()
	cena.add_child(replica)
	var configurou:bool=replica.configurar({"cena":"res://cenas/inimigos/goblin_pomar.tscn","barra":false,"vm":44})
	verificar("replica online nasce recortada com pivo e escala corretos",configurou and replica.sprites.size()==1 and replica.sprites[0].texture is AtlasTexture and not replica.sprites[0].centered and replica.sprites[0].offset==Vector2(-320,-560) and replica.sprites[0].hframes==1 and replica.sprites[0].scale.is_equal_approx(Vector2.ONE*.071))
	replica.queue_free()
	alvo.queue_free()
	var mortes:=[0];g.inimigo_morreu.connect(func():mortes[0]+=1)
	g.morrer();g.morrer();verificar("morte unica e animada",mortes[0]==1 and g.animacao=="morrer")
	verificar("morte usa atlas da direcao atual",g._clip=="morte_"+g.DIRECOES[g.direcao])
	g.fator_velocidade_animacao=0.0
	var inicio_morte:Texture2D=g.sprite.texture
	g._physics_process(.2)
	verificar("queda desenhada avanca sem giro rigido",g.sprite.texture!=inicio_morte and is_zero_approx(g.sprite.rotation) and is_equal_approx(g.sprite.modulate.a,1.0))
	g._physics_process(1.2)
	var fim_morte:AtlasTexture=g.sprite.texture
	verificar("ultimo quadro deitado permanece visivel",fim_morte.region.position==Vector2(1920,640) and is_equal_approx(g.sprite.modulate.a,1.0) and not g.is_queued_for_deletion())
	g._physics_process(.6)
	verificar("pausa no chao antes da limpeza",g.sprite.texture==fim_morte and is_equal_approx(g.sprite.modulate.a,1.0))
	g._physics_process(.35)
	verificar("corpo some somente depois da queda e repouso",g.sprite.modulate.a>0.0 and g.sprite.modulate.a<1.0)
	g._physics_process(.3)
	verificar("morte limpa instancia e nao duplica sinal",g.is_queued_for_deletion() and mortes[0]==1)
	cena._escolha_ativa="tomas_menu"
	cena.interface._abrir_tela("introducao")
	verificar("reentrada abre",cena.abrir_regiao("pomar")==OK)
	verificar("troca de regiao encerra conversa anterior",not cena.interface._telas_abertas.has("introducao") and cena._escolha_ativa.is_empty())
	await quadros(6)
	verificar("reentrada repoe 32 sem duplicar",cena.goblins_espalhados.size()==32 and get_nodes_in_group("goblins_pomar").size()==32)
	verificar("saida para outra regiao",cena.abrir_regiao("vila")==OK)
	await quadros(6)
	verificar("goblins removidos ao sair",cena.goblins_espalhados.is_empty() and get_nodes_in_group("goblins_pomar").is_empty())
	print("Falhas: ",falhas);quit(1 if falhas else 0)
