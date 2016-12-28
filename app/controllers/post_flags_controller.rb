class PostFlagsController < ApplicationController
  before_filter :member_only, :except => [:index, :show]
  respond_to :html, :xml, :json, :js

  def index
    @query = PostFlag.order("id desc").search(params[:search])
    @post_flags = @query.paginate(params[:page], :limit => params[:limit])
    respond_with(@post_flags) do |format|
      format.xml do
        render :xml => @post_flags.to_xml(:root => "post-flags")
      end
    end
  end

  def create
    @post_flag = PostFlag.create(params[:post_flag].merge(:is_resolved => false))
    respond_with(@post_flag)
  end

  def show
    @post_flag = PostFlag.find(params[:id])
    respond_with(@post_flag)
  end
end
