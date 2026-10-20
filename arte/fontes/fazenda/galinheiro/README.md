# Galinheiro da fazenda

Construções e sala próprias geradas por `imagegen`, com a casa do Bento como referência de materiais, perspectiva e palha. As folhas originais ficam em `gerados/`; não são atlas do Tiny RPG. O preparador aplica recortes fixos e registra porta, tela e capacidades no manifesto.

Pedido de produção: três ampliações de galinheiro em madeira natural, pedra e palha dourada; perspectiva elevada de três quartos, linguagem Mana Seed, porta do jogador central e portinha de galinhas à direita com rampa. Escala planejada: folhas com ampliação de quatro vezes e porta lógica de aproximadamente 20 px. Fundo transparente, sem personagens, textos ou sombras soltas. Interior abrigado com piso de madeira, comedouro, feno e ninhos; circulação e saída central livres.

Variantes: verão mais seco e vegetação florida; outono com folhas quentes e palha escurecida; inverno com neve sobre telhado e superfícies expostas. Preservar os recortes e pivôs. O interior usa somente a fonte abrigada de primavera. A ampliação insere trechos de piso e parede, sem esticar móveis ou a porta.

Galinhas animadas (quadros 16×16, folha 4×7) e ícones de ovo/omelete/ração: Farm RPG - Tiny Asset Pack, cópias em `originais/`. Nenhuma construção nem tileset de celeiro desse pacote é consumido pelo galinheiro.

Reprodução: `python3 ferramentas/fazenda/preparar_galinheiro.py`. Fontes geradas preservadas; o pacote em Downloads só é necessário para renovar as cópias Tiny existentes. A folha de madeira da portinha e seu recorte durante a travessia são desenhados no motor.

## Correção do alimento e da passagem interna

`gerados/interior_vazio.png` é a edição pelo `image_gen` integrado da sala original: remover todo feno, palha e alimento, deixar os compartimentos vazios, retirar o estoque da esquerda e preservar câmera, paredes, piso, porta central, móveis e transparência. Pedido de saída: sprite lógico 192×144 com blocos de pixels definidos, sem portinha solta ou novos objetos. Fonte preservada na resolução retornada pela ferramenta; o preparador a integra na grade nativa.

Recursos consumidos: `assets/cenario/fazenda/galinheiro/interior_vazio_{1,2,3}.png`. A comida é uma região do atlas original (`interior_1.png`, recorte 42,29 de 40×5) contida no comedouro. `feno_colocado` e a quantidade restante controlam sua visibilidade e o consumo. Construir ou preparar pelo F3 deixa o comedouro vazio. Reservas antigas não são apagadas nem gastas em dobro: o depósito entrega essas porções como itens de feno para o jogador lançar no comedouro. Não há menu de cuidados.

A abertura das galinhas fica na fachada da frente, ao lado da porta principal. Na vista interna, a saída reutiliza o próprio recorte da entrada principal (48×46 px), reduzido para 24×37 px, com vão, piso, postes e soleira. Um recorte no fundo abre a parede nessa posição; não há um marcador quadrado sobre a madeira. O centro fica 40 px à direita da entrada, deixando os postes separados. As aves caminham pelo vão até a soleira. A folha interna usa tábuas simples (`codigo/fazenda/folha_portinha.gd`), sem maçaneta de porta principal e acompanha a abertura real do bando: recolhe ao abrir e fecha após a última ave voltar. Ao entrar com a portinha fechada, a folha já nasce fechada.

A portinha EXTERNA usa a madeira da própria rampa (região 134,132 de 7×10 da fachada de primavera): quando fechada, as tábuas cobrem o vão por completo; ao abrir, recolhe a folha e revela a abertura escura. A moldura e a rampa permanecem na fachada e acompanham as quatro estações. A folha de madeira sob o beiral mantém seu material; não usa a porta principal nem uma moldura redesenhada sobre a fachada.

O vão externo foi medido por modelo: níveis 1/2 em (133,117), nível 3 em (134,116), todos de 10×11 px no atlas. A tampa tem fundo opaco para impedir vazamento através da transparência do recorte. A animação e o trajeto das aves usam a posição corrigida. A regressão gráfica em `teste_galinheiro.gd` mede todos os pixels do vão e confere que a moldura/rampa não mudam nas quatro estações dos três níveis. O teste está registrado como gráfico no executor da bateria.

## Aves e cuidados diretos

`Chicken Brown Black.png` é a variante visual do galo; `Baby Chicken Yellow.png` representa pintinhos. As folhas originais Tiny RPG são preservadas em `originais/Animals/Farm/Chicken/`, com quadros 16×16 e grade 4×7. Nenhum sprite de construção Tiny é utilizado. O coração do carinho vem do ícone existente do HUD (`4 Bars/13.png`). Ovos nos ninhos e o ovo em incubação usam o ícone nativo já integrado, em escala compatível com o cenário.

O feno é `produto:feno`, selecionável na mesma barra das ferramentas. O arremesso usa o ícone nativo de alimento em uma trajetória até o comedouro, cuja camada só aparece com comida real. Depósito, ninhos, incubadora e portinha são interações locais, com descrição apenas na proximidade.
