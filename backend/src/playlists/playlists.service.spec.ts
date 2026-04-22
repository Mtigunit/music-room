import { Test, TestingModule } from '@nestjs/testing';
import {
  ForbiddenException,
  NotFoundException,
  BadRequestException,
  ConflictException,
  InternalServerErrorException,
} from '@nestjs/common';
import { PlaylistsService } from './playlists.service';
import { PlaylistsRepository } from './playlists.repository';
import { PlaylistsGateway } from './playlists.gateway';
import { YoutubeService } from '../tracks/youtube.service';
import { TrackSearchResultDto } from '../tracks/dto/track-search-result.dto';
import { PlaylistEditLicense, Prisma, Visibility } from '@prisma/client';
import { PlaylistAuthData } from './interfaces/playlist-auth-data.interface';

type PlaylistDetails = NonNullable<
  Awaited<ReturnType<PlaylistsRepository['getPlaylistDetails']>>
>;

const OWNER_ID = 'owner-uuid';
const OTHER_USER_ID = 'other-uuid';
const COLLABORATOR_ID = 'collab-uuid';
const PLAYLIST_ID = 'playlist-uuid';

const sampleTrack: TrackSearchResultDto = {
  providerTrackId: 'dQw4w9WgXcQ',
  title: 'Never Gonna Give You Up',
  artist: 'Rick Astley',
  durationMs: 213000,
  thumbnailUrl: 'https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg',
};

function buildPlaylist(
  overrides: Partial<PlaylistDetails & { _count: { tracks: number } }> = {},
): PlaylistDetails & { _count: { tracks: number } } {
  return {
    id: PLAYLIST_ID,
    name: 'Test Playlist',
    visibility: Visibility.PUBLIC,
    editLicense: PlaylistEditLicense.OPEN,
    description: null,
    tags: [],
    ownerId: OWNER_ID,
    createdAt: new Date(),
    updatedAt: new Date(),
    collaborators: [],
    tracks: [],
    owner: { id: OWNER_ID, username: 'owner' },
    _count: { tracks: 0 },
    ...overrides,
  } as PlaylistDetails & { _count: { tracks: number } };
}

describe('PlaylistsService', () => {
  let service: PlaylistsService;
  let repository: jest.Mocked<PlaylistsRepository>;
  let youtubeService: jest.Mocked<YoutubeService>;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        PlaylistsService,
        {
          provide: PlaylistsRepository,
          useValue: {
            createPlaylist: jest.fn(),
            getUserPlaylists: jest.fn(),
            explorePublicPlaylists: jest.fn(),
            getPlaylistDetails: jest.fn(),
            findPlaylistForAuth: jest.fn(),
            findPlaylistTrack: jest.fn(),
            removeTrackFromPlaylist: jest.fn(),
            updatePlaylist: jest.fn(),
            deletePlaylist: jest.fn(),
            addCollaborator: jest.fn(),
            addTrackToPlaylist: jest.fn(),
            checkUserExists: jest.fn(),
            isTrackInPlaylist: jest.fn(),
          },
        },
        {
          provide: PlaylistsGateway,
          useValue: {
            server: {
              to: jest.fn().mockReturnThis(),
              emit: jest.fn(),
            },
          },
        },
        {
          provide: YoutubeService,
          useValue: {
            getTrackDetails: jest.fn(),
          },
        },
      ],
    }).compile();

    service = module.get<PlaylistsService>(PlaylistsService);
    repository = module.get<PlaylistsRepository>(
      PlaylistsRepository,
    ) as jest.Mocked<PlaylistsRepository>;
    youtubeService = module.get<YoutubeService>(
      YoutubeService,
    ) as jest.Mocked<YoutubeService>;
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  // ─── getPlaylistDetails ────────────────────────────────────

  describe('getPlaylistDetails', () => {
    it('should throw NotFoundException when playlist does not exist', async () => {
      repository.getPlaylistDetails.mockResolvedValueOnce(null);

      await expect(
        service.getPlaylistDetails(PLAYLIST_ID, OWNER_ID),
      ).rejects.toThrow(NotFoundException);
    });

    it('should return a public playlist to any authenticated user', async () => {
      const playlist = buildPlaylist();
      repository.getPlaylistDetails.mockResolvedValueOnce(playlist);

      const result = await service.getPlaylistDetails(
        PLAYLIST_ID,
        OTHER_USER_ID,
      );
      expect(result).toEqual(playlist);
    });

    it('should return a private playlist to the owner', async () => {
      const playlist = buildPlaylist({
        visibility: Visibility.PRIVATE,
      });
      repository.getPlaylistDetails.mockResolvedValueOnce(playlist);

      const result = await service.getPlaylistDetails(PLAYLIST_ID, OWNER_ID);
      expect(result).toEqual(playlist);
    });

    it('should return a private playlist to a collaborator', async () => {
      const playlist = buildPlaylist({
        visibility: Visibility.PRIVATE,
        collaborators: [
          {
            id: 'collab-record',
            playlistId: PLAYLIST_ID,
            userId: COLLABORATOR_ID,
            grantedAt: new Date(),
            user: { id: COLLABORATOR_ID, username: 'collab' },
          },
        ],
      });
      repository.getPlaylistDetails.mockResolvedValueOnce(playlist);

      const result = await service.getPlaylistDetails(
        PLAYLIST_ID,
        COLLABORATOR_ID,
      );
      expect(result).toEqual(playlist);
    });

    it('should throw ForbiddenException for a private playlist when requester is neither owner nor collaborator', async () => {
      const playlist = buildPlaylist({
        visibility: Visibility.PRIVATE,
      });
      repository.getPlaylistDetails.mockResolvedValueOnce(playlist);

      await expect(
        service.getPlaylistDetails(PLAYLIST_ID, OTHER_USER_ID),
      ).rejects.toThrow(ForbiddenException);
    });
  });

  // ─── update ────────────────────────────────────────────────

  describe('update', () => {
    it('should throw NotFoundException when playlist does not exist', async () => {
      repository.findPlaylistForAuth.mockResolvedValueOnce(null);

      await expect(
        service.update(PLAYLIST_ID, OWNER_ID, { name: 'New' }),
      ).rejects.toThrow(NotFoundException);
    });

    it('should throw ForbiddenException when a non-owner tries to update', async () => {
      repository.findPlaylistForAuth.mockResolvedValueOnce(
        buildPlaylist() as PlaylistAuthData,
      );

      await expect(
        service.update(PLAYLIST_ID, OTHER_USER_ID, { name: 'New' }),
      ).rejects.toThrow(ForbiddenException);
    });

    it('should allow the owner to update the playlist', async () => {
      repository.findPlaylistForAuth.mockResolvedValueOnce(
        buildPlaylist() as PlaylistAuthData,
      );
      repository.updatePlaylist.mockResolvedValueOnce({} as never);

      await service.update(PLAYLIST_ID, OWNER_ID, { name: 'New' });

      expect(repository.updatePlaylist).toHaveBeenCalledWith(PLAYLIST_ID, {
        name: 'New',
      });
    });
  });

  // ─── remove ────────────────────────────────────────────────

  describe('remove', () => {
    it('should throw NotFoundException when playlist does not exist', async () => {
      repository.findPlaylistForAuth.mockResolvedValueOnce(null);

      await expect(service.remove(PLAYLIST_ID, OWNER_ID)).rejects.toThrow(
        NotFoundException,
      );
    });

    it('should throw ForbiddenException when a non-owner tries to delete', async () => {
      repository.findPlaylistForAuth.mockResolvedValueOnce(
        buildPlaylist() as PlaylistAuthData,
      );

      await expect(service.remove(PLAYLIST_ID, OTHER_USER_ID)).rejects.toThrow(
        ForbiddenException,
      );
    });

    it('should allow the owner to delete the playlist', async () => {
      repository.findPlaylistForAuth.mockResolvedValueOnce(
        buildPlaylist() as PlaylistAuthData,
      );
      repository.deletePlaylist.mockResolvedValueOnce({} as never);

      await service.remove(PLAYLIST_ID, OWNER_ID);

      expect(repository.deletePlaylist).toHaveBeenCalledWith(PLAYLIST_ID);
    });
  });

  // ─── addCollaborator ───────────────────────────────────────

  describe('addCollaborator', () => {
    it('should throw NotFoundException when playlist does not exist', async () => {
      repository.findPlaylistForAuth.mockResolvedValueOnce(null);

      await expect(
        service.addCollaborator(PLAYLIST_ID, OWNER_ID, OTHER_USER_ID),
      ).rejects.toThrow(NotFoundException);
    });

    it('should throw ForbiddenException when a non-owner tries to add a collaborator', async () => {
      repository.findPlaylistForAuth.mockResolvedValueOnce(
        buildPlaylist() as PlaylistAuthData,
      );

      await expect(
        service.addCollaborator(PLAYLIST_ID, OTHER_USER_ID, COLLABORATOR_ID),
      ).rejects.toThrow(ForbiddenException);
    });

    it('should throw BadRequestException when the target user does not exist', async () => {
      repository.findPlaylistForAuth.mockResolvedValueOnce(
        buildPlaylist() as PlaylistAuthData,
      );
      repository.checkUserExists.mockResolvedValueOnce(false);

      await expect(
        service.addCollaborator(PLAYLIST_ID, OWNER_ID, 'ghost-uuid'),
      ).rejects.toThrow('Target user does not exist');
    });

    it('should add a collaborator when all checks pass', async () => {
      repository.findPlaylistForAuth.mockResolvedValueOnce(
        buildPlaylist() as PlaylistAuthData,
      );
      repository.checkUserExists.mockResolvedValueOnce(true);
      repository.addCollaborator.mockResolvedValueOnce({} as never);

      await service.addCollaborator(PLAYLIST_ID, OWNER_ID, COLLABORATOR_ID);

      expect(repository.addCollaborator).toHaveBeenCalledWith(
        PLAYLIST_ID,
        COLLABORATOR_ID,
      );
    });
  });

  // ─── addTrackToPlaylist ────────────────────────────────────

  describe('addTrackToPlaylist', () => {
    it('should throw NotFoundException when playlist does not exist', async () => {
      repository.findPlaylistForAuth.mockResolvedValueOnce(null);

      await expect(
        service.addTrackToPlaylist(
          PLAYLIST_ID,
          OWNER_ID,
          sampleTrack.providerTrackId,
        ),
      ).rejects.toThrow(NotFoundException);
    });

    it('should allow any user to add a track when editLicense is OPEN', async () => {
      repository.findPlaylistForAuth.mockResolvedValueOnce(
        buildPlaylist() as PlaylistAuthData,
      );
      youtubeService.getTrackDetails.mockResolvedValueOnce(sampleTrack);
      repository.isTrackInPlaylist.mockResolvedValueOnce(false);
      repository.addTrackToPlaylist.mockResolvedValueOnce({} as never);

      await service.addTrackToPlaylist(
        PLAYLIST_ID,
        OTHER_USER_ID,
        sampleTrack.providerTrackId,
      );

      expect(repository.addTrackToPlaylist).toHaveBeenCalledWith(
        PLAYLIST_ID,
        OTHER_USER_ID,
        sampleTrack,
      );
    });

    it('should allow the owner to add a track when editLicense is RESTRICTED', async () => {
      repository.findPlaylistForAuth.mockResolvedValueOnce(
        buildPlaylist({
          editLicense: PlaylistEditLicense.RESTRICTED,
        }) as PlaylistAuthData,
      );
      youtubeService.getTrackDetails.mockResolvedValueOnce(sampleTrack);
      repository.isTrackInPlaylist.mockResolvedValueOnce(false);
      repository.addTrackToPlaylist.mockResolvedValueOnce({} as never);

      await service.addTrackToPlaylist(
        PLAYLIST_ID,
        OWNER_ID,
        sampleTrack.providerTrackId,
      );

      expect(repository.addTrackToPlaylist).toHaveBeenCalledWith(
        PLAYLIST_ID,
        OWNER_ID,
        sampleTrack,
      );
    });

    it('should allow a collaborator to add a track when editLicense is RESTRICTED', async () => {
      repository.findPlaylistForAuth.mockResolvedValueOnce(
        buildPlaylist({
          editLicense: PlaylistEditLicense.RESTRICTED,
          collaborators: [
            {
              id: 'collab-record',
              playlistId: PLAYLIST_ID,
              userId: COLLABORATOR_ID,
              grantedAt: new Date(),
              user: { id: COLLABORATOR_ID, username: 'collab' },
            },
          ],
        }) as PlaylistAuthData,
      );
      youtubeService.getTrackDetails.mockResolvedValueOnce(sampleTrack);
      repository.isTrackInPlaylist.mockResolvedValueOnce(false);
      repository.addTrackToPlaylist.mockResolvedValueOnce({} as never);

      await service.addTrackToPlaylist(
        PLAYLIST_ID,
        COLLABORATOR_ID,
        sampleTrack.providerTrackId,
      );

      expect(repository.addTrackToPlaylist).toHaveBeenCalledWith(
        PLAYLIST_ID,
        COLLABORATOR_ID,
        sampleTrack,
      );
    });

    it('should throw ForbiddenException when an unauthorized user adds a track to a RESTRICTED playlist', async () => {
      repository.findPlaylistForAuth.mockResolvedValueOnce(
        buildPlaylist({
          editLicense: PlaylistEditLicense.RESTRICTED,
        }) as PlaylistAuthData,
      );

      await expect(
        service.addTrackToPlaylist(
          PLAYLIST_ID,
          OTHER_USER_ID,
          sampleTrack.providerTrackId,
        ),
      ).rejects.toThrow(ForbiddenException);
    });

    it('should throw BadRequestException when playlist capacity is reached (300 tracks)', async () => {
      repository.findPlaylistForAuth.mockResolvedValueOnce(
        buildPlaylist({ _count: { tracks: 300 } }) as PlaylistAuthData,
      );

      await expect(
        service.addTrackToPlaylist(
          PLAYLIST_ID,
          OWNER_ID,
          sampleTrack.providerTrackId,
        ),
      ).rejects.toThrow(BadRequestException);
    });

    it('should throw NotFoundException when track is not found by provider', async () => {
      repository.findPlaylistForAuth.mockResolvedValueOnce(
        buildPlaylist() as PlaylistAuthData,
      );
      youtubeService.getTrackDetails.mockResolvedValueOnce(null);

      await expect(
        service.addTrackToPlaylist(
          PLAYLIST_ID,
          OWNER_ID,
          sampleTrack.providerTrackId,
        ),
      ).rejects.toThrow(NotFoundException);
    });

    it('should throw ConflictException when track already exists in playlist', async () => {
      repository.findPlaylistForAuth.mockResolvedValueOnce(
        buildPlaylist() as PlaylistAuthData,
      );
      youtubeService.getTrackDetails.mockResolvedValueOnce(sampleTrack);
      repository.isTrackInPlaylist.mockResolvedValueOnce(true);

      await expect(
        service.addTrackToPlaylist(
          PLAYLIST_ID,
          OWNER_ID,
          sampleTrack.providerTrackId,
        ),
      ).rejects.toThrow(ConflictException);
    });

    it('should throw ConflictException if the repository fails due to a unique constraint violation (race condition)', async () => {
      // Use mockResolvedValue instead of mockResolvedValueOnce because we call the service twice in this test
      repository.findPlaylistForAuth.mockResolvedValue(
        buildPlaylist() as PlaylistAuthData,
      );
      youtubeService.getTrackDetails.mockResolvedValue(sampleTrack);
      repository.isTrackInPlaylist.mockResolvedValue(false);

      const prismaError = new Prisma.PrismaClientKnownRequestError(
        'Unique constraint failed',
        {
          code: 'P2002',
          clientVersion: '5.0.0',
          meta: { target: ['trackId'] },
        },
      );
      repository.addTrackToPlaylist.mockRejectedValue(prismaError);

      await expect(
        service.addTrackToPlaylist(
          PLAYLIST_ID,
          OWNER_ID,
          sampleTrack.providerTrackId,
        ),
      ).rejects.toThrow(ConflictException);

      const error = await service
        .addTrackToPlaylist(PLAYLIST_ID, OWNER_ID, sampleTrack.providerTrackId)
        .catch((e) => e);
      expect(error.message).toBe('This track is already in the playlist');
    });

    it('should rethrow a P2002 error if it targets a different field (e.g., position collision)', async () => {
      repository.findPlaylistForAuth.mockResolvedValueOnce(
        buildPlaylist() as PlaylistAuthData,
      );
      youtubeService.getTrackDetails.mockResolvedValueOnce(sampleTrack);
      repository.isTrackInPlaylist.mockResolvedValueOnce(false);

      const prismaError = new Prisma.PrismaClientKnownRequestError(
        'Unique constraint failed on position',
        {
          code: 'P2002',
          clientVersion: '5.0.0',
          meta: { target: ['position'] },
        },
      );
      repository.addTrackToPlaylist.mockRejectedValueOnce(prismaError);

      await expect(
        service.addTrackToPlaylist(
          PLAYLIST_ID,
          OWNER_ID,
          sampleTrack.providerTrackId,
        ),
      ).rejects.toThrow(Prisma.PrismaClientKnownRequestError);
    });

    it('should propagate InternalServerErrorException when provider service fails', async () => {
      repository.findPlaylistForAuth.mockResolvedValueOnce(
        buildPlaylist() as PlaylistAuthData,
      );
      youtubeService.getTrackDetails.mockRejectedValueOnce(
        new InternalServerErrorException(
          'Failed to fetch YouTube track details',
        ),
      );

      await expect(
        service.addTrackToPlaylist(
          PLAYLIST_ID,
          OWNER_ID,
          sampleTrack.providerTrackId,
        ),
      ).rejects.toThrow(InternalServerErrorException);
    });
  });

  // ─── removeTrackFromPlaylist ──────────────────────────────

  describe('removeTrackFromPlaylist', () => {
    const PLAYLIST_TRACK_ID = 'track-entry-uuid';
    const ADDER_ID = 'adder-uuid';

    const mockPlaylistTrack = {
      id: PLAYLIST_TRACK_ID,
      playlistId: PLAYLIST_ID,
      trackId: 'track-dict-uuid',
      position: 2,
      addedById: ADDER_ID,
      addedAt: new Date(),
      track: {
        id: 'track-dict-uuid',
        providerTrackId: 'dQw4w9WgXcQ',
        title: 'Never Gonna Give You Up',
        artist: 'Rick Astley',
        durationMs: 213000,
        thumbnailUrl: 'https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg',
      },
    };

    it('should throw NotFoundException when playlist does not exist', async () => {
      repository.findPlaylistForAuth.mockResolvedValueOnce(null);

      await expect(
        service.removeTrackFromPlaylist(
          PLAYLIST_ID,
          PLAYLIST_TRACK_ID,
          OWNER_ID,
        ),
      ).rejects.toThrow(NotFoundException);
    });

    it('should throw NotFoundException when track does not exist in playlist', async () => {
      repository.findPlaylistForAuth.mockResolvedValueOnce(
        buildPlaylist() as PlaylistAuthData,
      );
      repository.findPlaylistTrack.mockResolvedValueOnce(null);

      await expect(
        service.removeTrackFromPlaylist(
          PLAYLIST_ID,
          PLAYLIST_TRACK_ID,
          OWNER_ID,
        ),
      ).rejects.toThrow(NotFoundException);
    });

    it('should throw NotFoundException when track exists but belongs to a different playlist', async () => {
      repository.findPlaylistForAuth.mockResolvedValueOnce(
        buildPlaylist({ id: PLAYLIST_ID }) as PlaylistAuthData,
      );
      // Repository returns null because it now scopes the lookup by playlistId
      repository.findPlaylistTrack.mockResolvedValueOnce(null);

      await expect(
        service.removeTrackFromPlaylist(
          PLAYLIST_ID,
          'track-from-another-playlist',
          OWNER_ID,
        ),
      ).rejects.toThrow(NotFoundException);

      expect(repository.removeTrackFromPlaylist).not.toHaveBeenCalled();
    });

    it('should allow the playlist owner to remove any track', async () => {
      repository.findPlaylistForAuth.mockResolvedValueOnce(
        buildPlaylist() as PlaylistAuthData,
      );
      repository.findPlaylistTrack.mockResolvedValueOnce(
        mockPlaylistTrack as never,
      );
      repository.removeTrackFromPlaylist.mockResolvedValueOnce({
        deletedTrack: mockPlaylistTrack,
        updates: [],
      } as never);

      const result = await service.removeTrackFromPlaylist(
        PLAYLIST_ID,
        PLAYLIST_TRACK_ID,
        OWNER_ID,
      );

      expect(repository.removeTrackFromPlaylist).toHaveBeenCalledWith(
        PLAYLIST_ID,
        PLAYLIST_TRACK_ID,
      );
      expect(result).toEqual(mockPlaylistTrack);
    });

    it('should allow the user who added the track to remove it', async () => {
      repository.findPlaylistForAuth.mockResolvedValueOnce(
        buildPlaylist() as PlaylistAuthData,
      );
      repository.findPlaylistTrack.mockResolvedValueOnce(
        mockPlaylistTrack as never,
      );
      repository.removeTrackFromPlaylist.mockResolvedValueOnce({
        deletedTrack: mockPlaylistTrack,
        updates: [],
      } as never);

      const result = await service.removeTrackFromPlaylist(
        PLAYLIST_ID,
        PLAYLIST_TRACK_ID,
        ADDER_ID,
      );

      expect(repository.removeTrackFromPlaylist).toHaveBeenCalledWith(
        PLAYLIST_ID,
        PLAYLIST_TRACK_ID,
      );
      expect(result).toEqual(mockPlaylistTrack);
    });

    it('should throw ForbiddenException when a non-owner tries to remove a track they did not add', async () => {
      repository.findPlaylistForAuth.mockResolvedValueOnce(
        buildPlaylist() as PlaylistAuthData,
      );
      repository.findPlaylistTrack.mockResolvedValueOnce(
        mockPlaylistTrack as never,
      );

      await expect(
        service.removeTrackFromPlaylist(
          PLAYLIST_ID,
          PLAYLIST_TRACK_ID,
          OTHER_USER_ID,
        ),
      ).rejects.toThrow(ForbiddenException);

      expect(repository.removeTrackFromPlaylist).not.toHaveBeenCalled();
    });

    it('should emit a WebSocket event when a track is successfully removed', async () => {
      const gateway = {
        server: { to: jest.fn().mockReturnThis(), emit: jest.fn() },
      };
      // Re-bind the gateway mock for this specific test
      const module: TestingModule = await Test.createTestingModule({
        providers: [
          PlaylistsService,
          { provide: PlaylistsRepository, useValue: repository },
          { provide: PlaylistsGateway, useValue: gateway },
          { provide: YoutubeService, useValue: youtubeService },
        ],
      }).compile();
      const svc = module.get<PlaylistsService>(PlaylistsService);

      repository.findPlaylistForAuth.mockResolvedValueOnce(
        buildPlaylist() as PlaylistAuthData,
      );
      repository.findPlaylistTrack.mockResolvedValueOnce(
        mockPlaylistTrack as never,
      );
      repository.removeTrackFromPlaylist.mockResolvedValueOnce({
        deletedTrack: mockPlaylistTrack,
        updates: [{ trackId: 'uuid1', position: 3 }],
      } as never);

      await svc.removeTrackFromPlaylist(
        PLAYLIST_ID,
        PLAYLIST_TRACK_ID,
        OWNER_ID,
      );

      expect(gateway.server.to).toHaveBeenCalledWith(`playlist_${PLAYLIST_ID}`);
      expect(gateway.server.emit).toHaveBeenCalledWith(
        'playlist:track:removed',
        {
          playlistId: PLAYLIST_ID,
          deletedTrackId: PLAYLIST_TRACK_ID,
          updates: [{ trackId: 'uuid1', position: 3 }],
        },
      );
    });

    it('should not emit a WebSocket event when repository returns null', async () => {
      const gateway = {
        server: { to: jest.fn().mockReturnThis(), emit: jest.fn() },
      };
      const module: TestingModule = await Test.createTestingModule({
        providers: [
          PlaylistsService,
          { provide: PlaylistsRepository, useValue: repository },
          { provide: PlaylistsGateway, useValue: gateway },
          { provide: YoutubeService, useValue: youtubeService },
        ],
      }).compile();
      const svc = module.get<PlaylistsService>(PlaylistsService);

      repository.findPlaylistForAuth.mockResolvedValueOnce(
        buildPlaylist() as PlaylistAuthData,
      );
      repository.findPlaylistTrack.mockResolvedValueOnce(
        mockPlaylistTrack as never,
      );
      repository.removeTrackFromPlaylist.mockResolvedValueOnce(null);

      await expect(
        svc.removeTrackFromPlaylist(PLAYLIST_ID, PLAYLIST_TRACK_ID, OWNER_ID),
      ).rejects.toThrow(NotFoundException);

      expect(gateway.server.to).not.toHaveBeenCalled();
      expect(gateway.server.emit).not.toHaveBeenCalled();
    });
  });
});
