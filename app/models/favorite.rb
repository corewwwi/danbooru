class Favorite < ActiveRecord::Base
  belongs_to :post, counter_cache: :fav_count
  belongs_to :user, counter_cache: :favorite_count

  validates_uniqueness_of :user_id, scope: :post_id
  after_save :update_post
  after_destroy :update_post

  def self.add(post, user)
    Favorite.create!(:user_id => user.id, :post_id => post.id)
  end

  def self.remove(post, user)
    Favorite.destroy_all(user_id: user.id, post_id: post.id)
  end

  def update_post
    post.regen_fav_string!
  end
end
