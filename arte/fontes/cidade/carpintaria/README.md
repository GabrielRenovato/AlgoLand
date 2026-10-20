# Casa e quintal do carpinteiro

Arte própria criada com a ferramenta `image_gen` integrada. Fontes preservadas e recursos consumidos separados; não há chamadas à API/CLI.

## Pedido da fachada

Referência visual: `assets/cenario/cidade/casas/exterior/casa_bento.png`, comparada ao cenário real da vila. Casa maior de madeira e reboco para três pessoas, com oficina anexa à direita, telhado quente, chaminé, janelas residenciais e entrada larga. Perspectiva elevada de três quartos, paleta natural Mana Seed, grupos de pixels definidos, sem cenário, personagens, textos ou sombras soltas. Folha 1536×1024 em 2×2 células de 768×512, representando sprites lógicos 192×128 ampliados quatro vezes. Porta ancorada em (80,116) em todas as células. Primavera com folhas/flores discretas, verão mais seco, outono âmbar e inverno com neve nas superfícies expostas; arquitetura e pivôs preservados.

Revisão do acesso: substituir apenas os pequenos degraus da entrada por uma rampa de madeira larga e contínua, sem espelhos de degraus, preservando posições, dimensões e a geometria sazonal. Neve nas bordas, passagem utilizável limpa. A fonte anterior fica preservada separadamente quando substituída.

Integração: `python3 ferramentas/cidade/preparar_carpintaria.py`; recortes fixos, redução inteira por vizinho mais próximo e normalização do canal alfa. Nenhuma pintura ou alteração criativa pelo preparador. O manifesto registra dimensões, pivô e colisões; quatro PNGs efetivamente usados por `DetalheAmbiente` e `casa_exterior.gd`. A máscara solar deriva somente da transparência do sprite.

## Mapa ilustrado

`mapa_expandido.png` foi gerado por edição do mapa original `assets/ui/mapa_mundi/algoland.png`, com a nova fachada como referência. Pedido: ampliar a carta para proporção 2:1, conservar fazenda, prédios, fonte, rio, ponte, praia e píer da vila e acrescentar à direita o bairro da família. Casa junto à extremidade leste da ponte, caminho de pedra contínuo, cercado com portão largo, galinhas bicando e abrigo à direita. Continuar floresta e costa; sem textos, marcadores, legenda ou duplicação de prédios. A ilustração final retornou em 1776×888 e é consumida nessa resolução, sem deformação. Marcadores e projeções foram medidos nela em `dados_mapa_mundi.gd`.

## Terreno e interior

A cidade passa a 1024×576, sem deslocar os prédios existentes. Casa na base (816,224), cercado em (736,304,192,120), portão entre x800 e x864 e abrigo em (888,344). A revisão aproxima a implantação da carta ilustrada: casa e quintal junto à margem leste, rua horizontal contínua, acesso curto ao portão aberto, flores nas bordas e floresta imediatamente ao sul. A margem à esquerda da casa recebe árvore, arbusto e canteiro nativos, sem bloquear a ponte ou o acesso à rampa. As flores de borda recolhem no inverno. As folhas abertas do portão reutilizam as peças verticais sazonais da cerca, com colisão correspondente e vão central livre. Calçamento reutiliza bordas/cantos da cidade e cercas/vegetação/abrigo mantêm as quatro estações nativas. Não são bens nem aves do jogador.

Planta interior reproduzível: `ferramentas/cidade/layout_carpintaria.py`, consumida pelo gerador compartilhado de interiores. Três quartos independentes com cama própria; sala com área de trabalho; cozinha equipada; corredores e vãos largos para a cadeira. Os móveis e tiles existentes da cidade mantêm materiais e variantes sazonais do ambiente abrigado.

Verificação: `teste_casa_carpinteiro.gd` usa saves isolados, percorre a ponte e todos os cômodos com a colisão real da cadeira, verifica entrada/saída individual em coop, abrigo das aves, quatro fachadas/cercas e marcadores. Com `-- --capturar`, grava as quatro visões gerais, quintal em escala de jogo, interior inteiro e carta atualizada em `arte/previas/carpintaria/` do projeto isolado.

## Arquivos consumidos

- Fachada-base: `assets/cenario/cidade/casas/exterior/carpintaria.png`.
- Fachadas sazonais: `assets/cenario/cidade/ambientes/fachada/carpintaria/{primavera,verao,outono,inverno}.png`.
- Carta ilustrada: `assets/ui/mapa_mundi/algoland.png`.
- Máscara de sombra: `assets/cenario/cidade/sombras/casas/carpintaria.png`.
- Capturas finais no motor: `arte/previas/carpintaria/`.

Revisão de cercas e visibilidade: a cerca de contorno antiga termina antes do rio; o terreno da família usa somente o cercado fechado com portão. As copas completas ficam fora do pasto com margem mínima de 12 px, verificada pelo gerador e pelo teste de cena. A fileira sul começa visualmente depois da cerca, deixando aves e abrigo expostos. Todos os acessos às casas têm meia largura de 24 px e centro alinhado à grade de 16 px, garantindo ao menos dois tiles úteis. O portão tem a mesma largura; a rua leste termina reta em x960, com acabamento nativo, sem ponta estreita.
