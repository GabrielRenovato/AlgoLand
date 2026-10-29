// O servidor só negocia salas/SDP/ICE. Nenhum estado da partida passa por ele.
import { randomBytes } from 'node:crypto';
export const MAX_JOGADORES = 4;
export function criarCoop(enviar, { maxSalas = 100 } = {}) {
  const salas = new Map(), porJogador = new Map();
  const erro = (j, codigo) => enviar(j, { t: 'coop_erro', erro: codigo });
  const perfil = (p) => p && typeof p === 'object' && !Array.isArray(p) && JSON.stringify(p).length <= 5000 ? structuredClone(p) : null;
  const informar = (s) => { for (const j of s.jogadores) enviar(j, { t: 'coop_sala', codigo: s.codigo, dono: s.dono.id, jogadores: s.jogadores.map(p => ({ id: p.id, perfil: s.perfis.get(p.id) })) }); };
  function sair(j, intencional = false) {
    const s = porJogador.get(j.id); if (!s) return;
    if (s.dono === j) {
      // O anfitrião simula a partida: sem ele a sala acaba para todos.
      for (const p of s.jogadores) { porJogador.delete(p.id); enviar(p, { t: 'coop_fim', motivo: p === j ? 'saiu' : 'parceiro_saiu', intencional }); }
      salas.delete(s.codigo);
      return;
    }
    // Convidado que sai: a sala continua com os demais.
    s.jogadores = s.jogadores.filter(p => p !== j); s.perfis.delete(j.id); porJogador.delete(j.id);
    enviar(j, { t: 'coop_fim', motivo: 'saiu', intencional });
    informar(s);
  }
  function aoMensagem(j, m) {
    const s = porJogador.get(j.id);
    switch (m.t) {
      case 'coop_listar':
        enviar(j, { t: 'coop_salas', salas: [...salas.values()].map(sala => ({
          codigo: sala.codigo, anfitriao: sala.anfitriao, andar: sala.andar,
          jogadores: sala.jogadores.length, maximo: MAX_JOGADORES, em_partida: sala.emPartida
        })) }); break;
      case 'coop_iniciar':
        if (s && s.dono === j) s.emPartida = true;
        break;
      case 'coop_criar': {
        if (s) return erro(j, 'ja_na_sala');
        if (salas.size >= maxSalas) return erro(j, 'muitas_salas');
        const p = perfil(m.perfil); if (!p) return erro(j, 'perfil_invalido');
        const codigo = randomBytes(6).toString('hex').toUpperCase();
        const anfitriao = String(p.apelido ?? 'JOGADOR').replace(/[\r\n\t]/g, ' ').slice(0, 24);
        const andar = Number.isInteger(m.andar) ? Math.max(1, Math.min(1000, m.andar)) : 1;
        const nova = { codigo, anfitriao, andar, emPartida: false, dono: j, jogadores: [j], perfis: new Map([[j.id, p]]) };
        salas.set(codigo, nova); porJogador.set(j.id, nova); informar(nova); break;
      }
      case 'coop_entrar': {
        if (s) return erro(j, 'ja_na_sala');
        if (typeof m.codigo !== 'string' || !/^[A-Fa-f0-9]{12}$/.test(m.codigo)) return erro(j, 'sala_inexistente');
        const sala = salas.get(m.codigo.toUpperCase());
        if (!sala) return erro(j, 'sala_inexistente');
        if (sala.emPartida) return erro(j, 'em_partida');
        if (sala.jogadores.length >= MAX_JOGADORES) return erro(j, 'sala_cheia');
        const p = perfil(m.perfil); if (!p) return erro(j, 'perfil_invalido');
        sala.jogadores.push(j); sala.perfis.set(j.id, p); porJogador.set(j.id, sala); informar(sala); break;
      }
      case 'coop_sinal': {
        if (!s || s.jogadores.length < 2) return erro(j, 'sem_parceiro');
        const d = m.dados;
        if (!d || typeof d !== 'object') return;
        // Estrela: o anfitrião negocia com cada convidado; convidados só falam com o anfitrião.
        const alvo = s.dono === j ? s.jogadores.find(p => p.id === m.para && p !== j) : s.dono;
        if (!alvo) return;
        let sinal;
        if (['offer', 'answer'].includes(d.tipo) && typeof d.sdp === 'string' && d.sdp.length <= 6000) sinal = { tipo: d.tipo, sdp: d.sdp };
        else if (d.tipo === 'ice' && typeof d.mid === 'string' && d.mid.length <= 100 && Number.isInteger(d.indice) && d.indice >= 0 && d.indice <= 32 && typeof d.candidato === 'string' && d.candidato.length <= 1500) sinal = { tipo: 'ice', mid: d.mid, indice: d.indice, candidato: d.candidato };
        if (sinal) enviar(alvo, { t: 'coop_sinal', de: j.id, dados: sinal });
        break;
      }
      case 'coop_ping': enviar(j, { t: 'coop_pong', c: m.c }); break;
      case 'coop_sair': sair(j, true); break;
    }
  }
  return { aoMensagem, sair, quantidade: () => salas.size };
}
