Rails.application.routes.draw do
  root "users#index"
  resources :users
  get "/api-docs", to: redirect("/swagger/index.html")
end
