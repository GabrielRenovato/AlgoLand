extends RefCounted

## Casa própria do outro lado da ponte, com três quartos, sala e cozinha.
## Helena permanece sentada; Clara empurra a cadeira nos deslocamentos.
static func agenda(id: String, hora: float, estacao: int, clima: int) -> Dictionary:
	if id == "osvaldo" and int(Fazenda.galinheiro.obra) > 0 and hora >= 8 and hora < 17:
		var ponto_obra := Vector2(144,236) if hora < 12 else Vector2(208,236)
		return {"local":"fazenda","ponto":ponto_obra,"atividade":"Construindo o galinheiro na fazenda","construindo":true}
	if id == "osvaldo" and (hora >= 22 or hora < 6):
		return {"local":"carpintaria","ponto":Vector2(64,124),"atividade":"Dormindo em casa","dormindo":true,"cama":Vector2(64,112),"altura_cama":58.0,"ajuste_travesseiro":Vector2(0,14)}
	var pontos := {"osvaldo":Vector2(264,400),"helena":Vector2(76,450),"clara":Vector2(112,450)}
	var atividade := "Descansando em familia"
	var ponto: Vector2 = pontos[id]
	if hora >= 8 and hora < 17:
		atividade = "Trabalhando nas encomendas de carpintaria" if id == "osvaldo" else "Bordando e conversando" if id == "helena" else "Ajudando a mae e preparando seus bordados"
	if hora >= 10 and hora < 12 and estacao != 3 and clima in [-1,0,1]:
		if id in ["helena","clara"]:
			return {"local":"cidade","ponto":Vector2(392,310) if id == "helena" else Vector2(418,310),"atividade":"Passeando na praca com Clara" if id == "helena" else "Levando Helena para passear na praca"}
	if hora >= 17 and hora < 20:
		ponto = Vector2(472,476) if id == "osvaldo" else Vector2(408,460) if id == "helena" else Vector2(544,476)
		atividade = "Tomando cha em familia"
	if hora >= 22 or hora < 6:
		atividade = "Repousando no quarto" if id == "helena" else "Descansando em casa"
		ponto = Vector2(304,136) if id == "helena" else Vector2(104,136) if id == "osvaldo" else Vector2(512,136)
	return {"local":"carpintaria","ponto":ponto,"atividade":atividade}

const FALAS := {
	"osvaldo": {
		"boas_vindas":"Sou Osvaldo, carpinteiro. Tenho 65 anos e ainda me empolgo com o cheiro da madeira. Minha esposa e a Helena; nossa filha Clara mora conosco. Nossa casa e a oficina ficam depois da ponte, a leste da vila. As galinhas ficam no cercado em frente.",
		"saudacoes":{"novo":["{periodo}! Entre, a serragem eu varro depois."],"conhecido":["{periodo}! O que vamos construir hoje?"],"amigo":["Tem cafe e madeira boa esperando por voce."]},
		"papo":[{"texto":"Uma casa boa tem passagem larga e piso sem desnivel. Foi a Helena quem me ensinou a enxergar o que eu deixava passar."},{"texto":"Clara trouxe um desenho para a bancada. Diz que e simples. Todo projeto que comeca assim me ocupa a semana."},{"texto":"Helena escolhe os tecidos e eu preparo as molduras. Fazemos uma boa dupla ha muito tempo."}],
		"dicas":[{"chave":"aves","prioridade":25,"texto":"O galinheiro comeca com duas galinhas e um galo. Retire feno no deposito, selecione na barra e jogue no comedouro. Recolha os ovos diretamente nos ninhos."},{"chave":"ampliar","prioridade":20,"texto":"Traga madeira e pedra para construir. Depois amplio para oito e doze aves. Cada obra tem seu prazo; nao se cobra duas vezes."}],
		"historias":[{"amizade":3,"texto":"Aos 65 anos, eu ainda erro medida. So que agora culpo os oculos antes de culpar a madeira."},{"amizade":6,"texto":"Quando a Helena passou a usar a cadeira, refizemos a casa juntos. Ela escolheu cada mudanca. A casa e dela tanto quanto minha."}],
		"baloes":[{"texto":"Madeira boa merece paciencia."}]},
	"helena": {
		"boas_vindas":"Helena, prazer. Tenho 55 anos, gosto de bordar e sei mais historias desta vila do que o Osvaldo admite. Uso cadeira de rodas por causa da ELA. A Clara me ajuda nos cuidados do dia a dia. Pode puxar assunto comigo tambem!",
		"saudacoes":{"novo":["{periodo}. Venha me fazer companhia."],"conhecido":["Olhe quem chegou! Trouxe novidades?"],"amigo":["Guardei uma historia boa para voce."]},
		"papo":[{"texto":"Estou escolhendo as cores de um bordado. A Clara prefere verde; eu quero um vermelho que apareca do outro lado da praca."},{"texto":"O Osvaldo diz que conhece todas as madeiras. Deixe ele tentar adivinhar qual delas eu escolhi para a moldura."},{"texto":"Gosto quando perguntam antes de ajudar ou mover minha cadeira. Eu digo do que preciso, e a conversa continua."},{"texto":"Hoje pedi a Clara que deixasse as encomendas de lado um pouco. Queria ouvir como anda o desenho dela."}],
		"dicas":[{"chave":"familia","prioridade":20,"texto":"O Osvaldo recebe encomendas na nossa oficina, na nossa casa depois da ponte, a leste da vila. Das oito as dezessete voce o encontra por la."}],
		"historias":[{"amizade":3,"texto":"Conheci o Osvaldo discutindo uma moldura. Ele achou que eu tinha vindo comprar. Tinha vindo reclamar da cor."},{"amizade":6,"texto":"A ELA mudou nossa rotina. Clara e Osvaldo me ajudam, mas continuamos tendo assunto, vontade e planos para alem da doenca."}],
		"baloes":[{"texto":"Esse vermelho vai ficar bonito no bordado."}]},
	"clara": {
		"boas_vindas":"Sou Clara, tenho 30 anos. Ajudo nos cuidados da minha mae, Helena, e tambem faco bordados e desenhos para vender. Meu pai e o Osvaldo, o carpinteiro. Venha tomar um cha com a gente.",
		"saudacoes":{"novo":["{periodo}! Entre, tem lugar para mais um."],"conhecido":["Que bom te ver! Como estao as aves?"],"amigo":["Chegou bem na hora da minha pausa."]},
		"papo":[{"texto":"De manha acompanho minha mae ate a praca quando o tempo ajuda. Ela sempre volta com mais historias do que eu."},{"texto":"Meu pai cuida do jantar quando estou terminando uma encomenda. A gente divide as tarefas; eu tambem preciso descansar."},{"texto":"Quero fazer um mostruario dos meus bordados. O dificil e escolher so alguns para levar."}],
		"dicas":[{"chave":"chocar","prioridade":20,"texto":"Galinha bota ovo mesmo sem galo. Para nascer pintinho, precisa de um galo adulto e de um ovo no ninho de chocar. Reserve espaco antes de comecar."}],
		"historias":[{"amizade":3,"texto":"Minha mae me ensinou a bordar antes de eu ter paciencia para dar um no. Hoje ela ainda escolhe as cores das encomendas."},{"amizade":6,"texto":"Cuidar e parte da minha vida, mas meus desenhos e minhas amizades tambem sao. Quando meu pai assume os cuidados, gosto de passear sem pressa."}],
		"baloes":[{"texto":"Uma pausa e depois mais um desenho."}]}
}
