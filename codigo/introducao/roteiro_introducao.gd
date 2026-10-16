extends RefCounted

const RESGATE: Array[String] = [
	"Ei! Voce esta inteiro? Sou Bento, da Vila das Flores.",
	"Isto e a Arena do Limiar. Daqui saem criaturas em ondas, cada vez mais fortes.",
	"Essa espada e esse escudo eram de quem guardava este lugar. Agora sao seus.",
	"Aqui nao e seguro. Vou na frente: quando eu sumir, entre no portal."
]
const VILA: Array[String] = [
	"Bem-vindo a Vila das Flores! O selo nas pedras ainda protege nossas casas.",
	"O Limiar chamou voce para segurar as criaturas. Mas ninguem vive so de batalha.",
	"Tomas vende armas, Rosa cuida dos feridos, Caio canta lendas e Lia organiza tudo.",
	"Se cair na arena, voce acorda na enfermaria da Rosa. A fazenda e as melhorias ficam.",
	"Tem uma fazenda vazia a oeste. Vamos la, e so me acompanhar."
]
## Depois da primeira onda vencida no jogo livre: Bento explica a janela entre as ondas e as moedas (aula_arena.gd)
const AULA_ARENA: Array[String] = [
	"Primeira onda vencida! Deixa eu te explicar o que vem agora.",
	"Essas moedas sao ouro. Ele so vale nesta partida, entao gaste sem do.",
	"Sementes e equipamentos que os monstros soltam voam ate voce no fim da onda.",
	"Se a mochila encher, o equipamento vai para o SAQUE da janela: la voce escolhe o que levar ou vender.",
	"Na janela entre as ondas, MELHORIAS vende totens que te fortalecem ate o fim da partida.",
	"Na BIGORNA a arma sobe de nivel. Pecas de conjunto pedem moeda de forja, que vem dos chefes.",
	"Em ENCANTAR sua arma ganha fogo, gelo ou raio.",
	"Pronto para mais? Pise no circulo brilhante do chao e a proxima onda comeca.",
	"O portal reabre a janela e leva voce para a vila. A cada dez ondas vem um chefe.",
	"Se cair, sua luta vira Brasas. A Lia troca Brasas por melhorias permanentes.",
	"Era isso. Boa sorte la dentro!"
]
## Paradas acessíveis, junto aos sistemas que já existem; não promete funções apenas decorativas.
const PARADAS := [
	{"nome": "CONHECA SUA FAZENDA", "ponto": Vector2(912, 294), "falas": [
		"Esta e a sua fazenda. A trilha a leste volta para a vila.",
		"O relogio fica no canto da tela. Depois desta visita, os dias voltam a passar."
	]},
	{"nome": "LIMPAR O TERRENO", "ponto": Vector2(744, 300), "ferramentas": ["machadinha", "picareta"], "tarefas": ["cortar", "quebrar"], "falas": [
		"Primeiro, abrir espaco. A machadinha corta arvores; a picareta quebra pedras.",
		"Escolha a ferramenta na barra e use USAR. Corte uma arvore e depois quebre uma pedra."
	]},
	{"nome": "PREPARAR A HORTA", "ponto": Vector2(400, 328), "ferramentas": ["enxada"], "tarefas": ["arar"], "falas": [
		"Aqui e a area de plantio. Use a enxada para arar um quadrado de terra."
	]},
	{"nome": "SEMENTES E AGUA", "ponto": Vector2(352, 328), "ferramentas": ["regador"], "sementes": true, "tarefas": ["plantar", "regar"], "falas": [
		"Tome sementes de cenoura e morango. As duas crescem na primavera.",
		"Plante uma cenoura no canteiro e regue. O regador se enche no lago da fazenda.",
		"Regue todo dia, ou deixe a chuva regar. Cada planta so cresce na sua estacao."
	]},
	{"nome": "DA HORTA PARA A ARENA", "ponto": Vector2(432, 286), "tarefas": ["colher"], "falas": [
		"Separei uma cenoura madura para voce treinar. Chegue perto dela e use COLHER.",
		"Colheitas viram pocoes com a Rosa. Na arena, beba com BEBER quando precisar."
	]},
	{"nome": "UM LUGAR PARA DESCANSAR", "ponto": Vector2(376, 261), "falas": [
		"Esta casa agora e sua. A cama passa o dia e recupera suas forcas.",
		"Nao fique na rua depois das duas da manha, ou voce desmaia de cansaco.",
		"Vou voltar para a vila. Seja bem-vindo ao seu novo lar!"
	]}
]
