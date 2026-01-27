# Security Policy

DeskFlow takes security seriously. We appreciate your help in keeping DeskFlow and our users safe.

## Reporting a Vulnerability

If you discover a security vulnerability, please report it responsibly:

1. **Do NOT** open a public GitHub issue
2. Email us at: **security@growlocals.ai**
3. Include:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Any suggested fixes

We will acknowledge your report within 48 hours and work with you to understand and resolve the issue.

## Supported Versions

| Version | Supported |
|---------|-----------|
| Latest release | ✅ |
| Previous releases | ❌ |

We recommend always running the latest version.

## Scope

### In Scope

- Remote code execution
- SQL injection
- Authentication bypass
- Privilege escalation
- Cross-site scripting (XSS)
- Cross-site request forgery (CSRF)
- Sensitive data exposure
- Authorization flaws

### Out of Scope

- Denial of Service (DoS) attacks
- Social engineering
- Physical attacks
- Issues in dependencies (report to upstream)
- Missing security headers without demonstrated impact
- Reports from automated scanners without validation

## Responsible Disclosure

- Give us reasonable time to fix issues before public disclosure
- Do not access or modify other users' data
- Do not perform testing on production systems
- Use a self-hosted instance for security testing

## Upstream Security

DeskFlow is built on [Chatwoot](https://github.com/chatwoot/chatwoot). For vulnerabilities in core Chatwoot functionality, please also consider reporting to the upstream project:

- Chatwoot Security: https://github.com/chatwoot/chatwoot/security/advisories/new
- Chatwoot Email: security@chatwoot.com

## Thanks

We appreciate security researchers who help keep DeskFlow safe. 🙏

---

*Last updated: January 2025*
