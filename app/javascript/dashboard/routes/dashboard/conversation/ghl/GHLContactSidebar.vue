<script setup>
import { computed, watch, onMounted, ref } from 'vue';
import { useStore } from 'dashboard/composables/store';
import { useMapGetter } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';

const { t } = useI18n();
const store = useStore();

const currentChat = useMapGetter('getSelectedChat');

const contactGetter = useMapGetter('contacts/getContact');
const contactId = computed(() => currentChat.value?.meta?.sender?.id);
const contact = computed(() => contactGetter.value(contactId.value));

const ghlContact = computed(() => store.getters['ghlContact/getGHLContact']);
const ghlTags = computed(() => store.getters['ghlContact/getGHLTags']);
const ghlCustomFields = computed(
  () => store.getters['ghlContact/getGHLCustomFields']
);
const ghlPipelineStage = computed(
  () => store.getters['ghlContact/getGHLPipelineStage']
);
const ghlUIFlags = computed(() => store.getters['ghlContact/getGHLUIFlags']);

const isExpanded = ref(true);

const displayFields = computed(() => {
  if (!ghlCustomFields.value?.length) return [];
  return ghlCustomFields.value
    .filter(f => f.value && f.value !== '')
    .slice(0, 10);
});

const fetchGHLData = () => {
  if (!contact.value) return;
  const email = contact.value.email;
  const phone = contact.value.phone_number;
  if (email || phone) {
    store.dispatch('ghlContact/fetchGHLContact', { email, phone });
  }
};

watch(contactId, (newId, oldId) => {
  if (newId && newId !== oldId) {
    fetchGHLData();
  }
});

onMounted(() => {
  fetchGHLData();
});

const toggleExpanded = () => {
  isExpanded.value = !isExpanded.value;
};

const getPipelineStatusColor = status => {
  const colors = {
    open: 'bg-g-100 text-g-800 dark:bg-g-900 dark:text-g-200',
    won: 'bg-b-100 text-b-800 dark:bg-b-900 dark:text-b-200',
    lost: 'bg-r-100 text-r-800 dark:bg-r-900 dark:text-r-200',
    abandoned: 'bg-n-100 text-n-600 dark:bg-n-800 dark:text-n-300',
  };
  return colors[status] || 'bg-n-100 text-n-600 dark:bg-n-800 dark:text-n-300';
};

const formattedMonetary = computed(() => {
  if (!ghlPipelineStage.value?.monetaryValue) return '';
  return `$${Number(ghlPipelineStage.value.monetaryValue).toLocaleString()}`;
});

const formattedDateAdded = computed(() => {
  if (!ghlContact.value?.dateAdded) return '';
  return new Date(ghlContact.value.dateAdded).toLocaleDateString();
});
</script>

<template>
  <div class="ghl-contact-sidebar">
    <button
      class="flex items-center justify-between w-full px-3 py-2 text-sm font-medium text-left rounded-lg text-n-slate-12 hover:bg-n-alpha-2"
      @click="toggleExpanded"
    >
      <span class="flex items-center gap-2">
        <svg
          xmlns="http://www.w3.org/2000/svg"
          class="w-4 h-4 text-p-600"
          fill="none"
          viewBox="0 0 24 24"
          stroke="currentColor"
          stroke-width="2"
        >
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            d="M13 10V3L4 14h7v7l9-11h-7z"
          />
        </svg>
        {{ t('GHL_SIDEBAR.TITLE') }}
      </span>
      <svg
        xmlns="http://www.w3.org/2000/svg"
        class="w-4 h-4 transition-transform"
        :class="{ 'rotate-180': isExpanded }"
        fill="none"
        viewBox="0 0 24 24"
        stroke="currentColor"
        stroke-width="2"
      >
        <path
          stroke-linecap="round"
          stroke-linejoin="round"
          d="M19 9l-7 7-7-7"
        />
      </svg>
    </button>

    <div v-if="isExpanded" class="px-3 pb-3">
      <!-- Loading State -->
      <div
        v-if="ghlUIFlags.isFetching"
        class="flex items-center justify-center py-4"
      >
        <div
          class="w-5 h-5 border-2 rounded-full animate-spin border-p-500 border-t-transparent"
        />
        <span class="ml-2 text-xs text-n-500">
          {{ t('GHL_SIDEBAR.LOADING') }}
        </span>
      </div>

      <!-- No Contact Found -->
      <div
        v-else-if="!ghlContact"
        class="py-3 text-xs text-center rounded-lg text-n-400 bg-n-alpha-1"
      >
        <svg
          xmlns="http://www.w3.org/2000/svg"
          class="w-6 h-6 mx-auto mb-1 text-n-300"
          fill="none"
          viewBox="0 0 24 24"
          stroke="currentColor"
          stroke-width="1.5"
        >
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"
          />
        </svg>
        {{ t('GHL_SIDEBAR.NO_CONTACT') }}
      </div>

      <!-- Contact Data -->
      <div v-else class="space-y-3">
        <!-- Pipeline Stage -->
        <div v-if="ghlPipelineStage" class="p-2.5 rounded-lg bg-n-alpha-1">
          <div
            class="mb-1.5 text-xs font-semibold text-n-500 uppercase tracking-wider"
          >
            {{ t('GHL_SIDEBAR.PIPELINE') }}
          </div>
          <div class="flex items-center gap-2">
            <span
              class="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium"
              :class="getPipelineStatusColor(ghlPipelineStage.status)"
            >
              {{ ghlPipelineStage.stageName }}
            </span>
          </div>
          <div class="mt-1 text-xs text-n-400">
            {{ ghlPipelineStage.pipelineName }}
          </div>
          <div
            v-if="formattedMonetary"
            class="mt-1 text-xs font-medium text-g-600"
          >
            {{ formattedMonetary }}
          </div>
        </div>

        <!-- Tags -->
        <div v-if="ghlTags.length" class="p-2.5 rounded-lg bg-n-alpha-1">
          <div
            class="mb-1.5 text-xs font-semibold text-n-500 uppercase tracking-wider"
          >
            {{ t('GHL_SIDEBAR.GHL_TAGS') }}
          </div>
          <div class="flex flex-wrap gap-1">
            <span
              v-for="tag in ghlTags"
              :key="tag"
              class="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-p-100 text-p-700 dark:bg-p-900 dark:text-p-200"
            >
              {{ tag }}
            </span>
          </div>
        </div>

        <!-- Custom Fields -->
        <div v-if="displayFields.length" class="p-2.5 rounded-lg bg-n-alpha-1">
          <div
            class="mb-1.5 text-xs font-semibold text-n-500 uppercase tracking-wider"
          >
            {{ t('GHL_SIDEBAR.CUSTOM_FIELDS') }}
          </div>
          <div class="space-y-1.5">
            <div
              v-for="field in displayFields"
              :key="field.id || field.key"
              class="flex items-start justify-between text-xs"
            >
              <span
                class="font-medium truncate text-n-600 dark:text-n-300 max-w-[45%]"
              >
                {{ field.key || field.name || field.id }}
              </span>
              <span class="text-right truncate text-n-500 max-w-[50%]">
                {{ field.value }}
              </span>
            </div>
          </div>
        </div>

        <!-- Quick Info -->
        <div
          v-if="ghlContact.source || ghlContact.dateAdded"
          class="p-2.5 rounded-lg bg-n-alpha-1"
        >
          <div
            class="mb-1.5 text-xs font-semibold text-n-500 uppercase tracking-wider"
          >
            {{ t('GHL_SIDEBAR.GHL_INFO') }}
          </div>
          <div class="space-y-1">
            <div v-if="ghlContact.source" class="flex justify-between text-xs">
              <span class="text-n-500">{{ t('GHL_SIDEBAR.SOURCE') }}</span>
              <span class="font-medium text-n-700 dark:text-n-300">
                {{ ghlContact.source }}
              </span>
            </div>
            <div v-if="formattedDateAdded" class="flex justify-between text-xs">
              <span class="text-n-500">{{ t('GHL_SIDEBAR.ADDED') }}</span>
              <span class="font-medium text-n-700 dark:text-n-300">
                {{ formattedDateAdded }}
              </span>
            </div>
            <div v-if="ghlContact.dnd" class="flex justify-between text-xs">
              <span class="text-n-500">{{ t('GHL_SIDEBAR.DND') }}</span>
              <span class="font-medium text-r-600">
                {{ t('GHL_SIDEBAR.DND_ACTIVE') }}
              </span>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.ghl-contact-sidebar {
  border-top: 1px solid var(--color-border-light, #e5e7eb);
}
</style>
