-- =============================================================================
-- VERIION OS — Migration 3 : Sécurité (RLS, privilèges)
-- Chaque table est fermée par défaut ; chaque politique découle des fonctions
-- d'autorisation définies dans la migration 1 (has_perm, in_unit, ...).
-- =============================================================================

-- Privilèges de base : l'accès réel est décidé par RLS.
revoke all on all tables    in schema public from anon;
revoke all on all sequences in schema public from anon;
grant usage on schema public to authenticated;
grant select, insert, update, delete on all tables in schema public to authenticated;
grant usage, select on all sequences in schema public to authenticated;

-- Fonctions internes : jamais appelables depuis l'API.
revoke execute on function public.notify(uuid, text, text, text, text)  from public, anon, authenticated;
revoke execute on function public.sync_auto_grants(uuid)                 from public, anon, authenticated;
revoke execute on function public.recompute_invoice(uuid)                from public, anon, authenticated;
revoke execute on function public.mark_overdue_invoices()                from public, anon, authenticated;

-- Garde : seuls org.manage (ou le responsable de l'unité parente) déplacent / archivent une unité.
create or replace function public.org_units_guard()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null or public.has_perm('org.manage') then return new; end if;
  if new.parent_id is distinct from old.parent_id
     or new.kind is distinct from old.kind
     or new.domain is distinct from old.domain
     or new.archived_at is distinct from old.archived_at then
    if not public.has_perm('unit.manage', old.parent_id) then
      raise exception 'Seule la direction peut restructurer cette unité' using errcode = '42501';
    end if;
  end if;
  return new;
end $$;
create trigger org_units_guard_bu before update on public.org_units
  for each row execute function public.org_units_guard();

-- Toute modification d'un modèle de rôle recalcule les droits de tous.
create or replace function public.role_templates_resync()
returns trigger language plpgsql security definer set search_path = public as $$
declare r record;
begin
  for r in select distinct profile_id from public.unit_memberships where end_date is null loop
    perform public.sync_auto_grants(r.profile_id);
  end loop;
  return null;
end $$;
create trigger role_templates_resync_trg after insert or update or delete on public.role_templates
  for each statement execute function public.role_templates_resync();

-- -----------------------------------------------------------------------------
-- Activation RLS
-- -----------------------------------------------------------------------------
do $$
declare t text;
begin
  foreach t in array array[
    'company_settings','org_units','profiles','unit_memberships','permissions','role_templates','role_grants','audit_log',
    'notifications','announcements','channels','channel_members','messages',
    'projects','project_members','tasks','task_dependencies','task_comments',
    'accounts','contacts','opportunities','interactions',
    'budgets','invoices','invoice_lines','transactions',
    'employment_contracts','salaries','leave_requests','lifecycle_items',
    'documents','objectives','key_results','kpi_definitions','product_metrics','incidents',
    'meetings','meeting_attendees'
  ] loop
    execute format('alter table public.%I enable row level security', t);
  end loop;
end $$;

-- -----------------------------------------------------------------------------
-- Socle
-- -----------------------------------------------------------------------------
create policy "settings: lecture"      on public.company_settings for select to authenticated using (public.is_active_user());
create policy "settings: modification" on public.company_settings for update to authenticated using (public.is_admin()) with check (public.is_admin());

create policy "units: lecture"   on public.org_units for select to authenticated using (public.is_active_user());
create policy "units: création"  on public.org_units for insert to authenticated
  with check (public.has_perm('org.manage') or (parent_id is not null and public.has_perm('unit.manage', parent_id)));
create policy "units: modification" on public.org_units for update to authenticated
  using (public.has_perm('org.manage') or public.has_perm('unit.manage', id))
  with check (public.has_perm('org.manage') or public.has_perm('unit.manage', id));
create policy "units: suppression" on public.org_units for delete to authenticated using (public.has_perm('org.manage'));

create policy "profiles: annuaire" on public.profiles for select to authenticated using (public.is_active_user());
create policy "profiles: modification" on public.profiles for update to authenticated
  using (id = auth.uid() or public.has_perm('users.admin') or public.manages_profile(id))
  with check (id = auth.uid() or public.has_perm('users.admin') or public.manages_profile(id));

create policy "memberships: lecture" on public.unit_memberships for select to authenticated using (public.is_active_user());
-- écriture uniquement via appoint_member() / end_membership()

create policy "permissions: lecture" on public.permissions    for select to authenticated using (public.is_active_user());
create policy "templates: lecture"   on public.role_templates for select to authenticated using (public.is_active_user());
create policy "templates: gestion"   on public.role_templates for all to authenticated
  using (public.is_ceo()) with check (public.is_ceo());

create policy "grants: lecture" on public.role_grants for select to authenticated
  using (profile_id = auth.uid() or public.has_perm('grants.manage') or public.has_perm('audit.view'));
create policy "grants: dérogation" on public.role_grants for insert to authenticated
  with check (public.has_perm('grants.manage') and source = 'manual' and granted_by = auth.uid() and profile_id <> auth.uid());
create policy "grants: révocation" on public.role_grants for delete to authenticated
  using (public.has_perm('grants.manage') and source = 'manual');

create policy "audit: lecture" on public.audit_log for select to authenticated using (public.has_perm('audit.view'));

create policy "notifications: les miennes" on public.notifications for select to authenticated using (profile_id = auth.uid());
create policy "notifications: marquer lue"  on public.notifications for update to authenticated using (profile_id = auth.uid()) with check (profile_id = auth.uid());
create policy "notifications: supprimer"    on public.notifications for delete to authenticated using (profile_id = auth.uid());

-- -----------------------------------------------------------------------------
-- Communication
-- -----------------------------------------------------------------------------
create policy "annonces: lecture" on public.announcements for select to authenticated
  using (public.is_active_user() and (unit_id is null or public.in_unit(unit_id) or public.has_perm('unit.manage', unit_id) or author_id = auth.uid()));
create policy "annonces: publication" on public.announcements for insert to authenticated
  with check (public.has_perm('announcements.publish') and author_id = auth.uid());
create policy "annonces: modification" on public.announcements for update to authenticated
  using (author_id = auth.uid() or public.is_admin()) with check (author_id = auth.uid() or public.is_admin());
create policy "annonces: suppression" on public.announcements for delete to authenticated
  using (author_id = auth.uid() or public.is_admin());

create or replace function public.can_access_channel(p_channel uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.channels c
    where c.id = p_channel and public.is_active_user() and (
      c.created_by = auth.uid()
      or exists (select 1 from public.channel_members m where m.channel_id = c.id and m.profile_id = auth.uid())
      or (c.kind = 'group'   and not c.is_private)
      or (c.kind = 'unit'    and (public.in_unit(c.unit_id) or public.has_perm('unit.manage', c.unit_id)))
      or (c.kind = 'project' and public.can_view_project(c.project_id))
    )
  )
$$;

-- Le créateur d'un groupe en est propriétaire.
create or replace function public.channels_after_insert()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.kind = 'group' and new.created_by is not null then
    insert into public.channel_members (channel_id, profile_id, role) values (new.id, new.created_by, 'owner')
    on conflict do nothing;
  end if;
  return null;
end $$;
create trigger channels_ai after insert on public.channels
  for each row execute function public.channels_after_insert();

create policy "canaux: lecture" on public.channels for select to authenticated
  using (created_by = auth.uid() or public.can_access_channel(id));
create policy "canaux: création" on public.channels for insert to authenticated
  with check (public.is_active_user() and kind = 'group' and created_by = auth.uid());
create policy "canaux: modification" on public.channels for update to authenticated
  using (created_by = auth.uid() or public.is_admin()
         or (kind = 'unit' and public.has_perm('unit.manage', unit_id))
         or (kind = 'project' and public.can_manage_project(project_id)))
  with check (created_by = auth.uid() or public.is_admin()
         or (kind = 'unit' and public.has_perm('unit.manage', unit_id))
         or (kind = 'project' and public.can_manage_project(project_id)));

create policy "membres canal: lecture" on public.channel_members for select to authenticated
  using (profile_id = auth.uid() or public.can_access_channel(channel_id));
create policy "membres canal: rejoindre / ajouter" on public.channel_members for insert to authenticated
  with check (
    (profile_id = auth.uid() and public.can_access_channel(channel_id))
    or exists (select 1 from public.channels c where c.id = channel_id and c.kind = 'group' and c.created_by = auth.uid())
    or exists (select 1 from public.channel_members m where m.channel_id = channel_members.channel_id and m.profile_id = auth.uid() and m.role = 'owner')
  );
create policy "membres canal: préférences" on public.channel_members for update to authenticated
  using (profile_id = auth.uid()) with check (profile_id = auth.uid());
create policy "membres canal: quitter / retirer" on public.channel_members for delete to authenticated
  using (profile_id = auth.uid() or exists (select 1 from public.channels c where c.id = channel_id and c.created_by = auth.uid()));

create policy "messages: lecture" on public.messages for select to authenticated using (public.can_access_channel(channel_id));
create policy "messages: envoi" on public.messages for insert to authenticated
  with check (author_id = auth.uid() and public.can_access_channel(channel_id)
              and exists (select 1 from public.channels c where c.id = channel_id and c.archived_at is null));
create policy "messages: édition" on public.messages for update to authenticated
  using (author_id = auth.uid()) with check (author_id = auth.uid());

-- -----------------------------------------------------------------------------
-- Projets & tâches
-- -----------------------------------------------------------------------------
create policy "projets: lecture" on public.projects for select to authenticated
  using (owner_id = auth.uid() or public.project_role(id) is not null or public.in_unit(unit_id)
         or public.has_perm('projects.admin') or public.has_perm('unit.manage', unit_id) or public.has_perm('dashboard.exec'));
create policy "projets: création" on public.projects for insert to authenticated
  with check (public.is_active_user() and owner_id = auth.uid()
              and (unit_id is null or public.in_unit(unit_id) or public.has_perm('unit.assign', unit_id) or public.has_perm('projects.admin')));
create policy "projets: modification" on public.projects for update to authenticated
  using (public.can_manage_project(id)) with check (public.can_manage_project(id));
create policy "projets: suppression" on public.projects for delete to authenticated
  using (public.has_perm('projects.admin') or owner_id = auth.uid());

create policy "membres projet: lecture" on public.project_members for select to authenticated using (public.can_view_project(project_id));
create policy "membres projet: gestion" on public.project_members for all to authenticated
  using (public.can_manage_project(project_id)) with check (public.can_manage_project(project_id));

create or replace function public.can_view_task(p_task uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.tasks t where t.id = p_task and (
      t.assignee_id = auth.uid() or t.reporter_id = auth.uid()
      or (t.project_id is not null and public.can_view_project(t.project_id)))
  )
$$;

create or replace function public.can_edit_task(p_task uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.tasks t where t.id = p_task and (
      t.assignee_id = auth.uid() or t.reporter_id = auth.uid()
      or (t.project_id is not null and public.can_contribute_project(t.project_id)))
  )
$$;

create policy "tâches: lecture" on public.tasks for select to authenticated
  using (assignee_id = auth.uid() or reporter_id = auth.uid() or (project_id is not null and public.can_view_project(project_id)));
create policy "tâches: création" on public.tasks for insert to authenticated
  with check (public.is_active_user() and reporter_id = auth.uid()
              and (project_id is null or public.can_contribute_project(project_id)));
create policy "tâches: modification" on public.tasks for update to authenticated
  using (assignee_id = auth.uid() or reporter_id = auth.uid() or (project_id is not null and public.can_contribute_project(project_id)))
  with check (project_id is null or public.can_contribute_project(project_id) or assignee_id = auth.uid() or reporter_id = auth.uid());
create policy "tâches: suppression" on public.tasks for delete to authenticated
  using (reporter_id = auth.uid() or (project_id is not null and public.can_manage_project(project_id)));

create policy "dépendances: lecture" on public.task_dependencies for select to authenticated using (public.can_view_task(task_id));
create policy "dépendances: gestion" on public.task_dependencies for all to authenticated
  using (public.can_edit_task(task_id)) with check (public.can_edit_task(task_id) and public.can_view_task(depends_on_id));

create policy "commentaires: lecture" on public.task_comments for select to authenticated using (public.can_view_task(task_id));
create policy "commentaires: ajout" on public.task_comments for insert to authenticated
  with check (author_id = auth.uid() and public.can_view_task(task_id));
create policy "commentaires: suppression" on public.task_comments for delete to authenticated using (author_id = auth.uid());

-- -----------------------------------------------------------------------------
-- CRM
-- -----------------------------------------------------------------------------
create or replace function public.can_read_crm()
returns boolean language sql stable security definer set search_path = public as $$
  select public.has_perm('crm.view') or public.has_perm('crm.edit') or public.has_perm('crm.admin') or public.has_perm('dashboard.exec')
$$;

create policy "comptes: lecture"      on public.accounts for select to authenticated using (public.can_read_crm() or owner_id = auth.uid());
create policy "comptes: création"     on public.accounts for insert to authenticated with check (public.has_perm('crm.edit'));
create policy "comptes: modification" on public.accounts for update to authenticated
  using (public.has_perm('crm.edit') or owner_id = auth.uid()) with check (public.has_perm('crm.edit') or owner_id = auth.uid());
create policy "comptes: suppression"  on public.accounts for delete to authenticated using (public.has_perm('crm.admin'));

create policy "contacts: lecture"      on public.contacts for select to authenticated using (public.can_read_crm() or owner_id = auth.uid());
create policy "contacts: création"     on public.contacts for insert to authenticated with check (public.has_perm('crm.edit'));
create policy "contacts: modification" on public.contacts for update to authenticated
  using (public.has_perm('crm.edit') or owner_id = auth.uid()) with check (public.has_perm('crm.edit') or owner_id = auth.uid());
create policy "contacts: suppression"  on public.contacts for delete to authenticated using (public.has_perm('crm.admin') or owner_id = auth.uid());

create policy "opportunités: lecture"      on public.opportunities for select to authenticated using (public.can_read_crm() or owner_id = auth.uid());
create policy "opportunités: création"     on public.opportunities for insert to authenticated with check (public.has_perm('crm.edit'));
create policy "opportunités: modification" on public.opportunities for update to authenticated
  using (public.has_perm('crm.edit') or owner_id = auth.uid()) with check (public.has_perm('crm.edit') or owner_id = auth.uid());
create policy "opportunités: suppression"  on public.opportunities for delete to authenticated using (public.has_perm('crm.admin'));

create policy "interactions: lecture"  on public.interactions for select to authenticated using (public.can_read_crm() or author_id = auth.uid());
create policy "interactions: création" on public.interactions for insert to authenticated
  with check (author_id = auth.uid() and (public.has_perm('crm.edit') or public.has_perm('crm.view')));
create policy "interactions: modification" on public.interactions for update to authenticated
  using (author_id = auth.uid() or public.has_perm('crm.admin')) with check (author_id = auth.uid() or public.has_perm('crm.admin'));
create policy "interactions: suppression" on public.interactions for delete to authenticated
  using (author_id = auth.uid() or public.has_perm('crm.admin'));

-- -----------------------------------------------------------------------------
-- Finance
-- -----------------------------------------------------------------------------
create or replace function public.can_read_finance()
returns boolean language sql stable security definer set search_path = public as $$
  select public.has_perm('finance.view') or public.has_perm('finance.admin') or public.has_perm('dashboard.exec')
$$;

create policy "budgets: lecture" on public.budgets for select to authenticated
  using (public.can_read_finance() or public.has_perm('unit.manage', unit_id));
create policy "budgets: gestion" on public.budgets for all to authenticated
  using (public.has_perm('finance.admin')) with check (public.has_perm('finance.admin'));

create policy "factures: lecture" on public.invoices for select to authenticated using (public.can_read_finance());
create policy "factures: gestion" on public.invoices for all to authenticated
  using (public.has_perm('finance.admin')) with check (public.has_perm('finance.admin'));

create policy "lignes facture: lecture" on public.invoice_lines for select to authenticated using (public.can_read_finance());
create policy "lignes facture: gestion" on public.invoice_lines for all to authenticated
  using (public.has_perm('finance.admin')) with check (public.has_perm('finance.admin'));

create policy "transactions: lecture" on public.transactions for select to authenticated
  using (public.can_read_finance() or public.has_perm('unit.manage', unit_id));
create policy "transactions: gestion" on public.transactions for all to authenticated
  using (public.has_perm('finance.admin')) with check (public.has_perm('finance.admin'));

-- -----------------------------------------------------------------------------
-- RH
-- -----------------------------------------------------------------------------
create policy "contrats: lecture" on public.employment_contracts for select to authenticated
  using (profile_id = auth.uid() or public.has_perm('hr.view') or public.has_perm('hr.admin'));
create policy "contrats: gestion" on public.employment_contracts for all to authenticated
  using (public.has_perm('hr.admin')) with check (public.has_perm('hr.admin'));

create policy "salaires: lecture" on public.salaries for select to authenticated
  using (profile_id = auth.uid() or public.has_perm('hr.admin') or public.has_perm('finance.admin'));
create policy "salaires: gestion" on public.salaries for all to authenticated
  using (public.has_perm('hr.admin') or public.has_perm('finance.admin'))
  with check (public.has_perm('hr.admin') or public.has_perm('finance.admin'));

create policy "congés: lecture" on public.leave_requests for select to authenticated
  using (profile_id = auth.uid() or public.has_perm('hr.view') or public.has_perm('hr.admin') or public.manages_profile(profile_id));
create policy "congés: demande" on public.leave_requests for insert to authenticated
  with check (profile_id = auth.uid() and status = 'pending' and public.is_active_user());
create policy "congés: mise à jour" on public.leave_requests for update to authenticated
  using (profile_id = auth.uid() or public.has_perm('hr.admin') or public.manages_profile(profile_id))
  with check (profile_id = auth.uid() or public.has_perm('hr.admin') or public.manages_profile(profile_id));
create policy "congés: suppression" on public.leave_requests for delete to authenticated
  using (profile_id = auth.uid() and status = 'pending');

create policy "parcours: lecture" on public.lifecycle_items for select to authenticated
  using (profile_id = auth.uid() or assignee_id = auth.uid() or public.has_perm('hr.view') or public.has_perm('hr.admin') or public.manages_profile(profile_id));
create policy "parcours: gestion" on public.lifecycle_items for insert to authenticated
  with check (public.has_perm('hr.admin') or public.manages_profile(profile_id));
create policy "parcours: avancement" on public.lifecycle_items for update to authenticated
  using (profile_id = auth.uid() or assignee_id = auth.uid() or public.has_perm('hr.admin') or public.manages_profile(profile_id))
  with check (profile_id = auth.uid() or assignee_id = auth.uid() or public.has_perm('hr.admin') or public.manages_profile(profile_id));
create policy "parcours: suppression" on public.lifecycle_items for delete to authenticated
  using (public.has_perm('hr.admin') or public.manages_profile(profile_id));

-- -----------------------------------------------------------------------------
-- Documents
-- -----------------------------------------------------------------------------
create policy "documents: lecture" on public.documents for select to authenticated
  using (owner_id = auth.uid() or public.can_read_document(id));
create policy "documents: dépôt" on public.documents for insert to authenticated
  with check (public.is_active_user() and owner_id = auth.uid());
create policy "documents: modification" on public.documents for update to authenticated
  using (owner_id = auth.uid() or public.has_perm('docs.confidential') or public.has_perm('unit.manage', unit_id))
  with check (owner_id = auth.uid() or public.has_perm('docs.confidential') or public.has_perm('unit.manage', unit_id));
create policy "documents: suppression" on public.documents for delete to authenticated
  using (owner_id = auth.uid() or public.has_perm('docs.confidential') or public.is_admin());

-- -----------------------------------------------------------------------------
-- Objectifs & pilotage
-- -----------------------------------------------------------------------------
create policy "objectifs: lecture" on public.objectives for select to authenticated
  using (public.is_active_user() and (level in ('company', 'unit') or owner_id = auth.uid()
         or public.manages_profile(owner_id) or public.has_perm('hr.admin')));
create policy "objectifs: création" on public.objectives for insert to authenticated
  with check (
    (level = 'company'    and public.has_perm('objectives.admin'))
    or (level = 'unit'    and (public.has_perm('unit.manage', unit_id) or public.has_perm('objectives.admin')))
    or (level = 'individual' and (owner_id = auth.uid() or public.manages_profile(owner_id)))
  );
create policy "objectifs: modification" on public.objectives for update to authenticated
  using (public.can_edit_objective(id))
  with check (
    (level = 'company'    and public.has_perm('objectives.admin'))
    or (level = 'unit'    and (public.has_perm('unit.manage', unit_id) or public.has_perm('objectives.admin')))
    or (level = 'individual' and (owner_id = auth.uid() or public.manages_profile(owner_id)))
  );
create policy "objectifs: suppression" on public.objectives for delete to authenticated using (public.can_edit_objective(id));

create policy "résultats clés: lecture" on public.key_results for select to authenticated
  using (exists (select 1 from public.objectives o where o.id = objective_id));
create policy "résultats clés: gestion" on public.key_results for all to authenticated
  using (public.can_edit_objective(objective_id)) with check (public.can_edit_objective(objective_id));

create policy "kpi: lecture" on public.kpi_definitions for select to authenticated using (public.is_active_user());
create policy "kpi: gestion" on public.kpi_definitions for all to authenticated
  using (public.has_perm('dashboard.exec') or public.has_perm('objectives.admin'))
  with check (public.has_perm('dashboard.exec') or public.has_perm('objectives.admin'));

create policy "métriques: lecture" on public.product_metrics for select to authenticated
  using (public.has_perm('dashboard.exec') or public.has_perm('metrics.manage'));
create policy "métriques: gestion" on public.product_metrics for all to authenticated
  using (public.has_perm('metrics.manage')) with check (public.has_perm('metrics.manage'));

create policy "incidents: lecture"  on public.incidents for select to authenticated using (public.is_active_user());
create policy "incidents: signalement" on public.incidents for insert to authenticated
  with check (public.is_active_user() and reported_by = auth.uid());
create policy "incidents: suivi" on public.incidents for update to authenticated
  using (public.has_perm('metrics.manage') or reported_by = auth.uid() or public.has_perm('unit.manage', unit_id))
  with check (public.has_perm('metrics.manage') or reported_by = auth.uid() or public.has_perm('unit.manage', unit_id));
create policy "incidents: suppression" on public.incidents for delete to authenticated using (public.has_perm('metrics.manage'));

-- -----------------------------------------------------------------------------
-- Réunions
-- -----------------------------------------------------------------------------
create policy "réunions: lecture" on public.meetings for select to authenticated
  using (organizer_id = auth.uid() or public.is_meeting_participant(id)
         or (unit_id is not null and public.in_unit(unit_id))
         or (project_id is not null and public.can_view_project(project_id)));
create policy "réunions: création" on public.meetings for insert to authenticated
  with check (public.is_active_user() and organizer_id = auth.uid());
create policy "réunions: modification" on public.meetings for update to authenticated
  using (organizer_id = auth.uid() or public.is_admin()) with check (organizer_id = auth.uid() or public.is_admin());
create policy "réunions: suppression" on public.meetings for delete to authenticated
  using (organizer_id = auth.uid() or public.is_admin());

create policy "participants: lecture" on public.meeting_attendees for select to authenticated
  using (profile_id = auth.uid() or exists (select 1 from public.meetings m where m.id = meeting_id));
create policy "participants: invitation" on public.meeting_attendees for insert to authenticated
  with check (exists (select 1 from public.meetings m where m.id = meeting_id and m.organizer_id = auth.uid()));
create policy "participants: réponse" on public.meeting_attendees for update to authenticated
  using (profile_id = auth.uid()) with check (profile_id = auth.uid());
create policy "participants: retrait" on public.meeting_attendees for delete to authenticated
  using (exists (select 1 from public.meetings m where m.id = meeting_id and m.organizer_id = auth.uid()));
