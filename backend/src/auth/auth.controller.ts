import { Throttle } from '@nestjs/throttler';
import {
  Controller,
  Post,
  Get,
  Body,
  UseGuards,
  Request,
} from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiResponse,
  ApiBearerAuth,
} from '@nestjs/swagger';
import { AuthService } from './auth.service';
import { OtpService } from '../otp/otp.service';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';
import { SendOtpDto } from './dto/send-otp.dto';
import { VerifyOtpDto } from './dto/verify-otp.dto';
import { ForgotPasswordDto } from './dto/forgot-password.dto';
import { VerifyResetOtpDto } from './dto/verify-reset-otp.dto';
import { ResetPasswordDto } from './dto/reset-password.dto';
import { GoogleLoginDto } from './dto/google-login.dto';
import { AuthResponseDto } from './dto/auth-response.dto';
import { JwtAuthGuard } from './guards/jwt-auth.guard';
import { ClientMeta } from '../common/decorators/client-meta.decorator';
import { ApiClientMeta } from '../common/decorators/api-client-meta.decorator';
import { ClientMetaDto } from '../common/dto/client-meta.dto';

interface AuthenticatedRequest {
  user: { id: string; email: string };
}

@ApiTags('Auth')
@Throttle({
  default: {
    ttl: parseInt(process.env.RATE_LIMIT_AUTH_TTL_MS || '60000', 10),
    limit: parseInt(process.env.RATE_LIMIT_AUTH_LIMIT || '10', 10),
  },
})
@Controller('auth')
export class AuthController {
  constructor(
    private readonly authService: AuthService,
    private readonly otpService: OtpService,
  ) {}

  @Post('send-otp')
  @ApiOperation({ summary: 'Send OTP verification code to email' })
  @ApiResponse({ status: 201, description: 'OTP sent successfully.' })
  @ApiResponse({ status: 409, description: 'Email already registered.' })
  @ApiResponse({ status: 400, description: 'Rate limit exceeded.' })
  async sendOtp(@Body() dto: SendOtpDto) {
    await this.authService.sendRegistrationOtp(dto.email);
    return { message: 'OTP sent successfully' };
  }

  @Post('verify-otp')
  @ApiOperation({ summary: 'Verify OTP code and receive verification token' })
  @ApiResponse({
    status: 201,
    description: 'OTP verified. Returns emailVerificationToken.',
  })
  @ApiResponse({ status: 400, description: 'Invalid or expired OTP.' })
  async verifyOtp(@Body() dto: VerifyOtpDto) {
    const { token } = await this.otpService.verifyOtp(dto.email, dto.code);
    return { emailVerificationToken: token };
  }

  @Post('register')
  @ApiClientMeta()
  @ApiOperation({ summary: 'Register a new user with verified email' })
  @ApiResponse({
    status: 201,
    description: 'User registered successfully.',
    type: AuthResponseDto,
  })
  @ApiResponse({ status: 400, description: 'Invalid verification token.' })
  @ApiResponse({ status: 409, description: 'Email or username already taken.' })
  async register(
    @Body() dto: RegisterDto,
    @ClientMeta() meta: ClientMetaDto,
  ): Promise<AuthResponseDto> {
    return this.authService.register(dto, meta);
  }

  @Post('login')
  @ApiClientMeta()
  @ApiOperation({ summary: 'Login with email/username and password' })
  @ApiResponse({
    status: 201,
    description: 'Login successful.',
    type: AuthResponseDto,
  })
  @ApiResponse({ status: 401, description: 'Invalid credentials.' })
  async login(
    @Body() dto: LoginDto,
    @ClientMeta() meta: ClientMetaDto,
  ): Promise<AuthResponseDto> {
    return this.authService.login(dto, meta);
  }

  @Post('google')
  @ApiClientMeta()
  @ApiOperation({ summary: 'Login or Register with Google' })
  @ApiResponse({
    status: 201,
    description: 'Google Auth successful.',
    type: AuthResponseDto,
  })
  @ApiResponse({ status: 401, description: 'Invalid Google ID Token.' })
  async googleAuth(
    @Body() dto: GoogleLoginDto,
    @ClientMeta() meta: ClientMetaDto,
  ): Promise<AuthResponseDto> {
    return this.authService.googleAuth(dto.idToken, meta);
  }

  @Post('forgot-password')
  @ApiOperation({ summary: 'Send OTP for password reset' })
  @ApiResponse({
    status: 201,
    description:
      'Request accepted. If the email is registered, a reset OTP will be sent.',
  })
  @ApiResponse({
    status: 400,
    description: 'Rate limited.',
  })
  async forgotPassword(@Body() dto: ForgotPasswordDto) {
    await this.authService.sendPasswordResetOtp(dto.email);
    return {
      message:
        'If an account with this email exists, a password reset OTP has been sent.',
    };
  }

  @Post('verify-reset-otp')
  @ApiOperation({
    summary: 'Verify password reset OTP and receive proof token',
  })
  @ApiResponse({
    status: 201,
    description: 'OTP verified. Returns passwordResetToken.',
  })
  @ApiResponse({ status: 400, description: 'Invalid or expired OTP.' })
  async verifyResetOtp(@Body() dto: VerifyResetOtpDto) {
    const { token } = await this.otpService.verifyOtp(
      dto.email,
      dto.code,
      'password_reset',
    );
    return { passwordResetToken: token };
  }

  @Post('reset-password')
  @ApiClientMeta()
  @ApiOperation({ summary: 'Reset password using the proof token' })
  @ApiResponse({ status: 200, description: 'Password reset successfully.' })
  @ApiResponse({ status: 400, description: 'Invalid or expired reset token.' })
  async resetPassword(
    @Body() dto: ResetPasswordDto,
    @ClientMeta() meta: ClientMetaDto,
  ) {
    await this.authService.resetPassword(dto, meta);
    return { message: 'Password has been reset successfully' };
  }

  @Get('profile')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Get the authenticated user profile' })
  @ApiResponse({ status: 200, description: 'User profile returned.' })
  @ApiResponse({ status: 401, description: 'Unauthorized.' })
  getProfile(@Request() req: AuthenticatedRequest) {
    return req.user;
  }

  @Post('logout-all')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiClientMeta()
  @ApiOperation({
    summary: 'Logout from all devices (invalidates all sessions)',
  })
  @ApiResponse({ status: 200, description: 'Logged out from all devices.' })
  @ApiResponse({ status: 401, description: 'Unauthorized.' })
  async logoutAll(
    @Request() req: AuthenticatedRequest,
    @ClientMeta() meta: ClientMetaDto,
  ) {
    await this.authService.logoutAll(req.user.id, meta);
    return { message: 'Successfully logged out from all devices' };
  }
}
