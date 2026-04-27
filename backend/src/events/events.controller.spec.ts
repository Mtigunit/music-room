import { Test, TestingModule } from '@nestjs/testing';
import { EventsController } from './events.controller';
import { EventsService } from './events.service';
import { EventsRepository } from './events.repository';
import { PrismaService } from '../prisma/prisma.service';
import { EventsGateway } from './events.gateway';
import { YoutubeService } from '../tracks/youtube.service';
import type { Request } from 'express';
import { EventEmitter2 } from '@nestjs/event-emitter';

describe('EventsController', () => {
  let controller: EventsController;
  let service: EventsService;

  const mockUser = { id: 'user-1' };
  const mockReq = { user: mockUser } as unknown as Request;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [EventsController],
      providers: [
        EventsService,
        EventsRepository,
        {
          provide: YoutubeService,
          useValue: {
            getTrackDetails: jest.fn(),
            getTrackDetailsBatch: jest.fn(),
          },
        },
        {
          provide: PrismaService,
          useValue: {
            $transaction: jest.fn(),
            event: {
              create: jest.fn(),
              findMany: jest.fn(),
              findUnique: jest.fn(),
              update: jest.fn(),
              delete: jest.fn(),
            },
          },
        },
        {
          provide: EventsGateway,
          useValue: {
            server: {
              to: jest.fn().mockReturnThis(),
              in: jest.fn().mockReturnThis(),
              socketsLeave: jest.fn(),
              emit: jest.fn(),
            },
          },
        },
        {
          provide: EventEmitter2,
          useValue: { emit: jest.fn() },
        },
      ],
    }).compile();

    controller = module.get<EventsController>(EventsController);
    service = module.get<EventsService>(EventsService);
  });

  it('should be defined', () => {
    expect(controller).toBeDefined();
  });

  describe('create', () => {
    it('should call eventsService.create with correct parameters', async () => {
      const dto = { name: 'Test Event', visibility: 'PUBLIC' } as any;
      const spy = jest
        .spyOn(service, 'create')
        .mockResolvedValue({ id: 'event-1' } as any);

      await controller.create(dto, mockReq);

      expect(spy).toHaveBeenCalledWith(mockUser.id, dto);
    });
  });

  describe('findAll', () => {
    it('should call eventsService.findAll with correct parameters', async () => {
      const page = 1;
      const limit = 10;
      const search = 'test';
      const spy = jest
        .spyOn(service, 'findAll')
        .mockResolvedValue({ data: [], total: 0 } as any);

      await controller.findAll(page, limit, mockReq, search);

      expect(spy).toHaveBeenCalledWith(mockUser.id, { page, limit, search });
    });
  });

  describe('findHosting', () => {
    it('should call eventsService.findHosting with correct parameters', async () => {
      const page = 1;
      const limit = 10;
      const search = 'test';
      const spy = jest
        .spyOn(service, 'findHosting')
        .mockResolvedValue({ data: [], total: 0 } as any);

      await controller.findHosting(page, limit, mockReq, search);

      expect(spy).toHaveBeenCalledWith(mockUser.id, { page, limit, search });
    });
  });

  describe('findInvited', () => {
    it('should call eventsService.findInvited with correct parameters', async () => {
      const page = 1;
      const limit = 10;
      const search = 'test';
      const spy = jest
        .spyOn(service, 'findInvited')
        .mockResolvedValue({ data: [], total: 0 } as any);

      await controller.findInvited(page, limit, mockReq, search);

      expect(spy).toHaveBeenCalledWith(mockUser.id, { page, limit, search });
    });
  });

  describe('findOne', () => {
    it('should call eventsService.findOne with correct parameters', async () => {
      const eventId = '740777df-e348-40b6-925e-4c0f020cf68c';
      const spy = jest
        .spyOn(service, 'findOne')
        .mockResolvedValue({ id: eventId } as any);

      await controller.findOne(eventId, mockReq);

      expect(spy).toHaveBeenCalledWith(eventId, mockUser.id);
    });
  });

  describe('update', () => {
    it('should call eventsService.update with correct parameters', async () => {
      const eventId = '740777df-e348-40b6-925e-4c0f020cf68c';
      const dto = { name: 'Updated Event' } as any;
      const spy = jest
        .spyOn(service, 'update')
        .mockResolvedValue({ id: eventId } as any);

      await controller.update(eventId, dto, mockReq);

      expect(spy).toHaveBeenCalledWith(eventId, mockUser.id, dto);
    });
  });

  describe('inviteUser', () => {
    it('should call eventsService.inviteUser with correct parameters', async () => {
      const eventId = '740777df-e348-40b6-925e-4c0f020cf68c';
      const invitedUserId = 'user-2';
      const dto = { userId: invitedUserId };
      const spy = jest
        .spyOn(service, 'inviteUser')
        .mockResolvedValue({ id: 'invite-1' } as any);

      await controller.inviteUser(eventId, dto, mockReq);

      expect(spy).toHaveBeenCalledWith(eventId, mockUser.id, invitedUserId);
    });
  });

  describe('getTracks', () => {
    it('should call eventsService.getTracks with correct parameters', async () => {
      const eventId = '740777df-e348-40b6-925e-4c0f020cf68c';
      const page = 1;
      const limit = 10;
      const spy = jest.spyOn(service, 'getTracks').mockResolvedValue({
        data: [],
        pagination: { total: 0, page, limit, totalPages: 0 },
      } as any);

      await controller.getTracks(eventId, mockReq, page, limit);

      expect(spy).toHaveBeenCalledWith(eventId, mockUser.id, { page, limit });
    });
  });

  describe('remove', () => {
    it('should call eventsService.remove with correct parameters', async () => {
      const eventId = '740777df-e348-40b6-925e-4c0f020cf68c';
      const spy = jest
        .spyOn(service, 'remove')
        .mockResolvedValue({ message: 'Deleted' } as any);

      await controller.remove(eventId, mockReq);

      expect(spy).toHaveBeenCalledWith(eventId, mockUser.id);
    });
  });

  describe('appendTrack', () => {
    it('should call eventsService.appendTrack with correct parameters', async () => {
      const eventId = '740777df-e348-40b6-925e-4c0f020cf68c';
      const providerTrackId = 'track-123';
      const dto = { providerTrackId };
      const spy = jest
        .spyOn(service, 'appendTrack')
        .mockResolvedValue({ id: 'event-track-1' } as any);

      await controller.appendTrack(eventId, dto, mockReq);

      expect(spy).toHaveBeenCalledWith(eventId, mockUser.id, providerTrackId);
    });
  });

  describe('removeTrack', () => {
    it('should call eventsService.removeTrack with correct parameters', async () => {
      const eventId = '740777df-e348-40b6-925e-4c0f020cf68c';
      const providerTrackId = 'track-123';
      const spy = jest
        .spyOn(service, 'removeTrack')
        .mockResolvedValue({ providerTrackId } as any);

      await controller.removeTrack(eventId, providerTrackId, mockReq);

      expect(spy).toHaveBeenCalledWith(eventId, providerTrackId, mockUser.id);
    });
  });
});
