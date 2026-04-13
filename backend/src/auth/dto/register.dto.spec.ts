import { validate } from 'class-validator';
import { plainToInstance } from 'class-transformer';
import { RegisterDto } from './register.dto';

function createDto(partial: Partial<RegisterDto>): RegisterDto {
  return plainToInstance(RegisterDto, {
    email: 'valid@example.com',
    username: 'valid_user',
    password: 'Valid@123',
    emailVerificationToken: 'valid-token',
    ...partial,
  });
}

async function expectValid(partial: Partial<RegisterDto>) {
  const dto = createDto(partial);
  const errors = await validate(dto);
  expect(errors).toHaveLength(0);
}

async function expectInvalid(
  partial: Partial<RegisterDto>,
  property: string,
) {
  const dto = createDto(partial);
  const errors = await validate(dto);
  const match = errors.find((e) => e.property === property);
  expect(match).toBeDefined();
}

describe('RegisterDto', () => {
  // ─── VALID INPUTS ─────────────────────────────────────

  describe('valid inputs', () => {
    it('should pass with all valid fields', async () => {
      await expectValid({});
    });

    it('should accept a username with exactly 3 characters', async () => {
      await expectValid({ username: 'abc' });
    });

    it('should accept a username with exactly 30 characters', async () => {
      await expectValid({ username: 'a'.repeat(30) });
    });

    it('should accept a username with underscores and numbers', async () => {
      await expectValid({ username: 'user_123_test' });
    });

    it('should accept a password with minimum complexity', async () => {
      await expectValid({ password: 'Abcdef@1' });
    });
  });

  // ─── EMAIL EDGE CASES ─────────────────────────────────

  describe('email validation', () => {
    it('should reject an empty email', async () => {
      await expectInvalid({ email: '' }, 'email');
    });

    it('should reject an email without @', async () => {
      await expectInvalid({ email: 'notanemail' }, 'email');
    });

    it('should reject an email without domain', async () => {
      await expectInvalid({ email: 'user@' }, 'email');
    });
  });

  // ─── USERNAME EDGE CASES ──────────────────────────────

  describe('username validation', () => {
    it('should reject a username shorter than 3 characters', async () => {
      await expectInvalid({ username: 'ab' }, 'username');
    });

    it('should reject a single-character username', async () => {
      await expectInvalid({ username: 'x' }, 'username');
    });

    it('should reject an empty username', async () => {
      await expectInvalid({ username: '' }, 'username');
    });

    it('should reject a username longer than 30 characters', async () => {
      await expectInvalid({ username: 'a'.repeat(31) }, 'username');
    });

    it('should reject a username with spaces', async () => {
      await expectInvalid({ username: 'has space' }, 'username');
    });

    it('should reject a username with special characters', async () => {
      await expectInvalid({ username: 'user@name' }, 'username');
    });

    it('should reject a username with dashes', async () => {
      await expectInvalid({ username: 'user-name' }, 'username');
    });

    it('should reject a username with dots', async () => {
      await expectInvalid({ username: 'user.name' }, 'username');
    });
  });

  // ─── PASSWORD EDGE CASES ──────────────────────────────

  describe('password validation', () => {
    it('should reject a password shorter than 8 characters', async () => {
      await expectInvalid({ password: 'Ab@1234' }, 'password');
    });

    it('should reject a password without uppercase', async () => {
      await expectInvalid({ password: 'abcdef@1' }, 'password');
    });

    it('should reject a password without lowercase', async () => {
      await expectInvalid({ password: 'ABCDEF@1' }, 'password');
    });

    it('should reject a password without a number', async () => {
      await expectInvalid({ password: 'Abcdefg@' }, 'password');
    });

    it('should reject a password without a special character', async () => {
      await expectInvalid({ password: 'Abcdefg1' }, 'password');
    });

    it('should reject an empty password', async () => {
      await expectInvalid({ password: '' }, 'password');
    });

    it('should reject a password of only numbers', async () => {
      await expectInvalid({ password: '12345678' }, 'password');
    });

    it('should reject a password of only lowercase', async () => {
      await expectInvalid({ password: 'abcdefgh' }, 'password');
    });
  });
});
