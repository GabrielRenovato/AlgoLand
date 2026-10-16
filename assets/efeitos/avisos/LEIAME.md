# Tile compartilhado de aviso de ataques

perigo.png é um tile nativo de 64 × 64, com fundo transparente e seis cores, desenhado para combinar com o pixel art do jogo. A fonte e o prompt estão em fontes/perigo_v1.png e fontes/prompt_perigo_v1.txt. Criação com image_gen integrado, sem CLI.

codigo/efeitos/aviso_ataque.gd repete esse mesmo tile com filtro nearest e o recorta por um polígono de qualquer formato. UVs em pixels do mundo preservam o tamanho do padrão sem esticá-lo. definir_area recebe o polígono real do golpe e animar controla a pulsação. Reutilizar para cones, círculos e áreas especiais sem gerar novas artes. A área do dragão e a chuva de fogo já usam esse componente.

Regerar o tile: ferramentas/efeitos/importar_tile_aviso.gd. A arte preserva o chão visível entre as marcas; a colisão continua sendo definida pela geometria do golpe, sem depender da transparência dos pixels do aviso.
