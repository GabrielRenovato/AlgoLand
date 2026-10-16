# Matriz de testes do cooperativo, controle e Android

Execute a partir da raiz do projeto:

```bash
python3 ferramentas/projeto/testar_coop.py
python3 ferramentas/projeto/testar_coop.py --grupo coop --grupo android
python3 ferramentas/projeto/testar_coop.py --teste coop_entradas --teste coop_android
python3 ferramentas/projeto/testar_coop.py --listar
```

O executor encontra Godot/Godot 4 ou o Flatpak `org.godotengine.Godot`, prepara uma cópia fora do repositório e usa uma pasta de save exclusiva **para cada teste e execução**. Não execute os scripts de cena diretamente no projeto principal. Os recursos são compartilhados por links, conforme `preparar_testes.py`; não edite a cópia para fazer experimentos.

Logs completos e `relatorio.json` ficam em `/tmp/algoland-coop-*`. `--saida /tmp/pasta-nova` escolhe uma pasta vazia. O código de saída é 1 se houver falha, erro de script, erro do Godot, travamento ou limite de tempo excedido, mesmo se o script retornar zero. Diagnósticos já conhecidos de DisplayServer headless e recursos no encerramento ficam registrados em `avisos_conhecidos`, sem reprovar o teste; outros erros reprovam. Erros de script encerram o processo imediatamente para não deixar uma corrotina interrompida travar a matriz. O limite padrão é 180 segundos **por teste**; ajuste com `--limite`. Os testes continuam após uma falha para registrar o restante da matriz; falha na importação impede a execução.

| Grupo | Cobertura automatizada |
| --- | --- |
| `coop` | Todos os vínculos de entrada P1/P2, botões, gatilhos, analógico e direcional; isolamento de dispositivo desconhecido; soltura; reatribuição; saída para solo; cenas e arena; HUDs e painéis; inventários e navegação separados; ambientes independentes; ferramentas; pausa por ambos os controles; bancos; sono; economia e missões; praia, palafita e guia de pesca; aviso da festa de sábado e pombo-correio (solo, toque e P2). |
| `controle` | Rótulos Xbox/Nintendo/PlayStation, foco e navegação de interface, mira, barra de armas e pausa. |
| `android` | Toque simulado com as interfaces reais: P1 no toque e P2 no controle, isolamento de ações e menus, tamanho e separação dos botões, fechamento pela rota GUI, reviver; também joystick livre, zona morta, multitoque, ataque e defesa, bloqueio com menus, coleta e tutorial. |
| `sistemas` | Regressões existentes de inventário, fazenda, plantio, poções, defesa, morte, transições, introdução e diálogo. Estes testes complementam a matriz; não executam automaticamente cada funcionalidade com dois jogadores. |

`teste_coop_entradas.gd` verifica cada evento de controle cadastrado nas ações do coop, em ambos os dispositivos e em um dispositivo não atribuído. Ele injeta eventos e observa o estado de `Input`; os outros testes verificam os efeitos no jogo. `teste_coop_android.gd` injeta eventos de tela na janela, com as coordenadas das metades e usa o controle do parceiro pela entrada do Godot. Os testes existentes cobrem os efeitos de combate, agricultura, menus e transições.

Para conferir com renderização real, acrescente `--grafico`. Isso abre janelas e não substitui a inspeção visual. A matriz de toque no desktop **não valida um APK nem hardware Android**. Antes de distribuir, confira em aparelho:

- Toque + controle Bluetooth/USB no coop, em duas proporções de tela, com recorte da câmera e barras do sistema.
- Andar, atacar/usar ferramenta, defender, rolar, colher, trocar ferramenta/arma/poção e interagir; soltar todos os dedos sem comandos presos.
- Abrir, navegar e fechar mochila, lojas, baú, diálogos e pausa; um menu individual não bloqueia o parceiro.
- Desconectar/reconectar o controle, colocar o app em segundo plano e voltar; conferir comandos presos, foco e retomada.
- Travessias separadas, combate, queda/reanimação e sono conjunto com saves descartáveis.

Pesca ainda não possui mecânica de captura implementada. Compatibilidade com aparelhos, recortes físicos, permissões do Android e reconexão Bluetooth precisam da validação em dispositivo; o relatório automatizado não certifica esses itens.
