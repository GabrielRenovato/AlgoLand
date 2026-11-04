"""Deriva a casa de leilões em ouro preservando as regras/transações existentes."""
from pathlib import Path
raiz=Path(__file__).resolve().parent
partes=[]
for nome in ['20261025120000_mercado.sql','20261025170000_mercado_seguranca.sql']:
 texto=(raiz/nome).read_text().replace('mercado_','campanha_mercado_')
 # Catálogo de itens e banimentos são comuns. Saldos, anúncios, limites e correio são independentes.
 texto=texto.replace('campanha_mercado_tipos','mercado_tipos').replace('campanha_mercado_banidos','mercado_banidos')
 texto=texto.replace('Brasas','Ouro').replace('brasas','ouro')
 texto='\n'.join(l for l in texto.splitlines() if l.strip().lower() not in ['begin;','commit;'])
 partes.append(texto)
saida=raiz/'20261104090000_campanha_ouro.sql'
saida.write_text('-- Gerado por gerar_campanha.py; depende do catálogo comum de tipos de mercado.\nbegin;\n'+'\n'.join(partes)+'\ncommit;\n')
print(saida)

teste=(raiz/'teste_mercado.sql').read_text().replace('mercado_','campanha_mercado_').replace('campanha_mercado_tipos','mercado_tipos').replace('campanha_mercado_banidos','mercado_banidos').replace('brasas','ouro')
(raiz/'teste_campanha_ouro.sql').write_text('-- Gerado por gerar_campanha.py; somente banco de testes.\n'+teste)
