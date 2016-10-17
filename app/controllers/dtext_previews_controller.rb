class DtextPreviewsController < ApplicationController
  # XXX
  def create
    render :inline => "<%= format_text(params[:body], :ragel => true) %>"
  end
end
