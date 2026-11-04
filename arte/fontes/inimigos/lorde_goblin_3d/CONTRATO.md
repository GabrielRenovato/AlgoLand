# Lorde Goblin — modelo canônico 3D

- Função: modelo visual do chefe da caverna do estágio 4, separado da IA e dos sprites de combate existentes.
- Referência: `referencia.png`, conceito gerado no chat. Anatomia e equipamentos modelados do zero em Blender; nenhum GLB, malha ou rig do Goblin King foi importado.
- Identidade: corpo robusto, cabeça descoberta, olhos âmbar, presas curvas, armadura irregular de ferro, couro marrom, manto azul-petróleo no ombro esquerdo e martelo de granito na mão direita.
- Escala: corpo com cerca de 3,08 m; martelo chega a 3,56 m. Aumento de 50% solicitado pelo usuário durante a modelagem. Referência do goblin comum/jogador: 1,35 m; o Lorde tem aproximadamente 2,3 vezes essa altura. A prévia de caverna amplia o tamanho visual na mesma proporção.
- Pivô: centro dos pés no chão, origem `(0,0,0)`. Blender usa Z para cima e frente -Y; GLB/Godot usa Y para cima e frente +Z.
- Câmera: ortográfica elevada e frontal sem yaw no enquadramento de jogo. A folha de revisão gira o modelo em oito direções.
- Pintura: oito materiais em pixel art com filtro nearest; olhos, cavidades e detalhes pequenos usam cores foscas. Texturas incorporadas no GLB.
- Rig: 18 ossos próprios. Manto e martelo possuem ossos separados. A mão direita fecha em torno do cabo.
- Mãos: quatro dedos com falanges curvas e um polegar oposto em cada mão. Palmas e dedos formam superfícies contínuas; a pegada possui uma cavidade de apoio para não penetrar no cabo. Na fonte animada, a mão esquerda recebe a mesma anatomia curva da direita espelhada e orientada para a pegada dupla; no repouso fica semi-fechada. Os pés possuem quatro dedos com proporções diferentes e unhas curtas, conforme a anatomia fantástica da referência.
- Movimentos: respiração base de 3,2 s; ataques transferidos da biblioteca gratuita KayKit (CC0), com chaves a 60 FPS: `Melee_2H_Attack_Slice`, `Melee_2H_Attack_Chop` e `Melee_2H_Attack_Spinning`. Caminhada e morte pendentes. Detalhes em `CONTRATO_ANIMACOES.md`.
- Estações: não se aplicam variantes de cenário ao personagem.
- Destino: `assets/inimigos/lorde_goblin_3d/lorde_goblin.glb` e `cenas/inimigos/lorde_goblin_3d.tscn`. Fontes editáveis: `lorde_goblin.blend` (base) e `lorde_goblin_kaykit.blend` (ataques gratuitos transferidos).
- A cena jogável `lorde_goblin.tscn` mantém o atlas animado anterior até a produção dos movimentos deste modelo. O novo recurso não se apresenta como uma substituição animada completa do ator.
- Prévia de integração: `arte/previas/inimigos/lorde_goblin_3d/na_caverna.png` compõe o GLB renderizado no Godot sobre a captura real da caverna, sem carregar uma partida.
- `atlas_materiais_v1.png` registra a tentativa rejeitada por contraste excessivo da pele e do ferro; somente `atlas_materiais.png` é consumido pelo preparador.
- Custo em mobile ainda não perfilado; não declarar otimização com base apenas na quantidade de triângulos.
