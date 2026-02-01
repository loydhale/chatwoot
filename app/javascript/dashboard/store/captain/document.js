import HudleyDocumentAPI from 'dashboard/api/captain/document';
import { createStore } from '../storeFactory';

export default createStore({
  name: 'HudleyDocument',
  API: HudleyDocumentAPI,
});
