import { Test, TestingModule } from '@nestjs/testing';
import { DelegationsService } from './delegations.service';
import { DelegationsRepository } from './delegations.repository';
import { UserRepository } from '../users/user.repository';
import { EventEmitter2 } from '@nestjs/event-emitter';
import {
  ForbiddenException,
  NotFoundException,
  ConflictException,
} from '@nestjs/common';
import { AUDIT_LOG_EVENT } from '../audit-log/audit-log.constants';
import { INTERNAL_EVENTS } from '../events/events.constants';

describe('DelegationsService', () => {
  let service: DelegationsService;
  let repository: jest.Mocked<DelegationsRepository>;
  let userRepository: jest.Mocked<UserRepository>;
  let eventEmitter: jest.Mocked<EventEmitter2>;

  const mockMeta = {
    ipAddress: '127.0.0.1',
    platform: 'test',
    deviceModel: 'test',
    appVersion: '1.0.0',
  } as any;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        DelegationsService,
        {
          provide: DelegationsRepository,
          useValue: {
            findEventById: jest.fn(),
            findActive: jest.fn(),
            createPending: jest.fn(),
            deletePending: jest.fn(),
            activateById: jest.fn(),
            revoke: jest.fn(),
            findByEventId: jest.fn(),
          },
        },
        {
          provide: UserRepository,
          useValue: {
            findById: jest.fn(),
          },
        },
        {
          provide: EventEmitter2,
          useValue: { emit: jest.fn() },
        },
      ],
    }).compile();

    service = module.get<DelegationsService>(DelegationsService);
    repository = module.get(DelegationsRepository);
    userRepository = module.get(UserRepository);
    eventEmitter = module.get(EventEmitter2);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  describe('grant', () => {
    it('should grant delegation when host is valid', async () => {
      const eventId = 'event-1';
      const hostId = 'host-1';
      const delegateeId = 'user-2';

      repository.findEventById.mockResolvedValue({
        id: eventId,
        hostId,
        name: 'Test Event',
      } as any);
      userRepository.findById.mockResolvedValue({
        id: delegateeId,
        username: 'testuser',
      } as any);
      repository.findActive.mockResolvedValue(null);
      repository.createPending.mockResolvedValue({ id: 'pending-1' } as any);

      const result = await service.grant(
        eventId,
        hostId,
        delegateeId,
        mockMeta,
      );

      expect(repository.createPending).toHaveBeenCalledWith(
        eventId,
        delegateeId,
      );
      expect(eventEmitter.emit).toHaveBeenCalledWith(
        INTERNAL_EVENTS.DELEGATION_INVITE_SENT,
        expect.objectContaining({
          eventId,
          delegateeId,
          delegationId: 'pending-1',
        }),
      );
      expect(eventEmitter.emit).toHaveBeenCalledWith(
        AUDIT_LOG_EVENT,
        expect.objectContaining({ action: 'DELEGATION_GRANT' }),
      );
      expect(result).toEqual({
        message: 'Delegation invite sent successfully',
        delegationId: 'pending-1',
      });
    });

    it('should throw ConflictException if active delegation already exists', async () => {
      const eventId = 'event-1';
      const hostId = 'host-1';
      const delegateeId = 'user-2';

      repository.findEventById.mockResolvedValue({
        id: eventId,
        hostId,
      } as any);
      userRepository.findById.mockResolvedValue({ id: delegateeId } as any);
      repository.findActive.mockResolvedValue({ id: 'active-1' } as any);

      await expect(
        service.grant(eventId, hostId, delegateeId, mockMeta),
      ).rejects.toThrow(ConflictException);
    });

    it('should throw ForbiddenException when non-host tries to grant', async () => {
      const eventId = 'event-1';
      const hostId = 'user-2';
      const delegateeId = 'user-3';

      repository.findEventById.mockResolvedValue({
        id: eventId,
        hostId: 'host-1',
      } as any);

      await expect(
        service.grant(eventId, hostId, delegateeId, mockMeta),
      ).rejects.toThrow(ForbiddenException);
    });

    it('should throw ForbiddenException when host delegates to self', async () => {
      const eventId = 'event-1';
      const hostId = 'host-1';

      repository.findEventById.mockResolvedValue({
        id: eventId,
        hostId,
      } as any);

      await expect(
        service.grant(eventId, hostId, hostId, mockMeta),
      ).rejects.toThrow(ForbiddenException);
    });

    it('should throw NotFoundException when event does not exist', async () => {
      repository.findEventById.mockResolvedValue(null);

      await expect(
        service.grant('event-1', 'host-1', 'user-2', mockMeta),
      ).rejects.toThrow(NotFoundException);
    });

    it('should throw NotFoundException when delegatee does not exist', async () => {
      const eventId = 'event-1';
      const hostId = 'host-1';
      const delegateeId = 'user-2';

      repository.findEventById.mockResolvedValue({
        id: eventId,
        hostId,
      } as any);
      userRepository.findById.mockResolvedValue(null);

      await expect(
        service.grant(eventId, hostId, delegateeId, mockMeta),
      ).rejects.toThrow(NotFoundException);
    });
  });

  describe('revoke', () => {
    it('should revoke delegation when host is valid', async () => {
      const eventId = 'event-1';
      const hostId = 'host-1';
      const delegateeId = 'user-2';

      repository.findEventById.mockResolvedValue({
        id: eventId,
        hostId,
      } as any);
      repository.revoke.mockResolvedValue({ count: 1 } as any);

      const result = await service.revoke(
        eventId,
        hostId,
        delegateeId,
        mockMeta,
      );

      expect(result.message).toBe('Delegation revoked successfully');
      expect(eventEmitter.emit).toHaveBeenCalledWith(
        AUDIT_LOG_EVENT,
        expect.objectContaining({ action: 'DELEGATION_REVOKE' }),
      );
    });

    it('should throw ForbiddenException when non-host tries to revoke', async () => {
      const eventId = 'event-1';
      const hostId = 'user-2';
      const delegateeId = 'user-3';

      repository.findEventById.mockResolvedValue({
        id: eventId,
        hostId: 'host-1',
      } as any);

      await expect(
        service.revoke(eventId, hostId, delegateeId, mockMeta),
      ).rejects.toThrow(ForbiddenException);
    });
  });

  describe('list', () => {
    it('should return active delegations for host', async () => {
      const eventId = 'event-1';
      const hostId = 'host-1';
      const mockDelegations = [
        { id: 'del-1', delegateeId: 'user-2', isActive: true },
      ];

      repository.findEventById.mockResolvedValue({
        id: eventId,
        hostId,
      } as any);
      repository.findByEventId.mockResolvedValue(mockDelegations as any);

      const result = await service.list(eventId, hostId);

      expect(result).toEqual(mockDelegations);
    });

    it('should throw ForbiddenException when non-host tries to list', async () => {
      const eventId = 'event-1';
      const hostId = 'user-2';

      repository.findEventById.mockResolvedValue({
        id: eventId,
        hostId: 'host-1',
      } as any);

      await expect(service.list(eventId, hostId)).rejects.toThrow(
        ForbiddenException,
      );
    });
  });

  describe('handleResponse', () => {
    it('should activate delegation on accept', async () => {
      const delegationId = 'pending-1';
      const deviceId = 'device-1';
      repository.activateById.mockResolvedValue({ count: 1 } as any);

      const result = await service.handleResponse(delegationId, true, deviceId);

      expect(repository.activateById).toHaveBeenCalledWith(
        delegationId,
        deviceId,
      );
      expect(result).toEqual({ status: 'accepted' });
    });

    it('should return already_accepted if count is 0 on accept', async () => {
      const delegationId = 'pending-1';
      const deviceId = 'device-1';
      repository.activateById.mockResolvedValue({ count: 0 } as any);

      const result = await service.handleResponse(delegationId, true, deviceId);

      expect(result).toEqual({ status: 'accepted' });
    });
  });
});
