// Supabase Edge Function: daily-email-digest
// Deploy with: supabase functions deploy daily-email-digest
// Invoke with: curl -i --location --request POST 'https://<project-ref>.supabase.co/functions/v1/daily-email-digest' \
//   --header 'Authorization: Bearer <anon-key>' \
//   --header 'Content-Type: application/json'

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY')!
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

interface EmailData {
  user_email: string
  user_name: string
  partner_name: string | null
  has_partner: boolean
  personal_unclaimed: number
  personal_claimed: number
  group_unclaimed: number
  group_claimed_by_user: number
  group_claimed_by_partner: number
  total_open: number
}

interface TaskDetail {
  id: string
  title: string
  priority: string
  due_date: string | null
  created_by_me?: boolean
}

interface TasksData {
  personal_unclaimed: TaskDetail[]
  personal_claimed: TaskDetail[]
  group_unclaimed: TaskDetail[]
  group_claimed_by_user: TaskDetail[]
  group_claimed_by_partner: TaskDetail[]
}

function buildEmailHtml(data: EmailData, tasks: TasksData): string {
  const formatDate = (dateStr: string | null) => {
    if (!dateStr) return ''
    const date = new Date(dateStr)
    return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit' })
  }

  const taskListHtml = (taskList: TaskDetail[], title: string, emptyMessage: string) => {
    if (taskList.length === 0) {
      return `<p style="color: #6b7280; font-style: italic;">${emptyMessage}</p>`
    }
    
    return `
      <ul style="list-style: none; padding: 0; margin: 0;">
        ${taskList.map(task => `
          <li style="padding: 12px; margin: 8px 0; background: #f9fafb; border-left: 4px solid ${task.priority === 'urgent' ? '#ef4444' : '#3b82f6'}; border-radius: 4px;">
            <div style="font-weight: 600; color: #111827;">${task.title}</div>
            ${task.due_date ? `<div style="font-size: 0.875rem; color: #6b7280; margin-top: 4px;">📅 ${formatDate(task.due_date)}</div>` : ''}
          </li>
        `).join('')}
      </ul>
    `
  }

  return `
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>DuoTask Daily Digest</title>
    </head>
    <body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;">
      
      <!-- Header -->
      <div style="text-align: center; margin-bottom: 32px;">
        <h1 style="color: #6366f1; margin: 0;">DuoTask</h1>
        <p style="color: #6b7280; margin: 8px 0;">Your Daily Task Digest</p>
        <p style="color: #9ca3af; font-size: 0.875rem;">${new Date().toLocaleDateString('en-US', { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' })}</p>
      </div>

      <!-- Summary Card -->
      <div style="background: linear-gradient(135deg, #6366f1 0%, #8b5cf6 100%); color: white; padding: 24px; border-radius: 12px; margin-bottom: 24px;">
        <h2 style="margin: 0 0 16px 0; font-size: 1.5rem;">Hello, ${data.user_name}! 👋</h2>
        <p style="margin: 0; font-size: 1.125rem;">
          You have <strong>${data.total_open}</strong> open task${data.total_open !== 1 ? 's' : ''} today.
        </p>
      </div>

      <!-- Personal Tasks Section -->
      <div style="margin-bottom: 32px;">
        <h2 style="color: #111827; border-bottom: 2px solid #e5e7eb; padding-bottom: 8px; margin-bottom: 16px;">
          📋 Your Personal Tasks (${data.personal_unclaimed + data.personal_claimed})
        </h2>
        
        ${data.personal_unclaimed > 0 ? `
          <h3 style="color: #6b7280; font-size: 1rem; margin: 16px 0 8px 0;">Unclaimed (${data.personal_unclaimed})</h3>
          ${taskListHtml(tasks.personal_unclaimed, 'Unclaimed Personal Tasks', 'No unclaimed tasks')}
        ` : ''}
        
        ${data.personal_claimed > 0 ? `
          <h3 style="color: #6b7280; font-size: 1rem; margin: 16px 0 8px 0;">Claimed by You (${data.personal_claimed})</h3>
          ${taskListHtml(tasks.personal_claimed, 'Your Claimed Tasks', 'No claimed tasks')}
        ` : ''}

        ${data.personal_unclaimed === 0 && data.personal_claimed === 0 ? `
          <p style="color: #6b7280; font-style: italic;">You have no personal tasks right now. Great job! 🎉</p>
        ` : ''}
      </div>

      ${data.has_partner ? `
        <!-- Shared Tasks Section -->
        <div style="margin-bottom: 32px;">
          <h2 style="color: #111827; border-bottom: 2px solid #e5e7eb; padding-bottom: 8px; margin-bottom: 16px;">
            👥 Shared Tasks with ${data.partner_name || 'Partner'} (${data.group_unclaimed + data.group_claimed_by_user + data.group_claimed_by_partner})
          </h2>
          
          ${data.group_unclaimed > 0 ? `
            <h3 style="color: #6b7280; font-size: 1rem; margin: 16px 0 8px 0;">⏳ No One Owns (${data.group_unclaimed})</h3>
            ${taskListHtml(tasks.group_unclaimed, 'Unclaimed Shared Tasks', 'No unclaimed shared tasks')}
          ` : ''}
          
          ${data.group_claimed_by_user > 0 ? `
            <h3 style="color: #6b7280; font-size: 1rem; margin: 16px 0 8px 0;">✋ You Own (${data.group_claimed_by_user})</h3>
            ${taskListHtml(tasks.group_claimed_by_user, 'Tasks You Own', 'You own no tasks')}
          ` : ''}
          
          ${data.group_claimed_by_partner > 0 ? `
            <h3 style="color: #6b7280; font-size: 1rem; margin: 16px 0 8px 0;">🤝 ${data.partner_name || 'Partner'} Owns (${data.group_claimed_by_partner})</h3>
            ${taskListHtml(tasks.group_claimed_by_partner, 'Tasks Partner Owns', 'Partner owns no tasks')}
          ` : ''}

          ${data.group_unclaimed === 0 && data.group_claimed_by_user === 0 && data.group_claimed_by_partner === 0 ? `
            <p style="color: #6b7280; font-style: italic;">No shared tasks right now. Create one to collaborate! 🚀</p>
          ` : ''}
        </div>
      ` : `
        <!-- Pair Up Section -->
        <div style="background: #fef3c7; border-left: 4px solid #f59e0b; padding: 16px; border-radius: 8px; margin-bottom: 32px;">
          <h3 style="color: #92400e; margin: 0 0 8px 0;">💡 Pair up to share tasks!</h3>
          <p style="color: #78350f; margin: 0;">Connect with a partner in DuoTask to collaborate on shared tasks together.</p>
        </div>
      `}

      <!-- Footer -->
      <div style="text-align: center; margin-top: 48px; padding-top: 24px; border-top: 1px solid #e5e7eb;">
        <p style="color: #6b7280; font-size: 0.875rem; margin: 8px 0;">
          <a href="https://duotask-seven.vercel.app" style="color: #6366f1; text-decoration: none;">Open DuoTask</a>
        </p>
        <p style="color: #9ca3af; font-size: 0.75rem; margin: 8px 0;">
          Don't want these emails? <a href="https://duotask-seven.vercel.app/settings" style="color: #6b7280;">Manage preferences</a>
        </p>
      </div>

    </body>
    </html>
  `
}

serve(async (req) => {
  try {
    // Initialize Supabase client
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

    // Get all users with email enabled
    const { data: preferences, error: prefsError } = await supabase
      .from('email_preferences')
      .select('user_id')
      .eq('daily_email_enabled', true)

    if (prefsError) throw prefsError

    let emailsSent = 0
    let emailsFailed = 0

    // Send emails to each user
    for (const pref of preferences || []) {
      try {
        // Get email data for user
        const { data: emailDataResult, error: emailDataError } = await supabase
          .rpc('get_daily_email_data', { user_uuid: pref.user_id })

        if (emailDataError) throw emailDataError

        const emailData: EmailData = emailDataResult

        // Skip if no open tasks
        if (emailData.total_open === 0) continue

        // Get task details
        const { data: tasksResult, error: tasksError } = await supabase
          .rpc('get_daily_email_tasks', { user_uuid: pref.user_id })

        if (tasksError) throw tasksError

        const tasks: TasksData = tasksResult

        // Build email HTML
        const htmlContent = buildEmailHtml(emailData, tasks)

        // Send email via Resend
        const resendResponse = await fetch('https://api.resend.com/emails', {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${RESEND_API_KEY}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            from: 'DuoTask <noreply@duotask.app>',
            to: [emailData.user_email],
            subject: `Your Daily DuoTask Digest - ${emailData.total_open} task${emailData.total_open !== 1 ? 's' : ''}`,
            html: htmlContent,
          }),
        })

        if (resendResponse.ok) {
          emailsSent++
          
          // Update last_email_sent_at
          await supabase
            .from('email_preferences')
            .update({ last_email_sent_at: new Date().toISOString() })
            .eq('user_id', pref.user_id)
        } else {
          emailsFailed++
          console.error(`Failed to send email to ${emailData.user_email}:`, await resendResponse.text())
        }

      } catch (userError) {
        emailsFailed++
        console.error(`Error processing user ${pref.user_id}:`, userError)
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        emails_sent: emailsSent,
        emails_failed: emailsFailed,
        total_users: (preferences || []).length,
      }),
      {
        headers: { 'Content-Type': 'application/json' },
        status: 200,
      }
    )

  } catch (error) {
    console.error('Error in daily-email-digest function:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        headers: { 'Content-Type': 'application/json' },
        status: 500,
      }
    )
  }
})
