# Kit modular da Vila das Flores

O kit **Mana v2** usa três folhas novas geradas com as imagens Mana Seed do projeto como referência: terreno, construções e objetos. Os arquivos originais estão em `assets/cenario/cidade/tilesets/mana_v2/` e foram preservados sem redução. Fontes e prompts ficam em `arte/fontes/cidade/tilesets/mana_v2/` e `arte/fontes/cidade/prompts_mana_v2.json`.

## Construir no Godot

1. Abra `cenas/cidade.tscn` para editar terreno, praça, trilhas, horta e ponte.
2. O chão usa `recursos/cidade/tileset_cidade.tres`. A escala `16/307` transforma cada célula do atlas em um tile de 16 pixels no mundo.
3. As seis casas dos moradores são imagens inteiras geradas no PixelLab (`assets/cenario/cidade/casas/exterior/<id>.png`; fontes e versões em `arte/fontes/cenario/casas/`). Cada uma é um nó com o script `codigo/cidade/casa_exterior.gd` e o `id` da casa; as medidas ficam em `assets/cenario/cidade/casas/exteriores.json`: âncora no centro da porta, colisões, chaminé (fumaça) e janelas (luz quente à noite).
4. Para trocar o visual de uma casa, gere outra imagem, substitua o PNG e refaça as medidas no JSON (a grade de 10 px em `arte/previas/cenario/` ajuda a medir). A porta precisa ficar sob a âncora para a passagem e a chegada seguirem alinhadas.
5. As construções modulares antigas (`recursos/cidade/construcoes/`, tileset de construções) não são mais usadas na vila; ficam como fonte. O coreto continua modular.
6. O lago e o riacho usam o tile de água novo com contorno contínuo, sem cortar a margem em quadrados. Os objetos têm recortes próprios na folha nova.

As fachadas usam células de 24 pixels no mundo. Portas têm 40 pixels de altura, janelas 24, e o telhado tem cobertura e beiral contínuos. Cada construção tem dimensões e detalhes próprios. O anexo do agricultor e a torre da mística também têm colisão.

## Regenerar

```bash
python3 ferramentas/cidade/gerar_tilesets.py
python3 ferramentas/cidade/gerar_cidade.py
```

O primeiro comando configura os atlas e as seis construções. O segundo monta o mapa e os interiores. Guarde as alterações manuais antes de regenerar as cenas. As folhas antigas permanecem preservadas como fontes, mas a vila usa a versão Mana v2.

## Interiores das casas

Cada casa é uma sala (imagem inteira gerada no PixelLab em `assets/cenario/cidade/interiores/<casa>/sala.png`, recortada pelo `recorte` da casa) com móveis soltos em `props/<nome>.png`, no padrão do Mana Seed: o pack (`cozy furnishings sampler`, recortes de `home interiors`) entra como style_image do Pro Flash, e os originais gerados ficam em `arte/fontes/cenario/interiores/<casa>_mana/` (ids dos jobs em `jobs_mana.txt`, baixados por `baixar_mana.sh`). Quem monta tudo é `codigo/cidade/interior_casa.gd`, a partir de `assets/cenario/cidade/interiores/interiores.json`: cada sala tem a própria `geometria` (parede de fundo, fim do chão, paredes laterais, vão da porta), cada móvel é ancorado pela base-centro, tem colisão só no pé (camada 64), profundidade pela base, e pode ter luzes (fogo, vela, cristal, poção) e vapor.

Para mexer nos móveis, edite `CASAS` em `ferramentas/cidade/layout_interiores.py` e rode:

```bash
python3 ferramentas/cidade/layout_interiores.py
python3 ferramentas/cidade/gerar_cidade.py interiores
```

Móvel novo: gere a imagem, ponha em `props/`, rode `ferramentas/interiores/medir.gd` e salve a saída em `ferramentas/cidade/medidas_moveis.json` (retângulo com pixels de cada imagem; o `recorte` de uma sala nova é o `sala_usada` dessa saída). Os pontos dos moradores (`pontos`: trabalho, passeio, cama; `inverno`: quem se aquece na pousada; `mural`: interação do quadro da sede) também ficam nesse layout. Conferência na cópia de testes: `ferramentas/interiores/verificar_colisoes.gd` (colisões e portas; os moradores aparecem como "falha" no próprio ponto) e `ferramentas/interiores/render_interiores.gd` (prévias; um quarto argumento qualquer desenha as colisões).

## Estilo aconchegante (atual)

Desde 15/10/2026 a cidade usa o estilo "aconchegante" (referência: `arte/fontes/cenario/estilo_ref/referencia.png`, de um indie no estilo Stardew; recortes dela entram como style_image no Pro Flash, ids em `estilo_ref/uploads.txt`). Originais das fachadas, placas, vegetação e decoração em `arte/fontes/cenario/aconchego/` (`jobs.txt`, `baixar.sh`); tilesets do chão em `arte/fontes/cenario/terreno_aconchego/`, recoloridos por `recolorir_wang.gd <estação> aconchego` (cores em `PALETA_ACONCHEGO`). A praça tem um anel de terra em volta (a folha terra/pedra é a que tem o calçamento desenhado). Tufos de grama, folhas no outono e trilhas de pedras soltas vêm de `chao_aconchegante()` em `layout_decoracao.py`.

## Terreno, estações e água

O chão vem de quatro tilesets de transição do PixelLab em modo pro (`create_topdown_tileset`, grama/terra, grama/pedra, terra/pedra, grama/água; ids e cantos em `arte/fontes/cenario/terreno_wang/`), que encaixam sem emenda. Saem em cores próprias, então `ferramentas/cidade/recolorir_wang.gd <estação>` tinge cada terreno com a cor da estação no padrão Mana Seed (média dos tiles-base de `arte/fontes/cenario/terreno_mana/<estação>/`, gerados por `create_tiles_pro` com tiles do pack como referência; pedra e terra têm cores fixas em `MEDIAS`). A água sai em 8 quadros, com os tons claros acendendo em ondas diagonais (ciclo de cores, como no Secret of Mana). Prévia de tudo: `ferramentas/cidade/previa_terreno.gd`.

Traçado da vila em `ferramentas/cidade/terreno_vila.py` (`RUAS`, praça, lago, rio) e casas em `codigo/cidade/layout_vila.json`: rua principal leste-oeste (fazenda → ponte), rua da sede descendo até a rua de baixo, praça no cruzamento, fileira de casas de cada lado de frente para as ruas, trilha do portal e parque com o lago ao sul. `gerar_cidade.py` grava a camada `Terrains/Terreno`; `cidade.gd` troca as folhas pela estação do nó Estacoes (que obedece ao F3) e anima a água.

A decoração passa pelo espaçador de `layout_decoracao.py`: nenhuma peça fica em cima de casa, porta, placa, rua ou água, nem de outra peça; quem não cabe sai (a lista sai no terminal).

## Fachadas, placas e decoração

As seis fachadas (`assets/cenario/cidade/casas/exterior/<id>.png`) e as placas de madeira ao lado de cada porta (`.../casas/placa/<id>.png`) foram geradas no PixelLab no padrão Mana Seed (a `casa_fazenda` do pack como style_image); originais em `arte/fontes/cenario/casas_mana/` (ids em `jobs.txt`, `baixar.sh`). Medidas à mão em `.../casas/exteriores.json` (âncora na porta, colisão, janelas acesas, chaminé e a `placa`, cujo nome é escrito pelo jogo na tábua de baixo com a fonte do projeto; `tamanho_fonte` para nomes longos). Com `ferramentas/interiores/ampliar.gd` se mede uma imagem com grade.

A decoração solta da cidade (fonte animada, postes de luz, cercas, canteiros, carrinho, lenha, feno, varal animado, placa de encruzilhada...) fica em `assets/cenario/cidade/decoracao/` (originais e ids em `arte/fontes/cenario/decoracao_mana/`), posta por `ferramentas/cidade/layout_decoracao.py` (gera `decoracao.json`, lido por `codigo/cidade/decoracao_vila.gd`). Folhas animadas: `ferramentas/cidade/montar_folha.gd` junta os quadros do `animate_image` (`download?index=N`). Medidas: `ferramentas/cidade/medir_decoracao.gd` → `medidas_decoracao.json`. Prévia: `ferramentas/cidade/render_fachadas.gd` na cópia de testes.

## Moradores

As folhas dos seis moradores (`assets/npcs/cidade/<id>.png`) vêm do PixelLab no padrão do Mana Seed, na mesma escala do jogador (~31 px de altura, sem redimensionar). Receita: uma captura do jogador (`ferramentas/personagem/capturar_jogador.gd`) como style_image no Pro Flash gera o morador de frente; `create_character` v3 com essa imagem de referência (4 direções) e `animate_character` skeleton-v3 `walking-6-frames` em sul, leste e norte (oeste = leste espelhado). Os quadros baixados ficam em `arte/fontes/npcs/pixellab/<id>/` e `ferramentas/cidade/preparar_npcs_pixellab.gd` monta a folha (7 colunas: parado + 6 de andar; 4 linhas: baixo, direita, cima, esquerda) e atualiza `manifesto.json`. As folhas anteriores ficam em `arte/fontes/npcs/cidade_antigos/`.

Testes e prévias devem usar uma cópia com saves isolados, conforme o README do projeto.
