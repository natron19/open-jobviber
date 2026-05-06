class ResumesController < ApplicationController
  rate_limit to: 10, within: 1.minute, only: [:create]

  def create
    @application = current_user.job_applications.find(params[:application_id])
    @profile = current_user.job_seeker_profile

    unless @profile&.background_summary.present?
      return render turbo_stream: turbo_stream.update(
        "resumes_#{@application.id}",
        partial: "resumes/resumes",
        locals: { application: @application, profile: @profile }
      )
    end

    result = GeminiService.generate(
      template:  "jobviber_resume_v1",
      variables: {
        background_summary: @profile.background_summary,
        key_skills:         @profile.key_skills,
        work_history:       @profile.work_history.to_s,
        education:          @profile.education.to_s,
        job_title:          @application.job_title,
        company:            @application.company,
        job_description:    @application.job_description.to_s
      }
    )

    @application.resumes.create!(body: result, gemini_raw: result)

    render turbo_stream: turbo_stream.update(
      "resumes_#{@application.id}",
      partial: "resumes/resumes",
      locals: { application: @application, profile: @profile }
    )

  rescue GeminiService::BudgetExceededError
    render turbo_stream: turbo_stream.update(
      "resumes_#{@application.id}",
      partial: "shared/ai_error",
      locals: { error_type: :budget_exceeded }
    )
  rescue GeminiService::GatekeeperError
    render turbo_stream: turbo_stream.update(
      "resumes_#{@application.id}",
      partial: "shared/ai_error",
      locals: { error_type: :gatekeeper_blocked }
    )
  rescue GeminiService::TimeoutError
    render turbo_stream: turbo_stream.update(
      "resumes_#{@application.id}",
      partial: "shared/ai_error",
      locals: { error_type: :timeout }
    )
  rescue GeminiService::GeminiError
    render turbo_stream: turbo_stream.update(
      "resumes_#{@application.id}",
      partial: "shared/ai_error",
      locals: { error_type: :error }
    )
  end

  def destroy
    @application = current_user.job_applications.find(params[:application_id])
    @resume = @application.resumes.find(params[:id])
    @resume.destroy
    render turbo_stream: turbo_stream.remove("resume_#{@resume.id}")
  end
end
