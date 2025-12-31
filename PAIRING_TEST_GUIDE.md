# 🔗 DuoTask Pairing Test Guide

## ✅ Issue Fixed: RLS Policy

**Problem**: Users couldn't search for pending pairing codes because the Row Level Security (RLS) policy only allowed viewing pairings where the user was already the requester OR recipient. When accepting a code, the recipient_id was NULL, so the query failed.

**Solution**: Updated the SELECT policy on the `pairings` table to allow anyone to view pending pairings. This enables users to search for codes before accepting them.

```sql
-- New Policy
CREATE POLICY "Users can view their pairings or search pending codes"
ON pairings FOR SELECT
USING (
  (auth.uid() = requester_id OR auth.uid() = recipient_id)
  OR
  (status = 'pending')
);
```

---

## 🎯 How to Test Pairing

### **Prerequisites**
- Two different users (can be two browser windows/devices)
- Fresh start (existing pairings have been cancelled)

### **Test Users Ready:**
- ✅ **User 1**: `jhasavi@gmail.com`
- ✅ **User 2**: `munujha@gmail.com`

---

## 📋 Step-by-Step Test Procedure

### **Step 1: User 1 Generates Code**

1. Sign in as `jhasavi@gmail.com`
2. Navigate to **Pairing Screen** (from Home → Settings → Pairing, or similar)
3. Click **"Generate Code"** button
4. You should see a code appear in a large, gradient box (e.g., `XYZW1234`)
5. Click the **Copy icon** next to the code
6. Confirm you see: "Code copied to clipboard!" (green snackbar)

**Expected Result**: Code is displayed clearly and copied successfully.

---

### **Step 2: User 2 Accepts Code**

1. Open a new browser window/incognito/device
2. Sign in as `munujha@gmail.com`
3. Navigate to **Pairing Screen**
4. In the **"Enter Partner's Code"** section:
   - Paste or type the code from User 1 (e.g., `XYZW1234`)
   - Click **"Connect"** button
5. Wait for processing

**Expected Result**: 
- Success message: "Successfully paired!"
- Screen closes or redirects to Home
- Both users should now see each other as paired

---

### **Step 3: Verify Pairing**

**For Both Users:**

1. Go to **Pairing Screen** again
2. You should see:
   - Partner's name and email
   - A checkmark icon indicating successful pairing
   - "Disconnect Partner" button

**For User 1** (`jhasavi@gmail.com`):
- Should see: "Connected with munujha@gmail.com"

**For User 2** (`munujha@gmail.com`):
- Should see: "Connected with jhasavi@gmail.com"

---

## 🧪 Additional Tests

### **Test 3: Cannot Pair With Yourself**

1. Sign in as any user
2. Generate your own code
3. Try to enter your own code
4. **Expected**: Error message "Cannot pair with yourself"

### **Test 4: Invalid Code**

1. Enter a random/non-existent code (e.g., `ZZZZ9999`)
2. Click Connect
3. **Expected**: Error message "Invalid or expired pairing code"

### **Test 5: Unpair**

1. While paired, click **"Disconnect Partner"**
2. Confirm the action
3. **Expected**: 
   - Success message "Unpairing successful"
   - Both users should no longer see each other as paired
   - Can generate new codes and pair again

---

## 🚀 New Deployment

**Production URL**: `https://duotask-nxpt77b88-sanjeevs-projects-e08bbbfb.vercel.app`

**Changes Deployed**:
- ✅ Fixed RLS policy for pairing code lookup
- ✅ Professional pairing UI with gradients and large fonts
- ✅ Better error handling and user feedback
- ✅ Loading states during operations

---

## 🐛 Debugging

If pairing still fails, check browser console (F12):

1. Look for **"Accepting pairing code: XXXXX"** debug logs
2. Check **"Pairing response: ..."** to see query results
3. Any PostgrestException errors will show the exact failure

**Database Check** (from terminal):

```bash
# Check if codes exist
PGPASSWORD=M3ra-task psql "postgresql://postgres@db.xqhlnuvpogiolzkucupt.supabase.co:5432/postgres" -c "SELECT pairing_code, status, requester_id, recipient_id FROM public.pairings WHERE status = 'pending';"

# Check user's active pairings
PGPASSWORD=M3ra-task psql "postgresql://postgres@db.xqhlnuvpogiolzkucupt.supabase.co:5432/postgres" -c "SELECT u1.email as requester, u2.email as recipient, p.status FROM pairings p JOIN users u1 ON p.requester_id = u1.id LEFT JOIN users u2 ON p.recipient_id = u2.id WHERE p.status = 'active';"
```

---

## ✨ What's New in the UI

1. **Large, Readable Code Display**:
   - 24px font size with 6px letter spacing
   - Monospace font family
   - Gradient background (primary → secondary colors)
   - Prominent copy button

2. **Professional Card Design**:
   - Elevated cards with rounded corners
   - Icon badges with colored backgrounds
   - Clear visual hierarchy

3. **Better Feedback**:
   - Green success snackbars with checkmark
   - Red error snackbars with clear messages
   - Loading spinners during operations

4. **Improved UX**:
   - Clear labels and instructions
   - Centered, large input field for codes
   - Prominent action buttons

---

**Ready to test!** Try pairing `jhasavi@gmail.com` with `munujha@gmail.com` now! 🎉
