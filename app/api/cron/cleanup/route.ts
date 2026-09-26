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
