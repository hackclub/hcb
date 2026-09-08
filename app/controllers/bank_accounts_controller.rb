# frozen_string_literal: true

class BankAccountsController < ApplicationController
  before_action :set_link_vars, only: [:new, :reauthenticate]

  def new
    authorize BankAccount
  end

  def create
    public_token = params[:auth][:public_token]
    account_id = params[:auth][:account_id]
    account_name = params[:auth][:account_name]

    bank_account_id = params[:auth][:bank_account_id]

    auth_info = PlaidService.instance.exchange_public_token(public_token)

    if bank_account_id.present?
      @account = BankAccount.find(bank_account_id)
    else
      @account = BankAccount.new
    end

    @account.plaid_access_token = auth_info.access_token
    @account.plaid_item_id = auth_info.item_id
    @account.plaid_account_id = account_id
    @account.name = account_name

    authorize @account

    if @account.save
      redirect_to @account
    else
      redirect_to action: :new
    end
  end

  def update
    @bank_account = BankAccount.find(params[:id])
    authorize @bank_account

    if @bank_account.update(bank_account_update_params)
      redirect_back_or_to bank_accounts_admin_index_path
    else
      render :show, status: :unprocessable_content
    end
  end

  def index
    authorize BankAccount
    redirect_to bank_accounts_admin_index_path
  end

  def show
    @account = BankAccount.find(params[:id])
    authorize @account
    @transactions = @account.transactions.includes(:event)
  end

  def reauthenticate
    @account = BankAccount.find(params[:bank_account_id])
    authorize @account

    request = ::Plaid::LinkTokenCreateRequest.new(
      user: { client_user_id: "1" },
      country_codes: ["US"],
      client_name: PlaidService.instance.client_name,
      language: "en",
      access_token: @account.plaid_access_token,
    )

    response = PlaidService.instance.client.link_token_create(request)

    @link_token = response.link_token
  end

  private

  def set_link_vars
    @client_name = PlaidService.instance.client_name
    @link_env = PlaidService.instance.env
    @public_key = PlaidService.instance.public_key
    @product = ["transactions"]
  end

  def bank_account_update_params
    params.require(:bank_account).permit(:should_sync, :should_sync_v2)
  end

end
