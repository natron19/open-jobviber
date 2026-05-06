class CoverLetter < ApplicationRecord
  TONES = %w[confident conversational concise].freeze

  belongs_to :job_application
  has_one :user, through: :job_application

  validates :job_application_id, presence: true
  validates :tone, inclusion: { in: TONES }
  validates :body, presence: true
end
