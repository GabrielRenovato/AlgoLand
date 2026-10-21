# Ponte da cidade

Original gerado com `image_gen`: `kit.png`, 1536×1024, RGBA.
Referências: `enfeites_detalhados/cerca.png` e `pousada_frontal.png`.

Pedido de produção: kit de ponte horizontal leste–oeste, vista ortográfica de
RPG inclinada, pintura detalhada com carvalho quente e pequenos pregos de ferro,
no acabamento das cercas e da taverna. Três componentes isolados em linhas, sem
cenário, água, texto ou sombra externa: piso de tábuas sem corrimãos; balaustrada
com quatro postes e duas travessas com vãos transparentes; viga inferior com dois
pilares e mãos francesas. Mesma largura nas três peças e espaço transparente
entre linhas. Silhuetas simples para uma ponte de 80 pixels lógicos de largura.

Preparação: `python3 ferramentas/cidade/preparar_ponte_detalhada.py`. Recortes do
original em resolução 4×; as quatro estações compartilham a mesma geometria.
Reutiliza o tratamento sazonal das cercas: madeira mais quente no verão,
escurecida no outono, musgo sazonal e neve fina apenas nas superfícies superiores
no inverno. A passagem central continua exposta.

Integração: `codigo/cidade/ponte_cidade.gd`, criada pelo layout existente em
`decoracao_vila.gd`. Âncora (676,298); piso mundial x636..716, y261..288.
Apoios em z=-996, piso em z=-995. Corrimãos têm profundidade independente pela
base e colisão na camada 64: norte y257..261, sul y288..292, largura 80.
As entradas leste/oeste permanecem abertas. A navegação lê essas mesmas formas;
não se adiciona obstáculo nos pilares abaixo do piso. Os polígonos existentes do
rio continuam impedindo a passagem fora da ponte.

As texturas seguem o calendário e a prévia de estação/F3 via `DetalheAmbiente`.
Teste gráfico com save isolado: `testes/teste_ponte_cidade.gd`. Verifica travessia
nos dois sentidos, bloqueio no centro e nas cabeceiras, profundidade, cadeira
física da Helena, navegação e as quatro variantes reais. Capturas temporárias em
`/tmp/algoland-ponte-cidade/`; revisão final preservada em
`arte/previas/cidade/ponte_detalhada/`.
