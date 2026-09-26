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
    try {
      const res = await fetch('/api/students', { cache: 'no-store' });
      const data = await res.json();
      if (Array.isArray(data)) {
        setStudents(data);
      }
    } catch (err) {
      console.error('Failed to load roster:', err);
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

      setStatusMap((prev) => ({ ...prev, [studentId]: 'Delivered [OK]' }));
      await fetchRoster();
    } catch (err: any) {
      alert(`Error: ${err.message}`);
      setStatusMap((prev) => ({ ...prev, [studentId]: 'Failed' }));
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
          const isDone = currentStatus === 'Delivered [OK]';
          const isProcessing = currentStatus && !isDone && currentStatus !== 'Failed';
          const latestDispatch = student.video_dispatches?.[student.video_dispatches.length - 1];

          return (
            <div
              key={student.id}
              className="bg-white p-4 rounded-xl border border-slate-200 shadow-sm flex items-center justify-between transition"
            >
              <div>
                <p className="font-semibold text-slate-900 text-sm">{student.full_name}</p>
                <p className="text-xs text-slate-500">{student.class_code} - {student.parent_name}</p>
                
                <div className="mt-2 text-xs">
                  {currentStatus ? (
                    <span className={`font-semibold ${isDone ? 'text-emerald-600' : isProcessing ? 'text-amber-600 animate-pulse' : 'text-rose-600'}`}>
                      {currentStatus}
                    </span>
                  ) : latestDispatch ? (
                    latestDispatch.open_count > 0 ? (
                      <span className="text-sky-700 bg-sky-50 px-2 py-0.5 rounded font-medium">
                        Viewed by parent ({latestDispatch.open_count}x)
                      </span>
                    ) : (
                      <span className="text-amber-700 bg-amber-50 px-2 py-0.5 rounded font-medium">
                        Delivered - Unopened
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
