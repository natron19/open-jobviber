FactoryBot.define do
  factory :resume do
    association :job_application
    body { "Professional summary.\n\nEXPERIENCE\nSenior Engineer at Acme Corp (2020–present)\nBuilt things." }
    gemini_raw { body }
  end
end
