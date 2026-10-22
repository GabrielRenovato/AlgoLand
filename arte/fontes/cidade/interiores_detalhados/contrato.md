# Interiores pintados do AlgoLand

Referência de acabamento: `arte/fontes/cidade/enfeites_detalhados/pousada_frontal.png`.
Fontes produzidas com `image_gen`, uma chamada por recurso; pedidos específicos,
dimensões e transparência em `catalogo.json`. Complementos de café, vela e pesca
têm também seus pedidos preservados nesta pasta. A banqueta reutiliza o original
pintado já integrado à cidade.

Direção compartilhada: cenário de RPG ortográfico visto de sul e de cima,
contornos suaves e definidos, carvalho/nogueira, reboco creme, metal escuro e
tecidos discretos. Topos visíveis, sem ponto de fuga diagonal, objetos apoiados
pela base e conteúdo acomodado dentro de caixas e prateleiras. As fontes não
substituem a revisão na resolução real do jogo.

## Preparação e encaixe

`python3 ferramentas/cidade/preparar_interiores_detalhados.py` prepara os
recursos em `assets/cenario/cidade/interiores_detalhados/`. Exige todas as fontes,
lê o layout atual e produz o manifesto consumido em execução. Não altera plantas,
colisões, assentos, lugares dos moradores nem pontos de atendimento.

- Texturas4×, pivô e canvas lógicos originais. Móveis preservam a proporção dentro
  do quadro. A câmera do tampo das mesas é ajustada conservando as pernas, para
  conter os pratos servidos nas posições já usadas pela taverna.
- Tapetes usam nove faixas; o corredor repete os medalhões, sem alongar uma flor.
  Bancos alongam somente a região entre as pernas da banqueta canônica.
- Material de piso com período lógico128px e três tons por cômodo. Paredes têm
  face32px, cortes8px, trechos64px e janelas24px com margem interna4px. Nenhuma
  dimensão física da planta muda. Cortes de parede usam madeira sólida, sem
  recortes de reboco ou margem quadriculada da apresentação do original.
- Quatro estações, sempre abrigadas: exposição e luz ambiente sutis, sem neve
  sobre madeira, colchões, tecidos ou ervas. Fogo, folhas e líquidos têm quatro
  quadros de variação localizada; madeira e bases não se movem. O aquecimento
  sazonal das lareiras preserva o comportamento do layout.
- Velas ficam sobre os tampos, com luz e chama alinhadas. Na taverna, ficam
  atrás da região das travessas. Xícaras e vapor ficam acima do novo tampo.

## Consumidores

`interiores_detalhados.gd` mescla o manifesto numa cópia do item original.
`interior_casa.gd`, `sala_topdown.gd` e `DetalheAmbiente` apresentam os materiais
sem regravar `interiores.json`. A estação vem do ambiente ancestral, permitindo
mundos cooperativos distintos e prévia visual local.

`mobilia_casa_detalhada.gd` mantém os nós da casa inicial e seus pontos de uso:
aplica imagens novas como filhos dos sprites originais e conserva os retângulos
usados pela transparência de profundidade. A cama mantém oito faixas de desenho.
`cama.gd` recorta o cobertor4× em coordenadas lógicas e preserva cabeça, aparência
e respiração. Cabeças dos moradores ficam no travesseiro do colchão novo;
ajustes de pivô específicos dos personagens continuam explícitos.

A palafita usa a mesma biblioteca e equipamentos de pesca próprios. A opção
`interior_detalhado` de `mobiliario_cais.gd` ativa os móveis pintados no interior.
Na forja, `trabalho_ferreiro.gd::PONTO_IMPACTO` acompanha o tampo da bigorna:
peça aquecida, posição do Ivo e centelhas ficam alinhadas ao desenho novo.

Ao mudar medidas do layout, reexecutar o preparador e a revisão. Não voltar ao
atlas de móveis pixelados para corrigir um erro de encaixe.

## Validação e capturas

Usar projeto e saves isolados com nome iniciado por `AlgoLand testes`.
`testes/teste_interiores_detalhados.gd` cobre dez interiores, estações, canvas,
colisões, área servida das mesas, ordem das xícaras, cama em faixas e sono.
`teste_ambientes_cidade.gd` verifica também chamas, calendário e rotas.

`ferramentas/cidade/revisar_interiores.gd` captura as dez plantas em quatro
estações, sono do jogador e do Bento e uso da cadeira. Saída em
`arte/previas/cidade/interiores_detalhados/`. A opção `-- --antes` grava somente a
primeira estação em `/tmp/algoland-interiores-antes/` para comparação.
Capturas não substituem os testes de casa inicial, acessibilidade da carpintaria,
atendimento e trabalho do ferreiro.
