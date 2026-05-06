# JobViber Demo — Build Tasks

Tracks implementation progress phase by phase. Check off items as they are completed.  
Full spec: `docs/open-jobviber/jobviber-demo-spec.md`  
Phased detail: `docs/open-jobviber/jobviber-phases.md`

---

## Phase 0 — App Bootstrap & Branding

### Implementation
- [x] Update `.env.example` with `APP_NAME`, `APP_TAGLINE`, `APP_DESCRIPTION`, and all required env vars
- [x] Add accent color, kanban layout, and cover-letter body CSS to `application.css`
- [x] Update navbar in `layouts/application.html.erb` with "My Board" and "My Profile" links (signed-in only)
- [x] Replace `home/index.html.erb` with JobViber landing (hero + 3 feature cards)
- [x] Add `before_action :redirect_to_board` to `DashboardController`
- [x] Add domain routes (`/board`, `/profile`, `/applications`, `/cover_letters`) to `routes.rb`
- [x] Rename all database entries in `config/database.yml` from `open_base_*` to `open_jobviber_*`

### Manual Tests
- [x] `/` shows tagline, red accent buttons, three feature cards
- [x] Sign-in form renders with no errors; submit button uses accent color
- [x] Navbar shows "My Board" and "My Profile" when signed in; hides them when signed out

### RSpec
- [ ] Run `bundle exec rspec spec/requests/sessions_spec.rb` — all pass (no regressions)

---

## Phase 1 — Data Models & Migrations

### Implementation
- [x] Migration: `create_job_seeker_profiles` (UUID PK, `user_id` unique index)
- [x] Migration: `create_job_applications` (UUID PK, status index, composite index on user_id + created_at)
- [x] Migration: `create_cover_letters` (UUID PK, index on job_application_id + created_at)
- [x] `rails db:migrate` completes cleanly
- [x] Model: `JobSeekerProfile` — associations, validations (presence, uniqueness, length)
- [x] Model: `JobApplication` — associations, validations (presence, status inclusion, URL format, job_description max 3500)
- [x] Model: `CoverLetter` — associations, validations (presence, tone inclusion)
- [x] `User` model: add `has_one :job_seeker_profile` and `has_many :job_applications`
- [x] Factory: `spec/factories/job_seeker_profiles.rb`
- [x] Factory: `spec/factories/job_applications.rb` (with `:interviewing`, `:offer`, `:rejected` traits)
- [x] Factory: `spec/factories/cover_letters.rb` (with `:conversational`, `:concise` traits)

### Manual Tests
- [x] `rails db:migrate` runs with no errors
- [x] Rails console: create a valid `JobApplication`, verify it saves
- [x] Rails console: blank `job_title` on `JobApplication` → validation error
- [x] Rails console: invalid URL on `JobApplication` → format validation error
- [x] Rails console: second `JobSeekerProfile` for same user → uniqueness error

### RSpec
- [x] Write `spec/models/job_seeker_profile_spec.rb` (presence, uniqueness, lengths, association)
- [x] Write `spec/models/job_application_spec.rb` (presence, status, URL, dependent destroy, association)
- [x] Write `spec/models/cover_letter_spec.rb` (presence, tone, association, gemini_raw nullable)
- [x] Run `bundle exec rspec spec/models/` — all pass

---

## Phase 2 — Job Applications CRUD

### Implementation
- [x] Add routes: `resources :applications`, nested `resources :cover_letters` stub
- [x] `JobApplicationsController` — `index`, `new`, `create`, `show`, `edit`, `update`, `destroy`
- [x] All queries scoped through `current_user.job_applications`
- [x] `update` handles status-only PATCH (Turbo Stream) and full-form PATCH (redirect)
- [x] Strong params defined
- [x] View: `job_applications/index.html.erb` (table list)
- [x] View: `job_applications/new.html.erb` and `edit.html.erb` (wrapping `_form`)
- [x] View: `job_applications/_form.html.erb` (all fields per spec)
- [x] View: `job_applications/show.html.erb` (two-column; right column cover letter stub)

### Manual Tests
- [x] `/applications/new` → fill form → submit → redirect to board (or error until board exists)
- [x] `/applications/:id` shows correct application details
- [x] `/applications/:id` for another user's record → 404
- [x] Edit application → save → redirect to show page
- [x] Delete application → redirect to board
- [x] Blank `job_title` on submit → re-renders form with error
- [x] Invalid URL → validation error shown

### RSpec
- [x] Write `spec/requests/job_applications_spec.rb` (all cases from spec Section 9)
- [x] Run `bundle exec rspec spec/requests/job_applications_spec.rb` — all pass

---

## Phase 3 — Profile Management

### Implementation
- [x] Add route: `resource :profile, controller: "profiles"`
- [x] `ProfilesController` — `show`, `edit`, `update`
- [x] `show` and `edit` use `find_or_initialize` scoped to `current_user`
- [x] `update` saves profile, redirects with flash on success; re-renders edit on failure
- [x] View: `profiles/show.html.erb` (two-column card, edit button, note about Gemini usage)
- [x] View: `profiles/edit.html.erb` (two textareas, character counts, disclaimer note)
- [x] Stimulus controller: `character_count_controller.js` (tracks remaining chars, max value)

### Manual Tests
- [x] `/profile` with no profile → setup prompt shown, edit link works
- [x] `/profile/edit` → fill both fields → save → flash notice on `/profile`
- [x] Blank background summary → re-renders edit with validation error
- [x] Character counter decrements as you type in both fields
- [x] Profile is user-scoped (another signed-in user sees their own profile)

### RSpec
- [x] Write `spec/requests/profiles_spec.rb` (show, update valid, update invalid, auth, scoping)
- [x] Run `bundle exec rspec spec/requests/profiles_spec.rb` — all pass

---

## Phase 4 — Kanban Board

### Implementation
- [x] Add route: `get "/board", to: "board#show", as: :board`
- [x] `BoardController#show` — groups applications by status, sets `@profile_complete`
- [x] Dashboard redirects to `board_path`
- [x] View: `board/show.html.erb` (4-column scrollable layout, profile setup alert, new-app button)
- [x] View: `board/_card.html.erb` (Bootstrap card, draggable, status badge, View button, Move to dropdown)
- [x] Stimulus controller: `kanban_controller.js` (dragstart, dragover, drop → PATCH to update status)
- [x] Column headers: "Applied" neutral, "Interviewing" yellow (`#ca8a04`), "Offer" success, "Rejected" muted
- [x] Empty column placeholder: muted "No applications" text

### Manual Tests
- [x] Sign in → lands on `/board`
- [x] Board shows four columns with correct styling (yellow Interviewing header)
- [x] Applications appear in correct column for their status
- [x] No applications → empty placeholders shown
- [x] Profile incomplete → setup alert shown with link to `/profile/edit`
- [x] Drag card to new column → status updates
- [x] "Move to" dropdown works (for mobile / non-drag)
- [x] Another user's cards do not appear

### RSpec
- [x] Write `spec/requests/board_spec.rb` (200 with apps, 200 empty, redirect unauth, status grouping)
- [x] Run `bundle exec rspec spec/requests/board_spec.rb` — all pass

---

## Phase 5 — AI Cover Letter Generation

### Implementation
- [x] Add `jobviber_cover_letter_v1` template to `db/seeds.rb` (model: `gemini-2.5-flash`, max_tokens: 800, temp: 0.8)
- [ ] Run `rails db:seed` — template appears in admin panel
- [x] `CoverLettersController` — `create` (Gemini call, save, Turbo Stream response)
- [x] `CoverLettersController` — `destroy` (scoped find, destroy, Turbo Stream remove)
- [x] Rate limit on `create`: 10 requests per minute
- [x] All four `GeminiService` error types rescued and rendered via `shared/ai_error` Turbo Stream
- [x] `JobApplicationsController#show` sets `@profile` for the right column
- [x] View: `job_applications/show.html.erb` updated with Turbo Frame wrapper
- [x] View: `cover_letters/_cover_letters.html.erb` (tone form, cover letter list, no-profile guard)
- [x] View: `cover_letters/_cover_letter.html.erb` (letter body, raw toggle, copy button, delete, disclaimer)
- [x] Stimulus controller: `clipboard_controller.js` (copy to clipboard, "Copied!" feedback)
- [x] Cover letter card: left border `4px solid var(--accent)`, body uses `cover-letter-body` CSS class

### Manual Tests
- [x] Admin panel at `/admin/ai_templates` shows `jobviber_cover_letter_v1`
- [x] Admin test panel: enter sample values, run test → Gemini returns a cover letter
- [x] Application show with no profile → "Set up your profile" notice in right column
- [x] Application show with profile → tone radio buttons and generate button appear
- [x] Click "Generate cover letter" (confident) → letter appears without page reload
- [x] Generate again (conversational) → second letter prepended to list
- [x] "Show raw response" toggle reveals raw text
- [x] "Copy to clipboard" works
- [x] Delete cover letter → removed from page via Turbo Stream
- [x] Long job description (~3,500 chars) → generation succeeds (not gatekeeper-blocked)
- [x] Budget error: set `AI_CALLS_PER_USER_PER_DAY=0` in `.env`, restart, generate → error partial renders

### RSpec
- [x] Write `spec/requests/cover_letters_spec.rb` (all cases from spec Section 9)
- [x] Run `bundle exec rspec spec/requests/cover_letters_spec.rb` — all pass

---

## Phase 6 — Seed Data

### Implementation
- [x] Add `JobSeekerProfile` seed for demo user (background + key skills)
- [x] Add `JobApplication` seed 1: Senior Backend Engineer @ Basecamp (applied, 7 days ago)
- [x] Add `JobApplication` seed 2: Staff Software Engineer @ Linear (interviewing, 14 days ago)
- [x] Add `JobApplication` seed 3: Platform Engineer @ Shopify (rejected, 21 days ago)
- [x] Add one pre-generated `CoverLetter` per application (confident / conversational / concise)
- [x] All seeds use `find_or_create_by!` (idempotent)

### Manual Tests
- [x] `rails db:seed` completes with no errors
- [x] Sign in as `demo@example.com` / `password123` → board shows 3 cards in correct columns
- [x] Click each card → pre-generated cover letter is visible
- [x] Run `rails db:seed` again → no duplicate records

---

## Phase 7 — Polish, Full Test Suite & README

### Final Code Audit
- [x] Audit all controllers: no `turbo_stream.replace` — only `turbo_stream.update`
- [x] Grep views for `onclick`, `addEventListener`, `<script>` — none found
- [x] Grep views/config for hardcoded "JobViber" strings — all use `ENV.fetch`
- [x] Sign in as non-admin, visit `/admin` → 404 (not 403)
- [x] Check browser console on each page — no CSP errors
- [x] Grep repo for `GEMINI_API_KEY` — not in any committed file (only `.env.example` placeholder)

### README
- [x] App name and tagline at top
- [x] Description paragraph
- [x] Setup section (only extra requirement: `GEMINI_API_KEY`)
- [x] "Editing the AI Prompt" section
- [x] Demo credentials: `demo@example.com` / `password123`

### Full RSpec Suite
- [x] `spec/models/job_seeker_profile_spec.rb` — passes
- [x] `spec/models/job_application_spec.rb` — passes
- [x] `spec/models/cover_letter_spec.rb` — passes
- [x] `spec/requests/board_spec.rb` — passes
- [x] `spec/requests/job_applications_spec.rb` — passes
- [x] `spec/requests/cover_letters_spec.rb` — passes
- [x] `spec/requests/profiles_spec.rb` — passes
- [x] Boilerplate specs still pass (user, ai_template, llm_request, services, sessions, admin)
- [x] Run `bundle exec rspec` — full suite green, zero failures

---

## Phase 8 — AI Resume Generation

Adds a custom tailored-resume feature alongside cover letters. The key constraint: the AI must only use information the user explicitly provided — no hallucinated experience, education, or dates. The system prompt enforces this strictly.

### Profile Expansion

- [x] Migration: add `work_history` (text, null: true) and `education` (text, null: true) to `job_seeker_profiles`
- [x] Run `rails db:migrate`
- [x] Update `JobSeekerProfile` model — no presence validation (optional fields); add `length: { maximum: 6000 }` on `work_history` and `length: { maximum: 2000 }` on `education`
- [x] Update `ProfilesController` strong params to permit `work_history`, `education`
- [x] Update `profiles/edit.html.erb` — add two new textareas with `character-count` controller (6000 / 2000 limits)
- [x] Update `profiles/show.html.erb` — render work_history and education if present

### Resume Model & Routes

- [x] Migration: `create_resumes` — UUID PK, `job_application_id` (uuid, null: false), `body` (text, null: false), `gemini_raw` (text, null: true), timestamps; index on `job_application_id + created_at`
- [x] Model: `Resume` — `belongs_to :job_application`; `validates :body, presence: true`
- [x] Update `JobApplication` model: `has_many :resumes, dependent: :destroy`
- [x] Add route: `resources :applications` nested `resources :resumes, only: [:create, :destroy]`
- [x] Factory: `spec/factories/resumes.rb`

### Resume Controller & Views

- [x] `ResumesController` — mirrors `CoverLettersController` structure
- [x] View: `resumes/_resumes.html.erb` — generate button (no tone selector), resume list, no-profile guard, work_history hint
- [x] View: `resumes/_resume.html.erb` — same card pattern as cover letter (accent left border, clipboard, raw toggle, delete)
- [x] Update `job_applications/show.html.erb` — add resume `turbo_frame_tag` below cover letters in right column

### AI Template

- [x] Add `jobviber_resume_v1` seed to `db/seeds.rb` using `find_or_initialize_by` pattern
- [x] Run `rails db:seed` — both templates appear in admin panel

### Manual Tests

- [x] Profile edit → new Work History and Education fields visible with character counters
- [x] `/applications/:id` → resume section appears below cover letters
- [x] Fill in profile Work History → generate resume → resume appears without page reload
- [x] Resume contains only information from profile — no invented dates or companies
- [x] Delete resume → removed via Turbo Stream
- [x] No profile → "Set up your profile" guard shown in resume section
- [x] Rate limit: 11 rapid submits → rate limit response

### RSpec

- [x] Write `spec/models/resume_spec.rb` (presence, association, dependent destroy)
- [x] Write `spec/requests/resumes_spec.rb` (create, destroy, auth, scoping, gatekeeper error, budget error)
- [x] Update `spec/models/job_seeker_profile_spec.rb` — add optional work_history / education length tests
- [x] Run `bundle exec rspec` — full suite green

---

## Progress Summary

| Phase | Status |
|---|---|
| Phase 0 — Branding | ✅ RSpec green — pending manual tests |
| Phase 1 — Data Models | ✅ Migrated + RSpec green |
| Phase 2 — Job Applications CRUD | ✅ RSpec green — pending manual tests |
| Phase 3 — Profile Management | ✅ RSpec green — pending manual tests |
| Phase 4 — Kanban Board | ✅ RSpec green — pending manual tests |
| Phase 5 — AI Cover Letters | ✅ RSpec green — pending `rails db:seed` + manual tests |
| Phase 6 — Seed Data | ✅ Code complete — pending `rails db:seed` + manual tests |
| Phase 7 — Polish & Tests | ✅ Complete |
| Phase 8 — AI Resume Generation | ✅ Complete |
