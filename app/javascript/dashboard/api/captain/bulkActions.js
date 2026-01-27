import ApiClient from '../ApiClient';

class AtlasBulkActionsAPI extends ApiClient {
  constructor() {
    super('captain/bulk_actions', { accountScoped: true });
  }
}

export default new AtlasBulkActionsAPI();
