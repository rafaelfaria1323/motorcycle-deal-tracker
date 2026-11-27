-- Yamaha's R models are also written with their YZF prefix glued on
-- ("YZFR7 2023", "yzfr1") or after another word ("Mota YZF R7"): the
-- name "R7" alone missed those titles (N.123). The YZF-R name as an alias
-- covers every spelling; the next import's rematch fixes stored ads.
update public.motorcycles m
set aliases = m.aliases || array['YZF-' || m.model],
    updated_at = now()
where m.slug in ('yamaha-r1', 'yamaha-r3', 'yamaha-r7', 'yamaha-r9')
  and not ('YZF-' || m.model) = any (m.aliases);
