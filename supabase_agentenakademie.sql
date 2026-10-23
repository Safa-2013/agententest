-- S.G.D. Agentenakademie: cloud users, results, activities and questions.
-- Run in a NEW Supabase project. Do not run in an existing unrelated project.
-- Uses Supabase Auth email/password (passwords never stored in public tables).

create schema if not exists sgd_private;
revoke all on schema sgd_private from public;

drop function if exists public.sgd_set_agent_access(uuid,text,text[],boolean);

create table if not exists public.sgd_profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 username text not null unique check (username ~ '^[a-z0-9._-]{3,24}$'),
 display_name text not null check (char_length(display_name) between 1 and 60),
 alias text not null check (char_length(alias) between 1 and 35),
 group_name text not null default '',
 role text not null default 'student' check (role in ('student','agent','employee','customer','admin')),
 permissions text[] not null default '{}',
 disabled boolean not null default false,
 created_at timestamptz not null default now(),
 promoted_at timestamptz
);

create table if not exists public.sgd_results (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references auth.users(id) on delete cascade,
 alias text not null default 'Agent',
 points int not null check (points between 0 and 24),
 duration int not null check (duration between 0 and 86400),
 success boolean not null,
 mode text not null check (mode in ('end','easy','escape','complete','theory')),
 created_at timestamptz not null default now()
);
create index if not exists sgd_results_user_created_idx on public.sgd_results(user_id,created_at desc);

create table if not exists public.sgd_activity (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references auth.users(id) on delete cascade,
 action text not null check (char_length(action)<=65),
 target text not null default '' check (char_length(target)<=120),
 detail text not null default '' check (char_length(detail)<=300),
 created_at timestamptz not null default now()
);
create index if not exists sgd_activity_created_idx on public.sgd_activity(created_at desc);
create index if not exists sgd_activity_user_idx on public.sgd_activity(user_id,created_at desc);

create table if not exists public.sgd_questions (
 id bigint primary key,
 created_by uuid not null references auth.users(id),
 title text not null,
 category text not null,
 story text not null,
 question text not null,
 answers text[] not null check (array_length(answers,1)=4),
 correct smallint not null check (correct between 0 and 3),
 explanation text not null default '',
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);

create table if not exists public.sgd_solution_overrides (
 question_id bigint primary key,
 correct smallint not null check (correct between 0 and 3),
 changed_by uuid not null references auth.users(id),
 updated_at timestamptz not null default now()
);

create or replace function sgd_private.is_admin() returns boolean
language sql stable security definer set search_path = '' as $$
 select exists(select 1 from public.sgd_profiles where id=(select auth.uid()) and role='admin' and not disabled)
$$;
create or replace function sgd_private.can_do(p text) returns boolean
language sql stable security definer set search_path = '' as $$
 select exists(select 1 from public.sgd_profiles where id=(select auth.uid()) and not disabled
 and (role='admin' or p=any(permissions)))
$$;
revoke all on function sgd_private.is_admin() from public;
revoke all on function sgd_private.can_do(text) from public;
grant usage on schema sgd_private to authenticated;
grant execute on function sgd_private.is_admin() to authenticated;
grant execute on function sgd_private.can_do(text) to authenticated;

create or replace function sgd_private.new_agent_profile() returns trigger
language plpgsql security definer set search_path = '' as $$
declare u text; disp text; a text; g text;
begin
 u:=lower(coalesce(new.raw_user_meta_data->>'username',''));
 if u !~ '^[a-z0-9._-]{3,24}$' then raise exception 'Ungültiger Benutzername'; end if;
 disp:=left(coalesce(nullif(trim(new.raw_user_meta_data->>'displayName'),''),u),60);
 a:=left(coalesce(nullif(trim(new.raw_user_meta_data->>'alias'),''),u),35);
 g:=left(coalesce(new.raw_user_meta_data->>'group',''),25);
 insert into public.sgd_profiles(id,username,display_name,alias,group_name)
 values(new.id,u,disp,a,g);
 return new;
end $$;
drop trigger if exists sgd_new_auth_user on auth.users;
create trigger sgd_new_auth_user after insert on auth.users
for each row execute procedure sgd_private.new_agent_profile();

create or replace function sgd_private.after_exam() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
 -- This is a role update based on a client-reported result, NOT independently verified exam integrity.
 if new.success and new.mode <> 'escape' then
  update public.sgd_profiles set role='agent',promoted_at=now()
  where id=new.user_id and role='student';
 end if;
 return new;
end $$;
drop trigger if exists sgd_exam_promotion on public.sgd_results;
create trigger sgd_exam_promotion after insert on public.sgd_results
for each row execute procedure sgd_private.after_exam();

create or replace function public.sgd_set_agent_access(
 target_id uuid, next_role text, next_permissions text[], next_disabled boolean
) returns void language plpgsql security definer set search_path = '' as $$
declare caller_id uuid := (select auth.uid());
begin
 if caller_id is null or not (select sgd_private.is_admin()) then
  raise exception 'Nur Admins können Rechte ändern';
 end if;
 if target_id=caller_id then raise exception 'Eigene Adminrechte nicht hier ändern'; end if;
 if next_role not in ('student','agent','employee','customer','admin') then
  raise exception 'Ungültige Rolle'; end if;
 if exists(select 1 from unnest(coalesce(next_permissions,'{}'::text[])) v
   where v not in ('view_accounts','manage_accounts','issue_cards','manage_cards','view_questions','edit_questions','edit_solutions','edit_missions','view_results','export_data'))
 then raise exception 'Ungültige Berechtigung'; end if;
 update public.sgd_profiles set role=next_role,permissions=coalesce(next_permissions,'{}'::text[]),disabled=next_disabled
 where id=target_id;
 if not found then raise exception 'Konto nicht gefunden'; end if;
 insert into public.sgd_activity(user_id,action,target,detail)
 values(caller_id,'Kontorechte geändert',target_id::text, next_role || ' · Rechte: ' || array_to_string(next_permissions,', '));
end $$;
revoke execute on function public.sgd_set_agent_access(uuid,text,text[],boolean) from public,anon;
grant execute on function public.sgd_set_agent_access(uuid,text,text[],boolean) to authenticated;

alter table public.sgd_profiles enable row level security;
alter table public.sgd_results enable row level security;
alter table public.sgd_activity enable row level security;
alter table public.sgd_questions enable row level security;
alter table public.sgd_solution_overrides enable row level security;

drop policy if exists "sgd_profile_select" on public.sgd_profiles;
create policy "sgd_profile_select" on public.sgd_profiles for select to authenticated
using (id=(select auth.uid()) or (select sgd_private.can_do('view_accounts')));
drop policy if exists "sgd_profile_update_own" on public.sgd_profiles;
create policy "sgd_profile_update_own" on public.sgd_profiles for update to authenticated
using(id=(select auth.uid()) or (select sgd_private.can_do('manage_accounts'))) with check(id=(select auth.uid()) or (select sgd_private.can_do('manage_accounts')));

drop policy if exists "sgd_result_select" on public.sgd_results;
create policy "sgd_result_select" on public.sgd_results for select to authenticated
using (user_id=(select auth.uid()) or (select sgd_private.can_do('view_results')));
drop policy if exists "sgd_result_insert" on public.sgd_results;
create policy "sgd_result_insert" on public.sgd_results for insert to authenticated
with check (user_id=(select auth.uid()) and (select exists(select 1 from public.sgd_profiles where id=(select auth.uid()) and not disabled)));

drop policy if exists "sgd_activity_select" on public.sgd_activity;
create policy "sgd_activity_select" on public.sgd_activity for select to authenticated
using(user_id=(select auth.uid()) or (select sgd_private.is_admin()));
drop policy if exists "sgd_activity_insert" on public.sgd_activity;
create policy "sgd_activity_insert" on public.sgd_activity for insert to authenticated
with check(user_id=(select auth.uid()));

drop policy if exists "sgd_questions_read" on public.sgd_questions;
create policy "sgd_questions_read" on public.sgd_questions for select to authenticated using (true);
drop policy if exists "sgd_questions_insert" on public.sgd_questions;
create policy "sgd_questions_insert" on public.sgd_questions for insert to authenticated
with check (created_by=(select auth.uid()) and (select sgd_private.can_do('edit_questions')));
drop policy if exists "sgd_questions_update" on public.sgd_questions;
create policy "sgd_questions_update" on public.sgd_questions for update to authenticated
using((select sgd_private.can_do('edit_questions'))) with check((select sgd_private.can_do('edit_questions')));
drop policy if exists "sgd_questions_delete" on public.sgd_questions;
create policy "sgd_questions_delete" on public.sgd_questions for delete to authenticated
using((select sgd_private.can_do('edit_questions')));

drop policy if exists "sgd_solutions_read" on public.sgd_solution_overrides;
create policy "sgd_solutions_read" on public.sgd_solution_overrides for select to authenticated using(true);
drop policy if exists "sgd_solutions_insert" on public.sgd_solution_overrides;
create policy "sgd_solutions_insert" on public.sgd_solution_overrides for insert to authenticated
with check(changed_by=(select auth.uid()) and (select sgd_private.can_do('edit_solutions')));
drop policy if exists "sgd_solutions_update" on public.sgd_solution_overrides;
create policy "sgd_solutions_update" on public.sgd_solution_overrides for update to authenticated
using((select sgd_private.can_do('edit_solutions'))) with check((select sgd_private.can_do('edit_solutions')));

-- Trusted server records for creations/changes/deletions of questions and answer keys.
create or replace function sgd_private.audit_learning_changes() returns trigger
language plpgsql security definer set search_path = '' as $$
declare actor uuid := (select auth.uid()); label text; reference text;
begin
 if actor is null then return coalesce(new,old); end if;
 if tg_table_name='sgd_questions' then
   reference:='#' || coalesce(new.id,old.id)::text;
   label:=case tg_op when 'INSERT' then 'Frage erstellt (Server)' when 'UPDATE' then 'Frage geändert (Server)' else 'Frage gelöscht (Server)' end;
 else
   reference:='#' || coalesce(new.question_id,old.question_id)::text;
   label:='Lösung geändert (Server)';
 end if;
 insert into public.sgd_activity(user_id,action,target,detail)
 values(actor,label,reference,'Änderung durch authentifiziertes Konto bestätigt');
 return coalesce(new,old);
end $$;
drop trigger if exists sgd_audit_questions on public.sgd_questions;
create trigger sgd_audit_questions after insert or update or delete on public.sgd_questions
for each row execute procedure sgd_private.audit_learning_changes();
drop trigger if exists sgd_audit_solutions on public.sgd_solution_overrides;
create trigger sgd_audit_solutions after insert or update on public.sgd_solution_overrides
for each row execute procedure sgd_private.audit_learning_changes();

-- Supabase Data API opt-in (October 2026 change): explicit grants plus RLS.
revoke all on public.sgd_profiles,public.sgd_results,public.sgd_activity,public.sgd_questions,public.sgd_solution_overrides from anon;
grant select on public.sgd_profiles to authenticated;
grant update(display_name,alias,group_name) on public.sgd_profiles to authenticated;
grant select,insert on public.sgd_results to authenticated;
grant select,insert on public.sgd_activity to authenticated;
grant select,insert,update,delete on public.sgd_questions to authenticated;
grant select,insert,update on public.sgd_solution_overrides to authenticated;

-- IMPORTANT: After creating your first ONLINE user with username safa, run this manually ONCE
-- in the NEW project's SQL editor, then remove this instruction from any public repo:
-- UPDATE public.sgd_profiles SET role='admin' WHERE username='safa';
-- This prevents public sign-up from claiming admin rights.
