# 🤖 DuoTask Discord Bot - Quick Start

## ✅ Configuration Saved

Your Discord bot is configured with:
- **Application ID**: 1440406561393737892
- **Client ID**: 1440406561393737892

## 🔑 NEXT STEP: Get Your Bot Token

1. Go back to: https://discord.com/developers/applications/1440406561393737892/bot
2. Under "TOKEN" section, click **"Reset Token"** (or "Copy" if visible)
3. **Copy the token** (it looks like: `MTQ0MDQwNjU2MTM5MzczNzg5Mg.GXxXxX.xxxxxxxxxxxxxxxxxxxxxxxxxxx`)
4. **Paste it below** to complete setup:

```bash
cd /Users/sanjeevjha/duo/duotask/discord-bot

# Edit .env and replace YOUR_BOT_TOKEN_GOES_HERE with your actual token
nano .env

# Or use this command (replace TOKEN_HERE with your actual token):
# sed -i '' 's/YOUR_BOT_TOKEN_GOES_HERE/YOUR_ACTUAL_TOKEN/' .env
```

## 🚀 Once You Have the Token

### Start the bot:
```bash
cd /Users/sanjeevjha/duo/duotask/discord-bot
npm install
npm start
```

### Invite bot to your server:
Use this URL (already configured for you):
```
https://discord.com/oauth2/authorize?client_id=1440406561393737892&permissions=2147485696&integration_type=0&scope=bot+applications.commands
```

1. Click the URL
2. Select your Discord server
3. Click "Authorize"

## 📝 Available Commands

Once the bot is running and invited:

```
/register email:you@email.com password:secure123 name:YourName
/login email:you@email.com password:secure123
/task title:"Buy groceries" urgent:true
/list
/pair
/accept code:ABC123
```

## ✅ Current Status

- ✅ Application created
- ✅ Client ID configured
- ⏳ **Need bot token** (get from Bot tab)
- ⏳ Install dependencies
- ⏳ Start bot
- ⏳ Invite to server

---

**Just get the bot token and paste it in `discord-bot/.env`, then run `npm install && npm start`!**
