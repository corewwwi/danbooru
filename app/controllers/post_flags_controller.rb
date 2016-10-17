class PostFlagsController < ApplicationController
  before_filter :member_only, :except => [:index, :show]
  respond_to :html, :xml, :json

  def new
    @post_flag = PostFlag.new
    respond_with(@post_flag)
  end

  def index
    @query = PostFlag.order("id desc").search(params[:search])
    @post_flags = @query.paginate(params[:page], :limit => params[:limit])
    respond_with(@post_flags)
  end

  def create
    # XXX exploit: set is_deletion=true to flag multiple times.
    @post_flag = PostFlag.create(params[:post_flag].merge(:is_resolved => false))
    respond_with(@post_flag) { |format| format.js }
  end

  def show
    @post_flag = PostFlag.find(params[:id])
    respond_with(@post_flag)
  end

private
  def check_privilege(post_flag)
    raise User::PrivilegeError unless (post_flag.creator_id == CurrentUser.id || CurrentUser.is_moderator?)
  end
end
