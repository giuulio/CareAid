-- Synthetic seed data. Every person, condition and event here is invented.
-- CLAUDE.md §2, rule 2: no real patient data, ever.
--
-- Idempotent and re-runnable — truncate then insert. Expect to run this
-- twenty times tonight.
--
-- Dates are RELATIVE to the day you run it, so "last night" is always last
-- night no matter when the demo happens. The one exception is Dr Okafor's
-- appointment, which CLAUDE.md pins to 14 August.

begin;

truncate table artifact, timeline_event, brief, capture,
               medication, circle_member, caregiver, recipient
  restart identity cascade;

-- Helpers. Everything on screen is Europe/London; everything stored is UTC.
create or replace function seed_ts(days_ago int, at_time time)
returns timestamptz language sql stable as $$
  select ((((now() at time zone 'Europe/London')::date - days_ago)::timestamp + at_time)
          at time zone 'Europe/London');
$$;

create or replace function seed_date(days_ago int)
returns text language sql stable as $$
  select to_char((now() at time zone 'Europe/London')::date - days_ago, 'YYYY-MM-DD');
$$;

-- ---------------------------------------------------------------- people --

-- Margaret Ellis, 78. UUID must match Config.recipientID.
insert into recipient (id, display_name, legal_name, year_of_birth,
                       conditions, allergies, gp_practice)
values ('11111111-1111-4111-8111-111111111111',
        'Mum', 'Margaret Ellis', 1948,
        array['Parkinson''s disease (diagnosed 2021)', 'Atrial fibrillation'],
        array['Penicillin'],
        'Fairfield Road Surgery');

-- Sarah, 52, daughter. The app user. UUID must match Config.caregiverID.
-- work_hours are the blocks she is NOT available to hand over pills — this is
-- what C12 schedules around.
insert into caregiver (id, name, relation, work_hours)
values ('22222222-2222-4222-8222-222222222222',
        'Sarah', 'daughter',
        jsonb_build_object('blocks', jsonb_build_array(
          jsonb_build_object('label','Work','days',jsonb_build_array('mon','tue','wed','thu','fri'),
                             'start','09:00:00','end','17:30:00'),
          jsonb_build_object('label','Standup','days',jsonb_build_array('mon','tue','wed','thu','fri'),
                             'start','09:00:00','end','09:30:00'),
          jsonb_build_object('label','Commute','days',jsonb_build_array('mon','tue','wed','thu','fri'),
                             'start','08:00:00','end','09:00:00')
        )));

-- Joy, paid carer. Sits in `caregiver` because her visit windows are a
-- scheduling input for C12 ("cluster on meals and Joy's visits"), and this is
-- the only field in §6 that holds availability. She is also a circle_member
-- below, because Sarah can message her. Two rows, two different jobs.
insert into caregiver (id, name, relation, work_hours)
values ('22222222-2222-4222-8222-000000000002',
        'Joy', 'paid carer',
        jsonb_build_object('blocks', jsonb_build_array(
          jsonb_build_object('label','Morning visit',
                             'days',jsonb_build_array('mon','tue','wed','thu','fri','sat','sun'),
                             'start','07:30:00','end','08:15:00'),
          jsonb_build_object('label','Evening visit',
                             'days',jsonb_build_array('mon','tue','wed','thu','fri','sat','sun'),
                             'start','18:00:00','end','18:45:00')
        )));

insert into circle_member (id, recipient_id, name, relation, channel, handle, share_level) values
  ('33333333-3333-4333-8333-000000000001', '11111111-1111-4111-8111-111111111111',
   'Tom', 'son', 'whatsapp', '+447700900123', 'summary'),
  ('33333333-3333-4333-8333-000000000002', '11111111-1111-4111-8111-111111111111',
   'Joy', 'paid carer', 'sms', '+447700900456', 'headline');

-- ----------------------------------------------------------- medications --

-- Realistic Parkinson's + AF polypharmacy.
--
-- rxcui values are the ones `tools/dailymed_extract.py` actually resolved from
-- RxNorm when it built medication_rules.json — not invented. They are what
-- RuleStore matches on, so a medication renamed on screen still finds its
-- label. Change one only by re-running that script.
--
-- Levothyroxine and Adcal-D3 are both at 08:00 on purpose. That is the
-- separation conflict C12 is built to notice — and it must produce a question
-- for the pharmacist, never a schedule change (CLAUDE.md §2, rule 1).
insert into medication (id, recipient_id, name, rxcui, dose, schedule, scheduled_times,
                        quantity_remaining, started_on, active) values
  ('44444444-4444-4444-8444-000000000001', '11111111-1111-4111-8111-111111111111',
   'Co-careldopa (Sinemet)', '103990', '25/100mg', '4x daily: 8am, 12pm, 4pm, 8pm',
   array['08:00','12:00','16:00','20:00']::time[], 96, date '2021-04-12', true),
  ('44444444-4444-4444-8444-000000000002', '11111111-1111-4111-8111-111111111111',
   'Entacapone', '60307', '200mg', 'With each co-careldopa dose',
   array['08:00','12:00','16:00','20:00']::time[], 88, date '2023-02-06', true),
  ('44444444-4444-4444-8444-000000000003', '11111111-1111-4111-8111-111111111111',
   'Rasagiline', '134748', '1mg', 'Once daily, morning',
   array['08:00']::time[], 22, date '2021-06-01', true),
  ('44444444-4444-4444-8444-000000000004', '11111111-1111-4111-8111-111111111111',
   'Apixaban', '1364430', '5mg', 'Twice daily, morning and evening',
   array['08:00','20:00']::time[], 44, date '2019-11-18', true),
  ('44444444-4444-4444-8444-000000000005', '11111111-1111-4111-8111-111111111111',
   'Bisoprolol', '142146', '2.5mg', 'Once daily, morning',
   array['08:00']::time[], 19, date '2019-11-18', true),
  ('44444444-4444-4444-8444-000000000006', '11111111-1111-4111-8111-111111111111',
   'Atorvastatin', '83367', '20mg', 'Once daily, evening',
   array['20:00']::time[], 27, date '2020-03-02', true),
  ('44444444-4444-4444-8444-000000000007', '11111111-1111-4111-8111-111111111111',
   'Levothyroxine', '10582', '50mcg', 'Once daily, before breakfast',
   array['08:00']::time[], 25, date '2018-09-14', true),
  ('44444444-4444-4444-8444-000000000008', '11111111-1111-4111-8111-111111111111',
   'Adcal-D3', '608343', '1500mg/400iu', 'Twice daily, morning and evening',
   array['08:00','20:00']::time[], 51, date '2022-01-10', true),

  -- The rest of the box. Fifteen medicines is ordinary for a 78-year-old with
  -- Parkinson's and AF, and the point of listing them all is that the caregiver
  -- is holding every one of them in her head.
  --
  -- rxcui is null on these: the eight above carry the codes
  -- `tools/dailymed_extract.py` actually resolved, and inventing one here would
  -- make RuleStore claim a label it never read.
  ('44444444-4444-4444-8444-000000000009', '11111111-1111-4111-8111-111111111111',
   'Amlodipine', null, '5mg', 'Once daily, morning',
   array['08:00']::time[], 31, date '2017-05-22', true),
  ('44444444-4444-4444-8444-000000000010', '11111111-1111-4111-8111-111111111111',
   'Omeprazole', null, '20mg', 'Once daily, before breakfast',
   array['07:30']::time[], 12, date '2021-08-30', true),
  ('44444444-4444-4444-8444-000000000011', '11111111-1111-4111-8111-111111111111',
   'Domperidone', null, '10mg', 'Three times daily, before meals',
   array['08:00','12:00','16:00']::time[], 64, date '2021-05-04', true),
  ('44444444-4444-4444-8444-000000000012', '11111111-1111-4111-8111-111111111111',
   'Senna', null, '7.5mg', 'At night',
   array['22:00']::time[], 40, date '2022-11-03', true),
  ('44444444-4444-4444-8444-000000000013', '11111111-1111-4111-8111-111111111111',
   'Melatonin (modified release)', null, '2mg', 'One hour before bed',
   array['21:00']::time[], 16, date '2025-02-17', true),
  ('44444444-4444-4444-8444-000000000014', '11111111-1111-4111-8111-111111111111',
   'Macrogol (Laxido)', null, 'One sachet', 'Once daily, mid-morning',
   array['10:00']::time[], 23, date '2023-06-19', true),
  -- No scheduled_times on purpose: "when she needs it" is a real answer, and
  -- the medication list has to be able to show one.
  ('44444444-4444-4444-8444-000000000015', '11111111-1111-4111-8111-111111111111',
   'Paracetamol', null, '500mg', 'As needed, up to 4x daily',
   array[]::time[], 84, date '2019-01-08', true);

-- ------------------------------------------------------------- captures ---

-- Only the recent notable entries are linked to a capture. Older history is
-- backfilled and carries a null capture_id, which is what "imported from the
-- old notebook" looks like.
insert into capture (id, recipient_id, author_id, source, raw_text, captured_at, processed_at) values
  ('66666666-6666-4666-8666-000000000001', '11111111-1111-4111-8111-111111111111',
   '22222222-2222-4222-8222-222222222222', 'voice',
   'She was up in the night again, froze on the way to the bathroom and I had to help her back.',
   seed_ts(24,'07:40'), seed_ts(24,'07:41')),
  ('66666666-6666-4666-8666-000000000002', '11111111-1111-4111-8111-111111111111',
   '22222222-2222-4222-8222-222222222222', 'voice',
   'Evening tablet was still in the tray this morning. She''d gone to bed without it.',
   seed_ts(19,'08:05'), seed_ts(19,'08:06')),
  ('66666666-6666-4666-8666-000000000003', '11111111-1111-4111-8111-111111111111',
   '22222222-2222-4222-8222-222222222222', 'text',
   'Nearly went over reaching for the kettle. Caught herself on the worktop.',
   seed_ts(10,'19:20'), seed_ts(10,'19:21')),
  ('66666666-6666-4666-8666-000000000004', '11111111-1111-4111-8111-111111111111',
   '22222222-2222-4222-8222-222222222222', 'voice',
   'Same again with the evening one, still in the tray.',
   seed_ts(8,'08:10'), seed_ts(8,'08:11')),
  ('66666666-6666-4666-8666-000000000005', '11111111-1111-4111-8111-111111111111',
   '22222222-2222-4222-8222-222222222222', 'voice',
   'She was muddled this morning, didn''t know what day it was for a bit. Came right after breakfast.',
   seed_ts(7,'11:00'), seed_ts(7,'11:01'));

-- -------------------------------------------------------------- history ---

-- ~90 days of a tired caregiver's log. Not every dose — she records what
-- stands out. The arc: steady in the spring, sleep fraying through June,
-- night-time freezing from about three weeks ago, and the evening dose
-- starting to slip.
insert into timeline_event
  (recipient_id, capture_id, kind, occurred_at, headline, detail, severity, tags, confidence) values

-- Baseline: roughly 90 to 60 days ago
('11111111-1111-4111-8111-111111111111', null, 'admin',     seed_ts(88,'11:00'), 'Repeat prescription collected', null, 0, array['admin'], null),
('11111111-1111-4111-8111-111111111111', null, 'mood',      seed_ts(85,'15:30'), 'Good day, finished the crossword', null, 0, array['mood'], null),
('11111111-1111-4111-8111-111111111111', null, 'symptom',   seed_ts(82,'16:00'), 'Tremor more noticeable after lunch', 'Settled by teatime.', 1, array['tremor'], null),
('11111111-1111-4111-8111-111111111111', null, 'care_task', seed_ts(79,'08:00'), 'Joy said the morning went smoothly', null, 0, array['carer'], null),
('11111111-1111-4111-8111-111111111111', null, 'symptom',   seed_ts(76,'14:00'), 'Slow getting going after her nap', null, 1, array['mobility'], null),
('11111111-1111-4111-8111-111111111111', null, 'appointment', seed_ts(73,'10:30'), 'GP review, bloods taken', null, 0, array['gp'], null),
('11111111-1111-4111-8111-111111111111', null, 'admin',     seed_ts(70,'12:00'), 'Surgery rang, bloods were fine', null, 0, array['gp'], null),
('11111111-1111-4111-8111-111111111111', null, 'mood',      seed_ts(67,'17:00'), 'Low, her friend cancelled again', null, 1, array['mood'], null),
('11111111-1111-4111-8111-111111111111', null, 'symptom',   seed_ts(64,'11:30'), 'Handwriting smaller this week', null, 1, array['handwriting'], null),
('11111111-1111-4111-8111-111111111111', null, 'medication', seed_ts(61,'08:00'), 'Started taking Adcal with breakfast', null, 0, array['adherence'], null),

-- Middle: 60 to 30 days ago
('11111111-1111-4111-8111-111111111111', null, 'symptom',   seed_ts(58,'07:30'), 'Stiff first thing, eased after her tablet', null, 1, array['stiffness'], null),
('11111111-1111-4111-8111-111111111111', null, 'care_task', seed_ts(55,'18:00'), 'Joy did the shopping', null, 0, array['carer'], null),
('11111111-1111-4111-8111-111111111111', null, 'incident',  seed_ts(52,'16:45'), 'Stumbled in the hallway, stayed upright', 'No injury. Shaken for a bit.', 2, array['falls'], null),
('11111111-1111-4111-8111-111111111111', null, 'symptom',   seed_ts(50,'20:00'), 'Tired the whole day', null, 1, array['fatigue'], null),
('11111111-1111-4111-8111-111111111111', null, 'mood',      seed_ts(47,'14:00'), 'Sat out in the garden, enjoyed it', null, 0, array['mood'], null),
('11111111-1111-4111-8111-111111111111', null, 'symptom',   seed_ts(44,'13:00'), 'Tremor about the same, no change', null, 1, array['tremor'], null),
('11111111-1111-4111-8111-111111111111', null, 'admin',     seed_ts(41,'11:00'), 'Repeat prescription collected', null, 0, array['admin'], null),
('11111111-1111-4111-8111-111111111111', null, 'symptom',   seed_ts(38,'03:30'), 'Woke twice in the night', null, 1, array['sleep'], null),
('11111111-1111-4111-8111-111111111111', null, 'symptom',   seed_ts(35,'21:15'), 'Froze in the doorway for a moment', 'First time I''ve seen that.', 2, array['freezing'], null),
('11111111-1111-4111-8111-111111111111', null, 'mood',      seed_ts(33,'10:00'), 'Frustrated with her cardigan buttons', null, 1, array['mood','dexterity'], null),
('11111111-1111-4111-8111-111111111111', null, 'symptom',   seed_ts(31,'09:00'), 'Slower on the stairs than last month', null, 1, array['mobility'], null),

-- Recent: the last month, where the story is
('11111111-1111-4111-8111-111111111111', null, 'symptom',   seed_ts(28,'02:00'), 'Woke at 2am and could not settle', null, 1, array['sleep'], null),
('11111111-1111-4111-8111-111111111111', null, 'care_task', seed_ts(26,'18:30'), 'Joy stayed late, Mum was unsteady', null, 1, array['carer'], null),
('11111111-1111-4111-8111-111111111111', '66666666-6666-4666-8666-000000000001', 'symptom', seed_ts(24,'03:15'), 'Froze getting to the bathroom at night', 'Had to help her back to bed.', 2, array['freezing','sleep'], 0.9),
('11111111-1111-4111-8111-111111111111', null, 'symptom',   seed_ts(23,'03:40'), 'Second night of freezing on the landing', null, 2, array['freezing','sleep'], null),
('11111111-1111-4111-8111-111111111111', null, 'mood',      seed_ts(22,'19:00'), 'Anxious about going to bed', null, 2, array['mood','sleep'], null),
('11111111-1111-4111-8111-111111111111', null, 'medication', seed_ts(21,'22:00'), 'Evening dose taken late, about 10pm', null, 1, array['adherence'], null),

-- Missed evening dose #1. See the note at the foot of this file.
('11111111-1111-4111-8111-111111111111', '66666666-6666-4666-8666-000000000002', 'medication', seed_ts(19,'20:00'), 'Evening co-careldopa dose missed', 'Found still in the tray next morning.', 2, array['adherence','levodopa'], 0.95),

('11111111-1111-4111-8111-111111111111', null, 'symptom',   seed_ts(18,'09:00'), 'Groggy all morning', null, 1, array['fatigue'], null),
('11111111-1111-4111-8111-111111111111', null, 'care_task', seed_ts(17,'18:00'), 'Joy noticed she was quieter than usual', null, 1, array['carer'], null),
('11111111-1111-4111-8111-111111111111', null, 'symptom',   seed_ts(15,'02:50'), 'Freezing again on the way to the loo', null, 2, array['freezing','sleep'], null),
('11111111-1111-4111-8111-111111111111', null, 'admin',     seed_ts(14,'10:15'), 'Rang the surgery about the repeat', null, 0, array['admin','gp'], null),
('11111111-1111-4111-8111-111111111111', null, 'mood',      seed_ts(13,'16:00'), 'Brighter, had a long chat with Tom', null, 0, array['mood'], null),
('11111111-1111-4111-8111-111111111111', null, 'symptom',   seed_ts(12,'18:30'), 'Tremor worse when she is tired', null, 1, array['tremor'], null),
('11111111-1111-4111-8111-111111111111', null, 'symptom',   seed_ts(11,'03:00'), 'Up twice again in the night', null, 1, array['sleep'], null),
('11111111-1111-4111-8111-111111111111', '66666666-6666-4666-8666-000000000003', 'incident', seed_ts(10,'19:10'), 'Nearly fell reaching for the kettle', 'Caught herself on the worktop.', 2, array['falls'], 0.9),
('11111111-1111-4111-8111-111111111111', null, 'symptom',   seed_ts(9,'08:30'),  'Stiff and slow first thing', null, 1, array['stiffness'], null),

-- Missed evening dose #2.
('11111111-1111-4111-8111-111111111111', '66666666-6666-4666-8666-000000000004', 'medication', seed_ts(8,'20:00'), 'Evening co-careldopa dose missed', 'Still in the tray again.', 2, array['adherence','levodopa'], 0.95),

('11111111-1111-4111-8111-111111111111', '66666666-6666-4666-8666-000000000005', 'symptom', seed_ts(7,'09:30'), 'Muddled for an hour after waking', 'Came right after breakfast.', 2, array['confusion'], 0.85),
('11111111-1111-4111-8111-111111111111', null, 'care_task', seed_ts(6,'18:10'), 'Joy helped her with a bath', null, 0, array['carer'], null),
('11111111-1111-4111-8111-111111111111', null, 'symptom',   seed_ts(5,'22:30'), 'Freezing episode just before bed', null, 2, array['freezing'], null),
('11111111-1111-4111-8111-111111111111', null, 'mood',      seed_ts(4,'15:00'), 'Settled day, no complaints', null, 0, array['mood'], null),
('11111111-1111-4111-8111-111111111111', null, 'symptom',   seed_ts(3,'03:10'), 'Awake at three again', null, 1, array['sleep'], null),
('11111111-1111-4111-8111-111111111111', null, 'admin',     seed_ts(2,'12:00'), 'Neurology appointment letter arrived', null, 0, array['admin'], null),
('11111111-1111-4111-8111-111111111111', null, 'symptom',   seed_ts(1,'08:45'), 'Slow start, better after breakfast', null, 1, array['mobility'], null);

-- Upcoming. Pinned to 14 August by CLAUDE.md, so this one is absolute.
insert into timeline_event
  (recipient_id, kind, occurred_at, headline, detail, severity, tags)
values ('11111111-1111-4111-8111-111111111111', 'appointment',
        (timestamp '2026-08-14 10:00' at time zone 'Europe/London'),
        'Dr Okafor, neurology', 'Royal Infirmary, outpatients.', 0, array['neurology','appointment']);

-- ------------------------------------------------------------ artifacts ---

-- A question bank with something already in it, so the Appointment Pack is
-- not empty before the demo capture runs.
insert into artifact (recipient_id, capture_id, kind, payload, status, confidence, created_at, actioned_at) values
  ('11111111-1111-4111-8111-111111111111', '66666666-6666-4666-8666-000000000001',
   'question',
   jsonb_build_object('question','Is the night-time freezing linked to when her last dose is?',
                      'for_specialty','neurology','priority',1),
   'approved', 0.9, seed_ts(24,'07:42'), seed_ts(24,'07:45')),
  ('11111111-1111-4111-8111-111111111111', '66666666-6666-4666-8666-000000000003',
   'question',
   jsonb_build_object('question','Should we be thinking about rails on the stairs?',
                      'for_specialty','gp','priority',2),
   'approved', 0.8, seed_ts(10,'19:22'), seed_ts(10,'19:30')),
  ('11111111-1111-4111-8111-111111111111', '66666666-6666-4666-8666-000000000004',
   'task',
   -- `OF` renders a whole-hour offset as "+01", which is not something our
   -- ISO8601 decoder accepts. Emit UTC with a literal Z instead.
   jsonb_build_object('title','Ask Joy to check the evening tray before she leaves',
                      'due_at', to_char(seed_ts(7,'18:00') at time zone 'UTC',
                                        'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
                      'why','Evening dose missed twice in a fortnight'),
   'done', 0.9, seed_ts(8,'08:12'), seed_ts(8,'08:20'));

-- ---------------------------------------------------------------- brief ---

insert into brief (recipient_id, version, content, source_capture_id)
values ('11111111-1111-4111-8111-111111111111', 1,
  jsonb_build_object(
    'one_liner', 'Margaret is managing at home, but her nights are getting harder.',
    'current_concerns', jsonb_build_array(
      jsonb_build_object('text','Freezing at night on the way to the bathroom',
                         'since', seed_date(24), 'trend','worsening'),
      jsonb_build_object('text','Evening levodopa dose being missed',
                         'since', seed_date(19), 'trend','worsening'),
      jsonb_build_object('text','Waking in the early hours',
                         'since', seed_date(38), 'trend','stable')
    ),
    'medications', jsonb_build_array(
      jsonb_build_object('name','Co-careldopa (Sinemet)','dose','25/100mg','schedule','4x daily: 8am, 12pm, 4pm, 8pm','adherence_note','Evening dose missed twice this month'),
      jsonb_build_object('name','Entacapone','dose','200mg','schedule','With each co-careldopa dose','adherence_note',null),
      jsonb_build_object('name','Rasagiline','dose','1mg','schedule','Once daily, morning','adherence_note',null),
      jsonb_build_object('name','Apixaban','dose','5mg','schedule','Twice daily','adherence_note','Taken reliably'),
      jsonb_build_object('name','Bisoprolol','dose','2.5mg','schedule','Once daily, morning','adherence_note',null),
      jsonb_build_object('name','Atorvastatin','dose','20mg','schedule','Once daily, evening','adherence_note',null),
      jsonb_build_object('name','Levothyroxine','dose','50mcg','schedule','Once daily, before breakfast','adherence_note',null),
      jsonb_build_object('name','Adcal-D3','dose','1500mg/400iu','schedule','Twice daily','adherence_note',null),
      jsonb_build_object('name','Amlodipine','dose','5mg','schedule','Once daily, morning','adherence_note',null),
      jsonb_build_object('name','Omeprazole','dose','20mg','schedule','Once daily, before breakfast','adherence_note',null),
      jsonb_build_object('name','Domperidone','dose','10mg','schedule','Three times daily, before meals','adherence_note',null),
      jsonb_build_object('name','Senna','dose','7.5mg','schedule','At night','adherence_note',null),
      jsonb_build_object('name','Melatonin (modified release)','dose','2mg','schedule','One hour before bed','adherence_note','Started in February for her nights'),
      jsonb_build_object('name','Macrogol (Laxido)','dose','One sachet','schedule','Once daily, mid-morning','adherence_note',null),
      jsonb_build_object('name','Paracetamol','dose','500mg','schedule','As needed','adherence_note',null)
    ),
    'recent_changes', jsonb_build_array(
      'Joy''s evening visit moved to 18:00',
      'Night-time freezing started about three weeks ago'
    ),
    'open_questions', jsonb_build_array(
      'Is the night-time freezing linked to when her last dose is?',
      'Should we be thinking about rails on the stairs?'
    ),
    'whats_working', jsonb_build_array(
      'The morning routine is settled',
      'Joy''s visits are a fixed point in her day'
    )
  ),
  '66666666-6666-4666-8666-000000000005');

drop function seed_ts(int, time);
drop function seed_date(int);

commit;

-- Two missed evening doses, not three.
--
-- PLAN.md C3 asks for three in the current month, but §9's demo capture is
-- itself the third — it writes its own timeline_event when Sarah records it.
-- Seeding three would make the pattern banner read "fourth". Seeding two makes
-- "That's the third missed evening dose this month" literally true on stage.
