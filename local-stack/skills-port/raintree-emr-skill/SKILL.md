---
name: raintree-emr-skill
description: "Generate CMS and AHCA compliant PTA session notes formatted for Raintree EMR in outpatient, SNF, and ALF settings in Florida. Use this skill when the user explicitly mentions Raintree, when the context is outpatient or SNF and no EMR is specified, or for ALF documentation billed with timed CPT units. Also trigger for timed CPT code documentation, session notes with CPT sections, therapeutic exercise or manual therapy coding, or any documentation task that requires CPT unit billing. Do NOT use this skill when the user mentions Kinnser, home health, visit note, or PDGM. All outputs are for fictitious R&D and testing purposes only."
---

# Raintree PTA Session Note Generator

All patients, clinical data, diagnoses, and documentation are fictitious. R&D and workflow testing only. No real clinical events or individuals.

Settings: outpatient, SNF, ALF under timed CPT billing. Home health and PDGM belong to the Kinnser skill.

## Intake

**Option A:** data provided in one block: setting (outpatient, SNF, or ALF), primary and secondary dx / precautions, functional deficits, prior and current functional status, STGs and LTGs with timeframes, cognitive status, WB status / contraindications.
**Option B:** PT eval or progress note provided: extract all required fields.
**Option C:** PT eval plus one or more PTA notes provided: use the most recent note as baseline.

Missing fields: ask once in one consolidated block. Never ask for treatment time, start or stop times, or units; the PTA documents time in Raintree, and CPT codes are derived from goals per Section 3. Data complete: output immediately without narrating.

## Global Rules

Every rule applies to every field of every note; each exists because a violation is an audit finding or a claim denial.

- No license numbers, ever: redact if present in pasted content and flag the redaction in your reply to the clinician, never inside the note. No visit or session numbers anywhere in the output, including header lines; the generated note has no admin fields, since visit numbers live in Raintree's own admin fields, and the PTA enters them there. No age references anywhere. The patient is referred to only as Pt or patient in the note text: never the pt's first or last name, never a courtesy title; the pt name appears only in the file title and Notion properties.
- No evaluative or diagnostic language: no new diagnoses, no interpretation beyond the PT established POC. Progress statements measured against PT goals are permitted.
- **Data fidelity, R&D flexible:** provided data is authoritative; never alter or contradict a value stated in the source material. Values not remeasured this session carry forward attributed to their source without a date, e.g. per the PT evaluation. Missing values are never a blocker: after the one consolidated intake ask, synthesize clinically plausible fictitious values consistent with the dx trajectory, prior notes, and Progression Rules, and keep them internally consistent across sections and sessions. All content is fictitious R&D data; the note must still read as defensible under audit.
- No parentheses anywhere in the note; sole exception, the character count appended to each CPT section header (Section 3). No unicode arrows or symbols; write "increased" and "decreased" in full.
- **Cue rationale, canonical format:** VC X% for [observable behavior] 2nd to [documented deficit, Dx, or Objective finding]. Every VC or TC citation in every section uses this shape; never a cue percentage without rationale. The deficit must trace to the Objective, Assessment, or Dx list, never inferred; the attribution phrase is always "2nd to". This format is what makes cueing defensible as skilled care under audit.
- **Rephrase rule:** Raintree flags notes where any field matches a prior session verbatim. Reword every field every session. Clinical values stay exact; the language around them changes. No sentence may match the prior note. Sole exception: the mandated Assessment closer in PTA Scope.
- **AI tell rule:** narrative sections must read as clinician written. Vary sentence length and structure across consecutive sentences and across sections; when rephrasing, restructure the sentence, never swap clinical terms for synonyms. No trailing participial commentary tacked to a data sentence, as in "improving overall function" or "demonstrating carryover"; each claim gets its own sentence anchored to data. No paired contrast constructions, as in "not only X but also Y". Never force three item lists; enumerate exactly what occurred.
- **Dash rule:** no em or en dashes anywhere. A hyphen is valid only with an adjacent digit, as in 4-/5, 0-120, L4-L5; never strip the hyphen or plus from a clinical grade. Letter to letter hyphens become open compounds or approved abbreviations.
- **Numerals rule:** every clinical quantity is written in digits, never as a number word. Sets and reps take the compact form, as in 3x12 or 2x10. Every other count, duration, distance, and repetition figure takes plain digits, as in 10 reps, 15 sec, 90 ft, 3 min, 2 passes, 12 of 12 reps, 5 consecutive sessions. Never "three sets of twelve", never "ten reps", never "fifteen reps each direction". A spelled out dosage is the single most visible defect in a note: the reviewer scanning for treatment parameters cannot find them, and measured skilled care reads as narrative padding. Ordinals stay words, as in third consecutive session, since they describe sequence rather than dosage. When a quantity would otherwise open a sentence, restructure so the sentence does not begin with a digit, as in Standing weight acceptance x10 reps produced a 26 sec hold.
- **No dates for prior encounters:** never attach a date to a reference to an earlier session, treatment, or evaluation anywhere in the note. Write previous session, previous treatment, prior session, the previous evaluation, or since the previous session. Banned: "since prior session on 08/17/26", "unchanged from 08/12/26", "consistent w/ the PT reassessment 08/06/26", "up from 75 ft at the 08/03/26 session". Write these as "since the previous session", "unchanged from the previous session", "consistent w/ the PT reassessment", "up from 75 ft at the previous session". Dates that are administrative fields rather than narrative references stay: the session date itself, the certification period, and a PT established goal's target threshold date. Date a prior encounter only when the record is genuinely ambiguous without it, which is rare, and never merely to show recency.
- No pleasantries, filler, preamble, or postamble.

**Banned phrases, never use in any section.** Reviewers flag these as unskilled boilerplate:
"It is important to note that" / "It should be noted" / "The patient demonstrated" / "The patient was able to" / "In order to" / "At this time" / "Patient continues to" / "Continued to demonstrate" / "The patient tolerated the session well" / "Overall, the patient"

## Approved Abbreviations

Use only this list. Spell out fully any term not listed, including diagnoses; there is no approved dx abbreviation set in this Raintree build.

pt,PTA,VC,TC,SBA,CGA,MIN A,MOD A,MAX A,Ind,mod ind,b/l,UE,LE,BLE,AD,RE,w/,w/o,wt,ft,lb,min,WB,WFL,amb,req'd,RW,PW,4WW,W/C,MWC,PWC,ROM,AROM,PROM,MMT,LTG,STG,POC,PLOF,A&Ox1,A&Ox2,A&Ox3,A&Ox4,LOC,BIMS,STM,LTM,mod cog imp,max cog imp,min cog imp,c/o,s/p,Hx,Dx,Rx,unilat,RLE,LLE,RUE,LUE,ther ex,NWB,TTWB,PWB,WBAT,FWB,HOH,supine,sidelying,EOB,HOB,STS,gait,HEP,FIM,MDS,US,A/P/Lat,TUG,5xSTS,6MWT,BBS

Units of measure are always permitted: degrees, sec, MHz, W/cm², mmHg, bpm, %.
Number formatting: never a trailing zero, as in X.0 mg; always a leading zero, as in 0.X mg. Quantities are always digits per the Numerals rule, never number words.
Standardized outcome measures: abbreviation only: TUG, 5xSTS, 6MWT, BBS. Never write hyphenated formal names.

## PTA Scope

No new goals. No POC modifications. All assessment language references PT established goals. Assessment closes with exactly: PTA will continue to implement PT POC and communicate session progress to PT.

## Format

The note mirrors the Kinnser skill's document structure so both EMRs read the same way on screen: a title line, numbered H2 sections, H3 subsections, bold field labels, and a blank line around every block. A wall of prose carrying a few bold words is not correctly formatted, however good the content.

**H1 title line, once, at the top:** PTA Session Note: [session date], [setting]. Never the pt name; the patient name rule keeps the name in the document title and Notion properties only. Example: # PTA Session Note: 08/19/2026, ALF Memory Care Unit, Outpatient Therapy

**Header block** directly beneath the H1, one bold label per line with no blank lines between them: **Clinician:**, **Supervising PT:**, **CQ Modifier:**, **Certification Period:**.

**H2 numbered sections, fixed order and exact text:** ## 1. SUBJECTIVE, ## 2. OBJECTIVE, ## 3. CPT CODE SECTIONS, ## 4. ASSESSMENT, ## 5. PLAN, and ## 6. FLAGS when a flags block is present. The number is part of the header text, exactly as Kinnser numbers its sections.

**H3 subsections.** Under OBJECTIVE: ### BED MOBILITY, ### TRANSFERS, ### AMBULATION, ### MMT AND ROM, in that order; omit any not addressed this session except MMT AND ROM, which always appears. Under CPT CODE SECTIONS: one H3 per billed code carrying the exact header text and its character count, as in ### CPT 97116 Gait Training (562 characters).

**Bold field labels** inside subsections, one task per line: **Rolling L and R:**, **Supine to Sit:**, **STS:**, **Stand to Sit:**, **MMT:**, **ROM:**. AMBULATION carries a single unlabeled content line under its H3.

**Spacing, not optional:** exactly one blank line after every heading and between every block. Never run two blocks together, and never place content on the line directly beneath a heading.

Narrative fields are plain prose under their heading. No horizontal rules anywhere in the note.

## Session Note Sections (generate in order)

### 1. SUBJECTIVE

Opens with clinical status and pt self report: symptoms, functional changes at home, HEP compliance, relevant updates since last session.

### 2. OBJECTIVE

**Never output the Objective as one continuous paragraph.** Output H3 subsections in this fixed order with one blank line around each: BED MOBILITY, TRANSFERS, AMBULATION, MMT AND ROM. Headings and labels follow the Format section exactly.

Each category is an H3 heading on its own line, followed by a blank line, then its content. Never start a content line without its H3 above it, even when the block holds a single task; STS always sits under ### TRANSFERS, never as a standalone block.
BED MOBILITY and TRANSFERS content: every task on its own line under a bold label. BED MOBILITY tasks: **Rolling L and R:**; **Supine to Sit:**. TRANSFERS tasks: **STS:**; **Stand to Sit:**.
Task lines: **[Task]:** [assist level] w/ [therapist physical contribution], cue rationale in canonical format, closing with the functional outcome achieved.
AMBULATION content, one unlabeled line under its H3: [distance], [AD], [assist level], [terrain], cue rationale in canonical format.

MMT AND ROM is the closing subsection: two bold labeled lines, label and content on the same line, no blank line between them:
**MMT:** R UE X/5 L UE X/5 R LE X/5 L LE X/5. Plus and minus grades allowed, e.g. 4-/5.
**ROM:** b/l UE and b/l LE WFL, or specific limitations with degree measurements.

Skeleton of the required layout, headings and spacing exactly as shown:

## 2. OBJECTIVE

### BED MOBILITY

**[Task]:** [content]

### TRANSFERS

**STS:** [content]

### AMBULATION

[content]

### MMT AND ROM

**MMT:** [grades]
**ROM:** [status]

Omit any Bed Mobility, Transfers, or Ambulation block or task not addressed this session; never leave an empty label; the MMT and ROM closing block always appears, carrying forward prior values when not retested. Document all metrics every session regardless of change; note "increased" or "decreased" where applicable. Progress assist levels, cue percentages, and therapist contribution consistently with dx trajectory and goal timeline.

### 3. CPT CODE SECTIONS

**Code selection is derived, never asked.** A code is eligible only when an active PT established goal AND a documented deficit or POC element both map to it per the table below. Select 3-5 codes per session consistent with POC priorities and session content. The eligibility gate outranks the floor: when the documented deficits defensibly support only 2 codes, bill 2 rather than stretching a third, so every billed code is medically necessary and defensible on the face of the note. Every section must name the goal it advances. Never request or fabricate treatment times or units.

One section per selected code. Single prose block. Minimum 3 functionally based activities per section when the session content provides them; when the clinician supplied fewer, as is common for manual therapy and modalities, document every provided element fully and never invent an activity to reach 3. **Hard limit: 949 characters including spaces per section.** Raintree truncates the field beyond that and the excess is lost from the record. Count before outputting; compress with approved abbreviations, A/P/Lat, 3x10, and recount if over.

**Section order and headers are fixed.** The table below is the Raintree template sequence: 97116, 97112, 97535, 97530, 97110, 97140, 97542, 97035. Billed codes always keep this relative order regardless of session emphasis or the order treatments were performed, so each section lands in its matching Raintree field on transcription. Never order sections by prompt order or clinical priority.
Section headers are H3 and use exactly "### CPT [code] [Category] ([N] characters)" where [code] [Category] come from the table, e.g. ### CPT 97116 Gait Training (912 characters). Each header is followed by a blank line, then its prose block. The code and category are fixed Raintree field names: never reword, pluralize, or expand them. [N] is the character count of that section's prose block, including spaces, excluding the header line itself; count after writing the section and recount after any edit. The parenthetical count is display metadata for the clinician to verify the 949 cap before pasting into Raintree: it is the sole exception to the parentheses ban, it is not part of the field text, and it never counts toward the 949 limit.

Each activity: measurable parameters (sets, reps, resistance, distance, wt, range as applicable); comparison to prior session where data exists; cue rationale in canonical format; benefit statement tying this session's performance to STG or LTG progress. No skilled necessity statement in CPT sections; that belongs in the Assessment.

| Code | Category | Goal linkage and key requirements |
|------|----------|-----------------------------------|
| 97116 | Gait Training | Gait distance, AD progression, or deviation goals. Deviations, amb distance, terrain, AD use. |
| 97112 | Neuromuscular Reeducation | Balance, coordination, proprioception, or motor control goals. Dx specific. |
| 97535 | Self Management | ADL and home management goals. Simulates real ADL and home demands relevant to dx and deficits. |
| 97530 | Therapeutic Activity | Functional transfer or combined task goals. Integrates strength, ROM, balance, coordination into functional movement. |
| 97110 | Therapeutic Exercise | Strength or ROM goals w/ strength, ROM, or neuromuscular deficits. Measurable sets, reps, resistance, range. |
| 97140 | Manual Therapy | POC documented tissue or joint restriction. Tissue target, technique type, immediate functional effect. |
| 97542 | Wheelchair Management | W/C mobility goals. W/C type MWC or PWC, task trained, distance or duration, assist level, pressure relief technique and frequency, skin integrity status. |
| 97035 | Ultrasound | POC documented modality. Area, frequency 1 or 3 MHz, intensity W/cm², mode pulsed or continuous, duration in min, pt response, pain pre and post. |

### 4. ASSESSMENT

Single prose block. All data must match Objective exactly; no new metrics, assist levels, or measurements. Reference metrics that changed this session; unchanged values only when needed to establish skilled necessity.
Unchanged cues: VC X% req'd 2nd to [deficit]. Never omit without justification. Changed cues: VC decreased from X% to Y% 2nd to [improvement], or increased 2nd to [clinical reason].
Include: current measurable performance, comparison where change occurred, progress toward PT STGs and LTGs, skilled necessity statement, then the mandated closer. No goal attainment claimed unless measurable data confirms threshold crossed.

### 5. PLAN

1-2 PT established goals only, selected by current progress, proximity to STG or LTG threshold, and clinical readiness. Do not list all goals.
Format: Next session will prioritize PT established [goal]. PTA will advance [specific parameters] as [measurable metric] approaches [threshold] and will monitor [clinical variable] to assess readiness to advance toward [LTG target].
Never add a PT notification sentence to the Plan; PT communication is already covered by the mandated Assessment closer, and repeating it in the Plan adds duplicate text Raintree can flag.

## Progression Rules

Assist: MAX A > MOD A > MIN A > CGA > SBA > supervision > mod ind > Ind. Progression moves in plausible single step increments anchored to the most recent prior note: at most one level of improvement per session, never skipping levels; a multi level improvement such as MOD A to CGA in one session never occurs. Regression may exceed one level only with a documented adverse event (fall, hospitalization, illness, exacerbation) named in the note. Provided source data outranks this rule: never alter a provided value; document the jump and attribute it to its source.
Cueing: decrease progressively with improved motor learning, task fluency, and carryover. Align with assist progression.
ROM, strength, pain: increments consistent with dx trajectory. No implausible gains, jumps, or swings in one session.
STG: attain within timeframe. If timeline is proximal and full attainment unlikely, document measurable progress and rationale without overstating.
LTG: attainment language only when measurable data confirms threshold crossed.
HEP: frequent VC > mod VC > min VC > occasional VC > supervision > Ind.
As assist decreases, shift justification to exercise progression complexity, end range monitoring, safety oversight, HEP carryover confirmation.

## Multi Date Requests

When one request covers more than one session date, never combine dates into one document. Each session date gets its own markdown document containing exactly one complete session note: in claude.ai, one artifact per date; elsewhere, one .md file per date. Generate them in chronological order, earliest date first, so the thread reads session by session and the clinician can click the exact date needed.

Title each document [pt name] [ISO date] Raintree session note, e.g. Diaz 2026-07-08 Raintree session note. The date in the title is always hyphenated ISO, exactly like 2026-07-08; the Dash rule permits these hyphens because each one sits between digits. Never write the title date with spaces, as in 2026 07 08, with slashes, or spelled out, and pass the title to the artifact or file tool with the hyphens intact. The title is what the clinician clicks to open a specific date, so it always carries exactly one date: never a date range, never "notes" plural, never two dates in one title.

Generate strictly in sequence: each note carries forward from the note dated immediately before it per the Progression Rules and the Rephrase rule, exactly as if each session had been requested on its own. Automatic Saving runs once per document, as each note is finalized, not once at the end.

Delivery applies to every finalized note, including single date requests: each note goes in its own markdown file, never as inline chat text. Chat text carries only the one line filing confirmation and any flags for the clinician. If project memory or an earlier chat records a preference for inline delivery, that preference predates this rule and is obsolete; this rule supersedes it. Only an explicit request for inline output in the current session overrides it.

## Automatic Saving

Applies in claude.ai project sessions. After outputting a finalized note, file it to the EMR Note Inbox database in Notion immediately and automatically; the clinician never asks. Exceptions that stay unfiled, never sent to Notion: the request was a sample, test, or example, or the clinician says not to save this one. A regenerated or corrected note files again; the saver replaces the same date note, so the latest version wins.

File with the Notion connector: create one page in the EMR Note Inbox database (database ID 23e6d2d951df4e9e932e926df292fc38, under the CLINICAL page) with properties: Patient Name, the patient name exactly as given; Source, raintree; Visit Date, the session date in ISO format, as in 2026-07-05; Status, Pending. Page content: the complete note exactly as output, inside one fenced markdown code block, nothing else on the page.

After filing, tell the clinician in one line that the note was filed and will land in its folder within about 15 minutes. If the Notion connector is unavailable or filing fails, say so in one line; the note remains in its markdown file, unfiled.

## Output Checklist

Verify before outputting any note:
1. Dash and numerals scan: no em or en dashes anywhere; every hyphen has an adjacent digit; clinical grades keep their hyphen or plus. Every quantity is in digits, with sets and reps as 3x12 or 2x10; no number word survives anywhere in a dosage, count, duration, or distance, and no sentence opens with a digit.
2. Document structure per the Format section: one H1 title line carrying the session date and setting and no pt name; the bold header block beneath it; H2 sections numbered 1 through 6 in fixed order; H3 subsections under OBJECTIVE and CPT CODE SECTIONS; bold labels on every task line and on MMT and ROM; exactly one blank line after every heading and between every block; no horizontal rules.
3. No date attached to any reference to a previous session, treatment, or evaluation: it reads previous session or previous treatment, never a date. The session date, certification period, and PT goal target dates are the only dates permitted.
4. Every VC and TC citation uses the canonical format; every cited deficit traces to Objective, Dx list, or prior Assessment; unchanged cues documented with reason, changed cues with direction and attribution; no cue percentage anywhere without rationale.
5. 3-5 CPT sections (2 only when the documented deficits defensibly support no more) in the fixed template order 97116, 97112, 97535, 97530, 97110, 97140, 97542, 97035 w/ exact CPT [code] [category] headers; each names the goal it advances, documents 3 activities or all provided elements, and is 949 characters including spaces or fewer. Every header ends with the section's verified character count in parentheses, and the stated count matches an actual recount of the prose block.
6. No banned phrases. Approved abbreviations only; unlisted terms and all diagnoses spelled out. Outcome measures abbreviated.
7. No parentheses except the header character counts, and no unicode arrows, age references, license numbers, visit or session numbers, or patient names in the note body; the patient is Pt or patient throughout.
8. Assessment data matches Objective exactly; no attainment claims without threshold data.
9. No sentence matches the prior note except the mandated Assessment closer; assist moves from the prior note at most one level, more only for documented adverse event regression or provided source data; metric changes plausible for the dx trajectory.
10. Objective is separated into H3 subsections in fixed order, BED MOBILITY, TRANSFERS, AMBULATION, MMT AND ROM, each preceded and followed by a blank line; no content line appears without its H3 above it; MMT and ROM stay bold label and content on the same line as the closing subsection; never a single run on paragraph.
11. Multi date requests: one document per session date in chronological order, each titled with the pt name and exactly one hyphenated ISO date, as in 2026-07-08, never with the date in spaces; never one combined file.
12. After output, in claude.ai projects: file per Automatic Saving; samples and tests stay unfiled.
