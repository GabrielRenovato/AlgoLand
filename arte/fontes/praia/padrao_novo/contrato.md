# Praia no padrão pintado da vila

Fontes produzidas pela ferramenta integrada `image_gen`, com a pousada como
referência de acabamento. Pedidos completos em `pedidos.json`,
`pedido_estrela_mar.json` e `pedido_palafita.json`. Fontes antigas não são
referências de acabamento; fornecem somente geometria, base e porta.

## Geometria e contato

- Grade existente16×16. Texturas4× com filtro local, sem mudar o filtro global.
- CoqueiroA: canvas65×88, raiz física em(+6,0). CoqueiroB:63×84,
  raiz em(-18,0). Uma escala por fonte e uma âncora por árvore; a copa cabe
  inteira sem mover as colisões12×8. Sombras sazonais usam a mesma silhueta e
  encontram a raiz, sem deslocamento arbitrário.
- Rochas33×24, madeira24×15, capim25×20, estrela16×16. Detalhes baixos não
  criam obstáculos; as bases das rochas conservam25×12.
- Banco44×26 com área de sentar e saída existentes. A arte é um filho4×;
  o nó de interação conserva escala1 e alcance original. Vasos16×22.
- Canteiros reaproveitam a fonte da praça. Bancada61×44 e suporte45×46
  reaproveitam os móveis pintados da palafita, com bases e interação externas.
- Casa do Nilo: canvas160×160, desenho em(8,8,144,120), soleira(80,128).
  Origem da cena(464,224), porta e colisões existentes preservadas.
- Areia e madeira com período128px e fase mundial. Pedra e grama reutilizam
  os materiais da cidade, recortados pelas bordas, cantos e junções da orla.
- Vigas, estacas e cabeços reaproveitam o kit pintado da ponte. Estacas descem
 29px até a água. Piso cobre os apoios; máscara exclui todas as células do
  cais. Ondulações de contato aparecem na linha de imersão, abaixo da madeira.

## Estações e consumidores

As quatro estações mantêm os mesmos canvases, pivôs, bases e colisões.
Coqueiros continuam perenes: tons de exposição, sem folhas laranjas ou queda
artificial. Neve fica nos apoios expostos de rochas, vasos, móveis e telhado;
madeira submersa e areia da arrebentação não recebem cobertura branca uniforme.
O calendário do ambiente ancestral também funciona em mundos cooperativos.

`python3 ferramentas/pesca/preparar_praia_detalhada.py` prepara
`assets/cenario/praia/detalhada/`. `arte_praia.gd`, `decoracao_praia.gd`,
`mobiliario_cais.gd`, `praia.gd` e os renderizadores do cais usam o manifesto.
As árvores da cidade e da orla carregam diretamente
`assets/cenario/fazenda/natureza_detalhada/{estacao}/{carvalho,pinheiro}.png`;
regenerar o atlas antigo não muda essa escolha.

## Revisão

Saves sempre isolados com nome iniciado por `AlgoLand testes`.
`teste_praia_detalhada.gd` cobre fontes, estações, raízes, sombras, geometria e
alcance dos bancos. `teste_praia.gd` cobre colisão, sentar/levantar, catálogo,
pesca e viagens no cooperativo; o relógio de P1 rege os ambientes de P2.
`teste_rotina_praia.gd` cobre agenda, visita, retorno e sono do Nilo.

`ferramentas/pesca/revisar_praia_detalhada.gd` captura cidade e praia nas quatro
estações e banco ocupado. `-- --antes` grava em `/tmp/algoland-praia-antes/`.
Capturas finais ficam em `arte/previas/praia/padrao_novo/`. Inspecionar visão
geral, detalhe dos apoios, porta e assento; testes não aprovam a arte.
