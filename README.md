# JobViber Demo

> Track your job applications. Let AI write the cover letter and tailor your resume.

A kanban-style job tracker built on [Open Demo Starter](https://github.com/your-org/open-demo-starter) — Rails 8, Turbo, Stimulus, Bootstrap 5 dark mode, and Google Gemini. Every application gets AI-generated cover letters in three tones and a tailored resume built strictly from your own background — no hallucination.

## Demo credentials

```
Email:    demo@example.com
Password: password123
```

Sign in to see a pre-seeded board with three applications and pre-generated cover letters.

## Features

- **Kanban board** — drag cards between Applied, Interviewing, Offer, and Rejected columns; or use the "Move to" dropdown on mobile
- **Application tracking** — job title, company, status, applied date, job posting URL, job description, private notes
- **AI cover letters** — three tone modes (Confident, Conversational, Concise); each letter is grounded in your profile and the job description
- **AI resume generation** — one click produces a tailored, ATS-friendly resume using only what you wrote in your profile — the AI is instructed to omit sections rather than invent content
- **Profile** — background summary, key skills, work history, and education feed both AI features

## Setup

### Requirements

- Ruby 3.2+
- PostgreSQL 15+
- A free [Google Gemini API key](https://aistudio.google.com/app/apikey)

### Steps

```bash
git clone <this-repo> && cd open-jobviber
cp .env.example .env          # then add your GEMINI_API_KEY
bin/setup                     # installs gems, creates and migrates the database, seeds demo data
bin/rails server
```

Visit [http://localhost:3000](http://localhost:3000) and sign in with the demo credentials above.

### Environment variables

| Variable | Default | Description |
|---|---|---|
| `GEMINI_API_KEY` | (required) | Free key at [aistudio.google.com](https://aistudio.google.com/app/apikey) |
| `APP_NAME` | `"JobViber Demo"` | Navbar and page title |
| `APP_TAGLINE` | — | Footer and landing hero |
| `APP_DESCRIPTION` | — | Landing page meta |
| `AI_CALLS_PER_USER_PER_DAY` | `50` | Daily AI budget per user |
| `AI_GLOBAL_TIMEOUT_SECONDS` | `15` | Gemini request timeout |

## Editing the AI prompts

Both prompts live in the database as `AiTemplate` records, editable through the admin panel at `/admin/ai_templates` (sign in with an admin account).

| Template | Purpose | Key tuning notes |
|---|---|---|
| `jobviber_cover_letter_v1` | Cover letters | Three tones set by the last line of the user prompt. Raise `max_output_tokens` if letters are cut short — Gemini 2.5 Flash thinking tokens count against this budget. |
| `jobviber_resume_v1` | Tailored resumes | Temperature set to 0.4 to reduce embellishment. System prompt instructs the model to omit sections rather than fabricate content when the applicant's profile is sparse. |

To test a prompt change without touching real data, use the **Test** button in the admin template editor — it renders a live Gemini response inline.

Changes to `db/seeds.rb` take effect on the next `rails db:seed` run (seeds use `find_or_initialize_by`, so re-seeding updates existing templates without creating duplicates).

## Responsible AI

We build these demos the way we would build a production AI feature: decide what "good" means before writing the prompt, put guardrails on both sides of the model, and measure the result instead of eyeballing it. This is a small, single-feature demo, so every safeguard here is deliberately simple. Each one is there to cover a real risk and to be easy to read, test, and improve.

### Guardrails

**Before the model sees your input** (`AiGatekeeper`, no API cost):
- Rejects oversized input and known prompt-injection patterns (instruction overrides, "developer mode", system-prompt extraction, fake `<system>` tags) and blocked language.

**Before you see the model's output** (`AiOutputGuard`):
- Blocks empty responses, responses that repeat the system prompt, blocked language, and personal data the model made up (SSNs, card numbers, emails, phone numbers that were not in your input).

**Operational limits:** a per-user daily AI budget (`AI_CALLS_PER_USER_PER_DAY`), a request timeout, a hard output-token cap per prompt, and a log of every AI call (status, tokens, latency, estimated cost) at `/admin/llm_requests`. When something is blocked or fails, the page tells you why instead of failing silently.

### How we evaluate it

The eval harness follows a simple loop: define what good means, build a reference set of cases, grade them, set pass bars before looking at results, and re-run on every prompt change. Details are in [`docs/ai-evals.md`](docs/ai-evals.md).

| What we check | How | Run it |
|---|---|---|
| Guardrails catch attacks and leave normal input alone | Offline attack and look-alike suite, no API cost | `bin/rails evals:guardrails` |
| Output has the right shape | Code checks: required fields, counts, lengths | `bin/rails evals:run` |
| Output is actually good | An LLM judge scores each case 1–5 against a written rubric, after first proving it agrees with human-labeled examples | `bin/rails evals:run` |
| Latency, cost, and error rate | Read from the request log for each eval case | `bin/rails evals:run` |
| The real feature works in a browser | Headless Chrome walks the main AI feature, plus a blocked-input journey | Maintainer's fleet test harness, run before releases |

This app has 14 eval cases (typical, edge-case, adversarial, and benign look-alike inputs). The judge scores it on:

- **Accurate:** Every experience, employer, credential, degree and metric in the letter appears in the applicant's background summary or key skills. Nothing is invented or inflated.
- **Useful:** The letter is tailored to this job description, connecting specific requirements in the posting to specific parts of the applicant's background rather than generic praise.
- **Steerable:** The letter follows the requested tone directive and the structure asked for (no salutation, no header, no sign-off, no bullet points).
- **Accurate:** Every job title, employer, date, degree, institution, technology and metric in the resume appears in the applicant's background, skills, work history or education. Nothing is invented or embellished.
- **Useful:** The resume emphasises and orders the applicant's real experience by relevance to the target job description.
- **Steerable:** The resume is plain text with section headers, omits sections that had no input, and has no preamble, commentary or contact block.

**Current status (October 2026):** the guardrail suite passes: 12/12 input attacks and 7/7 output attacks blocked, with no false positives (18/18 and 6/6 benign cases allowed). Live-model eval baselines are being run next and will be published here. Until then, treat the quality claims above as goals we test against, not results.

### What this demo does and doesn't do

**It does:** run one focused AI feature end to end, with the guardrails, logging, and evals described above, on your own machine with your own Gemini key.

**It doesn't (yet):**
- Guarantee correct output. Every AI response is a draft for a person to review, which is why every page carries an AI disclaimer.
- Catch every attack. The input and output guards are pattern-based. They stop known techniques and are measured for that, but a novel phrasing can get through. That is why the output guard and the evals exist as a second layer.
- Scrub personal data from what you type. Don't paste anything sensitive into a local demo.
- Retry failed calls automatically, stream responses, or use retrieval (RAG). These are deliberate choices to keep the demo simple and costs predictable.

## Contributing and feedback

This project is open source and we want it to be useful to real people. Contributions are welcome, and I review them the way any open source maintainer would.

- **Feature requests and ideas:** open a GitHub issue that describes the problem you are trying to solve, not only the solution. Examples of the outputs you wish you got are especially helpful.
- **Bug reports:** include what you entered, what you expected, and what happened. For AI quality problems, the output itself is the most useful evidence.
- **Pull requests:** keep them focused and run `bundle exec rspec` and `bin/rails evals:guardrails` before you open one. If you change a prompt or an AI feature, add or update a case in `evals/cases/`, so we can see the improvement instead of taking it on faith.
- **Reviews:** I read every issue and review every pull request personally. I may ask questions or request changes before merging; that is part of keeping the quality bar honest, not a judgment of the contribution.
- **Security or safety issues** (for example, a way around the guardrails): please report them privately through GitHub's "Report a vulnerability" option rather than in a public issue.

## Stack

| Layer | Choice |
|---|---|
| Framework | Rails 8.1 |
| Database | PostgreSQL with UUID primary keys |
| Auth | Rails native (`has_secure_password`, sessions) |
| CSS | Bootstrap 5 dark mode (CDN) |
| JavaScript | Stimulus + Turbo via importmap |
| AI | Google Gemini 2.5 Flash via `gemini-ai` gem |
| Queue / Cache / Cable | Solid Stack (no Redis) |
| Testing | RSpec |

## License

MIT — see [LICENSE](LICENSE)
