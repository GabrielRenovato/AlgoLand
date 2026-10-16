# Medusa — chefe da onda 20

Chefe original inspirado na referência enviada pelo usuário, compatível com a arte Mana Seed usada no jogo. Serpentes no cabelo, unhas longas, uma única cauda, sem arco. As cinco folhas de movimento/ataques têm 6×4 quadros de 256 pixels, renderizados a 0,5. Ordem no jogo: frente, costas, direita, esquerda.

Ataques normais: garras em cone curto, varrida circular de cauda e bote em linha reta. A IA usa bote para fechar distância, alterna garras/cauda perto e continua perseguindo quando há obstáculos. Sem dano por contato. Os avisos usam o tile compartilhado e a mesma geometria do impacto; obstáculos bloqueiam ataques, e o bote testa o segmento percorrido para não atravessar o jogador sem acertar.

Especial ativo: Ruína da Górgona, uma vez ao cruzar 50% de vida e outra aos 10%. Marca um círculo de raio 180 no local do jogador, com 2,5 segundos para sair. Um círculo verde nasce nos olhos da Medusa, cresce e assenta na área indicada; a luz é verde e não há feixe. No impacto, permanecer na área causa petrificação fatal: 0,65 segundo de pedra, 0,5 segundo de desintegração e hit kill, independente de defesa, invulnerabilidade, esquiva dentro da área ou reviver. Apenas escapar da área evita o especial fatal. O corpo fica substituído por cascalho no chão e é restaurado ao iniciar uma nova partida.

A variante de olhar em cone e petrificação temporária permanece para verificação do componente, mas não entra na escolha automática da IA. O ciclo da luta usa três ataques normais (garras, cauda e bote) e o especial fatal nos dois limiares.

Onda 20 (e 70 no rodízio), preservando Minotauro 10 e Dragão 50. F3 → MEDUSA permite ir à onda e forçar os quatro ataques.

Arte criada na ferramenta integrada de geração de imagens; fontes, referência e prompts em `arte/fontes/inimigos/medusa/` e `arte/fontes/efeitos/medusa/`. Fontes corrigidas `_v2.png` têm prioridade; o bote frontal e de costas usa a correção `bote_frente_costas_v3.png`. Preparação pelo Godot: `ferramentas/inimigos/preparar_medusa.gd` e `ferramentas/efeitos/importar_efeitos_medusa.gd`. Sem redução de paleta nem filtros de suavização. Sete efeitos separados em `assets/efeitos/medusa/`, incluindo `ruina.png` e `cascalho.png`.

Testes: `testes/teste_medusa.gd` cobre IA, geometria, dano sem repetição, petrificação/esquiva/saída do cone, recuperação, conservação dos equipamentos e rodízio. Rodar exclusivamente com saves isolados. `testes/teste_eventos_chefes.gd` mantém a cobertura geral do rodízio e das habilidades existentes.

Prévias em `arte/previas/inimigos/medusa/`, geradas por `ferramentas/inimigos/previa_medusa.gd`. A captura da arena e do jogador petrificado está em `arte/previas/inimigos/medusa/jogo/`.

O especial fatal completo é renderizado por `ferramentas/inimigos/previa_ruina_medusa.gd` na arena isolada. As capturas e `especial_fatal.gif` ficam em `arte/previas/inimigos/medusa/ruina/`; `exportar_previas_medusa.py` exporta os GIFs. A ruína usa quadros de 256 pixels para manter nitidez na área grande; os demais efeitos usam 128. O círculo e os avisos têm a mesma extensão real, e o olho é medido na pose para ancorar a origem da invocação.
