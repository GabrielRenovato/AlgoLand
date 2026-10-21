#!/usr/bin/env python3
"""Exporta os ícones das peças Raven usadas pelo jogador, sem escala."""
from preparar_raven import SAIDA, pacote, imagem

def preparar():
    destino=SAIDA/'icones'
    destino.mkdir(parents=True,exist_ok=True)
    base=pacote('base')
    fontes={'espada_basica':'Basic Sword.png','espada_gemea':'Two Handed Sword.png',
            'machado':'Two Handed Axe.png','lanca_basica':'Spear.png',
            'arco_curto':'Bow.png','escudo_basico':'Shield Above.png'}
    for tipo,arquivo in fontes.items():
        fonte=imagem(base,'Extras/'+arquivo)
        caixa=(16,16,96,96) if tipo=='lanca_basica' else (48,64,96,128)
        recorte=fonte.crop(caixa)
        assert recorte.getbbox(),tipo
        recorte.crop(recorte.getbbox()).save(destino/(tipo+'.png'))

if __name__=='__main__': preparar()
