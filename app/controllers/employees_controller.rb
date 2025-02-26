# frozen_string_literal: true

class EmployeesController < ApplicationController
  include SetEvent

  def create
    @event = Event.friendly.find(employee_params[:event_id])
    user = User.find_or_create_by!(email: employee_params[:email])
    @employee = @event.employees.build(entity: user)

    authorize @employee

    if @employee.save
      redirect_to event_employees_path(@event), flash: { success: "Employee successfully invited." }
    else
      redirect_to event_employees_path(@event), flash: { error: @employee.errors.full_messages.to_sentence }
    end
  end

  def show
    @employee = Employee.find(params[:id])
    @event = @employee.event
    authorize @employee
  end

  def onboard
    @employee = Employee.find(params[:employee_id])
    authorize @employee
    @employee.update(gusto_id: params[:gusto_id])
    @employee.mark_onboarded!
    redirect_to employees_admin_index_path
  end

  def terminate
    @employee = Employee.find(params[:employee_id])
    authorize @employee
    @employee.mark_terminated!
    redirect_to current_user.admin? ? employees_admin_index_path : event_employees_path(@employee.event)
  end

  def destroy
    @employee = Employee.find(params[:id])
    authorize @employee
    @employee.destroy
    redirect_to current_user.admin? ? employees_admin_index_path : event_employees_path(@employee.event)
  end

  private

  def employee_params
    params.require(:employee).permit(:event_id, :email).compact_blank
  end

end
