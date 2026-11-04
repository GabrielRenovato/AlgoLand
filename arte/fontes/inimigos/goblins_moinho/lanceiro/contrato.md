# Lanceiro — caminhada e estocada

Modelo canônico: linha superior de `../modelos_v1.png`. Pintura 2D, câmera elevada fixa, goblin compacto de couro castanho e tecido ocre. Preservar rosto, corpo, orelhas, botas e lança de madeira/ferro. As mãos mantêm sua posição na haste. Quatro vistas desenhadas: baixo, direita, cima e esquerda; não girar uma folha lateral para inventar frente/costas.

Caminhada: seis poses por direção (contato esquerdo, absorção esquerda, passagem direita, contato direito, absorção direita, passagem esquerda), dez quadros por segundo, ciclo de 0,6 s. Alternância dos pés e último→primeiro revisados. Pequeno balanço do corpo e da lança, sem atacar andando.

Estocada: seis poses por direção (guarda, recuo/antecipação, projeção, extensão máxima, recolhimento, retorno à guarda), durações previstas 0,14/0,14/0,09/0,10/0,15/0,18 s; ação de 0,80 s sem repetição. Não substituir estocada por corte ou rotação da lança. Apoio das mãos, ponta e pé de avanço devem ser conferidos em cada vista.

Fontes previstas 1536×1024, três colunas e duas linhas de 512×512. Raiz de referência (256,448), corpo previsto de 300 pixels. A raiz/escala finais são medidas no primeiro ciclo e registradas junto das folhas; o registro não recentraliza cada pose por silhueta. Corpo final com cerca de 26 pixels lógicos, menor que o player. Sem sombras pintadas no chão nem efeitos misturados à anatomia.

Fontes e prompts nesta pasta; atlas e SpriteFrames em `assets/inimigos/goblins_moinho/lanceiro/`; prévias e evidências em `arte/previas/inimigos/goblins_moinho/lanceiro/`. Esta tarefa entrega o recurso animado; população, patrulha e combate do estágio serão integrados separadamente.

## Recursos exportados

Oito animações: `andar_baixo`, `andar_direita`, `andar_cima`, `andar_esquerda`, e os quatro `ataque_*`. Seis desenhos por animação, 48 no total. Fontes selecionadas no `registro.json`; v1/v2 de estudos que não constam desse registro não são consumidas. Desenhos de esquerda próprios, sem espelhamento do equipamento.

Exportação: células intermediárias 1024×1024, raiz (512,896); reamostragem uniforme 0,25 para células finais de 256×256, pivô (128,224), atlas 1536×256. Registro anatômico comum por linha compensado no recorte, sem recentralização de cada silhueta. Escala fixa por folha para manter corpo próximo de 26 pixels lógicos. Componentes são extraídos com suas faixas próprias, sem pedaços das figuras vizinhas nas pontas das lanças. A máscara da caminhada traseira usa suporte opaco e margem de um pixel para excluir o halo do fundo; as demais mantêm quatro pixels de margem de alfa.

Consumo: `assets/inimigos/goblins_moinho/lanceiro/animacoes.tres`, `cenas/inimigos/goblin_lanceiro_visual.tscn`, script `codigo/inimigos/lanceiro_moinho_visual.gd`. `tocar("andar", "baixo")` ou `tocar("ataque", "direita")`. Ataque não repete; o chamador aguarda `animation_finished` antes de escolher a próxima ação. Esses recursos não aplicam dano nem ativam IA. Ao integrar combate, a extensão visual ocupa 0,28–0,47 s; dano e alcance devem ser calibrados no corpo físico correspondente.

Preparar: Godot em projeto isolado, `--headless --script res://ferramentas/inimigos/preparar_lanceiro_moinho.gd`; importar os PNGs gerados; renderizar `--script res://ferramentas/inimigos/previa_lanceiro_moinho.gd`. A prévia reproduz dois ciclos de caminhada e uma estocada nas quatro vistas, depois captura as poses pelo mesmo SpriteFrames.
