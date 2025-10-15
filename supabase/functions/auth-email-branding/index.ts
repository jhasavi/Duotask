// Supabase Edge Function: auth-email-branding
// Customizes email templates for DuoTask authentication emails
// This function intercepts auth emails and applies custom branding

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

interface EmailTemplate {
  subject: string;
  html: string;
  text: string;
}

const DUOTASK_BRANDING = {
  name: "DuoTask",
  logo: "https://duotask.app/logo.png", // Replace with actual logo URL
  primaryColor: "#6366f1", // Indigo
  secondaryColor: "#f59e0b", // Amber
  supportEmail: "support@duotask.app",
  website: "https://duotask.app",
}

function createEmailTemplate(type: string, data: any): EmailTemplate {
  const baseHtml = `
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>${DUOTASK_BRANDING.name}</title>
      <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; margin: 0; padding: 0; background-color: #f8fafc; }
        .container { max-width: 600px; margin: 0 auto; background-color: white; }
        .header { background: linear-gradient(135deg, ${DUOTASK_BRANDING.primaryColor}, ${DUOTASK_BRANDING.secondaryColor}); padding: 40px 20px; text-align: center; }
        .logo { font-size: 32px; font-weight: bold; color: white; margin-bottom: 10px; }
        .tagline { color: rgba(255,255,255,0.9); font-size: 16px; }
        .content { padding: 40px 20px; }
        .button { display: inline-block; background-color: ${DUOTASK_BRANDING.primaryColor}; color: white; padding: 12px 24px; text-decoration: none; border-radius: 8px; font-weight: 600; margin: 20px 0; }
        .footer { background-color: #f1f5f9; padding: 20px; text-align: center; color: #64748b; font-size: 14px; }
        .footer a { color: ${DUOTASK_BRANDING.primaryColor}; text-decoration: none; }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="header">
          <div class="logo">${DUOTASK_BRANDING.name}</div>
          <div class="tagline">Simple task sharing for two</div>
        </div>
        <div class="content">
          {{CONTENT}}
        </div>
        <div class="footer">
          <p>© 2024 ${DUOTASK_BRANDING.name}. All rights reserved.</p>
          <p>Need help? Contact us at <a href="mailto:${DUOTASK_BRANDING.supportEmail}">${DUOTASK_BRANDING.supportEmail}</a></p>
          <p><a href="${DUOTASK_BRANDING.website}">${DUOTASK_BRANDING.website}</a></p>
        </div>
      </div>
    </body>
    </html>
  `;

  switch (type) {
    case 'confirm_signup':
      return {
        subject: `Confirm your ${DUOTASK_BRANDING.name} account`,
        html: baseHtml.replace('{{CONTENT}}', `
          <h2>Welcome to ${DUOTASK_BRANDING.name}! 👋</h2>
          <p>Thanks for signing up! To complete your registration, please confirm your email address by clicking the button below:</p>
          <a href="${data.confirmation_url}" class="button">Confirm Email Address</a>
          <p>If the button doesn't work, you can copy and paste this link into your browser:</p>
          <p style="word-break: break-all; color: #64748b;">${data.confirmation_url}</p>
          <p>This link will expire in 24 hours for security reasons.</p>
          <p>If you didn't create a ${DUOTASK_BRANDING.name} account, you can safely ignore this email.</p>
        `),
        text: `
Welcome to ${DUOTASK_BRANDING.name}!

Thanks for signing up! To complete your registration, please confirm your email address by visiting this link:

${data.confirmation_url}

This link will expire in 24 hours for security reasons.

If you didn't create a ${DUOTASK_BRANDING.name} account, you can safely ignore this email.

Best regards,
The ${DUOTASK_BRANDING.name} Team
        `
      };

    case 'recovery':
      return {
        subject: `Reset your ${DUOTASK_BRANDING.name} password`,
        html: baseHtml.replace('{{CONTENT}}', `
          <h2>Password Reset Request 🔐</h2>
          <p>We received a request to reset your ${DUOTASK_BRANDING.name} password. Click the button below to create a new password:</p>
          <a href="${data.recovery_url}" class="button">Reset Password</a>
          <p>If the button doesn't work, you can copy and paste this link into your browser:</p>
          <p style="word-break: break-all; color: #64748b;">${data.recovery_url}</p>
          <p>This link will expire in 1 hour for security reasons.</p>
          <p>If you didn't request a password reset, you can safely ignore this email. Your password will remain unchanged.</p>
        `),
        text: `
Password Reset Request

We received a request to reset your ${DUOTASK_BRANDING.name} password. Visit this link to create a new password:

${data.recovery_url}

This link will expire in 1 hour for security reasons.

If you didn't request a password reset, you can safely ignore this email. Your password will remain unchanged.

Best regards,
The ${DUOTASK_BRANDING.name} Team
        `
      };

    case 'magic_link':
      return {
        subject: `Sign in to ${DUOTASK_BRANDING.name}`,
        html: baseHtml.replace('{{CONTENT}}', `
          <h2>Sign in to ${DUOTASK_BRANDING.name} 🚀</h2>
          <p>Click the button below to sign in to your ${DUOTASK_BRANDING.name} account:</p>
          <a href="${data.magic_link}" class="button">Sign In</a>
          <p>If the button doesn't work, you can copy and paste this link into your browser:</p>
          <p style="word-break: break-all; color: #64748b;">${data.magic_link}</p>
          <p>This link will expire in 1 hour for security reasons.</p>
          <p>If you didn't request this sign-in link, you can safely ignore this email.</p>
        `),
        text: `
Sign in to ${DUOTASK_BRANDING.name}

Click the link below to sign in to your ${DUOTASK_BRANDING.name} account:

${data.magic_link}

This link will expire in 1 hour for security reasons.

If you didn't request this sign-in link, you can safely ignore this email.

Best regards,
The ${DUOTASK_BRANDING.name} Team
        `
      };

    default:
      return {
        subject: `${DUOTASK_BRANDING.name} Notification`,
        html: baseHtml.replace('{{CONTENT}}', `
          <h2>${DUOTASK_BRANDING.name} Notification</h2>
          <p>You have a new notification from ${DUOTASK_BRANDING.name}.</p>
        `),
        text: `${DUOTASK_BRANDING.name} Notification\n\nYou have a new notification from ${DUOTASK_BRANDING.name}.`
      };
  }
}

serve(async (req) => {
  try {
    const { type, data } = await req.json();
    
    if (!type || !data) {
      return new Response(
        JSON.stringify({ error: 'Missing type or data' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      );
    }

    const template = createEmailTemplate(type, data);
    
    return new Response(
      JSON.stringify(template),
      { headers: { 'Content-Type': 'application/json' } }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    );
  }
});
