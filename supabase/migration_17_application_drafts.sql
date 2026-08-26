-- DoorFeast — Migration 17: save-and-continue for the application form
-- Run after migration_16.
--
-- application.html now saves progress as the applicant goes, instead of
-- only writing a row on final submit. A 'draft' row is created the moment
-- someone starts the form and updated after each step, so closing the tab
-- (or a phone call ending mid-form) doesn't lose their answers — resuming
-- reloads whatever was saved and picks up at the first empty step.
--
-- draft rows are still owner-only, same as every other status — no admin
-- visibility into in-progress drafts in this pass. The existing "no
-- update after submission" stance is preserved for pending/approved/
-- rejected; only 'draft' rows are ever updatable from the browser.
--
-- If this constraint has a different name than assumed below (unlikely,
-- but check with \d restaurant_applications in the SQL editor if this
-- errors), adjust the `drop constraint` line to match.

alter table restaurant_applications drop constraint restaurant_applications_status_check;
alter table restaurant_applications add constraint restaurant_applications_status_check
  check (status in ('draft', 'pending', 'approved', 'rejected'));

-- USING gates which rows are updatable at all (must currently be a draft
-- of theirs). WITH CHECK gates what the row is allowed to become after —
-- 'pending' is included so final submit (draft -> pending) is allowed by
-- this same policy, but 'approved'/'rejected' are deliberately excluded:
-- an owner still can't set those themselves, only decide-application's
-- service_role can, same as before this migration.
create policy "owner can update own draft"
  on restaurant_applications for update
  using (user_id = auth.uid() and status = 'draft')
  with check (user_id = auth.uid() and status in ('draft', 'pending'));
