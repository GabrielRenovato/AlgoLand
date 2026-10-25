# Revisão do catálogo de armaduras

Capturas de `revisar_catalogo.gd` no Godot, usando compositor Raven, quatro peças reais e save isolado. `parado_0.png` compara os dez conjuntos nas quatro direções; `no_jogo.png` mostra o Astral na fazenda. As outras folhas percorrem 16 ações. `forja-*.png` mostra nome e quatro custos em PC, celular e tela dividida.

`correr.gif` preserva os seis tempos de 100/60/140ms por passada (ciclo de 0,6s a 80px/s). O roteiro também reproduziu dois ciclos por direção dos sete novos conjuntos com o controlador real. Conferir apoio dos pés, alternância de membros, elmo acompanhando o crânio, trajetórias de ferramentas e fechamento do ciclo. Repouso: 200ms por quadro; colheita: 400/240/180/300ms. As capturas usam a mesma escala de três pixels por pixel nativo.

Validação: sete manifestos × três modos (11 páginas, corrida e ações de fazenda), sem falhas. Testes de catálogo/combate, F3/trocas/save, bônus/coberturas, padrão de armaduras, congelamento do Mordomo, bigorna, receitas/progressão e layout da forja aprovados. Logs completos em `/tmp/armadura-validar-*.log`, `/tmp/teste_*-final.log` e `/tmp/armaduras-*.log`; avisos de display headless e liberação de recursos no encerramento são mantidos nos logs.

Fontes e prompts: `arte/fontes/armaduras/<id>/`, gerados com image_gen integrada. Dados e paletas: `ferramentas/armaduras/em_preparacao/<id>/manifesto.json`. Recursos jogáveis: `assets/personagens/conjuntos/<id>/`.
