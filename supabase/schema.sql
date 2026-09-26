-- Storage: Bucket for video recordings (100% private)
insert into storage.buckets (id, name, public)
values ('interview-videos', 'interview-videos', false)
on conflict (id) do nothing;

-- Table: Students & Roster
create table if not exists public.students (
  id uuid primary key default gen_random_uuid(),
  full_name text not null,
  parent_name text not null,
  parent_email text not null,
  class_code text not null,
  created_at timestamptz default timezone('utc'::text, now()) not null
);

-- Table: Video Dispatches
create table if not exists public.video_dispatches (
  id uuid primary key default gen_random_uuid(),
  student_id uuid references public.students(id) on delete cascade not null,
  storage_path text not null,
  signed_url_expires_at timestamptz not null,
  email_status text default 'pending' not null,
  first_opened_at timestamptz,
  open_count integer default 0 not null,
  created_at timestamptz default timezone('utc'::text, now()) not null
);

-- Table: Access Logs
create table if not exists public.video_access_logs (
  id uuid primary key default gen_random_uuid(),
  dispatch_id uuid references public.video_dispatches(id) on delete cascade not null,
  ip_address text,
  user_agent text,
  accessed_at timestamptz default timezone('utc'::text, now()) not null
);

-- Optimization Indexes
create index if not exists idx_video_dispatches_created_at on public.video_dispatches(created_at);
create index if not exists idx_video_dispatches_student on public.video_dispatches(student_id);
create index if not exists idx_access_logs_dispatch on public.video_access_logs(dispatch_id);

-- Sample Data (Replace with your roster)
insert into public.students (full_name, parent_name, parent_email, class_code)
values 
  ('Lucas Chan', 'Mr. Chan', 'parent1@example.com', 'K1-INTERVIEW-A'),
  ('Emma Wong', 'Ms. Wong', 'parent2@example.com', 'K1-INTERVIEW-A'),
  ('Ethan Cheung', 'Mrs. Cheung', 'parent3@example.com', 'K1-INTERVIEW-A')
on conflict do nothing;
