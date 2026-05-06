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

## AI safety

- Per-user daily call cap (default: 50/day)
- Pre-flight gatekeeper: input length limit (15,000 chars), prompt injection pattern detection, profanity filter
- Hard output token cap per template
- Configurable request timeout
- Full request log at `/admin/llm_requests` — status, tokens, duration
- Fail-soft UI: Gemini errors render an inline alert, never crash the page
- AI disclaimer in the footer on every page

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
