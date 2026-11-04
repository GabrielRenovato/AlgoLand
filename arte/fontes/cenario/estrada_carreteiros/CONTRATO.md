# Estrada dos Carreteiros — objetos v1

Folha original gerada por imagegen: 1774×887, quatro colunas sazonais e duas linhas (carreto e abrigo). Primavera, verão, outono e inverno preservam orientação, grade e função. Uso: segundo estágio, estrada de abastecimento atacada.

Referência: árvores, terra da fazenda e peças modulares aceitas das Clareiras da Chegada. Vista elevada de três quartos, luz superior esquerda, madeira quente e ferro envelhecido. Carreto com 112px de largura aparente; abrigo com 148px. Escala calculada uma vez por objeto e preservada nas estações. Quadro e pivô comuns entre variantes, definidos pelo recortador sem ajuste individual por bounding box.

Carreto: base física de 76×30px, eixo/rodas danificados, carga de mantimentos. Abrigo: frente aberta, colisões independentes apenas nos apoios, posição de conversa à frente do NPC. Objetos independentes do chão. Chão em TileMap de 16px lógicos, atlas compartilhado da clareira; nenhum fundo de mapa completo.

Integração: `codigo/campanha/estrada_carreteiros.gd`. Preparação reproduzível: `python3 ferramentas/campanha/preparar_estrada_carreteiros.py arte/fontes/cenario/estrada_carreteiros/objetos_v1.png`. Revisão: teste `estrada_carreteiros`, quatro estações, mapa geral, desktop, oclusão e passagens.
