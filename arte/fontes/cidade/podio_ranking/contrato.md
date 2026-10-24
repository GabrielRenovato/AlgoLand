# Pódio do ranking

Construção da praça, referência: fonte e mural detalhados da cidade (captura /tmp/algoland-praca-ranking-detalhe.png). Perspectiva elevada de três quartos, luz superior esquerda, pedra quente e acabamentos dourados discretos.

Canvas lógico 192×72, apresentação4× (768×288), grade do terreno16×16. Exibição em128×48 lógicos (escala1/6 da arte4×), com personagens na escala nativa. Base-centro em (464,296); retângulo físico114×20 na base. Três plataformas: 2º à esquerda, 1º no centro e mais alto, 3º à direita. Centros dos pés locais: (-36,-29), (0,-38), (37,-23). Personagens Raven nativos80×80, mesma escala do jogador, sem gerar novas animações. Números e nicknames em nós independentes; não pintar personagens nem textos na arte.

Quatro estações preservam geometria, pivô e espaço caminhável. Primavera: pedra seca e florzinhas discretas na borda. Verão: pedra aquecida e poucos musgos secos. Outono: folhas esparsas nos cantos da base. Inverno: neve fina nas bordas, sem cobrir as áreas de apoio/medalhões.

Fontes/prompts aqui; recursos em assets/cenario/cidade/podio_ranking; prévias em arte/previas/cidade/podio_ranking. Conferir quatro estações no Godot, profundidade, contato dos pés, acesso à consulta e apelidos de16 caracteres, com saves isolados.

A favorita usa a pose Raven de guarda correspondente (primeiro quadro), com espada, espada de duas mãos, lança, maça, machado ou arco nas mãos. Sem contagens, usa o ciclo de repouso. Não gerar outra identidade de personagem.
