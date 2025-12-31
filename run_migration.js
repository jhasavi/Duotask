#!/usr/bin/env node
/**
 * Migration Script for Pairing Improvements
 * Runs the SQL migration to add visibility and pair_id fields
 */

const { createClient } = require('@supabase/supabase-js');
require('dotenv').config();

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_ANON_KEY;

if (!supabaseUrl || !supabaseKey) {
  console.error('❌ Missing Supabase credentials in .env file');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseKey);

const migrations = [
  {
    name: 'Add visibility column',
    sql: `
      ALTER TABLE tasks 
      ADD COLUMN IF NOT EXISTS visibility TEXT NOT NULL DEFAULT 'personal' 
      CHECK (visibility IN ('personal', 'group'));
    `
  },
  {
    name: 'Add pair_id column',
    sql: `
      ALTER TABLE tasks 
      ADD COLUMN IF NOT EXISTS pair_id UUID 
      REFERENCES pairings(id) ON DELETE SET NULL;
    `
  },
  {
    name: 'Create indexes',
    sql: `
      CREATE INDEX IF NOT EXISTS idx_tasks_pair_id ON tasks(pair_id);
      CREATE INDEX IF NOT EXISTS idx_tasks_visibility ON tasks(visibility);
    `
  },
  {
    name: 'Migrate existing data',
    sql: `
      UPDATE tasks 
      SET visibility = CASE 
        WHEN is_personal = true THEN 'personal' 
        ELSE 'group' 
      END
      WHERE visibility = 'personal';
    `
  },
  {
    name: 'Update SELECT policy',
    sql: `
      DROP POLICY IF EXISTS "Users can view their own tasks" ON tasks;
      CREATE POLICY "Users can view their own tasks"
        ON tasks FOR SELECT
        USING (
          (visibility = 'personal' AND auth.uid() = created_by_id)
          OR
          (visibility = 'group' AND pair_id IN (
            SELECT id FROM pairings 
            WHERE status = 'active' 
            AND (requester_id = auth.uid() OR recipient_id = auth.uid())
          ))
          OR
          auth.uid() = assigned_to_id OR
          auth.uid() = claimed_by_id
        );
    `
  },
  {
    name: 'Update UPDATE policy',
    sql: `
      DROP POLICY IF EXISTS "Users can update their own tasks" ON tasks;
      CREATE POLICY "Users can update their own tasks"
        ON tasks FOR UPDATE
        USING (
          (visibility = 'personal' AND auth.uid() = created_by_id)
          OR
          (visibility = 'group' AND pair_id IN (
            SELECT id FROM pairings 
            WHERE status = 'active' 
            AND (requester_id = auth.uid() OR recipient_id = auth.uid())
          ))
          OR
          auth.uid() = assigned_to_id
        );
    `
  },
  {
    name: 'Create RPC function',
    sql: `
      CREATE OR REPLACE FUNCTION cycle_task_status(
        task_uuid UUID,
        user_uuid UUID
      )
      RETURNS TABLE (
        id UUID,
        status TEXT,
        claimed_by_id UUID,
        claimed_at TIMESTAMPTZ,
        completed_at TIMESTAMPTZ,
        updated_at TIMESTAMPTZ
      ) AS $$
      DECLARE
        current_status TEXT;
        new_status TEXT;
        new_claimed_by UUID;
        new_claimed_at TIMESTAMPTZ;
        new_completed_at TIMESTAMPTZ;
      BEGIN
        SELECT tasks.status INTO current_status
        FROM tasks
        WHERE tasks.id = task_uuid
        FOR UPDATE;

        CASE current_status
          WHEN 'unclaimed' THEN
            new_status := 'claimed';
            new_claimed_by := user_uuid;
            new_claimed_at := NOW();
            new_completed_at := NULL;
          WHEN 'claimed' THEN
            new_status := 'completed';
            new_claimed_by := (SELECT tasks.claimed_by_id FROM tasks WHERE tasks.id = task_uuid);
            new_claimed_at := (SELECT tasks.claimed_at FROM tasks WHERE tasks.id = task_uuid);
            new_completed_at := NOW();
          WHEN 'completed' THEN
            new_status := 'unclaimed';
            new_claimed_by := NULL;
            new_claimed_at := NULL;
            new_completed_at := NULL;
          ELSE
            RAISE EXCEPTION 'Invalid task status: %', current_status;
        END CASE;

        RETURN QUERY
        UPDATE tasks
        SET 
          status = new_status,
          claimed_by_id = new_claimed_by,
          claimed_at = new_claimed_at,
          completed_at = new_completed_at,
          updated_at = NOW()
        WHERE tasks.id = task_uuid
        RETURNING tasks.id, tasks.status::TEXT, tasks.claimed_by_id, 
                  tasks.claimed_at, tasks.completed_at, tasks.updated_at;
      END;
      $$ LANGUAGE plpgsql SECURITY DEFINER;
    `
  }
];

async function runMigrations() {
  console.log('🚀 Starting database migration...\n');
  
  for (let i = 0; i < migrations.length; i++) {
    const migration = migrations[i];
    console.log(`[${i + 1}/${migrations.length}] Running: ${migration.name}...`);
    
    try {
      const { error } = await supabase.rpc('exec_sql', { sql: migration.sql });
      
      if (error) {
        // Try direct execution if RPC fails
        const response = await fetch(`${supabaseUrl}/rest/v1/rpc/exec_sql`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'apikey': supabaseKey,
            'Authorization': `Bearer ${supabaseKey}`
          },
          body: JSON.stringify({ sql: migration.sql })
        });
        
        if (!response.ok) {
          console.log(`   ⚠️  Could not run via API (this is expected for schema changes)`);
          console.log(`   📝 Please run this SQL manually in Supabase SQL Editor:`);
          console.log(`   ${migration.sql.trim().substring(0, 100)}...`);
        } else {
          console.log(`   ✅ Success`);
        }
      } else {
        console.log(`   ✅ Success`);
      }
    } catch (err) {
      console.log(`   ⚠️  Note: ${err.message}`);
      console.log(`   📝 Manual execution may be required in Supabase SQL Editor`);
    }
  }
  
  console.log('\n✅ Migration script completed!');
  console.log('\n📋 Next Steps:');
  console.log('1. Verify migrations in Supabase SQL Editor');
  console.log('2. Run: flutter pub get');
  console.log('3. Run: flutter run');
  console.log('4. Test the new features');
}

runMigrations().catch(console.error);
