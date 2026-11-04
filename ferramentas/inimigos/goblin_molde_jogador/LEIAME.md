# Goblin derivado do jogador

Modelo canônico: `cenas/personagem/base_3d/personagem.scn`, sem substituir a malha ou o rig; escala 0,82. Pele oliva, roupa marrom, mãos vazias. Orelhas, nariz, mandíbula, sobrancelhas, presas e argola acompanham `DEF-head`. Pivô e animações herdados do jogador.

`preparar.gd` grava a cena em `assets/inimigos/goblin_molde_jogador/goblin.scn` e exporta vistas e 12 fases de caminhada. `previa_pixel.gd` carrega a cena pronta, renderiza em 160×160 sem MSAA e aplica o shader `contorno_pixel_base_3d.gdshader`, ampliando 5× por vizinho mais próximo. Câmera ortográfica de tamanho 1,9; enquadramento fixo; fundo verde-acinzentado. Prévias em `arte/previas/inimigos/goblin_molde_jogador/`.

Executar os scripts em projeto isolado sem autoloads ou save da partida, com os recursos do repositório disponíveis em `res://`. Revisão desta alteração: frente e três quartos com o filtro renderizados e inspecionados no Godot. A caminhada não foi alterada; a geração das fases não certifica revisão do movimento. Não integrado aos mapas jogáveis.
