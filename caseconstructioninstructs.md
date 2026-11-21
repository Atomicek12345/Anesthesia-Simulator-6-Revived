```markdown
# Anesthesia Simulator — AI Case Authoring Guide

This document defines the exact format, physics/pharmacology behavior, and Finite State Machine (FSM) rules for creating custom cases (`cases/Anesth6CaseXX.js`) for this modified Anesthesia Simulator.

---

## 1. File Placement & Registration
1. Save the file as `cases/Anesth6Case<N>.js` (e.g., `cases/Anesth6Case35.js`).
2. Register it in `index.html` under `<!-- case files -->`:
   ```html
   <script src="cases/Anesth6Case35.js" type="text/javascript"></script>
   ```
3. The file must assign a single object to `CaseData[<N>]`:
   ```javascript
   CaseData[35] = {
       "title": "Case 35 - ...",
       ...
       "states": [ ... ]
   };
   ```
   - `states[0]` is **always** the starting state.
   - `ShowNewCaseScreen()` automatically populates the Case Library dropdown from `CaseData[1..length-1]`.

---

## 2. Upgraded Engine Behavior (Important Context)
This simulator has been upgraded beyond the original static 2013 engine. **Do NOT script manual workarounds for these—the engine handles them automatically:**

1. **Smooth State Transitions:** When transitioning between states, `baseHr`, `baseAbpS/D/M`, `cvp`, `pap*`, and `cardiacOutput` glide smoothly over ~15–30 seconds (`0.07`/sec; `0.5`/sec on cardiac arrest).
2. **Live Physiological Variability:** Heart rate, ABP, SpO2 rate, spontaneous RR/TV, and EtCO2 have continuous RSA/Mayer/autonomic variability. Variability is automatically disabled when `baseHr == 0` or `rhythm` is `"Vfib2"` or `"Asystole1"`.
3. **Snappy Two-Step Pharmacology (`ke0 = 0.15`):**
   - Boluses have a smooth ~15–30s onset curve (`effectSiteLevel`) and continuous redistribution/washout (after 15s for `hr`/`bp` drugs; after `0.5 * effectSec` for `mic`/`nmb`).
   - `hr` and `bp` clamps are `[-45, 60]` and `[-50, 60]`.
   - **Secondary Hemodynamic Effects** are built in:
     - `Propofol`, `Thiopental`, `Methohexital` → transient hypotension.
     - `Ketamine` → raises HR and BP.
     - `Fentanyl`, `Alfentanil`, `Sufentanil`, `Remifentanil`, `Morphine` → mild HR/BP reduction.
     - `Epinephrine`, `Ephedrine` → raise HR + BP.
     - `Phenylephrine` → raises BP + mild reflex bradycardia.
     - Volatile MAC (`PrpMac`) → dose-dependent BP reduction (`-10 * PrpMac`).
4. **Active Metabolic, Airway & Renal Drugs:**
   - `Insulin` (bolus/infusion) lowers `PrpGlucose` and shifts `PrpPotassium` (`K+`) down.
   - `Dextrose50` raises `PrpGlucose`.
   - `Lidocaine` blunts elevated HR (>85) and SBP (>125) and adds mild MAC-sparing `mic` (`+0.12` to `+0.18`).
   - `Albuterol`, `Isoetharine`, `Metaproterenol`, `Aminophylline`, `Epinephrine` actively lower high `contPip`, improve obstructed tidal volume, and flatten `"restricted"` shark-fin capnograms when `bronchoLvl >= 0.65`.
   - `Furosemide` and `Mannitol` multiply `rateUo` (urine output).

---

## 3. Case-Level Schema (`CaseData[N]`)
Missing properties fall back to `CaseDefault`:
- `title` *(string)*: `"Case 35 - 58 year old with ..."`
- `preopMsg` *(string)*: Pre-op H&P, meds, allergies, exam, labs, NPO status (supports `\n`).
- `learningObj` *(string)*: Learning objectives shown in Case Help.
- `debriefMsg` *(string)*: Summary shown in Case Log once `finalState != 0`.
- `possiblePoints` *(number)*: Max positive score (aim to match the sum of optimal-path transition points; `> 79%` = High Pass).
- `leanBodyMass` *(number)*: Patient weight in kg (used for all drug dosing & tidal volume scaling).
- `initialSat` *(number)*: Starting SpO2 (e.g., `97`).
- `badDrugs` *(string[])*: Drug `nameStr` values that deduct `badDrugScore` points whenever given (e.g., `["Succinylcholine"]`).
- `badDrugScore` *(number)*: Penalty per bad drug (default `50`).
- `coMin` *(number)*: Minimum cardiac output for gas uptake (default `1.2`).
- `depthCarina` *(number)*: cm (default `25`).
- `depthCords` *(number)*: cm (default `18`).
- `depthTubeInitial` *(number)*: cm (default `22`).
- `durationPrep` *(number)*: Surgeon prep duration in seconds (e.g., `45`).
- `durationSurgery` *(number)*: Surgery duration in seconds (e.g., `1200`).
- `imageSet` *(number)*: Patient photo set ID (`1`–`10`, e.g., `5` or `7`).
- `volAnDsp` *(number)*: Anatomic dead space in mL (default `80`).
- `helpFlag` *(boolean)*: `true`.
- `states` *(array)*: Array of State objects.

---

## 4. State-Level Schema (`states[i]`)
Missing properties fall back to `StateDefault`:

### Identity & Flow
- `name` *(string, UPPERCASE)*: Unique state ID (e.g., `"AWAKE"`, `"INDUCED"`, `"BRONCHOSPASM"`).
- `finalState` *(number)*:
  - `0` = Normal active state
  - `1` = Case completed successfully (stops management, grades Pass/High Pass)
  - `-1` = Fail (patient survived)
  - `-2` = Fail (patient died)
- `whatNextMsg` *(string)*: Hint shown in Case Help → "What Now?".
- `recordMsg` *(string)*: Entry printed in the Case Log upon entering this state.
- `overdoseFlag` *(boolean)*: `true` normally; set `false` in arrest/dead states so resuscitative doses don't trigger overdose.

### Hemodynamics & ECG
- `baseHr` *(number)* & `spRate` *(number)*: Baseline HR & SpO2 pulse rate (`0` for arrest).
- `baseAbpS`, `baseAbpD`, `baseAbpM` *(numbers)*: Systolic, Diastolic, Mean BP (`18` for arrest).
- `rhythm` *(string, MUST be one of)*:
  - `"Sinus1"`, `"Sinus2"`, `"Sinus3"`, `"Sinus4"`, `"Sinus5"`, `"Sinus6"`
  - `"St1"` (mild ST), `"St2"` (moderate ST), `"St3"` (severe ST)
  - `"Afib6"` (Atrial Fibrillation)
  - `"Vtach3"` (Ventricular Tachycardia)
  - `"Vfib2"` (Ventricular Fibrillation)
  - `"Asystole1"` (Asystole)
- `stSegII`, `stSegV5` *(numbers)*: ST segment deviation in mm (e.g., `0.0`, `-2.5`).
- `cardiacOutput` *(number)*: L/min (e.g., `5.0`, or `0.2` in arrest).
- `cvp`, `papS`, `papD`, `papM`, `papW` *(numbers)*: Filling & PA pressures.
- `spSignal` *(number)*: `3` (`***`), `2` (`**`), `1` (`*`), or `0` (`---`).

### Airway & Respiratory
- `airwayStr` *(string, MUST be one of)*:
  - `"nl"` (normal)
  - `"restricted"` (bronchospasm — raises PIP, produces shark-fin capnogram; responds to bronchodilators)
  - `"obstructed"` (coughing/laryngospasm — severely reduces TV, produces humped capnogram)
- `spontRr` *(number)*, `spontTv` *(number)*: Spontaneous RR (bpm) and TV (mL). Set to `0` when apneic/anesthetized.
- `contPip` *(number)*: Baseline PIP scaling factor for controlled ventilation (normal `24`–`28`, bronchospasm `45`–`60`).
- `sat20`, `sat40`, `sat100` *(numbers)*: Target SpO2 at FiO2 20%, 40%, 100%.
- `laryTubeSuccess` *(number)*:
  - `1` = Grade 1 view → ETT goes into trachea
  - `0` = Coughing/poor view → ETT goes into esophagus
  - `-1` = Grade 4 view → ETT goes into esophagus
  - `-2` = Good view of cords → ETT goes into esophagus
- `lmaSuccessFlag` *(boolean)*: `true` if LMA insertion succeeds in this state.
- `sputumAmount` *(number)*: `0` (minimal), `1` (moderate), `2` (copious secretions).
- `hiCo2ProdFlag` *(boolean)*: `true` for malignant hyperthermia / hypermetabolic CO2 surge.

### Labs, Bleeding & Exam Messages
- `temperature` *(number °C)*, `hct` *(number %)*, `sodium` *(number)*, `basePot` *(number)*, `baseBicarb` *(number)*, `glucose` *(number)*.
- `rateEbl` *(number mL/min)*: Active blood loss while surgeon is operating.
- `rateUo` *(number mL/min)*: Baseline urine output.
- Exam strings: `mentalStatusMsg`, `pupilsMsg`, `lidReflexMsg`, `breathSoundsMsg`, `heartSoundsMsg`, `pulseMsg`, `skinMsg`, `aspirateCvpMsg`.

---

## 5. Transitions (`trans`) & Conditions Reference
Each state has a `trans: [ ... ]` array evaluated **once per second** in **top-to-bottom order**:
- **Between transitions:** OR logic (the **first** transition whose conditions all pass fires).
- **Inside `conditions`:** AND logic (**ALL** conditions in the array must be true).

```javascript
{
    "nextState": "TARGET_STATE",
    "comment": "Log message shown when transition fires. (+100 points)",
    "points": 100,
    "conditions": [
        { "type": "doa", "op": "GT", "value": 0.6 }
    ]
}
```

### Valid Operators (`op`)
- `"GT"` (`>`), `"LT"` (`<`), `"EQ"` (`==`)

### Valid Condition `type`s
1. **Numeric (`op` + `value`):**
   - `"time"`: Seconds elapsed in the **current** state (resets to `0` on every transition).
   - `"doa"`: Depth of Anesthesia (`mac + mic`). Typical: `0.3` sedated, `0.7` asleep, `1.2–2.0` surgical, `> 2.8` excessive.
   - `"mac"`: Volatile MAC only.
   - `"mic"`: IV anesthetic/opioid depth only.
   - `"nmb"`: Neuromuscular blockade (`0.8+` = full paralysis).
   - `"tFluid"`: Total IV fluid administered in mL (LR + NS + Albumin + PRBC).
   - `"o2Sat"`: SpO2 %.
   - `"peep"`: Set PEEP (cmH2O).
   - `"nitrousOxide"`, `"halothane"`: Alveolar gas %.
   - `"defib"`, `"sync"`: Defibrillator / synchronized cardioversion Joules.
2. **Drug Triggers (`drug` + `op` + `value`):**
   - `"bDrug"`: **Single bolus** check (checks only the most recent bolus; **does not sum** split doses). Use exact `DrugInfo.Drugs[i].nameStr` (e.g., `"Phenylephrine"`, `"Ephedrine"`, `"Epinephrine"`, `"Albuterol"`, `"Atropine"`, `"Dantrolene"`, `"Insulin"`, `"Dextrose50"`, `"Amiodarone"`, `"Lidocaine"`, `"SodiumBicarb"`, etc.).
   - `"iDrug"`: Active infusion rate check.
3. **Boolean (`value: true | false`, no `op`):**
   - Airway: `"tubeTrachea"` *(preferred for successful intubation)*, `"airwayTube"`, `"tubeEsoph"`, `"tubeMainstem"`, `"tubeAbove"`, `"airwayLma"`, `"airwayCrico"`, `"tryLaryTube"`, `"tryFo"`, `"tryLma"`, `"checkTube"`, `"suction"`, `"adjustHead"`, `"oralAirway"`, `"nasalAirway"`, `"doingCricoid"`, `"checkCircuit"`.
   - Surgery & Resuscitation: `"makeIncision"`, `"doingSurgery"`, `"chestTube"`, `"floodField"`, `"aspirateCvp"`, `"doingCpr"`.
   - Position & Temp: `"level"`, `"trend"`, `"revTrend"`, `"warmIv"`, `"warmBlanket"`, `"icedIv"`, `"icePack"`, `"icedLavage"`.

---

## 6. Best Practices for Designing Great Cases
1. **Never strand the player:** Every non-final state (`finalState == 0`) should have at least one valid exit path (plus a realistic deterioration or timeout path if an emergency goes untreated).
2. **Verify every `nextState`:** Every `nextState` string must match a `name` in `states[]` (exact uppercase match).
3. **Prefer `doa` / `nmb` / `tubeTrachea` over `bDrug` for general anesthesia steps:** That lets the clinician choose *which* induction agent, opioid, or paralytic they prefer (e.g., Propofol vs. Etomidate, Rocuronium vs. Succinylcholine) unless a specific drug is clinically required.
4. **Order transitions carefully:** Put emergency/penalty transitions or higher-priority branches **above** generic fallback `time` transitions so they aren't shadowed.
5. **Balance `possiblePoints`:** Sum the points of the intended optimal path and set `possiblePoints` to that total.
6. **Avoid `finalState: 1` too early:** Only set `finalState: 1` on the true end-of-case state (or stable maintenance if the case ends once stabilized), because `finalState != 0` immediately locks management controls and grades the case.
```