# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Regras de projeto (idioma, arte, economia de contexto) estão em `AGENTS.md` e valem também aqui. Mapa técnico de caminhos e contratos: `ferramentas/projeto/CONTEXTO.md`, consultado sob demanda.

## Comandos

Godot 4.7 roda pelo flatpak. Não há `godot` no PATH.

```bash
# Abrir o editor
flatpak run org.godotengine.Godot --path .

# Reimportar recursos depois de mexer em assets (também valida scripts e cenas)
flatpak run org.godotengine.Godot --headless --editor --path . --import --quit

# Auditar referências quebradas
python3 ferramentas/projeto/auditar_referencias.py
```

Testes rodam numa cópia fora do repositório, porque alguns inicializam cenas e gravam inventário:

```bash
python3 ferramentas/projeto/preparar_testes.py /tmp/algoland-testes
flatpak run org.godotengine.Godot --path /tmp/algoland-testes --script res://testes/teste_estrutura_projeto.gd
```

Um teste só: trocar o `--script` por `res://testes/<arquivo>.gd`. Não rode a suíte sem pedido explícito.

Build e publicação:

```bash
# APK de depuração (preset "Android" em export_presets.cfg)
flatpak run org.godotengine.Godot --headless --path . --export-debug "Android" /caminho/AlgoLand.apk

# Patch de conteúdo (.pck); grava direto em ../AlgoLand-wiki/public/jogar/atualizacao/
python3 ferramentas/atualizacao/gerar_atualizacao.py patch --preset Android   # ou "Windows Desktop", "Linux"
python3 ferramentas/atualizacao/gerar_atualizacao.py base                      # base de cada APK exportado
```

A wiki é um repositório separado em `../AlgoLand-wiki` (Netlify): `npm run build` no diretório dela, `scripts/sincronizar-dados.py ../AlgoLand` e `scripts/exportar-jogo-web.py ../AlgoLand <saida>` para a Web. O passo a passo de publicação está em `fluxo-publicacao-conteudo` na memória do projeto.

Neste ambiente não há `git` no PATH: use `host-spawn git ...`.

## Arquitetura

**Entrada e autoloads.** O jogo abre em `cenas/inicio_do_jogo.tscn`. Os autoloads em `project.godot` têm ordem: `Saves` é o primeiro e prepara `codigo/dados/versao_save.gd` e `reequilibrio_save.gd` antes de carregar os demais. A ordem importa; mudar autoload ou `project.godot` exige APK novo, não patch.

**Estado do jogo.** Cada sistema tem um autoload dono do estado: `Fazenda` (`codigo/globais/fazenda_dados.gd`, água, plantio, pesca), `Calendario` (dia e estação), `Progresso`, `InventarioJogador` (e `InventarioJogador2` no cooperativo), `Cooperativo`, `Transicao` (fade, dormir, carregamento de cenas), `Comercio`, `AgendaVila`. Os saves ficam em `user://`, separados por mundo.

**Tempo.** `Iluminacao` (`codigo/efeitos/iluminacao.gd`) tem o relógio do dia e chama o fim do dia; `Transicao` leva o jogador a dormir e salva. O relógio não é salvo: o dia só avança por `Calendario.dormir()`, e `Calendario.encerrar_dia()` marca o fim para um save feito antes de dormir.

**Mundos.** Vila (`codigo/cidade/`, moradores com rotina em `agenda_vila.gd` e `dados_cidade.gd`), fazenda (`codigo/logica/plantio.gd`, `extracao_fazenda.gd`), fendas em andares (`codigo/logica/` e `codigo/fendas/`, com um `gerenciador_andar`), arena com ondas (`gerenciador_ondas`), pesca (`codigo/pesca/`), duelo online (`codigo/duelo/`, com o servidor em `ferramentas/lobby/servidor/duelo.mjs`) e mercado (`codigo/mercado/cliente_mercado.gd` fala com RPCs do Supabase definidas em `ferramentas/mercado/*.sql`).

**Dados de jogo.** `codigo/dados/` concentra tabelas: plantas, raridades, receitas, peixes, encantamentos. Números de balanceamento ficam aí, não nos scripts de cena.

**Patches.** O jogo abre em `cenas/atualizacao.tscn`, baixa `.pck` da wiki e confere SHA-256 e assinatura RSA antes de abrir. A lista `NUCLEO` em `ferramentas/atualizacao/gerar_atualizacao.py` fixa os arquivos que um patch não pode trocar; se ela mudar, o gerador recusa e exige um app novo. A chave privada fica em `~/.config/algoland/atualizacao_privada.pem`.

**Pipeline de arte.** Fontes e prompts ficam em `arte/fontes/`, previews em `arte/previas/`. Os geradores em `ferramentas/` leem essas fontes e escrevem em `assets/`, que é o que o jogo carrega. `arte/`, `arquivo/` e `builds/` têm `.gdignore`, então não são importados. Armaduras seguem o manifesto, o gerador e o validador compartilhados em `ferramentas/armaduras/`, descritos em `PADRAO.md`.

**Exportação.** `export_presets.cfg` exclui `testes/`, `ferramentas/`, `arte/`, `arquivo/`, `builds/` e `docs/` do pacote. Um arquivo novo que o jogo carrega por caminho tem de estar dentro do pacote exportado, ou o build quebra sem avisar no editor.
