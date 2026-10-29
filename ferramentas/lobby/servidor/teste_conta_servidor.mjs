// Conferência do token da conta no "entrar": node teste_conta_servidor.mjs
// Usa um Supabase falso (só /auth/v1/user) e dois servidores reais em porta local: um que não exige conta e um que exige.
import http from 'node:http';
import assert from 'node:assert/strict';
import { criarServidor, CONFIG } from './servidor.mjs';
import { criarVerificadorConta } from './conta.mjs';

let falhas = 0;
const conferir = (ok, nome) => { console.log(ok ? 'OK   ' : 'FALHA', nome); if (!ok) falhas++; };
const hex = (n) => Array.from({ length: 32 }, () => Math.floor(Math.random() * 16).toString(16)).join('') + String(n).padStart(2, '0');
const TOKEN_BOM = 'token-bom-' + 'x'.repeat(30);
let consultas = 0;
const falso = http.createServer((req, res) => {
  consultas++;
  const ok = req.url === '/auth/v1/user' && req.headers.apikey === 'chave-publica' && req.headers.authorization === `Bearer ${TOKEN_BOM}`;
  res.writeHead(ok ? 200 : 401, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify(ok ? { id: '11111111-2222-3333-4444-555555555555', email: 'a@b.c' } : { msg: 'invalido' }));
});
await new Promise((r) => falso.listen(0, '127.0.0.1', r));
const url = `http://127.0.0.1:${falso.address().port}`;

// Verificador isolado
const v = criarVerificadorConta({ url, chave: 'chave-publica', ttlMs: 60000 });
conferir(await v.verificar(TOKEN_BOM) === '11111111-2222-3333-4444-555555555555', 'token valido devolve o id da conta');
conferir(await v.verificar(TOKEN_BOM) !== null && consultas === 1, 'segunda conferencia sai do cache');
conferir(await v.verificar('token-ruim-' + 'y'.repeat(30)) === null, 'token invalido recusado');
conferir(await v.verificar('curto') === null && await v.verificar(undefined) === null, 'token curto ou ausente recusado sem consultar');
conferir(await criarVerificadorConta({}).verificar(TOKEN_BOM) === null, 'sem URL configurada nada e aceito');

async function entrar(porta, codigo, token) {
  const ws = new WebSocket(`ws://127.0.0.1:${porta}`);
  const mensagens = [];
  let fechou = false;
  ws.onmessage = (e) => mensagens.push(JSON.parse(e.data));
  ws.onclose = () => { fechou = true; };
  await new Promise((ok, no) => { ws.onopen = ok; ws.onerror = no; });
  const corpo = { t: 'entrar', codigo, geracao: hex(1), estado: { x: 1, y: 1, mapa: 0, apelido: 'ANA', aparencia: { versao: 1 } } };
  if (token !== undefined) corpo.token = token;
  ws.send(JSON.stringify(corpo));
  const fim = Date.now() + 3000;
  while (Date.now() < fim && !mensagens.length && !fechou) await new Promise((r) => setTimeout(r, 20));
  return { ws, mensagens, fechou: () => fechou };
}

// Servidor que não exige conta
const livre = criarServidor({ ...CONFIG, porta: 0, portaAdmin: 0, expiraMs: 60000, supabaseUrl: url, supabaseChave: 'chave-publica', exigirConta: false });
const portaLivre = await livre.iniciar();
let c = await entrar(portaLivre, hex(2), undefined);
conferir(c.mensagens.length > 0 && !c.mensagens[0].erro, 'sem exigir: entra sem token (versao antiga do jogo)');
c.ws.close();
c = await entrar(portaLivre, hex(3), TOKEN_BOM);
conferir(c.mensagens.length > 0 && !c.mensagens[0].erro, 'sem exigir: entra com token valido');
c.ws.close();
c = await entrar(portaLivre, hex(4), 'token-ruim-' + 'z'.repeat(30));
conferir(c.mensagens.length > 0 && !c.mensagens[0].erro, 'sem exigir: token invalido nao impede a entrada');
c.ws.close();
await livre.parar();

// Servidor que exige conta
const estrito = criarServidor({ ...CONFIG, porta: 0, portaAdmin: 0, expiraMs: 60000, supabaseUrl: url, supabaseChave: 'chave-publica', exigirConta: true });
const portaEstrita = await estrito.iniciar();
c = await entrar(portaEstrita, hex(5), undefined);
conferir(c.mensagens[0]?.erro === 'conta_obrigatoria', 'exigindo: sem token e recusado com conta_obrigatoria');
c = await entrar(portaEstrita, hex(6), 'token-ruim-' + 'w'.repeat(30));
conferir(c.mensagens[0]?.erro === 'conta_obrigatoria', 'exigindo: token invalido e recusado');
c = await entrar(portaEstrita, hex(7), TOKEN_BOM);
conferir(c.mensagens.length > 0 && !c.mensagens[0].erro, 'exigindo: token valido entra');
c.ws.close();
await estrito.parar();
falso.close();
console.log(falhas ? `CONTA NO SERVIDOR: ${falhas} falhas` : 'CONTA NO SERVIDOR: conferencia do token, cache e modo estrito OK.');
process.exit(falhas ? 1 : 0);
