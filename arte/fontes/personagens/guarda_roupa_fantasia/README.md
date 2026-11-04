# Guarda-roupa e gerador de NPCs

Referências visuais: `referencia_roupas.png`, `referencia_cabelos.png` e a foto enviada pelo usuário em `referencia_corpete_usuario.jpg`. As duas pranchas foram geradas com imagegen; os prompts estão nesta pasta. A foto orienta a blusa creme de mangas bufantes, o corpete preto com amarração e a saia vinho longa.

## Contrato de produção

- Modelo canônico: corpo e esqueleto 3D já usados por `heroi_base_3d.gd`. Não substituir nem repintar a malha do corpo para vestir o personagem.
- Quatro categorias independentes: camisa, parte inferior, calçado e cabelo. Cada peça usa o mesmo `Skin` e caminho de esqueleto do corpo. Saia e corpete podem ser combinados separadamente.
- Novidades: sete camisas, uma saia longa e quatro cabelos. IDs e índices anteriores foram preservados no catálogo `codigo/dados/roupas_base_3d.gd`.
- Camisas novas são modeladas em `roupas_fantasia_3d.gd`; cabelos em `cabelos_fantasia_3d.gd`; saia em `visuais_femininos_3d.gd`. A pintura é um atlas próprio de cada roupa, produzido por `roupas_pixel_3d.gd`.
- Cobertura da saia longa: esconde pele das pernas/pés e o calçado enquanto está vestida. Retirar a saia restaura essas camadas, sem alterar a seleção do calçado nem a malha do corpo.
- O avental do ferreiro tem frente curva, alças sobre os ombros e cruzadas nas costas, avesso, bolso e rebites. UV2.y=8 marca a ilha de couro no espaço reservado à mão do atlas da roupa; o tronco e as mangas continuam sendo a camisa creme.
- Camisas novas usam atlas256×256; as demais peças mantêm o atlas64×64.
- Câmera ortográfica e área80×80 em pixels de mundo herdadas do personagem; direções0 sul,1 leste,2 norte,3 oeste. Corrida `mixamo/Running` de0,733333s, repetição contínua; as capturas amostram oito fases uniformes do ciclo em cada direção. O chão/pivô é o do modelo canônico.
- Malhas prontas: `assets/personagens/base_3d/pele_pixel/malhas/`. Texturas: `assets/personagens/base_3d/roupas_pixel_3d/`. O gerador `ferramentas/personagem/base_3d/gerar_guarda_roupa_npcs.gd` refaz as peças novas e o fechamento do topo do cabelo longo existente em projeto de teste isolado.
- Pivô, escala e animações permanecem os do rig canônico. Cabelos acompanham a cabeça; mangas acompanham braço/antebraço; saias usam quadril e influência reduzida das coxas. Não há simulação física de tecido.
- Estas são roupas cosméticas. Não são conjuntos de armadura nem criam itens, bônus ou mudanças de inventário. Estações não trocam automaticamente o traje de um NPC.

## Usar a oficina

Na raiz do projeto:

```bash
python3 ferramentas/personagem/abrir_oficina_npcs.py
```

A oficina usa dados isolados em `/tmp/algoland-oficina-npcs`. Permite escolher perfil e semente, combinar as quatro categorias, renomear, girar a prévia, alternar caminhada e retirar as roupas para conferir a separação do corpo. “Salvar ficha” exporta JSON. A mesma semente e perfil reproduzem a mesma ficha.

Para colocar um NPC numa cena, instanciar `cenas/npcs/npc_gerado.tscn` e configurar `perfil`, `semente` e, opcionalmente, `nome_personagem`. Uma ficha pode ser atribuída antes de adicionar o nó à árvore:

```gdscript
var npc = preload("res://cenas/npcs/npc_gerado.tscn").instantiate()
npc.ficha = preload("res://codigo/dados/gerador_npcs.gd").carregar(caminho_json)
add_child(npc)
```

`rota` recebe posições globais; patrulha exige uma malha de navegação compatível no cenário. Rota vazia mantém o NPC parado. Diálogos, missões e população definitiva da vila são integrações separadas.

## Conferência

```bash
python3 ferramentas/projeto/harness.py testar --perfil selecionado --teste gerador_npcs_3d --teste roupas_base_3d --teste tintura_cabelo_3d
```

O teste novo captura quatro vistas dos trajes e cabelos, oito fases de caminhada por direção, poses de ação e a oficina em desktop, retrato e tela dividida. Também verifica pesos, malhas independentes, preservação da geometria do corpo, fichas reproduzíveis e posição do nome acima da cabeça. As capturas precisam de revisão visual; testes aprovados não certificam qualidade artística nem aparelhos físicos.
