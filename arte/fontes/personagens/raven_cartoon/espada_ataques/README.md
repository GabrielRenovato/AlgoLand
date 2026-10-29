# Espada cartoon nos ataques

Espada simples de uma mão baseada no modelo e nas camadas Mana Seed ONE3, produzida pelo `image_gen` integrado. Fonte preservada em `espada_base_original.png`, prompt em `prompt_espada.txt`, referência em `referencia_espada_isolada.png`. A textura consumida é `assets/personagens/raven_cartoon/espada_base_cartoon.png`, com alfa preservado.

Os corpos aprovados não foram redesenhados. A arma é uma camada independente em `camada_espada.gd`, com punhos e ângulos por quadro em `assets/personagens/raven_cartoon/pegadas_espada_base.json`. Pivô474×1350 na imagem948×1660, escala vertical constante0,30 e horizontal0,352; comprimento constante entre quadros. A lâmina ficou 36,36% mais longa e 60% mais larga, mantendo o pivô do cabo. O porte nas costas usa exatamente a mesma proporção. Esquerda espelha o corpo e arma ao redor da raiz da direita. O quarto tempo repete o término do terceiro, como as animações-base.

Ângulos e ordem seguem a referência visual de espada Mana Seed: frontal cima/direita/cima-esquerda; costas baixo-esquerda/cima-esquerda/direita; lateral cima-esquerda/baixo-esquerda/cima. A espada passa atrás do corpo, exceto a passagem do ataque lateral no segundo quadro. Nesse quadro, um recorte exato da própria textura do punho cobre o cabo, sem pintura ou alteração de pixels. A ordem efetiva fica acima do fundo da prévia em todos os casos.

Revisão: `revisar_todos_ataques.gd -- --com-espada`, em projeto/save isolado no Godot. Layout2×2, tela lógica1280×1280 e janela900×900 para evitar corte pelo gerenciador de janelas. Quatro tempos sincronizados160/60/70/200ms e duas reproduções. Capturas em `arte/previas/personagens/raven_cartoon/ataques_quatro_direcoes_com_espada/motor/`.

Exportar o GIF a partir das capturas reais: `python3 ferramentas/personagem/raven_cartoon/exportar_previa_espada.py`. Confere dimensões das capturas, margens da arma/títulos e16 amostras de aço visível, detectando regressão da arma escondida pelo fundo. Também foram inspecionados os três desenhos únicos e as pegadas ampliadas. GIF inicial `ataques_com_espada.gif`; versão atual `ataques_com_espada_e_rastro_v2.gif`,490ms. Prévia independente; não troca o personagem ou inventário ativo.

## Comparação direta com Mana Seed

`comparar_ataques_com_espada.gd` renderiza quatro duplas no Godot isolado: referência à esquerda, Raven à direita. Usa cópias sem alteração dos atlas `char_a_pONE3_0bas_humn_v01.png` e `6tla/char_a_pONE3_6tla_sw01_v01.png`, do pacote local `21.07b - Sword & Shield Combat 2.3a/char_a_pONE3`, guardadas como `assets/personagens/raven_cartoon/comparacao_mana_{corpo,espada}.png`. Slash1 ocupa quatro colunas de 64px; linhas baixo/cima/direita/esquerda são 0/1/2/3. A espada original inclui o arco branco, mantido na comparação; o Raven agora usa um rastro suave nativo do Godot nos mesmos tempos de corte. A adaptação cartoon mantém as fases, com proporções próprias e espada mais encorpada para o personagem cartoon.

Oito corpos sincronizados, quatro fases e duas reproduções; camadas da arma conforme guia do autor. Tela lógica 1920×1280, janela 1050×700. Capturas em `motor/comparacao/`, com registro em `reproducao.json`. Exportar com `python3 ferramentas/personagem/raven_cartoon/exportar_comparacao_espada.py`: verifica margens da referência e durações de 160/60/70/200ms. Resultado atualizado `comparacao_mana_seed_com_rastro_v2.gif`; a primeira versão sem rastro permanece preservada. Não substitui recursos ou animações aprovados.


## Rastro branco do golpe

Camada editável nativa em `rastro_espada.gd`, consumida por `camada_espada.gd`; parâmetros em `assets/personagens/raven_cartoon/rastros_espada.json`. Não houve regeneração do corpo ou da arma. A faixa elíptica branca tem 96 segmentos e pontas afiladas; orientação e fases foram comparadas visualmente com Slash1: arco inferior para baixo, superior para cima, lateral nos perfis. Esquerda espelha corpo, espada e efeito juntos. O efeito fica à frente da espada e do recorte do punho, com z_index relativo +3 (espada -1/+1, punho +2). As partes da lâmina que cruzam a faixa branca são cobertas pelo rastro. Quadros 1 e 4 sem rastro, quadro 2 com arco largo e quadro 3 com continuação mais estreita. Mantém os tempos 160/60/70/200ms.

Revisadas as duas fases visíveis e a ausência no término em capturas reais do Godot isolado, tanto no layout das quatro direções quanto no comparativo. Os exportadores também verificam presença/ausência do branco nos 16 estados, além das verificações de arma e margens existentes. Dois pontos reais de cruzamento da lâmina com o arco no segundo quadro também devem ficar brancos, detectando inversão da ordem das camadas. Não altera o personagem ativo ou os saves do jogo.

O alcance visual do rastro acompanha a lâmina maior: `acrescimo_raio_rastro=110` nos dois arquivos de pegadas. Mantém ordem acima da espada e os tempos dos dois golpes. A gravação atual integrada à fazenda fica em `arte/previas/personagens/raven_cartoon/no_jogo/`.
