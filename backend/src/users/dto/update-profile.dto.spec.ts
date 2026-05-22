import { validate } from 'class-validator';
import { plainToInstance } from 'class-transformer';
import {
  UpdateProfileDto,
  FriendInfoDto,
  PrivateInfoDto,
} from './update-profile.dto';

describe('UpdateProfileDto', () => {
  it('should pass with valid update data', async () => {
    const dto = plainToInstance(UpdateProfileDto, {
      friendInfo: {
        location: 'New York, USA',
      },
      privateInfo: {
        physicalAddress: '123 Main St, Apt 4B',
      },
    });

    const errors = await validate(dto);
    expect(errors).toHaveLength(0);
  });

  it('should reject location longer than 255 characters in FriendInfoDto', async () => {
    const friendInfo = plainToInstance(FriendInfoDto, {
      location: 'a'.repeat(256),
    });

    const errors = await validate(friendInfo);
    const match = errors.find((e) => e.property === 'location');
    expect(match).toBeDefined();
  });

  it('should reject physicalAddress longer than 255 characters in PrivateInfoDto', async () => {
    const privateInfo = plainToInstance(PrivateInfoDto, {
      physicalAddress: 'a'.repeat(256),
    });

    const errors = await validate(privateInfo);
    const match = errors.find((e) => e.property === 'physicalAddress');
    expect(match).toBeDefined();
  });

  it('should reject invalid nested location in UpdateProfileDto', async () => {
    const dto = plainToInstance(UpdateProfileDto, {
      friendInfo: {
        location: 'a'.repeat(256),
      },
    });

    const errors = await validate(dto);
    expect(errors).toHaveLength(1);
    expect(errors[0].property).toBe('friendInfo');
  });

  it('should reject invalid nested physicalAddress in UpdateProfileDto', async () => {
    const dto = plainToInstance(UpdateProfileDto, {
      privateInfo: {
        physicalAddress: 'a'.repeat(256),
      },
    });

    const errors = await validate(dto);
    expect(errors).toHaveLength(1);
    expect(errors[0].property).toBe('privateInfo');
  });
});
