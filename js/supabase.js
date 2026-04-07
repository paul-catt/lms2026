// src/js/supabase.js
// Centralised Supabase client - imported by all pages

const SUPABASE_URL = 'https://jrdjdqjepffdcjdfuarc.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpyZGpkcWplcGZmZGNqZGZ1YXJjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU0NTczMTcsImV4cCI6MjA5MTAzMzMxN30.nzriEXXYSau-2wBElzgWw-Gwhf1crzVA2lcvPexjq0M';

const { createClient } = supabase;
const db = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
