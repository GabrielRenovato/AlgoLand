# Corrida cartoon — outras direções

Modelo: corpo base Raven cartoon aprovado, careca e com short cinza opaco. A frente aprovada permanece preservada. Novas vistas: costas, direita e esquerda; quatro quadros a 100ms, ciclo de 400ms, sem fase aérea.

Desenhos produzidos com `image_gen` integrado. Cada direção tem sua fonte original, guia, contrato e prompt em `costas/` ou `direita/`. Correções isoladas preservam as fontes anteriores. O lado esquerdo é o espelhamento horizontal das células completas do direito. O quarto quadro das costas espelha o segundo corrigido.

Prompts usados:

- `costas/prompt.txt` e `direita/prompt.txt`: identidade, direção, quatro fases e grade.
- `costas/prompt_correcao_passagens.txt`: braços nas passagens.
- `direita/prompt_correcao_quadro3.txt`: braço oposto no terceiro quadro.
- `direita/prompt_correcao_pernas3.txt` e `prompt_correcao_pernas4.txt`: abertura do short e sobreposição das coxas para alternar a perna próxima e distante.
- `costas/prompt_correcao_pe.txt`: sola e calcanhar no pé levantado, removendo dedos vistos pela frente.
- `direita/prompt_quadro4_perna_atras_v2.txt` e `prompt_quadro4_braco_frente_v2.txt`: perna esquerda distante recuada e braço esquerdo distante à frente no último quadro; os três primeiros quadros permanecem idênticos.

Empacotamento: `python3 ferramentas/personagem/raven_cartoon/preparar_direcoes.py`. Usa uma escala comum por direção e translações pela calota e sola de apoio; não dimensiona cada pose pelo próprio contorno. Células 512×896, chão y850. A cabeça no perfil fica à frente do quadril, centro x280 para direita e espelhado para esquerda.

Recursos: `assets/personagens/raven_cartoon/corrida_{costas,direita,esquerda}_4.png` e `corrida_quatro_direcoes.tres`. Prévia independente: `ferramentas/personagem/raven_cartoon/previa_quatro_direcoes.tscn`. Não substitui o personagem ativo.

Revisão: `revisar_direcoes.gd` reproduziu dois ciclos sincronizados no Godot em projeto/save isolado. Capturas dos quatro instantes e tempos ficam em `arte/previas/personagens/raven_cartoon/corrida_direcoes_4/motor/`; GIF do motor em `quatro_direcoes_motor.gif`. Foram conferidos direção, encaixe, alternância, pés, margens e rótulos. As pequenas diferenças de traço e volume entre desenhos permanecem próprias do estudo; a avaliação artística das novas direções cabe ao usuário.
