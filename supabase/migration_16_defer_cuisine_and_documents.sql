-- DoorFeast — Migration 16: defer cuisine and documents to post-approval
-- Run after migration_15.
--
-- The application wizard now only asks for business name, owner name,
-- phone, and address up front — cuisine and the 3 documents are collected
-- after approval, via onboarding-documents.html and the new
-- complete-onboarding Edge Function. Neither is known at initial
-- submission time anymore, so they can no longer be not-null.

alter table restaurant_applications alter column cuisine drop not null;
alter table restaurant_applications alter column hygiene_cert_path drop not null;
alter table restaurant_applications alter column business_reg_path drop not null;
alter table restaurant_applications alter column id_doc_path drop not null;
alter table restaurants alter column cuisine drop not null;
