-- CareAid schema. Mirrors CLAUDE.md §6.
--
-- All data in this database is synthetic. There is no real patient data here
-- and there never will be — see CLAUDE.md §2, rule 2.

create extension if not exists pgcrypto;

create table if not exists recipient (
  id uuid primary key default gen_random_uuid(),
  display_name text not null,           -- "Mum"
  legal_name text, year_of_birth int,
  conditions text[] default '{}', allergies text[] default '{}',
  gp_practice text, created_at timestamptz default now()
);

create table if not exists caregiver (
  id uuid primary key default gen_random_uuid(),
  name text not null, relation text,
  work_hours jsonb default '{}'::jsonb,  -- caregiver-first: availability constraints
  created_at timestamptz default now()
);

create table if not exists circle_member (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid references recipient(id),
  name text not null, relation text,
  channel text check (channel in ('whatsapp','sms','email')),
  handle text,
  share_level text check (share_level in ('headline','summary','full')) default 'summary'
);

create table if not exists medication (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid references recipient(id),
  name text not null, rxcui text, dose text,
  schedule text,                         -- "4x daily: 8am, 12pm, 4pm, 8pm"
  scheduled_times time[] default '{}',
  quantity_remaining int,
  started_on date, active boolean default true
);

create table if not exists capture (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid references recipient(id),
  author_id uuid references caregiver(id),
  source text check (source in ('voice','photo','text')) not null,
  raw_text text, media_url text,
  captured_at timestamptz default now(), processed_at timestamptz,
  model_raw jsonb
);

create table if not exists timeline_event (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid references recipient(id),
  capture_id uuid references capture(id),
  kind text check (kind in ('symptom','medication','incident','appointment','mood','care_task','admin')),
  occurred_at timestamptz not null,
  headline text not null,                -- <=60 chars, plain language
  detail text,
  severity int check (severity between 0 and 3) default 0,
  tags text[] default '{}', confidence numeric
);

create table if not exists artifact (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid references recipient(id),
  capture_id uuid references capture(id),
  kind text check (kind in ('task','calendar_event','family_update','question','timer','medication_update')),
  payload jsonb not null,
  status text check (status in ('proposed','approved','dismissed','done','sent')) default 'proposed',
  confidence numeric,
  created_at timestamptz default now(), actioned_at timestamptz
);

create table if not exists brief (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid references recipient(id),
  version int not null, content jsonb not null,
  generated_at timestamptz default now(),
  source_capture_id uuid references capture(id)
);

-- Indexes. Not in §6, but every read path in the app is "this recipient,
-- newest first", and §7 injects 90 days of headlines on every capture.
create index if not exists timeline_event_recipient_occurred_idx
  on timeline_event (recipient_id, occurred_at desc);
create index if not exists artifact_recipient_status_idx
  on artifact (recipient_id, status);
create index if not exists artifact_capture_idx
  on artifact (capture_id);
create index if not exists timeline_event_capture_idx
  on timeline_event (capture_id);
create index if not exists brief_recipient_version_idx
  on brief (recipient_id, version desc);

-- RLS stays off: one hardcoded demo user, no auth, and every row is synthetic
-- (CLAUDE.md §3 and §6). Stated explicitly so a project template that enables
-- RLS by default cannot silently make the anon key read nothing.
--
-- This is safe *only* because the contents are invented. The moment anything
-- real lands here, this block must go and policies must replace it.
alter table recipient      disable row level security;
alter table caregiver      disable row level security;
alter table circle_member  disable row level security;
alter table medication     disable row level security;
alter table capture        disable row level security;
alter table timeline_event disable row level security;
alter table artifact       disable row level security;
alter table brief          disable row level security;
