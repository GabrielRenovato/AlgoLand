# Pintura do personagem base e cabeça da referência

`referencia_v1.png` é a imagem gerada por image_gen que o usuário escolheu como
referência. `roupas_referencia_v1.png` é apenas estudo; as roupas novas ainda
não foram aplicadas. Prompts completos ficam nesta pasta.

## Corpo base aplicado

`codigo/jogador/pintura_corpo_3d.gd` aplica UVs de pele e short a
`assets/personagens/base_3d/pintura_corpo/atlas.png`, gerado com image_gen.
Não é transferência literal da imagem para a pele: usa atlas derivado.
`teste_pintura_corpo_3d.gd` confere os15586 triângulos, posições, normais,
regiões e pesos do corpo. Cabeça antiga fica recortada quando a nova está ativa.

## Cabeça refeita

`referencia_oito_direcoes_v1.png` é a folha gerada com imagegen a partir da
referência original, com correção da diagonal traseira direita. Ordem: frente,
diagonal direita, perfil direito, costas/direita, costas, costas/esquerda,
perfil esquerdo e diagonal esquerda. Uma cabeça canônica, câmera elevada20°.

O ensaio de volume reconstruído de quatro silhuetas não preservou os perfis.
O jogo agora usa os próprios desenhos das oito vistas, copiados sem alterações
para `assets/personagens/base_3d/pintura_corpo/referencia_oito_direcoes.png`.
`cabeca_referencia_3d.gd` prende o desenho ao DEF-head; o shader mantém a
perspectiva e escala diante da câmera e acompanha a inclinação do osso.
Recortes comuns370×370, escala0,0018m por pixel, âncoras e queixos medidos por
vista no script. O shader remove o fundo verde e recorta acima dos ombros:
pescoço, corpo, rig, pesos e animações continuam sendo os originais.

Pele, cabelo e olhos salvos colorem a mesma pintura, sem retornar à cabeça
antiga por causa da personalização. O cabelo Bagunçado usa esta folha;
outros penteados e elmos mantêm seus modelos próprios. Os JSONs e o gerador
de volume anteriores são fontes de ensaio, não a cabeça atualmente renderizada.

Render sem filtro de pixelização: 1280×1280 no desktop,640×640 em mobile,
sempre na mesma área80×80. A diferença para a imagem original pode incluir
amostragem, movimento e perspectiva. Não se presume aprovação do usuário.

## Revisão reproduzível

Todos os scripts exigem projeto/save isolados, conforme o mapa técnico.

- `teste_cabeca_referencia_3d.gd`: oito direções, união cabeça/pescoço por
  conectividade de alfa, olhos na frente/ausentes na nuca, sono, retorno da
  personalização e inventário. `-- --aparencias=/tmp/casos.json` reproduz
  somente os campos de aparência de saves em teste isolado.
- `revisar_low_poly.gd -- --pintura`: oito vistas comparadas e128 poses reais
  de corrida/ataque. `--amostra` captura apenas as vistas.
- `comparar_referencia_pintura.py`: referência versus captura real, incluindo
  `rosto_lado_a_lado.png`.

Prévias reais em `arte/previas/personagens/base_3d/pintura_corpo/`.

## Estudos de movimento do rosto

`referencia_movimento_corpo_v1.png`: estudo gerado de corrida (linha superior)
e golpe (inferior), para relação cabeça/pescoço/tronco. Não é folha final de
animação: a alternância de pernas da corrida ainda não constitui um ciclo.
`referencia_movimento_rosto_v1.png`: aproximação de oito poses para examinar
flexão, extensão, giro e inclinação da cabeça. As folhas são estudos, não capturas. A integração deriva as inclinações
dessas referências sem copiar a sequência de pernas do estudo.
Na integração atual, corrigidos recorte dos ombros na folha direcional e leitura
da inclinação após SkeletonModifier3D, sem afirmar reprodução destes estudos.

## Movimento integrado

`referencia_cabeca_baixa_v1.png` e `referencia_cabeca_erguida_v1.png`, geradas
com imagegen a partir da folha direcional e do estudo ampliado, cobrem as oito
direções com flexão18° e extensão12°. Cópias originais, sem redimensionamento,
em `assets/personagens/base_3d/pintura_corpo/cabeca_{baixa,erguida}.png`.
Junto da pose neutra, são24 vistas. O script mede giro/flexão/inclinação após
SkeletonModifier3D, converte Z-up para o mundo e acompanha o giro do rosto.
Na corrida,40% da inclinação do peito participa da flexão porque o clipe
original estabiliza quase totalmente a cabeça. Corpo/rig/tempos são preservados.
Shader interpola as pinturas usando marcos dos olhos registrados e apoio na
nuca: evita olhos duplicados e deslizamento da cabeça ao trocar a perspectiva.
Sono usa a pintura neutra com olhos fechados, cores salvas são mantidas.

`revisar_low_poly.gd -- --pintura` verifica256 poses de corrida/golpe nas oito
direções, variação de inclinação em cada direção e reprodução com relógio real
sem seek por quadro. `movimento_rosto.json` registra ângulos e pesos de pintura.
O exportador também aceita direções diagonais, mantendo pivô e tempos reais.

## Estudos de perfil retirados do jogo

`referencia_perfil_esquerdo_v1.png`, `perfil_corrida_v1.png` e
`perfil_golpe_v1.png` são estudos rejeitados para integração: os quadros
alteravam poses e volume corporal. Não são o modelo canônico nem animações
ativas. Suas cópias `perfil_{esquerdo,corrida,golpe}.png` não são carregadas.
O compositor de corpo inteiro e seus ajustes artificiais de mãos foram
removidos. Corpo e equipamentos voltam a acompanhar o esqueleto original
em todas as direções, inclusive no perfil esquerdo; o acabamento é aplicado
por materiais/UVs sem substituir quadros ou redimensionar poses.
