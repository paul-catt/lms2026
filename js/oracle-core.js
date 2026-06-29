// ── oracle-core.js ────────────────────────────────────────────────────────────
// Shared oracle algorithm — loaded by player.html and admin.html
// Functions: getRoundMode, getEliteIds, buildOraclePool, getOraclePickAdvice
// ─────────────────────────────────────────────────────────────────────────────

const ORACLE_KO_ROUNDS    = ['Round of 32','Round of 16','Quarter Finals','Quarter-Final','Semi Finals','Semi-Final','Final'];
const ORACLE_LATE_ROUNDS  = ['Quarter Finals','Quarter-Final','Semi Finals','Semi-Final','Final'];
const ORACLE_FINAL_ROUNDS = ['Semi Finals','Semi-Final','Final'];

// Per-round fixture coverage config.
// expected:    total matches in a complete round
// maxPicks:    Oracle's ceiling when fully scheduled
// minCoverage: fraction of expected matches that must be confirmed before any pick
const ORACLE_ROUND_CONFIG = {
  'Round of 32':   { expected: 16, maxPicks: 1, minCoverage: 0.40 },
  'Round of 16':   { expected: 8,  maxPicks: 1, minCoverage: 0.40 },
  'Quarter Finals':{ expected: 4,  maxPicks: 1, minCoverage: 0.50 },
  'Quarter-Final': { expected: 4,  maxPicks: 1, minCoverage: 0.50 },
  'Semi Finals':   { expected: 2,  maxPicks: 1, minCoverage: 0.50 },
  'Semi-Final':    { expected: 2,  maxPicks: 1, minCoverage: 0.50 },
  'Final':         { expected: 1,  maxPicks: 1, minCoverage: 1.00 },
};

// ── getOraclePickAdvice ───────────────────────────────────────────────────────
// Returns how many picks Oracle should make given fixture coverage.
// Call BEFORE buildOraclePool; if count === 0 skip the pool entirely.
//
// round   — { id, name, round_type }
// matches — fixtures array for this round (same as passed to buildOraclePool)
//
// Returns: { count, coverage, explanation }
//   count       — recommended picks (null = group stage, no throttle applied)
//   coverage    — fraction of expected matches scheduled (null for group)
//   explanation — human-readable reason, or null if no throttle in effect
function getOraclePickAdvice(round, matches) {
  const cfg = ORACLE_ROUND_CONFIG[round && round.name];
  if (!cfg) return { count: null, coverage: null, explanation: null }; // group stage

  const scheduled = (matches || []).length;
  const coverage  = scheduled / cfg.expected;
  const pct       = Math.round(coverage * 100);

  if (coverage < cfg.minCoverage) {
    return {
      count: 0,
      coverage,
      explanation: `Only ${scheduled} of ${cfg.expected} ${round.name} fixtures confirmed (${pct}%) — not enough to make confident picks yet. Check back as more games are scheduled.`,
    };
  }

  if (coverage < 0.60) {
    return {
      count: Math.min(1, cfg.maxPicks),
      coverage,
      explanation: `${pct}% of ${round.name} fixtures confirmed — picking just the top-rated option for now.`,
    };
  }

  if (coverage < 0.80) {
    const count = Math.min(2, cfg.maxPicks);
    return {
      count,
      coverage,
      explanation: count < 2 ? null
        : `${pct}% of ${round.name} fixtures confirmed — picking top 2. More options may appear as remaining fixtures are scheduled.`,
    };
  }

  // ≥80% — full pick quota
  return { count: cfg.maxPicks, coverage, explanation: null };
}

function getRoundMode(round) {
  if (!round) return 'group';
  if (ORACLE_FINAL_ROUNDS.includes(round.name)) return 'final';  // SF+: survival only
  if (ORACLE_KO_ROUNDS.includes(round.name))    return 'ko';     // R32/R16/QF: save on
  return 'group';                                                  // GP1-3: max save
}

// Stage-aware elite save tier
function getEliteIds(allTeams, mode, roundName) {
  if (mode === 'final') return new Set();
  if (mode === 'ko') {
    if (roundName === 'Quarter Finals' || roundName === 'Quarter-Final')
      return new Set(allTeams.filter(t => t.odds_rank && t.odds_rank <= 3).map(t => t.id));
    if (roundName === 'Semi Finals' || roundName === 'Semi-Final')
      return new Set(allTeams.filter(t => t.odds_rank && t.odds_rank <= 2).map(t => t.id));
    return new Set(allTeams.filter(t => t.band === 'favourite').map(t => t.id));
  }
  return new Set();
}

// ── Main pool builder ─────────────────────────────────────────────────────────
// available      — teams not yet used by this player + not eliminated
// round          — { id, name, round_type }
// matches        — fixtures for this round with nested home_team / away_team
// outrightOddsMap — { team_id: decimal_odds } (latest per team from team_odds)
// allTeams       — full 48-team list (for elite-ids calculation)
//
// Returns array of scored entries sorted highest-to-lowest:
//   { team, reasonCode, opponent, stars, kickoff, isElite, myH2h }
function buildOraclePool(available, round, matches, outrightOddsMap, allTeams) {
  const mode    = getRoundMode(round);
  const isGroup = mode === 'group';

  const opponentMap = {};
  const h2hOddsMap  = {};
  const kickoffMap  = {};

  matches.forEach(m => {
    if (m.home_team && m.away_team) {
      opponentMap[m.home_team_id] = m.away_team;
      opponentMap[m.away_team_id] = m.home_team;
      h2hOddsMap[m.home_team_id]  = parseFloat(m.odds_home) || null;
      h2hOddsMap[m.away_team_id]  = parseFloat(m.odds_away) || null;
      kickoffMap[m.home_team_id]  = m.kickoff;
      kickoffMap[m.away_team_id]  = m.kickoff;
    }
  });

  const fixtureIds = new Set(Object.keys(opponentMap));
  const candidates = !isGroup
    ? available.filter(t => fixtureIds.has(t.id))
    : available;

  if (candidates.length === 0) return [];

  const eliteIds = getEliteIds(allTeams || [], mode, round.name);

  const pool5 = [], pool4 = [], pool3 = [], pool2 = [], poolFallback = [];

  candidates.forEach(t => {
    const opp     = opponentMap[t.id] || null;
    const myH2h   = h2hOddsMap[t.id]  || null;
    const oppH2h  = opp ? (h2hOddsMap[opp.id] || null) : null;
    const kickoff = kickoffMap[t.id]   || null;
    const isElite = eliteIds.has(t.id);
    const isLS    = !!t.is_longshot;
    const oppBand = opp ? opp.band : null;
    const myRank  = t.odds_rank || 99;
    const oppRank = opp ? (opp.odds_rank || 99) : 99;
    const isFav   = t.band === 'favourite';
    const isDH    = t.band === 'dark_horse';

    let winStrong, winLikely, winFav, coinFlip;
    if (myH2h) {
      winStrong = myH2h < 2.0;
      winLikely = myH2h < 2.5;
      winFav    = myH2h < 3.5;
      coinFlip  = myH2h >= 3.5 && myH2h < 5.5;
    } else {
      const rankGap = oppRank - myRank;
      winStrong = rankGap >= 20;
      winLikely = rankGap >= 10;
      winFav    = rankGap >= 3;
      coinFlip  = Math.abs(rankGap) <= 4;
    }

    const oppWeak = oppBand === 'no_hoper' || oppRank >= 36 || (oppH2h && oppH2h > 5.0);

    const entry = (reasonCode, stars) => ({
      team: t, reasonCode, opponent: opp, stars, kickoff, isElite, myH2h,
    });

    if (isGroup) {
      if (isFav) return; // Favourites excluded from group picks
      if (isLS && oppWeak && winStrong) { pool5.push(entry('G_BONUS_STRONG', 5)); return; }
      if (isLS && oppWeak)              { pool4.push(entry('G_BONUS_WEAK',  4)); return; }
      if (isDH && winStrong && oppWeak) { pool4.push(entry('G_DH_STRONG',   4)); return; }
      if (isLS && (winFav || winLikely || coinFlip)) { pool3.push(entry('G_BONUS_MID', 3)); return; }
      if (isLS)                                       { pool3.push(entry('G_BONUS_MID', 3)); return; }
      if (winFav || winLikely || coinFlip)            { pool3.push(entry('G_SAFE_BURN', 3)); return; }
      poolFallback.push(entry('G_DAMAGE', 2));

    } else if (mode === 'ko') {
      if (isDH && winStrong && oppWeak)  { pool5.push(entry('K_DH_STRONG',   5)); return; }
      if (isDH && winLikely)             { pool4.push(entry('K_DH_MID',      4)); return; }
      if (isFav && winStrong && oppWeak) { pool4.push(entry('K_FAV_SAVE',    4)); return; }
      if (isFav)                         { pool3.push(entry('K_FAV_WARN',    3)); return; }
      if (isLS && winStrong && oppWeak)  { pool3.push(entry('K_BONUS_KO',    3)); return; }
      if (isLS)                          { pool2.push(entry('K_BONUS_RISKY', 2)); return; }
      if (winFav || coinFlip)            { pool2.push(entry('K_COINFLIP',    2)); return; }
      const isLateKO = ORACLE_LATE_ROUNDS.includes(round.name);
      poolFallback.push(entry(isLateKO ? 'K_DAMAGE_LATE' : 'K_DAMAGE', 1));

    } else {
      // mode === 'final' (QF+)
      if (winStrong)              { pool5.push(entry('K_LATE_STRONG', 5)); return; }
      if (isElite && winLikely)   { pool4.push(entry('K_QF_SAVE',    4)); return; }
      if (winLikely || winFav)    { pool4.push(entry('K_LATE_MID',   4)); return; }
      if (isElite)                { pool3.push(entry('K_QF_SAVE',    3)); return; }
      if (coinFlip)               { pool2.push(entry('K_COINFLIP',   2)); return; }
      poolFallback.push(entry('K_DAMAGE_LATE', 1));
    }
  });

  return [...pool5, ...pool4, ...pool3, ...pool2, ...poolFallback];
}
