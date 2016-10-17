class ArtistCommentariesController < ApplicationController
  respond_to :html, :xml, :json
  before_filter :member_only, :except => [:index]

  def index
    @commentaries = ArtistCommentary.search(params[:search]).order("artist_commentaries.id desc").paginate(params[:page], :limit => params[:limit])
    respond_with(@commentaries)
  end

  # XXX should be POST /artist_commentaries.json (create) and PUT /artist_commentaries/1.json (update)
  def create_or_update
    @artist_commentary = ArtistCommentary.find_by_post_id(params[:artist_commentary][:post_id])

    if @artist_commentary
      @artist_commentary.update_attributes(params[:artist_commentary])
    else
      @artist_commentary = ArtistCommentary.create(params[:artist_commentary])
    end

    respond_with(@artist_commentary) { |format| format.js }
  end

  def revert
    @artist_commentary = ArtistCommentary.find_by_post_id!(params[:id])
    @version = @artist_commentary.versions.find(params[:version_id])
    @artist_commentary.revert_to!(@version)
    respond_with(@artist_commentary) { |format| format.js }
  end
end
