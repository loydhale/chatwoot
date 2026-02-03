# frozen_string_literal: true

class Api::V1::Accounts::Integrations::GhlController < Api::V1::Accounts::BaseController
  before_action :fetch_hook, except: [:status, :contacts, :show_contact]
  before_action :check_authorization, except: [:contacts, :show_contact]
  before_action :check_agent_authorization, only: [:contacts, :show_contact]

  # GET /api/v1/accounts/:account_id/integrations/ghl/status
  def status
    hook = Current.account.hooks.find_by(app_id: 'gohighlevel')

    if hook.present?
      render json: {
        connected: true,
        location_id: hook.settings['location_id'],
        company_id: hook.settings['company_id'],
        connected_at: hook.settings['connected_at'],
        expires_at: hook.settings['expires_at']
      }
    else
      render json: { connected: false }
    end
  end

  # POST /api/v1/accounts/:account_id/integrations/ghl/refresh
  def refresh
    refresh_token = @hook.refresh_token.presence || @hook.settings&.dig('refresh_token')
    return render_token_refresh_not_supported if refresh_token.blank?

    new_tokens = Ghl::TokenRefreshService.new(refresh_token).refresh!

    settings = @hook.settings || {}
    @hook.update!(
      access_token: new_tokens['access_token'],
      refresh_token: new_tokens['refresh_token'] || refresh_token,
      settings: settings.merge(
        expires_in: new_tokens['expires_in'],
        expires_at: (Time.current + new_tokens['expires_in'].to_i.seconds).iso8601
      )
    )

    render json: { success: true, message: 'Token refreshed successfully' }
  rescue StandardError => e
    Rails.logger.error("GHL token refresh error: #{e.message}")
    render json: { success: false, error: e.message }, status: :unprocessable_entity
  end

  # GET /api/v1/accounts/:account_id/integrations/ghl/contacts
  # Searches GHL contacts by email or phone for the sidebar display
  def contacts
    email = params[:email]
    phone = params[:phone]

    return render json: { error: 'email or phone required' }, status: :bad_request if email.blank? && phone.blank?

    hook = Current.account.hooks.find_by(app_id: 'gohighlevel')
    return render json: { error: 'GHL integration not connected' }, status: :unprocessable_entity if hook&.access_token.blank?

    location_id = hook.settings&.dig('location_id')
    return render json: { error: 'GHL location_id not configured for this account' }, status: :unprocessable_entity if location_id.blank?

    query = email.present? ? "email=#{CGI.escape(email)}" : "phone=#{CGI.escape(phone)}"

    response = ghl_api_request(
      hook.access_token,
      "/contacts/v1/contacts/search?locationId=#{location_id}&#{query}"
    )

    if response.success?
      contacts_data = JSON.parse(response.body)['contacts'] || []
      render json: contacts_data.first || {}
    else
      render json: { error: 'GHL API request failed' }, status: :bad_gateway
    end
  end

  # GET /api/v1/accounts/:account_id/integrations/ghl/contacts/:id
  def show_contact
    contact_id = params[:id]
    hook = Current.account.hooks.find_by(app_id: 'gohighlevel')

    return render json: { error: 'GHL integration not connected' }, status: :unprocessable_entity if hook&.access_token.blank?

    location_id = hook.settings&.dig('location_id')
    return render json: { error: 'GHL location_id not configured for this account' }, status: :unprocessable_entity if location_id.blank?

    response = ghl_api_request(
      hook.access_token,
      "/contacts/v1/contacts/#{contact_id}?locationId=#{location_id}"
    )

    if response.success?
      contact = JSON.parse(response.body)['contact'] || {}
      render json: contact
    else
      render json: { error: 'GHL contact not found' }, status: :not_found
    end
  end

  # DELETE /api/v1/accounts/:account_id/integrations/ghl
  def destroy
    @hook.destroy!
    head :ok
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def fetch_hook
    @hook = Current.account.hooks.find_by!(app_id: 'gohighlevel')
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'GHL integration not found' }, status: :not_found
  end

  def check_authorization
    raise Pundit::NotAuthorizedError unless Current.account_user.administrator?
  end

  def render_token_refresh_not_supported
    render json: { success: false, error: 'Refresh token not available' }, status: :unprocessable_entity
  end

  def check_agent_authorization
    raise Pundit::NotAuthorizedError unless Current.user
  end

  def ghl_api_request(token, path)
    conn = Faraday.new(url: 'https://services.leadconnectorhq.com') do |f|
      f.request :url_encoded
      f.adapter Faraday.default_adapter
    end

    conn.get(path) do |req|
      req.headers['Authorization'] = "Bearer #{token}"
      req.headers['Version'] = '2021-07-28'
    end
  end

end
