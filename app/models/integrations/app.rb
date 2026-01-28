class Integrations::App
  include Linear::IntegrationHelper
  attr_accessor :params

  def initialize(params)
    @params = params
  end

  def id
    params[:id]
  end

  def name
    I18n.t("integration_apps.#{params[:i18n_key]}.name")
  end

  def description
    I18n.t("integration_apps.#{params[:i18n_key]}.description")
  end

  def short_description
    I18n.t("integration_apps.#{params[:i18n_key]}.short_description")
  end

  def logo
    params[:logo]
  end

  def fields
    params[:fields]
  end

  # There is no way to get the account_id from the linear callback
  # so we are using the generate_linear_token method to generate a token and encode it in the state parameter
  def encode_state
    generate_linear_token(Current.account.id)
  end

  def action
    case params[:id]
    when 'slack'
      client_id = GlobalConfigService.load('SLACK_CLIENT_ID', nil)
      "#{params[:action]}&client_id=#{client_id}&redirect_uri=#{self.class.slack_integration_url}"
    when 'linear'
      build_linear_action
    when 'gohighlevel'
      build_ghl_action
    else
      params[:action]
    end
  end

  def active?(account)
    case params[:id]
    when 'slack'
      GlobalConfigService.load('SLACK_CLIENT_SECRET', nil).present?
    when 'linear'
      account.feature_enabled?('linear_integration') && GlobalConfigService.load('LINEAR_CLIENT_ID', nil).present?
    when 'shopify'
      shopify_enabled?(account)
    when 'leadsquared'
      account.feature_enabled?('crm_integration')
    when 'notion'
      notion_enabled?(account)
    when 'gohighlevel'
      ghl_enabled?
    else
      true
    end
  end

  def build_linear_action
    app_id = GlobalConfigService.load('LINEAR_CLIENT_ID', nil)
    [
      "#{params[:action]}?response_type=code",
      "client_id=#{app_id}",
      "redirect_uri=#{self.class.linear_integration_url}",
      "state=#{encode_state}",
      'scope=read,write',
      'prompt=consent',
      'actor=app'
    ].join('&')
  end

  def build_ghl_action
    app_id = GlobalConfigService.load('GHL_CLIENT_ID', nil)
    scopes = ghl_default_scopes.join(' ')
    [
      "#{params[:action]}?response_type=code",
      "client_id=#{app_id}",
      "redirect_uri=#{self.class.ghl_integration_url}",
      "state=#{encode_ghl_state}",
      "scope=#{URI.encode_www_form_component(scopes)}"
    ].join('&')
  end

  def encode_ghl_state
    # Use a secure token that can be verified on callback
    Current.account.to_sgid(expires_in: 15.minutes).to_s
  end

  def ghl_default_scopes
    %w[
      contacts.readonly
      contacts.write
      conversations.readonly
      conversations.write
      conversations/message.readonly
      conversations/message.write
      locations.readonly
      users.readonly
    ]
  end

  def enabled?(account)
    case params[:id]
    when 'webhook'
      account.webhooks.exists?
    when 'dashboard_apps'
      account.dashboard_apps.exists?
    else
      account.hooks.exists?(app_id: id)
    end
  end

  def hooks
    Current.account.hooks.where(app_id: id)
  end

  def self.slack_integration_url
    "#{ENV.fetch('FRONTEND_URL', nil)}/app/accounts/#{Current.account.id}/settings/integrations/slack"
  end

  def self.linear_integration_url
    "#{ENV.fetch('FRONTEND_URL', nil)}/linear/callback"
  end

  def self.ghl_integration_url
    "#{ENV.fetch('FRONTEND_URL', nil)}/ghl/callback"
  end

  class << self
    def apps
      Hashie::Mash.new(APPS_CONFIG)
    end

    def all
      apps.values.each_with_object([]) do |app, result|
        result << new(app)
      end
    end

    def find(params)
      all.detect { |app| app.id == params[:id] }
    end
  end

  private

  def shopify_enabled?(account)
    account.feature_enabled?('shopify_integration') && GlobalConfigService.load('SHOPIFY_CLIENT_ID', nil).present?
  end

  def notion_enabled?(account)
    account.feature_enabled?('notion_integration') && GlobalConfigService.load('NOTION_CLIENT_ID', nil).present?
  end

  def ghl_enabled?
    GlobalConfigService.load('GHL_CLIENT_ID', nil).present? && GlobalConfigService.load('GHL_CLIENT_SECRET', nil).present?
  end
end
