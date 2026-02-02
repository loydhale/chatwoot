# frozen_string_literal: true

# Super Admin controller for managing GHL marketplace tenants.
#
# Provides overview of all GHL-connected workspaces, their subscription
# status, usage metrics, and management actions.
#
# Accessible at: /super_admin/ghl_tenants
class SuperAdmin::GhlTenantsController < SuperAdmin::ApplicationController
  before_action :set_subscription, only: %i[show edit update upgrade suspend reactivate reset_usage]

  def index
    @subscriptions = GhlSubscription
                       .includes(:account)
                       .order(created_at: :desc)
                       .page(params[:page])

    # Filters
    @subscriptions = @subscriptions.where(plan: params[:plan]) if params[:plan].present?
    @subscriptions = @subscriptions.where(status: params[:status]) if params[:status].present?
    @subscriptions = @subscriptions.over_ai_limit if params[:over_limit] == 'true'

    @stats = compute_stats
  end

  def show
    @account = @subscription.account
    @hook = @account.hooks.find_by(app_id: 'gohighlevel')
    @usage_history = build_usage_history
  end

  def edit; end

  def update
    if @subscription.update(subscription_params)
      redirect_to super_admin_ghl_tenant_path(@subscription),
                  notice: 'Subscription updated successfully.'
    else
      render :edit
    end
  end

  # POST /super_admin/ghl_tenants/:id/upgrade
  def upgrade
    new_plan = params[:plan]
    unless GhlSubscription::PLANS.key?(new_plan)
      redirect_back fallback_location: super_admin_ghl_tenant_path(@subscription),
                    alert: "Unknown plan: #{new_plan}"
      return
    end

    @subscription.upgrade_to!(new_plan)
    redirect_to super_admin_ghl_tenant_path(@subscription),
                notice: "Upgraded to #{new_plan.titleize} plan."
  end

  # POST /super_admin/ghl_tenants/:id/suspend
  def suspend
    @subscription.suspend!
    redirect_to super_admin_ghl_tenant_path(@subscription),
                notice: 'Subscription suspended.'
  end

  # POST /super_admin/ghl_tenants/:id/reactivate
  def reactivate
    @subscription.activate!
    redirect_to super_admin_ghl_tenant_path(@subscription),
                notice: 'Subscription reactivated.'
  end

  # POST /super_admin/ghl_tenants/:id/reset_usage
  def reset_usage
    @subscription.reset_monthly_usage!
    redirect_to super_admin_ghl_tenant_path(@subscription),
                notice: 'AI usage reset for current period.'
  end

  private

  def set_subscription
    @subscription = GhlSubscription.includes(:account).find(params[:id])
  end

  def subscription_params
    params.require(:ghl_subscription).permit(
      :plan, :status, :locations_limit, :agents_limit,
      :ai_credits_limit, :trial_ends_at, :current_period_ends_at
    )
  end

  def compute_stats
    subs = GhlSubscription.all
    {
      total: subs.count,
      active: subs.where(status: %w[trialing active]).count,
      trialing: subs.where(status: 'trialing').count,
      cancelled: subs.where(status: 'cancelled').count,
      suspended: subs.where(status: 'suspended').count,
      by_plan: subs.group(:plan).count,
      over_ai_limit: subs.over_ai_limit.count,
      total_ai_credits_used: subs.sum(:ai_credits_used),
      mrr_estimate: estimate_mrr(subs)
    }
  end

  def estimate_mrr(subs)
    subs.where(status: %w[trialing active]).sum do |sub|
      GhlSubscription::PLANS.dig(sub.plan, :price_monthly) || 0
    end
  end

  def build_usage_history
    data = @subscription.usage_data['daily_ai'] || {}
    # Last 30 days
    (29.days.ago.to_date..Date.current).map do |date|
      { date: date.iso8601, credits: data[date.iso8601] || 0 }
    end
  end
end
