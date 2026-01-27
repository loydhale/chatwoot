# Paul's Development Notes - SupportFlow

## Project Overview
White-label AI support platform for GHL agencies, built on Chatwoot.

**Started:** 2026-01-26 ~9pm CST
**Repo:** loydhale/chatwoot (will rename)
**Local:** /Users/loyd/clawd/projects/supportflow

## Goals (From PRD + Creative License)
1. Rebrand Chatwoot completely → SupportFlow (working name)
2. Add per-account white-labeling capabilities
3. GHL Marketplace integration
4. AI usage metering for billing
5. Make it cool and useful

## Progress Log

### Session 1 (2026-01-26 Night)

#### Done:
- [x] Forked chatwoot/chatwoot to loydhale/chatwoot
- [x] Cloned locally
- [x] Identify all branding touchpoints (1393 files!)
- [x] Start systematic rebranding
  - [x] config/application.rb - Module renamed to DeskFlow
  - [x] package.json - Updated name and metadata
  - [x] README.md - New branded version
  - [x] EN locale files - Chatwoot → DeskFlow, Captain → Atlas
  - [x] ERB templates - Chatwoot → DeskFlow
  - [x] SVG logos - Created placeholder DeskFlow logos
- [ ] Set up dev environment
- [ ] Test that it runs

#### Files to Rebrand (discovering as I go):
- config/locales/*.yml - i18n strings
- app/javascript/ - Vue frontend
- public/ - logos, favicons
- app/views/ - email templates
- config/application.rb - app name
- README.md, docs

#### Ideas Beyond PRD:
- (will add as I discover opportunities)

---

## Commands Reference

```bash
# Dev setup
docker-compose up -d
bundle install
yarn install
rails db:prepare
rails server

# Test
bundle exec rspec
```

## Notes for Loyd
I'll update this file as I work so you can see my thinking and progress.
