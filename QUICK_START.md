# 🎯 DUOTASK - QUICK START GUIDE

## ✅ YOUR WEB APP IS LIVE!

### Working URLs (Choose any):
1. **https://duotask-seven.vercel.app** ⭐ (RECOMMENDED - Short & clean)
2. https://duotask-sanjeevs-projects-e08bbbfb.vercel.app
3. https://duotask-jhasavi-sanjeevs-projects-e08bbbfb.vercel.app

### Custom Domain Setup (duotask.namasteneedham.com)
To make your custom domain work:

1. **Go to Vercel Dashboard:** https://vercel.com/sanjeevs-projects-e08bbbfb/duotask/settings/domains
2. **Add your domain:** duotask.namasteneedham.com
3. **Add DNS records at your domain provider:**
   - Type: CNAME
   - Name: duotask
   - Value: cname.vercel-dns.com
4. **Wait 5-10 minutes** for DNS propagation

---

## 🤖 DISCORD BOT SETUP

### What "Add to Server" Means:
Discord bots need to be invited to a Discord server (like a Slack workspace) before you can use them.

### Quick Setup (2 minutes):

#### If you DON'T have a Discord server:
1. **Open Discord** (app or web: https://discord.com)
2. **Create a server:**
   - Click the "+" button on left sidebar
   - Choose "Create My Own"
   - Name it "DuoTask Test" or anything you like
   - Click "Create"

#### Add the Bot:
1. **Click this link:** https://discord.com/oauth2/authorize?client_id=1440406561393737892&permissions=2147485696&integration_type=0&scope=bot+applications.commands
2. **Select your server** from the dropdown
3. **Click "Authorize"**
4. **Complete the CAPTCHA**
5. **Done!** The bot is now in your server

#### Test the Bot:
Go to any channel in your server and type:
```
/register
```
You'll see the command autocomplete - fill in:
- Email: test@example.com
- Password: secure123
- Name: Your Name

---

## 🧪 TESTING BOTH PLATFORMS

### Option 1: Web App Only (Fastest)
1. Open: **https://duotask-seven.vercel.app**
2. Click "Register" or "Login with Google"
3. Create tasks using the + button
4. Tap task bubbles to change status (Orange → Blue → Green)
5. Test pairing:
   - Click pairing icon
   - Open app in incognito/another browser
   - Register different account
   - Enter pairing code
   - See tasks sync!

### Option 2: Discord Bot Only
1. Make sure bot is in your server (see above)
2. In any channel: `/register email:you@email.com password:pass123 name:John`
3. Create tasks: `/task title:"Buy groceries" urgent:true`
4. View tasks: `/list`
5. Generate pairing code: `/pair`

### Option 3: Cross-Platform Sync (COOLEST!)
1. **On Web:** Register account: user@test.com
2. **On Discord:** Login with same account: `/login email:user@test.com password:yourpass`
3. **Create task on Web** → Type `/list` on Discord → See it appear! ✨
4. **Create task on Discord** → Refresh web app → See it sync! ✨

---

## 🔍 TROUBLESHOOTING

### "I can't see the web app"
- ✅ Use: **https://duotask-seven.vercel.app**
- ❌ Don't use the long URL (it has auth protection)
- Custom domain needs DNS setup (see above)

### "Discord says 'Add to Server'"
- This is normal! You need to:
  1. Have a Discord account (free at discord.com)
  2. Create or join a Discord server
  3. Invite the bot to that server using the link
  4. Then use commands in that server

### "Commands don't work in Discord"
- Make sure you invited the bot (used the authorization link)
- Bot must be online: `ps aux | grep "node index.js"`
- If not running: 
  ```bash
  cd /Users/sanjeevjha/duo/duotask/discord-bot
  nohup node index.js > bot.log 2>&1 &
  ```

### "Tasks don't sync"
- Make sure you're using the SAME email/account on both platforms
- Check you're logged in (not just registered)
- Try creating task on one platform, wait 2-3 seconds, check other

---

## 📱 SHARE WITH OTHERS

Send this link to anyone:
**https://duotask-seven.vercel.app**

They can:
- Use it on any device (phone, tablet, computer)
- Register their own account
- Pair with you using pairing codes
- See your tasks sync in real-time!

---

## 🎯 WHAT TO TRY FIRST

**Absolute Simplest Test (30 seconds):**
1. Open: https://duotask-seven.vercel.app
2. Click around, create a task
3. Done! That's it!

**Full Experience (5 minutes):**
1. Open web app on computer
2. Open web app on phone (same URL)
3. Register on computer
4. Generate pairing code
5. Enter code on phone
6. Create task on phone → See it on computer instantly! 🎉

---

## ✅ CURRENT STATUS

- ✅ Web app deployed and working
- ✅ Discord bot online and ready
- ✅ Supabase database connected
- ✅ Real-time sync enabled
- ⏳ Custom domain (needs DNS setup)

**Everything works - just use https://duotask-seven.vercel.app to start!**
