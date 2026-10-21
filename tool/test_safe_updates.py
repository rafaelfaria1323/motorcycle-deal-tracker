import unittest

from safe_updates import unsafe_statements


class UnsafeStatementsTest(unittest.TestCase):
    def test_update_and_delete_without_where(self):
        body = """
          update public.github_token_check set state = 'ok' returning * into v_row;
          delete from public.alerts;
        """
        self.assertEqual(
            unsafe_statements(body),
            [
                "update public.github_token_check set state = '' returning * into v_row",
                "delete from public.alerts",
            ],
        )

    def test_with_where(self):
        body = """
          update public.github_token_check set state = 'ok' where id;
          update public.listings l set price = 1
          from public.x where x.id = l.id;
          delete from public.alerts a where a.id = p_id;
        """
        self.assertEqual(unsafe_statements(body), [])

    def test_on_conflict_comments_and_strings(self):
        body = """
          insert into public.t (id) values (1)
          on conflict (id) do update set id = excluded.id;
          -- update public.t set x = 1;
          perform cron.schedule('j', '* * * * *', $job$ delete from public.t $job$);
          v := 'update public.t set x = 1';
        """
        self.assertEqual(unsafe_statements(body), [])


if __name__ == "__main__":
    unittest.main()
