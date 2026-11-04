# Goblin brutamontes com machado

`gerar_modelo.py` é executado no Blender em background. Produz o GLB, a fonte `.blend`, os albedos editáveis e o manifesto. A referência, o atlas de materiais gerado com a ferramenta de imagem e os prompts ficam em `arte/fontes/inimigos/goblin_machado_3d/`.

O personagem tem uma versão estática preservada e uma versão animada independente. `cenas/inimigos/goblin_machado_3d.tscn` abre o GLB animado; ainda não participa da campanha. A pintura está nos albedos de 128×128, com amostragem nearest. O comando de revisão aceita `-- --pixel` para aplicar também o filtro do jogo à prévia.

`previa_modelo.gd` importa o GLB pelo `GLTFDocument` em projeto Godot isolado, sem autoloads/saves, e captura frente, três-quartos, perfil e costas em 1000×1000. As variáveis `ALGOLAND_GOBLIN_MACHADO` e `ALGOLAND_GOBLIN_MACHADO_PREVIAS` permitem apontar os caminhos absolutos do modelo e das capturas. A opção `--pixel` acrescenta capturas frontal e três-quartos com renderização 160×160, shader de contorno/rampa do personagem e ampliação nearest para 800×800. Nenhum shader é incorporado ao GLB.

Blender e Godot estão disponíveis como Flatpaks `org.blender.Blender` e `org.godotengine.Godot`. A integração de combate é uma etapa posterior.

As mãos permanecem em duas malhas independentes no Blender/GLB. O encaixe usa a inclinação rígida compartilhada com o cabo; a cavidade das palmas é esculpida pelo volume real da empunhadura. A revisão inclui `empunhadura.png` e `empunhadura_lateral.png`, sem pós-processamento, além da prévia completa com filtro.

## Animação

`animar_modelo.py` abre a fonte estática, constrói o rig de 23 ossos, aplica pesos e adapta os movimentos locais do Mixamo e do Quaternius. Exporta `goblin_machado_animado.blend`, `goblin_machado_animado.glb` e `animacoes.json` com os arquivos de origem, hashes, durações e medidas da pegada. Não baixa animações.

Os ataques usam a rotação e a trajetória da mão do clipe de espada de duas mãos do Mixamo, com calibração do eixo da arma, ajuste ao alcance dos braços e recuperação para a pose de repouso. Machado e mãos compartilham uma transformação rígida; os braços são resolvidos por cinemática inversa e gravados a 60 fps. As prévias são renderizadas no Godot pelo `revisar_animacoes.gd`, usando o mesmo filtro pixel art.

`codigo/inimigos/goblin_machado_3d.gd` inicia o repouso, mantém os ciclos de locomoção e retorna ao repouso após ataques/reação. A morte permanece no último quadro. O método `tocar` permite selecionar os clipes. A cena não implementa IA, deslocamento físico nem dano.

A versão animada aproxima as mãos no cabo para acomodar o movimento de duas mãos. `ataque_1` e `ataque_2` usam duas cadências da mesma base `Great Sword Slash`; não são dois movimentos de origem distintos. A importação do GLB usa 60 fps para preservar a pegada durante as rotações rápidas.

As mãos são filhas do osso da arma, garantindo o vínculo durante interpolação e transições. Os braços seguem as posições de pegada por cinemática inversa gravada nos clipes. O perfil `goblin-machado` confere a hierarquia, pesos, clipes, ciclos, recuperação e erro relativo das mãos no Godot.
