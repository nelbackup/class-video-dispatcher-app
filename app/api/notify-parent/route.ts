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
