# Peças do mapa regional

Montagem: `codigo/campanha/montagem_mapa_tiles.gd`. Layout: `layout_mapa_tiles.json`.

- `assets/ui/campanha/tiles/locais_sazonais.png`: atlas RGBA 1536×1024, quatro colunas (moinho, mina, observatório, bastião), quatro linhas sazonais. Gerado com imagegen; original `exec-f9f85d3c-73be-4e66-a727-d68aaffbbb5b.png`.
- `assets/ui/campanha/tiles/paredoes_sazonais.png`: atlas RGBA 1254×1254, quatro colunas (duas variantes de parede, pé vazado, topo com vegetação), quatro linhas sazonais. Gerado com imagegen; original `exec-ff3b52ea-06d7-4cb3-9dac-745dd7b2e06f.png`. Recortes fracionários com margem interna evitam as linhas divisórias do atlas.
- Casas, árvores, pedras, portal e solos reutilizam os recursos sazonais existentes do AlgoLand.
- A cachoeira reutiliza o atlas de oito quadros em `regiao_camadas/cachoeira.png`, reorganizado pelo Godot em peças de topo, corpo e base.
- Água e encaixes do solo são atlas gerados pelo Godot; os quadros de água são animações nativas do TileSet. Nenhuma pintura completa serve de piso.

Escala: célula lógica 16 px; célula de textura 64 px. Este mapa é a seleção de regiões, sem alteração das colisões dos cenários jogáveis.
