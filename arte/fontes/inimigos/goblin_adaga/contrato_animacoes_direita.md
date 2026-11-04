# Goblin com adaga — corrida e combo à direita

Modelo canônico: `assets/inimigos/goblin_adaga/modelo_base.png`, vista central. Preservar pele oliva, cabelo, orelhas, proporções, couro castanho, faixa ocre e adaga curta na mão direita. Personagem com altura de repouso equivalente aos 31 px do jogador; não redimensionar cada pose pelo contorno.

Câmera lateral direita em vista elevada do RPG. Só esta direção é produzida nesta etapa. Corrida: 8 fases, tempos 50/60/40/50 ms por meia passada, 400 ms/ciclo; contatos alternados, absorção, passagem e voo. Deslocamento previsto 100 px/s (40 px/ciclo), a conferir na reprodução. Guia anatômico e apoios em `movimento_direita.json` e `guia_corrida_direita.png`.

Combo: três golpes de adaga na mesma mão, corte, retorno e estocada; quatro fases por golpe (antecipação, impacto, continuação e ligação/recuperação), sem repetição no recurso. As durações individuais e os quadros de impacto ficam registrados junto do atlas. O GIF demonstrativo acrescenta pausa entre execuções, sem alterar a sequência consumida pelo motor.

Grade planejada de 512×512 por pose; pivô (256,448), raiz anatômica constante, sem recortar por contorno. Receber a arte gerada, inspecionar a grade real e registrar ajustes comuns antes do empacotamento. Recurso `SpriteFrames` e cena própria de prévia; sem expandir outras direções ou substituir mobs ativos neste estudo de animação.

## Recursos preparados e registro da arte recebida

Fontes geradas pelo `image_gen` integrado: `corrida_direita_v1.png` (1774×887, grade 4×2) e `combo_direita_v1.png` (1448×1086, grade 4×3). Prompts correspondentes: `prompt_corrida_direita.txt` e `prompt_combo_direita.txt`. Guias próprios são referências de fase, não transferência comprovada de articulações.

Empacotamento por `ferramentas/inimigos/preparar_goblin_adaga.gd`: uma transformação uniforme para cada folha inteira estabelece células de 512 px; depois elas são alojadas em células transparentes de 640×640, com deslocamentos comuns (64,84) na corrida e (64,72) no combo. Não há escala nem centro por contorno de cada pose. Limpeza técnica de alfa residual até 16/255 durante importação; as fontes permanecem intactas. Pivô final (320,560), escala 0,071. Altura da guarda 31,03 px; a corrida baixa o corpo por flexão e voo, sem alterar o tamanho anatômico.

Atlas finais e tempos em `assets/inimigos/goblin_adaga/registro_animacoes.json`; `animacoes.tres` contém `correr_direita`, `combo_direita`, os três golpes separados e `parado_direita`. A cena `cenas/inimigos/goblin_adaga_visual.tscn` reproduz os recursos. O combo não repete e retorna à guarda; sinais de impacto nos quadros 1,5,9 (índices iniciados em zero), aos 100/550/1020 ms. Duração total 1250 ms, incluindo duas pausas de 200 ms entre golpes.

Revisão de identidade e movimento: mesma roupa, orelhas, rosto e adaga nas poses; perfis à direita, torso gira nos cortes; antebraço e punho conduzem a lâmina. Corrida alterna perna próxima/distante nas duas metades, com contatos 0/4 e fases aéreas 3/7. Fechamento 7→0 conecta a perna próxima avançando ao contato. Tempos 50/60/40/50 por meia passada acompanham o recuo dos apoios na reprodução a 100 px/s; não alinhar todos os quadros pela sola mais baixa, pois os de voo devem subir.

Folhas de contato e GIFs saem dos mesmos atlas e durações. A revisão no motor usa projeto e save isolados, duas execuções do combo e mais de quatro ciclos de corrida, incluindo dois ciclos em deslocamento. A captura do mapa corrige a limitação anterior do fundo cinza. Evidências em `arte/previas/inimigos/goblin_adaga/`; teste estrutural e de reprodução pelo perfil selecionado `goblin_adaga_animacoes`. A revisão cobre a produção à direita solicitada; não introduz um inimigo com IA/colisão de combate.

Ajuste de ritmo solicitado: corrida e combo acelerados em 40% sobre a primeira prévia (560→400 ms e 1190→850 ms). Deslocamento proporcional de 72→100 px/s. O GIF demonstra pausa de 250 ms entre combos; ela não faz parte da animação do motor.

Intervalos pedidos entre golpes: o combo segura as poses de ligação 3 e 7 por mais 200 ms cada (270 ms por pose contando a recuperação original de 70 ms). O ritmo acelerado dos golpes individuais continua igual. O intervalo só pertence ao combo encadeado; os três clipes isolados mantêm os tempos rápidos.
