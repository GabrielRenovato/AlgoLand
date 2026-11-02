extends "res://codigo/logica/equipamento_drop.gd"
## Recompensa pessoal pendente no mesmo arquivo do inventário. Não usa venda automática da arena.
var registro:=""
var saque:Node
func _inventario() -> Node:return saque.inventario
func _jogador() -> Node2D:
 _dono=saque.cena.jogador
 return _dono if is_instance_valid(_dono) and not _dono.estaMorto else null
func _tentar_pegar() -> void:
 if _pego or not is_instance_valid(saque):return
 if not saque.inventario.saque_campanha.pendentes.has(registro):queue_free();return
 var inv:Node=_inventario()
 if not inv.pode_receber(item):
  _atraido=false;_velocidade=0;_recusado_ate=_tempo+ESPERA_RECUSA
  get_tree().call_group(_grupo_hud(),"avisar_equipamento_cheio","MOCHILA CHEIA: O DROP FICA GUARDADO")
  return
 var antes:Array=inv.fotografar_mochila()
 var recibo:Dictionary=inv.saque_campanha.duplicate(true)
 if inv.receber(item)<0:return
 inv.saque_campanha.pendentes.erase(registro)
 if not inv.salvar():
  inv.saque_campanha=recibo;inv.restaurar_mochila(antes)
  _recusado_ate=_tempo+ESPERA_RECUSA;return
 if saque.cena.get("registro_run")!=null:saque.cena.registro_run.drop_recolhido(registro,item)
 _pego=true
 get_tree().call_group(_grupo_hud(),"avisar_equipamento",item)
 Sons.tocar("compra",0.05)
 queue_free()
func vender() -> void:pass
