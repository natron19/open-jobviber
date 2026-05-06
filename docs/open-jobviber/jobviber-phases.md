# JobViber Demo — Phased Build Specification

**Built on:** Open Demo Starter v2.0  
**Source spec:** `docs/open-jobviber/jobviber-demo-spec.md`  
**Tasks tracker:** `tasks.md`

This document breaks the full spec into discrete implementation phases. Each phase is independently testable. Complete all tests for a phase before starting the next.

---

## Known Constraint — Gatekeeper Input Length

The boilerplate `AiGatekeeper` enforces a 5,000-character maximum on the rendered (interpolated) prompt. The spec allows `job_description` up to 8,000 characters; combined with the other variables, the full prompt would easily exceed 5,000 characters.

**Resolution (Phase 1):** Validate `job_description` at a maximum of **3,500 characters** in the `JobApplication` model. This keeps the fully-interpolated prompt (background_summary 1,000 + key_skills 500 + job_title 200 + company 200 + job_description 3,500 + template scaffolding ~400) comfortably under the 5,000-character gatekeeper ceiling.

Update the `.env.example` comment to document this trade-off if users observe gatekeeper blocks on long job descriptions.

---

## Known Constraint — Gemini Model Name

The spec (`Section 7`) names `gemini-2.0-flash` as the target model. Per `docs/ai-templates.md`, this model is deprecated for new API keys and returns 404 on v1beta. Use `gemini-2.5-flash` throughout. The seed data and template record must reflect this corrected model name.

---

## Phase 0 — App Bootstrap & Branding

**Goal:** The app opens with JobViber branding, accent color, and navbar links. No domain models yet.

### Changes

**`.env.example`**  
Add / update:
```
APP_NAME=JobViber Demo
APP_TAGLINE=Track your applications. Let AI write the cover letter.
APP_DESCRIPTION=A kanban job tracker with AI cover letter generation. One template, three tones, every application.
GEMINI_API_KEY=your_key_here
AI_CALLS_PER_USER_PER_DAY=50
AI_GLOBAL_TIMEOUT_SECONDS=15
```

**`app/assets/stylesheets/application.css`**  
Add accent overrides and kanban/cover-letter layout rules:
```css
:root {
  --accent: #dc2626;
  --accent-hover: #b91c1c;
}

/* Primary button override */
.btn-primary {
  background-color: var(--accent);
  border-color: var(--accent);
}
.btn-primary:hover {
  background-color: var(--accent-hover);
  border-color: var(--accent-hover);
}

/* Kanban board layout */
.kanban-board {
  overflow-x: auto;
}
.kanban-column {
  min-width: 280px;
}

/* Cover letter body rendering */
.cover-letter-body {
  white-space: pre-wrap;
  font-family: Georgia, serif;
  line-height: 1.7;
}
```

**`app/views/layouts/application.html.erb`**  
Update navbar to include "My Board" (`/board`) and "My Profile" (`/profile`) links alongside the existing auth links. These links should only render when the user is signed in.

**`app/views/home/index.html.erb`**  
Replace with JobViber landing page:
- Hero section: JobViber logo/name, tagline from `ENV.fetch("APP_TAGLINE", "...")`, two CTA buttons ("Get started" → `/sign_up`, "Sign in" → `/sign_in`)
- Three feature callout cards: "Kanban tracker", "AI cover letters", "Open source"
- No JavaScript beyond the Stimulus bootstrap

**`app/controllers/dashboard_controller.rb`**  
Add `before_action :redirect_to_board` that calls `redirect_to board_path`. Keep the existing `show` action stub in place so the route continues to work.

### Manual Tests — Phase 0

- [ ] Visit `/` — verify tagline, accent color (red buttons), three feature cards render
- [ ] Visit `/sign_in` — no errors, accent red on submit button
- [ ] Sign in as `demo@example.com` / `password123` — verify redirect lands on board (404 expected until Phase 4)
- [ ] Navbar shows "My Board" and "My Profile" links when signed in
- [ ] Navbar hides those links when signed out

### RSpec — Phase 0

No new RSpec specs for this phase. Existing boilerplate specs must still pass after the layout change. Ask user to run `bundle exec rspec spec/requests/sessions_spec.rb` to confirm.

---

## Phase 1 — Data Models & Migrations

**Goal:** Three domain models created, migrated, validated, and factory-backed. No controllers yet.

### Migrations

**`db/migrate/TIMESTAMP_create_job_seeker_profiles.rb`**
```ruby
create_table :job_seeker_profiles, id: :uuid do |t|
  t.references :user, null: false, foreign_key: true, type: :uuid
  t.text :background_summary, null: false, default: ""
  t.text :key_skills, null: false, default: ""
  t.timestamps null: false
end
add_index :job_seeker_profiles, :user_id, unique: true
```

**`db/migrate/TIMESTAMP_create_job_applications.rb`**
```ruby
create_table :job_applications, id: :uuid do |t|
  t.references :user, null: false, foreign_key: true, type: :uuid
  t.string :job_title, null: false
  t.string :company, null: false
  t.string :status, null: false, default: "applied"
  t.text :job_description
  t.string :url
  t.text :notes
  t.date :applied_on
  t.timestamps null: false
end
add_index :job_applications, [:user_id, :created_at]
add_index :job_applications, :status
```

**`db/migrate/TIMESTAMP_create_cover_letters.rb`**
```ruby
create_table :cover_letters, id: :uuid do |t|
  t.references :job_application, null: false, foreign_key: true, type: :uuid
  t.string :tone, null: false
  t.text :body, null: false
  t.text :gemini_raw
  t.timestamps null: false
end
add_index :cover_letters, [:job_application_id, :created_at]
```

### Models

**`app/models/job_seeker_profile.rb`**
```ruby
class JobSeekerProfile < ApplicationRecord
  belongs_to :user

  validates :user_id, presence: true, uniqueness: true
  validates :background_summary, presence: true, length: { maximum: 1000 }
  validates :key_skills, presence: true, length: { maximum: 500 }
end
```

**`app/models/job_application.rb`**
```ruby
class JobApplication < ApplicationRecord
  STATUSES = %w[applied interviewing offer rejected].freeze

  belongs_to :user
  has_many :cover_letters, dependent: :destroy

  validates :user_id, presence: true
  validates :job_title, presence: true, length: { maximum: 200 }
  validates :company, presence: true, length: { maximum: 200 }
  validates :status, inclusion: { in: STATUSES }
  validates :job_description, length: { maximum: 3500 }
  validates :url, format: { with: /\Ahttps?:\/\//i, message: "must begin with http:// or https://" },
                  allow_blank: true
end
```

Note: `job_description` maximum is 3,500 characters (not 8,000 as in spec) — see constraint note at top of this document.

**`app/models/cover_letter.rb`**
```ruby
class CoverLetter < ApplicationRecord
  TONES = %w[confident conversational concise].freeze

  belongs_to :job_application
  has_one :user, through: :job_application

  validates :job_application_id, presence: true
  validates :tone, inclusion: { in: TONES }
  validates :body, presence: true
end
```

**`app/models/user.rb`**  
Add associations:
```ruby
has_one :job_seeker_profile, dependent: :destroy
has_many :job_applications, dependent: :destroy
```

### Factories

**`spec/factories/job_seeker_profiles.rb`**
```ruby
FactoryBot.define do
  factory :job_seeker_profile do
    user
    background_summary { "Experienced software engineer with 6 years building web applications." }
    key_skills         { "Ruby on Rails, PostgreSQL, React, TypeScript" }
  end
end
```

**`spec/factories/job_applications.rb`**
```ruby
FactoryBot.define do
  factory :job_application do
    user
    job_title       { "Software Engineer" }
    company         { "Acme Corp" }
    status          { "applied" }
    job_description { "We are looking for a skilled engineer to join our team." }

    trait :interviewing { status { "interviewing" } }
    trait :offer        { status { "offer" } }
    trait :rejected     { status { "rejected" } }
  end
end
```

**`spec/factories/cover_letters.rb`**
```ruby
FactoryBot.define do
  factory :cover_letter do
    job_application
    tone       { "confident" }
    body       { "I am excited to apply for this position..." }
    gemini_raw { "I am excited to apply for this position..." }

    trait :conversational { tone { "conversational" } }
    trait :concise        { tone { "concise" } }
  end
end
```

### Manual Tests — Phase 1

- [ ] `rails db:migrate` completes with no errors
- [ ] `rails console` — create a `JobApplication` for the demo user, verify it saves
- [ ] `rails console` — try saving a `JobApplication` with a blank `job_title`, verify validation error
- [ ] `rails console` — try saving a `JobApplication` with `url: "not-a-url"`, verify format validation fails
- [ ] `rails console` — try saving a second `JobSeekerProfile` for the same user, verify uniqueness error

### RSpec — Phase 1

Files to write:
- `spec/models/job_seeker_profile_spec.rb`
- `spec/models/job_application_spec.rb`
- `spec/models/cover_letter_spec.rb`

Key cases per the spec (Section 9):

**`job_seeker_profile_spec.rb`:**
- Validates presence of `background_summary` and `key_skills`
- Enforces uniqueness of `user_id`
- Enforces max length on both text fields (1000 and 500)
- `belongs_to :user` is required

**`job_application_spec.rb`:**
- Validates presence of `job_title`, `company`, `user_id`
- Validates `status` inclusion in four permitted values
- Rejects invalid URL formats; accepts blank URLs
- `has_many :cover_letters, dependent: :destroy` — destroying the application destroys its letters
- `belongs_to :user` is required

**`cover_letter_spec.rb`:**
- Validates presence of `job_application_id`, `body`, `tone`
- Validates `tone` inclusion in `%w[confident conversational concise]`
- `belongs_to :job_application` is required
- `gemini_raw` is nullable and does not block saving

Ask user to run: `bundle exec rspec spec/models/`

---

## Phase 2 — Job Applications CRUD

**Goal:** Full CRUD for `JobApplication` with proper access control. No AI yet.

### Routes

```ruby
resources :applications,
          controller: "job_applications",
          except: [:index] do
  resources :cover_letters, only: [:create, :destroy]
end
get "/applications", to: "job_applications#index", as: :applications
```

### Controller — `app/controllers/job_applications_controller.rb`

Implement: `index`, `new`, `create`, `show`, `edit`, `update`, `destroy`.

Key requirements:
- All queries scoped through `current_user.job_applications`
- `show`, `edit`, `update`, `destroy` use `find` (raises `RecordNotFound` → 404 for other users' records)
- `update` accepts a status-only PATCH (drag-and-drop) **or** a full params set
- Status-only PATCH responds with a Turbo Stream updating the card's status badge (`turbo_stream.update`)
- Full edit redirect goes to the application show page
- `destroy` redirects to `board_path`
- Strong params: `job_title`, `company`, `status`, `job_description`, `url`, `notes`, `applied_on`

### Views

**`app/views/job_applications/index.html.erb`**  
Simple table list: job title, company, status badge, applied date, links to show/edit/delete. "New application" button.

**`app/views/job_applications/new.html.erb`**  
Wraps `_form.html.erb` in a page card.

**`app/views/job_applications/edit.html.erb`**  
Wraps `_form.html.erb` in a page card.

**`app/views/job_applications/_form.html.erb`**  
Fields: job title (text input), company (text input), status (select), URL (text input, optional), applied on (date input, optional), job description (textarea, `rows: 10`), notes (textarea, `rows: 4`). Submit and cancel (back to board) buttons.

**`app/views/job_applications/show.html.erb`**  
Two-column layout:
- Left (col-8): job title, company, status badge, URL link if present, applied date, job description block, notes block. Edit and Delete action buttons.
- Right (col-4): cover letters section wrapped in `turbo_frame_tag "cover_letters_#{@application.id}"` (stub content for now — "Cover letters coming in Phase 5").

### Manual Tests — Phase 2

- [ ] Visit `/applications/new`, fill in form, submit → redirects to board (404 until Phase 4, but redirect happens)
- [ ] Visit `/applications/:id` for a valid application → shows details
- [ ] Visit `/applications/:id` for another user's application → 404
- [ ] Edit an application → save → redirect to show
- [ ] Delete an application → redirect to board path
- [ ] Try submitting new application with blank `job_title` → re-renders form with errors
- [ ] Try a URL without `http://` → validation error

### RSpec — Phase 2

File: `spec/requests/job_applications_spec.rb`

Key cases per spec (Section 9):
- `POST /applications` with valid params creates application, redirects to board
- `POST /applications` with missing `job_title` re-renders `new` with errors
- `PATCH /applications/:id` status-only responds with Turbo Stream
- `DELETE /applications/:id` destroys and redirects to board
- `GET /applications/:id` returns 404 for another user's application (access control)
- `PATCH /applications/:id` for another user's application returns 404 (access control)
- Unauthenticated requests to all routes redirect to sign in

Ask user to run: `bundle exec rspec spec/requests/job_applications_spec.rb`

---

## Phase 3 — Profile Management

**Goal:** Users can view and edit their `JobSeekerProfile`. Profile data is what Gemini uses in Phase 5.

### Routes

```ruby
resource :profile, controller: "profiles", only: [:show, :edit, :update]
```

Note: singular `resource` (no `:id`, one profile per user).

### Controller — `app/controllers/profiles_controller.rb`

**`show`:** `@profile = current_user.job_seeker_profile || current_user.build_job_seeker_profile`

**`edit`:** Same as show.

**`update`:** `@profile = current_user.job_seeker_profile || current_user.build_job_seeker_profile`. Update with strong params. On success, redirect to `profile_path` with flash notice. On failure, re-render `edit` with validation errors.

Strong params: `background_summary`, `key_skills`.

### Views

**`app/views/profiles/show.html.erb`**  
Two-column card: left shows background summary, right shows key skills. "Edit profile" button. A note below: "This profile is what Gemini uses to personalize your cover letters — keep it current." If profile is blank (new user), shows a setup prompt.

**`app/views/profiles/edit.html.erb`**  
Form with two textareas: "Background summary" (rows 6, max 1000 chars) and "Key skills" (rows 3, max 500 chars). Stimulus character-count controller on each textarea (shows remaining chars). A note: "The more specific your background summary and skills, the more accurate your cover letters will be." Save and cancel buttons.

### Stimulus — `app/javascript/controllers/character_count_controller.js`

Targets: `input` (the textarea), `counter` (span showing remaining chars).  
Value: `max` (integer).  
On `connect` and `input` event: update `counterTarget.textContent` with `maxValue - inputTarget.value.length`.

### Manual Tests — Phase 3

- [ ] Visit `/profile` with no profile set → shows setup prompt, edit link works
- [ ] Visit `/profile/edit` → fill in both fields → save → redirects to `/profile` with flash notice
- [ ] Try saving with blank background summary → re-renders edit with validation error
- [ ] Character counter decrements correctly as you type (check both fields)
- [ ] Visit `/profile` when another user is signed in → shows only that user's profile (or setup prompt)

### RSpec — Phase 3

File: `spec/requests/profiles_spec.rb`

Key cases per spec (Section 9):
- `GET /profile` returns 200 for signed-in user
- `PATCH /profile` with valid params updates and redirects
- `PATCH /profile` with blank `background_summary` re-renders edit with errors
- Unauthenticated requests redirect to sign in
- Profile is always scoped to `current_user`

Ask user to run: `bundle exec rspec spec/requests/profiles_spec.rb`

---

## Phase 4 — Kanban Board

**Goal:** Board view displays all applications grouped by status. Stimulus drag-and-drop moves cards between columns and fires a status-update PATCH.

### Routes

```ruby
get "/board", to: "board#show", as: :board
```

### Controller — `app/controllers/board_controller.rb`

**`show`:**
```ruby
applications = current_user.job_applications.order(created_at: :desc)
@columns = JobApplication::STATUSES.index_with { |s| applications.select { |a| a.status == s } }
@profile_complete = current_user.job_seeker_profile.present? &&
                    current_user.job_seeker_profile.background_summary.present?
```

### Views

**`app/views/board/show.html.erb`**
- "New application" button top-right linking to `new_application_path`
- If `!@profile_complete`: alert prompting user to set up profile with link to `edit_profile_path`
- Horizontally scrollable row (`class: "kanban-board d-flex gap-3 pb-3"`) with `data-controller="kanban"`
- Four column divs (`class: "kanban-column flex-shrink-0"`), each with `data-status` attribute and `data-action="dragover->kanban#dragover drop->kanban#drop"`
- Column headers: "Applied" (neutral), "Interviewing" (style `color: #ca8a04`), "Offer" (Bootstrap success text), "Rejected" (Bootstrap muted)
- Each column renders `render partial: "board/card", collection: @columns[status], as: :application`
- Empty column shows a muted "No applications" placeholder

**`app/views/board/_card.html.erb`**
- Bootstrap card with `style: "border-left: 4px solid var(--accent)"` and `data-draggable="true"` and `data-id="#{application.id}"`
- Shows: job title (`h6`), company (small text), optional applied date, status badge
- Two buttons: "View" (link to `application_path(application)`), "Move to" dropdown listing the other three statuses (each fires a PATCH via `data: { turbo_method: :patch }` to `application_path(application, job_application: { status: target_status })`)
- The "Move to" dropdown uses `window.bootstrap.Dropdown` via a Stimulus controller

### Stimulus — `app/javascript/controllers/kanban_controller.js`

Handles `dragstart`, `dragover`, `drop` on the kanban board.

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  dragstart(event) {
    event.dataTransfer.setData("application_id", event.target.closest("[data-id]").dataset.id)
  }

  dragover(event) {
    event.preventDefault()
  }

  drop(event) {
    event.preventDefault()
    const id = event.dataTransfer.getData("application_id")
    const status = event.target.closest("[data-status]")?.dataset.status
    if (!id || !status) return

    fetch(`/applications/${id}`, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector("meta[name='csrf-token']").content,
        "Accept": "text/vnd.turbo-stream.html"
      },
      body: JSON.stringify({ job_application: { status } })
    }).then(r => r.text()).then(html => {
      window.Turbo.renderStreamMessage(html)
    })
  }
}
```

Cards must have `draggable="true"` and `data-action="dragstart->kanban#dragstart"` on the card element.

### `JobApplicationsController#update` Turbo Stream response

When the PATCH contains only `status`, return a Turbo Stream that updates the board. A full board re-render is acceptable here (`turbo_stream.update("board", partial: "board/board", locals: { ... })`), or update individual card status badges. The simpler approach: redirect to board on status-only update, as the full page reload from a `redirect_to board_path` is acceptable for MVP drag-and-drop (the Stimulus controller handles the optimistic visual update, the server confirms it).

For the drag-and-drop flow: the `fetch` call in the Stimulus controller sends a Turbo Stream request. The controller can respond with `turbo_stream.update` on a per-card target or reload the board. Simplest working implementation: respond with a full-page Turbo Stream board update.

### Dashboard Redirect

**`app/controllers/dashboard_controller.rb`** — ensure `before_action :redirect_to_board` is in place, calling `redirect_to board_path`.

### Manual Tests — Phase 4

- [ ] Sign in → lands on board at `/board`
- [ ] Board shows four columns with correct headers (Interviewing in yellow)
- [ ] Applications appear in the correct column for their status
- [ ] Signed-in user with no applications sees empty column placeholders
- [ ] Profile setup prompt appears if profile is incomplete
- [ ] "New application" button links to new application form
- [ ] Drag a card to another column → status updates, card moves (after page confirms)
- [ ] "Move to" dropdown works on mobile (no drag)
- [ ] Another user's applications do not appear on the board

### RSpec — Phase 4

File: `spec/requests/board_spec.rb`

Key cases per spec (Section 9):
- `GET /board` returns 200 for signed-in user with applications
- `GET /board` returns 200 for signed-in user with no applications
- `GET /board` redirects to sign in for unauthenticated request
- Each status group contains only applications with the matching status

Ask user to run: `bundle exec rspec spec/requests/board_spec.rb`

---

## Phase 5 — AI Cover Letter Generation

**Goal:** Users can generate, view, and delete cover letters from the application show page. Gemini integration is live.

### AI Template Seed

Add to `db/seeds.rb`:

```ruby
AiTemplate.find_or_create_by!(name: "jobviber_cover_letter_v1") do |t|
  t.description = "Generates a personalized cover letter. One template, three tone modes: confident, conversational, concise."
  t.system_prompt = <<~PROMPT
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
  PROMPT
  t.user_prompt_template = <<~PROMPT
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
  PROMPT
  t.model = "gemini-2.5-flash"
  t.max_output_tokens = 800
  t.temperature = 0.8
  t.notes = "Watch for the model ignoring the concise tone directive on long job descriptions. If salutations appear despite the system prompt instruction, add explicit negative instruction. Tone modifier is the last line in the user prompt — this placement is intentional. Model corrected to gemini-2.5-flash (2.0-flash deprecated for new API keys)."
end
```

Run `rails db:seed` after adding this.

### Routes

Nested under `:applications` (already defined in Phase 2):
```ruby
resources :cover_letters, only: [:create, :destroy]
```

### Controller — `app/controllers/cover_letters_controller.rb`

**`create`:**
1. Find `@application = current_user.job_applications.find(params[:application_id])` (raises 404 for other users)
2. Find or initialize `@profile = current_user.job_seeker_profile`
3. Guard: if profile blank, respond with Turbo Stream rendering profile-missing notice
4. Call:
   ```ruby
   result = GeminiService.generate(
     template:  "jobviber_cover_letter_v1",
     variables: {
       background_summary: @profile.background_summary,
       key_skills:         @profile.key_skills,
       job_title:          @application.job_title,
       company:            @application.company,
       job_description:    @application.job_description.to_s,
       tone:               params[:tone]
     }
   )
   ```
5. Save: `@cover_letter = @application.cover_letters.create!(body: result, gemini_raw: result, tone: params[:tone])`
6. On success: respond with Turbo Stream `update` on `"cover_letters_#{@application.id}"` rendering the full `_cover_letters` partial
7. Rescue all four `GeminiService` error types; render `shared/ai_error` via Turbo Stream into the same frame

Rate limit: add `rate_limit to: 10, within: 1.minute, only: [:create]` to the controller.

**`destroy`:**
1. Find `@application = current_user.job_applications.find(params[:application_id])`
2. Find `@cover_letter = @application.cover_letters.find(params[:id])`
3. Destroy `@cover_letter`
4. Respond with Turbo Stream `remove` for the cover letter card DOM ID (`"cover_letter_#{@cover_letter.id}"`)

### Views

**`app/views/job_applications/show.html.erb`** (update from Phase 2)  
Right column:
```erb
<%= turbo_frame_tag "cover_letters_#{@application.id}" do %>
  <%= render "cover_letters/cover_letters", application: @application, profile: @profile %>
<% end %>
```
Set `@profile = current_user.job_seeker_profile` in `JobApplicationsController#show`.

**`app/views/cover_letters/_cover_letters.html.erb`**  
If profile is blank: show notice "Set up your profile before generating a cover letter" with link to `edit_profile_path`.  
Otherwise:
- Tone radio buttons form (`confident`, `conversational`, `concise`) posting to `application_cover_letters_path(application)` with `data: { turbo_frame: "cover_letters_#{application.id}" }`
- "Generate cover letter" submit button
- List of existing cover letters via `render partial: "cover_letters/cover_letter", collection: application.cover_letters.order(created_at: :desc), as: :cover_letter`

**`app/views/cover_letters/_cover_letter.html.erb`**  
Bootstrap card with `id: "cover_letter_#{cover_letter.id}"` and `style: "border-left: 4px solid var(--accent)"`:
- Header: generation timestamp, tone badge (`badge bg-secondary` for confident, `bg-info` for conversational, `bg-dark` for concise)
- Body: `<div class="cover-letter-body"><%= cover_letter.body %></div>`
- Inline disclaimer: "Review this letter before sending. AI-generated letters may include inaccurate phrasing or claims not reflected in your actual experience."
- "Show raw response" Bootstrap collapse toggle (reveals `gemini_raw` in a `<pre>` block)
- "Copy to clipboard" button: Stimulus `clipboard` controller, copies `cover_letter.body`
- "Delete" button: `link_to "Delete", application_cover_letter_path(application, cover_letter), data: { turbo_method: :delete, turbo_confirm: "Delete this cover letter?" }, class: "btn btn-sm btn-outline-danger"`

### Stimulus — `app/javascript/controllers/clipboard_controller.js`

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["source", "button"]

  copy() {
    navigator.clipboard.writeText(this.sourceTarget.textContent)
    const original = this.buttonTarget.textContent
    this.buttonTarget.textContent = "Copied!"
    setTimeout(() => { this.buttonTarget.textContent = original }, 2000)
  }
}
```

Wrap the cover letter body and button in a `data-controller="clipboard"` div. The body element gets `data-clipboard-target="source"` and the button gets `data-clipboard-target="button"` and `data-action="click->clipboard#copy"`.

### Manual Tests — Phase 5

- [ ] Verify `rails db:seed` creates the `jobviber_cover_letter_v1` template
- [ ] Visit `/admin/ai_templates` → template appears, click Test with sample values → Gemini returns a cover letter
- [ ] Visit application show page with no profile set → "Set up your profile" notice appears in right column
- [ ] Set up profile, return to application show → tone radio buttons and generate button appear
- [ ] Click "Generate cover letter" (confident) → cover letter appears in the right column without page reload
- [ ] Generate a second time (conversational) → new letter prepended to the list
- [ ] "Show raw response" toggle reveals the raw text
- [ ] "Copy to clipboard" copies the body text
- [ ] "Delete" removes the letter from the page via Turbo Stream
- [ ] Test with a very long job description (near 3,500 chars) → should succeed (not gatekeeper blocked)
- [ ] Test error states: temporarily set `AI_CALLS_PER_USER_PER_DAY=0` and generate → budget error partial renders

### RSpec — Phase 5

File: `spec/requests/cover_letters_spec.rb`

Key cases per spec (Section 9):
- `POST` with valid tone calls `GeminiService.generate` with correct template and variables (stubbed)
- `POST` creates a `CoverLetter` with `body` and `gemini_raw` populated from stub response
- `POST` creates an `LlmRequest` record
- `POST` with `BudgetExceededError` renders error partial
- `POST` with `GatekeeperError` renders error partial
- `POST` with `TimeoutError` renders error partial
- `POST` returns 404 for another user's application
- `DELETE` destroys the letter and responds with Turbo Stream remove
- `DELETE` returns 404 for another user's application
- Unauthenticated requests redirect to sign in

Ask user to run: `bundle exec rspec spec/requests/cover_letters_spec.rb`

---

## Phase 6 — Seed Data

**Goal:** `bin/setup` / `rails db:seed` produces a fully populated demo board: one profile, three applications across three statuses, one pre-generated cover letter per application. The board looks ready to demo on first load.

### `db/seeds.rb` additions

After the `AiTemplate` seed (keep the `User` and template seeds already present):

```ruby
demo_user = User.find_by!(email: "demo@example.com")

profile = JobSeekerProfile.find_or_create_by!(user: demo_user) do |p|
  p.background_summary = "Experienced software engineer with 6 years building web applications in Ruby on Rails and React. Former team lead at a Series B fintech startup; now seeking a senior individual contributor role at a product-led company."
  p.key_skills = "Ruby on Rails, PostgreSQL, React, TypeScript, API design, system design, technical mentoring, agile delivery"
end

# Application 1 — Applied (Basecamp)
app1 = JobApplication.find_or_create_by!(user: demo_user, company: "Basecamp", job_title: "Senior Backend Engineer") do |a|
  a.status = "applied"
  a.applied_on = 7.days.ago.to_date
  a.job_description = <<~JD.strip
    Basecamp is hiring a Senior Backend Engineer to help us build and maintain our suite of products.
    You'll work in a small, self-directed team where ownership matters and shipping is the measure of success.

    We use Ruby on Rails extensively and care deeply about clean, maintainable code. You'll work on features
    that touch millions of users, optimize PostgreSQL queries for performance, and contribute to the async
    workflows that keep Basecamp running smoothly.

    You're a great fit if you've shipped production Rails applications, understand database performance, and
    are comfortable working without daily standups. We value clear written communication over synchronous meetings.

    We're fully remote and have been since day one.
  JD
end

CoverLetter.find_or_create_by!(job_application: app1, tone: "confident") do |cl|
  cl.body = "Six years of shipping production Rails applications—including two years as team lead at a fintech startup handling real-time payment flows—put me in a strong position to contribute to Basecamp from day one.\n\nThe work that excites me most in this posting is the intersection of async workflows and PostgreSQL performance. At my previous role I led a project to reduce p99 query latency by 60% on our core ledger tables, which required deep collaboration between backend engineers and the database team. I also built and maintained several Basecamp-inspired async communication features internally, which gave me direct appreciation for the product philosophy you ship.\n\nI'd welcome the chance to talk through how my background aligns with what you're building."
  cl.gemini_raw = cl.body
end

# Application 2 — Interviewing (Linear)
app2 = JobApplication.find_or_create_by!(user: demo_user, company: "Linear", job_title: "Staff Software Engineer") do |a|
  a.status = "interviewing"
  a.applied_on = 14.days.ago.to_date
  a.job_description = <<~JD.strip
    Linear is looking for a Staff Software Engineer to help us build the future of project management.
    You'll work across our TypeScript and React frontend and Node.js backend, designing systems that feel
    fast and delightful.

    We move fast, care about craft, and ship continuously. You'll take ownership of large features end-to-end,
    mentor junior engineers, and help define engineering best practices across the team.

    Strong TypeScript skills, experience with React at scale, and an eye for UX are essential.
  JD
end

CoverLetter.find_or_create_by!(job_application: app2, tone: "conversational") do |cl|
  cl.body = "I've been using Linear for the past two years to manage my team's work, and I'm genuinely excited about the opportunity to help build the tool I rely on every day.\n\nOn the technical side, I bring six years of full-stack experience with a strong lean toward TypeScript and React in recent years. At my last company I led the migration of our frontend from a legacy jQuery codebase to a modern React + TypeScript stack—a project that touched forty-plus components and required careful coordination with backend API changes. I also spent a lot of time on performance: bundle splitting, lazy loading, and keeping interaction latency under 100ms for our most-used workflows.\n\nI'd love to chat more about the kinds of systems problems you're working on and where I might be able to contribute most."
  cl.gemini_raw = cl.body
end

# Application 3 — Rejected (Shopify)
app3 = JobApplication.find_or_create_by!(user: demo_user, company: "Shopify", job_title: "Platform Engineer") do |a|
  a.status = "rejected"
  a.applied_on = 21.days.ago.to_date
  a.job_description = <<~JD.strip
    Shopify's Platform Engineering team builds the infrastructure that powers millions of merchants.
    We're looking for an engineer who thrives on distributed systems challenges, can debug across the
    full stack, and wants to work at massive scale.

    Experience with Kubernetes, cloud infrastructure, and observability tooling is a strong plus.
  JD
end

CoverLetter.find_or_create_by!(job_application: app3, tone: "concise") do |cl|
  cl.body = "Six years building and operating production systems at scale makes Shopify's Platform Engineering team a natural next step for me.\n\nAt my previous company I owned the migration of our monolith to a containerized deployment on Kubernetes, which cut our deploy time from 40 minutes to 8 and gave us the observability hooks we needed to debug production incidents faster. I'm comfortable across the full stack—from writing the application code to configuring the infrastructure it runs on.\n\nHappy to share more detail on any of the above."
  cl.gemini_raw = cl.body
end
```

### Manual Tests — Phase 6

- [ ] Run `rails db:seed` → no errors
- [ ] Sign in as `demo@example.com` / `password123` → board shows three cards in correct columns
- [ ] Click each card → existing cover letter is visible in right column
- [ ] Run `rails db:seed` a second time → no duplicate records created (idempotent)
- [ ] Generate a new cover letter for an existing application → fourth card appears

---

## Phase 7 — Polish, Full Test Suite & README

**Goal:** All specs pass, edge cases verified, README updated for JobViber Demo.

### Final Checks

- [ ] Confirm all `turbo_stream.replace` calls are `turbo_stream.update` (audit every controller)
- [ ] Confirm no plain `onclick`, `addEventListener`, or `<script>` tags in views
- [ ] Confirm `ENV.fetch` used for every app name / tagline reference (grep for hardcoded "JobViber")
- [ ] Confirm admin 404 behavior: sign in as non-admin, visit `/admin` → 404, not 403
- [ ] Confirm CSP is not broken: check browser console for CSP errors on each page
- [ ] Confirm `GEMINI_API_KEY` is not in any committed file (grep the repo)

### README Updates

Update `README.md` per spec Section 11:
- App name and tagline at the top
- Description paragraph
- Setup section: `GEMINI_API_KEY` is the only extra requirement beyond boilerplate defaults
- "Editing the AI Prompt" section (admin panel link)
- Demo credentials: `demo@example.com` / `password123`
- Screenshot placeholder

### Full Test Suite

Ask user to run: `bundle exec rspec`

All of the following spec files must exist and pass:
- `spec/models/job_seeker_profile_spec.rb`
- `spec/models/job_application_spec.rb`
- `spec/models/cover_letter_spec.rb`
- `spec/requests/board_spec.rb`
- `spec/requests/job_applications_spec.rb`
- `spec/requests/cover_letters_spec.rb`
- `spec/requests/profiles_spec.rb`

Boilerplate specs that must continue to pass:
- `spec/models/user_spec.rb`
- `spec/models/ai_template_spec.rb`
- `spec/models/llm_request_spec.rb`
- `spec/services/ai_gatekeeper_spec.rb`
- `spec/services/ai_budget_checker_spec.rb`
- `spec/services/gemini_service_spec.rb`
- `spec/requests/sessions_spec.rb`
- `spec/requests/admin/ai_templates_spec.rb`

---

## Appendix — Stimulus Controller Inventory

| Controller | File | Used In |
|---|---|---|
| `kanban` | `kanban_controller.js` | Board drag-and-drop |
| `clipboard` | `clipboard_controller.js` | Cover letter copy button |
| `character-count` | `character_count_controller.js` | Profile edit textareas |
| `variable-inputs` | `variable_inputs_controller.js` | Admin template editor (boilerplate) |
| `temperature-slider` | `temperature_slider_controller.js` | Admin template editor (boilerplate) |

---

## Appendix — Route Helpers Reference

| Helper | Path |
|---|---|
| `board_path` | `/board` |
| `profile_path` | `/profile` |
| `edit_profile_path` | `/profile/edit` |
| `applications_path` | `/applications` |
| `new_application_path` | `/applications/new` |
| `application_path(a)` | `/applications/:id` |
| `edit_application_path(a)` | `/applications/:id/edit` |
| `application_cover_letters_path(a)` | `/applications/:id/cover_letters` |
| `application_cover_letter_path(a, cl)` | `/applications/:id/cover_letters/:id` |
