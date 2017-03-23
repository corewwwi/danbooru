class Favorite < ActiveRecord::Base
  belongs_to :post, counter_cache: :fav_count
  belongs_to :user, counter_cache: :favorite_count

  validates_uniqueness_of :user_id, scope: :post_id
  after_save :update_post
  after_destroy :update_post

  def self.add(post, user)
    Favorite.create(user_id: user.id, post_id: post.id)
  end

  def self.remove(post, user)
    Favorite.destroy_all(user_id: user.id, post_id: post.id)
  end

  def move(other_post)
    other_fav = other_post.favorites.find { |f| f.user_id == user_id }

    # if the user hasn't already fav'd the other post, move this fav to the other post.
    if other_fav.nil?
      self.update(post: other_post)
    else # if the user has already fav'd the other post...
      if other_fav.id < id
        # ...and the other fav is older than this fav, then keep the other fav and remove this fav.
        self.destroy
      else
        # ...and the other fav is newer than this fav, then replace the other fav with this fav.
        other_fav.destroy
        self.update(post: other_post)
      end
    end
  end

  def update_post
    if post_id_changed? && post_id_was.present?
      Post.find(post_id_was).regen_fav_string!
    end

    post.regen_fav_string!
  end
end
