FactoryBot.define do
  factory :cover_letter do
    job_application
    tone       { "confident" }
    body       { "I am excited to apply for this position and bring my experience to your team." }
    gemini_raw { "I am excited to apply for this position and bring my experience to your team." }

    trait :conversational do
      tone { "conversational" }
    end

    trait :concise do
      tone { "concise" }
    end
  end
end
