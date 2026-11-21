### Operators (`op`)
- **`GT`** = **Greater Than** (`>`) — e.g. `tFluid GT 499` means `500+ mL`
- **`LT`** = **Less Than** (`<`) — e.g. `o2Sat LT 85` means `SpO2 < 85%`
- **`EQ`** = **Equal To** (`==`) — exact match (best for `peep` or `defib` energy)

> **Rule of thumb:** Inside a single transition, **ALL** conditions must be true (**AND**). Between multiple transitions in the same state, the **first** one that matches from top to bottom triggers (**OR**).

---

### Numeric Conditions
| Type | Meaning | Typical Values |
| :--- | :--- | :--- |
| **`time`** | Seconds spent in **this** state (resets to `0` on every state change) | `30`, `60`, `180` |
| **`doa`** | **Depth of Anesthesia** (`mac + mic`) | `0.3` sedated · `0.7` asleep · `1.2–2.0` surgical · `> 2.8` too deep |
| **`mac`** | Volatile gas MAC only (`Sevo`, `Des`, `Iso`, `N2O`) | `0.5`, `1.0`, `1.5` |
| **`mic`** | IV anesthetics & opioids only (`Propofol`, `Etomidate`, `Fentanyl`) | `0.5`, `1.0` |
| **`nmb`** | **Neuromuscular Blockade** (paralysis level) | `0` none · `0.5` partial · `0.8+` fully paralyzed |
| **`tFluid`** | **Total IV fluid** given across the case (mL) | `299` (300 mL) · `499` (500 mL) · `999` (1 L) |
| **`o2Sat`** | **SpO2 %** | `LT 88` desaturation · `LT 65` severe hypoxia |
| **`peep`** | Set **PEEP** (cmH2O) | `5`, `10` |
| **`defib`** | Unsynchronized **Defibrillator** shock (Joules) | `GT 199` (200+ J) |
| **`sync`** | **Synchronized Cardioversion** (Joules) | `GT 49` (50+ J) |
| **`nitrousOxide`** | Alveolar N2O % | `GT 50` |

---

### Drug Conditions
| Type | Meaning | Example |
| :--- | :--- | :--- |
| **`bDrug`** | **Single IV bolus** of that drug (checks the *last* bolus pushed; does **not** sum split doses) | `Phenylephrine GT 99` = single `100+ mcg` bolus |
| **`iDrug`** | **Active infusion rate** of that drug (in its dropdown units) | `Norepinephrine GT 0.04` = `0.05+ mcg/kg/min` |

---

### Boolean (`true` / `false`) Conditions
- **Airway & Intubation:**
  - `tubeTrachea` — ETT is correctly in the **trachea** *(best one to use for "intubated successfully")*
  - `airwayTube` — ETT is placed *(even if esophageal)*
  - `tubeEsoph` / `tubeMainstem` / `tubeAbove` — ETT is in esophagus / right mainstem / pulled above cords
  - `airwayLma` / `airwayCrico` — LMA or cricothyroidotomy is in place
  - `tryLaryTube` / `tryFo` / `tryLma` — fires the moment the user attempts laryngoscopy / fiberoptic / LMA
  - `suction`, `adjustHead`, `oralAirway`, `nasalAirway`, `doingCricoid`, `checkTube`, `checkCircuit`
- **Surgeon & Resuscitation:**
  - `makeIncision` — user clicked **Make Incision** in the Surgeon tab
  - `doingSurgery` — surgeon is actively operating
  - `chestTube`, `floodField`, `aspirateCvp`, `doingCpr`
- **Position & Temperature:**
  - `level` (supine), `trend` (Trendelenburg), `revTrend` (Reverse Trendelenburg)
  - `warmIv`, `warmBlanket`, `icedIv`, `icePack`, `icedLavage`

---

### State Settings Quick Reference
- **`finalState`**:
  - `0` = normal active state
  - `1` = **Win / End of case** (`High Pass` if score > 79%, otherwise `Pass`)
  - `-1` = **Fail** (patient survived)
  - `-2` = **Fail** (patient died)
- **`laryTubeSuccess`**: `1` = Grade 1 view (goes into trachea) · `0` = coughing / fails into esophagus · `-1` = Grade 4 / fails into esophagus
- **`airwayStr`**: `nl` (normal) · `restricted` (bronchospasm / shark-fin CO2) · `obstructed` (laryngospasm / coughing)