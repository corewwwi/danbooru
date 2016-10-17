class PostAppealsController < ApplicationController
  before_filter :member_only, :except => [:index, :show]
  respond_to :html, :xml, :json

  def new
    @post_appeal = PostAppeal.new
    respond_with(@post_appeal)
  end

  def index
    @query = PostAppeal.order("post_appeals.id desc").includes(:post).search(params[:search])
    @post_appeals = @query.paginate(params[:page], :limit => params[:limit])
    respond_with(@post_appeals)
  end

  def create
    @post_appeal = PostAppeal.create(params[:post_appeal])
    respond_with(@post_appeal) { |format| format.js }
  end

  def show
    @post_appeal = PostAppeal.find(params[:id])
    respond_with(@post_appeal)
  end
end
