extends SceneTree
const Receitas=preload("res://codigo/dados/forja_armas.gd")
const Melhorias=preload("res://codigo/dados/melhorias_ferramentas.gd")
const Criacao=preload("res://codigo/fazenda/criacao_galinhas.gd")
var falhas=0
var verificacoes=0
func _initialize():rodar.call_deferred()
func conferir(ok: bool,texto: String):
 verificacoes+=1
 if not ok:falhas+=1;push_error(texto)
func rodar():
 assert(OS.get_user_data_dir().get_file().begins_with("AlgoLand testes"))
 await process_frame
 root.get_node("Saves").trocar("coop");root.get_node("Introducao").pular_prologo()
 var Drops=load("res://codigo/logica/drops_forja.gd")
 var prog=root.get_node("Progresso");var inv=root.get_node("InventarioJogador");var inv2=root.get_node("InventarioJogador2");var cal=root.get_node("Calendario")
 for tipo in Receitas.receitas_ativas():
  if tipo in Receitas.INICIAIS_LIVRES:continue
  prog.apagar();inv.limpar();inv.criar_itens_iniciais();inv2.limpar();inv2.criar_itens_iniciais()
  var marco=Receitas.onda_receita(tipo)
  prog.armas_liberadas[tipo]=true
  inv.receber_materiais(Receitas.RECEITAS[tipo])
  var antes=inv.fotografar_mochila();var antes2={}
  inv2.receber_materiais({"madeira":7,"ferro":13,"fibra":11})
  for id in Receitas.MATERIAIS:antes2[id]=inv2.quantidade_tipo("material:"+id)
  prog.maior_onda_vencida=marco-1
  conferir(prog.encomendar_arma(tipo,inv)=="VENCA O ANDAR %d PARA FABRICAR"%marco and inv.fotografar_mochila()==antes and prog.encomenda_forja.is_empty(),"Marco não consome recursos: "+tipo)
  prog.maior_onda_vencida=marco
  conferir(prog.encomendar_arma(tipo,inv)=="","Aceita no marco com custos completos: "+tipo)
  conferir(prog.encomenda_forja.materiais==Receitas.RECEITAS[tipo],"Fotografia do pagamento: "+tipo)
  for material in Receitas.RECEITAS[tipo]:conferir(inv.quantidade_tipo("material:"+material)==0,"Custo exato: "+tipo+material)
  prog.carregar()
  conferir(prog.encomenda_forja.get("materiais",{})==Receitas.RECEITAS[tipo],"Pagamento persiste: "+tipo)
  var pronto=prog.encomenda_forja.dia_pronto;prog.maior_onda_vencida=0;cal.dia=pronto
  conferir(prog.retirar_encomenda_forja(inv)=="" and prog.arma_liberada(tipo),"Pedido pago não é revalidado ou cobrado: "+tipo)
  conferir(antes2.keys().all(func(id):return inv2.quantidade_tipo("material:"+id)==antes2[id]),"Segundo jogador não paga: "+tipo)
  prog.salvar();prog.carregar()
  conferir(prog.arma_liberada(tipo),"Modelo conquistado conserva acesso abaixo do marco: "+tipo)
 # Contrato anterior, sem custos fotografados, abaixo do novo marco.
 prog.apagar();inv.limpar();inv.criar_itens_iniciais();cal.dia=10
 prog.armas_liberadas.elmo_carrasco=true
 prog.encomenda_forja={"tipo":"elmo_carrasco","dia_inicio":8,"dia_pronto":10,"jogador":1}
 prog.salvar();prog.carregar()
 conferir(not prog.encomenda_forja.has("materiais") and prog.encomenda_forja_pronta(),"Contrato legado mantém prazo e não inventa custos")
 conferir(prog.retirar_encomenda_forja(inv)=="" and inv.buscar_por_tipo("elmo_carrasco")!=null,"Contrato antigo entrega sem materiais adicionais")
 # Famílias são alternativas equivalentes; peças avançam por etapa.
 for prefixo in ["luvas","botas","elmo","peitoral"]:
  var ref=prefixo+"_carrasco"
  for conjunto in ["cavaleiro_rubro","cavalheiro"]:
   conferir(Receitas.onda_receita(ref)==Receitas.onda_receita(prefixo+"_"+conjunto) and Receitas.RECEITAS[ref]==Receitas.RECEITAS[prefixo+"_"+conjunto],"Escolha do conjunto não muda dificuldade")
 conferir(Receitas.onda_receita("luvas_carrasco")==10 and Receitas.onda_receita("botas_carrasco")==12 and Receitas.onda_receita("elmo_carrasco")==15 and Receitas.onda_receita("peitoral_carrasco")==20,"Conjunto completo é objetivo de médio prazo")
 conferir(Receitas.RECEITAS.arco_curto.madeira>Receitas.extracao("arvore").madeira and Receitas.RECEITAS.lanca_basica.madeira>Receitas.extracao("arvore").madeira,"Uma árvore não paga arco ou lança")
 conferir(not Criacao.CUSTOS[1].has("ferro") and not Criacao.CUSTOS[1].has("nucleo"),"Primeiro abrigo acessível sem arena")
 for material in ["madeira","pedra","fibra"]:
  conferir(Melhorias.CUSTOS[3][material]>Melhorias.CUSTOS[2][material],"Ferramenta tem investimento crescente: "+material)
  conferir(Criacao.CUSTOS[1][material]<Criacao.CUSTOS[2][material] and Criacao.CUSTOS[2][material]<Criacao.CUSTOS[3][material],"Construção tem investimento crescente: "+material)
 # Uma receita de estágio avançado nunca é antecipada no sorteio.
 prog.apagar()
 for tipo in Receitas.RECEITAS:
  if tipo!="peitoral_carrasco":prog.armas_liberadas[tipo]=true
 conferir(Drops.receita_pendente(19,self)=="" and Drops.receita_pendente(20,self)=="peitoral_carrasco","Saque respeita último marco")
 print("PROGRESSAO FABRICACAO: ",verificacoes," verificações; ",falhas," falhas")
 quit(1 if falhas else 0)
