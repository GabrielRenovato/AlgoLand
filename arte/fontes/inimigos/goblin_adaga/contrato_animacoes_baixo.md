# Goblin com adaga — direção para baixo

Referência canônica: vista frontal (esquerda) de `assets/inimigos/goblin_adaga/modelo_base.png`. Preservar pele oliva, presas, cabelo escuro, orelhas, túnica de couro com amarração, faixa ocre, botas e adaga na mão anatômica direita (lado esquerdo da imagem quando a pose está em guarda). Câmera elevada frontal do jogo; corpo, cabeça e pés voltados à parte inferior da tela. Olhos e orelhas frontais legíveis. Rotações locais dos ombros participam dos cortes sem transformar a ação em perfil.

Corrida: 8 quadros, durações 50/60/40/50 ms por meia passada, ciclo 400 ms. Alternar contatos direito/esquerdo, absorção, passagem e voo; os apoios recuam para cima na tela conforme o corpo se desloca para baixo. Deslocamento de referência 100 px/s. Braços em oposição às pernas, adaga curta sempre na mesma mão, sem mudar volume ou escala da cabeça.

Combo: 12 quadros, corte diagonal descendente, retorno diagonal e estocada frontal para baixo (com escorço). Mesmos tempos rápidos da direita, mais 200 ms de pausa nas duas ligações. Total 1250 ms, impactos em 100/550/1020 ms. Não repetir automaticamente. Conservar trajetória da mão e encaixe rígido da lâmina; a estocada pode reduzir o comprimento aparente pelo escorço, não o tamanho real da arma.

Grade planejada 4×2 para corrida e 4×3 para combo, células 512×512; base (256,478), corpo de aproximadamente 430 px na fonte. Conferir a grade recebida e registrar transformação comum antes de empacotar. Entrega em atlas de células 640×640, pivô (320,560), escala visual 0,071 para combinar com os 31 px do jogador e com a direção direita. Sem redimensionar poses pelo contorno. Fontes, prompts, guias e fases nesta pasta; atlas em `assets/inimigos/goblin_adaga/`, prévias em `arte/previas/inimigos/goblin_adaga/`.

Os guias próprios descrevem gesto e apoio; a geração precisa preservar o desenho canônico e ser revisada quadro a quadro, nas passagens e no fechamento do ciclo. Conferir reprodução no Godot em mapa real com save isolado e comparação ao jogador. Esta etapa acrescenta somente corrida/combo para baixo e os recursos necessários para sua reprodução.

## Entrega preparada e evidências

Arte gerada com `image_gen` integrado. Fontes de corrida: `corrida_baixo_v1.png` (primeira tentativa com repetição de perna) e `corrida_baixo_v2.png` (1774×887). A montagem usa a v2 na ordem 0,1,2,7,4,5,6,3: as poses aéreas são colocadas antes dos contatos corretos, sem espelhar o corpo. Os quadros 1 e 6 usam as correções isoladas `corrida_baixo_pose_1_corrigida.png` e `corrida_baixo_pose_6_corrigida.png` (1280×1280): adaga restaurada e perna direita avançada na passagem, respectivamente. Fontes anteriores preservadas para revisão, sem uso da versão rejeitada no atlas final. Prompts: `prompt_corrida_baixo.txt`, `prompt_correcao_corrida_baixo_v2.txt`, `prompt_corrigir_pose_1_baixo.txt` e `prompt_corrigir_pose_6_baixo.txt`.

Combo: `combo_baixo_v1.png` (1448×1086), prompt `prompt_combo_baixo.txt`. As três ações ficam frontais e atingem a área inferior da imagem; o braço direito cruza o torso nos cortes e a estocada tem escorço. As pausas adicionais de 200 ms ficam nas poses 3 e 7; não acrescentam impactos nem alteram a velocidade dos clipes de ataque individuais.

Preparação reproduzível: `ferramentas/inimigos/preparar_goblin_adaga.gd`, seguido de `ferramentas/inimigos/montar_previas_goblin_adaga.py`. Transformações uniformes de tela por ação: corrida usa células intermediárias de 472 px e deslocamento (84,104); combo usa 500 px e deslocamento (70,83). As correções isoladas usam exatamente a mesma tela e transformação dos demais quadros. Não há redimensionamento ou centralização pelo contorno de cada pose. Célula final 640 px, pivô (320,560), escala 0,071. O combo recebeu limpeza técnica de alfa residual até 40/255 para eliminar uma mancha isolada de opacidade máxima 38/255 fora da figura; a fonte permanece intacta.

Recursos carregados: `assets/inimigos/goblin_adaga/correr_baixo.png`, `combo_baixo.png`, `animacoes.tres` e `registro_animacoes.json`. O consumidor `codigo/inimigos/goblin_adaga_visual.gd` aceita `tocar("correr", "baixo")` ou `tocar("combo", "baixo")`, emite os três impactos e retorna à guarda da mesma direção. A chamada anterior sem direção mantém a reprodução à direita.

Revisão: folha de contato com todos os oito quadros de corrida e doze de combo; identidade, mão dominante, direção frontal, pernas alternadas, fases aéreas e passagem 7→0 inspecionadas. GIFs usam os mesmos atlas e tempos do motor. Reprodução no Godot 4.7.2 com save isolado, no mapa da Bacia do Moinho, jogador ao lado, duas execuções do combo e mais de quatro ciclos de corrida, além de dois ciclos com deslocamento para baixo. Capturas e gravações em `arte/previas/inimigos/goblin_adaga/`, sufixo `_baixo`. O teste `goblin_adaga_animacoes` cobre ambas as direções, margens, altura, tempos, intervalos, sinais únicos e retorno à guarda.

## Correção de cabeça e pescoço

- As folhas `corrida_baixo_cabeca_v1.png` e `combo_baixo_cabeca_v1.png` substituem as fontes ativas da direção baixo. Criadas pelo image_gen integrado a partir dos atlas finais ordenados, preservam as correções de alternância das pernas e adaga. Os atlas anteriores estão em `correr_baixo_antes_cabeca.png` e `combo_baixo_antes_cabeca.png`.
- Prompts exatos: `prompt_cabeca_corrida_baixo.txt` e `prompt_cabeca_combo_baixo.txt`.
- A edição redesenha o queixo, a perspectiva do rosto, a inclinação das orelhas e o pescoço. Na corrida, a cabeça baixa nas absorções e sobe nas fases de voo. No combo, acompanha os cortes e recolhe o queixo na estocada. Não há transformação adicional de cabeça no controlador.
- As novas folhas representam células finais de 640 px: redimensionamento comum da grade para 2560×1280/1920, sem deslocamento, nova ordem ou ajuste individual por contorno. Pivô (320,560), escala 0,071. Altura da guarda revisada: 30,956 px.
- Tempos mantidos: corrida 400 ms, combo 1250 ms, pausas adicionais de 200 ms nos quadros 3 e 7. Direita preservada.
- Revisados todos os contatos e capturas reais no Godot com jogador ao lado e deslocamento frontal. Verificação `goblin_adaga_animacoes`: 28 OK, zero falhas; relatório `/tmp/algoland-harness/execucao-s2g4ouzo/relatorio.json`.

## Revisão da corrida com referência externa

O usuário esclareceu que a crítica é ao movimento de corrida, não à qualidade da arte. A hipótese de trocar o acabamento foi descartada. Somente `correr_baixo` usa agora `corrida_baixo_referencia_v1.png`, gerada pelo image_gen integrado com a aparência original e a prévia frontal de corrida de Oul Studio como referência de movimento. Fontes, atribuições, links e limitações em `referencias_internet/REFERENCIAS.md`; prompt em `prompt_corrida_baixo_referencia_internet.txt`. Não houve cópia literal de articulações ou integração de pacote externo.

Oito fases preservam os mesmos tempos e a escala anterior. A revisão concentra apoio, compressão, oposição braço/perna, encurtamento da perna recuada, voo e fechamento. Cabeça e tronco variam juntos em pequena amplitude; o queixo não faz os grandes acenos da tentativa anterior. Combo e direita mantêm suas fontes.

Revisão: contatos dos oito quadros, sequência real capturada no Godot com player ao lado e corrida avançando a 100 px/s. Prévia `correr_baixo.gif` usa exatamente os quadros e tempos do recurso. Verificações estruturais/de reprodução: 28 OK, zero falhas em `/tmp/algoland-harness/execucao-qxcmul3j/relatorio.json`; uma aferição de relógio falhou na execução concorrente anterior e passou na repetição isolada, sem alterar o teste ou os tempos. Isso não constitui aprovação artística do usuário.
