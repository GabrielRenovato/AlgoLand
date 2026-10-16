# Base refinada do jogador

A base padrão usa as poses nativas com paleta uniforme, contornos contrastantes e transições internas de pele em resolução dupla. São 11 páginas, com 8×8 quadros de 128×128 pixels, exibidos em escala 0,5. O tamanho no mundo, os índices das poses e o tempo das animações continuam definidos pelas cenas existentes.

`ferramentas/personagem/preparar_corpo_refinado.gd` conserva a posição de cada pixel do molde, incluindo olhos e mãos. O sombreado adicional atua somente entre tons de pele; não modifica olhos, contorno ou transparência. `validar_corpo_refinado.py` compara os 704 quadros com os moldes e verifica manchas na pele e preservação dos olhos/contornos. As camadas de roupa, cabelo, armas e quatro peças de armadura usam seus cadastros atuais.

Fontes e prompts gerados por IA ficam preservados em `arte/fontes/personagens/refinado/` como referências, mas não são mais recortados sobre as poses: a revisão encontrou inconsistências anatômicas e de cor nesse processo. O arquivo `manifesto.json` registra as páginas, seus moldes e a versão do acabamento. Renderização nearest, transparência binária e sem mipmaps. Os protótipos anteriores continuam acessíveis pelo F3.

Os sete cabelos também usam células de 128×128 em escala 0,5, nas onze páginas. `preparar_cabelos_refinados.gd` gera as 77 folhas em `cabelos/`, com contornos escuros, tons neutros para personalização e luz/sombra seguindo as mechas nativas. O prendedor do coque mantém suas cores. `validar_cabelos_refinados.py` verifica cobertura, transparência e contornos em 4.928 quadros.

No jogo, `Aparencia.aplicar_cabelo` aplica a textura refinada e a escala correspondente. `Aparencia.cabelo` mantém o acesso aos moldes nativos das ferramentas de armadura; `cabelo_refinado` reaplica suas máscaras de elmo e cartola em resolução dupla. A cartola composta é redimensionada com nearest e continua seguindo a pose da roupa.

As vestimentas usam o mesmo tamanho de célula e escala. `roupas/manifesto.json` registra as 46 entradas do catálogo nas onze páginas, reutilizando fontes iguais e preservando os índices. `preparar_roupas_refinadas.gd` compila as roupas disponíveis; entradas que já usam uma roupa substituta conservam essa seleção. `validar_roupas_refinadas.py` verifica a cobertura das 176 folhas distintas.

Carrasco, Rubro e Mordomo usam o gerador, os manifestos e o validador compartilhados de `ferramentas/armaduras`. As quatro peças refinadas ficam em `conjuntos/<id>/`, com recomposição exata e máscaras iguais às nativas em resolução dupla. Nenhum dado de nível, raridade, drop, bônus ou inventário é regenerado pelo comando `--somente-acabamento`. As misturas e peças isoladas usam as superfícies pré-compiladas sobre o recorte do compositor nativo.

`objetos/manifesto.json` registra 159 folhas de armas, escudos, arcos, aljavas, flecha, ferramentas agrícolas e marreta de forja. `preparar_objetos_refinados.gd` coleta os cinco níveis do catálogo e as folhas de reação; as imagens dobram de resolução e usam escala 0,5, inclusive a flecha de célula única. `ObjetosRefinados.aplicar` preserva posição, rotação, espelhamento, quadros e ordem das camadas. A aplicação é idempotente e admite a camada de arco ainda sem textura durante a inicialização.

O acabamento preserva pixels claros de rastros, água e brilhos. `validar_objetos_refinados.py` confere dimensões, transparência, a máscara de cada quadro e a intensidade desses efeitos. `teste_objetos_refinados.gd` verifica os roteamentos, poses, ferramentas e a flecha; os testes de fazenda e defesa conferem impactos, interrupções, aparo e escudada com saves isolados. Dano, colisões, alcance, níveis e tempos continuam usando os dados nativos.
