import { Visibility, PlaylistEditLicense } from '@prisma/client';

export interface PlaylistAuthData {
  id: string;
  ownerId: string;
  visibility: Visibility;
  editLicense: PlaylistEditLicense;
  updatedAt: Date;
  collaborators: {
    userId: string;
  }[];
  _count: {
    tracks: number;
  };
}
