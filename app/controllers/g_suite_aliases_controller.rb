# frozen_string_literal: true

class GSuiteAliasesController < ApplicationController
  def create
    @g_suite_account = GSuiteAccount.find(params[:g_suite_account_id])
    @g_suite = @g_suite_account.g_suite
    @g_suite_domain = @g_suite.domain
    @address = "#{params[:address]}@#{@g_suite_domain}"

    @g_suite_alias = @g_suite_account.g_suite_aliases.new(address: @address)
    authorize @g_suite_alias

    if @g_suite_alias.save
      flash[:success] = "Google Workspace alias created."
    else
      flash[:error] = @g_suite_alias.errors.full_messages.to_sentence
    end

    redirect_to event_g_suite_overview_path(event_id: @g_suite.event.slug)
  end

  def destroy
    @g_suite_alias = GSuiteAlias.find(params[:g_suite_alias_id])

    authorize @g_suite_alias
    event = @g_suite_alias.g_suite.event

    begin
      @g_suite_alias.destroy!

      flash[:success] = "Google Workspace alias deleted."
    rescue => e
      Rails.error.report(e)

      flash[:error] = e.message
    end

    redirect_to event_g_suite_overview_path(event_id: event.slug)
  end

end
