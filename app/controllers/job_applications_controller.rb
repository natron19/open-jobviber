class JobApplicationsController < ApplicationController
  before_action :set_application, only: [:show, :edit, :update, :destroy]

  def index
    @applications = current_user.job_applications.order(created_at: :desc)
  end

  def new
    @application = current_user.job_applications.build
  end

  def create
    @application = current_user.job_applications.build(job_application_params)
    if @application.save
      redirect_to board_path, notice: "Application added."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @profile = current_user.job_seeker_profile
  end

  def edit
  end

  def update
    if @application.update(job_application_params)
      respond_to do |format|
        format.turbo_stream do
          applications = current_user.job_applications.order(created_at: :desc)
          @columns = JobApplication::STATUSES.index_with { |s| applications.select { |a| a.status == s } }
        end
        format.html { redirect_to application_path(@application), notice: "Application updated." }
      end
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @application.destroy
    redirect_to board_path, notice: "Application deleted."
  end

  private

  def set_application
    @application = current_user.job_applications.find(params[:id])
  end

  def job_application_params
    params.require(:job_application).permit(:job_title, :company, :status, :job_description, :url, :notes, :applied_on)
  end
end
