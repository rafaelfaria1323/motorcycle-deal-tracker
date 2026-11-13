-- Fuel in the cost of ownership (N.74): the models' consumption, DGEG's
-- daily petrol price read into fuel_prices, readable by everyone.
-- (The http stub answers from http_replies.)
do $$
begin
  assert (select fuel_l_per_100km from public.motorcycles where slug = 'yamaha-mt-07') = 4.2;
  assert (select count(*) from public.motorcycles where fuel_l_per_100km is null
          and slug in ('yamaha-mt-07', 'yamaha-r7', 'honda-cb650r', 'honda-cbr650r')) = 0;
  assert (select schedule from cron.job where jobname = 'refresh-fuel-prices') = '41 9 * * *';

  assert public.fuel_price_from_text('1,911 €') = 1.911;
  assert public.fuel_price_from_text(' 2.05 ') = 2.05;
  assert public.fuel_price_from_text('1,9112 €') = 1.9112;
  assert public.fuel_price_from_text('') is null;
  assert public.fuel_price_from_text('n/d') is null;
  assert public.fuel_price_from_text(null) is null;
end $$;

create temp table dgeg_url as
select 'https://precoscombustiveis.dgeg.gov.pt/api/PrecoComb/PMD?idsTiposComb=3201'
       || '&dataIni=' || to_char(current_date - 7, 'YYYY-MM-DD')
       || '&dataFim=' || to_char(current_date, 'YYYY-MM-DD')
       || '&qtdPorPagina=10&pagina=1&orderDesc=1' as uri;

do $$
declare
  v_stored integer;
begin
  -- DGEG's answer: two days, one with a price that isn't one.
  insert into extensions.http_replies (method, uri, status, content)
  select 'GET', uri, 200, jsonb_build_object('status', true, 'resultado', jsonb_build_array(
    jsonb_build_object('Data', to_char(current_date - 1, 'YYYY-MM-DD'),
                       'TipoCombustivel', 'Gasolina simples 95',
                       'NumPostos', 1808, 'PrecoMedio', '1,911 €'),
    jsonb_build_object('Data', to_char(current_date - 2, 'YYYY-MM-DD'),
                       'TipoCombustivel', 'Gasolina simples 95',
                       'NumPostos', 1790, 'PrecoMedio', '1,899 €'),
    jsonb_build_object('Data', to_char(current_date - 3, 'YYYY-MM-DD'),
                       'NumPostos', 0, 'PrecoMedio', '-')))::text
  from dgeg_url;
  insert into public.fuel_prices (fuel, day, price, fetched_at)
  values ('petrol_95', current_date - 2, 1.5, now() - interval '1 day'),
         ('petrol_95', current_date - 500, 1.7, now() - interval '500 days');

  v_stored := public.refresh_fuel_prices();
  assert v_stored = 2, v_stored::text;
  assert (select count(*) from extensions.http_calls) = 1;
  assert (select price from public.fuel_prices where day = current_date - 1) = 1.911;
  assert (select stations from public.fuel_prices where day = current_date - 1) = 1808;
  -- A day read again takes DGEG's figure.
  assert (select price from public.fuel_prices where day = current_date - 2) = 1.899;
  assert not exists (select from public.fuel_prices where day = current_date - 3);
  assert not exists (select from public.fuel_prices where day = current_date - 500),
    'a price over 400 days old kept';

  -- DGEG down or answering something else: nothing changes, no error.
  update extensions.http_replies set status = 503;
  assert public.refresh_fuel_prices() is null;
  update extensions.http_replies set status = 200, content = '<html>maintenance</html>';
  assert public.refresh_fuel_prices() is null;
  update extensions.http_replies set content = '{"status":false,"resultado":null}';
  assert public.refresh_fuel_prices() = 0;
  assert (select count(*) from public.fuel_prices) = 2;
end $$;

-- Everyone reads the prices; nobody but the database writes them.
set local role anon;
do $$
begin
  assert (select count(*) from public.fuel_prices) = 2;
  begin
    insert into public.fuel_prices (fuel, day, price) values ('petrol_95', current_date, 1);
    assert false, 'anon wrote a fuel price';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.refresh_fuel_prices();
    assert false, 'anon refreshed the fuel prices';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;
