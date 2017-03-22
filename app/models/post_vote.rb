class PostVote < ActiveRecord::Base
  class Error < Exception ; end

  belongs_to :post
  belongs_to :user
  before_validation :initialize_user, :on => :create
  validates_presence_of :post_id, :user_id, :score
  validates_inclusion_of :score, :in => [SuperVoter::MAGNITUDE, 1, -1, -SuperVoter::MAGNITUDE]
  validates_uniqueness_of :user_id, :scope => :post_id, :message => "have already voted for this post", strict: PostVote::Error
  validate :validate_user_can_vote

  attr_accessible :post_id, :user_id, :score, :vote

  after_save :update_post_on_save
  after_destroy :update_post_on_destroy

  def self.prune!
    where("created_at < ?", 90.days.ago).delete_all
  end

  def self.positive_user_ids
    select_values_sql("select user_id from post_votes where score > 0 group by user_id having count(*) > 100")
  end

  def self.negative_post_ids(user_id)
    select_values_sql("select post_id from post_votes where score < 0 and user_id = ?", user_id)
  end

  def self.positive_post_ids(user_id)
    select_values_sql("select post_id from post_votes where score > 0 and user_id = ?", user_id)
  end

  def vote=(x)
    if x == "up"
      write_attribute(:score, magnitude)
    elsif x == "down"
      write_attribute(:score, -magnitude)
    end
  end

  def initialize_user
    self.user_id ||= CurrentUser.user.id
  end

  # XXX should validate that non-supervotes can't supervote.
  def update_post_on_save
    if score > 0
      Post.where(:id => post_id).update_all("score = score + #{score}, up_score = up_score + #{score}")
    else
      Post.where(:id => post_id).update_all("score = score + #{score}, down_score = down_score + #{score}")
    end
  end

  def update_post_on_destroy
    if score > 0
      Post.where(:id => post_id).update_all("score = score - #{score}, up_score = up_score - #{score}")
    else
      Post.where(:id => post_id).update_all("score = score - #{score}, down_score = down_score - #{score}")
    end
  end

  def magnitude
    if CurrentUser.is_super_voter?
      SuperVoter::MAGNITUDE
    else
      1
    end
  end

  def validate_user_can_vote
    raise PostVote::Error.new("You do not have permission to vote") unless user.is_voter?
  end
end
