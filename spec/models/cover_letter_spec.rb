require "rails_helper"

RSpec.describe CoverLetter, type: :model do
  let(:application) { create(:job_application) }

  describe "validations" do
    it "is valid with valid attributes" do
      expect(build(:cover_letter, job_application: application)).to be_valid
    end

    it "requires body" do
      expect(build(:cover_letter, job_application: application, body: "")).not_to be_valid
      expect(build(:cover_letter, job_application: application, body: nil)).not_to be_valid
    end

    it "requires job_application" do
      letter = build(:cover_letter, job_application: nil)
      expect(letter).not_to be_valid
      expect(letter.errors[:job_application]).to be_present
    end

    it "validates tone inclusion" do
      expect(build(:cover_letter, job_application: application, tone: "confident")).to be_valid
      expect(build(:cover_letter, job_application: application, tone: "conversational")).to be_valid
      expect(build(:cover_letter, job_application: application, tone: "concise")).to be_valid
      expect(build(:cover_letter, job_application: application, tone: "casual")).not_to be_valid
    end
  end

  describe "associations" do
    it "belongs to a job_application" do
      letter = create(:cover_letter, job_application: application)
      expect(letter.job_application).to eq(application)
    end
  end

  describe "gemini_raw" do
    it "can be saved as nil independently of body" do
      letter = create(:cover_letter, job_application: application, gemini_raw: nil)
      expect(letter.reload.gemini_raw).to be_nil
      expect(letter.body).to be_present
    end

    it "can be saved with a value distinct from body" do
      letter = create(:cover_letter, job_application: application,
                      body: "Parsed body", gemini_raw: "Raw Gemini output")
      expect(letter.reload.gemini_raw).to eq("Raw Gemini output")
      expect(letter.body).to eq("Parsed body")
    end
  end
end
