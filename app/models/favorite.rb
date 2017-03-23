class Favorite < ActiveRecord::Base
  belongs_to :post
  belongs_to :user

  attr_accessible :user_id, :post_id

  validates_uniqueness_of :user_id, scope: :post_id

  def self.add(post, user)
    Favorite.transaction do
      User.where(:id => user.id).select("id").lock("FOR UPDATE NOWAIT").first

      Favorite.create!(:user_id => user.id, :post_id => post.id)
      Post.where(:id => post.id).update_all("fav_count = fav_count + 1")
      post.append_user_to_fav_string(user.id)
      User.where(:id => user.id).update_all("favorite_count = favorite_count + 1")
      user.favorite_count += 1
      # post.fav_count += 1 # this is handled in Post#clean_fav_string!
    end
  end

  def self.remove(post, user)
    Favorite.transaction do
      User.where(:id => user.id).select("id").lock("FOR UPDATE NOWAIT").first

      return unless Favorite.for_user(user.id).where(:user_id => user.id, :post_id => post.id).exists?
      Favorite.destroy_all(user_id: user.id, post_id: post.id)
      Post.where(:id => post.id).update_all("fav_count = fav_count - 1")
      post.delete_user_from_fav_string(user.id)
      User.where(:id => user.id).update_all("favorite_count = favorite_count - 1")
      user.favorite_count -= 1
      post.fav_count -= 1
    end
  end
end
