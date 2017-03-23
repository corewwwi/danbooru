require 'test_helper'

class FavoriteTest < ActiveSupport::TestCase
  setup do
    @user = FactoryGirl.create(:user)
    CurrentUser.user = @user
    CurrentUser.ip_addr = "127.0.0.1"
    MEMCACHE.flush_all
  end

  teardown do
    CurrentUser.user = nil
    CurrentUser.ip_addr = nil
  end

  context "A favorite" do
    should "delete from all tables" do
      user1 = FactoryGirl.create(:user)
      p1 = FactoryGirl.create(:post)

      p1.add_favorite!(user1)
      assert_equal(1, Favorite.count)

      Favorite.destroy_all(:user_id => user1.id, :post_id => p1.id)
      assert_equal(0, Favorite.count)
    end

    should "know which table it belongs to" do
      user1 = FactoryGirl.create(:user)
      user2 = FactoryGirl.create(:user)
      p1 = FactoryGirl.create(:post)
      p2 = FactoryGirl.create(:post)

      p1.add_favorite!(user1)
      p2.add_favorite!(user1)
      p1.add_favorite!(user2)

      favorites = user1.favorites.order("id desc")
      assert_equal(2, favorites.count)
      assert_equal(p2.id, favorites[0].post_id)
      assert_equal(p1.id, favorites[1].post_id)

      favorites = user2.favorites.order("id desc")
      assert_equal(1, favorites.count)
      assert_equal(p1.id, favorites[0].post_id)
    end

    should "not allow duplicates" do
      user1 = FactoryGirl.create(:user)
      p1 = FactoryGirl.create(:post)
      p2 = FactoryGirl.create(:post)
      p1.add_favorite!(user1)
      p1.add_favorite!(user1)

      assert_equal(1, user1.favorites.count)
    end

    context "when added" do
      setup do
        @post = FactoryGirl.create(:post)
      end

      should "save the favorite in the favorites table" do
        Favorite.add(@post, @user)

        assert(@post.favorites.where(user: @user).exists?)
        assert(@user.favorites.where(post: @post).exists?)
      end

      should "save the favorite in the post's fav_string" do
        Favorite.add(@post, @user)

        assert(@post.reload.favorited_by?(@user.id))
      end

      should "increment the post's fav_count" do
        assert_difference("@post.reload.fav_count", 1) do
          Favorite.add(@post, @user)
        end
      end

      should "increment the user's favorite_count" do
        assert_difference("@user.reload.favorite_count", 1) do
          Favorite.add(@post, @user)
        end
      end
    end

    context "when removed" do
      setup do
        @post = FactoryGirl.create(:post)
        Favorite.add(@post, @user)
      end

      should "remove the favorite from the favorite table" do
        Favorite.remove(@post, @user)

        assert_not(@post.favorites.where(user: @user).exists?)
        assert_not(@user.favorites.where(post: @post).exists?)
      end

      should "remove the favorite from the post's fav_string" do
        Favorite.remove(@post, @user)

        assert_not(!!@post.reload.favorited_by?(@user.id))
      end

      should "decrement the post's fav_count" do
        assert_difference("@post.reload.fav_count", -1) do
          Favorite.remove(@post, @user)
        end
      end

      should "decrement the user's favorite_count" do
        assert_difference("@user.reload.favorite_count", -1) do
          Favorite.remove(@post, @user)
        end
      end
    end
  end
end
