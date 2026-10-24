-- Chat: reduz o intervalo entre mensagens para 0,5 s, mantendo nonce e limites do lobby.
begin;
create or replace function public.lobby_cidade(p_codigo text,p_geracao text,p_estado jsonb,p_conhecidos jsonb default '{}',p_depois bigint default 0,p_mensagem text default '',p_envio text default '')
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare h text; s public.lobby_sessoes%rowtype; agora timestamptz:=clock_timestamp();
 u public.lobby_uso%rowtype; novo boolean; nome text; visual jsonb; px real; py real;
 texto text; confirmado text; aviso text:=''; pessoas jsonb; mensagens jsonb; resposta jsonb; tamanho bigint;
begin
 if p_codigo is null or length(p_codigo) not between 24 and 128 then raise exception 'codigo_invalido'; end if;
 if p_geracao is null or p_geracao !~ '^[a-f0-9]{24,64}$' then raise exception 'sessao_invalida'; end if;
 if p_estado is null or jsonb_typeof(p_estado)<>'object' or octet_length(p_estado::text)>6000 then raise exception 'estado_invalido'; end if;
 if p_conhecidos is null or jsonb_typeof(p_conhecidos)<>'object' or octet_length(p_conhecidos::text)>2048 then raise exception 'estado_invalido'; end if;
 px:=(p_estado->>'x')::real; py:=(p_estado->>'y')::real;
 if px is null or py is null or not(px between 0 and 1024 and py between 0 and 576) then raise exception 'posicao_invalida'; end if;
 nome:=left(btrim(regexp_replace(coalesce(p_estado->>'apelido',''),'[[:cntrl:]]','','g')),16);
 if nome='' or public.apelido_proibido(nome) then nome:='sem apelido'; end if;
 visual:=p_estado->'aparencia';
 if visual is not null and (jsonb_typeof(visual)<>'object' or visual->>'versao' is distinct from '1' or octet_length(visual::text)>4096) then raise exception 'aparencia_invalida'; end if;
 h:=encode(sha256(convert_to(p_codigo,'UTF8')),'hex');
 -- Oito vagas e orçamento global são conferidos sob a mesma trava, inclusive em entradas simultâneas.
 perform pg_advisory_xact_lock(68102301);
 delete from public.lobby_sessoes where visto_em<agora-interval '1 hour';
 insert into public.lobby_uso(dia) values(current_date) on conflict do nothing;
 select * into u from public.lobby_uso where dia=current_date for update;
 -- 64 MiB/dia (incluindo margem por requisição) reservam boa parte da franquia para o restante do jogo.
 if u.bytes>=67108864 then return jsonb_build_object('erro','limite_gratuito'); end if;
 select * into s from public.lobby_sessoes where codigo_hash=h for update;
 novo:=not found;
 if not novo and p_geracao=any(s.encerradas) then return jsonb_build_object('erro','sessao_encerrada'); end if;
 if novo or not s.online or s.visto_em<agora-interval '20 seconds' then
  if (select count(*) from public.lobby_sessoes where online and visto_em>=agora-interval '20 seconds')>=8 then return jsonb_build_object('erro','cidade_cheia'); end if;
  if novo and u.novos>=500 then return jsonb_build_object('erro','limite_gratuito'); end if;
 end if;
 if novo then
  if visual is null then raise exception 'aparencia_invalida'; end if;
  insert into public.lobby_sessoes(codigo_hash,aparencia) values(h,visual) returning * into s;
  update public.lobby_uso set novos=novos+1 where dia=current_date;
 end if;
 if p_geracao=s.geracao and agora<s.sincronizado_em+interval '500 milliseconds' then return jsonb_build_object('erro','aguarde'); end if;
 if visual is null then visual:=s.aparencia; end if;
 update public.lobby_sessoes set geracao=p_geracao,online=true,apelido=nome,aparencia=visual,
  revisao=s.revisao+case when visual<>s.aparencia or nome<>s.apelido then 1 else 0 end,
  x=px,y=py,direcao=greatest(0,least(3,coalesce((p_estado->>'direcao')::int,0))),
  andando=coalesce((p_estado->>'andando')::boolean,false),visto_em=agora,sincronizado_em=agora
  where codigo_hash=h returning * into s;
 if coalesce(p_mensagem,'')<>'' then
  if p_envio is null or p_envio !~ '^[a-f0-9]{24,64}$' then raise exception 'envio_invalido'; end if;
  if exists(select 1 from public.lobby_mensagens where codigo_hash=h and envio=p_envio) then confirmado:=p_envio;
  elsif agora<s.mensagem_em+interval '500 milliseconds' then aviso:='aguarde_mensagem';
  else
   texto:=left(btrim(regexp_replace(p_mensagem,'[[:cntrl:]]',' ','g')),160);
   if texto='' or public.apelido_proibido(texto) then aviso:='mensagem_recusada'; confirmado:=p_envio;
   else
    insert into public.lobby_mensagens(jogador_id,codigo_hash,envio,apelido,texto) values(s.id,h,p_envio,s.apelido,texto);
    update public.lobby_sessoes set mensagem_em=agora where codigo_hash=h;
    confirmado:=p_envio;
   end if;
  end if;
 end if;
 delete from public.lobby_mensagens where criado_em<agora-interval '1 hour' or id<(select coalesce(max(id),0)-500 from public.lobby_mensagens);
 select coalesce(jsonb_agg(jsonb_build_object('id',id,'apelido',apelido,'x',x,'y',y,'direcao',direcao,'andando',andando,'revisao',revisao,'instante',extract(epoch from sincronizado_em),
  'aparencia',case when p_conhecidos->>id::text=revisao::text then null else aparencia end) order by id),'[]') into pessoas
  from public.lobby_sessoes where online and visto_em>=agora-interval '20 seconds';
 select coalesce(jsonb_agg(jsonb_build_object('id',id,'jogador',jogador_id,'apelido',apelido,'texto',ultimas.texto) order by id),'[]') into mensagens
  from (select * from public.lobby_mensagens where id>greatest(0,coalesce(p_depois,0)) order by id desc limit 40) as ultimas;
 resposta:=jsonb_build_object('eu',s.id,'jogadores',pessoas,'mensagens',mensagens,'confirmado',confirmado,'aviso',aviso,'limite',8);
 tamanho:=octet_length(resposta::text)+octet_length(p_estado::text)+octet_length(p_conhecidos::text)+2048;
 update public.lobby_uso set bytes=bytes+tamanho where dia=current_date;
 delete from public.lobby_uso where dia<current_date-interval '35 days';
 return resposta;
end $$;

commit;
