# Deployment Checklist - Enhanced Scripts

## Pre-Deployment Verification

### Environment Check

- [ ] Bash version: `bash --version` (must be 4.0+)
- [ ] System: Debian Trixie or compatible
- [ ] User: Has appropriate permissions
- [ ] Disk space: Sufficient for builds (50GB+)

### File Verification

```bash
cd /mnt/PYTHON-AI-PROJECTS/vllm-cpu

# Check enhanced files exist
- [ ] build_wheels_enhanced.sh exists
- [ ] publish_to_pypi_enhanced.sh exists
- [ ] Both are executable (chmod +x)

# Verify backups exist
- [ ] build_wheels.sh.backup exists
- [ ] publish_to_pypi.sh.backup exists
```

### Security Check

```bash
# Verify .env permissions
- [ ] .env exists (if using PyPI publishing)
- [ ] chmod 600 .env (owner read/write only)
- [ ] ls -l .env shows: -rw-------
```

## Testing Phase (Development)

### Test 1: build_wheels_enhanced.sh

```bash
# Basic functionality
- [ ] ./build_wheels_enhanced.sh --help works
- [ ] Shows "Version: 2.0.0"
- [ ] Logs have timestamps
- [ ] Logs show PID [12345]

# Error handling
- [ ] Invalid Python version rejected
- [ ] Invalid max-jobs rejected
- [ ] Missing dependencies detected
- [ ] Path validation works

# Cleanup behavior
- [ ] Cleanup runs once (not twice)
- [ ] Test: Ctrl+C during build
- [ ] Check logs: only ONE cleanup message
```

### Test 2: publish_to_pypi_enhanced.sh

```bash
# Basic functionality
- [ ] ./publish_to_pypi_enhanced.sh --help works
- [ ] Shows "Version: 2.0.0"
- [ ] Logs have timestamps
- [ ] Logs show PID

# .env security (CRITICAL)
- [ ] chmod 644 .env
- [ ] Run: ./publish_to_pypi_enhanced.sh --test --skip-build
- [ ] Script FAILS with "UNSAFE permissions" error
- [ ] chmod 600 .env
- [ ] Script works now

# Token handling
- [ ] Token not visible in ps aux during upload
- [ ] Token validation rejects invalid format
- [ ] Test with fake token: "invalid-token"
- [ ] Should fail with "does not appear to be valid"
```

### Test 3: Integration Test

```bash
# Full workflow test
- [ ] Build small variant: --variant=vllm-cpu --no-cleanup --max-jobs=2
- [ ] Check output: dist/*.whl exists
- [ ] Validate: twine check dist/*.whl
- [ ] Publish to Test PyPI: --test --skip-build
```

## Deployment Phase

### Step 1: Backup Current Production

```bash
# Create versioned backups
- [ ] cp build_wheels.sh build_wheels_v1_$(date +%Y%m%d).sh
- [ ] cp publish_to_pypi.sh publish_to_pypi_v1_$(date +%Y%m%d).sh

# Verify backups
- [ ] diff build_wheels.sh build_wheels_v1_*.sh (should be identical)
- [ ] diff publish_to_pypi.sh publish_to_pypi_v1_*.sh (should be identical)
```

### Step 2: Deploy Enhanced Scripts

```bash
# Option A: Side-by-side (RECOMMENDED)
- [ ] cp build_wheels_enhanced.sh build_wheels_v2.sh
- [ ] cp publish_to_pypi_enhanced.sh publish_to_pypi_v2.sh
- [ ] Test v2 scripts in production environment
- [ ] Once confirmed: mv build_wheels_v2.sh build_wheels.sh
- [ ] Once confirmed: mv publish_to_pypi_v2.sh publish_to_pypi.sh

# Option B: Direct replacement
- [ ] mv build_wheels_enhanced.sh build_wheels.sh
- [ ] mv publish_to_pypi_enhanced.sh publish_to_pypi.sh
- [ ] chmod +x build_wheels.sh publish_to_pypi.sh
```

### Step 3: Update CI/CD

```bash
# GitHub Actions
- [ ] Workflows use correct script names
- [ ] Secrets configured (PYPI_API_TOKEN, TEST_PYPI_API_TOKEN)
- [ ] Test workflow manually
- [ ] Verify builds complete successfully
```

## Post-Deployment Validation

### Monitoring (First 24 Hours)

```bash
# Check logs
- [ ] Timestamps present in all logs
- [ ] PIDs present in all logs
- [ ] No "CLEANUP" duplicate messages
- [ ] No permission errors

# Performance
- [ ] Build times similar to before (±10%)
- [ ] No unusual delays
- [ ] Memory usage normal
```

### Functional Tests

```bash
# Build test
- [ ] Build at least one variant
- [ ] Verify wheel created
- [ ] Validate wheel: twine check

# Publish test (Test PyPI first!)
- [ ] Publish to Test PyPI
- [ ] Install from Test PyPI
- [ ] Import vllm successfully
- [ ] Only after Test PyPI success: Publish to production PyPI
```

## Rollback Procedure (If Needed)

### Quick Rollback

```bash
# If issues found, rollback immediately
- [ ] mv build_wheels.sh build_wheels_failed.sh
- [ ] mv publish_to_pypi.sh publish_to_pypi_failed.sh
- [ ] mv build_wheels_v1_*.sh build_wheels.sh
- [ ] mv publish_to_pypi_v1_*.sh publish_to_pypi.sh
- [ ] chmod +x build_wheels.sh publish_to_pypi.sh

# Verify rollback
- [ ] ./build_wheels.sh --help | grep -v "Version: 2.0.0"
- [ ] Test build works
```

### Root Cause Analysis

```bash
# If rollback was needed
- [ ] Capture error logs
- [ ] Identify failure point
- [ ] Document issue
- [ ] Fix in enhanced scripts
- [ ] Re-test before redeployment
```

## Documentation Updates

### Update README.md

```markdown
- [ ] Add Bash 4.0+ requirement
- [ ] Update build instructions
- [ ] Add .env security note
- [ ] Mention debug mode: DEBUG=1
```

### Update CLAUDE.md

```markdown
- [ ] Update development environment requirements
- [ ] Add troubleshooting section
- [ ] Document new logging format
- [ ] Add version information
```

### Update CI/CD Docs

```markdown
- [ ] Document workflow changes
- [ ] Update secret requirements
- [ ] Add monitoring recommendations
```

## Compliance Verification

### Security

- [ ] All .env files have 600 permissions
- [ ] Tokens not exposed in logs
- [ ] Input validation working
- [ ] Path traversal prevented
- [ ] Command injection prevented

### Code Quality

- [ ] Bash version check working
- [ ] Readonly constants not modified
- [ ] Logs properly formatted
- [ ] Error messages helpful
- [ ] Cleanup working correctly

### Best Practices

- [ ] IFS set to $'\n\t'
- [ ] Trap handler correct
- [ ] Command timeouts working
- [ ] Debug mode functional
- [ ] ShellCheck clean (if available)

## Final Sign-Off

### Checklist Complete

- [ ] All pre-deployment checks passed
- [ ] All testing passed
- [ ] Deployment completed successfully
- [ ] Post-deployment validation passed
- [ ] Documentation updated
- [ ] Team notified of changes

### Approval

- [ ] Reviewed by: ________________
- [ ] Date: ________________
- [ ] Approved for production: Yes / No
- [ ] Rollback plan confirmed: Yes / No

## Contact Information

### For Issues

- Primary contact: [Your contact]
- Escalation: [Manager contact]
- Documentation: See FINAL_IMPROVEMENTS_SUMMARY.md

### For Questions

- Security: See SECURITY_FIXES.md
- Best Practices: See ENHANCEMENTS_APPLIED.md
- Usage: See CLAUDE.md

## Notes

_Add any deployment-specific notes here:_

---

**Last Updated**: 2025-11-21
**Version**: 2.0.0
**Status**: Ready for Production ✅
