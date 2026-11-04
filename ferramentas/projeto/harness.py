#!/usr/bin/env python3
"""Entrada curta para contexto, testes com cache e conferência da publicação."""
import argparse
import hashlib
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import re
import shutil
import signal
import socket
import stat
import subprocess
import sys
import tempfile
import threading
import time

from preparar_testes import preparar
from testar_coop import analisar_log, executar
from testar_tudo import GRAFICOS

RAIZ = Path(__file__).resolve().parents[2]
PERFIS = {
    "goblin-machado": {"testes": ["goblin_machado_3d"], "caminhos": ["codigo/inimigos/goblin_machado_3d.gd", "cenas/inimigos/goblin_machado_3d.tscn", "assets/inimigos/goblin_machado_3d/", "ferramentas/inimigos/goblin_machado_3d/", "testes/teste_goblin_machado_3d.gd"], "visual": True},
    "goblins-pomar": {"testes": ["goblin_adaga_animacoes", "goblins_pomar"], "caminhos": ["codigo/inimigos/goblin_", "codigo/campanha/goblins_pomar.gd", "cenas/inimigos/goblin_", "assets/inimigos/goblin_adaga/", "ferramentas/inimigos/preparar_goblin_adaga.gd", "testes/teste_goblin_adaga_animacoes.gd", "testes/teste_goblins_pomar.gd"], "visual": True},
    "moinho-mobile": {"testes": ["moinho_mobile"], "caminhos": ["codigo/campanha/", "codigo/ui/controles_toque.gd", "codigo/cenario/grama_3d_no_mapa.gd", "testes/teste_moinho_mobile.gd"], "visual": True},
    "interface-campanha": {"testes": ["interface_campanha", "salas_campanha"], "caminhos": ["codigo/campanha/", "codigo/ui/estilo_campanha.gd", "testes/teste_interface_campanha.gd"], "visual": True},
    "instancias-campanha": {"testes": ["instancias_campanha"], "caminhos": ["codigo/campanha/", "testes/teste_instancias_campanha.gd"], "visual": True},
    "drops-iniciais": {"testes": ["drops_iniciais", "drops_iniciais_visual"], "caminhos": ["codigo/campanha/saque_inicial.gd", "codigo/campanha/catalogo_saque_inicial.gd", "codigo/campanha/drop_inicial.gd", "codigo/dados/acessorios_iniciais.gd", "testes/teste_drops_iniciais"], "visual": True},
    "maestria": {"testes": ["maestria", "maestria_rede", "maestria_combate", "maestria_coop"], "caminhos": ["codigo/dados/catalogo_maestria.gd", "codigo/modelos/modelo_maestria.gd", "codigo/jogador/maestria_jogador.gd", "codigo/ui/tela_maestria.gd", "testes/teste_maestria"], "visual": True},
    "estrada-carreteiros": {"testes": ["estrada_carreteiros"], "caminhos": ["codigo/campanha/estrada_", "codigo/campanha/encontro_estrada.gd", "codigo/campanha/interacao_estrada.gd", "cenas/campanha/terreno_estrada.tscn", "assets/cenario/campanha/estrada_carreteiros/", "testes/teste_estrada_carreteiros.gd"], "visual": True},
    "salas-campanha": {"testes": ["salas_campanha"], "caminhos": ["codigo/campanha/dialogo_salas.gd", "codigo/campanha/sessao_expedicao.gd", "testes/teste_salas_campanha.gd"], "visual": True},
    "cerne-partido": {"testes": ["cerne_partido"], "caminhos": ["codigo/inimigos/cerne_partido.gd", "codigo/inimigos/apoio_cerne.gd", "cenas/inimigos/cerne_partido.tscn", "cenas/inimigos/apoio_cerne.tscn", "assets/inimigos/cerne_partido/", "ferramentas/campanha/preparar_cerne_partido.py", "testes/teste_cerne_partido.gd"], "visual": True},
    "monstro-raizes": {"testes": ["monstro_raizes"], "caminhos": ["codigo/inimigos/rebento_raizes.gd", "codigo/inimigos/erupcao_raizes.gd", "cenas/inimigos/rebento_raizes.tscn", "assets/inimigos/rebento_raizes/", "ferramentas/campanha/preparar_rebento_raizes.py", "testes/teste_monstro_raizes.gd"], "visual": True},
    "bacia-moinho": {"testes": ["entrada_dungeon_visual", "bacia_moinho"], "caminhos": ["codigo/campanha/", "assets/cenario/campanha/bacia_tiles/", "assets/cenario/campanha/moinho_modular/", "assets/cenario/campanha/moinho_lowpoly/", "assets/cenario/campanha/agua_bacia/", "assets/cenario/campanha/mecanismos_3d/", "testes/teste_bacia_moinho.gd", "testes/teste_entrada_dungeon_visual.gd"], "visual": True},
    "mapas-modulares": {"testes": ["entrada_dungeon_visual", "mapas_modulares", "bacia_moinho"], "caminhos": ["codigo/campanha/", "assets/cenario/campanha/clareiras_modulares/", "assets/cenario/campanha/bacia_tiles/", "assets/cenario/campanha/moinho_modular/", "assets/cenario/campanha/moinho_lowpoly/", "assets/cenario/campanha/agua_bacia/", "assets/cenario/campanha/mecanismos_3d/", "ferramentas/campanha/", "testes/teste_mapas_modulares.gd", "testes/teste_bacia_moinho.gd", "testes/teste_entrada_dungeon_visual.gd"], "visual": True},
    "campanha-online": {"testes": [], "caminhos": ["codigo/campanha/", "codigo/coop_online/", "ferramentas/lobby/servidor/"], "visual": True},
    "campanha-percurso": {"testes": ["percurso_campanha", "mapas_campanha"], "caminhos": ["cenas/campanha/", "codigo/campanha/percurso_prototipo.gd", "testes/teste_percurso_campanha"], "visual": True},
    "campanha-social": {"testes": ["campanha_pesca_social", "leilao_campanha", "cidade_campanha_online"], "caminhos": ["codigo/campanha/", "codigo/pesca/", "codigo/mercado/", "codigo/cidade/sessao_lobby.gd", "codigo/modelos/modelo_inventario.gd", "ferramentas/mercado/", "ferramentas/lobby/", "testes/teste_campanha_pesca_social.gd", "testes/teste_leilao_campanha.py", "testes/teste_cidade_campanha_online.py"], "visual": True},
    "campanha": {"testes": ["campanha_primeiro_andar", "controlador_campanha"], "caminhos": ["codigo/campanha/", "testes/teste_campanha_primeiro_andar"], "visual": False},
    "web": {"testes": ["fontes_web"], "caminhos": ["codigo/dados/fontes_interface.gd", "codigo/conta/", "codigo/ui/", "codigo/globais/controle.gd"], "visual": True},
    "coop-online": {"testes": [], "caminhos": ["codigo/coop_online/", "codigo/efeitos/", "codigo/jogador/", "ferramentas/lobby/servidor/"], "visual": True},
    "conjuntos": {"testes": ["bonus_conjuntos"], "caminhos": ["codigo/dados/conjuntos_armadura.gd", "codigo/dados/base_conjunto_armadura.gd", "ferramentas/armaduras/"], "visual": False},
    "pacotes": {"testes": ["pacotes_atualizacao"], "caminhos": ["ferramentas/atualizacao/", "codigo/globais/inicializacao_patches.gd", "codigo/globais/atualizacao.gd"], "visual": False},
    "harness": {"testes": ["harness"], "caminhos": ["ferramentas/projeto/harness", "testes/teste_harness.py"], "visual": False},
    "web-browser": {"testes": [], "caminhos": [], "visual": True},
    "selecionado": {"testes": [], "caminhos": [], "visual": False},
}
# Os hashes do índice cobrem recursos versionados; só alterações são lidas do disco.
ENTRADAS = ["project.godot", "export_presets.cfg", "codigo", "cenas", "recursos", "assets", "addons", "testes", "ferramentas", "AGENTS.md", ".codex/config.toml"]


def git(raiz, *args):
    return subprocess.check_output(["git", "-C", str(raiz), *args])


def alterados(raiz=RAIZ, caminhos=ENTRADAS):
    nomes = set(git(raiz, "diff", "--name-only", "-z", "HEAD", "--", *caminhos).split(b"\0"))
    nomes.update(git(raiz, "ls-files", "--others", "--exclude-standard", "-z", "--", *caminhos).split(b"\0"))
    return sorted(os.fsdecode(n) for n in nomes if n)


def assinatura(raiz, motor, selecao):
    h = hashlib.sha256(b"algoland-harness-v1\0")
    h.update(json.dumps([motor, selecao], sort_keys=True).encode())
    entradas = {}
    for linha in git(raiz, "ls-files", "--stage", "-z", "--", *ENTRADAS).split(b"\0"):
        if not linha: continue
        metadados, nome = linha.split(b"\t", 1)
        modo, objeto, estagio = metadados.split()
        if estagio != b"0": raise ValueError("Conflito no índice: " + os.fsdecode(nome))
        entradas[os.fsdecode(nome)] = (modo, objeto)
    nomes = set(git(raiz, "diff-files", "--name-only", "-z", "--", *ENTRADAS).split(b"\0"))
    nomes.update(git(raiz, "ls-files", "--others", "--exclude-standard", "-z", "--", *ENTRADAS).split(b"\0"))
    algoritmo = git(raiz, "rev-parse", "--show-object-format").decode().strip()
    for nome in (os.fsdecode(n) for n in nomes if n):
        p = raiz / nome
        if p.is_symlink():
            dados = os.fsencode(os.readlink(p))
            objeto = hashlib.new(algoritmo, b"blob " + str(len(dados)).encode() + b"\0" + dados)
            entradas[nome] = (b"120000", objeto.hexdigest().encode())
        elif p.is_file():
            objeto = hashlib.new(algoritmo, b"blob " + str(p.stat().st_size).encode() + b"\0")
            with p.open("rb") as f:
                for bloco in iter(lambda: f.read(1024 * 1024), b""): objeto.update(bloco)
            entradas[nome] = (b"100755" if p.stat().st_mode & stat.S_IXUSR else b"100644", objeto.hexdigest().encode())
        else:
            entradas.pop(nome, None)
    for nome, dados in sorted(entradas.items()):
        h.update(os.fsencode(nome) + b"\0" + b" ".join(dados) + b"\0")
    return h.hexdigest()


def gravar(caminho, dados):
    caminho.parent.mkdir(parents=True, exist_ok=True)
    temporario = caminho.with_suffix(".tmp")
    temporario.write_text(json.dumps(dados, indent=2, ensure_ascii=False) + "\n")
    temporario.replace(caminho)


def cache_valido(caminho, chave):
    try:
        r = json.loads(caminho.read_text())
        relatorio = json.loads(Path(r["relatorio"]).read_text())
        valido = all(d.get("assinatura") == chave and d.get("aprovado") is True for d in [r, relatorio])
        if relatorio.get("revisao_visual") == "pendente":
            valido = valido and bool(relatorio.get("capturas")) and all(Path(p).is_file() for p in relatorio["capturas"])
        return r if valido and relatorio.get("estado_preservado") is True else None
    except (OSError, ValueError, KeyError, TypeError):
        return None


def motor_godot(saida):
    motor = shutil.which("godot") or shutil.which("godot4")
    if motor:
        return ["env", "XDG_DATA_HOME=" + str(saida / "dados"), motor], [motor, "--version"]
    if not shutil.which("flatpak"):
        raise RuntimeError("Godot 4 não encontrado")
    # --command=env evita que o Flatpak substitua XDG_DATA_HOME após o override.
    return ["flatpak", "run", "--filesystem=" + str(saida), "--command=env", "org.godotengine.Godot", "XDG_DATA_HOME=" + str(saida / "dados"), "godot"], ["flatpak", "run", "org.godotengine.Godot", "--version"]


def encerrar(processo):
    if processo.poll() is not None: return
    try:
        os.killpg(processo.pid, signal.SIGTERM)
        processo.wait(timeout=5)
    except subprocess.TimeoutExpired:
        os.killpg(processo.pid, signal.SIGKILL)
        processo.wait()
    except ProcessLookupError:
        pass


def preparar_par(saida, papel):
    projeto = preparar(saida / papel)
    p = projeto / "project.godot"
    texto = re.sub(r'^config/(?:use_custom_user_dir|custom_user_dir_name)=.*\n', '', p.read_text(), flags=re.M)
    texto = texto.replace("[application]", '[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="AlgoLand testes harness ' + papel + '"', 1)
    p.write_text(texto.replace('window/size/mode=3', 'window/size/mode=0'))
    return projeto


def executar_par(comandos, saida, limite):
    """Um erro fatal interrompe os dois atores; timeout/CTRL+C não deixam filhos."""
    inicio = time.monotonic()
    processos, logs = {}, {}
    expirou = False
    interrompido = False
    try:
        for papel, comando in comandos.items():
            logs[papel] = (saida / (papel + ".log")).open("w")
            processos[papel] = subprocess.Popen(comando, stdout=logs[papel], stderr=subprocess.STDOUT, start_new_session=True)
        while any(p.poll() is None for p in processos.values()):
            expirou = time.monotonic() - inicio >= limite
            fatal = any(re.search(r"SCRIPT ERROR|Parse Error", (saida / (nome + ".log")).read_text(errors="replace")) for nome in processos)
            falhou = any(p.poll() is not None and p.returncode != 0 for p in processos.values())
            if expirou or fatal or falhou:
                interrompido = True
                break
            time.sleep(0.1)
    finally:
        for processo in processos.values(): encerrar(processo)
        for arquivo in logs.values(): arquivo.close()
    resultados = []
    for nome, processo in processos.items():
        log = saida / (nome + ".log")
        texto = log.read_text(errors="replace")
        avisos, erros, esperados = analisar_log(texto)
        verificacoes = len(re.findall(r"^OK(?:\s|$)", texto, re.M))
        if not verificacoes: erros.append("Nenhuma verificação OK executada")
        resultados.append({"nome": nome, "codigo": processo.returncode, "timeout": expirou,
            "interrompido": interrompido, "segundos": round(time.monotonic() - inicio, 2),
            "avisos_conhecidos": avisos, "erros_esperados": esperados, "erros": erros[:30],
            "total_erros": len(erros), "verificacoes_ok": verificacoes, "log": str(log),
            "aprovado": processo.returncode == 0 and not erros and not expirou and not interrompido})
    return resultados


def coop_online(saida, limite, teste="coop_online"):
    verificacoes = []
    if teste == "expedicao_online":
        for nome in ["teste_coop.mjs", "teste_expedicoes.mjs"]:
            etapa = executar(["node", str(RAIZ / "ferramentas/lobby/servidor" / nome)], saida / (nome+".log"), limite)
            etapa["nome"] = nome
            verificacoes.append(etapa)
            if not etapa["aprovado"]: return verificacoes
    motor, _ = motor_godot(saida)
    projetos = {p: preparar_par(saida, p) for p in ["host", "convidado"]}
    importacao = executar(motor + ["--headless", "--editor", "--path", str(projetos["host"]), "--import", "--quit"], saida / "importacao.log", limite)
    importacao["nome"] = "importacao"
    if not importacao["aprovado"]: return [importacao]
    comunicacao = saida / "rede"
    comunicacao.mkdir()
    with socket.socket() as reserva:
        reserva.bind(("127.0.0.1", 0))
        porta = reserva.getsockname()[1]
    ambiente = dict(os.environ, PORTA=str(porta), ADMIN_PORTA="0", EXIGIR_CONTA="0", SUPABASE_URL="", SUPABASE_CHAVE="")
    with (saida / "servidor.log").open("w") as log:
        servidor = subprocess.Popen(["node", str(RAIZ / "ferramentas/lobby/servidor/servidor.mjs")], env=ambiente, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
        try:
            prazo = time.monotonic() + 10
            while True:
                if servidor.poll() is not None: raise RuntimeError("Servidor local encerrou; consulte servidor.log")
                try:
                    with socket.create_connection(("127.0.0.1", porta), timeout=0.2): break
                except OSError:
                    if time.monotonic() >= prazo: raise RuntimeError("Servidor local não iniciou")
                    time.sleep(0.1)
            comandos = {}
            for papel in ["host", "convidado"]:
                args = ["--somente-conjuntos", "--duelo-ws=ws://127.0.0.1:" + str(porta), "--coop-teste-pasta=" + str(comunicacao)]
                if papel == "host": args.append("--host")
                comandos[papel] = motor + ["--path", str(projetos[papel]), "--script", "res://testes/teste_" + teste + ".gd", "--", *args]
            return [*verificacoes, importacao, *executar_par(comandos, saida, limite)]
        finally:
            encerrar(servidor)


def executar_perfil(args, saida):
    if args.perfil == "coop-online": return coop_online(saida, args.limite)
    if args.perfil == "campanha-online": return coop_online(saida, args.limite, "expedicao_online")
    if args.perfil == "web-browser":
        servidor = None
        fluxo = None
        try:
            url = args.url
            if args.build:
                pasta = args.build.resolve()
                if not (pasta / "jogar/index.html").is_file(): raise ValueError("--build precisa conter jogar/index.html")
                log = saida / "servidor-web.log"
                class Handler(SimpleHTTPRequestHandler):
                    def __init__(self, *a, **kw): super().__init__(*a, directory=str(pasta), **kw)
                    def log_message(self, formato, *a):
                        with log.open("a") as f: f.write((formato % a) + "\n")
                servidor = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
                fluxo = threading.Thread(target=servidor.serve_forever, daemon=True)
                fluxo.start()
                url = "http://127.0.0.1:%d/jogar/" % servidor.server_port
            comando = ["node", str(RAIZ / "ferramentas/projeto/harness_web.mjs"), "--wiki", str(args.wiki), "--url", url, "--saida", str(saida)]
            r = executar(comando, saida / "browser.log", args.limite)
        finally:
            if servidor:
                servidor.shutdown()
                servidor.server_close()
                fluxo.join(timeout=5)
        r["nome"] = "web-browser"
        return [r]
    testes = args.teste or PERFIS[args.perfil]["testes"]
    if somente_python(testes):
        etapas = []
        for nome in testes:
            r = executar([sys.executable, str(RAIZ / "testes" / ("teste_" + nome + ".py"))], saida / (nome + ".log"), args.limite)
            r.update(nome=nome, modo="python")
            etapas.append(r)
        return etapas
    comando = [sys.executable, str(RAIZ / "ferramentas/projeto/testar_tudo.py"), "--saida", str(saida / "testes"), "--limite", str(args.limite)]
    for teste in testes: comando += ["--teste", teste]
    resultado = executar(comando, saida / "runner.log", args.limite * (len(testes) + 1) + 30)
    relatorio = saida / "testes/relatorio.json"
    if not relatorio.is_file():
        resultado["nome"] = "runner"
        return [resultado]
    r = json.loads(relatorio.read_text())
    etapas = [dict(r["importacao"], nome="importacao"), *r["testes"]]
    if not resultado["aprovado"] and all(e["aprovado"] for e in etapas):
        resultado["nome"] = "runner"
        etapas.append(resultado)
    return etapas


def somente_python(testes):
    return bool(testes) and all((RAIZ / "testes" / ("teste_" + n + ".py")).is_file() and not (RAIZ / "testes" / ("teste_" + n + ".gd")).exists() for n in testes)


def testar(args):
    if args.perfil == "web-browser" and not (args.url or args.build): raise ValueError("web-browser exige --url ou --build")
    selecao = {"perfil": args.perfil, "testes": args.teste, "limite": args.limite}
    raiz_cache = args.cache.expanduser().resolve()
    # Contextos de navegador e publicação sempre consultam o estado atual.
    if args.perfil == "web-browser":
        versao = subprocess.check_output(["node", "--version"], text=True, timeout=20).strip()
    elif somente_python(args.teste or PERFIS[args.perfil]["testes"]):
        versao = sys.version
    else:
        versao = "Python " + sys.version.split()[0] + " / " + subprocess.check_output(motor_godot(raiz_cache)[1], text=True, timeout=20).strip()
        if args.perfil in ["coop-online", "campanha-online"]:
            versao += " / Node " + subprocess.check_output(["node", "--version"], text=True, timeout=20).strip()
    chave = assinatura(RAIZ, versao, selecao)
    indice = raiz_cache / "cache" / (chave + ".json")
    anterior = cache_valido(indice, chave) if not args.forcar and args.perfil not in ["web-browser", "campanha-online"] else None
    if anterior:
        print("OK " + args.perfil + " (reutilizado; mesmo estado do projeto)")
        print("Relatório: " + anterior["relatorio"])
        if anterior.get("revisao_visual") == "pendente": print("Revisão visual continua pendente; veja as capturas no relatório.")
        return 0
    raiz_cache.mkdir(parents=True, exist_ok=True)
    saida = Path(tempfile.mkdtemp(prefix="execucao-", dir=raiz_cache))
    visual = PERFIS[args.perfil]["visual"] or any(t in GRAFICOS for t in args.teste or [])
    relatorio = {"assinatura": chave, "perfil": args.perfil, "motor": versao, "aprovado": False, "etapas": [], "revisao_visual": "pendente" if visual else "nao_aplicavel"}
    if args.perfil == "mapas-modulares":
        relatorio["criterios_visuais"] = [
            "Água: conferir atlas com quadros próprios, grade, ordem, FPS/durações e folha de contato.",
            "Água: observar dois ciclos completos no Godot, incluindo último→primeiro, sem saltos ou flashes.",
            "Água: revisar encaixes entre tiles em todos os quadros, margens separadas e colisões estáveis.",
            "Água: conferir quatro estações e detalhe em desktop; registrar evidências e pendências.",
        ]
    caminho = saida / "relatorio.json"
    print("Executando " + args.perfil + "; logs: " + str(saida), flush=True)
    try:
        relatorio["etapas"] = executar_perfil(args, saida)
        for etapa in relatorio["etapas"]:
            if etapa.get("nome") == "mapas_modulares" and etapa.get("log"):
                for linha in Path(etapa["log"]).read_text(errors="replace").splitlines():
                    if linha.startswith("METRICAS "):
                        etapa["metricas"] = json.loads(linha.removeprefix("METRICAS "))
        relatorio["aprovado"] = bool(relatorio["etapas"]) and all(e["aprovado"] for e in relatorio["etapas"])
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as erro:
        relatorio["erro"] = str(erro)
    finally:
        # Se alguém editou o projeto durante o teste, o resultado não entra no cache.
        relatorio["estado_preservado"] = chave == assinatura(RAIZ, versao, selecao)
        if not relatorio["estado_preservado"]:
            relatorio["aprovado"] = False
            relatorio["erro"] = "Arquivos mudaram durante o teste; esta execução não valida o estado atual"
        relatorio["capturas"] = [str(p) for p in saida.rglob("*.png")]
        gravar(caminho, relatorio)
        gravar(raiz_cache / "ultimo.json", {"relatorio": str(caminho)})
    for etapa in relatorio["etapas"]:
        print(("OK " if etapa["aprovado"] else "FALHA ") + etapa["nome"])
        for erro in etapa.get("erros", [])[:3]: print("  " + erro)
    if relatorio.get("erro"): print("FALHA " + relatorio["erro"])
    if relatorio["aprovado"] and relatorio["estado_preservado"] and args.perfil != "web-browser":
        gravar(indice, {"assinatura": chave, "aprovado": True, "relatorio": str(caminho), "revisao_visual": relatorio["revisao_visual"]})
    if relatorio["revisao_visual"] == "pendente": print("Revisão visual: pendente; capturas listadas no relatório.")
    print("Resultado: " + ("OK" if relatorio["aprovado"] else "FALHA") + "; relatório: " + str(caminho))
    return 0 if relatorio["aprovado"] else 1


def contexto():
    # Exibe nomes, sem abrir o mapa inteiro nem ler conteúdo de recursos.
    arquivos = alterados(caminhos=[p for p in ENTRADAS if p not in ["assets", "addons"]])
    print("Alterados: " + (", ".join(arquivos[:20]) or "nenhum"))
    if len(arquivos) > 20: print("Mais %d caminhos; use git diff focado no sistema." % (len(arquivos) - 20))
    recomendados = [p for p, d in PERFIS.items() if d["caminhos"] and any(n.startswith(c) for n in arquivos for c in d["caminhos"])]
    print("Perfis sugeridos: " + (", ".join(recomendados) or "selecione pelo sistema alterado"))
    print("Perfis disponíveis: " + ", ".join(PERFIS))
    print("Teste: python3 ferramentas/projeto/harness.py testar --perfil NOME")
    print("Referência: ferramentas/projeto/HARNESS.md")
    return 0


def retomar(args):
    """Gera passagem curta sem tratar relatórios antigos como aprovação atual."""
    arquivos = alterados(caminhos=[p for p in ENTRADAS if p not in ["assets", "addons"]])
    linhas = ["Projeto: AlgoLand", "Objetivo: " + args.objetivo,
              "Estado: " + git(RAIZ, "rev-parse", "--short", "HEAD").decode().strip(),
              "Alterados: " + (", ".join(arquivos[:20]) or "nenhum")]
    if len(arquivos) > 20:
        linhas.append("Mais %d caminhos; consultar diff focado." % (len(arquivos) - 20))
    linhas += ["Pendente: " + p for p in args.pendente]
    linhas += ["Começar: python3 ferramentas/projeto/harness.py contexto",
               "Validar: testar --perfil NOME (ou selecionado --teste NOME).",
               "Relatórios antigos exigem confirmação do harness para reuso; revisão visual continua obrigatória.",
               "Publicar somente quando solicitado; o resumo não transfere autorização de publicação."]
    conteudo = "\n".join(linhas) + "\n"
    if args.saida:
        # Evita sobrescrever um arquivo de trabalho por engano.
        with args.saida.open("x") as arquivo:
            arquivo.write(conteudo)
        print("Resumo: " + str(args.saida))
    else:
        print(conteudo, end="")
    return 0


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    comandos = parser.add_subparsers(dest="comando", required=True)
    comandos.add_parser("contexto", help="Lista mudanças e perfis pertinentes, sem ler o mapa inteiro")
    resumo = comandos.add_parser("retomar", help="Prepara um resumo curto para outra conversa; não abre chat")
    resumo.add_argument("--objetivo", required=True)
    resumo.add_argument("--pendente", action="append", default=[])
    resumo.add_argument("--saida", type=Path, help="Arquivo novo opcional; por padrão imprime o resumo")
    teste = comandos.add_parser("testar", help="Executa um perfil ou reutiliza o resultado do mesmo estado")
    teste.add_argument("--perfil", choices=PERFIS, required=True)
    teste.add_argument("--teste", action="append", help="Restringe testes do runner comum; nome sem teste_/.gd")
    teste.add_argument("--forcar", action="store_true", help="Ignora resultados anteriores")
    teste.add_argument("--limite", type=int, default=180)
    teste.add_argument("--cache", type=Path, default=Path("/tmp/algoland-harness"))
    teste.add_argument("--wiki", type=Path, default=RAIZ.parent / "AlgoLand-wiki")
    teste.add_argument("--url", help="Endereço explícito do build para o perfil web-browser")
    teste.add_argument("--build", type=Path, help="Dist da wiki: inicia/encerra um servidor HTTP local para web-browser")
    publicacao = comandos.add_parser("publicacao", help="Confere pacotes assinados locais e, opcionalmente, no ar")
    publicacao.add_argument("--wiki", type=Path, default=RAIZ.parent / "AlgoLand-wiki")
    publicacao.add_argument("--url", help="URL HTTPS/localhost da pasta jogar; omita para conferir só arquivos locais")
    publicacao.add_argument("--esperar", type=int, default=0, help="Segundos para aguardar a versão local aparecer no endereço")
    publicacao.add_argument("--saida", type=Path)
    publicar = comandos.add_parser("publicar", help="Executa o publicador existente, com conferência antes/depois do push")
    publicar.add_argument("--resumo", required=True)
    publicar.add_argument("--simular", action="store_true")
    args = parser.parse_args(argv)
    if args.comando == "testar" and args.limite <= 0: parser.error("--limite deve ser positivo")
    if args.comando == "testar" and args.perfil == "selecionado" and not args.teste: parser.error("selecionado exige --teste NOME; não executa a bateria inteira")
    if args.comando == "testar" and args.teste and args.perfil in ["coop-online", "campanha-online", "web-browser"]: parser.error("Este perfil não usa --teste")
    if args.comando == "testar" and args.build and (args.url or args.perfil != "web-browser"): parser.error("--build é exclusivo de web-browser e não combina com --url")
    try:
        if args.comando == "contexto": return contexto()
        if args.comando == "retomar": return retomar(args)
        if args.comando == "testar": return testar(args)
        if args.comando == "publicar":
            comando = [sys.executable, str(RAIZ / "ferramentas/projeto/publicar_conteudo.py"), "--resumo", args.resumo]
            if args.simular: comando.append("--simular")
            return subprocess.call(comando, cwd=RAIZ)
        from harness_publicacao import conferir
        return conferir(RAIZ, args.wiki.resolve(), args.url, args.esperar, args.saida)
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as erro:
        print("FALHA: " + str(erro), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
