#!/usr/bin/env python3
"""Composições instrumentais e ambientes originais, determinísticos, sem pacotes externos."""
from pathlib import Path
from array import array
import math
import random
import wave

RAIZ = Path(__file__).resolve().parents[2] / 'assets/audio/trilhas'
TAXA = 16000
COMPASSOS = 32
TEMAS = {
 'vila': (76, [[60,64,67],[57,60,64],[53,57,60],[55,59,62]], [0,2,1,2,0,1,2,1]),
 'fazenda': (84, [[60,64,67],[65,69,72],[57,60,64],[55,59,62]], [0,1,2,1,0,2,1,2]),
 'praia': (66, [[62,65,69],[58,62,65],[65,69,72],[60,64,67]], [2,1,0,1,2,0,1,0]),
 'fenda': (72, [[45,52,57],[41,48,53],[43,50,55],[40,47,52]], [0,2,1,0,2,1,0,1]),
 'guardiao': (104, [[45,48,52],[41,45,48],[43,47,50],[40,44,47]], [0,1,0,2,0,1,2,1]),
}

def salvar(nome, dados):
 pico=max(abs(x) for x in dados) or 1
 ganho=.66/pico
 pcm=array('h', (round(max(-1,min(1,x*ganho))*32767) for x in dados))
 with wave.open(str(RAIZ/(nome+'.wav')), 'wb') as arq:
  arq.setnchannels(1); arq.setsampwidth(2); arq.setframerate(TAXA); arq.writeframes(pcm.tobytes())
 rms=math.sqrt(sum((x*ganho)**2 for x in dados)/len(dados))
 print(nome, 'segundos',round(len(dados)/TAXA,2),'pico',round(pico*ganho,3),'rms',round(rms,3),'juncao',round(abs(dados[-1]-dados[0])*ganho,4))

def nota(dados, inicio, duracao, midi, volume, timbre):
 freq=440*2**((midi-69)/12)
 for i in range(int(duracao*TAXA)):
  t=i/TAXA
  env=min(1,t/.025)*min(1,(duracao-t)/.15)
  env*=math.exp(-t*(2.7 if timbre=='corda' else .45))
  fase=2*math.pi*freq*t
  som=math.sin(fase)+.18*math.sin(2*fase)+.06*math.sin(3*fase)
  dados[(int(inicio*TAXA)+i)%len(dados)]+=som*env*volume

def gerar_tema(nome):
 bpm,acordes,melodia=TEMAS[nome]
 pulso=60/bpm
 dados=[0.] * round(COMPASSOS*4*pulso*TAXA)
 for compasso in range(COMPASSOS):
  acorde=acordes[compasso%4]
  frase=(compasso//4)%4
  for n in acorde: nota(dados,compasso*4*pulso,4.8*pulso,n-12,.09,'pad')
  for i in range(len(melodia)):
   grau=melodia[(i+frase*2)%len(melodia)]
   # Frases de resposta deixam espaço entre notas, preservando o pulso e a harmonia.
   if frase==2 and i in [3,7]: continue
   oitava=12 if nome in ['vila','fazenda','praia'] else 0
   volume=.13*(.85 if frase in [1,2] else 1.)
   nota(dados,(compasso*4+i*.5)*pulso,(1.8 if frase==2 else 1.3)*pulso,acorde[grau]+oitava,volume,'corda')
  for i in [0,2]: nota(dados,(compasso*4+i)*pulso,1.9*pulso,acorde[0]-24,.13,'pad')
 # Reverberação circular: as caudas do fim continuam no início do mesmo período.
 seco=dados[:]
 for atraso,ganho in [(0.073,.14),(0.137,.08)]:
  amostras=round(atraso*TAXA)
  for i in range(len(dados)): dados[i]+=seco[(i-amostras)%len(dados)]*ganho
 return dados

if __name__=='__main__':
 RAIZ.mkdir(parents=True,exist_ok=True)
 for nome in TEMAS:
  salvar(nome,gerar_tema(nome))
 for nome in ['bosque','mar','caverna']:
  rng=random.Random(nome)
  dados=[]; suave=0.
  emenda=2*TAXA
  for i in range(24*TAXA+emenda):
   t=i/TAXA; suave=.975*suave+.025*rng.uniform(-1,1)
   onda=.55+.35*math.sin(2*math.pi*t/(8 if nome=='mar' else 12))
   dados.append(suave*onda*(.7 if nome=='mar' else .3))
  for i in range(emenda):
   mistura=i/emenda
   dados[i]=dados[24*TAXA+i]*(1-mistura)+dados[i]*mistura
  dados=dados[:24*TAXA]
  salvar(nome,dados)
