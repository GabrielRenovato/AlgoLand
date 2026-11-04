# Movimentos femininos dos NPCs

Fonte real: **Human Basic Motions FREE Godot/Unreal**, Kevin Iglesias, obtido gratuitamente em https://kevdev.itch.io/basic-motions-free em 30/10/2026. Caminhada `HumanF@Walk01_Forward`, descanso `HumanF@Idle01` e conversa `HumanF@Talk01`. São movimentos dos FBX originais transferidos para o rig canônico com o importador de rotações globais usado no projeto. O estudo procedural inicial foi substituído.

A biblioteca consumida pelo jogo é `assets/personagens/base_3d/movimentos_npcs.res`. Não altera corpo, roupas, animações nativas nem o personagem do jogador. `movimento: feminino` é um campo explícito da ficha de NPC; a oficina permite escolher o estilo sem trocar a roupa. Os moradores neutros conservam sua caminhada. A biblioteca carrega somente três clipes, com poses reamostradas a 30 Hz, e guarda a autoria e a origem por clipe.

Os clipes têm 0,8 s / 2,7 s / 2,2667 s. A cadência na rua usa distância efetivamente percorrida e passada medida no rig chibi, para preservar o apoio dos pés. A prévia de oficina usa os tempos originais dos clipes. Durante uma conversa a NPC para de andar, faz os gestos do clipe importado e retoma o passeio ao fechar o diálogo.

`contrato.json` guarda a licença resumida, hash do ZIP e caminhos. A página oficial do autor com os termos está preservada em `pagina_autor_2026-10-30.html`. O ZIP/FBX original está no cache local de produção em `/tmp/algoland-human-basic-free.zip` e `/tmp/algoland-human-basic-free/`. Não são incluídos no pacote do jogo como assets avulsos.

Para reimportar, baixar a versão Godot/Unreal pela página oficial e passar a pasta `Animations/Female` para `ferramentas/personagem/base_3d/gerar_movimentos_npcs.gd -- --fonte=<pasta>` em projeto isolado. O Godot precisa ter acesso à pasta fonte, inclusive quando roda via Flatpak. Validar com `harness.py testar --perfil selecionado --teste movimentos_npcs --teste gerador_npcs_3d --teste moradores_primeira_raiz`. `exportar_movimentos_npcs.py <capturas-movimentos-npcs>` monta os GIFs e folhas de contato dos mesmos quadros e tempos revisados no motor.
