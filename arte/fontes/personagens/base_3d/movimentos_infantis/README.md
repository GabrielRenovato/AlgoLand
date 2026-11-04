# Movimentos infantis na Primeira Raiz

Fonte: [Schoolkid — Gobkit Free Character Pack Vol. 1](https://gobkit.itch.io/gobkit-free-character-pack-vol-1), licença CC0 1.0 declarada pelo autor. Original e SHA256 em `fonte.json`. Nenhum modelo, textura ou roupa externa substitui nosso personagem.

- `baixar_movimentos_infantis.py` baixa o GLB oficial e expande accessors esparsos para compatibilidade com o Godot, sem alterar valores de animação.
- `gerar_movimentos_infantis.gd`, executado com projeto/save isolado, transfere `Walk` e `Idle` ao rig canônico a 30 Hz. Mantém rotações por repouso global e deslocamento vertical proporcional. A pose base dos braços é abaixada em 0,8 rad para encaixar no manequim, preservando a oscilação da fonte.
- A caminhada tem 1,0333333 s e o descanso 2,0333333 s. Biblioteca `assets/personagens/base_3d/movimentos_infantis.res` com metadados de origem, licença e passada medida: 7,930568 px/ciclo no corpo infantil. NPCs usam distância real percorrida para avançar o ciclo.
- Câmera ortográfica, quatro direções do jogo, SubViewport160×160; mesmo pivô do personagem adulto, escala corporal infantil0,8 e proporções próprias. Roupas e cabelos são malhas independentes do guarda-roupa infantil existente.
- Revisão: 12 fases por direção e por criança, preservando a caixa comum; contato/passagem e fechamento do ciclo nos quadros do Godot. A mesma sequência gera o GIF. Conferidos rostos, mãos, roupas, linha dos pés e diálogo nos três formatos suportados.
- `testes/teste_moradores_primeira_raiz.gd` verifica três identidades infantis, rotas de todas as atividades, pausa/retomada da agenda, recolhimento noturno, conversa contextual e reencontro sem duplicar a população.

Rotinas locais no percurso experimental: ajuda07h, descobertas10h, brincadeira14h, retorno18h e recolhimento20h. A integração não sincroniza agendas pela rede nem altera o save de produção.

## Encaixe da nuca

O material infantil conserva a base posterior da cabeça e a pele do pescoço sob o cabelo separado (`preservar_nuca`). O deslocamento vertical infantil da cabeça é -0,04 m em relação ao repouso para fechar a junção. O material e o deslocamento dos adultos permanecem com seus padrões. A revisão está em `arte/previas/npcs/criancas_primeira_raiz/correcao_nuca`; o teste de vestuário rejeita linhas transparentes entre cabeça e tronco nas vistas de costas.
