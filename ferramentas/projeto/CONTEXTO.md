# Mapa técnico do AlgoLand

Consulta sob demanda; confirmar no código antes de editar. Projeto Godot 4, GDScript.

## Pontos de entrada

| Sistema | Caminhos principais |
| --- | --- |
| Prólogo e tutorial guiado | `codigo/introducao/`; autoload `Introducao`; `testes/teste_introducao.gd` |
| Inicialização e autoloads | `project.godot`; `cenas/inicio_do_jogo.tscn` |
| Fazenda | `cenas/fazenda.tscn`; `cenas/terreno_fazenda.tscn` |
| Plantio e coleta | `codigo/logica/plantio.gd`; `codigo/globais/fazenda_dados.gd` |
| Solo e limites visuais | `codigo/cenario/solo_arado.gd`; `codigo/cenario/limite_plantio.gd` |
| Árvores e pedras | `codigo/logica/extracao_fazenda.gd` |
| Jogador e ações agrícolas | `codigo/jogador/jogador.gd`; `codigo/jogador/fazenda_jogador.gd` |
| Inventário | `codigo/modelos/modelo_inventario.gd`; `codigo/modelos/dados_item.gd` |
| Missões na mochila | `codigo/ui/tela_inventario.gd`; `codigo/ui/missoes_inventario.gd`; progresso compartilhado em `codigo/cidade/estado_cidade.gd` |
| Sementes e armas permanentes | `codigo/dados/loja_sementes.gd`; `codigo/dados/desafios_armas.gd`; `codigo/ui/desafios_inventario.gd`; `testes/teste_economia_festa.gd` |
| Festa e assentos na taverna | `codigo/cidade/rotina_taverna.gd`; `assento_morador.gd`; `trajeto_morador.gd`; poses em `ferramentas/cidade/preparar_npcs_sentados.gd`; teste de festa com `--festa-coop` e captura opcional `--capturar` |
| Avisos de eventos e pombo-correio | autoload `AgendaVila` (`codigo/globais/agenda_vila.gd`): eventos em `DadosCidade.EVENTOS` no banner de todos os HUDs; dormir deixa `Cidade.carta_pendente` e o pombo (`codigo/cidade/pombo_correio.gd`) entrega a carta de pedido ao sair de casa; carta abre no modo carta de `dialogo_cidade.gd`; sprite gerado por `ferramentas/cidade/gerar_pombo.gd` (gavião Mana Seed recolorido); desligado em testes `--script`; `testes/teste_agenda_vila.gd` |
| Cooperativo local | `codigo/globais/cooperativo.gd`; `codigo/ui/vista_jogador.gd`; `testes/teste_interface_coop.gd`; `testes/teste_controle_ambientes_coop.gd` |
| HUD e entradas | `codigo/ui/hud.gd`; `barra_armas.gd`, `controles_toque.gd`, `mini_tutorial.gd` em `codigo/ui/`; `codigo/globais/controle.gd`; InputMap em `project.godot` |
| Cidade e moradores | `codigo/cidade/`; conversas de encontro em `papos_vizinhos.gd`, afazeres livres em `passeio_morador.gd`, validação em `testes/teste_papos_rotinas.gd`; `cenas/cidade.tscn`; cercas em `codigo/cidade/cercas_vila.gd`; grama sazonal em `ferramentas/cidade/preparar_grama_mana_seed.py` |
| Praia e arte de pesca | `cenas/praia.tscn`; `codigo/pesca/`; costa e adornos em `layout_praia.json`, mar animado em `mar.gdshader`, colisão da costa calculada pelo gerador com os mesmos parâmetros; Nilo apresenta `assets/pesca/catalogo.json` (12 ícones Tiny RPG); `ferramentas/pesca/preparar_recursos.py` prepara atlas/ícones/NPC/adornos e `gerar_praia.py` gera a cena; rua sul em `ferramentas/cidade/terreno_vila.py`; geração de cidade/praia libera o corredor na decoração existente; mecânica de captura ainda não implementada |
| Palafita, Nilo e visitantes | `cenas/palafita.tscn` e palafita exterior geradas por `ferramentas/pesca/gerar_praia.py`; casa e caminhada preparadas por `preparar_recursos.py`; rotina do Nilo em `codigo/pesca/rotina_nilo.gd` e ator em `pescador.gd`, sem mudar o cadastro dos seis moradores; visitas em `DadosCidade.visita_praia`, fora do trabalho e com tempo bom; praia herda navegação/conversas de `cidade.gd`; trajetos compartilhados tratam praia–palafita como ligação direta |
| Composição do cais | Plataformas, porta da casa e mobiliário em `codigo/pesca/layout_praia.json`; `gerar_praia.py` desconta o cais da colisão do mar e monta corrimãos nativos; `estrutura_cais.gd` desenha vigas e estacas submersas nas bordas, sem colisão; piso e paredes Mana Seed e móveis da vila em `interior_palafita.gd`; mobiliário externo em `mobiliario_cais.gd`; referências e prompts em `arte/fontes/praia/geracao.json` |
| Clima e estações | `codigo/cenario/clima.gd`; `estacoes.gd`; `codigo/globais/calendario.gd` |
| Geração de recursos | `ferramentas/fazenda/`; `ferramentas/cidade/`; `ferramentas/armaduras/` |

Recursos usados pelo jogo ficam em `assets/`. Fontes e prévias ficam em `arte/`; não criar dependências do jogo nessa pasta.

## Verificação com saves isolados

- Matriz de coop/controle/Android: `python3 ferramentas/projeto/testar_coop.py`; grupos `coop`, `controle`, `android`, `sistemas`, filtro `--teste` e execução gráfica com `--grafico`. Cada teste recebe save exclusivo; logs e relatório JSON em `/tmp`. Cobertura e verificações em aparelho em `testes/COOP.md`.

Godot instalado via Flatpak: `org.godotengine.Godot`. Usar uma cópia fora do repositório:

```bash
python3 ferramentas/projeto/preparar_testes.py /tmp/algoland-tarefa
flatpak run --filesystem=/tmp org.godotengine.Godot --headless --editor --path /tmp/algoland-tarefa --import --quit > /tmp/algoland-import.log 2>&1
flatpak run --filesystem=/tmp org.godotengine.Godot --headless --path /tmp/algoland-tarefa --script res://testes/TESTE.gd > /tmp/algoland-teste.log 2>&1
```

- A cópia compartilha arquivos por symlinks; editar nela também pode alterar o projeto real.
- O nome `AlgoLand testes Carrasco` é exigido por vários testes; manter. Para isolar também entre tarefas, configurar **somente no project.godot da cópia**, em `[application]`, `config/use_custom_user_dir=true` e `config/custom_user_dir_name="AlgoLand testes identificador-unico"`.
- Selecionar o teste pertinente em `testes/`. Coleta: `teste_coleta_dedicada.gd`; limite de terra: `teste_limite_plantio.gd`; moradores/chuva: `teste_moradores_clima.gd`.
- Praia: `teste_praia.gd` exige `config/custom_user_dir_name="AlgoLand testes praia 20261016"` na cópia; cobre colisões, bancos (sentar/levantar com teclado e controle), guia e travessia individual no cooperativo. `-- --capturar-colisoes` salva detalhes da casa nas quatro estações, banco ocupado e visão geral em `/tmp/algoland-colisoes-*.png`. Com `-- --capturar` e renderização gráfica, salva prévias em `arte/previas/praia/`.
- Casa/rotinas: `teste_rotina_praia.gd` usa o mesmo save isolado, valida horários, abrigo, cama, caminhada até a palafita e ida/volta de visitantes. `teste_praia.gd` também acompanha o Nilo entre casa e praia em mundos cooperativos distintos.
- Sobreposição do cais: executar `teste_sobreposicao_cais.gd` com renderização gráfica real na cópia isolada. Compara pixels do piso antes/depois dos apoios e força ordem invertida e uma invasão proposital; exige zero pixels alterados no piso e apoios visíveis na água. `estrutura_cais.gd` usa `recorte_estrutura_cais.gdshader` para mascarar as células do piso.
- Conferir código de saída, `FALHA`, `SCRIPT ERROR` e `Parse Error`. Avisos conhecidos de DisplayServer headless ou recursos no encerramento não substituem a análise de erros novos.
- Auditoria de caminhos, quando houver mudanças de recursos: `python3 ferramentas/projeto/auditar_referencias.py`.

No cooperativo, as portas preservam os ambientes em `World2D` independentes: cada jogador atravessa sozinho e áreas iguais compartilham o mesmo mundo. A entrada e a saída da arena seguem conjuntas. Os viewports renderizam em pixels físicos, com organização lógica independente.

Prólogo ativado pelo NOVO JOGO. `user://introducao.json` guarda etapa, presentes e checkpoint do inventário; ausência do arquivo mantém saves antigos no jogo livre. Durante a introdução, o relógio fica parado até o primeiro sono. As caminhadas têm acompanhamento automático (`jogador.seguindo_introducao`); as lições em `tarefa_pratica.gd` liberam o controle e só avançam com ações válidas nos alvos salvos.
