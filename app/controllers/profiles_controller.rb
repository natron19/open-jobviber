class ProfilesController < ApplicationController
  def show
    @profile = current_user.job_seeker_profile || current_user.build_job_seeker_profile
  end

  def edit
    @profile = current_user.job_seeker_profile || current_user.build_job_seeker_profile
  end

  def update
    @profile = current_user.job_seeker_profile || current_user.build_job_seeker_profile
    if @profile.update(profile_params)
      redirect_to profile_path, notice: "Profile updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def profile_params
    params.require(:job_seeker_profile).permit(:background_summary, :key_skills, :work_history, :education)
  end
end
