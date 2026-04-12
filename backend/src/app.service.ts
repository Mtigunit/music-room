import { Injectable } from '@nestjs/common';
import { AppRepository } from './app.repository';

@Injectable()
export class AppService {
  constructor(private readonly appRepository: AppRepository) {}

  getHello(): string {
    return 'Hello World!';
  }

  // async testDbQuery() {
  //   return this.appRepository.testDbQuery();
  // }
}
