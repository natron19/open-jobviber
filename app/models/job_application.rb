class JobApplication < ApplicationRecord
  STATUSES = %w[applied interviewing offer rejected].freeze

  belongs_to :user
  has_many :cover_letters, dependent: :destroy
  has_many :resumes, dependent: :destroy

  validates :user_id, presence: true
  validates :job_title, presence: true, length: { maximum: 200 }
  validates :company, presence: true, length: { maximum: 200 }
  validates :status, inclusion: { in: STATUSES }

  validates :url, format: { with: /\Ahttps?:\/\//i, message: "must begin with http:// or https://" },
                  allow_blank: true
end
