// Salas de duelo (PvP 1x1, melhor de 3). O servidor guarda as salas, o placar e quem está pronto;
// posição/animação e golpes são só repassados ao adversário (quem apanha resolve defesa e dano no próprio jogo).
import { limparTexto } from './filtro.mjs';

export const DUELO = {
  maxSalas: 60,
  rounds: 2, // Rounds para vencer (melhor de 3).
  intervaloRoundMs: 2500,
  maxTitulo: 24,
  maxSenha: 12,
  maxPerfil: 4096,
  maxEstado: 1024,
  maxEvento: 512,
};
const TIPOS_EVENTO = new Set(['golpe', 'acao', 'efeito']);

export function criarDuelo(enviar, config = DUELO) {
  /** @type {Map<number, any>} */
  const salas = new Map();
  let proximaSala = 1;

  const resumo = (s) => ({ id: s.id, titulo: s.titulo, senha: s.senha !== '', jogadores: s.membros.length, estado: s.estado });
  const completa = (s) => ({
    id: s.id, titulo: s.titulo, senha: s.senha !== '', dono: s.dono, estado: s.estado, placar: s.placar, round: s.round,
    jogadores: s.membros.map((j) => ({ id: j.id, apelido: j.apelido, pronto: s.prontos.has(j.id), perfil: j.duelo?.perfil ?? null })),
  });
  const avisarSala = (s) => { for (const j of s.membros) enviar(j, { t: 'duelo_sala', sala: completa(s) }); };
  const adversario = (s, jogador) => s.membros.find((j) => j !== jogador);
  const salaDe = (jogador) => (jogador.duelo?.sala ? salas.get(jogador.duelo.sala) : undefined);

  function perfilValido(perfil) {
    if (perfil === undefined || perfil === null) return null;
    if (typeof perfil !== 'object' || JSON.stringify(perfil).length > config.maxPerfil) return undefined;
    return perfil;
  }

  function sair(jogador) {
    const s = salaDe(jogador);
    if (!s) return;
    s.membros = s.membros.filter((j) => j !== jogador);
    s.prontos.delete(jogador.id);
    jogador.duelo.sala = 0;
    if (s.membros.length === 0) { clearTimeout(s.timer); salas.delete(s.id); return; }
    if (s.dono === jogador.id) s.dono = s.membros[0].id;
    // Abandonar no meio da partida entrega a vitória ao adversário.
    if (s.estado === 'jogo') encerrar(s, s.membros[0].id, 'abandono');
    avisarSala(s);
  }

  function encerrar(s, vencedor, motivo) {
    clearTimeout(s.timer);
    for (const j of s.membros) enviar(j, { t: 'duelo_fim', vencedor, motivo, placar: s.placar });
    s.estado = 'espera';
    s.prontos.clear();
    s.round = 0;
  }

  function comecarRound(s) {
    s.round += 1;
    s.caido = '';
    const lados = Object.fromEntries(s.membros.map((j, i) => [j.id, i]));
    for (const j of s.membros) enviar(j, { t: 'duelo_round', round: s.round, placar: s.placar, lados });
  }

  function aoMensagem(jogador, dados) {
    jogador.duelo ??= { sala: 0, perfil: null };
    const s = salaDe(jogador);
    switch (dados.t) {
      case 'duelo_ping':
        // Eco imediato para o jogo medir a ida e volta até o servidor.
        enviar(jogador, { t: 'duelo_pong', c: Number.isFinite(dados.c) ? dados.c : 0 });
        return true;
      case 'duelo_salas':
        enviar(jogador, { t: 'duelo_salas', salas: [...salas.values()].map(resumo) });
        return true;
      case 'duelo_criar': {
        if (s) sair(jogador);
        if (salas.size >= config.maxSalas) { enviar(jogador, { t: 'duelo_erro', erro: 'muitas_salas' }); return true; }
        const perfil = perfilValido(dados.perfil);
        if (perfil === undefined) { enviar(jogador, { t: 'duelo_erro', erro: 'perfil_invalido' }); return true; }
        const titulo = limparTexto(typeof dados.titulo === 'string' ? dados.titulo : '').slice(0, config.maxTitulo) || `Sala de ${jogador.apelido}`;
        const senha = typeof dados.senha === 'string' ? dados.senha.slice(0, config.maxSenha) : '';
        const nova = { id: proximaSala++, titulo, senha, dono: jogador.id, membros: [jogador], prontos: new Set(), estado: 'espera', placar: {}, round: 0, caido: '', timer: null };
        salas.set(nova.id, nova);
        jogador.duelo.sala = nova.id;
        jogador.duelo.perfil = perfil;
        avisarSala(nova);
        return true;
      }
      case 'duelo_entrar': {
        const alvo = salas.get(Number(dados.id));
        if (!alvo) { enviar(jogador, { t: 'duelo_erro', erro: 'sala_inexistente' }); return true; }
        if (alvo === s) { avisarSala(alvo); return true; }
        if (alvo.membros.length >= 2) { enviar(jogador, { t: 'duelo_erro', erro: 'sala_cheia' }); return true; }
        if (alvo.estado !== 'espera') { enviar(jogador, { t: 'duelo_erro', erro: 'sala_em_jogo' }); return true; }
        if (alvo.senha !== '' && dados.senha !== alvo.senha) { enviar(jogador, { t: 'duelo_erro', erro: 'senha_errada' }); return true; }
        const perfil = perfilValido(dados.perfil);
        if (perfil === undefined) { enviar(jogador, { t: 'duelo_erro', erro: 'perfil_invalido' }); return true; }
        if (s) sair(jogador);
        alvo.membros.push(jogador);
        jogador.duelo.sala = alvo.id;
        jogador.duelo.perfil = perfil;
        avisarSala(alvo);
        return true;
      }
      case 'duelo_sair':
        sair(jogador);
        enviar(jogador, { t: 'duelo_saiu' });
        return true;
      case 'duelo_pronto':
        if (!s || s.estado !== 'espera') return true;
        if (dados.pronto === true) s.prontos.add(jogador.id); else s.prontos.delete(jogador.id);
        avisarSala(s);
        return true;
      case 'duelo_iniciar':
        if (!s || s.dono !== jogador.id || s.estado !== 'espera') return true;
        if (s.membros.length < 2 || !s.membros.every((j) => s.prontos.has(j.id) || j.id === s.dono)) {
          enviar(jogador, { t: 'duelo_erro', erro: 'adversario_nao_pronto' });
          return true;
        }
        s.estado = 'jogo';
        s.placar = Object.fromEntries(s.membros.map((j) => [j.id, 0]));
        s.round = 0;
        avisarSala(s);
        comecarRound(s);
        return true;
      case 'duelo_estado': {
        if (!s || s.estado !== 'jogo') return true;
        if (!dados.e || typeof dados.e !== 'object' || JSON.stringify(dados.e).length > config.maxEstado) return true;
        const outro = adversario(s, jogador);
        if (outro) enviar(outro, { t: 'duelo_estado', e: dados.e });
        return true;
      }
      case 'duelo_evento': {
        if (!s || s.estado !== 'jogo') return true;
        const ev = dados.ev;
        if (!ev || typeof ev !== 'object' || !TIPOS_EVENTO.has(ev.tipo) || JSON.stringify(ev).length > config.maxEvento) return true;
        const outro = adversario(s, jogador);
        if (outro) enviar(outro, { t: 'duelo_evento', ev });
        return true;
      }
      case 'duelo_caiu': {
        // Quem caiu avisa; o placar e o próximo round são do servidor (o round é contado uma vez só).
        if (!s || s.estado !== 'jogo' || s.caido !== '' || Number(dados.round) !== s.round) return true;
        const outro = adversario(s, jogador);
        if (!outro) return true;
        s.caido = jogador.id;
        s.placar[outro.id] = (s.placar[outro.id] ?? 0) + 1;
        for (const j of s.membros) enviar(j, { t: 'duelo_ponto', vencedor: outro.id, placar: s.placar, round: s.round });
        if (s.placar[outro.id] >= config.rounds) {
          s.timer = setTimeout(() => { encerrar(s, outro.id, 'placar'); avisarSala(s); }, config.intervaloRoundMs);
        } else {
          s.timer = setTimeout(() => comecarRound(s), config.intervaloRoundMs);
        }
        return true;
      }
      default:
        return false;
    }
  }

  return {
    aoMensagem,
    sair,
    estadoAdmin: () => [...salas.values()].map((s) => ({ ...resumo(s), placar: s.placar, round: s.round })),
    salas,
  };
}
