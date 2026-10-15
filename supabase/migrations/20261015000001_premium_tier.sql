-- ============================================================================
-- Premium tier (web, Stripe)
--
-- DuoTask has no `profiles` table: the per-user profile row is public.users,
-- so the premium columns live there.
--
-- Who can write them: ONLY the service role (the stripe-webhook Edge
-- Function). The existing "Users can update their own profile" RLS policy
-- lets a signed-in user UPDATE any column of their own row, so without the
-- guard trigger below anyone could grant themselves premium from the browser
-- console. Column-level REVOKEs are not enough on their own because the
-- table-level UPDATE grant to `authenticated` still covers new columns.
--
-- One subscription covers the pair: public.get_premium_status() reports a
-- user as premium when they OR their active partner hold a live
-- subscription.
-- ============================================================================

BEGIN;

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS is_premium BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS premium_until TIMESTAMPTZ;

-- Stripe identifiers live apart from public.users because a user's row is
-- readable by their partner (RLS "Users can view their partner's profile").
-- RLS is on with no policies: only the service role can read or write it.
CREATE TABLE IF NOT EXISTS public.billing_customers (
  user_id UUID PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
  stripe_customer_id TEXT NOT NULL UNIQUE,
  stripe_subscription_id TEXT UNIQUE,
  subscription_status TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.billing_customers ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.billing_customers FROM anon, authenticated;

DROP TRIGGER IF EXISTS update_billing_customers_updated_at ON public.billing_customers;
CREATE TRIGGER update_billing_customers_updated_at
  BEFORE UPDATE ON public.billing_customers
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- ----------------------------------------------------------------------------
-- Guard: premium columns are server-managed.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.guard_billing_columns()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
  -- auth.role() is 'service_role' for the webhook, NULL for direct SQL in
  -- the dashboard / migrations (postgres role); both are trusted.
  IF auth.role() IN ('anon', 'authenticated') THEN
    IF TG_OP = 'INSERT' THEN
      IF NEW.is_premium OR NEW.premium_until IS NOT NULL THEN
        RAISE EXCEPTION 'Billing fields are managed by the server'
          USING ERRCODE = '42501';
      END IF;
    ELSIF NEW.is_premium IS DISTINCT FROM OLD.is_premium
       OR NEW.premium_until IS DISTINCT FROM OLD.premium_until THEN
      RAISE EXCEPTION 'Billing fields are managed by the server'
        USING ERRCODE = '42501';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_guard_billing_columns ON public.users;
CREATE TRIGGER trg_guard_billing_columns
  BEFORE INSERT OR UPDATE ON public.users
  FOR EACH ROW
  EXECUTE FUNCTION public.guard_billing_columns();

-- ----------------------------------------------------------------------------
-- Effective premium status for the caller, including the partner's plan.
-- SECURITY DEFINER so it can look at the partner row without widening the
-- users SELECT policy; it only ever reports on auth.uid() and their active
-- partner.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_premium_status()
RETURNS TABLE (
  is_premium BOOLEAN,
  premium_until TIMESTAMPTZ,
  via_partner BOOLEAN
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  me UUID := auth.uid();
  partner UUID;
  my_until TIMESTAMPTZ;
  partner_until TIMESTAMPTZ;
BEGIN
  IF me IS NULL THEN
    RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
  END IF;

  -- premium_until NULL with is_premium TRUE means "no known end" (e.g. a
  -- manual grant); treat it as open-ended.
  SELECT CASE WHEN u.is_premium THEN COALESCE(u.premium_until, 'infinity') END
  INTO my_until
  FROM users u WHERE u.id = me;

  SELECT CASE WHEN p.requester_id = me THEN p.recipient_id ELSE p.requester_id END
  INTO partner
  FROM pairings p
  WHERE p.status = 'active'
    AND (p.requester_id = me OR p.recipient_id = me)
  ORDER BY p.accepted_at DESC NULLS LAST
  LIMIT 1;

  IF partner IS NOT NULL THEN
    SELECT CASE WHEN u.is_premium THEN COALESCE(u.premium_until, 'infinity') END
    INTO partner_until
    FROM users u WHERE u.id = partner;
  END IF;

  IF my_until IS NOT NULL AND my_until > NOW() THEN
    RETURN QUERY SELECT TRUE,
      CASE WHEN my_until = 'infinity' THEN NULL ELSE my_until END, FALSE;
  ELSIF partner_until IS NOT NULL AND partner_until > NOW() THEN
    RETURN QUERY SELECT TRUE,
      CASE WHEN partner_until = 'infinity' THEN NULL ELSE partner_until END, TRUE;
  ELSE
    RETURN QUERY SELECT FALSE, NULL::TIMESTAMPTZ, FALSE;
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.get_premium_status() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_premium_status() TO authenticated;

COMMIT;
