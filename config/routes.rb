Rails.application.routes.draw do

  namespace :admin do
    resources :users, :only => [:edit, :update]
    resource  :alias_and_implication_import, :only => [:new, :create]
    resource  :dashboard, :only => [:show]
  end
  namespace :moderator do
    resource :bulk_revert, :only => [:new, :create]
    resource :dashboard, :only => [:show]
    resources :ip_addrs, :only => [:index] do
      collection do
        get :search
      end
    end
    resources :invitations, :only => [:new, :create, :index]
    resource :tag, :only => [:edit, :update]
    namespace :post do
      resource :queue, :only => [:show] do
        member do
          get :random
        end
      end
      resource :approval, :only => [:create]
      resource :disapproval, :only => [:create]
      resources :posts, :only => [:delete, :undelete, :expunge, :confirm_delete] do
        member do
          get :confirm_delete
          post :expunge
          post :delete
          post :undelete
          get :confirm_move_favorites
          post :move_favorites
          get :confirm_ban
          post :ban
          post :unban
        end
      end
    end
    resources :invitations, :only => [:new, :create, :index, :show]
    resources :ip_addrs, :only => [:index, :search] do
      collection do
        get :search
      end
    end
  end
  namespace :explore do
    resources :posts, :only => [] do
      collection do
        get :popular
        get :viewed
        get :searches
        get :missed_searches
        get :intro
      end
    end
  end
  namespace :maintenance do
    namespace :user do
      resource :email_notification, :only => [:show, :destroy]
      resource :password_reset, :only => [:new, :create, :edit, :update]
      resource :login_reminder, :only => [:new, :create]
      resource :deletion, :only => [:show, :destroy]
      resource :email_change, :only => [:new, :create]
      resource :dmail_filter, :only => [:edit, :update]
      resource :api_key, :only => [:show, :view, :update, :destroy] do
        post :view
      end
    end
  end

  resources :artists do
    member do
      put :revert
      put :ban
      put :unban
      post :undelete
    end
    collection do
      get :show_or_new
      get :banned
      get :finder
    end
  end
  resources :artist_versions, :only => [:index] do
    collection do
      get :search
    end
  end
  resources :bans
  resources :bulk_update_requests do
    member do
      post :approve
    end
  end
  resources :comments do
    resource :votes, :controller => "comment_votes", :only => [:create, :destroy]
    collection do
      get :search
    end
    member do
      post :undelete
    end
  end
  resources :counts do
    collection do
      get :posts
    end
  end
  resources :delayed_jobs, :only => [:index, :destroy] do
    member do
      put :run
      put :retry
      put :cancel
    end
  end
  resources :dmails, :only => [:new, :create, :index, :show, :destroy] do
    member do
      post :spam
      post :ham
    end
    collection do
      post :mark_all_as_read
    end
  end
  resource  :dtext_preview, :only => [:create]
  resources :favorites, :only => [:index, :create, :destroy]
  resources :favorite_groups do
    member do
      put :add_post
    end
    resource :order, :only => [:edit], :controller => "favorite_group_orders"
  end
  resources :forum_posts do
    member do
      post :undelete
    end
    collection do
      get :search
    end
  end
  resources :forum_topics do
    member do
      post :undelete
      get :new_merge
      post :create_merge
      post :subscribe
      post :unsubscribe
    end
    collection do
      post :mark_all_as_read
    end
    resource :visit, :controller => "forum_topic_visits"
  end
  resources :ip_bans
  resource :iqdb_queries, :only => [:create, :show, :check] do
    get :check
  end
  resources :janitor_trials do
    collection do
      get :test
    end
    member do
      put :promote
      put :demote
    end
  end
  resources :mod_actions
  resources :news_updates
  resources :notes do
    collection do
      get :search
    end
    member do
      put :revert
    end
  end
  resources :note_versions, :only => [:index]
  resource :note_previews, :only => [:show]
  resources :pools do
    member do
      put :revert
      post :undelete
    end
    collection do
      get :gallery
    end
    resource :order, :only => [:edit], :controller => "pool_orders"
  end
  resource  :pool_element, :only => [:create, :destroy] do
    collection do
      get :all_select
    end
  end
  resources :pool_versions, :only => [:index] do
    member do
      get :diff
    end
  end
  resources :post_replacements, :only => [:index, :new, :create, :update]
    resources :posts, :only => [:index, :show, :update] do
    resources :events, :only => [:index], :controller => "post_events"
    resources :replacements, :only => [:index, :new, :create], :controller => "post_replacements"
    resource :artist_commentary, :only => [:index, :show] do
      collection { put :create_or_update }
      member { put :revert }
    end
    resource :votes, :controller => "post_votes", :only => [:create, :destroy]
    collection do
      get :random
    end
    member do
      put :revert
      put :copy_notes
      get :show_seq
      put :mark_as_translated
    end
    get :similar, :to => "iqdb_queries#index"
  end
  resources :post_appeals
  resources :post_flags
  resources :post_versions, :only => [:index, :search] do
    member do
      put :undo
    end
    collection do
      get :search
    end
  end
  resources :artist_commentaries, :only => [:index, :show] do
    collection do
      put :create_or_update
      get :search
    end
    member do
      put :revert
    end
  end
  resources :artist_commentary_versions, :only => [:index]
  resource :related_tag, :only => [:show, :update]
  get "reports/uploads" => "reports#uploads"
  get "reports/similar_users" => "reports#similar_users"
  get "reports/upload_tags" => "reports#upload_tags"
  get "reports/post_versions" => "reports#post_versions"
  post "reports/post_versions_create" => "reports#post_versions_create"
  get "reports/down_voting_post" => "reports#down_voting_post"
  post "reports/down_voting_post_create" => "reports#down_voting_post_create"
  resources :saved_searches, :except => [:show] do
    collection do
      get :labels
    end
  end
  resource :session do
    collection do
      get :sign_out
    end
  end
  resource :source, :only => [:show]
  resources :tags do
    resource :correction, :only => [:new, :create, :show], :controller => "tag_corrections"
    collection do
      get :autocomplete
    end
  end
  resources :tag_aliases do
    resource :correction, :controller => "tag_alias_corrections"
    member do
      post :approve
    end
  end
  resource :tag_alias_request, :only => [:new, :create]
  resources :tag_implications do
    member do
      post :approve
    end
  end
  resource :tag_implication_request, :only => [:new, :create]
  resources :uploads do
    collection do
      get :batch
      get :image_proxy
    end
  end
  resources :users do
    resource :password, :only => [:edit], :controller => "maintenance/user/passwords"
    resource :api_key, :only => [:show, :view, :update, :destroy], :controller => "maintenance/user/api_keys" do
      post :view
    end

    collection do
      get :search
      get :custom_style
    end

    member do
      delete :cache
    end
  end
  resource :user_upgrade, :only => [:new, :create, :show]
  resources :user_feedbacks do
    collection do
      get :search
    end
  end
  resources :user_name_change_requests do
    member do
      post :approve
      post :reject
    end
  end
  resource :user_revert, :only => [:new, :create]
  resources :wiki_pages do
    member do
      put :revert
    end
    collection do
      get :search
      get :show_or_new
    end
  end
  resources :wiki_page_versions, :only => [:index, :show, :diff] do
    collection do
      get :diff
    end
  end

  get "/static/keyboard_shortcuts" => "static#keyboard_shortcuts", :as => "keyboard_shortcuts"
  get "/static/bookmarklet" => "static#bookmarklet", :as => "bookmarklet"
  get "/static/site_map" => "static#site_map", :as => "site_map"
  get "/static/terms_of_service" => "static#terms_of_service", :as => "terms_of_service"
  post "/static/accept_terms_of_service" => "static#accept_terms_of_service", :as => "accept_terms_of_service"
  get "/static/mrtg" => "static#mrtg", :as => "mrtg"
  get "/static/contact" => "static#contact", :as => "contact"
  get "/static/benchmark" => "static#benchmark"
  get "/static/name_change" => "static#name_change", :as => "name_change"
  get "/meta_searches/tags" => "meta_searches#tags", :as => "meta_searches_tags"

  get "/intro" => redirect("/explore/posts/intro")

  root :to => "posts#index"

  # get "*other", :to => "static#not_found"
end
