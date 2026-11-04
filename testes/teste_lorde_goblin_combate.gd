extends SceneTree
## Ator real2D: contato único, área, espelho, interrupção e proteção da chegada.
class Alvo extends CharacterBody2D:
	var estaMorto := false
	var caido := false
	var invulneravel := false
	var acertos := 0
	var dano_total := 0
	func receber_dano(valor: int,_forca: Vector2=Vector2.ZERO) -> void:
		acertos+=1;dano_total+=valor
var falhas := 0
func _initialize() -> void:rodar.call_deferred()
func verificar(nome: String,ok: bool) -> void:
	print("OK " if ok else "FALHA ",nome)
	if not ok:falhas+=1
func rodar() -> void:
	var mundo:=Node2D.new();root.add_child(mundo);current_scene=mundo
	var alvos: Array[Alvo]=[]
	for i in 3:
		var alvo:=Alvo.new();alvo.position=Vector2(1000+i*100,1000)
		alvo.add_to_group("jogadores");mundo.add_child(alvo);alvos.append(alvo)
	var boss=load("res://cenas/inimigos/lorde_goblin.tscn").instantiate()
	boss.ia_habilitada=false;mundo.add_child(boss)
	boss.set_process(false);boss.set_physics_process(false);boss.sprite.set_process(false)
	var vida: int=boss.vida
	boss.receber_dano(50);boss.receber_dano_efeito(20,Color.RED)
	verificar("apresentacao nao recebe dano",boss.vida==vida and not boss.em_combate)
	boss.liberar_combate();boss.set_physics_process(false)
	for rumo in [Vector2.DOWN,Vector2.UP,Vector2.RIGHT,Vector2.LEFT]:
		var id:String=boss.sprite.direcao_para(rumo)
		boss.sprite.orientar(rumo);boss.sprite.definir_andando(true)
		var poses:Array=[]
		for i in 12:
			boss.sprite._process(.11);poses.append(boss.sprite.quadro_andada)
		verificar("caminhada percorre seis poses e fecha ciclo "+id,poses.slice(0,6)==poses.slice(6,12) and poses.has(5) and boss.sprite.andando)
		boss.sprite.definir_andando(false)
		verificar("parada volta a guarda "+id,not boss.sprite.andando and boss.sprite.quadro==0)
		verificar("inicia martelada "+id,boss.iniciar_ataque("martelada",rumo*100))
		verificar("ataque interrompe caminhada "+id,not boss.sprite.andando)
		var centro:Vector2=boss.sprite.ponto_contato_para(rumo)
		alvos[0].position=boss.position+centro-Vector2(0,5)
		alvos[1].position=alvos[0].position+Vector2(12,3)
		alvos[2].position=alvos[0].position+Vector2(500,0)
		var antes: Array[int]=[alvos[0].acertos,alvos[1].acertos,alvos[2].acertos]
		var instante:float=boss.sprite._dados(id).impacto_ms/1000.0
		boss.sprite._process(instante-.001)
		verificar("sem dano antes do contato "+id,alvos[0].acertos==antes[0] and alvos[1].acertos==antes[1])
		boss.sprite._process(.002)
		verificar("area atinge dois alvos uma vez "+id,alvos[0].acertos==antes[0]+1 and alvos[1].acertos==antes[1]+1 and alvos[2].acertos==antes[2])
		verificar("alcance da IA usa mesma area "+id,boss._alvo_ao_alcance("martelada",alvos[0].position) and not boss._alvo_ao_alcance("martelada",alvos[2].position))
		verificar("esquerda espelha atlas da direita "+id,boss.sprite.flip_h==(id=="esquerda"))
		boss.sprite._process(3.0)
		verificar("termina sem dano duplicado "+id,not boss.esta_atacando and alvos[0].acertos==antes[0]+1)
	verificar("dano real foi aplicado",alvos[0].dano_total>0)
	boss.iniciar_ataque("martelada",Vector2(0,100))
	var antes:=alvos[0].acertos
	boss.sprite.cancelar_ataque();boss._fim_ataque();boss.sprite._process(5.0)
	verificar("cancelamento impede dano atrasado",alvos[0].acertos==antes)
	var mortes:Array=[];boss.inimigo_morreu.connect(func():mortes.append(true))
	boss.receber_dano(100000);boss.receber_dano(100000)
	verificar("morte sinaliza derrota uma vez",boss.esta_morto and mortes.size()==1)
	await process_frame
	print("FALHAS: ",falhas);quit(1 if falhas else 0)
