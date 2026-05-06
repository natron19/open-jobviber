require "rails_helper"

RSpec.describe "Resumes", type: :request do
  let(:user)        { create(:user) }
  let(:other_user)  { create(:user) }
  let!(:application) { create(:job_application, user: user) }
  let!(:profile)     { create(:job_seeker_profile, user: user) }

  describe "POST /applications/:application_id/resumes" do
    it "redirects unauthenticated requests to sign in" do
      post application_resumes_path(application)
      expect(response).to redirect_to(sign_in_path)
    end

    context "when signed in" do
      before { sign_in_as(user) }

      it "calls GeminiService with correct template and variables" do
        allow(GeminiService).to receive(:generate).and_return("Resume content.")

        post application_resumes_path(application),
          headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(GeminiService).to have_received(:generate).with(
          template: "jobviber_resume_v1",
          variables: hash_including(
            background_summary: profile.background_summary,
            key_skills: profile.key_skills,
            job_title: application.job_title,
            company: application.company
          )
        )
      end

      it "creates a Resume with body and gemini_raw populated" do
        allow(GeminiService).to receive(:generate).and_return("My resume.")

        expect {
          post application_resumes_path(application),
            headers: { "Accept" => "text/vnd.turbo-stream.html" }
        }.to change(Resume, :count).by(1)

        resume = Resume.last
        expect(resume.body).to eq("My resume.")
        expect(resume.gemini_raw).to eq("My resume.")
      end

      it "responds with turbo stream on success" do
        allow(GeminiService).to receive(:generate).and_return("Resume text.")

        post application_resumes_path(application),
          headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      end

      it "renders error partial on BudgetExceededError" do
        allow(GeminiService).to receive(:generate).and_raise(GeminiService::BudgetExceededError)

        post application_resumes_path(application),
          headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(response.media_type).to eq("text/vnd.turbo-stream.html")
        expect(response.body).to include("daily AI request limit")
      end

      it "renders error partial on GatekeeperError" do
        allow(GeminiService).to receive(:generate).and_raise(GeminiService::GatekeeperError)

        post application_resumes_path(application),
          headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(response.body).to include("couldn't be processed")
      end

      it "renders error partial on TimeoutError" do
        allow(GeminiService).to receive(:generate).and_raise(GeminiService::TimeoutError)

        post application_resumes_path(application),
          headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(response.body).to include("took too long")
      end

      it "returns 404 for another user's application" do
        other_app = create(:job_application, user: other_user)
        post application_resumes_path(other_app)
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "DELETE /applications/:application_id/resumes/:id" do
    let!(:resume) { create(:resume, job_application: application) }

    it "redirects unauthenticated requests to sign in" do
      delete application_resume_path(application, resume)
      expect(response).to redirect_to(sign_in_path)
    end

    context "when signed in" do
      before { sign_in_as(user) }

      it "destroys the resume and responds with turbo stream remove" do
        expect {
          delete application_resume_path(application, resume),
            headers: { "Accept" => "text/vnd.turbo-stream.html" }
        }.to change(Resume, :count).by(-1)

        expect(response.media_type).to eq("text/vnd.turbo-stream.html")
        expect(response.body).to include("resume_#{resume.id}")
      end

      it "returns 404 for another user's application" do
        other_app    = create(:job_application, user: other_user)
        other_resume = create(:resume, job_application: other_app)
        delete application_resume_path(other_app, other_resume)
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
