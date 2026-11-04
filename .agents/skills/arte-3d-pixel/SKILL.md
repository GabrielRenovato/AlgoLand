---
name: arte-3d-pixel
description: Cria e adapta recursos do AlgoLand em 3D pintado como pixel art, incluindo modelos, materiais, texturas, cenários, objetos e personagens. Use ao definir ou aplicar a identidade visual 3D do jogo.
---

# Arte 3D pintada como pixel art

Ajude a manter uma identidade visual única no AlgoLand: **formas e volume em 3D, com superfícies pintadas em pixel art**. O resultado não deve parecer um modelo 3D genérico com cor lisa, uma textura fotográfica ou uma ilustração plana fingindo ser geometria.

## Antes de criar ou alterar arte

- Leia `ferramentas/projeto/REGRAS_VISUAIS.md` e `ferramentas/projeto/ESTILO_3D_ALGOLAND.md`.
- Para personagens, animações, armaduras, TileMaps ou cenários, use também a skill visual correspondente disponível no ambiente. Preserve contratos de rig, pivô, estações, terreno modular e revisão no Godot.
- Confira recursos existentes da mesma família para combinar paleta, escala e acabamento.
- Para objeto de cenário 3D novo, produza e inspecione uma referência específica antes de modelar. Guarde imagem, prompt e metadados junto ao modelo.

## Direção visual

- Modele volume tridimensional verdadeiro, com silhueta clara, planos simples e peças reutilizáveis.
- Pinte as superfícies com texturas de pixel art: agrupamentos de pixels nítidos, bordas controladas, sombras e luz pintadas em faixas de valor, variação artesanal de cor e detalhes que sobrevivam à escala final. A textura deve acompanhar a forma e o material (madeira, pedra, tecido, pele, metal), sem ruído fino.
- Preserve a câmera e a escala da família. Para recursos de mapa 2D, siga a câmera ortográfica elevada do projeto, o módulo de 16 px, âncora no contato com o chão e filtro nearest-neighbor. Não aplique yaw diferente sem motivo visual do projeto.
- Use materiais foscos e paleta natural coerente com o AlgoLand. A luz pode dar volume, mas não deve substituir a pintura pixel art das superfícies.
- Renderize detalhes para leitura na dimensão real do jogo; confira também em aproximação para revisar UVs, textura, costuras, normais e contato entre peças.
- Em cenário sazonal, mantenha forma e leitura nas quatro estações; adapte as texturas e acrescente efeitos discretos sem cobrir a silhueta nem a passagem.
- Separe arte, animação, profundidade e colisão quando o sistema permitir. Não transforme uma ilustração inteira do mapa em um objeto/grade de tiles.

## Aplicação e revisão

1. Entenda a função, a família, as dimensões, a câmera, o pivô, a colisão, as animações e as estações exigidas.
2. Faça uma referência visual e escolha materiais/texturas pixel art antes de completar a malha.
3. Implemente o recurso no sistema existente, registrando dimensões, origem da referência, prompt e variantes no manifesto próprio.
4. Revise a renderização real no Godot, em escala de jogo e em detalhe, com o mapa/fundo correto. Corrija silhueta, pintura, encaixes, âncora, margens e sobreposições antes de concluir.
5. Informe o que foi integrado e o que foi visualmente conferido; não chame de final uma peça que só foi validada por código.

Para criação de sprites ou texturas bitmap, use a ferramenta de imagem disponível e as instruções da skill de imagem. A malha e a integração devem continuar como recursos próprios do projeto.
