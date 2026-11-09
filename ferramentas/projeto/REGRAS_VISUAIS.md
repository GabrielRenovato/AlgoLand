# Regras de arte e cenários do AlgoLand

O estilo (assinatura, paletas, ícones, ilustrações, arte gerada por IA e checklist de aprovação) está no [guia de arte](GUIA_ARTE.md). Conferir toda arte nova contra ele antes de colocá-la em `assets/`.

## Acabamento obrigatório antes da entrega

- Nunca entregar como pronto um recurso incompleto, feio ou com defeitos visíveis. Comparar o resultado com a referência, conferir no Godot e corrigir os problemas antes da entrega. Uma prévia continua sendo uma prévia até passar por essa revisão.
- Portais, cavernas e túneis devem mostrar profundidade: paredes internas, teto e piso/escadaria coerentes, com escurecimento progressivo. O fundo escuro deve ficar contido no interior; retângulos vazando pela silhueta e manchas uniformes cobrindo o vão inteiro reprovam a entrega.
- Conferir a imagem completa e o detalhe na escala do jogo. Para defeitos recorrentes, manter uma verificação automática pertinente; nunca usar aprovação funcional para justificar acabamento ruim.

## Referências antes da modelagem 3D
- A projeção das construções e mecanismos deve seguir a vista frontal elevada do cenário existente: câmera ortográfica sem rotação lateral por padrão, vigas horizontais e pilares verticais. A elevação mostra o topo dos objetos; não converter a composição para uma vista isométrica ou girar peças na diagonal sem referência local e solicitação explícita. As vistas frontais das referências orientam o enquadramento no mapa.
- Antes de criar ou refazer um modelo 3D de cenário, gerar imagens de referência específicas da peça. A modelagem começa somente depois dessas imagens existirem e terem sido inspecionadas; se o usuário pedir aprovação prévia, aguardar essa aprovação.
- Mostrar a peça inteira em perspectiva de jogo e vistas complementares suficientes para entender sua construção. Definir escala em relação ao jogador, silhueta, materiais, paleta, apoios, encaixes, peças móveis e seus pivôs. Mecanismos devem mostrar como o movimento é transmitido e quais partes permanecem fixas.
- Guardar referências e prompts em `arte/fontes/`, vinculados ao modelo correspondente. Usar o moinho como referência de materiais quando pertinente. Imagens rejeitadas não são referências aprovadas.
- Comparar o modelo com as referências e revisar a renderização real no Godot, nas quatro estações e na escala do jogo. Para o visual 3D com filtro pixel art, aplicar a redução de resolução após renderizar geometria, iluminação e efeitos; manter interface legível em sua resolução própria.

Ler antes de trabalhar com personagens, animações, armaduras, arte ou cenários, inclusive quando a alteração estiver em código.

## Produção de Personagens e Animações
- Ao criar ou corrigir corpos base, sprites de personagens, caminhada, corrida, ataques, mineração, corte de árvores, roupas ou cabelos animados, aplicar a skill [produzir-sprites-animados](/var/home/alfeim/.codex/skills/produzir-sprites-animados/SKILL.md), junto da revisão de pixel art quando pertinente.
- Produzir com os recursos disponíveis, inclusive do zero; não depender da compra de pacotes. Fixar um modelo canônico e revisar identidade, direção, proporções, apoio dos pés, alternância dos membros, trajetória das mãos/ferramentas, pivô e fechamento do ciclo antes da entrega.
- Folha gerada, redimensionamento, GIF exportado e testes funcionais não comprovam qualidade da animação. Inspecionar os quadros, o movimento com as durações reais e a reprodução no Godot em save isolado; corrigir defeitos visíveis antes de apresentar como concluído.

## Conjuntos de Armadura
- Antes de criar ou alterar um conjunto, ler [o padrão de armaduras](ferramentas/armaduras/PADRAO.md).
- Usar o manifesto, o gerador e o validador compartilhados em ferramentas/armaduras. O Carrasco é a referência funcional.
- Preservar ids e índices existentes, quatro peças independentes, 11 páginas, encaixe sem roupa vazando e a separação entre prévia cosmética e itens reais.
- Testes que carregam a arena ou gravam inventário devem usar saves isolados, sem alterar a partida do usuário.

## TileMaps, Encaixes e Sobreposição Visual

- Grama volumétrica deve passar à frente da base de pedras, troncos, postes, cercas e demais objetos apoiados no gramado. Respeitar o contorno de contato com o chão, inclusive bases estreitas, rasas, circulares e poligonais; não deixar o objeto inteiro desenhado sobre todas as lâminas. Preservar o volume acima da base, as fachadas, os pisos e os acessos. Conferir esse contato no Godot na escala do jogo, com um objeto pequeno e uma estrutura larga.
- Todo tile ou sprite de cenário novo deve ser entregue com versões de **primavera, verão, outono e inverno**, integradas à troca de estação do jogo. Conferir as quatro no motor, preservando grade, pivôs, colisões e estilo. Não considerar o trabalho completo com apenas a primavera ou arquivos sazonais sem uso no mapa; objetos que não mudam fisicamente ainda precisam de tratamento visual coerente com cada estação.
- Piso de pedra em mapas externos deve ter **bordas, cantos e junções no padrão da cidade**, incluindo transições para areia, grama e outros pisos. Reutilizar o sistema de acabamento da cidade quando compatível; não deixar o preenchimento retangular sem arremate nas extremidades. Conferir também nas quatro estações.
- Em tarefas de arte, sprites, props e TileMaps, aplicar a skill [revisao-visual-pixel-art](/var/home/alfeim/.codex/skills/revisao-visual-pixel-art/SKILL.md) e ler seu [perfil específico do AlgoLand](/var/home/alfeim/.codex/skills/revisao-visual-pixel-art/references/algoland.md) antes de gerar. Definir referência, dimensões, grade, pivô, base física, variantes e integração no pedido; comparar com referências aceitas no cenário. Resolução, origem do pacote e testes funcionais não comprovam qualidade artística.
- Ao criar ou alterar `TileMap`, `TileMapLayer`, TileSets ou elementos ligados a eles, **sempre conferir a renderização real no Godot antes de concluir**. Inspecionar a visão geral e os detalhes em escala de pixel, especialmente cantos, junções, bordas e transições entre chão, água e construções.
- Conferir a ordem efetiva das camadas, incluindo `z_index`, `z_as_relative`, hierarquia e ordenação por profundidade. Pilares e vigas ficam sob o piso; corrimãos, personagens e objetos ficam na profundidade apropriada. Sombras e reflexos também não podem invadir superfícies indevidas. Usar máscara/recorte quando a ordem das camadas não garantir o encaixe.
- Verificar atlas, regiões de textura, offsets, pivôs, escala, filtros e espaçamento dos tiles: sem peças duplicadas, frestas, vazamento de tiles vizinhos, apoios atravessando o piso ou objetos parecendo flutuar.
- Em cercas e corrimãos, conferir separadamente os trechos horizontais e verticais: bases sobre o piso, ligações contínuas entre postes e cantos conectados, preservando entradas e aberturas de uso.
- Conferir se colisões e navegação correspondem ao desenho e preservam passagens e áreas caminháveis. Elementos apenas visuais não devem criar obstáculos acidentais.
- Testes funcionais aprovados **não substituem a inspeção visual**. Para regressões recorrentes de sobreposição, adicionar comparação de renderização ou outra verificação automática pertinente, além de revisar a imagem final. Capturas e testes de cenas devem usar saves isolados.


## Água: animação por quadros obrigatória

- Produzir a água como sprites animados, quadro a quadro, em atlas reutilizável ou `SpriteFrames`. Cada quadro deve representar uma etapa real do movimento de ondas, correnteza, espuma e reflexos. Apenas deslocar uma textura estática por UV ou variar sua cor não atende a esta regra.
- Definir antes da produção: dimensões nativas de cada quadro, grade do atlas, quantidade e ordem dos quadros, FPS ou duração individual, sentido da corrente e duração do ciclo. Manter enquadramento, escala e registro idênticos entre quadros; escolher a quantidade conforme o movimento, sem impor um número fixo a toda água.
- Revisar o movimento quadro a quadro e na velocidade final, incluindo a passagem do último ao primeiro. Evitar saltos, flashes, mudança de volume, ruído que troca aleatoriamente e reflexos que parecem objetos sólidos se movendo.
- Conferir o encaixe entre tiles em todos os quadros, inclusive bordas opostas, curvas, cantos e junções. Usar um relógio compartilhado para tiles vizinhos; variações de fase só podem ser usadas quando preservarem essas junções. A seleção de quadros pode ocorrer por shader, desde que reproduza quadros discretos do atlas.
- Separar superfície animada, margens, espuma de contato, objetos e colisões. A animação não desloca a margem nem altera navegação ou colisão a cada quadro. Cachoeiras, água parada e correntezas precisam de movimentos próprios quando presentes.
- Entregar primavera, verão, outono e inverno com a mesma grade e encaixes. Preservar boa definição na escala real de desktop e compartilhar atlas e materiais entre tiles.
- Guardar a ficha da animação e uma folha de contato com todos os quadros. Revisar ao menos dois ciclos completos no Godot em save isolado, além dos encaixes e das quatro estações. Uma captura estática não comprova a qualidade do movimento. Registrar no relatório do harness as evidências e qualquer pendência; não declarar a regra atendida enquanto houver apenas água estática ou UV contínuo.

## Mapas jogáveis: montagem modular obrigatória

- Analisar a referência aprovada inteira antes de produzir: terreno, água, margens, caminhos, relevo, vegetação, construções, acessos e pontos de história. A imagem aprovada orienta composição e estilo; não deve virar um pôster de fundo recortado em uma grade.
- Produzir tiles reutilizáveis de terreno com bordas, cantos e junções, e objetos independentes para árvores, pedras, troncos, raízes e ruínas. Cada objeto precisa de pivô, base física, profundidade e variantes sazonais; copas não devem virar colisões que bloqueiam o caminho inteiro.
- Chão, água, objetos, colisões, navegação e interações devem permanecer editáveis separadamente. Remover um tronco ou árvore deve revelar chão verdadeiro, sem deixar a mesma peça pintada no fundo. Alterar um trecho de solo deve atualizar apenas os tiles e as transições locais pertinentes.
- Reutilizar atlas, materiais e texturas entre instâncias; evitar texturas de mapa completo e um tile único por posição para simular modularidade. Qualidade para desktop exige densidade real de pixels na escala de jogo, preservação de silhuetas e revisão em 1080p e 1440p; ampliar o arquivo não acrescenta detalhe. Medir o custo da montagem antes de afirmar que ficou mais leve.
- Para cenários novos ou convertidos, executar `python3 ferramentas/projeto/harness.py testar --perfil mapas-modulares` e os perfis de gameplay afetados. O perfil cobre atualmente a clareira; ampliar o conjunto quando outro cenário adotar o contrato. Inspecionar as capturas das quatro estações, visão geral, detalhe de desktop, transições, oclusão, colisões e passagens.
- A aprovação automática comprova estrutura e alterações independentes; a semelhança com a referência e o acabamento continuam exigindo revisão visual real no Godot.
