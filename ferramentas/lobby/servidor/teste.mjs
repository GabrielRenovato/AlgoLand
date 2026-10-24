// Testes do servidor com clientes WebSocket reais em porta local: node teste.mjs
import { criarServidor, CONFIG } from './servidor.mjs';
import { proibido, limparApelido } from './filtro.mjs';

let falhas = 0;
const conferir = (ok, nome, detalhe = '') => { console.log(ok ? 'OK ' : 'FALHA', nome, ok ? '' : detalhe); if (!ok) falhas++; };
const esperar = (ms) => new Promise((r) => setTimeout(r, ms));
const aparencia = { versao: 1, pele: 0, cabelo: 1 };
const hex = (n) => Array.from({ length: 32 }, () => Math.floor(Math.random() * 16).toString(16)).join('') + String(n).padStart(2, '0');

class Cliente {
  constructor(url, codigo) { this.url = url; this.codigo = codigo; this.msgs = []; this.ultimo = null; this.fechado = false; }
  async conectar(estado, depois = 0) {
    this.ws = new WebSocket(this.url);
    this.ws.onmessage = (e) => { const d = JSON.parse(e.data); this.msgs.push(d); if (!d.erro) this.ultimo = d; };
    this.ws.onclose = () => { this.fechado = true; };
    await new Promise((r, j) => { this.ws.onopen = r; this.ws.onerror = j; });
    this.geracao = hex(1);
    this.ws.send(JSON.stringify({ t: 'entrar', codigo: this.codigo, geracao: this.geracao, estado, depois }));
    await this.esperarSnapshot(() => true);
  }
  estado(extra) { this.ws.send(JSON.stringify({ t: 'estado', estado: { x: 100, y: 100, direcao: 0, andando: false, apelido: 'ANA', aparencia, ...extra } })); }
  msg(texto, envio = hex(2)) { this.envio = envio; this.ws.send(JSON.stringify({ t: 'msg', texto, envio })); return envio; }
  async esperarSnapshot(cond, limite = 3000) {
    const fim = Date.now() + limite;
    while (Date.now() < fim) { if (this.ultimo && cond(this.ultimo)) return this.ultimo; await esperar(20); }
    return this.ultimo;
  }
  fechar() { this.ws.close(); }
}

const servidor = criarServidor({ ...CONFIG, porta: 0, tickMs: 50, expiraMs: 60000, maxPorMapa: 3 });
const porta = await servidor.iniciar();
const url = `ws://127.0.0.1:${porta}`;
const cod = (n) => `codigo_secreto_de_teste_numero_${n}_abcdefghij`;

// Filtro
conferir(proibido('fuck') && proibido('p0rra') && proibido('cu') && proibido('f0der') && !proibido('Cuca') && !proibido('Ana'), 'filtro de palavras igual ao do banco');
conferir(limparApelido('  \u0007Fulano de Tal com nome longo ') === 'Fulano de Tal co' && limparApelido('merda') === 'sem apelido', 'apelido limpo e limitado a 16');

const saude = await (await fetch(`http://127.0.0.1:${porta}/saude`)).json();
conferir(saude.ok === true, '/saude responde');

const a = new Cliente(url, cod(1)), b = new Cliente(url, cod(2)), c = new Cliente(url, cod(3));
await a.conectar({ x: 100, y: 100, mapa: 2, apelido: 'ANA', aparencia, direcao: 1, andando: false });
await b.conectar({ x: 200, y: 150, mapa: 2, apelido: 'BETO', aparencia });
await c.conectar({ x: 300, y: 300, mapa: 1, apelido: 'CIDA', aparencia });
conferir(a.ultimo.eu.length === 36, 'identidade é um UUID de 36 caracteres');
let sa = await a.esperarSnapshot((s) => s.jogadores.length === 2);
conferir(sa.jogadores.length === 2 && sa.jogadores.every((p) => p.mapa === 2), 'mesmo mapa se enxerga', JSON.stringify(sa.jogadores.map((p) => p.mapa)));
conferir(sa.jogadores.some((p) => p.apelido === 'BETO' && p.aparencia?.versao === 1), 'apelido e aparência chegam na primeira vez');
let sc = await c.esperarSnapshot((s) => s.jogadores.length === 1);
conferir(sc.jogadores.length === 1 && sc.jogadores[0].apelido === 'CIDA', 'outro mapa não enxerga');

// Movimento chega, e a aparência não se repete
b.estado({ x: 400, y: 420, mapa: 2, apelido: 'BETO', direcao: 3, andando: true });
sa = await a.esperarSnapshot((s) => s.jogadores.some((p) => p.x === 400));
const beto = sa.jogadores.find((p) => p.apelido === 'BETO');
conferir(beto && beto.x === 400 && beto.y === 420 && beto.direcao === 3 && beto.andando === true, 'movimento chega ao outro jogador');
conferir(beto && beto.aparencia === null, 'aparência já conhecida não é reenviada');
conferir(beto && typeof beto.instante === 'number', 'amostra traz o instante');

// Troca de mapa
b.estado({ x: 300, y: 300, mapa: 1, apelido: 'BETO' });
sa = await a.esperarSnapshot((s) => s.jogadores.length === 1);
sc = await c.esperarSnapshot((s) => s.jogadores.length === 2);
conferir(sa.jogadores.length === 1 && sc.jogadores.length === 2, 'quem muda de mapa sai de um e aparece no outro');
conferir(sc.jogadores.find((p) => p.apelido === 'BETO')?.aparencia?.versao === 1, 'reentrada reenvia a aparência');

// Chat global, mesmo em mapa sem presença
a.estado({ x: 100, y: 100, mapa: 0, apelido: 'ANA' });
const envio = a.msg('olá mundo');
const sb = await b.esperarSnapshot((s) => s.mensagens.some((m) => m.texto === 'olá mundo'));
conferir(sb.mensagens.some((m) => m.texto === 'olá mundo' && m.apelido === 'ANA'), 'chat chega a todos os mapas');
sa = await a.esperarSnapshot((s) => s.confirmado === envio);
conferir(sa.confirmado === envio && sa.aviso === '', 'remetente recebe a confirmação');
a.msg('olá mundo', envio);
await esperar(200);
conferir(servidor.jogadores.size === 3, 'servidor segue com os três');
const ouvidas = b.msgs.flatMap((s) => s.mensagens ?? []).filter((m) => m.texto === 'olá mundo').length;
conferir(ouvidas === 1, 'mesmo envio não duplica a mensagem', String(ouvidas));
await esperar(600);
const outro = a.msg('merda aqui');
sa = await a.esperarSnapshot((s) => s.confirmado === outro);
conferir(sa.aviso === 'mensagem_recusada' && !b.msgs.flatMap((s) => s.mensagens ?? []).some((m) => m.texto === 'merda aqui'), 'palavrão é recusado');
a.msg('primeira');
const segunda = a.msg('segunda logo em seguida');
sa = await a.esperarSnapshot((s) => s.aviso === 'aguarde_mensagem');
conferir(sa.aviso === 'aguarde_mensagem' && segunda !== null, 'intervalo mínimo entre mensagens');

// Histórico e reconexão com o mesmo perfil
const d = new Cliente(url, cod(4));
await d.conectar({ x: 1, y: 1, mapa: 1, apelido: 'DADA', aparencia });
conferir(d.ultimo.mensagens.some((m) => m.texto === 'olá mundo'), 'quem entra recebe o histórico');
const idAntes = c.ultimo.eu;
const c2 = new Cliente(url, cod(3));
await c2.conectar({ x: 5, y: 5, mapa: 1, apelido: 'CIDA', aparencia }, 9999);
await esperar(100);
conferir(c2.ultimo.eu === idAntes && c.fechado, 'mesmo perfil mantém a identidade e derruba a conexão antiga');

// Lotação do mapa: o quarto fica sem avatar, mas conversa
const e = [new Cliente(url, cod(5)), new Cliente(url, cod(6)), new Cliente(url, cod(7)), new Cliente(url, cod(8))];
for (const cl of e) await cl.conectar({ x: 9, y: 9, mapa: 3, apelido: 'LOTADO', aparencia });
await esperar(200);
const naPraia = [...servidor.jogadores.values()].filter((p) => p.mapa === 3).length;
conferir(naPraia === 3, 'lotação por mapa respeitada', String(naPraia));
const semAvatar = e[3].ultimo;
conferir(semAvatar.jogadores.length === 0 && servidor.jogadores.size >= 8, 'o excedente fica conectado sem avatar');

// Validação
const f = new Cliente(url, cod(9));
await f.conectar({ x: 9, y: 9, mapa: 2, apelido: 'VALIDA', aparencia });
f.estado({ x: 5000, y: 1, mapa: 2 });
await f.esperarSnapshot(() => false, 300);
conferir(f.msgs.some((m) => m.erro === 'posicao_invalida'), 'posição fora do envelope é recusada');
f.estado({ x: 5, y: 1, mapa: 9 });
await f.esperarSnapshot(() => false, 300);
conferir(f.msgs.some((m) => m.erro === 'estado_invalido'), 'mapa inválido é recusado');
const ruim = new WebSocket(url);
await new Promise((r) => { ruim.onopen = () => { ruim.send(JSON.stringify({ t: 'entrar', codigo: 'curto', geracao: 'x' })); }; ruim.onclose = r; });
conferir(true, 'entrada com código inválido é encerrada');

// Sair e expirar
b.ws.send(JSON.stringify({ t: 'sair' }));
await esperar(150);
conferir(![...servidor.jogadores.values()].some((p) => p.apelido === 'BETO'), 'sair remove na hora');
for (const cl of [a, c2, d, ...e, f]) try { cl.fechar(); } catch {}
await servidor.parar();

// Expiração: quem para de enviar estado some (servidor próprio, com prazo curto)
const curto = criarServidor({ ...CONFIG, porta: 0, tickMs: 50, expiraMs: 400 });
const portaCurta = await curto.iniciar();
const g = new Cliente(`ws://127.0.0.1:${portaCurta}`, cod(10));
await g.conectar({ x: 1, y: 1, mapa: 1, apelido: 'SUMIDO', aparencia });
conferir(curto.jogadores.size === 1, 'jogador conectado');
await esperar(900);
conferir(curto.jogadores.size === 0 && g.fechado, 'quem para de enviar expira e é desconectado');
await curto.parar();
console.log(falhas ? `FALHAS: ${falhas}` : 'SERVIDOR: todos os testes OK');
process.exit(falhas ? 1 : 0);
