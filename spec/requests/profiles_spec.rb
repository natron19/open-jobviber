require "rails_helper"

RSpec.describe "Profiles", type: :request do
  let(:user) { create(:user) }

  describe "GET /profile" do
    it "redirects unauthenticated requests to sign in" do
      get profile_path
      expect(response).to redirect_to(sign_in_path)
    end

    context "when signed in" do
      before { sign_in_as(user) }

      it "returns 200" do
        get profile_path
        expect(response).to have_http_status(:ok)
      end

      it "returns 200 when profile exists" do
        create(:job_seeker_profile, user: user)
        get profile_path
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "GET /profile/edit" do
    it "redirects unauthenticated requests to sign in" do
      get edit_profile_path
      expect(response).to redirect_to(sign_in_path)
    end

    context "when signed in" do
      before { sign_in_as(user) }

      it "returns 200" do
        get edit_profile_path
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "PATCH /profile" do
    it "redirects unauthenticated requests to sign in" do
      patch profile_path, params: { job_seeker_profile: { background_summary: "Test" } }
      expect(response).to redirect_to(sign_in_path)
    end

    context "when signed in" do
      before { sign_in_as(user) }

      it "creates a new profile and redirects to profile page" do
        expect {
          patch profile_path, params: {
            job_seeker_profile: {
              background_summary: "I am a senior engineer with 6 years experience.",
              key_skills: "Ruby, Rails, PostgreSQL"
            }
          }
        }.to change(JobSeekerProfile, :count).by(1)
        expect(response).to redirect_to(profile_path)
      end

      it "updates existing profile and redirects" do
        profile = create(:job_seeker_profile, user: user)
        patch profile_path, params: {
          job_seeker_profile: {
            background_summary: "Updated summary.",
            key_skills: "Go, Rust"
          }
        }
        expect(response).to redirect_to(profile_path)
        expect(profile.reload.background_summary).to eq("Updated summary.")
      end

      it "re-renders edit with 422 for blank background_summary" do
        patch profile_path, params: {
          job_seeker_profile: { background_summary: "", key_skills: "Ruby" }
        }
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "is scoped to current user" do
        other_user = create(:user)
        create(:job_seeker_profile, user: other_user)

        patch profile_path, params: {
          job_seeker_profile: {
            background_summary: "My summary.",
            key_skills: "My skills."
          }
        }

        expect(response).to redirect_to(profile_path)
        expect(user.reload.job_seeker_profile.background_summary).to eq("My summary.")
      end
    end
  end
end
