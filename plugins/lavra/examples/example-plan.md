# Add Two-Factor Authentication

Add TOTP-based two-factor authentication to protect user accounts.

## Background

Users have requested 2FA for enhanced security. Current authentication is username/password only, which is vulnerable to credential stuffing attacks.

Market research shows 73% of competitors offer 2FA, and it's becoming table stakes for security-conscious users.

## Research

**TOTP (Time-based One-Time Password)**
- RFC 6238 standard
- 6-digit codes that rotate every 30 seconds
- Compatible with Google Authenticator, Authy, 1Password, etc.
- More secure than SMS-based 2FA (no SIM swapping vulnerability)

**Ruby gems available**:
- `rotp` - TOTP generation and verification (8.3k downloads/week)
- `rqrcode` - QR code generation for setup (1.2M downloads/week)

**Security considerations**:
- OTP secrets MUST be encrypted at rest
- Backup codes needed for account recovery (10 single-use codes)
- Rate limiting on verification attempts (max 3 failures, then lockout)
- Must support account recovery flow if user loses device

## Decisions

**Choice: TOTP over SMS**
- TOTP is more secure (no SIM swapping vulnerability)
- Works offline (no dependency on SMS delivery)
- Better UX (no waiting for SMS, works internationally)
- Industry best practice per NIST guidelines

**Choice: Required for admins, optional for users**
- Admins handle sensitive operations, require 2FA
- Users can opt-in for enhanced security
- Gradual rollout reduces support burden

**Choice: Using rotp + rqrcode gems**
- Battle-tested libraries
- Active maintenance
- Simple API

## Implementation Steps

### Step 1: Database Schema

Create `otp_secrets` table:
- user_id (indexed, unique)
- encrypted_secret (encrypted with Rails credentials)
- backup_codes (jsonb array, encrypted)
- enabled_at (timestamp)
- last_used_at (timestamp)

Migration checklist:
- Add foreign key constraint to users
- Add index on user_id
- Encrypt secret column using lockbox or similar
- Add validation for backup codes format

### Step 2: OTP Secret Generation

Create `OtpService` to handle:
- Generate secure random secret (Base32 encoded)
- Encrypt and store secret
- Generate 10 backup codes (random 8-char alphanumeric)
- Return QR code provisioning URI for authenticator apps

API:
```ruby
OtpService.enable_for_user(user)
# => { qr_code_uri: "otpauth://...", backup_codes: [...] }
```

### Step 3: QR Code Display Endpoint

Create `Settings::TwoFactorController#new`:
- GET /settings/two_factor/setup
- Generates OTP secret via OtpService
- Renders QR code using rqrcode
- Shows backup codes (one-time display)
- User must verify before enabling

Response includes:
- QR code image (SVG for crispness)
- Manual entry key (for apps that don't scan QR)
- 10 backup codes to save

### Step 4: Verification Endpoint

Create `Settings::TwoFactorController#create`:
- POST /settings/two_factor/verify
- Accepts 6-digit OTP code
- Verifies against stored secret using rotp
- Enables 2FA on success
- Rate limits: max 3 attempts, 5-minute lockout

Error cases:
- Invalid code (wrong digits)
- Expired code (clock drift tolerance: 30 seconds)
- Rate limit exceeded
- Secret not found

### Step 5: Login Flow Integration

Modify `SessionsController#create`:
- After successful password authentication
- If user has 2FA enabled, redirect to 2FA verification
- Session marked as "partial" (authenticated but not 2FA verified)
- Must verify OTP before full session granted

Add `SessionsController#verify_otp`:
- POST /sessions/verify_otp
- Accepts 6-digit code or backup code
- Verifies and completes login
- Invalidates backup code if used
- Rate limits: max 3 attempts, 5-minute lockout

### Step 6: Settings UI

Add 2FA section to user settings:
- Show status (enabled/disabled)
- Enable button → goes to setup flow
- Disable button (requires password confirmation)
- Regenerate backup codes option
- View recovery options

UI includes:
- Clear status indicator (badge/icon)
- Setup instructions
- Troubleshooting help link

### Step 7: Account Recovery Flow

Add recovery mechanism for lost devices:
- User can disable 2FA via email confirmation link
- Requires password + email verification
- Notifies user via email when 2FA is disabled
- Logs security event for audit trail

Security:
- Email link expires in 1 hour
- Single use only
- Requires password entry after clicking link
- Rate limited: max 3 requests per day

## Testing Checklist

- [ ] Setup flow generates valid TOTP secret
- [ ] QR code scannable by Google Authenticator
- [ ] Backup codes work for login
- [ ] Backup codes invalidated after use
- [ ] Rate limiting prevents brute force
- [ ] Clock drift handled (30-second window)
- [ ] Account recovery flow works
- [ ] Email notifications sent correctly
- [ ] Admin 2FA enforcement works
- [ ] User opt-in works

## Rollout Plan

**Phase 1: Internal testing (Week 1)**
- Deploy to staging
- Team members test with their accounts
- Validate all edge cases

**Phase 2: Admins required (Week 2)**
- Require all admin accounts to enable 2FA
- Support team prepares for user questions
- Monitor for issues

**Phase 3: User opt-in (Week 3)**
- Announce feature to all users
- Settings page shows option
- Monitor adoption rate

**Phase 4: Encourage adoption (Week 4+)**
- In-app banners for high-value accounts
- Email campaign explaining benefits
- Track metrics: adoption rate, support tickets

## Success Metrics

- 100% admin adoption within 1 week
- 25% user adoption within 1 month
- <5 support tickets per 1000 users
- Zero account takeovers on 2FA-enabled accounts

## Dependencies

- Rails 7.0+ (has encrypted attributes built-in)
- rotp gem
- rqrcode gem
- Email delivery working (for recovery flow)
