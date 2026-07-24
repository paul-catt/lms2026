--
-- PostgreSQL database dump
--

\restrict 8NzBRQ5s6svd2ndhIUr7AWE7Cz9Xp3hAdomNu35OX1lHQdCu1kfcOoodF0fq5K6

-- Dumped from database version 17.6
-- Dumped by pg_dump version 18.4

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA public;


--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA public IS 'standard public schema';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: admin_users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.admin_users (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    username text NOT NULL,
    password_hash text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: app_config; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.app_config (
    key text NOT NULL,
    value text
);


--
-- Name: bracket_predictions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.bracket_predictions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    data jsonb NOT NULL,
    label text,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: default_pool; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.default_pool (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    team_id uuid NOT NULL,
    priority_order integer NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: ko_progression; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ko_progression (
    match_number integer NOT NULL,
    next_match_number integer NOT NULL,
    slot text NOT NULL,
    loser_next_match_number integer,
    loser_slot text,
    CONSTRAINT ko_progression_loser_slot_check CHECK ((loser_slot = ANY (ARRAY['home'::text, 'away'::text]))),
    CONSTRAINT ko_progression_slot_check CHECK ((slot = ANY (ARRAY['home'::text, 'away'::text])))
);


--
-- Name: leaderboard_snapshots; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.leaderboard_snapshots (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    round_id uuid,
    player_id uuid,
    "position" integer,
    total_points integer,
    snapshot_taken_at timestamp with time zone DEFAULT now(),
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: matches; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.matches (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    round_id uuid NOT NULL,
    home_team_id uuid,
    away_team_id uuid,
    kickoff timestamp with time zone NOT NULL,
    home_score integer,
    away_score integer,
    status text DEFAULT 'scheduled'::text NOT NULL,
    odds_home numeric(10,2),
    odds_draw numeric(10,2),
    odds_away numeric(10,2),
    odds_updated_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    is_third_place boolean DEFAULT false,
    pens_winner_id uuid,
    match_number integer,
    venue text,
    confirmed boolean DEFAULT false,
    elapsed_minutes integer,
    api_status text,
    odds_home_prev numeric,
    odds_draw_prev numeric,
    odds_away_prev numeric,
    expected_home_score integer,
    expected_away_score integer,
    CONSTRAINT matches_status_check CHECK ((status = ANY (ARRAY['scheduled'::text, 'live'::text, 'complete'::text])))
);


--
-- Name: pick_results; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pick_results (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    pick_id uuid NOT NULL,
    match_id uuid NOT NULL,
    base_points integer DEFAULT 0 NOT NULL,
    longshot_bonus integer DEFAULT 0 NOT NULL,
    multiplier_applied integer DEFAULT 2 NOT NULL,
    points_earned integer DEFAULT 0 NOT NULL,
    match_result text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT pick_results_base_points_check CHECK ((base_points = ANY (ARRAY[0, 1, 2, 3]))),
    CONSTRAINT pick_results_longshot_bonus_check CHECK ((longshot_bonus = ANY (ARRAY[0, 1]))),
    CONSTRAINT pick_results_match_result_check CHECK ((match_result = ANY (ARRAY['win'::text, 'draw'::text, 'loss'::text])))
);


--
-- Name: picks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.picks (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    player_id uuid NOT NULL,
    round_id uuid NOT NULL,
    team_id uuid NOT NULL,
    multiplier integer DEFAULT 2 NOT NULL,
    is_assigned boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    oracle_pick boolean DEFAULT false,
    CONSTRAINT picks_multiplier_check CHECK ((multiplier = ANY (ARRAY[2, 3])))
);


--
-- Name: players; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.players (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    name text NOT NULL,
    slug text NOT NULL,
    total_goals_prediction integer,
    is_active boolean DEFAULT true NOT NULL,
    is_eliminated boolean DEFAULT false NOT NULL,
    eliminated_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    has_paid boolean DEFAULT false,
    eliminated_in_round_id uuid,
    display_name text,
    is_bot boolean DEFAULT false NOT NULL,
    CONSTRAINT elim_consistency CHECK ((((is_eliminated = false) AND (eliminated_in_round_id IS NULL)) OR ((is_eliminated = true) AND (eliminated_in_round_id IS NOT NULL))))
);


--
-- Name: rounds; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.rounds (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    name text NOT NULL,
    round_type text NOT NULL,
    phase_number integer,
    deadline timestamp with time zone NOT NULL,
    is_complete boolean DEFAULT false NOT NULL,
    sort_order integer NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT rounds_round_type_check CHECK ((round_type = ANY (ARRAY['group'::text, 'knockout'::text])))
);


--
-- Name: player_furthest_round; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.player_furthest_round AS
 SELECT player_id,
    max(furthest_round) AS furthest_round
   FROM ( SELECT pk.player_id,
            max(r.sort_order) AS furthest_round
           FROM ((public.picks pk
             JOIN public.rounds r ON ((r.id = pk.round_id)))
             JOIN public.pick_results pr ON ((pr.pick_id = pk.id)))
          WHERE (pr.match_result IS NOT NULL)
          GROUP BY pk.player_id
        UNION ALL
         SELECT p.id AS player_id,
            r.sort_order AS furthest_round
           FROM (public.players p
             JOIN public.rounds r ON ((r.id = p.eliminated_in_round_id)))
          WHERE (p.eliminated_in_round_id IS NOT NULL)) sub
  GROUP BY player_id;


--
-- Name: teams; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.teams (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    name text NOT NULL,
    flag_emoji text NOT NULL,
    is_longshot boolean DEFAULT false NOT NULL,
    odds_rank integer,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    pot integer,
    is_eliminated boolean DEFAULT false,
    band text,
    eliminated_in_round_id uuid,
    bracket_half text,
    CONSTRAINT teams_bracket_half_check CHECK ((bracket_half = ANY (ARRAY['top'::text, 'bottom'::text])))
);


--
-- Name: player_teams_used; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.player_teams_used AS
 SELECT pk.player_id,
    t.id AS team_id,
    t.name AS team_name,
    t.flag_emoji,
    t.is_longshot,
    pk.round_id,
    r.name AS round_name,
    pk.multiplier,
    pr.points_earned,
    pr.match_result,
    m.pens_winner_id
   FROM ((((public.picks pk
     JOIN public.teams t ON ((t.id = pk.team_id)))
     JOIN public.rounds r ON ((r.id = pk.round_id)))
     LEFT JOIN public.pick_results pr ON ((pr.pick_id = pk.id)))
     LEFT JOIN public.matches m ON ((m.id = pr.match_id)));


--
-- Name: player_gd; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.player_gd AS
 SELECT p.player_id,
    sum(
        CASE
            WHEN (pr.match_result IS NULL) THEN 0
            WHEN (p.team_id = m.home_team_id) THEN (m.home_score - m.away_score)
            ELSE (m.away_score - m.home_score)
        END) AS gd
   FROM (((public.player_teams_used p
     JOIN public.picks pk ON (((pk.player_id = p.player_id) AND (pk.team_id = p.team_id))))
     JOIN public.pick_results pr ON ((pr.pick_id = pk.id)))
     JOIN public.matches m ON ((m.id = pr.match_id)))
  GROUP BY p.player_id;


--
-- Name: player_scores; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.player_scores AS
 SELECT p.id AS player_id,
    p.name,
    p.slug,
    p.display_name,
    p.is_eliminated,
    p.eliminated_in_round_id,
    p.total_goals_prediction,
    p.is_bot,
    COALESCE(sum((pr.points_earned + pr.longshot_bonus)), (0)::bigint) AS total_points,
    COALESCE(sum(
        CASE
            WHEN (r.round_type = 'knockout'::text) THEN (pr.points_earned + pr.longshot_bonus)
            ELSE 0
        END), (0)::bigint) AS knockout_points,
    count(DISTINCT pk.team_id) AS teams_used,
    count(DISTINCT
        CASE
            WHEN (pr.match_result IS NOT NULL) THEN pk.id
            ELSE NULL::uuid
        END) AS rounds_played
   FROM (((public.players p
     LEFT JOIN public.picks pk ON ((pk.player_id = p.id)))
     LEFT JOIN public.pick_results pr ON ((pr.pick_id = pk.id)))
     LEFT JOIN public.rounds r ON ((r.id = pk.round_id)))
  GROUP BY p.id, p.name, p.slug, p.display_name, p.is_eliminated, p.eliminated_in_round_id, p.total_goals_prediction, p.is_bot;


--
-- Name: push_subscriptions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.push_subscriptions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    player_id uuid,
    subscription jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: team_odds; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.team_odds (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    team_id uuid,
    odds_decimal numeric,
    odds_fractional text,
    fetched_at timestamp with time zone DEFAULT now()
);


--
-- Name: todays_match_picks; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.todays_match_picks AS
 SELECT m.id AS match_id,
    m.kickoff,
    m.home_score,
    m.away_score,
    m.status,
    m.odds_home,
    m.odds_draw,
    m.odds_away,
    ht.name AS home_team,
    ht.flag_emoji AS home_flag,
    at2.name AS away_team,
    at2.flag_emoji AS away_flag,
    r.name AS round_name,
    p.name AS player_name,
    p.slug AS player_slug,
    pk.multiplier,
        CASE
            WHEN (pk.team_id = m.home_team_id) THEN 'home'::text
            WHEN (pk.team_id = m.away_team_id) THEN 'away'::text
            ELSE NULL::text
        END AS picked_side,
    t.is_longshot AS pick_is_longshot,
    pr.points_earned
   FROM (((((((public.matches m
     JOIN public.rounds r ON ((r.id = m.round_id)))
     JOIN public.teams ht ON ((ht.id = m.home_team_id)))
     JOIN public.teams at2 ON ((at2.id = m.away_team_id)))
     JOIN public.picks pk ON (((pk.round_id = m.round_id) AND ((pk.team_id = m.home_team_id) OR (pk.team_id = m.away_team_id)))))
     JOIN public.players p ON ((p.id = pk.player_id)))
     JOIN public.teams t ON ((t.id = pk.team_id)))
     LEFT JOIN public.pick_results pr ON (((pr.pick_id = pk.id) AND (pr.match_id = m.id))))
  WHERE (date((m.kickoff AT TIME ZONE 'UTC'::text)) = CURRENT_DATE);


--
-- Data for Name: admin_users; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.admin_users (id, username, password_hash, created_at) FROM stdin;
\.


--
-- Data for Name: app_config; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.app_config (key, value) FROM stdin;
test_date_override	
group_position_locks	[{"teamId":"95b1e39e-97c3-4d45-9714-3f507d7c52f1","status":"advance"},{"teamId":"f2c7a0c3-9a4c-4e3f-92a3-39abff0ce8e2","status":"advance"},{"teamId":"cffa413c-8c76-45a6-843e-87c34e78e45a","status":"advance"},{"teamId":"e176dd2c-4446-4811-b4cc-fc28e9c2ab25","status":"advance"},{"teamId":"20e98c7a-4548-44f8-964d-7aba42ae7624","status":"advance"},{"teamId":"6527ec07-bc6b-4b53-8bff-90b6f622aece","status":"advance"},{"teamId":"e171e736-56f2-44fa-92b5-b0653ea2ce2a","status":"advance"},{"teamId":"7f560d60-00fc-46e1-b81b-4e7234b7cb04","status":"out"},{"teamId":"aa0baf4e-af82-4020-9093-715971d63105","status":"out"},{"teamId":"a1cbc3f2-826a-4c04-803b-b5c2930d3c42","status":"out"},{"teamId":"87881cf2-7a14-4afa-9912-0ef5b2672387","status":"out"},{"teamId":"8d109cbf-133f-496a-b5b7-3f75a0ec1dcd","status":"out"},{"teamId":"ee8ecff9-d0b1-4aa8-ab21-da08a6c9229a","status":"out"},{"teamId":"1b2fe4cc-3105-4e0b-b1ff-06f91c466ef7","status":"advance"},{"teamId":"eaca3063-d90c-4007-b3d8-ba829b3ee14e","status":"advance"},{"teamId":"4976e7fd-9b45-4cc7-b741-fe801fcee2d0","status":"advance"},{"teamId":"1270b02b-ff92-4068-a52e-ae90bcae805b","status":"advance"}]
tiebreak_overrides	[{"higher":"4976e7fd-9b45-4cc7-b741-fe801fcee2d0","lower":"c8e5c035-af92-4497-b96c-82f2c0a15214"}]
\.


--
-- Data for Name: bracket_predictions; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.bracket_predictions (id, data, label, created_at) FROM stdin;
9ad0275b-39d1-45ac-9139-039134766dc0	{"qf": [97, 98, 99, 100], "sf": [101, 102], "r16": [89, 90, 93, 94, 91, 92, 95, 96], "r32": [74, 77, 73, 75, 83, 84, 81, 82, 76, 78, 79, 80, 86, 88, 85, 87], "final": [104], "progression": {"73": {"next": 90, "slot": "home"}, "74": {"next": 89, "slot": "home"}, "75": {"next": 90, "slot": "away"}, "76": {"next": 91, "slot": "home"}, "77": {"next": 89, "slot": "away"}, "78": {"next": 91, "slot": "away"}, "79": {"next": 92, "slot": "home"}, "80": {"next": 92, "slot": "away"}, "81": {"next": 94, "slot": "home"}, "82": {"next": 94, "slot": "away"}, "83": {"next": 93, "slot": "away"}, "84": {"next": 93, "slot": "home"}, "85": {"next": 96, "slot": "home"}, "86": {"next": 95, "slot": "home"}, "87": {"next": 96, "slot": "away"}, "88": {"next": 95, "slot": "away"}, "89": {"next": 97, "slot": "home"}, "90": {"next": 97, "slot": "away"}, "91": {"next": 99, "slot": "home"}, "92": {"next": 99, "slot": "away"}, "93": {"next": 98, "slot": "home"}, "94": {"next": 98, "slot": "away"}, "95": {"next": 100, "slot": "home"}, "96": {"next": 100, "slot": "away"}, "97": {"next": 101, "slot": "home"}, "98": {"next": 101, "slot": "away"}, "99": {"next": 102, "slot": "home"}, "100": {"next": 102, "slot": "away"}, "101": {"next": 104, "slot": "home", "loser_next": 103, "loser_slot": "home"}, "102": {"next": 104, "slot": "away", "loser_next": 103, "loser_slot": "away"}}, "third_place": [103], "predicted_teams": {"73": {"away": {"flag": "🇨🇦", "name": "Canada"}, "home": {"flag": "🇰🇷", "name": "South Korea"}}, "74": {"away": {"flag": "🇺🇸", "name": "USA"}, "home": {"flag": "🇩🇪", "name": "Germany"}}, "75": {"away": {"flag": "🇲🇦", "name": "Morocco"}, "home": {"flag": "🇳🇱", "name": "Netherlands"}}, "76": {"away": {"flag": "🇯🇵", "name": "Japan"}, "home": {"flag": "🇧🇷", "name": "Brazil"}}, "77": {"away": {"flag": "🇪🇸", "name": "Spain"}, "home": {"flag": "🇫🇷", "name": "France"}}, "78": {"away": {"flag": "🇸🇳", "name": "Senegal"}, "home": {"flag": "🇨🇮", "name": "Ivory Coast"}}, "79": {"away": {"flag": "🇪🇨", "name": "Ecuador"}, "home": {"flag": "🇲🇽", "name": "Mexico"}}, "80": {"away": {"flag": "🇺🇿", "name": "Uzbekistan"}, "home": {"flag": "🇭🇷", "name": "Croatia"}}, "81": {"away": {"flag": "🇧🇦", "name": "Bosnia/Herzeg"}, "home": {"flag": "🇵🇾", "name": "Paraguay"}}, "82": {"away": {"flag": "🇨🇿", "name": "Czech Rep"}, "home": {"flag": "🇧🇪", "name": "Belgium"}}, "83": {"away": {"flag": "🏴󠁧󠁢󠁥󠁮󠁧󠁿", "name": "England"}, "home": {"flag": "🇨🇴", "name": "Colombia"}}, "84": {"away": {"flag": "🇩🇿", "name": "Algeria"}, "home": {"flag": "🇺🇾", "name": "Uruguay"}}, "85": {"away": {"flag": "🇦🇹", "name": "Austria"}, "home": {"flag": "🇨🇭", "name": "Switzerland"}}, "86": {"away": {"flag": "🇸🇦", "name": "Saudi Arabia"}, "home": {"flag": "🇦🇷", "name": "Argentina"}}, "87": {"away": {"flag": "🇳🇴", "name": "Norway"}, "home": {"flag": "🇵🇹", "name": "Portugal"}}, "88": {"away": {"flag": "🇪🇬", "name": "Egypt"}, "home": {"flag": "🇦🇺", "name": "Australia"}}}}	\N	2026-05-06 18:20:09.572902+00
a3c47211-3d45-48a4-87c3-521d69e89b9d	{"qf": [97, 98, 99, 100], "sf": [101, 102], "r16": [89, 90, 93, 94, 91, 92, 95, 96], "r32": [74, 77, 73, 75, 83, 84, 81, 82, 76, 78, 79, 80, 86, 88, 85, 87], "final": [104], "progression": {"73": {"next": 90, "slot": "home"}, "74": {"next": 89, "slot": "home"}, "75": {"next": 90, "slot": "away"}, "76": {"next": 91, "slot": "home"}, "77": {"next": 89, "slot": "away"}, "78": {"next": 91, "slot": "away"}, "79": {"next": 92, "slot": "home"}, "80": {"next": 92, "slot": "away"}, "81": {"next": 94, "slot": "home"}, "82": {"next": 94, "slot": "away"}, "83": {"next": 93, "slot": "away"}, "84": {"next": 93, "slot": "home"}, "85": {"next": 96, "slot": "home"}, "86": {"next": 95, "slot": "home"}, "87": {"next": 96, "slot": "away"}, "88": {"next": 95, "slot": "away"}, "89": {"next": 97, "slot": "home"}, "90": {"next": 97, "slot": "away"}, "91": {"next": 99, "slot": "home"}, "92": {"next": 99, "slot": "away"}, "93": {"next": 98, "slot": "home"}, "94": {"next": 98, "slot": "away"}, "95": {"next": 100, "slot": "home"}, "96": {"next": 100, "slot": "away"}, "97": {"next": 101, "slot": "home"}, "98": {"next": 101, "slot": "away"}, "99": {"next": 102, "slot": "home"}, "100": {"next": 102, "slot": "away"}, "101": {"next": 104, "slot": "home", "loser_next": 103, "loser_slot": "home"}, "102": {"next": 104, "slot": "away", "loser_next": 103, "loser_slot": "away"}}, "third_place": [103], "predicted_teams": {"73": {"away": {"flag": "🇨🇦", "name": "Canada"}, "home": {"flag": "🇲🇽", "name": "Mexico"}}, "74": {"away": {"flag": "🇺🇸", "name": "USA"}, "home": {"flag": "🇩🇪", "name": "Germany"}}, "75": {"away": {"flag": "🇲🇦", "name": "Morocco"}, "home": {"flag": "🇳🇱", "name": "Netherlands"}}, "76": {"away": {"flag": "🇯🇵", "name": "Japan"}, "home": {"flag": "🇧🇷", "name": "Brazil"}}, "77": {"away": {"flag": "🇪🇬", "name": "Egypt"}, "home": {"flag": "🇫🇷", "name": "France"}}, "78": {"away": {"flag": "🇸🇳", "name": "Senegal"}, "home": {"flag": "🇨🇮", "name": "Ivory Coast"}}, "79": {"away": {"flag": "🇸🇦", "name": "Saudi Arabia"}, "home": {"flag": "🇿🇦", "name": "South Africa"}}, "80": {"away": {"flag": "🇳🇴", "name": "Norway"}, "home": {"flag": "🇭🇷", "name": "Croatia"}}, "81": {"away": {"flag": "🇧🇦", "name": "Bosnia/Herzeg"}, "home": {"flag": "🇵🇾", "name": "Paraguay"}}, "82": {"away": {"flag": "🇨🇿", "name": "Czech Rep"}, "home": {"flag": "🇧🇪", "name": "Belgium"}}, "83": {"away": {"flag": "🏴󠁧󠁢󠁥󠁮󠁧󠁿", "name": "England"}, "home": {"flag": "🇨🇴", "name": "Colombia"}}, "84": {"away": {"flag": "🇩🇿", "name": "Algeria"}, "home": {"flag": "🇺🇾", "name": "Uruguay"}}, "85": {"away": {"flag": "🇦🇹", "name": "Austria"}, "home": {"flag": "🇨🇭", "name": "Switzerland"}}, "86": {"away": {"flag": "🇪🇸", "name": "Spain"}, "home": {"flag": "🇦🇷", "name": "Argentina"}}, "87": {"away": {"flag": "🇪🇨", "name": "Ecuador"}, "home": {"flag": "🇵🇹", "name": "Portugal"}}, "88": {"away": {"flag": "🇮🇷", "name": "Iran"}, "home": {"flag": "🇦🇺", "name": "Australia"}}}}	29 May	2026-05-29 09:40:35.045021+00
7e919092-53d2-40ed-b113-22932e4aa508	{"qf": [97, 98, 99, 100], "sf": [101, 102], "r16": [89, 90, 93, 94, 91, 92, 95, 96], "r32": [74, 77, 73, 75, 83, 84, 81, 82, 76, 78, 79, 80, 86, 88, 85, 87], "final": [104], "progression": {"73": {"next": 90, "slot": "home"}, "74": {"next": 89, "slot": "home"}, "75": {"next": 90, "slot": "away"}, "76": {"next": 91, "slot": "home"}, "77": {"next": 89, "slot": "away"}, "78": {"next": 91, "slot": "away"}, "79": {"next": 92, "slot": "home"}, "80": {"next": 92, "slot": "away"}, "81": {"next": 94, "slot": "home"}, "82": {"next": 94, "slot": "away"}, "83": {"next": 93, "slot": "away"}, "84": {"next": 93, "slot": "home"}, "85": {"next": 96, "slot": "home"}, "86": {"next": 95, "slot": "home"}, "87": {"next": 96, "slot": "away"}, "88": {"next": 95, "slot": "away"}, "89": {"next": 97, "slot": "home"}, "90": {"next": 97, "slot": "away"}, "91": {"next": 99, "slot": "home"}, "92": {"next": 99, "slot": "away"}, "93": {"next": 98, "slot": "home"}, "94": {"next": 98, "slot": "away"}, "95": {"next": 100, "slot": "home"}, "96": {"next": 100, "slot": "away"}, "97": {"next": 101, "slot": "home"}, "98": {"next": 101, "slot": "away"}, "99": {"next": 102, "slot": "home"}, "100": {"next": 102, "slot": "away"}, "101": {"next": 104, "slot": "home", "loser_next": 103, "loser_slot": "home"}, "102": {"next": 104, "slot": "away", "loser_next": 103, "loser_slot": "away"}}, "third_place": [103], "predicted_teams": {"73": {"away": {"flag": "🇨🇦", "name": "Canada"}, "home": {"flag": "🇨🇿", "name": "Czech Rep"}}, "74": {"away": {"flag": "🏴󠁧󠁢󠁳󠁣󠁴󠁿", "name": "Scotland"}, "home": {"flag": "🇩🇪", "name": "Germany"}}, "75": {"away": {"flag": "🇲🇦", "name": "Morocco"}, "home": {"flag": "🇳🇱", "name": "Netherlands"}}, "76": {"away": {"flag": "🇯🇵", "name": "Japan"}, "home": {"flag": "🇧🇷", "name": "Brazil"}}, "77": {"away": {"flag": "🇵🇾", "name": "Paraguay"}, "home": {"flag": "🇫🇷", "name": "France"}}, "78": {"away": {"flag": "🇸🇳", "name": "Senegal"}, "home": {"flag": "🇨🇮", "name": "Ivory Coast"}}, "79": {"away": {"flag": "🇸🇦", "name": "Saudi Arabia"}, "home": {"flag": "🇲🇽", "name": "Mexico"}}, "80": {"away": {"flag": "🇳🇴", "name": "Norway"}, "home": {"flag": "🏴󠁧󠁢󠁥󠁮󠁧󠁿", "name": "England"}}, "81": {"away": {"flag": "🇦🇹", "name": "Austria"}, "home": {"flag": "🇹🇷", "name": "Turkey"}}, "82": {"away": {"flag": "🇰🇷", "name": "South Korea"}, "home": {"flag": "🇧🇪", "name": "Belgium"}}, "83": {"away": {"flag": "🇭🇷", "name": "Croatia"}, "home": {"flag": "🇨🇴", "name": "Colombia"}}, "84": {"away": {"flag": "🇩🇿", "name": "Algeria"}, "home": {"flag": "🇪🇸", "name": "Spain"}}, "85": {"away": {"flag": "🇮🇷", "name": "Iran"}, "home": {"flag": "🇨🇭", "name": "Switzerland"}}, "86": {"away": {"flag": "🇺🇾", "name": "Uruguay"}, "home": {"flag": "🇦🇷", "name": "Argentina"}}, "87": {"away": {"flag": "🇪🇨", "name": "Ecuador"}, "home": {"flag": "🇵🇹", "name": "Portugal"}}, "88": {"away": {"flag": "🇪🇬", "name": "Egypt"}, "home": {"flag": "🇺🇸", "name": "USA"}}}}	\N	2026-06-07 15:27:59.72709+00
e9fc720d-e4ac-48ef-82ac-4cb86564c6e2	{"qf": [97, 98, 99, 100], "sf": [101, 102], "r16": [89, 90, 93, 94, 91, 92, 95, 96], "r32": [74, 77, 73, 75, 83, 84, 81, 82, 76, 78, 79, 80, 86, 88, 85, 87], "final": [104], "progression": {"73": {"next": 90, "slot": "home"}, "74": {"next": 89, "slot": "home"}, "75": {"next": 90, "slot": "away"}, "76": {"next": 91, "slot": "home"}, "77": {"next": 89, "slot": "away"}, "78": {"next": 91, "slot": "away"}, "79": {"next": 92, "slot": "home"}, "80": {"next": 92, "slot": "away"}, "81": {"next": 94, "slot": "home"}, "82": {"next": 94, "slot": "away"}, "83": {"next": 93, "slot": "away"}, "84": {"next": 93, "slot": "home"}, "85": {"next": 96, "slot": "home"}, "86": {"next": 95, "slot": "home"}, "87": {"next": 96, "slot": "away"}, "88": {"next": 95, "slot": "away"}, "89": {"next": 97, "slot": "home"}, "90": {"next": 97, "slot": "away"}, "91": {"next": 99, "slot": "home"}, "92": {"next": 99, "slot": "away"}, "93": {"next": 98, "slot": "home"}, "94": {"next": 98, "slot": "away"}, "95": {"next": 100, "slot": "home"}, "96": {"next": 100, "slot": "away"}, "97": {"next": 101, "slot": "home"}, "98": {"next": 101, "slot": "away"}, "99": {"next": 102, "slot": "home"}, "100": {"next": 102, "slot": "away"}, "101": {"next": 104, "slot": "home", "loser_next": 103, "loser_slot": "home"}, "102": {"next": 104, "slot": "away", "loser_next": 103, "loser_slot": "away"}}, "third_place": [103], "predicted_teams": {"73": {"away": {"flag": "🇨🇦", "name": "Canada"}, "home": {"flag": "🇰🇷", "name": "South Korea"}}, "74": {"away": {"flag": "🇦🇺", "name": "Australia"}, "home": {"flag": "🇩🇪", "name": "Germany"}}, "75": {"away": {"flag": "🇧🇷", "name": "Brazil"}, "home": {"flag": "🇳🇱", "name": "Netherlands"}}, "76": {"away": {"flag": "🇯🇵", "name": "Japan"}, "home": {"flag": "🇲🇦", "name": "Morocco"}}, "77": {"away": {"flag": "🇸🇪", "name": "Sweden"}, "home": {"flag": "🇫🇷", "name": "France"}}, "78": {"away": {"flag": "🇸🇳", "name": "Senegal"}, "home": {"flag": "🇨🇮", "name": "Ivory Coast"}}, "79": {"away": {"flag": "🇸🇦", "name": "Saudi Arabia"}, "home": {"flag": "🇲🇽", "name": "Mexico"}}, "80": {"away": {"flag": "🇦🇹", "name": "Austria"}, "home": {"flag": "🏴󠁧󠁢󠁥󠁮󠁧󠁿", "name": "England"}}, "81": {"away": {"flag": "🇧🇦", "name": "Bosnia/Herzeg"}, "home": {"flag": "🇺🇸", "name": "USA"}}, "82": {"away": {"flag": "🇨🇿", "name": "Czech Rep"}, "home": {"flag": "🇧🇪", "name": "Belgium"}}, "83": {"away": {"flag": "🇭🇷", "name": "Croatia"}, "home": {"flag": "🇨🇴", "name": "Colombia"}}, "84": {"away": {"flag": "🇩🇿", "name": "Algeria"}, "home": {"flag": "🇪🇸", "name": "Spain"}}, "85": {"away": {"flag": "🇮🇷", "name": "Iran"}, "home": {"flag": "🇨🇭", "name": "Switzerland"}}, "86": {"away": {"flag": "🇺🇾", "name": "Uruguay"}, "home": {"flag": "🇦🇷", "name": "Argentina"}}, "87": {"away": {"flag": "🇳🇴", "name": "Norway"}, "home": {"flag": "🇵🇹", "name": "Portugal"}}, "88": {"away": {"flag": "🇪🇬", "name": "Egypt"}, "home": {"flag": "🇵🇾", "name": "Paraguay"}}}}	\N	2026-06-15 21:56:39.018589+00
07318db2-358d-4c20-97be-9d2d0d3a6a41	{"qf": [97, 98, 99, 100], "sf": [101, 102], "r16": [89, 90, 93, 94, 91, 92, 95, 96], "r32": [74, 77, 73, 75, 83, 84, 81, 82, 76, 78, 79, 80, 86, 88, 85, 87], "final": [104], "progression": {"73": {"next": 90, "slot": "home"}, "74": {"next": 89, "slot": "home"}, "75": {"next": 90, "slot": "away"}, "76": {"next": 91, "slot": "home"}, "77": {"next": 89, "slot": "away"}, "78": {"next": 91, "slot": "away"}, "79": {"next": 92, "slot": "home"}, "80": {"next": 92, "slot": "away"}, "81": {"next": 94, "slot": "home"}, "82": {"next": 94, "slot": "away"}, "83": {"next": 93, "slot": "away"}, "84": {"next": 93, "slot": "home"}, "85": {"next": 96, "slot": "home"}, "86": {"next": 95, "slot": "home"}, "87": {"next": 96, "slot": "away"}, "88": {"next": 95, "slot": "away"}, "89": {"next": 97, "slot": "home"}, "90": {"next": 97, "slot": "away"}, "91": {"next": 99, "slot": "home"}, "92": {"next": 99, "slot": "away"}, "93": {"next": 98, "slot": "home"}, "94": {"next": 98, "slot": "away"}, "95": {"next": 100, "slot": "home"}, "96": {"next": 100, "slot": "away"}, "97": {"next": 101, "slot": "home"}, "98": {"next": 101, "slot": "away"}, "99": {"next": 102, "slot": "home"}, "100": {"next": 102, "slot": "away"}, "101": {"next": 104, "slot": "home", "loser_next": 103, "loser_slot": "home"}, "102": {"next": 104, "slot": "away", "loser_next": 103, "loser_slot": "away"}}, "third_place": [103], "predicted_teams": {"73": {"away": {"flag": "🇨🇦", "name": "Canada"}, "home": {"flag": "🇰🇷", "name": "South Korea"}}, "74": {"away": {"flag": "🇦🇺", "name": "Australia"}, "home": {"flag": "🇩🇪", "name": "Germany"}}, "75": {"away": {"flag": "🇧🇷", "name": "Brazil"}, "home": {"flag": "🇳🇱", "name": "Netherlands"}}, "76": {"away": {"flag": "🇯🇵", "name": "Japan"}, "home": {"flag": "🇲🇦", "name": "Morocco"}}, "77": {"away": {"flag": "🇸🇪", "name": "Sweden"}, "home": {"flag": "🇫🇷", "name": "France"}}, "78": {"away": {"flag": "🇳🇴", "name": "Norway"}, "home": {"flag": "🇨🇮", "name": "Ivory Coast"}}, "79": {"away": {"flag": "🇸🇦", "name": "Saudi Arabia"}, "home": {"flag": "🇲🇽", "name": "Mexico"}}, "80": {"away": {"flag": "🇸🇳", "name": "Senegal"}, "home": {"flag": "🏴󠁧󠁢󠁥󠁮󠁧󠁿", "name": "England"}}, "81": {"away": {"flag": "🇧🇦", "name": "Bosnia/Herzeg"}, "home": {"flag": "🇺🇸", "name": "USA"}}, "82": {"away": {"flag": "🇨🇿", "name": "Czech Rep"}, "home": {"flag": "🇧🇪", "name": "Belgium"}}, "83": {"away": {"flag": "🇭🇷", "name": "Croatia"}, "home": {"flag": "🇨🇴", "name": "Colombia"}}, "84": {"away": {"flag": "🇦🇹", "name": "Austria"}, "home": {"flag": "🇪🇸", "name": "Spain"}}, "85": {"away": {"flag": "🇩🇿", "name": "Algeria"}, "home": {"flag": "🇨🇭", "name": "Switzerland"}}, "86": {"away": {"flag": "🇺🇾", "name": "Uruguay"}, "home": {"flag": "🇦🇷", "name": "Argentina"}}, "87": {"away": {"flag": "🇪🇨", "name": "Ecuador"}, "home": {"flag": "🇵🇹", "name": "Portugal"}}, "88": {"away": {"flag": "🇪🇬", "name": "Egypt"}, "home": {"flag": "🇵🇾", "name": "Paraguay"}}}}	End GP1	2026-06-17 12:08:05.043995+00
\.


--
-- Data for Name: default_pool; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.default_pool (id, team_id, priority_order, created_at) FROM stdin;
73bac5e1-f75e-433e-b630-9f9eaac793f9	52eaa3b4-081b-4393-b291-d69c644c612e	1	2026-04-10 10:58:06.79787+00
fde7993e-d0d7-42e3-8448-54313f42418b	4976e7fd-9b45-4cc7-b741-fe801fcee2d0	2	2026-04-10 10:58:06.79787+00
0bdb31b5-a6b8-47d4-85cf-4a09a00f81e4	4f0f3776-f99f-4c06-9eb4-0acd2825d8c2	3	2026-04-10 10:58:06.79787+00
85e006b7-984f-4877-af31-5f77508a495d	8cccecd8-b1ab-4159-bf35-29ef0db369c4	4	2026-04-10 10:58:06.79787+00
5d27b41b-16c9-471d-9930-34ceaba4894f	d6209663-7a5c-4736-b346-cde299b554b2	5	2026-04-10 10:58:06.79787+00
bf0d43cc-0e03-4d7a-a957-2f21134cd3d9	cd984ce3-2f2c-41d5-a7ba-137060caf8ae	6	2026-04-10 10:58:06.79787+00
afe8d8a9-a166-4854-808b-556610fe97aa	ddd77a2f-eb9f-4a20-8ae4-e1ca55c21893	7	2026-04-10 10:58:06.79787+00
577b3147-18af-4b33-84c8-50a5622acca3	61d8b501-96d1-4043-a2b7-de27e9b137d7	8	2026-04-10 10:58:06.79787+00
95d4a0a9-1898-4cef-a3c0-46d87b6d54b2	54ef8b7c-5afd-4a48-a3b9-d6701dd757f9	9	2026-04-10 10:58:06.79787+00
bf0f6bf4-3dce-400f-87d4-e5a8e236dd01	c8e5c035-af92-4497-b96c-82f2c0a15214	10	2026-04-10 10:58:06.79787+00
a75661c5-b0d2-4376-821a-45341cb6f5ee	52f066d8-0a7a-42c5-8a6b-103ec4ba2c91	11	2026-04-10 10:58:06.79787+00
9b9475f8-4067-4c85-8ae5-82214eee21ab	151a98cf-99e8-4e7a-ab57-396a13db4a72	12	2026-04-10 10:58:06.79787+00
7bd998e2-f24b-47fa-af65-d0a3d6ca1a4b	20160ec3-c507-4fb3-b19d-89cb66c59a98	13	2026-04-10 10:58:06.79787+00
9e342ff8-e36a-42a8-b370-ff1bcec82830	910a4a31-591d-4c32-8b57-b0d0bbde5a26	14	2026-04-10 10:58:06.79787+00
3cc47c9f-01eb-4f84-8755-364a55fec89c	acfbd82a-7005-41b9-9613-606ceefc857e	15	2026-04-10 10:58:06.79787+00
ca6faea1-453d-4a34-a179-fe03e6ab9817	87881cf2-7a14-4afa-9912-0ef5b2672387	16	2026-04-10 10:58:06.79787+00
\.


--
-- Data for Name: ko_progression; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.ko_progression (match_number, next_match_number, slot, loser_next_match_number, loser_slot) FROM stdin;
74	89	home	\N	\N
77	89	away	\N	\N
73	90	home	\N	\N
75	90	away	\N	\N
76	91	home	\N	\N
78	91	away	\N	\N
79	92	home	\N	\N
80	92	away	\N	\N
83	93	home	\N	\N
84	93	away	\N	\N
81	94	home	\N	\N
82	94	away	\N	\N
86	95	home	\N	\N
88	95	away	\N	\N
85	96	home	\N	\N
87	96	away	\N	\N
89	97	home	\N	\N
90	97	away	\N	\N
93	98	home	\N	\N
94	98	away	\N	\N
91	99	home	\N	\N
92	99	away	\N	\N
95	100	home	\N	\N
96	100	away	\N	\N
97	101	home	\N	\N
98	101	away	\N	\N
99	102	home	\N	\N
100	102	away	\N	\N
101	104	home	103	home
102	104	away	103	away
\.


--
-- Data for Name: leaderboard_snapshots; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.leaderboard_snapshots (id, round_id, player_id, "position", total_points, snapshot_taken_at, created_at) FROM stdin;
8a70680c-e132-4e52-adde-cd9353eebd4c	5f39c536-340b-4981-b59a-4a9d7aff9e1e	ed3a6f56-12b3-4f1a-ab83-4744531df4f1	1	18	2026-07-04 03:49:15.880695+00	2026-07-04 03:49:15.880695+00
8a31e090-5adb-43da-84af-a477ac865a81	5f39c536-340b-4981-b59a-4a9d7aff9e1e	e73bedf4-0330-41d0-b1e7-31cb55909eed	2	18	2026-07-04 03:49:15.880695+00	2026-07-04 03:49:15.880695+00
5a54650c-1ba5-48eb-b3c9-51d44c24d798	5f39c536-340b-4981-b59a-4a9d7aff9e1e	3422f6a8-d289-4ce8-8135-b547ff0f9606	3	17	2026-07-04 03:49:15.880695+00	2026-07-04 03:49:15.880695+00
d38e2103-d155-428b-9527-54844563cabd	5f39c536-340b-4981-b59a-4a9d7aff9e1e	b8526be4-5eb8-4f89-b015-699537c368ce	4	17	2026-07-04 03:49:15.880695+00	2026-07-04 03:49:15.880695+00
695addd0-9c0c-4ef7-9ab5-4d1958f8b434	5f39c536-340b-4981-b59a-4a9d7aff9e1e	31780afe-855c-4c9d-9cf6-56e3570c00c4	5	17	2026-07-04 03:49:15.880695+00	2026-07-04 03:49:15.880695+00
0b7878e4-fe57-4b16-a187-b7e389d11468	5f39c536-340b-4981-b59a-4a9d7aff9e1e	5d4ce78f-67ee-4a61-afab-c44ffc6afe91	6	16	2026-07-04 03:49:15.880695+00	2026-07-04 03:49:15.880695+00
b4d0c0e7-ad19-4a11-b3f2-4411eb1e7236	5f39c536-340b-4981-b59a-4a9d7aff9e1e	1243a746-100c-460a-bf0f-2aadef7332b8	7	16	2026-07-04 03:49:15.880695+00	2026-07-04 03:49:15.880695+00
4426013e-66cd-4f6d-a32c-6ccec7a0002d	5f39c536-340b-4981-b59a-4a9d7aff9e1e	8050b663-c1ef-4a14-86bd-3ea225435c17	8	16	2026-07-04 03:49:15.880695+00	2026-07-04 03:49:15.880695+00
614aede2-9a9b-47e1-b608-6cfcf954969a	5f39c536-340b-4981-b59a-4a9d7aff9e1e	1114a750-be9a-44a9-8d82-001931ea4466	9	15	2026-07-04 03:49:15.880695+00	2026-07-04 03:49:15.880695+00
37bcea67-41c2-4557-9be6-bbe72122d2f6	5f39c536-340b-4981-b59a-4a9d7aff9e1e	c599dde6-99b1-4e0e-a4cf-2842c8f62162	10	15	2026-07-04 03:49:15.880695+00	2026-07-04 03:49:15.880695+00
41fd8123-9f35-4cbd-974b-94934859e646	5f39c536-340b-4981-b59a-4a9d7aff9e1e	38120818-5997-43e2-a907-f86000cf4b53	11	15	2026-07-04 03:49:15.880695+00	2026-07-04 03:49:15.880695+00
136e3345-717b-4d6a-8783-4394b653b018	5f39c536-340b-4981-b59a-4a9d7aff9e1e	6df76041-17a2-4c81-b653-82bb7124ee3f	12	14	2026-07-04 03:49:15.880695+00	2026-07-04 03:49:15.880695+00
ae7111cf-52d6-4314-a7c6-908bc4ebe3e6	5f39c536-340b-4981-b59a-4a9d7aff9e1e	1c570e30-214d-4723-96d3-0669c937f5a4	13	14	2026-07-04 03:49:15.880695+00	2026-07-04 03:49:15.880695+00
c4a5d742-1533-4bad-8e7d-808c58ec765d	5f39c536-340b-4981-b59a-4a9d7aff9e1e	71391ec7-5614-4690-8008-e2e16163570b	14	13	2026-07-04 03:49:15.880695+00	2026-07-04 03:49:15.880695+00
774cb593-d60e-42b4-943a-0b72e9ebc48a	5f39c536-340b-4981-b59a-4a9d7aff9e1e	3d58a7df-9922-413e-b42a-c2f162fb834c	15	13	2026-07-04 03:49:15.880695+00	2026-07-04 03:49:15.880695+00
18985de1-27e6-4574-b35f-af7a6c16ee4d	5f39c536-340b-4981-b59a-4a9d7aff9e1e	3fe745df-9187-41d7-a785-c3736a7277d7	16	12	2026-07-04 03:49:15.880695+00	2026-07-04 03:49:15.880695+00
6f4cf871-3b8e-4114-9f1d-c6d0f1be2afd	5f39c536-340b-4981-b59a-4a9d7aff9e1e	b94d44f2-7ae2-41f4-a105-e12b6ec3a572	17	12	2026-07-04 03:49:15.880695+00	2026-07-04 03:49:15.880695+00
126e2f49-3212-4a32-b611-c378cc606e3b	5f39c536-340b-4981-b59a-4a9d7aff9e1e	195dcc37-e60e-4608-a0dc-c12766e96259	18	12	2026-07-04 03:49:15.880695+00	2026-07-04 03:49:15.880695+00
d63905d2-358a-4c63-aa93-66ab74c1c881	5f39c536-340b-4981-b59a-4a9d7aff9e1e	ce064aab-7c13-4db9-89b3-7eb444cc158b	19	12	2026-07-04 03:49:15.880695+00	2026-07-04 03:49:15.880695+00
45721f03-f9df-4656-9d1e-3deda7b844cd	5f39c536-340b-4981-b59a-4a9d7aff9e1e	fea5b705-eab8-4ba4-b0f2-739b370efd98	20	12	2026-07-04 03:49:15.880695+00	2026-07-04 03:49:15.880695+00
cae1bacd-3f96-4ca5-95bf-ad2cc34a7edd	5f39c536-340b-4981-b59a-4a9d7aff9e1e	36e379ae-18cb-488c-a9ef-34e99c796cfe	21	12	2026-07-04 03:49:15.880695+00	2026-07-04 03:49:15.880695+00
dd597abe-88f0-401b-adf7-7a9c545c5265	5f39c536-340b-4981-b59a-4a9d7aff9e1e	b3d06ab8-28c8-4e46-a174-1da15c08949c	22	11	2026-07-04 03:49:15.880695+00	2026-07-04 03:49:15.880695+00
9c77b058-1834-4f12-b6a4-843cdcff507c	5f39c536-340b-4981-b59a-4a9d7aff9e1e	5e429458-4e6f-4df7-88bd-43977c8f74b1	23	10	2026-07-04 03:49:15.880695+00	2026-07-04 03:49:15.880695+00
de7e17c4-79ef-4ba1-bd66-069b01508717	5f39c536-340b-4981-b59a-4a9d7aff9e1e	d8cc0ff6-c084-4134-8931-bf514fa05f23	24	10	2026-07-04 03:49:15.880695+00	2026-07-04 03:49:15.880695+00
1a83c1d0-21b4-4b7c-8987-1644e738af85	5f39c536-340b-4981-b59a-4a9d7aff9e1e	6f8a0f72-aa76-4252-9486-cc8b95570923	25	10	2026-07-04 03:49:15.880695+00	2026-07-04 03:49:15.880695+00
d8d4a630-0c86-42f0-8572-bf042f5f1c2d	5f39c536-340b-4981-b59a-4a9d7aff9e1e	1cc4459a-e518-4a28-b323-7cbb9d07994a	26	10	2026-07-04 03:49:15.880695+00	2026-07-04 03:49:15.880695+00
9f091cad-9acb-4e79-8265-1c0bc534129c	5f39c536-340b-4981-b59a-4a9d7aff9e1e	03d17e40-bb16-4728-9043-ceb05e62c9e9	27	9	2026-07-04 03:49:15.880695+00	2026-07-04 03:49:15.880695+00
9f30be96-6930-44d2-bf30-efff92059f55	aa9754bd-50eb-4785-8698-e56c6d3cb661	3422f6a8-d289-4ce8-8135-b547ff0f9606	1	21	2026-07-12 08:29:29.05563+00	2026-07-12 08:29:29.05563+00
4bf41f9c-e654-42bb-a9a2-492bcec69ef9	aa9754bd-50eb-4785-8698-e56c6d3cb661	5d4ce78f-67ee-4a61-afab-c44ffc6afe91	2	20	2026-07-12 08:29:29.05563+00	2026-07-12 08:29:29.05563+00
f6cb6e5e-d768-4116-8c45-1bdf32b65eff	aa9754bd-50eb-4785-8698-e56c6d3cb661	1243a746-100c-460a-bf0f-2aadef7332b8	3	20	2026-07-12 08:29:29.05563+00	2026-07-12 08:29:29.05563+00
dafd3d74-e192-41f8-92a5-4a689fd1803f	aa9754bd-50eb-4785-8698-e56c6d3cb661	8050b663-c1ef-4a14-86bd-3ea225435c17	4	20	2026-07-12 08:29:29.05563+00	2026-07-12 08:29:29.05563+00
c5f8cc86-33e1-45e2-8482-e0296f8bde38	aa9754bd-50eb-4785-8698-e56c6d3cb661	38120818-5997-43e2-a907-f86000cf4b53	5	19	2026-07-12 08:29:29.05563+00	2026-07-12 08:29:29.05563+00
fae61c20-1940-4179-a356-ee2f3d4509a1	aa9754bd-50eb-4785-8698-e56c6d3cb661	ed3a6f56-12b3-4f1a-ab83-4744531df4f1	6	19	2026-07-12 08:29:29.05563+00	2026-07-12 08:29:29.05563+00
c97a52ef-515f-4f74-b1fc-f62de3a44201	aa9754bd-50eb-4785-8698-e56c6d3cb661	e73bedf4-0330-41d0-b1e7-31cb55909eed	7	18	2026-07-12 08:29:29.05563+00	2026-07-12 08:29:29.05563+00
02804521-757b-4813-a5d3-21d19d420847	aa9754bd-50eb-4785-8698-e56c6d3cb661	71391ec7-5614-4690-8008-e2e16163570b	8	17	2026-07-12 08:29:29.05563+00	2026-07-12 08:29:29.05563+00
57591504-4025-4691-92dd-5d19038ad4cf	aa9754bd-50eb-4785-8698-e56c6d3cb661	b8526be4-5eb8-4f89-b015-699537c368ce	9	17	2026-07-12 08:29:29.05563+00	2026-07-12 08:29:29.05563+00
2bea3992-354d-4f75-a6be-91c909b11d88	aa9754bd-50eb-4785-8698-e56c6d3cb661	31780afe-855c-4c9d-9cf6-56e3570c00c4	10	17	2026-07-12 08:29:29.05563+00	2026-07-12 08:29:29.05563+00
0d1e05a6-c9a7-4dfd-9a72-92d5ea43feb8	aa9754bd-50eb-4785-8698-e56c6d3cb661	3fe745df-9187-41d7-a785-c3736a7277d7	11	16	2026-07-12 08:29:29.05563+00	2026-07-12 08:29:29.05563+00
3726568a-8758-4251-a759-72ee74297ef2	aa9754bd-50eb-4785-8698-e56c6d3cb661	195dcc37-e60e-4608-a0dc-c12766e96259	12	16	2026-07-12 08:29:29.05563+00	2026-07-12 08:29:29.05563+00
d1e2b249-bbb0-4004-8138-7a0d6920e56d	aa9754bd-50eb-4785-8698-e56c6d3cb661	1114a750-be9a-44a9-8d82-001931ea4466	13	15	2026-07-12 08:29:29.05563+00	2026-07-12 08:29:29.05563+00
4a8c6354-1cd8-4901-a9f7-adc5b7fad78d	aa9754bd-50eb-4785-8698-e56c6d3cb661	c599dde6-99b1-4e0e-a4cf-2842c8f62162	14	15	2026-07-12 08:29:29.05563+00	2026-07-12 08:29:29.05563+00
feb25be4-b101-4114-91fd-a78e72ff1099	aa9754bd-50eb-4785-8698-e56c6d3cb661	6df76041-17a2-4c81-b653-82bb7124ee3f	15	14	2026-07-12 08:29:29.05563+00	2026-07-12 08:29:29.05563+00
92d46d1a-b48f-4118-8d46-e6d4d068a9ea	aa9754bd-50eb-4785-8698-e56c6d3cb661	1c570e30-214d-4723-96d3-0669c937f5a4	16	14	2026-07-12 08:29:29.05563+00	2026-07-12 08:29:29.05563+00
d7ef44fa-3c11-451c-a8fc-df9e4a5373ab	aa9754bd-50eb-4785-8698-e56c6d3cb661	03d17e40-bb16-4728-9043-ceb05e62c9e9	17	13	2026-07-12 08:29:29.05563+00	2026-07-12 08:29:29.05563+00
00a5e3ce-68a5-4f29-b2c5-c03378ee304b	aa9754bd-50eb-4785-8698-e56c6d3cb661	3d58a7df-9922-413e-b42a-c2f162fb834c	18	13	2026-07-12 08:29:29.05563+00	2026-07-12 08:29:29.05563+00
7b3186c4-259a-4b92-bca1-e89887c7fee1	aa9754bd-50eb-4785-8698-e56c6d3cb661	b94d44f2-7ae2-41f4-a105-e12b6ec3a572	19	12	2026-07-12 08:29:29.05563+00	2026-07-12 08:29:29.05563+00
9a55e881-5dd6-4072-ac78-d7793d3eb22f	aa9754bd-50eb-4785-8698-e56c6d3cb661	ce064aab-7c13-4db9-89b3-7eb444cc158b	20	12	2026-07-12 08:29:29.05563+00	2026-07-12 08:29:29.05563+00
b5639480-3eba-49c2-bcb3-113c3ecbde02	aa9754bd-50eb-4785-8698-e56c6d3cb661	fea5b705-eab8-4ba4-b0f2-739b370efd98	21	12	2026-07-12 08:29:29.05563+00	2026-07-12 08:29:29.05563+00
481e7de7-44ab-4601-a10b-528e2ef0b526	aa9754bd-50eb-4785-8698-e56c6d3cb661	36e379ae-18cb-488c-a9ef-34e99c796cfe	22	12	2026-07-12 08:29:29.05563+00	2026-07-12 08:29:29.05563+00
63387c5d-2f23-4f9e-8815-6ead2e0192f0	aa9754bd-50eb-4785-8698-e56c6d3cb661	b3d06ab8-28c8-4e46-a174-1da15c08949c	23	11	2026-07-12 08:29:29.05563+00	2026-07-12 08:29:29.05563+00
2e52ff8d-0f40-4f3f-9715-8f5db45db1a4	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	38120818-5997-43e2-a907-f86000cf4b53	1	6	2026-06-18 05:40:07.580305+00	2026-06-18 05:40:07.580305+00
0d081efe-7113-459f-815c-08dfde26a551	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	8050b663-c1ef-4a14-86bd-3ea225435c17	2	6	2026-06-18 05:40:07.580305+00	2026-06-18 05:40:07.580305+00
187a530b-e85c-406a-ab53-5aa4707be833	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	ed3a6f56-12b3-4f1a-ab83-4744531df4f1	3	6	2026-06-18 05:40:07.580305+00	2026-06-18 05:40:07.580305+00
189d911b-1fc2-4110-b449-83e8404c4a67	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	e73bedf4-0330-41d0-b1e7-31cb55909eed	4	6	2026-06-18 05:40:07.580305+00	2026-06-18 05:40:07.580305+00
4351acea-4bee-4c36-89ef-c257d3ddc652	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	3422f6a8-d289-4ce8-8135-b547ff0f9606	5	6	2026-06-18 05:40:07.580305+00	2026-06-18 05:40:07.580305+00
73df14cd-76ea-46e1-aab3-b72073a9ec60	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	b3d06ab8-28c8-4e46-a174-1da15c08949c	6	5	2026-06-18 05:40:07.580305+00	2026-06-18 05:40:07.580305+00
a4dbdabe-afae-450f-9b7d-7e72c9574b66	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	5d4ce78f-67ee-4a61-afab-c44ffc6afe91	7	5	2026-06-18 05:40:07.580305+00	2026-06-18 05:40:07.580305+00
7a91e7b6-7a91-487a-a9fb-9814b8c7772b	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	195dcc37-e60e-4608-a0dc-c12766e96259	8	5	2026-06-18 05:40:07.580305+00	2026-06-18 05:40:07.580305+00
a080fe47-8280-48fd-80ff-951e747e8e94	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	fea5b705-eab8-4ba4-b0f2-739b370efd98	9	5	2026-06-18 05:40:07.580305+00	2026-06-18 05:40:07.580305+00
570fd407-c63a-4cb3-980a-86fa11453008	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	31780afe-855c-4c9d-9cf6-56e3570c00c4	10	5	2026-06-18 05:40:07.580305+00	2026-06-18 05:40:07.580305+00
60791e6e-0e33-47b4-b2b9-e016a0918236	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	b8526be4-5eb8-4f89-b015-699537c368ce	11	5	2026-06-18 05:40:07.580305+00	2026-06-18 05:40:07.580305+00
c7bf09bf-a63b-4c9d-afcf-3319f103641c	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	71391ec7-5614-4690-8008-e2e16163570b	12	5	2026-06-18 05:40:07.580305+00	2026-06-18 05:40:07.580305+00
8c8a1e1a-735e-4d04-a397-0637bf4610ed	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	1c570e30-214d-4723-96d3-0669c937f5a4	13	5	2026-06-18 05:40:07.580305+00	2026-06-18 05:40:07.580305+00
34bb67f6-8617-452a-b09c-447855f9ceb3	aa9754bd-50eb-4785-8698-e56c6d3cb661	5e429458-4e6f-4df7-88bd-43977c8f74b1	24	10	2026-07-12 08:29:29.05563+00	2026-07-12 08:29:29.05563+00
19d06105-39e0-4895-bd85-eac89cb768aa	aa9754bd-50eb-4785-8698-e56c6d3cb661	d8cc0ff6-c084-4134-8931-bf514fa05f23	25	10	2026-07-12 08:29:29.05563+00	2026-07-12 08:29:29.05563+00
f90b85e2-147b-4902-b1a2-7ebc55eed44d	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	3d58a7df-9922-413e-b42a-c2f162fb834c	14	5	2026-06-18 05:40:07.580305+00	2026-06-18 05:40:07.580305+00
eedf7ddb-9a09-4466-90e0-a96dafa0528b	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	c599dde6-99b1-4e0e-a4cf-2842c8f62162	15	5	2026-06-18 05:40:07.580305+00	2026-06-18 05:40:07.580305+00
1ff5d6a2-fdd8-442d-8601-55853bd843a6	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	1114a750-be9a-44a9-8d82-001931ea4466	16	4	2026-06-18 05:40:07.580305+00	2026-06-18 05:40:07.580305+00
45c289ad-b537-4352-b97f-1d950c8da8bd	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	6f8a0f72-aa76-4252-9486-cc8b95570923	17	4	2026-06-18 05:40:07.580305+00	2026-06-18 05:40:07.580305+00
618422fc-d670-43be-9050-7bd6fb5c7046	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	1243a746-100c-460a-bf0f-2aadef7332b8	18	4	2026-06-18 05:40:07.580305+00	2026-06-18 05:40:07.580305+00
8dde11f2-4c9c-40a9-960f-c8fad5f1ad14	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	ce064aab-7c13-4db9-89b3-7eb444cc158b	19	3	2026-06-18 05:40:07.580305+00	2026-06-18 05:40:07.580305+00
66bd61f4-c6d1-494c-9e5b-332183d3e60d	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	5e429458-4e6f-4df7-88bd-43977c8f74b1	20	3	2026-06-18 05:40:07.580305+00	2026-06-18 05:40:07.580305+00
d10a3b1a-d03d-4699-8eaa-d1b8546f4d46	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	b94d44f2-7ae2-41f4-a105-e12b6ec3a572	21	3	2026-06-18 05:40:07.580305+00	2026-06-18 05:40:07.580305+00
0efac824-b881-4384-b3b3-e7bd7f6b8f1f	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	6df76041-17a2-4c81-b653-82bb7124ee3f	22	3	2026-06-18 05:40:07.580305+00	2026-06-18 05:40:07.580305+00
694afc15-4281-491d-948f-c6766f118c71	aa9754bd-50eb-4785-8698-e56c6d3cb661	6f8a0f72-aa76-4252-9486-cc8b95570923	26	10	2026-07-12 08:29:29.05563+00	2026-07-12 08:29:29.05563+00
89bd2345-074e-4bcb-8e4e-c06a24460277	aa9754bd-50eb-4785-8698-e56c6d3cb661	1cc4459a-e518-4a28-b323-7cbb9d07994a	27	10	2026-07-12 08:29:29.05563+00	2026-07-12 08:29:29.05563+00
74f70d16-494e-47c3-8c7d-18c048b6edee	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	3fe745df-9187-41d7-a785-c3736a7277d7	23	3	2026-06-18 05:40:07.580305+00	2026-06-18 05:40:07.580305+00
7859621b-5bdf-4a4e-bcb0-8d5112f62dda	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	1cc4459a-e518-4a28-b323-7cbb9d07994a	24	3	2026-06-18 05:40:07.580305+00	2026-06-18 05:40:07.580305+00
f6719b65-e2be-46f3-8e4f-868c0c23d95b	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	03d17e40-bb16-4728-9043-ceb05e62c9e9	25	3	2026-06-18 05:40:07.580305+00	2026-06-18 05:40:07.580305+00
178e179b-57fe-4cd4-aeaf-133d0741a3f6	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	36e379ae-18cb-488c-a9ef-34e99c796cfe	26	2	2026-06-18 05:40:07.580305+00	2026-06-18 05:40:07.580305+00
bbcb194e-a42f-4189-ba7f-754a540bde8c	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	d8cc0ff6-c084-4134-8931-bf514fa05f23	27	2	2026-06-18 05:40:07.580305+00	2026-06-18 05:40:07.580305+00
5daecbbb-6350-417a-9002-f4dcefef3b6d	318f2b2d-d52a-4102-bd8d-7ab594a40f42	c599dde6-99b1-4e0e-a4cf-2842c8f62162	1	0	2026-06-18 15:05:59.288454+00	2026-06-18 15:05:59.288454+00
646e7ca7-c417-4ac9-a82c-ac669cbed097	318f2b2d-d52a-4102-bd8d-7ab594a40f42	ed3a6f56-12b3-4f1a-ab83-4744531df4f1	2	0	2026-06-18 15:05:59.288454+00	2026-06-18 15:05:59.288454+00
d2c442b5-72a0-42f1-a779-c8f2973def1e	318f2b2d-d52a-4102-bd8d-7ab594a40f42	e73bedf4-0330-41d0-b1e7-31cb55909eed	3	0	2026-06-18 15:05:59.288454+00	2026-06-18 15:05:59.288454+00
0a2bb8a0-99ac-4fd3-84d3-35a5cedeac40	318f2b2d-d52a-4102-bd8d-7ab594a40f42	5e429458-4e6f-4df7-88bd-43977c8f74b1	4	0	2026-06-18 15:05:59.288454+00	2026-06-18 15:05:59.288454+00
65b7188a-6bc7-4570-aef5-47a22a2c7f7c	318f2b2d-d52a-4102-bd8d-7ab594a40f42	6f8a0f72-aa76-4252-9486-cc8b95570923	5	0	2026-06-18 15:05:59.288454+00	2026-06-18 15:05:59.288454+00
c945a66f-31da-4d3d-b074-e4d6b5ce05cd	318f2b2d-d52a-4102-bd8d-7ab594a40f42	03d17e40-bb16-4728-9043-ceb05e62c9e9	6	0	2026-06-18 15:05:59.288454+00	2026-06-18 15:05:59.288454+00
e200012d-b8e6-42e6-98c8-b5b02a0fe02f	318f2b2d-d52a-4102-bd8d-7ab594a40f42	38120818-5997-43e2-a907-f86000cf4b53	7	0	2026-06-18 15:05:59.288454+00	2026-06-18 15:05:59.288454+00
bf0b13d2-f62d-42cd-93d2-100c71bfe27a	318f2b2d-d52a-4102-bd8d-7ab594a40f42	8050b663-c1ef-4a14-86bd-3ea225435c17	8	0	2026-06-18 15:05:59.288454+00	2026-06-18 15:05:59.288454+00
8c11655f-8b46-4f04-bbdb-68ad7dad5b8f	318f2b2d-d52a-4102-bd8d-7ab594a40f42	b94d44f2-7ae2-41f4-a105-e12b6ec3a572	9	0	2026-06-18 15:05:59.288454+00	2026-06-18 15:05:59.288454+00
757415eb-2bb1-4a96-bc0e-93692099c9aa	318f2b2d-d52a-4102-bd8d-7ab594a40f42	6df76041-17a2-4c81-b653-82bb7124ee3f	10	0	2026-06-18 15:05:59.288454+00	2026-06-18 15:05:59.288454+00
6903fd88-353c-4972-a624-ca2f9fdc1e39	318f2b2d-d52a-4102-bd8d-7ab594a40f42	b8526be4-5eb8-4f89-b015-699537c368ce	11	0	2026-06-18 15:05:59.288454+00	2026-06-18 15:05:59.288454+00
83d9779c-3959-4b06-a6d7-c3bf53091217	318f2b2d-d52a-4102-bd8d-7ab594a40f42	1cc4459a-e518-4a28-b323-7cbb9d07994a	12	0	2026-06-18 15:05:59.288454+00	2026-06-18 15:05:59.288454+00
3fb3aaf9-4e55-4344-ac27-8c9fd7517f15	318f2b2d-d52a-4102-bd8d-7ab594a40f42	71391ec7-5614-4690-8008-e2e16163570b	13	0	2026-06-18 15:05:59.288454+00	2026-06-18 15:05:59.288454+00
42e6f632-110d-451c-aaee-b69a745e6857	318f2b2d-d52a-4102-bd8d-7ab594a40f42	b3d06ab8-28c8-4e46-a174-1da15c08949c	14	0	2026-06-18 15:05:59.288454+00	2026-06-18 15:05:59.288454+00
5fdceb02-678d-4eb9-99f2-2887bdcb319b	318f2b2d-d52a-4102-bd8d-7ab594a40f42	36e379ae-18cb-488c-a9ef-34e99c796cfe	15	0	2026-06-18 15:05:59.288454+00	2026-06-18 15:05:59.288454+00
414045d2-b307-49f5-9d9c-0a849269b786	318f2b2d-d52a-4102-bd8d-7ab594a40f42	5d4ce78f-67ee-4a61-afab-c44ffc6afe91	16	0	2026-06-18 15:05:59.288454+00	2026-06-18 15:05:59.288454+00
8278d6cc-1693-452e-8fcc-caf0b6e2c6e7	318f2b2d-d52a-4102-bd8d-7ab594a40f42	ce064aab-7c13-4db9-89b3-7eb444cc158b	17	0	2026-06-18 15:05:59.288454+00	2026-06-18 15:05:59.288454+00
d0ea24fc-e09e-47b7-b120-a34ad98d60cc	318f2b2d-d52a-4102-bd8d-7ab594a40f42	1114a750-be9a-44a9-8d82-001931ea4466	18	0	2026-06-18 15:05:59.288454+00	2026-06-18 15:05:59.288454+00
d6d8fc00-0a5c-490b-8ed0-db100fef612c	318f2b2d-d52a-4102-bd8d-7ab594a40f42	1c570e30-214d-4723-96d3-0669c937f5a4	19	0	2026-06-18 15:05:59.288454+00	2026-06-18 15:05:59.288454+00
64b2d0a3-48f4-4500-bcf9-2d67eeac3572	318f2b2d-d52a-4102-bd8d-7ab594a40f42	3fe745df-9187-41d7-a785-c3736a7277d7	20	0	2026-06-18 15:05:59.288454+00	2026-06-18 15:05:59.288454+00
fe01dee1-b4e4-4db8-a564-aa76b5bc5b3f	318f2b2d-d52a-4102-bd8d-7ab594a40f42	d8cc0ff6-c084-4134-8931-bf514fa05f23	21	0	2026-06-18 15:05:59.288454+00	2026-06-18 15:05:59.288454+00
73548216-2e4c-4d7c-8b99-2507b6831a32	318f2b2d-d52a-4102-bd8d-7ab594a40f42	3422f6a8-d289-4ce8-8135-b547ff0f9606	22	0	2026-06-18 15:05:59.288454+00	2026-06-18 15:05:59.288454+00
0fb9bb02-ada3-4470-b675-f93132bb5e9a	318f2b2d-d52a-4102-bd8d-7ab594a40f42	1243a746-100c-460a-bf0f-2aadef7332b8	23	0	2026-06-18 15:05:59.288454+00	2026-06-18 15:05:59.288454+00
f46b367e-1933-478b-856b-9054decca88f	318f2b2d-d52a-4102-bd8d-7ab594a40f42	fea5b705-eab8-4ba4-b0f2-739b370efd98	24	0	2026-06-18 15:05:59.288454+00	2026-06-18 15:05:59.288454+00
4e913db3-3785-4b03-a76b-bcc67f2461b7	318f2b2d-d52a-4102-bd8d-7ab594a40f42	195dcc37-e60e-4608-a0dc-c12766e96259	25	0	2026-06-18 15:05:59.288454+00	2026-06-18 15:05:59.288454+00
432e2ac3-122f-4cd5-b072-db7a0b0bbdb8	318f2b2d-d52a-4102-bd8d-7ab594a40f42	31780afe-855c-4c9d-9cf6-56e3570c00c4	26	0	2026-06-18 15:05:59.288454+00	2026-06-18 15:05:59.288454+00
03337267-fab5-4cab-929e-59f06683a4b8	318f2b2d-d52a-4102-bd8d-7ab594a40f42	3d58a7df-9922-413e-b42a-c2f162fb834c	27	0	2026-06-18 15:05:59.288454+00	2026-06-18 15:05:59.288454+00
ec7a02cb-209f-40f0-aba2-a419ffa63ec3	c22e6746-73c1-4060-9194-eb35359c955e	b8526be4-5eb8-4f89-b015-699537c368ce	1	10	2026-06-24 06:17:24.454436+00	2026-06-24 06:17:24.454436+00
de6a08a5-8348-4fa9-a23f-573876156094	c22e6746-73c1-4060-9194-eb35359c955e	31780afe-855c-4c9d-9cf6-56e3570c00c4	2	10	2026-06-24 06:17:24.454436+00	2026-06-24 06:17:24.454436+00
01367dda-f33c-4d05-85e4-bda68a161f4c	c22e6746-73c1-4060-9194-eb35359c955e	ed3a6f56-12b3-4f1a-ab83-4744531df4f1	3	10	2026-06-24 06:17:24.454436+00	2026-06-24 06:17:24.454436+00
1416a566-daea-4f73-b7b1-324dd403fe90	c22e6746-73c1-4060-9194-eb35359c955e	1243a746-100c-460a-bf0f-2aadef7332b8	4	9	2026-06-24 06:17:24.454436+00	2026-06-24 06:17:24.454436+00
25242ef6-6991-4da6-a140-a8c8619e4c83	c22e6746-73c1-4060-9194-eb35359c955e	5d4ce78f-67ee-4a61-afab-c44ffc6afe91	5	9	2026-06-24 06:17:24.454436+00	2026-06-24 06:17:24.454436+00
fb5620dc-7ea3-423e-b019-5acd5f44f1d1	c22e6746-73c1-4060-9194-eb35359c955e	3422f6a8-d289-4ce8-8135-b547ff0f9606	6	9	2026-06-24 06:17:24.454436+00	2026-06-24 06:17:24.454436+00
f8ea2c74-6b83-4975-82fd-76222c4d58cd	c22e6746-73c1-4060-9194-eb35359c955e	71391ec7-5614-4690-8008-e2e16163570b	7	8	2026-06-24 06:17:24.454436+00	2026-06-24 06:17:24.454436+00
cd2dc6f5-6e4f-4911-9c3f-0e5bc5ff0b84	c22e6746-73c1-4060-9194-eb35359c955e	38120818-5997-43e2-a907-f86000cf4b53	8	8	2026-06-24 06:17:24.454436+00	2026-06-24 06:17:24.454436+00
ac72ff94-75b0-41ac-8400-00edd77e327e	c22e6746-73c1-4060-9194-eb35359c955e	8050b663-c1ef-4a14-86bd-3ea225435c17	9	8	2026-06-24 06:17:24.454436+00	2026-06-24 06:17:24.454436+00
46f9098a-437f-4c9d-809e-9bfc9d4931b6	c22e6746-73c1-4060-9194-eb35359c955e	6df76041-17a2-4c81-b653-82bb7124ee3f	10	7	2026-06-24 06:17:24.454436+00	2026-06-24 06:17:24.454436+00
17210551-0810-4428-8d72-0e6fcd72e978	c22e6746-73c1-4060-9194-eb35359c955e	ce064aab-7c13-4db9-89b3-7eb444cc158b	11	7	2026-06-24 06:17:24.454436+00	2026-06-24 06:17:24.454436+00
591a64c8-ae4b-404e-9cd7-3c17c65d1d99	c22e6746-73c1-4060-9194-eb35359c955e	1114a750-be9a-44a9-8d82-001931ea4466	12	7	2026-06-24 06:17:24.454436+00	2026-06-24 06:17:24.454436+00
4dc8533d-2b18-4f86-a3de-4e94e5546ed6	c22e6746-73c1-4060-9194-eb35359c955e	b3d06ab8-28c8-4e46-a174-1da15c08949c	13	7	2026-06-24 06:17:24.454436+00	2026-06-24 06:17:24.454436+00
553f4c51-a0eb-4b6b-84e1-711f688cd6d8	c22e6746-73c1-4060-9194-eb35359c955e	195dcc37-e60e-4608-a0dc-c12766e96259	14	7	2026-06-24 06:17:24.454436+00	2026-06-24 06:17:24.454436+00
e8449ea5-eb24-472a-9e1a-1072061c4538	c22e6746-73c1-4060-9194-eb35359c955e	03d17e40-bb16-4728-9043-ceb05e62c9e9	15	7	2026-06-24 06:17:24.454436+00	2026-06-24 06:17:24.454436+00
87bb6905-d3f1-45d5-83c7-086d77df3468	c22e6746-73c1-4060-9194-eb35359c955e	fea5b705-eab8-4ba4-b0f2-739b370efd98	16	7	2026-06-24 06:17:24.454436+00	2026-06-24 06:17:24.454436+00
b6a6fe6f-4540-4813-8b7e-37030b1fa34b	c22e6746-73c1-4060-9194-eb35359c955e	36e379ae-18cb-488c-a9ef-34e99c796cfe	17	7	2026-06-24 06:17:24.454436+00	2026-06-24 06:17:24.454436+00
3965859a-19de-4464-bf9d-a12a7d720442	c22e6746-73c1-4060-9194-eb35359c955e	1c570e30-214d-4723-96d3-0669c937f5a4	18	7	2026-06-24 06:17:24.454436+00	2026-06-24 06:17:24.454436+00
b9beecee-0b30-45c7-b57f-f870b375823c	c22e6746-73c1-4060-9194-eb35359c955e	3d58a7df-9922-413e-b42a-c2f162fb834c	19	7	2026-06-24 06:17:24.454436+00	2026-06-24 06:17:24.454436+00
2df2f13e-fe6c-4971-808c-54d149288640	c22e6746-73c1-4060-9194-eb35359c955e	c599dde6-99b1-4e0e-a4cf-2842c8f62162	20	7	2026-06-24 06:17:24.454436+00	2026-06-24 06:17:24.454436+00
4f182489-d9e6-48c5-84fe-62030d0868fa	c22e6746-73c1-4060-9194-eb35359c955e	e73bedf4-0330-41d0-b1e7-31cb55909eed	21	7	2026-06-24 06:17:24.454436+00	2026-06-24 06:17:24.454436+00
264bce33-4ecf-421e-9083-aab53e729c95	c22e6746-73c1-4060-9194-eb35359c955e	5e429458-4e6f-4df7-88bd-43977c8f74b1	22	6	2026-06-24 06:17:24.454436+00	2026-06-24 06:17:24.454436+00
2e4b7b06-699d-401c-b087-54995615bb0b	c22e6746-73c1-4060-9194-eb35359c955e	d8cc0ff6-c084-4134-8931-bf514fa05f23	23	6	2026-06-24 06:17:24.454436+00	2026-06-24 06:17:24.454436+00
adbf9bfc-3077-42f0-a606-071d51a2ba48	c22e6746-73c1-4060-9194-eb35359c955e	6f8a0f72-aa76-4252-9486-cc8b95570923	24	6	2026-06-24 06:17:24.454436+00	2026-06-24 06:17:24.454436+00
caf2b112-6f0d-4d61-8a08-1a2ec753f0bc	c22e6746-73c1-4060-9194-eb35359c955e	b94d44f2-7ae2-41f4-a105-e12b6ec3a572	25	5	2026-06-24 06:17:24.454436+00	2026-06-24 06:17:24.454436+00
1a640eb4-462e-4b02-9ba4-10912cad0d29	c22e6746-73c1-4060-9194-eb35359c955e	3fe745df-9187-41d7-a785-c3736a7277d7	26	5	2026-06-24 06:17:24.454436+00	2026-06-24 06:17:24.454436+00
9f402945-90a9-47d0-98b4-a8d04eafb2de	c22e6746-73c1-4060-9194-eb35359c955e	1cc4459a-e518-4a28-b323-7cbb9d07994a	27	4	2026-06-24 06:17:24.454436+00	2026-06-24 06:17:24.454436+00
7ff6621a-06ea-428c-862d-73b3eeb2e807	27ce4fc5-3de9-4cf0-bfc5-5fa0addb7081	3422f6a8-d289-4ce8-8135-b547ff0f9606	1	19	2026-07-07 23:10:22.304823+00	2026-07-07 23:10:22.304823+00
9e3fc5ea-28bf-4fab-8d10-94080316c0b6	27ce4fc5-3de9-4cf0-bfc5-5fa0addb7081	ed3a6f56-12b3-4f1a-ab83-4744531df4f1	2	19	2026-07-07 23:10:22.304823+00	2026-07-07 23:10:22.304823+00
b863b83d-678c-4ec5-bcf3-d3686049e5eb	27ce4fc5-3de9-4cf0-bfc5-5fa0addb7081	5d4ce78f-67ee-4a61-afab-c44ffc6afe91	3	18	2026-07-07 23:10:22.304823+00	2026-07-07 23:10:22.304823+00
5def1df0-12ab-463c-9ea5-2e23388b54ac	27ce4fc5-3de9-4cf0-bfc5-5fa0addb7081	1243a746-100c-460a-bf0f-2aadef7332b8	4	18	2026-07-07 23:10:22.304823+00	2026-07-07 23:10:22.304823+00
29a5b5cf-b9b9-4895-880f-72ad7a64798b	27ce4fc5-3de9-4cf0-bfc5-5fa0addb7081	8050b663-c1ef-4a14-86bd-3ea225435c17	5	18	2026-07-07 23:10:22.304823+00	2026-07-07 23:10:22.304823+00
09967f9a-f382-4dcc-86c2-dc637febc35d	27ce4fc5-3de9-4cf0-bfc5-5fa0addb7081	e73bedf4-0330-41d0-b1e7-31cb55909eed	6	18	2026-07-07 23:10:22.304823+00	2026-07-07 23:10:22.304823+00
7868683c-9dbf-4ae8-b235-5627e083d270	27ce4fc5-3de9-4cf0-bfc5-5fa0addb7081	38120818-5997-43e2-a907-f86000cf4b53	7	17	2026-07-07 23:10:22.304823+00	2026-07-07 23:10:22.304823+00
b2e79a45-7e08-4108-9e66-81c563b5e34f	27ce4fc5-3de9-4cf0-bfc5-5fa0addb7081	b8526be4-5eb8-4f89-b015-699537c368ce	8	17	2026-07-07 23:10:22.304823+00	2026-07-07 23:10:22.304823+00
0740091e-c237-4590-8de9-ff165edd7bf1	27ce4fc5-3de9-4cf0-bfc5-5fa0addb7081	31780afe-855c-4c9d-9cf6-56e3570c00c4	9	17	2026-07-07 23:10:22.304823+00	2026-07-07 23:10:22.304823+00
f5861b46-5417-418a-973a-f8587d0ed02c	27ce4fc5-3de9-4cf0-bfc5-5fa0addb7081	71391ec7-5614-4690-8008-e2e16163570b	10	15	2026-07-07 23:10:22.304823+00	2026-07-07 23:10:22.304823+00
99b3c963-2bd1-4f2a-8edc-6031a2ae3599	27ce4fc5-3de9-4cf0-bfc5-5fa0addb7081	1114a750-be9a-44a9-8d82-001931ea4466	11	15	2026-07-07 23:10:22.304823+00	2026-07-07 23:10:22.304823+00
633c607a-334d-4b14-a75e-005e6f3acbfb	27ce4fc5-3de9-4cf0-bfc5-5fa0addb7081	c599dde6-99b1-4e0e-a4cf-2842c8f62162	12	15	2026-07-07 23:10:22.304823+00	2026-07-07 23:10:22.304823+00
9aeb6cc5-0ec3-4729-b2ed-a3a753361e9e	27ce4fc5-3de9-4cf0-bfc5-5fa0addb7081	3fe745df-9187-41d7-a785-c3736a7277d7	13	14	2026-07-07 23:10:22.304823+00	2026-07-07 23:10:22.304823+00
3f0b43e7-3e33-4e13-a14e-734a05fb18a1	27ce4fc5-3de9-4cf0-bfc5-5fa0addb7081	195dcc37-e60e-4608-a0dc-c12766e96259	14	14	2026-07-07 23:10:22.304823+00	2026-07-07 23:10:22.304823+00
665ff3a7-85b1-420d-84ab-f8fa7e49e82a	27ce4fc5-3de9-4cf0-bfc5-5fa0addb7081	6df76041-17a2-4c81-b653-82bb7124ee3f	15	14	2026-07-07 23:10:22.304823+00	2026-07-07 23:10:22.304823+00
5f09ff75-2a2e-4fc5-9d00-83f1f0e621b7	27ce4fc5-3de9-4cf0-bfc5-5fa0addb7081	1c570e30-214d-4723-96d3-0669c937f5a4	16	14	2026-07-07 23:10:22.304823+00	2026-07-07 23:10:22.304823+00
36fd53ba-c04c-4906-9836-13a2cfa9a6f3	27ce4fc5-3de9-4cf0-bfc5-5fa0addb7081	3d58a7df-9922-413e-b42a-c2f162fb834c	17	13	2026-07-07 23:10:22.304823+00	2026-07-07 23:10:22.304823+00
9bd254de-d04f-4a14-a778-0fef7159ff38	27ce4fc5-3de9-4cf0-bfc5-5fa0addb7081	b94d44f2-7ae2-41f4-a105-e12b6ec3a572	18	12	2026-07-07 23:10:22.304823+00	2026-07-07 23:10:22.304823+00
de618273-fd66-428b-8195-9a819889f7bf	27ce4fc5-3de9-4cf0-bfc5-5fa0addb7081	ce064aab-7c13-4db9-89b3-7eb444cc158b	19	12	2026-07-07 23:10:22.304823+00	2026-07-07 23:10:22.304823+00
9b319455-731c-45ae-828c-889ebc7daf61	27ce4fc5-3de9-4cf0-bfc5-5fa0addb7081	fea5b705-eab8-4ba4-b0f2-739b370efd98	20	12	2026-07-07 23:10:22.304823+00	2026-07-07 23:10:22.304823+00
4ae6fac8-26f7-4b86-a514-8746fa680199	27ce4fc5-3de9-4cf0-bfc5-5fa0addb7081	36e379ae-18cb-488c-a9ef-34e99c796cfe	21	12	2026-07-07 23:10:22.304823+00	2026-07-07 23:10:22.304823+00
186bc016-89ef-43f0-b168-78889145fba0	27ce4fc5-3de9-4cf0-bfc5-5fa0addb7081	03d17e40-bb16-4728-9043-ceb05e62c9e9	22	11	2026-07-07 23:10:22.304823+00	2026-07-07 23:10:22.304823+00
4bc36770-de40-4c4d-a86e-ea09d1b32d01	27ce4fc5-3de9-4cf0-bfc5-5fa0addb7081	b3d06ab8-28c8-4e46-a174-1da15c08949c	23	11	2026-07-07 23:10:22.304823+00	2026-07-07 23:10:22.304823+00
21dc34cd-cc9b-4430-a9bd-122390cd9da1	27ce4fc5-3de9-4cf0-bfc5-5fa0addb7081	5e429458-4e6f-4df7-88bd-43977c8f74b1	24	10	2026-07-07 23:10:22.304823+00	2026-07-07 23:10:22.304823+00
d19369f4-e65f-45a1-a305-3b01df26f8cc	27ce4fc5-3de9-4cf0-bfc5-5fa0addb7081	d8cc0ff6-c084-4134-8931-bf514fa05f23	25	10	2026-07-07 23:10:22.304823+00	2026-07-07 23:10:22.304823+00
a90310cc-5ddb-4f7e-8743-ed6ffe2fd5da	27ce4fc5-3de9-4cf0-bfc5-5fa0addb7081	6f8a0f72-aa76-4252-9486-cc8b95570923	26	10	2026-07-07 23:10:22.304823+00	2026-07-07 23:10:22.304823+00
9532827e-b4ea-4b22-9188-b3a3ba6a73df	27ce4fc5-3de9-4cf0-bfc5-5fa0addb7081	1cc4459a-e518-4a28-b323-7cbb9d07994a	27	10	2026-07-07 23:10:22.304823+00	2026-07-07 23:10:22.304823+00
f80ec049-30e0-4c24-9e71-063913a87caf	5b9456a0-db45-445f-87a0-58737bb89313	b8526be4-5eb8-4f89-b015-699537c368ce	1	16	2026-06-29 08:42:30.839291+00	2026-06-29 08:42:30.839291+00
a48b9e67-31f7-4d4f-a0b2-f31cf44fcdcc	5b9456a0-db45-445f-87a0-58737bb89313	31780afe-855c-4c9d-9cf6-56e3570c00c4	2	16	2026-06-29 08:42:30.839291+00	2026-06-29 08:42:30.839291+00
e7cef29e-20ca-4615-9484-0a79c7d3de40	5b9456a0-db45-445f-87a0-58737bb89313	ed3a6f56-12b3-4f1a-ab83-4744531df4f1	3	16	2026-06-29 08:42:30.839291+00	2026-06-29 08:42:30.839291+00
ef8f87c7-c55f-4e44-8d2d-ae9166e755f1	5b9456a0-db45-445f-87a0-58737bb89313	e73bedf4-0330-41d0-b1e7-31cb55909eed	4	16	2026-06-29 08:42:30.839291+00	2026-06-29 08:42:30.839291+00
a19785a3-cf99-495b-ad45-ae256dc498b7	5b9456a0-db45-445f-87a0-58737bb89313	3422f6a8-d289-4ce8-8135-b547ff0f9606	5	15	2026-06-29 08:42:30.839291+00	2026-06-29 08:42:30.839291+00
804df89c-f96b-47c2-8742-804e5e482b34	5b9456a0-db45-445f-87a0-58737bb89313	5d4ce78f-67ee-4a61-afab-c44ffc6afe91	6	14	2026-06-29 08:42:30.839291+00	2026-06-29 08:42:30.839291+00
165d45f0-dfb2-497b-89ff-7242f236dc0e	5b9456a0-db45-445f-87a0-58737bb89313	1243a746-100c-460a-bf0f-2aadef7332b8	7	14	2026-06-29 08:42:30.839291+00	2026-06-29 08:42:30.839291+00
034144ea-7295-43c7-9f69-c8d2d7ba3e09	5b9456a0-db45-445f-87a0-58737bb89313	8050b663-c1ef-4a14-86bd-3ea225435c17	8	14	2026-06-29 08:42:30.839291+00	2026-06-29 08:42:30.839291+00
5d4fefad-52fe-45e6-8b0c-ddf00307970c	5b9456a0-db45-445f-87a0-58737bb89313	6df76041-17a2-4c81-b653-82bb7124ee3f	9	13	2026-06-29 08:42:30.839291+00	2026-06-29 08:42:30.839291+00
1412a11f-b1d0-484b-8545-2288fe1493d1	5b9456a0-db45-445f-87a0-58737bb89313	1114a750-be9a-44a9-8d82-001931ea4466	10	13	2026-06-29 08:42:30.839291+00	2026-06-29 08:42:30.839291+00
657ffdd0-116b-4c4c-9481-47c19adc960f	5b9456a0-db45-445f-87a0-58737bb89313	38120818-5997-43e2-a907-f86000cf4b53	11	13	2026-06-29 08:42:30.839291+00	2026-06-29 08:42:30.839291+00
f782386c-b972-423a-93a0-ed2efb12b87c	5b9456a0-db45-445f-87a0-58737bb89313	1c570e30-214d-4723-96d3-0669c937f5a4	12	13	2026-06-29 08:42:30.839291+00	2026-06-29 08:42:30.839291+00
3a6db36d-e681-427f-96e6-5ee029541573	5b9456a0-db45-445f-87a0-58737bb89313	c599dde6-99b1-4e0e-a4cf-2842c8f62162	13	13	2026-06-29 08:42:30.839291+00	2026-06-29 08:42:30.839291+00
e4163fba-76c1-4269-82d8-ab114c296a9b	5b9456a0-db45-445f-87a0-58737bb89313	3d58a7df-9922-413e-b42a-c2f162fb834c	14	12	2026-06-29 08:42:30.839291+00	2026-06-29 08:42:30.839291+00
5f34e568-0780-4ae4-b080-7e983314c6b8	5b9456a0-db45-445f-87a0-58737bb89313	71391ec7-5614-4690-8008-e2e16163570b	15	11	2026-06-29 08:42:30.839291+00	2026-06-29 08:42:30.839291+00
9302a659-ec17-498e-91d4-5354c12cbd26	5b9456a0-db45-445f-87a0-58737bb89313	ce064aab-7c13-4db9-89b3-7eb444cc158b	16	11	2026-06-29 08:42:30.839291+00	2026-06-29 08:42:30.839291+00
ca87ef64-fde5-461e-8330-c563097f915e	5b9456a0-db45-445f-87a0-58737bb89313	fea5b705-eab8-4ba4-b0f2-739b370efd98	17	11	2026-06-29 08:42:30.839291+00	2026-06-29 08:42:30.839291+00
858f179f-f64c-442e-b9eb-f095b6b4bdcd	5b9456a0-db45-445f-87a0-58737bb89313	36e379ae-18cb-488c-a9ef-34e99c796cfe	18	11	2026-06-29 08:42:30.839291+00	2026-06-29 08:42:30.839291+00
5a72798f-6c56-40f3-a796-5006a47e2cc4	5b9456a0-db45-445f-87a0-58737bb89313	3fe745df-9187-41d7-a785-c3736a7277d7	19	10	2026-06-29 08:42:30.839291+00	2026-06-29 08:42:30.839291+00
6f1a5e3e-0d48-40ff-a4d1-39cbda060f6f	5b9456a0-db45-445f-87a0-58737bb89313	b94d44f2-7ae2-41f4-a105-e12b6ec3a572	20	10	2026-06-29 08:42:30.839291+00	2026-06-29 08:42:30.839291+00
01ae98a0-d82a-419c-89d5-9287e8f2666a	5b9456a0-db45-445f-87a0-58737bb89313	b3d06ab8-28c8-4e46-a174-1da15c08949c	21	10	2026-06-29 08:42:30.839291+00	2026-06-29 08:42:30.839291+00
9e4c680f-f63d-41c8-8caa-c4be861ed2d7	5b9456a0-db45-445f-87a0-58737bb89313	195dcc37-e60e-4608-a0dc-c12766e96259	22	10	2026-06-29 08:42:30.839291+00	2026-06-29 08:42:30.839291+00
0a31d895-54ba-419a-9231-1912407bfd4d	5b9456a0-db45-445f-87a0-58737bb89313	5e429458-4e6f-4df7-88bd-43977c8f74b1	23	9	2026-06-29 08:42:30.839291+00	2026-06-29 08:42:30.839291+00
1619ee4a-ee05-4ada-992d-637a8921c32e	5b9456a0-db45-445f-87a0-58737bb89313	d8cc0ff6-c084-4134-8931-bf514fa05f23	24	9	2026-06-29 08:42:30.839291+00	2026-06-29 08:42:30.839291+00
8c815a75-8377-4925-ae8f-8f0332673034	5b9456a0-db45-445f-87a0-58737bb89313	6f8a0f72-aa76-4252-9486-cc8b95570923	25	9	2026-06-29 08:42:30.839291+00	2026-06-29 08:42:30.839291+00
a78a2f25-46e3-461c-aebf-422e73b4f926	5b9456a0-db45-445f-87a0-58737bb89313	1cc4459a-e518-4a28-b323-7cbb9d07994a	26	9	2026-06-29 08:42:30.839291+00	2026-06-29 08:42:30.839291+00
7c5303ba-d9aa-433c-9618-817563f07bf3	5b9456a0-db45-445f-87a0-58737bb89313	03d17e40-bb16-4728-9043-ceb05e62c9e9	27	7	2026-06-29 08:42:30.839291+00	2026-06-29 08:42:30.839291+00
a83f6416-715c-4b6c-a8fc-335d43de57e6	6aa7c75c-0fc8-46f0-8219-84f969510a0e	3422f6a8-d289-4ce8-8135-b547ff0f9606	1	23	2026-07-15 21:05:07.755299+00	2026-07-15 21:05:07.755299+00
9fe25352-7eaf-42c1-900d-7ceeaa0463cd	6aa7c75c-0fc8-46f0-8219-84f969510a0e	1243a746-100c-460a-bf0f-2aadef7332b8	2	22	2026-07-15 21:05:07.755299+00	2026-07-15 21:05:07.755299+00
ea66ef7f-2ea8-4fb3-bc93-78365a9b785b	6aa7c75c-0fc8-46f0-8219-84f969510a0e	5d4ce78f-67ee-4a61-afab-c44ffc6afe91	3	20	2026-07-15 21:05:07.755299+00	2026-07-15 21:05:07.755299+00
352780ce-9907-43ba-8a4d-1a22e5d76f18	6aa7c75c-0fc8-46f0-8219-84f969510a0e	8050b663-c1ef-4a14-86bd-3ea225435c17	4	20	2026-07-15 21:05:07.755299+00	2026-07-15 21:05:07.755299+00
373b86a7-31c0-40e0-9987-51350fcd2175	6aa7c75c-0fc8-46f0-8219-84f969510a0e	71391ec7-5614-4690-8008-e2e16163570b	5	19	2026-07-15 21:05:07.755299+00	2026-07-15 21:05:07.755299+00
2ade93c9-3ca2-4afc-a464-4561bafb56d3	6aa7c75c-0fc8-46f0-8219-84f969510a0e	38120818-5997-43e2-a907-f86000cf4b53	6	19	2026-07-15 21:05:07.755299+00	2026-07-15 21:05:07.755299+00
6010da2e-6d3a-44e0-9c16-60142627be97	6aa7c75c-0fc8-46f0-8219-84f969510a0e	ed3a6f56-12b3-4f1a-ab83-4744531df4f1	7	19	2026-07-15 21:05:07.755299+00	2026-07-15 21:05:07.755299+00
955a6ac9-b843-4184-ba30-9711284ec270	6aa7c75c-0fc8-46f0-8219-84f969510a0e	e73bedf4-0330-41d0-b1e7-31cb55909eed	8	18	2026-07-15 21:05:07.755299+00	2026-07-15 21:05:07.755299+00
33f6d1f3-a7d5-4a1b-b05b-c8cffa68ed23	6aa7c75c-0fc8-46f0-8219-84f969510a0e	b8526be4-5eb8-4f89-b015-699537c368ce	9	17	2026-07-15 21:05:07.755299+00	2026-07-15 21:05:07.755299+00
b8385630-fad1-49a4-bc59-ccccc6c911fe	6aa7c75c-0fc8-46f0-8219-84f969510a0e	31780afe-855c-4c9d-9cf6-56e3570c00c4	10	17	2026-07-15 21:05:07.755299+00	2026-07-15 21:05:07.755299+00
aa785ea9-f27f-4a5a-89da-36543800b87f	6aa7c75c-0fc8-46f0-8219-84f969510a0e	3fe745df-9187-41d7-a785-c3736a7277d7	11	16	2026-07-15 21:05:07.755299+00	2026-07-15 21:05:07.755299+00
9753f69c-b054-4c1f-8cdf-deecaa851234	6aa7c75c-0fc8-46f0-8219-84f969510a0e	195dcc37-e60e-4608-a0dc-c12766e96259	12	16	2026-07-15 21:05:07.755299+00	2026-07-15 21:05:07.755299+00
19e9681c-2dba-46db-a575-f44cc9f07837	6aa7c75c-0fc8-46f0-8219-84f969510a0e	1114a750-be9a-44a9-8d82-001931ea4466	13	15	2026-07-15 21:05:07.755299+00	2026-07-15 21:05:07.755299+00
ce79981b-1595-4da4-8d92-050dfaaaf89b	6aa7c75c-0fc8-46f0-8219-84f969510a0e	c599dde6-99b1-4e0e-a4cf-2842c8f62162	14	15	2026-07-15 21:05:07.755299+00	2026-07-15 21:05:07.755299+00
328d5265-8ce1-43ce-9c99-12b4e15ecde3	6aa7c75c-0fc8-46f0-8219-84f969510a0e	6df76041-17a2-4c81-b653-82bb7124ee3f	15	14	2026-07-15 21:05:07.755299+00	2026-07-15 21:05:07.755299+00
f55bed59-bf37-4f9f-9dfa-f40064618dfb	6aa7c75c-0fc8-46f0-8219-84f969510a0e	1c570e30-214d-4723-96d3-0669c937f5a4	16	14	2026-07-15 21:05:07.755299+00	2026-07-15 21:05:07.755299+00
c268f6e7-3bf2-4f6c-b3f9-84995ced68a6	6aa7c75c-0fc8-46f0-8219-84f969510a0e	03d17e40-bb16-4728-9043-ceb05e62c9e9	17	13	2026-07-15 21:05:07.755299+00	2026-07-15 21:05:07.755299+00
dfcd88b8-f47b-49cb-bbe2-1cf98a50dd8c	6aa7c75c-0fc8-46f0-8219-84f969510a0e	3d58a7df-9922-413e-b42a-c2f162fb834c	18	13	2026-07-15 21:05:07.755299+00	2026-07-15 21:05:07.755299+00
f5fcf277-446d-4cff-a597-e9ea44aa1ba1	6aa7c75c-0fc8-46f0-8219-84f969510a0e	b94d44f2-7ae2-41f4-a105-e12b6ec3a572	19	12	2026-07-15 21:05:07.755299+00	2026-07-15 21:05:07.755299+00
e7cf67c2-3bcf-4217-befd-4658217a768e	6aa7c75c-0fc8-46f0-8219-84f969510a0e	ce064aab-7c13-4db9-89b3-7eb444cc158b	20	12	2026-07-15 21:05:07.755299+00	2026-07-15 21:05:07.755299+00
37da0ba2-7911-4986-9a0a-d91062fbc658	6aa7c75c-0fc8-46f0-8219-84f969510a0e	fea5b705-eab8-4ba4-b0f2-739b370efd98	21	12	2026-07-15 21:05:07.755299+00	2026-07-15 21:05:07.755299+00
c4bb7c64-41d7-4931-bbe4-0c9d1b0fb224	6aa7c75c-0fc8-46f0-8219-84f969510a0e	36e379ae-18cb-488c-a9ef-34e99c796cfe	22	12	2026-07-15 21:05:07.755299+00	2026-07-15 21:05:07.755299+00
726c56bb-74ef-4274-94a4-8a7c8826ff93	6aa7c75c-0fc8-46f0-8219-84f969510a0e	b3d06ab8-28c8-4e46-a174-1da15c08949c	23	11	2026-07-15 21:05:07.755299+00	2026-07-15 21:05:07.755299+00
a5ffa922-b8da-4fe4-b064-a10a53786dae	6aa7c75c-0fc8-46f0-8219-84f969510a0e	5e429458-4e6f-4df7-88bd-43977c8f74b1	24	10	2026-07-15 21:05:07.755299+00	2026-07-15 21:05:07.755299+00
a87d05cb-a409-4ebe-a682-a0fc7ea5b309	6aa7c75c-0fc8-46f0-8219-84f969510a0e	d8cc0ff6-c084-4134-8931-bf514fa05f23	25	10	2026-07-15 21:05:07.755299+00	2026-07-15 21:05:07.755299+00
a20ac598-4ed8-4ecd-86b4-35744fc96543	6aa7c75c-0fc8-46f0-8219-84f969510a0e	6f8a0f72-aa76-4252-9486-cc8b95570923	26	10	2026-07-15 21:05:07.755299+00	2026-07-15 21:05:07.755299+00
80fd7cd5-4cb9-453d-82e6-9f5f6302b462	6aa7c75c-0fc8-46f0-8219-84f969510a0e	1cc4459a-e518-4a28-b323-7cbb9d07994a	27	10	2026-07-15 21:05:07.755299+00	2026-07-15 21:05:07.755299+00
d3ddc10a-b456-46ae-82c0-af8a70356083	b9bd6954-7f07-432a-af76-2dc2d3e9ab1f	3422f6a8-d289-4ce8-8135-b547ff0f9606	1	25	2026-07-19 22:03:06.610381+00	2026-07-19 22:03:06.610381+00
43a740f1-19f4-4784-9eef-e956df98b452	b9bd6954-7f07-432a-af76-2dc2d3e9ab1f	1243a746-100c-460a-bf0f-2aadef7332b8	2	22	2026-07-19 22:03:06.610381+00	2026-07-19 22:03:06.610381+00
cc36b0aa-d1f9-40ef-b0c0-eb3a34aa2fda	b9bd6954-7f07-432a-af76-2dc2d3e9ab1f	5d4ce78f-67ee-4a61-afab-c44ffc6afe91	3	20	2026-07-19 22:03:06.610381+00	2026-07-19 22:03:06.610381+00
9e3c8a65-73ad-43a5-ae63-598fdb819c6e	b9bd6954-7f07-432a-af76-2dc2d3e9ab1f	8050b663-c1ef-4a14-86bd-3ea225435c17	4	20	2026-07-19 22:03:06.610381+00	2026-07-19 22:03:06.610381+00
2846f03a-4334-4852-8179-8f14086b1d10	b9bd6954-7f07-432a-af76-2dc2d3e9ab1f	71391ec7-5614-4690-8008-e2e16163570b	5	19	2026-07-19 22:03:06.610381+00	2026-07-19 22:03:06.610381+00
ec26669a-4c99-405e-af47-0dffd520419a	b9bd6954-7f07-432a-af76-2dc2d3e9ab1f	38120818-5997-43e2-a907-f86000cf4b53	6	19	2026-07-19 22:03:06.610381+00	2026-07-19 22:03:06.610381+00
bcd4b343-bf63-41ac-9147-efa6f522e67d	b9bd6954-7f07-432a-af76-2dc2d3e9ab1f	ed3a6f56-12b3-4f1a-ab83-4744531df4f1	7	19	2026-07-19 22:03:06.610381+00	2026-07-19 22:03:06.610381+00
40fb8375-4438-4de4-8671-d3a57ab44bda	b9bd6954-7f07-432a-af76-2dc2d3e9ab1f	e73bedf4-0330-41d0-b1e7-31cb55909eed	8	18	2026-07-19 22:03:06.610381+00	2026-07-19 22:03:06.610381+00
218b5b80-0ea2-4d16-a6c3-b5e838c5393b	b9bd6954-7f07-432a-af76-2dc2d3e9ab1f	b8526be4-5eb8-4f89-b015-699537c368ce	9	17	2026-07-19 22:03:06.610381+00	2026-07-19 22:03:06.610381+00
ca604be7-660a-4803-8edf-b2c34236a4df	b9bd6954-7f07-432a-af76-2dc2d3e9ab1f	31780afe-855c-4c9d-9cf6-56e3570c00c4	10	17	2026-07-19 22:03:06.610381+00	2026-07-19 22:03:06.610381+00
4d380fc5-bdc3-40eb-9c21-f47232f79cae	b9bd6954-7f07-432a-af76-2dc2d3e9ab1f	3fe745df-9187-41d7-a785-c3736a7277d7	11	16	2026-07-19 22:03:06.610381+00	2026-07-19 22:03:06.610381+00
def92328-4e6d-4bcd-a010-cc16da286312	b9bd6954-7f07-432a-af76-2dc2d3e9ab1f	195dcc37-e60e-4608-a0dc-c12766e96259	12	16	2026-07-19 22:03:06.610381+00	2026-07-19 22:03:06.610381+00
c0bd162e-f394-4aa8-8b05-b8bbd3ef9aa3	b9bd6954-7f07-432a-af76-2dc2d3e9ab1f	1114a750-be9a-44a9-8d82-001931ea4466	13	15	2026-07-19 22:03:06.610381+00	2026-07-19 22:03:06.610381+00
21540ec7-c4de-453d-bb0f-e46645c461b3	b9bd6954-7f07-432a-af76-2dc2d3e9ab1f	c599dde6-99b1-4e0e-a4cf-2842c8f62162	14	15	2026-07-19 22:03:06.610381+00	2026-07-19 22:03:06.610381+00
a82173ee-e6ba-4e11-b868-19fd9d5628d7	b9bd6954-7f07-432a-af76-2dc2d3e9ab1f	6df76041-17a2-4c81-b653-82bb7124ee3f	15	14	2026-07-19 22:03:06.610381+00	2026-07-19 22:03:06.610381+00
32f552c2-2df7-4805-bee3-a468295bf118	b9bd6954-7f07-432a-af76-2dc2d3e9ab1f	1c570e30-214d-4723-96d3-0669c937f5a4	16	14	2026-07-19 22:03:06.610381+00	2026-07-19 22:03:06.610381+00
f35403bb-f218-4a67-a142-e790ecec9973	b9bd6954-7f07-432a-af76-2dc2d3e9ab1f	03d17e40-bb16-4728-9043-ceb05e62c9e9	17	13	2026-07-19 22:03:06.610381+00	2026-07-19 22:03:06.610381+00
feca1e65-0bb5-426c-a00d-136f2d0f7ce3	b9bd6954-7f07-432a-af76-2dc2d3e9ab1f	3d58a7df-9922-413e-b42a-c2f162fb834c	18	13	2026-07-19 22:03:06.610381+00	2026-07-19 22:03:06.610381+00
ed945b76-d764-479c-8673-0d822902df58	b9bd6954-7f07-432a-af76-2dc2d3e9ab1f	b94d44f2-7ae2-41f4-a105-e12b6ec3a572	19	12	2026-07-19 22:03:06.610381+00	2026-07-19 22:03:06.610381+00
4053c32f-d268-4c55-aaef-549098fd9f26	b9bd6954-7f07-432a-af76-2dc2d3e9ab1f	ce064aab-7c13-4db9-89b3-7eb444cc158b	20	12	2026-07-19 22:03:06.610381+00	2026-07-19 22:03:06.610381+00
1e69eab0-7b6e-4730-be2d-07b0daa0c0bb	b9bd6954-7f07-432a-af76-2dc2d3e9ab1f	fea5b705-eab8-4ba4-b0f2-739b370efd98	21	12	2026-07-19 22:03:06.610381+00	2026-07-19 22:03:06.610381+00
375c3c11-294f-4be1-af80-36862c6287e8	b9bd6954-7f07-432a-af76-2dc2d3e9ab1f	36e379ae-18cb-488c-a9ef-34e99c796cfe	22	12	2026-07-19 22:03:06.610381+00	2026-07-19 22:03:06.610381+00
ef57ecd4-3888-4728-b45b-ba66e62acd7a	b9bd6954-7f07-432a-af76-2dc2d3e9ab1f	b3d06ab8-28c8-4e46-a174-1da15c08949c	23	11	2026-07-19 22:03:06.610381+00	2026-07-19 22:03:06.610381+00
1bc63e37-fb3b-4af7-a59d-a4a5fcaecaa2	b9bd6954-7f07-432a-af76-2dc2d3e9ab1f	5e429458-4e6f-4df7-88bd-43977c8f74b1	24	10	2026-07-19 22:03:06.610381+00	2026-07-19 22:03:06.610381+00
22157552-d7f5-41c5-ad44-93e12840d0c4	b9bd6954-7f07-432a-af76-2dc2d3e9ab1f	d8cc0ff6-c084-4134-8931-bf514fa05f23	25	10	2026-07-19 22:03:06.610381+00	2026-07-19 22:03:06.610381+00
aa4917a9-9f7c-4cde-ae1e-310cea696928	b9bd6954-7f07-432a-af76-2dc2d3e9ab1f	6f8a0f72-aa76-4252-9486-cc8b95570923	26	10	2026-07-19 22:03:06.610381+00	2026-07-19 22:03:06.610381+00
8f923d4b-0ec9-4904-b478-2f7026e0f00f	b9bd6954-7f07-432a-af76-2dc2d3e9ab1f	1cc4459a-e518-4a28-b323-7cbb9d07994a	27	10	2026-07-19 22:03:06.610381+00	2026-07-19 22:03:06.610381+00
\.


--
-- Data for Name: matches; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.matches (id, round_id, home_team_id, away_team_id, kickoff, home_score, away_score, status, odds_home, odds_draw, odds_away, odds_updated_at, created_at, is_third_place, pens_winner_id, match_number, venue, confirmed, elapsed_minutes, api_status, odds_home_prev, odds_draw_prev, odds_away_prev, expected_home_score, expected_away_score) FROM stdin;
63b7d74c-799e-46b5-a7ca-282dfb8fcecb	5f39c536-340b-4981-b59a-4a9d7aff9e1e	1b2fe4cc-3105-4e0b-b1ff-06f91c466ef7	a681c714-630a-487f-b167-9cefea486591	2026-07-01 16:00:00+00	2	1	complete	1.25	5.00	12.00	\N	2026-04-19 19:45:22.650156+00	f	\N	80	Atlanta	t	\N	FINISHED	1.29	5	11	\N	\N
2e98ff8b-14f8-427d-bf77-320b06b02c7c	5f39c536-340b-4981-b59a-4a9d7aff9e1e	acfbd82a-7005-41b9-9613-606ceefc857e	b6afbe52-5067-4263-a750-6101f6efedc0	2026-07-03 03:00:00+00	2	0	complete	2.00	3.20	3.80	\N	2026-04-19 19:45:22.650156+00	f	\N	85	Vancouver	t	\N	FINISHED	2	3.2	3.8	\N	\N
7b1532a6-5ab7-4341-96ab-1788fc4f97e1	5f39c536-340b-4981-b59a-4a9d7aff9e1e	6ea9375b-d599-463f-96e6-c87d9209e9b2	52eaa3b4-081b-4393-b291-d69c644c612e	2026-07-02 19:00:00+00	3	0	complete	1.33	4.80	9.00	\N	2026-04-19 19:45:22.650156+00	f	\N	84	Los Angeles	t	\N	FINISHED	1.33	4.8	9	\N	\N
356341b8-bf0c-49e3-9811-85ca67b9eea8	5f39c536-340b-4981-b59a-4a9d7aff9e1e	95b1e39e-97c3-4d45-9714-3f507d7c52f1	1270b02b-ff92-4068-a52e-ae90bcae805b	2026-07-03 22:00:00+00	3	2	complete	1.12	8.00	19.00	\N	2026-04-19 19:45:22.650156+00	f	\N	86	Miami	t	\N	FINISHED	1.14	7.5	21	\N	\N
236c08bc-7541-4651-8d66-87c6d653553a	5f39c536-340b-4981-b59a-4a9d7aff9e1e	54ef8b7c-5afd-4a48-a3b9-d6701dd757f9	20e98c7a-4548-44f8-964d-7aba42ae7624	2026-06-30 17:00:00+00	1	2	complete	3.50	3.40	2.05	\N	2026-04-19 19:45:29.973987+00	f	\N	78	Dallas	t	\N	FINISHED	3.6	3.4	2	\N	\N
8c96ab78-96b6-44ea-bae7-7ceaff6233aa	5f39c536-340b-4981-b59a-4a9d7aff9e1e	f2c7a0c3-9a4c-4e3f-92a3-39abff0ce8e2	910a4a31-591d-4c32-8b57-b0d0bbde5a26	2026-06-30 21:00:00+00	3	0	complete	1.29	5.50	9.50	\N	2026-04-19 19:45:22.650156+00	f	\N	77	New York	t	\N	FINISHED	1.25	5.8	9	\N	\N
7a401e03-6574-47d7-b91c-a7de7c3ed1dd	aa9754bd-50eb-4785-8698-e56c6d3cb661	6ea9375b-d599-463f-96e6-c87d9209e9b2	8682004e-e186-4705-aa29-9704b2815dc4	2026-07-10 19:00:00+00	2	1	complete	1.62	3.80	5.00	\N	2026-04-19 19:45:22.650156+00	f	\N	98	Los Angeles	t	\N	FINISHED	1.6	3.8	5.5	\N	\N
674d531c-ea1e-4fb8-b533-cb72f31d2a07	5f39c536-340b-4981-b59a-4a9d7aff9e1e	e171e736-56f2-44fa-92b5-b0653ea2ce2a	61d8b501-96d1-4043-a2b7-de27e9b137d7	2026-07-04 01:30:00+00	1	0	complete	1.40	4.00	7.50	\N	2026-04-19 19:45:29.973987+00	f	\N	87	Kansas City	t	\N	FINISHED	1.4	4	8.5	\N	\N
623afe5d-5dc9-413f-8931-6f08795bf386	5b9456a0-db45-445f-87a0-58737bb89313	ddd77a2f-eb9f-4a20-8ae4-e1ca55c21893	f959649f-d7be-48e3-9129-58e7fc519606	2026-06-27 03:00:00+00	1	1	complete	2.40	2.70	3.30	\N	2026-04-14 18:08:42.801797+00	f	\N	63	Seattle	t	\N	FINISHED	2.45	2.7	3.3	2	1
7f870462-0943-4624-8daa-38ddf5354a2f	5b9456a0-db45-445f-87a0-58737bb89313	e171e736-56f2-44fa-92b5-b0653ea2ce2a	eaca3063-d90c-4007-b3d8-ba829b3ee14e	2026-06-27 23:30:00+00	0	0	complete	3.40	3.60	1.95	\N	2026-04-14 18:08:42.801797+00	f	\N	71	Miami	t	\N	FINISHED	3.9	3.6	1.85	1	3
7d4539bf-823e-4e2f-bf44-76939f82f166	c22e6746-73c1-4060-9194-eb35359c955e	8d109cbf-133f-496a-b5b7-3f75a0ec1dcd	8cccecd8-b1ab-4159-bf35-29ef0db369c4	2026-06-23 23:00:00+00	0	1	complete	6.50	4.00	1.44	\N	2026-04-14 18:08:42.801797+00	f	\N	46	Toronto	t	\N	FINISHED	6.5	3.8	1.5	0	1
89faf49a-c4d3-43da-9c28-461f46e56075	5b9456a0-db45-445f-87a0-58737bb89313	c8e5c035-af92-4497-b96c-82f2c0a15214	f99d6725-238c-4d95-8502-9d25b4a6e89e	2026-06-26 02:00:00+00	0	0	complete	2.70	2.25	3.60	\N	2026-04-14 18:08:42.801797+00	f	\N	60	San Francisco	t	\N	FINISHED	2.7	2.25	3.6	1	1
4e6332aa-4d1e-4c23-b657-4d3dd2747af3	c22e6746-73c1-4060-9194-eb35359c955e	f2c7a0c3-9a4c-4e3f-92a3-39abff0ce8e2	f27875c8-4818-4323-8d45-333b7f82cf57	2026-06-22 21:00:00+00	3	0	complete	1.10	10.00	23.00	\N	2026-04-14 18:08:42.801797+00	f	\N	42	Philadelphia	t	\N	FINISHED	1.08	10	29	3	0
1aa10d87-0313-4753-98b0-d24ab8bb444c	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	6527ec07-bc6b-4b53-8bff-90b6f622aece	c8e5c035-af92-4497-b96c-82f2c0a15214	2026-06-13 01:00:00+00	4	1	complete	2.00	3.20	3.70	\N	2026-04-14 18:08:42.801797+00	f	\N	4	Los Angeles	t	\N	FINISHED	\N	\N	\N	\N	\N
8b694d3b-c857-43c4-a291-9d03ed28a289	5b9456a0-db45-445f-87a0-58737bb89313	cd984ce3-2f2c-41d5-a7ba-137060caf8ae	cffa413c-8c76-45a6-843e-87c34e78e45a	2026-06-25 20:00:00+00	2	1	complete	3.70	3.80	1.85	\N	2026-04-14 18:08:42.801797+00	f	\N	56	New York	t	\N	FINISHED	3.5	3.8	1.85	1	2
585588af-146a-483b-88c3-795bd93acb0a	5b9456a0-db45-445f-87a0-58737bb89313	66a8014f-0009-400e-928c-6b28cb8dab1f	910a4a31-591d-4c32-8b57-b0d0bbde5a26	2026-06-25 23:00:00+00	1	1	complete	1.85	3.60	3.80	\N	2026-04-14 18:08:42.801797+00	f	\N	57	Dallas	t	\N	FINISHED	1.85	3.6	3.8	2	2
baf4d1d7-c901-44dd-b105-d8848a8aa6f6	5b9456a0-db45-445f-87a0-58737bb89313	a1cbc3f2-826a-4c04-803b-b5c2930d3c42	2044181c-c7e7-4759-8101-4779166812e3	2026-06-25 23:00:00+00	1	3	complete	26.00	9.50	1.10	\N	2026-04-14 18:08:42.801797+00	f	\N	58	Kansas City	t	\N	FINISHED	21	8	1.12	0	1
f1597d1c-d2cb-4027-86e1-0ba93a331041	5b9456a0-db45-445f-87a0-58737bb89313	a681c714-630a-487f-b167-9cefea486591	ef919163-49fb-4cc5-ab4e-f55d9419d806	2026-06-27 23:30:00+00	3	1	complete	1.67	3.90	4.60	\N	2026-04-14 18:08:42.801797+00	f	\N	72	Atlanta	t	\N	FINISHED	1.75	3.8	4	2	1
d094ec78-e479-4f3b-b030-b45e918c43ba	c22e6746-73c1-4060-9194-eb35359c955e	aa0baf4e-af82-4020-9093-715971d63105	b6afbe52-5067-4263-a750-6101f6efedc0	2026-06-23 03:00:00+00	1	2	complete	6.00	4.00	1.50	\N	2026-04-14 18:08:42.801797+00	f	\N	44	San Francisco	t	\N	FINISHED	5.5	3.8	1.57	1	2
3fade0b4-4567-4b5f-b099-f865cca5e2ed	5b9456a0-db45-445f-87a0-58737bb89313	8cccecd8-b1ab-4159-bf35-29ef0db369c4	61d8b501-96d1-4043-a2b7-de27e9b137d7	2026-06-27 21:00:00+00	2	1	complete	1.85	3.10	4.40	\N	2026-04-14 18:08:42.801797+00	f	\N	68	Philadelphia	t	\N	FINISHED	1.73	3.3	5	2	1
67423ac2-4ae3-42ec-b786-c3b824a15d4e	5b9456a0-db45-445f-87a0-58737bb89313	87881cf2-7a14-4afa-9912-0ef5b2672387	6527ec07-bc6b-4b53-8bff-90b6f622aece	2026-06-26 02:00:00+00	3	2	complete	3.60	3.90	1.83	\N	2026-04-14 18:08:42.801797+00	f	\N	59	Los Angeles	t	\N	FINISHED	3.6	3.9	1.83	1	2
bd96de28-090a-4f99-8d20-7fb5e86a7380	c22e6746-73c1-4060-9194-eb35359c955e	eaca3063-d90c-4007-b3d8-ba829b3ee14e	ef919163-49fb-4cc5-ab4e-f55d9419d806	2026-06-23 17:00:00+00	5	0	complete	1.15	7.50	15.00	\N	2026-04-14 18:08:42.801797+00	f	\N	47	Houston	t	\N	FINISHED	1.18	6.5	15	2	0
2b8d5341-a73c-40fb-a9e4-975e879b65d3	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	4f0f3776-f99f-4c06-9eb4-0acd2825d8c2	4976e7fd-9b45-4cc7-b741-fe801fcee2d0	2026-06-12 19:00:00+00	1	1	complete	1.80	3.30	4.50	\N	2026-04-14 18:08:42.801797+00	f	\N	3	Toronto	t	\N	FINISHED	\N	\N	\N	\N	\N
7bb5f910-03ca-4de7-abb9-96cb4ec53f63	5b9456a0-db45-445f-87a0-58737bb89313	20e98c7a-4548-44f8-964d-7aba42ae7624	f2c7a0c3-9a4c-4e3f-92a3-39abff0ce8e2	2026-06-26 19:00:00+00	1	4	complete	4.60	4.33	1.62	\N	2026-04-14 18:08:42.801797+00	f	\N	61	Boston	t	\N	FINISHED	4.5	4.33	1.62	0	1
e2495259-08ed-45c8-8e9c-25cbcc0d349f	5b9456a0-db45-445f-87a0-58737bb89313	8d109cbf-133f-496a-b5b7-3f75a0ec1dcd	1b2fe4cc-3105-4e0b-b1ff-06f91c466ef7	2026-06-27 21:00:00+00	0	2	complete	13.00	7.50	1.17	\N	2026-04-14 18:08:42.801797+00	f	\N	67	New York	t	\N	FINISHED	13	7.5	1.17	1	4
61a1b8a8-c713-460a-989e-9a4494ed4758	5b9456a0-db45-445f-87a0-58737bb89313	b6afbe52-5067-4263-a750-6101f6efedc0	52eaa3b4-081b-4393-b291-d69c644c612e	2026-06-28 02:00:00+00	3	3	complete	3.50	2.25	2.62	\N	2026-04-14 18:08:42.801797+00	f	\N	69	Kansas City	t	\N	FINISHED	3.5	2.25	2.62	0	1
1e0e13f8-56b5-42c1-bd5a-8530c015553c	5f39c536-340b-4981-b59a-4a9d7aff9e1e	f99d6725-238c-4d95-8502-9d25b4a6e89e	ddd77a2f-eb9f-4a20-8ae4-e1ca55c21893	2026-07-03 18:00:00+00	1	1	complete	3.40	2.88	2.30	\N	2026-04-19 19:45:29.973987+00	f	ddd77a2f-eb9f-4a20-8ae4-e1ca55c21893	88	Dallas	t	\N	FINISHED_PENS_AWAY	3.2	2.8	2.4	\N	\N
93786882-4ea3-4057-adcd-89e8fe90ba67	5f39c536-340b-4981-b59a-4a9d7aff9e1e	eaca3063-d90c-4007-b3d8-ba829b3ee14e	8cccecd8-b1ab-4159-bf35-29ef0db369c4	2026-07-02 23:00:00+00	2	1	complete	1.65	3.80	4.80	\N	2026-04-19 19:45:22.650156+00	f	\N	83	Toronto	t	\N	FINISHED	1.75	3.4	4.8	\N	\N
75b95055-eae5-422d-95d9-f53306255944	5b9456a0-db45-445f-87a0-58737bb89313	1270b02b-ff92-4068-a52e-ae90bcae805b	622bb3ef-bc6e-4c9a-9efe-aae4d0f95822	2026-06-27 00:00:00+00	0	0	complete	2.62	3.10	2.62	\N	2026-04-14 18:08:42.801797+00	f	\N	65	Houston	t	\N	FINISHED	2.62	3.1	2.62	1	2
006b2c74-d118-431d-b856-d6b2fa148d07	c22e6746-73c1-4060-9194-eb35359c955e	95b1e39e-97c3-4d45-9714-3f507d7c52f1	52eaa3b4-081b-4393-b291-d69c644c612e	2026-06-22 17:00:00+00	2	0	complete	1.44	4.00	7.00	\N	2026-04-14 18:08:42.801797+00	f	\N	43	Dallas	t	\N	FINISHED	1.6	3.75	5.5	2	0
e71dd1df-caa8-4b10-8ffb-220c4e918698	c22e6746-73c1-4060-9194-eb35359c955e	8682004e-e186-4705-aa29-9704b2815dc4	f959649f-d7be-48e3-9129-58e7fc519606	2026-06-21 19:00:00+00	0	0	complete	1.44	4.33	7.00	\N	2026-04-14 18:08:42.801797+00	f	\N	39	Los Angeles	t	\N	FINISHED	1.4	4.4	7	2	1
5688eceb-e867-4cbb-a673-0677aacc75f2	c22e6746-73c1-4060-9194-eb35359c955e	ee8ecff9-d0b1-4aa8-ab21-da08a6c9229a	1270b02b-ff92-4068-a52e-ae90bcae805b	2026-06-21 22:00:00+00	2	2	complete	1.44	3.90	7.00	\N	2026-04-14 18:08:42.801797+00	f	\N	37	Miami	t	\N	FINISHED	1.44	3.9	7	3	0
1fd593cc-3f89-4335-8c34-1d4183911037	5f39c536-340b-4981-b59a-4a9d7aff9e1e	2044181c-c7e7-4759-8101-4779166812e3	fcc03c57-8857-4986-98b0-0e30fb42ab2a	2026-06-30 01:00:00+00	1	1	complete	2.30	3.00	3.10	\N	2026-04-19 19:45:22.650156+00	f	fcc03c57-8857-4986-98b0-0e30fb42ab2a	75	Monterrey	t	\N	FINISHED_PENS_AWAY	2.25	3	3.3	\N	\N
34faf1f8-d253-4f37-a9d3-6f7806842d1b	c22e6746-73c1-4060-9194-eb35359c955e	6ea9375b-d599-463f-96e6-c87d9209e9b2	622bb3ef-bc6e-4c9a-9efe-aae4d0f95822	2026-06-21 16:00:00+00	4	0	complete	1.10	9.50	29.00	\N	2026-04-14 18:08:42.801797+00	f	\N	38	Atlanta	t	\N	FINISHED	1.1	9.5	29	2	1
09779cac-8a10-4c3d-a107-9f9490f548f1	c22e6746-73c1-4060-9194-eb35359c955e	acfbd82a-7005-41b9-9613-606ceefc857e	4976e7fd-9b45-4cc7-b741-fe801fcee2d0	2026-06-18 19:00:00+00	4	1	complete	1.55	3.90	5.80	\N	2026-04-14 18:08:42.801797+00	f	\N	26	Los Angeles	t	\N	FINISHED	1.53	3.9	6	1	0
558a4b5f-74e2-4687-95d5-2f6e52c5acc7	5b9456a0-db45-445f-87a0-58737bb89313	ee8ecff9-d0b1-4aa8-ab21-da08a6c9229a	6ea9375b-d599-463f-96e6-c87d9209e9b2	2026-06-27 00:00:00+00	0	1	complete	5.50	3.30	1.67	\N	2026-04-14 18:08:42.801797+00	f	\N	66	Guadalajara	t	\N	FINISHED	5.8	3.6	1.62	1	2
e51ad0e0-f1b7-449e-ad47-4e4c2559ff76	5b9456a0-db45-445f-87a0-58737bb89313	a760ffb3-5775-4d7d-b803-cf0087525d91	8682004e-e186-4705-aa29-9704b2815dc4	2026-06-27 03:00:00+00	1	5	complete	12.00	7.00	1.20	\N	2026-04-14 18:08:42.801797+00	f	\N	64	Vancouver	t	\N	FINISHED	13	7	1.18	1	3
2cc09d93-3fa3-44d0-9049-5b90ac167097	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	f99d6725-238c-4d95-8502-9d25b4a6e89e	87881cf2-7a14-4afa-9912-0ef5b2672387	2026-06-14 04:00:00+00	2	0	complete	4.80	3.60	1.67	\N	2026-04-14 18:08:42.801797+00	f	\N	6	Vancouver	t	\N	FINISHED	\N	\N	\N	\N	\N
2737b00b-6825-43fa-900a-0a522772306f	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	7f560d60-00fc-46e1-b81b-4e7234b7cb04	52f066d8-0a7a-42c5-8a6b-103ec4ba2c91	2026-06-14 01:00:00+00	0	1	complete	6.00	4.20	1.50	\N	2026-04-14 18:08:42.801797+00	f	\N	5	Boston	t	\N	FINISHED	\N	\N	\N	\N	\N
0635f748-c59a-4104-b439-1c84c2e81460	5b9456a0-db45-445f-87a0-58737bb89313	151a98cf-99e8-4e7a-ab57-396a13db4a72	f27875c8-4818-4323-8d45-333b7f82cf57	2026-06-26 19:00:00+00	5	0	complete	1.20	6.00	12.00	\N	2026-04-14 18:08:42.801797+00	f	\N	62	Toronto	t	\N	FINISHED	1.22	6	12	2	1
84b62dcf-7110-46f4-ac2c-d4d5ccfbce8b	c22e6746-73c1-4060-9194-eb35359c955e	d6209663-7a5c-4736-b346-cde299b554b2	9507020f-6157-4043-ae5b-72ca12dea41e	2026-06-18 16:00:00+00	1	1	complete	1.80	3.40	4.40	\N	2026-04-14 18:08:42.801797+00	f	\N	25	Atlanta	t	\N	FINISHED	1.75	3.5	4.33	3	1
05e45fa7-7370-410b-af83-1ce4a669acfc	c22e6746-73c1-4060-9194-eb35359c955e	20e98c7a-4548-44f8-964d-7aba42ae7624	151a98cf-99e8-4e7a-ab57-396a13db4a72	2026-06-23 00:00:00+00	3	2	complete	2.10	3.30	3.25	\N	2026-04-14 18:08:42.801797+00	f	\N	41	New York	t	\N	FINISHED	2.3	3.3	2.9	1	1
2b5bb71c-92cc-4afa-b379-e31f3af967eb	c22e6746-73c1-4060-9194-eb35359c955e	2044181c-c7e7-4759-8101-4779166812e3	910a4a31-591d-4c32-8b57-b0d0bbde5a26	2026-06-20 17:00:00+00	5	1	complete	1.73	3.60	4.50	\N	2026-04-14 18:08:42.801797+00	f	\N	35	Houston	t	\N	FINISHED	1.73	3.6	4.6	2	0
6154fec4-83b3-4b8c-b92f-b8a31399f6c9	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	61d8b501-96d1-4043-a2b7-de27e9b137d7	8d109cbf-133f-496a-b5b7-3f75a0ec1dcd	2026-06-17 23:00:00+00	1	0	complete	2.30	3.10	3.00	\N	2026-04-14 18:08:42.801797+00	f	\N	21	Toronto	t	\N	FINISHED	2.25	3.2	3.1	0	0
96e26051-ad61-49e1-ac36-e36198699a57	5b9456a0-db45-445f-87a0-58737bb89313	aa0baf4e-af82-4020-9093-715971d63105	95b1e39e-97c3-4d45-9714-3f507d7c52f1	2026-06-28 02:00:00+00	1	3	complete	15.00	8.00	1.15	\N	2026-04-14 18:08:42.801797+00	f	\N	70	Dallas	t	\N	FINISHED	13	7	1.17	0	3
eef657ff-2854-4e48-8de2-114e508fe17f	c22e6746-73c1-4060-9194-eb35359c955e	cffa413c-8c76-45a6-843e-87c34e78e45a	54ef8b7c-5afd-4a48-a3b9-d6701dd757f9	2026-06-20 20:00:00+00	2	1	complete	1.53	4.20	5.00	\N	2026-04-14 18:08:42.801797+00	f	\N	33	Toronto	t	\N	FINISHED	1.53	4.2	5	1	0
447d4217-d302-49c0-980c-cd1359ccb3c5	c22e6746-73c1-4060-9194-eb35359c955e	cd984ce3-2f2c-41d5-a7ba-137060caf8ae	666ba168-4d8b-4060-8e4b-e1dd7b2a7503	2026-06-21 00:00:00+00	0	0	complete	1.10	9.50	29.00	\N	2026-04-14 18:08:42.801797+00	f	\N	34	Kansas City	t	\N	FINISHED	1.1	9.5	29	3	1
ff4b8afa-c644-4ef8-9a42-56784b08adcd	c22e6746-73c1-4060-9194-eb35359c955e	a1cbc3f2-826a-4c04-803b-b5c2930d3c42	66a8014f-0009-400e-928c-6b28cb8dab1f	2026-06-21 04:00:00+00	0	4	complete	6.00	3.80	1.53	\N	2026-04-14 18:08:42.801797+00	f	\N	36	Monterrey	t	\N	FINISHED	6	3.8	1.53	0	1
53d7793c-7e1b-4a8a-bd9e-8044f4ffc71b	c22e6746-73c1-4060-9194-eb35359c955e	4f0f3776-f99f-4c06-9eb4-0acd2825d8c2	600575e1-d737-452a-abec-c6e22da92787	2026-06-18 22:00:00+00	6	0	complete	1.29	5.00	10.00	\N	2026-04-14 18:08:42.801797+00	f	\N	27	Vancouver	t	\N	FINISHED	1.25	5	10	3	0
a7c2c157-2a27-4c63-a608-a258de256673	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	20160ec3-c507-4fb3-b19d-89cb66c59a98	d6209663-7a5c-4736-b346-cde299b554b2	2026-06-12 02:00:00+00	2	1	complete	2.62	2.90	2.80	\N	2026-04-14 18:08:42.801797+00	f	\N	2	Guadalajara	t	\N	FINISHED	\N	\N	\N	\N	\N
8b43c919-110a-4ae6-9fc8-81acfa9ba2c4	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	e176dd2c-4446-4811-b4cc-fc28e9c2ab25	9507020f-6157-4043-ae5b-72ca12dea41e	2026-06-11 19:00:00+00	2	0	complete	1.40	4.20	8.00	\N	2026-04-14 18:08:42.801797+00	f	\N	1	Mexico City	t	\N	FINISHED	\N	\N	\N	\N	\N
a3f494e7-f129-4d66-87f5-438a915a4bdb	c22e6746-73c1-4060-9194-eb35359c955e	e171e736-56f2-44fa-92b5-b0653ea2ce2a	a681c714-630a-487f-b167-9cefea486591	2026-06-24 02:00:00+00	1	0	complete	1.53	3.80	6.50	\N	2026-04-14 18:08:42.801797+00	f	\N	48	Guadalajara	t	\N	FINISHED	1.5	3.9	6.5	1	0
25314813-cb44-4dc2-a23b-09ddf7c0e193	c22e6746-73c1-4060-9194-eb35359c955e	1b2fe4cc-3105-4e0b-b1ff-06f91c466ef7	61d8b501-96d1-4043-a2b7-de27e9b137d7	2026-06-23 20:00:00+00	0	0	complete	1.20	7.00	19.00	\N	2026-04-14 18:08:42.801797+00	f	\N	45	Boston	t	\N	FINISHED	1.22	6.5	13	3	1
e4852745-20b6-45b2-aac0-af40c416c1ee	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	eaca3063-d90c-4007-b3d8-ba829b3ee14e	a681c714-630a-487f-b167-9cefea486591	2026-06-17 17:00:00+00	1	1	complete	1.29	5.00	11.00	\N	2026-04-14 18:08:42.801797+00	f	\N	23	Houston	t	\N	FINISHED	1.3	4.8	10	1	1
dbda9c0d-398c-4b92-ad6e-d55e3be3e4e7	5b9456a0-db45-445f-87a0-58737bb89313	acfbd82a-7005-41b9-9613-606ceefc857e	4f0f3776-f99f-4c06-9eb4-0acd2825d8c2	2026-06-24 19:00:00+00	2	1	complete	2.45	3.00	2.90	\N	2026-04-14 18:08:42.801797+00	f	\N	51	Vancouver	t	\N	FINISHED	2.3	3.1	3	2	0
720da904-3561-4abe-948d-4165be6de275	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	f2c7a0c3-9a4c-4e3f-92a3-39abff0ce8e2	151a98cf-99e8-4e7a-ab57-396a13db4a72	2026-06-16 19:00:00+00	3	1	complete	1.44	4.20	6.00	\N	2026-04-14 18:08:42.801797+00	f	\N	17	New York	t	\N	FINISHED	1.44	4.2	6.5	\N	\N
ce869e56-f2dc-40e2-aae8-45faa5b174d9	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	1b2fe4cc-3105-4e0b-b1ff-06f91c466ef7	8cccecd8-b1ab-4159-bf35-29ef0db369c4	2026-06-17 20:00:00+00	4	2	complete	1.70	3.60	4.75	\N	2026-04-14 18:08:42.801797+00	f	\N	22	Dallas	t	\N	FINISHED	1.7	3.6	4.75	4	2
64167916-7a8e-4126-bdc2-445e6dfd9cd8	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	52eaa3b4-081b-4393-b291-d69c644c612e	aa0baf4e-af82-4020-9093-715971d63105	2026-06-17 04:00:00+00	3	1	complete	1.33	4.80	8.50	\N	2026-04-14 18:08:42.801797+00	f	\N	20	San Francisco	t	\N	FINISHED	1.36	4.8	7.5	3	1
d6028dab-94a8-4e2f-bf47-0370f6fdcd3b	5b9456a0-db45-445f-87a0-58737bb89313	9507020f-6157-4043-ae5b-72ca12dea41e	20160ec3-c507-4fb3-b19d-89cb66c59a98	2026-06-25 01:00:00+00	1	0	complete	5.50	3.80	1.57	\N	2026-04-14 18:08:42.801797+00	f	\N	54	Monterrey	t	\N	FINISHED	5	3.6	1.67	2	3
b74d9072-2d8e-4988-ad96-c3680624ee52	c22e6746-73c1-4060-9194-eb35359c955e	6527ec07-bc6b-4b53-8bff-90b6f622aece	f99d6725-238c-4d95-8502-9d25b4a6e89e	2026-06-19 19:00:00+00	2	0	complete	1.60	4.00	5.00	\N	2026-04-14 18:08:42.801797+00	f	\N	32	Seattle	t	\N	FINISHED	1.57	4	5	1	1
5f2999a7-5535-4fe4-b0ba-a058b61fd138	5b9456a0-db45-445f-87a0-58737bb89313	666ba168-4d8b-4060-8e4b-e1dd7b2a7503	54ef8b7c-5afd-4a48-a3b9-d6701dd757f9	2026-06-25 20:00:00+00	0	2	complete	19.00	7.50	1.15	\N	2026-04-14 18:08:42.801797+00	f	\N	55	Philadelphia	t	\N	FINISHED	21	7.5	1.14	0	3
371dfc3a-483b-4b55-9462-6a8b23f9cb6e	c22e6746-73c1-4060-9194-eb35359c955e	a760ffb3-5775-4d7d-b803-cf0087525d91	ddd77a2f-eb9f-4a20-8ae4-e1ca55c21893	2026-06-22 01:00:00+00	1	3	complete	5.00	3.90	1.60	\N	2026-04-14 18:08:42.801797+00	f	\N	40	Vancouver	t	\N	FINISHED	5	3.9	1.6	0	1
95e9203a-5dfe-44fe-9946-8e2d0dc2e1a9	c22e6746-73c1-4060-9194-eb35359c955e	e176dd2c-4446-4811-b4cc-fc28e9c2ab25	20160ec3-c507-4fb3-b19d-89cb66c59a98	2026-06-19 01:00:00+00	1	0	complete	2.05	3.10	3.75	\N	2026-04-14 18:08:42.801797+00	f	\N	28	Guadalajara	t	\N	FINISHED	1.95	3.1	3.9	2	1
4645c3d2-2710-4c1f-a94b-f1a4b24de902	c22e6746-73c1-4060-9194-eb35359c955e	52f066d8-0a7a-42c5-8a6b-103ec4ba2c91	fcc03c57-8857-4986-98b0-0e30fb42ab2a	2026-06-19 22:00:00+00	0	1	complete	5.00	3.40	1.67	\N	2026-04-14 18:08:42.801797+00	f	\N	30	Boston	t	\N	FINISHED	4.8	3.4	1.73	1	2
ff8ff08a-b110-4120-a1c9-8ffe191fc2ba	c22e6746-73c1-4060-9194-eb35359c955e	cba2c884-3603-4b90-976e-49389b04f562	7f560d60-00fc-46e1-b81b-4e7234b7cb04	2026-06-20 00:30:00+00	3	0	complete	1.10	10.00	23.00	\N	2026-04-14 18:08:42.801797+00	f	\N	29	Philadelphia	t	\N	FINISHED	1.1	10	21	2	0
97d24d3d-e7f7-4611-b7b3-0609fec069b3	5b9456a0-db45-445f-87a0-58737bb89313	4976e7fd-9b45-4cc7-b741-fe801fcee2d0	600575e1-d737-452a-abec-c6e22da92787	2026-06-24 19:00:00+00	3	1	complete	1.33	5.00	8.00	\N	2026-04-14 18:08:42.801797+00	f	\N	52	Seattle	t	\N	FINISHED	1.4	4.8	6.5	1	0
799ad195-8136-4549-b477-95fe02eaef8e	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	ef919163-49fb-4cc5-ab4e-f55d9419d806	e171e736-56f2-44fa-92b5-b0653ea2ce2a	2026-06-18 02:00:00+00	1	3	complete	8.50	4.40	1.36	\N	2026-04-14 18:08:42.801797+00	f	\N	24	Mexico City	t	\N	FINISHED	9	4.5	1.36	1	3
00087c0b-a720-4e3b-acd8-4f259e3f4af7	5b9456a0-db45-445f-87a0-58737bb89313	52f066d8-0a7a-42c5-8a6b-103ec4ba2c91	cba2c884-3603-4b90-976e-49389b04f562	2026-06-24 22:00:00+00	0	3	complete	9.50	5.00	1.30	\N	2026-04-14 18:08:42.801797+00	f	\N	49	Miami	t	\N	FINISHED	9	5	1.3	0	1
6f06c3af-317c-463e-a28b-d6fb9dd411ec	c22e6746-73c1-4060-9194-eb35359c955e	87881cf2-7a14-4afa-9912-0ef5b2672387	c8e5c035-af92-4497-b96c-82f2c0a15214	2026-06-20 03:00:00+00	0	1	complete	2.00	3.25	3.60	\N	2026-04-14 18:08:42.801797+00	f	\N	31	San Francisco	t	\N	FINISHED	2	3.2	3.8	2	2
24a55af4-cc2c-4c75-a9c3-f0ba07f8965e	5b9456a0-db45-445f-87a0-58737bb89313	fcc03c57-8857-4986-98b0-0e30fb42ab2a	7f560d60-00fc-46e1-b81b-4e7234b7cb04	2026-06-24 22:00:00+00	4	2	complete	1.17	6.50	17.00	\N	2026-04-14 18:08:42.801797+00	f	\N	50	Atlanta	t	\N	FINISHED	1.18	6.5	15	3	0
4a1a38c4-fe97-4d42-a2ff-8a0caa18ff17	5b9456a0-db45-445f-87a0-58737bb89313	d6209663-7a5c-4736-b346-cde299b554b2	e176dd2c-4446-4811-b4cc-fc28e9c2ab25	2026-06-25 01:00:00+00	0	3	complete	3.60	3.60	1.91	\N	2026-04-14 18:08:42.801797+00	f	\N	53	Mexico City	t	\N	FINISHED	3.6	3.7	1.85	1	1
472a5e3d-5ce9-46a8-9abf-fa5593699943	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	f27875c8-4818-4323-8d45-333b7f82cf57	20e98c7a-4548-44f8-964d-7aba42ae7624	2026-06-16 22:00:00+00	1	4	complete	13.00	6.00	1.20	\N	2026-04-14 18:08:42.801797+00	f	\N	18	Boston	t	\N	FINISHED	13	6	1.25	\N	\N
6398048c-047b-4f02-81dc-7b7449e3bc5e	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	95b1e39e-97c3-4d45-9714-3f507d7c52f1	b6afbe52-5067-4263-a750-6101f6efedc0	2026-06-17 01:00:00+00	3	0	complete	1.40	4.20	7.50	\N	2026-04-14 18:08:42.801797+00	f	\N	19	Kansas City	t	\N	FINISHED	1.4	4.2	8	\N	\N
c482116e-ce9c-40bc-b95e-616917977de0	27ce4fc5-3de9-4cf0-bfc5-5fa0addb7081	4f0f3776-f99f-4c06-9eb4-0acd2825d8c2	fcc03c57-8857-4986-98b0-0e30fb42ab2a	2026-07-04 17:00:00+00	0	3	complete	4.60	3.25	1.83	\N	2026-04-19 19:45:22.650156+00	f	\N	90	Houston	t	\N	FINISHED	4.2	3.25	1.91	\N	\N
71d5d345-eb38-4189-a48d-bbfdc2fd74da	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	cba2c884-3603-4b90-976e-49389b04f562	fcc03c57-8857-4986-98b0-0e30fb42ab2a	2026-06-13 22:00:00+00	1	1	complete	1.60	3.90	5.00	\N	2026-04-14 18:08:42.801797+00	f	\N	7	New York	t	\N	FINISHED	\N	\N	\N	\N	\N
25cced55-f450-45fb-b776-c81cf7419b07	27ce4fc5-3de9-4cf0-bfc5-5fa0addb7081	eaca3063-d90c-4007-b3d8-ba829b3ee14e	6ea9375b-d599-463f-96e6-c87d9209e9b2	2026-07-06 19:00:00+00	0	1	complete	3.90	3.40	1.91	\N	2026-04-19 19:45:22.650156+00	f	\N	93	Dallas	t	\N	FINISHED	3.75	3.5	1.91	\N	\N
3ca50009-6690-4197-8fbb-29612575864d	27ce4fc5-3de9-4cf0-bfc5-5fa0addb7081	c8e5c035-af92-4497-b96c-82f2c0a15214	f2c7a0c3-9a4c-4e3f-92a3-39abff0ce8e2	2026-07-04 21:00:00+00	0	1	complete	15.00	6.50	1.18	\N	2026-04-19 19:45:22.650156+00	f	\N	89	Philadelphia	t	\N	FINISHED	15	7	1.18	\N	\N
8dc0c811-0f83-4784-95c6-94cd1691217e	27ce4fc5-3de9-4cf0-bfc5-5fa0addb7081	cba2c884-3603-4b90-976e-49389b04f562	20e98c7a-4548-44f8-964d-7aba42ae7624	2026-07-05 20:00:00+00	1	2	complete	1.80	3.80	4.00	\N	2026-04-19 19:45:29.973987+00	f	\N	91	New York	t	\N	FINISHED	1.85	3.5	4	\N	\N
5ff3fb62-02c7-4666-80f9-540118fecb20	27ce4fc5-3de9-4cf0-bfc5-5fa0addb7081	acfbd82a-7005-41b9-9613-606ceefc857e	e171e736-56f2-44fa-92b5-b0653ea2ce2a	2026-07-07 20:00:00+00	0	0	complete	3.25	3.00	2.30	\N	2026-04-19 19:45:29.973987+00	f	acfbd82a-7005-41b9-9613-606ceefc857e	96	Vancouver	t	\N	FINISHED_PENS_HOME	3.3	2.9	2.3	\N	\N
b58779a0-33b8-44da-905b-67c3b4f81254	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	6ea9375b-d599-463f-96e6-c87d9209e9b2	1270b02b-ff92-4068-a52e-ae90bcae805b	2026-06-15 16:00:00+00	0	0	complete	1.10	10.00	23.00	\N	2026-04-14 18:08:42.801797+00	f	\N	14	Atlanta	t	\N	FINISHED	\N	\N	\N	\N	\N
a0e08c51-817d-46fe-8016-5f5a0215b470	27ce4fc5-3de9-4cf0-bfc5-5fa0addb7081	95b1e39e-97c3-4d45-9714-3f507d7c52f1	ddd77a2f-eb9f-4a20-8ae4-e1ca55c21893	2026-07-07 16:00:00+00	3	2	complete	1.36	4.40	8.00	\N	2026-04-19 19:45:29.973987+00	f	\N	95	Atlanta	t	\N	IN_PLAY	1.4	4.33	8	\N	\N
15148b9f-4d4c-40b4-8905-e533ff0ca8d4	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	910a4a31-591d-4c32-8b57-b0d0bbde5a26	a1cbc3f2-826a-4c04-803b-b5c2930d3c42	2026-06-15 02:00:00+00	5	1	complete	1.91	3.25	4.00	\N	2026-04-14 18:08:42.801797+00	f	\N	12	Monterrey	t	\N	FINISHED	\N	\N	\N	\N	\N
7c21e0db-01cc-4536-bfe0-c6c4997e76ad	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	54ef8b7c-5afd-4a48-a3b9-d6701dd757f9	cd984ce3-2f2c-41d5-a7ba-137060caf8ae	2026-06-14 23:00:00+00	1	0	complete	3.10	2.90	2.40	\N	2026-04-14 18:08:42.801797+00	f	\N	9	Philadelphia	t	\N	FINISHED	\N	\N	\N	\N	\N
cb976605-f36a-4d43-9d53-0aa131e8421a	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	2044181c-c7e7-4759-8101-4779166812e3	66a8014f-0009-400e-928c-6b28cb8dab1f	2026-06-14 20:00:00+00	2	2	complete	2.05	3.30	3.40	\N	2026-04-14 18:08:42.801797+00	f	\N	11	Dallas	t	\N	FINISHED	\N	\N	\N	\N	\N
d7faf3e3-d358-4158-bbbc-73fde86ea30f	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	622bb3ef-bc6e-4c9a-9efe-aae4d0f95822	ee8ecff9-d0b1-4aa8-ab21-da08a6c9229a	2026-06-15 22:00:00+00	1	1	complete	7.50	4.00	1.44	\N	2026-04-14 18:08:42.801797+00	f	\N	13	Miami	t	\N	FINISHED	7.5	4	1.44	\N	\N
7a30db92-79a3-4444-92aa-08ab3f769fba	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	f959649f-d7be-48e3-9129-58e7fc519606	a760ffb3-5775-4d7d-b803-cf0087525d91	2026-06-16 01:00:00+00	2	2	complete	1.73	3.50	4.75	\N	2026-04-14 18:08:42.801797+00	f	\N	15	Los Angeles	t	\N	FINISHED	1.75	3.5	4.6	\N	\N
0abac47a-3e0a-4c4d-a733-fd3c5e94beed	aa9754bd-50eb-4785-8698-e56c6d3cb661	20e98c7a-4548-44f8-964d-7aba42ae7624	1b2fe4cc-3105-4e0b-b1ff-06f91c466ef7	2026-07-11 21:00:00+00	1	2	complete	3.80	3.50	1.85	\N	2026-04-19 19:45:29.973987+00	f	\N	99	Miami	t	\N	FINISHED	4	3.5	1.85	\N	\N
ef04c4e1-d29a-4f4d-8a83-4aae430183d3	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	cffa413c-8c76-45a6-843e-87c34e78e45a	666ba168-4d8b-4060-8e4b-e1dd7b2a7503	2026-06-14 17:00:00+00	7	1	complete	1.05	17.00	36.00	\N	2026-04-14 18:08:42.801797+00	f	\N	10	Houston	t	\N	FINISHED	\N	\N	\N	\N	\N
96886524-a0dc-4126-9d42-ff0050f7fefc	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	8682004e-e186-4705-aa29-9704b2815dc4	ddd77a2f-eb9f-4a20-8ae4-e1ca55c21893	2026-06-15 19:00:00+00	1	1	complete	1.62	3.75	5.00	\N	2026-04-14 18:08:42.801797+00	f	\N	16	Seattle	t	\N	FINISHED	\N	\N	\N	\N	\N
0aa39c05-82fc-4131-9670-9fe588932f2d	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	600575e1-d737-452a-abec-c6e22da92787	acfbd82a-7005-41b9-9613-606ceefc857e	2026-06-13 19:00:00+00	1	1	complete	13.00	5.80	1.22	\N	2026-04-14 18:08:42.801797+00	f	\N	8	San Francisco	t	\N	FINISHED	\N	\N	\N	\N	\N
4ec3afba-9a7c-4409-87d0-7d3f64316c22	6aa7c75c-0fc8-46f0-8219-84f969510a0e	f2c7a0c3-9a4c-4e3f-92a3-39abff0ce8e2	6ea9375b-d599-463f-96e6-c87d9209e9b2	2026-07-14 19:00:00+00	0	2	complete	2.38	3.10	3.20	\N	2026-04-19 19:45:29.973987+00	f	\N	101	Dallas	t	\N	FINISHED	2.3	3.1	3	\N	\N
91c61b35-1644-4bca-971a-d9f570efb786	5f39c536-340b-4981-b59a-4a9d7aff9e1e	8682004e-e186-4705-aa29-9704b2815dc4	151a98cf-99e8-4e7a-ab57-396a13db4a72	2026-07-01 20:00:00+00	3	2	complete	2.10	3.40	3.30	\N	2026-04-19 19:45:29.973987+00	f	\N	82	Seattle	t	\N	FINISHED	2.15	3.1	3.3	\N	\N
1fecd180-a5d7-4da8-bf23-72d2c4e5c280	2fd614f4-1aa7-43d5-beeb-be06f5530a85	f2c7a0c3-9a4c-4e3f-92a3-39abff0ce8e2	1b2fe4cc-3105-4e0b-b1ff-06f91c466ef7	2026-07-18 21:00:00+00	4	6	complete	\N	\N	\N	\N	2026-04-19 19:45:22.650156+00	t	\N	103	Miami	t	\N	FINISHED	\N	\N	\N	\N	\N
6182cc0b-a324-4530-81e4-ba352565140b	27ce4fc5-3de9-4cf0-bfc5-5fa0addb7081	e176dd2c-4446-4811-b4cc-fc28e9c2ab25	1b2fe4cc-3105-4e0b-b1ff-06f91c466ef7	2026-07-06 00:00:00+00	2	3	complete	3.00	3.00	2.40	\N	2026-04-19 19:45:22.650156+00	f	\N	92	Mexico City	t	\N	FINISHED	3	3	2.4	\N	\N
1f013a7e-8052-415d-8090-99a4cfba5780	5f39c536-340b-4981-b59a-4a9d7aff9e1e	cffa413c-8c76-45a6-843e-87c34e78e45a	c8e5c035-af92-4497-b96c-82f2c0a15214	2026-06-29 20:30:00+00	1	1	complete	1.36	4.75	8.00	\N	2026-04-19 19:45:29.973987+00	f	c8e5c035-af92-4497-b96c-82f2c0a15214	74	Boston	t	\N	FINISHED_PENS_AWAY	1.35	4.8	8	\N	\N
7ea5f707-1221-4f5e-afd4-b87a6704c790	5f39c536-340b-4981-b59a-4a9d7aff9e1e	9507020f-6157-4043-ae5b-72ca12dea41e	4f0f3776-f99f-4c06-9eb4-0acd2825d8c2	2026-06-28 19:00:00+00	0	1	complete	5.50	3.50	1.67	\N	2026-04-19 19:45:29.973987+00	f	\N	73	Los Angeles	t	\N	FINISHED	5.5	3.5	1.62	\N	\N
0bcfd687-dbd6-4369-bb0f-8fd682346491	5f39c536-340b-4981-b59a-4a9d7aff9e1e	6527ec07-bc6b-4b53-8bff-90b6f622aece	4976e7fd-9b45-4cc7-b741-fe801fcee2d0	2026-07-02 00:00:00+00	2	0	complete	1.35	4.80	8.00	\N	2026-04-19 19:45:29.973987+00	f	\N	81	San Francisco	t	\N	FINISHED	1.36	4.6	8	\N	\N
15a9d048-eb7c-464c-8034-cb2e8508bc61	27ce4fc5-3de9-4cf0-bfc5-5fa0addb7081	6527ec07-bc6b-4b53-8bff-90b6f622aece	8682004e-e186-4705-aa29-9704b2815dc4	2026-07-07 00:00:00+00	1	4	complete	2.50	3.25	2.62	\N	2026-04-19 19:45:22.650156+00	f	\N	94	Seattle	t	\N	FINISHED	2.6	3.3	2.6	\N	\N
00b8176c-7982-4869-afe6-35e05e89d930	aa9754bd-50eb-4785-8698-e56c6d3cb661	95b1e39e-97c3-4d45-9714-3f507d7c52f1	acfbd82a-7005-41b9-9613-606ceefc857e	2026-07-12 01:00:00+00	3	1	complete	1.70	3.30	5.50	\N	2026-04-19 19:45:22.650156+00	f	\N	100	Kansas City	t	\N	FINISHED	1.7	3.4	5	\N	\N
5a849898-4855-4db0-926b-08d9605fd81a	6aa7c75c-0fc8-46f0-8219-84f969510a0e	1b2fe4cc-3105-4e0b-b1ff-06f91c466ef7	95b1e39e-97c3-4d45-9714-3f507d7c52f1	2026-07-15 19:00:00+00	1	2	complete	2.62	2.88	2.90	\N	2026-04-19 19:45:29.973987+00	f	\N	102	Atlanta	t	\N	FINISHED	2.62	2.88	2.9	\N	\N
0ef4fa94-95e2-4f21-bf22-2dbd50f2426c	aa9754bd-50eb-4785-8698-e56c6d3cb661	f2c7a0c3-9a4c-4e3f-92a3-39abff0ce8e2	fcc03c57-8857-4986-98b0-0e30fb42ab2a	2026-07-09 20:00:00+00	2	0	complete	1.57	3.80	6.00	\N	2026-04-19 19:45:22.650156+00	f	\N	97	Boston	t	\N	FINISHED	1.57	3.7	5.8	\N	\N
6938c7c1-9273-4bf2-a558-80824e54a458	5f39c536-340b-4981-b59a-4a9d7aff9e1e	cba2c884-3603-4b90-976e-49389b04f562	66a8014f-0009-400e-928c-6b28cb8dab1f	2026-06-29 17:00:00+00	2	1	complete	1.73	3.50	4.80	\N	2026-04-19 19:45:29.973987+00	f	\N	76	Houston	t	\N	FINISHED	1.7	3.6	5	\N	\N
09f1fc45-6061-4b0f-a5bb-25868f5a4a57	5f39c536-340b-4981-b59a-4a9d7aff9e1e	e176dd2c-4446-4811-b4cc-fc28e9c2ab25	cd984ce3-2f2c-41d5-a7ba-137060caf8ae	2026-07-01 01:00:00+00	2	0	complete	2.20	2.80	3.90	\N	2026-04-19 19:45:29.973987+00	f	\N	79	Mexico City	t	\N	FINISHED	2.15	2.9	3.8	\N	\N
c168f9b4-b365-4b6c-9b68-3f20f8650bf5	b9bd6954-7f07-432a-af76-2dc2d3e9ab1f	6ea9375b-d599-463f-96e6-c87d9209e9b2	95b1e39e-97c3-4d45-9714-3f507d7c52f1	2026-07-19 19:00:00+00	1	0	complete	\N	\N	\N	\N	2026-04-19 19:45:22.650156+00	f	\N	104	New York	t	\N	FINISHED	\N	\N	\N	\N	\N
\.


--
-- Data for Name: pick_results; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.pick_results (id, pick_id, match_id, base_points, longshot_bonus, multiplier_applied, points_earned, match_result, created_at) FROM stdin;
60004add-98e3-4c56-af03-132317dd93bd	34901be0-8283-4da8-a135-c8242bd4e44a	8b43c919-110a-4ae6-9fc8-81acfa9ba2c4	3	0	3	3	win	2026-06-11 21:10:48.449311+00
de6ab86e-3057-4ce3-b4bd-fc7570834324	3844c305-627a-4e78-86d1-8a80243701c4	8b43c919-110a-4ae6-9fc8-81acfa9ba2c4	3	0	3	3	win	2026-06-11 21:10:48.449311+00
b41b5523-1c0f-485b-afad-6594cd65c186	dd036c38-6480-499b-9041-64cecc9a1276	2b8d5341-a73c-40fb-a9e4-975e879b65d3	1	0	2	1	draw	2026-06-12 21:05:22.303512+00
0d1480c0-18e7-4659-91e4-a1b060739148	3617d909-af94-4722-857f-9250fa7e1573	2b8d5341-a73c-40fb-a9e4-975e879b65d3	1	0	2	1	draw	2026-06-12 21:05:22.303512+00
58034898-27f8-4066-a299-9ce561a0a064	8afc3225-5929-4cad-87cb-e44760e19f55	0aa39c05-82fc-4131-9670-9fe588932f2d	1	0	3	1	draw	2026-06-13 21:09:32.876848+00
61c8afbb-8fb3-4cf3-b2c3-19ee955c3b6f	59c2a05e-d441-475b-a254-b4ad61dabc7d	0aa39c05-82fc-4131-9670-9fe588932f2d	1	0	3	1	draw	2026-06-13 21:09:32.876848+00
6eef4c84-38f9-44d7-9e9b-dbd523cc32e7	98e40309-511c-4ec7-bf8e-06d56299211d	0aa39c05-82fc-4131-9670-9fe588932f2d	1	0	3	1	draw	2026-06-13 21:09:32.876848+00
77690a15-64f9-4453-842f-bbcee333e542	28a7347c-5309-4ddc-87c2-171a38efa8e5	0aa39c05-82fc-4131-9670-9fe588932f2d	1	0	3	1	draw	2026-06-13 21:09:32.876848+00
9dab2998-f503-4da7-a3cf-6caad4dcfca0	e3aabe51-1561-4dfb-9466-bde9cee3a680	0aa39c05-82fc-4131-9670-9fe588932f2d	1	0	3	1	draw	2026-06-13 21:09:32.876848+00
6ab1d765-d3ef-4937-8669-126e99badad9	2b9bd34c-43c1-4ef1-b9d8-ad662c55efce	0aa39c05-82fc-4131-9670-9fe588932f2d	1	0	2	1	draw	2026-06-13 21:09:32.876848+00
48149760-35f7-48a2-bbd6-b8809a3a9f2b	43c2148a-2a78-4238-a2fc-8a7d61c6c37b	0aa39c05-82fc-4131-9670-9fe588932f2d	1	0	3	1	draw	2026-06-13 21:09:32.876848+00
5c77df0b-f49c-4c70-b174-56af7783a722	82e9d82d-8f87-45e0-8658-28cf709a8490	2cc09d93-3fa3-44d0-9049-5b90ac167097	0	0	3	0	loss	2026-06-14 06:10:50.563584+00
1eb9abe3-fea0-4100-887b-753ccbfcb038	170f69e3-16b4-48a3-84fe-a0b3fd1a6f58	2737b00b-6825-43fa-900a-0a522772306f	3	0	3	3	win	2026-06-14 06:10:59.746555+00
d8b83c0f-4158-43ab-81d3-2d8e4f765809	d66cb19c-1ed7-44af-a05d-128e639fd263	2737b00b-6825-43fa-900a-0a522772306f	3	0	3	3	win	2026-06-14 06:10:59.746555+00
66473010-21dc-476a-957e-2b467be6ba8a	72f8c43b-0b4a-43b3-bb7f-37483a3c1a59	2737b00b-6825-43fa-900a-0a522772306f	2	0	2	2	win	2026-06-14 06:10:59.746555+00
7e215ab0-c3be-409e-8472-652e54dafb7c	4ba5728d-a717-4d3d-9aaa-31991485f256	2737b00b-6825-43fa-900a-0a522772306f	3	0	3	3	win	2026-06-14 06:10:59.746555+00
21eb48a6-ea8d-47e4-bc78-57ea70983db8	dfa1c6af-f9ed-41be-95b2-acc51621e98a	2737b00b-6825-43fa-900a-0a522772306f	2	0	2	2	win	2026-06-14 06:10:59.746555+00
81c9bf30-7b04-4977-897f-1d2cc8a92eef	975fe05c-5398-4da2-8bb0-dc75d7fa86b6	2737b00b-6825-43fa-900a-0a522772306f	3	0	3	3	win	2026-06-14 06:10:59.746555+00
9ae7bb10-0808-43ab-aa93-f69321572b02	5766336c-a0db-4a0f-ace2-35cb78378bd2	2737b00b-6825-43fa-900a-0a522772306f	3	0	3	3	win	2026-06-14 06:10:59.746555+00
cb5a6d39-2662-4dd3-a893-eb6b562c53fe	5bcfbff8-9dcf-4eea-8b30-1fcfe3d72bfb	2737b00b-6825-43fa-900a-0a522772306f	2	0	2	2	win	2026-06-14 06:10:59.746555+00
f360bf59-60b8-4c5f-9aa3-c2e23311654d	f3d82b86-fe6b-45be-82e1-361c74c797cb	2737b00b-6825-43fa-900a-0a522772306f	3	0	3	3	win	2026-06-14 06:10:59.746555+00
215367c1-4ab0-497c-adab-68502ec29f9b	b8cea0d2-2503-4e46-80d9-009bc02fb93d	2737b00b-6825-43fa-900a-0a522772306f	3	0	3	3	win	2026-06-14 06:10:59.746555+00
ff6f98dd-c621-4ed8-a06b-973c7bb5b8a8	5a8b5ada-1e89-4aa5-9c1d-155376187162	2737b00b-6825-43fa-900a-0a522772306f	2	0	2	2	win	2026-06-14 06:10:59.746555+00
f471ccd9-013e-4dd8-9200-00b8485aca5d	7e0802f3-072b-4f99-b13f-449f495bcfa0	2737b00b-6825-43fa-900a-0a522772306f	3	0	3	3	win	2026-06-14 06:10:59.746555+00
5dfbcbbb-d9fe-4181-84cb-a683e2bf4d77	5743d80d-4cc4-4b2c-9c73-14b0617a9e4d	ef04c4e1-d29a-4f4d-8a83-4aae430183d3	3	0	3	3	win	2026-06-14 19:02:15.732309+00
0e88a134-935b-4113-abd6-23d2185f0e64	f8034bc4-2d20-47f7-81a6-e92683fce7f8	15148b9f-4d4c-40b4-8905-e533ff0ca8d4	2	0	2	2	win	2026-06-15 05:47:03.79509+00
12f21135-05bb-469a-8e48-1e707a436a6d	48fa004d-e8e5-4ec2-8577-83d5b894ce7c	7c21e0db-01cc-4536-bfe0-c6c4997e76ad	2	0	2	2	win	2026-06-15 05:47:39.431222+00
5de8acb0-efaa-4ee9-8b86-0a168b593714	8454e7db-2a11-45af-8b9a-e990da3be448	b58779a0-33b8-44da-905b-67c3b4f81254	1	0	2	1	draw	2026-06-15 18:16:26.566522+00
ef8042f9-ca2b-4303-bd92-3117323f5340	d3c89295-cc79-458c-9d18-57a37c901b1c	96886524-a0dc-4126-9d42-ff0050f7fefc	1	0	3	1	draw	2026-06-15 20:58:17.142573+00
5a336876-084d-4596-9049-ea58214af713	498fb3fa-4beb-4176-828c-f1dbdaa57fb9	d7faf3e3-d358-4158-bbbc-73fde86ea30f	1	0	2	1	draw	2026-06-16 05:52:57.545566+00
578daaee-092c-41c2-808d-248391978875	8052d2fe-367b-4d0c-b140-69cfd16395a1	d7faf3e3-d358-4158-bbbc-73fde86ea30f	1	0	2	1	draw	2026-06-16 05:52:57.545566+00
4600dd0e-25f9-442f-8acb-9d174f43954f	1a1b5c8d-1379-4cd2-91eb-5c61b6cc6510	472a5e3d-5ce9-46a8-9abf-fa5593699943	2	0	2	2	win	2026-06-17 05:30:13.792149+00
81b569c5-d88d-450b-b8a8-a6ada5676c48	f8ddd991-2242-4aa3-be9a-a4f72e0d931e	472a5e3d-5ce9-46a8-9abf-fa5593699943	2	0	2	2	win	2026-06-17 05:30:13.792149+00
ae941c36-c2db-42a9-990d-541038258eaa	658f3772-af5d-4d3a-80a0-97ee9f0c2c9d	472a5e3d-5ce9-46a8-9abf-fa5593699943	3	0	3	3	win	2026-06-17 05:30:13.792149+00
57331a3c-b5d0-4774-aca4-b1b0df18a4ed	6b87a1ac-1832-47d9-8c01-012c2f03a755	472a5e3d-5ce9-46a8-9abf-fa5593699943	3	0	3	3	win	2026-06-17 05:30:13.792149+00
6188f06e-5479-405b-a857-a9b6dbd3b444	23dde6b6-0d42-4f98-98c2-6829c91fa855	472a5e3d-5ce9-46a8-9abf-fa5593699943	3	0	3	3	win	2026-06-17 05:30:13.792149+00
1cd0880a-b96c-46de-a92e-e51be69b3458	766234a8-baa7-47c2-a44a-9414ba5208e1	64167916-7a8e-4126-bdc2-445e6dfd9cd8	2	0	2	2	win	2026-06-17 06:14:22.426639+00
1862e0ed-00cc-4dce-b051-df0b7f88924c	0cee0956-6598-40ce-b920-77efc52500ba	64167916-7a8e-4126-bdc2-445e6dfd9cd8	3	0	3	3	win	2026-06-17 06:14:22.426639+00
eab58ed4-43b1-49ae-bb8a-b77170b16348	45afc289-0d3b-4c7a-a1d3-f77a1bcf4213	64167916-7a8e-4126-bdc2-445e6dfd9cd8	3	0	3	3	win	2026-06-17 06:14:22.426639+00
df4b4ab4-e1ef-4a01-9bcb-d90a709a4323	b522652a-b1e5-4b57-afe0-b36a4705dbe1	64167916-7a8e-4126-bdc2-445e6dfd9cd8	2	0	2	2	win	2026-06-17 06:14:22.426639+00
6f406490-6a6f-4536-8dba-5cec4dbaf532	bcd7152d-2ca8-4016-8260-a61597921f5f	64167916-7a8e-4126-bdc2-445e6dfd9cd8	3	0	3	3	win	2026-06-17 06:14:22.426639+00
8254452c-130e-4560-8c21-1eecd997dea4	07395e96-812e-4c00-b31c-e39d4d78ddd3	64167916-7a8e-4126-bdc2-445e6dfd9cd8	2	0	2	2	win	2026-06-17 06:14:22.426639+00
121751ac-b0f3-48a3-9760-d681f0892721	06476d60-d7e3-4e4c-99f2-f554740acc3e	64167916-7a8e-4126-bdc2-445e6dfd9cd8	2	0	2	2	win	2026-06-17 06:14:22.426639+00
26c7c28d-9fa2-44aa-ba9c-0ee1370d57bc	5fa9c20d-e6a5-4365-80c1-c62a99f9e4b8	64167916-7a8e-4126-bdc2-445e6dfd9cd8	2	0	2	2	win	2026-06-17 06:14:22.426639+00
6de3856a-4687-4b41-8fff-74b1a8885add	2f41ac59-eceb-4d73-b4f9-45c4772bbd80	64167916-7a8e-4126-bdc2-445e6dfd9cd8	2	0	2	2	win	2026-06-17 06:14:22.426639+00
203743d9-f1c8-4a48-a3c5-9ec86273af58	f5b14944-30e9-43de-a233-875d89bb555b	64167916-7a8e-4126-bdc2-445e6dfd9cd8	2	0	2	2	win	2026-06-17 06:14:22.426639+00
3ae52005-cbcb-4555-8fa7-193d7e89eb4a	91e3367a-d890-4726-81ce-510e46788c6b	6154fec4-83b3-4b8c-b92f-b8a31399f6c9	2	1	2	2	win	2026-06-18 05:40:07.15981+00
22cc1fbe-2742-45be-9598-c6145dd0c526	83e2707e-1efc-4685-9dd7-4b5e5bfd019a	6154fec4-83b3-4b8c-b92f-b8a31399f6c9	2	1	2	2	win	2026-06-18 05:40:07.15981+00
637d206b-e8d1-4dcd-89ce-ba1c2867d9d3	d4077bd1-f686-451c-9070-f7356d646a0f	6154fec4-83b3-4b8c-b92f-b8a31399f6c9	3	1	3	3	win	2026-06-18 05:40:07.15981+00
eb3cf5f3-aedb-42ed-988c-8ee5b17e27b3	abbed847-5440-421c-922b-cdb3bf0dd381	6154fec4-83b3-4b8c-b92f-b8a31399f6c9	2	1	2	2	win	2026-06-18 05:40:07.15981+00
98360aa8-be4c-4d6a-9e52-f978c15c3b05	c72d79d4-8159-4b46-9ce7-aad8d1a863f7	6154fec4-83b3-4b8c-b92f-b8a31399f6c9	2	1	2	2	win	2026-06-18 05:40:07.15981+00
b2c518e0-844f-4dc3-ad34-b36efca43630	865161dc-dee5-4b62-9502-957bd743d9ea	6154fec4-83b3-4b8c-b92f-b8a31399f6c9	2	1	2	2	win	2026-06-18 05:40:07.15981+00
71b0f14b-58fa-4ebc-b379-48d09bedab8c	6c33d2a6-8ba5-49f1-af6d-ea9e1710bd20	6154fec4-83b3-4b8c-b92f-b8a31399f6c9	0	0	2	0	loss	2026-06-18 05:40:07.15981+00
0730fcc5-e9e5-4d33-a812-eae5c6916deb	819eefc5-3492-44aa-85d7-1e2c7a20f656	799ad195-8136-4549-b477-95fe02eaef8e	3	0	3	3	win	2026-06-18 05:40:17.949665+00
b1a002de-4aef-4c66-918e-bd01a6d4530a	f61c4b99-1253-4c47-9340-581814d14ae8	799ad195-8136-4549-b477-95fe02eaef8e	3	0	3	3	win	2026-06-18 05:40:17.949665+00
09948452-8242-426e-8d33-6b3ceb0ca004	45661692-2f33-4243-ae8e-029025fffefc	799ad195-8136-4549-b477-95fe02eaef8e	2	0	2	2	win	2026-06-18 05:40:17.949665+00
2c0703a2-3d4e-44de-8ec3-7042e2be20e6	a4a36be7-713f-4145-8b42-67abc12a05ee	84b62dcf-7110-46f4-ac2c-d4d5ccfbce8b	1	0	2	1	draw	2026-06-18 19:13:13.632799+00
aecba499-3c35-4257-9504-3bd0b07be152	96754c6f-3c8d-4a6c-b2ff-44ac79bd5f70	84b62dcf-7110-46f4-ac2c-d4d5ccfbce8b	1	0	2	1	draw	2026-06-18 19:13:13.632799+00
7a4ecdf0-a46e-454b-9a16-e1ae34e0f430	747023f0-5db0-407a-a94d-855dd0fe64e3	84b62dcf-7110-46f4-ac2c-d4d5ccfbce8b	1	0	2	1	draw	2026-06-18 19:13:13.632799+00
9428e65a-742f-4c30-bd0b-da6ed1d88185	7ba2e30f-3648-4036-a8c7-0a3f616525f2	84b62dcf-7110-46f4-ac2c-d4d5ccfbce8b	1	0	2	1	draw	2026-06-18 19:13:13.632799+00
d3ce2fe1-0525-43aa-816a-37b2c210573d	903438d3-94cd-4837-a393-10db197e9528	84b62dcf-7110-46f4-ac2c-d4d5ccfbce8b	1	0	2	1	draw	2026-06-18 19:13:13.632799+00
eeffbeac-8dc6-426d-869a-69c0b1e9403f	1668026a-ecbf-4789-8a20-b3ae5bcc7519	84b62dcf-7110-46f4-ac2c-d4d5ccfbce8b	1	0	3	1	draw	2026-06-18 19:13:13.632799+00
a940c762-0ab0-4841-a46d-5825f5965389	84be8d14-5150-47ec-a548-561a7e994c98	84b62dcf-7110-46f4-ac2c-d4d5ccfbce8b	1	0	2	1	draw	2026-06-18 19:13:13.632799+00
38b97d5e-b39a-4622-b021-10f51e4d35ac	d470d41d-42cd-4c9e-84e9-b8b0e1487caa	84b62dcf-7110-46f4-ac2c-d4d5ccfbce8b	1	0	2	1	draw	2026-06-18 19:13:13.632799+00
110b6283-461f-4697-bde3-e72066ed32fa	e6fbc360-6cd5-4e38-bb44-e09a352bbe98	84b62dcf-7110-46f4-ac2c-d4d5ccfbce8b	1	0	3	1	draw	2026-06-18 19:13:13.632799+00
205c8136-805f-4ca3-9e17-66b9fecd656f	ace84946-ad1c-498e-bc50-841158b9916c	84b62dcf-7110-46f4-ac2c-d4d5ccfbce8b	1	0	2	1	draw	2026-06-18 19:13:13.632799+00
409bda14-acad-45e3-a8b0-17bf28cfb429	7b233df2-ecef-4ebc-85f6-99c7d7a9132b	84b62dcf-7110-46f4-ac2c-d4d5ccfbce8b	1	0	2	1	draw	2026-06-18 19:13:13.632799+00
c58e6530-3305-41bb-9d77-2b2f81ac8493	4897196b-e754-461b-a800-8b2bd39957b6	84b62dcf-7110-46f4-ac2c-d4d5ccfbce8b	1	0	3	1	draw	2026-06-18 19:13:13.632799+00
9532d308-856d-4907-9d40-7f540127fa24	1ee91f43-f35f-409e-8db8-7b5e6bdc67f8	84b62dcf-7110-46f4-ac2c-d4d5ccfbce8b	1	0	2	1	draw	2026-06-18 19:13:13.632799+00
230da699-1ee5-4640-8556-dec3470b1edc	08a0fda1-9f44-4a00-b6ad-ca913cc28d00	84b62dcf-7110-46f4-ac2c-d4d5ccfbce8b	1	0	2	1	draw	2026-06-18 19:13:13.632799+00
10649a64-0c13-45ce-8924-d2e8de68dcb0	2edf3ae8-fee1-4404-981d-44e62e53dba4	84b62dcf-7110-46f4-ac2c-d4d5ccfbce8b	1	0	2	1	draw	2026-06-18 19:13:13.632799+00
228e0262-8525-40c2-a125-940be8f2eb55	7a0f87f4-5d10-484f-9170-1d1cf6b672f8	84b62dcf-7110-46f4-ac2c-d4d5ccfbce8b	1	0	3	1	draw	2026-06-18 19:13:13.632799+00
b0c419f4-b65b-4fbc-93b8-61e9aa551a45	d72412f2-814c-4b19-9a02-79781605232e	09779cac-8a10-4c3d-a107-9f9490f548f1	2	0	2	2	win	2026-06-18 21:42:45.107196+00
5b2a83f4-fd3d-4df0-8771-cc391bc26030	3bf8b92e-e19f-4df9-aa93-668ad03a9c31	53d7793c-7e1b-4a8a-bd9e-8044f4ffc71b	2	0	2	2	win	2026-06-19 01:58:30.58785+00
74bd804a-cb1b-406a-9bf9-f7393a622d25	338be2cc-b9b7-494f-8e63-5f83a5b21eec	53d7793c-7e1b-4a8a-bd9e-8044f4ffc71b	2	0	2	2	win	2026-06-19 01:58:30.58785+00
e076588d-e659-4434-9237-b425b5bc1030	cc48d101-64a9-4da3-8b4b-ae2ae55572ea	53d7793c-7e1b-4a8a-bd9e-8044f4ffc71b	2	0	2	2	win	2026-06-19 01:58:30.58785+00
840efcb8-c272-4da5-b089-582e5cae1da2	f6f0df20-282e-4682-afef-c7121ba2f68a	53d7793c-7e1b-4a8a-bd9e-8044f4ffc71b	3	0	3	3	win	2026-06-19 01:58:30.58785+00
c3bdd3e0-a3e2-4224-8b4e-d7dfe1c8cb6e	e0041469-d0f2-4e6f-9aad-1d65c38a5271	95e9203a-5dfe-44fe-9946-8e2d0dc2e1a9	0	0	2	0	loss	2026-06-19 06:55:47.897524+00
754c4b29-6556-4cea-a199-0355feda5057	949b8f71-8f82-4502-85d7-7262a9223506	b74d9072-2d8e-4988-ad96-c3680624ee52	3	0	3	3	win	2026-06-19 21:44:05.863439+00
ab15c6ce-5549-4621-99a5-2d8b06e72382	b9191401-84c2-42be-8394-ad3659bc6162	4645c3d2-2710-4c1f-a94b-f1a4b24de902	2	0	2	2	win	2026-06-20 06:37:37.977227+00
3c0759e1-cfb5-4fd3-810b-0511553dafcd	1687a5d0-0a74-48c0-aee1-586c47daebc5	ff8ff08a-b110-4120-a1c9-8ffe191fc2ba	3	0	3	3	win	2026-06-20 06:37:46.581181+00
c70f9983-9ece-458c-9980-ee6083c385ce	a64d4b3e-f5e1-41d6-a88e-4113d679e1a8	ff8ff08a-b110-4120-a1c9-8ffe191fc2ba	3	0	3	3	win	2026-06-20 06:37:46.581181+00
e48a2460-92f5-42fb-aef7-b7f475197d6d	684357ca-b1be-4b8c-b03b-c3a74ab47476	447d4217-d302-49c0-980c-cd1359ccb3c5	1	0	2	1	draw	2026-06-21 06:24:54.356673+00
bc5eca07-4179-4ea7-9360-b318ed563787	29d0629f-44a9-49a8-a0b0-d9fee87355ae	447d4217-d302-49c0-980c-cd1359ccb3c5	1	0	2	1	draw	2026-06-21 06:24:54.356673+00
1608d5d9-45a2-4430-8d8b-1aae5b76416d	383e528c-694d-44c2-a9e0-68f39272a79e	447d4217-d302-49c0-980c-cd1359ccb3c5	1	0	3	1	draw	2026-06-21 06:24:54.356673+00
113e483d-9ae2-4246-9e2d-8d8c15f79777	4edee4df-2901-47b3-aa1e-5b5b44734547	447d4217-d302-49c0-980c-cd1359ccb3c5	1	0	3	1	draw	2026-06-21 06:24:54.356673+00
c394c4de-2bb7-4ca9-86ed-01aaa9cb86dc	8ceeb596-437c-4483-9564-1c63c4df8152	447d4217-d302-49c0-980c-cd1359ccb3c5	1	0	3	1	draw	2026-06-21 06:24:54.356673+00
88850e9d-2dc1-47c0-995c-831c4cf3503f	852a2a8d-6c94-4d90-a4c5-35a8b64348ff	447d4217-d302-49c0-980c-cd1359ccb3c5	1	0	3	1	draw	2026-06-21 06:24:54.356673+00
9aa5fdd8-b989-44bb-82a6-7c3e8394f1da	46ab2698-2857-4049-b073-192fc46c7fb6	447d4217-d302-49c0-980c-cd1359ccb3c5	1	0	2	1	draw	2026-06-21 06:24:54.356673+00
369ed390-61b8-42ae-b087-453d2d98cb7e	e299ca02-e0ff-42cf-990d-169579dd76eb	447d4217-d302-49c0-980c-cd1359ccb3c5	1	0	3	1	draw	2026-06-21 06:24:54.356673+00
43ca4abd-e9a5-4972-8301-78b29f7b3661	ddb16359-c8c7-4e78-9990-651c955d4bd0	447d4217-d302-49c0-980c-cd1359ccb3c5	1	0	2	1	draw	2026-06-21 06:24:54.356673+00
87cf837c-90be-49b8-9c9f-212090b3f6dd	91101c0b-cb8c-4b59-a165-df7ece12b28e	447d4217-d302-49c0-980c-cd1359ccb3c5	1	0	3	1	draw	2026-06-21 06:24:54.356673+00
51bfc0da-e31b-4073-96f1-ac3474a82976	404c1888-347e-4577-bb2a-83d12760fb9e	447d4217-d302-49c0-980c-cd1359ccb3c5	1	0	3	1	draw	2026-06-21 06:24:54.356673+00
efde822d-be1f-4e93-b5da-6bcd1b0a9806	b1b492c4-59ea-400f-a23c-f04e19024314	447d4217-d302-49c0-980c-cd1359ccb3c5	1	0	3	1	draw	2026-06-21 06:24:54.356673+00
2c4a2401-6b99-4b50-b38b-7a6731ee13e9	fb492b60-8db3-4912-b4e0-bdcac48489bb	ff4b8afa-c644-4ef8-9a42-56784b08adcd	3	0	3	3	win	2026-06-21 06:25:04.634312+00
8cc35767-6439-4d15-9dd1-5f2fb5f62b64	b963d149-7873-4a54-acb7-2efa34627c14	ff4b8afa-c644-4ef8-9a42-56784b08adcd	3	0	3	3	win	2026-06-21 06:25:04.634312+00
1e0f13f6-efbc-49d9-826f-3305b8ce8f50	6a813b11-3c44-4740-82a7-79c1475309b3	ff4b8afa-c644-4ef8-9a42-56784b08adcd	2	0	2	2	win	2026-06-21 06:25:04.634312+00
87ae463d-e264-4a50-9e60-3941e98f7013	8e80e933-977c-422f-91c8-cbd168c89ec4	e71dd1df-caa8-4b10-8ffb-220c4e918698	1	0	3	1	draw	2026-06-21 21:01:41.129512+00
68d349a8-2628-4eb3-b263-fc1823634456	8465e4e6-f492-47e5-8c50-ef8761a3a10b	e71dd1df-caa8-4b10-8ffb-220c4e918698	1	0	3	1	draw	2026-06-21 21:01:41.129512+00
5bc84e31-0e56-4ace-8203-bfc4a544140c	809a34d5-fc53-4b8e-a13d-de8c208fdb89	e71dd1df-caa8-4b10-8ffb-220c4e918698	1	0	2	1	draw	2026-06-21 21:01:41.129512+00
c1227a3b-692c-4734-a40b-9f919d30493c	b4b4b2e2-0dee-4eea-9309-8190d689f978	5688eceb-e867-4cbb-a673-0677aacc75f2	1	0	3	1	draw	2026-06-22 03:40:02.230937+00
917fe940-e222-401b-8fdb-66cb7337f095	14efa54b-c629-4e54-96be-fe776a992502	5688eceb-e867-4cbb-a673-0677aacc75f2	1	0	3	1	draw	2026-06-22 03:40:02.230937+00
cf9849c2-4a0e-4c30-be9b-05708e14ff22	deddd4c3-a62b-4503-ad65-d6245b1462ac	5688eceb-e867-4cbb-a673-0677aacc75f2	1	0	2	1	draw	2026-06-22 03:40:02.230937+00
15b679b0-14c2-40f5-9072-ad81663e6e97	a8396f71-0bef-4602-af64-a4c45d18bf56	5688eceb-e867-4cbb-a673-0677aacc75f2	1	0	3	1	draw	2026-06-22 03:40:02.230937+00
ac9414cf-524d-415c-a63e-15ab5189e4ca	48f52dd9-4b34-4b79-be20-1c14a736a4d9	5688eceb-e867-4cbb-a673-0677aacc75f2	1	0	2	1	draw	2026-06-22 03:40:02.230937+00
0701d2fa-6eb8-420f-9fcc-07ae41d4403b	6f773ba7-cbac-42ac-a96f-cf5a47ff0611	371dfc3a-483b-4b55-9462-6a8b23f9cb6e	3	0	3	3	win	2026-06-22 03:40:13.446856+00
35c36fb0-8a3d-4c04-b931-4354fb2bdbb4	bf4d041b-bc7d-4e4c-be54-37de9a0d1682	371dfc3a-483b-4b55-9462-6a8b23f9cb6e	2	0	2	2	win	2026-06-22 03:40:13.446856+00
e7e0e7d2-6d86-44dc-95d8-917436afd711	2ccab4b4-3b72-4d40-9088-da8567b3c8da	371dfc3a-483b-4b55-9462-6a8b23f9cb6e	3	0	3	3	win	2026-06-22 03:40:13.446856+00
428552d8-3489-4bdf-93b5-96418846bd4a	b55cb969-cc67-48bd-9dad-97ac206ce182	d094ec78-e479-4f3b-b030-b45e918c43ba	3	0	3	3	win	2026-06-23 05:47:32.630108+00
0ee4eb63-ecb9-4846-b076-c02c0dedee0d	70b072ea-876e-4856-80f7-be94e89104a7	d094ec78-e479-4f3b-b030-b45e918c43ba	2	0	2	2	win	2026-06-23 05:47:32.630108+00
0a5cc880-d142-40da-94a5-a257ed3317d8	6f6af635-58ee-47f3-872e-d1d6479942fa	bd96de28-090a-4f99-8d20-7fb5e86a7380	3	0	3	3	win	2026-06-23 18:58:16.142084+00
bfe9cfec-3675-459e-a3e6-c2c7b15a4f71	6b7dff11-5bc7-41cb-8bc6-ec54d68b0055	a3f494e7-f129-4d66-87f5-438a915a4bdb	3	0	3	3	win	2026-06-24 06:17:32.52683+00
8dbb43de-8606-4cff-87f2-2acd90f6e0eb	9ae2e036-3fa7-480a-9c05-53986536c206	97d24d3d-e7f7-4611-b7b3-0609fec069b3	2	1	2	2	win	2026-06-24 21:25:07.162105+00
08e27717-de98-4b7a-8504-209c30240aa4	91cec3ab-120d-4ea0-9a53-082214e3814c	97d24d3d-e7f7-4611-b7b3-0609fec069b3	3	1	3	3	win	2026-06-24 21:25:07.162105+00
9505bb23-76c0-412e-9e65-f358911ba87b	bde7ed21-f9ba-4044-8e0b-216e6f2df086	97d24d3d-e7f7-4611-b7b3-0609fec069b3	2	1	2	2	win	2026-06-24 21:25:07.162105+00
92a3b4ed-a81c-4bad-afe4-fba87de37a74	24d317f4-e7a3-40d9-8a2b-c8a9e6214959	97d24d3d-e7f7-4611-b7b3-0609fec069b3	2	1	2	2	win	2026-06-24 21:25:07.162105+00
ee14883c-b7f1-4a8f-9238-583c5bb8b7fb	d1e67e69-8b29-4011-8094-5ec328d8d7b4	97d24d3d-e7f7-4611-b7b3-0609fec069b3	3	1	3	3	win	2026-06-24 21:25:07.162105+00
d8f982e7-0f46-40c7-aa4b-ffd9e78fe9f3	1200e2a8-75c8-4e91-9ef7-159baf293be5	97d24d3d-e7f7-4611-b7b3-0609fec069b3	3	1	3	3	win	2026-06-24 21:25:07.162105+00
44d46ac1-6ea6-4c3e-a763-0f2d6d3d22fb	6463f221-12e4-4d8e-8863-ea3075440210	97d24d3d-e7f7-4611-b7b3-0609fec069b3	2	1	2	2	win	2026-06-24 21:25:07.162105+00
95511008-2824-4b8d-85d9-6cda61a582b3	47ad14eb-a2a2-4011-b122-d5c4acfbf43f	97d24d3d-e7f7-4611-b7b3-0609fec069b3	3	1	3	3	win	2026-06-24 21:25:07.162105+00
861cc41c-7831-4367-9f0f-a89de9f6bdcf	ad51dc02-a456-4f27-b454-220cc70e09b6	97d24d3d-e7f7-4611-b7b3-0609fec069b3	2	1	2	2	win	2026-06-24 21:25:07.162105+00
005e3ce7-5731-4690-a3cb-ef563320a797	a3f9c63e-85db-445b-b1fb-8a8127a549f5	97d24d3d-e7f7-4611-b7b3-0609fec069b3	2	1	2	2	win	2026-06-24 21:25:07.162105+00
81f68062-09cf-4ff4-b90a-f0307ae67d4e	16f84c2b-a182-4041-a31d-7590e0745b7c	97d24d3d-e7f7-4611-b7b3-0609fec069b3	2	1	2	2	win	2026-06-24 21:25:07.162105+00
a31315a1-22c6-4d7b-ac1c-089fa40794dd	8318e774-35dd-4b3f-9c55-292d76c749bb	24a55af4-cc2c-4c75-a9c3-f0ba07f8965e	3	0	3	3	win	2026-06-25 05:50:36.628916+00
451699ac-a7c5-4654-8cb8-f0b15413c08c	a98034ff-0966-4d4a-8e7f-77cd28b28a02	24a55af4-cc2c-4c75-a9c3-f0ba07f8965e	3	0	3	3	win	2026-06-25 05:50:36.628916+00
f1629f9a-c570-4711-b12f-1f235ec94499	011679a8-9c2a-465d-ab45-d84d5587e841	24a55af4-cc2c-4c75-a9c3-f0ba07f8965e	2	0	2	2	win	2026-06-25 05:50:36.628916+00
b95b5280-bbef-4e8b-a07d-70d7d06fdec9	846de7c9-58aa-41e8-b526-89f0bf72c1cd	24a55af4-cc2c-4c75-a9c3-f0ba07f8965e	3	0	3	3	win	2026-06-25 05:50:36.628916+00
a140a146-95cd-4af9-8df7-7b321c4ad8d7	8843ff08-b9a5-4177-b926-7796316c54b1	24a55af4-cc2c-4c75-a9c3-f0ba07f8965e	3	0	3	3	win	2026-06-25 05:50:36.628916+00
47142c0e-ae13-45c4-b3d7-774143b615e8	9783b537-9528-4b96-a68a-41c25af7e25f	24a55af4-cc2c-4c75-a9c3-f0ba07f8965e	3	0	3	3	win	2026-06-25 05:50:36.628916+00
40fcc6b1-2543-46b4-aa58-f4b4b280762a	362af7f2-672b-4eaf-a959-da301f1a3d71	24a55af4-cc2c-4c75-a9c3-f0ba07f8965e	2	0	2	2	win	2026-06-25 05:50:36.628916+00
0992770c-e689-4b6c-a53f-c7d1b470d7a8	d2beeaf2-af92-4136-b828-796fcd69acb0	24a55af4-cc2c-4c75-a9c3-f0ba07f8965e	3	0	3	3	win	2026-06-25 05:50:36.628916+00
c8a5a47c-61a6-449a-a961-9f698257f693	5087e3b8-b5da-4f16-a216-4f42c467746e	4a1a38c4-fe97-4d42-a2ff-8a0caa18ff17	2	0	2	2	win	2026-06-25 05:50:44.23606+00
4c93d4fd-00c5-4f25-924e-f6e803cf6361	84552afe-300c-431a-b1a9-375305560ee9	4a1a38c4-fe97-4d42-a2ff-8a0caa18ff17	2	0	2	2	win	2026-06-25 05:50:44.23606+00
9ba07da0-bdcd-41b7-ac95-88f4f50a6370	3292dbeb-749f-49f7-9e6f-0b8cc376b059	d6028dab-94a8-4e2f-bf47-0370f6fdcd3b	0	0	3	0	loss	2026-06-25 05:51:02.252767+00
58202dca-e88b-4c2b-93e9-5c8ab7b1d3af	fbe87f42-8977-4670-a191-0034f1992729	d6028dab-94a8-4e2f-bf47-0370f6fdcd3b	0	0	2	0	loss	2026-06-25 05:51:02.252767+00
5687f126-d261-4e31-8575-7ebb7be524b4	d0930464-d664-4485-9542-0f6c71132fa6	d6028dab-94a8-4e2f-bf47-0370f6fdcd3b	0	0	3	0	loss	2026-06-25 05:51:02.252767+00
a16f5ce8-497e-425d-8523-4115f3eb51ec	a205f308-2ff3-4f63-8d1a-a5ebe9c9fd71	d6028dab-94a8-4e2f-bf47-0370f6fdcd3b	0	0	2	0	loss	2026-06-25 05:51:02.252767+00
2e735bce-f1c4-4a34-ac84-0bc0231aeda4	6466543e-f5a4-4af9-9669-62a8223418a0	d6028dab-94a8-4e2f-bf47-0370f6fdcd3b	0	0	2	0	loss	2026-06-25 05:51:02.252767+00
be453b23-649a-4813-868b-7b56938e00ad	f0228980-47f2-438a-b9af-599cfb8feff5	d6028dab-94a8-4e2f-bf47-0370f6fdcd3b	0	0	2	0	loss	2026-06-25 05:51:02.252767+00
db79988f-0fdd-4b35-9654-ba4e261fe108	a288a34d-25e3-4dca-b80c-33c7f45af302	d6028dab-94a8-4e2f-bf47-0370f6fdcd3b	0	0	2	0	loss	2026-06-25 05:51:02.252767+00
db56b39b-dcad-4d9f-9016-9f5e1d3d3379	98c7a20b-ba36-4d7f-a4ba-c596a2c127be	5f2999a7-5535-4fe4-b0ba-a058b61fd138	3	0	3	3	win	2026-06-25 21:58:11.451425+00
02cbd6ac-86bc-4086-82f3-ad4377d5efb2	326b80fe-af3a-4047-89ff-de1364d09cc4	5f2999a7-5535-4fe4-b0ba-a058b61fd138	2	0	2	2	win	2026-06-25 21:58:11.451425+00
e905a637-02f1-4708-bda5-57606758ab52	f99eba48-a829-46ee-bb62-5452046e1078	5f2999a7-5535-4fe4-b0ba-a058b61fd138	3	0	3	3	win	2026-06-25 21:58:11.451425+00
fcfee208-24e4-4815-b672-7cd2f56337e2	a15291f0-055c-4710-bedc-d46ba0ce3ade	5f2999a7-5535-4fe4-b0ba-a058b61fd138	3	0	3	3	win	2026-06-25 21:58:11.451425+00
067816e1-1af2-4639-a7b9-f9afb03837b1	d97b978b-254a-4a3e-82ac-06c3c6f91722	5f2999a7-5535-4fe4-b0ba-a058b61fd138	2	0	2	2	win	2026-06-25 21:58:11.451425+00
7be58915-6874-42ac-838d-5678db1a2a28	21f0fc91-5621-478b-b7cb-3bf80b2acdea	8b694d3b-c857-43c4-a291-9d03ed28a289	0	0	3	0	loss	2026-06-25 21:58:35.79712+00
06d87547-5592-454a-af80-92fad7b3437e	9f7299c3-e804-4f92-b0ac-172375b575bd	89faf49a-c4d3-43da-9c28-461f46e56075	1	0	3	1	draw	2026-06-26 05:44:05.175976+00
9385c0fe-de19-4dfb-9160-5f4fde4afa6a	69e1e472-329b-4c0f-ac3d-70a86a6d0103	89faf49a-c4d3-43da-9c28-461f46e56075	1	0	2	1	draw	2026-06-26 05:44:05.175976+00
3d1077e3-7812-4487-96c7-e2114bcaf1cc	a8dfffed-d9ed-4b84-bec4-9ecabe2032ca	67423ac2-4ae3-42ec-b786-c3b824a15d4e	0	0	2	0	loss	2026-06-26 05:44:51.841022+00
74608826-365f-45c2-aed9-fe3e4a21ddd3	9d738f52-4624-44c2-a7f3-5d7634f037ac	0635f748-c59a-4104-b439-1c84c2e81460	3	0	3	3	win	2026-06-26 21:07:01.649577+00
a2a10d4e-e756-4680-804c-a7a836d22869	d8b62402-0256-4d04-97b0-810a7aaa0915	0635f748-c59a-4104-b439-1c84c2e81460	2	0	2	2	win	2026-06-26 21:07:01.649577+00
90b510ee-d4e6-473f-a0cd-abf2d96c3bcf	0289ac63-698d-4a87-aac7-6b65311e9a02	0635f748-c59a-4104-b439-1c84c2e81460	2	0	2	2	win	2026-06-26 21:07:01.649577+00
7af48028-3103-4f45-bfed-3d8ef1601b7c	4b3c87f8-90b8-455d-8c16-19105a511b6f	0635f748-c59a-4104-b439-1c84c2e81460	3	0	3	3	win	2026-06-26 21:07:01.649577+00
753f3987-3f51-429b-afa1-a2b783e5d7ef	06c518d3-8536-4a1a-bcae-c895c911a61f	0635f748-c59a-4104-b439-1c84c2e81460	3	0	3	3	win	2026-06-26 21:07:01.649577+00
45808696-5411-43da-ba63-bc231ad9b329	71e6fbd0-64dc-47af-95ec-6bf708c981cf	0635f748-c59a-4104-b439-1c84c2e81460	3	0	3	3	win	2026-06-26 21:07:01.649577+00
3b673487-96d6-4921-9a8a-728da21e2ac0	009f5367-8575-4caa-a586-4a6ec0538072	0635f748-c59a-4104-b439-1c84c2e81460	2	0	2	2	win	2026-06-26 21:07:01.649577+00
5365e1ae-5104-4622-8826-6a33ceb828a7	3908aa5a-1bc5-4e82-b129-c1eb86410ce3	0635f748-c59a-4104-b439-1c84c2e81460	3	0	3	3	win	2026-06-26 21:07:01.649577+00
4d346814-c496-41e6-9422-8ffcff33a26e	531be698-4a2d-49bc-8ded-dee8ff695a9b	75b95055-eae5-422d-95d9-f53306255944	1	0	2	1	draw	2026-06-27 05:33:54.400366+00
9d97b874-ff20-445a-a1ab-b2eecedd1e14	ee5d54c9-d97c-4fe0-aad5-bf13ccee80f7	e51ad0e0-f1b7-449e-ad47-4e4c2559ff76	2	0	2	2	win	2026-06-27 05:34:06.218286+00
32d66f55-a91d-4b14-b388-a1f2f7addadd	4b207b03-0f4b-4d0a-acc8-5c3659dd6c80	e51ad0e0-f1b7-449e-ad47-4e4c2559ff76	2	0	2	2	win	2026-06-27 05:34:06.218286+00
57fae109-25f1-41ec-bd93-a7b22a92d298	398f4588-9da3-43f5-8438-a5140012ea71	e51ad0e0-f1b7-449e-ad47-4e4c2559ff76	3	0	3	3	win	2026-06-27 05:34:06.218286+00
759be5b9-b378-418f-b633-257a3729b2b0	8d5d476f-7e6e-4b53-a32f-a236533d3170	e51ad0e0-f1b7-449e-ad47-4e4c2559ff76	3	0	3	3	win	2026-06-27 05:34:06.218286+00
4e46ac8b-df99-488d-923c-6cb52b0be101	d581f8ff-e3f0-413b-9a4d-be337cebbcfa	623afe5d-5dc9-413f-8931-6f08795bf386	1	0	3	1	draw	2026-06-27 05:34:18.819158+00
5eb6bbf2-f3a7-4335-9ed7-85569760dd42	70a31294-9c8d-4f8b-bbb8-d676082f7988	f1597d1c-d2cb-4027-86e1-0ba93a331041	3	1	3	3	win	2026-06-28 08:10:12.856203+00
8b8b163c-c25b-4de3-9722-b8f62af1a444	96c11b54-15c5-4174-9408-abf158176d7f	f1597d1c-d2cb-4027-86e1-0ba93a331041	2	1	2	2	win	2026-06-28 08:10:12.856203+00
6647b0a9-20af-49ab-8081-d9cac157500f	d0512d16-c747-4149-b868-b787f852d753	f1597d1c-d2cb-4027-86e1-0ba93a331041	2	1	2	2	win	2026-06-28 08:10:12.856203+00
a3bad606-f6b6-4d7f-b8a7-9791df66c78b	3e14fc9e-981c-44d2-af3d-6c86f847f7aa	f1597d1c-d2cb-4027-86e1-0ba93a331041	3	1	3	3	win	2026-06-28 08:10:12.856203+00
9211ad01-d7a2-4b86-8e8e-b307fabebae3	af11bed1-3ae5-4dca-9511-f4a02eaf98d6	f1597d1c-d2cb-4027-86e1-0ba93a331041	3	1	3	3	win	2026-06-28 08:10:12.856203+00
20d244ba-510b-43b0-9543-80992fbaaf46	043c8449-c751-4a8a-810f-72e2ecd29045	7ea5f707-1221-4f5e-afd4-b87a6704c790	2	0	2	2	win	2026-06-28 20:57:27.993667+00
31cab300-68ec-486a-a325-49e20f1b762c	924ebbea-7b19-4167-b02a-2aea69e2df3b	7ea5f707-1221-4f5e-afd4-b87a6704c790	2	0	2	2	win	2026-06-28 20:57:27.993667+00
df5d633a-22e0-431d-8985-c9ee8b55fff2	648f4240-cc78-49c2-a7ed-91dd751b05e7	7ea5f707-1221-4f5e-afd4-b87a6704c790	2	0	2	2	win	2026-06-28 20:57:27.993667+00
e50123a2-81bb-47de-b20c-e572e50e4c2c	725879ce-81f7-4efe-bf1f-f8c8f17afbd9	7ea5f707-1221-4f5e-afd4-b87a6704c790	2	0	2	2	win	2026-06-28 20:57:27.993667+00
3a568d05-9fb2-47cc-8397-36285e0cc9b1	b3ace729-a7b8-438e-9ce9-d143e85f4126	1f013a7e-8052-415d-8090-99a4cfba5780	1	0	2	1	loss	2026-06-29 23:29:18.775185+00
2f5e577b-abcb-4671-9a7e-d5b43f86c0ce	d931a92e-282e-4660-837b-98d4d6bd19d1	1f013a7e-8052-415d-8090-99a4cfba5780	1	0	2	1	loss	2026-06-29 23:29:18.775185+00
35fb6f30-c8a5-4746-8564-9341e86e562e	81a4d73a-5c71-4afe-9bba-bdf444dd1adb	1f013a7e-8052-415d-8090-99a4cfba5780	1	0	2	1	loss	2026-06-29 23:29:18.775185+00
949a6cc2-8e4d-4976-ba28-396b16a8bca3	cd44771a-f2eb-48bb-b4dc-34a7b9fe564f	1f013a7e-8052-415d-8090-99a4cfba5780	1	0	2	1	loss	2026-06-29 23:29:18.775185+00
1b653f0f-3f76-480d-9080-f973676e47d1	7d5ee64b-d2f8-4cbd-a675-46adc213eab1	1f013a7e-8052-415d-8090-99a4cfba5780	1	0	2	1	loss	2026-06-29 23:29:18.775185+00
1a213706-e9a8-4642-b5aa-70798f73ff84	7a87d60e-ed48-456c-b5db-d5c6c17573a9	1f013a7e-8052-415d-8090-99a4cfba5780	1	0	2	1	loss	2026-06-29 23:29:18.775185+00
fbd11cba-ac95-4f6d-9315-4d3610acfbdf	f93e73c2-48aa-48b5-bcba-8eeb44e097ea	1f013a7e-8052-415d-8090-99a4cfba5780	1	0	2	1	loss	2026-06-29 23:29:18.775185+00
c8c10dd1-91aa-430d-bd9e-e2279a31d453	17dbaad8-1db1-4052-bf0e-3498c395b2d2	1f013a7e-8052-415d-8090-99a4cfba5780	1	0	2	1	loss	2026-06-29 23:29:18.775185+00
33958ee5-1a7a-4e04-9974-97dce0295ea9	3561b430-8d09-42c6-b1fc-65f0d5d451d8	1f013a7e-8052-415d-8090-99a4cfba5780	1	0	2	1	loss	2026-06-29 23:29:18.775185+00
42edd3c5-a47e-40f2-b08f-cbe56805122a	e540302c-fa3c-4ffc-bdc6-5217e6fdb103	1f013a7e-8052-415d-8090-99a4cfba5780	1	0	2	1	loss	2026-06-29 23:29:18.775185+00
d120d38b-6bde-40f8-9648-6ca7bef85349	c434bd29-7723-4b7f-9be0-4c26d43e3ce8	1f013a7e-8052-415d-8090-99a4cfba5780	1	0	2	1	loss	2026-06-29 23:29:18.775185+00
28f7b9b5-1773-46a2-aea4-a2000d04f877	3d890314-34b7-4be9-b579-93a38d997dd5	1f013a7e-8052-415d-8090-99a4cfba5780	1	0	2	1	loss	2026-06-29 23:29:18.775185+00
90f06835-5063-4262-8352-53cf7d5dbc9b	c8d54e64-9033-485a-8870-093f3d736a4c	1fd593cc-3f89-4335-8c34-1d4183911037	1	0	2	1	loss	2026-06-30 05:43:05.935735+00
1d4d7f2c-7915-4d26-b240-dec622ab686e	62f9f805-a897-41b6-948c-6d319f3de4b7	0bcfd687-dbd6-4369-bb0f-8fd682346491	2	0	2	2	win	2026-07-02 05:40:54.454317+00
aa2d5999-7125-4901-8871-5f262cf42134	db23c536-0a75-4e98-9b91-3c5e2f6d1e0d	0bcfd687-dbd6-4369-bb0f-8fd682346491	2	0	2	2	win	2026-07-02 05:40:54.454317+00
983b6f38-a46e-4846-816c-4f1717f40d42	4f49ecfe-d72b-475a-9fa8-3a5cf0d87343	0bcfd687-dbd6-4369-bb0f-8fd682346491	2	0	2	2	win	2026-07-02 05:40:54.454317+00
e456cd33-233e-426d-8bf1-bf5798ee66af	352dc734-6f9a-4cf0-bf2f-5f61015ede1c	0bcfd687-dbd6-4369-bb0f-8fd682346491	2	0	2	2	win	2026-07-02 05:40:54.454317+00
0ea590fa-51ed-4406-a82a-6a80ad834cc7	aa47e00f-2e87-4503-93f8-c3df70c26fa8	0bcfd687-dbd6-4369-bb0f-8fd682346491	2	0	2	2	win	2026-07-02 05:40:54.454317+00
87c30b65-1d64-405b-989c-f7aab746fc4b	9e79d347-2922-496b-a213-870f9c0ee284	0bcfd687-dbd6-4369-bb0f-8fd682346491	2	0	2	2	win	2026-07-02 05:40:54.454317+00
76e87edb-5f9b-4ca7-bdda-c1ebe994477d	b939347d-9031-4518-935e-39b7ab8050a9	0bcfd687-dbd6-4369-bb0f-8fd682346491	2	0	2	2	win	2026-07-02 05:40:54.454317+00
f10d5ffd-fade-4fd2-8633-d7b021247a1b	5fca833f-1b18-43f1-800b-33ad3965c56c	2e98ff8b-14f8-427d-bf77-320b06b02c7c	2	0	2	2	win	2026-07-03 06:52:38.697271+00
b323d4be-4952-4392-b215-3abf3d79ff9c	4caff54d-5f5a-4540-8520-6c9c98246a36	2e98ff8b-14f8-427d-bf77-320b06b02c7c	2	0	2	2	win	2026-07-03 06:52:38.697271+00
74cc6cc4-8712-4423-a043-7e00ec0f5b1a	de8fc6c4-49b9-4ad2-9b08-5728e2a4330d	356341b8-bf0c-49e3-9811-85ca67b9eea8	2	0	2	2	win	2026-07-04 03:16:39.246198+00
81adb5f4-6f74-4549-8b02-2d05a12a56f3	47f4a597-829d-46e6-ae0c-27f3f09b1f72	674d531c-ea1e-4fb8-b533-cb72f31d2a07	2	0	2	2	win	2026-07-04 03:32:53.196272+00
bbc9375f-06cf-455a-8519-da21306214e6	07ff1fc0-bf34-4de5-a524-edcf21d41208	c482116e-ce9c-40bc-b95e-616917977de0	2	0	2	2	win	2026-07-04 19:04:16.218977+00
82d4be34-dae4-4cd9-a742-ebc8e9bee5fd	c96fb551-02b9-486b-bc05-3c5b5636cac3	c482116e-ce9c-40bc-b95e-616917977de0	2	0	2	2	win	2026-07-04 19:04:16.218977+00
f095aa7e-b6f2-442d-810c-7d5d901eea48	41d9df49-0ff7-48de-beb8-a78d75cb3bb4	c482116e-ce9c-40bc-b95e-616917977de0	2	0	2	2	win	2026-07-04 19:04:16.218977+00
8780ac9f-89fa-4432-85c0-19c1656b0afa	ab97cb8e-eb42-411c-b47d-e8feb2d1280d	c482116e-ce9c-40bc-b95e-616917977de0	2	0	2	2	win	2026-07-04 19:04:16.218977+00
bfe5de52-bc77-48e3-aaee-5fb7f1fee24d	b00b6ffa-1372-49a5-b00c-9d92210d9fa3	c482116e-ce9c-40bc-b95e-616917977de0	2	0	2	2	win	2026-07-04 19:04:16.218977+00
fafa4584-e245-4b3f-803c-b130fda4b04e	3688f461-dc4d-41b0-9a1d-1a0faa46bcd7	c482116e-ce9c-40bc-b95e-616917977de0	2	0	2	2	win	2026-07-04 19:04:16.218977+00
edff3a18-d751-41bd-bf7c-e734e1a2ce47	e211558f-13c7-4920-9a2e-9148e53fa674	c482116e-ce9c-40bc-b95e-616917977de0	2	0	2	2	win	2026-07-04 19:04:16.218977+00
b78827a8-08af-4d8b-a0a2-a8380c1da82b	15e49401-a3b9-4021-b993-00a02c96b5ea	c482116e-ce9c-40bc-b95e-616917977de0	2	0	2	2	win	2026-07-04 19:04:16.218977+00
3a9bc4ab-fcb4-4aa5-b19e-bfb2f0087584	4283ab13-59c0-455b-b8b1-b6fd1f20546c	3ca50009-6690-4197-8fbb-29612575864d	2	0	2	2	win	2026-07-04 23:05:16.917455+00
c8f74486-78e0-4319-bf0e-92b1c267d68e	05a7d3db-280c-4405-b1c3-d3d828835941	8dc0c811-0f83-4784-95c6-94cd1691217e	0	0	2	0	loss	2026-07-06 00:01:20.442506+00
5cf1e868-91d1-471a-bfa0-4b81eec4bb6b	eef13217-e927-46e3-a9d5-c68cfc149be1	8dc0c811-0f83-4784-95c6-94cd1691217e	0	0	2	0	loss	2026-07-06 00:01:20.442506+00
b306863b-8fc5-40aa-8c50-03942b8d2c09	6c86d07e-636b-46ab-adb8-8db7eaaabb6b	8dc0c811-0f83-4784-95c6-94cd1691217e	0	0	2	0	loss	2026-07-06 00:01:20.442506+00
3be86c26-08bc-4125-82db-96ad129c1630	9d5cfe84-a6d5-42d8-aa8c-434bee581085	15a9d048-eb7c-464c-8034-cb2e8508bc61	0	0	2	0	loss	2026-07-07 06:39:59.798561+00
9c766014-e605-4aab-b189-d3dcfcc0e8b5	6cc62e54-8e76-41dd-b5fb-d23ce80aa10c	a0e08c51-817d-46fe-8016-5f5a0215b470	2	0	2	2	win	2026-07-07 18:06:49.153078+00
62a35a11-a8d5-412a-a69c-8b834a2582b8	36398198-c0c1-4bff-b357-bf851b2af6f2	5ff3fb62-02c7-4666-80f9-540118fecb20	1	0	2	1	loss	2026-07-07 22:50:36.559474+00
65b0e61a-eee7-4431-9507-270fd7a39336	beb70ea8-4882-4c6d-86f2-b26f14f80fc0	0ef4fa94-95e2-4f21-bf22-2dbd50f2426c	2	0	2	2	win	2026-07-09 22:00:57.007691+00
ec5f0dea-ec40-4326-a9fb-49cbc558af54	33abd365-0f43-4c90-a357-163607e75f94	7a401e03-6574-47d7-b91c-a7de7c3ed1dd	2	0	2	2	win	2026-07-10 20:59:48.403655+00
8d795ca9-5ce9-4f98-a189-41c37ffb3452	82b1fc2e-2e3c-4b3d-898d-da0f7d9f2e94	7a401e03-6574-47d7-b91c-a7de7c3ed1dd	2	0	2	2	win	2026-07-10 20:59:48.403655+00
3242d279-ccfc-433e-be7e-7e66fe146913	0c2cf528-6c47-488e-ab9c-32b688529522	7a401e03-6574-47d7-b91c-a7de7c3ed1dd	2	0	2	2	win	2026-07-10 20:59:48.403655+00
0f53aca2-a262-4061-b2bb-d17c0b130c92	ecb7e696-3b92-4d09-8b5f-1eead1d33994	7a401e03-6574-47d7-b91c-a7de7c3ed1dd	2	0	2	2	win	2026-07-10 20:59:48.403655+00
f78e3b96-3eda-4812-bf98-c9f5ffd27124	ef757b5c-a4df-4f93-a771-51d2bcf3b320	7a401e03-6574-47d7-b91c-a7de7c3ed1dd	2	0	2	2	win	2026-07-10 20:59:48.403655+00
a0437a06-01ed-44da-8af7-9e16bc568bdb	ba0fd4a0-98f9-48b6-bfaf-7194833efba0	7a401e03-6574-47d7-b91c-a7de7c3ed1dd	2	0	2	2	win	2026-07-10 20:59:48.403655+00
642fddd8-9485-456e-8f4e-aa631644a596	ab0ba333-841c-431d-ab92-a4e2ae574132	0abac47a-3e0a-4c4d-a733-fd3c5e94beed	2	0	2	2	win	2026-07-12 00:11:02.851975+00
e4ba8355-07ea-4f65-8fcb-738a86354e54	bc075904-041a-441c-a462-7c5271d9fa89	0abac47a-3e0a-4c4d-a733-fd3c5e94beed	2	0	2	2	win	2026-07-12 00:11:02.851975+00
a62f55e0-e67b-4554-97be-ad279fdde2f2	73deb83f-1cbb-47e7-b43a-16397b5bff71	00b8176c-7982-4869-afe6-35e05e89d930	2	0	2	2	win	2026-07-12 08:29:28.083051+00
2be236dc-47e4-48e9-8a98-25c3b5d759b6	c0738043-cc63-4dce-857d-3d08b85cd8e2	4ec3afba-9a7c-4409-87d0-7d3f64316c22	0	0	2	0	loss	2026-07-14 21:00:04.198853+00
6753fcc6-6dcb-40b7-8f09-c052b152f2d5	6fa1e9a4-0f8e-44d6-948a-db7ec32612df	4ec3afba-9a7c-4409-87d0-7d3f64316c22	0	0	2	0	loss	2026-07-14 21:00:04.198853+00
5a44e356-f859-431e-b110-72997964e182	e6d54021-80e8-481a-b73e-ce5d61eeda09	4ec3afba-9a7c-4409-87d0-7d3f64316c22	2	0	2	2	win	2026-07-14 21:00:04.198853+00
c87f8ce5-a0b0-4fd6-bb91-6220d3330de8	1bfbf1a9-2362-4d03-8813-34c9984a7fc0	4ec3afba-9a7c-4409-87d0-7d3f64316c22	0	0	2	0	loss	2026-07-14 21:00:04.198853+00
0f023b11-e2af-433d-8542-432bd133ebb1	13e39c16-7714-4062-ba07-f52043c35c66	4ec3afba-9a7c-4409-87d0-7d3f64316c22	0	0	2	0	loss	2026-07-14 21:00:04.198853+00
9801269d-ac39-46bc-baa8-fa14fe82ce01	12571d8d-fa1a-4443-acef-40309f5cf735	4ec3afba-9a7c-4409-87d0-7d3f64316c22	0	0	2	0	loss	2026-07-14 21:00:04.198853+00
ccf5a191-26e5-4a72-82c8-c0b15e5be979	04e85684-03aa-4533-a880-d2180376a275	5a849898-4855-4db0-926b-08d9605fd81a	0	0	2	0	loss	2026-07-15 21:05:06.3587+00
a58f285a-eb12-4000-b17f-57617520ea2e	8d904975-9ce6-4f31-aeff-f5f06e37e644	5a849898-4855-4db0-926b-08d9605fd81a	2	0	2	2	win	2026-07-15 21:05:06.3587+00
7a2e42ce-8696-4154-9bbb-0ce6f90da308	0dabc4ce-d9e1-4c0c-959d-57d79b58877f	5a849898-4855-4db0-926b-08d9605fd81a	2	0	2	2	win	2026-07-15 21:05:06.3587+00
28acb81a-bbed-4471-b6bb-295ab352da16	8f7a757f-c61d-4b95-9c83-6ac793fcba98	5a849898-4855-4db0-926b-08d9605fd81a	0	0	2	0	loss	2026-07-15 21:05:06.3587+00
9f85cd95-426a-4334-8214-6cbba20a1d66	9e9a58f5-26cf-477a-beea-394516422d46	c168f9b4-b365-4b6c-9b68-3f20f8650bf5	2	0	2	2	win	2026-07-19 22:03:05.588808+00
\.


--
-- Data for Name: picks; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.picks (id, player_id, round_id, team_id, multiplier, is_assigned, created_at, oracle_pick) FROM stdin;
8318e774-35dd-4b3f-9c55-292d76c749bb	6df76041-17a2-4c81-b653-82bb7124ee3f	5b9456a0-db45-445f-87a0-58737bb89313	fcc03c57-8857-4986-98b0-0e30fb42ab2a	3	f	2026-06-19 13:18:26.114475+00	f
9ae2e036-3fa7-480a-9c05-53986536c206	6df76041-17a2-4c81-b653-82bb7124ee3f	5b9456a0-db45-445f-87a0-58737bb89313	4976e7fd-9b45-4cc7-b741-fe801fcee2d0	2	f	2026-06-19 13:18:26.114475+00	f
91cec3ab-120d-4ea0-9a53-082214e3814c	1114a750-be9a-44a9-8d82-001931ea4466	5b9456a0-db45-445f-87a0-58737bb89313	4976e7fd-9b45-4cc7-b741-fe801fcee2d0	3	f	2026-06-20 11:07:56.382022+00	f
5087e3b8-b5da-4f16-a216-4f42c467746e	1114a750-be9a-44a9-8d82-001931ea4466	5b9456a0-db45-445f-87a0-58737bb89313	e176dd2c-4446-4811-b4cc-fc28e9c2ab25	2	f	2026-06-20 11:07:56.382022+00	f
5743d80d-4cc4-4b2c-9c73-14b0617a9e4d	1114a750-be9a-44a9-8d82-001931ea4466	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	cffa413c-8c76-45a6-843e-87c34e78e45a	3	f	2026-06-05 08:57:22.315872+00	f
8454e7db-2a11-45af-8b9a-e990da3be448	1114a750-be9a-44a9-8d82-001931ea4466	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	6ea9375b-d599-463f-96e6-c87d9209e9b2	2	f	2026-06-05 08:57:22.315872+00	f
9f7299c3-e804-4f92-b0ac-172375b575bd	d8cc0ff6-c084-4134-8931-bf514fa05f23	5b9456a0-db45-445f-87a0-58737bb89313	f99d6725-238c-4d95-8502-9d25b4a6e89e	3	f	2026-06-21 06:44:58.671721+00	f
ee5d54c9-d97c-4fe0-aad5-bf13ccee80f7	d8cc0ff6-c084-4134-8931-bf514fa05f23	5b9456a0-db45-445f-87a0-58737bb89313	8682004e-e186-4705-aa29-9704b2815dc4	2	f	2026-06-21 06:44:58.671721+00	f
3292dbeb-749f-49f7-9e6f-0b8cc376b059	195dcc37-e60e-4608-a0dc-c12766e96259	5b9456a0-db45-445f-87a0-58737bb89313	20160ec3-c507-4fb3-b19d-89cb66c59a98	3	f	2026-06-22 13:50:43.355503+00	f
bde7ed21-f9ba-4044-8e0b-216e6f2df086	195dcc37-e60e-4608-a0dc-c12766e96259	5b9456a0-db45-445f-87a0-58737bb89313	4976e7fd-9b45-4cc7-b741-fe801fcee2d0	2	f	2026-06-22 13:50:43.355503+00	f
170f69e3-16b4-48a3-84fe-a0b3fd1a6f58	3d58a7df-9922-413e-b42a-c2f162fb834c	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	52f066d8-0a7a-42c5-8a6b-103ec4ba2c91	3	f	2026-06-05 17:22:21.514743+00	f
766234a8-baa7-47c2-a44a-9414ba5208e1	3d58a7df-9922-413e-b42a-c2f162fb834c	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	52eaa3b4-081b-4393-b291-d69c644c612e	2	f	2026-06-05 17:22:21.514743+00	f
d66cb19c-1ed7-44af-a05d-128e639fd263	5d4ce78f-67ee-4a61-afab-c44ffc6afe91	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	52f066d8-0a7a-42c5-8a6b-103ec4ba2c91	3	f	2026-06-06 11:19:44.545127+00	f
f8034bc4-2d20-47f7-81a6-e92683fce7f8	5d4ce78f-67ee-4a61-afab-c44ffc6afe91	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	910a4a31-591d-4c32-8b57-b0d0bbde5a26	2	f	2026-06-06 11:19:44.545127+00	f
0cee0956-6598-40ce-b920-77efc52500ba	8050b663-c1ef-4a14-86bd-3ea225435c17	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	52eaa3b4-081b-4393-b291-d69c644c612e	3	f	2026-06-06 11:29:06.070391+00	f
91e3367a-d890-4726-81ce-510e46788c6b	8050b663-c1ef-4a14-86bd-3ea225435c17	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	61d8b501-96d1-4043-a2b7-de27e9b137d7	2	f	2026-06-06 11:29:06.070391+00	f
8afc3225-5929-4cad-87cb-e44760e19f55	ce064aab-7c13-4db9-89b3-7eb444cc158b	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	acfbd82a-7005-41b9-9613-606ceefc857e	3	f	2026-06-07 12:46:27.058011+00	f
1a1b5c8d-1379-4cd2-91eb-5c61b6cc6510	ce064aab-7c13-4db9-89b3-7eb444cc158b	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	20e98c7a-4548-44f8-964d-7aba42ae7624	2	f	2026-06-07 12:46:27.058011+00	f
a98034ff-0966-4d4a-8e7f-77cd28b28a02	6f8a0f72-aa76-4252-9486-cc8b95570923	5b9456a0-db45-445f-87a0-58737bb89313	fcc03c57-8857-4986-98b0-0e30fb42ab2a	3	f	2026-06-22 13:57:01.803275+00	t
fbe87f42-8977-4670-a191-0034f1992729	6f8a0f72-aa76-4252-9486-cc8b95570923	5b9456a0-db45-445f-87a0-58737bb89313	20160ec3-c507-4fb3-b19d-89cb66c59a98	2	f	2026-06-22 13:57:01.803275+00	t
9d738f52-4624-44c2-a7f3-5d7634f037ac	3422f6a8-d289-4ce8-8135-b547ff0f9606	5b9456a0-db45-445f-87a0-58737bb89313	151a98cf-99e8-4e7a-ab57-396a13db4a72	3	f	2026-06-22 18:40:05.190423+00	f
24d317f4-e7a3-40d9-8a2b-c8a9e6214959	3422f6a8-d289-4ce8-8135-b547ff0f9606	5b9456a0-db45-445f-87a0-58737bb89313	4976e7fd-9b45-4cc7-b741-fe801fcee2d0	2	f	2026-06-22 18:40:05.190423+00	f
82e9d82d-8f87-45e0-8658-28cf709a8490	03d17e40-bb16-4728-9043-ceb05e62c9e9	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	87881cf2-7a14-4afa-9912-0ef5b2672387	3	f	2026-06-07 18:40:05.523766+00	f
83e2707e-1efc-4685-9dd7-4b5e5bfd019a	03d17e40-bb16-4728-9043-ceb05e62c9e9	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	61d8b501-96d1-4043-a2b7-de27e9b137d7	2	f	2026-06-07 18:40:05.523766+00	t
45afc289-0d3b-4c7a-a1d3-f77a1bcf4213	b3d06ab8-28c8-4e46-a174-1da15c08949c	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	52eaa3b4-081b-4393-b291-d69c644c612e	3	f	2026-06-07 18:47:19.327658+00	f
f8ddd991-2242-4aa3-be9a-a4f72e0d931e	b3d06ab8-28c8-4e46-a174-1da15c08949c	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	20e98c7a-4548-44f8-964d-7aba42ae7624	2	f	2026-06-07 18:47:19.327658+00	f
d3c89295-cc79-458c-9d18-57a37c901b1c	5e429458-4e6f-4df7-88bd-43977c8f74b1	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	8682004e-e186-4705-aa29-9704b2815dc4	3	f	2026-06-07 21:15:11.124378+00	f
b522652a-b1e5-4b57-afe0-b36a4705dbe1	5e429458-4e6f-4df7-88bd-43977c8f74b1	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	52eaa3b4-081b-4393-b291-d69c644c612e	2	f	2026-06-07 21:15:11.124378+00	f
d4077bd1-f686-451c-9070-f7356d646a0f	3422f6a8-d289-4ce8-8135-b547ff0f9606	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	61d8b501-96d1-4043-a2b7-de27e9b137d7	3	f	2026-06-08 11:06:17.697689+00	f
72f8c43b-0b4a-43b3-bb7f-37483a3c1a59	3422f6a8-d289-4ce8-8135-b547ff0f9606	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	52f066d8-0a7a-42c5-8a6b-103ec4ba2c91	2	f	2026-06-08 11:06:17.697689+00	f
bcd7152d-2ca8-4016-8260-a61597921f5f	38120818-5997-43e2-a907-f86000cf4b53	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	52eaa3b4-081b-4393-b291-d69c644c612e	3	f	2026-06-08 11:51:39.752476+00	f
abbed847-5440-421c-922b-cdb3bf0dd381	38120818-5997-43e2-a907-f86000cf4b53	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	61d8b501-96d1-4043-a2b7-de27e9b137d7	2	f	2026-06-08 11:51:39.752476+00	f
98c7a20b-ba36-4d7f-a4ba-c596a2c127be	38120818-5997-43e2-a907-f86000cf4b53	5b9456a0-db45-445f-87a0-58737bb89313	54ef8b7c-5afd-4a48-a3b9-d6701dd757f9	3	f	2026-06-08 11:54:20.408673+00	f
011679a8-9c2a-465d-ab45-d84d5587e841	38120818-5997-43e2-a907-f86000cf4b53	5b9456a0-db45-445f-87a0-58737bb89313	fcc03c57-8857-4986-98b0-0e30fb42ab2a	2	f	2026-06-08 11:54:20.408673+00	f
59c2a05e-d441-475b-a254-b4ad61dabc7d	d8cc0ff6-c084-4134-8931-bf514fa05f23	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	acfbd82a-7005-41b9-9613-606ceefc857e	3	f	2026-06-08 14:59:31.979755+00	f
3617d909-af94-4722-857f-9250fa7e1573	d8cc0ff6-c084-4134-8931-bf514fa05f23	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	4f0f3776-f99f-4c06-9eb4-0acd2825d8c2	2	f	2026-06-08 14:59:31.979755+00	f
4ba5728d-a717-4d3d-9aaa-31991485f256	b8526be4-5eb8-4f89-b015-699537c368ce	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	52f066d8-0a7a-42c5-8a6b-103ec4ba2c91	3	f	2026-06-08 16:20:21.777935+00	f
07395e96-812e-4c00-b31c-e39d4d78ddd3	b8526be4-5eb8-4f89-b015-699537c368ce	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	52eaa3b4-081b-4393-b291-d69c644c612e	2	f	2026-06-08 16:20:21.777935+00	f
98e40309-511c-4ec7-bf8e-06d56299211d	3fe745df-9187-41d7-a785-c3736a7277d7	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	acfbd82a-7005-41b9-9613-606ceefc857e	3	f	2026-06-08 18:59:49.229728+00	f
dfa1c6af-f9ed-41be-95b2-acc51621e98a	3fe745df-9187-41d7-a785-c3736a7277d7	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	52f066d8-0a7a-42c5-8a6b-103ec4ba2c91	2	f	2026-06-08 18:59:49.229728+00	f
975fe05c-5398-4da2-8bb0-dc75d7fa86b6	e73bedf4-0330-41d0-b1e7-31cb55909eed	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	52f066d8-0a7a-42c5-8a6b-103ec4ba2c91	3	f	2026-06-09 19:24:18.417394+00	f
c72d79d4-8159-4b46-9ce7-aad8d1a863f7	e73bedf4-0330-41d0-b1e7-31cb55909eed	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	61d8b501-96d1-4043-a2b7-de27e9b137d7	2	f	2026-06-09 19:24:18.417394+00	f
5766336c-a0db-4a0f-ace2-35cb78378bd2	ed3a6f56-12b3-4f1a-ab83-4744531df4f1	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	52f066d8-0a7a-42c5-8a6b-103ec4ba2c91	3	f	2026-06-09 19:56:20.766514+00	f
865161dc-dee5-4b62-9502-957bd743d9ea	ed3a6f56-12b3-4f1a-ab83-4744531df4f1	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	61d8b501-96d1-4043-a2b7-de27e9b137d7	2	f	2026-06-09 19:56:20.766514+00	f
34901be0-8283-4da8-a135-c8242bd4e44a	71391ec7-5614-4690-8008-e2e16163570b	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	e176dd2c-4446-4811-b4cc-fc28e9c2ab25	3	f	2026-06-09 20:03:57.523594+00	f
5bcfbff8-9dcf-4eea-8b30-1fcfe3d72bfb	71391ec7-5614-4690-8008-e2e16163570b	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	52f066d8-0a7a-42c5-8a6b-103ec4ba2c91	2	f	2026-06-09 20:03:57.523594+00	f
28a7347c-5309-4ddc-87c2-171a38efa8e5	36e379ae-18cb-488c-a9ef-34e99c796cfe	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	acfbd82a-7005-41b9-9613-606ceefc857e	3	f	2026-06-09 22:46:19.165509+00	f
498fb3fa-4beb-4176-828c-f1dbdaa57fb9	36e379ae-18cb-488c-a9ef-34e99c796cfe	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	ee8ecff9-d0b1-4aa8-ab21-da08a6c9229a	2	f	2026-06-09 22:46:19.165509+00	f
658f3772-af5d-4d3a-80a0-97ee9f0c2c9d	195dcc37-e60e-4608-a0dc-c12766e96259	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	20e98c7a-4548-44f8-964d-7aba42ae7624	3	f	2026-06-10 05:31:01.724624+00	f
06476d60-d7e3-4e4c-99f2-f554740acc3e	195dcc37-e60e-4608-a0dc-c12766e96259	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	52eaa3b4-081b-4393-b291-d69c644c612e	2	f	2026-06-10 05:31:01.724624+00	f
f3d82b86-fe6b-45be-82e1-361c74c797cb	1cc4459a-e518-4a28-b323-7cbb9d07994a	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	52f066d8-0a7a-42c5-8a6b-103ec4ba2c91	3	f	2026-06-10 10:17:28.558076+00	f
6c33d2a6-8ba5-49f1-af6d-ea9e1710bd20	1cc4459a-e518-4a28-b323-7cbb9d07994a	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	8d109cbf-133f-496a-b5b7-3f75a0ec1dcd	2	f	2026-06-10 10:17:28.558076+00	f
e3aabe51-1561-4dfb-9466-bde9cee3a680	b94d44f2-7ae2-41f4-a105-e12b6ec3a572	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	acfbd82a-7005-41b9-9613-606ceefc857e	3	f	2026-06-10 10:20:39.901686+00	f
5fa9c20d-e6a5-4365-80c1-c62a99f9e4b8	b94d44f2-7ae2-41f4-a105-e12b6ec3a572	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	52eaa3b4-081b-4393-b291-d69c644c612e	2	f	2026-06-10 10:20:39.901686+00	f
b8cea0d2-2503-4e46-80d9-009bc02fb93d	1c570e30-214d-4723-96d3-0669c937f5a4	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	52f066d8-0a7a-42c5-8a6b-103ec4ba2c91	3	f	2026-06-10 10:54:58.100843+00	f
2f41ac59-eceb-4d73-b4f9-45c4772bbd80	1c570e30-214d-4723-96d3-0669c937f5a4	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	52eaa3b4-081b-4393-b291-d69c644c612e	2	f	2026-06-10 10:54:58.100843+00	f
2b9bd34c-43c1-4ef1-b9d8-ad662c55efce	fa6409a1-23bb-4d8f-a6a3-a724774868cb	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	acfbd82a-7005-41b9-9613-606ceefc857e	2	f	2026-06-10 12:28:53.451545+00	f
6b87a1ac-1832-47d9-8c01-012c2f03a755	fa6409a1-23bb-4d8f-a6a3-a724774868cb	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	20e98c7a-4548-44f8-964d-7aba42ae7624	3	f	2026-06-10 12:28:53.451545+00	f
23dde6b6-0d42-4f98-98c2-6829c91fa855	31780afe-855c-4c9d-9cf6-56e3570c00c4	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	20e98c7a-4548-44f8-964d-7aba42ae7624	3	f	2026-06-10 16:58:20.238314+00	f
5a8b5ada-1e89-4aa5-9c1d-155376187162	31780afe-855c-4c9d-9cf6-56e3570c00c4	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	52f066d8-0a7a-42c5-8a6b-103ec4ba2c91	2	f	2026-06-10 16:58:20.238314+00	f
819eefc5-3492-44aa-85d7-1e2c7a20f656	6f8a0f72-aa76-4252-9486-cc8b95570923	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	e171e736-56f2-44fa-92b5-b0653ea2ce2a	3	f	2026-06-10 18:20:08.295485+00	t
dd036c38-6480-499b-9041-64cecc9a1276	6f8a0f72-aa76-4252-9486-cc8b95570923	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	4976e7fd-9b45-4cc7-b741-fe801fcee2d0	2	f	2026-06-10 18:20:08.295485+00	t
b4b4b2e2-0dee-4eea-9309-8190d689f978	6f8a0f72-aa76-4252-9486-cc8b95570923	c22e6746-73c1-4060-9194-eb35359c955e	ee8ecff9-d0b1-4aa8-ab21-da08a6c9229a	3	f	2026-06-10 18:20:39.243316+00	t
a4a36be7-713f-4145-8b42-67abc12a05ee	6f8a0f72-aa76-4252-9486-cc8b95570923	c22e6746-73c1-4060-9194-eb35359c955e	d6209663-7a5c-4736-b346-cde299b554b2	2	f	2026-06-10 18:20:39.243316+00	t
7e0802f3-072b-4f99-b13f-449f495bcfa0	c599dde6-99b1-4e0e-a4cf-2842c8f62162	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	52f066d8-0a7a-42c5-8a6b-103ec4ba2c91	3	f	2026-06-10 20:49:19.338111+00	f
48fa004d-e8e5-4ec2-8577-83d5b894ce7c	c599dde6-99b1-4e0e-a4cf-2842c8f62162	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	54ef8b7c-5afd-4a48-a3b9-d6701dd757f9	2	f	2026-06-10 20:49:19.338111+00	f
f61c4b99-1253-4c47-9340-581814d14ae8	1243a746-100c-460a-bf0f-2aadef7332b8	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	e171e736-56f2-44fa-92b5-b0653ea2ce2a	3	f	2026-06-10 21:32:34.470904+00	f
8052d2fe-367b-4d0c-b140-69cfd16395a1	1243a746-100c-460a-bf0f-2aadef7332b8	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	ee8ecff9-d0b1-4aa8-ab21-da08a6c9229a	2	f	2026-06-10 21:32:34.470904+00	f
6f773ba7-cbac-42ac-a96f-cf5a47ff0611	1243a746-100c-460a-bf0f-2aadef7332b8	c22e6746-73c1-4060-9194-eb35359c955e	ddd77a2f-eb9f-4a20-8ae4-e1ca55c21893	3	f	2026-06-10 21:36:28.056292+00	f
3bf8b92e-e19f-4df9-aa93-668ad03a9c31	1243a746-100c-460a-bf0f-2aadef7332b8	c22e6746-73c1-4060-9194-eb35359c955e	4f0f3776-f99f-4c06-9eb4-0acd2825d8c2	2	f	2026-06-10 21:36:28.056292+00	f
846de7c9-58aa-41e8-b526-89f0bf72c1cd	1243a746-100c-460a-bf0f-2aadef7332b8	5b9456a0-db45-445f-87a0-58737bb89313	fcc03c57-8857-4986-98b0-0e30fb42ab2a	3	f	2026-06-10 21:40:08.828336+00	f
d8b62402-0256-4d04-97b0-810a7aaa0915	1243a746-100c-460a-bf0f-2aadef7332b8	5b9456a0-db45-445f-87a0-58737bb89313	151a98cf-99e8-4e7a-ab57-396a13db4a72	2	f	2026-06-10 21:40:08.828336+00	f
43c2148a-2a78-4238-a2fc-8a7d61c6c37b	6df76041-17a2-4c81-b653-82bb7124ee3f	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	acfbd82a-7005-41b9-9613-606ceefc857e	3	f	2026-06-11 13:57:32.335553+00	f
45661692-2f33-4243-ae8e-029025fffefc	6df76041-17a2-4c81-b653-82bb7124ee3f	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	e171e736-56f2-44fa-92b5-b0653ea2ce2a	2	f	2026-06-11 13:57:32.335553+00	f
3844c305-627a-4e78-86d1-8a80243701c4	fea5b705-eab8-4ba4-b0f2-739b370efd98	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	e176dd2c-4446-4811-b4cc-fc28e9c2ab25	3	f	2026-06-11 17:05:25.658607+00	f
f5b14944-30e9-43de-a233-875d89bb555b	fea5b705-eab8-4ba4-b0f2-739b370efd98	32854b42-0d3a-4e2e-9555-00cd1e6c83c6	52eaa3b4-081b-4393-b291-d69c644c612e	2	f	2026-06-11 17:05:25.658607+00	f
70a31294-9c8d-4f8b-bbb8-d676082f7988	1cc4459a-e518-4a28-b323-7cbb9d07994a	5b9456a0-db45-445f-87a0-58737bb89313	a681c714-630a-487f-b167-9cefea486591	3	f	2026-06-19 19:20:59.877652+00	f
531be698-4a2d-49bc-8ded-dee8ff695a9b	1cc4459a-e518-4a28-b323-7cbb9d07994a	5b9456a0-db45-445f-87a0-58737bb89313	622bb3ef-bc6e-4c9a-9efe-aae4d0f95822	2	f	2026-06-19 19:20:59.877652+00	f
fb492b60-8db3-4912-b4e0-bdcac48489bb	ce064aab-7c13-4db9-89b3-7eb444cc158b	c22e6746-73c1-4060-9194-eb35359c955e	66a8014f-0009-400e-928c-6b28cb8dab1f	3	f	2026-06-15 09:57:35.783708+00	f
684357ca-b1be-4b8c-b03b-c3a74ab47476	ce064aab-7c13-4db9-89b3-7eb444cc158b	c22e6746-73c1-4060-9194-eb35359c955e	cd984ce3-2f2c-41d5-a7ba-137060caf8ae	2	f	2026-06-15 09:57:35.783708+00	f
8843ff08-b9a5-4177-b926-7796316c54b1	ce064aab-7c13-4db9-89b3-7eb444cc158b	5b9456a0-db45-445f-87a0-58737bb89313	fcc03c57-8857-4986-98b0-0e30fb42ab2a	3	f	2026-06-22 03:01:21.166117+00	f
69e1e472-329b-4c0f-ac3d-70a86a6d0103	ce064aab-7c13-4db9-89b3-7eb444cc158b	5b9456a0-db45-445f-87a0-58737bb89313	f99d6725-238c-4d95-8502-9d25b4a6e89e	2	f	2026-06-22 03:01:21.166117+00	f
1687a5d0-0a74-48c0-aee1-586c47daebc5	d8cc0ff6-c084-4134-8931-bf514fa05f23	c22e6746-73c1-4060-9194-eb35359c955e	cba2c884-3603-4b90-976e-49389b04f562	3	f	2026-06-15 20:30:51.690038+00	f
96754c6f-3c8d-4a6c-b2ff-44ac79bd5f70	d8cc0ff6-c084-4134-8931-bf514fa05f23	c22e6746-73c1-4060-9194-eb35359c955e	d6209663-7a5c-4736-b346-cde299b554b2	2	f	2026-06-15 20:30:51.690038+00	f
949b8f71-8f82-4502-85d7-7262a9223506	31780afe-855c-4c9d-9cf6-56e3570c00c4	c22e6746-73c1-4060-9194-eb35359c955e	6527ec07-bc6b-4b53-8bff-90b6f622aece	3	f	2026-06-16 20:34:26.851764+00	f
bf4d041b-bc7d-4e4c-be54-37de9a0d1682	31780afe-855c-4c9d-9cf6-56e3570c00c4	c22e6746-73c1-4060-9194-eb35359c955e	ddd77a2f-eb9f-4a20-8ae4-e1ca55c21893	2	f	2026-06-16 20:34:26.851764+00	f
14efa54b-c629-4e54-96be-fe776a992502	8050b663-c1ef-4a14-86bd-3ea225435c17	c22e6746-73c1-4060-9194-eb35359c955e	ee8ecff9-d0b1-4aa8-ab21-da08a6c9229a	3	f	2026-06-17 06:04:20.470644+00	f
29d0629f-44a9-49a8-a0b0-d9fee87355ae	8050b663-c1ef-4a14-86bd-3ea225435c17	c22e6746-73c1-4060-9194-eb35359c955e	cd984ce3-2f2c-41d5-a7ba-137060caf8ae	2	f	2026-06-17 06:04:20.470644+00	f
8e80e933-977c-422f-91c8-cbd168c89ec4	c599dde6-99b1-4e0e-a4cf-2842c8f62162	c22e6746-73c1-4060-9194-eb35359c955e	8682004e-e186-4705-aa29-9704b2815dc4	3	f	2026-06-17 06:52:31.923941+00	f
747023f0-5db0-407a-a94d-855dd0fe64e3	c599dde6-99b1-4e0e-a4cf-2842c8f62162	c22e6746-73c1-4060-9194-eb35359c955e	d6209663-7a5c-4736-b346-cde299b554b2	2	f	2026-06-17 06:52:31.923941+00	f
b963d149-7873-4a54-acb7-2efa34627c14	5d4ce78f-67ee-4a61-afab-c44ffc6afe91	c22e6746-73c1-4060-9194-eb35359c955e	66a8014f-0009-400e-928c-6b28cb8dab1f	3	f	2026-06-17 09:19:54.876021+00	f
7ba2e30f-3648-4036-a8c7-0a3f616525f2	5d4ce78f-67ee-4a61-afab-c44ffc6afe91	c22e6746-73c1-4060-9194-eb35359c955e	d6209663-7a5c-4736-b346-cde299b554b2	2	f	2026-06-17 09:19:54.876021+00	f
a64d4b3e-f5e1-41d6-a88e-4113d679e1a8	b8526be4-5eb8-4f89-b015-699537c368ce	c22e6746-73c1-4060-9194-eb35359c955e	cba2c884-3603-4b90-976e-49389b04f562	3	f	2026-06-17 09:30:30.453386+00	f
6a813b11-3c44-4740-82a7-79c1475309b3	b8526be4-5eb8-4f89-b015-699537c368ce	c22e6746-73c1-4060-9194-eb35359c955e	66a8014f-0009-400e-928c-6b28cb8dab1f	2	f	2026-06-17 09:30:30.453386+00	f
383e528c-694d-44c2-a9e0-68f39272a79e	b3d06ab8-28c8-4e46-a174-1da15c08949c	c22e6746-73c1-4060-9194-eb35359c955e	cd984ce3-2f2c-41d5-a7ba-137060caf8ae	3	f	2026-06-17 10:51:28.469252+00	f
903438d3-94cd-4837-a393-10db197e9528	b3d06ab8-28c8-4e46-a174-1da15c08949c	c22e6746-73c1-4060-9194-eb35359c955e	d6209663-7a5c-4736-b346-cde299b554b2	2	f	2026-06-17 10:51:28.469252+00	f
1668026a-ecbf-4789-8a20-b3ae5bcc7519	1cc4459a-e518-4a28-b323-7cbb9d07994a	c22e6746-73c1-4060-9194-eb35359c955e	d6209663-7a5c-4736-b346-cde299b554b2	3	f	2026-06-17 11:53:02.039188+00	f
e0041469-d0f2-4e6f-9aad-1d65c38a5271	1cc4459a-e518-4a28-b323-7cbb9d07994a	c22e6746-73c1-4060-9194-eb35359c955e	20160ec3-c507-4fb3-b19d-89cb66c59a98	2	f	2026-06-17 11:53:02.039188+00	f
4edee4df-2901-47b3-aa1e-5b5b44734547	1c570e30-214d-4723-96d3-0669c937f5a4	c22e6746-73c1-4060-9194-eb35359c955e	cd984ce3-2f2c-41d5-a7ba-137060caf8ae	3	f	2026-06-17 12:01:04.542266+00	f
deddd4c3-a62b-4503-ad65-d6245b1462ac	1c570e30-214d-4723-96d3-0669c937f5a4	c22e6746-73c1-4060-9194-eb35359c955e	ee8ecff9-d0b1-4aa8-ab21-da08a6c9229a	2	f	2026-06-17 12:01:04.542266+00	f
8ceeb596-437c-4483-9564-1c63c4df8152	b94d44f2-7ae2-41f4-a105-e12b6ec3a572	c22e6746-73c1-4060-9194-eb35359c955e	cd984ce3-2f2c-41d5-a7ba-137060caf8ae	3	f	2026-06-17 13:45:12.62055+00	f
84be8d14-5150-47ec-a548-561a7e994c98	b94d44f2-7ae2-41f4-a105-e12b6ec3a572	c22e6746-73c1-4060-9194-eb35359c955e	d6209663-7a5c-4736-b346-cde299b554b2	2	f	2026-06-17 13:45:12.62055+00	t
6b7dff11-5bc7-41cb-8bc6-ec54d68b0055	e73bedf4-0330-41d0-b1e7-31cb55909eed	c22e6746-73c1-4060-9194-eb35359c955e	e171e736-56f2-44fa-92b5-b0653ea2ce2a	3	f	2026-06-17 13:50:33.232108+00	f
d470d41d-42cd-4c9e-84e9-b8b0e1487caa	e73bedf4-0330-41d0-b1e7-31cb55909eed	c22e6746-73c1-4060-9194-eb35359c955e	d6209663-7a5c-4736-b346-cde299b554b2	2	f	2026-06-17 13:50:33.232108+00	f
852a2a8d-6c94-4d90-a4c5-35a8b64348ff	71391ec7-5614-4690-8008-e2e16163570b	c22e6746-73c1-4060-9194-eb35359c955e	cd984ce3-2f2c-41d5-a7ba-137060caf8ae	3	f	2026-06-17 14:24:01.295937+00	f
d72412f2-814c-4b19-9a02-79781605232e	71391ec7-5614-4690-8008-e2e16163570b	c22e6746-73c1-4060-9194-eb35359c955e	acfbd82a-7005-41b9-9613-606ceefc857e	2	f	2026-06-17 14:24:01.295937+00	f
8465e4e6-f492-47e5-8c50-ef8761a3a10b	3d58a7df-9922-413e-b42a-c2f162fb834c	c22e6746-73c1-4060-9194-eb35359c955e	8682004e-e186-4705-aa29-9704b2815dc4	3	f	2026-06-17 16:42:12.541838+00	f
46ab2698-2857-4049-b073-192fc46c7fb6	3d58a7df-9922-413e-b42a-c2f162fb834c	c22e6746-73c1-4060-9194-eb35359c955e	cd984ce3-2f2c-41d5-a7ba-137060caf8ae	2	f	2026-06-17 16:42:12.541838+00	f
d0930464-d664-4485-9542-0f6c71132fa6	5e429458-4e6f-4df7-88bd-43977c8f74b1	5b9456a0-db45-445f-87a0-58737bb89313	20160ec3-c507-4fb3-b19d-89cb66c59a98	3	f	2026-06-17 18:48:33.691159+00	f
96c11b54-15c5-4174-9408-abf158176d7f	5e429458-4e6f-4df7-88bd-43977c8f74b1	5b9456a0-db45-445f-87a0-58737bb89313	a681c714-630a-487f-b167-9cefea486591	2	f	2026-06-17 18:48:33.691159+00	f
e6fbc360-6cd5-4e38-bb44-e09a352bbe98	5e429458-4e6f-4df7-88bd-43977c8f74b1	c22e6746-73c1-4060-9194-eb35359c955e	d6209663-7a5c-4736-b346-cde299b554b2	3	f	2026-06-17 18:50:20.45+00	f
338be2cc-b9b7-494f-8e63-5f83a5b21eec	5e429458-4e6f-4df7-88bd-43977c8f74b1	c22e6746-73c1-4060-9194-eb35359c955e	4f0f3776-f99f-4c06-9eb4-0acd2825d8c2	2	f	2026-06-17 18:50:20.45+00	f
e299ca02-e0ff-42cf-990d-169579dd76eb	fa6409a1-23bb-4d8f-a6a3-a724774868cb	c22e6746-73c1-4060-9194-eb35359c955e	cd984ce3-2f2c-41d5-a7ba-137060caf8ae	3	f	2026-06-17 19:09:45.091169+00	f
ace84946-ad1c-498e-bc50-841158b9916c	fa6409a1-23bb-4d8f-a6a3-a724774868cb	c22e6746-73c1-4060-9194-eb35359c955e	d6209663-7a5c-4736-b346-cde299b554b2	2	f	2026-06-17 19:09:45.091169+00	f
6f6af635-58ee-47f3-872e-d1d6479942fa	03d17e40-bb16-4728-9043-ceb05e62c9e9	c22e6746-73c1-4060-9194-eb35359c955e	eaca3063-d90c-4007-b3d8-ba829b3ee14e	3	f	2026-06-17 21:32:38.716879+00	f
809a34d5-fc53-4b8e-a13d-de8c208fdb89	03d17e40-bb16-4728-9043-ceb05e62c9e9	c22e6746-73c1-4060-9194-eb35359c955e	8682004e-e186-4705-aa29-9704b2815dc4	2	f	2026-06-17 21:32:38.716879+00	f
a8396f71-0bef-4602-af64-a4c45d18bf56	38120818-5997-43e2-a907-f86000cf4b53	c22e6746-73c1-4060-9194-eb35359c955e	ee8ecff9-d0b1-4aa8-ab21-da08a6c9229a	3	f	2026-06-18 01:24:42.67973+00	f
7b233df2-ecef-4ebc-85f6-99c7d7a9132b	38120818-5997-43e2-a907-f86000cf4b53	c22e6746-73c1-4060-9194-eb35359c955e	d6209663-7a5c-4736-b346-cde299b554b2	2	f	2026-06-18 01:24:42.67973+00	f
4897196b-e754-461b-a800-8b2bd39957b6	3422f6a8-d289-4ce8-8135-b547ff0f9606	c22e6746-73c1-4060-9194-eb35359c955e	d6209663-7a5c-4736-b346-cde299b554b2	3	f	2026-06-18 03:28:45.097872+00	f
cc48d101-64a9-4da3-8b4b-ae2ae55572ea	3422f6a8-d289-4ce8-8135-b547ff0f9606	c22e6746-73c1-4060-9194-eb35359c955e	4f0f3776-f99f-4c06-9eb4-0acd2825d8c2	2	f	2026-06-18 03:28:45.097872+00	f
f6f0df20-282e-4682-afef-c7121ba2f68a	6df76041-17a2-4c81-b653-82bb7124ee3f	c22e6746-73c1-4060-9194-eb35359c955e	4f0f3776-f99f-4c06-9eb4-0acd2825d8c2	3	f	2026-06-18 06:08:25.927333+00	f
ddb16359-c8c7-4e78-9990-651c955d4bd0	6df76041-17a2-4c81-b653-82bb7124ee3f	c22e6746-73c1-4060-9194-eb35359c955e	cd984ce3-2f2c-41d5-a7ba-137060caf8ae	2	f	2026-06-18 06:08:25.927333+00	f
b55cb969-cc67-48bd-9dad-97ac206ce182	ed3a6f56-12b3-4f1a-ab83-4744531df4f1	c22e6746-73c1-4060-9194-eb35359c955e	b6afbe52-5067-4263-a750-6101f6efedc0	3	f	2026-06-18 06:58:32.610758+00	f
1ee91f43-f35f-409e-8db8-7b5e6bdc67f8	ed3a6f56-12b3-4f1a-ab83-4744531df4f1	c22e6746-73c1-4060-9194-eb35359c955e	d6209663-7a5c-4736-b346-cde299b554b2	2	f	2026-06-18 06:58:32.610758+00	f
2ccab4b4-3b72-4d40-9088-da8567b3c8da	36e379ae-18cb-488c-a9ef-34e99c796cfe	c22e6746-73c1-4060-9194-eb35359c955e	ddd77a2f-eb9f-4a20-8ae4-e1ca55c21893	3	f	2026-06-18 08:34:15.510325+00	f
70b072ea-876e-4856-80f7-be94e89104a7	36e379ae-18cb-488c-a9ef-34e99c796cfe	c22e6746-73c1-4060-9194-eb35359c955e	b6afbe52-5067-4263-a750-6101f6efedc0	2	f	2026-06-18 08:34:15.510325+00	f
91101c0b-cb8c-4b59-a165-df7ece12b28e	195dcc37-e60e-4608-a0dc-c12766e96259	c22e6746-73c1-4060-9194-eb35359c955e	cd984ce3-2f2c-41d5-a7ba-137060caf8ae	3	f	2026-06-18 10:00:39.978081+00	f
08a0fda1-9f44-4a00-b6ad-ca913cc28d00	195dcc37-e60e-4608-a0dc-c12766e96259	c22e6746-73c1-4060-9194-eb35359c955e	d6209663-7a5c-4736-b346-cde299b554b2	2	f	2026-06-18 10:00:39.978081+00	f
404c1888-347e-4577-bb2a-83d12760fb9e	3fe745df-9187-41d7-a785-c3736a7277d7	c22e6746-73c1-4060-9194-eb35359c955e	cd984ce3-2f2c-41d5-a7ba-137060caf8ae	3	f	2026-06-18 10:11:42.231762+00	f
48f52dd9-4b34-4b79-be20-1c14a736a4d9	3fe745df-9187-41d7-a785-c3736a7277d7	c22e6746-73c1-4060-9194-eb35359c955e	ee8ecff9-d0b1-4aa8-ab21-da08a6c9229a	2	f	2026-06-18 10:11:42.231762+00	f
b1b492c4-59ea-400f-a23c-f04e19024314	fea5b705-eab8-4ba4-b0f2-739b370efd98	c22e6746-73c1-4060-9194-eb35359c955e	cd984ce3-2f2c-41d5-a7ba-137060caf8ae	3	f	2026-06-18 10:28:54.832197+00	f
2edf3ae8-fee1-4404-981d-44e62e53dba4	fea5b705-eab8-4ba4-b0f2-739b370efd98	c22e6746-73c1-4060-9194-eb35359c955e	d6209663-7a5c-4736-b346-cde299b554b2	2	f	2026-06-18 10:28:54.832197+00	f
7a0f87f4-5d10-484f-9170-1d1cf6b672f8	1114a750-be9a-44a9-8d82-001931ea4466	c22e6746-73c1-4060-9194-eb35359c955e	d6209663-7a5c-4736-b346-cde299b554b2	3	f	2026-06-18 14:30:36.720541+00	f
b9191401-84c2-42be-8394-ad3659bc6162	1114a750-be9a-44a9-8d82-001931ea4466	c22e6746-73c1-4060-9194-eb35359c955e	fcc03c57-8857-4986-98b0-0e30fb42ab2a	2	f	2026-06-18 14:30:36.720541+00	f
d1e67e69-8b29-4011-8094-5ec328d8d7b4	8050b663-c1ef-4a14-86bd-3ea225435c17	5b9456a0-db45-445f-87a0-58737bb89313	4976e7fd-9b45-4cc7-b741-fe801fcee2d0	3	f	2026-06-23 05:29:25.761883+00	f
0289ac63-698d-4a87-aac7-6b65311e9a02	8050b663-c1ef-4a14-86bd-3ea225435c17	5b9456a0-db45-445f-87a0-58737bb89313	151a98cf-99e8-4e7a-ab57-396a13db4a72	2	f	2026-06-23 05:29:25.761883+00	f
1200e2a8-75c8-4e91-9ef7-159baf293be5	fa6409a1-23bb-4d8f-a6a3-a724774868cb	5b9456a0-db45-445f-87a0-58737bb89313	4976e7fd-9b45-4cc7-b741-fe801fcee2d0	3	f	2026-06-23 11:53:17.486521+00	f
a205f308-2ff3-4f63-8d1a-a5ebe9c9fd71	fa6409a1-23bb-4d8f-a6a3-a724774868cb	5b9456a0-db45-445f-87a0-58737bb89313	20160ec3-c507-4fb3-b19d-89cb66c59a98	2	f	2026-06-23 11:53:17.486521+00	f
9783b537-9528-4b96-a68a-41c25af7e25f	c599dde6-99b1-4e0e-a4cf-2842c8f62162	5b9456a0-db45-445f-87a0-58737bb89313	fcc03c57-8857-4986-98b0-0e30fb42ab2a	3	f	2026-06-23 12:10:58.96401+00	f
6463f221-12e4-4d8e-8863-ea3075440210	c599dde6-99b1-4e0e-a4cf-2842c8f62162	5b9456a0-db45-445f-87a0-58737bb89313	4976e7fd-9b45-4cc7-b741-fe801fcee2d0	2	f	2026-06-23 12:10:58.96401+00	f
21f0fc91-5621-478b-b7cb-3bf80b2acdea	03d17e40-bb16-4728-9043-ceb05e62c9e9	5b9456a0-db45-445f-87a0-58737bb89313	cffa413c-8c76-45a6-843e-87c34e78e45a	3	f	2026-06-23 12:17:46.551885+00	f
a8dfffed-d9ed-4b84-bec4-9ecabe2032ca	03d17e40-bb16-4728-9043-ceb05e62c9e9	5b9456a0-db45-445f-87a0-58737bb89313	6527ec07-bc6b-4b53-8bff-90b6f622aece	2	f	2026-06-23 12:17:46.551885+00	f
4b3c87f8-90b8-455d-8c16-19105a511b6f	31780afe-855c-4c9d-9cf6-56e3570c00c4	5b9456a0-db45-445f-87a0-58737bb89313	151a98cf-99e8-4e7a-ab57-396a13db4a72	3	f	2026-06-23 12:38:29.058426+00	f
d0512d16-c747-4149-b868-b787f852d753	31780afe-855c-4c9d-9cf6-56e3570c00c4	5b9456a0-db45-445f-87a0-58737bb89313	a681c714-630a-487f-b167-9cefea486591	2	f	2026-06-23 12:38:29.058426+00	f
47ad14eb-a2a2-4011-b122-d5c4acfbf43f	1c570e30-214d-4723-96d3-0669c937f5a4	5b9456a0-db45-445f-87a0-58737bb89313	4976e7fd-9b45-4cc7-b741-fe801fcee2d0	3	f	2026-06-23 12:40:27.162971+00	f
362af7f2-672b-4eaf-a959-da301f1a3d71	1c570e30-214d-4723-96d3-0669c937f5a4	5b9456a0-db45-445f-87a0-58737bb89313	fcc03c57-8857-4986-98b0-0e30fb42ab2a	2	f	2026-06-23 12:40:27.162971+00	f
d581f8ff-e3f0-413b-9a4d-be337cebbcfa	71391ec7-5614-4690-8008-e2e16163570b	5b9456a0-db45-445f-87a0-58737bb89313	ddd77a2f-eb9f-4a20-8ae4-e1ca55c21893	3	f	2026-06-23 14:49:00.763321+00	f
4b207b03-0f4b-4d0a-acc8-5c3659dd6c80	71391ec7-5614-4690-8008-e2e16163570b	5b9456a0-db45-445f-87a0-58737bb89313	8682004e-e186-4705-aa29-9704b2815dc4	2	f	2026-06-23 14:49:00.763321+00	f
3e14fc9e-981c-44d2-af3d-6c86f847f7aa	36e379ae-18cb-488c-a9ef-34e99c796cfe	5b9456a0-db45-445f-87a0-58737bb89313	a681c714-630a-487f-b167-9cefea486591	3	f	2026-06-23 15:43:33.098515+00	f
6466543e-f5a4-4af9-9669-62a8223418a0	36e379ae-18cb-488c-a9ef-34e99c796cfe	5b9456a0-db45-445f-87a0-58737bb89313	20160ec3-c507-4fb3-b19d-89cb66c59a98	2	f	2026-06-23 15:43:33.098515+00	f
398f4588-9da3-43f5-8438-a5140012ea71	b94d44f2-7ae2-41f4-a105-e12b6ec3a572	5b9456a0-db45-445f-87a0-58737bb89313	8682004e-e186-4705-aa29-9704b2815dc4	3	f	2026-06-23 17:30:34.649233+00	f
326b80fe-af3a-4047-89ff-de1364d09cc4	b94d44f2-7ae2-41f4-a105-e12b6ec3a572	5b9456a0-db45-445f-87a0-58737bb89313	54ef8b7c-5afd-4a48-a3b9-d6701dd757f9	2	f	2026-06-23 17:30:34.649233+00	t
f99eba48-a829-46ee-bb62-5452046e1078	b3d06ab8-28c8-4e46-a174-1da15c08949c	5b9456a0-db45-445f-87a0-58737bb89313	54ef8b7c-5afd-4a48-a3b9-d6701dd757f9	3	f	2026-06-23 17:49:14.949745+00	f
f0228980-47f2-438a-b9af-599cfb8feff5	b3d06ab8-28c8-4e46-a174-1da15c08949c	5b9456a0-db45-445f-87a0-58737bb89313	20160ec3-c507-4fb3-b19d-89cb66c59a98	2	f	2026-06-23 17:49:14.949745+00	f
a15291f0-055c-4710-bedc-d46ba0ce3ade	e73bedf4-0330-41d0-b1e7-31cb55909eed	5b9456a0-db45-445f-87a0-58737bb89313	54ef8b7c-5afd-4a48-a3b9-d6701dd757f9	3	f	2026-06-23 17:52:13.67922+00	f
ad51dc02-a456-4f27-b454-220cc70e09b6	e73bedf4-0330-41d0-b1e7-31cb55909eed	5b9456a0-db45-445f-87a0-58737bb89313	4976e7fd-9b45-4cc7-b741-fe801fcee2d0	2	f	2026-06-23 17:52:13.67922+00	f
06c518d3-8536-4a1a-bcae-c895c911a61f	5d4ce78f-67ee-4a61-afab-c44ffc6afe91	5b9456a0-db45-445f-87a0-58737bb89313	151a98cf-99e8-4e7a-ab57-396a13db4a72	3	f	2026-06-23 18:28:47.219401+00	f
84552afe-300c-431a-b1a9-375305560ee9	5d4ce78f-67ee-4a61-afab-c44ffc6afe91	5b9456a0-db45-445f-87a0-58737bb89313	e176dd2c-4446-4811-b4cc-fc28e9c2ab25	2	f	2026-06-23 18:28:47.219401+00	f
d2beeaf2-af92-4136-b828-796fcd69acb0	3d58a7df-9922-413e-b42a-c2f162fb834c	5b9456a0-db45-445f-87a0-58737bb89313	fcc03c57-8857-4986-98b0-0e30fb42ab2a	3	f	2026-06-24 05:24:00.906269+00	f
d97b978b-254a-4a3e-82ac-06c3c6f91722	3d58a7df-9922-413e-b42a-c2f162fb834c	5b9456a0-db45-445f-87a0-58737bb89313	54ef8b7c-5afd-4a48-a3b9-d6701dd757f9	2	f	2026-06-24 05:24:00.906269+00	f
71e6fbd0-64dc-47af-95ec-6bf708c981cf	b8526be4-5eb8-4f89-b015-699537c368ce	5b9456a0-db45-445f-87a0-58737bb89313	151a98cf-99e8-4e7a-ab57-396a13db4a72	3	f	2026-06-24 08:03:29.922647+00	f
a3f9c63e-85db-445b-b1fb-8a8127a549f5	b8526be4-5eb8-4f89-b015-699537c368ce	5b9456a0-db45-445f-87a0-58737bb89313	4976e7fd-9b45-4cc7-b741-fe801fcee2d0	2	f	2026-06-24 08:03:29.922647+00	f
af11bed1-3ae5-4dca-9511-f4a02eaf98d6	fea5b705-eab8-4ba4-b0f2-739b370efd98	5b9456a0-db45-445f-87a0-58737bb89313	a681c714-630a-487f-b167-9cefea486591	3	f	2026-06-24 16:18:19.455669+00	f
a288a34d-25e3-4dca-b80c-33c7f45af302	fea5b705-eab8-4ba4-b0f2-739b370efd98	5b9456a0-db45-445f-87a0-58737bb89313	20160ec3-c507-4fb3-b19d-89cb66c59a98	2	f	2026-06-24 16:18:19.455669+00	f
8d5d476f-7e6e-4b53-a32f-a236533d3170	3fe745df-9187-41d7-a785-c3736a7277d7	5b9456a0-db45-445f-87a0-58737bb89313	8682004e-e186-4705-aa29-9704b2815dc4	3	f	2026-06-24 16:53:30.915526+00	f
009f5367-8575-4caa-a586-4a6ec0538072	3fe745df-9187-41d7-a785-c3736a7277d7	5b9456a0-db45-445f-87a0-58737bb89313	151a98cf-99e8-4e7a-ab57-396a13db4a72	2	f	2026-06-24 16:53:30.915526+00	f
3908aa5a-1bc5-4e82-b129-c1eb86410ce3	ed3a6f56-12b3-4f1a-ab83-4744531df4f1	5b9456a0-db45-445f-87a0-58737bb89313	151a98cf-99e8-4e7a-ab57-396a13db4a72	3	f	2026-06-24 17:33:07.867375+00	f
16f84c2b-a182-4041-a31d-7590e0745b7c	ed3a6f56-12b3-4f1a-ab83-4744531df4f1	5b9456a0-db45-445f-87a0-58737bb89313	4976e7fd-9b45-4cc7-b741-fe801fcee2d0	2	f	2026-06-24 17:33:07.867375+00	f
043c8449-c751-4a8a-810f-72e2ecd29045	1114a750-be9a-44a9-8d82-001931ea4466	5f39c536-340b-4981-b59a-4a9d7aff9e1e	4f0f3776-f99f-4c06-9eb4-0acd2825d8c2	2	f	2026-06-26 17:13:11.903845+00	f
924ebbea-7b19-4167-b02a-2aea69e2df3b	38120818-5997-43e2-a907-f86000cf4b53	5f39c536-340b-4981-b59a-4a9d7aff9e1e	4f0f3776-f99f-4c06-9eb4-0acd2825d8c2	2	f	2026-06-27 06:55:49.470988+00	f
c8d54e64-9033-485a-8870-093f3d736a4c	6f8a0f72-aa76-4252-9486-cc8b95570923	5f39c536-340b-4981-b59a-4a9d7aff9e1e	2044181c-c7e7-4759-8101-4779166812e3	2	f	2026-06-27 16:32:10.715232+00	t
de8fc6c4-49b9-4ad2-9b08-5728e2a4330d	1243a746-100c-460a-bf0f-2aadef7332b8	5f39c536-340b-4981-b59a-4a9d7aff9e1e	95b1e39e-97c3-4d45-9714-3f507d7c52f1	2	f	2026-06-27 20:54:30.260859+00	f
62f9f805-a897-41b6-948c-6d319f3de4b7	e73bedf4-0330-41d0-b1e7-31cb55909eed	5f39c536-340b-4981-b59a-4a9d7aff9e1e	6527ec07-bc6b-4b53-8bff-90b6f622aece	2	f	2026-06-28 07:06:56.176207+00	f
db23c536-0a75-4e98-9b91-3c5e2f6d1e0d	8050b663-c1ef-4a14-86bd-3ea225435c17	5f39c536-340b-4981-b59a-4a9d7aff9e1e	6527ec07-bc6b-4b53-8bff-90b6f622aece	2	f	2026-06-28 07:45:11.741181+00	f
4f49ecfe-d72b-475a-9fa8-3a5cf0d87343	c599dde6-99b1-4e0e-a4cf-2842c8f62162	5f39c536-340b-4981-b59a-4a9d7aff9e1e	6527ec07-bc6b-4b53-8bff-90b6f622aece	2	f	2026-06-28 08:10:57.364209+00	f
b3ace729-a7b8-438e-9ce9-d143e85f4126	5e429458-4e6f-4df7-88bd-43977c8f74b1	5f39c536-340b-4981-b59a-4a9d7aff9e1e	cffa413c-8c76-45a6-843e-87c34e78e45a	2	f	2026-06-28 08:18:24.387652+00	f
d931a92e-282e-4660-837b-98d4d6bd19d1	d8cc0ff6-c084-4134-8931-bf514fa05f23	5f39c536-340b-4981-b59a-4a9d7aff9e1e	cffa413c-8c76-45a6-843e-87c34e78e45a	2	f	2026-06-28 08:21:04.760326+00	f
5fca833f-1b18-43f1-800b-33ad3965c56c	ed3a6f56-12b3-4f1a-ab83-4744531df4f1	5f39c536-340b-4981-b59a-4a9d7aff9e1e	acfbd82a-7005-41b9-9613-606ceefc857e	2	f	2026-06-28 08:25:52.773101+00	f
81a4d73a-5c71-4afe-9bba-bdf444dd1adb	1cc4459a-e518-4a28-b323-7cbb9d07994a	5f39c536-340b-4981-b59a-4a9d7aff9e1e	cffa413c-8c76-45a6-843e-87c34e78e45a	2	f	2026-06-28 08:27:28.321723+00	f
cd44771a-f2eb-48bb-b4dc-34a7b9fe564f	ce064aab-7c13-4db9-89b3-7eb444cc158b	5f39c536-340b-4981-b59a-4a9d7aff9e1e	cffa413c-8c76-45a6-843e-87c34e78e45a	2	f	2026-06-28 08:40:21.641309+00	f
7d5ee64b-d2f8-4cbd-a675-46adc213eab1	b8526be4-5eb8-4f89-b015-699537c368ce	5f39c536-340b-4981-b59a-4a9d7aff9e1e	cffa413c-8c76-45a6-843e-87c34e78e45a	2	f	2026-06-28 09:30:09.529318+00	f
7a87d60e-ed48-456c-b5db-d5c6c17573a9	3d58a7df-9922-413e-b42a-c2f162fb834c	5f39c536-340b-4981-b59a-4a9d7aff9e1e	cffa413c-8c76-45a6-843e-87c34e78e45a	2	f	2026-06-28 10:19:58.413356+00	f
f93e73c2-48aa-48b5-bcba-8eeb44e097ea	31780afe-855c-4c9d-9cf6-56e3570c00c4	5f39c536-340b-4981-b59a-4a9d7aff9e1e	cffa413c-8c76-45a6-843e-87c34e78e45a	2	f	2026-06-28 11:32:47.804846+00	f
352dc734-6f9a-4cf0-bf2f-5f61015ede1c	5d4ce78f-67ee-4a61-afab-c44ffc6afe91	5f39c536-340b-4981-b59a-4a9d7aff9e1e	6527ec07-bc6b-4b53-8bff-90b6f622aece	2	f	2026-06-28 11:32:58.790287+00	f
17dbaad8-1db1-4052-bf0e-3498c395b2d2	6df76041-17a2-4c81-b653-82bb7124ee3f	5f39c536-340b-4981-b59a-4a9d7aff9e1e	cffa413c-8c76-45a6-843e-87c34e78e45a	2	f	2026-06-28 11:42:06.661123+00	f
aa47e00f-2e87-4503-93f8-c3df70c26fa8	3fe745df-9187-41d7-a785-c3736a7277d7	5f39c536-340b-4981-b59a-4a9d7aff9e1e	6527ec07-bc6b-4b53-8bff-90b6f622aece	2	f	2026-06-28 12:30:53.913055+00	f
9e79d347-2922-496b-a213-870f9c0ee284	fa6409a1-23bb-4d8f-a6a3-a724774868cb	5f39c536-340b-4981-b59a-4a9d7aff9e1e	6527ec07-bc6b-4b53-8bff-90b6f622aece	2	f	2026-06-28 12:50:11.948073+00	t
47f4a597-829d-46e6-ae0c-27f3f09b1f72	b94d44f2-7ae2-41f4-a105-e12b6ec3a572	5f39c536-340b-4981-b59a-4a9d7aff9e1e	e171e736-56f2-44fa-92b5-b0653ea2ce2a	2	f	2026-06-28 13:01:18.270833+00	f
3561b430-8d09-42c6-b1fc-65f0d5d451d8	1c570e30-214d-4723-96d3-0669c937f5a4	5f39c536-340b-4981-b59a-4a9d7aff9e1e	cffa413c-8c76-45a6-843e-87c34e78e45a	2	f	2026-06-28 13:11:42.310195+00	f
648f4240-cc78-49c2-a7ed-91dd751b05e7	195dcc37-e60e-4608-a0dc-c12766e96259	5f39c536-340b-4981-b59a-4a9d7aff9e1e	4f0f3776-f99f-4c06-9eb4-0acd2825d8c2	2	f	2026-06-28 13:20:46.99964+00	f
b939347d-9031-4518-935e-39b7ab8050a9	3422f6a8-d289-4ce8-8135-b547ff0f9606	5f39c536-340b-4981-b59a-4a9d7aff9e1e	6527ec07-bc6b-4b53-8bff-90b6f622aece	2	f	2026-06-28 13:31:41.802388+00	f
725879ce-81f7-4efe-bf1f-f8c8f17afbd9	71391ec7-5614-4690-8008-e2e16163570b	5f39c536-340b-4981-b59a-4a9d7aff9e1e	4f0f3776-f99f-4c06-9eb4-0acd2825d8c2	2	f	2026-06-28 15:28:50.951368+00	f
e540302c-fa3c-4ffc-bdc6-5217e6fdb103	b3d06ab8-28c8-4e46-a174-1da15c08949c	5f39c536-340b-4981-b59a-4a9d7aff9e1e	cffa413c-8c76-45a6-843e-87c34e78e45a	2	f	2026-06-28 15:44:05.395527+00	f
c434bd29-7723-4b7f-9be0-4c26d43e3ce8	36e379ae-18cb-488c-a9ef-34e99c796cfe	5f39c536-340b-4981-b59a-4a9d7aff9e1e	cffa413c-8c76-45a6-843e-87c34e78e45a	2	f	2026-06-28 17:05:44.114593+00	f
3d890314-34b7-4be9-b579-93a38d997dd5	fea5b705-eab8-4ba4-b0f2-739b370efd98	5f39c536-340b-4981-b59a-4a9d7aff9e1e	cffa413c-8c76-45a6-843e-87c34e78e45a	2	f	2026-06-28 17:54:48.90448+00	f
4caff54d-5f5a-4540-8520-6c9c98246a36	03d17e40-bb16-4728-9043-ceb05e62c9e9	5f39c536-340b-4981-b59a-4a9d7aff9e1e	acfbd82a-7005-41b9-9613-606ceefc857e	2	f	2026-06-28 17:58:33.511897+00	f
07ff1fc0-bf34-4de5-a524-edcf21d41208	3422f6a8-d289-4ce8-8135-b547ff0f9606	27ce4fc5-3de9-4cf0-bfc5-5fa0addb7081	fcc03c57-8857-4986-98b0-0e30fb42ab2a	2	f	2026-07-03 15:52:19.594728+00	f
c96fb551-02b9-486b-bc05-3c5b5636cac3	fa6409a1-23bb-4d8f-a6a3-a724774868cb	27ce4fc5-3de9-4cf0-bfc5-5fa0addb7081	fcc03c57-8857-4986-98b0-0e30fb42ab2a	2	f	2026-07-04 03:33:23.17556+00	f
4283ab13-59c0-455b-b8b1-b6fd1f20546c	1243a746-100c-460a-bf0f-2aadef7332b8	27ce4fc5-3de9-4cf0-bfc5-5fa0addb7081	f2c7a0c3-9a4c-4e3f-92a3-39abff0ce8e2	2	f	2026-07-04 04:30:46.553023+00	f
9d5cfe84-a6d5-42d8-aa8c-434bee581085	1114a750-be9a-44a9-8d82-001931ea4466	27ce4fc5-3de9-4cf0-bfc5-5fa0addb7081	6527ec07-bc6b-4b53-8bff-90b6f622aece	2	f	2026-07-04 05:17:31.629558+00	f
05a7d3db-280c-4405-b1c3-d3d828835941	c599dde6-99b1-4e0e-a4cf-2842c8f62162	27ce4fc5-3de9-4cf0-bfc5-5fa0addb7081	cba2c884-3603-4b90-976e-49389b04f562	2	f	2026-07-04 05:42:51.730411+00	f
36398198-c0c1-4bff-b357-bf851b2af6f2	ed3a6f56-12b3-4f1a-ab83-4744531df4f1	27ce4fc5-3de9-4cf0-bfc5-5fa0addb7081	e171e736-56f2-44fa-92b5-b0653ea2ce2a	2	f	2026-07-04 06:37:39.636439+00	f
41d9df49-0ff7-48de-beb8-a78d75cb3bb4	71391ec7-5614-4690-8008-e2e16163570b	27ce4fc5-3de9-4cf0-bfc5-5fa0addb7081	fcc03c57-8857-4986-98b0-0e30fb42ab2a	2	f	2026-07-04 07:19:41.735889+00	f
ab97cb8e-eb42-411c-b47d-e8feb2d1280d	03d17e40-bb16-4728-9043-ceb05e62c9e9	27ce4fc5-3de9-4cf0-bfc5-5fa0addb7081	fcc03c57-8857-4986-98b0-0e30fb42ab2a	2	f	2026-07-04 08:09:51.970623+00	f
eef13217-e927-46e3-a9d5-c68cfc149be1	e73bedf4-0330-41d0-b1e7-31cb55909eed	27ce4fc5-3de9-4cf0-bfc5-5fa0addb7081	cba2c884-3603-4b90-976e-49389b04f562	2	f	2026-07-04 08:16:55.800807+00	f
b00b6ffa-1372-49a5-b00c-9d92210d9fa3	8050b663-c1ef-4a14-86bd-3ea225435c17	27ce4fc5-3de9-4cf0-bfc5-5fa0addb7081	fcc03c57-8857-4986-98b0-0e30fb42ab2a	2	f	2026-07-04 08:40:46.236087+00	f
6cc62e54-8e76-41dd-b5fb-d23ce80aa10c	38120818-5997-43e2-a907-f86000cf4b53	27ce4fc5-3de9-4cf0-bfc5-5fa0addb7081	95b1e39e-97c3-4d45-9714-3f507d7c52f1	2	f	2026-07-04 09:15:50.00013+00	f
3688f461-dc4d-41b0-9a1d-1a0faa46bcd7	3fe745df-9187-41d7-a785-c3736a7277d7	27ce4fc5-3de9-4cf0-bfc5-5fa0addb7081	fcc03c57-8857-4986-98b0-0e30fb42ab2a	2	f	2026-07-04 09:46:24.503043+00	f
e211558f-13c7-4920-9a2e-9148e53fa674	195dcc37-e60e-4608-a0dc-c12766e96259	27ce4fc5-3de9-4cf0-bfc5-5fa0addb7081	fcc03c57-8857-4986-98b0-0e30fb42ab2a	2	f	2026-07-04 09:58:31.669402+00	f
6c86d07e-636b-46ab-adb8-8db7eaaabb6b	b94d44f2-7ae2-41f4-a105-e12b6ec3a572	27ce4fc5-3de9-4cf0-bfc5-5fa0addb7081	cba2c884-3603-4b90-976e-49389b04f562	2	f	2026-07-04 12:00:51.432677+00	f
15e49401-a3b9-4021-b993-00a02c96b5ea	5d4ce78f-67ee-4a61-afab-c44ffc6afe91	27ce4fc5-3de9-4cf0-bfc5-5fa0addb7081	fcc03c57-8857-4986-98b0-0e30fb42ab2a	2	f	2026-07-04 12:03:15.222429+00	f
33abd365-0f43-4c90-a357-163607e75f94	5d4ce78f-67ee-4a61-afab-c44ffc6afe91	aa9754bd-50eb-4785-8698-e56c6d3cb661	6ea9375b-d599-463f-96e6-c87d9209e9b2	2	f	2026-07-07 10:40:09.645007+00	f
beb70ea8-4882-4c6d-86f2-b26f14f80fc0	fa6409a1-23bb-4d8f-a6a3-a724774868cb	aa9754bd-50eb-4785-8698-e56c6d3cb661	f2c7a0c3-9a4c-4e3f-92a3-39abff0ce8e2	2	f	2026-07-07 23:29:40.548494+00	f
82b1fc2e-2e3c-4b3d-898d-da0f7d9f2e94	38120818-5997-43e2-a907-f86000cf4b53	aa9754bd-50eb-4785-8698-e56c6d3cb661	6ea9375b-d599-463f-96e6-c87d9209e9b2	2	f	2026-07-07 23:30:36.386081+00	f
0c2cf528-6c47-488e-ab9c-32b688529522	3fe745df-9187-41d7-a785-c3736a7277d7	aa9754bd-50eb-4785-8698-e56c6d3cb661	6ea9375b-d599-463f-96e6-c87d9209e9b2	2	f	2026-07-07 23:47:21.361561+00	f
ab0ba333-841c-431d-ab92-a4e2ae574132	1243a746-100c-460a-bf0f-2aadef7332b8	aa9754bd-50eb-4785-8698-e56c6d3cb661	1b2fe4cc-3105-4e0b-b1ff-06f91c466ef7	2	f	2026-07-08 03:40:25.321432+00	f
ecb7e696-3b92-4d09-8b5f-1eead1d33994	8050b663-c1ef-4a14-86bd-3ea225435c17	aa9754bd-50eb-4785-8698-e56c6d3cb661	6ea9375b-d599-463f-96e6-c87d9209e9b2	2	f	2026-07-08 05:21:26.497783+00	f
73deb83f-1cbb-47e7-b43a-16397b5bff71	03d17e40-bb16-4728-9043-ceb05e62c9e9	aa9754bd-50eb-4785-8698-e56c6d3cb661	95b1e39e-97c3-4d45-9714-3f507d7c52f1	2	f	2026-07-08 07:41:36.479108+00	f
bc075904-041a-441c-a462-7c5271d9fa89	3422f6a8-d289-4ce8-8135-b547ff0f9606	aa9754bd-50eb-4785-8698-e56c6d3cb661	1b2fe4cc-3105-4e0b-b1ff-06f91c466ef7	2	f	2026-07-08 17:49:46.921539+00	f
ef757b5c-a4df-4f93-a771-51d2bcf3b320	195dcc37-e60e-4608-a0dc-c12766e96259	aa9754bd-50eb-4785-8698-e56c6d3cb661	6ea9375b-d599-463f-96e6-c87d9209e9b2	2	f	2026-07-08 21:27:42.140586+00	f
ba0fd4a0-98f9-48b6-bfaf-7194833efba0	71391ec7-5614-4690-8008-e2e16163570b	aa9754bd-50eb-4785-8698-e56c6d3cb661	6ea9375b-d599-463f-96e6-c87d9209e9b2	2	f	2026-07-09 13:21:20.151348+00	f
c0738043-cc63-4dce-857d-3d08b85cd8e2	38120818-5997-43e2-a907-f86000cf4b53	6aa7c75c-0fc8-46f0-8219-84f969510a0e	f2c7a0c3-9a4c-4e3f-92a3-39abff0ce8e2	2	f	2026-07-12 07:14:51.995545+00	f
04e85684-03aa-4533-a880-d2180376a275	fa6409a1-23bb-4d8f-a6a3-a724774868cb	6aa7c75c-0fc8-46f0-8219-84f969510a0e	1b2fe4cc-3105-4e0b-b1ff-06f91c466ef7	2	f	2026-07-12 08:33:10.691902+00	f
6fa1e9a4-0f8e-44d6-948a-db7ec32612df	8050b663-c1ef-4a14-86bd-3ea225435c17	6aa7c75c-0fc8-46f0-8219-84f969510a0e	f2c7a0c3-9a4c-4e3f-92a3-39abff0ce8e2	2	f	2026-07-12 10:27:32.767834+00	f
8d904975-9ce6-4f31-aeff-f5f06e37e644	71391ec7-5614-4690-8008-e2e16163570b	6aa7c75c-0fc8-46f0-8219-84f969510a0e	95b1e39e-97c3-4d45-9714-3f507d7c52f1	2	f	2026-07-12 16:21:12.067441+00	f
e6d54021-80e8-481a-b73e-ce5d61eeda09	1243a746-100c-460a-bf0f-2aadef7332b8	6aa7c75c-0fc8-46f0-8219-84f969510a0e	6ea9375b-d599-463f-96e6-c87d9209e9b2	2	f	2026-07-13 05:05:31.603625+00	f
0dabc4ce-d9e1-4c0c-959d-57d79b58877f	3422f6a8-d289-4ce8-8135-b547ff0f9606	6aa7c75c-0fc8-46f0-8219-84f969510a0e	95b1e39e-97c3-4d45-9714-3f507d7c52f1	2	f	2026-07-13 13:23:43.828412+00	f
1bfbf1a9-2362-4d03-8813-34c9984a7fc0	5d4ce78f-67ee-4a61-afab-c44ffc6afe91	6aa7c75c-0fc8-46f0-8219-84f969510a0e	f2c7a0c3-9a4c-4e3f-92a3-39abff0ce8e2	2	f	2026-07-13 17:40:42.653507+00	f
8f7a757f-c61d-4b95-9c83-6ac793fcba98	3fe745df-9187-41d7-a785-c3736a7277d7	6aa7c75c-0fc8-46f0-8219-84f969510a0e	1b2fe4cc-3105-4e0b-b1ff-06f91c466ef7	2	f	2026-07-14 00:31:23.39182+00	f
13e39c16-7714-4062-ba07-f52043c35c66	03d17e40-bb16-4728-9043-ceb05e62c9e9	6aa7c75c-0fc8-46f0-8219-84f969510a0e	f2c7a0c3-9a4c-4e3f-92a3-39abff0ce8e2	2	f	2026-07-14 06:32:13.621458+00	f
12571d8d-fa1a-4443-acef-40309f5cf735	195dcc37-e60e-4608-a0dc-c12766e96259	6aa7c75c-0fc8-46f0-8219-84f969510a0e	f2c7a0c3-9a4c-4e3f-92a3-39abff0ce8e2	2	f	2026-07-14 06:39:07.766725+00	f
9e9a58f5-26cf-477a-beea-394516422d46	3422f6a8-d289-4ce8-8135-b547ff0f9606	b9bd6954-7f07-432a-af76-2dc2d3e9ab1f	6ea9375b-d599-463f-96e6-c87d9209e9b2	2	f	2026-07-18 22:09:38.932706+00	f
\.


--
-- Data for Name: players; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.players (id, name, slug, total_goals_prediction, is_active, is_eliminated, eliminated_at, created_at, has_paid, eliminated_in_round_id, display_name, is_bot) FROM stdin;
fa6409a1-23bb-4d8f-a6a3-a724774868cb	🔮Oracle	the-oracle	300	t	t	2026-07-15 21:05:07.02+00	2026-06-10 12:24:17.597968+00	f	6aa7c75c-0fc8-46f0-8219-84f969510a0e	🔮Oracle	t
3fe745df-9187-41d7-a785-c3736a7277d7	Anita Doyle	anita-20	260	t	t	2026-07-15 21:05:07.02+00	2026-06-05 05:29:28.758628+00	t	6aa7c75c-0fc8-46f0-8219-84f969510a0e	Anita	f
8050b663-c1ef-4a14-86bd-3ea225435c17	Ed John	ed-71	293	t	t	2026-07-15 21:05:07.02+00	2026-06-05 11:38:58.380834+00	t	6aa7c75c-0fc8-46f0-8219-84f969510a0e	\N	f
5d4ce78f-67ee-4a61-afab-c44ffc6afe91	Dylan Doyle	dylan-14	270	t	t	2026-07-15 21:05:07.02+00	2026-06-05 05:33:24.985308+00	t	6aa7c75c-0fc8-46f0-8219-84f969510a0e	\N	f
38120818-5997-43e2-a907-f86000cf4b53	Will Bratton	will-49	294	t	t	2026-07-15 21:05:07.02+00	2026-06-07 20:12:31.105813+00	t	6aa7c75c-0fc8-46f0-8219-84f969510a0e	\N	f
6df76041-17a2-4c81-b653-82bb7124ee3f	Kieran Walrond	kieran-9	284	t	t	2026-07-04 03:32:53.648+00	2026-06-11 12:25:09.131838+00	t	5f39c536-340b-4981-b59a-4a9d7aff9e1e	\N	f
71391ec7-5614-4690-8008-e2e16163570b	Fiona Williams	fiona-5	274	t	t	2026-07-15 21:05:07.198+00	2026-06-05 17:52:58.651819+00	t	6aa7c75c-0fc8-46f0-8219-84f969510a0e	Fiona	f
b8526be4-5eb8-4f89-b015-699537c368ce	Nick Clifford	nick-99	282	t	t	2026-07-04 03:32:53.648+00	2026-06-05 08:20:40.151129+00	t	5f39c536-340b-4981-b59a-4a9d7aff9e1e	\N	f
fea5b705-eab8-4ba4-b0f2-739b370efd98	Dylan Catterfeld	dylan-2	210	t	t	2026-07-04 03:32:53.648+00	2026-04-13 14:31:06.184396+00	t	5f39c536-340b-4981-b59a-4a9d7aff9e1e	\N	f
1c570e30-214d-4723-96d3-0669c937f5a4	Lee Langstaffe	lee-42	261	t	t	2026-07-04 03:32:53.648+00	2026-06-05 15:32:10.348234+00	t	5f39c536-340b-4981-b59a-4a9d7aff9e1e	\N	f
3d58a7df-9922-413e-b42a-c2f162fb834c	Martin Doyle	martin-22	154	t	t	2026-07-04 03:32:53.648+00	2026-06-05 05:31:30.339033+00	t	5f39c536-340b-4981-b59a-4a9d7aff9e1e	\N	f
5e429458-4e6f-4df7-88bd-43977c8f74b1	Julian Skeels	julian-60	298	t	t	2026-07-04 03:32:53.648+00	2026-06-07 18:49:30.492797+00	t	5f39c536-340b-4981-b59a-4a9d7aff9e1e	\N	f
36e379ae-18cb-488c-a9ef-34e99c796cfe	Robert Wegenek	robert-3	272	t	t	2026-07-04 03:32:53.648+00	2026-06-04 21:15:10.760163+00	t	5f39c536-340b-4981-b59a-4a9d7aff9e1e	\N	f
3422f6a8-d289-4ce8-8135-b547ff0f9606	Frank OSullivan	frank-4	252	t	t	2026-07-19 22:03:05.97+00	2026-06-04 21:42:11.586411+00	t	b9bd6954-7f07-432a-af76-2dc2d3e9ab1f	Big Frank	f
e73bedf4-0330-41d0-b1e7-31cb55909eed	Ian Taylor	taylor-22	350	t	t	2026-07-07 22:50:37.171+00	2026-06-05 15:27:51.145038+00	t	27ce4fc5-3de9-4cf0-bfc5-5fa0addb7081	Taylor	f
195dcc37-e60e-4608-a0dc-c12766e96259	Andy Taylor	andy-42	168	t	t	2026-07-15 21:05:07.02+00	2026-06-05 08:10:54.482764+00	t	6aa7c75c-0fc8-46f0-8219-84f969510a0e	\N	f
03d17e40-bb16-4728-9043-ceb05e62c9e9	Meg Catterfeld	meg-68	294	t	t	2026-07-15 21:05:07.02+00	2026-06-05 13:51:36.273884+00	f	6aa7c75c-0fc8-46f0-8219-84f969510a0e	Meg	f
d8cc0ff6-c084-4134-8931-bf514fa05f23	Andy Still	andy-11	260	t	t	2026-07-04 03:32:53.648+00	2026-06-07 13:20:08.14567+00	t	5f39c536-340b-4981-b59a-4a9d7aff9e1e	Stilly	f
31780afe-855c-4c9d-9cf6-56e3570c00c4	James Doyle	james-67	167	t	t	2026-07-04 03:32:53.648+00	2026-06-05 05:32:08.987431+00	t	5f39c536-340b-4981-b59a-4a9d7aff9e1e	\N	f
ce064aab-7c13-4db9-89b3-7eb444cc158b	James Williams	james-78	267	t	t	2026-07-04 03:32:53.648+00	2026-06-05 17:52:21.95518+00	t	5f39c536-340b-4981-b59a-4a9d7aff9e1e	\N	f
b3d06ab8-28c8-4e46-a174-1da15c08949c	Henry Catterfeld	henry-01	273	t	t	2026-07-04 03:32:53.648+00	2026-04-13 14:24:20.039577+00	f	5f39c536-340b-4981-b59a-4a9d7aff9e1e	\N	f
1cc4459a-e518-4a28-b323-7cbb9d07994a	Tom Stafford	tom-21	278	t	t	2026-07-04 03:32:53.648+00	2026-06-05 05:27:48.846651+00	t	5f39c536-340b-4981-b59a-4a9d7aff9e1e	\N	f
6f8a0f72-aa76-4252-9486-cc8b95570923	John C the Bot	john-78	294	t	t	2026-07-04 03:32:53.648+00	2026-06-10 18:16:21.473616+00	t	5f39c536-340b-4981-b59a-4a9d7aff9e1e	JC the Bot	f
c599dde6-99b1-4e0e-a4cf-2842c8f62162	Paul Blessing	paul-30	312	t	t	2026-07-07 22:50:37.171+00	2026-06-08 09:52:46.039121+00	t	27ce4fc5-3de9-4cf0-bfc5-5fa0addb7081	\N	f
b94d44f2-7ae2-41f4-a105-e12b6ec3a572	Paul Catterfeld	paul-01	290	t	t	2026-07-07 22:50:37.171+00	2026-04-06 08:16:08.077112+00	t	27ce4fc5-3de9-4cf0-bfc5-5fa0addb7081	\N	f
1114a750-be9a-44a9-8d82-001931ea4466	Robbie White	robbie-10	385	t	t	2026-07-07 22:50:37.171+00	2026-06-05 08:21:49.720975+00	t	27ce4fc5-3de9-4cf0-bfc5-5fa0addb7081	\N	f
ed3a6f56-12b3-4f1a-ab83-4744531df4f1	James Taylor	james-34	305	t	t	2026-07-07 22:50:37.171+00	2026-06-05 15:29:03.391151+00	t	27ce4fc5-3de9-4cf0-bfc5-5fa0addb7081	\N	f
1243a746-100c-460a-bf0f-2aadef7332b8	Tim Bratton	tim-83	215	t	t	2026-07-14 21:00:05.88+00	2026-06-07 20:12:02.853591+00	t	6aa7c75c-0fc8-46f0-8219-84f969510a0e	Timbo	f
\.


--
-- Data for Name: push_subscriptions; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.push_subscriptions (id, player_id, subscription, created_at) FROM stdin;
\.


--
-- Data for Name: rounds; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.rounds (id, name, round_type, phase_number, deadline, is_complete, sort_order, created_at) FROM stdin;
32854b42-0d3a-4e2e-9555-00cd1e6c83c6	Group Phase 1	group	1	2026-06-11 18:00:00+00	t	1	2026-04-06 07:37:08.161165+00
318f2b2d-d52a-4102-bd8d-7ab594a40f42	Group Phase 0	group	\N	2026-06-01 00:00:00+00	t	0	2026-04-30 17:22:15.854953+00
c22e6746-73c1-4060-9194-eb35359c955e	Group Phase 2	group	2	2026-06-18 15:00:00+00	t	2	2026-04-06 07:37:08.161165+00
5b9456a0-db45-445f-87a0-58737bb89313	Group Phase 3	group	3	2026-06-24 18:00:00+00	t	3	2026-04-06 07:37:08.161165+00
5f39c536-340b-4981-b59a-4a9d7aff9e1e	Round of 32	knockout	\N	2026-06-28 18:00:00+00	t	4	2026-04-06 07:37:08.161165+00
27ce4fc5-3de9-4cf0-bfc5-5fa0addb7081	Round of 16	knockout	\N	2026-07-04 16:00:00+00	t	5	2026-04-06 07:37:08.161165+00
aa9754bd-50eb-4785-8698-e56c6d3cb661	Quarter Finals	knockout	\N	2026-07-09 19:00:00+00	t	6	2026-04-06 07:37:08.161165+00
6aa7c75c-0fc8-46f0-8219-84f969510a0e	Semi Finals	knockout	\N	2026-07-14 18:00:00+00	t	7	2026-04-06 07:37:08.161165+00
b9bd6954-7f07-432a-af76-2dc2d3e9ab1f	Final	knockout	\N	2026-07-19 18:00:00+00	t	8	2026-04-06 07:37:08.161165+00
2fd614f4-1aa7-43d5-beeb-be06f5530a85	3rd Place	knockout	\N	2026-07-18 20:00:00+00	f	9	2026-04-14 18:08:32.851272+00
\.


--
-- Data for Name: team_odds; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.team_odds (id, team_id, odds_decimal, odds_fractional, fetched_at) FROM stdin;
901ecaa4-e208-44b4-8329-9192d6331ab5	6ea9375b-d599-463f-96e6-c87d9209e9b2	6	5/1	2026-04-10 09:36:20.58+00
0998ef1b-ca7b-4ff1-93b8-61ba81e4537a	f2c7a0c3-9a4c-4e3f-92a3-39abff0ce8e2	7.2	31/5	2026-04-10 09:36:20.58+00
a14f3756-7a3c-4cee-a665-db4260b151af	1b2fe4cc-3105-4e0b-b1ff-06f91c466ef7	8.6	38/5	2026-04-10 09:36:20.58+00
d8c1640f-0b97-423e-a5a9-e817489347a5	cba2c884-3603-4b90-976e-49389b04f562	10	9/1	2026-04-10 09:36:20.58+00
bf75310e-36a9-47ff-98fe-8967ff2f3c9b	95b1e39e-97c3-4d45-9714-3f507d7c52f1	10.5	19/2	2026-04-10 09:36:20.58+00
aadc81a9-9efd-46a4-905e-3c6a98733015	eaca3063-d90c-4007-b3d8-ba829b3ee14e	13.5	25/2	2026-04-10 09:36:20.58+00
be228867-4eca-41df-8327-d291c33bc47c	cffa413c-8c76-45a6-843e-87c34e78e45a	18	17/1	2026-04-10 09:36:20.58+00
cabe9949-2b38-4c07-8755-3d058fc3d05c	2044181c-c7e7-4759-8101-4779166812e3	28	27/1	2026-04-10 09:36:20.58+00
3e006338-da66-4674-a313-0b8108491af6	20e98c7a-4548-44f8-964d-7aba42ae7624	36	35/1	2026-04-10 09:36:20.58+00
564e6e57-598f-4694-83bd-1781aac6e9eb	e171e736-56f2-44fa-92b5-b0653ea2ce2a	46	45/1	2026-04-10 09:36:20.58+00
f4a85c37-34bc-4396-ab10-06300fbcfc13	8682004e-e186-4705-aa29-9704b2815dc4	48	47/1	2026-04-10 09:36:20.58+00
3aa9a05b-1bfe-4e5a-9803-891b5e0bd103	66a8014f-0009-400e-928c-6b28cb8dab1f	50	49/1	2026-04-10 09:36:20.58+00
05838f66-f4f8-4d10-bd26-8f99eaa3f498	fcc03c57-8857-4986-98b0-0e30fb42ab2a	60	59/1	2026-04-10 09:36:20.58+00
2d501a76-2f1e-4670-9095-283ea4fc015f	ee8ecff9-d0b1-4aa8-ab21-da08a6c9229a	85	84/1	2026-04-10 09:36:20.58+00
c5d9abbe-1bbb-4292-95cc-b0b66d6f6cd2	e176dd2c-4446-4811-b4cc-fc28e9c2ab25	90	89/1	2026-04-10 09:36:20.58+00
467e69a0-959a-4312-808d-719ae1837703	8cccecd8-b1ab-4159-bf35-29ef0db369c4	110	109/1	2026-04-10 09:36:20.58+00
db523b34-5b81-413d-800b-44fe7fd2dca7	cd984ce3-2f2c-41d5-a7ba-137060caf8ae	110	109/1	2026-04-10 09:36:20.58+00
43165a5f-33e9-414c-913e-dfd3b1559946	acfbd82a-7005-41b9-9613-606ceefc857e	110	109/1	2026-04-10 09:36:20.58+00
1bc96fd9-afcf-4b24-848b-af09bcd3e806	151a98cf-99e8-4e7a-ab57-396a13db4a72	110	109/1	2026-04-10 09:36:20.58+00
3dd22497-57f5-4ed7-8592-be8eae6a3b96	910a4a31-591d-4c32-8b57-b0d0bbde5a26	120	119/1	2026-04-10 09:36:20.58+00
42c62fee-6443-4676-ad8e-56da2293209d	87881cf2-7a14-4afa-9912-0ef5b2672387	130	129/1	2026-04-10 09:36:20.58+00
9466ec4d-e74d-4b02-91dc-2065755fa836	52eaa3b4-081b-4393-b291-d69c644c612e	180	179/1	2026-04-10 09:36:20.58+00
c6dbb8c8-c194-409b-91e4-70d44b19eeff	52f066d8-0a7a-42c5-8a6b-103ec4ba2c91	250	249/1	2026-04-10 09:36:20.58+00
cdac6f6d-1da4-4793-b159-54ccfc6ee227	c8e5c035-af92-4497-b96c-82f2c0a15214	290	289/1	2026-04-10 09:36:20.58+00
e5ef65c3-8223-4fa5-ba92-ee9f0b2906cf	4f0f3776-f99f-4c06-9eb4-0acd2825d8c2	310	309/1	2026-04-10 09:36:20.58+00
7dad6a6e-73bb-42f4-83a7-48b7fb41dfe4	54ef8b7c-5afd-4a48-a3b9-d6701dd757f9	360	359/1	2026-04-10 09:36:20.58+00
3536522f-d9d1-422c-9cc7-1cf0b75dd829	20160ec3-c507-4fb3-b19d-89cb66c59a98	390	389/1	2026-04-10 09:36:20.58+00
f394b0aa-5ba2-4330-b3f3-d8d7a59f0ed1	ddd77a2f-eb9f-4a20-8ae4-e1ca55c21893	400	399/1	2026-04-10 09:36:20.58+00
8f2daecc-37f9-4993-8290-cf39781c9c43	61d8b501-96d1-4043-a2b7-de27e9b137d7	510	509/1	2026-04-10 09:36:20.58+00
582b424a-b838-4e01-b849-b8b8481804d5	b6afbe52-5067-4263-a750-6101f6efedc0	520	519/1	2026-04-10 09:36:20.58+00
a62b0ea2-9d7e-483e-aa40-f04ee0de9df1	f99d6725-238c-4d95-8502-9d25b4a6e89e	590	589/1	2026-04-10 09:36:20.58+00
73e1f1ef-faff-4358-842a-743ad7d75fef	a1cbc3f2-826a-4c04-803b-b5c2930d3c42	770	769/1	2026-04-10 09:36:20.58+00
53dd3373-3262-49cf-8027-c47fdb30ed82	f959649f-d7be-48e3-9129-58e7fc519606	1000	999/1	2026-04-10 09:36:20.58+00
eccecbb6-7585-480b-8803-5ce459c88279	aa0baf4e-af82-4020-9093-715971d63105	1000	999/1	2026-04-10 09:36:20.58+00
f31c038e-a759-4361-b7a2-a57738b5c8a4	ef919163-49fb-4cc5-ab4e-f55d9419d806	1000	999/1	2026-04-10 09:36:20.58+00
319c8108-2385-435d-8a83-d373000ca054	a760ffb3-5775-4d7d-b803-cf0087525d91	1000	999/1	2026-04-10 09:36:20.58+00
1e8f7640-eac8-432a-8c04-390da6305b45	600575e1-d737-452a-abec-c6e22da92787	1000	999/1	2026-04-10 09:36:20.58+00
cd799a6f-b2d0-40fe-adf8-da3f989a7f5a	622bb3ef-bc6e-4c9a-9efe-aae4d0f95822	1000	999/1	2026-04-10 09:36:20.58+00
61fa4ed2-9306-446e-a338-6c7d9df1adaa	1270b02b-ff92-4068-a52e-ae90bcae805b	1000	999/1	2026-04-10 09:36:20.58+00
97147321-8e04-4ca8-bdbb-bdee36f75778	9507020f-6157-4043-ae5b-72ca12dea41e	1000	999/1	2026-04-10 09:36:20.58+00
e7369de8-9dcb-49f6-936b-8df66c41d180	666ba168-4d8b-4060-8e4b-e1dd7b2a7503	1000	999/1	2026-04-10 09:36:20.58+00
c4e52c95-3957-4219-b301-1fcdda8c8bff	a681c714-630a-487f-b167-9cefea486591	1000	999/1	2026-04-10 09:36:20.58+00
45cb7136-9a76-446c-9cc5-6afc74b4eed8	7f560d60-00fc-46e1-b81b-4e7234b7cb04	1000	999/1	2026-04-10 09:36:20.58+00
de075109-4047-4f1e-bc67-ab0f6ff08880	f27875c8-4818-4323-8d45-333b7f82cf57	1000	999/1	2026-04-10 09:36:20.58+00
762a1a26-2c92-4e29-a44c-0c1b729ae07d	8d109cbf-133f-496a-b5b7-3f75a0ec1dcd	1000	999/1	2026-04-10 09:36:20.58+00
40672b0b-06b8-4884-8b54-714843f87746	1b2fe4cc-3105-4e0b-b1ff-06f91c466ef7	8.4	37/5	2026-04-10 09:59:13.764+00
de3802d5-c08a-470a-a9a9-00026a6b6874	d6209663-7a5c-4736-b346-cde299b554b2	370	369/1	2026-04-10 10:24:05.118+00
b5a1ecd0-7272-4e67-940f-8d18d174b56e	4976e7fd-9b45-4cc7-b741-fe801fcee2d0	390	389/1	2026-04-10 10:24:05.118+00
ba7aa1d5-02de-4263-8cd7-c81fdc048290	6527ec07-bc6b-4b53-8bff-90b6f622aece	80	79/1	2026-04-10 10:37:04.196+00
4f3089ad-e852-4366-80ed-dfa4104ad758	2044181c-c7e7-4759-8101-4779166812e3	29	28/1	2026-04-10 13:22:25.562+00
bb803c8b-aebb-4487-9995-8bf9b52ce47d	f2c7a0c3-9a4c-4e3f-92a3-39abff0ce8e2	7	6/1	2026-04-14 03:43:23.059+00
96840f15-b2db-4d6f-bc54-1aa7b8bef459	1b2fe4cc-3105-4e0b-b1ff-06f91c466ef7	8.6	38/5	2026-04-14 03:43:23.059+00
31d046c7-19a5-420d-b37a-595405a592ad	95b1e39e-97c3-4d45-9714-3f507d7c52f1	11	10/1	2026-04-14 03:43:23.059+00
fa8b4aaa-84b1-4663-bb1c-127bdbec6ae5	2044181c-c7e7-4759-8101-4779166812e3	27	26/1	2026-04-14 03:43:23.059+00
59512026-208e-486d-bd6f-a8949c20d6d2	20e98c7a-4548-44f8-964d-7aba42ae7624	40	39/1	2026-04-14 03:43:23.059+00
192587fa-1e52-4b5a-a829-a2e5050bc747	e171e736-56f2-44fa-92b5-b0653ea2ce2a	48	47/1	2026-04-14 03:43:23.059+00
e3db7283-d8fd-4d02-95a6-4942d30dc128	8682004e-e186-4705-aa29-9704b2815dc4	50	49/1	2026-04-14 03:43:23.059+00
b6532689-741d-4e84-97c2-90d0201acd26	66a8014f-0009-400e-928c-6b28cb8dab1f	55	54/1	2026-04-14 03:43:23.059+00
42fdf3fe-66c7-4058-8c03-a9b6db0b71ed	fcc03c57-8857-4986-98b0-0e30fb42ab2a	65	64/1	2026-04-14 03:43:23.059+00
b504e430-ab87-4837-a383-7f442e638415	ee8ecff9-d0b1-4aa8-ab21-da08a6c9229a	80	79/1	2026-04-14 03:43:23.059+00
c8ca0b75-674a-4bd4-9838-bee832653daf	54ef8b7c-5afd-4a48-a3b9-d6701dd757f9	100	99/1	2026-04-14 03:43:23.059+00
d00aa11c-52be-4a43-90c5-6a7bbf520d1d	52eaa3b4-081b-4393-b291-d69c644c612e	170	169/1	2026-04-14 03:43:23.059+00
ee4adbe1-228a-440a-845f-72d47f0cc73f	52f066d8-0a7a-42c5-8a6b-103ec4ba2c91	240	239/1	2026-04-14 03:43:23.059+00
e3bbb264-c2a6-422e-beee-891d9bcc7180	c8e5c035-af92-4497-b96c-82f2c0a15214	280	279/1	2026-04-14 03:43:23.059+00
c21a78d6-4d39-46ab-bb9d-4aaa16991c93	ddd77a2f-eb9f-4a20-8ae4-e1ca55c21893	380	379/1	2026-04-14 03:43:23.059+00
383126a4-a919-41f6-9162-dbb6ae6b44be	20160ec3-c507-4fb3-b19d-89cb66c59a98	410	409/1	2026-04-14 03:43:23.059+00
9e2f84a6-79bd-4fb4-9062-5696511adc32	4976e7fd-9b45-4cc7-b741-fe801fcee2d0	410	409/1	2026-04-14 03:43:23.059+00
1e54ffad-a4f2-41c8-8275-1bae5c111d64	b6afbe52-5067-4263-a750-6101f6efedc0	430	429/1	2026-04-14 03:43:23.059+00
7462930f-adc1-407c-b2ed-b6c0a542e20d	f99d6725-238c-4d95-8502-9d25b4a6e89e	560	559/1	2026-04-14 03:43:23.059+00
080aa908-a1cb-45ea-a42d-4eba9909cafe	a1cbc3f2-826a-4c04-803b-b5c2930d3c42	640	639/1	2026-04-14 03:43:23.059+00
b0c039c8-3ade-46ee-a6b8-d09ea394402d	f2c7a0c3-9a4c-4e3f-92a3-39abff0ce8e2	6.4	27/5	2026-04-21 12:08:49.475+00
abc1b39b-22da-45e7-8c41-853ab32f75f3	1b2fe4cc-3105-4e0b-b1ff-06f91c466ef7	8.8	39/5	2026-04-21 12:08:49.475+00
8c476873-ca91-4a37-98df-8e7b8115c989	cba2c884-3603-4b90-976e-49389b04f562	10.5	19/2	2026-04-21 12:08:49.475+00
91b55a24-7f5f-4317-b334-959bab656553	2044181c-c7e7-4759-8101-4779166812e3	29	28/1	2026-04-21 12:08:49.475+00
577c2aed-168f-478b-96fa-0b05fd772455	20e98c7a-4548-44f8-964d-7aba42ae7624	38	37/1	2026-04-21 12:08:49.475+00
c486095b-7310-4d48-bff1-888eeee17fa0	e171e736-56f2-44fa-92b5-b0653ea2ce2a	50	49/1	2026-04-21 12:08:49.475+00
563f127b-9b94-4447-87de-17e1044515d0	66a8014f-0009-400e-928c-6b28cb8dab1f	50	49/1	2026-04-21 12:08:49.475+00
c55583b3-b8c6-4904-a527-b32110cda33a	fcc03c57-8857-4986-98b0-0e30fb42ab2a	55	54/1	2026-04-21 12:08:49.475+00
24cc9c2e-a3ca-440a-9d32-4aa857ebf310	ee8ecff9-d0b1-4aa8-ab21-da08a6c9229a	85	84/1	2026-04-21 12:08:49.475+00
c15085ed-72b4-4ac5-b6e9-286c0a066e5f	acfbd82a-7005-41b9-9613-606ceefc857e	100	99/1	2026-04-21 12:08:49.475+00
2c0fde9f-bd98-4375-8330-5e11b8d17c4b	151a98cf-99e8-4e7a-ab57-396a13db4a72	100	99/1	2026-04-21 12:08:49.475+00
5ca89afd-ee00-4387-a792-17f7f0ea8eba	87881cf2-7a14-4afa-9912-0ef5b2672387	140	139/1	2026-04-21 12:08:49.475+00
eb9d84ef-8dc9-44e8-8338-a9aa5ebc46f4	52eaa3b4-081b-4393-b291-d69c644c612e	190	189/1	2026-04-21 12:08:49.475+00
8029b132-1c29-4749-9c91-ff25439ba77a	4f0f3776-f99f-4c06-9eb4-0acd2825d8c2	240	239/1	2026-04-21 12:08:49.475+00
7d2781e1-3a5c-4c79-9f8e-316b79edd71c	52f066d8-0a7a-42c5-8a6b-103ec4ba2c91	250	249/1	2026-04-21 12:08:49.475+00
de97bc38-15fd-4b6e-ae70-e24e4292333c	c8e5c035-af92-4497-b96c-82f2c0a15214	290	289/1	2026-04-21 12:08:49.475+00
021c654d-58b6-4d19-a1eb-9d0d6e2598c7	54ef8b7c-5afd-4a48-a3b9-d6701dd757f9	320	319/1	2026-04-21 12:08:49.475+00
fa4c2f57-3500-44d3-a01d-5bf375a3c053	ddd77a2f-eb9f-4a20-8ae4-e1ca55c21893	400	399/1	2026-04-21 12:08:49.475+00
0ce1026b-f342-4e2b-a766-35a2045500ff	d6209663-7a5c-4736-b346-cde299b554b2	400	399/1	2026-04-21 12:08:49.475+00
a64447fb-ed3c-4fc6-ac90-4fb01eb1cdde	4976e7fd-9b45-4cc7-b741-fe801fcee2d0	480	479/1	2026-04-21 12:08:49.475+00
331ed2b8-7413-4476-b3c2-a13095aac569	61d8b501-96d1-4043-a2b7-de27e9b137d7	550	549/1	2026-04-21 12:08:49.475+00
cdaa2888-7916-4ccf-8323-edbb70c4c23f	f99d6725-238c-4d95-8502-9d25b4a6e89e	600	599/1	2026-04-21 12:08:49.475+00
5061108a-d13f-472a-ba08-f71d833d6b18	b6afbe52-5067-4263-a750-6101f6efedc0	630	629/1	2026-04-21 12:08:49.475+00
f2a9f2bc-2106-42bc-911c-1cabdc02439a	f959649f-d7be-48e3-9129-58e7fc519606	710	709/1	2026-04-21 12:08:49.475+00
0221a4a0-1760-4741-9a7c-c5331a4580b8	a1cbc3f2-826a-4c04-803b-b5c2930d3c42	840	839/1	2026-04-21 12:08:49.475+00
a102a00c-715b-4b94-8937-1ba2a5670917	f2c7a0c3-9a4c-4e3f-92a3-39abff0ce8e2	6.2	26/5	2026-04-24 21:33:21.013+00
3813833b-6bf4-4471-9ef6-1ef46957f176	6ea9375b-d599-463f-96e6-c87d9209e9b2	6.6	28/5	2026-04-24 21:33:21.013+00
43976d0f-aa4a-4160-931d-a4a1e24b12ba	cba2c884-3603-4b90-976e-49389b04f562	10	9/1	2026-04-24 21:33:21.013+00
2a409455-5633-411e-8e78-791b9753a5b1	eaca3063-d90c-4007-b3d8-ba829b3ee14e	13	12/1	2026-04-24 21:33:21.013+00
97aaa01e-fc1f-495d-a296-bfe09b4d4bd7	cffa413c-8c76-45a6-843e-87c34e78e45a	18.5	35/2	2026-04-24 21:33:21.013+00
e4edde18-53a2-4adf-87d4-a5c61c2da838	2044181c-c7e7-4759-8101-4779166812e3	28	27/1	2026-04-24 21:33:21.013+00
893f395b-76bf-4661-9f11-ab2db05e6bce	6527ec07-bc6b-4b53-8bff-90b6f622aece	75	74/1	2026-04-24 21:33:21.013+00
436f7dc3-30a1-49b6-915a-6605da72a9a4	910a4a31-591d-4c32-8b57-b0d0bbde5a26	130	129/1	2026-04-24 21:33:21.013+00
b716b359-3f4f-437e-84b2-0ccc022d5028	52eaa3b4-081b-4393-b291-d69c644c612e	200	199/1	2026-04-24 21:33:21.013+00
437ad91c-6f60-41bc-893c-5c5aaf6c1a01	52f066d8-0a7a-42c5-8a6b-103ec4ba2c91	240	239/1	2026-04-24 21:33:21.013+00
bc2e1aa7-10c9-4cc0-bfe1-e32c466b04d2	4f0f3776-f99f-4c06-9eb4-0acd2825d8c2	260	259/1	2026-04-24 21:33:21.013+00
88ca2aec-3d16-4859-b3f9-2e33d802947c	c8e5c035-af92-4497-b96c-82f2c0a15214	300	299/1	2026-04-24 21:33:21.013+00
c5051037-018e-4e19-b01b-81925318de5b	54ef8b7c-5afd-4a48-a3b9-d6701dd757f9	330	329/1	2026-04-24 21:33:21.013+00
c766b476-4c2e-4351-a249-994c719af8bf	d6209663-7a5c-4736-b346-cde299b554b2	380	379/1	2026-04-24 21:33:21.013+00
7c42aed3-0c31-42e9-9f94-acb38e65806d	20160ec3-c507-4fb3-b19d-89cb66c59a98	430	429/1	2026-04-24 21:33:21.013+00
68e6bfd3-dbdf-44c3-a51f-24aa79304469	4976e7fd-9b45-4cc7-b741-fe801fcee2d0	490	489/1	2026-04-24 21:33:21.013+00
c5d42364-7262-4c36-bdb4-81956a62e9d0	61d8b501-96d1-4043-a2b7-de27e9b137d7	560	559/1	2026-04-24 21:33:21.013+00
b8755376-7b96-4d26-b818-0b747e2fa782	f99d6725-238c-4d95-8502-9d25b4a6e89e	610	609/1	2026-04-24 21:33:21.013+00
7352ad62-e0b6-4312-9ff6-743b8dcda6e3	b6afbe52-5067-4263-a750-6101f6efedc0	650	649/1	2026-04-24 21:33:21.013+00
085d6d0c-5f29-4d93-a6ce-e33f114c9dba	a1cbc3f2-826a-4c04-803b-b5c2930d3c42	880	879/1	2026-04-24 21:33:21.013+00
7fc7bd05-1ab6-4e46-ac31-26ed3b2f851e	f959649f-d7be-48e3-9129-58e7fc519606	920	919/1	2026-04-24 21:33:21.013+00
eefe2ecb-bb98-4126-b4cb-df7ce976dcd5	6ea9375b-d599-463f-96e6-c87d9209e9b2	5.5	9/2	2026-05-22 13:11:30.343+00
4db6e928-7d34-4de3-8a51-afcf1b71d82b	f2c7a0c3-9a4c-4e3f-92a3-39abff0ce8e2	5.5	9/2	2026-05-22 13:11:30.343+00
81e3c6fb-fbfc-47c5-9f82-da14f9fa4eb0	1b2fe4cc-3105-4e0b-b1ff-06f91c466ef7	7	6/1	2026-05-22 13:11:30.343+00
158c7fbe-c47d-49e5-b0d0-41286a253769	cba2c884-3603-4b90-976e-49389b04f562	9	8/1	2026-05-22 13:11:30.343+00
351802b8-8662-43f8-90e1-462735a050cc	95b1e39e-97c3-4d45-9714-3f507d7c52f1	10	9/1	2026-05-22 13:11:30.343+00
f94aa337-169b-4255-8a6b-7bb3c829ea6f	eaca3063-d90c-4007-b3d8-ba829b3ee14e	12	11/1	2026-05-22 13:11:30.343+00
883b0ec2-378d-4b15-acec-b0820e1df411	cffa413c-8c76-45a6-843e-87c34e78e45a	15	14/1	2026-05-22 13:11:30.343+00
2a547575-2e6f-4f36-96a2-d848324aea5b	2044181c-c7e7-4759-8101-4779166812e3	21	20/1	2026-05-22 13:11:30.343+00
db3b62dc-6fa3-4dcd-a5a5-776bce9b2656	20e98c7a-4548-44f8-964d-7aba42ae7624	29	28/1	2026-05-22 13:11:30.343+00
9ae0b4d4-10ac-406b-9098-7ae49bb9b25c	8682004e-e186-4705-aa29-9704b2815dc4	34	33/1	2026-05-22 13:11:30.343+00
5783e717-1122-4809-aaea-144efe5d28a2	e171e736-56f2-44fa-92b5-b0653ea2ce2a	34	33/1	2026-05-22 13:11:30.343+00
c71a0977-d4d1-441c-83ac-90a6fb5dd673	6527ec07-bc6b-4b53-8bff-90b6f622aece	51	50/1	2026-05-22 13:11:30.343+00
5261899b-f55d-4c4b-80a2-eb74257053e0	66a8014f-0009-400e-928c-6b28cb8dab1f	51	50/1	2026-05-22 13:11:30.343+00
8b34a4ca-9616-4471-bfbb-f7b7cef564b8	acfbd82a-7005-41b9-9613-606ceefc857e	51	50/1	2026-05-22 13:11:30.343+00
3ec7d3be-1960-43bc-a152-b6169d02a974	ee8ecff9-d0b1-4aa8-ab21-da08a6c9229a	67	66/1	2026-05-22 13:11:30.343+00
cdc0e11f-2ee3-44f6-8d6f-d5315d03a983	fcc03c57-8857-4986-98b0-0e30fb42ab2a	67	66/1	2026-05-22 13:11:30.343+00
11ff087e-e4ce-49ea-b1dc-be935907ed02	e176dd2c-4446-4811-b4cc-fc28e9c2ab25	67	66/1	2026-05-22 13:11:30.343+00
54dac4be-2fc7-4c3f-8a26-d92905478d84	910a4a31-591d-4c32-8b57-b0d0bbde5a26	67	66/1	2026-05-22 13:11:30.343+00
0d2b41dd-de85-474e-b730-a0d1d1e81021	8cccecd8-b1ab-4159-bf35-29ef0db369c4	81	80/1	2026-05-22 13:11:30.343+00
fa4aa045-460a-443e-b377-84fd4d9fc4ee	54ef8b7c-5afd-4a48-a3b9-d6701dd757f9	81	80/1	2026-05-22 13:11:30.343+00
493806f8-19b0-4a73-8843-268b713273d0	87881cf2-7a14-4afa-9912-0ef5b2672387	81	80/1	2026-05-22 13:11:30.343+00
392264fb-2630-4d97-99be-041c39e8244e	cd984ce3-2f2c-41d5-a7ba-137060caf8ae	101	100/1	2026-05-22 13:11:30.343+00
0cb02390-fb41-40ba-b159-7725dc60972e	151a98cf-99e8-4e7a-ab57-396a13db4a72	101	100/1	2026-05-22 13:11:30.343+00
16e69b9a-37bc-42fd-a25d-4cddc8b87d37	52eaa3b4-081b-4393-b291-d69c644c612e	101	100/1	2026-05-22 13:11:30.343+00
88658126-174a-4ce1-9d13-be6c02a2754c	4f0f3776-f99f-4c06-9eb4-0acd2825d8c2	151	150/1	2026-05-22 13:11:30.343+00
9b46ff14-bb39-4337-921c-12755ecf357c	c8e5c035-af92-4497-b96c-82f2c0a15214	151	150/1	2026-05-22 13:11:30.343+00
fc43e845-4254-49e5-b61f-36a22fe3711b	52f066d8-0a7a-42c5-8a6b-103ec4ba2c91	151	150/1	2026-05-22 13:11:30.343+00
c1bf8244-60f6-4fad-9f0e-a4448cb3dadc	d6209663-7a5c-4736-b346-cde299b554b2	201	200/1	2026-05-22 13:11:30.343+00
1d51f8c2-d90e-4521-9896-adf38c6666d8	4976e7fd-9b45-4cc7-b741-fe801fcee2d0	201	200/1	2026-05-22 13:11:30.343+00
150d0f22-087a-4ecf-b521-89b0185283f6	61d8b501-96d1-4043-a2b7-de27e9b137d7	251	250/1	2026-05-22 13:11:30.343+00
4cac9b06-9e87-4618-8f3e-cc8102fd76a5	ddd77a2f-eb9f-4a20-8ae4-e1ca55c21893	301	300/1	2026-05-22 13:11:30.343+00
cfe5eafd-1df3-4c01-9ca5-f5bb5869e443	20160ec3-c507-4fb3-b19d-89cb66c59a98	301	300/1	2026-05-22 13:11:30.343+00
5584e59e-37be-4cb7-a6c8-261293a28a13	b6afbe52-5067-4263-a750-6101f6efedc0	301	300/1	2026-05-22 13:11:30.343+00
9e497ac8-3d4d-4f99-87b4-395d5ea2f513	9507020f-6157-4043-ae5b-72ca12dea41e	501	500/1	2026-05-22 13:11:30.343+00
3246b5a9-a756-4774-b2fe-ba58ba79fd45	f99d6725-238c-4d95-8502-9d25b4a6e89e	501	500/1	2026-05-22 13:11:30.343+00
28165f56-7b90-4fd3-890b-20e78326b18c	a1cbc3f2-826a-4c04-803b-b5c2930d3c42	501	500/1	2026-05-22 13:11:30.343+00
48bfeb02-60c1-4d1f-bb04-f12e1cd8f3ce	f959649f-d7be-48e3-9129-58e7fc519606	501	500/1	2026-05-22 13:11:30.343+00
3ad323a1-e2d3-43a7-bafb-064aabb8c9d8	a681c714-630a-487f-b167-9cefea486591	751	750/1	2026-05-22 13:11:30.343+00
202d644e-66ab-4bbe-8b72-a9bc18df4bce	600575e1-d737-452a-abec-c6e22da92787	1001	1000/1	2026-05-22 13:11:30.343+00
3b9c081b-a1d4-4588-a487-d3d2e45281c7	a760ffb3-5775-4d7d-b803-cf0087525d91	1001	1000/1	2026-05-22 13:11:30.343+00
03576910-9214-48ef-889b-8986d3a363ab	622bb3ef-bc6e-4c9a-9efe-aae4d0f95822	1001	1000/1	2026-05-22 13:11:30.343+00
4673f785-559c-4558-9a50-c98eaefdb72e	f27875c8-4818-4323-8d45-333b7f82cf57	1001	1000/1	2026-05-22 13:11:30.343+00
75625b07-96e4-4046-8335-e24803f16190	1270b02b-ff92-4068-a52e-ae90bcae805b	1001	1000/1	2026-05-22 13:11:30.343+00
7ebee295-1d5a-4dcf-ac24-c7aad0e947c4	8d109cbf-133f-496a-b5b7-3f75a0ec1dcd	1001	1000/1	2026-05-22 13:11:30.343+00
23d5859f-ebfa-4c33-ac44-a101aece81fe	ef919163-49fb-4cc5-ab4e-f55d9419d806	1501	1500/1	2026-05-22 13:11:30.343+00
800a04a4-7aee-4a92-b9ed-23253a55448d	7f560d60-00fc-46e1-b81b-4e7234b7cb04	2001	2000/1	2026-05-22 13:11:30.343+00
8fa5970f-bbef-424e-90c4-6bf4a8f271c4	666ba168-4d8b-4060-8e4b-e1dd7b2a7503	2001	2000/1	2026-05-22 13:11:30.343+00
055637b1-a973-4d54-8538-d5130b0fae34	aa0baf4e-af82-4020-9093-715971d63105	2001	2000/1	2026-05-22 13:11:30.343+00
456a4192-6244-4297-936b-77a01653c53e	eaca3063-d90c-4007-b3d8-ba829b3ee14e	11	10/1	2026-05-29 15:07:51.126+00
e1f048c0-a52c-4b57-982c-cb0254080e57	fcc03c57-8857-4986-98b0-0e30fb42ab2a	51	50/1	2026-06-04 21:01:52.182+00
9bf6e5fe-6a86-48cd-90ed-3d68b68f14a7	eaca3063-d90c-4007-b3d8-ba829b3ee14e	9	8/1	2026-06-07 15:15:06.38+00
b6e3169a-0948-48f4-a4ae-be4f518249e3	2044181c-c7e7-4759-8101-4779166812e3	17	16/1	2026-06-07 15:15:06.38+00
6268000b-5d86-48e1-83e4-a4d29dd73634	8682004e-e186-4705-aa29-9704b2815dc4	29	28/1	2026-06-07 15:15:06.38+00
ee464a70-572f-4d6a-b660-0398077036ac	6527ec07-bc6b-4b53-8bff-90b6f622aece	67	66/1	2026-06-07 15:15:06.38+00
1ed923c2-2d6c-48ed-93a0-bff75d0bf483	910a4a31-591d-4c32-8b57-b0d0bbde5a26	81	80/1	2026-06-07 15:15:06.38+00
2497dae8-a9ad-469f-bf71-1ddcb1188e22	54ef8b7c-5afd-4a48-a3b9-d6701dd757f9	151	150/1	2026-06-07 15:15:06.38+00
52d3c82d-105b-459b-9bcf-67007bbd51c9	d6209663-7a5c-4736-b346-cde299b554b2	251	250/1	2026-06-07 15:15:06.38+00
eb98389d-395c-439b-a165-d1b41f755901	a760ffb3-5775-4d7d-b803-cf0087525d91	1501	1500/1	2026-06-07 15:15:06.38+00
ff14ecdb-5a85-4ab0-bac8-e7962da3c115	eaca3063-d90c-4007-b3d8-ba829b3ee14e	8	7/1	2026-06-11 12:52:58.271+00
3fd5a0b8-42da-47ae-9891-0d5aac0a2572	cba2c884-3603-4b90-976e-49389b04f562	10	9/1	2026-06-11 12:52:58.271+00
9cc2592a-6af2-4945-be86-ff1c49dc1f73	2044181c-c7e7-4759-8101-4779166812e3	19	18/1	2026-06-11 12:52:58.271+00
9e4c36a5-6ba1-4651-bfca-edde9592d1aa	e171e736-56f2-44fa-92b5-b0653ea2ce2a	41	40/1	2026-06-11 12:52:58.271+00
86130eee-5d43-48ec-b51c-31f62a978826	e176dd2c-4446-4811-b4cc-fc28e9c2ab25	51	50/1	2026-06-11 12:52:58.271+00
00233824-856b-465d-9236-d53a6facb921	cd984ce3-2f2c-41d5-a7ba-137060caf8ae	81	80/1	2026-06-11 12:52:58.271+00
94c3ff85-3f2a-46e4-a7d7-65a3b3863ad3	f99d6725-238c-4d95-8502-9d25b4a6e89e	401	400/1	2026-06-11 12:52:58.271+00
b98cb3b5-bcc0-4bcb-96c1-1200dd295916	20160ec3-c507-4fb3-b19d-89cb66c59a98	251	250/1	2026-06-12 16:38:05.893+00
1b53eb70-6419-45c8-acff-034b80887092	d6209663-7a5c-4736-b346-cde299b554b2	301	300/1	2026-06-12 16:38:05.893+00
4472004a-11fb-4f92-ae9b-34318f3e87dd	7f560d60-00fc-46e1-b81b-4e7234b7cb04	1001	1000/1	2026-06-12 16:38:05.893+00
83cc9e2e-e25e-4e10-b4c3-300b3e76523f	cba2c884-3603-4b90-976e-49389b04f562	11	10/1	2026-06-14 18:43:53.623+00
89b5b4e0-b065-4d96-a20a-b44d7bf57188	fcc03c57-8857-4986-98b0-0e30fb42ab2a	34	33/1	2026-06-14 18:43:53.623+00
a90862f8-b344-46b8-8d73-a0cb5eec58ed	6527ec07-bc6b-4b53-8bff-90b6f622aece	41	40/1	2026-06-14 18:43:53.623+00
a8134231-ed08-415f-a547-0790884d604e	f99d6725-238c-4d95-8502-9d25b4a6e89e	101	100/1	2026-06-14 18:43:53.623+00
6a7b2180-0b66-447c-9119-7921bdde14f7	4f0f3776-f99f-4c06-9eb4-0acd2825d8c2	126	125/1	2026-06-14 18:43:53.623+00
27a8af92-8959-4d37-95af-8b7e1afc789a	87881cf2-7a14-4afa-9912-0ef5b2672387	151	150/1	2026-06-14 18:43:53.623+00
b0c4ad8e-69b3-4b89-ba2b-fa09adacf7fb	4976e7fd-9b45-4cc7-b741-fe801fcee2d0	251	250/1	2026-06-14 18:43:53.623+00
f7013fd9-6b49-4ddc-a285-73c85690c5a8	c8e5c035-af92-4497-b96c-82f2c0a15214	351	350/1	2026-06-14 18:43:53.623+00
d34790ba-f70c-4af6-aee5-45bae99dacaa	61d8b501-96d1-4043-a2b7-de27e9b137d7	351	350/1	2026-06-14 18:43:53.623+00
7f69c4d1-29f8-4cec-b37d-dd17aa43ecd2	9507020f-6157-4043-ae5b-72ca12dea41e	1501	1500/1	2026-06-14 18:43:53.623+00
00fe486c-1a5b-4b76-bee9-5c1c9544c9cb	7f560d60-00fc-46e1-b81b-4e7234b7cb04	2001	2000/1	2026-06-14 18:43:53.623+00
c3bf652e-2519-4051-ab96-9914c7816fee	cffa413c-8c76-45a6-843e-87c34e78e45a	13	12/1	2026-06-15 20:39:34.157+00
7fb850ab-2a0a-4738-9965-1c26c07bc54c	66a8014f-0009-400e-928c-6b28cb8dab1f	41	40/1	2026-06-15 20:39:34.157+00
4b77fe4f-a187-4833-aec9-2d7f874a538d	8682004e-e186-4705-aa29-9704b2815dc4	51	50/1	2026-06-15 20:39:34.157+00
741836eb-b2db-4e3c-9837-51dc1130223b	cd984ce3-2f2c-41d5-a7ba-137060caf8ae	151	150/1	2026-06-15 20:39:34.157+00
6a420d32-92f1-426a-88f7-ebd6855f506d	ddd77a2f-eb9f-4a20-8ae4-e1ca55c21893	201	200/1	2026-06-15 20:39:34.157+00
3a18fe60-8808-45bf-9167-1021262f2511	8682004e-e186-4705-aa29-9704b2815dc4	41	40/1	2026-06-15 21:01:48.345+00
7268c5a4-1746-4a93-8f1e-f77a99c902c1	622bb3ef-bc6e-4c9a-9efe-aae4d0f95822	501	500/1	2026-06-16 08:30:52.372+00
c8a9f7e7-c1a7-440c-be20-3e87c6f90def	f2c7a0c3-9a4c-4e3f-92a3-39abff0ce8e2	5	4/1	2026-06-16 19:57:51.328+00
f1f249a8-aa7c-4c9b-b2c5-1175598293f2	6ea9375b-d599-463f-96e6-c87d9209e9b2	6	5/1	2026-06-16 19:57:51.328+00
ddb3c9a5-ea85-4459-8452-149e67a3960f	acfbd82a-7005-41b9-9613-606ceefc857e	67	66/1	2026-06-16 19:57:51.328+00
9e7032aa-3929-4fa8-9aaf-e468c84adbcd	1b2fe4cc-3105-4e0b-b1ff-06f91c466ef7	7.5	13/2	2026-06-17 06:15:57.424+00
34563d61-c5a7-4051-b653-cf72e2eba852	95b1e39e-97c3-4d45-9714-3f507d7c52f1	9	8/1	2026-06-17 06:15:57.424+00
4ece6ef7-bafc-490d-9fa9-7ec13a41e07b	2044181c-c7e7-4759-8101-4779166812e3	21	20/1	2026-06-17 06:15:57.424+00
4314c7e2-6074-46e7-b784-8f861a18bbdd	fcc03c57-8857-4986-98b0-0e30fb42ab2a	41	40/1	2026-06-17 06:15:57.424+00
de3a648b-1f7d-4f0b-a9b0-c02c5eda60f4	1b2fe4cc-3105-4e0b-b1ff-06f91c466ef7	7	6/1	2026-06-17 22:37:07.909+00
e6b41d92-cb39-46e9-9261-44d41e2a039d	eaca3063-d90c-4007-b3d8-ba829b3ee14e	10	9/1	2026-06-17 22:37:07.909+00
c9ff6e78-e559-449a-bdeb-7c621c7ce7b9	cba2c884-3603-4b90-976e-49389b04f562	12	11/1	2026-06-17 22:37:07.909+00
30fcffa2-6bd7-4020-aca2-1913fbd2d66e	cffa413c-8c76-45a6-843e-87c34e78e45a	15	14/1	2026-06-17 22:37:07.909+00
fe13f351-fd32-4828-b076-25ccc268bae8	2044181c-c7e7-4759-8101-4779166812e3	23	22/1	2026-06-17 22:37:07.909+00
a1a55e32-bcfa-40c7-b48e-3b0c6493e45d	20e98c7a-4548-44f8-964d-7aba42ae7624	26	25/1	2026-06-17 22:37:07.909+00
5f96c338-14a9-485f-b777-2aacc0d7cd81	eaca3063-d90c-4007-b3d8-ba829b3ee14e	11	10/1	2026-06-18 12:42:27.657+00
9397ad97-f629-4ccd-842b-f910907fb751	2044181c-c7e7-4759-8101-4779166812e3	21	20/1	2026-06-18 12:42:27.657+00
2985445f-aee3-47ee-9da3-6dc0890645e4	20e98c7a-4548-44f8-964d-7aba42ae7624	29	28/1	2026-06-18 12:42:27.657+00
96040f4c-ac7c-4e05-af2b-28d1b0b72960	fcc03c57-8857-4986-98b0-0e30fb42ab2a	34	33/1	2026-06-18 12:42:27.657+00
30fe83d7-e8a7-484c-9d0b-de2bb2bcbcc7	ee8ecff9-d0b1-4aa8-ab21-da08a6c9229a	81	80/1	2026-06-18 12:42:27.657+00
bd9846a3-bfcc-461b-9660-7bcbc32fb20f	acfbd82a-7005-41b9-9613-606ceefc857e	81	80/1	2026-06-18 12:42:27.657+00
0390e766-9f73-4796-92ec-368bfcb214a1	910a4a31-591d-4c32-8b57-b0d0bbde5a26	101	100/1	2026-06-18 12:42:27.657+00
2190e107-69fa-496c-8d48-9ae7a9cf7360	cd984ce3-2f2c-41d5-a7ba-137060caf8ae	126	125/1	2026-06-18 12:42:27.657+00
442cf460-e8c8-49c4-ae1a-c12b6ca91a08	151a98cf-99e8-4e7a-ab57-396a13db4a72	126	125/1	2026-06-18 12:42:27.657+00
fc6cc818-7404-4dae-ad96-7e4690d21cb4	52f066d8-0a7a-42c5-8a6b-103ec4ba2c91	201	200/1	2026-06-18 12:42:27.657+00
d78c44f9-780b-42d2-9059-85fc5b1fde8e	ddd77a2f-eb9f-4a20-8ae4-e1ca55c21893	251	250/1	2026-06-18 12:42:27.657+00
cb39338b-953e-40c6-846e-a2002c2db7c5	d6209663-7a5c-4736-b346-cde299b554b2	351	350/1	2026-06-18 12:42:27.657+00
dc20e82d-bf18-4919-99c3-0673ddaa6f7e	4976e7fd-9b45-4cc7-b741-fe801fcee2d0	351	350/1	2026-06-18 12:42:27.657+00
dcaa8508-1d40-4328-8ec7-d3d156572a6e	b6afbe52-5067-4263-a750-6101f6efedc0	351	350/1	2026-06-18 12:42:27.657+00
60690b33-4160-4ea9-b5af-b6d643a648f0	622bb3ef-bc6e-4c9a-9efe-aae4d0f95822	751	750/1	2026-06-18 12:42:27.657+00
dbcf029e-8e46-4c9c-90f4-2d2017362abe	a760ffb3-5775-4d7d-b803-cf0087525d91	1001	1000/1	2026-06-18 12:42:27.657+00
0f007b66-e49c-4981-a63a-268c38c5f489	f27875c8-4818-4323-8d45-333b7f82cf57	1501	1500/1	2026-06-18 12:42:27.657+00
9a0d95ba-fe28-413e-9506-5346936e63af	8d109cbf-133f-496a-b5b7-3f75a0ec1dcd	1501	1500/1	2026-06-18 12:42:27.657+00
b7eff444-d571-4084-beac-2771fc9d1ad5	7f560d60-00fc-46e1-b81b-4e7234b7cb04	2501	2500/1	2026-06-18 12:42:27.657+00
3519651f-644b-42f3-8383-dcd9466e3f84	666ba168-4d8b-4060-8e4b-e1dd7b2a7503	2501	2500/1	2026-06-18 12:42:27.657+00
9243f1ce-b769-4f61-b6ab-a00aa51a468f	e176dd2c-4446-4811-b4cc-fc28e9c2ab25	41	40/1	2026-06-19 10:53:20.378+00
bfd148d2-ba51-4fc6-a6a2-af30a7e00b5c	4f0f3776-f99f-4c06-9eb4-0acd2825d8c2	101	100/1	2026-06-19 10:53:20.378+00
bf3b7bda-90e5-4d1f-92a1-21efb1e22773	d6209663-7a5c-4736-b346-cde299b554b2	501	500/1	2026-06-19 10:53:20.378+00
7ab00933-9d53-4e13-8fab-085696ac248b	9507020f-6157-4043-ae5b-72ca12dea41e	1001	1000/1	2026-06-19 10:53:20.378+00
e99419f7-4517-496f-b8aa-71d24fa68b63	666ba168-4d8b-4060-8e4b-e1dd7b2a7503	1001	1000/1	2026-06-19 10:53:20.378+00
c923627d-82c9-406b-8dab-4932c349786e	f2c7a0c3-9a4c-4e3f-92a3-39abff0ce8e2	4.5	7/2	2026-06-22 13:54:32.611+00
e8939219-e5d4-4162-abd1-27fdee8a81f2	95b1e39e-97c3-4d45-9714-3f507d7c52f1	8	7/1	2026-06-22 13:54:32.611+00
37b92202-477d-42fb-b5e1-ba42daf87ddf	cba2c884-3603-4b90-976e-49389b04f562	13	12/1	2026-06-22 13:54:32.611+00
feb57755-9bdc-4395-ba2e-e8d4c5920c26	2044181c-c7e7-4759-8101-4779166812e3	17	16/1	2026-06-22 13:54:32.611+00
c7c4fa25-9520-4753-8668-83f21cf1f0ed	fcc03c57-8857-4986-98b0-0e30fb42ab2a	29	28/1	2026-06-22 13:54:32.611+00
3ef0f0aa-98de-49be-8af4-b4e6c05a0d57	6527ec07-bc6b-4b53-8bff-90b6f622aece	34	33/1	2026-06-22 13:54:32.611+00
e449ec19-5ded-409a-b86b-7e0a24f8271d	20e98c7a-4548-44f8-964d-7aba42ae7624	34	33/1	2026-06-22 13:54:32.611+00
7490c4b7-1aa0-40a0-be07-dc24ee5abbc8	8682004e-e186-4705-aa29-9704b2815dc4	51	50/1	2026-06-22 13:54:32.611+00
624fcbb2-70bd-48a6-b31a-21de0d30785f	e176dd2c-4446-4811-b4cc-fc28e9c2ab25	51	50/1	2026-06-22 13:54:32.611+00
30e759f9-ce89-48dc-833c-6f88a8e15229	8cccecd8-b1ab-4159-bf35-29ef0db369c4	101	100/1	2026-06-22 13:54:32.611+00
79542e26-eec2-4ace-b689-9f403b00cf9d	52eaa3b4-081b-4393-b291-d69c644c612e	126	125/1	2026-06-22 13:54:32.611+00
9f28c47f-0cae-47b5-8508-3a075200a1bc	ee8ecff9-d0b1-4aa8-ab21-da08a6c9229a	151	150/1	2026-06-22 13:54:32.611+00
d95d7d55-5087-4f88-aedd-abed5de52b3b	910a4a31-591d-4c32-8b57-b0d0bbde5a26	151	150/1	2026-06-22 13:54:32.611+00
6895f003-9655-4caa-82f2-dc5b1e6fcbe9	f99d6725-238c-4d95-8502-9d25b4a6e89e	201	200/1	2026-06-22 13:54:32.611+00
8405077d-0fea-4ea6-a4c1-e9a42740103b	cd984ce3-2f2c-41d5-a7ba-137060caf8ae	251	250/1	2026-06-22 13:54:32.611+00
0d536f75-76f3-41a7-8452-2ab8b6ac50a9	52f066d8-0a7a-42c5-8a6b-103ec4ba2c91	251	250/1	2026-06-22 13:54:32.611+00
8ab5e93d-ccf0-457b-9f7e-a9067ca89c42	20160ec3-c507-4fb3-b19d-89cb66c59a98	351	350/1	2026-06-22 13:54:32.611+00
a9c03abb-391c-4501-a208-262efd0922c1	4976e7fd-9b45-4cc7-b741-fe801fcee2d0	501	500/1	2026-06-22 13:54:32.611+00
57077553-925b-4e64-b94c-ea3eeb332e31	b6afbe52-5067-4263-a750-6101f6efedc0	501	500/1	2026-06-22 13:54:32.611+00
39bed17a-c517-4c30-a042-301e1cab03c6	622bb3ef-bc6e-4c9a-9efe-aae4d0f95822	1001	1000/1	2026-06-22 13:54:32.611+00
a40dd1a2-b67b-43af-9496-d258b2d54930	9507020f-6157-4043-ae5b-72ca12dea41e	1501	1500/1	2026-06-22 13:54:32.611+00
41c5007e-e491-439e-8b1c-d8cd7c99422e	f27875c8-4818-4323-8d45-333b7f82cf57	2001	2000/1	2026-06-22 13:54:32.611+00
345ced21-659c-409a-9dd5-1b4efb0dd630	666ba168-4d8b-4060-8e4b-e1dd7b2a7503	2501	2500/1	2026-06-22 13:54:32.611+00
8c38144a-962f-456d-92eb-a2cd849d55c3	600575e1-d737-452a-abec-c6e22da92787	3501	3500/1	2026-06-22 13:54:32.611+00
a82f13b3-9ed6-4ad3-a8ba-81e699af61c1	f2c7a0c3-9a4c-4e3f-92a3-39abff0ce8e2	5	4/1	2026-06-23 11:50:21.932+00
82216cab-755c-4d3d-8a66-e70ee31818e1	95b1e39e-97c3-4d45-9714-3f507d7c52f1	7.5	13/2	2026-06-23 11:50:21.932+00
69da8bcc-3354-4f90-8360-eb24f7dd98bb	eaca3063-d90c-4007-b3d8-ba829b3ee14e	13	12/1	2026-06-23 11:50:21.932+00
d7c36f54-9aee-4c6a-97af-5dc94cb6f58a	2044181c-c7e7-4759-8101-4779166812e3	15	14/1	2026-06-23 11:50:21.932+00
23e11fc2-b893-4688-8c2f-517f1ecc853b	cba2c884-3603-4b90-976e-49389b04f562	15	14/1	2026-06-23 11:50:21.932+00
749d8488-445f-42cc-87bb-fde0bc1aa505	20e98c7a-4548-44f8-964d-7aba42ae7624	29	28/1	2026-06-23 11:50:21.932+00
35e4e804-8d0b-4467-967d-73cf394eda6b	e171e736-56f2-44fa-92b5-b0653ea2ce2a	51	50/1	2026-06-23 11:50:21.932+00
b962a935-da0b-4129-bdcc-10a02f60db65	8cccecd8-b1ab-4159-bf35-29ef0db369c4	126	125/1	2026-06-23 11:50:21.932+00
63744e74-5867-4f75-9f29-2ba8e74354d8	4f0f3776-f99f-4c06-9eb4-0acd2825d8c2	126	125/1	2026-06-23 11:50:21.932+00
2c2be5d3-2f73-4a95-9891-198e5bf40240	151a98cf-99e8-4e7a-ab57-396a13db4a72	151	150/1	2026-06-23 11:50:21.932+00
1dd4b161-c62b-44c8-8e31-25ab9f3d9b59	52eaa3b4-081b-4393-b291-d69c644c612e	151	150/1	2026-06-23 11:50:21.932+00
78eb725c-6b73-41d8-bcbb-f12124aa35f9	ee8ecff9-d0b1-4aa8-ab21-da08a6c9229a	201	200/1	2026-06-23 11:50:21.932+00
35d09582-c8fa-4d71-bda6-98f73bee5266	c8e5c035-af92-4497-b96c-82f2c0a15214	251	250/1	2026-06-23 11:50:21.932+00
34ccf3e0-0d5a-4dd1-8392-e731db825566	20160ec3-c507-4fb3-b19d-89cb66c59a98	251	250/1	2026-06-23 11:50:21.932+00
05618764-49b8-483c-8043-9abf8d68a30d	f99d6725-238c-4d95-8502-9d25b4a6e89e	251	250/1	2026-06-23 11:50:21.932+00
8a26f88f-5aa2-44f8-b0e7-d466f455d537	f959649f-d7be-48e3-9129-58e7fc519606	751	750/1	2026-06-23 11:50:21.932+00
d2d6ceb7-6d06-44b6-a96d-e5d13b789d4a	f27875c8-4818-4323-8d45-333b7f82cf57	2501	2500/1	2026-06-23 11:50:21.932+00
5a595762-73cc-4290-ad08-c46877ee4521	eaca3063-d90c-4007-b3d8-ba829b3ee14e	11	10/1	2026-06-24 06:19:29.232+00
00916430-4d0a-46f1-9105-7683707267bf	e171e736-56f2-44fa-92b5-b0653ea2ce2a	41	40/1	2026-06-24 06:19:29.232+00
21ca2d01-350d-4685-ad88-8b9e664a70c2	8cccecd8-b1ab-4159-bf35-29ef0db369c4	101	100/1	2026-06-24 06:19:29.232+00
78231dad-e533-473b-ae15-7ac3711ff185	e171e736-56f2-44fa-92b5-b0653ea2ce2a	51	50/1	2026-06-24 16:55:52.433+00
6492bbb3-23e8-4c4d-8600-121b113c669a	4f0f3776-f99f-4c06-9eb4-0acd2825d8c2	201	200/1	2026-06-24 16:55:52.433+00
5a167302-a02b-40fb-ab51-c616eb52e2f5	910a4a31-591d-4c32-8b57-b0d0bbde5a26	201	200/1	2026-06-24 16:55:52.433+00
eb3a5b89-1123-4c92-ab91-067155fb8239	ee8ecff9-d0b1-4aa8-ab21-da08a6c9229a	251	250/1	2026-06-24 16:55:52.433+00
32eedc44-ef87-411a-9191-7897ea9b5d1c	cd984ce3-2f2c-41d5-a7ba-137060caf8ae	351	350/1	2026-06-24 16:55:52.433+00
f0d720ec-4e7f-4033-99cf-cd6b00f589b5	20160ec3-c507-4fb3-b19d-89cb66c59a98	351	350/1	2026-06-24 16:55:52.433+00
a9e61eb0-9aff-42bf-8b62-a6ce7ed00218	52f066d8-0a7a-42c5-8a6b-103ec4ba2c91	351	350/1	2026-06-24 16:55:52.433+00
d0b89f02-0eac-4000-af7c-955180b72d51	6ea9375b-d599-463f-96e6-c87d9209e9b2	6.5	11/2	2026-06-26 10:34:54.912+00
7eebce43-1e92-4fd0-b0ec-271597db46a1	95b1e39e-97c3-4d45-9714-3f507d7c52f1	7	6/1	2026-06-26 10:34:54.912+00
c62a7131-058c-4185-9b71-85b6bafa6b29	eaca3063-d90c-4007-b3d8-ba829b3ee14e	9	8/1	2026-06-26 10:34:54.912+00
93ac6896-8b88-4de5-9ed0-b9469d00b358	cba2c884-3603-4b90-976e-49389b04f562	13	12/1	2026-06-26 10:34:54.912+00
22a224f9-2bf6-4b39-a0f3-6d8622c3c3d3	cffa413c-8c76-45a6-843e-87c34e78e45a	17	16/1	2026-06-26 10:34:54.912+00
90bdebfc-3851-4422-a60d-89555a9e45a2	6527ec07-bc6b-4b53-8bff-90b6f622aece	29	28/1	2026-06-26 10:34:54.912+00
8bb87a32-5546-450a-b29e-5f10c49b7035	fcc03c57-8857-4986-98b0-0e30fb42ab2a	41	40/1	2026-06-26 10:34:54.912+00
b7ecd4df-4033-48e8-87ad-0e699ffa45ba	e176dd2c-4446-4811-b4cc-fc28e9c2ab25	41	40/1	2026-06-26 10:34:54.912+00
cff5544e-c44a-4878-9a48-2fec0691666d	e171e736-56f2-44fa-92b5-b0653ea2ce2a	41	40/1	2026-06-26 10:34:54.912+00
a04ca9bb-5cd6-45a8-b23b-1aedfcbf7162	acfbd82a-7005-41b9-9613-606ceefc857e	67	66/1	2026-06-26 10:34:54.912+00
98634755-8a52-4d16-b35c-54dc3ed37d2f	4f0f3776-f99f-4c06-9eb4-0acd2825d8c2	151	150/1	2026-06-26 10:34:54.912+00
e48c5db0-8750-4b0f-9200-be35c37690b3	ee8ecff9-d0b1-4aa8-ab21-da08a6c9229a	201	200/1	2026-06-26 10:34:54.912+00
8d52c815-d138-47b0-ae9d-f652d62cb9af	f99d6725-238c-4d95-8502-9d25b4a6e89e	201	200/1	2026-06-26 10:34:54.912+00
f1a3f1ce-de9e-4e78-ad1f-30ac0ba50a5e	cd984ce3-2f2c-41d5-a7ba-137060caf8ae	251	250/1	2026-06-26 10:34:54.912+00
7b1fd7b0-6136-45b5-bf73-daf49a5714c8	20160ec3-c507-4fb3-b19d-89cb66c59a98	401	400/1	2026-06-26 10:34:54.912+00
c0e8fc49-ee16-4d15-866b-4b3bd47fe9e1	9507020f-6157-4043-ae5b-72ca12dea41e	501	500/1	2026-06-26 10:34:54.912+00
9588d24a-f5c7-473b-9fe8-fb31e595a2f4	52f066d8-0a7a-42c5-8a6b-103ec4ba2c91	751	750/1	2026-06-26 10:34:54.912+00
37837821-8b44-4473-a9d5-1a5b6f486843	cd984ce3-2f2c-41d5-a7ba-137060caf8ae	126	125/1	2026-06-26 15:52:43.271+00
75c2cf7b-f623-4f66-a41a-7c9ed13e2728	f2c7a0c3-9a4c-4e3f-92a3-39abff0ce8e2	4.5	7/2	2026-06-27 05:44:45.991+00
0a1fc92a-ada7-49f6-8483-d8ac2cb6f8cf	8682004e-e186-4705-aa29-9704b2815dc4	41	40/1	2026-06-27 05:44:45.991+00
891caabf-9918-4cbe-b109-239b4268b65a	f959649f-d7be-48e3-9129-58e7fc519606	501	500/1	2026-06-27 05:44:45.991+00
71c3fe9e-67a8-40b3-ab7f-50cb57ac1ca7	95b1e39e-97c3-4d45-9714-3f507d7c52f1	5	4/1	2026-06-28 08:32:12.813+00
bce50378-b538-4b82-a94e-53a094ff142a	6ea9375b-d599-463f-96e6-c87d9209e9b2	7	6/1	2026-06-28 08:32:12.813+00
c1912818-4730-4253-905a-e3f12864a906	eaca3063-d90c-4007-b3d8-ba829b3ee14e	11	10/1	2026-06-28 08:32:12.813+00
e6e0345c-c3ea-40e7-aa5a-24249cbfada2	e171e736-56f2-44fa-92b5-b0653ea2ce2a	34	33/1	2026-06-28 08:32:12.813+00
2fa8033b-a485-4809-8fbd-ec9f3ae1fdca	a681c714-630a-487f-b167-9cefea486591	501	500/1	2026-06-28 08:32:12.813+00
00e747b4-547d-4f41-a9d3-7dc9c3142c70	f2c7a0c3-9a4c-4e3f-92a3-39abff0ce8e2	4.33	10/3	2026-06-28 12:48:00.061+00
423f9b5c-184b-4995-b55e-de59f7e67399	6ea9375b-d599-463f-96e6-c87d9209e9b2	7.5	13/2	2026-06-28 12:48:00.061+00
e22249d2-93d6-498a-95ee-6a1dc0b3d5ad	e171e736-56f2-44fa-92b5-b0653ea2ce2a	29	28/1	2026-06-29 11:00:02.429+00
624f50f4-d975-4cdb-96a2-4324cae290c4	4f0f3776-f99f-4c06-9eb4-0acd2825d8c2	101	100/1	2026-06-29 11:00:02.429+00
9d66a053-e830-4db7-b8a1-399b1f9bbdfb	f2c7a0c3-9a4c-4e3f-92a3-39abff0ce8e2	3.75	11/4	2026-06-29 23:44:55.782+00
1c07a844-c27c-44a4-8877-037c60efeea0	95b1e39e-97c3-4d45-9714-3f507d7c52f1	4.5	7/2	2026-06-29 23:44:55.782+00
4b70a2ab-2e8b-4a9f-80e3-a69306e1cd59	1b2fe4cc-3105-4e0b-b1ff-06f91c466ef7	7.5	13/2	2026-06-29 23:44:55.782+00
2e14faae-6272-4a27-9a9b-abff427bec46	cba2c884-3603-4b90-976e-49389b04f562	11	10/1	2026-06-29 23:44:55.782+00
479fe14a-a473-4d89-b7c3-9e12c5ae3e7d	eaca3063-d90c-4007-b3d8-ba829b3ee14e	13	12/1	2026-06-29 23:44:55.782+00
bdb007cb-a94b-4cd3-8916-976ace99f704	2044181c-c7e7-4759-8101-4779166812e3	17	16/1	2026-06-29 23:44:55.782+00
6d52e60b-d87e-494c-a3fa-cb7f9efe8689	6527ec07-bc6b-4b53-8bff-90b6f622aece	34	33/1	2026-06-29 23:44:55.782+00
21fbf720-5861-493f-8311-3dcf06b27310	20e98c7a-4548-44f8-964d-7aba42ae7624	41	40/1	2026-06-29 23:44:55.782+00
7487dc1b-52e0-418c-bf59-eb236cea1d88	8682004e-e186-4705-aa29-9704b2815dc4	51	50/1	2026-06-29 23:44:55.782+00
060a8fde-4f8e-4a6f-96bf-573453a9be67	fcc03c57-8857-4986-98b0-0e30fb42ab2a	51	50/1	2026-06-29 23:44:55.782+00
a4b9e889-9cdf-416a-b0d2-2f2d95ef66b3	e176dd2c-4446-4811-b4cc-fc28e9c2ab25	51	50/1	2026-06-29 23:44:55.782+00
ac539c95-8566-49fe-bb6f-5a26608d4615	acfbd82a-7005-41b9-9613-606ceefc857e	81	80/1	2026-06-29 23:44:55.782+00
88409804-536c-461f-8716-f68e4e4dfc9c	4f0f3776-f99f-4c06-9eb4-0acd2825d8c2	126	125/1	2026-06-29 23:44:55.782+00
f0e067cd-155d-4244-8b80-0ad7e2720c63	8cccecd8-b1ab-4159-bf35-29ef0db369c4	151	150/1	2026-06-29 23:44:55.782+00
43ed81da-cd9d-4fc8-a388-6ad225e19d27	54ef8b7c-5afd-4a48-a3b9-d6701dd757f9	201	200/1	2026-06-29 23:44:55.782+00
8ad97abb-219b-4863-8ea5-19560f62e0a7	52eaa3b4-081b-4393-b291-d69c644c612e	251	250/1	2026-06-29 23:44:55.782+00
114cbd82-fc3f-4163-80eb-385195d5539f	f99d6725-238c-4d95-8502-9d25b4a6e89e	251	250/1	2026-06-29 23:44:55.782+00
5b5cfe5b-1f53-4a96-a1e2-1ba680350526	b6afbe52-5067-4263-a750-6101f6efedc0	351	350/1	2026-06-29 23:44:55.782+00
5a39fb1d-cf13-4ccd-bf39-ad296d43dea5	1270b02b-ff92-4068-a52e-ae90bcae805b	501	500/1	2026-06-29 23:44:55.782+00
28bf7473-b6ca-4a7e-82b3-8865c0cc2ce9	f2c7a0c3-9a4c-4e3f-92a3-39abff0ce8e2	3.5	5/2	2026-06-30 17:41:19.132+00
17a59dc8-8926-4915-8eef-36bfb6b4ee39	95b1e39e-97c3-4d45-9714-3f507d7c52f1	5	4/1	2026-06-30 17:41:19.132+00
f45a8360-ac76-4e81-9f36-9a3e220d8b26	fcc03c57-8857-4986-98b0-0e30fb42ab2a	21	20/1	2026-06-30 17:41:19.132+00
e639c478-1526-45bc-a792-32b52fca417e	20e98c7a-4548-44f8-964d-7aba42ae7624	34	33/1	2026-06-30 17:41:19.132+00
f4e9b2b2-0eba-4572-8411-370fd9b1dee8	e176dd2c-4446-4811-b4cc-fc28e9c2ab25	41	40/1	2026-06-30 17:41:19.132+00
5417b0ca-eca0-4905-b857-d85b651a779a	c8e5c035-af92-4497-b96c-82f2c0a15214	201	200/1	2026-06-30 17:41:19.132+00
f73ebb6b-cf22-4e7a-b68a-5d444c78c3cd	54ef8b7c-5afd-4a48-a3b9-d6701dd757f9	251	250/1	2026-06-30 17:41:19.132+00
a459624e-7940-4934-b8e6-1f30f30dc6dc	f99d6725-238c-4d95-8502-9d25b4a6e89e	351	350/1	2026-06-30 17:41:19.132+00
6be8e87c-9c6a-4671-a8ed-c2a9f9cb25a9	f2c7a0c3-9a4c-4e3f-92a3-39abff0ce8e2	2.88	15/8	2026-07-01 18:21:56.547+00
2cb57193-69c2-466c-b085-d7405114fedc	6ea9375b-d599-463f-96e6-c87d9209e9b2	8	7/1	2026-07-01 18:21:56.547+00
ac64c5f4-8351-4257-b6d2-2690c8fc7f71	1b2fe4cc-3105-4e0b-b1ff-06f91c466ef7	8	7/1	2026-07-01 18:21:56.547+00
77ce5b68-0bca-429e-a467-28666c62f76c	cba2c884-3603-4b90-976e-49389b04f562	12	11/1	2026-07-01 18:21:56.547+00
a65a1408-7e9d-40c2-98ce-f2be8c12a7cc	eaca3063-d90c-4007-b3d8-ba829b3ee14e	15	14/1	2026-07-01 18:21:56.547+00
e0ea1e81-cf87-45c9-b99f-6dc0d94bbff2	fcc03c57-8857-4986-98b0-0e30fb42ab2a	26	25/1	2026-07-01 18:21:56.547+00
51e77eec-fed9-423f-8b44-45821fcf321e	e176dd2c-4446-4811-b4cc-fc28e9c2ab25	29	28/1	2026-07-01 18:21:56.547+00
be948acc-037b-45ea-b8a7-d959299071ab	e171e736-56f2-44fa-92b5-b0653ea2ce2a	34	33/1	2026-07-01 18:21:56.547+00
94799a22-799d-4566-8e00-f1d52797820c	8cccecd8-b1ab-4159-bf35-29ef0db369c4	201	200/1	2026-07-01 18:21:56.547+00
5eb2704b-22bc-470d-b1d5-ca6b2bc8d7c9	4f0f3776-f99f-4c06-9eb4-0acd2825d8c2	201	200/1	2026-07-01 18:21:56.547+00
d391af21-a092-4d61-944e-30584a82f13c	c8e5c035-af92-4497-b96c-82f2c0a15214	351	350/1	2026-07-01 18:21:56.547+00
6b5dc290-96fd-44af-8bdf-3128c77e7322	52eaa3b4-081b-4393-b291-d69c644c612e	351	350/1	2026-07-01 18:21:56.547+00
e10c7fb5-c1e7-4de1-a2b5-dc5a141a52b5	b6afbe52-5067-4263-a750-6101f6efedc0	501	500/1	2026-07-01 18:21:56.547+00
ecd283f6-97e8-44e6-9680-d02742b92365	1270b02b-ff92-4068-a52e-ae90bcae805b	751	750/1	2026-07-01 18:21:56.547+00
7545a9b9-a937-460a-9de3-5c3e14871ec5	6ea9375b-d599-463f-96e6-c87d9209e9b2	7	6/1	2026-07-02 20:58:38.911+00
082cf91a-0349-4466-9af0-3a815399889d	1b2fe4cc-3105-4e0b-b1ff-06f91c466ef7	9.5	17/2	2026-07-02 20:58:38.911+00
c9bf23cb-1d20-4717-8c3b-134b99b153b3	cba2c884-3603-4b90-976e-49389b04f562	11	10/1	2026-07-02 20:58:38.911+00
06351230-d1a3-4604-a8da-ce4b442ac2e8	6527ec07-bc6b-4b53-8bff-90b6f622aece	29	28/1	2026-07-02 20:58:38.911+00
f66ccbe6-9b49-430c-bc93-c0c445400029	e171e736-56f2-44fa-92b5-b0653ea2ce2a	29	28/1	2026-07-02 20:58:38.911+00
71e8b3c4-6e33-40c6-9515-cbf91beedca0	8682004e-e186-4705-aa29-9704b2815dc4	34	33/1	2026-07-02 20:58:38.911+00
e7d90f93-44f4-483b-8122-81c81c619c96	cba2c884-3603-4b90-976e-49389b04f562	13	12/1	2026-07-02 23:18:16.457+00
636ffc41-3f4a-4c6f-aaa1-9a4797a40e7b	eaca3063-d90c-4007-b3d8-ba829b3ee14e	21	20/1	2026-07-03 00:29:22.121+00
8427faa6-3640-4656-b8da-d1eb24fbcbad	8cccecd8-b1ab-4159-bf35-29ef0db369c4	67	66/1	2026-07-03 00:29:22.121+00
4924b20b-b2d6-4c1a-b095-9701ed3b4509	eaca3063-d90c-4007-b3d8-ba829b3ee14e	12	11/1	2026-07-03 07:33:33.777+00
8c3b3637-2b87-4d39-bb7b-753b0399cde0	acfbd82a-7005-41b9-9613-606ceefc857e	41	40/1	2026-07-03 07:33:33.777+00
9125c016-a4eb-447d-a7d1-49681b0c8444	1b2fe4cc-3105-4e0b-b1ff-06f91c466ef7	10	9/1	2026-07-03 21:35:10.023+00
b8e42276-c8f8-45bd-b966-e93f8b24271e	acfbd82a-7005-41b9-9613-606ceefc857e	51	50/1	2026-07-03 21:35:10.023+00
341d1e69-e3d9-481d-b3e2-597ec82260b4	ddd77a2f-eb9f-4a20-8ae4-e1ca55c21893	201	200/1	2026-07-03 21:35:10.023+00
bf7d551c-1cee-46ba-b7c4-24d0f4000cd7	95b1e39e-97c3-4d45-9714-3f507d7c52f1	5.5	9/2	2026-07-04 04:01:02.526+00
b18daade-2bb0-4734-b6ac-4c6cba721a71	e171e736-56f2-44fa-92b5-b0653ea2ce2a	26	25/1	2026-07-04 04:01:02.526+00
3b32ceaa-094a-4b91-b5f3-5d1466587c5e	95b1e39e-97c3-4d45-9714-3f507d7c52f1	5	4/1	2026-07-04 17:05:34.989+00
c5178472-cc35-4a57-8188-54ac1d784819	cba2c884-3603-4b90-976e-49389b04f562	12	11/1	2026-07-04 17:05:34.989+00
5108702c-cadb-4bbd-a331-0c7e5de1d40c	fcc03c57-8857-4986-98b0-0e30fb42ab2a	29	28/1	2026-07-04 17:05:34.989+00
24b093e7-9ce1-473a-b2d3-01eb3a5dfc6f	8682004e-e186-4705-aa29-9704b2815dc4	41	40/1	2026-07-04 17:05:34.989+00
b07d9f10-2fef-4e5f-83c4-5ec550774513	acfbd82a-7005-41b9-9613-606ceefc857e	67	66/1	2026-07-04 17:05:34.989+00
0ceed2b6-21dd-4127-8ce0-db79fbc69b2c	f2c7a0c3-9a4c-4e3f-92a3-39abff0ce8e2	2.5	6/4	2026-07-05 12:22:50.646+00
862e543c-5dda-4b07-820e-a5bb71f7ed32	95b1e39e-97c3-4d45-9714-3f507d7c52f1	5.5	9/2	2026-07-05 12:22:50.646+00
bb56cbb1-8c3a-42df-a0da-afb2ed67ab15	6ea9375b-d599-463f-96e6-c87d9209e9b2	6.5	11/2	2026-07-05 12:22:50.646+00
6f1d705a-f731-49ad-aec1-fcaefef96a89	fcc03c57-8857-4986-98b0-0e30fb42ab2a	23	22/1	2026-07-05 12:22:50.646+00
d5970300-5a89-4b38-8f39-778c999a189d	1b2fe4cc-3105-4e0b-b1ff-06f91c466ef7	7.5	13/2	2026-07-06 03:33:33.871+00
ae0f2bcc-adcc-4c4a-8153-4b32a5e059f5	20e98c7a-4548-44f8-964d-7aba42ae7624	13	12/1	2026-07-06 03:33:33.871+00
9ae3df71-63a2-4e05-bf25-df74304e217c	1b2fe4cc-3105-4e0b-b1ff-06f91c466ef7	6.5	11/2	2026-07-06 08:08:35.776+00
8e863289-2b15-4263-b19e-24eea2cc6a31	6ea9375b-d599-463f-96e6-c87d9209e9b2	7	6/1	2026-07-06 08:08:35.776+00
f84e987a-a3c3-494d-82e8-4e4bd587c43c	20e98c7a-4548-44f8-964d-7aba42ae7624	17	16/1	2026-07-06 08:08:35.776+00
aaf9393d-a468-4c6a-ac98-f802b320acf6	fcc03c57-8857-4986-98b0-0e30fb42ab2a	29	28/1	2026-07-06 08:08:35.776+00
e145f2a4-3da9-4f27-a607-6423689376f0	6527ec07-bc6b-4b53-8bff-90b6f622aece	34	33/1	2026-07-06 08:08:35.776+00
8a4d76e8-a495-4671-9565-e328c4043fc7	f2c7a0c3-9a4c-4e3f-92a3-39abff0ce8e2	2.88	15/8	2026-07-07 18:08:32.103+00
7d64e333-1c12-4f6f-963d-bb642365872b	6ea9375b-d599-463f-96e6-c87d9209e9b2	4.5	7/2	2026-07-07 18:08:32.103+00
024afbe2-581e-4091-badd-5dad8a6f280c	95b1e39e-97c3-4d45-9714-3f507d7c52f1	5	4/1	2026-07-07 18:08:32.103+00
73342b36-a54b-4a38-a74d-a7730b6c9899	1b2fe4cc-3105-4e0b-b1ff-06f91c466ef7	6	5/1	2026-07-07 18:08:32.103+00
5a9e8ba9-2784-4057-b09c-4937f7febbae	8682004e-e186-4705-aa29-9704b2815dc4	34	33/1	2026-07-07 18:08:32.103+00
82071fad-2c96-4f33-a29d-102cc24e5b12	fcc03c57-8857-4986-98b0-0e30fb42ab2a	34	33/1	2026-07-07 18:08:32.103+00
d33887a5-a726-40e4-ae3f-8ede8ac1cce7	95b1e39e-97c3-4d45-9714-3f507d7c52f1	4.5	7/2	2026-07-07 23:15:11.541+00
0b6be7fb-e2d3-4ad3-8cb8-f045cfd0cac4	acfbd82a-7005-41b9-9613-606ceefc857e	34	33/1	2026-07-07 23:15:11.541+00
1cc6045d-9d37-4bf6-9952-cd89d49f9ffd	6ea9375b-d599-463f-96e6-c87d9209e9b2	5	4/1	2026-07-08 21:00:16.181+00
84f56371-248c-4229-a5a0-8df34752488c	95b1e39e-97c3-4d45-9714-3f507d7c52f1	5	4/1	2026-07-08 21:00:16.181+00
b0a022f2-94d4-4db8-946e-d5a88f7e2f78	1b2fe4cc-3105-4e0b-b1ff-06f91c466ef7	5.5	9/2	2026-07-08 21:00:16.181+00
30e1fc34-84fe-4e4d-9abe-2e07f5bcbd50	20e98c7a-4548-44f8-964d-7aba42ae7624	15	14/1	2026-07-08 21:00:16.181+00
1ec3a110-1e5d-4ba2-9471-5b91d2e2eed6	fcc03c57-8857-4986-98b0-0e30fb42ab2a	29	28/1	2026-07-08 21:00:16.181+00
01baffda-1cc3-46b7-8309-07090c33d6e2	f2c7a0c3-9a4c-4e3f-92a3-39abff0ce8e2	2.5	6/4	2026-07-10 06:46:45.711+00
032dfb56-563e-4c8c-9fd4-f4847466d480	6ea9375b-d599-463f-96e6-c87d9209e9b2	5.5	9/2	2026-07-10 06:46:45.711+00
b5e61b00-eea3-46e9-b714-d7cc7c09cc9b	95b1e39e-97c3-4d45-9714-3f507d7c52f1	5.5	9/2	2026-07-10 06:46:45.711+00
f56bd87e-98f6-4807-ae77-00cb6bcb2eca	6ea9375b-d599-463f-96e6-c87d9209e9b2	4.33	10/3	2026-07-11 10:23:08.702+00
70fe22bb-6fe5-413b-95f1-953fe6e82f5a	acfbd82a-7005-41b9-9613-606ceefc857e	41	40/1	2026-07-11 10:23:08.702+00
1d772b0d-38ad-4cf2-aca6-0db245075a5a	6ea9375b-d599-463f-96e6-c87d9209e9b2	4	3/1	2026-07-12 00:11:35.213+00
616077d1-6914-4c14-bc1f-8280a9b17fb9	1b2fe4cc-3105-4e0b-b1ff-06f91c466ef7	4	3/1	2026-07-12 00:11:35.213+00
021858c8-8ff0-4fb9-878f-222ebeafb7f5	acfbd82a-7005-41b9-9613-606ceefc857e	34	33/1	2026-07-12 00:11:35.213+00
0ea2b0da-d3b6-4a76-9657-545406efcbc9	1b2fe4cc-3105-4e0b-b1ff-06f91c466ef7	4.33	10/3	2026-07-12 08:29:35.443+00
4f9727b5-4d34-482d-967b-e1c879cc3954	95b1e39e-97c3-4d45-9714-3f507d7c52f1	5	4/1	2026-07-12 08:29:35.443+00
abc4d30e-91f3-4bd1-8822-0ff4b4806722	f2c7a0c3-9a4c-4e3f-92a3-39abff0ce8e2	2.38	11/8	2026-07-14 18:13:49.969+00
d5a7684f-9b3f-4523-8018-50b20cdaf5d0	1b2fe4cc-3105-4e0b-b1ff-06f91c466ef7	4	3/1	2026-07-14 18:13:49.969+00
62e86926-d911-48e3-9545-d07d844c6b09	6ea9375b-d599-463f-96e6-c87d9209e9b2	1.91	10/11	2026-07-14 20:25:42.493+00
78b6f07e-f7cd-4179-ae82-6a1accf8eab4	1b2fe4cc-3105-4e0b-b1ff-06f91c466ef7	3.75	11/4	2026-07-14 20:25:42.493+00
41c6b740-1106-4934-983a-08689bef8586	95b1e39e-97c3-4d45-9714-3f507d7c52f1	4.5	7/2	2026-07-14 20:25:42.493+00
3686d658-7af2-4027-9b1f-308ccfaa840c	f2c7a0c3-9a4c-4e3f-92a3-39abff0ce8e2	13	12/1	2026-07-14 20:25:42.493+00
bb50f5b3-86dd-4876-ac31-5f2a450178ce	6ea9375b-d599-463f-96e6-c87d9209e9b2	1.7	4/6	2026-07-15 06:28:38.911+00
d7b8702d-9f09-4c1f-a312-962ce4762a7a	95b1e39e-97c3-4d45-9714-3f507d7c52f1	5	4/1	2026-07-15 06:28:38.911+00
ad5b01ce-ad91-4fa8-9f6c-2298e8b32314	6ea9375b-d599-463f-96e6-c87d9209e9b2	1.62	8/13	2026-07-15 21:09:13.201+00
d686862e-6b99-4a42-a352-9bd59380d3e6	95b1e39e-97c3-4d45-9714-3f507d7c52f1	2.2	6/5	2026-07-15 21:09:13.201+00
\.


--
-- Data for Name: teams; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.teams (id, name, flag_emoji, is_longshot, odds_rank, created_at, pot, is_eliminated, band, eliminated_in_round_id, bracket_half) FROM stdin;
9507020f-6157-4043-ae5b-72ca12dea41e	South Africa	🇿🇦	t	48	2026-04-08 22:32:34.951662+00	4	t	no_hoper	5f39c536-340b-4981-b59a-4a9d7aff9e1e	top
910a4a31-591d-4c32-8b57-b0d0bbde5a26	Sweden	🇸🇪	f	24	2026-04-06 07:37:04.039369+00	4	t	long_shot	5f39c536-340b-4981-b59a-4a9d7aff9e1e	top
cd984ce3-2f2c-41d5-a7ba-137060caf8ae	Ecuador	🇪🇨	f	19	2026-04-06 07:37:04.039369+00	2	t	dark_horse	5f39c536-340b-4981-b59a-4a9d7aff9e1e	bottom
a681c714-630a-487f-b167-9cefea486591	DR Congo	🇨🇩	t	38	2026-04-08 22:32:34.951662+00	4	t	no_hoper	5f39c536-340b-4981-b59a-4a9d7aff9e1e	bottom
b6afbe52-5067-4263-a750-6101f6efedc0	Algeria	🇩🇿	f	39	2026-04-06 07:37:04.039369+00	3	t	long_shot	5f39c536-340b-4981-b59a-4a9d7aff9e1e	bottom
1270b02b-ff92-4068-a52e-ae90bcae805b	Cape Verde	🇨🇻	t	46	2026-04-08 22:32:34.951662+00	4	t	no_hoper	5f39c536-340b-4981-b59a-4a9d7aff9e1e	bottom
e171e736-56f2-44fa-92b5-b0653ea2ce2a	Colombia	🇨🇴	f	12	2026-04-06 07:37:04.039369+00	2	t	dark_horse	27ce4fc5-3de9-4cf0-bfc5-5fa0addb7081	bottom
d6209663-7a5c-4736-b346-cde299b554b2	Czech Rep	🇨🇿	t	28	2026-04-08 22:32:34.951662+00	3	t	long_shot	5b9456a0-db45-445f-87a0-58737bb89313	\N
600575e1-d737-452a-abec-c6e22da92787	Qatar	🇶🇦	t	47	2026-04-06 07:37:04.039369+00	3	t	no_hoper	5b9456a0-db45-445f-87a0-58737bb89313	\N
7f560d60-00fc-46e1-b81b-4e7234b7cb04	Haiti	🇭🇹	t	44	2026-04-08 22:32:34.951662+00	4	t	no_hoper	5b9456a0-db45-445f-87a0-58737bb89313	\N
87881cf2-7a14-4afa-9912-0ef5b2672387	Turkey	🇹🇷	f	26	2026-04-06 07:37:04.039369+00	4	t	long_shot	5b9456a0-db45-445f-87a0-58737bb89313	\N
a760ffb3-5775-4d7d-b803-cf0087525d91	New Zealand	🇳🇿	t	42	2026-04-06 07:37:04.039369+00	4	t	no_hoper	5b9456a0-db45-445f-87a0-58737bb89313	\N
622bb3ef-bc6e-4c9a-9efe-aae4d0f95822	Saudi Arabia	🇸🇦	t	33	2026-04-06 07:37:04.039369+00	3	t	no_hoper	5b9456a0-db45-445f-87a0-58737bb89313	\N
f959649f-d7be-48e3-9129-58e7fc519606	Iran	🇮🇷	f	32	2026-04-06 07:37:04.039369+00	2	t	no_hoper	5b9456a0-db45-445f-87a0-58737bb89313	\N
8d109cbf-133f-496a-b5b7-3f75a0ec1dcd	Panama	🇵🇦	t	45	2026-04-06 07:37:04.039369+00	3	t	no_hoper	5b9456a0-db45-445f-87a0-58737bb89313	\N
ef919163-49fb-4cc5-ab4e-f55d9419d806	Uzbekistan	🇺🇿	t	39	2026-04-08 22:32:34.951662+00	4	t	no_hoper	5b9456a0-db45-445f-87a0-58737bb89313	\N
acfbd82a-7005-41b9-9613-606ceefc857e	Switzerland	🇨🇭	f	20	2026-04-06 07:37:04.039369+00	2	t	dark_horse	aa9754bd-50eb-4785-8698-e56c6d3cb661	bottom
cffa413c-8c76-45a6-843e-87c34e78e45a	Germany	🇩🇪	f	6	2026-04-06 07:37:04.039369+00	1	t	favourite	5f39c536-340b-4981-b59a-4a9d7aff9e1e	top
151a98cf-99e8-4e7a-ab57-396a13db4a72	Senegal	🇸🇳	f	18	2026-04-06 07:37:04.039369+00	2	t	dark_horse	5f39c536-340b-4981-b59a-4a9d7aff9e1e	top
4976e7fd-9b45-4cc7-b741-fe801fcee2d0	Bosnia/Herzeg	🇧🇦	t	31	2026-04-08 22:32:34.951662+00	4	t	long_shot	5f39c536-340b-4981-b59a-4a9d7aff9e1e	top
666ba168-4d8b-4060-8e4b-e1dd7b2a7503	Curaçao	🇨🇼	t	45	2026-04-08 22:32:34.951662+00	4	t	no_hoper	5b9456a0-db45-445f-87a0-58737bb89313	\N
ee8ecff9-d0b1-4aa8-ab21-da08a6c9229a	Uruguay	🇺🇾	f	11	2026-04-06 07:37:04.039369+00	2	t	dark_horse	5b9456a0-db45-445f-87a0-58737bb89313	\N
52f066d8-0a7a-42c5-8a6b-103ec4ba2c91	Scotland	🏴󠁧󠁢󠁳󠁣󠁴󠁿	f	26	2026-04-08 22:32:34.951662+00	3	t	long_shot	5b9456a0-db45-445f-87a0-58737bb89313	\N
20160ec3-c507-4fb3-b19d-89cb66c59a98	South Korea	🇰🇷	t	23	2026-04-06 07:37:04.039369+00	2	t	long_shot	5b9456a0-db45-445f-87a0-58737bb89313	\N
66a8014f-0009-400e-928c-6b28cb8dab1f	Japan	🇯🇵	f	16	2026-04-06 07:37:04.039369+00	2	t	dark_horse	5f39c536-340b-4981-b59a-4a9d7aff9e1e	bottom
54ef8b7c-5afd-4a48-a3b9-d6701dd757f9	Ivory Coast	🇨🇮	f	37	2026-04-06 07:37:04.039369+00	3	t	long_shot	5f39c536-340b-4981-b59a-4a9d7aff9e1e	bottom
c8e5c035-af92-4497-b96c-82f2c0a15214	Paraguay	🇵🇾	f	27	2026-04-08 22:32:34.951662+00	4	t	long_shot	27ce4fc5-3de9-4cf0-bfc5-5fa0addb7081	top
6527ec07-bc6b-4b53-8bff-90b6f622aece	USA	🇺🇸	f	14	2026-04-06 07:37:04.039369+00	1	t	dark_horse	27ce4fc5-3de9-4cf0-bfc5-5fa0addb7081	top
ddd77a2f-eb9f-4a20-8ae4-e1ca55c21893	Egypt	🇪🇬	f	34	2026-04-06 07:37:04.039369+00	3	t	long_shot	27ce4fc5-3de9-4cf0-bfc5-5fa0addb7081	bottom
8682004e-e186-4705-aa29-9704b2815dc4	Belgium	🇧🇪	f	9	2026-04-06 07:37:04.039369+00	1	t	dark_horse	aa9754bd-50eb-4785-8698-e56c6d3cb661	top
20e98c7a-4548-44f8-964d-7aba42ae7624	Norway	🇳🇴	f	9	2026-04-08 22:32:34.951662+00	3	t	dark_horse	aa9754bd-50eb-4785-8698-e56c6d3cb661	bottom
f2c7a0c3-9a4c-4e3f-92a3-39abff0ce8e2	France	🇫🇷	f	2	2026-04-06 07:37:04.039369+00	1	t	favourite	6aa7c75c-0fc8-46f0-8219-84f969510a0e	top
1b2fe4cc-3105-4e0b-b1ff-06f91c466ef7	England	🏴󠁧󠁢󠁥󠁮󠁧󠁿	f	3	2026-04-06 07:37:04.039369+00	1	t	favourite	6aa7c75c-0fc8-46f0-8219-84f969510a0e	bottom
95b1e39e-97c3-4d45-9714-3f507d7c52f1	Argentina	🇦🇷	f	5	2026-04-06 07:37:04.039369+00	1	t	favourite	b9bd6954-7f07-432a-af76-2dc2d3e9ab1f	bottom
2044181c-c7e7-4759-8101-4779166812e3	Netherlands	🇳🇱	f	8	2026-04-06 07:37:04.039369+00	1	t	favourite	5f39c536-340b-4981-b59a-4a9d7aff9e1e	top
a1cbc3f2-826a-4c04-803b-b5c2930d3c42	Tunisia	🇹🇳	t	40	2026-04-06 07:37:04.039369+00	3	t	long_shot	5b9456a0-db45-445f-87a0-58737bb89313	\N
f27875c8-4818-4323-8d45-333b7f82cf57	Iraq	🇮🇶	t	42	2026-04-08 22:32:34.951662+00	4	t	no_hoper	5b9456a0-db45-445f-87a0-58737bb89313	\N
aa0baf4e-af82-4020-9093-715971d63105	Jordan	🇯🇴	t	40	2026-04-08 22:32:34.951662+00	4	t	no_hoper	5b9456a0-db45-445f-87a0-58737bb89313	\N
8cccecd8-b1ab-4159-bf35-29ef0db369c4	Croatia	🇭🇷	f	13	2026-04-06 07:37:04.039369+00	2	t	dark_horse	5f39c536-340b-4981-b59a-4a9d7aff9e1e	top
f99d6725-238c-4d95-8502-9d25b4a6e89e	Australia	🇦🇺	t	25	2026-04-06 07:37:04.039369+00	2	t	long_shot	5f39c536-340b-4981-b59a-4a9d7aff9e1e	bottom
6ea9375b-d599-463f-96e6-c87d9209e9b2	Spain	🇪🇸	f	4	2026-04-06 07:37:04.039369+00	1	f	favourite	\N	top
52eaa3b4-081b-4393-b291-d69c644c612e	Austria	🇦🇹	f	22	2026-04-06 07:37:04.039369+00	2	t	long_shot	5f39c536-340b-4981-b59a-4a9d7aff9e1e	top
61d8b501-96d1-4043-a2b7-de27e9b137d7	Ghana	🇬🇭	t	38	2026-04-06 07:37:04.039369+00	4	t	long_shot	5f39c536-340b-4981-b59a-4a9d7aff9e1e	bottom
4f0f3776-f99f-4c06-9eb4-0acd2825d8c2	Canada	🇨🇦	f	46	2026-04-06 07:37:04.039369+00	1	t	long_shot	27ce4fc5-3de9-4cf0-bfc5-5fa0addb7081	top
cba2c884-3603-4b90-976e-49389b04f562	Brazil	🇧🇷	f	1	2026-04-06 07:37:04.039369+00	1	t	favourite	27ce4fc5-3de9-4cf0-bfc5-5fa0addb7081	bottom
e176dd2c-4446-4811-b4cc-fc28e9c2ab25	Mexico	🇲🇽	f	15	2026-04-06 07:37:04.039369+00	1	t	dark_horse	27ce4fc5-3de9-4cf0-bfc5-5fa0addb7081	bottom
eaca3063-d90c-4007-b3d8-ba829b3ee14e	Portugal	🇵🇹	f	7	2026-04-06 07:37:04.039369+00	1	t	favourite	27ce4fc5-3de9-4cf0-bfc5-5fa0addb7081	top
fcc03c57-8857-4986-98b0-0e30fb42ab2a	Morocco	🇲🇦	f	17	2026-04-06 07:37:04.039369+00	2	t	dark_horse	aa9754bd-50eb-4785-8698-e56c6d3cb661	top
\.


--
-- Name: admin_users admin_users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_users
    ADD CONSTRAINT admin_users_pkey PRIMARY KEY (id);


--
-- Name: admin_users admin_users_username_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_users
    ADD CONSTRAINT admin_users_username_key UNIQUE (username);


--
-- Name: app_config app_config_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_config
    ADD CONSTRAINT app_config_pkey PRIMARY KEY (key);


--
-- Name: bracket_predictions bracket_predictions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bracket_predictions
    ADD CONSTRAINT bracket_predictions_pkey PRIMARY KEY (id);


--
-- Name: default_pool default_pool_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.default_pool
    ADD CONSTRAINT default_pool_pkey PRIMARY KEY (id);


--
-- Name: default_pool default_pool_priority_order_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.default_pool
    ADD CONSTRAINT default_pool_priority_order_key UNIQUE (priority_order);


--
-- Name: ko_progression ko_progression_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ko_progression
    ADD CONSTRAINT ko_progression_pkey PRIMARY KEY (match_number);


--
-- Name: leaderboard_snapshots leaderboard_snapshots_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.leaderboard_snapshots
    ADD CONSTRAINT leaderboard_snapshots_pkey PRIMARY KEY (id);


--
-- Name: leaderboard_snapshots leaderboard_snapshots_round_id_player_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.leaderboard_snapshots
    ADD CONSTRAINT leaderboard_snapshots_round_id_player_id_key UNIQUE (round_id, player_id);


--
-- Name: matches matches_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.matches
    ADD CONSTRAINT matches_pkey PRIMARY KEY (id);


--
-- Name: pick_results pick_results_pick_id_match_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pick_results
    ADD CONSTRAINT pick_results_pick_id_match_id_key UNIQUE (pick_id, match_id);


--
-- Name: pick_results pick_results_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pick_results
    ADD CONSTRAINT pick_results_pkey PRIMARY KEY (id);


--
-- Name: picks picks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.picks
    ADD CONSTRAINT picks_pkey PRIMARY KEY (id);


--
-- Name: picks picks_player_id_round_id_multiplier_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.picks
    ADD CONSTRAINT picks_player_id_round_id_multiplier_key UNIQUE (player_id, round_id, multiplier);


--
-- Name: picks picks_player_id_team_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.picks
    ADD CONSTRAINT picks_player_id_team_id_key UNIQUE (player_id, team_id);


--
-- Name: players players_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.players
    ADD CONSTRAINT players_pkey PRIMARY KEY (id);


--
-- Name: players players_slug_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.players
    ADD CONSTRAINT players_slug_key UNIQUE (slug);


--
-- Name: push_subscriptions push_subscriptions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.push_subscriptions
    ADD CONSTRAINT push_subscriptions_pkey PRIMARY KEY (id);


--
-- Name: push_subscriptions push_subscriptions_player_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.push_subscriptions
    ADD CONSTRAINT push_subscriptions_player_id_key UNIQUE (player_id);


--
-- Name: rounds rounds_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rounds
    ADD CONSTRAINT rounds_pkey PRIMARY KEY (id);


--
-- Name: team_odds team_odds_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.team_odds
    ADD CONSTRAINT team_odds_pkey PRIMARY KEY (id);


--
-- Name: teams teams_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.teams
    ADD CONSTRAINT teams_name_key UNIQUE (name);


--
-- Name: teams teams_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.teams
    ADD CONSTRAINT teams_pkey PRIMARY KEY (id);


--
-- Name: idx_matches_kickoff; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_matches_kickoff ON public.matches USING btree (kickoff);


--
-- Name: idx_matches_round_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_matches_round_id ON public.matches USING btree (round_id);


--
-- Name: idx_pick_results_pick_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_pick_results_pick_id ON public.pick_results USING btree (pick_id);


--
-- Name: idx_picks_player_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_picks_player_id ON public.picks USING btree (player_id);


--
-- Name: idx_picks_round_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_picks_round_id ON public.picks USING btree (round_id);


--
-- Name: idx_picks_team_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_picks_team_id ON public.picks USING btree (team_id);


--
-- Name: idx_players_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_players_slug ON public.players USING btree (slug);


--
-- Name: players notify-goals-prediction; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER "notify-goals-prediction" AFTER UPDATE ON public.players FOR EACH ROW EXECUTE FUNCTION supabase_functions.http_request('https://jrdjdqjepffdcjdfuarc.supabase.co/functions/v1/notify-pick', 'POST', '{"Content-type":"application/json","Authorization":"Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpyZGpkcWplcGZmZGNqZGZ1YXJjIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NTQ1NzMxNywiZXhwIjoyMDkxMDMzMzE3fQ.-hzlKgGlIW6W6DawFXonSahuxoAQK-V2qZBCHu7A-5E"}', '{}', '5000');


--
-- Name: picks notify-pick; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER "notify-pick" AFTER INSERT ON public.picks FOR EACH ROW EXECUTE FUNCTION supabase_functions.http_request('https://jrdjdqjepffdcjdfuarc.supabase.co/functions/v1/notify-pick', 'POST', '{"Content-type":"application/json","Authorization":"Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpyZGpkcWplcGZmZGNqZGZ1YXJjIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NTQ1NzMxNywiZXhwIjoyMDkxMDMzMzE3fQ.-hzlKgGlIW6W6DawFXonSahuxoAQK-V2qZBCHu7A-5E"}', '{}', '5000');


--
-- Name: default_pool default_pool_team_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.default_pool
    ADD CONSTRAINT default_pool_team_id_fkey FOREIGN KEY (team_id) REFERENCES public.teams(id);


--
-- Name: leaderboard_snapshots leaderboard_snapshots_player_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.leaderboard_snapshots
    ADD CONSTRAINT leaderboard_snapshots_player_id_fkey FOREIGN KEY (player_id) REFERENCES public.players(id);


--
-- Name: leaderboard_snapshots leaderboard_snapshots_round_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.leaderboard_snapshots
    ADD CONSTRAINT leaderboard_snapshots_round_id_fkey FOREIGN KEY (round_id) REFERENCES public.rounds(id);


--
-- Name: matches matches_away_team_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.matches
    ADD CONSTRAINT matches_away_team_id_fkey FOREIGN KEY (away_team_id) REFERENCES public.teams(id);


--
-- Name: matches matches_home_team_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.matches
    ADD CONSTRAINT matches_home_team_id_fkey FOREIGN KEY (home_team_id) REFERENCES public.teams(id);


--
-- Name: matches matches_pens_winner_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.matches
    ADD CONSTRAINT matches_pens_winner_id_fkey FOREIGN KEY (pens_winner_id) REFERENCES public.teams(id);


--
-- Name: matches matches_round_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.matches
    ADD CONSTRAINT matches_round_id_fkey FOREIGN KEY (round_id) REFERENCES public.rounds(id) ON DELETE CASCADE;


--
-- Name: pick_results pick_results_match_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pick_results
    ADD CONSTRAINT pick_results_match_id_fkey FOREIGN KEY (match_id) REFERENCES public.matches(id) ON DELETE CASCADE;


--
-- Name: pick_results pick_results_pick_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pick_results
    ADD CONSTRAINT pick_results_pick_id_fkey FOREIGN KEY (pick_id) REFERENCES public.picks(id) ON DELETE CASCADE;


--
-- Name: picks picks_player_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.picks
    ADD CONSTRAINT picks_player_id_fkey FOREIGN KEY (player_id) REFERENCES public.players(id) ON DELETE CASCADE;


--
-- Name: picks picks_round_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.picks
    ADD CONSTRAINT picks_round_id_fkey FOREIGN KEY (round_id) REFERENCES public.rounds(id) ON DELETE CASCADE;


--
-- Name: picks picks_team_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.picks
    ADD CONSTRAINT picks_team_id_fkey FOREIGN KEY (team_id) REFERENCES public.teams(id);


--
-- Name: players players_eliminated_in_round_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.players
    ADD CONSTRAINT players_eliminated_in_round_id_fkey FOREIGN KEY (eliminated_in_round_id) REFERENCES public.rounds(id);


--
-- Name: push_subscriptions push_subscriptions_player_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.push_subscriptions
    ADD CONSTRAINT push_subscriptions_player_id_fkey FOREIGN KEY (player_id) REFERENCES public.players(id) ON DELETE CASCADE;


--
-- Name: team_odds team_odds_team_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.team_odds
    ADD CONSTRAINT team_odds_team_id_fkey FOREIGN KEY (team_id) REFERENCES public.teams(id);


--
-- Name: teams teams_eliminated_in_round_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.teams
    ADD CONSTRAINT teams_eliminated_in_round_id_fkey FOREIGN KEY (eliminated_in_round_id) REFERENCES public.rounds(id);


--
-- Name: matches Allow all inserts on matches; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all inserts on matches" ON public.matches FOR INSERT WITH CHECK (true);


--
-- Name: pick_results Allow all inserts on pick_results; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all inserts on pick_results" ON public.pick_results FOR INSERT WITH CHECK (true);


--
-- Name: picks Allow all inserts on picks; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all inserts on picks" ON public.picks FOR INSERT WITH CHECK (true);


--
-- Name: players Allow all inserts on players; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all inserts on players" ON public.players FOR INSERT WITH CHECK (true);


--
-- Name: rounds Allow all inserts on rounds; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all inserts on rounds" ON public.rounds FOR INSERT WITH CHECK (true);


--
-- Name: matches Allow all updates on matches; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all updates on matches" ON public.matches FOR UPDATE USING (true);


--
-- Name: pick_results Allow all updates on pick_results; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all updates on pick_results" ON public.pick_results FOR UPDATE USING (true);


--
-- Name: picks Allow all updates on picks; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all updates on picks" ON public.picks FOR UPDATE USING (true);


--
-- Name: players Allow all updates on players; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all updates on players" ON public.players FOR UPDATE USING (true);


--
-- Name: rounds Allow all updates on rounds; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all updates on rounds" ON public.rounds FOR UPDATE USING (true);


--
-- Name: teams Allow all updates on teams; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow all updates on teams" ON public.teams FOR UPDATE USING (true);


--
-- Name: bracket_predictions Allow anon delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon delete" ON public.bracket_predictions FOR DELETE USING (true);


--
-- Name: leaderboard_snapshots Allow anon delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon delete" ON public.leaderboard_snapshots FOR DELETE TO anon USING (true);


--
-- Name: matches Allow anon delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon delete" ON public.matches FOR DELETE TO anon USING (true);


--
-- Name: pick_results Allow anon delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon delete" ON public.pick_results FOR DELETE TO anon USING (true);


--
-- Name: picks Allow anon delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon delete" ON public.picks FOR DELETE TO anon USING (true);


--
-- Name: players Allow anon delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon delete" ON public.players FOR DELETE TO anon USING (true);


--
-- Name: rounds Allow anon delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon delete" ON public.rounds FOR UPDATE TO anon USING (true);


--
-- Name: teams Allow anon delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon delete" ON public.teams FOR UPDATE TO anon USING (true);


--
-- Name: leaderboard_snapshots Allow anon insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon insert" ON public.leaderboard_snapshots FOR INSERT TO anon WITH CHECK (true);


--
-- Name: pick_results Allow anon insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon insert" ON public.pick_results FOR INSERT TO anon WITH CHECK (true);


--
-- Name: picks Allow anon insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon insert" ON public.picks FOR INSERT TO anon WITH CHECK (true);


--
-- Name: team_odds Allow anon insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon insert" ON public.team_odds FOR INSERT TO anon WITH CHECK (true);


--
-- Name: leaderboard_snapshots Allow anon select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon select" ON public.leaderboard_snapshots FOR SELECT TO anon USING (true);


--
-- Name: matches Allow anon select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon select" ON public.matches FOR SELECT TO anon USING (true);


--
-- Name: pick_results Allow anon select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon select" ON public.pick_results FOR SELECT TO anon USING (true);


--
-- Name: picks Allow anon select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon select" ON public.picks FOR SELECT TO anon USING (true);


--
-- Name: players Allow anon select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon select" ON public.players FOR SELECT TO anon USING (true);


--
-- Name: rounds Allow anon select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon select" ON public.rounds FOR SELECT TO anon USING (true);


--
-- Name: team_odds Allow anon select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon select" ON public.team_odds FOR SELECT TO anon USING (true);


--
-- Name: teams Allow anon select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon select" ON public.teams FOR SELECT TO anon USING (true);


--
-- Name: leaderboard_snapshots Allow anon update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon update" ON public.leaderboard_snapshots FOR UPDATE TO anon USING (true) WITH CHECK (true);


--
-- Name: players Allow anon update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon update" ON public.players FOR UPDATE TO anon USING (true) WITH CHECK (true);


--
-- Name: rounds Allow anon update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon update" ON public.rounds FOR UPDATE TO anon USING (true) WITH CHECK (true);


--
-- Name: teams Allow anon update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon update" ON public.teams FOR UPDATE TO anon USING (true) WITH CHECK (true);


--
-- Name: pick_results Allow anon upsert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow anon upsert" ON public.pick_results FOR UPDATE TO anon USING (true) WITH CHECK (true);


--
-- Name: picks Allow delete own picks; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow delete own picks" ON public.picks FOR DELETE USING (true);


--
-- Name: bracket_predictions Anon insert bracket_predictions; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Anon insert bracket_predictions" ON public.bracket_predictions FOR INSERT WITH CHECK (true);


--
-- Name: pick_results Public delete pick_results; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Public delete pick_results" ON public.pick_results FOR DELETE USING (true);


--
-- Name: picks Public delete picks; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Public delete picks" ON public.picks FOR DELETE USING (true);


--
-- Name: pick_results Public insert pick_results; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Public insert pick_results" ON public.pick_results FOR INSERT WITH CHECK (true);


--
-- Name: picks Public insert picks; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Public insert picks" ON public.picks FOR INSERT WITH CHECK (true);


--
-- Name: teams Public read access; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Public read access" ON public.teams FOR SELECT USING (true);


--
-- Name: bracket_predictions Public read bracket_predictions; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Public read bracket_predictions" ON public.bracket_predictions FOR SELECT USING (true);


--
-- Name: default_pool Public read default_pool; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Public read default_pool" ON public.default_pool FOR SELECT USING (true);


--
-- Name: matches Public read matches; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Public read matches" ON public.matches FOR SELECT USING (true);


--
-- Name: pick_results Public read pick_results; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Public read pick_results" ON public.pick_results FOR SELECT USING (true);


--
-- Name: picks Public read picks; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Public read picks" ON public.picks FOR SELECT USING (true);


--
-- Name: players Public read players; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Public read players" ON public.players FOR SELECT USING (true);


--
-- Name: rounds Public read rounds; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Public read rounds" ON public.rounds FOR SELECT USING (true);


--
-- Name: teams Public read teams; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Public read teams" ON public.teams FOR SELECT USING (true);


--
-- Name: pick_results Public update pick_results; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Public update pick_results" ON public.pick_results FOR UPDATE USING (true);


--
-- Name: push_subscriptions anon insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "anon insert" ON public.push_subscriptions FOR INSERT WITH CHECK (true);


--
-- Name: ko_progression anon read ko_progression; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "anon read ko_progression" ON public.ko_progression FOR SELECT USING (true);


--
-- Name: push_subscriptions anon update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "anon update" ON public.push_subscriptions FOR UPDATE USING (true) WITH CHECK (true);


--
-- Name: app_config anon_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY anon_read ON public.app_config FOR SELECT USING (true);


--
-- Name: app_config anon_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY anon_update ON public.app_config FOR UPDATE USING (true);


--
-- Name: app_config; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.app_config ENABLE ROW LEVEL SECURITY;

--
-- Name: bracket_predictions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.bracket_predictions ENABLE ROW LEVEL SECURITY;

--
-- Name: default_pool; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.default_pool ENABLE ROW LEVEL SECURITY;

--
-- Name: ko_progression; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.ko_progression ENABLE ROW LEVEL SECURITY;

--
-- Name: leaderboard_snapshots; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.leaderboard_snapshots ENABLE ROW LEVEL SECURITY;

--
-- Name: matches; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.matches ENABLE ROW LEVEL SECURITY;

--
-- Name: pick_results; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.pick_results ENABLE ROW LEVEL SECURITY;

--
-- Name: picks; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.picks ENABLE ROW LEVEL SECURITY;

--
-- Name: players; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.players ENABLE ROW LEVEL SECURITY;

--
-- Name: push_subscriptions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.push_subscriptions ENABLE ROW LEVEL SECURITY;

--
-- Name: rounds; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.rounds ENABLE ROW LEVEL SECURITY;

--
-- Name: teams; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.teams ENABLE ROW LEVEL SECURITY;

--
-- PostgreSQL database dump complete
--

\unrestrict 8NzBRQ5s6svd2ndhIUr7AWE7Cz9Xp3hAdomNu35OX1lHQdCu1kfcOoodF0fq5K6

