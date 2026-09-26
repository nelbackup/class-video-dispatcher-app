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
