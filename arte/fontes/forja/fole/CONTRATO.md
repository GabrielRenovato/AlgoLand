# Fole da ferraria

Referência: fornalha e móveis pintados da biblioteca de interiores da vila. Madeira quente, couro sanfonado avermelhado, ferragens escuras e bico de latão. Personagem mantém a folha pixelada canônica do Ivo.

Prompt de produção: traditional blacksmith bellows, painted game prop matching warm wooden village interior tiles, expanded leather accordion between two wooden boards, operating handle on the left, hinge and brass nozzle on the right, stable short wooden feet, three-quarter top-down view, transparent background, no character, no text. Fonte: original.png, criada com imagegen.

Integração: ferramentas/cidade/preparar_fole.py recorta a transparência e prepara192×116px para48×29 unidades, escala1/4. Quatro estações mantêm exatamente grade, pivô, apoio e colisão; tons interiores mudam discretamente. Fole em360,43; bico entra diretamente no carvão inferior da fornalha, sem cano adicional. Placa inferior e pés permanecem fixos; dobradiça direita e sanfona recebem compressão no shader.

Ivo: PixelLab animate_image, job a0dcf64f-c4c4-42e6-9908-7bd170f8b232, asset23322a8c-8281-52c6-a02c-fe9fe1bf7990. Nove quadros completos64×64, pés y44 e suporte x26..34 em todos os quadros. Primeiro quadro canônico sem tenaz preparado no PixelLab pixelart_workbench, imagem b904d531-d360-4be8-a7b6-c43e77d15216. Prompt: keep exact canonical blacksmith identity and pixel palette; operate bellows lever with bare hands, stable feet and pivot, loop closes on first pose. Ordem temporal e pressão sincronizadas em trabalho_ferreiro.gd. Corpo inteiro por quadro, sem máscaras ou membros desenhados por código.

Processo: acionar fole, avivar fogo, aquecer metal com tenaz, contornar a bancada e martelar. Fornalha encostada à parede norte com fumaça na chaminé. Colisões preservam acesso lateral e passagem frontal.
