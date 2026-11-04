# Lorde Goblin 3D

Modelo e rig próprios; a criação não importa outros personagens. Conceito,
atlas, prompts, contrato e `.blend` ficam em `arte/fontes/inimigos/lorde_goblin_3d/`.
O GLB incorpora as texturas, o rig de 18 ossos e quatro clipes: `parado`, `golpe_duas_maos`, `impacto_area` e `giro_area`.

Regenerar os recortes e o modelo:

```bash
python3 ferramentas/inimigos/lorde_goblin_3d/preparar_texturas.py
flatpak run --filesystem=/home/alfeim/AlgoLand org.blender.Blender \
  --background --factory-startup \
  --python /home/alfeim/AlgoLand/ferramentas/inimigos/lorde_goblin_3d/gerar_modelo.py
```

O gerador foi executado em Blender 5.2. A cena consumidora é
`cenas/inimigos/lorde_goblin_3d.tscn`; seu script ajusta o filtro dos materiais
e inicia a respiração. Não tem lógica de dano ou acesso a saves.

`revisar_modelo.gd` roda em projeto mínimo, sem autoloads. Recebe os caminhos
absolutos em `ALGOLAND_LORDE_MODELO`, `ALGOLAND_LORDE_PREVIAS` e
`ALGOLAND_LORDE_CAVERNA`. O último aponta para a captura do chão da caverna.
Produz oito vistas, detalhes, escala de jogo, composição sobre a caverna,
17 amostras de dois ciclos de respiração e `revisao_godot.json`.
`-- --maos` limita a captura aos closes das mãos e dos pés. O teste também
verifica a folga entre a pele da pegada e o cilindro do cabo.

O teste estrutural usa saves isolados pelo harness:

```bash
python3 ferramentas/projeto/harness.py testar --perfil selecionado --teste lorde_goblin_3d
```

Os três ataques são produzidos por `animar_modelo.py`, após o gerador base:

```bash
flatpak run --filesystem=/home/alfeim/AlgoLand org.blender.Blender \
  --background --factory-startup \
  --python /home/alfeim/AlgoLand/ferramentas/inimigos/lorde_goblin_3d/animar_modelo.py
```

A fonte de animação é `lorde_goblin_kaykit.blend`; a fonte base continua
separada. A animação transfere clipes prontos KayKit (CC0), com IK para encaixar a
pegada no cabo, três voltas
com passos da fonte e transição de repouso. `animacoes.json` registra
tempos, raios e centros locais dos eventos. O visual oferece `tocar_ataque`,
`cancelar_ataque` e os sinais `impacto`, `aviso_area` e `acao_concluida`.
O consumidor transforma o centro local em coordenadas de mundo e aplica dano;
o modelo não consulta jogadores nem altera vida por conta própria.
Os anéis de área usam exatamente os centros e raios dos eventos.

`revisar_animacoes.gd` importa a 60 FPS em projeto mínimo e amostra os clipes
no Godot a 20 FPS, incluindo efeitos reais, frente, lateral, pegadas e escala
de jogo. `montar_animacoes.py` monta os mesmos quadros e tempos em GIFs e
folhas de contato, sem repintar o personagem.

O ator jogável `cenas/inimigos/lorde_goblin.tscn` agora renderiza este GLB
em viewport224² com nearest; possui caminhada gratuita Walking_A, três
ataques com dano sincronizado, hurtbox e derrota que libera a alavanca.
A cena `cenas/campanha/chegada_lorde_goblin.tscn` apresenta o guardião com
câmera e diálogo responsivo antes de ativar a luta. O HUD é restaurado
na conclusão. Morte usa desaparecimento, sem clipe esquelético próprio.

A fonte e licença da biblioteca ficam em `animacoes_kaykit.json` e
`LICENSE_KAYKIT.txt`, junto à fonte Blender. O giro usa o clipe contínuo
`Melee_2H_Attack_Spinning`; a varrida usa `Melee_2H_Attack_Slice`; a martelada
usa `Melee_2H_Attack_Chop`. Não há compra nem assinatura necessária.

O giratório inclui um tornado de três fitas 3D semitransparentes, ligado à
janela ativa. O efeito some ao terminar/cancelar e pode ser ocultado junto
dos outros efeitos por `exibir_efeitos`.
