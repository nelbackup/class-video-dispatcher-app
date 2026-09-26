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
