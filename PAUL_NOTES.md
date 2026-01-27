# Paul's Development Notes - DeskFlow (formerly SupportFlow)

## Project Overview
White-label AI support platform for GHL agencies, built on Chatwoot.

**Started:** 2026-01-26 ~9pm CST
**Repo:** loydhale/chatwoot (GitHub fork)
**Local:** /Users/loyd/clawd/projects/supportflow
**Product Name:** DeskFlow
**AI Assistant Name:** Atlas (was Captain)

## Goals (From PRD + Creative License)
1. ✅ Rebrand Chatwoot completely → DeskFlow
2. ✅ Rebrand Captain → Atlas
3. [ ] Add per-account white-labeling capabilities
4. [ ] GHL Marketplace integration
5. [ ] AI usage metering for billing
6. [ ] Make it cool and useful

## Session 1 Progress (2026-01-26 Night)

### Commits Made (7 total):
1. `592f875` - Initial rebrand (config, package.json, README)
2. `e9d6667` - Logos, templates, EN locales
3. `79e1f45` - ALL locale files (703 files!)
4. `c68471d` - Vue/JS components (144 files)
5. `6e2fa85` - Ruby files (187 files)
6. `941960f` - Spec files and env example (116 files)
7. `82afe18` - Email defaults and test URLs

### Total Files Rebranded: ~1,200+

### What Was Done:
- [x] Forked chatwoot/chatwoot to loydhale/chatwoot
- [x] Cloned locally
- [x] Renamed Ruby module to DeskFlow (with Chatwoot alias for compatibility)
- [x] Updated package.json with new name and metadata
- [x] Created new README.md with DeskFlow branding
- [x] Created BRANDING.md documentation
- [x] Replaced "Chatwoot" with "DeskFlow" in:
  - All locale files (JSON and YAML) - 703+ files
  - All Vue components - 144+ files
  - All JavaScript files
  - All Ruby files (app, lib, enterprise) - 187+ files
  - All ERB templates
  - Spec/test files - 116+ files
  - .env.example
- [x] Replaced "Captain" with "Atlas" in all user-facing strings
- [x] Created placeholder DeskFlow logos (SVG - light, dark, thumbnail)
- [x] Updated default email addresses (chatwoot.com → deskflow.app)
- [x] Updated test URLs

### What Was Preserved (For Compatibility):
- Technical API references (`chatwootWebChannel`, `chatwootSDK`) 
- Database field names (`captain_models`, `captain_features`)
- External package imports (`@chatwoot/utils`, etc.)
- Chatwoot module alias in config/application.rb

### What Still Needs Work:
- [ ] Set up development environment (Docker)
- [ ] Test that the app runs with the rebranding
- [ ] Create proper logo designs (current ones are placeholders)
- [ ] Add per-account branding feature (Phase 3 of PRD)
- [ ] GHL OAuth integration (Phase 4 of PRD)
- [ ] AI usage billing integration (Phase 5 of PRD)
- [ ] Replace PNG icons/favicons with new designs

## Files to Note

### Key Configuration:
- `config/application.rb` - Main module (DeskFlow with Chatwoot alias)
- `package.json` - NPM package name (@deskflow/deskflow)
- `.env.example` - Environment variable documentation

### Branding Assets:
- `public/brand-assets/logo.svg` - Main logo (placeholder)
- `public/brand-assets/logo_dark.svg` - Dark mode logo (placeholder)
- `public/brand-assets/logo_thumbnail.svg` - Thumbnail (placeholder)

### Documentation:
- `README.md` - New DeskFlow readme
- `BRANDING.md` - Branding guide
- `PAUL_NOTES.md` - This file

## Commands Reference

```bash
# Dev setup
docker-compose up -d
bundle install
pnpm install
rails db:prepare
rails server

# Test
bundle exec rspec
pnpm run test

# Build
pnpm run build
```

## Notes for Loyd

### What I Accomplished Tonight:
Massive rebranding pass - over 1,200 files updated. The app is now branded as "DeskFlow" with the AI assistant named "Atlas". All user-facing strings have been updated.

### What's Next:
1. Test that the app actually runs with these changes
2. Set up the dev environment locally or in Docker
3. Start on the GHL integration (Phase 4)
4. Build the per-account branding feature (Phase 3)

### Decisions I Made:
- **Product Name:** DeskFlow (clean, implies workflow, professional)
- **AI Name:** Atlas (strong, reliable, conveys support)
- **Approach:** Preserve technical API names for backwards compatibility
- **Logos:** Created simple placeholder SVGs (need proper design)

Let me know if you want me to change anything or go in a different direction!

---
*Last updated: 2026-01-26 ~10:30pm CST*
