import {
  Controller,
  Get,
  Post,
  Body,
  Patch,
  Param,
  Delete,
  ParseIntPipe,
} from '@nestjs/common';
import {
  ApiTags,
  ApiOperation,
  ApiResponse,
  ApiParam,
  ApiBody,
} from '@nestjs/swagger';
import { AuthService } from './auth.service';
import { CreateAuthDto } from './dto/create-auth.dto';
import { UpdateAuthDto } from './dto/update-auth.dto';

@ApiTags('Auth')
@Controller('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post()
  @ApiOperation({ summary: 'Create a new auth record' })
  @ApiBody({ type: CreateAuthDto })
  @ApiResponse({ status: 201, description: 'Auth record created.' })
  create(@Body() createAuthDto: CreateAuthDto) {
    return this.authService.create(createAuthDto);
  }

  @Get()
  @ApiOperation({ summary: 'Get all auth records' })
  @ApiResponse({ status: 200, description: 'List of auth records.' })
  findAll() {
    return this.authService.findAll();
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get an auth record by ID' })
  @ApiParam({ name: 'id', type: Number })
  @ApiResponse({ status: 200, description: 'Auth record found.' })
  @ApiResponse({ status: 404, description: 'Auth record not found.' })
  findOne(@Param('id', ParseIntPipe) id: number) {
    return this.authService.findOne(id);
  }

  @Patch(':id')
  @ApiOperation({ summary: 'Update an auth record by ID' })
  @ApiParam({ name: 'id', type: Number })
  @ApiBody({ type: UpdateAuthDto })
  @ApiResponse({ status: 200, description: 'Auth record updated.' })
  @ApiResponse({ status: 404, description: 'Auth record not found.' })
  update(
    @Param('id', ParseIntPipe) id: number,
    @Body() updateAuthDto: UpdateAuthDto,
  ) {
    return this.authService.update(id, updateAuthDto);
  }

  @Delete(':id')
  @ApiOperation({ summary: 'Delete an auth record by ID' })
  @ApiParam({ name: 'id', type: Number })
  @ApiResponse({ status: 200, description: 'Auth record deleted.' })
  @ApiResponse({ status: 404, description: 'Auth record not found.' })
  remove(@Param('id', ParseIntPipe) id: number) {
    return this.authService.remove(id);
  }
}
