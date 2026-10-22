# Interior da loja de pesca

Referência: acabamento da pousada pintada da cidade. Fontes novas produzidas
pela ferramenta integrada `image_gen`; pedidos completos em
`pedidos_loja_pesca.json`. O piso, paredes, cama, mesa e lareira continuam na
mesma biblioteca pintada, incluindo o fogo animado.

- `loja_balcao.png`: balcão contínuo130×41 lógico, pivô(65,41), base em(160,128).
  Substitui os dois balcões genéricos; mantém a colisão130×12 e os corredores.
  Bandeja de boias e linha à esquerda, centro livre para atendimento.
  O desenho mantém sua proporção dentro do canvas: tampo em torno de y104,
  sem esconder o rosto do Nilo na posição original de trabalho(152,100).
- `loja_reparos.png`: bancada de reparos73×50, pivô(36.5,50), base(58,145).
  Molinete, vara, linha e alicate; sem ferramentas de carpintaria.
- `loja_varas.png`: expositor de parede64×45, pivô(32,45), base(164,52).
  Varas, molinetes, puçá e boias, dentro da mesma região das ferramentas antigas.
  Arte ocupa no máximo32px de altura, com pontas abaixo da viga em y20.
- `loja_tapete.png`: tapete64×32 de tecido azul discreto com peixe bordado,
  vista de cima, pivô(32,32), base(160,183), sob o jogador e sem colisão.

Texturas4×, câmera frontal elevada de sul, madeira quente e contornos suaves,
sem mudar filtros globais. Quatro estações abrigadas com mesma tela, grade,
pivô e geometria; exposição interna sutil, sem neve nos móveis.

Preparo: `python3 ferramentas/cidade/preparar_interiores_detalhados.py`.
Saída: `assets/cenario/cidade/interiores_detalhados/moveis/palafita/loja_*/`.
Integração: `codigo/pesca/interior_palafita.gd`. Cena, colisões, localização
do atendimento, catálogo, cama e rotina do Nilo permanecem nos contratos atuais.

Revisão no Godot com saves isolados: `revisar_interiores.gd -- --casa=palafita
--fogo`; capturas de quatro estações em `arte/previas/cidade/interiores_detalhados/`.
Testes: `teste_interiores_detalhados.gd`, `teste_atendimento_cidade.gd` e
`teste_rotina_praia.gd`. Conferir visualmente a emenda do balcão, altura do
Nilo, apoio dos móveis, tapete e circulação até o quarto e a saída.
