extends "res://ferramentas/armaduras/revisar_mordomo_3d.gd"
## Mesma revisão de rig, peças e ações; referência e slots do Carrasco.
func _initialize():
 conjunto=preload("res://assets/personagens/conjuntos/carrasco/definicao.gd")
 id_conjunto="carrasco"
 outro_id="cavalheiro"
 indice_cosmetico=43
 saida="res://arte/previas/armaduras/carrasco_3d/"
 rodar.call_deferred()

func conferir_misturas():
 var slots=["cabeca","corpo","luvas","botas"]
 var prefixos=["elmo_","peitoral_","luvas_","botas_"]
 for escolha in 16:
  j.inventario.equipados.clear()
  for i in 4:
   var id: String="carrasco" if escolha & (1<<i) else "cavalheiro"
   j.inventario.equipados[slots[i]]=Receitas.criar_item(prefixos[i]+id)
  h._armaduras.atualizar()
  conferir(h._armaduras.mascara==15,"Mistura mantém quatro peças %d"%escolha)
  for i in 4:
   var id: String="carrasco" if escolha & (1<<i) else "cavalheiro"
   conferir(h._armaduras.raizes_pecas[i].contains("/"+id+"/"),"Slot usa o conjunto correto")
  conferir(h._pecas[3].visible==not bool(escolha & 1),"Mistura respeita cabelo e tipo de elmo")
  var grevas: float=h._pecas[1].material_override.get_shader_parameter("altura_grevas")
  conferir(is_equal_approx(grevas,.46 if escolha & 8 else 0.),"Cobertura da calça acompanha as grevas")
  for d in [0,4]:
   pose("parado",d,0)
   await foto("mistura_%02d_%d"%[escolha,d])
