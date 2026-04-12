import { Controller, Get } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse } from '@nestjs/swagger';
import { AppService } from './app.service';

@ApiTags('App')
@Controller()
export class AppController {
  constructor(private readonly appService: AppService) {}

  @Get()
  @ApiOperation({ summary: 'Get Hello World message' })
  @ApiResponse({ status: 200, description: 'Returns Hello World message.' })
  getHello(): string {
    return this.appService.getHello();
  }

  // @Get('db-test')
  // async testDbQuery() {
  //   return this.appService.testDbQuery();
  // }
}
