extends RefCounted

## Lugares e interesses individuais. Os horários de trabalho, sono e abrigo continuam na agenda.
const PERFIS := {
	"mercador": {
		"cidade": [["mercador_abertura","Conferindo as mercadorias da venda"],["bento_praca","Conversando sobre a proxima colheita"],["mural","Procurando encomendas para a venda"],["mercador_praca","Fazendo contatos na praca"],["coreto","Ouvindo as novidades da vila"]],
		"praia": [[Vector2(190,216),"Conferindo o movimento dos pescadores"],[Vector2(250,254),"Pensando em produtos para a venda"],[Vector2(282,198),"Descansando a sombra dos coqueiros"],[Vector2(180,278),"Observando os barcos"],[Vector2(264,224),"Fazendo uma pausa depois da loja"]],
		"ritmo": Vector2(25,29), "pausa": Vector2(16,32), "via": "mercador_praca", "orla": Vector2(248,196),
	},
	"curandeira": {
		"cidade": [["rosa_jardim","Examinando as ervas do jardim"],["estela_flores","Escolhendo flores para os remedios"],["rosa_praca","Descansando junto da fonte"],["lia_praca","Perguntando pela saude dos vizinhos"],["bento_horta","Conferindo as plantas do Bento"]],
		"praia": [[Vector2(460,214),"Procurando ervas perto da orla"],[Vector2(510,234),"Observando as plantas dos coqueiros"],[Vector2(474,246),"Respirando a brisa do mar"],[Vector2(410,206),"Descansando as pernas na sombra"],[Vector2(550,248),"Examinando as flores da praia"]],
		"ritmo": Vector2(20,24), "pausa": Vector2(28,52), "via": "rosa_jardim", "orla": Vector2(444,204),
	},
	"bardo": {
		"cidade": [["bardo_coreto","Ensaiando uma nova cancao"],["coreto","Conferindo o palco do coreto"],["mercador_praca","Ouvindo historias dos viajantes"],["rosa_praca","Buscando inspiracao no som da fonte"],["mural","Lendo historias no mural"]],
		"praia": [[Vector2(276,238),"Ouvindo o ritmo das ondas"],[Vector2(246,274),"Compondo uma cancao sobre o mar"],[Vector2(300,204),"Ensaiando longe do movimento"],[Vector2(214,258),"Observando o horizonte"],[Vector2(282,178),"Descansando antes de abrir a taverna"]],
		"ritmo": Vector2(24,30), "pausa": Vector2(22,44), "via": "coreto", "orla": Vector2(284,190),
	},
	"mistica": {
		"cidade": [["estela_flores","Observando as flores e as estacoes"],["rosa_jardim","Procurando ingredientes para os rituais"],["ponte","Contemplando o rio"],["coreto","Observando as sombras do fim da tarde"],["rosa_praca","Meditando ao lado da fonte"]],
		"praia": [[Vector2(580,232),"Procurando sinais entre as conchas"],[Vector2(616,258),"Observando as correntes do mar"],[Vector2(546,196),"Meditando na sombra dos coqueiros"],[Vector2(590,260),"Contemplando o horizonte"],[Vector2(520,220),"Recolhendo ideias para os rituais"]],
		"ritmo": Vector2(21,25), "pausa": Vector2(32,58), "via": "estela_flores", "orla": Vector2(530,210),
	},
	"lia": {
		"cidade": [["mural","Organizando os pedidos da comunidade"],["lia_praca","Recebendo os visitantes da vila"],["mercador_abertura","Conferindo o abastecimento da vila"],["coreto","Conferindo o espaco dos encontros"],["rosa_jardim","Visitando o jardim da comunidade"]],
		"praia": [[Vector2(398,182),"Conferindo os bancos da orla"],[Vector2(448,236),"Visitando a entrada do cais"],[Vector2(486,202),"Olhando as plantas da comunidade"],[Vector2(406,262),"Conversando sobre a vida na praia"],[Vector2(470,252),"Fazendo uma pausa dos pedidos"]],
		"ritmo": Vector2(26,31), "pausa": Vector2(14,28), "via": "lia_praca", "orla": Vector2(398,210),
	},
	"bento": {
		"cidade": [["bento_horta","Inspecionando as folhas da horta"],["mercador_abertura","Conferindo sementes na venda"],["bento_praca","Conversando sobre o tempo e a colheita"],["rosa_jardim","Comparando o crescimento das plantas"],["mural","Procurando pedidos de produtos da terra"]],
		"praia": [[Vector2(166,218),"Observando como as plantas crescem na areia"],[Vector2(192,252),"Conferindo a umidade perto do mar"],[Vector2(222,194),"Descansando depois da horta"],[Vector2(244,286),"Olhando a mare"],[Vector2(174,270),"Comparando a areia com a terra da fazenda"]],
		"ritmo": Vector2(22,26), "pausa": Vector2(24,46), "via": "bento_praca", "orla": Vector2(228,206),
	},
	"ferreiro": {
		"cidade": [["mural","Conferindo encomendas de ferramentas"],["mercador_praca","Procurando materiais para a oficina"],["rosa_praca","Refrescando-se depois da forja"],["ponte","Conferindo as ferragens da ponte"],["bardo_coreto","Descansando ao som do coreto"]],
		"praia": [[Vector2(418,242),"Conferindo as ferragens da entrada do cais"],[Vector2(468,256),"Observando o trabalho dos pescadores"],[Vector2(404,264),"Descansando do calor da forja"],[Vector2(494,232),"Pensando em ferramentas para a pesca"],[Vector2(448,202),"Respirando longe da fumaca da oficina"]],
		"ritmo": Vector2(27,32), "pausa": Vector2(18,34), "via": "mural", "orla": Vector2(414,228),
	},
	"nilo": {
		"cidade": [["mercador_abertura","Conferindo suprimentos para a oficina de pesca"],["mural","Lendo pedidos dos pescadores"],["ponte","Observando a correnteza do rio"],["bento_praca","Conversando sobre as chuvas"],["coreto","Descansando depois da oficina"]],
		"praia": [[Vector2(452,244),"Conferindo a mare antes da pesca"],[Vector2(506,248),"Observando os pontos de pesca"],[Vector2(414,254),"Conferindo o acesso ao cais"],[Vector2(550,254),"Procurando movimento de peixes"],[Vector2(470,220),"Descansando depois da oficina"]],
		"ritmo": Vector2(23,27), "pausa": Vector2(26,48), "via": "ponte", "orla": Vector2(462,242),
	},
}
