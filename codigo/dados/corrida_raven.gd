extends RefCounted
## Tempos reais do ciclo de corrida Mana Seed: apoio, passagem e fase aérea,
## com a outra perna repetindo as mesmas fases. Células80 e raiz40,47.
const RAIZ := "res://assets/personagens/raven_fantasy/corrida_mana_seed/"
const DURACOES := [0.10,0.06,0.14,0.10,0.06,0.14]
const QUADROS := 6
static func quadro(tempo: float, duracao_ciclo: float) -> int:
 var restante := fposmod(tempo,maxf(0.001,duracao_ciclo)) * 0.6 / maxf(0.001,duracao_ciclo)
 for i in DURACOES.size():
  if restante < DURACOES[i]-0.00001:return i
  restante -= DURACOES[i]
 return 0
