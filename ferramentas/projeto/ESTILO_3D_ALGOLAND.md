# Estilo 3D do AlgoLand — versão 1

Este guia define uma linguagem visual reutilizável para produzir cenário, objetos, personagens e criaturas 3D coerentes no AlgoLand. A assinatura do jogo é **volume 3D com superfícies pintadas como pixel art**. Ele complementa as regras de personagens e pixel art; não substitui os requisitos de animação, estações ou revisão no Godot.

## Assinatura visual

- **3D pintado como pixel art:** a malha fornece volume e silhueta; texturas pintadas fornecem a aparência dos materiais, luz e sombra em agrupamentos de pixels nítidos. Evitar superfícies apenas lisas com cor uniforme, texturas fotográficas e detalhe fino demais para a escala do jogo.
- **Câmera do mundo:** ortográfica, elevada e frontal, sem giro horizontal (yaw). A direção de frente do jogo permanece consistente entre peças. Uma peça pode girar para caber no mapa, sem mudar a câmera compartilhada.
- **Grade:** módulo visual de 16 px. Dimensões, pivôs, encaixes e colisões devem respeitar a grade ou declarar claramente a exceção.
- **Pintura e materiais:** foscos, com cores quentes e naturais. Pintar variação de madeira, pedra, tecido, pele e metal com bordas pixeladas controladas e faixas de valor que separam forma, frente, topo e sombra. Evitar brilho plástico, metal espelhado, ruído e degradês que desaparecem quando reduzidos.
- **Luz:** iluminação ampla e suave, luz principal quente e preenchimento frio discreto. A luz real completa a pintura sem substituí-la; sombras não escondem a silhueta nem escurecem o piso.
- **Acabamento:** arestas simples e intencionais, detalhes maiores que a resolução final e proporções consistentes com os personagens. Manter irregularidade artesanal moderada; evitar aparência industrial genérica.
- **Renderização:** quando o recurso for 3D em mapa 2D, renderizar em `SubViewport` transparente e ampliar com filtro nearest-neighbor. Definir âncora pelo contato com o chão e profundidade pelo ponto de apoio, não pelo centro da imagem.

## Forma de cada família

- **Cenário e objetos:** usar malhas low-poly com UVs e texturas de pixel art pintadas para o material. Dividir peças grandes em componentes reutilizáveis e manter colisão separada da arte.
- **Personagens e criaturas:** preservar silhueta reconhecível em oito direções, proporções e pivôs compatíveis com o sistema de animação. A paleta e a luz seguem o guia; a geometria deve continuar adequada ao rig, à deformação e à leitura dos quadros.
- **Construções e máquinas:** combinar módulos repetíveis com uma silhueta própria. Partes móveis devem ter pivô e movimento definidos, sem fundir a parte animada à malha estática.
- **Itens e ícones 3D:** uma forma principal, contorno de valor claro e detalhe só onde ajuda a identificar o item na dimensão de uso.

## Estações e identidade

Todo recurso de cenário sazonal deve preservar forma, escala e leitura nas quatro estações. Preferir materiais/cores sazonais e adições pequenas e reversíveis (por exemplo, geada nas bordas), sem cobrir o caminho ou a silhueta. Personagens e equipamentos só mudam de estação quando a ficha do recurso pedir.

## Fluxo de criação

1. Definir função no jogo, dimensões, pivô, câmera, colisão e as quatro variantes quando aplicável.
2. Gerar uma referência visual da peça e inspecioná-la antes da modelagem; guardar referência, prompt e metadados junto ao recurso.
3. Modelar componentes reutilizáveis, aplicar pintura pixel art compatível com os UVs e evitar microdetalhes que não sobrevivem ao tamanho final.
4. Integrar no sistema existente de profundidade, animação, colisão e estações, sem embutir esses comportamentos numa imagem.
5. Revisar no Godot em escala real e em aproximação, sobre o mapa e fundo de jogo. Corrigir contorno, contato com o chão, leitura, margens e sobreposições antes de considerar a peça pronta.

## Referência de implementação

A ponte da Bacia do Moinho e a pintura do moinho 3D aplicam esse padrão ao estágio 4. As referências e prompts da ponte estão em `arte/fontes/campanha/bacia_moinho/pontes_3d/`; as pinturas sazonais da ponte e do moinho usam materiais de superfície em pixel art com filtro nearest.

Ao criar um novo recurso, usar este guia como base e acrescentar decisões específicas ao manifesto da peça. Variações estilísticas podem existir por região ou família, desde que mantenham câmera, pintura pixel art, escala de leitura, acabamento fosco e identidade de paleta.
