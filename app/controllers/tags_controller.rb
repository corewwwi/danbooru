class TagsController < ApplicationController
  before_filter :member_only, :only => [:edit, :update]
  respond_to :html, :xml, :json

  def edit
    @tag = Tag.find(params[:id])
    check_privilege(@tag)
    respond_with(@tag)
  end

  def index
    @tags = Tag.search(params[:search]).paginate(params[:page], :limit => params[:limit], :search_count => params[:search])
    respond_with(@tags) do |format|
      format.xml do
        render :xml => @tags.to_xml(:root => "tags")
      end
    end
  end

  def autocomplete
    @tags = Tag.names_matches_with_aliases(params[:search][:name_matches])

    respond_with(@tags) do |format|
      format.xml do
        render :xml => @tags.to_xml(:root => "tags")
      end
    end
  end

  def search
  end

  def show
    @tag = Tag.find(params[:id])
    respond_with(@tag)
  end

  def update
    @tag = Tag.find(params[:id])
    check_privilege(@tag)
    @tag.update(update_params)
    @tag.update_category_cache_for_all
    respond_with(@tag)
  end

private
  def check_privilege(tag)
    raise User::PrivilegeError unless tag.editable_by?(CurrentUser.user)
  end

  def update_params
    if CurrentUser.is_moderator?
      params.require(:tag).permit(:category, :is_locked)
    else
      params.require(:tag).permit(:category)
    end
  end
end
