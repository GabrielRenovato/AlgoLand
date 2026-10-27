extends "res://ferramentas/armaduras/revisar_mordomo_3d.gd"
## Referência original do usuário, quatro slots e misturas com os dois conjuntos anteriores.
func _initialize():
 conjunto=preload("res://assets/personagens/conjuntos/cavaleiro_rubro/definicao.gd")
 id_conjunto="cavaleiro_rubro"
 outro_id="carrasco"
 indice_cosmetico=44
 saida="res://arte/previas/armaduras/rubro_3d/"
 rodar.call_deferred()

func conferir_misturas():
 var slots=["cabeca","corpo","luvas","botas"]
 var prefixos=["elmo_","peitoral_","luvas_","botas_"]
 for anterior in ["cavalheiro","carrasco"]:
  for escolha in 16:
   j.inventario.equipados.clear()
   for i in 4:
    var id: String=id_conjunto if escolha & (1<<i) else anterior
    j.inventario.equipados[slots[i]]=Receitas.criar_item(prefixos[i]+id)
   h._armaduras.atualizar()
   conferir(h._armaduras.mascara==15,"Mistura mantém quatro peças %s/%d"%[anterior,escolha])
   for i in 4:
    var id: String=id_conjunto if escolha & (1<<i) else anterior
    conferir(h._armaduras.raizes_pecas[i].contains("/"+id+"/"),"Slot usa o conjunto correto")
   var fechado: bool=bool(escolha & 1) or anterior=="carrasco"
   conferir(h._pecas[3].visible==not fechado,"Mistura respeita cabelo e tipo de elmo")
   var grevas: float=h._pecas[1].material_override.get_shader_parameter("altura_grevas")
   conferir(is_equal_approx(grevas,.46 if escolha & 8 or anterior=="carrasco" else 0.),"Cobertura da calça acompanha as grevas")
   for d in [0,4]:
    pose("parado",d,0)
    await foto("mistura_%s_%02d_%d"%[anterior,escolha,d])
