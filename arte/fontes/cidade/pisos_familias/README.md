# Pisos próprios por família

Atlas nativo image_gen com nove materiais independentes, sem Mana Seed ou Tiny.
Contrato: vista ortográfica, opaco, chão plano, resolução 4×, período lógico
128×128 e encaixe no contorno existente de sala_topdown.gd. Sem alterar
pivôs, plantas, bases de móveis, portas ou colisões. Pedido em pedido.txt.

| Família | Comércio (medio) | Quartos (claro) | Trabalho (escuro) |
| --- | --- | --- | --- |
| Mara | Parquet de nogueira em espinha | Tábuas largas de carvalho claro | Lajes de ardósia |
| Cora | Ladrilho xadrez terracota/creme | Pavers de terracota | Cerâmica cinza clara |
| Rosa | Calcário com cabochões verdes | Tábuas estreitas verticais | Cerâmica hexagonal verde |

`ferramentas/casas/preparar_pisos_familias.py` identifica recortes na mesma
fase das juntas e publica 36 texturas em assets. `manifesto.json` registra
os recortes efetivos e as repetições. A compensação de exposição nas
bordas do chão orgânico não é aplicada, pois mistura ladrilhos de cores
diferentes. As quatro estações recebem a luz ambiente abrigada já usada
pelo preparador de interiores; sem neve no piso interno.

O carregador seleciona pelo id da família, uso e estação. Os outros
interiores mantêm os materiais comuns. As passagens recebem o piso da
respectiva ala, preservando as transições nas portas.

Verificação: harness selecionado / casas_familias, 978 verificações, zero
erros, estado preservado. Relatório em
/tmp/algoland-harness/execucao-sifpu6uu/relatorio.json. Revisão no Godot
nas quatro estações e telas compactas; prévias em
arte/previas/cidade/pisos_familias/. Não implica aprovação do usuário.
