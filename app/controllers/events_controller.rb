class EventsController < ApplicationController
  before_action :signed_in_user
  before_action :set_event, only: [:show, :edit, :update, :destroy]

  # GET /events
  def index
    authorize Event

    @events = Event.all
  end

  # GET /events/new
  def new
    @event = Event.new
    authorize @event
  end

  # POST /events
  def create
    @event = Event.new(event_params)
    authorize @event

    if @event.save
      flash[:success] = 'Event was successfully created.'
      redirect_to @event
    else
      render :new
    end
  end

  # GET /events/1
  def show
    @card_requests = @event.card_requests.outstanding
    @load_card_requests = @event.load_card_requests.outstanding
    authorize @event
  end

  # GET /events/1/edit
  def edit
    authorize @event
  end

  # PATCH/PUT /events/1
  def update
    authorize @event

    if @event.update(event_params)
      flash[:success] = 'Event was successfully updated.'
      redirect_to @event
    else
      render :edit
    end
  end

  # DELETE /events/1
  def destroy
    authorize @event

    @event.destroy
    flash[:success] = 'Event was successfully destroyed.'
    redirect_to events_url
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_event
      @event = Event.find(params[:id])
    end

    # Only allow a trusted parameter "white list" through.
    def event_params
      params.require(:event).permit(:name, :start, :end, :address, :sponsorship_fee)
    end
end
