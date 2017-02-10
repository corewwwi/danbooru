class BulkUpdateRequestsController < ApplicationController
  respond_to :html, :xml, :json, :js
  before_filter :member_only
  before_filter :admin_only, :only => [:approve]
  before_filter :load_bulk_update_request, :except => [:new, :create, :index]

  def new
    @bulk_update_request = BulkUpdateRequest.new(:user_id => CurrentUser.user.id)
    respond_with(@bulk_update_request)
  end

  def create
    @bulk_update_request = BulkUpdateRequest.create(permitted_params)
    respond_with(@bulk_update_request, :location => bulk_update_requests_path)
  end

  def show
  end

  def edit
  end

  def update
    @bulk_update_request.update(permitted_params)
    flash[:notice] = "Bulk update request updated"
    respond_with(@bulk_update_request, :location => bulk_update_requests_path)
  end

  def approve
    raise User::PrivilegeError unless CurrentUser.is_admin?
    @bulk_update_request.approve!(CurrentUser.user)
    respond_with(@bulk_update_request, :location => bulk_update_requests_path)
  end

  def destroy
    raise User::PrivilegeError unless @bulk_update_request.editable?(CurrentUser.user)
    @bulk_update_request.reject!
    flash[:notice] = "Bulk update request rejected"
    respond_with(@bulk_update_request, :location => bulk_update_requests_path)
  end

  def index
    @bulk_update_requests = BulkUpdateRequest.search(params[:search]).order("(case status when 'pending' then 0 when 'approved' then 1 else 2 end), id desc").paginate(params[:page], :limit => params[:limit])
    respond_with(@bulk_update_requests)
  end

  private

  def load_bulk_update_request
    @bulk_update_request = BulkUpdateRequest.find(params[:id])
  end

  def permitted_params
    attributes =  []
    attributes += [:forum_topic_id, :script, :title, :reason, :skip_secondary_validations] if @bulk_update_request.editable?(CurrentUser.user)
    attributes += [:status, :approver_id] if CurrentUser.is_admin?

    params.require(:bulk_update_request).permit(attributes)
  end
end
