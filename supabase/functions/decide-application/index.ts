// Supabase Edge Function: decide-application
// Deploy via the Supabase Dashboard: Edge Functions -> Create a function ->
// name it "decide-application" -> paste this file's contents -> Deploy.
//
// Called by admin.html when an admin clicks Approve/Reject. Verifies the
// caller is a real admin (checked server-side against the `admins` table,
// not trusted from the browser), then — using the service_role key, which
// never reaches the browser — updates the application and, on approval,
// creates the restaurants row.
//
// Email sending (approve/reject notification to the applicant) is not
// wired up yet — see the TODO near the bottom. Add it once an email
// provider (e.g. Resend) is chosen.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

Deno.serve(async (req) => {
  try {
    if (req.method !== 'POST') {
      return new Response(JSON.stringify({ error: 'Method not allowed' }), { status: 405 });
    }

    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'Missing authorization' }), { status: 401 });
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
      return new Response(JSON.stringify({ error: 'Not authenticated' }), { status: 401 });
    }

    // service_role — bypasses RLS. Only used after the admin check below.
    const adminClient = createClient(supabaseUrl, serviceRoleKey);

    const { data: adminRow } = await adminClient
      .from('admins')
      .select('user_id')
      .eq('user_id', user.id)
      .maybeSingle();

    if (!adminRow) {
      return new Response(JSON.stringify({ error: 'Not an admin' }), { status: 403 });
    }

    const body = await req.json();
    const { application_id, action, reject_reason } = body;

    if (!application_id || !['approve', 'reject'].includes(action)) {
      return new Response(JSON.stringify({ error: 'Invalid request' }), { status: 400 });
    }
    if (action === 'reject' && !reject_reason) {
      return new Response(JSON.stringify({ error: 'reject_reason is required' }), { status: 400 });
    }

    const { data: application, error: appError } = await adminClient
      .from('restaurant_applications')
      .select('*')
      .eq('id', application_id)
      .single();

    if (appError || !application) {
      return new Response(JSON.stringify({ error: 'Application not found' }), { status: 404 });
    }
    if (application.status !== 'pending') {
      return new Response(JSON.stringify({ error: 'Application already decided' }), { status: 409 });
    }

    let restaurantId: string | null = null;

    if (action === 'approve') {
      const baseSlug = application.business_name
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

      // postcode/delivery settings aren't collected on the application form —
      // left blank/false here, filled in later by the owner via the dashboard's
      // Business Info section (or by an admin directly in the table editor).
      const { data: newRestaurant, error: restaurantError } = await adminClient
        .from('restaurants')
        .insert({
          name: application.business_name,
          slug,
          address: application.address,
          postcode: '',
          phone: application.phone,
          cuisine: application.cuisine,
          is_live: false,
          does_delivery: false,
          does_collection: false,
          owner_user_id: application.user_id
        })
        .select('id')
        .single();

      if (restaurantError) {
        return new Response(JSON.stringify({ error: restaurantError.message }), { status: 500 });
      }
      restaurantId = newRestaurant.id;
    }

    const { error: updateError } = await adminClient
      .from('restaurant_applications')
      .update({
        status: action === 'approve' ? 'approved' : 'rejected',
        reject_reason: action === 'reject' ? reject_reason : null,
        restaurant_id: restaurantId,
        decided_at: new Date().toISOString()
      })
      .eq('id', application_id);

    if (updateError) {
      return new Response(JSON.stringify({ error: updateError.message }), { status: 500 });
    }

    // TODO: send the applicant a decision email once an email provider
    // (e.g. Resend) is set up. Not blocking — the app already reflects the
    // decision on application-thankyou.html the next time they check.

    return new Response(JSON.stringify({ success: true, restaurant_id: restaurantId }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' }
    });
  } catch (err) {
    return new Response(JSON.stringify({ error: err instanceof Error ? err.message : 'Unknown error' }), { status: 500 });
  }
});
