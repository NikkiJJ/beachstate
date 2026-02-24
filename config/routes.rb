Rails.application.routes.draw do
  root "home#index"
  get "/results", to: "results#index"
  get "/blog", to: "blog#index"
  get "/blog/:slug", to: "blog#show", as: :blog_post
end
