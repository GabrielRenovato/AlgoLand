extends SceneTree
const Sustento=preload("res://codigo/jogador/sustento_combate.gd")
var falhas=0
var verificacoes=0
class Alvo extends Node2D:
 var vida=100
 var bloqueado=false
 var esta_morto=false
 func receber_dano(dano:int,_forca=Vector2.ZERO):
  if not bloqueado:vida=maxi(0,vida-dano);esta_morto=vida==0
func _initialize():rodar.call_deferred()
func conferir(ok:bool,texto:String):
 verificacoes+=1
 if not ok:falhas+=1;push_error(texto)
func rodar():
 assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
 await process_frame
 var s=Sustento.new();var cura=0
 for i in 100:cura+=s.recuperar(10000,0.8)
 conferir(cura==3,"Cem alvos e percentuais antigos não multiplicam o orçamento")
 s.ferido();s.avancar(1.1);conferir(s.recuperar(100,1)==0,"Dano recente interrompe roubo")
 s.avancar(0.2);conferir(s.recuperar(100,1)==3,"Esquivar abre recuperação limitada")
 s=Sustento.new();conferir(s.recuperar(0,1)==0,"Dano bloqueado não cura")
 cura=0
 for i in 13:cura+=s.recuperar(1,1)
 conferir(cura==1,"Acertos pequenos acumulam frações, sem cura mínima por alvo")
 var prog=root.get_node("Progresso");prog.apagar();prog.brasas=10000
 conferir(prog.comprar_melhoria("vigor"),"Primeira melhoria acessível")
 var antes=prog.brasas
 conferir(not prog.comprar_melhoria("vigor") and prog.brasas==antes,"Não compra cinco níveis antes de explorar")
 prog.maior_onda_vencida=30
 for id in prog.ORDEM_MELHORIAS:
  while prog.nivel(id)<5:conferir(prog.comprar_melhoria(id),"Nível comprado após marcos: "+id)
 conferir(prog.bonus_melhoria("vigor")<=0.15 and prog.bonus_melhoria("forca")<=0.10 and prog.bonus_melhoria("couraca")<=0.05,"Melhorias antigas no máximo não anulam o combate")
 root.get_node("Introducao").pular_prologo();change_scene_to_file("res://cenas/fazenda.tscn")
 for i in 35:await process_frame
 root.get_node("Transicao").limpar();current_scene.process_mode=Node.PROCESS_MODE_DISABLED
 var j=current_scene.get_node("Jogador");j.hp_atual=10;j.estatisticas.hp_maximo=100;j.estatisticas.roubo_vida=30;j.sustento_combate=Sustento.new()
 var a=Alvo.new();current_scene.add_child(a);a.vida=1;j.aplicar_golpe(a,Vector2.ZERO,1,1,{"golpe":{"dano":10000,"critico":false}})
 conferir(j.hp_atual==10,"Golpe de dez mil em alvo de 1 vida não gera cura de dez mil")
 a.esta_morto=false;a.vida=100;a.bloqueado=true;j.aplicar_golpe(a,Vector2.ZERO,1,1,{"golpe":{"dano":10000,"critico":false}})
 conferir(j.hp_atual==10,"Alvo que ignora o dano não dá vida")
 j.estatisticas.vitalidade=100;j.estatisticas.defesa=10000;j.estatisticas.calcular_estatisticas_derivadas();j.hp_atual=j.estatisticas.hp_maximo
 conferir(j.estatisticas.reducao_dano()<=0.60,"Defesa e Couraça têm teto conjunto")
 j.efeitos_pocao.ativos={"pedra":{"valor":0.15,"tempo":30.0},"vampiro":{"valor":0.06,"tempo":30.0}}
 var inicial=j.hp_atual
 for rodada in 20:
  j.invulneravel=false;j.receber_dano(80)
  for k in 10:
   a.vida=100000;a.esta_morto=false;a.bloqueado=false
   j.aplicar_golpe(a,Vector2.ZERO,1,1,{"golpe":{"dano":1000,"critico":true}})
  j.sustento_combate.avancar(0.4)
 conferir(j.hp_atual<inicial*0.5,"Personagem maximizado perde mais de metade da vida ao enfrentar golpes contínuos, mesmo atacando dez alvos")
 print("LIMITES COMBATE: ",verificacoes," verificações; ",falhas," falhas; vida no teste ",inicial," -> ",j.hp_atual)
 quit(1 if falhas else 0)
