# iOS Troubleshooting Guide

## Common iOS Issues and Solutions

### 1. Local Network Permission Error

**Error:** `Could not register as server for FlutterDartVMServicePublisher, permission denied`

**Solution:**
1. **For iOS Simulator:**
   - This is usually a simulator-specific issue
   - Try restarting the iOS Simulator
   - Go to iOS Simulator → Device → Erase All Content and Settings
   - Re-run the app

2. **For Physical Device:**
   - Go to Settings → Privacy & Security → Local Network
   - Find your app and enable Local Network access
   - Or go to Settings → Your App → Local Network → Allow

### 2. Safari Connection Error

**Error:** "Safari can't open the page because it couldn't connect to the server"

**Causes:**
- OAuth redirect URL mismatch
- Port conflicts
- Network connectivity issues

**Solutions:**
1. **Check OAuth Configuration:**
   - Ensure Supabase OAuth redirect URL is set to: `http://localhost:5001`
   - Verify Google Cloud Console has the same redirect URL

2. **Port Issues:**
   - Make sure port 5001 is not being used by another app
   - Run: `lsof -i :5001` to check
   - Kill conflicting processes: `kill <PID>`

3. **Network Issues:**
   - Check if your firewall is blocking localhost connections
   - Try using a different port (update .env file accordingly)

### 3. iOS Simulator Issues

**Common Problems:**
- App crashes on launch
- Hot reload not working
- Permission errors

**Solutions:**
1. **Reset Simulator:**
   ```bash
   xcrun simctl erase all
   ```

2. **Clean Build:**
   ```bash
   flutter clean
   flutter pub get
   flutter run -d "iPhone 16 Plus"
   ```

3. **Check iOS Version:**
   - Ensure simulator iOS version is compatible
   - Try different iOS versions if needed

### 4. OAuth on iOS

**For iOS Simulator:**
- OAuth works best on web version
- iOS simulator has limitations with OAuth flows
- Use web version for OAuth testing

**For Physical Device:**
- Ensure proper OAuth configuration
- Check network connectivity
- Verify app permissions

### 5. Development vs Production

**Development:**
- Use `http://localhost:5001` for OAuth
- Enable debug mode
- Use iOS Simulator for testing

**Production:**
- Use HTTPS URLs for OAuth
- Configure proper domain names
- Test on physical devices

## Quick Fixes

### Reset Everything:
```bash
# Kill all Flutter processes
pkill -f flutter

# Clean project
flutter clean
flutter pub get

# Reset iOS Simulator
xcrun simctl erase all

# Start fresh
./run_web.sh
```

### Check Status:
```bash
# Check if port is free
lsof -i :5001

# Check Flutter processes
ps aux | grep flutter

# Check iOS devices
flutter devices
```

## Best Practices

1. **Always use the web version for OAuth testing**
2. **Keep iOS Simulator updated**
3. **Use consistent port numbers**
4. **Check permissions before testing**
5. **Test on both simulator and physical device**

## Getting Help

If issues persist:
1. Check Flutter doctor: `flutter doctor -v`
2. Check iOS setup: `flutter doctor --android-licenses`
3. Review console logs for specific error messages
4. Try different iOS simulator versions 