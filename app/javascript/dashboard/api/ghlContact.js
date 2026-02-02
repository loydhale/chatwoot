/* global axios */
import ApiClient from './ApiClient';

/**
 * GHL Contact API — fetches GoHighLevel contact data
 * through the DeskFlows backend proxy.
 * Proxy routes: /api/v1/accounts/:account_id/integrations/ghl/contacts
 */
class GHLContactAPI extends ApiClient {
  constructor() {
    super('integrations/ghl', { accountScoped: true });
  }

  /**
   * Search for a GHL contact by email or phone
   */
  async searchContact({ email, phone }) {
    try {
      const response = await axios.get(`${this.url}/contacts`, {
        params: { email, phone },
      });
      return response.data;
    } catch {
      return null;
    }
  }

  /**
   * Get full GHL contact details by contact ID
   */
  async getContact(contactId) {
    try {
      const response = await axios.get(`${this.url}/contacts/${contactId}`);
      return response.data;
    } catch {
      return null;
    }
  }

  /**
   * Get pipelines for the location (uses status endpoint data)
   */
  async getPipelines() {
    try {
      const response = await axios.get(`${this.url}/status`);
      return response.data?.pipelines || [];
    } catch {
      return [];
    }
  }
}

export default new GHLContactAPI();
