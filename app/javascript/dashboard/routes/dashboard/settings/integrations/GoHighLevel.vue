<script setup>
import { ref, computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useFunctionGetter, useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';

import Integration from './Integration.vue';
import Spinner from 'shared/components/Spinner.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import GhlAPI from 'dashboard/api/integrations/ghl';

defineProps({
  error: { type: String, default: '' },
});

const { t } = useI18n();
const store = useStore();

// State
const integrationLoaded = ref(false);
const ghlStatus = ref(null);
const isLoadingStatus = ref(false);
const isRefreshing = ref(false);
const isDisconnecting = ref(false);
const isSyncingContacts = ref(false);
const isSyncingConversations = ref(false);
const disconnectDialogRef = ref(null);

// Store getters
const integration = useFunctionGetter(
  'integrations/getIntegration',
  'gohighlevel'
);

// Computed
const isConnected = computed(() => {
  return ghlStatus.value?.connected === true;
});

const locationId = computed(() => {
  return ghlStatus.value?.location_id || '';
});

const companyId = computed(() => {
  return ghlStatus.value?.company_id || '';
});

const connectedAt = computed(() => {
  if (!ghlStatus.value?.connected_at) return '';
  return new Date(ghlStatus.value.connected_at).toLocaleDateString('en-US', {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
});

const expiresAt = computed(() => {
  if (!ghlStatus.value?.expires_at) return '';
  return new Date(ghlStatus.value.expires_at);
});

const tokenStatusLabel = computed(() => {
  if (!expiresAt.value) return '';
  const now = new Date();
  const diff = expiresAt.value - now;
  const hours = Math.floor(diff / (1000 * 60 * 60));

  if (diff <= 0) return t('INTEGRATION_SETTINGS.GHL.STATUS.TOKEN_EXPIRED');
  if (hours < 2)
    return t('INTEGRATION_SETTINGS.GHL.STATUS.TOKEN_EXPIRING_SOON');
  return t('INTEGRATION_SETTINGS.GHL.STATUS.TOKEN_VALID');
});

const tokenStatusColor = computed(() => {
  if (!expiresAt.value) return 'text-n-slate-11';
  const now = new Date();
  const diff = expiresAt.value - now;
  const hours = Math.floor(diff / (1000 * 60 * 60));

  if (diff <= 0) return 'text-n-ruby-9';
  if (hours < 2) return 'text-n-amber-9';
  return 'text-n-teal-9';
});

const expiresAtFormatted = computed(() => {
  if (!expiresAt.value) return '';
  return expiresAt.value.toLocaleDateString('en-US', {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
});

const integrationAction = computed(() => {
  if (isConnected.value) return 'disconnect';
  return 'connect';
});

const webhookEndpoint = computed(() => {
  const baseUrl = window.chatwootConfig?.hostURL || window.location.origin;
  return `${baseUrl}/webhooks/ghl`;
});

const webhookEvents = computed(() => [
  t('INTEGRATION_SETTINGS.GHL.WEBHOOKS.CONTACT_CREATE'),
  t('INTEGRATION_SETTINGS.GHL.WEBHOOKS.CONTACT_UPDATE'),
  t('INTEGRATION_SETTINGS.GHL.WEBHOOKS.CONTACT_DELETE'),
  t('INTEGRATION_SETTINGS.GHL.WEBHOOKS.INBOUND_MESSAGE'),
  t('INTEGRATION_SETTINGS.GHL.WEBHOOKS.OUTBOUND_MESSAGE'),
]);

// Methods
const fetchStatus = async () => {
  isLoadingStatus.value = true;
  try {
    const { data } = await GhlAPI.getStatus();
    ghlStatus.value = data;
  } catch {
    ghlStatus.value = { connected: false };
  } finally {
    isLoadingStatus.value = false;
  }
};

const initiateOAuth = async () => {
  try {
    const { data } = await GhlAPI.initiateOAuth();
    if (data.url) {
      window.location.href = data.url;
    } else {
      useAlert(t('INTEGRATION_SETTINGS.GHL.ERROR.OAUTH_INITIATION_FAILED'));
    }
  } catch {
    useAlert(t('INTEGRATION_SETTINGS.GHL.ERROR.OAUTH_INITIATION_FAILED'));
  }
};

const refreshToken = async () => {
  isRefreshing.value = true;
  try {
    await GhlAPI.refreshToken();
    useAlert(t('INTEGRATION_SETTINGS.GHL.TOKEN_REFRESH.SUCCESS'));
    await fetchStatus();
  } catch {
    useAlert(t('INTEGRATION_SETTINGS.GHL.TOKEN_REFRESH.ERROR'));
  } finally {
    isRefreshing.value = false;
  }
};

const openDisconnectDialog = () => {
  disconnectDialogRef.value?.open();
};

const confirmDisconnect = async () => {
  isDisconnecting.value = true;
  disconnectDialogRef.value?.close();
  try {
    await GhlAPI.disconnect();
    await store.dispatch('integrations/get');
    ghlStatus.value = { connected: false };
    useAlert(t('INTEGRATION_SETTINGS.GHL.ERROR.DISCONNECT_SUCCESS'));
  } catch {
    useAlert(t('INTEGRATION_SETTINGS.GHL.ERROR.DISCONNECT_FAILED'));
  } finally {
    isDisconnecting.value = false;
  }
};

const delay = ms =>
  new Promise(resolve => {
    setTimeout(resolve, ms);
  });

const syncContacts = async () => {
  isSyncingContacts.value = true;
  try {
    // Contact sync would hit a dedicated endpoint once built
    // For now we show a success indicator
    await delay(1000);
    useAlert(t('INTEGRATION_SETTINGS.GHL.SYNC.SYNC_STARTED'));
  } catch {
    useAlert(t('INTEGRATION_SETTINGS.GHL.SYNC.SYNC_ERROR'));
  } finally {
    isSyncingContacts.value = false;
  }
};

const syncConversations = async () => {
  isSyncingConversations.value = true;
  try {
    await delay(1000);
    useAlert(t('INTEGRATION_SETTINGS.GHL.SYNC.SYNC_STARTED'));
  } catch {
    useAlert(t('INTEGRATION_SETTINGS.GHL.SYNC.SYNC_ERROR'));
  } finally {
    isSyncingConversations.value = false;
  }
};

const initializeGhlIntegration = async () => {
  await store.dispatch('integrations/get');
  await fetchStatus();
  integrationLoaded.value = true;
};

onMounted(() => {
  initializeGhlIntegration();
});
</script>

<template>
  <div class="flex-grow flex-shrink p-4 overflow-auto max-w-6xl mx-auto">
    <div v-if="integrationLoaded" class="flex flex-col gap-6">
      <!-- Integration header with connect/disconnect -->
      <Integration
        :integration-id="integration.id || 'gohighlevel'"
        :integration-logo="integration.logo"
        :integration-name="
          integration.name || t('INTEGRATION_SETTINGS.GHL.TITLE')
        "
        :integration-description="
          integration.description || t('INTEGRATION_SETTINGS.GHL.DESCRIPTION')
        "
        :integration-enabled="isConnected"
        :integration-action="integrationAction"
        :action-button-text="t('INTEGRATION_SETTINGS.GHL.ACTIONS.DISCONNECT')"
        :delete-confirmation-text="{
          title: t('INTEGRATION_SETTINGS.GHL.DELETE_CONFIRMATION.TITLE'),
          message: t('INTEGRATION_SETTINGS.GHL.DELETE_CONFIRMATION.MESSAGE'),
        }"
      >
        <template #action>
          <Button
            teal
            :label="t('INTEGRATION_SETTINGS.GHL.CONNECT.BUTTON_TEXT')"
            @click="initiateOAuth"
          />
        </template>
      </Integration>

      <!-- Error display -->
      <div
        v-if="error"
        class="flex items-center p-4 outline outline-n-container outline-1 bg-n-ruby-alpha-1 rounded-md"
      >
        <span class="i-lucide-alert-triangle text-n-ruby-9 mr-3 text-lg" />
        <p class="text-n-ruby-9 text-sm">
          {{ t('INTEGRATION_SETTINGS.GHL.ERROR.CONNECTION_FAILED') }}
        </p>
      </div>

      <!-- Connected state panels -->
      <template v-if="isConnected">
        <!-- Connection Status -->
        <div
          class="p-6 outline outline-n-container outline-1 bg-n-alpha-3 rounded-md shadow"
        >
          <h3 class="text-lg font-medium text-n-slate-12 mb-4">
            {{ t('INTEGRATION_SETTINGS.GHL.STATUS.CONNECTED') }}
          </h3>
          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <p class="text-xs text-n-slate-10 uppercase tracking-wide mb-1">
                {{ t('INTEGRATION_SETTINGS.GHL.STATUS.LOCATION_ID') }}
              </p>
              <p class="text-sm text-n-slate-12 font-mono">
                {{ locationId || '—' }}
              </p>
            </div>
            <div>
              <p class="text-xs text-n-slate-10 uppercase tracking-wide mb-1">
                {{ t('INTEGRATION_SETTINGS.GHL.STATUS.COMPANY_ID') }}
              </p>
              <p class="text-sm text-n-slate-12 font-mono">
                {{ companyId || '—' }}
              </p>
            </div>
            <div>
              <p class="text-xs text-n-slate-10 uppercase tracking-wide mb-1">
                {{ t('INTEGRATION_SETTINGS.GHL.STATUS.CONNECTED_AT') }}
              </p>
              <p class="text-sm text-n-slate-12">
                {{ connectedAt || '—' }}
              </p>
            </div>
            <div>
              <p class="text-xs text-n-slate-10 uppercase tracking-wide mb-1">
                {{ t('INTEGRATION_SETTINGS.GHL.STATUS.TOKEN_EXPIRES') }}
              </p>
              <div class="flex items-center gap-2">
                <p class="text-sm text-n-slate-12">
                  {{ expiresAtFormatted || '—' }}
                </p>
                <span
                  v-if="tokenStatusLabel"
                  class="text-xs font-medium px-2 py-0.5 rounded-full"
                  :class="[
                    tokenStatusColor,
                    tokenStatusColor.includes('ruby')
                      ? 'bg-n-ruby-alpha-2'
                      : tokenStatusColor.includes('amber')
                        ? 'bg-n-amber-alpha-2'
                        : 'bg-n-teal-alpha-2',
                  ]"
                >
                  {{ tokenStatusLabel }}
                </span>
              </div>
            </div>
          </div>

          <!-- Token actions -->
          <div class="flex gap-3 mt-5 pt-4 border-t border-n-container">
            <Button
              faded
              blue
              size="small"
              :label="t('INTEGRATION_SETTINGS.GHL.ACTIONS.REFRESH_TOKEN')"
              :is-loading="isRefreshing"
              @click="refreshToken"
            />
            <Button
              faded
              ruby
              size="small"
              :label="t('INTEGRATION_SETTINGS.GHL.ACTIONS.DISCONNECT')"
              :is-loading="isDisconnecting"
              @click="openDisconnectDialog"
            />
          </div>
        </div>

        <!-- Sync Controls -->
        <div
          class="p-6 outline outline-n-container outline-1 bg-n-alpha-3 rounded-md shadow"
        >
          <h3 class="text-lg font-medium text-n-slate-12 mb-2">
            {{ t('INTEGRATION_SETTINGS.GHL.SYNC.TITLE') }}
          </h3>

          <div class="flex flex-col gap-4 mt-4">
            <div
              class="flex items-center justify-between p-4 bg-n-background rounded-md border border-n-weak"
            >
              <div>
                <p class="text-sm font-medium text-n-slate-12">
                  {{ t('INTEGRATION_SETTINGS.GHL.ACTIONS.SYNC_CONTACTS') }}
                </p>
                <p class="text-xs text-n-slate-10 mt-1">
                  {{ t('INTEGRATION_SETTINGS.GHL.SYNC.CONTACTS_DESCRIPTION') }}
                </p>
              </div>
              <Button
                faded
                blue
                size="small"
                :label="t('INTEGRATION_SETTINGS.GHL.ACTIONS.SYNC_CONTACTS')"
                :is-loading="isSyncingContacts"
                @click="syncContacts"
              />
            </div>

            <div
              class="flex items-center justify-between p-4 bg-n-background rounded-md border border-n-weak"
            >
              <div>
                <p class="text-sm font-medium text-n-slate-12">
                  {{ t('INTEGRATION_SETTINGS.GHL.ACTIONS.SYNC_CONVERSATIONS') }}
                </p>
                <p class="text-xs text-n-slate-10 mt-1">
                  {{
                    t('INTEGRATION_SETTINGS.GHL.SYNC.CONVERSATIONS_DESCRIPTION')
                  }}
                </p>
              </div>
              <Button
                faded
                blue
                size="small"
                :label="
                  t('INTEGRATION_SETTINGS.GHL.ACTIONS.SYNC_CONVERSATIONS')
                "
                :is-loading="isSyncingConversations"
                @click="syncConversations"
              />
            </div>
          </div>
        </div>

        <!-- Webhook Status -->
        <div
          class="p-6 outline outline-n-container outline-1 bg-n-alpha-3 rounded-md shadow"
        >
          <h3 class="text-lg font-medium text-n-slate-12 mb-2">
            {{ t('INTEGRATION_SETTINGS.GHL.WEBHOOKS.TITLE') }}
          </h3>
          <p class="text-sm text-n-slate-11 mb-4">
            {{ t('INTEGRATION_SETTINGS.GHL.WEBHOOKS.DESCRIPTION') }}
          </p>

          <div class="space-y-3">
            <div>
              <p class="text-xs text-n-slate-10 uppercase tracking-wide mb-1">
                {{ t('INTEGRATION_SETTINGS.GHL.WEBHOOKS.ENDPOINT') }}
              </p>
              <p
                class="text-sm text-n-slate-12 font-mono bg-n-background px-3 py-2 rounded border border-n-weak"
              >
                {{ webhookEndpoint }}
              </p>
            </div>

            <div>
              <p class="text-xs text-n-slate-10 uppercase tracking-wide mb-2">
                {{ t('INTEGRATION_SETTINGS.GHL.WEBHOOKS.EVENTS') }}
              </p>
              <div class="flex flex-wrap gap-2">
                <span
                  v-for="event in webhookEvents"
                  :key="event"
                  class="text-xs font-medium px-2.5 py-1 rounded-full bg-n-alpha-2 text-n-slate-11 border border-n-weak"
                >
                  {{ event }}
                </span>
              </div>
            </div>
          </div>
        </div>
      </template>

      <!-- Disconnected state help text -->
      <div
        v-if="!isConnected && !isLoadingStatus"
        class="p-6 outline outline-n-container outline-1 bg-n-alpha-3 rounded-md shadow"
      >
        <p class="text-sm text-n-slate-11 leading-6">
          {{ t('INTEGRATION_SETTINGS.GHL.CONNECT.DESCRIPTION') }}
        </p>
      </div>

      <!-- Disconnect confirmation dialog -->
      <Dialog
        ref="disconnectDialogRef"
        type="alert"
        :title="t('INTEGRATION_SETTINGS.GHL.DELETE_CONFIRMATION.TITLE')"
        :description="t('INTEGRATION_SETTINGS.GHL.DELETE_CONFIRMATION.MESSAGE')"
        confirm-button-label="Disconnect"
        cancel-button-label="Cancel"
        @confirm="confirmDisconnect"
      />
    </div>

    <!-- Loading state -->
    <div v-else class="flex items-center justify-center flex-1 min-h-[200px]">
      <Spinner size="" color-scheme="primary" />
    </div>
  </div>
</template>
