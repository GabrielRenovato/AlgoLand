# Plano: migrar Inventário e Bigorna/Mercante para o padrão de UI do Godot

## Achados que o plano resolve
- **Salvamento incompleto.** O `configuracao_jogador.json` só guarda cosméticos (cabelo, roupa, apelido, cor). `nivel_*` e `usando_*` são lidos por `aplicar_dados_carregados`, mas ninguém grava essas chaves: hoje nível e equipamento **não persistem**. O inventário passa a ser salvo em `user://inventario.json`.
- **Ataque disparando junto com clique na UI.** O ataque usa `Input.is_action_just_pressed("attack")` (Espaço + botão esquerdo), que dispara mesmo quando o clique foi em painel. O inventário (tecla I) também não bloqueia as ações do jogador.
- **Esc tratado duas vezes.** Tanto `merchant.gd` quanto `menu_merchant.gd` fecham o menu no Esc. `merchant.gd` também chama métodos que não existem (`reset_menu`, `connect_menu_closed`, `connect_start_wave`).
- **Ataque bloqueado até abrir o mercante.** `menu_merchant._ready` chama `bloquear_ataques(true)` ao carregar, e o ataque só volta depois do primeiro fechamento do menu. É uma regra implícita a decidir.
- **Molduras e fontes.** Há texturas próprias para moldura em `UI/craftpix-net-775352-…/1 Frames/`:
  - `Back1/Back2` (93×96) para o painel;
  - `Back3` para a barra de título;
  - `Back4–6` para os botões;
  - `Frame1/Frame2` para os slots.

  As fontes pixel atuais **não têm acentos** (conferido).

## Arquitetura alvo
```
Autoloads: DadosJogo (existe), EventosJogo (só sinais), InventarioJogador (modelo)
cenario
└─ Interface (CanvasLayer layer=10) — gerenciador de telas
   ├─ TelaInventario
   └─ TelaMercante (abas Menu / Armas / Construir / Bigorna)
Componentes: grade_mochila, painel_equipamento, slot, item_arrastavel
Tema: recursos/ui/tema_principal.tres
```
- **`DadosItem` (Resource):**
  - Campos: `id`, `tipo`, `categoria`, `nivel`, `raridade`, `icone` (AtlasTexture), `duas_maos`.
  - Métodos: `nome()`, `cor_raridade()`, `para_dict()` e `de_dict()`.
  - Itens base ficam em `recursos/itens/*.tres`.
- **`InventarioJogador` (autoload, sem depender de nós):**
  - Dados: `mochila` com 15 posições e `equipados` (arma, escudo, cabeça, corpo, luvas, botas).
  - Sinais: `mochila_alterada`, `equipamento_alterado`, `item_alterado`.
  - API: `mover_para_mochila` (com troca), `pode_equipar` (regra de duas mãos), `equipar`, `desequipar`, `subir_nivel`, `salvar` e `carregar`.
- **`EventosJogo`:** sinais `abrir_tela`, `fechar_tela`, `tela_aberta`, `tela_fechada`, `forja_solicitada`.
- **Gerenciador de telas:**
  - É o único dono de Esc e da tecla I.
  - Ao abrir uma tela, bloqueia as ações do jogador; ao fechar a última, libera.
  - Não usa nenhum caminho `/root/...`.

## Fases (cada uma termina com o jogo funcionando)

### Fase 0 — Modelo de dados, sem mudança visual (P)
- **Criar:**
  - `Codigos/Modelos/dados_item.gd`
  - `Codigos/Modelos/modelo_inventario.gd`
  - `Codigos/Globais/eventos_jogo.gd`
  - os autoloads no `project.godot`
  - os `.tres` dos itens
- **Jogador:** no fim do `_ready`, sincroniza o modelo a partir de `usando_*`/`nivel_*`, e volta a sincronizar a cada `equipamento_alterado`/`forja_finalizada`.
- **Teste headless** (`testes/teste_inventario.gd`), cobrindo:
  - troca de células;
  - lança e escudo;
  - desequipar para uma célula livre;
  - ida e volta de `para_dict`/`de_dict`;
  - emissão dos sinais.

### Fase 1 — Inventário novo em CanvasLayer (G)
- **Tela.** `cenas/ui/interface.tscn` + `tela_inventario.tscn`, com esta hierarquia:
  ```
  CenterContainer
  └─ PanelContainer (moldura Back1)
     └─ MarginContainer
        └─ VBox
           ├─ título
           └─ HBox
              ├─ equipamento + boneco
              └─ GridContainer de 5 colunas (mochila de 15)
  ```
- **`slot.gd` e `item_arrastavel.gd`:**
  - passam a exibir um `DadosItem`;
  - a soltura chama `InventarioJogador`;
  - a regra de equipar sai do slot e vai para o modelo.
- **Ataque.** A leitura vai para `_unhandled_input`, e clique em painel deixa de atacar.
- **Transição.** O inventário antigo fica oculto e sem input, porque a bigorna ainda depende dele.
- **Teste manual:**
  - I abre e fecha;
  - o painel fica fixo quando a câmera se move;
  - arrastar e soltar funciona;
  - a lança tira o escudo;
  - clicar no painel não ataca;
  - Esc fecha.

### Fase 2 — Mercante e bigorna (G)
- **`tela_mercante.tscn`** com quatro abas:
  - **Armas:** uma lista que equipa pelo modelo.
  - **Construir:** a loja atual dentro de um GridContainer.
  - **Bigorna:** a mochila própria ao lado do slot da bigorna e do painel de upgrade, sem precisar abrir o inventário junto.
  - **Iniciar onda.**
- **Lógica.** O `_dados_upgrade`/`atualizar_painel_upgrade` atual é reaproveitado (já está desacoplado).
- **`merchant.gd`:**
  - abrir e fechar passam a ser feitos por `EventosJogo`;
  - sai o Esc próprio;
  - saem as chamadas mortas.
- **Testes:**
  - headless dos textos e do botão conforme moedas e onda;
  - manual de forja, loja e iniciar onda.

### Fase 3 — Remoção do legado e fonte de verdade única (M)
- **Remover:**
  - `inventario.tscn` e `Inventario.gd`;
  - `menu-do-mercante.tscn` e `menu_merchant.gd`;
  - os nós `Inventario` (no Jogador) e `MenuMerchant` (no Mercante);
  - o `object_drag.tscn` sem uso.
- **Níveis.** `nivel_espada/lanca/escudo` passam a vir do `InventarioJogador`, e a forja chama `subir_nivel`.
- **Persistência.** `salvar()` ao fechar telas e ao fim de cada onda; `carregar()` no início.
- **Verificação:**
  - grep sem referências antigas;
  - testes rodando de novo;
  - reiniciar o jogo e ver o nível mantido.

### Fase 4 — Tema e textos (M)
- **Tema único:**
  - fonte padrão em tamanho nativo;
  - StyleBoxTexture para painel, botões (normal, hover, pressionado, desabilitado), slot e tooltip;
  - sai o `theme_override` espalhado pelas cenas.
- **Textos em PT** centralizados em `Codigos/UI/textos.gd`:
  - "START WAVE" → INICIAR ONDA
  - "WEAPONS" → ARMAS
  - "BUILD" → CONSTRUIR
  - "LEAVE" → SAIR
  - "ANVIL" → BIGORNA
  - "BUY" → COMPRAR
- **Opcional:** escala pixel-perfect com `stretch/scale_mode="integer"`.

## Decisões
1. **Acentos:** textos de UI sem acento; nenhuma fonte nova.
2. **Ataque bloqueado no início:** removido (`bloquear_ataques(true)` em `menu_merchant._ready`).
3. **Execução:** cada fase com um agente `sonnet` e verificação headless no chat principal.
