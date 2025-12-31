# DuoTask / Task Bubble — Pairing + Shared Tasks Spec (VS Code Prompt)

> **✅ IMPLEMENTATION STATUS:** This specification has been fully implemented. See [PAIRING_IMPROVEMENTS.md](./PAIRING_IMPROVEMENTS.md) for implementation details and migration guide.

Use this prompt in VS Code (or Cursor) to guide implementation of the **pairing system** and **bubble task state machine**.  
Target stack: **Flutter (Android/iOS/macOS) + Supabase (DB + Realtime)**.

---

## 1) Goal

Implement a **two-user pairing workflow** and a **one-tap bubble interaction model** for task status transitions, with **real-time sync** between paired partners.

Key UX rules:

- **Before pairing**: tasks are **personal-only** by default.
- **After pairing**: when creating a task, user can choose **Personal** vs **Group** with **one click** (single tap toggle / segmented control).
- Bubble color rules:
  - If **creator is me** and task is **unclaimed** → **Yellow**
  - If **creator is partner** and task is **unclaimed** → **Orange**
  - If **claimed** by either partner → **Blue** and **smaller** bubble
  - If **completed** by either partner → **Green**
- Bubble tap transitions are **one click**:
  - **Unclaimed → Claimed → Done → Unclaimed** (cycle)
- Both partners see color/size transitions **in real time**.
- Bottom tab includes a dedicated **Pairing** screen/tab.
- Pairing is **remembered** (no repeated code prompts once paired), but partner is **notified** of pairing status changes.
- While paired, user can still manage **Personal** tasks easily.

---

## 2) Definitions

### Task Types
- **Personal task**: visible only to the creator (UserA).
- **Group task**: visible to both paired users.

### Task Status
- **unclaimed**
- **claimed**
- **done**

### Task Ownership Fields
- `created_by`: user_id of creator
- `pair_id`: nullable; set for group tasks
- `visibility`: `personal` | `group`
- `claimed_by`: nullable user_id (for group tasks; for personal tasks this may be creator or null based on your UX choice)
- `status`: `unclaimed` | `claimed` | `done`

---

## 3) Database + Realtime (Supabase) — Proposed Schema

### 3.1 `pairs` table
Stores the pairing relationship.

Fields:
- `id` (uuid, pk)
- `user_a` (uuid, fk -> profiles/users)
- `user_b` (uuid, fk -> profiles/users)
- `pair_code` (text, unique, short)
- `status` (text: `pending` | `active` | `revoked`)
- `created_at` (timestamptz)
- `updated_at` (timestamptz)

Rules:
- Only one **active** pair per user (for now).
- Pair code can be regenerated if unpaired/revoked.

### 3.2 `tasks` table
Fields:
- `id` (uuid, pk)
- `title` (text)
- `notes` (text, nullable)
- `visibility` (text: `personal` | `group`)
- `pair_id` (uuid, nullable, fk -> pairs.id)
- `created_by` (uuid)
- `status` (text: `unclaimed` | `claimed` | `done`)
- `claimed_by` (uuid, nullable)
- `claimed_at` (timestamptz, nullable)
- `done_at` (timestamptz, nullable)
- `due_at` (timestamptz, nullable)
- `created_at` (timestamptz)
- `updated_at` (timestamptz)

Realtime:
- Enable replication on `tasks` (and optionally `pairs`) for realtime updates.
- Subscribe client-side filtered by:
  - personal tasks: `created_by == current_user`
  - group tasks: `pair_id == my_active_pair_id`

### 3.3 RLS Policies (high-level)
- Personal tasks: only `created_by` can select/insert/update/delete.
- Group tasks: both users in the pair can select/update; insert allowed only if current user is in that pair.

> Implementation detail: use a helper view/function or join to validate membership in a pair.

---

## 4) Pairing Workflow

### 4.1 States
- **Unpaired**: no active pair in `pairs` for current user.
- **Paired**: `pairs.status == active` and current user is either `user_a` or `user_b`.

### 4.2 UX Flow
**Pairing Tab** shows:
- If unpaired:
  - “Create Pair Code” (generates a code + creates `pairs` row with status `pending` and `user_a = me`)
  - “Enter Pair Code” (joins an existing pending pair, sets `user_b = me`, status → `active`)
- If paired:
  - Show partner identity (name/email)
  - “Unpair” (status → `revoked`)
  - Optional: “Regenerate Code” (only if unpaired)

**Remember pairing**:
- On app startup, fetch active pair for current user once and keep in app state.
- Persist `pair_id` locally (secure storage) as a cache; always verify with Supabase on launch.

**Partner notifications**:
- Minimal approach: show a **real-time banner/toast** in-app when `pairs.status` changes.
- Optional later: push notification if you re-enable FCM.

---

## 5) Task Creation Rules

### 5.1 Before pairing
- Creating a task creates:
  - `visibility = personal`
  - `pair_id = null`
  - `status = unclaimed` (or you may default to `claimed` for personal tasks—see note below)
- Bubble color for personal tasks:
  - If you keep personal tasks in the same status model, treat “unclaimed created_by me” as Yellow.

### 5.2 After pairing
When the user taps “+ Add Task”:
- Present a **one-tap chooser** between:
  - **Personal** and **Group**
- Recommended UI: `SegmentedButton` / `CupertinoSlidingSegmentedControl` / two-icon toggle.
- Default selection: remember last choice for speed (but keep it safe—e.g. default to Personal first time).

If **Group** selected:
- `visibility = group`
- `pair_id = my_active_pair_id`

If **Personal** selected:
- `visibility = personal`
- `pair_id = null`

> Important: Personal tasks remain fully usable while paired by filtering in the task list UI (see Section 8).

---

## 6) Bubble Color + Size Rules

Given a task and current user:

### 6.1 Determine base state
- If `status == unclaimed`:
  - If `created_by == me` → **Yellow**
  - Else if `created_by == partner` → **Orange** (only possible for group tasks)
- If `status == claimed` → **Blue** (both users see the same)
- If `status == done` → **Green**

### 6.2 Bubble size
- **Unclaimed**: larger
- **Claimed**: smaller (visual cue of “in progress” / “taken”)
- **Done**: your choice, but keep consistent (often smaller or medium)

Implementation tip:
- Define sizes as constants, e.g. `kBubbleSizeUnclaimed`, `kBubbleSizeClaimed`, `kBubbleSizeDone`.

---

## 7) One-Tap State Machine (Bubble Tap)

### 7.1 Required transitions
On bubble tap, cycle:

1. **unclaimed → claimed**
   - Set `status = claimed`
   - Set `claimed_by = current_user`
   - Set `claimed_at = now()`

2. **claimed → done**
   - Set `status = done`
   - Set `done_at = now()`
   - Keep `claimed_by` as-is (whoever claimed)

3. **done → unclaimed**
   - Set `status = unclaimed`
   - Set `claimed_by = null`
   - Set `claimed_at = null`
   - Set `done_at = null`

### 7.2 Concurrency / race conditions
Two users might tap at the same time.

To implement safely:
- Use **optimistic UI** but confirm with DB result.
- Update via a single `update` call with a **WHERE** guard:
  - Example: when moving unclaimed→claimed, only update if `status == 'unclaimed'`.
- If update affects 0 rows, refresh task state and display “Already claimed”.

Best option (most robust):
- Use a Postgres function (RPC) `transition_task(task_id, user_id)` that:
  - Reads current status
  - Applies transition atomically
  - Returns updated row

---

## 8) Task Lists While Paired

Make it easy for paired users to still do personal work.

Recommended UI pattern:
- On the main tasks screen, add a **top filter** (chips or segmented control):
  - **Group**
  - **Personal**
  - **All**
- Default when paired: **Group** (or remember last used)
- Default when unpaired: **Personal**

This solves your “not sure how personal tasks work while paired” concern cleanly: they’re simply another filter view.

---

## 9) Bottom Navigation + Pairing Tab

Bottom tabs (example):
- **Tasks**
- **Pairing**
- **History/Stats** (optional)

Pairing tab requirements:
- Unpaired view: create code + enter code
- Paired view: partner info + status + unpair
- Display pairing status prominently (Active / Pending / Unpaired)

Remembering partner:
- Once paired, store a lightweight local state (e.g., `pair_id`, `partner_name`) for fast boot.
- On app resume/launch, verify active pair from Supabase to prevent stale pairing.

---

## 10) Real-Time Sync Requirements

### 10.1 Subscribe to tasks changes
- Subscribe to inserts/updates/deletes on `tasks` relevant to the user:
  - `created_by == me` OR `pair_id == my_pair_id`

### 10.2 Subscribe to pairing changes
- Subscribe to `pairs` where:
  - `user_a == me OR user_b == me`
- Update UI when:
  - status becomes active (paired)
  - status revoked (unpaired)

### 10.3 UI update behavior
- When remote change arrives, animate bubble color/size change.
- Ensure both devices update within a second or two.

---

## 11) Acceptance Criteria (must pass)

1. Unpaired users can create tasks and they are always **personal**.
2. After pairing, task creation provides **one-tap** Personal vs Group.
3. Unclaimed bubble colors:
   - created by me → Yellow
   - created by partner → Orange
4. Claimed bubbles are Blue and smaller, for both users.
5. Done bubbles are Green for both users.
6. Single tap on bubble cycles **unclaimed → claimed → done → unclaimed**.
7. Changes appear **in real-time** on both devices.
8. Pairing screen exists in bottom tabs.
9. Pairing is remembered; code not re-requested after successful pairing.
10. Partner is notified in-app when pairing status changes.
11. While paired, user can still access personal tasks easily via filter.

---

## 12) Suggestions to Make Partner Collaboration Easier

### 12.1 Add “Assigned to” micro-label (optional)
Even though claim color shows it, a tiny icon/initials overlay can reduce confusion:
- Claimed by me: show my initials
- Claimed by partner: show partner initials

### 12.2 Quick “nudge” button (optional)
Inside a task details sheet:
- “Nudge partner” sends an in-app ping (or push later)

### 12.3 Daily mode
A simple toggle:
- **Today view** only shows tasks due today / created today
- Keeps shared work focused

### 12.4 Conflict safety
If personal tasks are separate, prevent accidental creation of group tasks by:
- Defaulting create mode to Personal unless explicitly toggled
- Remembering last used mode only after user intentionally selects Group a few times

### 12.5 Undo
After tap transition, show a quick snackbar:
- “Marked done” [Undo]
This reduces anxiety about one-click cycling.

---

## 13) Implementation Notes for the Developer (what to build)

- Create/confirm Supabase tables and RLS.
- Implement Pairing tab and pair state in app-level store (Riverpod/Provider/BLoC).
- Implement task creation modal with one-tap Personal/Group toggle (only visible when paired).
- Implement bubble widget mapping status→color/size with rules above.
- Implement bubble tap state machine via RPC or guarded updates.
- Implement Realtime subscriptions for tasks and pairs.
- Add task list filters (All/Group/Personal) when paired.

---

## 14) Developer Checklist

- [ ] DB schema created: `pairs`, `tasks`
- [ ] RLS policies validated with two test users
- [ ] Pair create/join/unpair flows complete
- [ ] Persist pair locally + verify on boot
- [ ] One-tap create toggle only when paired
- [ ] Bubble color rules implemented
- [ ] Bubble size rules implemented
- [ ] One-tap transition cycle implemented + concurrency safe
- [ ] Realtime subscriptions wired for tasks + pairs
- [ ] Filters for Personal vs Group while paired
- [ ] In-app pairing status notification

---

## 15) Notes / Clarification Choices (OK to decide now)

**Personal tasks status model:**  
Option A (simple): Personal tasks also start as **unclaimed** (yellow) and can be claimed/done like group tasks.  
Option B (more natural): Personal tasks start as **claimed by me** automatically (blue/smaller), because “I created it so I own it.”  
Either is acceptable—choose one and keep consistent.

Recommended: **Option B** (less confusing). If you choose Option B, adjust the spec:
- Personal tasks set `status = claimed` and `claimed_by = me` at creation time.

---

End of prompt.
