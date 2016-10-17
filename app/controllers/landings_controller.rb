class LandingsController < ApplicationController
  # XXX
  def show
    @explorer = PopularPostExplorer.new
    render :layout => "blank"
  end
end
