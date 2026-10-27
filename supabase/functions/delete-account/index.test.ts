// ADR 0001 §5 against the local stack. Env: SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY.
import { assertEquals } from 'jsr:@std/assert@1'
import { createClient } from 'npm:@supabase/supabase-js@2'

const url = Deno.env.get('SUPABASE_URL')!
const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!
const opts = { auth: { persistSession: false, autoRefreshToken: false } }
const admin = createClient(url, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, opts)

async function call(method: string, token?: string) {
  const res = await fetch(`${url}/functions/v1/delete-account`,
    { method, headers: token ? { Authorization: `Bearer ${token}` } : {} })
  await res.body?.cancel()
  return res.status
}

const created: string[] = []

// A user with one attempts row, signed in. Email login is off (config.toml), so the token comes from a magic link.
async function newUser() {
  const email = `${crypto.randomUUID()}@test.local`
  const { data: { user }, error } = await admin.auth.admin.createUser({ email, email_confirm: true })
  if (error) throw error
  created.push(user!.id)
  const link = await admin.auth.admin.generateLink({ type: 'magiclink', email })
  if (link.error) throw link.error
  const client = createClient(url, anonKey, opts)
  const { data, error: otpErr } = await client.auth.verifyOtp({ token_hash: link.data.properties.hashed_token, type: 'magiclink' })
  if (otpErr) throw otpErr
  const ins = await client.from('attempts').insert({ id: crypto.randomUUID(), scenario_id: 's~k', grade: 'best', solved_on: '2026-10-25' })
  if (ins.error) throw ins.error
  return { id: user!.id, token: data.session!.access_token }
}

async function exists(id: string) {
  const { data } = await admin.auth.admin.getUserById(id)
  const { count } = await admin.from('attempts').select('*', { count: 'exact', head: true }).eq('user_id', id)
  return { user: !!data.user, rows: count }
}

Deno.test('POST deletes only the caller and their rows; again is still 204', async () => {
  try {
    const a = await newUser(), b = await newUser()
    assertEquals(await call('POST', a.token), 204)
    assertEquals(await exists(a.id), { user: false, rows: 0 })
    assertEquals(await exists(b.id), { user: true, rows: 1 })
    assertEquals(await call('POST', a.token), 204)
  } finally {
    for (const id of created) await admin.auth.admin.deleteUser(id)
  }
})

Deno.test('GET is 405', async () => {
  assertEquals(await call('GET', anonKey), 405)
})

Deno.test('no Authorization is 401 (verify_jwt gateway, before the function)', async () => {
  assertEquals(await call('POST'), 401)
})

Deno.test('anon key (no sub) is 401', async () => {
  assertEquals(await call('POST', anonKey), 401)
})
