"""Confere a geração local e a versão publicada sem alterar arquivos do jogo/site."""
from concurrent.futures import ThreadPoolExecutor
import base64
import hashlib
import json
from pathlib import Path
import re
import subprocess
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request


def nome_seguro(nome):
    if not isinstance(nome, str) or not nome or nome == "." or ".." in nome or "/" in nome or "\\" in nome:
        raise ValueError("Nome de arquivo inválido no manifesto")
    return nome


def sha256(caminho):
    with caminho.open("rb") as arquivo:
        return hashlib.file_digest(arquivo, "sha256").hexdigest()


def assinatura_valida(chave, dados, assinatura, temporarios):
    try:
        sig = base64.b64decode(assinatura, validate=True)
    except (ValueError, TypeError) as erro:
        raise ValueError("Assinatura em Base64 inválida") from erro
    (temporarios / "dados").write_bytes(dados)
    (temporarios / "assinatura").write_bytes(sig)
    r = subprocess.run(["openssl", "dgst", "-sha256", "-verify", str(chave), "-signature", str(temporarios / "assinatura"), str(temporarios / "dados")], capture_output=True)
    if r.returncode: raise ValueError("Assinatura RSA inválida")


def validar_local(raiz, wiki):
    publicos = wiki / "public/jogar"
    configuracao = re.search(r'^config/version="([^"]+)"', (raiz / "project.godot").read_text(), re.M)
    if not configuracao: raise ValueError("Versão do projeto não encontrada")
    versao = configuracao.group(1)
    envelopes = json.loads((publicos / "atualizacao/versao.json").read_text())
    web = json.loads((publicos / "manifesto.json").read_text())
    if not isinstance(envelopes, dict) or not isinstance(web, dict): raise ValueError("Manifesto deve ser um objeto JSON")
    arquivos = {}
    conteudos = set()
    plataformas = []
    with tempfile.TemporaryDirectory(prefix="algoland-assinaturas-") as pasta:
        temporarios = Path(pasta)
        chave = temporarios / "publica.pem"
        texto = (raiz / "codigo/globais/atualizacao_chave.gd").read_text()
        correspondencia = re.search(r'PUBLICA\s*:=?\s*"""(.*?)"""', texto, re.S)
        if not correspondencia: raise ValueError("Chave pública não encontrada")
        chave.write_text(correspondencia.group(1))
        for plataforma in ["android", "windows", "linux"]:
            envelope = envelopes["pacotes"][plataforma][versao]
            assinatura_valida(chave, envelope["dados"].encode(), envelope["assinatura"], temporarios)
            manifesto = json.loads(envelope["dados"])
            if not isinstance(manifesto, dict): raise ValueError("Manifesto assinado deve ser um objeto JSON")
            if manifesto.get("formato") != 2 or manifesto.get("app_base") != versao or manifesto.get("plataforma") != plataforma:
                raise ValueError("Manifesto incompatível: " + plataforma)
            if not isinstance(manifesto.get("conteudo"), int) or manifesto["conteudo"] <= 0 or not manifesto.get("pacotes"):
                raise ValueError("Geração vazia/inválida: " + plataforma)
            conteudos.add(manifesto["conteudo"])
            ids, nomes = set(), set()
            for pacote in manifesto["pacotes"]:
                nome = nome_seguro(pacote["arquivo"])
                identificador = nome_seguro(pacote["id"])
                if nome in nomes or identificador in ids: raise ValueError("Pacote duplicado: " + plataforma)
                ids.add(identificador)
                nomes.add(nome)
                relativo = "atualizacao/" + nome
                p = publicos / relativo
                if p.stat().st_size != pacote["tamanho"] or sha256(p) != pacote["sha256"]:
                    raise ValueError("Tamanho/hash inválido: " + relativo)
                with p.open("rb") as f:
                    if f.read(4) != b"GDPC": raise ValueError("PCK inválido: " + relativo)
                assinatura_valida(chave, p.read_bytes(), pacote["assinatura"], temporarios)
                arquivos[relativo] = {"tamanho": pacote["tamanho"], "sha256": pacote["sha256"]}
            plataformas.append({"plataforma": plataforma, "conteudo": manifesto["conteudo"], "pacotes": len(ids)})
    if len(conteudos) != 1: raise ValueError("As plataformas têm números de conteúdo diferentes")
    completo = hashlib.sha256()
    tamanho = 0
    if not web.get("partes"): raise ValueError("Manifesto Web sem partes")
    for parte in web["partes"]:
        nome = nome_seguro(parte["arquivo"])
        if nome in arquivos: raise ValueError("Parte Web duplicada")
        p = publicos / nome
        if p.stat().st_size != parte["tamanho"]: raise ValueError("Parte Web incompleta: " + nome)
        tamanho += p.stat().st_size
        with p.open("rb") as f:
            while bloco := f.read(1024 * 1024): completo.update(bloco)
        arquivos[nome] = {"tamanho": parte["tamanho"], "sha256": sha256(p)}
    if tamanho != web["pacote"] or completo.hexdigest() != web["sha256"] or web["versao"] != web["sha256"][:12]:
        raise ValueError("Hash/tamanho total do jogo Web diverge do manifesto")
    for nome in ["carregar.js", "sw.js", "index.wasm", "index.js"]:
        p = publicos / nome
        arquivos[nome] = {"tamanho": p.stat().st_size, "sha256": sha256(p)}
    for nome in ["carregar.js", "sw.js"]:
        if "__VERSAO__" in (publicos / nome).read_text() or "__REVISAO_CASCA__" in (publicos / nome).read_text():
            raise ValueError("Casca Web contém marcador de versão não substituído")
    if web["versao"] not in (publicos / "carregar.js").read_text(): raise ValueError("Carregador Web pertence a outra versão")
    return {"conteudo": next(iter(conteudos)), "base": versao, "web": web["versao"], "plataformas": plataformas, "arquivos": arquivos}, web, envelopes


def consultar_json(url):
    pedido = urllib.request.Request(url, headers={"Cache-Control": "no-cache"})
    with urllib.request.urlopen(pedido, timeout=20) as resposta:
        return json.load(resposta)


def aguardar_manifestos(url, web, envelopes, esperar):
    prazo = time.monotonic() + esperar
    while True:
        try:
            sufixo = "?harness=" + str(time.time_ns())
            if consultar_json(url + "manifesto.json" + sufixo) == web and consultar_json(url + "atualizacao/versao.json" + sufixo) == envelopes:
                return
            erro = "O endereço ainda não serve os manifestos locais"
        except (OSError, ValueError) as falha:
            erro = str(falha)
        if time.monotonic() >= prazo: raise RuntimeError(erro)
        time.sleep(min(5, max(0, prazo - time.monotonic())))


def verificar_remotos(url, arquivos):
    def verificar(item):
        nome, esperado = item
        h = hashlib.sha256()
        tamanho = 0
        with urllib.request.urlopen(url + urllib.parse.quote(nome, safe="/"), timeout=120) as resposta:
            while bloco := resposta.read(1024 * 1024):
                h.update(bloco)
                tamanho += len(bloco)
        if tamanho != esperado["tamanho"] or h.hexdigest() != esperado["sha256"]:
            raise ValueError("Tamanho/SHA256 remoto divergente: " + nome)
        return nome
    with ThreadPoolExecutor(max_workers=3) as fila:
        return list(fila.map(verificar, arquivos.items()))


def conferir(raiz, wiki, url=None, esperar=0, saida=None):
    if esperar < 0: raise ValueError("--esperar não pode ser negativo")
    if url:
        partes = urllib.parse.urlsplit(url)
        if partes.scheme not in ["http", "https"] or not partes.netloc or partes.query or partes.fragment or partes.username:
            raise ValueError("Use uma URL HTTP(S) da pasta jogar, sem credenciais, query ou fragmento")
        url = url.rstrip("/") + "/"
    saida = saida.resolve() if saida else Path(tempfile.mkdtemp(prefix="algoland-publicacao-"))
    saida.mkdir(parents=True, exist_ok=True)
    if list(saida.iterdir()): raise ValueError("--saida precisa ser uma pasta vazia")
    caminho = saida / "relatorio.json"
    relatorio = {"aprovado": False, "remoto": bool(url)}
    try:
        relatorio, web, envelopes = validar_local(raiz, wiki)
        relatorio.update(aprovado=False, remoto=bool(url))
        if url:
            print("Aguardando/conferindo a versão publicada; relatório: " + str(caminho), flush=True)
            aguardar_manifestos(url, web, envelopes, esperar)
            relatorio["remotos_verificados"] = verificar_remotos(url, relatorio["arquivos"])
        relatorio["aprovado"] = True
    except (OSError, ValueError, KeyError, TypeError, RuntimeError) as erro:
        relatorio["erro"] = str(erro)
    caminho.write_text(json.dumps(relatorio, indent=2, ensure_ascii=False) + "\n")
    if relatorio["aprovado"]:
        print("OK conteúdo %s; Web %s; %d arquivos com SHA256; assinaturas das 3 plataformas válidas%s" % (relatorio["conteudo"], relatorio["web"], len(relatorio["arquivos"]), "; produção conferida" if url else "; somente arquivos locais"))
    else:
        print("FALHA publicação: " + relatorio["erro"])
    print("Relatório: " + str(caminho))
    return 0 if relatorio["aprovado"] else 1
