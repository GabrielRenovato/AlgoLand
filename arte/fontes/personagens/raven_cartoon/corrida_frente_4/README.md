# Corrida frontal cartoon — quatro quadros

Usa o corpo cartoon aprovado em `../corpo_base_cartoon_v1.png`: careca, sem equipamentos e com o short cinza neutro. Referência de movimento: Mana Seed, colunas 0/1/3/4 da linha 4 de `arte/pacotes/Jogador/Base/20.01a - Character Base 2.5c/char_a_p1/char_a_p1_0bas_humn_v01.png`. Os guias retargetados orientam os desenhos; a transferência por geração não é uma cópia exata das articulações.

Pedido final: somente frente, no máximo quatro quadros, sem salto, alternando braços e pernas opostos. O estudo anterior de seis poses com fase aérea fica descartado.

1. Apoio na perna à esquerda da tela; braço à direita avança.
2. Passagem, ainda com apoio à esquerda; braços passam pela cintura.
3. Apoio à direita; braço à esquerda avança.
4. Passagem, ainda com apoio à direita; perna à esquerda avança.

O quarto desenho foi corrigido separadamente com a ferramenta integrada de imagem; `quadro_04_corrigido_original.png` contém essa revisão. Os outros três desenhos vêm da folha original, sem redesenho. Prompts e saídas originais permanecem nesta pasta.

`ferramentas/personagem/raven_cartoon/preparar_corrida.py` empacota o ciclo, alinha pela calota da cabeça e pela sola do pé identificado como apoio e conserva uma escala comum. Só reduz a ampliação uniforme da quarta imagem corrigida para a escala da folha original. Não recorta nem redimensiona cada pose pelo próprio contorno.

Recursos: `assets/personagens/raven_cartoon/corrida_frente_4.png` e `corrida_frente_4.tres`; células512×896, pivô256/850, quatro quadros de100ms, ciclo400ms. Todos os apoios chegam ao mesmo chão. A cabeça mantém o eixo horizontal; pequenas variações do traço da geração permanecem.

Prévia independente: `ferramentas/personagem/raven_cartoon/previa_corrida_frente.tscn`. Revisão: `revisar_corrida.gd` na mesma pasta, executado com renderização gráfica e save isolado. Foram renderizadas as quatro poses e dois ciclos completos a10fps. Contatos, transições de braço, alternância e fechamento do ciclo foram conferidos pelos quadros, suas trajetórias e capturas do motor. Não houve substituição do personagem ativo do jogo.

Evidências em `arte/previas/personagens/raven_cartoon/corrida_frente_4/`: `quatro_quadros.png`, `corrida_frente_4.gif` e `corrida_frente_4_motor.gif`. O último GIF usa as capturas do Godot com os mesmos quatro quadros e tempos do recurso. Esta revisão continua disponível para avaliação visual do usuário, sem atribuir aprovação artística aos testes de reprodução.
