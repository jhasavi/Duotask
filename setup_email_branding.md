# Email Branding Setup Instructions

## 🔧 **Manual Setup Required**

The email branding function has been deployed, but you need to configure it in the Supabase dashboard:

### Step 1: Access Supabase Dashboard
1. Go to your Supabase project dashboard
2. Navigate to **Authentication** → **Email Templates**

### Step 2: Configure Email Templates
For each email template, you need to set the **Custom SMTP** settings:

#### **Confirm Signup Email**
- **From Name**: `DuoTask`
- **From Email**: `noreply@duotask.app` (or your domain)
- **Subject**: `Confirm your DuoTask account`
- **Template**: Use the custom template from the function

#### **Recovery Email**
- **From Name**: `DuoTask`
- **From Email**: `noreply@duotask.app` (or your domain)
- **Subject**: `Reset your DuoTask password`
- **Template**: Use the custom template from the function

#### **Magic Link Email**
- **From Name**: `DuoTask`
- **From Email**: `noreply@duotask.app` (or your domain)
- **Subject**: `Sign in to DuoTask`
- **Template**: Use the custom template from the function

### Step 3: Alternative - Use SMTP Configuration
If you want to use a custom SMTP server:

1. Go to **Authentication** → **Settings**
2. Scroll down to **SMTP Settings**
3. Configure your SMTP server with:
   - **Host**: Your SMTP server
   - **Port**: 587 (or your SMTP port)
   - **Username**: Your email
   - **Password**: Your email password
   - **Sender Name**: `DuoTask`
   - **Sender Email**: `noreply@duotask.app`

### Step 4: Test Email Branding
1. Register a new test user
2. Check that the confirmation email comes from "DuoTask" instead of "Supabase Auth"

---

**Note**: The email branding function is deployed and ready, but Supabase requires manual configuration in the dashboard to use custom email templates.
