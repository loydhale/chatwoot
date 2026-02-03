import HudleyAssistantAPI from 'dashboard/api/captain/assistant';
import { createStore } from '../storeFactory';

export default createStore({
  name: 'HudleyAssistant',
  API: HudleyAssistantAPI,
});
