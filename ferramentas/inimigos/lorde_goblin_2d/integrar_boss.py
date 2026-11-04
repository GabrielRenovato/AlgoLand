"""Publica os atlas aprovados no recurso do boss, sem gerar novos desenhos."""
from pathlib import Path
import json
import shutil

RAIZ=Path(__file__).resolve().parents[3]
FONTES=RAIZ/'arte/fontes/inimigos/lorde_goblin_2d'
ASSETS=RAIZ/'assets/inimigos/lorde_goblin_2d'

def integrar():
    dados={}
    for direcao in ['baixo','cima','direita']:
        ficha=json.loads((FONTES/f'registro_martelada_{direcao}.json').read_text())
        paleta=json.loads((FONTES/f'revisao_paleta_{direcao}.json').read_text())
        destino=f'martelada_boss_{direcao}.png'
        shutil.copyfile(FONTES/ficha['folha_final'],ASSETS/destino)
        dados[direcao]={'textura':f'res://assets/inimigos/lorde_goblin_2d/{destino}',
                        'colunas':ficha['grade'][0],'tempos_ms':ficha['duracoes_ms'],
                        'impacto_ms':ficha['impacto_ms'],'impacto_quadro':ficha['impacto_quadro'],
                        'contato':paleta.get('contato',[320,500]),
                        'ganhos_couro':paleta['ganhos_couro'],'ganhos_manto':paleta['ganhos_manto']}
        caminho_andada=FONTES/f'andada_{direcao}_registro.json'
        if caminho_andada.exists():
            andada=json.loads(caminho_andada.read_text())
            dados[direcao]['andada']={chave:andada[chave] for chave in ['textura','colunas','tempos_ms','ganhos_couro','ganhos_manto']}
    dados['esquerda']={'espelho_de':'direita'}
    (ASSETS/'boss_direcoes.json').write_text(json.dumps(dados,indent=2,ensure_ascii=False)+'\n')
    print('Boss: tres atlas, quatro direcoes, esquerda espelhada da direita.')

if __name__=='__main__': integrar()
