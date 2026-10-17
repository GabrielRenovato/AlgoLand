extends "res://ferramentas/armaduras/gerar_conjunto.gd"

## Complemento opcional de pesca. Reutiliza os manifestos e o compilador compartilhado,
## preservando ids, quatro peças e as onze páginas obrigatórias existentes.
const CorpoRefinado := preload("res://ferramentas/personagem/preparar_corpo_refinado.gd")
const RAIZ_PESCA := "res://assets/personagens/Pesca/"
const MODELOS := ["res://ferramentas/armaduras/modelos/carrasco.json",
	"res://ferramentas/armaduras/em_preparacao/cavaleiro_rubro/manifesto.json",
	"res://ferramentas/armaduras/em_preparacao/cavalheiro/manifesto.json"]

func _initialize() -> void:
	var corpo := Image.load_from_file(RAIZ_PESCA + "corpo.png")
	var cabelo := Image.load_from_file(RAIZ_PESCA + "cabelos/bob1.png")
	var roupa := Image.load_from_file(RAIZ_PESCA + "roupas/pfpn_v05.png")
	var refinado := corpo.duplicate()
	for y in 512:
		for x in 512:
			var pixel := corpo.get_pixel(x,y)
			if pixel.a > 0.5:
				refinado.set_pixel(x,y,Color.html(CorpoRefinado.PALETA[pixel.to_html(false)]))
	refinado.resize(1024,1024,Image.INTERPOLATE_NEAREST)
	_gravar(refinado,Aparencia.RAIZ_CORPO_REFINADO+"pesca.png")
	for item in Aparencia.cabelos():
		var origem: String = RAIZ_PESCA+"cabelos/"+item["id"]+".png"
		var imagem := Image.load_from_file(origem)
		imagem.resize(1024,1024,Image.INTERPOLATE_NEAREST)
		_gravar(imagem,Aparencia.RAIZ_CABELOS_REFINADOS+item["id"]+"_pesca.png")
	for nome in DirAccess.get_files_at(RAIZ_PESCA+"roupas/"):
		if nome.ends_with(".png"):
			var origem := RAIZ_PESCA+"roupas/"+nome
			_gravar(Acabamento.refinar(Image.load_from_file(origem)), Aparencia.RAIZ_ROUPAS_REFINADAS+origem.md5_text()+".png")
	for modelo in MODELOS:
		_config = Padrao.carregar(modelo)
		assert(Padrao.validar(_config).is_empty())
		_destino = _config["destino"]
		_paleta = _config["paleta"]
		_elmos.clear(); _peitorais.clear(); _grevas.clear(); _ancoras_elmo.clear()
		_deslocamentos_cabeca.clear(); _elmos_rigidos.clear(); _ancoras_cartola.clear(); _deslocamentos_cranio.clear()
		assert(_preparar_pecas())
		var folhas := {}
		for peca in Padrao.PECAS:
			folhas[peca] = Image.create(512,512,false,Image.FORMAT_RGBA8)
		var mascarado := corpo.duplicate()
		for direcao in 4:
			for coluna in 8:
				var regiao := Rect2i(coluna*64,direcao*64,64,64)
				var cabeca := cabelo.get_region(regiao).get_used_rect()
				var partes := _vestir_tecido(corpo.get_region(regiao),roupa.get_region(regiao),cabeca,direcao) if _config.get("modo_visual", "armadura") == "tecido" else _vestir(corpo.get_region(regiao),roupa.get_region(regiao),cabeca,direcao)
				for peca in partes:
					folhas[peca].blit_rect(partes[peca],Rect2i(0,0,64,64),regiao.position)
				if _config.get("substituir_cabeca",false):
					mascarado.fill_rect(Rect2i(regiao.position+cabeca.position,Vector2i(cabeca.size.x,mini(13,64-cabeca.position.y))),Color.TRANSPARENT)
		var completa := Image.create(512,512,false,Image.FORMAT_RGBA8)
		for peca in ["peitoral","botas","luvas","elmo"]:
			_gravar(folhas[peca],_destino+peca+"/pesca.png")
			completa.blend_rect(folhas[peca],Rect2i(0,0,512,512),Vector2i.ZERO)
		_gravar(completa,_destino+"pesca.png")
		if _config.get("substituir_cabeca",false):
			_gravar(mascarado,_destino+"corpo_sem_cabeca/pesca.png")
		var acabamento := Acabamento.refinar(completa,_config.get("modo_visual","armadura") != "tecido")
		var destino_refinado: String = Acabamento.RAIZ+_config["id"]+"/"
		_gravar(acabamento,destino_refinado+"pesca.png")
		for peca in folhas:
			var mascara: Image = folhas[peca].duplicate()
			mascara.resize(1024,1024,Image.INTERPOLATE_NEAREST)
			var chapa := Image.create(1024,1024,false,Image.FORMAT_RGBA8)
			chapa.blit_rect_mask(acabamento,mascara,Rect2i(0,0,1024,1024),Vector2i.ZERO)
			_gravar(chapa,destino_refinado+peca+"/pesca.png")
		print("Pesca: ",_config["id"],", 32 poses, quatro peças independentes")
	quit()

func _gravar(imagem: Image, caminho: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(caminho.get_base_dir()))
	assert(imagem.save_png(caminho) == OK)
