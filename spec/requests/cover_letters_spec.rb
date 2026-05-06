require "rails_helper"

RSpec.describe "CoverLetters", type: :request do
  let(:user)        { create(:user) }
  let(:other_user)  { create(:user) }
  let!(:application) { create(:job_application, user: user) }
  let!(:profile)     { create(:job_seeker_profile, user: user) }

  describe "POST /applications/:application_id/cover_letters" do
    it "redirects unauthenticated requests to sign in" do
      post application_cover_letters_path(application), params: { tone: "confident" }
      expect(response).to redirect_to(sign_in_path)
    end

    context "when signed in" do
      before { sign_in_as(user) }

      it "calls GeminiService with correct template and variables" do
        allow(GeminiService).to receive(:generate).and_return("Great cover letter.")

        post application_cover_letters_path(application),
          params: { tone: "confident" },
          headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(GeminiService).to have_received(:generate).with(
          template: "jobviber_cover_letter_v1",
          variables: hash_including(
            background_summary: profile.background_summary,
            key_skills: profile.key_skills,
            job_title: application.job_title,
            company: application.company,
            tone: "confident"
          )
        )
      end

      it "creates a CoverLetter with body and gemini_raw populated" do
        allow(GeminiService).to receive(:generate).and_return("My cover letter.")

        expect {
          post application_cover_letters_path(application),
            params: { tone: "conversational" },
            headers: { "Accept" => "text/vnd.turbo-stream.html" }
        }.to change(CoverLetter, :count).by(1)

        letter = CoverLetter.last
        expect(letter.body).to eq("My cover letter.")
        expect(letter.gemini_raw).to eq("My cover letter.")
        expect(letter.tone).to eq("conversational")
      end

      it "responds with turbo stream on success" do
        allow(GeminiService).to receive(:generate).and_return("Cover letter text.")

        post application_cover_letters_path(application),
          params: { tone: "confident" },
          headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      end

      it "renders error partial on BudgetExceededError" do
        allow(GeminiService).to receive(:generate).and_raise(GeminiService::BudgetExceededError)

        post application_cover_letters_path(application),
          params: { tone: "confident" },
          headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(response.media_type).to eq("text/vnd.turbo-stream.html")
        expect(response.body).to include("daily AI request limit")
      end

      it "renders error partial on GatekeeperError" do
        allow(GeminiService).to receive(:generate).and_raise(GeminiService::GatekeeperError)

        post application_cover_letters_path(application),
          params: { tone: "confident" },
          headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(response.body).to include("couldn't be processed")
      end

      it "renders error partial on TimeoutError" do
        allow(GeminiService).to receive(:generate).and_raise(GeminiService::TimeoutError)

        post application_cover_letters_path(application),
          params: { tone: "confident" },
          headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(response.body).to include("took too long")
      end

      it "returns 404 for another user's application" do
        other_app = create(:job_application, user: other_user)
        post application_cover_letters_path(other_app), params: { tone: "confident" }
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "DELETE /applications/:application_id/cover_letters/:id" do
    let!(:cover_letter) { create(:cover_letter, job_application: application) }

    it "redirects unauthenticated requests to sign in" do
      delete application_cover_letter_path(application, cover_letter)
      expect(response).to redirect_to(sign_in_path)
    end

    context "when signed in" do
      before { sign_in_as(user) }

      it "destroys the cover letter and responds with turbo stream remove" do
        expect {
          delete application_cover_letter_path(application, cover_letter),
            headers: { "Accept" => "text/vnd.turbo-stream.html" }
        }.to change(CoverLetter, :count).by(-1)

        expect(response.media_type).to eq("text/vnd.turbo-stream.html")
        expect(response.body).to include("cover_letter_#{cover_letter.id}")
      end

      it "returns 404 for another user's application" do
        other_app    = create(:job_application, user: other_user)
        other_letter = create(:cover_letter, job_application: other_app)
        delete application_cover_letter_path(other_app, other_letter)
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
