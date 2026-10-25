// ADR 0001 §5: called from the app only. Deletes the caller's auth user; records go via cascade.
import { createClient } from 'npm:@supabase/supabase-js@2'

const admin = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  { auth: { persistSession: false } })

Deno.serve(async (req) => {
  if (req.method !== 'POST') return new Response(null, { status: 405 })
  const jwt = req.headers.get('Authorization')?.replace(/^Bearer /, '') ?? ''
  const { data, error } = await admin.auth.getClaims(jwt)
  const uid = data?.claims?.sub
  if (error || !uid || data.claims.role !== 'authenticated') return new Response(null, { status: 401 })
  const { error: delErr } = await admin.auth.admin.deleteUser(uid)   // only the token's sub, hard delete
  if (delErr && delErr.status !== 404) return new Response(null, { status: 500 })
  return new Response(null, { status: 204 })                         // already gone is success (idempotent)
})
