extends RefCounted
## Tempos reais do ciclo de corrida Mana Seed: apoio, passagem e fase aérea,
## com a outra perna repetindo as mesmas fases. Células80 e raiz40,47.
const RAIZ := "res://assets/personagens/raven_fantasy/corrida_mana_seed/"
const DURACOES := [0.10,0.06,0.14,0.10,0.06,0.14]
const QUADROS := 6
## Os elmos nativos novos recolhem dois pixels sobre a gola na passagem.
## O desenho da peça e o salto do corpo permanecem nos quadros originais.
const ELMOS_RECOLHIDOS := ["sentinela","batedor","guardiao_geada","templario_solar","arauto_trovao","guardiao_esmeralda","soberano_astral"]
const QUADROS_ELMO_RECOLHIDO := [1,4]
## O centro entre os ombros fica um pixel à direita da cabeça antiga
## nos quadros 0, 1 e 5. Alinhar a peça ao tronco, sem alterar o desenho.
const CORRECAO_LATERAL_ELMO_FRENTE := [1,1,0,0,0,1]
## De costas, manter o centro no pivô x=40 nos seis quadros. Seguir os
## ombros ainda acrescentava um balanço lateral de um pixel à cabeça.
const CORRECAO_LATERAL_ELMO_COSTAS := [0,0,2,2,2,0]
const CENTROS_CABECA_COSTAS := [40,40,38,38,38,40]
## Limite inferior da cabeça original, exclusivo, conforme o guia da corrida.
## A gola e os braços permanecem abaixo deste recorte.
const GOLAS_FRENTE := [29,28,26,29,28,26]

static func encaixe_elmo(id: String, acao: String, direcao: int, quadro: int) -> Vector2i:
 if acao!="correr" or direcao not in [0,2] or id not in ELMOS_RECOLHIDOS or quadro<0 or quadro>=QUADROS:
  return Vector2i.ZERO
 if direcao==2:
  return Vector2i(CORRECAO_LATERAL_ELMO_COSTAS[quadro],1 if quadro in QUADROS_ELMO_RECOLHIDO else 0)
 return Vector2i(CORRECAO_LATERAL_ELMO_FRENTE[quadro],2 if quadro in QUADROS_ELMO_RECOLHIDO else 0)

static func quadro(tempo: float, duracao_ciclo: float) -> int:
 var restante := fposmod(tempo,maxf(0.001,duracao_ciclo)) * 0.6 / maxf(0.001,duracao_ciclo)
 for i in DURACOES.size():
  if restante < DURACOES[i]-0.00001:return i
  restante -= DURACOES[i]
 return 0
