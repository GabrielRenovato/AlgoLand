# Atualizações por área

Android, Windows e Linux consultam `algoland/url_atualizacao` nas versões exportadas.
No editor, só consultam com `-- --atualizacao-url=http://.../`. A Web continua
atualizada pela hospedagem.

## Preparar a primeira versão com esse mecanismo

1. Incremente `application/config/version` e, no Android, `version/name` e o código
   de versão do preset. Distribua um aplicativo novo com `InicializacaoPatches`
   como primeiro autoload. As versões antigas não entendem o novo manifesto.
2. Preserve a chave privada em `~/.config/algoland/atualizacao_privada.pem` e faça
   backup seguro. O comando `chave` só é necessário se ainda não existir o par.
3. Sem alterar fontes/configuração entre exportar o aplicativo e registrar a base:

```bash
python3 ferramentas/atualizacao/gerar_atualizacao.py base --preset Android
python3 ferramentas/atualizacao/gerar_atualizacao.py base --preset 'Windows Desktop'
```

Cada plataforma tem sua própria base. Não sobrescreva a base de uma versão já
entregue nem altere a versão do aplicativo para publicar apenas conteúdo. Use a
mesma versão do Godot e os mesmos parâmetros de exportação da base.

## Publicar conteúdo

```bash
python3 ferramentas/atualizacao/gerar_atualizacao.py patch --preset Android --publicacao /tmp/publicacao-android
python3 ferramentas/atualizacao/gerar_atualizacao.py patch --preset 'Windows Desktop' --publicacao /tmp/publicacao-windows
```

Na publicação real, use a mesma pasta de saída para as plataformas, preservando
`versao.json`, ou faça a combinação das entradas antes de enviar. O destino padrão
é `../AlgoLand-wiki/public/jogar/atualizacao/`. Criar esses arquivos localmente
não publica o site.

Envie primeiro todos os `.pck` referenciados e, por último, `versao.json`. O
manifesto contém uma geração completa por versão/plataforma, assinada em RSA,
com hash SHA-256, assinatura e tamanho de cada pacote. Patches são cumulativos
em relação à base instalada, sem depender de atualizações intermediárias.

As regras de área ficam em `pacotes.py`: cada andar tem pacote próprio; cidade,
fazenda, praia, floresta, interface, áudio e recursos compartilhados têm grupos
separados. Binários importados/compilados seguem os `.import`/`.remap` dos fontes.
Recursos usados por mais de uma área permanecem no grupo compartilhado quando
não têm dono específico. Todos os grupos necessários são instalados juntos;
aqui não há download sob demanda ao entrar num mapa.

O nome de cada pacote contém o hash. Se só um andar mudou, os outros grupos
reutilizam os arquivos já baixados. A primeira atualização baixa as diferenças
acumuladas da base; as seguintes baixam apenas grupos cujo hash mudou.

## Ativação e recuperação

O download vai para um arquivo parcial e só é promovido após conferir assinatura,
tamanho e hash. O registro ativo só muda depois de obter todos os pacotes da
nova geração. Se um download falhar, os arquivos da geração atual são preservados, mas a
entrada no jogo fica bloqueada: é possível tentar novamente ou sair. Pacotes já
concluídos são reaproveitados na tentativa seguinte. O manifesto pendente fica
salvo e assinado; fechar o aplicativo ou perder a conexão não libera uma
atualização obrigatória já detectada.

O jogador fecha e reabre o jogo para ativar. A tela de conclusão oferece apenas
fechar o jogo, sem continuar na geração anterior. Se não houver atualização
pendente conhecida, a abertura offline continua disponível. No próximo início, `_init()` do primeiro
autoload verifica todos os pacotes e os monta antes de compilar os outros
singletons. O tema global, aberto antes pelo motor, recebe atualização profunda
do cache. Depois de uma montagem íntegra, pacotes antigos são removidos do
armazenamento local. Se faltar um pacote ou houver corrupção, o jogo usa a base
e tenta reparar pela rede. Saves ficam fora dessa pasta e não são alterados.

## Quando ainda precisa de APK/EXE novo

Mudanças no motor, extensões/bibliotecas nativas, opções de exportação,
`project.godot`, layout global de áudio, chave pública ou núcleo do atualizador exigem nova base e novo
aplicativo. A ferramenta bloqueia essas alterações. Scripts dos outros autoloads,
regras, cenas e arte podem seguir nos pacotes, ativados ao reabrir.

Para anunciar um instalador novo por plataforma, use também `--app VERSAO
--url-app URL`. Os argumentos antigos `--apk` e `--url-apk` continuam disponíveis
para o aviso Android. Atualizar o núcleo fixo requer distribuir o instalador.

## Validação

Antes de publicar, confira a preservação da mochila em um projeto com save isolado:

```bash
python3 ferramentas/projeto/preparar_testes.py /tmp/algoland-validacao-save
flatpak run --filesystem=/tmp org.godotengine.Godot --headless --path /tmp/algoland-validacao-save --script testes/teste_save_menu_inventario.gd
```

O teste abre processos novos, pausa/fecha no menu antes de carregar a mochila e
confere minérios, níveis das quatro ferramentas, P2 e checkpoint do prólogo.
Também confirma que uma mochila carregada continua gravando mudanças e pode ser
esvaziada intencionalmente. Falha nessa regressão impede a publicação. Nunca
execute esses cenários na partida real ou aumente a versão do save para corrigir
uma perda de itens.

```bash
python3 testes/teste_pacotes_atualizacao.py
python3 testes/teste_pacotes_atualizacao.py --preparar-motor /tmp/algoland-pacotes-motor
python3 -m http.server 18764 --bind 127.0.0.1 --directory /tmp/algoland-pacotes-motor/servidor
```

Em outro terminal, execute em sequência:

```bash
flatpak run --filesystem=/tmp org.godotengine.Godot --path /tmp/algoland-pacotes-motor --script res://teste.gd
flatpak run --filesystem=/tmp org.godotengine.Godot --headless --path /tmp/algoland-pacotes-motor --script res://teste.gd -- --montado
flatpak run --filesystem=/tmp org.godotengine.Godot --headless --path /tmp/algoland-pacotes-motor --script res://teste.gd -- --corrompido
```

A fixture usa chave descartável e save exclusivo. Testa download real, manifesto
adulterado, caminhos inválidos assinados, ativação completa, reutilização offline,
compilação do autoload com o patch, tema global e corrupção local. A primeira
execução gráfica captura download, falha e conclusão em quatro tamanhos em
`/tmp/algoland-atualizacao-*.png`, usando as molduras e fontes do jogo, e
confere as margens dos elementos visíveis. Também verifica que falha, pendência
offline e conclusão não liberam a entrada no jogo. A segunda corrompe o pacote de teste
para a terceira verificar a recuperação.
