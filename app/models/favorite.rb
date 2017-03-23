class Favorite < ActiveRecord::Base
  belongs_to :post, counter_cache: :fav_count
  belongs_to :user, counter_cache: :favorite_count

  attr_accessible :user_id, :post_id

  validates_uniqueness_of :user_id, scope: :post_id

  def self.add(post, user)
    Favorite.transaction do
      Favorite.create!(:user_id => user.id, :post_id => post.id)
      post.append_user_to_fav_string(user.id)
    end
  end

  def self.remove(post, user)
    Favorite.transaction do
      return unless Favorite.for_user(user.id).where(:user_id => user.id, :post_id => post.id).exists?
      Favorite.destroy_all(user_id: user.id, post_id: post.id)
      post.delete_user_from_fav_string(user.id)
    end
  end
end
