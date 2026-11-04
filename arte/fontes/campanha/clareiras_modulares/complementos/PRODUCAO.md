# Complementos da clareira

Referência: `arte/conceitos/campanha/clareiras_chegada_v1.png`.

Folha transparente 2×2: ponte de tronco com piso caminhável NW–SE, painel de ruína com árvore esculpida, broto de raízes com seiva dourada e suprimentos de resgate (caixas, barril, manta e lanterna). Perspectiva elevada de três quartos, madeira quente, vegetação natural, detalhes nativos para desktop e espaços transparentes entre peças. Sem cenário de fundo, água, textos ou molduras.

Larguras lógicas: ponte 120, painel 85, broto 26, suprimentos 43. Pivôs na base; colisões próprias para painel, brotos e suprimentos. Ponte fica na camada de piso e compartilha corredor com a máscara de água. Recortes e medidas nativas são registrados pelo preparador em `pecas.json`.

As variantes derivam da folha de primavera preservando posição, silhueta, escala, perspectiva e alpha: verão com folhas mais escuras e menos flores; outono com folhagem âmbar e musgo verde; inverno com neve descontínua nas superfícies superiores, preservando passagem, lanterna e seiva.

Preparação: `python3 ferramentas/campanha/preparar_modulares_clareiras.py`.

Decisão de integração: as raízes despertas serão mobs. A raiz grande com seiva e os brotos desta folha não são instanciados como decoração na clareira. Os originais ficam preservados para referência, sem antecipar a implementação dos mobs.
