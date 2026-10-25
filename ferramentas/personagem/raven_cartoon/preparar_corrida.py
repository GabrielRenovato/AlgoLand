#!/usr/bin/env python3
"""Empacota as quatro poses cartoon da corrida frontal como ciclo frontal sem salto.

Não redesenha os quadros: recorta a grade e aplica translações de encaixe.
O quarto desenho corrigido é trazido à escala uniforme da folha original.
"""
from pathlib import Path
import json
from hashlib import sha256
from PIL import Image

RAIZ=Path(__file__).resolve().parents[3]
FONTE=RAIZ/'arte/fontes/personagens/raven_cartoon/corrida_frente_4'
SAIDA=RAIZ/'assets/personagens/raven_cartoon'
PREVIA=RAIZ/'arte/previas/personagens/raven_cartoon/corrida_frente_4'
CELULA=(512,896)
CHAO=850
DURACOES=[100,100,100,100]

def centro_cabeca(im):
    # Centro anatômico da calota, acima das orelhas. Não recentraliza por contorno total.
    a=im.getchannel('A');centros=[]
    for y in range(85,125):
        xs=[x for x in range(im.width) if a.getpixel((x,y))>128]
        if xs:centros.append((min(xs)+max(xs))/2)
    return round(sum(centros)/len(centros))

def sola_apoio(im):
    a=im.getchannel('A');bb=a.point(lambda v:255 if v>128 else 0).getbbox()
    y=bb[3]-1
    xs=[x for yy in range(max(0,y-5),y+1) for x in range(im.width) if a.getpixel((x,yy))>128]
    return [round(sum(xs)/len(xs)),y]

def preparar():
    SAIDA.mkdir(parents=True,exist_ok=True);PREVIA.mkdir(parents=True,exist_ok=True)
    fonte=Image.open(FONTE/'folha_gerada_v1.png').convert('RGBA')
    w,h=(fonte.width+1)//2,(fonte.height+1)//2
    original=Image.new('RGBA',(w*2,h*2));original.alpha_composite(fonte)
    atlas=Image.new('RGBA',(CELULA[0]*4,CELULA[1]));contato=Image.new('RGBA',(CELULA[0]*2,CELULA[1]*2))
    quadros=[];dados=[]
    for q in range(4):
        caixa=((q%2)*w,(q//2)*h,(q%2+1)*w,(q//2+1)*h)
        im=original.crop(caixa)
        if q==3:
            corrigido=Image.open(FONTE/'quadro_04_corrigido_original.png').convert('RGBA')
            escala=min(w/corrigido.width,h/corrigido.height)
            tamanho=(round(corrigido.width*escala),round(corrigido.height*escala))
            corrigido=corrigido.resize(tamanho,Image.Resampling.LANCZOS)
            im=Image.new('RGBA',(w,h));im.alpha_composite(corrigido,((w-tamanho[0])//2,(h-tamanho[1])//2))
        cabeca=centro_cabeca(im);sola=sola_apoio(im)
        dx,dy=CELULA[0]//2-cabeca,CHAO-sola[1]
        quadro=Image.new('RGBA',CELULA);quadro.alpha_composite(im,(dx,dy))
        bb=quadro.getchannel('A').point(lambda v:255 if v>128 else 0).getbbox()
        assert bb and min(bb[:2])>15 and bb[2]<CELULA[0]-15 and bb[3]<CELULA[1]-15,(q,bb)
        # O pé apoiado troca de lado na segunda metade. Todos tocam o mesmo chão.
        apoio=[sola[0]+dx,sola[1]+dy]
        assert apoio[1]==CHAO
        assert (apoio[0]<CELULA[0]//2)==(q<2),(q,apoio)
        atlas.alpha_composite(quadro,(q*CELULA[0],0));contato.alpha_composite(quadro,((q%2)*CELULA[0],(q//2)*CELULA[1]))
        quadro.save(PREVIA/f'quadro_{q+1:02d}.png');quadros.append(quadro)
        dados.append({'quadro':q+1,'duracao_ms':DURACOES[q],'cabeca_centro_x':cabeca+dx,'apoio':apoio,'pe_apoiado':'esquerdo_da_tela' if q<2 else 'direito_da_tela','translacao':[dx,dy],'fonte':'quadro_04_corrigido_original.png' if q==3 else 'folha_gerada_v1.png','sha256_rgba':sha256(quadro.tobytes()).hexdigest()})
    atlas.save(SAIDA/'corrida_frente_4.png');contato.save(PREVIA/'quatro_quadros.png')
    frames=[]
    for im in quadros:
        fundo=Image.new('RGBA',CELULA,(236,231,216,255));fundo.alpha_composite(im)
        frames.append(fundo.resize((384,672),Image.Resampling.LANCZOS).convert('RGB'))
    frames[0].save(PREVIA/'corrida_frente_4.gif',save_all=True,append_images=frames[1:],duration=DURACOES,loop=0,disposal=2)
    contrato=json.loads((FONTE/'contrato.json').read_text());contrato.update({'estado':'preparado_para_revisao_no_motor','celula_exportada':list(CELULA),'pivo_exportado':[256,CHAO],'ordem':[1,2,3,4],'duracoes_ms':DURACOES,'quadros_exportados':dados,'quarto_quadro':'corrigido: perna direita da imagem apoiada e esquerda avançando; outros três desenhos preservados','atlas':'assets/personagens/raven_cartoon/corrida_frente_4.png'})
    (FONTE/'contrato.json').write_text(json.dumps(contrato,ensure_ascii=False,indent=2)+'\n')
    print('Quatro quadros frontais; apoio esquerdo/esquerdo/direito/direito; chão comum y850; ciclo400ms.')

if __name__=='__main__':preparar()
