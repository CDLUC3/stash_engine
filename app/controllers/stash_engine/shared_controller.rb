module StashEngine
  module SharedController
    #helper_method :current_tenant, :current_user, :metadata_engine, :metadata_url_helpers

    def metadata_url_helpers
      metadata_engine::Engine.routes.url_helpers
    end

    # get the current tenant for customizations, also deals with login
    def current_tenant
      if current_user
        StashEngine::Tenant.find(current_user.tenant_id)
      elsif session[:test_domain]
        StashEngine::Tenant.by_domain(session[:test_domain])
      else
        StashEngine::Tenant.by_domain(request.host)
      end
    end

    def current_user
      @current_user ||= User.find_by_id(session[:user_id]) if session[:user_id]
    end

    def metadata_engine
      StashEngine.app.metadata_engine.constantize
    end

    def clear_user
      @current_user = nil
    end

    def require_login
      return if current_user
      flash[:alert] = 'You must be logged in'
      redirect_to tenants_path
    end

    def require_resource_owner
      if current_user.id != @resource.user_id
        flash[:alert] = 'You do not have permission to view this resource'
        redirect_to tenants_path
      end
    end

    def stash_url_helpers
      StashEngine::Engine.routes.url_helpers
    end

    def ajax_require_current_user
      return false unless @current_user
    end

    # this sets up the page variables for use with kaminari paging
    def set_page_info
      @page = params[:page] || '1'
      @page_size = params[:page_size] || '5'
    end
  end
end