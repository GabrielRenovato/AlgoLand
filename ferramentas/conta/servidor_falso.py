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
        self.responder(404, {"message": "rota desconhecida"})


if __name__ == "__main__":
    porta = int(sys.argv[1]) if len(sys.argv) > 1 else 8799
    ThreadingHTTPServer(("127.0.0.1", porta), Manipulador).serve_forever()
