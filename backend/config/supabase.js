/**
 * Supabase Client Configuration
 */

const { createClient } = require('@supabase/supabase-js');

// Validate environment variables
if (!process.env.SUPABASE_URL) {
    throw new Error('SUPABASE_URL is not defined in environment variables');
}

if (!process.env.SUPABASE_SERVICE_KEY) {
    throw new Error('SUPABASE_SERVICE_KEY is not defined in environment variables');
}

// Create Supabase client with service role key for backend operations
const supabase = createClient(
    process.env.SUPABASE_URL,
    process.env.SUPABASE_SERVICE_KEY,
    {
        auth: {
            autoRefreshToken: false,
            persistSession: false
        }
    }
);

// Create public client for user-facing operations
const supabasePublic = createClient(
    process.env.SUPABASE_URL,
    process.env.SUPABASE_ANON_KEY
);

module.exports = {
    supabase,
    supabasePublic
};
