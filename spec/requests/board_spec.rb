require "rails_helper"

RSpec.describe "Board", type: :request do
  let(:user) { create(:user) }

  describe "GET /board" do
    it "redirects unauthenticated requests to sign in" do
      get board_path
      expect(response).to redirect_to(sign_in_path)
    end

    context "when signed in" do
      before { sign_in_as(user) }

      it "returns 200 with no applications" do
        get board_path
        expect(response).to have_http_status(:ok)
      end

      it "returns 200 with applications" do
        create(:job_application, user: user)
        get board_path
        expect(response).to have_http_status(:ok)
      end

      it "only shows the current user's applications" do
        other_user = create(:user)
        own_app    = create(:job_application, user: user,       job_title: "My Job")
        other_app  = create(:job_application, user: other_user, job_title: "Their Job")

        get board_path

        expect(response.body).to include("My Job")
        expect(response.body).not_to include("Their Job")
      end

      it "groups applications by status" do
        create(:job_application, user: user, job_title: "Applied Job",       status: "applied")
        create(:job_application, user: user, job_title: "Interviewing Job",  status: "interviewing")
        create(:job_application, user: user, job_title: "Offer Job",         status: "offer")
        create(:job_application, user: user, job_title: "Rejected Job",      status: "rejected")

        get board_path

        expect(response.body).to include("Applied Job")
        expect(response.body).to include("Interviewing Job")
        expect(response.body).to include("Offer Job")
        expect(response.body).to include("Rejected Job")
      end
    end
  end
end
