-- ADR 0003 §5: public bucket for content.json. No storage.objects policy: public skips read checks, only service role writes.
insert into storage.buckets (id, name, public) values ('content', 'content', true);
