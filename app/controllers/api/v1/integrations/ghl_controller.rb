# frozen_string_literal: true

class Api::V1::Integrations::GhlController < Api::BaseController
  before_action :check_authorization

  GHL_BASE_URL = 'https://services.leadconnectorhq.com'

  def contacts
    email = params[:email]
    phone = params[:phone]

    return render json: { error: 'email or phone required' }, status: :bad_request if email.blank? && phone.blank?

    query = email.present? ? "email=#{email}" : "phone=#{phone}"
    response = ghl_request("/contacts/?locationId=#{ghl_location_id}&#{query}")

    if response.success?
      contacts = JSON.parse(response.body).dig('contacts') || []
      render json: contacts.first || {}
    else
      render json: { error: 'GHL API error' }, status: :bad_gateway
    end
  end

  def show_contact
    contact_id = params[:id]
    response = ghl_request("/contacts/#{contact_id}?locationId=#{ghl_location_id}")

    if response.success?
      contact = JSON.parse(response.body).dig('contact') || {}
      render json: contact
    else
      render json: { error: 'GHL contact not found' }, status: :not_found
    end
  end

  private

  def ghl_request(path)
    conn = Faraday.new(url: GHL_BASE_URL) do |f|
      f.request :url_encoded
      f.adapter Faraday.default_adapter
    end

    conn.get(path) do |req|
      req.headers['Authorization'] = "Bearer #{ghl_pit_token}"
      req.headers['Version'] = '2021-07-28'
    end
  end

  def ghl_pit_token
    ENV.fetch('GHL_PIT_TOKEN', 'pit-75cb14b9-1b1f-47f8-b344-2e906c6ef853')
  end

  def ghl_location_id
    ENV.fetch('GHL_LOCATION_ID', 'GYkUAluHxTzXjFjq9Pxx')
  end

  def check_authorization
    # Allow any authenticated user to access GHL data
    raise Pundit::NotAuthorizedError unless Current.user
  end
end
