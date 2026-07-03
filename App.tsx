import { useState, useEffect, useRef } from "react";
import type React from "react";
import { createClient } from "@supabase/supabase-js";
import type { Session } from "@supabase/supabase-js";
import { toPng } from "html-to-image";

// ── Supabase client ───────────────────────────────────────────────────────────
const supabase = createClient(
  import.meta.env.VITE_SUPABASE_URL as string,
  import.meta.env.VITE_SUPABASE_ANON_KEY as string
);
const todayKey = new Date().toISOString().split("T")[0];
const todayStr = new Date().toLocaleDateString("en-GB", {
  weekday: "long", day: "numeric", month: "long", year: "numeric",
});

// Only this email sees the admin "resolve pending bird" panel
const ADMIN_EMAIL = "paul_catt35@yahoo.co.uk";

// ── Bird types ─────────────────────────────────────────────────────────────────
// Real birds now load from Supabase (`birds` table) instead of birds.ts.
// Each bird carries its own image/description/fact — no separate lookup tables.
type Bird = {
  id: string; name: string; latin: string; color: string;
  imageUrl: string; description: string; fact: string; facingRight: boolean;
};
type PendingBird = { id: string; name: string; isPending: true; resolvedTo?: string; color: string };
type AnyBird = Bird | PendingBird;
const isPending = (b: AnyBird): b is PendingBird => "isPending" in b;

// ── Streak utilities ──────────────────────────────────────────────────────────
function subtractDays(dateStr: string, n: number): string {
  const d = new Date(dateStr + "T12:00:00");
  d.setDate(d.getDate() - n);
  return d.toISOString().split("T")[0];
}
function calculateStreak(loggedDates: Set<string>): number {
  const today = new Date().toISOString().split("T")[0];
  let start = loggedDates.has(today) ? today : subtractDays(today, 1);
  if (!loggedDates.has(start)) return 0;
  let count = 0; let cur = start;
  while (loggedDates.has(cur)) { count++; cur = subtractDays(cur, 1); }
  return count;
}

// ── Image resize helper (matches existing manual workflow: 600px max, ~82% JPEG) ─
function resizeImage(file: File, maxDim = 600, quality = 0.82): Promise<Blob> {
  return new Promise((resolve, reject) => {
    const img = new Image();
    const url = URL.createObjectURL(file);
    img.onload = () => {
      URL.revokeObjectURL(url);
      let { width, height } = img;
      if (width > height && width > maxDim) { height = Math.round(height * (maxDim / width)); width = maxDim; }
      else if (height > maxDim) { width = Math.round(width * (maxDim / height)); height = maxDim; }
      const canvas = document.createElement("canvas");
      canvas.width = width; canvas.height = height;
      const ctx = canvas.getContext("2d");
      if (!ctx) { reject(new Error("Canvas context failed")); return; }
      ctx.drawImage(img, 0, 0, width, height);
      canvas.toBlob(blob => blob ? resolve(blob) : reject(new Error("toBlob failed")), "image/jpeg", quality);
    };
    img.onerror = reject;
    img.src = url;
  });
}

function slugify(name: string): string {
  return name.toLowerCase().replace(/[^a-z0-9]/g, "");
}

// ── Duplicate-name matching (used by the "not on the list?" request flow) ──────
function normalizeName(name: string): string {
  return name.trim().toLowerCase().replace(/[^a-z\s]/g, "").replace(/\s+/g, " ");
}

function levenshtein(a: string, b: string): number {
  const dp: number[][] = Array.from({ length: a.length + 1 }, () => new Array(b.length + 1).fill(0));
  for (let i = 0; i <= a.length; i++) dp[i][0] = i;
  for (let j = 0; j <= b.length; j++) dp[0][j] = j;
  for (let i = 1; i <= a.length; i++) {
    for (let j = 1; j <= b.length; j++) {
      dp[i][j] = a[i - 1] === b[j - 1]
        ? dp[i - 1][j - 1]
        : 1 + Math.min(dp[i - 1][j - 1], dp[i][j - 1], dp[i - 1][j]);
    }
  }
  return dp[a.length][b.length];
}

type DuplicateMatch = { name: string; exact: boolean };

// Checks a candidate name against both confirmed birds and existing pending
// requests. Exact (normalized) matches are unambiguous. Near-matches (typos,
// minor spelling variants) are flagged but not exact — caller decides whether
// to hard-block or just warn.
function findDuplicateBird(input: string, birds: Bird[], pending: PendingBird[]): DuplicateMatch | null {
  const norm = normalizeName(input);
  if (!norm) return null;

  const candidates = [...birds.map(b => b.name), ...pending.map(p => p.name)];
  let bestFuzzy: DuplicateMatch | null = null;

  for (const c of candidates) {
    const cNorm = normalizeName(c);
    if (cNorm === norm) return { name: c, exact: true };

    const dist = levenshtein(norm, cNorm);
    const threshold = Math.max(1, Math.floor(Math.min(norm.length, cNorm.length) * 0.2));
    if (dist <= threshold && !bestFuzzy) bestFuzzy = { name: c, exact: false };
  }
  return bestFuzzy;
}

// ── App ───────────────────────────────────────────────────────────────────────
export default function App() {
  const [view, setView]               = useState<"today" | "add" | "history" | "manage">("today");
  const [heard, setHeard]             = useState<string[]>([]);
  const [history, setHistory]         = useState<Record<string, string[]>>({});
  const [historyDay, setHistoryDay]   = useState<string | null>(null);
  const [zoomedBird, setZoomedBird]   = useState<AnyBird | null>(null);
  const [saving, setSaving]           = useState(false);
  const [streak, setStreak]           = useState(0);
  const [heardCounts, setHeardCounts] = useState<Record<string, number>>({});
  const [session, setSession]         = useState<Session | null>(null);
  const [authReady, setAuthReady]     = useState(false);
  const [birds, setBirds]             = useState<Bird[]>([]);
  const [birdsLoading, setBirdsLoading] = useState(true);
  const [pendingBirds, setPendingBirds] = useState<PendingBird[]>([]);
  const [showRequest, setShowRequest]   = useState(false);

  const allPendingRef = useRef<PendingBird[]>([]);
  const touchStartXRef = useRef<number | null>(null);
  const isAdmin = session?.user?.email === ADMIN_EMAIL;

  // ── Auth ──────────────────────────────────────────────────────────────────
  useEffect(() => {
    supabase.auth.getSession().then(({ data: { session } }) => {
      setSession(session); setAuthReady(true);
    });
    const { data: { subscription } } = supabase.auth.onAuthStateChange((_e, session) => {
      setSession(session); setAuthReady(true);
    });
    return () => subscription.unsubscribe();
  }, []);

  useEffect(() => { if (session) loadFromSupabase(); }, [session]);

  // ── Data loading ──────────────────────────────────────────────────────────
  async function loadFromSupabase() {
    const [birdsRes, logsRes, pendingRes] = await Promise.all([
      supabase.from("birds").select("*").order("name"),
      supabase.from("logs").select("date, bird_ids").order("date", { ascending: false }),
      supabase.from("pending_birds").select("id, name, status, resolved_to"),
    ]);

    if (birdsRes.error) { console.error("Birds load error:", birdsRes.error); }
    const loadedBirds: Bird[] = (birdsRes.data ?? []).map((b: any) => ({
      id: b.id, name: b.name, latin: b.latin, color: b.color,
      imageUrl: b.image_url, description: b.description, fact: b.fact, facingRight: b.facing_right,
    }));
    setBirds(loadedBirds);
    setBirdsLoading(false);

    const allPending: PendingBird[] = (pendingRes.data ?? []).map(r => ({
      id: r.id, name: r.name, isPending: true as const,
      resolvedTo: r.resolved_to ?? undefined, color: "#c8b99a",
    }));
    allPendingRef.current = allPending;
    setPendingBirds(allPending.filter(p => !p.resolvedTo));

    const data = logsRes.data;
    if (logsRes.error) { console.error("Supabase:", logsRes.error); return; }
    if (!data) return;

    const todayRow = data.find(r => r.date === todayKey);
    const hist: Record<string, string[]> = {};
    const counts: Record<string, number> = {};
    const loggedDates = new Set<string>();
    data.forEach(r => {
      if (r.bird_ids?.length > 0) {
        loggedDates.add(r.date);
        r.bird_ids.forEach((id: string) => { counts[id] = (counts[id] || 0) + 1; });
      }
      if (r.date !== todayKey && r.bird_ids?.length > 0) {
        const label = new Date(r.date + "T12:00:00").toLocaleDateString("en-GB", {
          weekday: "long", day: "numeric", month: "long", year: "numeric",
        });
        hist[label] = r.bird_ids;
      }
    });
    setHeard(todayRow?.bird_ids ?? []);
    setHistory(hist);
    setHeardCounts(counts);
    setStreak(calculateStreak(loggedDates));
  }

  function getAnyBird(id: string): AnyBird | undefined {
    const real = birds.find(b => b.id === id);
    if (real) return real;
    const pending = allPendingRef.current.find(p => p.id === id);
    if (!pending) return undefined;
    if (pending.resolvedTo) return birds.find(b => b.id === pending.resolvedTo);
    return pending;
  }

  async function toggleBird(id: string) {
    const next = heard.includes(id) ? heard.filter(b => b !== id) : [...heard, id];
    setHeard(next);
    setSaving(true);
    await supabase.from("logs").upsert(
      { date: todayKey, bird_ids: next, user_id: session!.user.id },
      { onConflict: "date,user_id" }
    );
    setSaving(false);
  }

  async function requestBird(name: string): Promise<{ blocked: DuplicateMatch } | void> {
    // Re-check against current state at submit time, not just at keystroke time —
    // closes most of the window where two people request the same bird almost
    // simultaneously. Doesn't eliminate it (that needs a DB constraint — see
    // the unique index note), but this is the last checkpoint before the insert.
    const dup = findDuplicateBird(name, birds, allPendingRef.current);
    if (dup?.exact) return { blocked: dup };

    const { data, error } = await supabase
      .from("pending_birds")
      .insert({ name: name.trim(), requested_by: session!.user.id, status: "pending" })
      .select("id, name")
      .single();
    if (error || !data) { console.error("Request error:", error); return; }
    const newPending: PendingBird = { id: data.id, name: data.name, isPending: true, color: "#c8b99a" };
    setPendingBirds(prev => [...prev, newPending]);
    allPendingRef.current = [...allPendingRef.current, newPending];
    setShowRequest(false);
  }

  // ── Resolve a pending bird into a real one (admin only) ──────────────────
  async function resolvePendingBird(opts: {
    pendingId: string; name: string; latin: string; color: string;
    description: string; fact: string; facingRight: boolean; file: File;
  }) {
    const newId = slugify(opts.name);
    const resized = await resizeImage(opts.file);
    const path = `${newId}.jpg`;

    const { error: uploadErr } = await supabase.storage
      .from("birds")
      .upload(path, resized, { upsert: true, contentType: "image/jpeg" });
    if (uploadErr) { console.error("Upload error:", uploadErr); throw new Error(`[image upload] ${uploadErr.message}`); }

    const { data: pub } = supabase.storage.from("birds").getPublicUrl(path);
    const imageUrl = pub.publicUrl;

    const { error: insertErr } = await supabase.from("birds").insert({
      id: newId, name: opts.name, latin: opts.latin, color: opts.color,
      image_url: imageUrl, description: opts.description, fact: opts.fact,
      facing_right: opts.facingRight,
    });
    if (insertErr) { console.error("Bird insert error:", insertErr); throw new Error(`[bird insert] ${insertErr.message}`); }

    const { error: resolveErr } = await supabase
      .from("pending_birds")
      .update({ status: "resolved", resolved_to: newId })
      .eq("id", opts.pendingId);
    if (resolveErr) { console.error("Resolve error:", resolveErr); throw new Error(`[mark resolved] ${resolveErr.message}`); }

    // Refresh local state
    await loadFromSupabase();
  }

  // ── Remove a pending bird request (admin only) ────────────────────────────
  async function removePendingBird(id: string) {
    const { error } = await supabase.from("pending_birds").delete().eq("id", id);
    if (error) { console.error("Remove pending bird error:", error); throw new Error(`[remove pending] ${error.message}`); }
    setPendingBirds(prev => prev.filter(p => p.id !== id));
    allPendingRef.current = allPendingRef.current.filter(p => p.id !== id);
  }

  const selectedBirds = heard.map(getAnyBird).filter(Boolean) as AnyBird[];

  // ── Auth guard ────────────────────────────────────────────────────────────
  if (!authReady) return <div style={s.shell} />;
  if (!session)   return <LoginScreen />;
  if (birdsLoading) return <div style={s.shell} />;

  const headerTitle = view === "history" && historyDay ? historyDay : "HEARD TODAY";
  const headerSub   = view === "history" && historyDay ? null : todayStr;
  const navTo = (v: "today" | "add" | "history" | "manage") => { setView(v); setHistoryDay(null); };

  // History days are inserted newest-first (query order). Swipe left = older, swipe right = newer.
  const historyDates = Object.keys(history);
  function shiftHistoryDay(dir: 1 | -1) {
    if (!historyDay) return;
    const idx = historyDates.indexOf(historyDay);
    const nextIdx = idx + dir;
    if (idx === -1 || nextIdx < 0 || nextIdx >= historyDates.length) return;
    setHistoryDay(historyDates[nextIdx]);
  }
  function onHistoryTouchStart(e: React.TouchEvent) {
    touchStartXRef.current = e.touches[0].clientX;
  }
  function onHistoryTouchEnd(e: React.TouchEvent) {
    if (touchStartXRef.current === null) return;
    const dx = e.changedTouches[0].clientX - touchStartXRef.current;
    touchStartXRef.current = null;
    if (Math.abs(dx) < 50) return; // ignore small movements/taps
    shiftHistoryDay(dx < 0 ? 1 : -1);
  }

  return (
    <div style={s.shell}>
      <header style={s.header}>
        <div style={s.headerEyebrow}>ST ALBANS · HERTFORDSHIRE</div>
        <div style={s.headerTitle}>{headerTitle}</div>
        {headerSub && <div style={s.headerDate}>{headerSub}</div>}
        {streak > 0 && view === "today" && !historyDay && (
          <div style={s.headerStreak}>· {streak} day streak ·</div>
        )}
        <div style={{ fontSize: 8, color: "#8a7a62", letterSpacing: "1px", marginTop: 2, visibility: saving ? "visible" : "hidden" }}>saving…</div>
      </header>

      <main style={s.main}>
        {view === "today" && (
          <MontageView birds={selectedBirds} onAdd={() => navTo("add")} onZoom={setZoomedBird} />
        )}
        {view === "add" && (
          <SelectorView
            birds={birds}
            pendingBirds={pendingBirds}
            selected={heard}
            heardCounts={heardCounts}
            onToggle={toggleBird}
            onDone={() => navTo("today")}
            onRequest={() => setShowRequest(true)}
          />
        )}
        {view === "history" && !historyDay && (
          <HistoryList history={history} getAnyBird={getAnyBird} onSelect={d => setHistoryDay(d)} />
        )}
        {view === "history" && historyDay && (
          <div onTouchStart={onHistoryTouchStart} onTouchEnd={onHistoryTouchEnd}>
            <button onClick={() => setHistoryDay(null)} style={s.backBtn}>← All days</button>
            <MontageView
              birds={(history[historyDay] ?? []).map(getAnyBird).filter(Boolean) as AnyBird[]}
              onZoom={setZoomedBird}
            />
          </div>
        )}
        {view === "manage" && isAdmin && (
          <ManagePanel pendingBirds={pendingBirds} onResolve={resolvePendingBird} onRemove={removePendingBird} onDone={() => navTo("today")} />
        )}
      </main>

      <nav style={s.nav}>
        {([
          { id: "today"   as const, label: "TODAY" },
          { id: "add"     as const, label: heard.length > 0 ? `+ LOG (${heard.length})` : "+ LOG" },
          { id: "history" as const, label: "HISTORY" },
          ...(isAdmin ? [{ id: "manage" as const, label: pendingBirds.length > 0 ? `MANAGE (${pendingBirds.length})` : "MANAGE" }] : []),
        ] as const).map(tab => (
          <button key={tab.id} onClick={() => navTo(tab.id)} style={{
            ...s.navBtn,
            background: view === tab.id ? "#2c2416" : "transparent",
            color:      view === tab.id ? "#f0ead8" : "#7a6e5a",
            borderTop:  view === tab.id ? "2px solid #2c2416" : "2px solid transparent",
          }}>
            {tab.label}
          </button>
        ))}
      </nav>

      {/* ── Zoom overlay ──────────────────────────────────────────────────── */}
      {zoomedBird && (
        <div style={s.zoomOverlay} onClick={() => setZoomedBird(null)}>
          <div style={s.zoomCard} onClick={e => e.stopPropagation()}>
            <button onClick={() => setZoomedBird(null)} style={s.zoomClose}>×</button>
            {isPending(zoomedBird) ? (
              <>
                <div style={{ ...s.zoomImgBox, display: "flex", alignItems: "center", justifyContent: "center", background: "#e8dfc8" }}>
                  <div style={{ textAlign: "center", opacity: 0.45 }}>
                    <div style={{ fontSize: 52 }}>🪶</div>
                    <div style={{ fontSize: 9, letterSpacing: "2px", color: "#2c2416", textTransform: "uppercase", marginTop: 10, fontFamily: "Georgia,serif" }}>
                      Illustration pending
                    </div>
                  </div>
                </div>
                <div style={s.zoomName}>{zoomedBird.name}</div>
                <div style={{ ...s.zoomDesc, fontStyle: "italic", color: "#8a7a62" }}>
                  This bird has been added to the list. An illustration and details will follow soon.
                </div>
              </>
            ) : (
              <>
                <div style={s.zoomImgBox}>
                  <img src={zoomedBird.imageUrl} alt={zoomedBird.name}
                    style={{ width: "100%", height: "100%", objectFit: "contain" }} />
                </div>
                <div style={s.zoomName}>{zoomedBird.name}</div>
                <div style={s.zoomLatin}>{zoomedBird.latin}</div>
                <div style={s.zoomDesc}>{zoomedBird.description}</div>
                <div style={s.zoomFact}>
                  <span style={{ fontWeight: "bold", letterSpacing: "1px", textTransform: "uppercase", fontSize: 8 }}>Did you know · </span>
                  {zoomedBird.fact}
                </div>
                <BirdAudio latin={zoomedBird.latin} />
              </>
            )}
          </div>
        </div>
      )}

      {/* ── Request bird modal ────────────────────────────────────────────── */}
      {showRequest && (
        <RequestBirdModal
          onSubmit={requestBird}
          onClose={() => setShowRequest(false)}
          birds={birds}
          pendingBirds={pendingBirds}
        />
      )}
    </div>
  );
}

// ── Login screen (OTP code) ───────────────────────────────────────────────────
function LoginScreen() {
  const [email, setEmail]     = useState("");
  const [code, setCode]       = useState("");
  const [stage, setStage]     = useState<"email" | "code">("email");
  const [loading, setLoading] = useState(false);
  const [error, setError]     = useState<string | null>(null);

  async function handleSendCode() {
    if (!email.trim()) return;
    setLoading(true); setError(null);
    const { error } = await supabase.auth.signInWithOtp({ email: email.trim() });
    setLoading(false);
    if (error) { setError(error.message); return; }
    setStage("code");
  }

  async function handleVerifyCode() {
    if (!code.trim()) return;
    setLoading(true); setError(null);
    const { error } = await supabase.auth.verifyOtp({
      email: email.trim(), token: code.trim(), type: "email",
    });
    setLoading(false);
    if (error) { setError("Incorrect or expired code. Try again."); return; }
  }

  return (
    <div style={{ ...s.shell, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", minHeight: "100vh" }}>
      <div style={{ textAlign: "center", padding: "0 32px", maxWidth: 320 }}>
        <div style={{ fontSize: 9, letterSpacing: "3px", color: "#8a7a62", textTransform: "uppercase", marginBottom: 8 }}>
          ST ALBANS · HERTFORDSHIRE
        </div>
        <div style={{ fontSize: 22, fontWeight: "bold", letterSpacing: "3px", color: "#2c2416", textTransform: "uppercase", marginBottom: 32 }}>
          HEARD TODAY
        </div>
        {stage === "email" ? (
          <>
            <div style={{ fontSize: 11, color: "#8a7a62", letterSpacing: "1px", lineHeight: "1.7", marginBottom: 24 }}>
              Enter your email to sign in.<br />We'll send you a code — no password needed.
            </div>
            <input type="email" value={email}
              onChange={e => setEmail(e.target.value)}
              onKeyDown={e => e.key === "Enter" && handleSendCode()}
              placeholder="your@email.com"
              style={{ width: "100%", padding: "12px 14px", marginBottom: 12, border: "1px solid #c8b99a", background: "#faf6ec", fontFamily: "Georgia,serif", fontSize: 13, color: "#2c2416", boxSizing: "border-box", outline: "none" }}
            />
            {error && <div style={{ fontSize: 10, color: "#a05a2c", marginBottom: 10, letterSpacing: "1px" }}>{error}</div>}
            <button onClick={handleSendCode} disabled={loading || !email.trim()}
              style={{ width: "100%", padding: "13px", background: "#2c2416", color: "#f0ead8", border: "none", fontFamily: "Georgia,serif", fontSize: 11, letterSpacing: "2px", cursor: loading ? "default" : "pointer", opacity: loading || !email.trim() ? 0.6 : 1 }}>
              {loading ? "SENDING…" : "SEND CODE"}
            </button>
          </>
        ) : (
          <>
            <div style={{ fontSize: 11, color: "#8a7a62", letterSpacing: "1px", lineHeight: "1.7", marginBottom: 8 }}>
              We've sent a code to<br /><span style={{ fontStyle: "italic" }}>{email}</span>.
            </div>
            <div style={{ fontSize: 10, color: "#8a7a62", letterSpacing: "1px", lineHeight: "1.7", marginBottom: 20 }}>
              Enter it below.
            </div>
            <input type="text" inputMode="numeric" value={code}
              onChange={e => setCode(e.target.value.replace(/\D/g, "").slice(0, 8))}
              onKeyDown={e => e.key === "Enter" && handleVerifyCode()}
              placeholder="12345678"
              autoFocus
              style={{ width: "100%", padding: "12px 14px", marginBottom: 12, border: "1px solid #c8b99a", background: "#faf6ec", fontFamily: "Georgia,serif", fontSize: 20, letterSpacing: "6px", textAlign: "center", color: "#2c2416", boxSizing: "border-box", outline: "none" }}
            />
            {error && <div style={{ fontSize: 10, color: "#a05a2c", marginBottom: 10, letterSpacing: "1px" }}>{error}</div>}
            <button onClick={handleVerifyCode} disabled={loading || code.length !== 8}
              style={{ width: "100%", padding: "13px", background: "#2c2416", color: "#f0ead8", border: "none", fontFamily: "Georgia,serif", fontSize: 11, letterSpacing: "2px", cursor: loading ? "default" : "pointer", opacity: loading || code.length !== 8 ? 0.6 : 1, marginBottom: 10 }}>
              {loading ? "VERIFYING…" : "VERIFY & SIGN IN"}
            </button>
            <button onClick={() => { setStage("email"); setCode(""); setError(null); }}
              style={{ width: "100%", padding: "8px", background: "none", border: "none", fontFamily: "Georgia,serif", fontSize: 10, letterSpacing: "1px", color: "#8a7a62", cursor: "pointer", textDecoration: "underline" }}>
              Use a different email
            </button>
          </>
        )}
      </div>
    </div>
  );
}

// ── Request bird modal ────────────────────────────────────────────────────────
function RequestBirdModal({
  onSubmit, onClose, birds, pendingBirds,
}: {
  onSubmit: (name: string) => Promise<{ blocked: DuplicateMatch } | void>;
  onClose: () => void;
  birds: Bird[];
  pendingBirds: PendingBird[];
}) {
  const [name, setName]         = useState("");
  const [loading, setLoading]   = useState(false);
  const [forceAdd, setForceAdd] = useState(false); // user dismissed a fuzzy warning once

  const match = findDuplicateBird(name, birds, pendingBirds);
  // Any edit after a fuzzy override should re-arm the warning.
  const effectiveMatch = forceAdd ? (match?.exact ? match : null) : match;

  function handleNameChange(v: string) {
    setName(v);
    setForceAdd(false);
  }

  async function handle() {
    if (!name.trim() || loading) return;
    if (effectiveMatch?.exact) return; // hard block, shouldn't reach here anyway
    if (effectiveMatch && !forceAdd) { setForceAdd(true); return; } // first Enter/click just surfaces the warning

    setLoading(true);
    const result = await onSubmit(name.trim());
    setLoading(false);
    if (result?.blocked) {
      // Someone else's request landed between our check and the insert.
      setForceAdd(false);
    }
  }

  return (
    <div style={s.zoomOverlay} onClick={onClose}>
      <div style={s.zoomCard} onClick={e => e.stopPropagation()}>
        <button onClick={onClose} style={s.zoomClose}>×</button>
        <div style={{ ...s.zoomName, marginBottom: 8 }}>New Bird</div>
        <div style={{ fontSize: 11, color: "#8a7a62", textAlign: "center", lineHeight: "1.7", marginBottom: 20, fontFamily: "Georgia,serif" }}>
          What did you hear? Type the name and we'll add an illustration soon.
        </div>
        <input
          autoFocus type="text" value={name}
          onChange={e => handleNameChange(e.target.value)}
          onKeyDown={e => e.key === "Enter" && handle()}
          placeholder="e.g. Pied Wagtail"
          style={{ width: "100%", padding: "12px 14px", marginBottom: effectiveMatch ? 8 : 14, border: `1px solid ${effectiveMatch?.exact ? "#a05a2c" : "#c8b99a"}`, background: "#faf6ec", fontFamily: "Georgia,serif", fontSize: 13, color: "#2c2416", boxSizing: "border-box", outline: "none" }}
        />
        {effectiveMatch && (
          <div style={{ fontSize: 10.5, color: "#a05a2c", lineHeight: "1.6", marginBottom: 14, fontFamily: "Georgia,serif", fontStyle: "italic" }}>
            {effectiveMatch.exact
              ? `"${effectiveMatch.name}" is already on the list.`
              : `Close to an existing entry: "${effectiveMatch.name}". Tap Add again to add it anyway.`}
          </div>
        )}
        <button onClick={handle} disabled={loading || !name.trim() || !!effectiveMatch?.exact}
          style={{ width: "100%", padding: "13px", background: "#2c2416", color: "#f0ead8", border: "none", fontFamily: "Georgia,serif", fontSize: 11, letterSpacing: "2px", cursor: loading ? "default" : "pointer", opacity: loading || !name.trim() || effectiveMatch?.exact ? 0.6 : 1 }}>
          {loading ? "ADDING…" : effectiveMatch && !forceAdd ? "ADD ANYWAY?" : "ADD TO LIST"}
        </button>
      </div>
    </div>
  );
}

// ── Admin: manage / resolve pending birds ─────────────────────────────────────
function ManagePanel({
  pendingBirds, onResolve, onRemove, onDone,
}: {
  pendingBirds: PendingBird[];
  onResolve: (opts: { pendingId: string; name: string; latin: string; color: string; description: string; fact: string; facingRight: boolean; file: File }) => Promise<void>;
  onRemove: (id: string) => Promise<void>;
  onDone: () => void;
}) {
  const [resolving, setResolving]     = useState<PendingBird | null>(null);
  const [confirmingId, setConfirmingId] = useState<string | null>(null);
  const [removingId, setRemovingId]   = useState<string | null>(null);
  const [removeError, setRemoveError] = useState<string | null>(null);

  async function handleRemove(id: string) {
    setRemovingId(id); setRemoveError(null);
    try {
      await onRemove(id);
      setConfirmingId(null);
    } catch (e: any) {
      setRemoveError(e?.message || "Failed to remove");
    } finally {
      setRemovingId(null);
    }
  }

  return (
    <div style={{ paddingBottom: 80 }}>
      <div style={s.selectorHeader}>
        <span>Manage pending birds</span>
        <button onClick={onDone} style={s.doneBtn}>Done</button>
      </div>
      {removeError && (
        <div style={{ fontSize: 10, color: "#a05a2c", letterSpacing: "0.5px", padding: "8px 0" }}>{removeError}</div>
      )}
      {pendingBirds.length === 0 ? (
        <div style={{ ...s.empty, minHeight: "40vh" }}>
          <div style={s.emptyTitle}>Nothing pending</div>
          <div style={s.emptySub}>Bird requests from your group will appear here.</div>
        </div>
      ) : (
        <div style={{ padding: "10px 0" }}>
          {pendingBirds.map(p => (
            <div key={p.id} style={{
              display: "flex", alignItems: "center", justifyContent: "space-between",
              padding: "12px 14px", background: "#ede5d0", border: "1px dashed #b8a98a",
              marginBottom: 8, fontFamily: "Georgia,serif",
            }}>
              <span onClick={() => setResolving(p)} style={{ fontSize: 14, fontStyle: "italic", color: "#2c2416", cursor: "pointer", flex: 1 }}>
                {p.name}
              </span>
              {confirmingId === p.id ? (
                <div style={{ display: "flex", alignItems: "center", gap: 8, flexShrink: 0 }}>
                  <span style={{ fontSize: 9, color: "#a05a2c", letterSpacing: "0.5px" }}>Remove?</span>
                  <button onClick={() => handleRemove(p.id)} disabled={removingId === p.id} style={{
                    fontSize: 9, letterSpacing: "1px", color: "#a05a2c", background: "none",
                    border: "1px solid #a05a2c", padding: "3px 8px", cursor: "pointer", fontFamily: "Georgia,serif",
                  }}>
                    {removingId === p.id ? "…" : "YES"}
                  </button>
                  <button onClick={() => setConfirmingId(null)} style={{
                    fontSize: 9, letterSpacing: "1px", color: "#8a7a62", background: "none",
                    border: "none", cursor: "pointer", fontFamily: "Georgia,serif",
                  }}>
                    cancel
                  </button>
                </div>
              ) : (
                <div style={{ display: "flex", alignItems: "center", gap: 12, flexShrink: 0 }}>
                  <span onClick={() => setResolving(p)} style={{ fontSize: 10, color: "#8a7a62", letterSpacing: "1px", cursor: "pointer" }}>
                    RESOLVE →
                  </span>
                  <span onClick={() => setConfirmingId(p.id)} style={{ fontSize: 15, color: "#8a7a62", cursor: "pointer", lineHeight: "1" }}>
                    ×
                  </span>
                </div>
              )}
            </div>
          ))}
        </div>
      )}
      {resolving && (
        <ResolveBirdModal pending={resolving} onResolve={onResolve} onClose={() => setResolving(null)} />
      )}
    </div>
  );
}

function ResolveBirdModal({
  pending, onResolve, onClose,
}: {
  pending: PendingBird;
  onResolve: (opts: { pendingId: string; name: string; latin: string; color: string; description: string; fact: string; facingRight: boolean; file: File }) => Promise<void>;
  onClose: () => void;
}) {
  const [name, setName]               = useState(pending.name);
  const [latin, setLatin]             = useState("");
  const [color, setColor]             = useState("#8B7355");
  const [description, setDescription] = useState("");
  const [fact, setFact]               = useState("");
  const [facingRight, setFacingRight] = useState(true);
  const [file, setFile]               = useState<File | null>(null);
  const [preview, setPreview]         = useState<string | null>(null);
  const [loading, setLoading]         = useState(false);
  const [error, setError]             = useState<string | null>(null);
  const [pasteText, setPasteText]     = useState("");
  const [parseOk, setParseOk]         = useState<boolean | null>(null);
  const pasteBoxRef = useRef<HTMLDivElement>(null);

  function handleFile(f: File | null) {
    setFile(f);
    if (f) setPreview(URL.createObjectURL(f));
  }

  function handleImagePaste(e: React.ClipboardEvent) {
    e.preventDefault();
    const items = e.clipboardData?.items;
    if (items) {
      for (const item of items) {
        if (item.type.startsWith("image/")) {
          const blob = item.getAsFile();
          if (blob) {
            // Clipboard image blobs often have no filename — give it one
            const f = new File([blob], "pasted-image.png", { type: blob.type });
            handleFile(f);
          }
          break;
        }
      }
    }
    // Wipe anything the browser may have inserted (text, HTML) before our preventDefault landed
    if (pasteBoxRef.current) pasteBoxRef.current.textContent = "";
  }

  // iOS Safari's long-press "Paste" menu can be unreliable inside a PWA. This gives a
  // tap-triggered fallback using the async Clipboard API, which needs a real user gesture.
  async function handleClipboardButtonPaste() {
    try {
      const clipboardItems = await navigator.clipboard.read();
      for (const item of clipboardItems) {
        const type = item.types.find(t => t.startsWith("image/"));
        if (type) {
          const blob = await item.getType(type);
          const f = new File([blob], "pasted-image.png", { type: blob.type });
          handleFile(f);
          return;
        }
      }
      setError("Clipboard doesn't contain an image — copy one first.");
    } catch {
      setError("Couldn't read the clipboard. Copy an image, then tap this button again.");
    }
  }

  function handlePasteParse(text: string) {
    setPasteText(text);
    if (!text.trim()) { setParseOk(null); return; }
    const latinMatch = text.match(/Latin:\s*([^\n]+)/i);
    const descMatch  = text.match(/Description:\s*([\s\S]*?)(?=\n\s*Fact:|$)/i);
    const factMatch  = text.match(/Fact:\s*([\s\S]*)/i);
    if (latinMatch || descMatch || factMatch) {
      if (latinMatch) setLatin(latinMatch[1].trim());
      if (descMatch)  setDescription(descMatch[1].trim());
      if (factMatch)  setFact(factMatch[1].trim());
      setParseOk(true);
    } else {
      setParseOk(false);
    }
  }

  async function handleSubmit() {
    if (!name.trim() || !latin.trim() || !description.trim() || !fact.trim() || !file) {
      setError("All fields and an image are required.");
      return;
    }
    setLoading(true); setError(null);
    try {
      await onResolve({ pendingId: pending.id, name: name.trim(), latin: latin.trim(), color, description: description.trim(), fact: fact.trim(), facingRight, file });
      onClose();
    } catch (e: any) {
      const msg = e?.message || e?.error_description || JSON.stringify(e);
      setError(`Failed: ${msg}`);
    } finally {
      setLoading(false);
    }
  }

  const inputStyle: React.CSSProperties = { width: "100%", padding: "10px 12px", marginBottom: 10, border: "1px solid #c8b99a", background: "#faf6ec", fontFamily: "Georgia,serif", fontSize: 12, color: "#2c2416", boxSizing: "border-box", outline: "none" };
  const labelStyle: React.CSSProperties = { fontSize: 9, letterSpacing: "1.5px", color: "#8a7a62", textTransform: "uppercase", marginBottom: 4, display: "block" };

  return (
    <div style={s.zoomOverlay} onClick={onClose}>
      <div style={{ ...s.zoomCard, maxHeight: "85vh", overflowY: "auto" }} onClick={e => e.stopPropagation()}>
        <button onClick={onClose} style={s.zoomClose}>×</button>
        <div style={{ ...s.zoomName, marginBottom: 16 }}>Resolve Bird</div>

        <label style={labelStyle}>Paste from Claude</label>
        <div style={{ fontSize: 10, color: "#8a7a62", lineHeight: "1.5", marginBottom: 6, fontFamily: "Georgia,serif" }}>
          Ask Claude for the Latin name, description and fact, then paste the whole reply here — it'll fill in the fields below.
        </div>
        <textarea
          value={pasteText}
          onChange={e => handlePasteParse(e.target.value)}
          placeholder={"Latin: ...\nDescription: ...\nFact: ..."}
          style={{ ...inputStyle, minHeight: 90, resize: "vertical", fontSize: 11 }}
        />
        {parseOk === true && (
          <div style={{ fontSize: 10, color: "#4a6b3a", marginBottom: 10, letterSpacing: "0.5px" }}>✓ Fields filled in below — check them, then continue.</div>
        )}
        {parseOk === false && (
          <div style={{ fontSize: 10, color: "#a05a2c", marginBottom: 10, letterSpacing: "0.5px" }}>Couldn't find Latin/Description/Fact labels — fill in the fields below manually.</div>
        )}

        <div style={{ borderTop: "1px solid #d4c5a6", margin: "16px 0" }} />

        <label style={labelStyle}>Name</label>
        <input style={inputStyle} value={name} onChange={e => setName(e.target.value)} />

        <label style={labelStyle}>Latin name</label>
        <input style={inputStyle} value={latin} onChange={e => setLatin(e.target.value)} placeholder="e.g. Motacilla alba" />

        <label style={labelStyle}>Description</label>
        <textarea style={{ ...inputStyle, minHeight: 60, resize: "vertical" }} value={description} onChange={e => setDescription(e.target.value)} />

        <label style={labelStyle}>Did you know fact</label>
        <textarea style={{ ...inputStyle, minHeight: 60, resize: "vertical" }} value={fact} onChange={e => setFact(e.target.value)} />

        <label style={labelStyle}>Fallback colour (used if image fails to load)</label>
        <input type="color" value={color} onChange={e => setColor(e.target.value)} style={{ width: "100%", height: 36, marginBottom: 10, border: "1px solid #c8b99a", cursor: "pointer" }} />

        <label style={{ ...labelStyle, display: "flex", alignItems: "center", gap: 6, cursor: "pointer" }}>
          <input type="checkbox" checked={facingRight} onChange={e => setFacingRight(e.target.checked)} />
          Illustration faces right (→)
        </label>

        <label style={labelStyle}>Illustration</label>
        <input type="file" accept="image/*" onChange={e => handleFile(e.target.files?.[0] ?? null)} style={{ marginBottom: 6, fontSize: 11, fontFamily: "Georgia,serif" }} />
        <div
          ref={pasteBoxRef}
          contentEditable
          suppressContentEditableWarning
          onPaste={handleImagePaste}
          style={{
            padding: "14px", marginBottom: 6, border: "1px dashed #b8a98a",
            background: "#faf6ec", fontSize: 10, color: "#8a7a62", letterSpacing: "0.5px",
            fontFamily: "Georgia,serif", textAlign: "center", outline: "none", cursor: "text",
          }}
        >
          or click here and paste an image (Ctrl/Cmd+V)
        </div>
        {typeof navigator !== "undefined" && !!navigator.clipboard?.read && (
          <button
            type="button"
            onClick={handleClipboardButtonPaste}
            style={{
              width: "100%", padding: "10px", marginBottom: 10, background: "none",
              border: "1px dashed #b8a98a", fontFamily: "Georgia,serif", fontSize: 10,
              color: "#8a7a62", letterSpacing: "1px", cursor: "pointer",
            }}
          >
            📋 paste image from clipboard
          </button>
        )}
        {preview && (
          <div style={{ width: 100, height: 100, marginBottom: 10, background: "#fff", border: "1px solid #c8b99a" }}>
            <img src={preview} alt="preview" style={{ width: "100%", height: "100%", objectFit: "contain" }} />
          </div>
        )}

        {error && <div style={{ fontSize: 10, color: "#a05a2c", marginBottom: 10, letterSpacing: "1px" }}>{error}</div>}

        <button onClick={handleSubmit} disabled={loading}
          style={{ width: "100%", padding: "13px", background: "#2c2416", color: "#f0ead8", border: "none", fontFamily: "Georgia,serif", fontSize: 11, letterSpacing: "2px", cursor: loading ? "default" : "pointer", opacity: loading ? 0.6 : 1 }}>
          {loading ? "SAVING…" : "SAVE & ADD TO LIBRARY"}
        </button>
      </div>
    </div>
  );
}

// ── Bird audio (xeno-canto) ───────────────────────────────────────────────────
function BirdAudio({ latin }: { latin: string }) {
  const [playing, setPlaying] = useState<"song" | "call" | null>(null);
  const [status, setStatus]   = useState<Record<"song" | "call", "loading" | "ready" | "error">>({ song: "loading", call: "loading" });
  const audioRef = useRef<HTMLAudioElement | null>(null);
  const urlCache = useRef<Partial<Record<"song" | "call", string>>>({});

  useEffect(() => {
    const prefetch = async (type: "song" | "call") => {
      try {
        const q1 = encodeURIComponent(`sp:"${latin}" q:A cnt:"United Kingdom" type:${type}`);
        let res  = await fetch(`/.netlify/functions/xeno?query=${q1}`);
        let data = await res.json();
        if (!data.recordings?.length) {
          const q2 = encodeURIComponent(`sp:"${latin}" q:A type:${type}`);
          res  = await fetch(`/.netlify/functions/xeno?query=${q2}`);
          data = await res.json();
        }
        if (data.recordings?.length) {
          const recs = data.recordings as any[];
          const mp3  = recs.find((r: any) => (r["file-name"] || "").toLowerCase().endsWith(".mp3"));
          const rec  = mp3 || recs[0];
          const raw  = rec.file as string;
          urlCache.current[type] = raw.startsWith("//") ? "https:" + raw : raw;
          setStatus(s => ({ ...s, [type]: "ready" }));
        } else {
          setStatus(s => ({ ...s, [type]: "error" }));
        }
      } catch {
        setStatus(s => ({ ...s, [type]: "error" }));
      }
    };
    prefetch("song");
    prefetch("call");
    return () => { audioRef.current?.pause(); };
  }, [latin]);

  const toggle = (type: "song" | "call") => {
    audioRef.current?.pause();
    audioRef.current = null;
    if (playing === type) { setPlaying(null); return; }
    setPlaying(null);
    const url = urlCache.current[type];
    if (!url) return;
    const audio = new Audio(url);
    audioRef.current = audio;
    audio.onended = () => setPlaying(null);
    audio.onerror = () => setPlaying(null);
    audio.load();
    audio.play().catch(() => setPlaying(null));
    setPlaying(type);
  };

  return (
    <div style={{ display: "flex", gap: 8, marginTop: 16 }}>
      {(["song", "call"] as const).map(type => {
        const st = status[type]; const isPlaying = playing === type;
        return (
          <button key={type} onClick={() => st === "ready" && toggle(type)} style={{
            flex: 1, padding: "10px 6px",
            background:    isPlaying ? "#2c2416" : "#ede5d0",
            color:         isPlaying ? "#f0ead8" : st === "error" ? "#a06040" : "#2c2416",
            border:        `1px solid ${st === "error" ? "#a06040" : "#c8b99a"}`,
            fontFamily:    "Georgia, serif", fontSize: 10, letterSpacing: "1.5px",
            textTransform: "uppercase", cursor: st === "ready" ? "pointer" : "default",
            opacity:       st === "loading" ? 0.5 : 1,
          }}>
            {st === "loading" ? "·····" : st === "error" ? "unavailable" : isPlaying ? `■ ${type}` : `▶ ${type}`}
          </button>
        );
      })}
    </div>
  );
}

// ── Montage canvas ────────────────────────────────────────────────────────────
// html-to-image serializes the DOM synchronously. If an <img> inside the
// capture target hasn't finished loading yet — common right after mount, and
// especially on iOS Safari where decode timing is unpredictable — that tile
// exports as a blank box even though it renders fine on screen a moment
// later. Wait for every image to actually load (or fail) before capturing.
async function waitForImages(container: HTMLElement): Promise<void> {
  const imgs = Array.from(container.querySelectorAll("img"));
  await Promise.all(imgs.map(img => {
    if (img.complete && img.naturalWidth !== 0) return Promise.resolve();
    return new Promise<void>(resolve => {
      img.addEventListener("load", () => resolve(), { once: true });
      img.addEventListener("error", () => resolve(), { once: true }); // don't hang the export on one broken image
    });
  }));
  // Loaded doesn't always mean painted yet on iOS Safari — give it one more frame.
  await new Promise(r => requestAnimationFrame(() => r(null)));
}

function MontageView({ birds, onAdd, onZoom }: { birds: AnyBird[]; onAdd?: () => void; onZoom?: (b: AnyBird) => void }) {
  const containerRef = useRef<HTMLDivElement>(null);
  const [containerW, setContainerW] = useState(390);
  const [sharing, setSharing] = useState(false);

  useEffect(() => {
    function measure() {
      if (containerRef.current) setContainerW(containerRef.current.offsetWidth);
    }
    measure();
    window.addEventListener("resize", measure);
    return () => window.removeEventListener("resize", measure);
  }, [birds.length]);

  async function handleShare() {
    if (!containerRef.current || sharing) return;
    setSharing(true);
    try {
      await waitForImages(containerRef.current);
      const dataUrl = await toPng(containerRef.current, { pixelRatio: 2, backgroundColor: "#f5edd8", cacheBust: true });
      const res = await fetch(dataUrl);
      const blob = await res.blob();
      const file = new File([blob], "heard-today.png", { type: "image/png" });

      if (navigator.share && navigator.canShare?.({ files: [file] })) {
        await navigator.share({ files: [file], title: "Heard Today" });
      } else {
        const link = document.createElement("a");
        link.href = dataUrl;
        link.download = "heard-today.png";
        link.click();
      }
    } catch (e) {
      console.error("Share failed:", e);
    } finally {
      setSharing(false);
    }
  }

  if (!birds.length) {
    return (
      <div style={s.empty}>
        <div style={s.emptyIcon}>⬚</div>
        <div style={s.emptyTitle}>Nothing logged yet</div>
        <div style={s.emptySub}>Tap LOG to record what you heard this morning</div>
        {onAdd && <button onClick={onAdd} style={s.emptyBtn}>+ LOG BIRDS</button>}
      </div>
    );
  }

  const count   = birds.length;
  const cols    = count === 1 ? 1 : count <= 4 ? 2 : 3;
  const rows    = Math.ceil(count / cols);
  const tileW   = count === 1 ? 260 : count <= 2 ? 200 : count <= 4 ? 175 : count <= 6 ? 150 : count <= 12 ? 115 : 100;
  const tileH   = tileW + 28;
  const canvasH = rows * tileH + (rows + 1) * 18;

  const JX  = [-20, 18, -15, 22, -18, 14, -22, 17, -12, 20, -16];
  const JY  = [-12, 16, -10, 18, -15, 10, -16, 14,  -8, 18, -13];
  const ROT = [ -5,  4,  -3,  6,  -4,  5,  -6,  3,  -4,  6,  -4];

  const colWpx = containerW / cols;
  const rowHpx = canvasH / rows;
  const edgeX  = tileW / 2 + 4;
  const edgeY  = tileH / 2 + 4;

  return (
    <div style={{ paddingBottom: 80 }}>
      <div ref={containerRef} style={{ position: "relative", width: "100%", height: canvasH, background: "#f5edd8" }}>
        {birds.map((bird, i) => {
          const col  = i % cols;
          const row  = Math.floor(i / cols);
          const rawCX = colWpx * col + colWpx / 2 + JX[i % JX.length];
          const rawCY = rowHpx * row + rowHpx / 2 + JY[i % JY.length];
          const cx   = Math.max(edgeX, Math.min(containerW - edgeX, rawCX));
          const cy   = Math.max(edgeY, Math.min(canvasH   - edgeY, rawCY));
          const rot  = ROT[i % ROT.length];

          const facesRight  = isPending(bird) ? false : bird.facingRight;
          const inRightHalf = cx > containerW / 2;
          const shouldFlip  = isPending(bird) ? false : (facesRight ? inRightHalf : !inRightHalf);

          return (
            <div key={bird.id} onClick={() => onZoom?.(bird)} style={{
              position: "absolute", left: cx, top: cy, width: tileW,
              transform: `translate(-50%, -50%) rotate(${rot}deg)`,
              zIndex: i + 1, boxShadow: "3px 5px 16px rgba(44,36,22,0.30)",
              cursor: onZoom ? "pointer" : "default",
            }}>
              <BirdTile bird={bird} w={tileW} flipX={shouldFlip} />
            </div>
          );
        })}
      </div>
      <div style={{ display: "flex", alignItems: "center", justifyContent: "center", gap: 12, marginTop: 14 }}>
        <div style={{ fontSize: 10, letterSpacing: "2px", color: "#8a7a62", textTransform: "uppercase" }}>{birds.length} species heard</div>
        <button onClick={handleShare} disabled={sharing} style={{
          fontSize: 9, letterSpacing: "1.5px", color: "#8a7a62", textTransform: "uppercase",
          background: "none", border: "1px solid #c8b99a", padding: "4px 10px",
          cursor: sharing ? "default" : "pointer", fontFamily: "Georgia,serif",
          opacity: sharing ? 0.5 : 1,
        }}>
          {sharing ? "…" : "↗ Share"}
        </button>
      </div>
    </div>
  );
}

// ── Single bird tile ──────────────────────────────────────────────────────────
// Routes a Supabase public bird-image URL through our own Netlify function so it's
// same-origin — avoids relying on Supabase Storage's CORS headers for canvas capture.
function proxiedImageUrl(url: string): string {
  const marker = "/storage/v1/object/public/birds/";
  const idx = url.indexOf(marker);
  if (idx === -1) return url; // not a recognised bird-image URL — leave it alone
  const path = url.slice(idx + marker.length);
  return `/.netlify/functions/bird-image?path=${encodeURIComponent(path)}`;
}

function BirdTile({ bird, w, flipX = false }: { bird: AnyBird; w: number; flipX?: boolean }) {
  const isHero = w >= 170;
  const isPend = isPending(bird);
  const rawImg = isPend ? null : bird.imageUrl;
  const img    = rawImg ? proxiedImageUrl(rawImg) : null;
  const latin  = isPend ? null : bird.latin;

  return (
    <div style={{ background: "#f0e8d4", border: isPending(bird) ? "1px dashed #b8a98a" : "1px solid #d4c5a6", padding: isHero ? 6 : 4 }}>
      <div style={{ textAlign: "center", paddingBottom: isHero ? 6 : 4, fontSize: isHero ? 10 : 8, letterSpacing: "1.5px", color: isPending(bird) ? "#8a7a62" : "#2c2416", fontFamily: "Georgia, serif", textTransform: "uppercase", lineHeight: 1.3, fontStyle: isPending(bird) ? "italic" : "normal" }}>
        {bird.name}
        {latin && (
          <div style={{ fontSize: isHero ? 8 : 7, color: "#8a7a62", fontStyle: "italic", marginTop: 2, letterSpacing: "0.5px" }}>
            {latin}
          </div>
        )}
      </div>
      {img ? (
        <div style={{ width: "100%", aspectRatio: "1", background: "#fff" }}>
          <img src={img} alt={bird.name} style={{ width: "100%", height: "100%", display: "block", objectFit: "contain", transform: flipX ? "scaleX(-1)" : undefined }} />
        </div>
      ) : (
        <div style={{ position: "relative", width: "100%", paddingBottom: "100%", background: bird.color, opacity: isPending(bird) ? 0.55 : 0.85 }}>
          <div style={{ position: "absolute", inset: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 6 }}>
            <div style={{ fontSize: isHero ? 28 : 18, opacity: 0.45, lineHeight: 1 }}>🪶</div>
            {isHero && (
              <div style={{ fontSize: 8, letterSpacing: "1.5px", color: "rgba(44,36,22,0.45)", textTransform: "uppercase", textAlign: "center", fontFamily: "Georgia, serif" }}>
                {isPending(bird) ? "Pending" : "No illustration"}
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
}

// ── Bird selector ─────────────────────────────────────────────────────────────
function SelectorView({
  birds, pendingBirds, selected, heardCounts, onToggle, onDone, onRequest,
}: {
  birds: Bird[];
  pendingBirds: PendingBird[];
  selected: string[];
  heardCounts: Record<string, number>;
  onToggle: (id: string) => void;
  onDone: () => void;
  onRequest: () => void;
}) {
  const allBirds: AnyBird[] = [...birds, ...pendingBirds];
  const sorted = [...allBirds].sort((a, b) => {
    const diff = (heardCounts[b.id] || 0) - (heardCounts[a.id] || 0);
    return diff !== 0 ? diff : a.name.localeCompare(b.name);
  });

  return (
    <div style={{ paddingBottom: 80 }}>
      <div style={s.selectorHeader}>
        <span>Which birds did you hear?</span>
        <button onClick={onDone} style={s.doneBtn}>Done</button>
      </div>
      <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 6, padding: "10px 0" }}>
        {sorted.map(bird => {
          const on      = selected.includes(bird.id);
          const img     = isPending(bird) ? null : bird.imageUrl;
          const count   = heardCounts[bird.id] || 0;
          const pending = isPending(bird);
          return (
            <div key={bird.id} onClick={() => onToggle(bird.id)} style={{
              display: "flex", alignItems: "center", gap: 8, padding: "7px 8px",
              background: on ? "#2c2416" : pending ? "#ece4cf" : "#ede5d0",
              border:     `1px ${pending ? "dashed" : "solid"} ${on ? "#2c2416" : "#c8b99a"}`,
              color:      on ? "#f0ead8" : pending ? "#8a7a62" : "#2c2416",
              cursor: "pointer", fontFamily: "Georgia,serif", minWidth: 0,
            }}>
              {img ? (
                <div style={{ width: 56, height: 56, flexShrink: 0, background: "#fff", overflow: "hidden", border: "1px solid #c8b99a" }}>
                  <img src={img} alt={bird.name} style={{ width: "100%", height: "100%", objectFit: "contain" }} />
                </div>
              ) : (
                <div style={{ width: 56, height: 56, flexShrink: 0, background: bird.color, opacity: pending ? 0.5 : 0.85, display: "flex", alignItems: "center", justifyContent: "center" }}>
                  <span style={{ fontSize: 22, opacity: 0.5 }}>🪶</span>
                </div>
              )}
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontSize: 15, letterSpacing: "0.5px", lineHeight: "1.3", fontStyle: pending ? "italic" : "normal" }}>
                  {bird.name}
                </div>
              </div>
              <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 2, flexShrink: 0 }}>
                <div style={{ fontSize: 14, fontWeight: "bold", opacity: 0.8 }}>{on ? "✓" : "+"}</div>
                <div style={{ fontSize: 8, letterSpacing: "0.5px", opacity: 0.5 }}>{count}</div>
              </div>
            </div>
          );
        })}
      </div>
      <div style={{ padding: "4px 0 16px" }}>
        <button onClick={onRequest} style={{
          width: "100%", padding: "14px", background: "transparent",
          border: "1px dashed #b8a98a", fontFamily: "Georgia,serif",
          fontSize: 11, color: "#8a7a62", letterSpacing: "1.5px",
          fontStyle: "italic", cursor: "pointer",
        }}>
          + not on the list?
        </button>
      </div>
    </div>
  );
}

// ── History list ──────────────────────────────────────────────────────────────
function HistoryList({
  history, getAnyBird, onSelect,
}: {
  history: Record<string, string[]>;
  getAnyBird: (id: string) => AnyBird | undefined;
  onSelect: (date: string) => void;
}) {
  const entries = Object.entries(history);
  if (!entries.length) {
    return (
      <div style={{ ...s.empty, minHeight: "50vh" }}>
        <div style={s.emptyTitle}>No history yet</div>
        <div style={s.emptySub}>Your previous morning logs will appear here</div>
      </div>
    );
  }
  return (
    <div style={{ padding: "12px 16px", paddingBottom: 80 }}>
      <div style={{ ...s.selectorHeader, marginBottom: 12 }}><span>Previous days</span></div>
      {entries.map(([date, ids]) => {
        const birds = ids.map(getAnyBird).filter(Boolean) as AnyBird[];
        return (
          <div key={date} onClick={() => onSelect(date)} style={s.historyCard}>
            <div style={s.historyDate}>{date}</div>
            <div style={{ display: "flex", gap: 4, marginTop: 8, alignItems: "flex-end" }}>
              {birds.slice(0, 5).map(bird => {
                const img = isPending(bird) ? null : bird.imageUrl;
                return (
                  <div key={bird.id} style={{ flex: 1, maxWidth: 64, boxShadow: "1px 2px 5px rgba(0,0,0,0.18)" }}>
                    {img ? (
                      <img src={img} alt={bird.name} style={{ width: "100%", aspectRatio: "1", display: "block", objectFit: "cover" }} />
                    ) : (
                      <div style={{ paddingBottom: "100%", background: bird.color, opacity: 0.75 }} />
                    )}
                  </div>
                );
              })}
              {birds.length > 5 && <div style={{ fontSize: 10, color: "#8a7a62", paddingLeft: 4 }}>+{birds.length - 5}</div>}
            </div>
            <div style={{ ...s.historyCount, marginTop: 8 }}>{birds.length} species · tap to see collage →</div>
          </div>
        );
      })}
    </div>
  );
}

// ── Styles ────────────────────────────────────────────────────────────────────
const s: Record<string, React.CSSProperties> = {
  shell:          { fontFamily: "Georgia,'Times New Roman',serif", background: "#f5edd8", minHeight: "100dvh", maxWidth: 420, margin: "0 auto", position: "relative" },
  header:         { textAlign: "center", padding: "18px 16px 14px", borderBottom: "1px solid #c8b99a", background: "#f0e8cc" },
  headerEyebrow:  { fontSize: 9, letterSpacing: "3px", color: "#8a7a62", textTransform: "uppercase", marginBottom: 4 },
  headerTitle:    { fontSize: 22, fontWeight: "bold", letterSpacing: "3px", color: "#2c2416", textTransform: "uppercase" },
  headerDate:     { fontSize: 10, color: "#8a7a62", marginTop: 4, letterSpacing: "1px" },
  headerStreak:   { fontSize: 9, color: "#8a7a62", marginTop: 4, letterSpacing: "2px" },
  main:           { overflowY: "auto", minHeight: "calc(100dvh - 130px)", WebkitOverflowScrolling: "touch", overscrollBehaviorY: "contain" },
  nav:            { position: "fixed", bottom: 0, left: "50%", transform: "translateX(-50%)", width: 420, display: "flex", background: "#f0e8cc", borderTop: "1px solid #c8b99a" },
  navBtn:         { flex: 1, padding: "14px 8px", border: "none", fontFamily: "Georgia,serif", fontSize: 10, letterSpacing: "2px", cursor: "pointer", transition: "all 0.15s" },
  empty:          { display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", minHeight: "60dvh", padding: 32, textAlign: "center" },
  emptyIcon:      { fontSize: 48, color: "#c8b99a", marginBottom: 16, lineHeight: "1" },
  emptyTitle:     { fontSize: 14, letterSpacing: "2px", color: "#2c2416", textTransform: "uppercase", marginBottom: 8 },
  emptySub:       { fontSize: 12, color: "#8a7a62", lineHeight: "1.6", marginBottom: 24 },
  emptyBtn:       { padding: "12px 24px", background: "#2c2416", color: "#f0ead8", border: "none", fontFamily: "Georgia,serif", fontSize: 11, letterSpacing: "2px", cursor: "pointer" },
  count:          { textAlign: "center", marginTop: 14, fontSize: 10, letterSpacing: "2px", color: "#8a7a62", textTransform: "uppercase" },
  selectorHeader: { display: "flex", justifyContent: "space-between", alignItems: "center", padding: "12px 0", fontSize: 10, letterSpacing: "2px", color: "#8a7a62", textTransform: "uppercase", borderBottom: "1px solid #c8b99a" },
  doneBtn:        { padding: "6px 14px", background: "#2c2416", color: "#f0ead8", border: "none", fontFamily: "Georgia,serif", fontSize: 10, letterSpacing: "1px", cursor: "pointer" },
  selectorRow:    { display: "flex", alignItems: "center", gap: 12, padding: "8px 16px", borderBottom: "1px solid", cursor: "pointer", fontFamily: "Georgia,serif" },
  backBtn:        { display: "block", padding: "10px 16px", background: "none", border: "none", borderBottom: "1px solid #c8b99a", width: "100%", textAlign: "left", fontFamily: "Georgia,serif", fontSize: 11, letterSpacing: "1px", color: "#8a7a62", cursor: "pointer" },
  historyCard:    { background: "#ede5d0", border: "1px solid #c8b99a", padding: 14, marginBottom: 10, cursor: "pointer" },
  historyDate:    { fontSize: 11, letterSpacing: "1px", color: "#2c2416", textTransform: "uppercase", fontWeight: "bold" },
  historyCount:   { fontSize: 9, letterSpacing: "2px", color: "#8a7a62", textTransform: "uppercase" },
  zoomOverlay:    { position: "fixed", inset: 0, background: "rgba(44,36,22,0.88)", display: "flex", alignItems: "center", justifyContent: "center", zIndex: 1000, padding: 24 },
  zoomCard:       { background: "#f0e8d4", border: "1px solid #d4c5a6", padding: 20, maxWidth: 340, width: "100%", position: "relative" },
  zoomClose:      { position: "absolute", top: 8, right: 12, background: "none", border: "none", fontSize: 28, color: "#2c2416", cursor: "pointer", fontFamily: "Georgia,serif", lineHeight: "1" },
  zoomImgBox:     { width: "100%", aspectRatio: "1", background: "#fff", marginBottom: 16 },
  zoomName:       { textAlign: "center", fontSize: 18, letterSpacing: "2px", color: "#2c2416", textTransform: "uppercase", fontFamily: "Georgia,serif", marginBottom: 6 },
  zoomLatin:      { textAlign: "center", fontSize: 12, color: "#8a7a62", fontStyle: "italic", fontFamily: "Georgia,serif", marginBottom: 16 },
  zoomDesc:       { fontSize: 12, color: "#2c2416", fontFamily: "Georgia,serif", lineHeight: "1.6", marginBottom: 12, textAlign: "center" },
  zoomFact:       { fontSize: 11, color: "#8a7a62", fontFamily: "Georgia,serif", lineHeight: "1.6", fontStyle: "italic", borderTop: "1px solid #d4c5a6", paddingTop: 12, textAlign: "center" },
};
