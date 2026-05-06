require "rails_helper"

RSpec.describe "JobApplications", type: :request do
  let(:user)       { create(:user) }
  let(:other_user) { create(:user) }
  let!(:application) { create(:job_application, user: user) }

  describe "GET /applications" do
    it "redirects unauthenticated requests to sign in" do
      get applications_path
      expect(response).to redirect_to(sign_in_path)
    end

    context "when signed in" do
      before { sign_in_as(user) }

      it "returns 200" do
        get applications_path
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "GET /applications/new" do
    it "redirects unauthenticated requests to sign in" do
      get new_application_path
      expect(response).to redirect_to(sign_in_path)
    end
  end

  describe "POST /applications" do
    it "redirects unauthenticated requests to sign in" do
      post applications_path, params: { job_application: { job_title: "Dev", company: "Acme" } }
      expect(response).to redirect_to(sign_in_path)
    end

    context "when signed in" do
      before { sign_in_as(user) }

      it "creates application and redirects to board" do
        expect {
          post applications_path, params: {
            job_application: { job_title: "Engineer", company: "Acme Corp", status: "applied" }
          }
        }.to change(JobApplication, :count).by(1)
        expect(response).to redirect_to(board_path)
      end

      it "re-renders new with 422 for missing job_title" do
        post applications_path, params: { job_application: { job_title: "", company: "Acme" } }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "GET /applications/:id" do
    it "redirects unauthenticated requests to sign in" do
      get application_path(application)
      expect(response).to redirect_to(sign_in_path)
    end

    context "when signed in" do
      before { sign_in_as(user) }

      it "returns 200 for own application" do
        get application_path(application)
        expect(response).to have_http_status(:ok)
      end

      it "returns 404 for another user's application" do
        other_app = create(:job_application, user: other_user)
        get application_path(other_app)
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "GET /applications/:id/edit" do
    it "redirects unauthenticated requests to sign in" do
      get edit_application_path(application)
      expect(response).to redirect_to(sign_in_path)
    end
  end

  describe "PATCH /applications/:id" do
    it "redirects unauthenticated requests to sign in" do
      patch application_path(application), params: { job_application: { status: "interviewing" } }
      expect(response).to redirect_to(sign_in_path)
    end

    context "when signed in" do
      before { sign_in_as(user) }

      it "updates and redirects to show for HTML format" do
        patch application_path(application), params: {
          job_application: { job_title: "Updated Title", company: "New Corp", status: "applied" }
        }
        expect(response).to redirect_to(application_path(application))
        expect(application.reload.job_title).to eq("Updated Title")
      end

      it "responds with turbo stream for turbo_stream format" do
        patch application_path(application),
          params: { job_application: { status: "interviewing" } },
          headers: { "Accept" => "text/vnd.turbo-stream.html" }
        expect(response.media_type).to eq("text/vnd.turbo-stream.html")
        expect(application.reload.status).to eq("interviewing")
      end

      it "returns 404 for another user's application" do
        other_app = create(:job_application, user: other_user)
        patch application_path(other_app), params: { job_application: { status: "interviewing" } }
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "DELETE /applications/:id" do
    it "redirects unauthenticated requests to sign in" do
      delete application_path(application)
      expect(response).to redirect_to(sign_in_path)
    end

    context "when signed in" do
      before { sign_in_as(user) }

      it "destroys application and redirects to board" do
        expect {
          delete application_path(application)
        }.to change(JobApplication, :count).by(-1)
        expect(response).to redirect_to(board_path)
      end
    end
  end
end
