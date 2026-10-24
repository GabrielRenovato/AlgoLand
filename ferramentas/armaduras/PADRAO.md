# Padrão de conjuntos de armadura — AlgoLand

O Carrasco é a referência funcional. Os próximos conjuntos reutilizam poses, separação das peças, encaixe, matemática de status e validação. A identidade visual e o bônus são definidos para cada set.

## Contrato fixo

| Peça | Categoria/slot | Bit visual | Id do item |
|---|---|---:|---|
| Elmo | cabeca | 1 | elmo_<id> |
| Peitoral e ombreiras | corpo | 2 | peitoral_<id> |
| Luvas/manoplas | luvas | 4 | luvas_<id> |
| Botas e grevas | botas | 8 | botas_<id> |

Máscara completa: 15. Cada item tem id, nível de 1 a 5, raridade, afixos e slot próprios. Uma peça pode ser equipada isoladamente. Misturar sets é permitido; o bônus completo conta somente os quatro itens do mesmo conjunto nos slots corretos. O traje cosmético do F3 não concede o bônus.

Ids em minúsculas sem acentos. Nunca reaproveitar ids ou mudar índices existentes nos saves. Textos do inventário em maiúsculas sem acentos por causa da fonte.

## Arte e animações

- Conceito com quatro vistas em colunas iguais, na ordem: frente, costas, direita, esquerda. Corpo inteiro, pose neutra, fundo transparente, sem armas ou cenário.
- Personagem nativo como referência de proporções e câmera; Carrasco como referência de acabamento. A nova referência define identidade, materiais e cores.
- Corpo compacto, pixels quadrados, contornos e brilhos legíveis. Não aumentar o personagem para encaixar mais detalhe.
- Paleta do compilador: 12 cores, sendo oito para o material principal e quatro para o forro.
- Folhas 512×512, grade 8×8, células 64×64, alfa 0 ou 255. Renderização nearest, sem trilinear ou mipmaps.
- Cada pose acompanha o corpo nativo e a posição da cabeça. Não colar o personagem inteiro parado sobre uma animação de ataque.
- Cada pixel pertence a uma peça. O elmo oculta o cabelo, mantendo a cor do metal.

As 11 páginas obrigatórias são andar, fazenda, forja, sentado, espada, lanca, reacao_um_mao, reacao_lanca, reacao_arco, arco_p2 e arco_p3. São 44 folhas de peças, 11 completas e uma camada transparente de cabelo.

~~~text
assets/personagens/conjuntos/<id>/
  definicao.gd
  cabelo_oculto.png
  andar.png ... arco_p3.png
  elmo/andar.png ... arco_p3.png
  peitoral/andar.png ... arco_p3.png
  luvas/andar.png ... arco_p3.png
  botas/andar.png ... arco_p3.png
~~~

O Carrasco mantém a pasta histórica assets/personagens/ArmaduraCavaleiro para preservar as referências.

## Criar o modelo

Na raiz do projeto:

~~~bash
python3 ferramentas/armaduras/criar_modelo.py \
  --id guardiao --nome "Guardião" --raridade epico \
  --arte res://assets/personagens/conjuntos/guardiao/conceito.png
~~~

Cria manifesto.json, prompt_conceito.txt e LEIAME.md em ferramentas/armaduras/em_preparacao/guardiao. Não registra drops, não copia a arte do Carrasco e não concede itens. A pasta deve ser nova.

Use o prompt para adaptar o design com as referências. Salve o conceito aprovado no caminho arte e guarde a referência e o prompt final.

Revise no manifesto: nome, raridade, onda mínima, chances, preço, cinco níveis de vitalidade/defesa por slot, bônus, paleta e recortes. O novo modelo inicia com bônus nenhum e chance zero, evitando herdar o raio por acidente.

fim_elmo e fim_peitoral delimitam faixas verticais do conceito. Os valores do Carrasco são ponto de partida; conceitos com proporções diferentes precisam de ajuste e revisão visual.

largura_elmo e altura_elmo são dimensões opcionais do recorte na escala nativa, inteiros entre 8 e 20. Sem esses campos, usa 14×17 como no Carrasco. A base do elmo permanece alinhada à gola; reduzir o tamanho não desloca a cabeça.

fracao_largura_elmo recorta horizontalmente a faixa da cabeça; fracao_gola_elmo estreita só os 30% inferiores dessa faixa. Valores opcionais entre 0,25 e 1; o padrão é 1. Isso evita incluir as ombreiras no elmo e permite manter chifres na parte superior.

alinhar_calota e ajustar_calota_corpo são opções booleanas, desativadas por padrão. A primeira alinha o recorte pela chapa, em vez de usar o centro dos chifres. A segunda ajusta os tons e detalhes da chapa ao contorno da cabeça nativa, preservando os chifres. Use quando a base opaca cinza estiver aparecendo fora do elmo; não resolver esse vazamento com uma mancha de cor sólida.

Para elmos fechados, preferir arte_elmo: uma folha isolada de quatro elmos, em frente/costas/direita/esquerda, com transparência somente fora das chapas. elmo_rigido em recortes preserva o visor: só desloca a arte com a cabeça, mantendo a mesma placa nas poses. Não esticar a face a cada quadro nem usar largura dos braços para remodelar o elmo. O teste teste_elmo_rubro.gd compara os pixels visíveis após descontar o movimento da cabeça.

Para preservar uma silhueta estreita, substituir_cabeca no manifesto gera corpo_sem_cabeca/<pagina>.png. Nesse modo o elmo rígido usa somente sua arte, sem suporte ou preenchimento para cobrir a cabeça antiga. Aparencia.corpo escolhe o corpo mascarado quando o elmo está presente; retirando o elmo, restaura o corpo original. As 11 páginas, inclusive os componentes de arco, reação e fazenda, devem usar esse roteamento. O validador confere que apenas a cabeça foi removida e que o corpo ainda visível permanece coberto.

Uma etapa apenas visual pode registrar o traje em Aparencia.ARMADURAS_VISUAIS e acrescentar uma entrada ao fim da lista de roupas. O F3 usa a mesma máscara para conferir as peças. Não registrar drops nem bônus nessa etapa; chances do manifesto ficam em zero. Testes devem encontrar trajes pelo id, sem presumir que o Carrasco sempre será a última entrada.

O F3 usa dropdowns de categoria e ação, com EXECUTAR. CONJUNTOS veste o traje completo, sem controles por peça. As folhas das peças permanecem separadas para a futura integração com itens.

As três entradas completas de CONJUNTOS agora usam EQUIPAR e colocam itens reais nos quatro slots. O F3 reutiliza itens existentes, preserva melhorias e guarda a armadura anterior na mochila; a troca é atômica, sem perda se faltar espaço. A ação retira prévias cosméticas para que os slots governem o visual e salva o inventário. Métodos de prévia continuam separados para testes. Mordomo (id cavalheiro) é comum, cai como os demais e também está no F3. Com quatro peças reais no nível 1, cada acerto tem 10% de chance de congelar o alvo por 2 segundos, com recarga compartilhada de 2 segundos. Carrasco e Rubro mantêm seus dados. Roteamento de cabelo e cartola recebe a raiz do elmo real nas 11 páginas, inclusive em combinações de sets.

## Gerar e validar

Neste ambiente, Godot via Flatpak:

~~~bash
flatpak run org.godotengine.Godot --headless --path . \
  --script ferramentas/armaduras/gerar_conjunto.gd -- \
  res://ferramentas/armaduras/em_preparacao/guardiao/manifesto.json

flatpak run org.godotengine.Godot --headless --path . \
  --script ferramentas/armaduras/validar_conjunto.gd -- \
  res://ferramentas/armaduras/em_preparacao/guardiao/manifesto.json

flatpak run org.godotengine.Godot --headless --path . --editor --import --quit
~~~

Depois de gerar ou alterar as folhas das peças, gravar a cobertura com `flatpak run org.godotengine.Godot --headless --path . --script ferramentas/armaduras/gerar_coberturas.gd -- res://assets/personagens/conjuntos/<id>/` (sem argumentos, processa todos os conjuntos) e reimportar. Ela cria cobertura/<pagina>.png; sem esses arquivos o jogo calcula a cobertura na hora e trava cerca de 200 ms por página ao equipar uma peça pela primeira vez.

Gera as folhas e definicao.gd, com nomes, categorias, status, preços e parâmetros do bônus. Para atualizar só o balanceamento, acrescente --somente-dados após o manifesto. O comando antigo ferramentas/personagem/gerar_set_cavaleiro.gd continua válido; sem argumentos, usa modelos/carrasco.json.

O Carrasco usa a definição gerada por meio de conjunto_carrasco.gd; altere seu manifesto e regenere os dados. Não editar seus dados gerados à mão.

O validador exige grade correta, peças independentes, recomposição exata, cobertura do corpo, ausência de sobreposição e pixels sem suavização. Compila o cadastro e confere seu manifesto. Uma falha retorna código diferente de zero.

Inspeção visual continua necessária: caminhada/corrida, quatro direções, ataques, arco, esquiva, ferido, fazenda, forja e sentado. O compilador adapta o conceito; poses difíceis podem precisar de ajustes artísticos.

Trajes de tecido com chapéu aberto usam modo_visual=tecido, substituir_cabeca=false e recortes.fim_cartola anterior a fim_elmo. A cartola é recortada sem a face do conceito e acompanha a cabeça; casaco e botas acompanham a silhueta animada da roupa nativa. O corpo original permanece visível no rosto, portanto o validador exige cobertura abaixo da cabeça. Aparencia.cabelo mantém o estilo e a cor escolhidos somente abaixo da copa e fora da aba. Não incorporar cabelo recolorido na peça do chapéu. O Mordomo (id cavalheiro) é a referência desse modo, com peças reais lendárias disponíveis pelo F3 e bônus de congelamento.

Chapéus abertos precisam de Aparencia.aplicar_cartola nas camadas do jogador e dos componentes de arco, reação e fazenda. A camada de cartola acompanha a roupa e fica acima do cabelo antes de cada desenho, inclusive quando a animação muda z_index ou flip_h. Não alterar a ordem da roupa inteira para levantar só o chapéu, nem herdar a tintura do cabelo.

Usar arte_elmo com as quatro cartolas completas para preservar copa, faixa e aba. encaixe_cartola indica a altura da aba em relação ao topo do cabelo nativo; o Cavalheiro usa 9 com altura 14, sem cortar o topo em nenhuma pose. A máscara do cabelo segue a borda da aba por coluna, evitando faixas de pele exposta. A copa é ancorada no topo do crânio, sem o deslocamento pelo nariz nos perfis. Cabelo já colorido e cartola são compostos na mesma camada e seguem o quadro e o espelhamento da roupa. Ocultar somente o desenho do cabelo original com self_modulate.a=0 e restaurá-lo ao retirar o chapéu. A pose nativa idle_up usa um quadro divergente de cabelo. O validador confere a altura íntegra da cartola por célula; a prévia real em previa_cartola_real.gd usa o AnimationPlayer original, sem saves.

## Encaixe obrigatório

A âncora das armaduras Raven usa o crânio do corpo, localizado nos sete primeiros pixels de altura da região do cabelo. Não centralizar pelo contorno da franja, pelo nariz ou pela largura total dos enfeites do capacete. `gerar_conjunto.gd:ancora_cabeca_raven` mantém esse marco nas quatro direções; `testes/teste_alinhamento_armaduras_raven.gd` confere repouso, cabelo assimétrico e deslocamento da cabeça. Após alterar o encaixe, regenerar as páginas, os recortes Web e a corrida/fazenda pelo gerador compartilhado e revisar com `revisar_alinhamento_raven.gd` em projeto com save isolado.

A armadura substitui a região da roupa que cobre. Apenas sobrepor pixels à roupa antiga deixava mangas, capas e riscos vermelhos aparecendo.

Para um set, usar Aparencia.compor_armadura(pagina, mascara, indice_roupa_base, raiz_sprites). Com quatro peças, substitui a roupa inteira. Nas combinações parciais, limpa a região correspondente antes de desenhar a chapa.

Para misturar sets, usar Aparencia.compor_pecas_armadura(pagina, indice_roupa_base, raizes_por_peca):

~~~gdscript
var raizes_por_peca := {
    "elmo": "res://assets/personagens/conjuntos/guardiao/",
    "peitoral": "res://assets/personagens/conjuntos/carrasco/",
}
var textura := Aparencia.compor_pecas_armadura("andar", roupa_atual, raizes_por_peca)
~~~

O jogador deve passar as peças realmente equipadas a todas as páginas, incluindo arco, reação e fazenda. Trocar só uma peça também atualiza texturas e visibilidade do cabelo. Cache distingue pasta, página, roupa base e combinação.

## Registro no jogo

### Acabamento de apresentação

Os moldes, máscaras, cobertura e folhas independentes do contrato continuam em 512×512. A apresentação refinada usa folhas de 1024×1024, células de 128×128 e escala 0,5, preservando o tamanho no mundo. `gerar_conjunto.gd` também gera essas folhas em `assets/personagens/refinado/conjuntos/<id>/` com o manifesto compartilhado. Para atualizar somente esse acabamento, sem regenerar dados ou moldes, usar `--somente-acabamento`; para validar a apresentação junto do conjunto nativo, acrescentar `--acabamento` a `validar_conjunto.gd`.

`codigo/dados/acabamento_refinado.gd` (fica em `codigo/` porque o jogo também o usa; `ferramentas/` não entra na exportação) refina a superfície completa e separa suas quatro peças pelas máscaras nativas. O validador exige recomposição exata, transparência binária, exclusividade e a mesma cobertura ampliada por nearest. As máscaras de corpo/cabelo e os arquivos de cobertura nativos permanecem válidos. As roupas comuns são compiladas por `ferramentas/personagem/preparar_roupas_refinadas.gd`, com um cadastro dos índices e fontes; repetir esse comando após atualizar os moldes de roupa.

No jogo, `Aparencia.aplicar_roupa` aplica a folha e a escala corretas em todas as ações; `roupa_refinada` preserva o compositor nativo para limpar a roupa sob peças parciais e então desenha as superfícies refinadas. Misturas reutilizam as peças já compiladas. `roupa` continua fornecendo os moldes nativos para as ferramentas. A cartola refinada acompanha a escala e o quadro da roupa, sem herdar a cor do cabelo.

A geração prepara os recursos; registrar o novo conjunto ainda é uma etapa explícita:

| Integração | Responsabilidade |
|---|---|
| equipamentos.gd | Consultar a definição para status e preço. |
| dados_item.gd e icones_itens.gd | Nome e ícone da própria peça, recortado ao conteúdo. |
| equipamento_drop.gd | Incluir no sorteio com onda mínima, raridade e categoria corretas. |
| jogador.gd e aparencia.gd | Slots, status sem acumulação e roteamento das peças nas 11 páginas. |
| item_ui.gd | Raridade, afixos, contador de peças e descrição do bônus. |
| painel_debug.gd | Drop dos quatro itens reais e prévia visual identificada. |

Reutilizar definicao.gd e base_conjunto_armadura.gd. Não copiar a matemática de máscara, quantidade, chances e níveis para cada set. Quando houver outros conjuntos, centralizar o registro dos tipos em vez de espalhar listas divergentes nas telas.

O manifesto descreve um bônus, mas não implementa uma habilidade nova. Raio, cura, fogo ou invocação precisam de ação de combate e testes próprios. Um set declarado como fogo não deve disparar o raio do Carrasco.

conjuntos_armadura.gd centraliza os tipos reais, raízes por peça e intervalos de sorteio. Os três conjuntos (Carrasco, Rubro e Mordomo) são Comuns, disponíveis desde a onda 1, sempre no nível 1. Só chefes soltam peças, por chance (nada garantido): o equipamento do chefe tem a chance do manifesto (10% por conjunto) de ser uma peça daquele conjunto; mobs e mutantes nunca soltam. O poder vem da bigorna (ouro, onda e 1 Moeda de Forja por nível, ver InventarioJogador.moedas_forja e Equipamentos.dados_melhoria_conjunto). A Moeda de Forja cai de qualquer chefe com 5% de chance. No nível 5 a bigorna faz a ascensão de raridade (Conjuntos.ascender): sobe um degrau até o lendário e soma um afixo aleatório novo (Raridades.sortear_afixo_extra), com custo em Equipamentos.CUSTOS_ASCENSAO e 1 moeda. A raridade é por instância e o save a preserva; não forçar a raridade do cadastro ao carregar.

Bônus por quantidade (base_conjunto_armadura.gd): 2 ou 3 peças do mesmo conjunto dão metade do efeito, 4 dão o completo, e cada nível acima do 1 soma 25% (nível 5 = 2x, contado pela peça mais fraca). Vale para chance de raio/congelamento, dano do raio e percentuais de status. Rubro tem bonus.tipo=status, defesa=0.1 e vitalidade=0.1 em 4/4 no nível 1. Os multiplicadores ficam separados dos status sem conjunto, para manter troca, melhoria e bônus de loja sem acumulação. Não salvar o aumento novamente como status base. Novos conjuntos herdam essas regras: definir raridade, chances e bônus no manifesto, sem copiar a matemática de peças e nível.

Efeitos por acerto usam o caminho comum de espada/lança/flecha, chance e recarga explícitas, itens reais equipados e proteção contra encadeamento infinito. Dano aliado não atinge o jogador. Retirar uma peça impede novas ativações; trocar de volta restaura os status.

Chances do manifesto são condicionais ao drop de equipamento. Cada conjunto: 5% de 1,5% = 0,075% por morte normal; 10% de 6% = 0,6% por mutante; 10% de 100% = 10% por chefe. Com mais sets, definir seus pesos sem transformar cada candidato em um drop extra independente.

## Conferência final

1. Validar o manifesto, as folhas e o cadastro.
2. Ver o personagem composto com roupa vermelha, roupa larga/capa e peças isoladas.
3. Conferir direções, ações, peça ausente, mudança de cabelo e mistura com o Carrasco.
4. Recolher drops reais, equipar/desequipar os slots e salvar/carregar.
5. Verificar bônus com 4/4, metade com 2/4 e 3/4, ausência com 1 peça de cada set misturado, chance desfavorável, recarga, arma e flecha reais.
6. Trocar equipamentos várias vezes e conferir que vida, defesa e afixos voltam aos valores anteriores.
7. Rodar testes de inventário e raridade após mudar o cadastro.

Testes da arena gravam saves. Usar cópia do projeto com config/name="AlgoLand testes Carrasco", como teste_carrasco.gd exige. Não usar a partida do usuário.

## Referências

modelos/carrasco.json e modelos/prompt_conceito.txt são os modelos de dados e arte. gerar_conjunto.gd e validar_conjunto.gd são o pipeline compartilhado. padrao_armadura.gd define o contrato; base_conjunto_armadura.gd contém as regras comuns. teste_set_cavaleiro.gd e teste_carrasco.gd são as regressões de sprites e gameplay.

O Rubro preserva a cabeça original: substituir_cabeca=false é registrado na definição gerada, e Aparencia.corpo respeita essa opção mesmo quando há folhas antigas de corpo_sem_cabeca na pasta. A calota precisa cobrir a cabeça real na caminhada; apagar a cabeça para encaixar um capacete menor não passa no teste do Rubro. borda_calota=1 acrescenta um contorno escuro de um pixel às chapas (não aos espigões); deslocamento_vertical_elmo define quatro ajustes inteiros entre -3 e 3 para alinhar cada vista. O visor original é preservado por cima do contorno.
