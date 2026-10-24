// Painel local do servidor do lobby: liga, desliga, reinicia e mostra jogadores, mensagens e logs.
// Só responde em 127.0.0.1 (nunca é publicado pelo Funnel). As ações exigem o token que a própria página recebe.
import http from 'node:http';
import { execFile } from 'node:child_process';
import { randomBytes } from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const pasta = path.dirname(fileURLToPath(import.meta.url));
const PORTA = Number(process.env.PAINEL_PORTA ?? 8790);
const ADMIN = process.env.ADMIN_URL ?? 'http://127.0.0.1:8788';
const UNIDADE = process.env.UNIDADE ?? 'algoland-lobby';
const PORTA_LOBBY = process.env.PORTA_LOBBY ?? '8787';
const token = randomBytes(16).toString('hex');
// Dentro de um container (distrobox), os comandos precisam rodar no sistema de verdade
const NO_CONTAINER = fs.existsSync('/run/.containerenv') || Boolean(process.env.CONTAINER_ID);

function rodar(comando, args, tempo = 8000) {
  const [c, a] = NO_CONTAINER ? ['host-spawn', [comando, ...args]] : [comando, args];
  return new Promise((resolve) => {
    execFile(c, a, { timeout: tempo, maxBuffer: 1 << 20 }, (erro, saida, erroSaida) => resolve({ ok: !erro, saida: `${saida ?? ''}${erroSaida ?? ''}`.trim() }));
  });
}

async function servidor() {
  try {
    const r = await fetch(`${ADMIN}/estado`, { signal: AbortSignal.timeout(1500) });
    return r.ok ? await r.json() : null;
  } catch { return null; }
}

async function estado() {
  const [ativo, detalhes, habilitado, funnel, tailscale, logs, lobby, socket, socketAtivo] = await Promise.all([
    rodar('systemctl', ['--user', 'is-active', UNIDADE]),
    rodar('systemctl', ['--user', 'show', UNIDADE, '-p', 'ActiveEnterTimestamp', '-p', 'MainPID', '-p', 'MemoryCurrent', '-p', 'NRestarts']),
    rodar('systemctl', ['--user', 'is-enabled', UNIDADE]),
    rodar('tailscale', ['funnel', 'status']),
    rodar('tailscale', ['status', '--json']),
    rodar('journalctl', ['--user', '-u', UNIDADE, '-n', '40', '--no-pager', '-o', 'short-iso']),
    servidor(),
    rodar('systemctl', ['--user', 'cat', `${UNIDADE}.socket`]),
    rodar('systemctl', ['--user', 'is-active', `${UNIDADE}.socket`]),
  ]);
  const propriedades = Object.fromEntries(detalhes.saida.split('\n').map((l) => l.split(/=(.*)/s).slice(0, 2)));
  let tailscaleOnline = null; let tailscaleNome = '';
  try { const j = JSON.parse(tailscale.saida); tailscaleOnline = j.BackendState === 'Running'; tailscaleNome = (j.Self?.DNSName ?? '').replace(/\.$/, ''); } catch {}
  const url = /https:\/\/\S+/.exec(funnel.saida)?.[0] ?? '';
  return {
    servico: { estado: ativo.saida || 'desconhecido', socketInstalado: socket.ok, socketAtivo: socketAtivo.saida === 'active', habilitado: habilitado.saida === 'enabled' || socketAtivo.saida === 'active', desde: propriedades.ActiveEnterTimestamp ?? '', pid: Number(propriedades.MainPID ?? 0),
      memoriaMB: propriedades.MemoryCurrent && /^\d+$/.test(propriedades.MemoryCurrent) ? Math.round(Number(propriedades.MemoryCurrent) / 1048576) : null, reinicios: Number(propriedades.NRestarts ?? 0) },
    lobby,
    acessoPublico: { ligado: /Funnel on/.test(funnel.saida), url, wss: url.replace('https://', 'wss://').replace(/\/$/, ''), tailscaleOnline, maquina: tailscaleNome },
    logs: logs.saida.split('\n').slice(-40),
    agora: Date.now(),
  };
}

const ACOES = {
  // Com socket instalado, ligar abre também a porta e desligar a fecha (senão a próxima conexão acordaria o servidor)
  iniciar: async () => (await rodar('systemctl', ['--user', 'cat', `${UNIDADE}.socket`])).ok
    ? rodar('systemctl', ['--user', 'start', `${UNIDADE}.socket`, `${UNIDADE}.service`]) : rodar('systemctl', ['--user', 'start', UNIDADE]),
  parar: async () => (await rodar('systemctl', ['--user', 'cat', `${UNIDADE}.socket`])).ok
    ? rodar('systemctl', ['--user', 'stop', `${UNIDADE}.socket`, `${UNIDADE}.service`]) : rodar('systemctl', ['--user', 'stop', UNIDADE]),
  reiniciar: () => rodar('systemctl', ['--user', 'restart', UNIDADE]),
  funnel_ligar: () => rodar('tailscale', ['funnel', '--bg', PORTA_LOBBY], 20000),
  funnel_desligar: () => rodar('tailscale', ['funnel', '--https=443', 'off'], 20000),
};

const hostsValidos = new Set([`127.0.0.1:${PORTA}`, `localhost:${PORTA}`]);
const servidorPainel = http.createServer(async (req, res) => {
  // Contra DNS rebinding e páginas de outros sites: só o próprio endereço local
  if (!hostsValidos.has(req.headers.host ?? '')) { res.writeHead(403); res.end('host invalido'); return; }
  const url = new URL(req.url, `http://${req.headers.host}`);
  if (req.method === 'GET' && url.pathname === '/') {
    const html = fs.readFileSync(path.join(pasta, 'index.html'), 'utf8').replace('__TOKEN__', token);
    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8', 'Cache-Control': 'no-store' });
    res.end(html);
    return;
  }
  if (req.method === 'GET' && url.pathname === '/api/estado') {
    res.writeHead(200, { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' });
    res.end(JSON.stringify(await estado()));
    return;
  }
  if (req.method === 'POST' && url.pathname.startsWith('/api/acao/')) {
    const origem = req.headers.origin;
    if (req.headers['x-painel-token'] !== token || (origem && origem !== `http://${req.headers.host}`)) { res.writeHead(403); res.end('token invalido'); return; }
    const acao = ACOES[url.pathname.slice('/api/acao/'.length)];
    if (!acao) { res.writeHead(404); res.end(); return; }
    const resultado = await acao();
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify(resultado));
    return;
  }
  res.writeHead(404);
  res.end();
});
servidorPainel.listen(PORTA, '127.0.0.1', () => console.log(`Painel do lobby em http://127.0.0.1:${PORTA}`));
