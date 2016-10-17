class NoteVersionsController < ApplicationController
  respond_to :html, :xml, :json

  def index
    @note_versions = NoteVersion.search(params[:search]).order("note_versions.id desc").paginate(params[:page], :limit => params[:limit])
    respond_with(@note_versions)
  end
end
