# Dragão Vermelho

Chefe de quatro patas, duas asas e uma única cauda, inspirado na referência enviada e adaptado para pixel art de RPG. A arte final corrigiu a cauda duplicada e as patas traseiras da quarta pose lateral da varrida.

Aparece na onda 50 e novamente a cada 50 ondas. O rodízio preserva golem (10), rei slime (20), caranguejo (30) e cogumelo (40). A vida e o dano acompanham os multiplicadores das ondas.

Três ataques com preparação visível e direção fixada no início: sopro de fogo em cone (150 px), varrida de cauda em área (82 px), batida de asas em área (112 px, empurrão maior). Cada golpe causa no máximo um impacto no jogador. Congelamento pausa a animação e o ataque. Morte e troca de onda removem avisos e efeitos pendentes.

Os efeitos de impacto usam sprites animados em Efeitos/dragao: fogo saindo da boca, poeira e pedras na cauda, rajada circular nas asas. Cada um possui seis estados e acompanha o relógio do golpe. Fontes, prompts, importador e prévia estão descritos em Efeitos/dragao/LEIAME.md.

F3 → DRAGAO permite ir à próxima onda do dragão e forçar cada golpe para avaliação. Não há escolta na onda de chefe.

O dragão não causa dano por contato ou proximidade: apenas os três golpes acertados aplicam dano. A área de contato está desativada e o método herdado não aplica dano. A ordem de desenho usa a base das patas por direção (frente 10, costas 0, direita 1, esquerda -4 px locais, com escala) e desempata com os pés do jogador quando ambos caem na mesma faixa de profundidade, inclusive no limite do z. Jogador à frente fica sobre as patas; atrás respeita a profundidade. O desempate continua sendo atualizado durante congelamento.

As quatro folhas nativas têm células de 128 × 128, seis colunas e quatro linhas: frente, costas, direita, esquerda. movimento.png usa dois quadros de repouso e quatro de caminhada. sopro.png, cauda.png e asas.png usam três quadros de preparação, dois de impacto e um de recuperação. Todos os pixels nativos são opacos ou transparentes, com 22 cores e filtro nearest, sem mipmaps.

Também há voo.png para a decolagem/pouso e patada.png para a patada frontal. Total: seis páginas, 144 quadros. Fontes voo_v1.png e patada_v1.png e seus prompts estão em fontes/, criadas com image_gen integrado. A patada é usada quando o jogador chega a 65 px locais: preparação de 0,32 s, 60% do dano base, empurrão de 480, recarga de 4,5 s. Depois de 0,15 s de recuperação, emenda o sopro mirando a nova posição do jogador. O F3 oferece PATADA + SOPRO e ESPECIAL: CHUVA DE FOGO para teste.

O corpo de movimento continua pequeno e não causa dano por contato. A área que recebe golpes é independente, obtida da silhueta de cada quadro e triangulada em formas convexas. Espada, lança e flechas resolvem essa área para o chefe real; um golpe de arma não duplica dano se tocar várias partes ou se o contorno mudar. A escudada considera o ponto mais próximo da silhueta. A área desaparece durante o especial e retorna no pouso. Testes/teste_acertos_dragao.gd cobre sinais e colisões reais nas quatro vistas, as quatro armas e todos os 144 quadros; teste_combo_patada.gd cobre proximidade, empurrão e combo.

O especial acontece uma vez abaixo de 50% e outra ao chegar a 10% de vida: decola, desaparece, marca 50% da arena ao redor da posição capturada do jogador, avisa por três segundos, faz três segundos de chuva com hit kill e pousa. A área marcada não segue o jogador. Ver Efeitos/dragao/LEIAME.md e Efeitos/avisos/LEIAME.md para efeitos e avisos reutilizáveis.

Arte criada/editada com image_gen integrado, sem CLI. Fontes selecionadas: fontes/movimento_v2.png, fontes/sopro_v2.png, fontes/cauda_v3.png e fontes/asas_v2.png. Os prompts correspondentes ficam em fontes/prompt_*_v2.txt e fontes/prompt_cauda_v3.txt. Conceitos anteriores foram preservados para histórico.

Regerar folhas: executar ferramentas/inimigos/preparar_dragao.gd no Godot. O importador extrai a silhueta principal conectada de cada célula, preservando sua posição e descartando fragmentos das poses vizinhas que atravessaram as divisões da fonte. Prévia renderizada dos sprites e avisos reais: ferramentas/inimigos/previa_dragao.gd. Testes: testes/teste_dragao.gd (geometria, três golpes, congelamento, morte, folhas, recorte da caminhada e rodízio) e testes/teste_debug_ondas.gd (F3, spawn, cancelamento). Executar em projeto isolado para preservar os saves da partida.
