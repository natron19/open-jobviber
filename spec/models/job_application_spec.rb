require "rails_helper"

RSpec.describe JobApplication, type: :model do
  let(:user) { create(:user) }

  describe "validations" do
    it "is valid with valid attributes" do
      expect(build(:job_application, user: user)).to be_valid
    end

    it "requires job_title" do
      expect(build(:job_application, user: user, job_title: "")).not_to be_valid
      expect(build(:job_application, user: user, job_title: nil)).not_to be_valid
    end

    it "requires company" do
      expect(build(:job_application, user: user, company: "")).not_to be_valid
      expect(build(:job_application, user: user, company: nil)).not_to be_valid
    end

    it "requires user" do
      expect(build(:job_application, user: nil)).not_to be_valid
    end

    it "enforces max length of 200 on job_title" do
      expect(build(:job_application, user: user, job_title: "a" * 201)).not_to be_valid
      expect(build(:job_application, user: user, job_title: "a" * 200)).to be_valid
    end

    it "enforces max length of 200 on company" do
      expect(build(:job_application, user: user, company: "a" * 201)).not_to be_valid
      expect(build(:job_application, user: user, company: "a" * 200)).to be_valid
    end

    it "validates status inclusion" do
      expect(build(:job_application, user: user, status: "applied")).to be_valid
      expect(build(:job_application, user: user, status: "interviewing")).to be_valid
      expect(build(:job_application, user: user, status: "offer")).to be_valid
      expect(build(:job_application, user: user, status: "rejected")).to be_valid
      expect(build(:job_application, user: user, status: "ghost")).not_to be_valid
    end

    describe "url validation" do
      it "accepts a blank url" do
        expect(build(:job_application, user: user, url: "")).to be_valid
        expect(build(:job_application, user: user, url: nil)).to be_valid
      end

      it "accepts urls beginning with http://" do
        expect(build(:job_application, user: user, url: "http://example.com/job")).to be_valid
      end

      it "accepts urls beginning with https://" do
        expect(build(:job_application, user: user, url: "https://example.com/job")).to be_valid
      end

      it "rejects urls without a scheme" do
        expect(build(:job_application, user: user, url: "example.com/job")).not_to be_valid
      end

      it "rejects urls with an invalid scheme" do
        expect(build(:job_application, user: user, url: "ftp://example.com/job")).not_to be_valid
      end
    end
  end

  describe "associations" do
    it "belongs to a user" do
      application = create(:job_application, user: user)
      expect(application.user).to eq(user)
    end

    it "destroys associated cover letters when the application is destroyed" do
      application = create(:job_application, user: user)
      create(:cover_letter, job_application: application)
      expect { application.destroy }.to change(CoverLetter, :count).by(-1)
    end
  end
end
