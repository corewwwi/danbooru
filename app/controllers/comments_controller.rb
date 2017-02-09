class CommentsController < ApplicationController
  respond_to :html, :xml, :json
  before_filter :member_only, :except => [:index, :search, :show]
  before_filter :check_privilege, :only => [:update, :edit, :destroy, :undelete]
  rescue_from ActiveRecord::StatementInvalid, :with => :rescue_exception
  skip_before_filter :api_check

  def index
    if params[:group_by] == "comment"
      index_by_comment
    elsif request.format == Mime::JS
      index_for_post
    else
      index_by_post
    end
  end

  def search
  end

  def new
    redirect_to comments_path
  end

  def update
    comment.update(update_params)
    respond_with(comment, :location => post_path(comment.post_id))
  end

  def create
    @comment = Comment.create(create_params)
    respond_with(@comment) do |format|
      format.html do
        if @comment.errors.any?
          redirect_to post_path(@comment.post), :notice => @comment.errors.full_messages.join("; ")
        else
          redirect_to post_path(@comment.post), :notice => "Comment posted"
        end
      end
    end
  end

  def edit
    respond_with(comment)
  end

  def show
    respond_with(comment)
  end

  def destroy
    comment.delete!
    respond_with(comment) do |format|
      format.js
    end
  end

  def undelete
    comment.undelete!
    respond_with(comment) do |format|
      format.js
    end
  end

private
  def index_for_post
    @post = Post.find(params[:post_id])
    @comments = @post.comments
    @comments = @comments.visible(CurrentUser.user) unless params[:include_below_threshold]
    render :action => "index_for_post"
  end

  def index_by_post
    @posts = Post.where("last_comment_bumped_at IS NOT NULL").tag_match(params[:tags]).reorder("last_comment_bumped_at DESC").paginate(params[:page], :limit => 5, :search_count => params[:search])
    @posts.each # hack to force rails to eager load
    respond_with(@posts) do |format|
      format.html {render :action => "index_by_post"}
      format.xml do
        render :xml => @posts.to_xml(:root => "posts")
      end
    end
  end

  def index_by_comment
    @comments = Comment.search(params[:search]).paginate(params[:page], :limit => params[:limit], :search_count => params[:search])
    respond_with(@comments) do |format|
      format.html {render :action => "index_by_comment"}
      format.xml do
        render :xml => @comments.to_xml(:root => "comments")
      end
    end
  end

  def comment
    @comment ||= Comment.find(params[:id])
  end

  def check_privilege
    if !comment.editable_by?(CurrentUser.user)
      raise User::PrivilegeError
    end
  end

  def create_params
    params.require(:comment).permit(:post_id, :body, :do_not_bump_post, :is_sticky)
  end

  def update_params
    attributes = []
    attributes += [:body, :is_deleted] if comment.editable_by?(CurrentUser.user)
    attributes += [:is_sticky] if CurrentUser.is_moderator?

    params.require(:comment).permit(attributes)
  end
end
