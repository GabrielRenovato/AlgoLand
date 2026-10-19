extends RefCounted

## Conversas de encontro: as vozes pertencem à dupla, e os assuntos consultam o mundo real.
## Os textos seguem a fonte sem acentos usada nos balões da vila.
const Clima := preload("res://codigo/dados/estados_clima.gd")
const Conversa := preload("res://codigo/cidade/conversa_moradores.gd")
# A ordem da chave define os interlocutores das falas alternadas.
const DUPLAS := {
	"mercador|ferreiro": ["Ivo, tenho madeira nova na venda. Esta quase reta.", "Quase reta tambem e o formato da ultima prateleira que voce pediu para eu consertar.", "Entao ja sabe trabalhar com o meu estoque!", "Separo o esquadro. Voce separa a madeira que nao faz curva."],
	"curandeira|ferreiro": ["Ivo, mostrou a mao para mim ou escondeu outra queimadura?", "Mostrei as duas. A senhora conta os dedos toda vez.", "E pretendo continuar encontrando dez.", "Por isso deixei as luvas perto da porta. Hoje eu lembrei."],
	"bardo|ferreiro": ["Ivo, pensei num ritmo novo para suas marteladas!", "O ferro continua preferindo o antigo. Ele e um publico conservador.", "Posso cantar baixo enquanto voce trabalha.", "Baixo e uma tonalidade que eu aprecio muito."],
	"mistica|ferreiro": ["As faiscas da sua forja parecem pequenas constelacoes, Ivo.", "As minhas tem a vantagem de avisar quando caem no sapato.", "Talvez eu desenhe uma no meu mapa.", "Desenhe longe da borda. Nem no papel gosto de desperdicar material."],
	"lia|ferreiro": ["Ivo, a dobradica da sede voltou a cantar.", "Vou conferir. Da ultima vez era o Caio atras da porta.", "Desta vez eu conferi antes de pedir.", "Entao levo oleo e deixo os protetores de ouvido em casa."],
	"bento|ferreiro": ["A enxada voltou boa, Ivo. Voce preservou o cabo.", "Sei reconhecer uma peca que ja encontrou a mao certa.", "Foi presente da minha companheira. Tem historia ali.", "Entao na proxima manutencao voce me conta mais um pedaco."],
	"mercador|curandeira": [
		"Rosa, separei seu mel. Mas voce levou dois potes na semana passada; a vila inteira ficou gripada?",
		"Um foi para o xarope. O outro virou bolo para quem ficou esperando na enfermaria.",
		"Entao era aquele cheiro! Eu achei que voce tinha inventado um remedio de dar fome.",
		"Passe la depois que fechar. Guardei uma fatia, mas so se voce parar de pular o almoco."
	],
	"mercador|bardo": [
		"Caio, achei uma pagina inteira de fiado seu. Tem ate uma corda de alaude no meio dos paes.",
		"Uma corda arrebentou bem no refrao! Eu nao podia abandonar a plateia naquele momento.",
		"A plateia eram tres pardais e o Bento. Mas tocar na porta da venda trouxe freguesia.",
		"Entao combinamos assim: eu toco depois que voce fechar o caixa, e voce separa o cafe."
	],
	"mercador|mistica": [
		"Estela, aquele viajante perguntou se sua bola de cristal previa o preco das mercadorias.",
		"Se previsse, eu teria comprado o cha antes do seu ultimo aumento.",
		"Foi o frete! A estrada anda dificil. Estou juntando as encomendas para fazer uma viagem so.",
		"Me avise antes de partir. Tenho uma carta para mandar e prefiro que ela viaje com alguem conhecido."
	],
	"mercador|lia": [
		"Lia, chegaram os tecidos da comunidade. Voce quer tudo na sede ou separo uma parte?",
		"Deixe os mais resistentes para os consertos. Os coloridos podem esperar a decoracao da praca.",
		"Vou etiquetar as caixas. Da ultima vez o Caio quase fez uma cortina com pano de remendo.",
		"E ainda chamou de cenario. Obrigada, Tomas; passo para conferir quando voce terminar de atender."
	],
	"mercador|bento": [
		"Bento, um fregues reclamou que suas cenouras vieram tortas. Eu disse que ele ia cortar mesmo.",
		"A terra tinha umas pedras naquele canteiro. O gosto nao mudou, mas vou afofar melhor.",
		"Guarde as tortinhas para mim. Ficam na frente da banca, e todo mundo para para olhar.",
		"So nao cobre mais por chamar de cenoura de exposicao. Vou conferir sua placa."
	],
	"curandeira|bardo": [
		"Caio, voce esta pigarreando de novo. Ficou cantando depois que todo mundo foi embora?",
		"Eu estava tentando acertar o ultimo verso. A sala vazia tem uma acustica maravilhosa.",
		"E nao te oferece agua. Vou separar o xarope, mas hoje voce precisa fazer uma pausa.",
		"Esta bem. Um intervalo para o cha tambem cria expectativa. Mas nao conte ao Tomas que eu obedeci."
	],
	"curandeira|mistica": [
		"Estela, encontrei a tigela que levei para voce ainda na janela. A sopa pelo menos foi comida?",
		"Foi, Rosa. Deixei a tigela ali para lembrar de devolver e acabei olhando o ceu a noite inteira.",
		"Entao traga quando vier buscar mais. Eu prefiro lavar uma tigela a descobrir que voce nao jantou.",
		"Desta vez eu levo o pao e como com voce. As estrelas podem esperar um pouco."
	],
	"curandeira|lia": [
		"Lia, voce escreveu descansar na sua lista ou so escreveu descanso dos outros?",
		"Eu ia parar depois de conferir o mural. Apareceram dois reparos e perdi a hora.",
		"O mural fica de pe sem voce por alguns minutos. Quero te ver sentada tomando um cha.",
		"Combinado. Mas voce senta comigo; cuidar da vila tambem inclui cuidar da curandeira."
	],
	"curandeira|bento": [
		"Bento, as mudas que voce trouxe pegaram. A hortela ja esta tentando tomar o canteiro todo.",
		"Ela faz isso. Deixe num vaso mais fundo, separado das outras ervas, que fica mais facil cuidar.",
		"Vou trocar de vaso antes que ela invada a camomila. Posso guardar umas mudas para voce?",
		"Pode. Levo um pouco de terra boa na proxima visita e a gente divide sem machucar a raiz."
	],
	"bardo|mistica": [
		"Estela, preciso de uma palavra bonita para o silencio antes de uma batalha. Pressagio serve?",
		"Serve, mas nem todo silencio anuncia perigo. As vezes e so alguem tentando escutar.",
		"Isso e melhor que o meu verso inteiro. Posso usar? Prometo nao transformar voce numa feiticeira malvada.",
		"Pode usar. E deixe uma pausa antes do refrao, para a plateia ouvir o silencio de verdade."
	],
	"bardo|lia": [
		"Lia, pensei em tocar no coreto antes de abrir a taverna. Uma apresentacao pequena, sem discurso.",
		"Pequena para voce e quantas cancoes? Da ultima vez o Tomas fechou a venda no segundo ato.",
		"Duas cancoes e um agradecimento breve. Eu mesmo ajudo a guardar os bancos depois.",
		"Assim eu apoio. Vou avisar no mural e deixar o caminho livre para quem estiver de passagem."
	],
	"bardo|bento": [
		"Bento, voce sai do coreto bem quando vou tocar a ultima cancao. Ela e tao ruim assim?",
		"Nao. E a hora em que eu costumo cuidar das ferramentas antes de escurecer.",
		"Eu estava prestes a reescrever tudo. Posso tocar essa primeiro da proxima vez?",
		"Pode. Levo uma caneca e fico mais um pouco. Mas nao precisa fazer anuncio quando eu chegar."
	],
	"mistica|lia": [
		"Lia, a luz do portal chega ate a janela da sede? Quero comparar o que vemos de cada lado da praca.",
		"Chega, principalmente quando apago a lamparina. Posso anotar a hora e o que muda.",
		"Isso ajuda mais que um palpite meu. Quero separar o que acontece sempre do que e so impressao.",
		"Vou deixar um caderno na janela. Depois olhamos juntas, sem assustar a vila com conclusoes apressadas."
	],
	"mistica|bento": [
		"Bento, aquelas folhas fecharam antes de escurecer. Achei que fossem esperar o fim da tarde.",
		"Elas respondem a luz e a umidade. Olhar a mesma planta todo dia ensina mais que arrancar para examinar.",
		"Vou desenhar como ficam, sem mexer. Voce pode me mostrar outras que fazem isso?",
		"Posso. So venha sem pressa. Quando a gente para de procurar um sinal, comeca a perceber os pequenos."
	],
	"lia|bento": [
		"Bento, quero arrumar o jardim perto da praca, mas nao quero pisar nas mudas que voce ja plantou.",
		"Vou marcar as bordas com uns gravetos. A parte do meio precisa ficar livre para a gente passar.",
		"Eu cuido das placas e chamo quem puder ajudar. Voce prefere fazer aos poucos?",
		"Prefiro. Um canteiro bem cuidado por vez. Depois a gente senta e ve o que ainda esta faltando."
	],
}
const TEMPO := {
	Clima.Estado.LIMPO: [
		"Com o ceu aberto assim, da vontade de resolver tudo na rua de uma vez.",
		"Da, mas vou dividir as tarefas. Quero aproveitar um pouco desse tempo sem ficar so correndo.",
		"Tem razao. A praca fica diferente quando a gente para para olhar, em vez de so atravessar.",
		"Entao vamos terminar este assunto aqui. O resto pode esperar uns minutos."
	],
	Clima.Estado.NUBLADO: [
		"Essas nuvens estao cobrindo a vila inteira. Ainda bem que encontrei voce por aqui.",
		"Eu trouxe o que precisava fazer na rua. Se comecar a chover, nao preciso sair correndo de novo.",
		"Nao da para saber se vai abrir ou fechar mais. Melhor nao deixar nada secando la fora.",
		"Vou lembrar disso quando voltar. Por enquanto ainda da para conversar sem se molhar."
	],
	Clima.Estado.CHUVA_LEVE: [
		"Essa chuva fina parece pouca, mas ja molhou a barra da minha roupa inteira.",
		"Pelo menos a gente lembrou da capa. Vou passar pela rua de pedra para nao levar barro para casa.",
		"Boa ideia. Quero guardar minhas coisas num lugar seco antes que a chuva aperte.",
		"Vamos sem pressa, mas sem demorar demais por aqui. Terminamos o papo no caminho."
	],
	Clima.Estado.CHUVA_FORTE: [
		"Com essa chuva forte mal consigo ouvir voce daqui. Vamos falar perto de um abrigo?",
		"Vamos. Eu so sai porque tinha uma coisa para resolver, mas ja estou querendo voltar.",
		"Tambem vou encurtar o passeio. As pedras da rua estao escorregadias, melhor olhar onde pisa.",
		"Assim que terminarmos, cada um segue para casa. A conversa pode continuar quando o tempo melhorar."
	],
	Clima.Estado.TEMPESTADE: [
		"Daqui de dentro da para ouvir os trovoes. Ainda bem que encontramos abrigo.",
		"Eu nao vou me arriscar na rua agora. O que faltou fazer fica para depois do temporal.",
		"Se alguem bater na porta, a gente abre. Ninguem merece ficar la fora com esse vento.",
		"Combinado. Enquanto esperamos, pelo menos temos companhia."
	],
	Clima.Estado.NEVE_LEVE: [
		"A neve esta caindo devagar, mas minhas maos ja estao geladas.",
		"As minhas tambem. Estou fazendo so o necessario antes de voltar para um lugar aquecido.",
		"Eu gosto de ver os flocos na praca. So nao quero perder a sensibilidade dos dedos para isso.",
		"A gente olha mais um pouco e volta. Uma caneca quente vai fazer falta daqui a pouco."
	],
	Clima.Estado.NEVE_FORTE: [
		"A neve engrossou. A rua esta ficando dificil de enxergar, ate nos trechos que eu conheco.",
		"Entao nada de inventar atalho. Vou ficar pelo caminho principal e procurar abrigo.",
		"Melhor avisar quem ainda estiver de saida. Nem todo mundo percebe como mudou la fora.",
		"Avisamos, sim. Hoje companhia e um lugar aquecido valem mais que terminar os afazeres."
	],
}
const ESTACOES := [
	["Na primavera sempre aparecem coisas novas nos canteiros. Estou tentando prestar mais atencao nelas.", "Eu tambem. A vila parece acordar aos poucos, e cada jardim fica de um jeito.", "Vou reservar uma parte do dia para olhar, sem levar uma lista de tarefas.", "Boa ideia. Se encontrar alguma coisa bonita, me chame antes de sair correndo."],
	["Neste verao estou deixando as caminhadas mais demoradas para quando o sol baixar.", "Eu saio com agua e tento fazer uma pausa na sombra. A pressa nao ajuda com esse calor.", "Talvez a gente se encontre mais tarde na praca. Agora quero terminar so o necessario.", "Combinado. E sem esquecer de beber agua enquanto trabalha."],
	["No outono basta limpar a entrada e ja tem folha de novo. Estou quase aceitando a decoracao.", "Eu tiro as que ficam no caminho. As outras podem ficar um pouco; gosto dessa cor na vila.", "Assim sobra tempo para outra coisa. Estava mesmo querendo passar mais devagar pela praca.", "Se eu estiver por la, me chame. Uma pausa faz bem antes de voltar para casa."],
	["No inverno ate uma caminhada curta faz a gente procurar uma lareira.", "Por isso gosto de encontrar os vizinhos la dentro. Da para conversar sem ficar batendo os dentes.", "Vou tentar terminar os afazeres cedo e deixar um tempo para isso.", "Faca isso. Um pouco de companhia ajuda nesses dias em que a vila fica mais quieta."],
]

static func montar(a: String, b: String, contexto: Dictionary, rodada := 0) -> Array[Dictionary]:
	var chave := a + "|" + b
	var invertida := not DUPLAS.has(chave)
	if invertida:
		chave = b + "|" + a
	if not DUPLAS.has(chave):
		return []
	var nomes := chave.split("|")
	var pessoal: Array = DUPLAS[chave]
	var blocos: Array = [pessoal.slice(0, 2)]
	# Alterna assuntos a cada reencontro, sempre usando o clima atual, nunca uma previsão inventada.
	if rodada % 3 != 2:
		blocos.append(TEMPO.get(int(contexto["clima"]), TEMPO[Clima.Estado.LIMPO]))
	else:
		blocos.append(ESTACOES[clampi(int(contexto["estacao"]), 0, 3)])
	if rodada % 2 == 0 or int(contexto["vencida"]) > 0:
		blocos.append(_arena(contexto))
	blocos.append(pessoal.slice(2, 4))
	var resultado: Array[Dictionary] = []
	for bloco in blocos:
		for i in bloco.size():
			resultado.append({"dono": nomes[i % 2], "texto": String(bloco[i]).format(contexto)})
	return resultado

static func _arena(ctx: Dictionary) -> Array:
	if int(ctx["chefe"]) > 0:
		return ["E aquela vitoria contra {nome_chefe}? Ainda estou tentando imaginar como foi enfrentar uma criatura dessas.", "Vencer esse chefe levou treino. Quero ouvir o relato com calma, sem aumentar a historia a cada vez que contamos.", "O maior andar concluido ja e o {vencida}. Isso nao quer dizer que os proximos vao ser faceis.", "Nao mesmo. Vou dar os parabens quando encontrar quem lutou, mas tambem lembrar de descansar antes de voltar."]
	if int(ctx["vencida"]) >= 5:
		return ["Soube que ja concluiram o andar {vencida} na arena. Cada vez que alguem volta eu quero saber como foi.", "Eu tambem. Mas chegar longe nao e o mesmo que voltar descansado; deve ser uma luta atras da outra.", "Cada andar tem um guardiao. Acho melhor preparar as coisas antes, em vez de contar so com coragem.", "Pocoes, equipamento e uma pausa entre as tentativas. Vamos lembrar disso quando o assunto surgir."]
	if int(ctx["vencida"]) > 0:
		return ["Ja venceram o andar {vencida}. Parece pouco quando a gente fala daqui, longe daquela arena.", "Para quem estava la, foi uma batalha inteira. Prefiro perguntar como foi do que dizer que era facil.", "Concordo. E melhor aprender a voltar em seguranca agora do que se apressar para chegar mais longe.", "Quando encontrar quem lutou, vou ouvir primeiro. As vezes a pessoa quer contar a historia sem receber um sermao."]
	return ["Voce tambem fica olhando para o portal quando alguem se aproxima? Ainda nao tivemos noticia de um andar vencido.", "Fico. A gente ve a entrada daqui, mas nao sabe o que a pessoa vai encontrar depois dela.", "Espero que ninguem confunda coragem com pressa. A vila pode ajudar na preparacao antes da primeira tentativa.", "E pode receber quem voltar, mesmo que precise tentar de novo. Ninguem devia achar que so merece isso depois de vencer."]

static func duracao(texto: String) -> float:
	return clampf(1.0 + texto.length() / 20.0, 3.5, 9.0)
