Rails.application.routes.draw do
  resources :file_uploads do
    collection do
      get 'show_via_url'
      post 'upload_via_api'
    end
  end
  resources :api_keys, only: [:index, :create, :destroy]
  
  get "show(/:url)" => "file_uploads#show_via_url"
  get 'dashboard/index'
  get 'dashboard/not_found'
  get 'system_settings/index'
  put 'system_settings/update_settings'
  delete 'system_settings/clean_up_expired_file_uploads'
  devise_for :users
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  root "dashboard#index"
end
