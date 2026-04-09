# frozen_string_literal: true

class SponsorsController < ApplicationController
  before_action :set_sponsor, only: [:show, :edit, :update, :destroy]

  # GET /sponsors
  def index
    authorize Sponsor
    @sponsors = Sponsor.all.includes(:event).order(created_at: :desc)
  end

  # GET /sponsors/1
  def show
    authorize @sponsor
  end

  # GET /sponsors/1/edit
  def edit
    authorize @sponsor
  end

  # POST /sponsors
  def create
    @sponsor = Sponsor.new(sponsor_params)
    @sponsor.event_id = params[:sponsor][:event_id]
    authorize @sponsor

    if @sponsor.save
      flash[:success] = "Sponsor was successfully created."
      redirect_to @sponsor
    else
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /sponsors/1
  def update
    @sponsor.attributes = sponsor_params
    authorize @sponsor

    if @sponsor.save
      flash[:success] = "Sponsor was successfully updated."
      redirect_to @sponsor
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /sponsors/1
  def destroy
    authorize @sponsor

    @sponsor.destroy

    respond_to do |format|
      format.html do
        flash[:success] = "Sponsor was successfully destroyed."
        redirect_to sponsors_url
      end
      format.json { head :no_content }
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_sponsor
    @sponsor = Sponsor.friendly.find(params[:id])
    @event = @sponsor.event
  end

  # Only allow a trusted parameter "white list" through.
  def sponsor_params
    # see pundit readme for details on permitted_attributes
    params.require(:sponsor).permit(policy(Sponsor).permitted_attributes)
  end

end
