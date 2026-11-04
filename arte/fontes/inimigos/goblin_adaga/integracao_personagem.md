# Integração do goblin de adaga 2D

## Personagem ativo

`cenas/inimigos/goblin_pomar.tscn` e `codigo/inimigos/goblin_pomar.gd` usam os mesmos SpriteFrames revisados em `assets/inimigos/goblin_adaga/animacoes.tres`. A cena é compartilhada pelo pomar, Bacia do Moinho, dungeon da comporta e encontros de fenda; os spawners continuam usando essa cena.

- Corrida: baixo/direita/cima/esquerda, pivô(320,560), escala0,071, corpo próximo a31px. A velocidade é100px/s, alinhada ao ciclo autorado de400ms; o relógio acompanha a velocidade efetiva ao acelerar/desacelerar.
- Parado: quatro direções, usando a guarda final do combo correspondente. Esquerda espelha direita, por solicitação explícita do usuário. Poses neutras próprias anteriores ficam apenas no histórico.
- Combate disponível: quatro direções. Esquerda usa espelhamento horizontal por pedido explícito; cima usa sequência de costas com três golpes. Fontes próprias antigas da esquerda ficam fora de uso.
- Um ataque pode escolher corte único ou combo de três (chance_combo0,5 preservada). Dano nos quadros1/5/9 dos recursos; pausas adicionais200ms entre golpes. Antecipação separada0,22s com aviso, seguida pelo clipe de velocidade original. Rumo cardinal bloqueado durante o golpe; alcance, cone, parede e invulnerabilidade são consultados em cada impacto.
- Avanço de golpe limitado a6px e à distância do alvo, com colisão. Interrupção por atordoamento, gelo ou quebra de postura; golpes comuns preservam a guarda existente. Sem dano de contato.
- Guarda, corrida e golpes mantêm escala/rotação/pivô; removidas deformações e balanços extras da versão3D. Ferimento usa flash e recuo; morte congela pose, cai ao redor dos pés e desvanece, sem trocar para outro modelo. Vida44, dano4 e recarga0,9s preservados do estado de trabalho anterior à integração.
- Hurtbox ajustada ao corpo2D: cápsula de raio8/altura28, centro(0,-15); colisor físico mantém raio7, barra de vida emy=-38.

## Movimento e rede

O contorno escolhe o rumo antes da aceleração. Rotacionar a velocidade depois de mover, como no controlador anterior, travava a aceleração e produzia corrida lenta com troca constante de direção. Há histerese perto das diagonais para a direção de corrida; a direção do ataque usa o alvo e o rumo do desenho.

O nó `Texture` continua Sprite2D para os efeitos e a replicação existentes. Cada quadro é o AtlasTexture compartilhado do SpriteFrames. A cena já nasce recortada com centered=false, offset(-320,-560) e escala0,071, inclusive na réplica online onde os scripts de IA são retirados. A infraestrutura atual transmite atlas/região por hash; não foi criado um segundo sistema de rede.

## Validação

Perfil `goblins-pomar` passa a testar `goblin_adaga_animacoes` e `goblins_pomar`. Inclui quatro corridas/guardas, escala, três impactos e pausas, alcance, paredes, interrupção, morte única, distribuição de32 goblins, reentrada/saída e pose inicial da réplica online. A proteção de inicialização de `natureza_bacia_lowpoly.gd` impede a câmera de acessar telas antes de existirem durante troca de região.

Demonstração: `ferramentas/inimigos/previa_goblin_adaga_integracao.gd`, projeto e save exclusivos. Usa IA/jogador reais, move o alvo em pontos livres para as quatro direções, registra combo e morte. Quadros/instantes/estados brutos em `/tmp/algoland-adaga-integracao/`; prévias e relatório visual em `arte/previas/inimigos/goblin_adaga/`. Inspeção de quadros e trajetórias capturados; não se afirma que o visualizador estático reproduziu o GIF.

Resultado anterior à ampliação dos combos:82 verificações OK; a revisão atual está em `revisao_integracao.json`. Revisão visual do agente registrada separadamente no relatório, sem atribuir aprovação artística ao usuário. Captura real incluiu as quatro corridas, três impactos e queda/fade; réplica online validada ao nascer, sem ensaio de dois clientes. Auditoria geral conserva8 falhas anteriores fora desta integração.

## Atualização:combos completos e esquerda espelhada

Quatro combos integrados. Esquerda espelha direita por célula; desenhos exclusivos cancelados. Combo de costas usa a fonte v2 corrigida para atacar para norte, com transformação comum588px/(26,21). Guarda de costas mede31,311px. Perfil atualizado:98 verificações OK, zero falhas, estado preservado; relatório `/tmp/algoland-harness/execucao-rjv0a22q/relatorio.json`. Captura real364 quadros, quatro corridas e quatro combos com três impactos cada. Revisão visual registrada em `revisao_integracao.json`.

## Reação de dano direcional

Quatro poses por direção,300ms sem ciclo, ligadas a receber_dano. Esquerda espelha direita. Cabeça e ombros participam do recuo; reação reinicia em novo acerto, com prioridade de morte/congelamento e guarda firme preservada. Fontes/prompt/contrato em contrato_ferido.md; evidências em revisao_ferido.json. Perfil atualizado:135 verificações OK, zero falhas, save isolado e conteúdo preservado.

## Colisão com jogador

Máscara física do goblin66:mundo64+jogador2. Camada32 já é detectada pela máscara96 do player. Bloqueio bilateral nos quatro sentidos com círculos dos pés existentes, sem alterar a área atingível. Perfil:goblins-pomar,144 verificações OK,zero falhas. Captura real e relatório em revisao_colisao_player.json.
