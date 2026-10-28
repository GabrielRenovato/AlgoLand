// Testes das salas de duelo com clientes WebSocket reais em porta local: node teste_duelo.mjs
import { criarServidor, CONFIG } from './servidor.mjs';

let falhas = 0;
const conferir = (ok, nome, detalhe = '') => { console.log(ok ? 'OK ' : 'FALHA', nome, ok ? '' : detalhe); if (!ok) falhas++; };
const esperar = (ms) => new Promise((r) => setTimeout(r, ms));
const hex = () => Array.from({ length: 32 }, () => Math.floor(Math.random() * 16).toString(16)).join('');
const aparencia = { versao: 1, pele: 0, cabelo: 1 };

class Cliente {
  constructor(url, codigo, apelido) { this.url = url; this.codigo = codigo; this.apelido = apelido; this.msgs = []; }
  async conectar() {
    this.ws = new WebSocket(this.url);
    this.ws.onmessage = (e) => this.msgs.push(JSON.parse(e.data));
    await new Promise((r, j) => { this.ws.onopen = r; this.ws.onerror = j; });
    this.ws.send(JSON.stringify({ t: 'entrar', codigo: this.codigo, geracao: hex(), estado: { x: 1, y: 1, mapa: 0, apelido: this.apelido, aparencia } }));
    await this.esperar((m) => m.eu);
    this.eu = this.msgs.find((m) => m.eu).eu;
  }
  enviar(obj) { this.ws.send(JSON.stringify(obj)); }
  async esperar(cond, limite = 3000) {
    const fim = Date.now() + limite;
    while (Date.now() < fim) { const m = this.msgs.find(cond); if (m) return m; await esperar(15); }
    return null;
  }
  limpar() { this.msgs = []; }
}

const servidor = criarServidor({ ...CONFIG, porta: 0, portaAdmin: 0, tickMs: 50, expiraMs: 60000, duelo: { intervaloRoundMs: 100 } });
const porta = await servidor.iniciar();
const url = `ws://127.0.0.1:${porta}`;
const a = new Cliente(url, 'codigo_secreto_duelo_a_abcdefghijklmn', 'ANA');
const b = new Cliente(url, 'codigo_secreto_duelo_b_abcdefghijklmn', 'BETO');
await a.conectar(); await b.conectar();

a.enviar({ t: 'duelo_criar', titulo: 'Sala da Ana', senha: '123', perfil: { roupas_3d: { cabelo: 'cabelo_cacheado' } } });
const salaA = await a.esperar((m) => m.t === 'duelo_sala');
conferir(salaA?.sala.titulo === 'Sala da Ana' && salaA.sala.senha === true && salaA.sala.jogadores.length === 1 && salaA.sala.dono === a.eu, 'criar sala com senha');
const id = salaA.sala.id;

b.enviar({ t: 'duelo_salas' });
const lista = await b.esperar((m) => m.t === 'duelo_salas');
conferir(lista?.salas.length === 1 && lista.salas[0].senha === true && lista.salas[0].jogadores === 1 && !JSON.stringify(lista).includes('123'), 'lista mostra a sala sem vazar a senha');

b.enviar({ t: 'duelo_entrar', id, senha: 'errada' });
conferir((await b.esperar((m) => m.t === 'duelo_erro'))?.erro === 'senha_errada', 'senha errada é recusada');
b.limpar(); a.limpar();
b.enviar({ t: 'duelo_entrar', id, senha: '123', perfil: { roupas_3d: { cabelo: 'cabelo_curto' } } });
const salaB = await b.esperar((m) => m.t === 'duelo_sala' && m.sala.jogadores.length === 2);
conferir(salaB && salaB.sala.jogadores[0].perfil?.roupas_3d?.cabelo === 'cabelo_cacheado', 'entrar com senha certa e ver o perfil do dono');

a.limpar();
a.enviar({ t: 'duelo_iniciar' });
conferir((await a.esperar((m) => m.t === 'duelo_erro'))?.erro === 'adversario_nao_pronto', 'dono não começa sem o adversário pronto');
b.enviar({ t: 'duelo_pronto', pronto: true });
await a.esperar((m) => m.t === 'duelo_sala' && m.sala.jogadores.some((j) => j.id === b.eu && j.pronto));
a.limpar(); b.limpar();
a.enviar({ t: 'duelo_iniciar' });
const r1 = await b.esperar((m) => m.t === 'duelo_round');
conferir(r1?.round === 1 && r1.lados[a.eu] === 0 && r1.lados[b.eu] === 1, 'partida começa no round 1 com lados definidos');

a.enviar({ t: 'duelo_estado', e: { x: 10, y: 20, acao: 'correr' } });
conferir((await b.esperar((m) => m.t === 'duelo_estado'))?.e.acao === 'correr', 'estado é repassado ao adversário');
b.enviar({ t: 'duelo_evento', ev: { tipo: 'golpe', dano: 7 } });
conferir((await a.esperar((m) => m.t === 'duelo_evento'))?.ev.dano === 7, 'golpe é repassado ao adversário');
b.enviar({ t: 'duelo_evento', ev: { tipo: 'hack' } });
await esperar(150);
conferir(!a.msgs.some((m) => m.t === 'duelo_evento' && m.ev.tipo === 'hack'), 'evento desconhecido não é repassado');

a.limpar(); b.limpar();
a.enviar({ t: 'duelo_caiu', round: 1 });
a.enviar({ t: 'duelo_caiu', round: 1 }); // Repetido: não conta duas vezes.
const p1 = await b.esperar((m) => m.t === 'duelo_ponto');
conferir(p1?.vencedor === b.eu && p1.placar[b.eu] === 1 && p1.placar[a.eu] === 0, 'queda dá o ponto ao adversário, uma vez só');
const r2 = await a.esperar((m) => m.t === 'duelo_round' && m.round === 2);
conferir(r2 !== null, 'round 2 começa depois do intervalo');
a.enviar({ t: 'duelo_caiu', round: 2 });
const fim = await b.esperar((m) => m.t === 'duelo_fim');
conferir(fim?.vencedor === b.eu && fim.motivo === 'placar' && fim.placar[b.eu] === 2, 'dois pontos vencem a partida (melhor de 3)');
const volta = await a.esperar((m) => m.t === 'duelo_sala' && m.sala.estado === 'espera');
conferir(volta && volta.sala.jogadores.every((j) => !j.pronto), 'sala volta à espera com prontos zerados');

// Conexão do duelo calada além do prazo, mas mandando sinal de vida, não expira
{
  const curto = criarServidor({ ...CONFIG, porta: 0, portaAdmin: 0, tickMs: 50, expiraMs: 400 });
  const portaCurta = await curto.iniciar();
  const v = new Cliente(`ws://127.0.0.1:${portaCurta}`, 'codigo_secreto_duelo_v_abcdefghijklmn', 'VIVO');
  await v.conectar();
  for (let i = 0; i < 8; i++) { v.enviar({ t: 'duelo_vivo' }); await esperar(120); }
  conferir(curto.jogadores.size === 1, 'sinal de vida do duelo mantém a conexão');
  v.ws.close();
  await curto.parar();
}

// Abandono no meio da partida
b.enviar({ t: 'duelo_pronto', pronto: true });
await a.esperar((m) => m.t === 'duelo_sala' && m.sala.jogadores.some((j) => j.id === b.eu && j.pronto) && m.sala.estado === 'espera');
a.limpar(); b.limpar();
a.enviar({ t: 'duelo_iniciar' });
await b.esperar((m) => m.t === 'duelo_round');
b.ws.close();
const aband = await a.esperar((m) => m.t === 'duelo_fim');
conferir(aband?.vencedor === a.eu && aband.motivo === 'abandono', 'quem sai no meio perde por abandono');
a.enviar({ t: 'duelo_sair' });
await esperar(100);
conferir(servidor.duelo.salas.size === 0, 'sala vazia é apagada');

a.ws.close();
await servidor.parar();
console.log(falhas ? `${falhas} FALHA(S)` : 'TODOS OK');
process.exit(falhas ? 1 : 0);
