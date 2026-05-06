require "rails_helper"

RSpec.describe Resume, type: :model do
  let(:application) { create(:job_application) }

  describe "validations" do
    it "is valid with valid attributes" do
      expect(build(:resume, job_application: application)).to be_valid
    end

    it "requires body" do
      expect(build(:resume, job_application: application, body: "")).not_to be_valid
      expect(build(:resume, job_application: application, body: nil)).not_to be_valid
    end

    it "requires job_application" do
      expect(build(:resume, job_application: nil)).not_to be_valid
    end
  end

  describe "associations" do
    it "belongs to a job_application" do
      resume = create(:resume, job_application: application)
      expect(resume.job_application).to eq(application)
    end

    it "is destroyed when the job_application is destroyed" do
      create(:resume, job_application: application)
      expect { application.destroy }.to change(Resume, :count).by(-1)
    end
  end
end
