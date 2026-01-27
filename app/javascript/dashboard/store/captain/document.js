import AtlasDocumentAPI from 'dashboard/api/captain/document';
import { createStore } from '../storeFactory';

export default createStore({
  name: 'AtlasDocument',
  API: AtlasDocumentAPI,
});
