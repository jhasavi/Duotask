# Daily Email Digest Setup Guide

## Prerequisites
1. Supabase account with a project
2. Resend account (or other email service provider)
3. Supabase CLI installed

## Setup Steps

### 1. Run Database Migration
Execute the SQL migration in Supabase SQL Editor:
```sql
-- Run migrations/v1.2_daily_email.sql
```

### 2. Get Resend API Key
1. Sign up at https://resend.com
2. Go to API Keys section
3. Create a new API key
4. Copy the key (starts with `re_`)

### 3. Configure Supabase Secrets
```bash
cd /Users/sanjeevjha/duo/duotask
supabase secrets set RESEND_API_KEY=re_your_key_here
```

### 4. Deploy Edge Function
```bash
supabase functions deploy daily-email-digest
```

### 5. Set Up Cron Job
In Supabase Dashboard → Database → Extensions:
1. Enable `pg_cron` extension
2. Go to SQL Editor and run:

```sql
-- Schedule daily email at 8 AM UTC (adjust for your timezone)
SELECT cron.schedule(
  'daily-email-digest',
  '0 8 * * *',  -- Every day at 8 AM
  $$
  SELECT
    net.http_post(
      url:='https://YOUR_PROJECT_REF.supabase.co/functions/v1/daily-email-digest',
      headers:='{"Content-Type": "application/json", "Authorization": "Bearer YOUR_ANON_KEY"}'::jsonb
    ) as request_id;
  $$
);
```

Replace:
- `YOUR_PROJECT_REF` with your Supabase project reference
- `YOUR_ANON_KEY` with your Supabase anon key

### 6. Test the Function
```bash
curl -i --location --request POST \
  'https://YOUR_PROJECT_REF.supabase.co/functions/v1/daily-email-digest' \
  --header 'Authorization: Bearer YOUR_ANON_KEY' \
  --header 'Content-Type: application/json'
```

## Email Preferences in App

Users can manage their email preferences in Settings:
- Enable/disable daily emails
- Set preferred time (future enhancement)
- View last email sent date

## Troubleshooting

### Emails not sending
1. Check Resend API key is set: `supabase secrets list`
2. Check function logs: `supabase functions logs daily-email-digest`
3. Verify email_preferences table has entries

### Cron not triggering
1. Verify pg_cron extension is enabled
2. Check cron schedule: `SELECT * FROM cron.job;`
3. Check cron job history: `SELECT * FROM cron.job_run_details ORDER BY start_time DESC LIMIT 10;`

## Customization

### Change Email Time
Edit cron schedule (hour is in UTC):
```sql
SELECT cron.alter_job(
  job_id => (SELECT jobid FROM cron.job WHERE jobname = 'daily-email-digest'),
  schedule => '0 20 * * *'  -- 8 PM UTC
);
```

### Customize Email Template
Edit `/Users/sanjeevjha/duo/duotask/supabase/functions/daily-email-digest/index.ts`
and redeploy:
```bash
supabase functions deploy daily-email-digest
```

## Production Checklist
- [ ] Database migration executed
- [ ] Resend API key configured
- [ ] Edge function deployed
- [ ] Cron job scheduled
- [ ] Test email sent successfully
- [ ] Users can manage preferences in Settings
- [ ] Email unsubscribe link working
