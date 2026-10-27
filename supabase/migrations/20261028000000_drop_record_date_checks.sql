-- ADR 0001 §1: dates come from the device clock. A row the server rejects would block sync for that table forever, so accept any date.
alter table public.attempts drop constraint attempts_solved_on_check;
alter table public.day_completions drop constraint day_completions_completed_on_check;
