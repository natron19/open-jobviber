class DashboardController < ApplicationController
  before_action :redirect_to_board

  def show
  end

  private

  def redirect_to_board
    redirect_to board_path
  end
end
