# Jornada da fenda

## Amostra desenhada no PixelLab

`cenas/fendas/amostra_caverna_pixel_manual.tscn` monta uma amostra de piso e paredes desenhados com comandos exatos `draw`/`set_node`, sem modelos geradores. O atlas256 nativo, subdividido em16, está em `assets/cenario/fendas/caverna_pixel_manual/`; a receita, paleta, ids das revisões e parecer ficam em `arte/fontes/fendas/caverna_pixel_manual/`. É uma amostra visual de uma variante, sem substituir a campanha, colisão ou navegação.

`desenhar_amostra_pixellab.py` escreve a receita e a bancada; o PNG precisa ser renderizado no `pixelart_workbench` do PixelLab. `revisar_amostra_pixellab.gd`, em execução gráfica com save isolado, salva TileSet/cena e capturas nativa/ampliada/detalhe em `arte/previas/fenda/caverna_pixel_manual/`. Revisão artística e comparação técnica dos pixels são verificações distintas.

## Bancada de encaixes de caverna

Esta versão gerada foi rejeitada visualmente pelo usuário; os testes de encaixe não a tornam referência de qualidade.

`cenas/fendas/previa_conexoes_caverna.tscn` usa uma folha desenhada para paredes, cantos internos/externos e piso, subdividida na grade16. Os módulos64 ficam registrados como padrões do TileSet em `assets/cenario/fendas/caverna_conexoes/`. A bancada combina trechos retos e reentrâncias; não interpreta setores da planta como círculos. Uma variante, conforme pedido do usuário. Cena de avaliação artística, sem colisão/navegação e sem substituir a campanha.

`preparar_conexoes_caverna.py <folha>` normaliza a ampliação da folha e monta a bancada. `avaliar_conexoes_caverna.py` mede divergências da silhueta em pares compatíveis e retorna falha acima de3px por borda64; isso não aprova estilo, repetição de piso ou transições de cor. Executar `revisar_conexoes_caverna.gd` graficamente em cópia com save isolado para salvar TileSet/cena e capturar geral/detalhe em `arte/previas/fenda/caverna_conexoes/`. Fontes, guia estrutural, prompts e pareceres em `arte/fontes/fendas/caverna_conexoes/contrato.json`; consultar o parecer antes de reutilizar.

## Recortes fiéis da caverna escolhida

A montagem do andar08 abaixo foi rejeitada visualmente pelo usuário. Reconstrução fiel da imagem fonte e testes de navegação não aprovam os recortes como conjunto modular.

`cenas/fendas/caverna_recortada.tscn` remonta o estudo `estudo_gaias_navel_v2.png` com células16, sem alterar pixels ou escala. O TileSet `assets/cenario/fendas/caverna_recortada/caverna.tres` registra20 padrões de seleção: paredes, curvas, margens, piso, água, escada, entrada e trechos completos. Selecionar o TileMapLayer `Caverna` no editor para usar os padrões.

São recortes para montagem manual, com o contexto da ilustração; não são autotiles que resolvem qualquer encontro entre formas novas. Não há colisão ou navegação nessa cena de arte. Não substituir a campanha por essa prévia.

Preparação: `python3 ferramentas/fendas/preparar_recortes_caverna.py`; executar `construir_recortes_caverna.gd` em cópia de teste para salvar TileSet/padrões/cena. `revisar_recortes_caverna.gd` exige execução gráfica com save isolado e captura a remontagem e a bancada em `arte/previas/fenda/caverna_recortada/`. `python3 testes/teste_recortes_caverna.py` compara todos os pixels remontados e os limites dos padrões. Contrato e recortes PNG nativos em `arte/fontes/fendas/caverna_recortada/`.

### Planta08 com esses recortes

`cenas/fendas/previa_caverna_08.tscn` é uma prévia independente: conserva os dez setores, doze trilhas e posições da entrada/guardião de `andar_08.json`, usando apenas blocos16 intactos do atlas escolhido. A seleção considera contorno e junções, excluindo pedaços de escadas; não deforma nem recolore as peças. Não substitui a Floresta ao Luar na campanha. Uma versão apenas, conforme solicitado.

`montar_caverna_08_recortes.py` exige Python com numpy/Pillow e gera a composição; `construir_caverna_08_recortes.gd` salva a cena, colisões e navegação com bake de faixas unidas. `revisar_caverna_08_recortes.gd` confere rotas completas para todas as salas e centros livres, em save isolado com renderização gráfica; capturas `andar_08_geral_godot.png` e `andar_08_detalhe_godot.png`. Os TileMapLayers dessas prévias têm material explícito para conservar as cores, sem aplicar o acabamento automático do cenário.

As onze plantas canônicas ficam em `codigo/fendas/plantas/andar_01.json` até `andar_11.json`. O primeiro andar é curto; os seguintes ampliam o percurso e a meta. Depois do11, repetem-se2–11 com atributos crescentes. Entrada, setores, grupos e guardião são definidos na planta; receitas, mineração, inventário, recordes e cooperativo preservam o contrato das ondas.

- `python3 ferramentas/fendas/gerar_jornada.py --plantas`: diagramas dos dez andares seguintes.
- `python3 ferramentas/fendas/gerar_jornada.py --andar N`: regenera um terreno e sua cena, com as quatro estações.
- Sem `--andar`, o gerador atualiza a jornada toda.
- `renderizar_jornada.gd -- --andares=1,2,3,4,5,7,8,11`: capturas reais no Godot, quatro estações e detalhe. Exige projeto com saves isolados e renderização gráfica.
- F3 → ANDARES → PROXIMO ANDAR: troca pelo fluxo real, preservando vida/ouro e sem premiar o combate pulado; ignora clique duplicado durante a transição.

## Gentle Forest

`gentle_forest.py` integra as três paletas fornecidas: andar1 claro(v01), andares2/5 selva(v02) e andar8 ao luar(v03). Fontes originais e contrato em `arte/fontes/fendas/gentle_forest/`.

A grade é16px; árvores80×96 mantêm pivô(40,95) e escala1. Grama, trilhas, cantos internos/externos, margens de água, penhascos completos, plantas, troncos, tocos e raízes vêm do pacote. As quatro estações adaptam vegetação e cobertura de neve, preservando geometria, materiais de madeira/pedra e a identidade da paleta. Árvores e demais materiais seguem o calendário e a prévia do F3.

`gentle_sazonal.gd` troca o atlas compartilhado de árvores e conserva os três quadros nativos da animação da água. `Estacoes.brilhos_personalizados` impede que reaplicar a estação atual restaure o brilho de outro pacote. A arena original continua usando os recursos padrão.

## RPGW Caves

`rpgw_caves.py` usa as folhas completas `MainLev2.0.png` e `decorative.png` fornecidas pelo usuário. Fontes, licença e coordenadas dos recortes ficam em `arte/fontes/fendas/rpgw_caves/`. As cavernas3/4/7/11 e o desfiladeiro9 usam peças32px subdivididas em quatro células16px, sem ampliar ou reduzir a arte.

A escolha minimiza as quatro costuras entre peças, com ajuste conjunto de pares de quinas. A faixa de acabamento inclui a primeira célula do chão para fechar as curvas nativas. A transparência das peças originais orienta o chão, o contorno físico e a navegação; os objetos sólidos têm colisão na base. Pisos variam entre terra, pedra escura, material azulado alagado e musgo. O atlas base é opaco para impedir faixas do terreno antigo aparecendo sob o desenho. Água fica em camada própria, com margem recortada pelo campo de distância. O subterrâneo bloqueia precipitação e usa quatro reflexos sazonais discretos.

Nenhum andar usa o atlas Wang antigo nem os objetos das ilustrações geradas. Os dezesseis recortes completos de `decorative.png` estão registrados em `objetos_completos.json`, sem redução e sem fatiar silhuetas. As fontes antigas ficam arquivadas, sem referências nas cenas. Os andares6/10 usam chão natural; o calçamento e os muros foram retirados.

## Conferência

### Prévia modular de caverna SNES

`cenas/fendas/gruta_nascente.tscn` é uma cena independente de revisão, sem substituir os andares. Usa atlas nativo16 e peças Wang32, colisão e navegação; versão única por pedido do usuário. Proveniência da adaptação de Secret of Mana, referências e prompts em `arte/fontes/fendas/gruta_nascente/tiles/manifesto.json`.

`python3 ferramentas/fendas/preparar_gruta_nascente.py` prepara atlas/planta; executar `construir_gruta_nascente.gd` em cópia isolada salva a cena. `revisar_gruta_nascente.gd` exige renderização gráfica e save isolado, valida colisões/rota e captura geral/detalhe em `arte/previas/fenda/gruta_nascente/`. `python3 testes/teste_gruta_nascente.py` confere os128 pares de margens compatíveis pixel a pixel.

`teste_jornada_fendas.gd` valida os onze mapas, população, metas, rotas de três classes, colisão do jogador, guardião, troca real e avanço pelo F3. Nos mapas Gentle confere também paleta, árvores nas quatro estações e animação de três quadros.

`teste_recortes_fendas.py` rejeita costuras retas de piso/parede maiores que8px nos cinco mapas RPGW e confere a silhueta inteira das plantas Gentle nas quatro estações.

`teste_andar_fenda.gd` cobre combate, melhorias, coop e retorno. `teste_continuidade_caverna.gd` compara a junção do andar4 e a margem do andar7 com referências gráficas revisadas. `teste_margens_caverna.py` rejeita alteração sazonal do contorno de água e transparência no atlas base RPGW. Atualizar referências somente após revisão da captura real no motor.

Usar `ferramentas/projeto/testar_tudo.py` para saves e capturas isolados. A arena anterior permanece em `cenas/cenario.tscn` e `cenas/terreno.tscn`.

## Colisões dos andares

`colisoes_andares.py` reconstrói as bases depois de finalizar a composição. Água e ilhas mantêm seus contornos; arbustos removidos não deixam obstáculos. Nas florestas o limite fica48px dentro da mata, com bases próprias nos troncos da primeira fileira. Nos mapas naturais6/10 toda a grama entre salas é caminhável, com mata fechando o perímetro externo. Troncos caídos, tocos e formações minerais usam a envoltória dos pixels sólidos nos10px inferiores do sprite, com pivô(32,60). Plantas baixas e detalhes transitáveis não bloqueiam. As quatro estações conservam a geometria.

Ao aparecer ou ser extraído um veio, `mineracao_fenda.gd` solicita uma atualização de `navegacao_fenda.gd`: as três classes passam a contornar sua colisão física e o espaço reabre após a extração. Não há bake por quadro nem alteração na navegação da arena original.

`teste_colisoes_andares.gd` verifica os onze mapas com o corpo real do jogador: contato em quatro direções, rotas para todas as salas, paredes fechadas e estabilidade sazonal. `revisar_colisoes_andares.gd` renderiza detalhes nas quatro estações com as bases em verde e os limites em laranja, para revisão visual no Godot com save isolado.

`mineracao_fenda.gd` distribui veios pelo mapa inteiro, em posições navegáveis, longe de jogadores, mobs, guardião e entrada. Preserva a progressão6/9/12... e o rendimento da arena. `teste_materiais_andares.gd` verifica mineração real e os drops físicos de fragmento, núcleo e receita nos guardiões dos andares6/9.

## Encontros e dificuldade

Os manifestos de combate reservam5–8 comuns por grupo, além dos elites:16 inimigos no primeiro andar até125 no11. Comuns valem3 pontos e elites9; a meta cresce de41 a364 e exige76–90% dos pontos disponíveis, preservando sobra para não exigir caçar o último mob. A distribuição usa candidatos locais em grade28px com distância mínima22px, dentro de110px do marcador; entrada protegida por140px.

`patrulha_andar.gd` movimenta cada inimigo móvel em rotas locais de45–115px, com55% da velocidade de combate, pausas curtas e animação original. Destinos precisam de rota válida na classe do corpo; corredores longos não viram atalhos de patrulha. Espécies enraizadas continuam como emboscadas. `gerenciador_andar.gd` verifica alerta a cada0,2s: visada livre até175px ou dano acordam o grupo próximo, sem perseguição global desde a entrada. A IA normal assume a perseguição, ataques e separação após o alerta.

`teste_patrulhas_andares.gd` cobre população, proporção da barra, deslocamento físico em180 quadros e alerta de grupo nos andares1/3/10. A publicação síncrona das iterações de navegação na entrada do mapa evita que encontros e patrulhas consultem uma malha antiga; não há rebuild a cada quadro.

## Guia após a vitória

`gerenciador_andar.gd` preserva recompensas e revive o parceiro como antes; depois instancia Orion perto do jogador, em área navegável e livre. A interação normal de NPC abre melhorias e as escolhas de seguir ou voltar. `guia_andar.gd` usa a mesma base de moradores (corpo31px, célula64px, pés44) com perfil próprio e cajado em pixels. A saída do andar remove o guia. `teste_andar_fenda.gd` verifica que o menu aguarda a conversa.

`previa_guia.gd` captura o ator junto ao jogador; `revisar_entregas.gd` registra a Medusa e as ferramentas da bigorna em PC/mobile. Executar com renderização gráfica e save isolado.
