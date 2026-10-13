extends SceneTree
# Folha de contato das peças do registro (Codigos/DadosLocais/aparencia.gd) numa página de animação, para conferir se cada cabelo e cada
# roupa existe, alinha com o corpo e fica certo naquela pose. Precisa de janela. Uso:
#   godot --path . --script res://ferramentas/personagem/previa_paginas.gd -- <saida.png> <pagina> <quadro> <roupas|cabelos> [escala]
# <pagina>: andar, fazenda, forja, sentado, espada, lanca, reacao_um_mao, reacao_lanca, reacao_arco, arco_p2, arco_p3.
# roupas: todas as roupas com o cabelo 0; cabelos: todos os cabelos com a roupa de camponês (índice 2) e a cor amarela.

const Aparencia := preload("res://Codigos/DadosLocais/aparencia.gd")
const CORPOS := {
	"andar": "res://CharacterSprites/Body/body_1.png",
	"fazenda": "res://CharacterSprites/Fazenda/corpo.png",
	"forja": "res://CharacterSprites/body_smithing/char_a_p4_0bas_humn_v00.png",
	"sentado": "res://CharacterSprites/body_smithing/char_a_p4_0bas_humn_v00.png",
	"espada": "res://CharacterSprites/Body_sword_chield/body_attack_sword.png",
	"lanca": "res://CharacterSprites/Body_spear_combat/body_spear_combat.png",
	"reacao_um_mao": "res://CharacterSprites/Reacao/um_mao/corpo.png",
	"reacao_lanca": "res://CharacterSprites/Reacao/lanca/corpo.png",
	"reacao_arco": "res://CharacterSprites/Reacao/arco/corpo.png",
	"arco_p2": "res://CharacterSprites/Arco/corpo_p2.png",
	"arco_p3": "res://CharacterSprites/Arco/corpo_p3.png",
}

class Folha extends Node2D:
	var corpo: Texture2D
	var roupas: Array = []
	var cabelos: Array = []
	var quadro := 0
	var escala := 2
	var colunas := 10
	var cor := Color("e8c860")
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 8000, 8000), Color(0.28, 0.28, 0.34))
		var origem := Vector2((quadro % 8) * 64, (quadro / 8) * 64)
		for i in roupas.size():
			var pos := Vector2((i % colunas) * 64 * escala, (i / colunas) * 64 * escala)
			var dst := Rect2(pos, Vector2(64 * escala, 64 * escala))
			var src := Rect2(origem, Vector2(64, 64))
			draw_texture_rect_region(corpo, dst, src)
			if roupas[i] != null:
				draw_texture_rect_region(roupas[i], dst, src)
			if cabelos[i] != null:
				draw_texture_rect_region(cabelos[i], dst, src, cor)
			draw_string(ThemeDB.fallback_font, pos + Vector2(2, 10), str(i), HORIZONTAL_ALIGNMENT_LEFT, -1, 10)

func _initialize() -> void:
	_rodar()

func _rodar() -> void:
	var a := OS.get_cmdline_user_args()
	var pagina: String = a[1]
	var f := Folha.new()
	f.escala = int(a[4]) if a.size() > 4 else 2
	f.quadro = int(a[2])
	f.corpo = load(CORPOS[pagina])
	if a[3] == "roupas":
		for i in Aparencia.total_roupas():
			f.roupas.append(Aparencia.roupa(i, pagina))
			f.cabelos.append(Aparencia.cabelo(0, pagina, i))
	else:
		for i in Aparencia.total_cabelos():
			f.roupas.append(Aparencia.roupa(2, pagina))
			f.cabelos.append(Aparencia.cabelo(i, pagina))
	f.colunas = mini(14, f.roupas.size())
	var vp := SubViewport.new()
	vp.size = Vector2i(f.colunas * 64 * f.escala, ((f.roupas.size() + f.colunas - 1) / f.colunas) * 64 * f.escala)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.add_child(f)
	root.add_child(vp)
	for i in 6:
		await process_frame
	vp.get_texture().get_image().save_png(a[0])
	print("salvo ", a[0])
	quit()
