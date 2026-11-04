# Prévias de impacto — baixo e direita

As três direções existentes agora possuem a prévia com escombros e revisão de cores. Esta etapa acrescenta baixo e direita; a direção cima foi preservada.

## Fontes e movimento

- Baixo: `martelada_baixo_v6.png`, nove quadros; contato no índice5 aos540ms, ponto320/530 da célula640².
- Direita: `martelada_folha_escolhida_usuario.png`, oito quadros aprovados pelo usuário, sem redesenho ou deformação. Recorte da grade4×2 e deslocamento comum98/70 em células640²; atlas `martelada_direita_escolhida_atlas.png`. Contato no índice4 aos480ms, ponto486/497. Não usar a versão de pegada fechada rejeitada.
- Escombros: mesmo atlas de nove fases já revisado para cima, com ponto da ruptura coincidente com o martelo no chão em cada direção. Lançamento, subida, queda e dissipação. Referências em `REFERENCIAS_ESCOMBROS.md`.
- Paleta: medidas de couro e manto comparadas ao primeiro quadro de cada direção, ganhos moderados na renderização, fontes originais intactas. Valores e evidência em `revisao_paleta_baixo.json` e `revisao_paleta_direita.json`. Cores da pele e sombras locais mantidas; a correção não é uma troca de identidade ou de desenho.

## Reprodução

1. `python3 ferramentas/inimigos/lorde_goblin_2d/preparar_previas_direcionais.py`
2. Para cada direção baixo/direita: `ALGOLAND_LORDE_DIRECAO=DIRECAO ALGOLAND_LORDE_EFEITOS=1 python3 ferramentas/projeto/harness.py testar --perfil selecionado --teste lorde_goblin_baixo --forcar`
3. `python3 ferramentas/inimigos/lorde_goblin_2d/exportar_previa_impacto.py DIRECAO`

O parâmetro `--forcar` é necessário ao trocar a direção por variável de ambiente, pois a chave do harness não inclui essas variáveis. Não reutilizar o resultado de baixo para direita. Cada renderização revisou dois golpes e60 amostras de efeito a30ms. GIF2200ms com400ms de pausa demonstrativa. Relatórios e contatos por direção na pasta de prévias.

## Escopo

O usuário escolheu prévia/GIF primeiro. Dano em área no combate ainda não foi ligado. O chefe ativo e os saves permanecem fora desta etapa. O contrato futuro é dano uma única vez no evento de contato, com escombros apenas visuais. A revisão não presume aprovação estética do usuário.
