# Goblin derivado do molde do jogador

- Pedido: adaptar o molde existente do personagem para um goblin comum 3D.
- Fonte efetivamente instanciada: `cenas/personagem/base_3d/personagem.scn`.
- Mantidos: CorpoBase, pesos, rig DEF, proporções de `proporcao_chibi.gd`, Camisa, Calca, Botas e Cabelo. Materiais duplicados antes de alterar a paleta; fonte permanece intacta.
- Adaptação: pele verde-oliva, olhos âmbar, cabelo escuro, roupas de tons terrosos; orelhas volumétricas pontudas, nariz e pequenas presas ligados ao osso DEF-head.
- Escala uniforme: 0,82 do jogador, preservando proporções. Mesmo chão, descida do quadril e câmera frontal elevada. Não normalizar vistas individualmente.
- Rig e biblioteca de animação originais preservados; prévias reais do ciclo parado e caminhada no Godot. Ataques específicos de lança não produzidos nesta adaptação.
- Modelo consumível: `assets/inimigos/goblin_molde_jogador/goblin.tscn` (cena 3D real, não sprite ou ilustração).
- Gerador: `ferramentas/inimigos/goblin_molde_jogador/preparar.gd`.
- Evidências: `arte/previas/inimigos/goblin_molde_jogador/`; comparação lado a lado usa o mesmo molde e iluminação.
- Estudo independente. Não troca o jogador, NPCs ou inimigos ativos; reversão consiste em retirar a instância da cena derivada quando ela for integrada.
