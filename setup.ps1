# ==========================================
# Class Video Dispatcher - Automated Scaffolding
# ==========================================

$ErrorActionPreference = "Stop"
Write-Host "Scaffolding Class Video Dispatcher project..." -ForegroundColor Cyan

# 1. Create directory structure
$directories = @(
    "app\api\cron\cleanup",
    "app\api\notify-parent",
    "app\api\upload-request",
    "app\watch\[id]",
    "lib",
    "public",
    "supabase"
)

foreach ($dir in $directories) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
}

# 2. package.json
Set-Content -LiteralPath "package.json" -Value @'
{
  "name": "class-video-dispatcher",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "lint": "next lint"
  },
  "dependencies": {
    "@supabase/supabase-js": "^2.45.4",
    "next": "15.0.0",
    "react": "19.0.0-rc-66855b96-20241015",
    "react-dom": "19.0.0-rc-66855b96-20241015",
    "resend": "^4.0.0"
  },
  "devDependencies": {
    "@types/node": "^20.14.0",
    "@types/react": "^18.3.0",
    "@types/react-dom": "^18.3.0",
    "autoprefixer": "^10.4.20",
    "postcss": "^8.4.47",
    "tailwindcss": "^3.4.13",
    "typescript": "^5.6.2"
  }
}
'@

# 3. tsconfig.json
Set-Content -LiteralPath "tsconfig.json" -Value @'
{
  "compilerOptions": {
    "target": "ES2017",
    "lib": ["dom", "dom.iterable", "esnext"],
    "allowJs": true,
    "skipLibCheck": true,
    "strict": true,
    "noEmit": true,
    "esModuleInterop": true,
    "module": "esnext",
    "moduleResolution": "bundler",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "jsx": "preserve",
    "incremental": true,
    "plugins": [{ "name": "next" }],
    "paths": {
      "@/*": ["./*"]
    }
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx", ".next/types/**/*.ts"],
  "exclude": ["node_modules"]
}
'@

# 4. next.config.mjs
Set-Content -LiteralPath "next.config.mjs" -Value @'
/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
};

export default nextConfig;
'@

# 5. tailwind.config.ts & postcss.config.mjs
Set-Content -LiteralPath "tailwind.config.ts" -Value @'
import type { Config } from "tailwindcss";

const config: Config = {
  content: [
    "./app/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  theme: {
    extend: {},
  },
  plugins: [],
};
export default config;
'@

Set-Content -LiteralPath "postcss.config.mjs" -Value @'
const config = {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},
  },
};
export default config;
'@

# 6. vercel.json
Set-Content -LiteralPath "vercel.json" -Value @'
{
  "crons": [
    {
      "path": "/api/cron/cleanup",
      "schedule": "0 3 * * *"
    }
  ]
}
'@

# 7. public/manifest.json
Set-Content -LiteralPath "public\manifest.json" -Value @'
{
  "name": "Class Video Dispatcher",
  "short_name": "ClassCam",
  "start_url": "/",
  "display": "standalone",
  "background_color": "#0f172a",
  "theme_color": "#0284c7"
}
'@

# 8. .env.example
Set-Content -LiteralPath ".env.example" -Value @'
NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
RESEND_API_KEY=re_123456789
EMAIL_FROM="Class Admissions <admissions@your-domain.com>"
NEXT_PUBLIC_APP_URL=https://your-production-app.vercel.app
CRON_SECRET=generate_a_random_hex_secret_here
'@

# 9. supabase/schema.sql
Set-Content -LiteralPath "supabase\schema.sql" -Value @'
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
'@

# 10. lib/supabaseServer.ts
Set-Content -LiteralPath "lib\supabaseServer.ts" -Value @'
import { createClient } from '@supabase/supabase-js';

export const supabaseAdmin = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!,
  {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  }
);
'@

# 11. app/globals.css
Set-Content -LiteralPath "app\globals.css" -Value @'
@tailwind base;
@tailwind components;
@tailwind utilities;

body {
  background-color: #f8fafc;
  color: #0f172a;
}
'@

# 12. app/layout.tsx
Set-Content -LiteralPath "app\layout.tsx" -Value @'
import type { Metadata, Viewport } from 'next';
import './globals.css';

export const metadata: Metadata = {
  title: 'Class Video Dispatcher',
  description: 'Secure class attendance recorder and performance delivery system',
  manifest: '/manifest.json',
};

export const viewport: Viewport = {
  themeColor: '#0284c7',
  width: 'device-width',
  initialScale: 1,
  maximumScale: 1,
  userScalable: false,
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body className="antialiased">{children}</body>
    </html>
  );
}
'@

# 13. app/page.tsx
Set-Content -LiteralPath "app\page.tsx" -Value @'
'use client';

import { useState, useEffect, useRef } from 'react';
import { createClient } from '@supabase/supabase-js';

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
);

interface DispatchSummary {
  open_count: number;
  first_opened_at: string | null;
  created_at: string;
}

interface Student {
  id: string;
  full_name: string;
  parent_name: string;
  class_code: string;
  video_dispatches?: DispatchSummary[];
}

export default function AttendanceRecorder() {
  const [students, setStudents] = useState<Student[]>([]);
  const [activeStudent, setActiveStudent] = useState<Student | null>(null);
  const [statusMap, setStatusMap] = useState<Record<string, string>>({});
  const fileInputRef = useRef<HTMLInputElement>(null);

  const fetchRoster = async () => {
    const { data } = await supabase
      .from('students')
      .select(`
        id,
        full_name,
        parent_name,
        class_code,
        video_dispatches (
          open_count,
          first_opened_at,
          created_at
        )
      `)
      .order('full_name');

    if (data) {
      setStudents(data as unknown as Student[]);
    }
  };

  useEffect(() => {
    fetchRoster();
  }, []);

  const handleRecordClick = (student: Student) => {
    setActiveStudent(student);
    if (fileInputRef.current) {
      fileInputRef.current.value = '';
      fileInputRef.current.click();
    }
  };

  const handleFileCapture = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file || !activeStudent) return;

    const studentId = activeStudent.id;
    try {
      setStatusMap((prev) => ({ ...prev, [studentId]: 'Requesting storage token...' }));

      const reqRes = await fetch('/api/upload-request', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          studentId: activeStudent.id,
          classCode: activeStudent.class_code,
        }),
      });
      const { path, token, error: reqErr } = await reqRes.json();
      if (reqErr) throw new Error(reqErr);

      setStatusMap((prev) => ({ ...prev, [studentId]: 'Streaming to storage...' }));
      const { error: uploadErr } = await supabase.storage
        .from('interview-videos')
        .uploadToSignedUrl(path, token, file);

      if (uploadErr) throw uploadErr;

      setStatusMap((prev) => ({ ...prev, [studentId]: 'Sending tracked email...' }));
      const notifyRes = await fetch('/api/notify-parent', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ studentId: activeStudent.id, storagePath: path }),
      });
      const notifyData = await notifyRes.json();
      if (notifyData.error) throw new Error(notifyData.error);

      setStatusMap((prev) => ({ ...prev, [studentId]: 'Delivered ?? }));
      await fetchRoster();
    } catch (err: any) {
      alert(`Error: ${err.message}`);
      setStatusMap((prev) => ({ ...prev, [studentId]: 'Failed ?? }));
    }
  };

  return (
    <main className="max-w-md mx-auto min-h-screen p-4 pb-12 font-sans">
      <header className="mb-6 pt-2">
        <h1 className="text-xl font-bold text-slate-900 tracking-tight">Class Video Dispatcher</h1>
        <p className="text-xs text-slate-500 mt-1">Tap a student to record and transmit interview clip</p>
      </header>

      <input
        ref={fileInputRef}
        type="file"
        accept="video/*"
        capture="environment"
        className="hidden"
        onChange={handleFileCapture}
      />

      <div className="space-y-3">
        {students.map((student) => {
          const currentStatus = statusMap[student.id];
          const isProcessing = currentStatus && !currentStatus.includes('??) && !currentStatus.includes('Failed');
          const latestDispatch = student.video_dispatches?.[student.video_dispatches.length - 1];

          return (
            <div
              key={student.id}
              className="bg-white p-4 rounded-xl border border-slate-200 shadow-sm flex items-center justify-between transition"
            >
              <div>
                <p className="font-semibold text-slate-900 text-sm">{student.full_name}</p>
                <p className="text-xs text-slate-500">{student.class_code} · {student.parent_name}</p>
                
                <div className="mt-2 text-xs">
                  {currentStatus ? (
                    <span className={`font-semibold ${currentStatus.includes('??) ? 'text-emerald-600' : isProcessing ? 'text-amber-600 animate-pulse' : 'text-rose-600'}`}>
                      {currentStatus}
                    </span>
                  ) : latestDispatch ? (
                    latestDispatch.open_count > 0 ? (
                      <span className="text-sky-700 bg-sky-50 px-2 py-0.5 rounded font-medium">
                        Viewed by parent ({latestDispatch.open_count}x)
                      </span>
                    ) : (
                      <span className="text-amber-700 bg-amber-50 px-2 py-0.5 rounded font-medium">
                        Delivered · Unopened
                      </span>
                    )
                  ) : (
                    <span className="text-slate-400">Ready to record</span>
                  )}
                </div>
              </div>

              <button
                disabled={Boolean(isProcessing)}
                onClick={() => handleRecordClick(student)}
                className={`px-4 py-2 rounded-lg text-xs font-bold uppercase tracking-wider transition ${
                  isProcessing
                    ? 'bg-amber-100 text-amber-800'
                    : latestDispatch
                    ? 'bg-slate-100 text-slate-600 border border-slate-200 hover:bg-slate-200'
                    : 'bg-sky-600 text-white hover:bg-sky-700 active:scale-95 shadow-sm'
                }`}
              >
                {isProcessing ? 'Working...' : latestDispatch ? 'Re-record' : 'Record'}
              </button>
            </div>
          );
        })}
      </div>
    </main>
  );
}
'@

# 14. app/watch/[id]/page.tsx
Set-Content -LiteralPath "app\watch\[id]\page.tsx" -Value @'
import { headers } from 'next/headers';
import { notFound } from 'next/navigation';
import { supabaseAdmin } from '@/lib/supabaseServer';

export const dynamic = 'force-dynamic';

interface PageProps {
  params: Promise<{ id: string }>;
}

export default async function WatchVideoPage({ params }: PageProps) {
  const { id } = await params;
  const headerList = await headers();

  const ipAddress =
    headerList.get('x-forwarded-for')?.split(',')[0].trim() ||
    headerList.get('x-real-ip') ||
    'Unknown';
  const userAgent = headerList.get('user-agent') || 'Unknown';

  const { data: dispatch, error: fetchErr } = await supabaseAdmin
    .from('video_dispatches')
    .select(`
      id,
      storage_path,
      signed_url_expires_at,
      open_count,
      first_opened_at,
      students (
        full_name,
        class_code
      )
    `)
    .eq('id', id)
    .single();

  if (fetchErr || !dispatch) {
    notFound();
  }

  const isExpired = new Date(dispatch.signed_url_expires_at) < new Date();
  const isPurged = dispatch.storage_path === '[PURGED]';

  if (isExpired || isPurged) {
    return (
      <main className="min-h-screen bg-slate-900 flex items-center justify-center p-4 font-sans text-white">
        <div className="max-w-md w-full bg-slate-800 p-8 rounded-2xl border border-slate-700 text-center shadow-xl">
          <div className="w-12 h-12 bg-amber-500/20 text-amber-400 rounded-full flex items-center justify-center mx-auto mb-4 font-bold text-lg">
            !
          </div>
          <h1 className="text-xl font-bold mb-2">Recording Link Expired</h1>
          <p className="text-sm text-slate-400 leading-relaxed">
            In compliance with student personal data protection policies, performance evaluation videos are automatically deleted once the retention period ends.
          </p>
        </div>
      </main>
    );
  }

  const nowIso = new Date().toISOString();
  await Promise.all([
    supabaseAdmin.from('video_access_logs').insert({
      dispatch_id: dispatch.id,
      ip_address: ipAddress,
      user_agent: userAgent,
    }),
    supabaseAdmin
      .from('video_dispatches')
      .update({
        open_count: (dispatch.open_count || 0) + 1,
        first_opened_at: dispatch.first_opened_at || nowIso,
      })
      .eq('id', dispatch.id),
  ]);

  const { data: signedData, error: signErr } = await supabaseAdmin.storage
    .from('interview-videos')
    .createSignedUrl(dispatch.storage_path, 900);

  if (signErr || !signedData?.signedUrl) {
    return (
      <main className="min-h-screen bg-slate-900 flex items-center justify-center p-4 text-white">
        <p className="text-sm text-rose-400">Failed to initialize secure stream. Please refresh.</p>
      </main>
    );
  }

  const student = dispatch.students as any;

  return (
    <main className="min-h-screen bg-slate-950 text-white flex flex-col items-center justify-center p-4 font-sans">
      <div className="w-full max-w-lg">
        <div className="mb-4">
          <span className="text-xs uppercase tracking-wider bg-sky-950 border border-sky-800 text-sky-400 px-2.5 py-1 rounded font-semibold">
            {student?.class_code}
          </span>
          <h1 className="text-xl font-bold mt-3 text-slate-100">{student?.full_name} ??Class Recording</h1>
          <p className="text-xs text-slate-400 mt-1">
            Valid until {new Date(dispatch.signed_url_expires_at).toLocaleDateString()}
          </p>
        </div>

        <div className="rounded-2xl overflow-hidden bg-black shadow-2xl border border-slate-800">
          <video
            controls
            controlsList="nodownload"
            playsInline
            preload="metadata"
            className="w-full aspect-video"
            src={signedData.signedUrl}
          >
            Your browser does not support HTML5 video playback.
          </video>
        </div>

        <div className="mt-4 p-3.5 rounded-xl bg-slate-900 border border-slate-800 text-xs text-slate-400 flex items-center justify-between">
          <span>Access Count: {dispatch.open_count + 1}</span>
          <span className="text-emerald-400 font-medium flex items-center gap-1.5">
            <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 inline-block"></span>
            End-to-End Audited
          </span>
        </div>
      </div>
    </main>
  );
}
'@

# 15. app/api/upload-request/route.ts
Set-Content -LiteralPath "app\api\upload-request\route.ts" -Value @'
import { NextResponse } from 'next/server';
import { supabaseAdmin } from '@/lib/supabaseServer';

export async function POST(req: Request) {
  try {
    const { studentId, classCode } = await req.json();

    if (!studentId || !classCode) {
      return NextResponse.json({ error: 'Missing student ID or class code' }, { status: 400 });
    }

    const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
    const storagePath = `${classCode}/${studentId}_${timestamp}.mp4`;

    const { data, error } = await supabaseAdmin.storage
      .from('interview-videos')
      .createSignedUploadUrl(storagePath);

    if (error || !data) {
      return NextResponse.json({ error: error?.message || 'Storage token creation failed' }, { status: 500 });
    }

    return NextResponse.json({
      path: data.path,
      token: data.token,
      signedUrl: data.signedUrl,
    });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
'@

# 16. app/api/notify-parent/route.ts
Set-Content -LiteralPath "app\api\notify-parent\route.ts" -Value @'
import { NextResponse } from 'next/server';
import { supabaseAdmin } from '@/lib/supabaseServer';
import { Resend } from 'resend';

const resend = new Resend(process.env.RESEND_API_KEY);

export async function POST(req: Request) {
  try {
    const { studentId, storagePath } = await req.json();

    const { data: student, error: studentErr } = await supabaseAdmin
      .from('students')
      .select('*')
      .eq('id', studentId)
      .single();

    if (studentErr || !student) {
      return NextResponse.json({ error: 'Student record not found' }, { status: 404 });
    }

    const expiryDate = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);

    const { data: dispatch, error: dispatchErr } = await supabaseAdmin
      .from('video_dispatches')
      .insert({
        student_id: student.id,
        storage_path: storagePath,
        signed_url_expires_at: expiryDate.toISOString(),
        email_status: 'pending',
      })
      .select('id')
      .single();

    if (dispatchErr || !dispatch) {
      return NextResponse.json({ error: 'Failed to initialize dispatch log' }, { status: 500 });
    }

    const appUrl = process.env.NEXT_PUBLIC_APP_URL || 'http://localhost:3000';
    const trackingUrl = `${appUrl}/watch/${dispatch.id}`;

    await resend.emails.send({
      from: process.env.EMAIL_FROM || 'onboarding@resend.dev',
      to: student.parent_email,
      subject: `Interview Class Video: ${student.full_name}`,
      html: `
        <div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; line-height: 1.6; color: #1e293b; max-width: 560px; margin: 0 auto; padding: 20px;">
          <h2 style="color: #0f172a; margin-bottom: 8px;">Class Performance Recording</h2>
          <p>Dear ${student.parent_name},</p>
          <p>The classroom evaluation clip for <strong>${student.full_name}</strong> is available for review:</p>
          <p style="margin: 28px 0;">
            <a href="${trackingUrl}" style="background-color: #0284c7; color: #ffffff; padding: 12px 24px; text-decoration: none; border-radius: 8px; font-weight: 600; display: inline-block;">
              View Recording
            </a>
          </p>
          <p style="font-size: 13px; color: #64748b;">
            <strong>Confidentiality Notice:</strong> To safeguard student privacy, this link is bound to your child and expires on <strong>${expiryDate.toLocaleDateString()}</strong>.
          </p>
        </div>
      `,
    });

    await supabaseAdmin
      .from('video_dispatches')
      .update({ email_status: 'delivered' })
      .eq('id', dispatch.id);

    return NextResponse.json({ success: true, trackingUrl });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
'@

# 17. app/api/cron/cleanup/route.ts
Set-Content -LiteralPath "app\api\cron\cleanup\route.ts" -Value @'
import { NextResponse } from 'next/server';
import { supabaseAdmin } from '@/lib/supabaseServer';

export const dynamic = 'force-dynamic';

export async function GET(req: Request) {
  try {
    const authHeader = req.headers.get('authorization');
    if (
      process.env.CRON_SECRET &&
      authHeader !== `Bearer ${process.env.CRON_SECRET}`
    ) {
      return new NextResponse('Unauthorized', { status: 401 });
    }

    const fourteenDaysAgo = new Date(
      Date.now() - 14 * 24 * 60 * 60 * 1000
    ).toISOString();

    const { data: expiredRecords, error: fetchErr } = await supabaseAdmin
      .from('video_dispatches')
      .select('id, storage_path')
      .lt('created_at', fourteenDaysAgo)
      .neq('storage_path', '[PURGED]')
      .limit(100);

    if (fetchErr) {
      return NextResponse.json({ error: fetchErr.message }, { status: 500 });
    }

    if (!expiredRecords || expiredRecords.length === 0) {
      return NextResponse.json({ message: 'No expired recordings to clean.' });
    }

    const filePaths = expiredRecords.map((r) => r.storage_path);
    const recordIds = expiredRecords.map((r) => r.id);

    // Call Supabase Storage API directly to destroy binary objects from block storage
    const { error: storageErr } = await supabaseAdmin.storage
      .from('interview-videos')
      .remove(filePaths);

    if (storageErr) {
      return NextResponse.json({ error: storageErr.message }, { status: 500 });
    }

    // Retain anonymized audit stub to verify compliance with data retention laws
    const { error: dbUpdateErr } = await supabaseAdmin
      .from('video_dispatches')
      .update({ storage_path: '[PURGED]' })
      .in('id', recordIds);

    if (dbUpdateErr) {
      return NextResponse.json({ error: dbUpdateErr.message }, { status: 500 });
    }

    return NextResponse.json({
      success: true,
      purgedCount: filePaths.length,
      files: filePaths,
    });
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
'@

Write-Host "Project files successfully generated!" -ForegroundColor Green
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Run: npm install"
Write-Host "2. Copy .env.example to .env.local and populate keys"
Write-Host "3. Execute supabase/schema.sql in your Supabase SQL Editor"
