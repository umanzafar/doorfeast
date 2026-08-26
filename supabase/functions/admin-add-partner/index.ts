// Supabase Edge Function: admin-add-partner
// Deploy via the Supabase Dashboard: Edge Functions -> admin-add-partner ->
// paste this file's contents (replacing everything) -> Deploy.
//
// Called by admin.html's "Add Partner" tab — the real onboarding path for
// a sales-led signup (a phone call, not the public application form).
// Creates a real Supabase Auth user for the owner (no password set), an
// already-approved restaurant_applications row, and the linked
// restaurants row, then returns a recovery link the admin sends to the
// owner manually (no email-sending infra exists yet — same as
// decide-application's own unbuilt decision-email TODO) so they can set a
// password and log in. Documents still come from the owner afterward via
// onboarding-documents.html.

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

    const callerClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } }
    });
    const { data: { user: caller }, error: callerError } = await callerClient.auth.getUser();
    if (callerError || !caller) {
      return json({ error: 'Not authenticated' }, 401);
    }

    const adminClient = createClient(supabaseUrl, serviceRoleKey);

    const { data: adminRow } = await adminClient
      .from('admins')
      .select('user_id')
      .eq('user_id', caller.id)
      .maybeSingle();

    if (!adminRow) {
      return json({ error: 'Not an admin' }, 403);
    }

    const body = await req.json();
    const { business_name, owner_name, phone, email, cuisine, address } = body;

    if (!business_name || !owner_name || !phone || !email || !cuisine || !address) {
      return json({ error: 'business_name, owner_name, phone, email, cuisine and address are all required' }, 400);
    }

    const { data: newUser, error: createUserError } = await adminClient.auth.admin.createUser({
      email,
      email_confirm: true
    });
    if (createUserError || !newUser?.user) {
      return json({ error: createUserError?.message || 'Could not create an account for that email' }, 400);
    }

    const ownerUserId = newUser.user.id;

    // Anything below this point failing leaves an auth user with nothing
    // attached to it — clean it up rather than leaving an orphaned
    // account that would block re-trying with the same email.
    async function rollbackUser() {
      await adminClient.auth.admin.deleteUser(ownerUserId);
    }

    const baseSlug = String(business_name)
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/(^-|-$)/g, '');
    let slug = baseSlug;
    let suffix = 1;
    // eslint-disable-next-line no-constant-condition
    while (true) {
      const { data: existing } = await adminClient.from('restaurants').select('id').eq('slug', slug).maybeSingle();
      if (!existing) break;
      suffix += 1;
      slug = `${baseSlug}-${suffix}`;
    }

    const { data: newRestaurant, error: restaurantError } = await adminClient
      .from('restaurants')
      .insert({
        name: business_name,
        slug,
        address,
        postcode: '',
        phone,
        cuisine,
        is_live: false,
        does_delivery: false,
        does_collection: false,
        owner_user_id: ownerUserId
      })
      .select('id')
      .single();

    if (restaurantError) {
      await rollbackUser();
      return json({ error: restaurantError.message }, 500);
    }

    const { error: applicationError } = await adminClient
      .from('restaurant_applications')
      .insert({
        user_id: ownerUserId,
        business_name,
        owner_name,
        phone,
        email,
        address,
        cuisine,
        status: 'approved',
        restaurant_id: newRestaurant.id,
        decided_at: new Date().toISOString()
      });

    if (applicationError) {
      await rollbackUser();
      return json({ error: applicationError.message }, 500);
    }

    const { data: linkData, error: linkError } = await adminClient.auth.admin.generateLink({
      type: 'recovery',
      email
    });
    if (linkError || !linkData) {
      // The account and records exist regardless — just couldn't mint the
      // link right now. Not worth rolling back over; the admin can ask
      // the owner to use "forgot password" on signup.html instead.
      return json({
        success: true,
        restaurant_id: newRestaurant.id,
        recovery_link: null,
        warning: 'Partner created, but the recovery link could not be generated. Have them use "Forgot password" on the login page instead.'
      });
    }

    return json({
      success: true,
      restaurant_id: newRestaurant.id,
      recovery_link: linkData.properties.action_link
    });
  } catch (err) {
    return json({ error: err instanceof Error ? err.message : 'Unknown error' }, 500);
  }
});
