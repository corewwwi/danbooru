module PostSets
  class Favorite < PostSets::Base
    attr_reader :user, :page, :favorites, :params

    def initialize(user_id, page = 1, params = {})
      @params = params
      @user = ::User.find(user_id)
      @favorites = @user.favorites.paginate(page, :limit => limit)
    end

    def limit
      params[:limit] || CurrentUser.user.per_page
    end

    def tag_array
      @tag_array ||= ["fav:#{user.name}"]
    end

    def tag_string
      tag_array.uniq.join(" ")
    end

    def humanized_tag_string
      "fav:#{user.pretty_name}"
    end

    def posts
      @posts ||= favorites.includes(:post).map(&:post).compact
    end

    def presenter
      @presenter ||= ::PostSetPresenters::Favorite.new(self)
    end
  end
end
