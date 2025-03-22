# frozen_string_literal: true

class CommentsController < ApplicationController
  before_action :set_comment, only: [:edit, :update, :destroy]
  before_action :set_commentable, except: [:edit, :update, :destroy]

  def new
    authorize @commentable
    @comment = @commentable.comments.new
  end

  def create
    @comment = @commentable.comments.build(comment_params)
    @comment.user = current_user

    authorize @comment

    if @comment.save
      flash[:success] = "Comment created."
      redirect_to @commentable.is_a?(Event) ? edit_event_path(@commentable, tab: :admin) : @commentable
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @commentable = @comment.commentable
    @event = @commentable.is_a?(Event) ? @commentable : @commentable.event

    authorize @comment
  end

  def update
    @comment.assign_attributes(comment_params)
    authorize @comment

    if @comment.save
      flash[:success] = "Comment successfully updated"
      # @commentable is not guaranteed to have a #show,
      # but all commentables effectively have a #show
      # because that's the only place comments show up as a list.
      redirect_to @comment.commentable.is_a?(Event) ? edit_event_path(@comment.commentable, tab: :admin) : @comment.commentable
    else
      @commentable = @comment.commentable
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @comment
    @comment.destroy!

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.remove(@comment)
      end

      format.any { redirect_back_or_to @comment.commentable }
    end
  end

  private

  def comment_params
    params.require(:comment).permit(:content, :file, :admin_only)
  end

  COMMENTABLE_TYPE_MAP = [AchTransfer, Disbursement, EmburseCardRequest, EmburseTransaction,
                          EmburseTransfer, Event, GSuite, HcbCode, Api::Models::CardCharge,
                          OrganizerPositionDeletionRequest, User, Reimbursement::Report].index_by(&:to_s).freeze

  # Given a route "/transactions/25/comments", this method sets @commentable to
  # Transaction with ID 25
  def set_commentable
    resource = params[:comment][:commentable_type] || request.path.split("/")[1]
    id =       params[:comment][:commentable_id]   || request.path.split("/")[2]

    klass = COMMENTABLE_TYPE_MAP[resource.singularize.classify]
    @commentable = klass.find(id)
  end

  def set_comment
    @comment = Comment.find(params[:id] || params[:comment_id])
  end

end
