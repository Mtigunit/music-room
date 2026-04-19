import { Test, TestingModule } from '@nestjs/testing';
import { ForbiddenException, NotFoundException } from '@nestjs/common';
import { PlaylistsService } from './playlists.service';
import { PlaylistsRepository } from './playlists.repository';
import { TrackSearchResultDto } from '../tracks/dto/track-search-result.dto';
import { PlaylistEditLicense, PlaylistVisibility } from '@prisma/client';

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
  overrides: Partial<PlaylistDetails> = {},
): PlaylistDetails {
  return {
    id: PLAYLIST_ID,
    name: 'Test Playlist',
    visibility: PlaylistVisibility.PUBLIC,
    editLicense: PlaylistEditLicense.OPEN,
    description: null,
    tags: [],
    ownerId: OWNER_ID,
    createdAt: new Date(),
    updatedAt: new Date(),
    collaborators: [],
    tracks: [],
    owner: { id: OWNER_ID, username: 'owner' },
    ...overrides,
  } as PlaylistDetails;
}

describe('PlaylistsService', () => {
  let service: PlaylistsService;
  let repository: jest.Mocked<PlaylistsRepository>;

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
            updatePlaylist: jest.fn(),
            deletePlaylist: jest.fn(),
            addCollaborator: jest.fn(),
            addTrackToPlaylist: jest.fn(),
            checkUserExists: jest.fn(),
          },
        },
      ],
    }).compile();

    service = module.get<PlaylistsService>(PlaylistsService);
    repository = module.get<PlaylistsRepository>(
      PlaylistsRepository,
    ) as jest.Mocked<PlaylistsRepository>;
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
        visibility: PlaylistVisibility.PRIVATE,
      });
      repository.getPlaylistDetails.mockResolvedValueOnce(playlist);

      const result = await service.getPlaylistDetails(PLAYLIST_ID, OWNER_ID);
      expect(result).toEqual(playlist);
    });

    it('should return a private playlist to a collaborator', async () => {
      const playlist = buildPlaylist({
        visibility: PlaylistVisibility.PRIVATE,
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
        visibility: PlaylistVisibility.PRIVATE,
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
      repository.getPlaylistDetails.mockResolvedValueOnce(null);

      await expect(
        service.update(PLAYLIST_ID, OWNER_ID, { name: 'New' }),
      ).rejects.toThrow(NotFoundException);
    });

    it('should throw ForbiddenException when a non-owner tries to update', async () => {
      repository.getPlaylistDetails.mockResolvedValueOnce(buildPlaylist());

      await expect(
        service.update(PLAYLIST_ID, OTHER_USER_ID, { name: 'New' }),
      ).rejects.toThrow(ForbiddenException);
    });

    it('should allow the owner to update the playlist', async () => {
      repository.getPlaylistDetails.mockResolvedValueOnce(buildPlaylist());
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
      repository.getPlaylistDetails.mockResolvedValueOnce(null);

      await expect(service.remove(PLAYLIST_ID, OWNER_ID)).rejects.toThrow(
        NotFoundException,
      );
    });

    it('should throw ForbiddenException when a non-owner tries to delete', async () => {
      repository.getPlaylistDetails.mockResolvedValueOnce(buildPlaylist());

      await expect(service.remove(PLAYLIST_ID, OTHER_USER_ID)).rejects.toThrow(
        ForbiddenException,
      );
    });

    it('should allow the owner to delete the playlist', async () => {
      repository.getPlaylistDetails.mockResolvedValueOnce(buildPlaylist());
      repository.deletePlaylist.mockResolvedValueOnce({} as never);

      await service.remove(PLAYLIST_ID, OWNER_ID);

      expect(repository.deletePlaylist).toHaveBeenCalledWith(PLAYLIST_ID);
    });
  });

  // ─── addCollaborator ───────────────────────────────────────

  describe('addCollaborator', () => {
    it('should throw NotFoundException when playlist does not exist', async () => {
      repository.getPlaylistDetails.mockResolvedValueOnce(null);

      await expect(
        service.addCollaborator(PLAYLIST_ID, OWNER_ID, OTHER_USER_ID),
      ).rejects.toThrow(NotFoundException);
    });

    it('should throw ForbiddenException when a non-owner tries to add a collaborator', async () => {
      repository.getPlaylistDetails.mockResolvedValueOnce(buildPlaylist());

      await expect(
        service.addCollaborator(PLAYLIST_ID, OTHER_USER_ID, COLLABORATOR_ID),
      ).rejects.toThrow(ForbiddenException);
    });

    it('should throw BadRequestException when the target user does not exist', async () => {
      repository.getPlaylistDetails.mockResolvedValueOnce(buildPlaylist());
      repository.checkUserExists.mockResolvedValueOnce(false);

      await expect(
        service.addCollaborator(PLAYLIST_ID, OWNER_ID, 'ghost-uuid'),
      ).rejects.toThrow('Target user does not exist');
    });

    it('should add a collaborator when all checks pass', async () => {
      repository.getPlaylistDetails.mockResolvedValueOnce(buildPlaylist());
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
      repository.getPlaylistDetails.mockResolvedValueOnce(null);

      await expect(
        service.addTrackToPlaylist(PLAYLIST_ID, OWNER_ID, sampleTrack),
      ).rejects.toThrow(NotFoundException);
    });

    it('should allow any user to add a track when editLicense is OPEN', async () => {
      repository.getPlaylistDetails.mockResolvedValueOnce(buildPlaylist());
      repository.addTrackToPlaylist.mockResolvedValueOnce({} as never);

      await service.addTrackToPlaylist(PLAYLIST_ID, OTHER_USER_ID, sampleTrack);

      expect(repository.addTrackToPlaylist).toHaveBeenCalledWith(
        PLAYLIST_ID,
        OTHER_USER_ID,
        sampleTrack,
      );
    });

    it('should allow the owner to add a track when editLicense is RESTRICTED', async () => {
      repository.getPlaylistDetails.mockResolvedValueOnce(
        buildPlaylist({ editLicense: PlaylistEditLicense.RESTRICTED }),
      );
      repository.addTrackToPlaylist.mockResolvedValueOnce({} as never);

      await service.addTrackToPlaylist(PLAYLIST_ID, OWNER_ID, sampleTrack);

      expect(repository.addTrackToPlaylist).toHaveBeenCalledWith(
        PLAYLIST_ID,
        OWNER_ID,
        sampleTrack,
      );
    });

    it('should allow a collaborator to add a track when editLicense is RESTRICTED', async () => {
      repository.getPlaylistDetails.mockResolvedValueOnce(
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
        }),
      );
      repository.addTrackToPlaylist.mockResolvedValueOnce({} as never);

      await service.addTrackToPlaylist(
        PLAYLIST_ID,
        COLLABORATOR_ID,
        sampleTrack,
      );

      expect(repository.addTrackToPlaylist).toHaveBeenCalledWith(
        PLAYLIST_ID,
        COLLABORATOR_ID,
        sampleTrack,
      );
    });

    it('should throw ForbiddenException when an unauthorized user adds a track to a RESTRICTED playlist', async () => {
      repository.getPlaylistDetails.mockResolvedValueOnce(
        buildPlaylist({ editLicense: PlaylistEditLicense.RESTRICTED }),
      );

      await expect(
        service.addTrackToPlaylist(PLAYLIST_ID, OTHER_USER_ID, sampleTrack),
      ).rejects.toThrow(ForbiddenException);
    });
  });
});
