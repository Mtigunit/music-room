import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Server } from 'node:http';
import request from 'supertest';
import { ConfigModule } from '@nestjs/config';
import { PlaylistsModule } from '../src/playlists/playlists.module';
import { PrismaModule } from '../src/prisma/prisma.module';
import { PrismaService } from '../src/prisma/prisma.service';
import { JwtAuthGuard } from '../src/auth/guards/jwt-auth.guard';
import { PlaylistEditLicense, PlaylistVisibility } from '@prisma/client';

/**
 * A mock guard that injects a fake user into the request.
 * This lets us test real DB behavior without needing real JWTs.
 */
let MOCK_USER_ID = '';

class MockJwtAuthGuard {
  canActivate(context: {
    switchToHttp: () => { getRequest: () => Express.Request };
  }) {
    const req = context.switchToHttp().getRequest();
    req.user = {
      id: MOCK_USER_ID,
      email: `${MOCK_USER_ID}@test.com`,
      sub: MOCK_USER_ID,
    };
    return true;
  }
}

describe('Playlists Integration (e2e)', () => {
  let app: INestApplication<Server>;
  let prisma: PrismaService;
  let ownerId: string;
  let otherUserId: string;

  beforeAll(async () => {
    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [
        ConfigModule.forRoot({ isGlobal: true }),
        PrismaModule,
        PlaylistsModule,
      ],
    })
      .overrideGuard(JwtAuthGuard)
      .useClass(MockJwtAuthGuard)
      .compile();

    app = moduleFixture.createNestApplication();
    app.useGlobalPipes(
      new ValidationPipe({
        transform: true,
        transformOptions: { enableImplicitConversion: true },
      }),
    );
    await app.init();

    prisma = moduleFixture.get<PrismaService>(PrismaService);

    // Seed two test users
    const owner = await prisma.user.create({
      data: {
        email: 'integration-owner@test.com',
        username: 'integration_owner',
        isEmailVerified: true,
      },
    });
    const other = await prisma.user.create({
      data: {
        email: 'integration-other@test.com',
        username: 'integration_other',
        isEmailVerified: true,
      },
    });
    ownerId = owner.id;
    otherUserId = other.id;
  });

  afterAll(async () => {
    // Clean up seeded data in dependency order
    await prisma.playlistCollaborator.deleteMany({});
    await prisma.playlistTrack.deleteMany({});
    await prisma.playlistCounter.deleteMany({});
    await prisma.playlist.deleteMany({});
    await prisma.user.deleteMany({
      where: {
        email: {
          in: ['integration-owner@test.com', 'integration-other@test.com'],
        },
      },
    });
    await app.close();
  });

  // ─── POST /playlists ──────────────────────────────────────

  describe('POST /playlists', () => {
    it('should create a playlist and persist it in the database', async () => {
      MOCK_USER_ID = ownerId;

      const res = await request(app.getHttpServer())
        .post('/playlists')
        .send({
          name: 'Integration Test Playlist',
          visibility: PlaylistVisibility.PUBLIC,
          editLicense: PlaylistEditLicense.OPEN,
          tags: ['CHILL'],
        })
        .expect(201);

      expect(res.body).toHaveProperty('id');
      expect(res.body.name).toBe('Integration Test Playlist');
      expect(res.body.ownerId).toBe(ownerId);

      // Verify it actually exists in the DB
      const dbPlaylist = await prisma.playlist.findUnique({
        where: { id: res.body.id as string },
      });
      expect(dbPlaylist).not.toBeNull();
    });

    it('should reject invalid enum values with 400', async () => {
      MOCK_USER_ID = ownerId;

      await request(app.getHttpServer())
        .post('/playlists')
        .send({
          name: 'Bad Playlist',
          visibility: 'INVALID',
          editLicense: 'OPEN',
        })
        .expect(400);
    });
  });

  // ─── GET /playlists ───────────────────────────────────────

  describe('GET /playlists', () => {
    it('should return paginated playlists for the authenticated user', async () => {
      MOCK_USER_ID = ownerId;

      const res = await request(app.getHttpServer())
        .get('/playlists?page=1&limit=10')
        .expect(200);

      expect(res.body).toHaveProperty('data');
      expect(res.body).toHaveProperty('meta');
      expect(res.body.meta.page).toBe(1);
      expect(res.body.meta.limit).toBe(10);
      expect(Array.isArray(res.body.data)).toBe(true);
      expect(res.body.data.length).toBeGreaterThan(0);
    });
  });

  // ─── GET /playlists/explore ───────────────────────────────

  describe('GET /playlists/explore', () => {
    it('should return public playlists with search filtering', async () => {
      MOCK_USER_ID = otherUserId;

      const res = await request(app.getHttpServer())
        .get('/playlists/explore?q=Integration')
        .expect(200);

      expect(res.body.data.length).toBeGreaterThan(0);
      expect(res.body.data[0]).toHaveProperty('owner');
      expect(res.body.data[0]).toHaveProperty('_count');
    });

    it('should return empty results for a non-matching search', async () => {
      MOCK_USER_ID = otherUserId;

      const res = await request(app.getHttpServer())
        .get('/playlists/explore?q=xyznonexistent')
        .expect(200);

      expect(res.body.data.length).toBe(0);
    });
  });

  // ─── GET /playlists/:id ───────────────────────────────────

  describe('GET /playlists/:id', () => {
    let playlistId: string;

    beforeAll(async () => {
      // Create a private playlist for this suite
      MOCK_USER_ID = ownerId;
      const res = await request(app.getHttpServer()).post('/playlists').send({
        name: 'Private Suite Playlist',
        visibility: PlaylistVisibility.PRIVATE,
        editLicense: PlaylistEditLicense.RESTRICTED,
      });
      playlistId = res.body.id as string;
    });

    it('should return playlist details to the owner', async () => {
      MOCK_USER_ID = ownerId;

      const res = await request(app.getHttpServer())
        .get(`/playlists/${playlistId}`)
        .expect(200);

      expect(res.body.id).toBe(playlistId);
      expect(res.body).toHaveProperty('tracks');
      expect(res.body).toHaveProperty('collaborators');
    });

    it('should return 403 for a private playlist when requester is not authorized', async () => {
      MOCK_USER_ID = otherUserId;

      await request(app.getHttpServer())
        .get(`/playlists/${playlistId}`)
        .expect(403);
    });
  });

  // ─── PATCH /playlists/:id ─────────────────────────────────

  describe('PATCH /playlists/:id', () => {
    let playlistId: string;

    beforeAll(async () => {
      MOCK_USER_ID = ownerId;
      const res = await request(app.getHttpServer()).post('/playlists').send({
        name: 'To Be Updated',
        visibility: PlaylistVisibility.PUBLIC,
        editLicense: PlaylistEditLicense.OPEN,
      });
      playlistId = res.body.id as string;
    });

    it('should allow the owner to update the playlist', async () => {
      MOCK_USER_ID = ownerId;

      const res = await request(app.getHttpServer())
        .patch(`/playlists/${playlistId}`)
        .send({ name: 'Updated Name' })
        .expect(200);

      expect(res.body.name).toBe('Updated Name');
    });

    it('should return 403 when a non-owner tries to update', async () => {
      MOCK_USER_ID = otherUserId;

      await request(app.getHttpServer())
        .patch(`/playlists/${playlistId}`)
        .send({ name: 'Hijacked' })
        .expect(403);
    });
  });

  // ─── DELETE /playlists/:id ────────────────────────────────

  describe('DELETE /playlists/:id', () => {
    let playlistId: string;

    beforeAll(async () => {
      MOCK_USER_ID = ownerId;
      const res = await request(app.getHttpServer()).post('/playlists').send({
        name: 'To Be Deleted',
        visibility: PlaylistVisibility.PUBLIC,
        editLicense: PlaylistEditLicense.OPEN,
      });
      playlistId = res.body.id as string;
    });

    it('should return 403 when a non-owner tries to delete', async () => {
      MOCK_USER_ID = otherUserId;

      await request(app.getHttpServer())
        .delete(`/playlists/${playlistId}`)
        .expect(403);
    });

    it('should allow the owner to delete the playlist', async () => {
      MOCK_USER_ID = ownerId;

      await request(app.getHttpServer())
        .delete(`/playlists/${playlistId}`)
        .expect(200);

      // Verify it no longer exists in the DB
      const dbPlaylist = await prisma.playlist.findUnique({
        where: { id: playlistId },
      });
      expect(dbPlaylist).toBeNull();
    });
  });

  // ─── POST /playlists/:id/collaborators ────────────────────

  describe('POST /playlists/:id/collaborators', () => {
    let playlistId: string;

    beforeAll(async () => {
      MOCK_USER_ID = ownerId;
      const res = await request(app.getHttpServer()).post('/playlists').send({
        name: 'Collab Playlist',
        visibility: PlaylistVisibility.PRIVATE,
        editLicense: PlaylistEditLicense.RESTRICTED,
      });
      playlistId = res.body.id as string;
    });

    it('should return 403 when a non-owner tries to add a collaborator', async () => {
      MOCK_USER_ID = otherUserId;

      await request(app.getHttpServer())
        .post(`/playlists/${playlistId}/collaborators`)
        .send({ targetUserId: otherUserId })
        .expect(403);
    });

    it('should allow the owner to add a collaborator', async () => {
      MOCK_USER_ID = ownerId;

      const res = await request(app.getHttpServer())
        .post(`/playlists/${playlistId}/collaborators`)
        .send({ targetUserId: otherUserId })
        .expect(201);

      expect(res.body.user.id).toBe(otherUserId);
    });

    it('should grant the new collaborator access to the private playlist', async () => {
      // otherUserId was just added as a collaborator above
      MOCK_USER_ID = otherUserId;

      await request(app.getHttpServer())
        .get(`/playlists/${playlistId}`)
        .expect(200);
    });
  });
});
