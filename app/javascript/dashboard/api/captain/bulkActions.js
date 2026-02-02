import ApiClient from '../ApiClient';

class HudleyBulkActionsAPI extends ApiClient {
  constructor() {
    super('captain/bulk_actions', { accountScoped: true });
  }
}

export default new HudleyBulkActionsAPI();
