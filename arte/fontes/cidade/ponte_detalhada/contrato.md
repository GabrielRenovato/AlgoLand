# Ponte da cidade

Original atual gerado com `image_gen`: `kit_margens_estacas.png`, 1536×1024,
RGBA. Pedido completo em `prompt_margens_estacas.txt`. Referências: o material
`chao_detalhado/pedra.png` e os arredores da ponte na captura da cidade.
O primeiro `kit.png` foi rejeitado pelo usuário: madeira alaranjada, piso estreito
e apoios curtos com sapatas. É uma fonte histórica e não alimenta o preparador.

Direção atual: tablado amplo, madeira envelhecida de tom neutro, entradas
niveladas de pedra e corrimãos leves. Duas estacas longas e maciças, sem sapatas,
entram diretamente na água. Piso, corrimão e estrutura inferior são componentes
separados, com vãos transparentes e mãos francesas abaixo do piso.

Preparação: `python3 ferramentas/cidade/preparar_ponte_detalhada.py`. Recortes do
original em resolução 4×; as quatro estações compartilham a mesma geometria.
O piso tem 320×176, corrimãos 320×48 e apoios 152×120 pixels. As estacas são
ajustadas para espessura lógica de 4,5 pixels, preservando viga e diagonais.
As cabeceiras continuam o material real da rua com período lógico de 128 pixels,
na mesma fase mundial e estação, evitando pedras esticadas ou outra paginação.
Reutiliza o tratamento sazonal das cercas nas partes expostas; madeira e algas
imersas ficam frias no inverno, sem neve branca sob a água. A passagem fica livre.

Integração: `codigo/cidade/ponte_cidade.gd`, criada pelo layout existente em
`decoracao_vila.gd`. Âncora (676,298); piso mundial x636..716, y252..292.
Apoios em z=-991, piso em z=-989: os tufos das margens (-990) ficam sob o piso,
sem atravessá-lo. Corrimãos têm profundidade independente pela base e colisão na
camada 64: norte y248..252, sul y292..296, largura 80. A abertura do rio corresponde
à largura real da travessia, em `terreno_vila.py` e `cenas/cidade.tscn`.
As entradas leste/oeste permanecem abertas. A navegação lê essas mesmas formas;
não se adiciona obstáculo nos pilares abaixo do piso. Os polígonos existentes do
rio continuam impedindo a passagem fora da ponte. A estrutura inferior começa
em (656,75;292) e tem 38×30 pixels lógicos, com as estacas alinhadas aos dois
postes internos do corrimão. `geometria.json` registra a interseção da
água com as duas estacas a partir dos pixels reais do sprite. `contato_estacas.gd`
desenha pequenas ondas abaixo da madeira (z=-992); somente as pontas submersas
têm transparência gradual. Não há blocos de pedra flutuando sob os pilares.

As texturas seguem o calendário e a prévia de estação/F3 via `DetalheAmbiente`.
Teste gráfico com save isolado: `testes/teste_ponte_cidade.gd`. Verifica travessia
nos dois sentidos em três faixas, bloqueio no centro e nas cabeceiras, profundidade,
cadeira física da Helena, navegação, contato real das estacas com o rio, ausência
de grama sobre o piso e material/fase das cabeceiras nas quatro variantes.
Capturas temporárias em
`/tmp/algoland-ponte-cidade/`; revisão final preservada em
`arte/previas/cidade/ponte_detalhada/`.
