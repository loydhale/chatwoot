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
    settings = @hook.settings || {}
    refresh_token = settings['refresh_token']
    return render_token_refresh_not_supported unless refresh_token.present?

    new_tokens = Ghl::TokenRefreshService.new(refresh_token).refresh!

    @hook.update!(
      access_token: new_tokens['access_token'],
      settings: settings.merge(
        refresh_token: new_tokens['refresh_token'] || refresh_token,
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
    unless hook&.access_token.present?
      # Fallback to PIT token
      return render json: ghl_pit_search(email, phone)
    end

    location_id = hook.settings&.dig('location_id') || ENV.fetch('GHL_LOCATION_ID', 'GYkUAluHxTzXjFjq9Pxx')
    query = email.present? ? "email=#{CGI.escape(email)}" : "phone=#{CGI.escape(phone)}"

    response = ghl_api_request(
      hook.access_token,
      "/contacts/v1/contacts/search?locationId=#{location_id}&#{query}"
    )

    if response.success?
      contacts_data = JSON.parse(response.body).dig('contacts') || []
      render json: contacts_data.first || {}
    else
      render json: ghl_pit_search(email, phone)
    end
  end

  # GET /api/v1/accounts/:account_id/integrations/ghl/contacts/:id
  def show_contact
    contact_id = params[:id]
    hook = Current.account.hooks.find_by(app_id: 'gohighlevel')

    unless hook&.access_token.present?
      return render json: ghl_pit_get_contact(contact_id)
    end

    location_id = hook.settings&.dig('location_id') || ENV.fetch('GHL_LOCATION_ID', 'GYkUAluHxTzXjFjq9Pxx')

    response = ghl_api_request(
      hook.access_token,
      "/contacts/v1/contacts/#{contact_id}?locationId=#{location_id}"
    )

    if response.success?
      contact = JSON.parse(response.body).dig('contact') || {}
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

  def ghl_pit_search(email, phone)
    pit_token = ENV.fetch('GHL_PIT_TOKEN', 'pit-75cb14b9-1b1f-47f8-b344-2e906c6ef853')
    location_id = ENV.fetch('GHL_LOCATION_ID', 'GYkUAluHxTzXjFjq9Pxx')
    query = email.present? ? "email=#{CGI.escape(email)}" : "phone=#{CGI.escape(phone)}"

    response = ghl_api_request(pit_token, "/contacts/?locationId=#{location_id}&#{query}")
    if response.success?
      contacts = JSON.parse(response.body).dig('contacts') || []
      contacts.first || {}
    else
      {}
    end
  end

  def ghl_pit_get_contact(contact_id)
    pit_token = ENV.fetch('GHL_PIT_TOKEN', 'pit-75cb14b9-1b1f-47f8-b344-2e906c6ef853')
    location_id = ENV.fetch('GHL_LOCATION_ID', 'GYkUAluHxTzXjFjq9Pxx')

    response = ghl_api_request(pit_token, "/contacts/#{contact_id}?locationId=#{location_id}")
    if response.success?
      JSON.parse(response.body).dig('contact') || {}
    else
      {}
    end
  end
end
