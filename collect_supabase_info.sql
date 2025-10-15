-- DuoTask Database Diagnostic Script
-- Run this in your Supabase SQL Editor to collect all necessary information

-- ========================================
-- 1. DATABASE SCHEMA INFORMATION
-- ========================================

-- Check if tables exist
SELECT 'TABLE EXISTENCE CHECK' as section;
SELECT 
    table_name,
    CASE WHEN table_name IS NOT NULL THEN 'EXISTS' ELSE 'MISSING' END as status
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('usr', 'tasks', 'pair_codes', 'pair_requests')
ORDER BY table_name;

-- ========================================
-- 2. TABLE STRUCTURE ANALYSIS
-- ========================================

-- usr table structure
SELECT 'USR TABLE STRUCTURE' as section;
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default,
    CASE WHEN column_name IN ('last_seen', 'claimed_by', 'updated_at') THEN 'MISSING COLUMN' ELSE 'OK' END as status
FROM information_schema.columns 
WHERE table_name = 'usr' AND table_schema = 'public'
ORDER BY ordinal_position;

-- tasks table structure
SELECT 'TASKS TABLE STRUCTURE' as section;
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default,
    CASE WHEN column_name IN ('claimed_by', 'pair_id', 'repeat_type', 'due_date', 'urgent') THEN 'MISSING COLUMN' ELSE 'OK' END as status
FROM information_schema.columns 
WHERE table_name = 'tasks' AND table_schema = 'public'
ORDER BY ordinal_position;

-- pair_codes table structure
SELECT 'PAIR_CODES TABLE STRUCTURE' as section;
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'pair_codes' AND table_schema = 'public'
ORDER BY ordinal_position;

-- pair_requests table structure
SELECT 'PAIR_REQUESTS TABLE STRUCTURE' as section;
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default,
    CASE WHEN column_name = 'updated_at' THEN 'MISSING COLUMN' ELSE 'OK' END as status
FROM information_schema.columns 
WHERE table_name = 'pair_requests' AND table_schema = 'public'
ORDER BY ordinal_position;

-- ========================================
-- 3. INDEX ANALYSIS
-- ========================================

-- Check existing indexes
SELECT 'EXISTING INDEXES' as section;
SELECT 
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes 
WHERE schemaname = 'public' 
AND tablename IN ('usr', 'tasks', 'pair_codes', 'pair_requests')
ORDER BY tablename, indexname;

-- ========================================
-- 4. ROW LEVEL SECURITY (RLS) STATUS
-- ========================================

-- Check RLS status
SELECT 'RLS STATUS' as section;
SELECT 
    schemaname,
    tablename,
    rowsecurity as rls_enabled
FROM pg_tables 
WHERE schemaname = 'public' 
AND tablename IN ('usr', 'tasks', 'pair_codes', 'pair_requests')
ORDER BY tablename;

-- Check RLS policies
SELECT 'RLS POLICIES' as section;
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies 
WHERE schemaname = 'public' 
AND tablename IN ('usr', 'tasks', 'pair_codes', 'pair_requests')
ORDER BY tablename, policyname;

-- ========================================
-- 5. DATA ANALYSIS
-- ========================================

-- User count and sample data
SELECT 'USER DATA ANALYSIS' as section;
SELECT 
    'Total users' as metric,
    COUNT(*) as value
FROM public.usr;

SELECT 'Sample user data' as metric;
SELECT 
    id,
    email,
    name,
    paired_with,
    email_confirmed,
    created_at
FROM public.usr 
LIMIT 5;

-- Task count and sample data
SELECT 'TASK DATA ANALYSIS' as section;
SELECT 
    'Total tasks' as metric,
    COUNT(*) as value
FROM public.tasks;

SELECT 'Sample task data' as metric;
SELECT 
    id,
    title,
    status,
    owner_id,
    created_at
FROM public.tasks 
LIMIT 5;

-- Pair codes analysis
SELECT 'PAIR CODES ANALYSIS' as section;
SELECT 
    'Total pair codes' as metric,
    COUNT(*) as value
FROM public.pair_codes;

SELECT 'Active pair codes' as metric,
    COUNT(*) as value
FROM public.pair_codes 
WHERE is_used = false;

-- Pair requests analysis
SELECT 'PAIR REQUESTS ANALYSIS' as section;
SELECT 
    'Total pair requests' as metric,
    COUNT(*) as value
FROM public.pair_requests;

SELECT 'Pending pair requests' as metric,
    COUNT(*) as value
FROM public.pair_requests 
WHERE status = 'pending';

-- ========================================
-- 6. FOREIGN KEY CONSTRAINTS
-- ========================================

-- Check foreign key constraints
SELECT 'FOREIGN KEY CONSTRAINTS' as section;
SELECT 
    tc.table_name,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints AS tc 
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
    AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
    AND ccu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY' 
AND tc.table_schema = 'public'
AND tc.table_name IN ('usr', 'tasks', 'pair_codes', 'pair_requests')
ORDER BY tc.table_name, kcu.column_name;

-- ========================================
-- 7. TRIGGERS
-- ========================================

-- Check triggers
SELECT 'TRIGGERS' as section;
SELECT 
    trigger_name,
    event_manipulation,
    event_object_table,
    action_statement
FROM information_schema.triggers 
WHERE trigger_schema = 'public'
AND event_object_table IN ('usr', 'tasks', 'pair_requests')
ORDER BY event_object_table, trigger_name;

-- ========================================
-- 8. FUNCTIONS
-- ========================================

-- Check functions
SELECT 'FUNCTIONS' as section;
SELECT 
    routine_name,
    routine_type,
    data_type
FROM information_schema.routines 
WHERE routine_schema = 'public'
AND routine_name LIKE '%update%'
ORDER BY routine_name;

-- ========================================
-- 9. SUMMARY AND RECOMMENDATIONS
-- ========================================

SELECT 'SUMMARY AND RECOMMENDATIONS' as section;

-- Missing columns summary
SELECT 'MISSING COLUMNS SUMMARY' as subsection;
SELECT 
    'usr.last_seen' as missing_column,
    CASE WHEN EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'usr' AND column_name = 'last_seen'
    ) THEN 'EXISTS' ELSE 'MISSING - NEEDS TO BE ADDED' END as status
UNION ALL
SELECT 
    'tasks.claimed_by' as missing_column,
    CASE WHEN EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'tasks' AND column_name = 'claimed_by'
    ) THEN 'EXISTS' ELSE 'MISSING - NEEDS TO BE ADDED' END as status
UNION ALL
SELECT 
    'pair_requests.updated_at' as missing_column,
    CASE WHEN EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'pair_requests' AND column_name = 'updated_at'
    ) THEN 'EXISTS' ELSE 'MISSING - NEEDS TO BE ADDED' END as status;

-- Action items
SELECT 'ACTION ITEMS' as subsection;
SELECT 
    '1. Add missing columns' as action,
    'Run the update_database.sql script' as instruction
UNION ALL
SELECT 
    '2. Verify RLS policies' as action,
    'Ensure all tables have proper RLS policies' as instruction
UNION ALL
SELECT 
    '3. Check indexes' as action,
    'Verify all required indexes exist' as instruction
UNION ALL
SELECT 
    '4. Test app functionality' as action,
    'Restart Flutter app after database updates' as instruction;
