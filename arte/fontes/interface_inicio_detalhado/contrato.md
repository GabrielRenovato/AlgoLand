# Tela inicial detalhada

Uso: `codigo/ui/tela_inicial.gd` e `codigo/ui/tela_criacao_personagem.gd`, sem alterar os temas compartilhados.

Referência: fachadas e madeira pintadas da vila atual, comparadas com a captura real do menu anterior. Paleta de nogueira, carvalho quente, pergaminho marfim, verde musgo e latão discreto. Vista frontal ortográfica, sem perspectiva ou elementos de cenário.

Original gerado pelo imagegen: `atlas_original.png`, copiado integralmente para `assets/ui/inicio_detalhado/atlas.png`. Folha quadrada de 1254×1254, quatro regiões de 627×627. Ordem: painel escuro, pergaminho, botão verde, madeira clara. A geração solicitou grade 2×2, centros vazios e discretos, bordas retas contínuas e cantos contidos na moldura, sem letras, ícones ou folhagens.

Integração: nove partes com cantos de64px, renderizadas em escala1/8 pelo `estilo_inicio_detalhado.gd`; margens lógicas14px nos painéis e10px laterais/2px verticais nos botões. Camada visual fora do cálculo de tamanho dos containers. Estados de foco, hover, pressão e desabilitado preservam o controle nativo e suas medidas. Filtro linear exclusivo do acabamento; o fundo sazonal e os personagens são preservados. Interface sem variantes sazonais próprias.

Tipografia: fontes pixeladas existentes Planes ValMore e CraftPix Survival Kit, conforme a preferência do usuário. Título em25px no PC e18px no layout compacto.

Revisão: `testes/teste_inicio_detalhado.gd` com save isolado; cinco resoluções, opções, créditos e coop. `--antes` diferencia a captura anterior; `--com-save` confere CONTINUAR. Capturas em `/tmp/algoland-inicio-*.png`.

Criação de personagem: o mesmo atlas é reutilizado nos painéis, botões, campo de nome e miniaturas. Molduras de botões e miniaturas usam escala1/16 para deixar área útil livre. O catálogo usa páginas e ocupa a largura disponível; nenhum ScrollContainer participa da tela. Em retrato os painéis são empilhados e nas telas baixas ficam lado a lado, com controles menores. A prévia mantém os sprites existentes e gira somente pelas setas. O teste `teste_criacao_detalhada.gd` verifica cinco resoluções, seleção/paginação, margens, setas, ausência de rolagem/giro automático e confirmação das escolhas em arquivo isolado.
