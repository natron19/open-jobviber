class CoverLettersController < ApplicationController
  rate_limit to: 10, within: 1.minute, only: [:create]

  def create
    @application = current_user.job_applications.find(params[:application_id])
    @profile = current_user.job_seeker_profile

    unless @profile&.background_summary.present?
      return render turbo_stream: turbo_stream.update(
        "cover_letters_#{@application.id}",
        partial: "cover_letters/cover_letters",
        locals: { application: @application, profile: @profile }
      )
    end

    result = GeminiService.generate(
      template:  "jobviber_cover_letter_v1",
      variables: {
        background_summary: @profile.background_summary,
        key_skills:         @profile.key_skills,
        job_title:          @application.job_title,
        company:            @application.company,
        job_description:    @application.job_description.to_s,
        tone:               params[:tone]
      }
    )

    @application.cover_letters.create!(body: result, gemini_raw: result, tone: params[:tone])

    render turbo_stream: turbo_stream.update(
      "cover_letters_#{@application.id}",
      partial: "cover_letters/cover_letters",
      locals: { application: @application, profile: @profile }
    )

  rescue GeminiService::BudgetExceededError
    render turbo_stream: turbo_stream.update(
      "cover_letters_#{@application.id}",
      partial: "shared/ai_error",
      locals: { error_type: :budget_exceeded }
    )
  rescue GeminiService::GatekeeperError
    render turbo_stream: turbo_stream.update(
      "cover_letters_#{@application.id}",
      partial: "shared/ai_error",
      locals: { error_type: :gatekeeper_blocked }
    )
  rescue GeminiService::TimeoutError
    render turbo_stream: turbo_stream.update(
      "cover_letters_#{@application.id}",
      partial: "shared/ai_error",
      locals: { error_type: :timeout }
    )
  rescue GeminiService::GeminiError
    render turbo_stream: turbo_stream.update(
      "cover_letters_#{@application.id}",
      partial: "shared/ai_error",
      locals: { error_type: :error }
    )
  end

  def destroy
    @application = current_user.job_applications.find(params[:application_id])
    @cover_letter = @application.cover_letters.find(params[:id])
    @cover_letter.destroy
    render turbo_stream: turbo_stream.remove("cover_letter_#{@cover_letter.id}")
  end
end
