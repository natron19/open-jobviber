FactoryBot.define do
  factory :job_seeker_profile do
    user
    background_summary { "Experienced software engineer with 6 years building web applications." }
    key_skills         { "Ruby on Rails, PostgreSQL, React, TypeScript" }
  end
end
