FactoryBot.define do
  factory :job_application do
    user
    job_title       { "Software Engineer" }
    company         { "Acme Corp" }
    status          { "applied" }
    job_description { "We are looking for a skilled engineer to join our team." }

    trait :interviewing do
      status { "interviewing" }
    end

    trait :offer do
      status { "offer" }
    end

    trait :rejected do
      status { "rejected" }
    end
  end
end
