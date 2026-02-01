json.partial! 'api/v1/models/account', formats: [:json], resource: @account
json.latest_deskflows_version @latest_deskflows_version
json.partial! 'enterprise/api/v1/accounts/partials/account', account: @account if DeskFlowsApp.enterprise?
