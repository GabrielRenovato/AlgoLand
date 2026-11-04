# Martelada para cima — costas

Referência: martelada_baixo_v6.png, nove quadros aceitos como base da nova direção. Mesmo Lorde, roupa, arma e estilo 2D pintado. Direção norte, costas verdadeiras, sem rosto; manto à direita da imagem, ombreira à esquerda. Golpe avança para cima da tela. Na preparação a pedra carrega atrás das costas, voltada ao observador; no ápice fica acima da cabeça; no contato atinge o chão à frente do personagem, no lado superior da imagem.

Grade3×3, células640², pivô320/500, pés emy500. Transformação única da folha exportada; não normalizar cada quadro pelo contorno. Tempos100/150/180/60/50/80/110/160/170ms,500ms adicionais somente na demonstração GIF. Conferir apoio, volume, pegada e oclusão em cada fase, reprodução isolada no Godot. Entrega como estudo de animação, sem alterar o chefe ativo nem o save. Fontes e prompt nesta pasta, GIF/folha de contato na pasta de prévias do Lorde.

## Exportação e revisão

Fonte gerada com a ferramenta de imagens integrada: `martelada_cima_gerada_v1.png` (1254²). Cada célula418² recebe a mesma transformação600² com deslocamento20/18, registrada no manifesto. Atlas `martelada_cima_v1.png` (1920²). Exportador `ferramentas/inimigos/lorde_goblin_2d/montar_cima.py`. Revisão de dois golpes no Godot com nove quadros observados, margem mínima21px e encerramento na guarda. Capturas e relatório na pasta de prévias. A testa­gem reutiliza o perfil selecionado `lorde_goblin_baixo` com `ALGOLAND_LORDE_DIRECAO=cima`; o registro do Godot identifica a direção realmente carregada. Não representa aprovação estética do usuário ou integração no combate.

## Revisão de pegada e orientação dos punhos

O usuário apontou encurtamento aparente do cabo e mãos orientadas como na vista frontal. A revisão v3 usa `cima_dorso_maos_v3.png` nos índices2/3/4, substituindo as três poses elevadas com punhos orientados para a vista traseira, dorsos e nós dos dedos aparentes, dedos envolvendo o cabo. As outras seis poses permanecem da fonte inicial. Transformação comum da correção:584² em40/-5, registrada no manifesto. Atlas atual `martelada_cima_v3.png`; GIF `martelada_cima_dorso_maos.gif`. Originais preservados. A avaliação estética continua com o usuário.

## Contato no chão entre as pernas — v5

As tentativas com pedra acima da nuca foram rejeitadas pelo usuário como flutuantes. Correção explícita: ponta/cabeça da marreta deve aparecer no vão entre as pernas, no chão. Atlas atual v5 substitui descida no índice4 e contato/absorção nos índices5/6; preserva as outras seis poses do v3. A fonte `cima_impacto_entre_pernas_v5.png` tem pedra e solas na mesma linha, madeira e mãos encobertas pelo corpo. Transformação comum aos dois impactos444² em98/100; descida470² em85/70. Tempos e pivô mantidos. Revisão isolada no Godot: nove poses em dois golpes, encerrando na guarda; arquivos de evidência na pasta de prévias.

Referências de internet solicitadas pelo usuário registradas em `REFERENCIAS_MOVIMENTO_CIMA.md`; a fotografia sequencial fornece o arco e o fim do golpe. O enquadramento entre as pernas é a adaptação solicitada pelo usuário. GIF atual `martelada_cima_impacto_chao.gif`, folha `martelada_cima_folha_impacto_chao.png`. Não equivale a aprovação estética nem integração no combate.

## Prévia com escombros e revisão de cor

Pedido posterior: dano em área no contato e escombros voando; usuário confirmou **prévia/GIF primeiro**. Portanto, nenhuma alteração no chefe ativo, saves ou dano de combate. Efeito próprio em nove quadros, ancorado no contato aos540ms, referência documentada em `REFERENCIAS_ESCOMBROS.md`. Reprodução visual em `codigo/efeitos/impacto_marreta_lorde_2d.gd`, com fim em900ms e dissipação gradual. A animação da marreta segue com nove poses e durações originais.

Os nove quadros foram comparados em escala e iluminação comuns. Corrigido o tingimento do couro e do manto por material/quadro na renderização; shader `recursos/shaders/lorde_goblin_paleta.gdshader`, ganhos e observações em `revisao_paleta_cima.json`. Mantidas sombras locais e fontes originais. Contato renderizado sem efeito permite examinar o personagem sem poeira.

Reprodução: `ALGOLAND_LORDE_DIRECAO=cima ALGOLAND_LORDE_EFEITOS=1 python3 ferramentas/projeto/harness.py testar --perfil selecionado --teste lorde_goblin_baixo`, depois `python3 ferramentas/inimigos/lorde_goblin_2d/exportar_previa_impacto.py`. GIF final `martelada_cima_escombros_cores_revisadas.gif`, amostragem30ms, pausa demonstrativa400ms. Revisão de dois golpes isolados no Godot e60 amostras da composição. Não equivale a aprovação estética do usuário.
