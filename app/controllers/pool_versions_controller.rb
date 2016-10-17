class PoolVersionsController < ApplicationController
  respond_to :html, :xml, :json

  def index
    @pool = Pool.find(params.dig(:search, :pool_id)

    @pool_versions = PoolVersion.search(params[:search]).order("updated_at desc").paginate(params[:page], :limit => params[:limit], :search_count => params[:search])
    respond_with(@pool_versions)
  end
end
