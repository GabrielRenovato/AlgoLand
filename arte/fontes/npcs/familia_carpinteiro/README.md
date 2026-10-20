# Família do carpinteiro

Osvaldo tem 65 anos, Helena 55 e Clara 30. As fontes iniciais permanecem nesta pasta para rastreabilidade; as folhas consumidas vêm de `revisao/`. Ivo, Rosa e Lia são as referências aceitas de escala, rosto, olhos pequenos, contornos e paleta. Identidades preservadas: cabelo/barba grisalhos, camisa verde-azulada e avental marrom de Osvaldo; cabelo castanho com mechas grisalhas, blusa vinho e cadeira de Helena; trança castanha, blusa ocre, calça verde e bolsa de Clara.

Arte produzida com `image_gen` integrado. Pedidos completos em `revisao/prompts.json` e `revisao/dupla_prompt.txt`; contrato em `revisao/contrato.json`. Referências ampliadas por vizinho mais próximo, sem redesenho, também ficam em `revisao/`. A tentativa de ampliar as folhas antigas não foi integrada porque preservava as proporções e os olhos rejeitados.

`python3 ferramentas/cidade/preparar_familia_carpinteiro.py` separa a grade 7×4, normaliza a transparência e prepara quadros 64×64 com altura máxima 31 px e pés/rodas em y45. Coluna zero em repouso, seis fases de caminhada, direções baixo/direita/cima/esquerda. Não modifica os demais moradores. As cópias de chuva preservam roupa e cadeira; a agenda leva a família ao abrigo. Retratos estáticos usam recortes das cabeças corrigidas, sem simular animação de boca.

Helena permanece sentada com os braços apoiados. `codigo/cidade/apoio_helena.gd` faz a cadeira esperar Clara se aproximar e usa uma folha conjunta durante o deslocamento. Clara caminha com as mãos nos apoios traseiros; Helena não impulsiona as rodas. A filha mantém interação e identidade próprias, sem um segundo desenho sobreposto. Conversar com Clara pausa a dupla; chegada e saída restauram os atores individuais e sincronizam os trajetos. A folha conjunta tem 28 quadros 96×96, com o eixo da cadeira em (48,64); medições de encaixe em `revisao/dupla_encaixe.json`.

Casa própria a leste da ponte, com três quartos, sala e cozinha. Fachada e quintal sazonais em `arte/fontes/cidade/carpintaria/`. NPCs não recebem variantes de neve ou vegetação.

`teste_familia_carpinteiro.gd` verifica espera por ajuda, deslocamento conjunto, pausa de conversa e saída para a praça. `-- --capturar` registra a comparação com moradores existentes nas quatro direções e seis fases da dupla em cada direção. `teste_galinheiro.gd` cobre família, cadeira, acessibilidade e serviços. Sempre usar saves isolados. Comparações em `arte/previas/carpintaria/familia-comparacao-*.png` e capturas reais `familia-no-jogo-*.png`.

Recursos consumidos: `assets/npcs/cidade/osvaldo.png`, `helena.png`, `clara.png`, `clara_empurrando_helena.png`, suas folhas de chuva e os três retratos em `assets/npcs/retratos/`. A prévia animada `arte/previas/carpintaria/clara-empurrando.gif` é uma conversão de seis capturas consecutivas das poses renderizadas no Godot.
