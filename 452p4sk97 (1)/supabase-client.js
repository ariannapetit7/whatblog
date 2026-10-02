// Browser-safe Supabase project configuration. The publishable key is designed for client use;
// database access must still be protected by the Row Level Security policies in supabase-setup.sql.
(function () {
  const supabaseUrl = 'https://btrycwhwyddoutgmzilo.supabase.co';
  const supabasePublishableKey = 'sb_publishable_ro8BBIjyvxh8l1P9rl5hjQ_Cg3y6iR3';

  if (!window.supabase || typeof window.supabase.createClient !== 'function') {
    console.error('Supabase client library did not load.');
    return;
  }

  window.appSupabase = window.supabase.createClient(supabaseUrl, supabasePublishableKey);
})();
