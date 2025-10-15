-- Quick DuoTask Database Diagnostic
-- Run this first to get essential information

-- 1. Check if critical columns exist
SELECT 'CRITICAL COLUMNS CHECK' as section;
SELECT 
    'usr.last_seen' as column_name,
    CASE WHEN EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'usr' AND column_name = 'last_seen'
    ) THEN '✅ EXISTS' ELSE '❌ MISSING' END as status
UNION ALL
SELECT 
    'tasks.claimed_by' as column_name,
    CASE WHEN EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'tasks' AND column_name = 'claimed_by'
    ) THEN '✅ EXISTS' ELSE '❌ MISSING' END as status
UNION ALL
SELECT 
    'pair_requests.updated_at' as column_name,
    CASE WHEN EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pair_requests' AND column_name = 'updated_at'
    ) THEN '✅ EXISTS' ELSE '❌ MISSING' END as status;

-- 2. Check table structures
SELECT 'TABLE STRUCTURES' as section;
SELECT 
    table_name,
    COUNT(*) as column_count
FROM information_schema.columns 
WHERE table_schema = 'public' 
AND table_name IN ('usr', 'tasks', 'pair_codes', 'pair_requests')
GROUP BY table_name
ORDER BY table_name;

-- 3. Check RLS status
SELECT 'RLS STATUS' as section;
SELECT 
    tablename,
    CASE WHEN rowsecurity THEN '✅ ENABLED' ELSE '❌ DISABLED' END as rls_status
FROM pg_tables 
WHERE schemaname = 'public' 
AND tablename IN ('usr', 'tasks', 'pair_codes', 'pair_requests')
ORDER BY tablename;

-- 4. Data counts
SELECT 'DATA COUNTS' as section;
SELECT 
    'Users' as table_name,
    COUNT(*) as record_count
FROM public.usr
UNION ALL
SELECT 
    'Tasks' as table_name,
    COUNT(*) as record_count
FROM public.tasks
UNION ALL
SELECT 
    'Pair Codes' as table_name,
    COUNT(*) as record_count
FROM public.pair_codes
UNION ALL
SELECT 
    'Pair Requests' as table_name,
    COUNT(*) as record_count
FROM public.pair_requests;

-- 5. Sample data (first 3 records each)
SELECT 'SAMPLE USERS' as section;
SELECT id, email, name, paired_with FROM public.usr LIMIT 3;

SELECT 'SAMPLE TASKS' as section;
SELECT id, title, status, owner_id FROM public.tasks LIMIT 3;
