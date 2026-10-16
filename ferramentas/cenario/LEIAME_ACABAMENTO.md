# Acabamento dos tiles e mapas

O acabamento é aplicado na renderização por `codigo/globais/tiles_refinados.gd`, registrado como autoload `TilesRefinados`. Ele reconhece os atlas de `assets/cenario/` e aplica `acabamento_tiles.gdshader` às camadas e sprites do cenário. As imagens originais, a grade de 16×16, as coordenadas dos atlas, animações, células e colisões são preservadas.

A paleta aumenta moderadamente contraste e saturação, reforça tons escuros e preserva reflexos claros. A transformação depende somente da cor de cada pixel: não cria contornos por célula nem altera o encontro entre tiles. A modulação de construções e a transparência são mantidas. Personagens, NPCs e UI ficam fora desse tratamento.

Água, ponte e pavimento que usam `agua_cidade.gdshader` reutilizam a mesma função de cor. O sampler repetido e o recorte original permanecem intactos. O solo arado e as plantas criadas durante o jogo recebem o acabamento ao entrar na árvore. A troca de estação continua trocando as texturas nativas com o mesmo shader.

`TilesRefinados.ativo` permite comparação temporária, sem gravar saves. A prévia GPU em `ferramentas/cidade/previa_tiles_refinados.gd` renderiza cidade, fazenda, casa, pousada e arena antes/depois e verifica alfa e tintura. `testes/teste_tiles_refinados.gd` confere células, fontes, colisões, quatro estações e exclusão de personagem/UI. Execute os testes na cópia com nome "AlgoLand testes Carrasco".

Este é acabamento sobre assets existentes, não criação independente dos sprites. Os avisos e readmes originais de Mana Seed são preservados. A licença aplicável à aquisição precisa ser verificada antes da publicação do projeto, especialmente quanto à cláusula de uso junto a conteúdos gerados por IA da licença atualmente publicada pelo autor.
