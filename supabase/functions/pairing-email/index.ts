// Supabase Edge Function: pairing-email
// Sends an email via Resend when a pairing request is created.
// Configure the secret in your project:
//   supabase functions secrets set RESEND_API_KEY=... 
// Sender should be a verified address in Resend, e.g., no-reply@updates.namastebostonhomes.com

import 'https://deno.land/x/dotenv@v3.2.2/load.ts';

interface Payload {
  to?: string | null;
  toName?: string | null;
  requesterName?: string | null;
}

Deno.serve(async (req: Request) => {
  try {
    if (req.method !== 'POST') {
      return new Response('Method Not Allowed', { status: 405 });
    }

    // Robust JSON parsing (handles missing content-type)
    let body: Payload = {};
    try {
      body = (await req.json()) as Payload;
    } catch (_) {
      try {
        const text = await req.text();
        body = JSON.parse(text) as Payload;
      } catch (_) {
        return new Response('Invalid JSON body', { status: 400 });
      }
    }

    console.log('pairing-email request body:', body);
    const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY');
    const FROM = 'no-reply@updates.namastebostonhomes.com';

    if (!RESEND_API_KEY) {
      return new Response('RESEND_API_KEY not configured', { status: 500 });
    }

    const to = body.to?.trim();
    if (!to) {
      return new Response('Missing recipient email', { status: 400 });
    }

    const requesterName = (body.requesterName ?? 'Your partner').toString();
    const toName = (body.toName ?? '').toString();

    const subject = `${requesterName} invited you to pair on DuoTask`;
    const text = `Hi ${toName || ''}\n\n${requesterName} sent you a pairing request on DuoTask.\nOpen the app to accept or decline.\n\nIf this wasn't you, you can ignore this email.`;

    const resp = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${RESEND_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from: `DuoTask <${FROM}>`,
        to: [to],
        subject,
        text,
      }),
    });

    const raw = await resp.text();
    console.log('Resend status:', resp.status, 'body:', raw);
    if (!resp.ok) {
      return new Response(`Resend error: ${raw}`, { status: 502 });
    }
    let data: unknown = undefined;
    try { data = JSON.parse(raw); } catch { data = raw; }
    return new Response(JSON.stringify({ ok: true, data }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (e) {
    console.error('pairing-email server error:', e);
    return new Response(`Server error: ${e}`, { status: 500 });
  }
});
