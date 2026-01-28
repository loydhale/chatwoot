# GoHighLevel OAuth Integration Requirements

> This document outlines the OAuth 2.0 integration requirements for DeskFlow to connect with the GoHighLevel (GHL) Marketplace.

## Overview

DeskFlow integrates with GHL as a **Marketplace App**, allowing GHL agencies and sub-accounts to:
1. SSO into DeskFlow directly from their GHL dashboard
2. Sync contacts/leads between GHL and DeskFlow
3. Receive webhook events from GHL (conversations, contacts, etc.)
4. Send messages back to GHL contacts via API

---

## OAuth 2.0 Flow

GHL uses the standard OAuth 2.0 Authorization Code flow:

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   GHL User  │────▶│  DeskFlow   │────▶│  GHL OAuth  │
│  (Agency)   │     │  /auth/ghl  │     │  /oauth/    │
└─────────────┘     └─────────────┘     └─────────────┘
       │                   │                   │
       │                   │◀── Auth Code ─────│
       │                   │                   │
       │                   │── Exchange Code ─▶│
       │                   │                   │
       │◀── Access Token ──│◀── Token ─────────│
       │                   │                   │
```

---

## Required Endpoints (DeskFlow)

### 1. OAuth Initiation
```
GET /api/v1/auth/ghl
```
Redirects user to GHL's OAuth authorization page.

**Query Parameters:**
- `redirect_uri` - Where to return after auth
- `state` - CSRF protection token

### 2. OAuth Callback
```
GET /api/v1/auth/ghl/callback
```
Receives the authorization code from GHL and exchanges it for tokens.

**Query Parameters:**
- `code` - Authorization code from GHL
- `state` - CSRF token (verify matches)

### 3. Token Refresh
```
POST /api/v1/auth/ghl/refresh
```
Background job to refresh tokens before expiration (tokens last 24h).

### 4. Webhook Receiver
```
POST /api/v1/webhooks/ghl
```
Receives webhook events from GHL (inbound messages, contact updates, etc.).

**Headers Required:**
- `X-GHL-Signature` - HMAC signature for verification

---

## GHL API Endpoints We'll Use

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/oauth/token` | POST | Exchange code for access token |
| `/oauth/token` | POST | Refresh access token |
| `/contacts/` | GET/POST | Sync contacts |
| `/contacts/{id}` | GET/PUT | Get/update contact |
| `/conversations/` | GET | List conversations |
| `/conversations/{id}/messages` | GET/POST | Get/send messages |
| `/locations/{id}` | GET | Get location (sub-account) info |
| `/users/` | GET | Get users for SSO mapping |

**Base URL:** `https://services.leadconnectorhq.com`

---

## Required OAuth Scopes

When registering the app, request these scopes:

### Core (Required)
| Scope | Purpose |
|-------|---------|
| `contacts.readonly` | Read contact data for conversation context |
| `contacts.write` | Create/update contacts from DeskFlow |
| `conversations.readonly` | Read conversation history |
| `conversations.write` | Send messages via GHL |
| `conversations/message.readonly` | Read individual messages |
| `conversations/message.write` | Send messages |
| `locations.readonly` | Get sub-account info |
| `users.readonly` | Map GHL users to DeskFlow agents |

### Optional (Enhanced Features)
| Scope | Purpose |
|-------|---------|
| `opportunities.readonly` | Show deal info in conversation sidebar |
| `opportunities.write` | Update deals from DeskFlow |
| `calendars.readonly` | Show upcoming appointments |
| `workflows.readonly` | Trigger/check automation status |
| `forms.readonly` | Access form submissions |
| `custom-fields.readonly` | Access custom contact fields |

### SSO Scopes
| Scope | Purpose |
|-------|---------|
| `oauth.readonly` | Access token introspection |
| `oauth.write` | Token management |

---

## Environment Variables

Add these to production `.env`:

```bash
# GHL OAuth Configuration
GHL_CLIENT_ID=your_client_id_from_marketplace
GHL_CLIENT_SECRET=your_client_secret_from_marketplace
GHL_REDIRECT_URI=https://app.deskflow.app/api/v1/auth/ghl/callback
GHL_WEBHOOK_SECRET=your_webhook_signing_secret

# GHL API Base URL
GHL_API_BASE_URL=https://services.leadconnectorhq.com
```

---

## Database Schema Additions

New tables/columns needed:

### `ghl_connections` table
```ruby
create_table :ghl_connections do |t|
  t.references :account, foreign_key: true, null: false
  t.string :location_id, null: false  # GHL sub-account ID
  t.string :company_id               # GHL agency ID
  t.string :access_token, null: false
  t.string :refresh_token, null: false
  t.datetime :token_expires_at
  t.jsonb :scopes, default: []
  t.jsonb :metadata, default: {}
  t.timestamps
  
  t.index :location_id, unique: true
end
```

### `users` table additions
```ruby
add_column :users, :ghl_user_id, :string
add_index :users, :ghl_user_id
```

### `contacts` table additions
```ruby
add_column :contacts, :ghl_contact_id, :string
add_index :contacts, [:account_id, :ghl_contact_id]
```

---

## Webhook Events to Subscribe

Configure these webhooks in the GHL Marketplace app settings:

| Event | Trigger | DeskFlow Action |
|-------|---------|-----------------|
| `ContactCreate` | New contact in GHL | Create contact in DeskFlow |
| `ContactUpdate` | Contact updated | Sync contact data |
| `ContactDelete` | Contact deleted | Archive in DeskFlow |
| `InboundMessage` | Message received | Create/append conversation |
| `OutboundMessage` | Message sent (from GHL) | Sync message to DeskFlow |
| `ConversationProviderOutboundMessage` | Provider message | Sync response |
| `NoteCreate` | Note added to contact | Create internal note |
| `TaskCreate` | Task created | Optionally sync |
| `AppointmentCreate` | Appointment booked | Notify agent |

**Webhook URL:** `https://app.deskflow.app/api/v1/webhooks/ghl`

---

## Implementation Checklist

### Phase 1: OAuth Foundation
- [ ] Create `GhlConnection` model
- [ ] Add GHL OAuth routes
- [ ] Implement authorization redirect
- [ ] Implement callback token exchange
- [ ] Implement token refresh job
- [ ] Store tokens securely (encrypted)

### Phase 2: Contact Sync
- [ ] Create `GhlSyncService`
- [ ] Implement contact import
- [ ] Implement bidirectional sync
- [ ] Handle duplicate detection
- [ ] Map custom fields

### Phase 3: Messaging
- [ ] Create `Channel::Ghl` model
- [ ] Implement message receiving webhook
- [ ] Implement message sending API
- [ ] Handle media attachments
- [ ] Implement delivery status tracking

### Phase 4: SSO
- [ ] Implement SSO login flow
- [ ] Map GHL users to DeskFlow agents
- [ ] Handle role/permission mapping
- [ ] Auto-provision new users

---

## Security Considerations

1. **Token Storage**: Encrypt access/refresh tokens at rest
2. **Webhook Verification**: Always verify `X-GHL-Signature` header
3. **CSRF Protection**: Use `state` parameter in OAuth flow
4. **Rate Limiting**: GHL has API rate limits (varies by plan)
5. **Scope Minimization**: Only request scopes actually needed
6. **Token Refresh**: Proactively refresh before expiration

---

## Testing

### Local Development
1. Use ngrok to expose local server: `ngrok http 3000`
2. Set `GHL_REDIRECT_URI` to ngrok URL
3. Create test app in GHL Developer Portal

### Staging
1. Create separate GHL app for staging
2. Use staging credentials
3. Test full OAuth flow
4. Test webhook delivery

---

## Resources

- [GHL API Documentation](https://highlevel.stoplight.io/docs/integrations/)
- [GHL OAuth Guide](https://highlevel.stoplight.io/docs/integrations/authentication)
- [GHL Marketplace App Guide](https://help.gohighlevel.com/support/solutions/articles/48001232016)
- [GHL Webhook Events](https://highlevel.stoplight.io/docs/integrations/webhooks)
