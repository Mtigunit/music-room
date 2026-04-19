import { Test, TestingModule } from '@nestjs/testing';
import { PlaylistsService } from './playlists.service';
import { PlaylistsRepository } from './playlists.repository';
import { TrackSearchResultDto } from '../tracks/dto/track-search-result.dto';
import { PlaylistEditLicense } from '@prisma/client';

describe('PlaylistsService', () => {
  let service: PlaylistsService;
  let repository: jest.Mocked<PlaylistsRepository>;

  const sampleTrack: TrackSearchResultDto = {
    providerTrackId: 'dQw4w9WgXcQ',
    title: 'Never Gonna Give You Up',
    artist: 'Rick Astley',
    durationMs: 213000,
    thumbnailUrl: 'https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg',
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        PlaylistsService,
        {
          provide: PlaylistsRepository,
          useValue: {
            addTrackToPlaylist: jest.fn(),
            getPlaylistDetails: jest.fn(),
          },
        },
      ],
    }).compile();

    service = module.get<PlaylistsService>(PlaylistsService);
    repository = module.get<PlaylistsRepository>(
      PlaylistsRepository,
    ) as jest.Mocked<PlaylistsRepository>;

    repository.getPlaylistDetails.mockResolvedValue({
      id: 'playlist-1',
      name: 'Test Playlist',
      visibility: 'PUBLIC',
      editLicense: PlaylistEditLicense.OPEN,
      description: null,
      tags: [],
      ownerId: 'owner-1',
      createdAt: new Date(),
      updatedAt: new Date(),
      collaborators: [],
      tracks: [],
      owner: { id: 'owner-1', username: 'owner' },
    } as NonNullable<
      Awaited<ReturnType<PlaylistsRepository['getPlaylistDetails']>>
    >);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  it('should allow concurrent addTrackToPlaylist calls', async () => {
    repository.addTrackToPlaylist.mockResolvedValueOnce({} as never);
    repository.addTrackToPlaylist.mockResolvedValueOnce({} as never);

    await Promise.all([
      service.addTrackToPlaylist('playlist-1', 'user-1', sampleTrack),
      service.addTrackToPlaylist('playlist-1', 'user-2', sampleTrack),
    ]);

    expect(repository.addTrackToPlaylist).toHaveBeenCalledTimes(2);
  });

  it('should surface errors when PlaylistCounter is missing', async () => {
    const error = new Error('PlaylistCounter not found');
    repository.addTrackToPlaylist.mockRejectedValueOnce(error);

    await expect(
      service.addTrackToPlaylist('playlist-1', 'user-1', sampleTrack),
    ).rejects.toThrow('PlaylistCounter not found');
  });

  it('should surface transaction rollback failures', async () => {
    const error = new Error('Transaction failed');
    repository.addTrackToPlaylist.mockRejectedValueOnce(error);

    await expect(
      service.addTrackToPlaylist('playlist-1', 'user-1', sampleTrack),
    ).rejects.toThrow('Transaction failed');
  });
});
