class BoardController < ApplicationController
  def show
    applications = current_user.job_applications.order(created_at: :desc)
    @columns = JobApplication::STATUSES.index_with { |s| applications.select { |a| a.status == s } }
    profile = current_user.job_seeker_profile
    @profile_complete = profile.present? && profile.background_summary.present?
  end
end
