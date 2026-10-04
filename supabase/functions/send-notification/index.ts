import { createClient } from 'npm:@supabase/supabase-js@2';
import { importPKCS8, SignJWT } from 'npm:jose@5';

const headers = { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-client-info' };
const respond = (status: number, body: unknown) => new Response(JSON.stringify(body), { status, headers });
Deno.serve(async (request: Request) => {
  if (request.method === 'OPTIONS') return new Response(null, { headers });
  if (request.method !== 'POST') return respond(405, { error: 'POST required' });
  try {
    const url = Deno.env.get('SUPABASE_URL')!;
    const caller = createClient(url, Deno.env.get('SUPABASE_ANON_KEY')!, { global: { headers: { Authorization: request.headers.get('Authorization') ?? '' } } });
    const { data: { user }, error: authError } = await caller.auth.getUser();
    if (authError || !user) return respond(401, { error: 'Sign in required' });
    const service = createClient(url, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
    const { data: member } = await service.from('school_members').select().eq('user_id', user.id).single();
    if (!member || !['teacher', 'principal', 'administrator'].includes(member.role)) return respond(403, { error: 'School staff only' });
    const { record_id } = await request.json();
    const { data: record } = await service.from('school_records').select().eq('id', record_id).eq('school_id', member.school_id).single();
    if (!record || !['attendance','mark','attempt','homework','exam','notice','resource','leave'].includes(record.kind)) return respond(400, { error: 'Unsupported school update' });
    if (member.role === 'teacher' && (!record.class_id || !member.classes.includes(record.class_id))) return respond(403, { error: 'Class access denied' });
    if (['mark','attempt'].includes(record.kind) && record.data.published !== true) return respond(400, { error: 'Results are not published' });
    const { data: members, error: membersError } = await service.from('school_members').select().eq('school_id', member.school_id);
    if (membersError) throw membersError;
    const { data: pupils } = await service.from('school_records').select('student_id,class_id').eq('school_id', member.school_id).eq('kind','student');
    const studentIds = new Set((pupils ?? []).filter(p => record.student_id ? p.student_id === record.student_id : !record.class_id || p.class_id === record.class_id).map(p => p.student_id));
    const recipients = (members ?? []).filter(m => record.kind === 'leave' ? m.user_id === record.owner_id :
      record.kind === 'notice' && !record.class_id || studentIds.has(m.user_id) || m.children.some((id: string) => studentIds.has(id))).map(m => m.user_id);
    if (!recipients.length) return respond(200, { delivered: 0 });
    const { data: devices, error: deviceError } = await service.from('device_tokens').select('token').in('user_id', recipients);
    if (deviceError) throw deviceError;
    if (!devices?.length) return respond(200, { delivered: 0 });
    const account = JSON.parse(Deno.env.get('FCM_SERVICE_ACCOUNT_JSON') ?? '{}');
    if (!account.private_key || !account.client_email || !account.project_id) return respond(503, { error: 'Push delivery is not configured' });
    const privateKey = await importPKCS8(account.private_key, 'RS256');
    const assertion = await new SignJWT({ scope: 'https://www.googleapis.com/auth/firebase.messaging' }).setProtectedHeader({ alg: 'RS256' }).setIssuer(account.client_email).setAudience('https://oauth2.googleapis.com/token').setIssuedAt().setExpirationTime('1h').sign(privateKey);
    const oauth = await fetch('https://oauth2.googleapis.com/token', { method: 'POST', body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion }) });
    const token = await oauth.json();
    if (!oauth.ok || !token.access_token) return respond(502, { error: 'Could not authorize push delivery' });
    let delivered = 0;
    const body = record.kind === 'attendance' ? 'An attendance update is available.' : ['mark','attempt'].includes(record.kind) ? 'A new academic result is ready.' : record.kind === 'leave' ? 'Your leave request has an update.' : 'There is something new on your school workspace.';
    for (const device of devices) {
      // Keep personal details and marks off lock-screen notifications.
      const result = await fetch(`https://fcm.googleapis.com/v1/projects/${account.project_id}/messages:send`, { method: 'POST', headers: { Authorization: `Bearer ${token.access_token}`, 'Content-Type': 'application/json' }, body: JSON.stringify({ message: { token: device.token, notification: { title: 'SchoolSphere', body }, data: { record_id: record.id, kind: record.kind } } }) });
      if (result.ok) delivered++;
    }
    return respond(200, { delivered, attempted: devices.length });
  } catch { return respond(500, { error: 'Notification delivery failed' }); }
});
