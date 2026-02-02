import axios from 'axios';

const { apiHost = '' } = window.deskflowsConfig || {};
const wootAPI = axios.create({ baseURL: `${apiHost}/` });

export default wootAPI;
