class JobSeekerProfile < ApplicationRecord
  belongs_to :user

  validates :user_id, presence: true, uniqueness: true
  validates :background_summary, presence: true, length: { maximum: 4000 }
  validates :key_skills, presence: true, length: { maximum: 500 }
  validates :work_history, length: { maximum: 6000 }, allow_blank: true
  validates :education, length: { maximum: 2000 }, allow_blank: true
end
