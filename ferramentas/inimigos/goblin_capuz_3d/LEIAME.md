# Goblin de capuz — modelo estático

Referência do usuário preservada em `arte/fontes/inimigos/goblin_capuz_3d/referencia.webp`.

Geometria construída do zero em Blender: corpo robusto, cabeça esculpida por união volumétrica, nariz largo, expressão carrancuda, orelhas longas, capuz com abertura real, manto rasgado, avental, tiracolo, cintos, bolsas, ataduras e lâmina curva. Reutiliza somente funções utilitárias de geometria/material; nenhuma malha do jogador ou de outro goblin. Paleta verde-musgo e couro marrom. Frente Blender −Y, Godot +Z, chão na sola. Sem rig ou animações.

- Modelo: `assets/inimigos/goblin_capuz_3d/goblin_capuz.glb`.
- Fonte: `arte/fontes/inimigos/goblin_capuz_3d/goblin_capuz.blend`.
- Gerador: `gerar_modelo.py`, executado no Blender em background com caminho absoluto.
- Revisão: `previa_modelo.gd`, executado em projeto Godot isolado sem autoloads, renderiza três quartos, frente, perfil e costas; verifica ausência de animações e skins no GLB.
- Capturas: `arte/previas/inimigos/goblin_capuz_3d/`.

Escultura estilizada baseada na referência; não é uma reconstrução idêntica da ilustração. Materiais portáteis incorporados no GLB. Não integrado ao mapa nem perfilado para mobile. Prévia suave para avaliar o modelo; filtro pixel art pode ser revisado separadamente.

## Versão com animações Mixamo

`animar_mixamo.py` abre a fonte estática preservada, constrói rig próprio de 22 ossos e transfere os FBXs locais de `arte/fontes/personagens/base_3d/mixamo/`. Gera `goblin_capuz_animado.blend`, `goblin_capuz_animado.glb` e `animacoes_mixamo.json` com proveniência e hashes. Não requer upload ao Mixamo. A versão estática continua independente.

Clipes: `parado` (Idle), `correr` (Standard Run), `ataque_1` (Standing Melee Attack Horizontal), `ataque_2` (Standing Melee Attack Downward), `defesa` (Sword And Shield Block Idle), `ferido` (Hit Reaction), `morrer` (Dying). Fonte: Adobe Mixamo, reutilizada do catálogo local; condições já registradas em `arte/fontes/personagens/base_3d/mixamo/contrato.json`. Os movimentos de cabeça do parado são atenuados para a anatomia do goblin. Dedos mantêm a forma modelada; não recebem animação individual. Não há escudo neste modelo.

A cena `cenas/inimigos/goblin_capuz_3d.tscn` configura ciclos e inicia parado. `tocar(nome)` troca o clipe; golpes e reação retornam ao parado, morte mantém a pose final. Corrida no lugar, sem controlador de velocidade ou IA. Lâmina e cabo acompanham a mão direita. O comprimento dos membros é o do goblin; não se usa o corpo humano do Mixamo.

`revisar_mixamo.gd` renderiza todos os quadros a 30 amostras/s com o filtro do jogo e executa corrida contínua por dois ciclos em projeto isolado. O argumento `--vistas` exporta 12 fases nas quatro direções de cada clipe. `exportar_previas_mixamo.py` gera GIFs com as mesmas durações e contatos. Os GIFs repetem golpes e morte apenas para demonstração. Evidências em `arte/previas/inimigos/goblin_capuz_3d/mixamo/`. As prévias usam câmera ortográfica de tamanho 3,0 e alvo em y=0,85, comuns aos clipes para acomodar a lâmina, o salto e a queda. Cada captura verifica margens transparentes antes da ampliação. O filtro é renderização 160×160 e shader `contorno_pixel_base_3d`, ampliado por vizinho mais próximo.

Validação estrutural: `python3 ferramentas/projeto/harness.py testar --perfil selecionado --teste goblin_capuz_mixamo`. A revisão visual é independente dos testes; física, danos e sincronização da passada com deslocamento no mapa ainda não estão integrados.

## Empunhadura e estágio 4

A faca inteira recebe uma transformação rígida na pose de vínculo: cabo alinhado à mão direita, curva voltada para fora do tronco. A seleção de cortes horizontal/vertical substitui os antigos clipes de espada e escudo. `encaixar_faca.py` verifica o giro do punho na transferência; `verificar_faca.py` confere interseções da lâmina com corpo e roupas em todos os quadros dos sete clipes e grava o hash do GLB no laudo. O teste rejeita laudo de outro modelo.

O estágio 4 (`pomar`) usa 32 goblins, criados em pontos livres com afastamento da entrada e dos alvos de missão. Os atlas de `exportar_atlas.gd` compartilham texturas entre todos os atores, sem um viewport 3D por inimigo. Quadros de 160×160, grade 12×4, quatro direções, pivô projetado da origem do modelo e escala 0,4 no mapa. `goblin_pomar.gd` sincroniza aviso, impacto único (0,97 s do clipe fonte) e recuperação do corte horizontal. Percepção local, perseguição, recuo, parede, morte e reinício da população são verificados pelo perfil `goblins-pomar`; saque de equipamentos do pomar não foi acrescentado. A missão e seu guia continuam usando os alvos existentes.

## Atlas com quadros por clipe (03/11/2026)

`exportar_atlas.gd` agora gera uma grade própria por clipe (`quadros` e `colunas` em `animacoes.json`; o quadro do
Sprite2D é `direcao*quadros+q`, com `hframes=colunas`). Antes eram 12 quadros fixos (o parado rodava a 3 fps e a
reação a dano mostrava 1-2 quadros). Agora: parado 24, correr 16, ataque 24, ferido 8 (recorte de 0,6 s tocado em
0,22 s para caber no recuo) e morrer 24 (recorte de 0,6 a 3,1 s tocado em 1,4 s; o corpo fica 1 s no chão).
Custo: ~39 MB de textura (eram ~25 MB). Rodar com `flatpak run org.godotengine.Godot --path . --script
res://ferramentas/inimigos/goblin_capuz_3d/exportar_atlas.gd` (precisa de janela, não roda `--headless`).
