# Cavaleiro de Aço cartoon

Prévia cosmética no F3: PERSONAGEM → CARTOON: CAVALEIRO DE ACO. Sem cadastro de itens, atributos, bônus ou drops.

As dez folhas em `animacoes_originais/` são a arte aprovada. O compilador preserva os quatro desenhos de cada folha, inclusive os elmos de cada pose. Aplica somente uma escala global da folha para a resolução do atlas, sem deslocar peças, substituir capacetes ou copiar o terceiro quadro para o quarto. As referências aprovadas de ataque frontal e costas estão em `referencias_aprovadas/`.

Quatro peças independentes: elmo, peitoral/ombreiras, luvas/manoplas e botas/grevas. Cada peça tem onze páginas; a corrida esquerda é o espelho exato de cada célula da direita. Ataques à esquerda espelham no motor. Células: 512×896 na corrida, 640×896 em repouso/ataques; pivôs e filtro iguais aos do corpo. Golpes: 160/60/70/200 ms. Corrida acompanha a distância física.

`conjunto_cartoon.gd`, invocado com `--cartoon` pelo gerador e pelo validador compartilhados, lê o manifesto em `ferramentas/armaduras/em_preparacao/cavaleiro_aco_cartoon/manifesto.json`. `marcacoes_animacoes.json` e `base_elmo` orientam somente a separação das quatro peças: não alteram os pixels da arte. A recomposição das peças deve ser idêntica à fonte normalizada em todos os pixels; hashes protegem as fontes de armadura e de corpo.

O rosto é extraído do corpo original numa camada `rosto/`, atrás das quatro peças. `encaixes_rosto.json` registra as aberturas dos elmos de cada quadro. Só o rosto é ajustado e recortado para essas aberturas. No segundo golpe de perfil, o recorte da cabeça de origem exclui as mãos. O elmo original cobre as bordas; o peitoral não apaga o rosto. As antigas projeções de `elmo_canonico/` não são usadas.

`cobertura/` oculta o corpo por peça equipada. O rosto acompanha o bit do elmo. `completo/` contém só o equipamento original, sem corpo; `composicoes/` nas prévias contém rosto mais armadura para inspeção. Runtime: `assets/personagens/raven_cartoon/armaduras/cavaleiro_aco/`.

Teste gráfico: `teste_cartoon_fazenda.gd -- --armadura --capturar --tela-inteira`, exclusivamente em projeto/save isolado. A gravação completa fica em `arte/previas/personagens/raven_cartoon/no_jogo/gravacao.json`. O exportador recusa gravações incompletas. Ferramentas e outras ações ainda usam o fallback Raven existente.
