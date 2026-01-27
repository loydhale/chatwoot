import { createStore } from '../storeFactory';
import AtlasToolsAPI from '../../api/captain/tools';
import { throwErrorMessage } from 'dashboard/store/utils/api';

const toolsStore = createStore({
  name: 'Tools',
  API: AtlasToolsAPI,
  actions: mutations => ({
    getTools: async ({ commit }) => {
      commit(mutations.SET_UI_FLAG, { fetchingList: true });
      try {
        const response = await AtlasToolsAPI.get();
        commit(mutations.SET, response.data);
        commit(mutations.SET_UI_FLAG, { fetchingList: false });
        return response.data;
      } catch (error) {
        commit(mutations.SET_UI_FLAG, { fetchingList: false });
        return throwErrorMessage(error);
      }
    },
  }),
});

export default toolsStore;
