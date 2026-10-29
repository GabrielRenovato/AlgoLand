#!/usr/bin/env python3
"""Imita o Supabase Auth (e-mail e senha) e a RPC vincular_conta para testar o cliente sem criar conta em produção.
Uso: python3 servidor_falso.py [porta]   (só escuta em 127.0.0.1; dados na memória)"""
import json
import sys
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs

USUARIOS = {}   # email -> {id, senha, meta}
SESSOES = {}    # access_token -> id
RENOVACOES = {} # refresh_token -> id
PERFIS = {}     # id -> {apelido, codigo}
NUVEM = {}      # id -> {rev, pacote, versao_app, versao_save, aparelho, anterior}


def sessao(id_usuario, email):
    acesso, renovacao = uuid.uuid4().hex, uuid.uuid4().hex
    SESSOES[acesso] = id_usuario
    RENOVACOES[renovacao] = id_usuario
    return {"access_token": acesso, "refresh_token": renovacao, "expires_in": 3600,
            "user": {"id": id_usuario, "email": email, "user_metadata": USUARIOS[email]["meta"]}}


class Manipulador(BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def responder(self, status, corpo=None):
        dados = b"" if corpo is None else json.dumps(corpo).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(dados)))
        self.end_headers()
        self.wfile.write(dados)

    def do_POST(self):
        if not self.headers.get("apikey"):
            return self.responder(401, {"message": "sem apikey"})
        tamanho = int(self.headers.get("Content-Length", 0))
        corpo = json.loads(self.rfile.read(tamanho) or b"{}")
        url = urlparse(self.path)
        grupo = parse_qs(url.query).get("grant_type", [""])[0]
        auth = self.headers.get("Authorization", "").removeprefix("Bearer ")
        if url.path == "/auth/v1/signup":
            email = corpo.get("email", "")
            if email in USUARIOS:
                return self.responder(422, {"error_code": "user_already_exists", "msg": "User already registered"})
            if len(corpo.get("password", "")) < 6:
                return self.responder(422, {"error_code": "weak_password", "msg": "weak"})
            USUARIOS[email] = {"id": str(uuid.uuid4()), "senha": corpo["password"], "meta": corpo.get("data", {})}
            return self.responder(200, sessao(USUARIOS[email]["id"], email))
        if url.path == "/auth/v1/token" and grupo == "password":
            u = USUARIOS.get(corpo.get("email", ""))
            if not u or u["senha"] != corpo.get("password"):
                return self.responder(400, {"error_code": "invalid_credentials", "msg": "Invalid login credentials"})
            return self.responder(200, sessao(u["id"], corpo["email"]))
        if url.path == "/auth/v1/token" and grupo == "refresh_token":
            id_usuario = RENOVACOES.get(corpo.get("refresh_token", ""))
            if not id_usuario:
                return self.responder(400, {"error_code": "refresh_token_not_found", "msg": "invalid"})
            email = next(e for e, u in USUARIOS.items() if u["id"] == id_usuario)
            return self.responder(200, sessao(id_usuario, email))
        if url.path == "/auth/v1/recover":
            return self.responder(200, {})
        if url.path == "/auth/v1/logout":
            SESSOES.pop(auth, None)
            return self.responder(204)
        if url.path == "/rest/v1/rpc/vincular_conta":
            id_usuario = SESSOES.get(auth)
            if not id_usuario:
                return self.responder(200, {"estado": "sem_login"})
            codigo = corpo.get("p_codigo", "")
            if not 24 <= len(codigo) <= 64:
                return self.responder(200, {"estado": "codigo_invalido"})
            atual = PERFIS.get(id_usuario)
            if atual:
                if atual["codigo"] == codigo:
                    return self.responder(200, {"estado": "ok", "apelido": atual["apelido"]})
                return self.responder(200, {"estado": "outro_codigo", "codigo_secreto": atual["codigo"], "apelido": atual["apelido"]})
            if any(p["codigo"] == codigo for p in PERFIS.values()):
                return self.responder(200, {"estado": "codigo_em_uso"})
            PERFIS[id_usuario] = {"codigo": codigo, "apelido": (corpo.get("p_apelido") or "JOGADOR")[:24]}
            return self.responder(200, {"estado": "ok", "apelido": PERFIS[id_usuario]["apelido"]})
        if url.path.startswith("/rest/v1/rpc/") and url.path.split("/")[-1] in ("meta_nuvem", "salvar_nuvem", "baixar_nuvem", "trocar_codigo_conta"):
            return self.nuvem(url.path.split("/")[-1], SESSOES.get(auth), corpo)
        self.responder(404, {"message": "rota desconhecida"})

    def nuvem(self, funcao, id_usuario, corpo):
        if not id_usuario:
            return self.responder(200, {"estado": "sem_login"})
        s = NUVEM.get(id_usuario)
        if funcao == "meta_nuvem":
            if not s:
                return self.responder(200, {"estado": "ok", "existe": False})
            return self.responder(200, {"estado": "ok", "existe": True, "rev": s["rev"], "atualizado_em": "2026-10-29T12:00:00Z",
                                        "aparelho": s["aparelho"], "versao_app": s["versao_app"], "versao_save": s["versao_save"]})
        if funcao == "baixar_nuvem":
            if not s:
                return self.responder(200, {"estado": "ok", "existe": False})
            pacote = s["anterior"] if corpo.get("p_anterior") else s["pacote"]
            if pacote is None:
                return self.responder(200, {"estado": "ok", "existe": False})
            return self.responder(200, {"estado": "ok", "existe": True, "rev": s["rev"], "pacote": pacote, "versao_app": s["versao_app"],
                                        "versao_save": s["versao_save"], "aparelho": s["aparelho"], "atualizado_em": "2026-10-29T12:00:00Z"})
        if funcao == "trocar_codigo_conta":
            codigo = corpo.get("p_codigo", "")
            if id_usuario not in PERFIS:
                return self.responder(200, {"estado": "sem_perfil"})
            if any(p["codigo"] == codigo for i, p in PERFIS.items() if i != id_usuario):
                return self.responder(200, {"estado": "codigo_em_uso"})
            PERFIS[id_usuario]["codigo"] = codigo
            return self.responder(200, {"estado": "ok"})
        pacote = corpo.get("p_pacote", "")
        if not 2 <= len(pacote) <= 1500000:
            return self.responder(200, {"estado": "tamanho_invalido"})
        esperada = corpo.get("p_rev_esperada")
        if not s:
            if (esperada or 0) != 0:
                return self.responder(200, {"estado": "conflito", "rev": 0})
            NUVEM[id_usuario] = {"rev": 1, "pacote": pacote, "versao_app": corpo.get("p_versao_app", ""), "versao_save": corpo.get("p_versao_save", 0),
                                 "aparelho": corpo.get("p_aparelho", ""), "anterior": None}
            return self.responder(200, {"estado": "ok", "rev": 1})
        if esperada != s["rev"]:
            return self.responder(200, {"estado": "conflito", "rev": s["rev"], "atualizado_em": "2026-10-29T12:00:00Z", "aparelho": s["aparelho"]})
        s.update({"anterior": s["pacote"], "pacote": pacote, "rev": s["rev"] + 1, "versao_app": corpo.get("p_versao_app", ""),
                  "versao_save": corpo.get("p_versao_save", 0), "aparelho": corpo.get("p_aparelho", "")})
        return self.responder(200, {"estado": "ok", "rev": s["rev"]})


if __name__ == "__main__":
    porta = int(sys.argv[1]) if len(sys.argv) > 1 else 8799
    ThreadingHTTPServer(("127.0.0.1", porta), Manipulador).serve_forever()
