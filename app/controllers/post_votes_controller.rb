class PostVotesController < ApplicationController
  before_filter :voter_only

  # XXX
  def create
    @post = Post.find(params[:post_id])
    @post.vote!(params[:score])
  rescue PostVote::Error => x
    @error = x
  end

  # XXX
  def destroy
    @post = Post.find(params[:post_id])
    @post.unvote!
  rescue PostVote::Error => x
    @error = x
  end
end
