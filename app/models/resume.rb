class Resume < ApplicationRecord
  belongs_to :job_application
  validates :body, presence: true
end
