# Prévia de movimento — duas poses

Pedido final: somente dois quadros por direção, com alternância das pernas e braços opostos, como referência de simplicidade Mana Seed. Sem fases intermediárias. A corrida anterior de seis quadros foi descartada.

Aparência: conceito_v1.png do estudo da cidade. Ferramenta de desenho: image_gen integrado, com guias de articulação; PixelLab continua sem gerações disponíveis. As fontes e os prompts foram preservados.

Frente e costas têm dois desenhos próprios em duas_poses_frente_costas.png. Direita usa os dois apoios corrigidos de apoios_opostos_v2.png; esquerda espelha essa lateral. A chapa do capacete funciona como marco horizontal constante para compensar a deriva de posição da geração. A escala e a linha de chão são comuns aos dois quadros de cada direção; não há recorte pelo contorno de cada pose. Parâmetros completos em duas_poses.json.

Prévia no Godot: ferramentas/armaduras/previa_carrasco_duas_poses.gd, em projeto e save AlgoLand testes. O script reproduz AnimatedSprite2D com dois quadros de 150 ms, captura as mesmas poses e mostra representações de revisão na cidade. A apresentação ativa dos equipamentos não foi alterada.

Resultados em arte/previas/armaduras/carrasco/estudo_cidade/: corrida_duas_poses.gif (exatamente dois quadros, 150 ms cada), folha_duas_poses.png (duas colunas, quatro direções) e capturas da cidade. GIF usa paleta comum e os quadros renderizados pelo motor.

Limite: é estudo animado da aparência, ainda em imagens compostas de corpo inteiro. Não é a entrega final das quatro peças nas onze páginas, nem foi conectada aos itens ou aos ataques. Não reduzir a prévia para a célula do personagem e chamá-la de conjunto pronto.

## Apoio lateral adicional

Pedido posterior: um desenho extra com os dois pés no chão somente nas laterais. Manifesto `apoio_lateral.json`: passo A (100 ms), apoio (50 ms), passo B (100 ms), mesmo apoio (50 ms). Frente e costas mantêm dois desenhos de 150 ms. O ciclo de 300 ms foi preservado. Fonte `apoio_lateral.png` gerada com os dois apoios e conceito como referências; normalização de resolução uniforme pelo capacete, documentada no manifesto. Resultado: `corrida_apoio_lateral.gif`.
