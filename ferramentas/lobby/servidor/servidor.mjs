// Servidor de presença por mapa e chat global do AlgoLand (WebSocket).
// Posições e quem está online ficam só na memória; nada de pessoal é gravado. A identidade é o hash do código secreto
// do perfil (nunca publicado). As respostas têm o mesmo formato do RPC chat_global do banco, então o cliente reaproveita o parser.
import http from 'node:http';
import { createHash, randomUUID } from 'node:crypto';
import { WebSocketServer } from 'ws';
import { limparApelido, limparTexto, proibido } from './filtro.mjs';
import { criarDuelo, DUELO } from './duelo.mjs';

export const CONFIG = {
  porta: Number(process.env.PORTA ?? 8787),
  // Painel de administração: só em 127.0.0.1 e em outra porta, que o Funnel/túnel não publica
  portaAdmin: Number(process.env.ADMIN_PORTA ?? 8788),
  maxConexoes: Number(process.env.MAX_CONEXOES ?? 200),
  maxPorMapa: Number(process.env.MAX_POR_MAPA ?? 24),
  tickMs: Number(process.env.TICK_MS ?? 100),
  expiraMs: Number(process.env.EXPIRA_MS ?? 20000),
  historico: 500,
  acoesGuardadas: 200,
  idadeAcaoMs: 2000,
  retencaoMs: 3600000,
  origens: (process.env.ORIGENS_PERMITIDAS ?? '').split(',').map((o) => o.trim()).filter(Boolean),
  // Só para testes locais: atrasa cada envio, simulando a latência da internet.
  atrasoTesteMs: Number(process.env.ATRASO_TESTE_MS ?? 0),
};
const ENVELOPE = { x: 1024, y: 576 };
const REGEX_HEX = /^[a-f0-9]{24,64}$/;
const ACOES = new Set(['ataque', 'arco', 'dash']);

export function criarServidor(config = CONFIG) {
  /** @type {Map<string, any>} id -> jogador */
  const jogadores = new Map();
  const porHash = new Map();
  const mensagens = [];
  let proximaMensagem = 1;
  // Ações de uma vez só (golpe, disparo, esquiva): cada vizinho do mesmo mapa recebe cada uma uma única vez
  const acoes = [];
  let proximaAcao = 1;
  const inicio = Date.now();
  const contadores = { conexoes: 0, mensagens: 0, acoes: 0, recusadas: 0, pico: 0 };

  const servidorHttp = http.createServer((req, res) => {
    if (req.url === '/saude') {
      const corpo = JSON.stringify({ ok: true, jogadores: jogadores.size, ativoHa: Math.round((Date.now() - inicio) / 1000) });
      res.writeHead(200, { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' });
      res.end(corpo);
      return;
    }
    res.writeHead(404);
    res.end();
  });
  const wss = new WebSocketServer({
    server: servidorHttp,
    maxPayload: 8192,
    verifyClient: ({ origin }) => config.origens.length === 0 || !origin || config.origens.includes(origin),
  });

  function enviar(jogador, objeto) {
    const texto = JSON.stringify(objeto);
    if (config.atrasoTesteMs > 0) { setTimeout(() => { if (jogador.ws.readyState === 1) jogador.ws.send(texto); }, config.atrasoTesteMs); return; }
    if (jogador.ws.readyState === 1) jogador.ws.send(texto);
  }
  // Salas de duelo (duelo.mjs): mensagens com t = duelo_*
  const duelo = criarDuelo(enviar, { ...DUELO, ...(config.duelo ?? {}) });

  function remover(jogador, motivo = '') {
    if (jogadores.get(jogador.id) !== jogador) return;
    duelo.sair(jogador);
    jogadores.delete(jogador.id);
    if (porHash.get(jogador.hash) === jogador) porHash.delete(jogador.hash);
    if (motivo && jogador.ws.readyState === 1) jogador.ws.close(1000, motivo);
  }

  function estadoValido(estado) {
    if (!estado || typeof estado !== 'object') return false;
    const { x, y } = estado;
    return Number.isFinite(x) && Number.isFinite(y) && x >= 0 && x <= ENVELOPE.x && y >= 0 && y <= ENVELOPE.y;
  }

  function aplicarEstado(jogador, estado, agora) {
    if (!estadoValido(estado)) return 'posicao_invalida';
    let mapa = Number.isInteger(estado.mapa) ? estado.mapa : (estado.cidade === true ? 1 : 0);
    if (mapa < 0 || mapa > 3) return 'estado_invalido';
    const aparencia = estado.aparencia;
    if (aparencia !== undefined && aparencia !== null) {
      if (typeof aparencia !== 'object' || aparencia.versao !== 1 || JSON.stringify(aparencia).length > 4096) return 'aparencia_invalida';
    }
    if (jogador.aparencia === null && !aparencia) return 'aparencia_invalida';
    const apelido = limparApelido(estado.apelido);
    if (aparencia && JSON.stringify(aparencia) !== JSON.stringify(jogador.aparencia)) {
      jogador.aparencia = aparencia;
      jogador.revisao += 1;
    }
    if (apelido !== jogador.apelido) { jogador.apelido = apelido; jogador.revisao += 1; }
    // Respeita a lotação do mapa: quem não cabe continua conversando, sem avatar
    if (mapa > 0 && jogador.mapa !== mapa) {
      const naMapa = [...jogadores.values()].filter((p) => p.mapa === mapa && p !== jogador).length;
      if (naMapa >= config.maxPorMapa) mapa = 0;
    }
    jogador.mapa = mapa;
    jogador.x = estado.x;
    jogador.y = estado.y;
    jogador.direcao = Number.isInteger(estado.direcao) ? Math.max(0, Math.min(3, estado.direcao)) : 0;
    jogador.andando = mapa > 0 && estado.andando === true;
    jogador.pesca = mapa > 0 && Number.isInteger(estado.pesca) && estado.pesca >= 0 && estado.pesca <= 3 ? estado.pesca : -1;
    jogador.instante = agora / 1000;
    jogador.vistoEm = agora;
    return '';
  }

  function guardarMensagem(jogador, texto, envio, agora) {
    if (jogador.envios.has(envio)) return { confirmado: envio, aviso: '' };
    if (agora - jogador.ultimaMensagem < 500) return { confirmado: null, aviso: 'aguarde_mensagem' };
    const limpo = limparTexto(texto);
    jogador.envios.add(envio);
    if (jogador.envios.size > 32) jogador.envios.delete(jogador.envios.values().next().value);
    if (limpo === '' || proibido(limpo)) { contadores.recusadas += 1; return { confirmado: envio, aviso: 'mensagem_recusada' }; }
    jogador.ultimaMensagem = agora;
    contadores.mensagens += 1;
    mensagens.push({ id: proximaMensagem++, jogador: jogador.id, apelido: jogador.apelido, texto: limpo, criadoEm: agora });
    while (mensagens.length > config.historico) mensagens.shift();
    return { confirmado: envio, aviso: '' };
  }

  function montarSnapshot(jogador, forcar) {
    const lista = [];
    if (jogador.mapa > 0) {
      for (const p of jogadores.values()) {
        if (p.mapa !== jogador.mapa) continue;
        const item = { id: p.id, apelido: p.apelido, x: p.x, y: p.y, direcao: p.direcao, andando: p.andando, pesca: p.pesca, revisao: p.revisao,
          mapa: p.mapa, instante: p.instante };
        item.aparencia = jogador.conhecidos.get(p.id) === p.revisao ? null : p.aparencia;
        lista.push(item);
        if (lista.length >= config.maxPorMapa) break;
      }
    }
    const novas = mensagens.filter((m) => m.id > jogador.depois).slice(-40)
      .map((m) => ({ id: m.id, jogador: m.jogador, apelido: m.apelido, texto: m.texto }));
    const assinatura = JSON.stringify([lista.map((i) => [i.id, i.x, i.y, i.direcao, i.andando, i.pesca, i.revisao, i.instante]), novas.length]);
    // Ações de outros no mesmo mapa que este cliente ainda não recebeu
    const limite = Date.now() - config.idadeAcaoMs;
    const novasAcoes = jogador.mapa > 0
      ? acoes.filter((a) => a.n > jogador.ultimaAcao && a.mapa === jogador.mapa && a.jogador !== jogador.id && a.em >= limite)
        .map((a) => ({ jogador: a.jogador, acao: a.acao, duracao: a.duracao, combo: a.combo, direcao: a.direcao }))
      : [];
    jogador.ultimaAcao = proximaAcao - 1;
    const mudou = forcar || assinatura !== jogador.ultimaAssinatura || jogador.confirmado !== null || jogador.aviso !== '' || novasAcoes.length > 0;
    if (!mudou) return null;
    jogador.ultimaAssinatura = assinatura;
    jogador.conhecidos = new Map(lista.map((i) => [i.id, i.aparencia === null ? jogador.conhecidos.get(i.id) : i.revisao]));
    if (novas.length) jogador.depois = novas[novas.length - 1].id;
    const resposta = { eu: jogador.id, mapa: jogador.mapa, jogadores: lista, mensagens: novas, acoes: novasAcoes, confirmado: jogador.confirmado, aviso: jogador.aviso, limite: config.maxPorMapa };
    jogador.confirmado = null;
    jogador.aviso = '';
    return resposta;
  }

  function aoMensagem(jogador, bruto) {
    const agora = Date.now();
    // Máximo de 30 mensagens por segundo por conexão
    jogador.janela = jogador.janela.filter((t) => agora - t < 1000);
    if (jogador.janela.length >= 30) { enviar(jogador, { erro: 'aguarde' }); return; }
    jogador.janela.push(agora);
    // Qualquer mensagem mostra que a conexão está viva (a do duelo não manda presença de mapa).
    jogador.vistoEm = agora;
    let dados;
    try { dados = JSON.parse(bruto.toString('utf8')); } catch { return; }
    if (!dados || typeof dados !== 'object') return;
    switch (dados.t) {
      case 'estado': {
        const erro = aplicarEstado(jogador, dados.estado, agora);
        if (erro) enviar(jogador, { erro });
        break;
      }
      case 'msg': {
        if (typeof dados.texto !== 'string' || typeof dados.envio !== 'string' || !REGEX_HEX.test(dados.envio)) { enviar(jogador, { erro: 'envio_invalido' }); break; }
        const { confirmado, aviso } = guardarMensagem(jogador, dados.texto, dados.envio, agora);
        jogador.confirmado = confirmado;
        jogador.aviso = aviso;
        break;
      }
      case 'acao': {
        if (jogador.mapa === 0 || !ACOES.has(dados.acao)) break;
        const duracao = Number.isFinite(dados.duracao) ? Math.max(0.05, Math.min(2, dados.duracao)) : 0.3;
        const combo = Number.isInteger(dados.combo) ? Math.max(0, Math.min(3, dados.combo)) : 0;
        const direcao = Number.isInteger(dados.direcao) ? Math.max(0, Math.min(3, dados.direcao)) : jogador.direcao;
        contadores.acoes += 1;
        acoes.push({ n: proximaAcao++, jogador: jogador.id, mapa: jogador.mapa, acao: dados.acao, duracao, combo, direcao, em: agora });
        while (acoes.length > config.acoesGuardadas) acoes.shift();
        break;
      }
      case 'sair':
        remover(jogador, 'saiu');
        break;
      default:
        if (typeof dados.t === 'string' && dados.t.startsWith('duelo_')) duelo.aoMensagem(jogador, dados);
    }
  }

  wss.on('connection', (ws) => {
    if (jogadores.size >= config.maxConexoes) { ws.send(JSON.stringify({ erro: 'limite_gratuito' })); ws.close(1013, 'cheio'); return; }
    let jogador = null;
    const limiteEntrada = setTimeout(() => { if (!jogador) ws.close(1008, 'sem entrada'); }, 5000);
    ws.on('message', (bruto) => {
      if (jogador) { aoMensagem(jogador, bruto); return; }
      let dados;
      try { dados = JSON.parse(bruto.toString('utf8')); } catch { ws.close(1008, 'invalido'); return; }
      if (!dados || dados.t !== 'entrar' || typeof dados.codigo !== 'string' || dados.codigo.length < 24 || dados.codigo.length > 128
        || typeof dados.geracao !== 'string' || !REGEX_HEX.test(dados.geracao)) { ws.send(JSON.stringify({ erro: 'codigo_invalido' })); ws.close(1008, 'invalido'); return; }
      clearTimeout(limiteEntrada);
      const hash = createHash('sha256').update(dados.codigo, 'utf8').digest('hex');
      const anterior = porHash.get(hash);
      // Reconectar com o mesmo perfil assume a identidade e histórico e derruba a conexão antiga
      const id = anterior?.id ?? randomUUID();
      if (anterior) { duelo.sair(anterior); jogadores.delete(anterior.id); porHash.delete(hash); anterior.ws.close(1000, 'substituida'); }
      jogador = { id, hash, ws, geracao: dados.geracao, apelido: 'sem apelido', aparencia: anterior?.aparencia ?? null, revisao: anterior?.revisao ?? 1,
        entrouEm: Date.now(), mapa: 0, x: 0, y: 0, direcao: 0, andando: false, pesca: -1, ultimaAcao: proximaAcao - 1, instante: Date.now() / 1000, vistoEm: Date.now(), ultimaMensagem: 0,
        envios: anterior?.envios ?? new Set(), janela: [], conhecidos: new Map(), depois: Number.isInteger(dados.depois) ? Math.max(0, dados.depois) : 0,
        confirmado: null, aviso: '', ultimaAssinatura: '' };
      jogadores.set(id, jogador);
      porHash.set(hash, jogador);
      contadores.conexoes += 1;
      contadores.pico = Math.max(contadores.pico, jogadores.size);
      const erro = aplicarEstado(jogador, dados.estado, Date.now());
      if (erro) { enviar(jogador, { erro }); remover(jogador, 'invalido'); return; }
      enviar(jogador, montarSnapshot(jogador, true));
    });
    ws.on('close', () => { clearTimeout(limiteEntrada); if (jogador) remover(jogador); });
    ws.on('error', () => {});
  });

  const relogio = setInterval(() => {
    const agora = Date.now();
    while (mensagens.length && agora - mensagens[0].criadoEm > config.retencaoMs) mensagens.shift();
    for (const jogador of [...jogadores.values()]) {
      if (agora - jogador.vistoEm > config.expiraMs) { remover(jogador, 'expirou'); continue; }
      const snapshot = montarSnapshot(jogador, false);
      if (snapshot) enviar(jogador, snapshot);
    }
  }, config.tickMs);

  function estadoAdmin() {
    const agora = Date.now();
    const porMapa = { 0: 0, 1: 0, 2: 0, 3: 0 };
    const lista = [...jogadores.values()].map((p) => {
      porMapa[p.mapa] += 1;
      return { id: p.id.slice(0, 8), apelido: p.apelido, mapa: p.mapa, desdeSeg: Math.round((agora - p.entrouEm) / 1000),
        vistoHaMs: agora - p.vistoEm, x: Math.round(p.x), y: Math.round(p.y), pesca: p.pesca >= 0 };
    }).sort((a, b) => a.mapa - b.mapa || a.apelido.localeCompare(b.apelido));
    return { ok: true, ativoHa: Math.round((agora - inicio) / 1000), jogadores: lista, porMapa, contadores: { ...contadores },
      mensagens: mensagens.slice(-40).map((m) => ({ id: m.id, apelido: m.apelido, texto: m.texto, criadoEm: m.criadoEm })),
      memoriaMB: Math.round(process.memoryUsage().rss / 1048576), node: process.version,
      limites: { maxConexoes: config.maxConexoes, maxPorMapa: config.maxPorMapa, expiraMs: config.expiraMs, tickMs: config.tickMs },
      duelos: duelo.estadoAdmin() };
  }
  const servidorAdmin = http.createServer((req, res) => {
    if (req.url === '/estado' && req.method === 'GET') {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify(estadoAdmin()));
      return;
    }
    res.writeHead(404);
    res.end();
  });

  return {
    iniciar: () => new Promise((resolve) => servidorHttp.listen(config.porta, () => {
      if (config.portaAdmin > 0) servidorAdmin.listen(config.portaAdmin, '127.0.0.1');
      resolve(servidorHttp.address().port);
    })),
    estadoAdmin,
    parar: () => new Promise((resolve) => {
      clearInterval(relogio);
      for (const cliente of wss.clients) cliente.terminate();
      if (servidorAdmin.listening) servidorAdmin.close();
      wss.close(() => servidorHttp.close(() => resolve()));
    }),
    jogadores,
    duelo,
  };
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const servidor = criarServidor();
  const porta = await servidor.iniciar();
  console.log(`AlgoLand lobby ouvindo na porta ${porta} (máx. ${CONFIG.maxConexoes} conexões, ${CONFIG.maxPorMapa} por mapa)`);
  const encerrar = async () => { await servidor.parar(); process.exit(0); };
  process.on('SIGINT', encerrar);
  process.on('SIGTERM', encerrar);
}
