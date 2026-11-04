# Goblin com adaga — esquerda espelhada

Por solicitação explícita do usuário, corrida, guarda e combo da esquerda são agora o espelhamento horizontal exato da direita. As folhas próprias da esquerda e suas correções de mão estão canceladas e fora do importador; fontes antigas ficam apenas como histórico.

O importador espelha cada célula final640×640, sem inverter a ordem dos quadros. Pivô(320,560), escala0,071; corrida8 quadros/400ms; combo12 quadros/1250ms, com200ms extras entre golpes. Guarda usa o último quadro do combo espelhado. Essa decisão aceita a inversão visual da mão entre perfis.

Consumidor: SpriteFrames compartilhado pelo goblin jogável e pela cena de prévia. Teste compara os pixels de cada quadro esquerdo com o direito espelhado, além dos tempos e impactos.
