# Security guidance

## PHP2Shell: upgrade the runtime, not just the extension

This project helps remove an OCI8 binary compatibility obstacle to a PHP upgrade.
It does **not** provide the PHP core fixes for **CVE-2026-109618** or
**CVE-2026-109619** (PHP2Shell). PHP's advisories describe remote-code-execution
risks involving out-of-memory corruption and stale request-owned global state.[1][2]

For the branches targeted by these builds, both advisories identify the following
first patched PHP releases:[1][2]

| Branch | Minimum release containing both fixes |
| --- | --- |
| PHP 8.2 | **8.2.35** |
| PHP 8.3 | **8.3.36** |
| PHP 8.4 | **8.4.27** |
| PHP 8.5 | **8.5.12** |

Use those releases or **newer patched releases within the corresponding branch**.
A version such as “PHP 8.3” alone is not a security assurance. Confirm the actual
patch version in the web-serving process, not only in a command-line installation.
The minimums above are from the upstream advisories checked on 2026-10-27;
consult the linked advisories for updates and your vendor for backported fixes.

PHP's first advisory says updating to a patched release is the only complete
mitigation; the second says there is no complete generic configuration mitigation.
Do not treat disabling error display, switching SAPI, increasing memory limits,
or deploying this extension as substitutes for updating PHP.[1][2]

Oracle also identifies these CVEs as PHP2Shell and recommends applying available
security patches without delay to affected Oracle products. That advisory does
not establish that Oracle Client 11.2 is safe or patched by this project.[3]

## Deployment requirements

- Install patched PHP independently of this extension. If choosing between
  branches, consider application compatibility and the branch's current support
  status, not merely availability of a DLL here.
- Match PHP minor version, TS/NTS mode, x64 architecture and compiler ABI.
- Install an appropriately licensed Oracle Client runtime separately. Do not
  copy Oracle DLLs from untrusted downloads or mix client architectures/Homes.
- Restart every web/PHP worker after updating, then verify the serving runtime
  and exercise application/database paths in a staging environment.
- Check all remaining extensions, frameworks and dependencies as part of the
  upgrade. This repository does not audit them.
- If compromise is suspected, investigate and follow your incident-response
  process; replacing binaries is not proof that a host is clean.

## Trust and verification limits

Release ZIPs contain the OCI8 extension, checksums, license and notices only.
Checksums detect changes relative to the published manifest; they are not an
independent code-signing or malware-free guarantee. Verify the source, workflow
and release provenance according to your organization's policy.

Build and packaging checks are not vulnerability scans, exploit regression tests,
web-server load tests or database integration certification. In particular, these
DLLs do not prove an application is immune to PHP2Shell.

## Private build inputs

Oracle media is held in a separate private repository. Its fine-grained download
PAT is read-only and exposed only to the download step. It must never appear in
source, logs, releases, artifacts or issue reports. Public pull requests do not
run a secret-bearing build. Do not introduce `pull_request_target` or execute
untrusted fork code with the private media token.

## Reporting

Report packaging/build issues through this repository's issues, without database
credentials, tokens, connection strings, private SQL/data or Oracle binaries.
For a sensitive repository issue, use GitHub's private vulnerability reporting
if available; otherwise arrange a private channel with the maintainer before
sharing details. Report PHP core and Oracle product vulnerabilities through the
respective upstream vendor's security channels.

## Sources

[1] https://github.com/php/php-src/security/advisories/GHSA-w8hw-w9fx-j79w
[2] https://github.com/php/php-src/security/advisories/GHSA-6wmf-4rv5-p3rp
[3] https://www.oracle.com/security-alerts/alert-cve-2026-109618.html
