# GHL Marketplace Submission Checklist

> Complete this checklist before submitting DeskFlow to the GoHighLevel Marketplace.

---

## 📋 Pre-Submission Requirements

### App Information
- [ ] **App Name:** DeskFlow (confirmed, unique in marketplace)
- [ ] **Tagline:** AI-powered customer support desk for agencies (max 80 chars)
- [ ] **Description:** Comprehensive description (see below)
- [ ] **Category:** Customer Support / Helpdesk
- [ ] **Website URL:** https://deskflow.app
- [ ] **Support Email:** support@deskflow.app
- [ ] **Privacy Policy URL:** https://deskflow.app/privacy
- [ ] **Terms of Service URL:** https://deskflow.app/terms

### Branding Assets
- [ ] **App Icon:** 512x512 PNG, transparent background
- [ ] **Logo:** SVG or high-res PNG for marketplace listing
- [ ] **Screenshots:** 3-5 screenshots (1280x800 recommended)
  - [ ] Dashboard overview
  - [ ] Conversation view with Atlas AI
  - [ ] Reports/analytics
  - [ ] Settings/configuration
  - [ ] Mobile responsive view
- [ ] **Demo Video:** 2-3 minute walkthrough (optional but recommended)

### Technical Requirements
- [ ] **OAuth 2.0 Implementation**
  - [ ] Authorization endpoint working
  - [ ] Token exchange working
  - [ ] Token refresh working
  - [ ] Proper error handling
  - [ ] State parameter for CSRF protection
- [ ] **Webhook Receiver**
  - [ ] Endpoint responding with 200
  - [ ] Signature verification implemented
  - [ ] All subscribed events handled
- [ ] **API Integration**
  - [ ] Contact sync working
  - [ ] Message sending working
  - [ ] Proper rate limiting
- [ ] **SSL/HTTPS** on all endpoints
- [ ] **Health check endpoint** responding

---

## 📝 App Description Template

**Short Description (80 chars):**
```
AI-powered helpdesk that turns GHL conversations into organized support tickets
```

**Full Description:**
```
DeskFlow is a white-label customer support platform built for GHL agencies.

🎯 KEY FEATURES:
• Atlas AI Assistant - Intelligent responses trained on your knowledge base
• Unified Inbox - All GHL conversations in one organized dashboard  
• Smart Ticketing - Auto-categorize and prioritize support requests
• Team Collaboration - Assign, @mention, and internal notes
• Knowledge Base - Self-service portal for common questions
• Analytics & Reports - Track response times, satisfaction, and volume
• White-Label Ready - Your brand, your domain

🔌 SEAMLESS GHL INTEGRATION:
• One-click SSO from GHL dashboard
• Two-way contact sync
• Automatic conversation import
• Send replies back to GHL
• Custom field mapping

💼 PERFECT FOR:
• Digital marketing agencies
• SaaS companies
• E-commerce support teams
• Service businesses

📈 PRICING:
• Free trial available
• Usage-based AI pricing
• Unlimited agents on all plans

Get started in minutes - just connect your GHL account!
```

---

## 🔐 OAuth Scopes Justification

When submitting, you'll need to explain why each scope is needed:

| Scope | Justification |
|-------|---------------|
| `contacts.readonly` | Display contact info in conversation sidebar |
| `contacts.write` | Create contacts from DeskFlow widget visitors |
| `conversations.readonly` | Import conversation history for unified inbox |
| `conversations.write` | Send support replies back to GHL |
| `conversations/message.readonly` | Display full message history |
| `conversations/message.write` | Send messages on behalf of agents |
| `locations.readonly` | Get sub-account details for multi-location support |
| `users.readonly` | Map GHL users to DeskFlow agents for SSO |

---

## ✅ Pre-Launch Testing

### OAuth Flow
- [ ] New user can authorize app
- [ ] Existing user can reauthorize
- [ ] Token refresh works (test after 23+ hours)
- [ ] Revoked access handled gracefully
- [ ] Error states have user-friendly messages

### Webhook Handling
- [ ] `ContactCreate` creates contact in DeskFlow
- [ ] `InboundMessage` creates/appends conversation
- [ ] `ContactUpdate` syncs changes
- [ ] Invalid signature returns 401
- [ ] Duplicate events handled (idempotency)

### User Experience
- [ ] SSO login works from GHL app card
- [ ] First-time setup wizard completes
- [ ] Conversations appear within 30 seconds
- [ ] Sending messages works
- [ ] Agent notifications working

### Edge Cases
- [ ] Large contact sync (1000+ contacts)
- [ ] High message volume
- [ ] Network timeouts handled
- [ ] API rate limits respected
- [ ] Concurrent requests safe

---

## 📄 Required Legal Documents

### Privacy Policy Must Include:
- [ ] What data is collected from GHL
- [ ] How data is stored and secured
- [ ] Data retention periods
- [ ] Third-party sharing (AI providers, etc.)
- [ ] User rights (deletion, export)
- [ ] Contact information

### Terms of Service Must Include:
- [ ] Service description
- [ ] User responsibilities
- [ ] Acceptable use policy
- [ ] Limitation of liability
- [ ] Termination conditions
- [ ] GHL as data processor relationship

---

## 🚀 Deployment Checklist

### Infrastructure
- [ ] Production server provisioned (Render/Railway)
- [ ] Database backups configured
- [ ] Redis for Sidekiq running
- [ ] SSL certificate valid
- [ ] Domain DNS configured
- [ ] Health monitoring set up

### Environment Variables Set
- [ ] `SECRET_KEY_BASE` (unique, secure)
- [ ] `DATABASE_URL`
- [ ] `REDIS_URL`
- [ ] `GHL_CLIENT_ID`
- [ ] `GHL_CLIENT_SECRET`
- [ ] `GHL_REDIRECT_URI`
- [ ] `GHL_WEBHOOK_SECRET`
- [ ] `OPENAI_API_KEY` (for Atlas AI)
- [ ] `SMTP_*` variables for email

### Performance
- [ ] Asset precompilation working
- [ ] CDN configured (optional)
- [ ] Database indexes created
- [ ] Sidekiq workers scaled appropriately

---

## 📊 Marketplace Listing Optimization

### Keywords (for searchability):
```
helpdesk, customer support, ticketing, live chat, AI support,
knowledge base, team inbox, SLA, response time, agent productivity
```

### Pricing Display:
- [ ] Clear pricing tiers
- [ ] Free trial highlighted
- [ ] Per-seat or usage pricing explained
- [ ] "Contact for enterprise" if applicable

### Social Proof (if available):
- [ ] Customer testimonials
- [ ] Case studies
- [ ] Usage statistics
- [ ] Integration partner logos

---

## 📬 Submission Process

1. **Log into GHL Developer Portal**
   - https://marketplace.gohighlevel.com/developer

2. **Create New App**
   - Fill in all required fields
   - Upload branding assets
   - Configure OAuth settings
   - Set up webhooks

3. **Submit for Review**
   - Apps typically reviewed within 5-7 business days
   - May receive feedback requiring changes
   - Be responsive to reviewer questions

4. **Post-Approval**
   - [ ] Verify live listing looks correct
   - [ ] Test install flow as new user
   - [ ] Monitor first installs for issues
   - [ ] Set up support channel for GHL users

---

## 🔄 Post-Launch

- [ ] Monitor error rates
- [ ] Track install/uninstall rates
- [ ] Collect user feedback
- [ ] Plan feature updates
- [ ] Respond to marketplace reviews
- [ ] Keep documentation updated

---

## 📞 Support Contacts

**GHL Developer Support:** developers@gohighlevel.com
**GHL Partner Program:** partners@gohighlevel.com
**Marketplace Issues:** marketplace@gohighlevel.com

---

*Last updated: January 2025*
