/* global axios */

import ApiClient from '../ApiClient';

class GhlAPI extends ApiClient {
  constructor() {
    super('integrations/ghl', { accountScoped: true });
  }

  getStatus() {
    return axios.get(`${this.url}/status`);
  }

  initiateOAuth() {
    return axios.post(
      `${this.url.replace('integrations/ghl', 'ghl/authorization')}`
    );
  }

  refreshToken() {
    return axios.post(`${this.url}/refresh`);
  }

  disconnect() {
    return axios.delete(`${this.url}`);
  }

  getContacts(params) {
    return axios.get(`${this.url}/contacts`, { params });
  }

  getContact(contactId) {
    return axios.get(`${this.url}/contacts/${contactId}`);
  }
}

export default new GhlAPI();
