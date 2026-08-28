# Phase 6 — Validation Benchmark

Run everything through OpenCode. Save all outputs to `./local-validation/`
with timestamps (`date +%Y%m%dT%H%M%S`). Work from a scratch copy:

```bash
TS=$(date +%Y%m%dT%H%M%S)
mkdir -p local-validation/bench-$TS && cp -R local-stack/validation/coding/fixtures local-validation/bench-$TS/
cd local-validation/bench-$TS && opencode   # coding model is the default
```

## Coding track (coding model) — paste each prompt into the OpenCode session

1. **Greenfield** — "Create `app/main.py`: a FastAPI async endpoint
   `POST /orders` with Pydantic v2 request validation (model with sku:str,
   quantity:int>0, customer_id:str), proper error handling returning
   RFC-ish JSON errors with correct status codes, plus `tests/test_orders.py`
   with pytest + httpx AsyncClient covering success and validation failure."
   Verify: `pip install fastapi httpx pytest && pytest tests/ -q` and the
   app imports clean.
2. **Refactor** — "Split `fixtures/legacy_module.py` into `models.py`,
   `repository.py`, `service.py` in a package `orders/`, correcting all
   imports across the three files and keeping behavior identical. Add
   `orders/__init__.py` re-exporting the public names."
   Verify: `python -c "from orders import OrderService, OrderRepository, Product, PaymentMethod; from decimal import Decimal; r=OrderRepository(); s=OrderService(r); r.save_product(Product('A','a',Decimal('2'),5)); o=s.create_order('c1',[('A',2)]); s.pay(o.order_id, PaymentMethod.CARD); print(s.revenue_report())"`
3. **Debug** — paste `fixtures/stacktrace.txt` contents and say: "This
   trace comes from `fixtures/async_bug.py`. Diagnose the race condition
   and fix the file so 200 concurrent fetches plus a concurrent `warm()`
   never raise and never return None." Verify: `python fixtures/async_bug.py`
   runs clean 5 times in a row. (Real bugs planted: an await between the
   in-flight check and future registration is not the issue — the pop after
   set_result races with `warm()`'s pop, and `warm` clearing `_inflight`
   strands waiters; a correct fix guards the pop and/or locks.)
4. **Tests** — "Write `tests/test_service.py`: parametrized pytest coverage
   for `orders/service.py` (from task 2) including edge cases: zero/negative
   quantity, unknown sku, invalid status transitions, cancel-restocks-stock,
   duplicate-sku line merge, empty order total." Verify: `pytest -q`, and
   deliberately break one service method to confirm the tests catch it.
5. **Tool use** — "Without asking me anything: (1) create `pkg/config.py`
   with a `load(path)` reading JSON, (2) create `pkg/defaults.json` with
   keys host/port, (3) create `pkg/__main__.py` printing the loaded config,
   (4) create `pkg/__init__.py`, then (5) run `python -m pkg` and fix
   whatever breaks until it prints the config." Verify: at least four file
   operations happened without intervention and `python -m pkg` works.

**Scoring per task:** 2 = runs correctly as delivered · 1 = minor fixes
needed · 0 = broken or hallucinated APIs. **Cutover gate: ≥ 7/10.**

## Documentation track (docs model) — switch with `/models`

Generate 5 fictitious PTA clinical notes using the ported rules files (all
patient data fictitious R&D test data), covering at minimum:
- 1 home health visit note (Kinnser rules: markdown table format, PDGM,
  homebound status)
- 1 outpatient session note with timed CPT sections (Raintree rules)
- 3 more of your choice across the ported settings

Audit **each note** against the ported rules files (not from memory):

| Check | Pass criterion |
|---|---|
| a. CPT codes | every code appears in the ported CPT table; ANY invented code = automatic fail for that note |
| b. Abbreviations | only abbreviations on the ported approved list |
| c. Goals | every goal ≤ 200 characters |
| d. Template | structure matches the ported format exactly |

**Cutover gate: 5/5 notes pass all four checks — no tolerance.** Any fail →
the documentation model is **draft-only with mandatory line-by-line human
review**, and the Phase 7 report must say so explicitly. A failure here
also requires diagnosing whether the **model** or the **Phase 4 port** is
at fault before scoring: re-open the ported skill file, confirm the rule
the note violated is present and verbatim (port OK → model at fault; rule
missing/mangled → port at fault, fix the port and re-run the track).

Record scores in `local-validation/phase6-scores.md` as:
`task | score | notes` (coding) and `note | a | b | c | d | pass/fail` (docs).
