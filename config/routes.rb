require 'sidekiq/web'
require 'admin_constraint'

Rails.application.routes.draw do
  mount Sidekiq::Web => '/sidekiq', constraints: AdminConstraint.new
  get '/sidekiq', to: 'users#auth' # fallback if adminconstraint fails, meaning user is not signed in

  root to: 'static_pages#index'

  get 'emburse_transactions/stats'
  get 'transactions/stats'

  resources :users, only: [ :edit, :update ] do
    collection do
      get 'auth', to: 'users#auth'
      post 'login_code', to: 'users#login_code'
      post 'exchange_login_code', to: 'users#exchange_login_code'
      delete 'logout', to: 'users#logout'
    end
  end

  resources :organizer_position_invites, only: [ :index, :show ], path: 'invites' do
    post 'accept'
    post 'reject'
    post 'cancel'
  end

  resources :organizer_positions, only: [ :destroy ], as: 'organizers' do
    resources :organizer_position_deletion_requests, only: [ :new ], as: 'remove'
  end

  resources :organizer_position_deletion_requests, only: [ :index, :show, :create ], path: 'organizer_deletion_request' do
    post 'close'
    post 'open'
  end

  resources :g_suite_applications, except: [ :new, :create, :edit, :update ] do
    post 'accept'
    post 'reject'

    resources :comments
  end

  resources :g_suite_accounts, only: [ :index, :create, :update, :edit ], path: 'g_suite_accounts' do
    get 'verify', to: 'g_suite_account#verify'
    post 'reject'
  end

  resources :g_suites, except: [ :new, :create, :edit, :update ] do
    resources :g_suite_accounts, only: [ :create ]

    resources :comments
  end

  resources :events do
    get 'team', to: 'events#team', as: :team
    get 'g_suite', to: 'events#g_suite_overview', as: :g_suite_overview
    get 'cards', to: 'events#card_overview', as: :cards_overview
    resources :organizer_position_invites,
      only: [ :new, :create ],
      path: 'invites'
    resources :g_suites, only: [ :new, :create, :edit, :update ]
    resources :g_suite_applications, only: [ :new, :create, :edit, :update ]
    resources :load_card_requests, only: [ :new ]
  end

  resources :sponsors do
    resources :invoices, only: [ :new, :create ]
  end
  resources :invoices, only: [ :show ] do
    get 'manual_payment'
    post 'manually_mark_as_paid'

    resources :comments
  end

  resources :cards

  resources :documents, except: [ :index ] do
    get 'download'
  end

  resources :bank_accounts, only: [ :new, :create, :show ] do
    get 'reauthenticate'
  end

  resources :transactions, only: [ :index, :show, :edit, :update ] do
    resources :comments
  end

  resources :card_requests, path: 'card_requests' do
    post 'reject'
    post 'cancel'

    resources :comments
  end

  resources :load_card_requests, except: [ :new ] do
    post 'accept'
    post 'reject'
    post 'cancel'
    resources :comments
  end

  resources :emburse_transactions, only: [:index, :edit, :update]

  post 'export/finances', to: 'exports#financial_export'
end
