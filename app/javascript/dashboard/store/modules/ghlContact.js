import GHLContactAPI from '../../api/ghlContact';

const state = {
  contact: null,
  pipelines: [],
  uiFlags: {
    isFetching: false,
    isError: false,
  },
};

const getters = {
  getGHLContact: $state => $state.contact,
  getGHLPipelines: $state => $state.pipelines,
  getGHLUIFlags: $state => $state.uiFlags,
  getGHLTags: $state => $state.contact?.tags || [],
  getGHLCustomFields: $state => $state.contact?.customFields || [],
  getGHLPipelineStage: $state => {
    if (!$state.contact?.opportunities?.length || !$state.pipelines.length)
      return null;

    const opp = $state.contact.opportunities[0];
    const pipeline = $state.pipelines.find(p => p.id === opp.pipelineId);
    if (!pipeline) return { pipelineName: 'Unknown', stageName: opp.status };

    const stage = pipeline.stages?.find(s => s.id === opp.pipelineStageId);
    return {
      pipelineName: pipeline.name,
      stageName: stage?.name || opp.status,
      monetaryValue: opp.monetaryValue,
      status: opp.status,
    };
  },
};

const actions = {
  fetchGHLContact: async ({ commit }, { email, phone }) => {
    commit('SET_GHL_UI_FLAG', { isFetching: true, isError: false });
    try {
      const contact = await GHLContactAPI.searchContact({ email, phone });
      commit('SET_GHL_CONTACT', contact);

      // Also fetch pipelines for stage context
      const pipelines = await GHLContactAPI.getPipelines();
      commit('SET_GHL_PIPELINES', pipelines);

      commit('SET_GHL_UI_FLAG', { isFetching: false });
    } catch {
      commit('SET_GHL_UI_FLAG', { isFetching: false, isError: true });
    }
  },

  clearGHLContact: ({ commit }) => {
    commit('SET_GHL_CONTACT', null);
  },
};

const mutations = {
  SET_GHL_UI_FLAG($state, data) {
    $state.uiFlags = { ...$state.uiFlags, ...data };
  },
  SET_GHL_CONTACT($state, contact) {
    $state.contact = contact;
  },
  SET_GHL_PIPELINES($state, pipelines) {
    $state.pipelines = pipelines;
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
