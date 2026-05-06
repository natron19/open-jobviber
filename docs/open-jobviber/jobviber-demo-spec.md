# JobViber Demo - Product Requirements Document

**Document Version:** 1.0
**Last Updated:** May 1, 2026
**Built on:** Open Demo Starter v2.0
**License:** MIT

---

## 1. App Overview

JobViber Demo is a single-user job application tracker with AI-powered cover letter generation. The user maintains a kanban board of their active job applications across four status columns (Applied, Interviewing, Offer, Rejected) and can ask Gemini to write a tailored cover letter for any application. Cover letters are generated from the user's profile (background and key skills) combined with the job description they paste in. Three tone modes (confident, conversational, concise) let the user generate the same letter in different registers without filling out a second form.

The problem this solves is direct: most job seekers write generic cover letters because writing a personalized one for each job is slow. This demo shows that a single AI template, parameterized with profile data and a tone flag, produces meaningfully differentiated output for every application in seconds.

This is one tool from a larger multi-tenant SaaS product, JobViber, which is built for teams: career coaches managing multiple clients, outplacement firms running cohort programs, and HR teams tracking internal applicants. The full product adds multi-tenancy, team collaboration, coach dashboards, and bulk generation. This demo isolates the single most valuable thing any individual user can do in that suite: generate a personalized cover letter from a kanban card. The demo is open source under the MIT license, scoped to a single signed-in user, and runs locally.

---

## 2. Customizations Applied to the Boilerplate

- **App name:** `JobViber Demo` set in `.env.example` as `APP_NAME`
- **Tagline:** `Track your applications. Let AI write the cover letter.` set as `APP_TAGLINE`
- **Description:** `A kanban job tracker with AI cover letter generation. One template, three tones, every application.` set as `APP_DESCRIPTION`
- **Accent color:** `#dc2626` (red) for `--accent`; `#b91c1c` for `--accent-hover`; secondary yellow `#ca8a04` used for "Interviewing" column header and offer badges
- **Navbar links:** "My Board" links to `/board` (the kanban view); "My Profile" links to `/profile`
- **Home page:** `home/index.html.erb` replaced with a landing pitch for JobViber Demo (see Section 6)
- **Dashboard:** `dashboard/show.html.erb` replaced with the kanban board (redirects to `/board`)
- **UX pattern:** Kanban board with four fixed status columns; Stimulus drag-and-drop for card movement; per-card Turbo Frame for cover letter generation
- **AI templates seeded:** `jobviber_cover_letter_v1` (full content in Section 7)

---

## 3. Data Model

### JobSeekerProfile

One profile per user. Used as the source of variables interpolated into every cover letter generation call.

| Field | Type | Notes |
|---|---|---|
| `id` | uuid | Primary key |
| `user_id` | uuid | Foreign key; unique (one profile per user) |
| `background_summary` | text | 2-4 sentence career summary **(template variable)** |
| `key_skills` | text | Comma-separated or freeform skill list **(template variable)** |
| `created_at` | datetime | |
| `updated_at` | datetime | |

Associations: `belongs_to :user`

Validations:
- `user_id`: presence, uniqueness
- `background_summary`: presence, maximum 1000 characters
- `key_skills`: presence, maximum 500 characters

### JobApplication

The core domain record. Each card on the kanban board is one `JobApplication`.

| Field | Type | Notes |
|---|---|---|
| `id` | uuid | Primary key |
| `user_id` | uuid | Foreign key |
| `job_title` | string | **(template variable)** |
| `company` | string | **(template variable)** |
| `status` | string | One of: `applied`, `interviewing`, `offer`, `rejected`; default `applied` |
| `job_description` | text | Pasted from the job posting **(template variable)** |
| `url` | string | Optional link to the original posting |
| `notes` | text | Private notes for the user; not sent to Gemini |
| `applied_on` | date | Optional; shown on the card |
| `created_at` | datetime | |
| `updated_at` | datetime | |

Associations:
- `belongs_to :user`
- `has_many :cover_letters, dependent: :destroy`

Validations:
- `user_id`: presence
- `job_title`: presence, maximum 200 characters
- `company`: presence, maximum 200 characters
- `status`: inclusion in `%w[applied interviewing offer rejected]`
- `job_description`: maximum 8000 characters (gatekeeper input length limit applies at the service layer)
- `url`: format validation if present (must begin with `http://` or `https://`)

### CoverLetter

Each generation attempt produces one `CoverLetter` record linked to the application. Multiple cover letters can exist per application (different tones, regenerations).

| Field | Type | Notes |
|---|---|---|
| `id` | uuid | Primary key |
| `job_application_id` | uuid | Foreign key |
| `tone` | string | One of: `confident`, `conversational`, `concise` |
| `body` | text | Parsed Gemini output (plain text, formatted paragraphs) |
| `gemini_raw` | text | The full, unprocessed Gemini response **(Gemini output, used for Show raw response toggle)** |
| `created_at` | datetime | |
| `updated_at` | datetime | |

Associations:
- `belongs_to :job_application`
- `has_one :user, through: :job_application`

Validations:
- `job_application_id`: presence
- `tone`: inclusion in `%w[confident conversational concise]`
- `body`: presence

---

## 4. Routes

| Verb | Path | Controller#Action | Purpose |
|---|---|---|---|
| GET | `/board` | `board#show` | Kanban board; all applications grouped by status |
| GET | `/profile` | `profiles#show` | View the user's job seeker profile |
| GET | `/profile/edit` | `profiles#edit` | Edit the profile |
| PATCH | `/profile` | `profiles#update` | Save profile changes |
| GET | `/applications` | `job_applications#index` | List view (backup; linked from admin for visibility) |
| GET | `/applications/new` | `job_applications#new` | New application form |
| POST | `/applications` | `job_applications#create` | Save a new application |
| GET | `/applications/:id` | `job_applications#show` | Application detail page |
| GET | `/applications/:id/edit` | `job_applications#edit` | Edit form |
| PATCH | `/applications/:id` | `job_applications#update` | Save edits (also accepts status-only PATCH for drag-and-drop) |
| DELETE | `/applications/:id` | `job_applications#destroy` | Delete the application and its cover letters |
| POST | `/applications/:id/cover_letters` | `cover_letters#create` | Trigger Gemini generation; saves a new CoverLetter |
| DELETE | `/applications/:application_id/cover_letters/:id` | `cover_letters#destroy` | Delete a single cover letter |

All routes require authentication (inherited from `ApplicationController`). No JSON or API routes.

---

## 5. Controllers and Actions

### `BoardController`

**`show`:** Queries `current_user.job_applications` and groups them into four ordered arrays by status (`applied`, `interviewing`, `offer`, `rejected`). Renders the kanban board. Also sets `@profile_complete` (boolean) so the board can show a setup prompt if the user has not yet filled in their profile.

### `ProfilesController`

**`show`:** Finds or initializes `current_user.job_seeker_profile` and renders the profile card.

**`edit`:** Renders the profile form.

**`update`:** Updates the profile with strong parameters. On success, redirects to `/profile` with a flash notice. On failure, re-renders `edit` with validation errors.

### `JobApplicationsController`

**`index`:** Lists `current_user.job_applications` ordered by `created_at desc`. Used as a fallback list view and linked from the admin panel for visibility.

**`new`:** Renders a blank application form.

**`create`:** Saves a new `JobApplication` scoped to `current_user`. On success, redirects to the board. On failure, re-renders `new` with validation errors.

**`show`:** Finds the application by `current_user.job_applications.find(params[:id])`. Renders the application detail page, including all associated cover letters ordered by `created_at desc`.

**`edit`:** Renders the application edit form.

**`update`:** Updates the application. Accepts either a full params set (edit form) or a single `status` param (drag-and-drop PATCH). On status-only update, responds with a Turbo Stream that updates the card's status badge. On full edit, redirects to the show page.

**`destroy`:** Destroys the application and its cover letters. Redirects to the board.

### `CoverLettersController`

**`create`:** This is the action that calls Gemini. It finds the parent `JobApplication` via `current_user.job_applications.find(params[:id])`. It finds or initializes `current_user.job_seeker_profile`. It calls `GeminiService.generate(template: "jobviber_cover_letter_v1", variables: { background_summary: ..., key_skills: ..., job_title: ..., company: ..., job_description: ..., tone: ... })`. It saves the response as a new `CoverLetter` with `body` set to the parsed output and `gemini_raw` set to the full Gemini response. On success, responds with a Turbo Stream that renders the new cover letter partial into the cover letters section of the application show page. Catches `GeminiService::GeminiError` subclasses and renders the boilerplate's error partial inside the same Turbo Frame.

**`destroy`:** Finds the cover letter through the scoped application, destroys it, and responds with a Turbo Stream that removes the cover letter card from the page.

All controllers use strong parameters. All queries are scoped through `current_user`.

---

## 6. Views

### `home/index.html.erb`

The public landing page. A centered hero section with the JobViber logo, the tagline ("Track your applications. Let AI write the cover letter."), and two buttons: "Get started" (links to `/sign_up`) and "Sign in" (links to `/sign_in`). Below the hero, three feature callout cards: "Kanban tracker" (keep everything organized), "AI cover letters" (one template, three tones), and "Open source" (clone it, run it, edit the prompt). No JavaScript beyond the Stimulus bootstrap.

### `dashboard/show.html.erb`

Immediately redirects to `/board` via a `before_action` in `DashboardController`. Keeps the boilerplate's dashboard route working.

### `board/show.html.erb`

The kanban board. Four Bootstrap columns, each representing one status. Column headers: "Applied" (neutral), "Interviewing" (accent yellow `#ca8a04`), "Offer" (accent green Bootstrap success), "Rejected" (muted). Each column lists its `JobApplication` cards using the `_card.html.erb` partial. A "New application" button floats at the top right. If the user has no profile yet, an inline alert prompts them to set up their profile first, with a link to `/profile/edit`. Stimulus drag-and-drop controller handles card movement across columns; dragging a card to a new column fires a PATCH to `/applications/:id` with only `status` in params.

### `board/_card.html.erb`

A Bootstrap card. Shows job title, company name, optional applied date, and a status badge. Two action buttons: "View" (links to the application show page) and "Move to" dropdown (lets the user change status without dragging, for mobile friendliness). The card border-left uses the accent color.

### `profiles/show.html.erb`

Displays the user's profile fields in a two-column card layout. An "Edit" button links to the profile edit form. A note below the skills field reminds the user that this profile is what Gemini uses to personalize cover letters; keeping it current improves output quality.

### `profiles/edit.html.erb`

A simple form with two textareas: "Background summary" and "Key skills." Character counts shown below each field (Stimulus controller). Save and cancel buttons.

### `job_applications/new.html.erb` and `job_applications/edit.html.erb`

Both render the shared `_form.html.erb` partial wrapped in a page card.

### `job_applications/_form.html.erb`

Fields: job title (text input), company (text input), status (select with four options), URL (text input, optional), applied on (date input, optional), job description (textarea, large), notes (textarea, medium). Standard Bootstrap form layout. Submit and cancel buttons.

### `job_applications/show.html.erb`

Two-column layout. Left column (wider): the application details (job title, company, status badge, URL if present, applied date, job description, notes). Right column: the cover letters section. The cover letters section contains the `_cover_letters.html.erb` partial wrapped in a Turbo Frame (`turbo_frame_tag "cover_letters_#{@application.id}"`). The cover letter form is rendered inside this same Turbo Frame so generation updates happen inline without a full page reload.

### `job_applications/_cover_letters.html.erb`

Renders the cover letter generation form (tone radio buttons: confident, conversational, concise; a "Generate cover letter" button) followed by a list of existing cover letters using `_cover_letter.html.erb`. If the user has no profile, the form is replaced with a notice: "Set up your profile before generating a cover letter" with a link to `/profile/edit`.

### `cover_letters/_cover_letter.html.erb`

A Bootstrap card showing: generation timestamp, tone badge, the cover letter body in a preformatted text block, a "Show raw response" Bootstrap collapse toggle (reveals `gemini_raw` in a `<pre>` block with monospace styling), a "Copy to clipboard" button (Stimulus controller, single-line), and a "Delete" button (Turbo Stream response removes the card).

---

## 7. AI Templates and Gemini Integration

### Template: `jobviber_cover_letter_v1`

**Description:** Generates a personalized cover letter from the user's profile and a job description. One template, three tone modes.

**System prompt:**

```
You are an expert career coach who writes highly personalized, natural-sounding cover letters.
Your letters are grounded in the applicant's actual background and the specific job description.
You never invent experience the applicant did not describe, and you never use hollow filler phrases
("passionate about," "team player," "fast-paced environment," "results-driven").

Your letters are structured as follows: one short opening paragraph (one or two sentences) that
names the role and signals genuine fit without restating the job title verbatim; two body
paragraphs that connect the applicant's background and skills to specific requirements in the job
description; one short closing paragraph that states interest in next steps.

Write in plain, direct prose. No bullet points. No headers. No sign-off salutation
(the applicant will add that themselves).

Adjust your register based on the tone directive: confident means authoritative, direct, first-
person strong verbs; conversational means warmer, approachable, slight informality acceptable;
concise means every sentence earns its place, overall letter under 200 words.
```

**User prompt template:**

```
Generate a cover letter for the following job application.

Applicant background:
{{background_summary}}

Key skills:
{{key_skills}}

Job title: {{job_title}}
Company: {{company}}

Job description:
{{job_description}}

Tone directive: {{tone}}

Return only the cover letter body. No salutation, no header, no closing sign-off.
```

**Variables consumed:**

- `{{background_summary}}` - `JobSeekerProfile#background_summary` for `current_user`
- `{{key_skills}}` - `JobSeekerProfile#key_skills` for `current_user`
- `{{job_title}}` - `JobApplication#job_title`
- `{{company}}` - `JobApplication#company`
- `{{job_description}}` - `JobApplication#job_description`
- `{{tone}}` - User-selected value from the cover letter form; one of `confident`, `conversational`, `concise`

**Model:** `gemini-2.0-flash` (default). A cover letter is a mid-length structured task; Flash is appropriate. No justification for Pro.

**max_output_tokens:** 800. A four-paragraph cover letter in plain prose fits well within 800 tokens. Setting this lower than the default 2000 caps runaway output and keeps the output disciplined. The system prompt already instructs the model to be concise; the token cap enforces it.

**Temperature:** 0.8. Slightly above default. Cover letter prose benefits from a little variety; too low and regenerations are nearly identical, undermining the value of the regenerate button.

**Notes:** The single-template / three-tone design is intentional. The tone directive at the end of the prompt acts as a behavioral modifier. Watch for the model occasionally ignoring the concise directive on longer job descriptions; if that happens, add "Maximum 200 words total" to the user_prompt_template when tone is concise (this can be handled in the controller by appending a length note to the job_description variable before interpolation, or by testing a second template variant in the admin UI). The most common failure mode is the model generating a salutation ("Dear Hiring Manager") despite the system prompt; if this becomes frequent, add an explicit negative instruction to the system prompt: "Do not write a salutation line." The notes field in the admin template editor is the right place to track these observed failures during iteration.

**Where it is called:** `CoverLettersController#create`.

**Expected output format:** Plain prose. No JSON. No headers or bullets. The model is instructed to return only the cover letter body. The controller stores `result` directly as `CoverLetter#body` and also stores it as `CoverLetter#gemini_raw`.

**How the response is parsed and rendered:** The raw string from `GeminiService.generate` is stored as-is in both `body` and `gemini_raw`. In the view, `body` is rendered inside a `white-space: pre-wrap` container so paragraph line breaks display correctly. The "Show raw response" toggle reveals `gemini_raw` in a `<pre>` block; for this template the raw and parsed values will be identical since no JSON parsing is needed, but the toggle is present for consistency with the boilerplate's UX expectation.

**Raw response field:** `CoverLetter#gemini_raw`.

---

## 8. AI Safety Considerations (Specific to This App)

### Content Sensitivity

Cover letters are career documents. A job seeker may act on AI-generated output in a consequential professional context: submitting a letter to an employer is a real-world action with real stakes. This makes JobViber Demo moderate on the sensitivity spectrum - not high-stakes like legal advice or mental health, but not trivial like generating social media captions either. A factually incorrect or tone-deaf cover letter could embarrass the user or cost them a job opportunity.

The primary risk is confabulation: the model inserting experience, skills, or qualifications the applicant did not describe. The system prompt explicitly prohibits this ("You never invent experience the applicant did not describe"), and the user's profile is the only factual input. However, Gemini may still hallucinate specifics when the job description contains technical jargon that loosely matches the applicant's skills. The "Show raw response" toggle exposes this for inspection.

### App-Specific Disclaimers

In addition to the boilerplate's footer note, the cover letter card (`_cover_letter.html.erb`) includes a short inline note below the letter body: "Review this letter before sending. AI-generated letters may include inaccurate phrasing or claims not reflected in your actual experience."

The profile edit page includes a note: "The more specific your background summary and skills, the more accurate your cover letters will be. Vague profiles produce generic output."

### Tightened Settings

`max_output_tokens` is set to 800 (vs. the boilerplate default of 2000) because a cover letter has a natural length ceiling and longer output almost always means the model padded rather than improved. The per-user daily cap inherits the boilerplate default of 50 calls/day, which is generous for individual job searching. No tightening needed on the gatekeeper; job descriptions are professional text and are unlikely to trigger injection patterns.

### What This Demo Deliberately Does NOT Do

- **Does not send the cover letter to employers.** The user copies and pastes manually. The demo has no email integration, no form fill, no apply-on-behalf-of capability.
- **Does not review or score the user's existing cover letters.** That would require a second template and an evaluation loop. It is a natural extension for the production app.
- **Does not use the user's resume file.** Profile input is freeform text only. File parsing belongs in the production app where it can be handled securely with proper storage and PII handling.
- **Does not store job descriptions long-term in any shared system.** All data is local to the user's own database. No aggregation, no analytics on job description content.

---

## 9. RSpec Outline

### `spec/models/job_seeker_profile_spec.rb`

- Validates presence of `background_summary` and `key_skills`
- Enforces uniqueness of `user_id` (one profile per user)
- Enforces maximum character lengths on both text fields
- `belongs_to :user` association is required

### `spec/models/job_application_spec.rb`

- Validates presence of `job_title`, `company`, and `user_id`
- Validates `status` is one of the four permitted values
- Rejects invalid URL formats; accepts blank URLs
- `has_many :cover_letters, dependent: :destroy` - destroying the application destroys its letters
- `belongs_to :user` association is required

### `spec/models/cover_letter_spec.rb`

- Validates presence of `job_application_id`, `body`, and `tone`
- Validates `tone` is one of `confident`, `conversational`, `concise`
- `belongs_to :job_application` association is required
- `gemini_raw` is stored separately from `body` (both can coexist, both nullable at model level)

### `spec/requests/board_spec.rb`

- GET `/board` returns 200 for a signed-in user with applications
- GET `/board` returns 200 for a signed-in user with no applications (empty board)
- GET `/board` redirects to sign in for an unauthenticated request
- Each status group contains only applications with the matching status

### `spec/requests/job_applications_spec.rb`

- POST `/applications` with valid params creates an application and redirects to the board
- POST `/applications` with invalid params (missing job title) re-renders `new` with errors
- PATCH `/applications/:id` with only `status` param updates status and responds with Turbo Stream
- DELETE `/applications/:id` destroys the application and redirects to the board
- GET `/applications/:id` returns 404 for an application belonging to a different user (access control)
- PATCH `/applications/:id` with another user's ID returns 404 (access control)

### `spec/requests/cover_letters_spec.rb`

- POST `/applications/:id/cover_letters` with a valid tone calls `GeminiService.generate` with the correct template name and variables (stubbed via the boilerplate's test double)
- POST creates a `CoverLetter` record with `body` and `gemini_raw` populated from the stub response
- POST creates an `LlmRequest` record for the Gemini call
- POST with `GeminiService::BudgetExceededError` renders the error partial with a retry button
- POST with `GeminiService::GatekeeperError` renders the error partial
- POST with `GeminiService::TimeoutError` renders the error partial
- POST returns 404 when the application belongs to a different user (access control)
- DELETE `/applications/:id/cover_letters/:cover_letter_id` destroys the letter and responds with a Turbo Stream; returns 404 for another user's application

### `spec/requests/profiles_spec.rb`

- GET `/profile` shows the profile for the signed-in user
- PATCH `/profile` with valid params updates the profile
- PATCH `/profile` with invalid params (blank background summary) re-renders edit with errors
- The profile form is scoped to `current_user`; a second user's profile is never accessible

---

## 10. Seed Data

### AiTemplate Seeds

`db/seeds.rb` creates the following `AiTemplate` record (full content matches Section 7):

```ruby
AiTemplate.find_or_create_by!(name: "jobviber_cover_letter_v1") do |t|
  t.description = "Generates a personalized cover letter. One template, three tone modes: confident, conversational, concise."
  t.system_prompt = <<~PROMPT
    # (full system prompt text from Section 7)
  PROMPT
  t.user_prompt_template = <<~PROMPT
    # (full user prompt template from Section 7)
  PROMPT
  t.model = "gemini-2.0-flash"
  t.max_output_tokens = 800
  t.temperature = 0.8
  t.notes = "Watch for the model ignoring the concise tone directive on long job descriptions. If salutations appear despite the system prompt instruction, add explicit negative instruction. Tone modifier is the last line in the user prompt - this placement is intentional (it acts as a final override)."
end
```

### Domain Seeds

The seed file creates one `JobSeekerProfile` and three `JobApplication` records for the demo admin user, with one pre-generated `CoverLetter` per application so the demo board looks populated on first load.

**JobSeekerProfile:**
- `background_summary`: "Experienced software engineer with 6 years building web applications in Ruby on Rails and React. Former team lead at a Series B fintech startup; now seeking a senior individual contributor role at a product-led company."
- `key_skills`: "Ruby on Rails, PostgreSQL, React, TypeScript, API design, system design, technical mentoring, agile delivery"

**JobApplication 1 - Applied:**
- `job_title`: "Senior Backend Engineer"
- `company`: "Basecamp"
- `status`: `applied`
- `applied_on`: 7 days ago
- `job_description`: A realistic 300-word Rails-focused backend job description emphasizing async workflows, PostgreSQL performance, and small team culture
- One pre-generated `CoverLetter` with `tone: "confident"` and a realistic body and matching `gemini_raw`

**JobApplication 2 - Interviewing:**
- `job_title`: "Staff Software Engineer"
- `company`: "Linear"
- `status`: `interviewing`
- `applied_on`: 14 days ago
- `job_description`: A realistic TypeScript/React hybrid full-stack posting
- One pre-generated `CoverLetter` with `tone: "conversational"`

**JobApplication 3 - Rejected:**
- `job_title`: "Platform Engineer"
- `company`: "Shopify"
- `status`: `rejected`
- `applied_on`: 21 days ago
- `job_description`: Short, realistic infrastructure-focused posting
- One pre-generated `CoverLetter` with `tone: "concise"`

The seed file is idempotent: each record is created via `find_or_create_by!` so running `bin/setup` twice does not duplicate data.

---

## 11. README Additions

### App Name and Tagline

**JobViber Demo** - Track your applications. Let AI write the cover letter.

### Description

JobViber Demo is an open source, locally-runnable Rails 8 app that combines a kanban job application tracker with AI cover letter generation. Add a job, paste in the description, and click a button to generate a tailored cover letter in one of three tones. The prompt is editable in the admin panel; clone the repo, add your Gemini API key, and tune the output to your own voice.

### Screenshot

*(Screenshot placeholder - add a screenshot of the kanban board with a cover letter card open)*

### Why I Built This

Cover letters are the part of job searching that everyone dreads and most people do badly. Generic letters get ignored; personalized ones take an hour each. I wanted to see how far a single, well-designed AI template could go with the right variables.

This demo is the solo version of one feature from a larger product I am building: JobViber, a multi-tenant job search platform for teams (career coaches, outplacement firms, HR departments). The full version adds coach dashboards, client management, bulk generation, and team collaboration. If that interests you, check out the production app at [jobviber.io](https://jobviber.io).

This demo is open source under the MIT license. Fork it, run it locally, break the prompt, make it better.

### Editing the AI Prompt

The cover letter prompt is not hardcoded. After running `bin/setup`, sign in as `demo@example.com` / `password123` and go to `/admin/ai_templates`. You can edit the system prompt, the user prompt template, the temperature, and the token cap directly in the browser, then click "Test" to see Gemini's response with your sample variable values before saving. No server restart required.

### Setup

Standard boilerplate setup applies (`bin/setup`). This demo requires only one API key beyond the defaults:

- `GEMINI_API_KEY` - Get a free key at [aistudio.google.com](https://aistudio.google.com). The free tier is sufficient for local demo use.

No other additional setup steps beyond the boilerplate's `bin/setup`.

---

## 12. Bootstrap Dark Mode and Accent Color Notes

### UX Pattern

Kanban board with four fixed-width Bootstrap columns in a scrollable horizontal layout. Each column is a `col-auto` with a fixed minimum width (approximately 280px) inside a horizontally scrollable `overflow-x: auto` container. On mobile, the columns stack vertically (standard Bootstrap responsive behavior).

### Accent Color Application

- **Primary buttons:** All `btn-primary` instances use `--accent` (`#dc2626`) via a CSS override in `_accent.scss`. This applies to "Generate cover letter," "Save," "Add application," and other CTA buttons across the app.
- **Active nav state:** The active navbar link uses `--accent` for its text color.
- **Column header - Interviewing:** The "Interviewing" column header text uses the secondary yellow (`#ca8a04`) to visually distinguish mid-funnel from top-funnel. This is the only place the secondary color appears.
- **Cover letter card border:** The left border of each cover letter card uses `var(--accent)` (a 4px solid border-left in red), matching the accent applied to application cards on the board.
- **Status badges:** Bootstrap contextual colors used directly (`badge bg-secondary` for applied, `badge bg-warning text-dark` for interviewing, `badge bg-success` for offer, `badge bg-danger` for rejected). No custom CSS needed for badges.

### Custom CSS

Two additions to `app/assets/stylesheets/application.css` beyond the boilerplate:

1. The kanban board container: `overflow-x: auto` on the row, `min-width: 280px` on each column, consistent card height to align column footers.
2. The cover letter body display: `white-space: pre-wrap; font-family: Georgia, serif; line-height: 1.7` applied to the `<div>` that renders `cover_letter.body`, giving the output a document-like feel distinct from the surrounding UI.

The Stimulus drag-and-drop controller handles `dragstart`, `dragover`, and `drop` events on the kanban columns. On `drop`, it fires a `fetch` PATCH to the application's update route with `{ job_application: { status: targetColumnStatus } }`. On success, the card's status badge updates via the Turbo Stream response from the server. No external drag-and-drop libraries are needed.

---

*v1.0 - JobViber Demo spec. Built on Open Demo Starter v2.0. Open source under MIT license.*
