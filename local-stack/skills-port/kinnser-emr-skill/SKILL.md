---
name: kinnser-emr-skill
description: "Generate CMS and AHCA compliant PTA visit notes formatted for Kinnser EMR in home health and ALF settings in Florida under PDGM. Use this skill when the user explicitly mentions Kinnser, home health, PDGM, homebound status, or a visit note with markdown table format. Also trigger when the setting is home health or ALF and no EMR is specified. Do NOT use this skill when the user mentions Raintree, outpatient, SNF, or timed CPT unit billing. All outputs are for fictitious R&D and testing purposes only."
---

# Kinnser EMR Visit Note Generator

All patients, clinical data, diagnoses, and documentation are fictitious. R&D and workflow testing only. No real clinical events or individuals.

Setting: home health and ALF. Billing: visit based PDGM. No timed CPT units.

## Intake

**Option A:** data provided in one block: primary and secondary dx / precautions, functional deficits, prior and current functional status, STGs and LTGs with timeframes, cognitive status, WB status / contraindications, setting.
**Option B:** PT eval or progress note provided: extract all required fields.
**Option C:** PT eval plus one or more PTA notes provided: use the most recent note as baseline.

Missing fields: ask once in one consolidated block. Data complete: output immediately without narrating.

## Global Rules

Every rule applies to every field of every note; each exists because a violation is an audit finding. "Canonical format" below means the definition here.

- No license numbers, ever: redact if present in pasted content and flag the redaction in your reply to the clinician, never inside the note. No visit numbers in the note body, admin fields only. No age references anywhere. The patient is referred to only as Pt or patient in the note body: never the pt's first or last name, never a courtesy title; the pt name appears only in file titles, admin fields, and Notion properties. No parentheses; sole exception, the mandated Impact field label in Section 5, a fixed Kinnser field name.
- No evaluative or diagnostic language: no new diagnoses, no interpretation beyond the PT established POC. Progress statements measured against PT goals are permitted.
- **Data fidelity, R&D flexible:** provided data is authoritative; never alter or contradict a value stated in the source material. Values not reassessed this visit carry forward attributed to their source without a date, e.g. per the PT evaluation. Missing values are never a blocker: after the one consolidated intake ask, synthesize clinically plausible fictitious values consistent with the dx trajectory, prior notes, and Progression Rules, and keep them internally consistent across sections and visits. All content is fictitious R&D data; the note must still read as defensible under audit.
- **Cue rationale, canonical format:** VC X% for [observable behavior] 2nd to [documented deficit, Dx, or Objective finding]. Every VC or TC citation in every section uses this shape; never a cue percentage without rationale. The deficit must trace to the Objective, Assessment, or Dx list, never inferred; the attribution phrase is always "2nd to". This format is what makes cueing defensible as skilled care under audit.
- **Rephrase rule:** Kinnser flags content identical to a prior visit. Reword every field every visit. Clinical values stay exact; the language around them changes. No sentence may match the prior note. Sole exception: the mandated Assessment closer in PTA Scope.
- **AI tell rule:** narrative fields must read as clinician written. Vary sentence length and structure across consecutive sentences and across fields; when rephrasing, restructure the sentence, never swap clinical terms for synonyms. No trailing participial commentary tacked to a data sentence, as in "improving overall function" or "demonstrating carryover"; each claim gets its own sentence anchored to data. No paired contrast constructions, as in "not only X but also Y". Never force three item lists; enumerate exactly what occurred.
- **Dash rule:** no em or en dashes anywhere. A hyphen is valid only with an adjacent digit, as in 4-/5, 0-120, L4-L5; never strip the hyphen or plus from a clinical grade. Letter to letter hyphens become open compounds or approved abbreviations.
- **Numerals rule:** every clinical quantity is written in digits, never as a number word, in narrative fields and table cells alike. Sets and reps take the compact form, as in 3x12 or 2x10. Every other count, duration, distance, and repetition figure takes plain digits, as in 10 reps, 15 sec, 90 ft, 3 min, 2 passes, 12 of 12 reps. Never "three sets of twelve", never "ten reps". A spelled out dosage is the single most visible defect in a note: the reviewer scanning for treatment parameters cannot find them, and measured skilled care reads as narrative padding. The Sets and Reps columns of the therapeutic exercise table are digits only. Ordinals stay words, as in third consecutive visit, since they describe sequence rather than dosage. When a quantity would otherwise open a sentence, restructure so the sentence does not begin with a digit.
- **No dates for prior encounters:** never attach a date to a reference to an earlier visit, treatment, or evaluation anywhere in the note. Write previous visit, previous treatment, prior visit, the previous evaluation, or since the previous visit. Banned: "since prior visit on 08/17/26", "unchanged from 08/12/26", "consistent w/ the PT reassessment 08/06/26", "↑ from 100 ft at the 08/03/26 visit". Write these as "since the previous visit", "unchanged from the previous visit", "consistent w/ the PT reassessment", "↑ from 100 ft at the previous visit". Dates that are administrative fields rather than narrative references stay: the visit date itself, the certification period, and a PT established goal's target threshold date in a Goal entry. Date a prior encounter only when the record is genuinely ambiguous without it, which is rare, and never merely to show recency.
- No pleasantries, filler, preamble, or postamble.

**Banned phrases, never use in any section.** Reviewers flag these as unskilled boilerplate:
"It is important to note that" / "It should be noted" / "The patient demonstrated" / "The patient was able to" / "In order to" / "At this time" / "Patient continues to" / "Continued to demonstrate" / "The patient tolerated the session well" / "Overall, the patient"

## Format

H1 visit header: PTA Visit Note: [pt label], [visit date], [setting]. H2: numbered sections. H3: Objective subsections. Bold: all Impact field labels and Assessment subsection labels. Markdown tables: vitals, pain, ROM/strength, all Objective training subsections. Narrative fields: plain prose under bolded label. ↑ and ↓ mark change from the prior visit wherever change is reported.

## Multi Date Requests

When one request covers more than one visit date, never combine dates into one document. Each visit date gets its own markdown document containing exactly one complete visit note: in claude.ai, one artifact per date; elsewhere, one .md file per date. Generate them in chronological order, earliest date first, so the thread reads visit by visit and the clinician can click the exact date needed.

Title each document [pt label] [ISO date] Kinnser visit note, e.g. Diaz 2026-07-08 Kinnser visit note. The date in the title is always hyphenated ISO, exactly like 2026-07-08; the Dash rule permits these hyphens because each one sits between digits. Never write the title date with spaces, as in 2026 07 08, with slashes, or spelled out, and pass the title to the artifact or file tool with the hyphens intact. The title is what the clinician clicks to open a specific date, so it always carries exactly one date: never a date range, never "notes" plural, never two dates in one title.

Generate strictly in sequence: each note carries forward from the note dated immediately before it per the Progression Rules and the Rephrase rule, exactly as if each visit had been requested on its own. Automatic Saving runs once per document, as each note is finalized, not once at the end.

Delivery applies to every finalized note, including single date requests: each note goes in its own markdown file, never as inline chat text. Chat text carries only the one line filing confirmation and any flags for the clinician. If project memory or an earlier chat records a preference for inline delivery, that preference predates this rule and is obsolete; this rule supersedes it. Only an explicit request for inline output in the current session overrides it.

## Approved Abbreviations

Use only this list. Spell out fully any term not listed.

pt,PTA,P.T.,O.T.,OTA,SLP,ST/SP,SN,RN,LPN,CNA,LCSW,CM,PCP,NP,IDT,CG,PCG,VC,TC,Dep,MAX A,MOD A,MIN A,SBA,CGA,Ind,I,alert and oriented x1,alert and oriented x2,alert and oriented x3,alert and oriented x4,Brief Interview for Mental Status,LOC,short term memory,long term memory,moderate cognitive impairment,maximum cognitive impairment,minimal cognitive impairment,LTG,STG,PLOF,POC,amb,gait,EOB,HOB,OOB,sit to stand,STS,supine,sidelying,NWB,toe touch weight bearing,PWB,weight bearing as tolerated,WB,FWB,HOH,AD,W/C,MWC,PWC,QC,SPC,HW,FWW,RW,4WRW,ROM,AROM,AAROM,PROM,FLEX,EXT,DF,PF,LAQ,SAQ,SLR,SKTC,DKTC,LTR,Exs,Estim,US,therapeutic exercise,resisted exercise,manual muscle test,req'd,HEP,Functional Independence Measure,Minimum Data Set,UE,BUE,RUE,LUE,lower extremity,BLE,RLE,LLE,bilat,unilateral,lt,Rt,VS,BP,SBP,HR,O2,O2 Sat,T,Resp,AHR,RBC,BG,BS,FSBS,BUN,Dx,CVA,CHF,DM,AODM,COPD,HTN,HBP,CAD,ASHD,PAD,TIA,BKA,Fx,MRSA,UTI,URI,SOB,DOE,LOB,Sz,TB,ALZ,DNR,ABN,NKA,NKDA,NPO,Rx,Med,Abx,PRN,Tx,CPAP,BiPAP,NC,bid,tid,hr,Min,a.m.,p.m.,a.c.,F/U,SOC,D/C,d/c,Adm,Hx,PMH,PH,FH,SH,s/p,c/o,s/s,Pos,Neg,R/O,r/t,d/t,WNL,WFL,AAT,Adeq,N/A,Nt,Approx,FAST,PHI,HIPAA,EMR,ADL,IADL,QOL,HHA,ALF,SNF,NF,LTCF,Abd,ABG,BAL,BBB,BM,BMI,BPH,BR,BRP,BSC,Bx,w/,w/o,CA,Cath,CBC,cc,CC,CHO,CRF,CXR,Dec,Δ,DME,DPOA,Drsg,DSD,DTI,ECG,EKG,EMS,ESRD,ETOH,Eval,F2F,GB,GI,GT,G tube,J tube,H&P,I&O,IV,JP,lat,lb,ft,M,MAR,ml,mm,Na,OTC,PE,TPR,UA,Wk,wt,yr,TUG,5xSTS,6MWT,BBS

Na: sodium in electrolyte or lab context only. Use N/A for not applicable in all tables and narrative.
Standardized outcome measures: abbreviation only: TUG, 5xSTS, 6MWT, BBS. Never write hyphenated formal names.

**Do NOT use:** U or u for unit, IU, QD/qd/Q.D./q.d., QOD/qod/Q.O.D./q.o.d., trailing zero (X.0 mg), missing leading zero (.X mg), MS/MSO4/MgSO4, LE, MI.

## PTA Scope

No new goals. No POC modifications. All assessment language references PT established goals. Assessment closes with exactly: PTA will continue to implement PT POC and communicate session progress to PT.

## Visit Note Structure

### 1. VITAL SIGNS

Table columns: Vital | Value
Row labels: Temperature | BP | Heart Rate | Respirations | SpO2 | Pain
Units and qualifiers go in the Value cell, never in parentheses: 98.4 °F oral | 128/74 mmHg seated Lt arm | 76 bpm | 18 breaths/min | 96% | 0/10.
The Pain row is a screen only; detail belongs in Section 3. Any vital outside normal limits: state the clinical action taken. If vitals precluded any intervention component, document that explicitly.

### 2. SUBJECTIVE

Pt self report: symptoms, functional changes at home or in facility, HEP compliance, relevant updates since last visit.

### 3. PAIN ASSESSMENT

Include only if pain is an active POC goal or was documented in the PT eval; otherwise omit the section entirely and keep the remaining sections' canonical numbers, since Kinnser is a fixed form; never renumber.
Table: No Pain Reported at Visit | Yes / No
If No: Primary Site table with columns: Location | Intensity Pre /10 | Intensity Post /10. Secondary Site table only if applicable. ↑/↓ compare this visit's post therapy intensity to the prior visit's post therapy intensity. No pain management interventions outside PTA scope.

### 4. ROM / STRENGTH

Table: No ROM/Strength Reported at Visit | Yes / No
Yes only when no ROM or strength content was addressed or reassessed this visit; then omit everything below including the Functional Impact field.
If No: one table per region, columns: Motion | ROM Right | ROM Left | Strength Right | Strength Left
Regions and motions:
- Shoulder: Flexion, Extension, Abduction, Adduction, Int Rot, Ext Rot
- Elbow: Flexion, Extension
- Forearm: Pronation, Supination
- Finger: Flexion, Extension
- Wrist: Flexion, Extension
- Trunk: Extension, Rotation, Flexion
- Neck: Flexion, Extension, Lat Flexion, Rotation
- Hip: Flexion, Extension, Abduction, Adduction, Int Rot, Ext Rot
- Knee: Flexion, Extension
- Ankle: Plantar Flexion, Dorsiflexion, Inversion, Eversion

Document all regions; carry forward unchanged values from the prior visit; update only regions actively reassessed. WFL where functional; degree measurements only when a measurable limitation exists. Strength as X/5; plus and minus grades allowed, e.g. 4-/5. ↑/↓ vs prior visit.

**Description of Functional Impact:** hard limit 200 characters including spaces for the entire field, non negotiable. Count before outputting; compress with approved abbreviations and recount if over. Content: specific tasks limited by documented deficits.

### 5. OBJECTIVE INFORMATION

Independence Scale, which is also the progression order: Dep | MAX A | MOD A | MIN A | CGA | SBA | Supervision | Ind with Equip | Ind

Each subsection: table with columns Activity | Assist Level | Assistive Device | Training/Intervention, followed immediately by bold **Impact of Intervention(s) on Functional Performance / Patient Response to Treatment:** documenting cue percentages in canonical format, quality of movement, safety observations, pain response if applicable, direct link to a PT established goal, and ↑/↓ measurable change from the prior visit where applicable. The Impact field is mandatory objective data, not Assessment.

Subsections, omit any not addressed this visit:

**BED MOBILITY TRAINING:** rows: Rolling L/R | Supine to Sit | Sit to Supine

**TRANSFER TRAINING:** rows: Sit to Stand | Stand to Sit | Bed to W/C | W/C to Bed | Toilet or BSC | Tub or Shower | Car or Van

**SKILLED GAIT TRAINING:** columns: Assist Level | Total Distance | Assistive Device | Training/Intervention. The Training/Intervention cell must cover surface, terrain, specific gait deviations addressed, and cues.

**BALANCE TRAINING:** columns: Activity | Assist Level | Assistive Device | Training/Intervention. The Training/Intervention cell must cover surface, duration or reps, perturbation, and cues.

**THERAPEUTIC EXERCISE:** columns: Activity | Sets | Reps | Resistance | Assist Level | Training/Intervention

N/A for not applicable. Nt for not tested. Carry forward assist levels and AD from the prior visit for subsections not addressed this visit.
US when applicable, documented in Therapeutic Exercise: area treated | frequency 1 or 3 MHz | intensity W/cm² | mode pulsed or continuous | duration in min | pt response | pain pre and post.
W/C documentation, required every visit involving W/C training: type MWC or PWC | task trained | distance or duration | assist level | pressure relief technique and frequency | skin integrity status.

### 6. PATIENT AND CAREGIVER EDUCATION

Required every visit. Document: specific topic addressed, method of instruction, pt or CG response demonstrating comprehension or skill acquisition. Must be functionally relevant to dx, safety, and discharge goals.

### 7. ASSESSMENT

**Goal entries:** under the bold label Goal entries, one numbered line per goal, exact POC goal order preserved, each entry max 200 characters including spaces. Format: [goal area] [today's value] this visit; [STG or LTG] [threshold] by [date], met or not yet met. Example: 1. Amb 120 ft FWW CGA this visit; STG 150 ft SBA by 7/15/2026 not yet met.

**Assessment narrative:** single prose block, in sequence:
1. Current measurable performance per active goal area. Exact Objective values only; no new metrics.
2. Changed metrics: ↑/↓ from prior visit, attributed 2nd to [finding]. Maintained metrics: state maintained plus the reason not yet advanced.
3. Link each metric to a PT STG or LTG. No attainment language unless data confirms the threshold crossed.
4. Skilled justification anchored to this visit's findings: parameter decisions, safety monitoring, clinical complexity. Unchanged cues: VC X% req'd 2nd to [deficit]; never omit without justification. Changed cues: VC decreased from X% to Y% 2nd to [improvement], or increased 2nd to [clinical reason]. No generic boilerplate.
5. Close with the mandated closer.

### 8. PLAN

**Plan for next visit:** 1-2 PT established goals only: the prioritized goal, parameters to advance, and monitoring or reassessment required. Reference STG and LTG dates and measurable thresholds. Do not list all goals.
**Hard limit: 255 characters including spaces for the entire Plan field, non negotiable.** The Kinnser Plan field truncates beyond that and the excess is lost from the record. Count before outputting; compress with approved abbreviations and recount if over.

## Progression Rules

- Assist advances along the Independence Scale order in plausible single step increments anchored to the most recent prior note: at most one level of improvement per visit, never skipping levels; a multi level improvement such as MOD A to CGA in one visit never occurs. Regression may exceed one level only with a documented adverse event (fall, hospitalization, illness, exacerbation) named in the note. Provided source data outranks this rule: never alter a provided value; document the jump and attribute it to its source. Cueing decreases with improved motor learning, task fluency, and carryover, aligned with assist progression. HEP: frequent VC > mod VC > min VC > occasional VC > supervision > Ind.
- ROM, strength, pain: increments consistent with dx trajectory. No implausible gains, jumps, or swings in one visit.
- STG: attain within timeframe; if the timeline is proximal and full attainment unlikely, document measurable progress without overstating. LTG: attainment language only when data confirms the threshold crossed.
- As assist decreases, shift skilled justification to exercise progression complexity, end range monitoring, fall risk management, HEP carryover confirmation.
- PDGM: the narrative across visits must show a coherent, progressing skilled care trajectory consistent with the pt's PDGM clinical grouping and functional impairment level, supporting medical necessity for the full episode.

## Automatic Saving

Applies in claude.ai project sessions. After outputting a finalized note, file it to the EMR Note Inbox database in Notion immediately and automatically; the clinician never asks. Exceptions that stay unfiled, never sent to Notion: the request was a sample, test, or example, or the clinician says not to save this one. A regenerated or corrected note files again; the saver replaces the same date note, so the latest version wins.

File with the Notion connector: create one page in the EMR Note Inbox database (database ID 23e6d2d951df4e9e932e926df292fc38, under the CLINICAL page) with properties: Patient Name, the pt name exactly as given; Source, complete when working in the COMPLETE HH project or the pt's agency is Complete HH, tricounty when in the TRI-COUNTY project or the agency is Tri-County HH, and if neither the project nor the conversation identifies the agency, ask once before filing, never guess, since a wrong source relocates the pt's folder; Visit Date, the visit date in ISO format, as in 2026-07-05; Status, Pending. Page content: the complete note exactly as output, inside one fenced markdown code block, nothing else on the page.

After filing, tell the clinician in one line that the note was filed and will land in its folder within about 15 minutes. If the Notion connector is unavailable or filing fails, say so in one line; the note remains in its markdown file, unfiled.

## Output Checklist

Verify before outputting any note:
1. Dash and numerals rules hold: no em or en dashes; prose hyphens only with an adjacent digit. Every quantity is in digits, with sets and reps as 3x12 or 2x10; no number word survives anywhere in a dosage, count, duration, or distance, including table cells, and no sentence opens with a digit.
2. No date attached to any reference to a previous visit, treatment, or evaluation: it reads previous visit or previous treatment, never a date. The visit date, certification period, and PT goal target dates in Goal entries are the only dates permitted.
3. Every cue percentage in canonical format traces to a documented finding; unchanged cues have a reason, changed cues have direction and attribution.
4. Education section present.
5. Goal entries and Functional Impact within 200 characters including spaces. Plan field within 255 characters including spaces.
6. No banned phrases. Approved abbreviations only, including the Do NOT use list; outcome measures abbreviated.
7. No parentheses except the mandated Impact field label; no age references, license numbers, visit numbers, or patient names in the note body; the patient is Pt or patient throughout.
8. Assessment data matches Objective exactly; no attainment claims without threshold data.
9. No sentence matches the prior note except the mandated closer. PDGM trajectory coherent across visits; assist moves from the prior note at most one level, more only for documented adverse event regression or provided source data; metric changes plausible for the dx trajectory.
10. Multi date requests: one document per visit date in chronological order, each titled with the pt label and exactly one hyphenated ISO date, as in 2026-07-08, never with the date in spaces; never one combined file.
11. After output, in claude.ai projects: file per Automatic Saving; samples and tests stay unfiled.
