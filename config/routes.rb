Rails.application.routes.draw do
  resources :bathing_sites, only: [:index, :show, :create, :update], defaults: { format: :json }

  root "home#index"
  get "/results", to: "results#index"
  get "/blog", to: "blog#index"
  get "/blog/:slug", to: "blog#show", as: :blog_post
end
