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
import { JwtAuthGuard } from './guards/jwt-auth.guard';

interface AuthenticatedRequest {
  user: { id: string; email: string };
}

@ApiTags('Auth')
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
    await this.otpService.sendOtp(dto.email);
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
  @ApiOperation({ summary: 'Register a new user with verified email' })
  @ApiResponse({ status: 201, description: 'User registered successfully.' })
  @ApiResponse({ status: 400, description: 'Invalid verification token.' })
  @ApiResponse({ status: 409, description: 'Email or username already taken.' })
  async register(@Body() dto: RegisterDto) {
    return this.authService.register(dto);
  }

  @Post('login')
  @ApiOperation({ summary: 'Login with email/username and password' })
  @ApiResponse({ status: 201, description: 'Login successful.' })
  @ApiResponse({ status: 401, description: 'Invalid credentials.' })
  async login(@Body() dto: LoginDto) {
    return this.authService.login(dto);
  }

  @Post('google')
  @ApiOperation({ summary: 'Login or Register with Google' })
  @ApiResponse({ status: 201, description: 'Google Auth successful.' })
  @ApiResponse({ status: 401, description: 'Invalid Google ID Token.' })
  async googleAuth(@Body() dto: GoogleLoginDto) {
    return this.authService.googleAuth(dto.idToken);
  }

  @Post('forgot-password')
  @ApiOperation({ summary: 'Send OTP for password reset' })
  @ApiResponse({ status: 201, description: 'Password reset OTP sent.' })
  @ApiResponse({
    status: 400,
    description: 'User does not exist or rate limited.',
  })
  async forgotPassword(@Body() dto: ForgotPasswordDto) {
    await this.otpService.sendOtp(dto.email, 'password_reset');
    return { message: 'Password reset OTP sent successfully' };
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
  @ApiOperation({ summary: 'Reset password using the proof token' })
  @ApiResponse({ status: 200, description: 'Password reset successfully.' })
  @ApiResponse({ status: 400, description: 'Invalid or expired reset token.' })
  async resetPassword(@Body() dto: ResetPasswordDto) {
    await this.authService.resetPassword(dto);
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
}
