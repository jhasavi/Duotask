# Migration to Clean Pairing Plan

## Overview
This document outlines the migration from the current complex pairing system to the cleaner approach defined in PAIRING.md.

## Current Issues to Fix
1. **Complex pairing state**: Multiple fields in `usr` table (`paired_with`, `pair_status`, `pair_request_from`)
2. **Task reassignment**: Tasks get moved when pairing/unpairing
3. **Request queues**: Complex pairing request system
4. **Data inconsistency**: No guarantees about exclusive pairing

## New Clean Approach (from PAIRING.md)

### 1. New Data Model
```sql
-- Dedicated pair table (dyad)
CREATE TABLE public.pair (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_a UUID NOT NULL REFERENCES public.usr(id),
  user_b UUID NOT NULL REFERENCES public.usr(id),
  status TEXT DEFAULT 'inactive' CHECK (status IN ('active', 'inactive')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_a, user_b),
  CONSTRAINT user_a_less_than_user_b CHECK (user_a < user_b)
);

-- Updated tasks table
ALTER TABLE public.tasks ADD COLUMN IF NOT EXISTS scope TEXT DEFAULT 'personal' CHECK (scope IN ('personal', 'shared'));
ALTER TABLE public.tasks ADD COLUMN IF NOT EXISTS creator_id UUID REFERENCES public.usr(id);
ALTER TABLE public.tasks ADD COLUMN IF NOT EXISTS pair_id UUID REFERENCES public.pair(id);
```

### 2. Key Benefits
- ✅ **Exclusive pairing**: Users can only be in one active pair
- ✅ **Task persistence**: Shared tasks stay with the dyad
- ✅ **Immutable properties**: `creator_id` and `pair_id` never change
- ✅ **Simple state**: Just active/inactive pairs
- ✅ **Re-pairing works**: Same dyad tasks reappear

### 3. Migration Steps

#### Phase 1: Create New Schema
1. Create `pair` table
2. Add new columns to `tasks` table
3. Create constraints and indexes
4. Set up RLS policies

#### Phase 2: Data Migration
1. Create dyads from existing pairings
2. Set `pair_id` on existing shared tasks
3. Set `creator_id` on all tasks
4. Mark dyads as active/inactive based on current state

#### Phase 3: Update Application
1. Replace pairing service with new dyad-based approach
2. Update task queries to use new model
3. Simplify UI to remove request complexity
4. Update RPC functions

#### Phase 4: Cleanup
1. Remove old pairing fields from `usr` table
2. Drop old pairing request tables
3. Remove old functions
4. Update documentation

## Implementation Priority

### High Priority (Fix Core Issues)
1. **Exclusive pairing guarantee**
2. **Task persistence on unpair**
3. **Simplified state management**

### Medium Priority (Improve UX)
1. **Cleaner UI without request queues**
2. **Better error messages**
3. **Consistent behavior**

### Low Priority (Nice to Have)
1. **Audit trails**
2. **Advanced analytics**
3. **Bulk operations**

## Risk Assessment

### Low Risk
- ✅ Data preservation: All existing data can be migrated
- ✅ Backward compatibility: Can maintain old APIs during transition
- ✅ Rollback plan: Can revert to old system if needed

### Medium Risk
- ⚠️ UI changes: Users will see different pairing flow
- ⚠️ Testing required: Need comprehensive testing of new system

### Mitigation
- Implement feature flags for gradual rollout
- Maintain both systems during transition
- Comprehensive testing before full migration

## Recommended Next Steps

1. **Create migration script** to implement new schema
2. **Update pairing service** to use dyad approach
3. **Test with sample data** to verify behavior
4. **Gradual rollout** with feature flags
5. **Monitor and validate** new system works correctly

## Conclusion

The PAIRING.md approach is significantly better than the current implementation. It provides:
- **Simpler logic** with fewer edge cases
- **Better data integrity** with immutable properties
- **Cleaner UX** without complex request flows
- **Future-proof design** that's easier to maintain

**Recommendation**: Implement this migration to resolve current pairing issues and provide a more robust foundation.
