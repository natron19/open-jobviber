require "rails_helper"

RSpec.describe JobSeekerProfile, type: :model do
  let(:user) { create(:user) }

  describe "validations" do
    it "is valid with valid attributes" do
      expect(build(:job_seeker_profile, user: user)).to be_valid
    end

    it "requires background_summary" do
      expect(build(:job_seeker_profile, user: user, background_summary: "")).not_to be_valid
      expect(build(:job_seeker_profile, user: user, background_summary: nil)).not_to be_valid
    end

    it "requires key_skills" do
      expect(build(:job_seeker_profile, user: user, key_skills: "")).not_to be_valid
      expect(build(:job_seeker_profile, user: user, key_skills: nil)).not_to be_valid
    end

    it "enforces max length of 4000 on background_summary" do
      expect(build(:job_seeker_profile, user: user, background_summary: "a" * 4001)).not_to be_valid
      expect(build(:job_seeker_profile, user: user, background_summary: "a" * 4000)).to be_valid
    end

    it "enforces max length of 500 on key_skills" do
      expect(build(:job_seeker_profile, user: user, key_skills: "a" * 501)).not_to be_valid
      expect(build(:job_seeker_profile, user: user, key_skills: "a" * 500)).to be_valid
    end

    it "accepts blank work_history and education" do
      expect(build(:job_seeker_profile, user: user, work_history: nil, education: nil)).to be_valid
      expect(build(:job_seeker_profile, user: user, work_history: "", education: "")).to be_valid
    end

    it "enforces max length of 6000 on work_history" do
      expect(build(:job_seeker_profile, user: user, work_history: "a" * 6001)).not_to be_valid
      expect(build(:job_seeker_profile, user: user, work_history: "a" * 6000)).to be_valid
    end

    it "enforces max length of 2000 on education" do
      expect(build(:job_seeker_profile, user: user, education: "a" * 2001)).not_to be_valid
      expect(build(:job_seeker_profile, user: user, education: "a" * 2000)).to be_valid
    end

    it "enforces uniqueness of user_id" do
      create(:job_seeker_profile, user: user)
      duplicate = build(:job_seeker_profile, user: user)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:user_id]).to be_present
    end
  end

  describe "associations" do
    it "belongs to a user" do
      profile = create(:job_seeker_profile, user: user)
      expect(profile.user).to eq(user)
    end
  end
end
