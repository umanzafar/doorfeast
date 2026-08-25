// Supabase Edge Function: complete-onboarding
// Deploy via the Supabase Dashboard: Edge Functions -> complete-onboarding ->
// paste this file's contents (replacing everything) -> Deploy.
//
// Called by onboarding-documents.html once an approved applicant has
// uploaded their 3 documents and picked a cuisine. restaurant_applications
// deliberately has no UPDATE policy (see migration_2) — status changes and
// this post-approval completion both go through service_role Edge
// Functions instead of direct browser writes, same pattern as
// decide-application.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS'
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' }
  });
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    if (req.method !== 'POST') {
      return json({ error: 'Method not allowed' }, 405);
    }

    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return json({ error: 'Missing authorization' }, 401);
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;

    // Scoped to the caller's own JWT — only used to find out who's calling.
    const callerClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } }
    });
    const { data: { user }, error: userError } = await callerClient.auth.getUser();
    if (userError || !user) {
      return json({ error: 'Not authenticated' }, 401);
    }

    const body = await req.json();
    const { cuisine, hygiene_cert_path, business_reg_path, id_doc_path } = body;

    if (!cuisine || !hygiene_cert_path || !business_reg_path || !id_doc_path) {
      return json({ error: 'cuisine and all 3 document paths are required' }, 400);
    }

    // Paths are stored as {user_id}/{filename} (same convention the storage
    // RLS policy already enforces on upload) — reject anything that doesn't
    // match the caller's own prefix, so a tampered path can't point at
    // someone else's uploaded file.
    const ownPrefix = `${user.id}/`;
    for (const path of [hygiene_cert_path, business_reg_path, id_doc_path]) {
      if (typeof path !== 'string' || !path.startsWith(ownPrefix)) {
        return json({ error: 'Invalid document path' }, 400);
      }
    }

    // service_role — bypasses RLS. Only used after the checks above.
    const adminClient = createClient(supabaseUrl, serviceRoleKey);

    const { data: application, error: appError } = await adminClient
      .from('restaurant_applications')
      .select('*')
      .eq('user_id', user.id)
      .order('created_at', { ascending: false })
      .limit(1)
      .maybeSingle();

    if (appError || !application) {
      return json({ error: 'No application found' }, 404);
    }
    if (application.status !== 'approved') {
      return json({ error: 'Application is not approved' }, 409);
    }
    if (!application.restaurant_id) {
      return json({ error: 'Approved application has no linked restaurant' }, 500);
    }

    const { error: updateAppError } = await adminClient
      .from('restaurant_applications')
      .update({
        cuisine,
        hygiene_cert_path,
        business_reg_path,
        id_doc_path
      })
      .eq('id', application.id);

    if (updateAppError) {
      return json({ error: updateAppError.message }, 500);
    }

    const { error: updateRestaurantError } = await adminClient
      .from('restaurants')
      .update({ cuisine })
      .eq('id', application.restaurant_id);

    if (updateRestaurantError) {
      return json({ error: updateRestaurantError.message }, 500);
    }

    return json({ success: true });
  } catch (err) {
    return json({ error: err instanceof Error ? err.message : 'Unknown error' }, 500);
  }
});
