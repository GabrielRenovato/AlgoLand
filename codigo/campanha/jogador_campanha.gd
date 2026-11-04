extends "res://codigo/jogador/jogador.gd"

## O jogador real, com inicialização e derrota próprias da campanha experimental.
signal derrota_campanha
var equipamentos_permitidos: Array = []

func _iniciar_inventario() -> void:
	# O cenário aponta o modelo para seu arquivo isolado antes de criar o jogador.
	if not inventario.carregar():
		inventario._limpar()
		inventario._caminho_inicializado = inventario.caminho_save
	# A migração do inventário comum concede armas básicas; a campanha só
	# conserva equipamentos já encontrados no seu diário.
	for tipo in ["espada_basica", "escudo_basico"]:
		if tipo in equipamentos_permitidos: continue
		for slot in inventario.equipados:
			if inventario.equipados[slot] != null and inventario.equipados[slot].tipo == tipo:
				inventario.equipados[slot] = null
				inventario.celulas_da_mao[slot] = -1
		for i in inventario.mochila.size():
			if inventario.mochila[i] != null and inventario.mochila[i].tipo == tipo:
				inventario.mochila[i] = null
	# A campanha mantém só a vara entre os utensílios; não altera a mochila do jogo livre.
	for i in inventario.mochila.size():
		if inventario.mochila[i]!=null and inventario.mochila[i].categoria=="ferramenta":
			inventario.mochila[i]=null
	if inventario.ouro_campanha<0:inventario.ouro_campanha=maxi(0,DadosJogo.moedas)
	DadosJogo.moedas=inventario.ouro_campanha
	inventario.sincronizar_vara()
	inventario._avisar_mochila()
	inventario.salvar()
	_aplicar_modelo()
	equipamento_alterado.connect(_enviar_estado_ao_modelo)
	inventario.equipamento_alterado.connect(_ao_modelo_equipamento_alterado)
	_inventario_pronto = true

func morrer(_ignorar_reviver: bool = false) -> void:
	if estaMorto:
		return
	if get_parent().get("registro_run")!=null:get_parent().registro_run.morte()
	estaMorto = true
	hp_atual = 0
	velocity = Vector2.ZERO
	defesa.cancelar()
	desabilitar_todas_acoes(true)
	derrota_campanha.emit()

func receber_dano(dano: int, forca_knockback := Vector2.ZERO) -> void:
	var antes: int=hp_atual
	super.receber_dano(dano,forca_knockback)
	var cena := get_parent()
	if cena.get("registro_run")!=null:cena.registro_run.dano_recebido(maxi(0,antes-hp_atual))

## Saldo da campanha viaja na mesma gravação atômica da mochila.
func adicionar_moedas(quantidade: int) -> void:
	var anterior: int=inventario.ouro_campanha
	inventario.ouro_campanha=maxi(0,anterior+quantidade)
	if not inventario.salvar():
		inventario.ouro_campanha=anterior
		return
	DadosJogo.moedas=inventario.ouro_campanha
	atualizar_rotulo_moedas()

func gastar_moedas(quantidade: int) -> void:
	if quantidade>0 and quantidade<=inventario.ouro_campanha:adicionar_moedas(-quantidade)
